"""
Download the crosswalks the project needs into Data/Crosswalks/, same as
every other raw data source.

Two crosswalks, both straight from IBGE (nothing typed by hand):

1. municipality_latlon.csv - one point per municipality, at its seat (the
   town itself, "Sede Municipal"), not the geographic centroid. In huge
   Amazon municipalities the centroid can sit in empty forest, while the
   seat is where people and jobs actually are.
   Source: IBGE's Localidades do Brasil 2022 (GeoPackage). Every locality
   in Brazil with its coordinates; we keep only municipal seats.
   https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/localidades/Localidades_do_Brasil/2022/
   State and federal capitals show up twice (once as "Sede Municipal",
   once as "Capital Estadual"/"Capital Federal", same town) - one row is
   kept per municipality. Result: 5,570 municipalities. Fernando de Noronha
   has no seat point in the file and is left out. Has both the 7-digit
   IBGE code and the 6-digit code RAIS uses.

2. cnae2_to_cnae67.csv - CNAE 2.0 class -> CNAE67 (IBGE's 67-sector
   national-accounts activity list, the one the IO matrix uses).
   Source: IBGE's own translator file,
   ftp://ftp.ibge.gov.br/Contas_Nacionais/Sistema_de_Contas_Nacionais/Tradutores/Tradutor_Atividade_CNAE.xls
   IBGE splits Education and Health into public/private versions, so ~26
   CNAE codes show up twice (CNAE alone can't tell public from private).
   We keep the first one. Doesn't touch mining or its linkages.
   Note: the HPC RAIS cleaning still builds its own copy of this file with
   HPC/build_cnae67_crosswalk.py (same source, same logic).

Same config.py setup as the other pull scripts - run 0. Configure File Paths/config.do in Stata
first.

Needs pandas, plus xlrd to read IBGE's old-style .xls file:
    pip install pandas xlrd

Usage: python pull_crosswalks.py
"""

import ftplib
import io
import sqlite3
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

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

if not Path(config.PROJECT_ROOT).is_dir():
    raise SystemExit(
        f"PROJECT_ROOT in config.py doesn't point to a real folder:\n"
        f"  {config.PROJECT_ROOT}\n"
        f"Run 0. Configure File Paths/config.do again with the right paths."
    )

OUT_DIR = Path(config.PROJECT_ROOT) / "Data" / "Crosswalks"

LOCALIDADES_URL = (
    "https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/"
    "localidades/Localidades_do_Brasil/2022/Localidades_Brasil_gpkg.zip"
)

CNAE_FTP_HOST = "ftp.ibge.gov.br"
CNAE_FTP_DIR = "/Contas_Nacionais/Sistema_de_Contas_Nacionais/Tradutores"
CNAE_FTP_FILE = "Tradutor_Atividade_CNAE.xls"


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


def pull_municipality_latlon():
    # The zip is only needed for a minute, so it goes in a temp folder that
    # cleans itself up.
    with tempfile.TemporaryDirectory() as tmp:
        zip_path = Path(tmp) / "Localidades_Brasil_gpkg.zip"
        print("Downloading IBGE localities (~6MB)...")
        download_file(LOCALIDADES_URL, zip_path)

        with zipfile.ZipFile(zip_path) as z:
            gpkg_name = [m for m in z.namelist() if m.endswith(".gpkg")][0]
            z.extract(gpkg_name, tmp)

        # A GeoPackage is just a SQLite file, so plain sqlite3 can read it -
        # no GIS packages needed.
        con = sqlite3.connect(Path(tmp) / gpkg_name)
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

    out_path = OUT_DIR / "municipality_latlon.csv"
    seats.to_csv(out_path, index=False)
    print(f"  Saved {len(seats):,} municipalities -> {out_path}")


def pull_cnae67():
    print(f"Downloading {CNAE_FTP_FILE} from IBGE's FTP...")
    buf = io.BytesIO()
    ftp = ftplib.FTP(CNAE_FTP_HOST, timeout=60)
    ftp.login()
    ftp.cwd(CNAE_FTP_DIR)
    ftp.retrbinary(f"RETR {CNAE_FTP_FILE}", buf.write)
    ftp.quit()
    buf.seek(0)

    try:
        df = pd.read_excel(buf, sheet_name="Plan2", header=None, skiprows=4)
    except ImportError:
        raise SystemExit("Reading IBGE's .xls file needs xlrd - run: pip install xlrd")

    df.columns = ["cnae67_code", "cnae67_desc", "cnae2", "cnae2_desc"]
    df = df.dropna(subset=["cnae2"])

    # The CNAE67 code is only written on the first row of each group (merged
    # cells in IBGE's Excel file) - copy it down to every row.
    df["cnae67_code"] = df["cnae67_code"].ffill()

    df["cnae2"] = df["cnae2"].astype(int)
    df["cnae67"] = df["cnae67_code"].astype(int)

    # Education/health public-private duplicates - keep the first one.
    before = len(df)
    df = df.drop_duplicates(subset="cnae2", keep="first")
    print(f"  Dropped {before - len(df)} duplicate cnae2 rows (education/health public-private split)")

    out = df[["cnae2", "cnae67"]].reset_index(drop=True)
    out_path = OUT_DIR / "cnae2_to_cnae67.csv"
    out.to_csv(out_path, index=False)
    print(f"  Saved {len(out):,} cnae2 -> cnae67 rows -> {out_path}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    pull_municipality_latlon()
    pull_cnae67()
    print("All done.")


if __name__ == "__main__":
    main()
