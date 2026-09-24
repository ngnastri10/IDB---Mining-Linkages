"""
Turn mine-level data into treatment variables for every municipal seat
(sede) and year: how many mines are near this town, and in what state.

For each sede x year (2003-2025) and each distance band, counts mines that:
  active        - are producing that year (between first and last royalty payment)
  opened        - opened that year (first royalty payment, 2003 on)
  closed        - closed that year (last payment, never paid in 2025-2026)
  requested     - are in the pipeline: concession requested, not granted yet
  granted       - are in the pipeline: concession granted, not open yet
  never_opened  - entered the pipeline and never opened (the controls).
                  Stays on from the year it entered.

Each gets a count (n_active_mine_10km) and a 1/0 (active_mine_10km).

Distance bands, measured straight-line from the sede to the mine's point:
  rings:       10km (0-10), 10_25km, 25_50km, 50_100km
  cumulative:  10km, 25km, 50km, 100km (= rings added up; 10km is both)

Plus, for each band:
  first_opened_year_<band>  - first year any mine in the band started
                              producing (2002/2003 = already producing when
                              CFEM started)
and, for the cumulative bands only:
  mine_group_<band>
      1 = treated        (first mine in the band started producing 2008-2025)
      2 = control        (a pipeline right in the band, but no mine ever)
      3 = always treated (a mine in the band producing by 2007 - drop these,
                          see Goodman-Bacon 2021 / Callaway & Sant'Anna 2021)
      4 = no mining potential (nothing in the band - drop these)

Two versions get written, so you can toggle between them:
  _priced - only mines of minerals we have a world price for (iron, gold,
            copper, aluminum/bauxite, nickel, tin, zinc, lead, silver,
            platinum). Drops sand pits, clay, gravel, stone, water, etc.
  _all    - every mine

Each mining right's mineral comes from its main CFEM royalty substance if
it ever paid royalties; otherwise (pipeline rights that never produced)
from the substances listed for it in the registry. The name -> price group
mapping is in Data/Crosswalks/substance_to_price_group.csv - edit it there.

Runs on plain numpy (no GIS packages). Distances use the haversine formula.

Inputs:
  Data/Crosswalks/municipality_latlon.csv
  Data/Crosswalks/substance_to_price_group.csv
  Working/Mines/mine_locations.dta
  Working/Mines/mine_timeline.dta
  Working/Mines/mine_pipeline.dta
  LARGE_DATA_ROOT/SCM/microdados/ProcessoSubstancia.txt

Outputs:
  Working/Mines/municipality_year_mining_priced.dta
  Working/Mines/municipality_year_mining_all.dta
  Working/Mines/mine_price_group.dta (each mining right's price group)

Same config.py setup as the other scripts - run config.do in Stata first.
"""

import sys
from pathlib import Path

import numpy as np
import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

try:
    import config
except ImportError:
    raise SystemExit(
        "Couldn't find config.py in the Code folder.\n"
        "Run config.do in Stata first (once per session) - see the README."
    )

MINES = Path(config.PROJECT_ROOT) / "Working" / "Mines"
CROSSWALKS = Path(config.PROJECT_ROOT) / "Data" / "Crosswalks"

FIRST_YEAR, LAST_YEAR = 2003, 2025
PANEL_START = 2007  # first RAIS year - producing by then = always treated
YEARS = np.arange(FIRST_YEAR, LAST_YEAR + 1)
N_YEARS = len(YEARS)

RING_EDGES = [10, 25, 50]  # rings: <=10, 10-25, 25-50, 50-100
MAX_KM = 100
N_RINGS = 4

# (band name, how to get it from the 4 rings, label text)
BANDS = [
    ("10km", ("ring", 0), "within 10 km"),
    ("10_25km", ("ring", 1), "10-25 km"),
    ("25_50km", ("ring", 2), "25-50 km"),
    ("50_100km", ("ring", 3), "50-100 km"),
    ("25km", ("cum", 1), "within 25 km"),
    ("50km", ("cum", 2), "within 50 km"),
    ("100km", ("cum", 3), "within 100 km"),
]
CUMULATIVE_BANDS = [("10km", 0), ("25km", 1), ("50km", 2), ("100km", 3)]

