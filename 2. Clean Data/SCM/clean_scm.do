* ==========================================================================
* Clean ANM's Cadastro Mineiro (SCM) registry down to one row per mining
* right, with the dates of its key milestones (concession requested,
* granted, mining start reported, ended).
*
* A "mining right" (processo) is a legal title over a patch of land for a
* substance - NOT a physical mine. One mine can have several.
*
* Used later for:
*   - openings: date_mining_start
*   - pipeline: concession requested/granted, but mining not started yet
*
* Input:
*   LARGE_DATA_ROOT/SCM/microdados/ (from pull_scm.py)
*
* Output:
*   Working/Mines/SCM/scm_process.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: Reshape the raw registry (via Python helper) if needed
*		Section 2: Import, fix dates, label, and save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

global SCM_RAW     "$LARGE_DATA_ROOT/SCM"
global SCM_WORKING "$WORKING_DIR/Mines/SCM"

capture mkdir "$WORKING_DIR/Mines"
capture mkdir "$SCM_WORKING"

********************************************************************************
********************************************************************************
**********															 ***********
********** 		Section 1: Reshape the raw registry       			 ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

	The event log is ~1GB, so Python does the heavy lifting
	(reshape_scm.py): keeps only the milestone events, writes one small
	CSV, and then deletes the big event log. If the CSV is already there
	this step is skipped.

*/

capture confirm file "$SCM_RAW/scm_process_milestones.csv"
if _rc {
    * "python", not "python3" - on Windows "python3" resolves to the
    * Microsoft Store stub, not the real install.
    shell python "$REPO_PATH/2. Clean Data/SCM/reshape_scm.py" "$SCM_RAW/microdados" "$SCM_RAW/scm_process_milestones.csv"

    capture confirm file "$SCM_RAW/scm_process_milestones.csv"
    if _rc {
        di as error "reshape_scm.py did not produce the CSV - run it directly (not through Stata) to see the real error."
        exit 601
    }
}

********************************************************************************
********************************************************************************
**********															 ***********
********** 		Section 2: Import, fix dates, label, and save        ***********
**********															 ***********
********************************************************************************
********************************************************************************

import delimited using "$SCM_RAW/scm_process_milestones.csv", clear varnames(1) stringcols(_all)

destring process_number process_year active area_hectares, replace

* Dates come in as "YYYY-MM-DD" strings - turn them into Stata dates.
foreach v in date_filed date_research_approved date_concession_requested date_concession_granted date_mining_start date_concession_ended {
	generate `v'_d = date(`v', "YMD")
	format `v'_d %td
	drop `v'
	rename `v'_d `v'
}

label variable process_number "Mining right number (matches CFEM/SIGMINE)"
label variable process_year "Mining right year (matches CFEM/SIGMINE)"
label variable active "Mining right still active in the registry (1 = yes)"
label variable requirement_type "Type of request that opened the mining right"
label variable phase "Current phase of the mining right"
label variable area_hectares "Area of the mining right, hectares"
label variable date_filed "Date the mining right was filed"
label variable date_research_approved "First date: research report approved (viable deposit found)"
label variable date_concession_requested "First date: mining concession requested"
label variable date_concession_granted "First date: mining concession granted"
label variable date_mining_start "First date: company reported mining started"
label variable date_concession_ended "First date: concession ended (renounced, revoked, voided, lapsed)"

order process_number process_year active requirement_type phase area_hectares date_filed ///
	date_research_approved date_concession_requested date_concession_granted date_mining_start date_concession_ended

compress
save "$SCM_WORKING/scm_process.dta", replace

di as result "Done - saved `=_N' mining rights to $SCM_WORKING/scm_process.dta"
