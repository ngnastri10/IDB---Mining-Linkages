"""
Pull IBGE's official 2022 boundary maps: municipalities and states.

Source (browse it yourself here first if you want):
https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2022/Brasil/BR/

Saved (unzipped) under LARGE_DATA_ROOT/Maps/ (the municipal map is ~200MB
zipped). The files are standard shapefiles, so they also open in ArcGIS or
QGIS.

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

DATA_DIR = Path(config.LARGE_DATA_ROOT) / "Maps"

BASE_URL = ("https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/"
            "malhas_municipais/municipio_2022/Brasil/BR/")
FILES_TO_PULL = ["BR_Municipios_2022.zip", "BR_UF_2022.zip"]


def download_file(url, destination_path):
    """Download a file from a URL and save it to disk, in 1 MB chunks."""
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=600) as response:
        with open(destination_path, "wb") as out_file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                out_file.write(chunk)


def main():
    print(f"Data will be saved under: {DATA_DIR}\n")

    for filename in FILES_TO_PULL:
        # e.g. BR_Municipios_2022.zip -> Data/Maps/BR_Municipios_2022/
        folder = DATA_DIR / filename.replace(".zip", "")
        folder.mkdir(parents=True, exist_ok=True)
        zip_path = folder / filename

        print(f"Downloading {filename}...")
        download_file(BASE_URL + filename, zip_path)

        with zipfile.ZipFile(zip_path) as z:
            z.extractall(folder)
        zip_path.unlink()
        print(f"  Done - unzipped into {folder}")

    print("\nAll done.")


if __name__ == "__main__":
    main()
