"""
Pull the World Bank's Pink Sheet monthly commodity price file from their
document server. Plain xlsx, no unzipping needed.

NOTE: If this 404s, go to
https://www.worldbank.org/en/research/commodity-markets, find "Monthly
prices" under the Pink Sheet section, and paste the new link into FILE_URL
below.

Same config.py setup as the other pull scripts - see pull_sigmine.py if
this errors out on missing config.py.
"""

import sys
import time
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

DATA_DIR = Path(config.PROJECT_ROOT) / "Data" / "WB Prices"

FILE_URL = (
    "https://thedocs.worldbank.org/en/doc/"
    "74e8be41ceb20fa0da750cda2f6b9e4e-0050012026/related/"
    "CMO-Historical-Data-Monthly.xlsx"
)


def download_file(url, destination_path, attempts=3):
    """Download a file from a URL and save it to disk.

    Streamed in 1 MB chunks rather than pulling the whole thing into
    memory at once. Retries a few times since this host has been known to
    reset the connection mid-download on flaky networks.
    """
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                with open(destination_path, "wb") as out_file:
                    while True:
                        chunk = response.read(1024 * 1024)
                        if not chunk:
                            break
                        out_file.write(chunk)
            return
        except Exception:
            if attempt == attempts:
                raise
            print(f"  Attempt {attempt} failed, retrying...")
            time.sleep(3)


def main():
    print(f"Project root (from config.py): {config.PROJECT_ROOT}")
    print(f"Data will be saved under: {DATA_DIR}\n")

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    file_path = DATA_DIR / "CMO-Historical-Data-Monthly.xlsx"

    print(f"Downloading CMO-Historical-Data-Monthly.xlsx -> {file_path}")
    try:
        download_file(FILE_URL, file_path)
    except Exception as e:
        print(f"  Could not download the file after retrying: {e}")
        print(f"  Could be a flaky connection, or the link may be stale - see the note at the top of this script.")
        print(f"  You can also just grab it by hand and drop it in {DATA_DIR}")
        return

    print("Done.")


if __name__ == "__main__":
    main()
