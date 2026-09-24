"""
Pull RAIS microdata (Vinculos + Estabelecimentos) from the Ministry of
Labor's FTP server. Downloads only - decompression is turned off here on
purpose, see the note in main() below. This saves to LARGE_DATA_ROOT, not
the normal Data folder - see config.do/README if that's not set up yet.

Source: ftp://ftp.mtps.gov.br/pdet/microdados/RAIS/<year>/

File naming has changed over the years - older years ship one .7z per
state plus one ESTB<year>.7z; newer years ship a handful of region-grouped
files plus RAIS_ESTAB_PUB.7z instead. Rather than hardcoding either naming
scheme, this just downloads every .7z file it finds sitting in a given
year's folder.

Needs py7zr to decompress (pip install py7zr) - not a default package.

Same config.py setup as the other pull scripts - see pull_sigmine.py if
this errors out on missing config.py.
"""

import sys
import time
import shutil
import ftplib
from pathlib import Path

try:
    import py7zr
except ImportError:
    raise SystemExit("Missing py7zr - run: pip install py7zr")

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

try:
    import config
except ImportError:
    raise SystemExit(
        "Couldn't find config.py in the Code folder.\n"
        "Run config.do in Stata first (once per session) - see the README."
    )

if not hasattr(config, "LARGE_DATA_ROOT") or not Path(config.LARGE_DATA_ROOT).is_dir():
    raise SystemExit(
        "LARGE_DATA_ROOT isn't set to a real folder.\n"
        "Paste a path (somewhere with a lot of free space) in config.do and run it again."
    )

######## Set the years you want to pull here ########
YEARS = list(range(1990,2001))
#######################################################

FTP_HOST = "ftp.mtps.gov.br"
FTP_BASE = "/pdet/microdados/RAIS"

RAIS_DIR = Path(config.LARGE_DATA_ROOT) / "RAIS"
RAW_7Z_DIR = RAIS_DIR / "raw_7z"
RAW_TXT_DIR = RAIS_DIR / "raw_txt"


def download_year(ftp, year, attempts=3):
    """Download every .7z file sitting in one year's FTP folder."""
    dest_folder = RAW_7Z_DIR / str(year)
    dest_folder.mkdir(parents=True, exist_ok=True)

    remote_dir = f"{FTP_BASE}/{year}"
    ftp.cwd(remote_dir)
    filenames = [f for f in ftp.nlst() if f.lower().endswith(".7z")]

    print(f"{year}: found {len(filenames)} .7z files")

    for filename in filenames:
        dest_path = dest_folder / filename
        if dest_path.exists():
            print(f"  {filename} already downloaded, skipping")
            continue

        # Download to a .part name first, only rename to the real filename
        # once it's fully done - so if this gets interrupted (closed
        # window, killed process, etc.), the leftover partial file can
        # never be mistaken for a completed download on the next run.
        partial_path = dest_path.with_suffix(dest_path.suffix + ".part")

        for attempt in range(1, attempts + 1):
            try:
                print(f"  Downloading {filename} (attempt {attempt})...")
                with open(partial_path, "wb") as out_file:
                    ftp.retrbinary(f"RETR {filename}", out_file.write)
                partial_path.rename(dest_path)
                break
            except Exception as e:
                partial_path.unlink(missing_ok=True)
                if attempt == attempts:
                    print(f"  Could not download {filename}: {e}")
                else:
                    print(f"  Attempt {attempt} failed, retrying...")
                    time.sleep(3)


def extract_year(year):
    """Decompress every .7z downloaded for one year into raw_txt/<year>/."""
    src_folder = RAW_7Z_DIR / str(year)
    dest_folder = RAW_TXT_DIR / str(year)
    dest_folder.mkdir(parents=True, exist_ok=True)

    for archive_path in src_folder.glob("*.7z"):
        already_done = list(dest_folder.glob(f"{archive_path.stem}*"))
        if already_done:
            print(f"  {archive_path.name} already extracted, skipping")
            continue

        # Extract into a temp subfolder first, then move the result into
        # dest_folder only once extraction fully succeeds - same reasoning
        # as the .part files on download: an interrupted extraction can't
        # then be mistaken for a completed one on the next run.
        temp_folder = dest_folder / f"_extracting_{archive_path.stem}"
        temp_folder.mkdir(exist_ok=True)

        print(f"  Extracting {archive_path.name}...")
        try:
            with py7zr.SevenZipFile(archive_path, mode="r") as archive:
                archive.extractall(path=temp_folder)
            for extracted_file in temp_folder.iterdir():
                extracted_file.rename(dest_folder / extracted_file.name)
            temp_folder.rmdir()
        except Exception as e:
            shutil.rmtree(temp_folder, ignore_errors=True)
            print(f"  Could not extract {archive_path.name}: {e}")


def main():
    print(f"LARGE_DATA_ROOT (from config.py): {config.LARGE_DATA_ROOT}")
    print(f"RAIS files will be saved under: {RAIS_DIR}\n")

    ftp = ftplib.FTP(FTP_HOST, timeout=120)
    ftp.login()

    for year in YEARS:
        download_year(ftp, year)

    ftp.close()

    # Decompression turned off on purpose - the HPC's login nodes don't
    # allow outbound internet, so the plan is to transfer these .7z files
    # over (small) and decompress on the HPC's end instead of here. Un-
    # comment below if that changes and this machine should do it locally.
    # print("\nDecompressing...")
    # for year in YEARS:
    #     extract_year(year)

    print("\nAll done.")


if __name__ == "__main__":
    main()
