"""
Make the project maps. All use the "priced" mining version (only mines of
minerals with a world price - no sand pits, clay, gravel, ...).

  1. treatment_groups_25km.png       municipalities colored by group, 25 km band
  2. treatment_groups_25km_dots.png  same, as dots at each sede (no borders)
  3. ring_zoom_example.png           one sede (control at 25 km, treated at
                                     50 km) with its 10/25/50/100 km rings;
                                     mines split by already open / opened in
                                     the window / never opened; Brazil inset
  4. mines_by_mineral.png            priced mines colored by mineral, sized
                                     by total royalties
  5. opening_timing_25km.png         treated municipalities by year their
                                     first mine opened, 25 km band

Groups: 1 treated (first mine within the band opens 2008-2025), 2 control
(concession requested/granted nearby, no mine ever opened), 3 always
treated (mine open by 2007), 4 no mining potential.

Inputs:
  Working/Maps/municipalities.gpkg, states.gpkg (from clean_map_boundaries.py)
  Working/Mines/municipality_year_mining_priced.dta
  Working/Mines/mine_locations.dta, mine_timeline.dta, mine_pipeline.dta,
                mine_price_group.dta
  Data/Crosswalks/municipality_latlon.csv (from pull_crosswalks.py)

Output:
  Results/Figures/Maps/*.png

Same config.py setup as the other scripts - run 0. Configure File Paths/config.do in Stata first.
"""

import sys
from pathlib import Path

import geopandas as gpd
import matplotlib
matplotlib.use("Agg")  # draw straight to file, no window
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
import numpy as np
import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "0. Configure File Paths"))

try:
    import config
except ImportError:
    raise SystemExit(
        "Couldn't find config.py in Code/0. Configure File Paths.\n"
        "Run 0. Configure File Paths/config.do in Stata first (once per session) - see the README."
    )

ROOT = Path(config.PROJECT_ROOT)
MAPS = ROOT / "Working" / "Maps"
MINES = ROOT / "Working" / "Mines"
OUT = ROOT / "Results" / "Figures" / "Maps"

KEYS = ["process_number", "process_year"]
DPI = 300

GROUP_LABELS = {1: "Treated", 2: "Control", 3: "Always treated", 4: "No mining potential"}
GROUP_COLORS = {1: "#c0392b", 2: "#2e86c1", 3: "#f0b27a", 4: "#e5e7e9"}

# Iron quadrangle (Minas Gerais), roughly its middle.
ZOOM_CENTER = (-20.15, -43.85)  # lat, lon
ZOOM_RINGS_KM = [10, 25, 50, 100]
ZOOM_CRS = "EPSG:31983"  # SIRGAS 2000 / UTM 23S - distances in meters

PANEL_START = 2007  # first RAIS year - mines open by then make a place "always treated"
LAST_YEAR = 2025

# Cumulative bands ("within X km") - the treatment groups are defined on these.
CUMULATIVE_BANDS_KM = [10, 25, 50, 100]
EXTENSIVE_DIR = OUT / "Extensive Margin"


def fix_keys(df):
    for k in KEYS:
        df[k] = df[k].astype("int64")
    return df


def load_data():
    munis = gpd.read_file(MAPS / "municipalities.gpkg")
    states = gpd.read_file(MAPS / "states.gpkg")

    # Group and first opening year don't change over time - one row each.
    mining = pd.read_stata(MINES / "municipality_year_mining_priced.dta", convert_categoricals=False,
                           columns=["municipality", "year"]
                           + [f"mine_group_{b}km" for b in CUMULATIVE_BANDS_KM]
                           + [f"first_opened_year_{b}km" for b in CUMULATIVE_BANDS_KM])
    mining = mining[mining.year == 2015].drop(columns="year")
    munis = munis.merge(mining, on="municipality", how="left")

    seats = pd.read_csv(ROOT / "Data" / "Crosswalks" / "municipality_latlon.csv").merge(mining, on="municipality", how="left")
    seats = gpd.GeoDataFrame(seats, geometry=gpd.points_from_xy(seats.seat_lon, seats.seat_lat), crs="EPSG:4674")

    loc = fix_keys(pd.read_stata(MINES / "mine_locations.dta")[KEYS + ["lat", "lon", "royalty_total"]].dropna(subset=["lat", "lon"]))
    priced = fix_keys(pd.read_stata(MINES / "mine_price_group.dta"))
    # Stata stores a blank mineral as an empty string, not missing.
    priced = priced[priced.price_group.fillna("") != ""]
    timeline = fix_keys(pd.read_stata(MINES / "mine_timeline.dta")[KEYS + ["first_year"]])
    pipeline = fix_keys(pd.read_stata(MINES / "mine_pipeline.dta", convert_categoricals=False)[KEYS + ["ever_opened"]])

    loc = loc.merge(priced, on=KEYS)  # priced minerals only
    open_mines = loc.merge(timeline, on=KEYS)
    never_opened = loc.merge(pipeline[pipeline.ever_opened == 0], on=KEYS)

    def to_points(df):
        return gpd.GeoDataFrame(df, geometry=gpd.points_from_xy(df.lon, df.lat), crs="EPSG:4674")

    return munis, states, seats, to_points(open_mines), to_points(never_opened)


