"""
Clean IBGE's 2022 boundary maps into light files that are fast to plot.

  - Municipalities: keep the code and name, add the 6-digit municipality
    code (drop the check digit) so it matches RAIS and the rest of the
    project, and simplify the shapes (the raw file is very detailed -
    fine for GIS work, slow and unnecessary for national maps).
  - States: same simplification, keep the two-letter state code.

Input:
  LARGE_DATA_ROOT/Maps/BR_Municipios_2022/, .../BR_UF_2022/ (from pull_map_boundaries.py)

Output:
  Working/Maps/municipalities.gpkg
  Working/Maps/states.gpkg

GeoPackage (.gpkg) is a standard single-file map format - opens in ArcGIS
or QGIS too.

Same config.py setup as the other scripts - run config.do in Stata first.
"""

import sys
from pathlib import Path

import geopandas as gpd

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

try:
    import config
except ImportError:
    raise SystemExit(
        "Couldn't find config.py in the Code folder.\n"
        "Run config.do in Stata first (once per session) - see the README."
    )

RAW_DIR = Path(config.LARGE_DATA_ROOT) / "Maps"
WORKING_DIR = Path(config.PROJECT_ROOT) / "Working" / "Maps"

# In degrees - roughly 500 m. Invisible on a national map, much faster.
SIMPLIFY_TOLERANCE = 0.005


def main():
    WORKING_DIR.mkdir(parents=True, exist_ok=True)

    munis = gpd.read_file(next((RAW_DIR / "BR_Municipios_2022").glob("*.shp")))
    munis = munis[["CD_MUN", "NM_MUN", "SIGLA_UF", "geometry"]].rename(columns={
        "CD_MUN": "municipality_code7",
        "NM_MUN": "municipality_name",
        "SIGLA_UF": "state",
    })
    munis["municipality_code7"] = munis["municipality_code7"].astype(int)
    # 7-digit IBGE code -> 6-digit (drop the check digit), to match RAIS.
    munis["municipality"] = munis["municipality_code7"] // 10
    munis["geometry"] = munis.geometry.simplify(SIMPLIFY_TOLERANCE, preserve_topology=True)
    munis.to_file(WORKING_DIR / "municipalities.gpkg", driver="GPKG")
    print(f"Municipalities: {len(munis):,} -> {WORKING_DIR / 'municipalities.gpkg'}")

    states = gpd.read_file(next((RAW_DIR / "BR_UF_2022").glob("*.shp")))
    states = states[["SIGLA_UF", "geometry"]].rename(columns={"SIGLA_UF": "state"})
    states["geometry"] = states.geometry.simplify(SIMPLIFY_TOLERANCE, preserve_topology=True)
    states.to_file(WORKING_DIR / "states.gpkg", driver="GPKG")
    print(f"States: {len(states):,} -> {WORKING_DIR / 'states.gpkg'}")


if __name__ == "__main__":
    main()
