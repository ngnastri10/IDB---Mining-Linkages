* ==========================================================================
* Run one Python script inside Stata, and stop if it fails.
*
* Usage (the path is relative to the Code folder, REPO_PATH):
*   do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/CFEM/pull_cfem.py"
* Scripts that take arguments get up to four more, in quotes:
*   do "$CONFIG_DIR/run_python.do" "2. Clean Data/SCM/reshape_scm.py" "arg1" "arg2"
*
* It uses Stata's built-in Python (Stata 16+), so the script's output
* shows up in the Results window and a crash stops Stata right there with
* the Python error. Stata finds Python on its own; if it can't, set
* PYTHON_EXE in config.do.
*
* Each script runs fresh, as if you'd typed "python script.py" in a
* terminal (see run_script.py). A script that quits early with an error
* message is turned into a real error too, so Stata stops.
*
* It's a do-file rather than a Stata program because every do-file in the
* repo starts with "clear all", which would wipe out a program.
* ==========================================================================

args script arg1 arg2 arg3 arg4

* This file is a helper - it needs to be told which script to run. If it's
* run on its own (e.g. with the Do button), say so instead of failing
* with a confusing error.
if "`script'" == "" {
	di as error "run_python.do is a helper - don't run it on its own."
	di as error "Run master.do instead, which calls this for every Python step."
	exit 198
}

local script_path "$REPO_PATH/`script'"

di as text _n "---- Running `script' ----"

* The actual running happens in run_script.py (a whole file runs cleanly;
* Stata's line-by-line python: blocks trip over multi-line code). It reads
* the script and its arguments from these globals - passing paths with
* spaces through python script's args() doesn't work.
global RUNPY_SCRIPT "`script_path'"
global RUNPY_ARG1 "`arg1'"
global RUNPY_ARG2 "`arg2'"
global RUNPY_ARG3 "`arg3'"
global RUNPY_ARG4 "`arg4'"

python script "$CONFIG_DIR/run_script.py"

macro drop RUNPY_*

di as result "---- Done: `script' ----"
