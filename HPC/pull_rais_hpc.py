"""
HPC version of pull_rais.py - downloads RAIS microdata directly on the
HPC, instead of on a local machine + external drive. Downloads only -
decompression is turned off here on purpose, see the note in main()
below. The .7z archives are small (a few GB per year even in the biggest
years), but decompressed they can run 50GB+ per year, which doesn't fit
this account's disk quota if done for every year at once - so the plan
is to decompress one year at a time, clean it, delete the raw text, then
move to the next year, rather than decompressing everything up front.

This relies on the HPC's login node allowing outbound internet access -
confirmed working already, this isn't hypothetical.

Source: ftp://ftp.mtps.gov.br/pdet/microdados/RAIS/<year>/

Same file-naming caveat as the local version - older years ship one .7z
per state, newer years ship region-grouped files instead. This just grabs
every .7z it finds rather than assuming either scheme.

Setup on the HPC before running:
    module load python312        (the default python3 here is 3.6.8, too old for py7zr)
    pip install --user py7zr     (no admin rights on a shared HPC, so --user)
"""

import sys
import time
import shutil
import ftplib
from pathlib import Path

try:
    import py7zr
except ImportError:
    raise SystemExit("Missing py7zr - run: pip install --user py7zr")

######## Set your HPC path here ########
HPC_ROOT = Path("/home/nn3495a-hpc/IDB")
##########################################

######## Set the years you want to pull here ########
YEARS = list(range(1985, 2026))
#######################################################

FTP_HOST = "ftp.mtps.gov.br"
FTP_BASE = "/pdet/microdados/RAIS"

RAIS_DIR = HPC_ROOT / "Data" / "RAIS"
RAW_7Z_DIR = RAIS_DIR / "raw_7z"
RAW_TXT_DIR = RAIS_DIR / "raw_txt"


def connect():
    """Open a fresh FTP connection and log in."""
    ftp = ftplib.FTP(FTP_HOST, timeout=120)
    # Some year folders (2023+) have filenames with stray non-UTF8 bytes
    # (e.g. an em-dash in Latin-1). Python 3.9+ ftplib defaults to strict
    # UTF-8 and crashes on those. latin-1 maps every byte 0-255 to a
    # character, so it can never raise a decode error here.
    ftp.encoding = "latin-1"
    ftp.login()
    return ftp


def download_year(ftp, year, attempts=3):
    """Download every .7z file sitting in one year's FTP folder.

    Returns (ftp, failures) - ftp may be a brand new connection object if
    the original one died and got reconnected along the way, and failures
    is a list of filenames that never made it down after every retry.
    """
    dest_folder = RAW_7Z_DIR / str(year)
    dest_folder.mkdir(parents=True, exist_ok=True)

    remote_dir = f"{FTP_BASE}/{year}"

    # cwd/nlst can hit a flaky protocol error on their own (seen on the
    # 2023 folder) - same reconnect-and-retry idea as the per-file
    # downloads below, just applied to the listing step first.
    filenames = None
    for attempt in range(1, attempts + 1):
        try:
            ftp.cwd(remote_dir)
            filenames = [f for f in ftp.nlst() if f.lower().endswith(".7z")]
            break
        except Exception as e:
            print(f"  Listing {year} failed (attempt {attempt}): {e}")
            try:
                ftp.close()
            except Exception:
                pass
            try:
                ftp = connect()
            except Exception as reconnect_error:
                print(f"  Reconnect failed too: {reconnect_error}")
            if attempt < attempts:
                time.sleep(3)

    if filenames is None:
        print(f"  Giving up on listing {year} after {attempts} attempts")
        return ftp, [f"<could not list {year}>"]

    print(f"{year}: found {len(filenames)} .7z files")

    failures = []

    for filename in filenames:
        dest_path = dest_folder / filename
        if dest_path.exists():
            print(f"  {filename} already downloaded, skipping")
            continue

        # Download to a .part name first, only rename to the real filename
        # once it's fully done - so if this gets interrupted, the leftover
        # partial file can't be mistaken for a completed download later.
        partial_path = dest_path.with_suffix(dest_path.suffix + ".part")
        succeeded = False

        for attempt in range(1, attempts + 1):
            try:
                print(f"  Downloading {filename} (attempt {attempt})...")
                with open(partial_path, "wb") as out_file:
                    ftp.retrbinary(f"RETR {filename}", out_file.write)
                partial_path.rename(dest_path)
                succeeded = True
                break
            except Exception as e:
                partial_path.unlink(missing_ok=True)
                print(f"  Attempt {attempt} failed ({e})")

                # A failed transfer often means the whole FTP connection
                # died, not just this one file - retrying on the same
                # broken connection would just fail the same way every
                # time. Reconnect before trying again.
                try:
                    ftp.close()
                except Exception:
                    pass
                try:
                    ftp = connect()
                    ftp.cwd(remote_dir)
                except Exception as reconnect_error:
                    print(f"  Reconnect failed too: {reconnect_error}")

                if attempt < attempts:
                    time.sleep(3)

        if not succeeded:
            print(f"  Giving up on {filename} after {attempts} attempts")
            failures.append(filename)

    return ftp, failures


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

        # Same reasoning as the .part files on download - extract into a
        # temp subfolder first, only move the result into dest_folder once
        # extraction fully succeeds.
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
    RAW_7Z_DIR.mkdir(parents=True, exist_ok=True)
    RAW_TXT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"HPC_ROOT: {HPC_ROOT}")
    print(f"RAIS files will be saved under: {RAIS_DIR}\n")

    ftp = connect()

    all_failures = {}
    for year in YEARS:
        ftp, failures = download_year(ftp, year)
        if failures:
            all_failures[year] = failures

    ftp.close()

    # Decompression turned off on purpose - see the note at the top of this
    # file. Decompress one year at a time by hand (or a small separate
    # script) as you're ready to clean it, then delete that year's raw
    # text before moving to the next one, rather than decompressing
    # everything here and blowing the disk quota.
    # print("\nDecompressing...")
    # for year in YEARS:
    #     extract_year(year)

    if all_failures:
        print("\nSome files never downloaded, even after retrying and reconnecting:")
        for year, files in all_failures.items():
            print(f"  {year}: {', '.join(files)}")
        print("\nJust re-run this script - already-downloaded files are skipped, so it'll only retry what's missing.")
        sys.exit(1)

    print("\nAll done.")


if __name__ == "__main__":
    main()
