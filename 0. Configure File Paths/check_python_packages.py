"""
Check that every package in requirements.txt can be imported, install any
that can't (pip install --user), and check again.

config.do runs this for you. You can also run it yourself:
    python check_python_packages.py

If you pass a file path, that file gets written only when everything is
installed - that's how config.do finds out whether it worked, since Stata
can't see a Python script's exit status.
"""

import importlib
import subprocess
import sys
from pathlib import Path

REQUIREMENTS = Path(__file__).resolve().parent / "requirements.txt"


def read_requirements():
    """Package names from requirements.txt, skipping comments and blank lines."""
    names = []
    for line in REQUIREMENTS.read_text().splitlines():
        line = line.split("#")[0].strip()
        if line:
            names.append(line)
    return names


def missing_packages(names):
    """The packages that fail to import. (Every package we use imports under
    the same name pip installs it under, so no name mapping is needed.)"""
    missing = []
    for name in names:
        try:
            importlib.import_module(name)
        except ImportError:
            missing.append(name)
    return missing


def main():
    print(f"Checking Python packages with: {sys.executable}")
    names = read_requirements()
    missing = missing_packages(names)

    if missing:
        print(f"Missing: {', '.join(missing)} - installing...")
        subprocess.call([sys.executable, "-m", "pip", "install", "--user", *missing])
        importlib.invalidate_caches()
        missing = missing_packages(missing)

    if missing:
        print(f"Still missing after trying to install: {', '.join(missing)}")
        print(f"Try by hand: {sys.executable} -m pip install {' '.join(missing)}")
        sys.exit(1)

    print("All packages there.")
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text("ok\n")


if __name__ == "__main__":
    main()
