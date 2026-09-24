"""
Pull ANM's Cadastro Mineiro (SCM) microdata - the full registry of mining
rights ("processos"). Only the tables we actually use get kept:

  - Processo            one row per mining right (phase, filing date, area, active)
  - ProcessoAssociacao  links between rights - type 4 = "Grupamento Mineiro",
                        the mining groups big mines (Vale's) pay royalties under
  - ProcessoMunicipio   mining right -> municipality
  - ProcessoEvento      dated event history for every right (big - ~1GB,
                        gets filtered down and deleted in the cleaning step)
  - ProcessoSubstancia  mining right -> substance(s)
  - plus the small lookup tables that turn their ID numbers into names

The rest of the zip (documents, people/holders, etc.) never gets unzipped.

Saved under LARGE_DATA_ROOT, not PROJECT_ROOT, since it's ~1.2GB unzipped
and PROJECT_ROOT sits on OneDrive.

Source (browse it yourself here first if you want):
https://dadosabertos.anm.gov.br/SCM/microdados/

Same config.py setup as the other pull scripts - see pull_sigmine.py if
this errors out on missing config.py.
"""

import sys
import urllib.request
import zipfile
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

if not Path(config.LARGE_DATA_ROOT).is_dir():
    raise SystemExit(
        f"LARGE_DATA_ROOT in config.py doesn't point to a real folder:\n"
        f"  {config.LARGE_DATA_ROOT}\n"
        f"Run config.do again with the right paths."
    )

DATA_DIR = Path(config.LARGE_DATA_ROOT) / "SCM" / "microdados"

ZIP_URL = "https://dadosabertos.anm.gov.br/SCM/microdados/microdados-scm.zip"

FILES_TO_KEEP = [
    # Main tables
    "Processo.txt",
    "ProcessoAssociacao.txt",
    "ProcessoMunicipio.txt",
    "ProcessoEvento.txt",
    "ProcessoSubstancia.txt",
    # Lookup tables (ID -> name)
    "TipoAssociacao.txt",
    "Evento.txt",
    "FaseProcesso.txt",
    "TipoRequerimento.txt",
    "Municipio.txt",
    "Substancia.txt",
]


def download_file(url, destination_path):
    """Download a file from a URL and save it to disk.

    Streamed in 1 MB chunks rather than pulling the whole thing into
    memory at once.
    """
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=300) as response:
        with open(destination_path, "wb") as out_file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                out_file.write(chunk)


def main():
    print(f"Data will be saved under: {DATA_DIR}\n")
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    zip_path = DATA_DIR / "microdados-scm.zip"
    print(f"Downloading the microdata zip (~200MB) -> {zip_path}")
    download_file(ZIP_URL, zip_path)

    # Files sit inside a subfolder in the zip - match on the file name alone
    # and write them flat into DATA_DIR.
    with zipfile.ZipFile(zip_path) as z:
        for member in z.namelist():
            name = Path(member).name
            if name in FILES_TO_KEEP:
                with z.open(member) as src, open(DATA_DIR / name, "wb") as dst:
                    while True:
                        chunk = src.read(1024 * 1024)
                        if not chunk:
                            break
                        dst.write(chunk)

    zip_path.unlink()

    missing = [f for f in FILES_TO_KEEP if not (DATA_DIR / f).exists()]
    if missing:
        raise SystemExit(f"These weren't in the zip - ANM may have renamed them: {missing}")

    print("\nKept:")
    for f in FILES_TO_KEEP:
        size_mb = (DATA_DIR / f).stat().st_size / 1e6
        print(f"  {f:28s} {size_mb:10.1f} MB")

    print("\nAll done.")


if __name__ == "__main__":
    main()
