"""
Build a municipality -> lat/long crosswalk: one point per municipality, at
its seat (the town itself, "Sede Municipal"), not the geographic centroid.
In huge Amazon municipalities the centroid can sit in empty forest, while
the seat is where people and jobs actually are.

Source: IBGE's Localidades do Brasil 2022 (GeoPackage). Every locality in
Brazil with its coordinates; we keep only municipal seats.
https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/localidades/Localidades_do_Brasil/2022/

State and federal capitals show up twice (once as "Sede Municipal", once as
"Capital Estadual"/"Capital Federal", same town) - one row is kept per
municipality. Result: 5,570 municipalities. Fernando de Noronha has no seat
point in the file and is left out.

Output: Data/Crosswalks/municipality_latlon.csv, with both the 7-digit IBGE
code and the 6-digit code RAIS uses.

The GeoPackage is just a SQLite file, so it's read with Python's built-in
sqlite3 - no GIS packages needed. It's deleted once the CSV is written.

Same config.py setup as the other pull scripts - see pull_sigmine.py if
this errors out on missing config.py.
"""

import sqlite3
import sys
import urllib.request
import zipfile
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

try:
    import config
except ImportError:
    raise SystemExit(
        "Couldn't find config.py in the Code folder.\n"
        "Run config.do in Stata first (once per session) - see the README."
    )

if not Path(config.PROJECT_ROOT).is_dir():
    raise SystemExit(
        f"PROJECT_ROOT in config.py doesn't point to a real folder:\n"
        f"  {config.PROJECT_ROOT}\n"
        f"Run config.do again with the right paths."
    )

DATA_DIR = Path(config.PROJECT_ROOT) / "Data" / "Crosswalks"

ZIP_URL = (
    "https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/"
    "localidades/Localidades_do_Brasil/2022/Localidades_Brasil_gpkg.zip"
)


def download_file(url, destination_path):
    """Download a file from a URL and save it to disk, in 1 MB chunks."""
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=300) as response:
        with open(destination_path, "wb") as out_file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                out_file.write(chunk)


def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    zip_path = DATA_DIR / "Localidades_Brasil_gpkg.zip"
    print(f"Downloading IBGE localities (~6MB) -> {zip_path}")
    download_file(ZIP_URL, zip_path)

    with zipfile.ZipFile(zip_path) as z:
        gpkg_name = [m for m in z.namelist() if m.endswith(".gpkg")][0]
        z.extract(gpkg_name, DATA_DIR)
    gpkg_path = DATA_DIR / gpkg_name

    con = sqlite3.connect(gpkg_path)
    seats = pd.read_sql(
        """
        select CD_MUN, NM_MUN, SIGLA_UF, LAT_LOCALIDADE, LONG_LOCALIDADE, SCT_LOCALIDADE
        from BR_localidades_2022
        where SCT_LOCALIDADE in ('Sede Municipal', 'Capital Estadual', 'Capital Federal')
        """,
        con,
    )
    con.close()

    # Capitals appear twice (seat + capital, same town) - keep one per municipality.
    seats = seats.sort_values("SCT_LOCALIDADE", key=lambda s: s != "Sede Municipal")
    seats = seats.drop_duplicates("CD_MUN")

    seats = seats.rename(columns={
        "CD_MUN": "municipality_code7",
        "NM_MUN": "municipality_name",
        "SIGLA_UF": "state",
        "LAT_LOCALIDADE": "seat_lat",
        "LONG_LOCALIDADE": "seat_lon",
    })
    seats["municipality_code7"] = seats["municipality_code7"].astype(int)
    # 7-digit IBGE code -> 6-digit (drop the check digit), to match RAIS.
    seats["municipality"] = seats["municipality_code7"] // 10
    seats = seats[["municipality", "municipality_code7", "municipality_name", "state", "seat_lat", "seat_lon"]]
    seats = seats.sort_values("municipality")

    out_path = DATA_DIR / "municipality_latlon.csv"
    seats.to_csv(out_path, index=False)

    gpkg_path.unlink()
    zip_path.unlink()

    print(f"Saved {len(seats)} municipalities -> {out_path}")
    print("All done.")


if __name__ == "__main__":
    main()
