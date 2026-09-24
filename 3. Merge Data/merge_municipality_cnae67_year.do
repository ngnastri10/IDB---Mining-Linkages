* ==========================================================================
* Final merge: one municipality x CNAE67 x year panel (2007-2025).
*
* Base: RAIS Vinculos (collapsed to municipality x cnae67 x year on the
* HPC), balanced so every municipality has all 67 industries every year.
*
* Merged on:
*   - IO Matrix linkages (by cnae67) - backward/forward linkage to mining
*   - Mining treatment (by municipality x year) - lean set, see Section 2
*   - CFEM royalties (by municipality x year) - total, iron, non-iron
*   - PIX (by municipality x year) - missing before it existed (Nov 2020)
*   - World Bank commodity prices (by year)
*   - RAIS Estab (by municipality x cnae67 x year) - only if already pulled
*
* Mining treatment comes from the "priced" version by default - only mines
* of minerals with a world price (no sand pits, clay, gravel, ...). Flip
* the switch below to "all" to use every mine. The full mining file (97
* columns: opened/closed events, pipeline stages, ...) stays separate in
* Working/Mines/ - merge anything else from it at analysis time with
* merge m:1 municipality year.
*
* Municipality codes: RAIS uses the 6-digit IBGE code. CFEM and PIX use
* the 7-digit version (+ a check digit), so those drop the last digit.
*
* Input:
*   LARGE_DATA_ROOT/RAIS/Working/CNAE67/cleaned_all_years.dta
*   LARGE_DATA_ROOT/RAIS/Working/Estab/CNAE67/cleaned_all_years.dta (optional)
*   Working/IO Matrix/io_matrix_mining_classification.dta
*   Working/Mines/municipality_year_mining_priced.dta (or _all)
*   Working/Mines/CFEM/cfem_process_month.dta
*   Working/Mines/municipality_year_price_shock.dta (from build_price_shock.py)
*   Working/PIX/pix_municipio_monthly.dta
*   Working/WB Prices/wb_commodity_prices_monthly.dta
*
* Output:
*   LARGE_DATA_ROOT/Merged/municipality_cnae67_year.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session,
* and the mining build files (build_mine_*.do, build_mine_distances.py).
*
* File Organization:
*
*		Section 1: Build the pieces we merge on (tempfiles)
*		Section 2: Mining treatment - lean set
*		Section 3: Balance RAIS and merge everything on
*		Section 4: Save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

* Which mining file to use: "priced" (default) or "all".
local mine_version "priced"

global RAIS_WORKING "$LARGE_DATA_ROOT/RAIS/Working"
global MINES        "$WORKING_DIR/Mines"
global MERGED       "$LARGE_DATA_ROOT/Merged"

capture mkdir "$MERGED"

********************************************************************************
********************************************************************************
**********															 ***********
********** 	Section 1: Build the pieces we merge on                     ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

	Each piece gets brought to the level it's merged at and saved as a
	tempfile - nothing here is saved to disk.

*/

****************************
** CFEM - municipality x year **
****************************

use year substance municipality_code royalty_value using "$MINES/CFEM/cfem_process_month.dta", clear

* ~1,600 rows have a broken municipality code - they can't be matched.
keep if inrange(municipality_code, 1000000, 9999999)

* 7-digit IBGE code -> 6-digit (drop the check digit) to match RAIS.
generate municipality = floor(municipality_code / 10)

* Iron vs. everything else - "Iron" and "Iron ore" are ~73% of royalties.
generate royalty_iron = cond(inlist(substance, "Iron", "Iron ore"), royalty_value, 0)
generate royalty_noniron = royalty_value - royalty_iron

collapse (sum) royalty_total = royalty_value royalty_iron royalty_noniron, by(municipality year)

tempfile cfem
save `cfem'

****************************
** PIX - municipality x year **
****************************

use "$WORKING_DIR/PIX/pix_municipio_monthly.dta", clear

replace municipality = floor(municipality / 10)

* Values and transaction counts add up over the year. The number of
* distinct payers/receivers doesn't (same person pays in many months), so
* that one gets the monthly average.
collapse (sum) pix_value_* pix_count_* (mean) pix_n_*, by(municipality year)

tempfile pix
save `pix'

****************************
** WB prices - year **
****************************

use "$WORKING_DIR/WB Prices/wb_commodity_prices_monthly.dta", clear

collapse (mean) *_price, by(year)

tempfile prices
save `prices'

********************************************************************************
********************************************************************************
**********															 ***********
********** 		Section 2: Mining treatment - lean set               ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

	Per distance band:

		treat_<band>             1 from the year the first mine in the band
		                         started producing, and stays 1 (even if it
		                         later closes) - the DiD treatment
		n_mines_<band>           number of mines producing in the band that
		                         year - the continuous (intensity) treatment
		first_treat_year_<band>  the year treat switches on - for event
		                         studies
		in_sample_<band>         1 = treated or control, 0 = always treated
		                         (mine producing by 2007) or no mining
		                         potential nearby. Use: keep if in_sample_25km

	Cumulative bands (10km, 25km, 50km, 100km) get all four. Rings
	(10_25km, 25_50km, 50_100km) get treat and n_mines only - rings go
	into one regression together, with the sample set by the outer
	cumulative band. 10km is both a ring (0-10) and cumulative.

*/

use "$MINES/municipality_year_mining_`mine_version'.dta", clear