MEASURES = {
    "active": "producing",
    "opened": "opened this yr",
    "closed": "closed this yr",
    "requested": "requested, not granted",
    "granted": "granted, not open",
    "never_opened": "pipeline, never opened",
}

KEYS = ["process_number", "process_year"]


def fix_keys(df):
    for k in KEYS:
        df[k] = df[k].astype("int64")
    return df


def pairs_within(seat_lat, seat_lon, mine_lat, mine_lon, chunk=100):
    """Every (seat, mine) pair within MAX_KM, with the distance in km.

    Done a chunk of seats at a time so the distance matrix fits in memory.
    """
    earth_km = 6371.0
    mlat, mlon = np.radians(mine_lat), np.radians(mine_lon)
    seats_out, mines_out, dist_out = [], [], []
    for start in range(0, len(seat_lat), chunk):
        slat = np.radians(seat_lat[start:start + chunk])[:, None]
        slon = np.radians(seat_lon[start:start + chunk])[:, None]
        h = np.sin((mlat - slat) / 2) ** 2 + np.cos(slat) * np.cos(mlat) * np.sin((mlon - slon) / 2) ** 2
        d = 2 * earth_km * np.arcsin(np.sqrt(h))
        s_idx, m_idx = np.nonzero(d <= MAX_KM)
        seats_out.append(s_idx + start)
        mines_out.append(m_idx)
        dist_out.append(d[s_idx, m_idx])
    return np.concatenate(seats_out), np.concatenate(mines_out), np.concatenate(dist_out)


def count_intervals(seat, ring, start_year, end_year, n_seats):
    """Count, for each seat x ring x year, how many mines are "on" - each
    mine is on from start_year through end_year (inclusive).

    Uses a running sum: +1 in the start year, -1 the year after the end.
    """
    ok = ~np.isnan(start_year) & ~np.isnan(end_year)
    a = np.clip(start_year[ok], FIRST_YEAR, None).astype(int) - FIRST_YEAR
    b = np.clip(end_year[ok], None, LAST_YEAR).astype(int) - FIRST_YEAR
    keep = a <= b
    s, r, a, b = seat[ok][keep], ring[ok][keep], a[keep], b[keep]

    diff = np.zeros((n_seats, N_RINGS, N_YEARS + 1), dtype=np.int32)
    np.add.at(diff, (s, r, a), 1)
    np.add.at(diff, (s, r, b + 1), -1)
    return diff.cumsum(axis=2)[:, :, :N_YEARS]


def col(df, name):
    return df[name].to_numpy(dtype=float)


def price_groups(timeline):
    """Each mining right's price group (iron, gold, ...) or blank if unpriced.

    Rights that paid royalties: their main CFEM substance. Rights that never
    did: any priced substance listed for them in the registry.
    """
    crosswalk = pd.read_csv(CROSSWALKS / "substance_to_price_group.csv", dtype=str)
    cfem_map = crosswalk[crosswalk.source == "cfem"].set_index("substance").price_group
    reg_map = crosswalk[crosswalk.source == "registry"].set_index("substance_id").price_group

    producing = timeline[KEYS].copy()
    producing["price_group"] = timeline.main_substance.map(cfem_map)

    reg = pd.read_csv(Path(config.LARGE_DATA_ROOT) / "SCM" / "microdados" / "ProcessoSubstancia.txt",
                      sep=";", encoding="latin-1", dtype=str, usecols=["DSProcesso", "IDSubstancia"])
    reg["price_group"] = reg.IDSubstancia.map(reg_map)
    reg = reg.dropna(subset=["price_group"]).drop_duplicates("DSProcesso")
    # Registry IDs look like "930.641/1989".
    reg["process_number"] = reg.DSProcesso.str.split("/").str[0].str.replace(".", "", regex=False).astype("int64")
    reg["process_year"] = reg.DSProcesso.str.split("/").str[1].str[:4].astype("int64")
    reg = reg[KEYS + ["price_group"]]

    # Producing rights keep their CFEM answer (even if blank); only rights
    # that never paid royalties fall back to the registry.
    reg = reg.merge(producing[KEYS], on=KEYS, how="left", indicator=True)
    reg = reg[reg._merge == "left_only"].drop(columns="_merge")
    return pd.concat([producing, reg], ignore_index=True)


