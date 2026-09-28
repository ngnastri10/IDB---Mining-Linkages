* ==========================================================================
* Shared config - paste your project folder below and everything else
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

******** 1. PASTE YOUR PROJECT FOLDER HERE (required) ********
* The folder that holds everything - the repo sits inside it as "Code".
global PROJECT_ROOT "C:\Users\ngnas\OneDrive\Desktop\PhD Documents\Publications\IDB - Mining"

******** 2. BIG FILES SOMEWHERE ELSE? (optional) ********
* RAIS, the registry microdata, map shapefiles and the final panel are
* big (several GB). Leave this as "" to keep them in a "Large Data"
* folder inside your project folder. Only set it if you're short on
* space and want them on another drive (e.g. "D:\Data").
global LARGE_DATA_ROOT "D:\Data"

******** 3. MAC USERS: change this to "python3" ********
* The command that runs Python. On Windows keep "python" - "python3" there
* can point to a Microsoft Store stub that fails silently.
global PYTHON "python"

*** Nothing below here needs changing. ***

* The repo (Code folder) and the big-files default follow from the above.
global REPO_PATH "$PROJECT_ROOT/Code"
if "$LARGE_DATA_ROOT" == "" {
	global LARGE_DATA_ROOT "$PROJECT_ROOT/Large Data"
}

* Catch the most likely setup mistake early: the repo not being in a
* folder called Code inside the project folder.
capture confirm file "$REPO_PATH/master.do"
if _rc {
	di as error "Can't find the code at $REPO_PATH"
	di as error "The repo needs to sit inside your project folder, in a folder called Code."
	exit 601
}

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
**********			 paths (no Stata Python integration needed)		 ***********
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

	check_python_packages.py tries to import everything in
	requirements.txt, installs whatever's missing (pip install --user),
	and checks again. If anything is still missing it prints what, and
	which Python it checked - that matters, since "$PYTHON" might not be
	the same Python you use in VS Code or Anaconda.

	shell doesn't tell Stata whether a Python script worked, so the script
	only writes the "ok" file when everything imports - no file means
	something's still missing.

*/

local python_ok "$CONFIG_DIR/python_packages_ok.txt"
capture erase "`python_ok'"

shell $PYTHON "$CONFIG_DIR/check_python_packages.py" "`python_ok'"

capture confirm file "`python_ok'"
if _rc {
	di as error "Some Python packages are missing, or Python itself couldn't be found (PYTHON = $PYTHON)."
	di as error "Run this in a terminal to see what's wrong:"
	di as error `"    $PYTHON "$CONFIG_DIR/check_python_packages.py""'
	di as error "Or install everything by hand:"
	di as error `"    $PYTHON -m pip install -r "$CONFIG_DIR/requirements.txt""'
	exit 601
}

erase "`python_ok'"
di as result "Python packages all there."
