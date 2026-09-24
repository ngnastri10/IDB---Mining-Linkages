"""
Build the shift-share price shock for every municipality and year
(2007-2025):

    shock_<band> = share x price_index_<band>

    share          - 2007 employment share in metal mining: iron ore (791)
                     + non-ferrous metals (792). 580 (coal + sand/stone
                     quarrying) is left out - those are the unpriced sand pits.
    price_index    - sum over minerals of weight x log(price / 2007 price).
                     Weights = each mineral's share of CFEM royalties paid
                     2003-2006 (before RAIS starts) by priced mines within
                     <band> of the town seat. Prices are World Bank, USD,
                     yearly averages.

Towns with no priced mine paying royalties nearby in 2003-2006 have no
weights: price_index is missing and shock is 0 (no exposure).

First-pass defaults - see Code/open_decisions.md for the alternatives.

Inputs:
  Data/Crosswalks/municipality_latlon.csv
  Working/Mines/CFEM/cfem_process_month.dta
  Working/Mines/mine_price_group.dta
  Working/Mines/mine_locations.dta
  Working/WB Prices/wb_commodity_prices_monthly.dta
  LARGE_DATA_ROOT/RAIS/Working/CNAE67/cleaned_all_years.dta

Output:
  Working/Mines/municipality_year_price_shock.dta

Same config.py setup as the other scripts - run config.do in Stata first.
"""

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_mine_distances import config, pairs_within, fix_keys, KEYS, MINES, CROSSWALKS

BASE_YEARS = (2003, 2006)   # royalty weights
SHARE_YEAR = 2007           # employment share
PRICE_BASE_YEAR = 2007      # prices relative to this year
YEARS = range(2007, 2026)
BANDS_KM = [10, 25, 50, 100]
MINING_CNAE67 = [791, 792]

PRICE_COLUMNS = {
    "iron": "iron_price", "gold": "gold_price", "copper": "copper_price",
    "aluminum": "aluminum_price", "nickel": "nickel_price", "tin": "tin_price",
    "zinc": "zinc_price", "lead": "lead_price", "silver": "silver_price",
    "platinum": "platinum_price",
}


def main():
    seats = pd.read_csv(CROSSWALKS / "municipality_latlon.csv")

    # 1. Base-period royalties of each priced mine, with its location.
    cfem = pd.read_stata(MINES / "CFEM" / "cfem_process_month.dta",
                         columns=["year", "process_number", "process_year", "royalty_value"])
    cfem = cfem.dropna(subset=KEYS)
    cfem = cfem[cfem.year.between(*BASE_YEARS)]
    base = fix_keys(cfem.groupby(KEYS, as_index=False).royalty_value.sum())

    groups = fix_keys(pd.read_stata(MINES / "mine_price_group.dta")).dropna(subset=["price_group"])
    loc = fix_keys(pd.read_stata(MINES / "mine_locations.dta")[KEYS + ["lat", "lon"]].dropna())
    base = base.merge(groups, on=KEYS).merge(loc, on=KEYS)
    print(f"Priced mines paying royalties {BASE_YEARS[0]}-{BASE_YEARS[1]}: {len(base):,}")

    s_idx, m_idx, dist = pairs_within(
        seats.seat_lat.to_numpy(), seats.seat_lon.to_numpy(),
        base.lat.to_numpy(), base.lon.to_numpy())
    pairs = pd.DataFrame({
        "seat": s_idx,
        "dist": dist,
        "price_group": base.price_group.to_numpy()[m_idx],
        "royalty": base.royalty_value.to_numpy()[m_idx],
    })

    # 2. Log prices relative to the base year.
    prices = pd.read_stata(Path(config.PROJECT_ROOT) / "Working" / "WB Prices" / "wb_commodity_prices_monthly.dta")
    for c in PRICE_COLUMNS.values():
        prices[c] = pd.to_numeric(prices[c], errors="coerce")
    annual = prices.groupby("year")[list(PRICE_COLUMNS.values())].mean()
    annual.columns = list(PRICE_COLUMNS)
    log_rel = np.log(annual) - np.log(annual.loc[PRICE_BASE_YEAR])
    log_rel = log_rel.loc[list(YEARS)]

    # 3. Mining employment share, 2007.
    rais = pd.read_stata(Path(config.LARGE_DATA_ROOT) / "RAIS" / "Working" / "CNAE67" / "cleaned_all_years.dta",
                         columns=["municipality", "cnae67", "year", "number_employed"])
    r = rais[rais.year == SHARE_YEAR]
    total = r.groupby("municipality").number_employed.sum()
    mining = r[r.cnae67.isin(MINING_CNAE67)].groupby("municipality").number_employed.sum()
    share = (mining.reindex(total.index).fillna(0) / total)

    # 4. Assemble municipality x year.
    n_years = len(YEARS)
    out = {
        "municipality": np.repeat(seats.municipality.to_numpy(), n_years),
        "year": np.tile(list(YEARS), len(seats)),
    }
    share_by_seat = share.reindex(seats.municipality).to_numpy()
    out["mining_emp_share_2007"] = np.repeat(share_by_seat, n_years)
    labels = {
        "municipality": "Municipality (6-digit IBGE code)",
        "year": "Year",
        "mining_emp_share_2007": "2007 employment share in metal mining (cnae67 791+792)",
    }

    for b in BANDS_KM:
        near = pairs[pairs.dist <= b]
        w = near.pivot_table(index="seat", columns="price_group", values="royalty", aggfunc="sum", fill_value=0)
        w = w.reindex(columns=list(PRICE_COLUMNS), fill_value=0)
        w = w.div(w.sum(axis=1), axis=0)
        # seats x years
        index = w.to_numpy() @ log_rel.fillna(0).to_numpy().T
        full = np.full((len(seats), n_years), np.nan)
        full[w.index.to_numpy()] = index
        price_index = full.reshape(-1)

        shock = out["mining_emp_share_2007"] * np.where(np.isnan(price_index), 0, price_index)

        out[f"price_index_{b}km"] = price_index
        out[f"shock_{b}km"] = shock
        labels[f"price_index_{b}km"] = f"Mineral price index (log vs 2007), royalty-weighted, within {b} km"
        labels[f"shock_{b}km"] = f"Shift-share price shock, within {b} km"
        print(f"  {b} km: {len(w):,} sedes have priced mines nearby in the base period")

    panel = pd.DataFrame(out)
    out_path = MINES / "municipality_year_price_shock.dta"
    panel.to_stata(out_path, write_index=False, version=118, variable_labels=labels)
    print(f"Saved {len(panel):,} rows -> {out_path}")


if __name__ == "__main__":
    main()
