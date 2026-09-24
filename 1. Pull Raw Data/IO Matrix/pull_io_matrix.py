"""
Pull two things from IBGE's 2015 National Accounts, both needed to build
the mining upstream/downstream classification:

1. The Input-Output Matrix (Matriz de Insumo-Produto), 67-sector
   activity-level version - the direct/Leontief requirement coefficients
   (Tabelas 14/15).
2. Tabela 10.2 ("Valor adicionado bruto... segundo as atividades") -
   Value Added by activity, same 67-activity codes. Needed alongside the
   Input-Output Matrix's own Tabela 02 (intermediate consumption per
   activity, already embedded in file 1 as a totals row) to reconstruct
   each activity's total OUTPUT (Output = Intermediate Consumption +
   Value Added) - the piece IBGE doesn't publish directly as its own
   table, needed for Ghosh-style allocation coefficients and real
   monetary-level flows, not just the direct requirement shares.

2015 is IBGE's most recent published Input-Output Matrix (confirmed
directly against their FTP listing - vintages go 1985, 1990-1996, 2000,
2005, 2010, 2015, nothing newer). The 67-sector level is the one that
matches our own cnae67 classification exactly (same "Atividade" system
used to build cnae2_to_cnae67.dta) - IBGE also publishes coarser 12- and
20-sector versions of the same table, not pulled here since they're not
useful for us.

Source (browse it yourself here first if you want - it's IBGE's official
FTP, not a document we're guessing the location of):
ftp://ftp.ibge.gov.br/Contas_Nacionais/Matriz_de_Insumo_Produto/2015/
ftp://ftp.ibge.gov.br/Contas_Nacionais/Sistema_de_Contas_Nacionais/2015/tabelas_xls/sinoticas/

Both are small, published Excel workbooks (well under 1MB each) -
nothing like RAIS, doesn't need the HPC. Plain downloads, no unzipping.

Same config.py setup as the other pull scripts - see pull_sigmine.py if
this errors out on missing config.py.
"""

import sys
import ftplib
from pathlib import Path

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

DATA_DIR = Path(config.PROJECT_ROOT) / "Data" / "IO Matrix"

FTP_HOST = "ftp.ibge.gov.br"

FILES_TO_PULL = [
    ("/Contas_Nacionais/Matriz_de_Insumo_Produto/2015", "Matriz_de_Insumo_Produto_2015_Nivel_67.xls"),
    ("/Contas_Nacionais/Sistema_de_Contas_Nacionais/2015/tabelas_xls/sinoticas", "tab10_2.xls"),
]


def main():
    print(f"Project root (from config.py): {config.PROJECT_ROOT}")
    print(f"Data will be saved under: {DATA_DIR}\n")

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    ftp = ftplib.FTP(FTP_HOST, timeout=60)
    ftp.login()

    for ftp_dir, filename in FILES_TO_PULL:
        dest_path = DATA_DIR / filename
        print(f"Downloading {filename} from IBGE's FTP...")
        ftp.cwd(ftp_dir)
        with open(dest_path, "wb") as f:
            ftp.retrbinary(f"RETR {filename}", f.write)
        print(f"  Done - saved to {dest_path}")

    ftp.quit()
    print("\nAll done.")


if __name__ == "__main__":
    main()
