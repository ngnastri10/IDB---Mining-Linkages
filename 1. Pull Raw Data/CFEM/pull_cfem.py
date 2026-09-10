"""
Pull CFEM royalty data from ANM's open data portal.

CFEM (Compensacao Financeira pela Exploracao de Recursos Minerais) is the
mining royalty Brazil charges on commercial mineral extraction. This pulls
the "Arrecadacao" (collection) file - the actual royalty payments, one row
per process per month, going back to 2002. Unlike SIGMINE, this is a plain
CSV, not a shapefile, so there's no unzipping step here.

Source (browse it yourself here first if you want):
https://dadosabertos.anm.gov.br/CFEM/

Same config.py setup as pull_sigmine.py - see that file if this errors out
on missing config.py.
"""

import sys
import urllib.request
from pathlib import Path

# config.py lives at the top of the repo: Code/1. Pull Raw Data/CFEM/
# -> up two levels -> Code/. Same trick as pull_sigmine.py.
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

DATA_DIR = Path(config.PROJECT_ROOT) / "Data" / "CFEM"

# CFEM_Arrecadacao.csv is the full file, every year from 2002 on, already
# combined - ANM also publishes the same data pre-split into 5-year
# chunks, but their sizes add up to exactly the full file's size, so
# there's no reason to pull both. If we later want ANM's other CFEM files
# (Distribuicao, Autuacao), add them here the same way we did
# Active/Inactive for SIGMINE.
BASE_URL = "https://dadosabertos.anm.gov.br/CFEM/"
FILES_TO_PULL = [
    ("Arrecadacao", "CFEM_Arrecadacao.csv"),
]


def download_file(url, destination_path):
    """Download a file from a URL and save it to disk.

    We stream it in 1 MB chunks rather than pulling the whole thing into
    memory at once - this file runs 300+ MB.
    """
    # ANM's server sometimes refuses requests that don't look like they're
    # coming from a normal web browser, so we fake a User-Agent header.
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=300) as response:
        with open(destination_path, "wb") as out_file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                out_file.write(chunk)


def main():
    print(f"Project root (from config.py): {config.PROJECT_ROOT}")
    print(f"Data will be saved under: {DATA_DIR}\n")

    for subfolder_name, filename in FILES_TO_PULL:
        folder = DATA_DIR / subfolder_name
        folder.mkdir(parents=True, exist_ok=True)

        file_path = folder / filename
        url = BASE_URL + filename

        print(f"Downloading {filename} -> {file_path}")
        try:
            download_file(url, file_path)
        except Exception as e:
            print(f"  Could not download {filename}: {e}")
            print(f"  You can also just grab it by hand from {url}")
            print(f"  and drop it in {folder}\n")
            continue

        print(f"Done with {filename}.\n")

    print("All done.")


if __name__ == "__main__":
    main()