def build_panel(pairs, timeline, pipeline, seats):
    """Sede x year treatment variables from a set of sede-mine pairs."""
    n_seats = len(seats)
    tp = pairs.merge(timeline, on=KEYS, how="inner")
    pp = pairs.merge(pipeline, on=KEYS, how="inner")
    t_seat, t_ring = tp.seat.to_numpy(), tp.ring.to_numpy()
    p_seat, p_ring = pp.seat.to_numpy(), pp.ring.to_numpy()

    # Counts per seat x ring x year, one array per measure.
    counts = {}
    counts["active"] = count_intervals(t_seat, t_ring, col(tp, "first_year"), col(tp, "last_year"), n_seats)
    counts["opened"] = count_intervals(t_seat, t_ring, col(tp, "opened_year"), col(tp, "opened_year"), n_seats)
    counts["closed"] = count_intervals(t_seat, t_ring, col(tp, "closed_year"), col(tp, "closed_year"), n_seats)

    # Requested: from entering until the grant (or leaving the pipeline).
    req_end = np.fmin(col(pp, "granted_year"), col(pp, "pipeline_end_year")) - 1
    req_end = np.where(np.isnan(req_end), LAST_YEAR, req_end)
    counts["requested"] = count_intervals(p_seat, p_ring, col(pp, "pipeline_start_year"), req_end, n_seats)

    # Granted: from the grant until it leaves the pipeline.
    gr_end = col(pp, "pipeline_end_year") - 1
    gr_end = np.where(np.isnan(gr_end), LAST_YEAR, gr_end)
    counts["granted"] = count_intervals(p_seat, p_ring, col(pp, "granted_year"), gr_end, n_seats)

    # Never opened: on from the year it entered the pipeline, stays on.
    never = pp.ever_opened.to_numpy() == 0
    counts["never_opened"] = count_intervals(
        p_seat[never], p_ring[never], col(pp, "pipeline_start_year")[never],
        np.full(never.sum(), float(LAST_YEAR)), n_seats)

    # First year a mine started producing, per seat x ring, and whether there
    # was any pipeline right (= viable) in that ring.
    first = np.full((n_seats, N_RINGS), np.inf)
    fy = col(tp, "first_year")
    ok = ~np.isnan(fy) & (fy <= LAST_YEAR)
    np.minimum.at(first, (t_seat[ok], t_ring[ok]), fy[ok])

    viable = np.zeros((n_seats, N_RINGS), dtype=bool)
    viable[p_seat, p_ring] = True

    first_cum = np.minimum.accumulate(first, axis=1)
    viable_cum = np.logical_or.accumulate(viable, axis=1)

    # Assemble.
    out = {
        "municipality": np.repeat(seats.municipality.to_numpy(), N_YEARS),
        "year": np.tile(YEARS, n_seats),
    }
    labels = {"municipality": "Municipality (6-digit IBGE code)", "year": "Year"}

    cum_counts = {m: arr.cumsum(axis=1) for m, arr in counts.items()}
    for m, m_text in MEASURES.items():
        for band, (kind, k), band_text in BANDS:
            arr = counts[m][:, k, :] if kind == "ring" else cum_counts[m][:, k, :]
            flat = arr.reshape(-1)
            out[f"n_{m}_mine_{band}"] = flat.astype(np.int32)
            out[f"{m}_mine_{band}"] = (flat > 0).astype(np.int8)
            labels[f"n_{m}_mine_{band}"] = f"# mines {m_text}, {band_text}"
            labels[f"{m}_mine_{band}"] = f"Any mine {m_text}, {band_text}"

    for band, (kind, k), band_text in BANDS:
        f = first[:, k] if kind == "ring" else first_cum[:, k]
        f = np.where(np.isinf(f), np.nan, f)
        out[f"first_opened_year_{band}"] = np.repeat(f, N_YEARS)
        labels[f"first_opened_year_{band}"] = f"First year a mine produced, {band_text}"

    for band, k in CUMULATIVE_BANDS:
        g = np.full(n_seats, 4, dtype=np.int8)
        g[viable_cum[:, k]] = 2
        g[first_cum[:, k] <= PANEL_START] = 3
        g[(first_cum[:, k] > PANEL_START) & (first_cum[:, k] <= LAST_YEAR)] = 1
        out[f"mine_group_{band}"] = np.repeat(g, N_YEARS)
        labels[f"mine_group_{band}"] = f"Treatment group, {band.replace('km', ' km')}"
        print(f"  Sedes by group, {band}: {pd.Series(g).map(GROUP_LABELS).value_counts().to_dict()}")

    return pd.DataFrame(out), labels


