* ==========================================================================
* Build the pipeline: mining rights that requested or got a concession -
* places that were promising enough for a company to go through the
* hassle - and whether they ever actually opened.
*
* Idea: rights that went through all that and NEVER opened are the control
* group (viable, but no mine), compared against places where mines did open.
*
* Rules:
*   - Entered the pipeline: first concession request (or the grant, if
*     there's no request date).
*   - Left the pipeline: it opened (first CFEM royalty payment or reported
*     mining start, whichever comes first) or the concession ended.
*   - No time cap - long-pending rights that never opened are exactly the
*     controls we want.
*   - Rights already producing before they entered never count as pipeline.
*
* Run once - feeds the distance counts, not the final merge directly.
*
* Input:
*   Working/Mines/SCM/scm_process.dta
*   Working/Mines/mine_timeline.dta
*
* Output:
*   Working/Mines/mine_pipeline.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: Entry and exit years
*		Section 2: Label and save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

global MINES "$WORKING_DIR/Mines"

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 1: Entry and exit years              ***********
**********															 ***********
********************************************************************************
********************************************************************************

use process_number process_year date_concession_requested date_concession_granted ///
	date_concession_ended date_mining_start using "$MINES/SCM/scm_process.dta", clear

keep if !missing(date_concession_requested) | !missing(date_concession_granted)

generate requested_year = year(date_concession_requested)
generate granted_year   = year(date_concession_granted)

* min() skips missing values, so this is the request year, or the grant
* year when there's no request date.
generate pipeline_start_year = min(requested_year, granted_year)

* Opening: first royalty payment or reported mining start, whichever first.
merge 1:1 process_number process_year using "$MINES/mine_timeline.dta", ///
	keepusing(first_year) keep(master match) nogenerate
generate opened_year = min(first_year, year(date_mining_start))

generate ended_year = year(date_concession_ended)

generate pipeline_end_year = min(opened_year, ended_year)

* Already producing before entering the pipeline - not a pipeline mine.
drop if !missing(opened_year) & opened_year <= pipeline_start_year

generate end_reason = 3
replace end_reason = 2 if !missing(ended_year) & ended_year == pipeline_end_year
replace end_reason = 1 if !missing(opened_year) & opened_year == pipeline_end_year

generate ever_opened = (end_reason == 1)

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 2: Label and save                    ***********
**********															 ***********
********************************************************************************
********************************************************************************

label define end_reason 1 "Opened" 2 "Concession ended" 3 "Still pending"
label values end_reason end_reason

keep process_number process_year pipeline_start_year granted_year pipeline_end_year end_reason ever_opened

label variable process_number "Mining right number"
label variable process_year "Mining right year"
label variable pipeline_start_year "Year it entered the pipeline (first concession request, or grant)"
label variable granted_year "Year the concession was granted (blank if never)"
label variable pipeline_end_year "Year it left the pipeline (opened or concession ended; blank if still pending)"
label variable end_reason "Why it left the pipeline"
label variable ever_opened "Eventually opened (1) vs. never opened - candidate control (0)"

order process_number process_year pipeline_start_year granted_year pipeline_end_year end_reason ever_opened

* Quick look: how many opened, dropped, or are still pending.
tab end_reason

compress
save "$MINES/mine_pipeline.dta", replace

di as result "Done - saved `=_N' pipeline mining rights to $MINES/mine_pipeline.dta"