foreach b in 10km 10_25km 25_50km 50_100km 25km 50km 100km {
	generate treat_`b' = !missing(first_opened_year_`b') & year >= first_opened_year_`b'
	rename n_active_mine_`b' n_mines_`b'
}

foreach b in 10km 25km 50km 100km {
	rename first_opened_year_`b' first_treat_year_`b'
	generate in_sample_`b' = inlist(mine_group_`b', 1, 2)
}

keep municipality year treat_* n_mines_* first_treat_year_* in_sample_*

foreach b in 10km 10_25km 25_50km 50_100km 25km 50km 100km {
	local txt = subinstr(subinstr("`b'", "_", "-", .), "km", " km", .)
	label variable treat_`b' "Treated: a mine started producing, `txt' (stays 1)"
	label variable n_mines_`b' "Number of mines producing this year, `txt'"
}
foreach b in 10km 25km 50km 100km {
	local txt = subinstr("`b'", "km", " km", .)
	label variable first_treat_year_`b' "Year the first mine started producing, within `txt'"
	label variable in_sample_`b' "In sample (treated or control), within `txt'"
}

tempfile mining
save `mining'

********************************************************************************
********************************************************************************
**********															 ***********
********** 	Section 3: Balance RAIS and merge everything on             ***********
**********															 ***********
********************************************************************************
********************************************************************************

use "$RAIS_WORKING/CNAE67/cleaned_all_years.dta", clear

* Rows with no cnae67 can't be balanced or merged on - count and drop.
count if missing(cnae67)
drop if missing(cnae67)

****************************
** Balance the panel **
****************************

/* Notes:

	Every municipality gets all 67 industries in every year. A filled-in
	cell had no workers, so COUNTS become 0 - but AVERAGES (age,
	education, wages, shares) stay missing: the average age of zero
	workers isn't 0, it doesn't exist.

*/

fillin municipality cnae67 year

* term_fired/resigned/retired are shares, not counts - only the monthly
* hire/termination counts get a 0.
foreach v in number_employed population {
	replace `v' = 0 if _fillin == 1
}
foreach m in jan feb mar apr may jun jul aug sep oct nov dec {
	replace hire_`m' = 0 if _fillin == 1
	replace term_`m' = 0 if _fillin == 1
}

* State doesn't change within a municipality - copy it onto filled rows.
bysort municipality (state): replace state = state[_N]

rename _fillin filled_in
label variable filled_in "No workers in this cell - added when balancing the panel"

****************************
** Merge **
****************************

* IO Matrix - by industry. Tab any cnae67 code RAIS has that the IO Matrix
* doesn't (e.g. a public/private split).
merge m:1 cnae67 using "$WORKING_DIR/IO Matrix/io_matrix_mining_classification.dta", keep(master match)
tab cnae67 if _merge == 1
drop _merge

* Mining treatment - by municipality-year.
merge m:1 municipality year using `mining', keep(master match) nogenerate

* CFEM - no row for a municipality-year means no royalties paid: a real 0.
merge m:1 municipality year using `cfem', keep(master match) nogenerate
foreach v in royalty_total royalty_iron royalty_noniron {
	replace `v' = 0 if missing(`v')
}

* Price shock (shift-share) - by municipality-year, if it's been built.
capture confirm file "$MINES/municipality_year_price_shock.dta"
if !_rc {
	merge m:1 municipality year using "$MINES/municipality_year_price_shock.dta", keep(master match) nogenerate
}
else {
	di as text "Price shock file not found yet - run build_price_shock.py first. Skipping it."
}

* PIX - stays missing before it existed.
merge m:1 municipality year using `pix', keep(master match) nogenerate

* WB prices - same for every municipality/industry in a year.
merge m:1 year using `prices', keep(master match) nogenerate

* RAIS Estab - only if it's been pulled already.
capture confirm file "$RAIS_WORKING/Estab/CNAE67/cleaned_all_years.dta"
if !_rc {
	merge 1:1 municipality cnae67 year using "$RAIS_WORKING/Estab/CNAE67/cleaned_all_years.dta", keepusing(estab_*) keep(master match) nogenerate

	* Estab lists every establishment, so no row = zero establishments.
	foreach v of varlist estab_* {
		replace `v' = 0 if missing(`v')
	}
}
else {
	di as text "Estab file not found yet - skipping it."
}

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 4: Save                              ***********
**********															 ***********
********************************************************************************
********************************************************************************

label variable royalty_total "CFEM royalties paid in this municipality-year, all substances"
label variable royalty_iron "CFEM royalties paid in this municipality-year, iron and iron ore"
label variable royalty_noniron "CFEM royalties paid in this municipality-year, everything except iron"

order municipality state cnae67 year filled_in

compress
save "$MERGED/municipality_cnae67_year.dta", replace

di as result "Done - saved `=_N' municipality x cnae67 x year rows to $MERGED/municipality_cnae67_year.dta"