GROUP_LABELS = {1: "Treated", 2: "Control", 3: "Always treated", 4: "No mining potential"}


def main():
    seats = pd.read_csv(CROSSWALKS / "municipality_latlon.csv")

    loc = pd.read_stata(MINES / "mine_locations.dta")[KEYS + ["lat", "lon"]].dropna()
    loc = fix_keys(loc).reset_index(drop=True)

    timeline = fix_keys(pd.read_stata(MINES / "mine_timeline.dta")[
        KEYS + ["first_year", "last_year", "opened_year", "closed_year", "main_substance"]])
    pipeline = fix_keys(pd.read_stata(MINES / "mine_pipeline.dta", convert_categoricals=False)[
        KEYS + ["pipeline_start_year", "granted_year", "pipeline_end_year", "ever_opened"]])

    print(f"Sedes: {len(seats):,} | mines with a location: {len(loc):,}")

    # Every sede-mine pair within 100 km, and which ring it falls in.
    s_idx, m_idx, dist = pairs_within(
        seats.seat_lat.to_numpy(), seats.seat_lon.to_numpy(),
        loc.lat.to_numpy(), loc.lon.to_numpy())
    pairs = pd.DataFrame({"seat": s_idx, "ring": np.searchsorted(RING_EDGES, dist, side="left")})
    pairs = pd.concat([pairs, loc.loc[m_idx, KEYS].reset_index(drop=True)], axis=1)
    print(f"Sede-mine pairs within {MAX_KM} km: {len(pairs):,}")

    # Price group per mining right - saved for the price index later.
    groups = price_groups(timeline)
    groups.to_stata(MINES / "mine_price_group.dta", write_index=False, version=118,
                    variable_labels={"price_group": "Priced mineral group (blank = no world price)"})
    priced = groups.dropna(subset=["price_group"])
    print(f"Mining rights with a priced mineral: {len(priced):,} "
          f"({priced.price_group.value_counts().to_dict()})")

    versions = {
        "all": pairs,
        "priced": pairs.merge(priced[KEYS], on=KEYS, how="inner"),
    }
    for name, version_pairs in versions.items():
        print(f"\n[{name}] {len(version_pairs):,} sede-mine pairs")
        panel, labels = build_panel(version_pairs, timeline, pipeline, seats)
        out_path = MINES / f"municipality_year_mining_{name}.dta"
        panel.to_stata(
            out_path, write_index=False, version=118, variable_labels=labels,
            value_labels={f"mine_group_{b}": GROUP_LABELS for b, _ in CUMULATIVE_BANDS},
        )
        print(f"  Saved {len(panel):,} rows, {panel.shape[1]} columns -> {out_path}")


if __name__ == "__main__":
    main()
