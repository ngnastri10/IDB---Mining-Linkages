"""
Pull two SCM files from ANM's open data portal: Guia de Utilizacao
Autorizada (authorized extraction volumes, with a real date) and Cessoes
de Direitos (rights-transfer history). Plain CSVs, no unzipping needed,
same pattern as pull_sigmine.py and pull_cfem.py.

Source (browse it yourself here first if you want):
https://dadosabertos.anm.gov.br/SCM/

Same config.py setup as the other pull scripts - see pull_sigmine.py if
this errors out on missing config.py.
"""

import sys
import urllib.request
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

DATA_DIR = Path(config.PROJECT_ROOT) / "Data" / "SCM"

BASE_URL = "https://dadosabertos.anm.gov.br/SCM/"
FILES_TO_PULL = [
    ("Guia", "Guia_de_Utilizacao_Autorizada.csv"),
    ("Cessoes", "Cessoes_de_Direitos.csv"),
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
