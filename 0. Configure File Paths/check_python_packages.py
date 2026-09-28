"""
Check that every package in requirements.txt can be imported, install any
that can't (pip install --user), and check again. Stops with an error if
anything is still missing.

config.do runs this for you (through run_python.do). You can also run it
yourself in a terminal:
    python check_python_packages.py
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


def python_exe():
    """The python executable to run pip with. Inside Stata, sys.executable
    can point to Stata itself, so fall back to the Python install folder."""
    exe = Path(sys.executable)
    if "python" in exe.name.lower():
        return str(exe)
    base = Path(sys.exec_prefix)
    for candidate in [base / "python.exe", base / "bin" / "python3", base / "bin" / "python"]:
        if candidate.exists():
            return str(candidate)
    return "python"


def main():
    python = python_exe()
    print(f"Checking Python packages with: {python}")
    names = read_requirements()
    missing = missing_packages(names)

    if missing:
        print(f"Missing: {', '.join(missing)} - installing...")
        subprocess.call([python, "-m", "pip", "install", "--user", *missing])
        importlib.invalidate_caches()
        missing = missing_packages(missing)

    if missing:
        sys.exit(f"Still missing after trying to install: {', '.join(missing)}. "
                 f"Try by hand: {python} -m pip install {' '.join(missing)}")

    print("All packages there.")


if __name__ == "__main__":
    main()
