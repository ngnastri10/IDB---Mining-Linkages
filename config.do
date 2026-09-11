* ==========================================================================
* Shared config - paste two paths below and everything else follows from
* them.
*
* Run this once per Stata session before running any other do-file in the repo.
*
* File Organization:
*
*		Section 1: Set globals from your two pasted paths
*		Section 2: Write config.py, so Python scripts see the same paths
*		Section 3: Create the Data/Results/Working folders
* ==========================================================================

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Set globals from your two pasted paths          ***********
**********															 ***********
********************************************************************************
********************************************************************************

* PROJECT_ROOT: the project folder you made to hold all files.
* REPO_PATH: wherever you cloned this repo into.

* Note: REPO_PATH should be inside of ROOT_PATH

******** PASTE BOTH PATHS IN QUOTES BELOW ********
global PROJECT_ROOT "C:\Users\ngnas\OneDrive\Desktop\PhD Documents\Publications\IDB - Mining"
global REPO_PATH "C:\Users\ngnas\OneDrive\Desktop\PhD Documents\Publications\IDB - Mining\Code"

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

file open cfgfile using "$REPO_PATH/config.py", write text replace
file write cfgfile "PROJECT_ROOT = r" (char(34)) "$PROJECT_ROOT" (char(34)) _n
file close cfgfile

di as result "config.py written with PROJECT_ROOT = $PROJECT_ROOT"

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
