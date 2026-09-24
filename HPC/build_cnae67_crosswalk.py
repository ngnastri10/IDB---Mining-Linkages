"""
Build the CNAE 2.0 -> CNAE67 (IBGE's 67-sector national-accounts
activity classification) crosswalk used by clean_rais_scrap_hpc.do's
cnae67 collapse.

Downloads IBGE's own official crosswalk straight from their FTP server
(confirmed real, not guessed - browse it yourself at
ftp://ftp.ibge.gov.br/Contas_Nacionais/Sistema_de_Contas_Nacionais/Tradutores/)
and cleans it into a plain two-column Stata file: cnae2, cnae67.

IBGE splits Education and Health into public/private versions (e.g. CNAE
8610 "hospital care" maps to BOTH "Saude publica" and "Saude privada" -
CNAE alone can't tell which, that needs RAIS's own legal_nature variable
to resolve, which isn't available at crosswalk-build time). So ~26 CNAE
codes appear twice in IBGE's raw file. This just keeps the first
occurrence for those - doesn't affect mining or its linkages at all,
only education/health get a default bucket assigned.

Called from clean_rais_scrap_hpc.do only if the output file doesn't
already exist yet - safe to rerun any time regardless.

Needs xlrd to read IBGE's old-style .xls file (pandas uses it
internally, doesn't come bundled with pandas itself) - installed
automatically below if it's missing, so this doesn't depend on whoever's
running it (you, a co-author, a fresh HPC account) having set it up by
hand first.

Usage: python3 build_cnae67_crosswalk.py <output_path.dta>
"""

import io
import sys
import ftplib
import subprocess
from pathlib import Path

try:
    import xlrd  # noqa: F401 - only imported to check it's installed; pandas uses it internally for .xls files below
except ImportError:
    print("xlrd not installed (needed to read IBGE's .xls file) - installing it now...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "xlrd"])

import pandas as pd

OUT_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("cnae2_to_cnae67.dta")

FTP_HOST = "ftp.ibge.gov.br"
FTP_DIR = "/Contas_Nacionais/Sistema_de_Contas_Nacionais/Tradutores"
FTP_FILE = "Tradutor_Atividade_CNAE.xls"


def main():
    print(f"Downloading {FTP_FILE} from IBGE's FTP...")
    buf = io.BytesIO()
    ftp = ftplib.FTP(FTP_HOST, timeout=60)
    ftp.login()
    ftp.cwd(FTP_DIR)
    ftp.retrbinary(f"RETR {FTP_FILE}", buf.write)
    ftp.quit()
    buf.seek(0)

    df = pd.read_excel(buf, sheet_name="Plan2", header=None, skiprows=4)
    df.columns = ["cnae67_code", "cnae67_desc", "cnae2", "cnae2_desc"]
    df = df.dropna(subset=["cnae2"])

    # cnae67_code only appears on the first row of each group in IBGE's
    # raw file (merged-cell Excel export) - forward-fill to every row.
    df["cnae67_code"] = df["cnae67_code"].ffill()

    df["cnae2"] = df["cnae2"].astype(int)
    df["cnae67"] = df["cnae67_code"].astype(int)

    # Education/health public-private duplicates (see module docstring) -
    # keep first occurrence, doesn't affect mining.
    before = len(df)
    df = df.drop_duplicates(subset="cnae2", keep="first")
    print(f"Dropped {before - len(df)} duplicate cnae2 rows (education/health public-private split).")

    out = df[["cnae2", "cnae67"]].reset_index(drop=True)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.to_stata(OUT_PATH, write_index=False)
    print(f"Saved {len(out)} cnae2 -> cnae67 mappings to {OUT_PATH}")


if __name__ == "__main__":
    main()
