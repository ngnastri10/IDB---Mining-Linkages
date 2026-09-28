* ==========================================================================
* Master file: runs the whole project, start to finish, in order.
*
* Before the first run, paste your project folder into
* "0. Configure File Paths/config.do" (see the README), and paste the
* same project folder just below. Then run this file.
*
* The switches in Section 1 turn each stage on or off, so you can re-run
* just part of the pipeline. Stages have to run in order the first time -
* each one uses what the stage before it saved.
*
* RAIS is the one thing this does NOT build: it's cleaned on the HPC (see
* the HPC folder, for reference only). Section 5 checks the RAIS files
* are where they should be and stops with a clear message if not.
*
* File Organization:
*
*		Section 1: Switches
*		Section 2: Configure (paths, packages)
*		Section 3: Pull raw data
*		Section 4: Clean
*		Section 5: Build mines and merge
*		Section 6: Results
* ==========================================================================

clear all
set more off

********************************************************************************
********************************************************************************
**********															 ***********
********** 					Section 1: Switches                      ***********
**********															 ***********
********************************************************************************
********************************************************************************

******** PASTE YOUR PROJECT FOLDER (same as PROJECT_ROOT in config.do) ********
* Needed here too, just so this file can find config.do.
local project_folder "C:\Users\ngnas\OneDrive\Desktop\PhD Documents\Publications\IDB - Mining"

* 1 = run this stage, 0 = skip it.
*
* Pulling re-downloads everything from the government sites. Those are
* live datasets, so a fresh pull can give slightly different numbers than
* the files you were sent - turn it off if you're working from a snapshot.
local run_pull    1
local run_clean   1
local run_merge   1
local run_results 1

********************************************************************************
********************************************************************************
**********															 ***********
********** 			Section 2: Configure (paths, packages)           ***********
**********															 ***********
********************************************************************************
********************************************************************************

* Sets the path globals, writes config.py for the Python scripts, and
* checks/installs Stata and Python packages. Always runs.
do "`project_folder'/Code/0. Configure File Paths/config.do"

* A log of the whole run, so you can scroll back through it afterwards.
capture log close master
log using "$PROJECT_ROOT/Results/master_log.txt", replace text name(master)

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 3: Pull raw data                     ***********
**********															 ***********
********************************************************************************
********************************************************************************

* All Python. Saves to Data/ (or LARGE_DATA_ROOT for the big ones).

if `run_pull' {
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/Crosswalks/pull_crosswalks.py"
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/CFEM/pull_cfem.py"
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/SIGMINE/pull_sigmine.py"
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/SCM/pull_scm.py"
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/IO Matrix/pull_io_matrix.py"
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/WB Prices/pull_wb_prices.py"
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/PIX/pull_pix.py"
	do "$CONFIG_DIR/run_python.do" "1. Pull Raw Data/Maps/pull_map_boundaries.py"
}

********************************************************************************
********************************************************************************
**********															 ***********
********** 					Section 4: Clean                         ***********
**********															 ***********
********************************************************************************
********************************************************************************

* Each source on its own. clean_scm.do and clean_io_matrix.do call their
* own Python reshape step (reshape_scm.py, reshape_io_matrix.py) when needed.

if `run_clean' {
	do "$REPO_PATH/2. Clean Data/CFEM/clean_cfem.do"
	do "$REPO_PATH/2. Clean Data/SIGMINE/clean_sigmine.do"
	do "$REPO_PATH/2. Clean Data/SCM/clean_scm.do"
	do "$REPO_PATH/2. Clean Data/IO Matrix/clean_io_matrix.do"
	do "$REPO_PATH/2. Clean Data/WB Prices/clean_wb_prices.do"
	do "$REPO_PATH/2. Clean Data/PIX/clean_pix.do"
	do "$CONFIG_DIR/run_python.do" "2. Clean Data/Maps/clean_map_boundaries.py"
}

********************************************************************************
********************************************************************************
**********															 ***********
********** 			Section 5: Build mines and merge                 ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

	Order matters here:
	  locations, timeline, pipeline  - one row per mining right
	  price groups                   - needs the timeline's CFEM data
	  distances                      - needs all four of the above
	  price shock, final merge       - need the distances AND the RAIS files

*/

if `run_merge' {
	do "$REPO_PATH/3. Merge Data/build_mine_locations.do"
	do "$REPO_PATH/3. Merge Data/build_mine_timeline.do"
	do "$REPO_PATH/3. Merge Data/build_mine_pipeline.do"
	do "$REPO_PATH/3. Merge Data/build_price_groups.do"
	do "$CONFIG_DIR/run_python.do" "3. Merge Data/build_mine_distances.py"

	* RAIS comes from the HPC - make sure it's in place before using it.
	capture confirm file "$LARGE_DATA_ROOT/RAIS/Working/CNAE67/cleaned_all_years.dta"
	if _rc {
		di as error "Missing the RAIS file from the HPC:"
		di as error "    $LARGE_DATA_ROOT/RAIS/Working/CNAE67/cleaned_all_years.dta"
		di as error "Put it there (see the README for which HPC file goes where), then re-run with run_pull and run_clean set to 0."
		exit 601
	}

	do "$CONFIG_DIR/run_python.do" "3. Merge Data/build_price_shock.py"
	do "$REPO_PATH/3. Merge Data/merge_municipality_cnae67_year.do"
}

********************************************************************************
********************************************************************************
**********															 ***********
********** 					Section 6: Results                       ***********
**********															 ***********
********************************************************************************
********************************************************************************

if `run_results' {
	* Every map (see MAPS_BY_NAME in make_maps.py). Saves to Results/Figures/Maps.
	do "$CONFIG_DIR/run_python.do" "4. Generate Results/Maps/make_maps.py"
}

di as result _n "All done."
log close master
