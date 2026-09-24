* ==========================================================================
* Build a timeline for every mining right that ever paid royalties (CFEM):
* when it started producing, when it stopped, and what it mines.
*
* Rules (agreed, see Code/open_decisions.md for things to revisit):
*   - Opened: first year it paid royalties, only counted from 2003 on -
*     anything paying in 2002 (CFEM's first year) was probably already open.
*   - Operating: every year between its first and last payment, even years
*     it skipped - small mines pay on and off.
*   - Closed: never paid in 2025 or 2026 (end of the data). Closing year =
*     last payment year.
*   - The registry's "mining start reported" date is kept next to it for
*     comparison only.
*
* Run once - feeds the distance counts, not the final merge directly.
*
* Input:
*   Working/Mines/CFEM/cfem_process_month.dta
*   Working/Mines/SCM/scm_process.dta
*
* Output:
*   Working/Mines/mine_timeline.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: Main substance of each mining right
*		Section 2: First/last payment, opened/closed
*		Section 3: Add registry mining start, label, and save
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
********** 		Section 1: Main substance of each mining right       ***********
**********															 ***********
********************************************************************************
********************************************************************************

use year process_number process_year substance royalty_value using "$MINES/CFEM/cfem_process_month.dta", clear

drop if missing(process_number) | missing(process_year)

* The substance it paid the most royalties on.
preserve
collapse (sum) royalty_value, by(process_number process_year substance)
bysort process_number process_year (royalty_value): keep if _n == _N
rename substance main_substance
keep process_number process_year main_substance

tempfile substance
save `substance'
restore

********************************************************************************
********************************************************************************
**********															 ***********
********** 		Section 2: First/last payment, opened/closed         ***********
**********															 ***********
********************************************************************************
********************************************************************************

collapse (min) first_year = year (max) last_year = year (sum) royalty_total = royalty_value, ///
	by(process_number process_year)

generate opened_year = first_year if first_year >= 2003
generate closed_year = last_year if last_year <= 2024

merge 1:1 process_number process_year using `substance', nogenerate

********************************************************************************
********************************************************************************
**********															 ***********
********** 	Section 3: Add registry mining start, label, and save       ***********
**********															 ***********
********************************************************************************
********************************************************************************

merge 1:1 process_number process_year using "$MINES/SCM/scm_process.dta", ///
	keepusing(date_mining_start) keep(master match) nogenerate

rename date_mining_start mining_start_registry

label variable process_number "Mining right number"
label variable process_year "Mining right year"
label variable first_year "First year it paid royalties"
label variable last_year "Last year it paid royalties"
label variable opened_year "Year it opened (first payment, 2003 on only)"
label variable closed_year "Year it closed (last payment, if it never paid in 2025-2026)"
label variable main_substance "Substance it paid the most royalties on"
label variable royalty_total "Total royalties paid, all years"
label variable mining_start_registry "Date the company reported mining started (registry, for comparison)"

order process_number process_year first_year last_year opened_year closed_year main_substance royalty_total mining_start_registry

* Quick look: openings and closings per year.
tab opened_year
tab closed_year

compress
save "$MINES/mine_timeline.dta", replace

di as result "Done - saved `=_N' mining rights to $MINES/mine_timeline.dta"
