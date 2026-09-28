* ==========================================================================
* Run one Python script from Stata, and stop if it fails.
*
* Usage (master.do does this for every Python step):
*   do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/CFEM/pull_cfem.py"
* The path is relative to the Code folder (REPO_PATH).
*
* Why this exists: Stata's shell runs the script but never finds out
* whether it crashed - it just moves on, and the failure shows up later
* as a confusing "file not found". So the shell command only writes a
* small "ok" file if Python finished without an error (that's what the
* && does), and we check for that file.
*
* It's a do-file rather than a Stata program because every do-file in the
* repo starts with "clear all", which would wipe out a program.
* ==========================================================================

args script

* This file is a helper - it needs to be told which script to run. If it's
* run on its own (e.g. with the Do button), say so instead of failing
* with a confusing error.
if "`script'" == "" {
	di as error "run_python.do is a helper - don't run it on its own."
	di as error "Run master.do instead, which calls this for every Python step."
	exit 198
}

local ok_file "$CONFIG_DIR/python_step_ok.txt"
capture erase "`ok_file'"

di as text _n "---- Running `script' ----"
shell $PYTHON "$REPO_PATH/`script'" && echo ok > "`ok_file'"

capture confirm file "`ok_file'"
if _rc {
	di as error "`script' failed (or didn't finish)."
	di as error "Run it directly in a terminal to see the real error:"
	di as error `"    $PYTHON "$REPO_PATH/`script'""'
	exit 601
}

erase "`ok_file'"
di as result "---- Done: `script' ----"