def base_axes(states, title):
    fig, ax = plt.subplots(figsize=(8, 8))
    states.boundary.plot(ax=ax, color="#555555", linewidth=0.4, zorder=3)
    ax.set_title(title, fontsize=13)
    ax.set_axis_off()
    return fig, ax


def save(fig, name, folder=None):
    folder = folder or OUT
    folder.mkdir(parents=True, exist_ok=True)
    fig.savefig(folder / name, dpi=DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {name}")


def group_legend(ax, counts):
    handles = [Patch(facecolor=GROUP_COLORS[g], edgecolor="#999999",
                     label=f"{GROUP_LABELS[g]} ({counts.get(g, 0):,})") for g in GROUP_LABELS]
    ax.legend(handles=handles, loc="lower left", fontsize=9, frameon=False)


# 1 ---------------------------------------------------------------------------
def map_groups(munis, states):
    fig, ax = base_axes(states, "Municipalities by treatment group (25 km, priced minerals)")
    colors = munis.mine_group_25km.map(GROUP_COLORS).fillna(GROUP_COLORS[4])
    munis.plot(ax=ax, color=colors, linewidth=0.05, edgecolor="white")
    group_legend(ax, munis.mine_group_25km.value_counts().to_dict())
    save(fig, "treatment_groups_25km.png")


# 2 ---------------------------------------------------------------------------
def map_group_dots(seats, states):
    fig, ax = base_axes(states, "Municipal seats by treatment group (25 km, priced minerals)")
    for g in [4, 2, 3, 1]:  # draw the interesting groups on top
        sub = seats[seats.mine_group_25km == g]
        sub.plot(ax=ax, color=GROUP_COLORS[g], markersize=3 if g == 4 else 6, zorder=4)
    group_legend(ax, seats.mine_group_25km.value_counts().to_dict())
    save(fig, "treatment_groups_25km_dots.png")


# 3 ---------------------------------------------------------------------------
def map_ring_zoom(munis, states, seats, open_mines, never_opened):
    # Example sede: a control at 25 km that becomes treated at 50 km, so the
    # rings visibly matter. Of those, the one closest to the iron quadrangle.
    center = gpd.GeoSeries(gpd.points_from_xy([ZOOM_CENTER[1]], [ZOOM_CENTER[0]]), crs="EPSG:4674").to_crs(ZOOM_CRS)
    candidates = seats[(seats.mine_group_25km == 2) & (seats.mine_group_50km == 1)].to_crs(ZOOM_CRS)
    sede = candidates.loc[[candidates.distance(center.iloc[0]).idxmin()]]
    sede_pt = sede.geometry.iloc[0]

    reach = max(ZOOM_RINGS_KM) * 1000 * 1.1
    window = (sede_pt.x - reach, sede_pt.x + reach, sede_pt.y - reach, sede_pt.y + reach)

    fig, ax = plt.subplots(figsize=(8, 8))
    munis.to_crs(ZOOM_CRS).plot(ax=ax, color="#f4f6f7", edgecolor="#c8c8c8", linewidth=0.3)

    for km in ZOOM_RINGS_KM:
        ring = sede_pt.buffer(km * 1000)
        gpd.GeoSeries([ring], crs=ZOOM_CRS).boundary.plot(ax=ax, color="#333333", linewidth=0.9, linestyle="--", zorder=3)
        ax.annotate(f"{km} km", (sede_pt.x, sede_pt.y + km * 1000), fontsize=8, ha="center", va="bottom", zorder=6)

    # Mines split by when they opened - matches the treatment groups.
    mines = open_mines.to_crs(ZOOM_CRS)
    already_open = mines[mines.first_year <= PANEL_START]
    opened_in_window = mines[(mines.first_year > PANEL_START) & (mines.first_year <= LAST_YEAR)]

    never_opened.to_crs(ZOOM_CRS).plot(ax=ax, facecolor="none", edgecolor=GROUP_COLORS[2], markersize=14, linewidth=0.8, zorder=4)
    already_open.plot(ax=ax, color=GROUP_COLORS[3], markersize=12, zorder=5)
    opened_in_window.plot(ax=ax, color=GROUP_COLORS[1], markersize=12, zorder=6)
    sede.plot(ax=ax, color="black", marker="*", markersize=180, zorder=7)

    ax.set_xlim(window[0], window[1])
    ax.set_ylim(window[2], window[3])
    ax.set_axis_off()
    ax.set_title(f"Rings around one sede: {sede.municipality_name.iloc[0]} ({sede.state.iloc[0]})", fontsize=13)
    ax.legend(handles=[
        Line2D([], [], marker="*", color="black", linestyle="", markersize=12, label="Sede (town seat)"),
        Line2D([], [], marker="o", color=GROUP_COLORS[1], linestyle="", markersize=6, label=f"Mine opened {PANEL_START + 1}-{LAST_YEAR}"),
        Line2D([], [], marker="o", color=GROUP_COLORS[3], linestyle="", markersize=6, label=f"Mine already open by {PANEL_START}"),
        Line2D([], [], marker="o", markerfacecolor="none", markeredgecolor=GROUP_COLORS[2], linestyle="",
               markersize=6, label="Concession, never opened"),
    ], loc="lower left", fontsize=9, framealpha=0.9)

    # Small Brazil in the corner, with a red box around the zoomed area.
    inset = ax.inset_axes([0.72, 0.72, 0.27, 0.27])
    inset.set_zorder(10)  # above the mine dots of the main map
    states.plot(ax=inset, color="#e5e7e9", edgecolor="#777777", linewidth=0.3)
    box = gpd.GeoSeries([box_polygon(window)], crs=ZOOM_CRS).to_crs(states.crs)
    box.boundary.plot(ax=inset, color="red", linewidth=1.2)
    inset.set_xticks([])
    inset.set_yticks([])
    inset.set_facecolor("white")

    save(fig, "ring_zoom_example.png")


# 3b --------------------------------------------------------------------------
def map_ring_zoom_pair(munis, states, seats, open_mines, never_opened, shade=None, rings=True):
    # Two neighboring sedes that land in different groups at 25 km:
    #   A = the same example as ring_zoom (control at 25 km, treated at 50 km)
    #   B = the nearest sede to the west/southwest of A that is treated at 25 km
    rings_km = [10, 25, 50]
    center = gpd.GeoSeries(gpd.points_from_xy([ZOOM_CENTER[1]], [ZOOM_CENTER[0]]), crs="EPSG:4674").to_crs(ZOOM_CRS)
    projected = seats.to_crs(ZOOM_CRS)
    candidates = projected[(projected.mine_group_25km == 2) & (projected.mine_group_50km == 1)]
    a = candidates.loc[[candidates.distance(center.iloc[0]).idxmin()]]
    a_pt = a.geometry.iloc[0]

    # At least 55 km apart, so the pair isn't sitting exactly on each other's
    # 50 km ring (looks like a coincidence).
    west_sw = projected[(projected.mine_group_25km == 1)
                        & (projected.geometry.x < a_pt.x) & (projected.geometry.y <= a_pt.y + 5000)
                        & (projected.distance(a_pt) >= 55000)]
    b = west_sw.loc[[west_sw.distance(a_pt).idxmin()]]
    b_pt = b.geometry.iloc[0]

    # Window covering both sets of 50 km rings.
    reach = max(rings_km) * 1000 * 1.1
    xs, ys = [a_pt.x, b_pt.x], [a_pt.y, b_pt.y]
    window = (min(xs) - reach, max(xs) + reach, min(ys) - reach, max(ys) + reach)

    fig, ax = plt.subplots(figsize=(9, 8))
    munis.to_crs(ZOOM_CRS).plot(ax=ax, color="#f4f6f7", edgecolor="#c8c8c8", linewidth=0.3)

    # One color per town (dark green / purple - neither clashes with the mine
    # markers); each town's rings fade from darkest (10 km) to lightest (50 km).
    ring_colors = {"a": "#1e8449", "b": "#7d3c98"}
    ring_alpha = {10: 1.0, 25: 0.7, 50: 0.45}
    status = {1: "treated", 2: "control", 3: "always treated", 4: "no mines"}
    from matplotlib.colors import to_rgba
    # rings=False draws just the towns and mines (no rings) - the opening frame.
    for key, sede, pt, va, sign in ([("a", a, a_pt, "bottom", 1), ("b", b, b_pt, "top", -1)] if rings else []):
        for km in rings_km:
            color = to_rgba(ring_colors[key], ring_alpha[km])
            gpd.GeoSeries([pt.buffer(km * 1000)], crs=ZOOM_CRS).boundary.plot(
                ax=ax, color=color, linewidth=1.4, linestyle="--", zorder=3)
            # Label each ring with that town's status within that distance.
            # A's labels on top of its rings, B's at the bottom, so they don't collide.
            group = sede[f"mine_group_{km}km"].iloc[0]
            ax.annotate(f"{km} km: {status.get(group, '')}", (pt.x, pt.y + sign * km * 1000), fontsize=7.5,
                        ha="center", va=va, color=ring_colors[key], fontweight="bold", zorder=6,
                        bbox=dict(facecolor="white", edgecolor="none", alpha=0.7, pad=0.5))

    # Optional: fill the "treated" zone of one town - each donut (between the
    # previous ring and this one) where that town counts as treated within
    # this ring's distance. That's where the mine that treats it sits.
    # Each donut's look = that town's status within the donut's outer ring:
    # treated = light fill, always treated = darker fill, control = unfilled,
    # no mines = gray hatching.
    shade_patch = []
    if shade:
        sede, pt = (a, a_pt) if shade == "a" else (b, b_pt)
        name = sede.municipality_name.iloc[0]
        color = ring_colors[shade]
        styles = {
            1: dict(color=color, alpha=0.2),
            3: dict(color=color, alpha=0.5),
            4: dict(facecolor="none", edgecolor="#9a9a9a", hatch="///", linewidth=0),
        }
        labels = {1: "treated", 2: "control", 3: "always treated", 4: "no mines"}
        seen = []
        inner = 0
        for km in rings_km:
            group = sede[f"mine_group_{km}km"].iloc[0]
            if group in styles:
                donut = pt.buffer(km * 1000).difference(pt.buffer(inner * 1000)) if inner else pt.buffer(km * 1000)
                gpd.GeoSeries([donut], crs=ZOOM_CRS).plot(ax=ax, zorder=2, **styles[group])
            if group in labels and group not in seen:
                seen.append(group)
            inner = km
        for g in seen:
            if g == 2:
                shade_patch.append(Patch(facecolor="white", edgecolor=color, label=f"{name}: {labels[g]}"))
            elif g == 4:
                shade_patch.append(Patch(facecolor="none", edgecolor="#9a9a9a", hatch="///", label=f"{name}: {labels[g]}"))
            else:
                shade_patch.append(Patch(facecolor=color, alpha=styles[g]["alpha"] + 0.1, label=f"{name}: {labels[g]}"))

    mines = open_mines.to_crs(ZOOM_CRS)
    already_open = mines[mines.first_year <= PANEL_START]
    opened_in_window = mines[(mines.first_year > PANEL_START) & (mines.first_year <= LAST_YEAR)]
    never_opened.to_crs(ZOOM_CRS).plot(ax=ax, facecolor="none", edgecolor=GROUP_COLORS[2], markersize=14, linewidth=0.8, zorder=4)
    already_open.plot(ax=ax, color=GROUP_COLORS[3], markersize=12, zorder=5)
    opened_in_window.plot(ax=ax, color=GROUP_COLORS[1], markersize=12, zorder=6)

    for sede, key in [(a, "a"), (b, "b")]:
        sede.plot(ax=ax, color=ring_colors[key], marker="*", markersize=200, zorder=7)
        pt = sede.geometry.iloc[0]
        ax.annotate(sede.municipality_name.iloc[0], (pt.x, pt.y), xytext=(6, 6), textcoords="offset points",
                    fontsize=9, fontweight="bold", color=ring_colors[key], zorder=8)

    ax.set_xlim(window[0], window[1])
    ax.set_ylim(window[2], window[3])
    ax.set_axis_off()
    a_name, b_name = a.municipality_name.iloc[0], b.municipality_name.iloc[0]
    ax.set_title(f"Neighbors, different treatment: {a_name} vs. {b_name}", fontsize=13)
    ax.legend(handles=[
        *([Line2D([], [], color=ring_colors["a"], linestyle="--", label=f"Rings around {a_name}"),
           Line2D([], [], color=ring_colors["b"], linestyle="--", label=f"Rings around {b_name}")] if rings else []),
        Line2D([], [], marker="o", color=GROUP_COLORS[1], linestyle="", markersize=6, label=f"Mine opened {PANEL_START + 1}-{LAST_YEAR}"),
        Line2D([], [], marker="o", color=GROUP_COLORS[3], linestyle="", markersize=6, label=f"Mine already open by {PANEL_START}"),
        Line2D([], [], marker="o", markerfacecolor="none", markeredgecolor=GROUP_COLORS[2], linestyle="",
               markersize=6, label="Concession, never opened"),
    ] + shade_patch, loc="upper left", fontsize=8, framealpha=0.9)

    inset = ax.inset_axes([0.74, 0.74, 0.25, 0.25])
    inset.set_zorder(10)
    states.plot(ax=inset, color="#e5e7e9", edgecolor="#777777", linewidth=0.3)
    gpd.GeoSeries([box_polygon(window)], crs=ZOOM_CRS).to_crs(states.crs).boundary.plot(ax=inset, color="red", linewidth=1.2)
    inset.set_xticks([])
    inset.set_yticks([])
    inset.set_facecolor("white")

    suffix = {None: "", "a": "_shaded_" + a.municipality_name.iloc[0], "b": "_shaded_" + b.municipality_name.iloc[0]}[shade]
    if not rings:
        suffix = "_norings"
    # Plain ASCII file names (no accents), so LaTeX can include them.
    import unicodedata
    suffix = unicodedata.normalize("NFKD", suffix).encode("ascii", "ignore").decode().replace(" ", "_")
    save(fig, f"ring_zoom_pair{suffix}.png")
    print(f"  pair: {a_name} ({a.state.iloc[0]}) and {b_name} ({b.state.iloc[0]}), "
          f"{a_pt.distance(b_pt) / 1000:.0f} km apart")


def box_polygon(window):
    from shapely.geometry import box
    return box(window[0], window[2], window[1], window[3])


# 4 ---------------------------------------------------------------------------
def map_mines_by_mineral(states, open_mines):
    fig, ax = base_axes(states, "Mines of priced minerals, by mineral (size = total royalties)")
    minerals = open_mines.price_group.value_counts().index.tolist()
    palette = plt.get_cmap("tab10")
    # Square-root scaling so giant mines don't swamp everything.
    royalty = open_mines.royalty_total.clip(lower=0).fillna(0)
    sizes = 2 + 150 * np.sqrt(royalty / royalty.max())
    handles = []
    for i, mineral in enumerate(minerals):
        mask = open_mines.price_group == mineral
        open_mines[mask].plot(ax=ax, color=palette(i), markersize=sizes[mask], alpha=0.6, zorder=4)
        handles.append(Line2D([], [], marker="o", color=palette(i), linestyle="", markersize=6,
                              label=f"{mineral} ({mask.sum():,})"))
    ax.legend(handles=handles, loc="lower left", fontsize=9, frameon=False)
    save(fig, "mines_by_mineral.png")


# 5 ---------------------------------------------------------------------------
def map_timing(munis, states):
    fig, ax = base_axes(states, "Treated municipalities by first mine opening (25 km)")
    munis.plot(ax=ax, color=GROUP_COLORS[4], linewidth=0.05, edgecolor="white")
    treated = munis[munis.mine_group_25km == 1]
    treated.plot(ax=ax, column="first_opened_year_25km", cmap="viridis", linewidth=0.05, edgecolor="white",
                 legend=True, legend_kwds={"label": "Year first mine opened", "shrink": 0.5})
    save(fig, "opening_timing_25km.png")


# 6 ---------------------------------------------------------------------------
def map_groups_timing(munis, states, band, label="priced minerals", folder=None):
    # One map for the whole extensive-margin design: treated shaded by the
    # year their first mine opened, always treated in black, controls in white.
    fig, ax = plt.subplots(figsize=(9, 8))
    ax.set_title(f"Treatment timing and groups (within {band} km, {label})", fontsize=13)
    ax.set_axis_off()

    # Background: Brazil as one gray blob - no municipal outlines, just states.
    states.plot(ax=ax, color=GROUP_COLORS[4], linewidth=0)
    states.boundary.plot(ax=ax, color="#555555", linewidth=0.4, zorder=3)

    # Only municipalities in the design get an outline.
    outline = {"linewidth": 0.15, "edgecolor": "#6b6b6b"}

    group = munis[f"mine_group_{band}km"]
    control = munis[group == 2]
    if len(control):  # can be empty, e.g. all mine types at 100 km
        control.plot(ax=ax, color="white", **outline)

    always = munis[group == 3]
    if len(always):
        always.plot(ax=ax, color="black", **outline)

    # Hot colors, reversed so earlier openings (longer exposure) are darker
    # red. Trimmed at both ends: no near-white yellow (would look like the
    # white controls) and no near-black maroon (would look like always treated).
    from matplotlib.colors import ListedColormap
    cmap = ListedColormap(plt.get_cmap("YlOrRd")(np.linspace(0.85, 0.25, 256)))

    treated = munis[group == 1]
    treated.plot(ax=ax, column=f"first_opened_year_{band}km", cmap=cmap, vmin=PANEL_START + 1, vmax=LAST_YEAR,
                 legend=True, legend_kwds={"label": "Year first mine opened",
                                           "shrink": 0.55, "fraction": 0.03, "pad": 0.0},
                 **outline)
    # Treated count as a horizontal label under the color bar, so the
    # vertical label stays the same width across bands.
    cbar_ax = fig.axes[-1]
    cbar_ax.text(0.5, -0.07, f"Treated ({len(treated):,})", transform=cbar_ax.transAxes,
                 ha="center", va="top", fontsize=10)

    minx, miny, maxx, maxy = states.total_bounds
    ax.set_xlim(minx, maxx)
    ax.set_ylim(miny, maxy)

    ax.legend(handles=[
        Patch(facecolor="black", edgecolor="black", label=f"Always treated ({len(always):,})"),
        Patch(facecolor="white", edgecolor="#9a9a9a", label=f"Control ({len(control):,})"),
        Patch(facecolor=GROUP_COLORS[4], edgecolor="#9a9a9a", label="No mining potential"),
    ], loc="lower left", fontsize=9, frameon=False)
    save(fig, f"groups_timing_{band}km.png", folder or EXTENSIVE_DIR)


# 7 ---------------------------------------------------------------------------
def map_priced_vs_all(states):
    # Every mine that ever produced (paid royalties) in gray; mines of minerals
    # with a world price highlighted. Shows how few mines the price shock
    # covers by count, but how much of the value.
    loc = fix_keys(pd.read_stata(MINES / "mine_locations.dta")[KEYS + ["lat", "lon", "royalty_total"]].dropna(subset=["lat", "lon"]))
    produced = fix_keys(pd.read_stata(MINES / "mine_timeline.dta")[KEYS])
    groups = fix_keys(pd.read_stata(MINES / "mine_price_group.dta"))
    groups = groups[groups.price_group.fillna("") != ""]

    mines = loc.merge(produced, on=KEYS).merge(groups, on=KEYS, how="left")
    mines["priced"] = mines.price_group.fillna("") != ""
    mines = gpd.GeoDataFrame(mines, geometry=gpd.points_from_xy(mines.lon, mines.lat), crs="EPSG:4674")

    royalty = mines.royalty_total.clip(lower=0).fillna(0)
    share_count = mines.priced.mean()
    share_value = royalty[mines.priced].sum() / royalty.sum()

    fig, ax = plt.subplots(figsize=(9, 8))
    ax.set_axis_off()
    ax.set_title("Mines of priced minerals (size = total royalties)", fontsize=13)
    print(f"  priced minerals: {share_count:.0%} of mines, {share_value:.0%} of mining value")
    states.plot(ax=ax, color=GROUP_COLORS[4], linewidth=0)
    states.boundary.plot(ax=ax, color="#555555", linewidth=0.4, zorder=3)

    # Priced mines only, colored by mineral, circle area scaled by total
    # royalties (square root, so the giant iron mines don't swamp everything).
    priced = mines[mines.priced].copy()
    priced["royalty"] = priced.royalty_total.clip(lower=0).fillna(0)
    max_royalty = priced.royalty.max()

    def size(r):
        return 4 + 600 * np.sqrt(r / max_royalty)

    priced = priced.sort_values("royalty", ascending=False)  # big first, small drawn on top
    palette = plt.get_cmap("tab10")
    colors = {m: palette(i) for i, m in enumerate(priced.price_group.value_counts().index)}
    priced.plot(ax=ax, color=priced.price_group.map(colors), markersize=size(priced.royalty),
                alpha=0.7, edgecolor="white", linewidth=0.3, zorder=5)

    mineral_handles = [Line2D([], [], marker="o", color=c, linestyle="", markersize=6,
                              label=f"{m.capitalize()} ({(priced.price_group == m).sum():,})")
                       for m, c in colors.items()]
    # Size key: three reference royalty totals (R$ billions).
    size_handles = [plt.scatter([], [], s=size(v * 1e9), color="#999999", alpha=0.7, label=f"R\\$ {v:g}bn")
                    for v in [0.1, 1, 10]]

    minx, miny, maxx, maxy = states.total_bounds
    ax.set_xlim(minx, maxx)
    ax.set_ylim(miny, maxy)
    leg = ax.legend(handles=mineral_handles, loc="lower left", fontsize=8, frameon=False, title="Mineral")
    ax.add_artist(leg)
    ax.legend(handles=size_handles, loc="lower right", fontsize=8, frameon=False,
              title="Total royalties", labelspacing=1.5, borderpad=1)
    save(fig, "priced_vs_all_mines.png", OUT / "Intensive Margin")


def munis_all_version(munis):
    # Same municipalities, but treatment groups from the "all mines" file
    # (every mine type, including sand, clay, stone, ...).
    keep = [c for c in munis.columns if not c.startswith(("mine_group_", "first_opened_year_"))]
    cols = (["municipality", "year"] + [f"mine_group_{b}km" for b in CUMULATIVE_BANDS_KM]
            + [f"first_opened_year_{b}km" for b in CUMULATIVE_BANDS_KM])
    mining = pd.read_stata(MINES / "municipality_year_mining_all.dta", convert_categoricals=False, columns=cols)
    mining = mining[mining.year == 2015].drop(columns="year")
    return munis[keep].merge(mining, on="municipality", how="left")


# 8 ---------------------------------------------------------------------------
def chart_prices():
    # World prices of the minerals on the intensive-margin map, 2007 = 100.
    # Same order (most mines first) and so the same colors as that map.
    minerals = ["gold", "iron", "aluminum", "tin", "copper", "nickel", "silver", "zinc", "lead"]
    prices = pd.read_stata(ROOT / "Working" / "WB Prices" / "wb_commodity_prices_monthly.dta")
    cols = [f"{m}_price" for m in minerals]
    for c in cols:
        prices[c] = pd.to_numeric(prices[c], errors="coerce")
    annual = prices[prices.year.between(PANEL_START, LAST_YEAR)].groupby("year")[cols].mean()
    index = 100 * annual / annual.loc[PANEL_START]

    palette = plt.get_cmap("tab10")
    fig, ax = plt.subplots(figsize=(9, 6))
    for i, m in enumerate(minerals):
        ax.plot(index.index, index[f"{m}_price"], color=palette(i), linewidth=2, label=m.capitalize())
    ax.axhline(100, color="#999999", linewidth=0.8, linestyle="--")
    ax.set_yscale("log")
    from matplotlib.ticker import NullFormatter
    ax.set_yticks([25, 50, 100, 200, 400])
    ax.set_yticklabels(["25", "50", "100", "200", "400"])
    ax.yaxis.set_minor_formatter(NullFormatter())
    ax.set_xticks(range(PANEL_START + 1, LAST_YEAR + 1, 3))
    ax.set_title(f"World prices of priced minerals ({PANEL_START} = 100)", fontsize=13)
    ax.set_ylabel(f"Price index, {PANEL_START} = 100 (log scale)")
    ax.spines[["top", "right"]].set_visible(False)

    # Label each line at its end instead of a legend. Lines that end close
    # together get their labels nudged apart (spacing measured on the log scale).
    ends = sorted(((np.log10(index[f"{m}_price"].iloc[-1]), m, i) for i, m in enumerate(minerals)))
    min_gap = 0.045
    placed = []
    for y, m, i in ends:
        if placed and y - placed[-1][0] < min_gap:
            y = placed[-1][0] + min_gap
        placed.append((y, m, i))
    for y, m, i in placed:
        ax.text(LAST_YEAR + 0.3, 10 ** y, m.capitalize(), color=palette(i), fontsize=10,
                va="center", fontweight="bold")
    ax.set_xlim(PANEL_START - 0.3, LAST_YEAR + 2.2)
    save(fig, "mineral_prices.png", OUT / "Intensive Margin")


MAPS_BY_NAME = {
    "ring_zoom_pair_shaded": lambda d: [map_ring_zoom_pair(d["munis"], d["states"], d["seats"], d["open_mines"], d["never_opened"], s)
                                        for s in ["a", "b"]],
    "ring_zoom_pair_norings": lambda d: map_ring_zoom_pair(d["munis"], d["states"], d["seats"], d["open_mines"], d["never_opened"], rings=False),
    "ring_zoom_pair": lambda d: map_ring_zoom_pair(d["munis"], d["states"], d["seats"], d["open_mines"], d["never_opened"]),
    "prices": lambda d: chart_prices(),
    "groups_timing_all": lambda d: [map_groups_timing(munis_all_version(d["munis"]), d["states"], b,
                                                      "all mine types", EXTENSIVE_DIR / "All Mines")
                                    for b in CUMULATIVE_BANDS_KM],
    "priced_vs_all": lambda d: map_priced_vs_all(d["states"]),
    "groups": lambda d: map_groups(d["munis"], d["states"]),
    "group_dots": lambda d: map_group_dots(d["seats"], d["states"]),
    "ring_zoom": lambda d: map_ring_zoom(d["munis"], d["states"], d["seats"], d["open_mines"], d["never_opened"]),
    "mines_by_mineral": lambda d: map_mines_by_mineral(d["states"], d["open_mines"]),
    "timing": lambda d: map_timing(d["munis"], d["states"]),
    "groups_timing": lambda d: [map_groups_timing(d["munis"], d["states"], b) for b in CUMULATIVE_BANDS_KM],
}


def main():
    # Run everything, or only the maps named on the command line, e.g.
    #   python make_maps.py groups_timing
    wanted = sys.argv[1:] or list(MAPS_BY_NAME)
    unknown = [w for w in wanted if w not in MAPS_BY_NAME]
    if unknown:
        raise SystemExit(f"Unknown map name(s): {unknown}. Options: {list(MAPS_BY_NAME)}")

    OUT.mkdir(parents=True, exist_ok=True)
    print("Loading data...")
    munis, states, seats, open_mines, never_opened = load_data()
    print(f"  {len(open_mines):,} priced mines that opened, {len(never_opened):,} priced sites that never opened")
    data = {"munis": munis, "states": states, "seats": seats,
            "open_mines": open_mines, "never_opened": never_opened}

    print("Drawing maps...")
    for name in wanted:
        MAPS_BY_NAME[name](data)
    print(f"\nAll done - maps in {OUT}")


if __name__ == "__main__":
    main()
