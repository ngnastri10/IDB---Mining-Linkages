"""
Pull SIGMINE mining-process data from ANM's open data portal.

SIGMINE is the Brazilian mining regulator's (ANM) geolocated database of
mining processes (shapefile of every mining claim/concession
in the country). ANM publishes it as a couple of zip files that get updated
daily. This script grabs those zip files and unzips them into the
Data folder.

Source (browse it yourself here first if you want):
https://dadosabertos.anm.gov.br/SIGMINE/PROCESSOS_MINERARIOS/

--------------------------------------------------------------------------
A note on file paths: If you haven't set up config.py yet, see config_template.py for the (one
line) setup step.
--------------------------------------------------------------------------
"""

import sys
import urllib.request
import zipfile
from pathlib import Path

# config.py lives at the top of the repo: Code/1. Pull Raw Data/SIGMINE/
# -> up two levels -> Code/. We add that folder to Python's search path so
# "import config" below can find it no matter where this repo was cloned.
REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

try:
    import config
except ImportError:
    raise SystemExit(
        "Couldn't find config.py in the Code folder.\n"
        "Copy config_template.py to config.py and fill in your own "
        "PROJECT_ROOT path - instructions are inside that file."
    )

if not Path(config.PROJECT_ROOT).is_dir():
    raise SystemExit(
        f"PROJECT_ROOT in config.py doesn't point to a real folder:\n"
        f"  {config.PROJECT_ROOT}\n"
        f"Double check the path you put in config.py."
    )

DATA_DIR = Path(config.PROJECT_ROOT) / "Data" / "SIGMINE"

# The two files we want from ANM. Each one is a different "aspect" of
# SIGMINE - active mining processes vs. ones that have been closed out for
# some reason - so we give each its own subfolder under Data/SIGMINE. If we
# ever want more SIGMINE layers later (there are a few smaller ones on
# ANM's site - leasing areas, blocked areas, etc.), we'd just add another
# line to this list.
BASE_URL = "https://dadosabertos.anm.gov.br/SIGMINE/PROCESSOS_MINERARIOS/"
FILES_TO_PULL = [
    ("Active", "BRASIL.zip"),
    ("Inactive", "PROCESSOS_INATIVOS.zip"),
]


def download_file(url, destination_path):
    """Download a file from a URL and save it to disk.

    We stream it in 1 MB chunks rather than pulling the whole thing into
    memory at once, since these files run 100+ MB each.
    """
    # ANM's server sometimes refuses requests that don't look like they're
    # coming from a normal web browser, so we fake a User-Agent header.
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
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
        # exist_ok=True means this won't complain or break if the folder
        # (or Data/SIGMINE itself) already exists - it just uses it.
        folder.mkdir(parents=True, exist_ok=True)

        zip_path = folder / filename
        url = BASE_URL + filename

        print(f"Downloading {filename} -> {zip_path}")
        try:
            download_file(url, zip_path)
        except Exception as e:
            print(f"  Could not download {filename}: {e}")
            print(f"  You can also just grab it by hand from {url}")
            print(f"  and drop it in {folder}\n")
            continue

        print(f"Unzipping {filename} ...")
        with zipfile.ZipFile(zip_path, "r") as zip_file:
            zip_file.extractall(folder)

        print(f"Done with {filename}.\n")

    print("All done.")


if __name__ == "__main__":
    main()
