* ==========================================================================
* Shared config - paste the path to this repo below and everything else
* follows from it.
*
* Run this once per Stata session before running any other do-file in the
* repo (master.do runs it for you).
*
* Heads up: this file is tracked in git. Paste your own path, but don't
* commit your version - otherwise everyone else gets your path when they
* pull.
*
* File Organization:
*
*		Section 1: Set globals from your pasted path
*		Section 2: Write config.py, so Python scripts see the same paths
*		Section 3: Create the Data/Results/Working folders
*		Section 4: Check Stata packages
*		Section 5: Check Python packages
* ==========================================================================

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Set globals from your pasted path               ***********
**********															 ***********
********************************************************************************
********************************************************************************

******** 1. PASTE THE PATH TO THIS REPO HERE (required) ********
* The folder you cloned - whatever it's called. The folder it sits in is
* your project folder: Data, Working and Results get created there.
global REPO_PATH "C:\Users\ngnas\OneDrive\Desktop\PhD Documents\Publications\IDB - Mining\Code"

******** 2. BIG FILES SOMEWHERE ELSE? (optional) ********
* RAIS, the registry microdata, map shapefiles and the final panel are
* big (several GB). Leave this as "" to keep them in a "Large Data"
* folder inside your project folder (the one the repo sits in). Only set it if you're short on
* space and want them on another drive (e.g. "D:\Data").
global LARGE_DATA_ROOT "D:\Data"

******** 3. ONLY IF PYTHON WON'T START (optional) ********
* Python scripts run inside Stata, and Stata picks a Python on its own. If
* that one won't start (common with Anaconda), type "python search" in
* Stata and paste one of the paths it lists here.
global PYTHON_EXE "C:\Users\ngnas\AppData\Local\Programs\Python\Python311\python.exe"

*** Nothing below here needs changing. ***

* Catch the most likely setup mistake early: a path that isn't the repo.
capture confirm file "$REPO_PATH/master.do"
if _rc {
	di as error "Can't find the code at $REPO_PATH"
	di as error "REPO_PATH should be the folder you cloned - the one with master.do in it."
	exit 601
}

* The project folder is the folder the repo sits in. Switch backslashes to
* forward slashes (Stata and Python both handle those on every system),
* drop any trailing slash, then cut off the last folder name.
local repo = subinstr("$REPO_PATH", "\", "/", .)
if substr("`repo'", -1, 1) == "/" {
	local repo = substr("`repo'", 1, length("`repo'") - 1)
}
global REPO_PATH "`repo'"
global PROJECT_ROOT = substr("`repo'", 1, strrpos("`repo'", "/") - 1)

* Big files default to a "Large Data" folder inside the project folder.
if "$LARGE_DATA_ROOT" == "" {
	global LARGE_DATA_ROOT "$PROJECT_ROOT/Large Data"
}

di as result "Project folder: $PROJECT_ROOT"
di as result "Big files go in: $LARGE_DATA_ROOT"

* This folder - config.py, requirements.txt and the package checker live here.
global CONFIG_DIR "$REPO_PATH/0. Configure File Paths"

* RAW_DIR and WORKING_DIR are globals, so they mean the same thing in
* every do-file - the top-level Data/Working folders, nothing more
* specific. Each clean_*.do file points to its own source's subfolder
* with a *local* macro instead of redefining these.
global RAW_DIR     "$PROJECT_ROOT/Data"
global WORKING_DIR "$PROJECT_ROOT/Working"


********************************************************************************
********************************************************************************
**********															 ***********
********** Section 2: Write config.py, so Python scripts see the same **********
**********			 paths											 ***********
********************************************************************************
********************************************************************************

* Written next to this file, in the same folder. Every Python script looks
* for it here. It's personal, so it's in .gitignore.
file open cfgfile using "$CONFIG_DIR/config.py", write text replace
file write cfgfile "PROJECT_ROOT = r" (char(34)) "$PROJECT_ROOT" (char(34)) _n
file write cfgfile "LARGE_DATA_ROOT = r" (char(34)) "$LARGE_DATA_ROOT" (char(34)) _n
file close cfgfile

di as result "config.py written with PROJECT_ROOT = $PROJECT_ROOT"
di as result "config.py written with LARGE_DATA_ROOT = $LARGE_DATA_ROOT"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 3: Create the Data/Results/Working folders         ***********
**********															 ***********
********************************************************************************
********************************************************************************

capture mkdir "$PROJECT_ROOT/Data"
capture mkdir "$PROJECT_ROOT/Results"
capture mkdir "$PROJECT_ROOT/Working"
capture mkdir "$LARGE_DATA_ROOT"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 4: Check Stata packages                            ***********
**********															 ***********
********************************************************************************
********************************************************************************

* User-written Stata packages (from SSC) the code needs. Nothing yet -
* add each one here when the analysis starts using it, e.g.:
*   local stata_packages "reghdfe ftools csdid drdid"
local stata_packages ""

foreach pkg of local stata_packages {
	capture which `pkg'
	if _rc {
		di as text "Installing Stata package `pkg' from SSC..."
		ssc install `pkg', replace
	}
}

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 5: Check Python packages                           ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

	Python scripts run inside Stata (Stata 16+). Step 1 makes sure Stata
	can find Python; step 2 runs check_python_packages.py, which imports
	everything in requirements.txt, installs whatever's missing
	(pip install --user) and stops with an error if anything is still
	missing.

*/

* 1. Point Stata at Python, if a path was given. This only works before
* Python has started in this Stata session, hence the capture.
if "$PYTHON_EXE" != "" {
	capture python set exec "$PYTHON_EXE"
}

capture python: import sys
if _rc {
	di as error "Python won't start in Stata."
	di as error "Type 'python search' in Stata, then paste one of the paths it lists"
	di as error "into PYTHON_EXE at the top of config.do (and restart Stata)."
	exit 601
}

* 2. Check (and install) the packages.
do "$CONFIG_DIR/run_python.do" "0. Configure File Paths/check_python_packages.py"
