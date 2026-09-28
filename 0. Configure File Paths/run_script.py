"""
Helper for run_python.do - runs one project Python script inside Stata.

run_python.do puts the script's full path and up to four arguments in the
Stata globals RUNPY_SCRIPT and RUNPY_ARG1-4, and this reads them. The
script runs fresh, as if you'd typed "python script.py arg1 arg2" in a
terminal.

A script that quits early with an error message (sys.exit with a message)
is turned into a real error, so Stata stops instead of carrying on.
"""

import runpy
import sys

from sfi import Macro  # Stata's Python interface

target = Macro.getGlobal("RUNPY_SCRIPT")
args = [Macro.getGlobal(f"RUNPY_ARG{i}") for i in range(1, 5)]
# Blank globals mean "no argument" - drop them.
sys.argv = [target] + [a for a in args if a]

try:
    runpy.run_path(target, run_name="__main__")
except SystemExit as e:
    # sys.exit() with no message, or 0, means it finished fine.
    if e.code not in (None, 0):
        raise RuntimeError(str(e.code))
