* ==========================================================================
* Build a location (lat/lon) for every mining right we care about:
*   - every right that ever paid royalties (CFEM) - operating, opening,
*     and closing mines
*   - every right that ever requested or got a mining concession (the
*     pipeline)
*
* Each right gets the first location source that works:
*   1 = its own SIGMINE point
*   2 = average of its group members' SIGMINE points (the "Grupamento
*       Mineiro" group processes big mines pay royalties under)
*   3 = hand-coded (Data/Crosswalks/hand_coded_mine_locations.csv) -
*       always wins when filled in, since it's exact
*   4 = seat of the town where it paid the most royalties (last resort)
*
* Run once - only needs re-running when you hand-code new mines. Feeds the
* distance counts, not the final merge directly.
*
* Input:
*   Working/Mines/CFEM/cfem_process_month.dta
*   Working/Mines/SIGMINE/sigmine_mine_level.dta
*   Working/Mines/SCM/scm_process.dta
*   LARGE_DATA_ROOT/SCM/microdados/ProcessoAssociacao.txt
*   Data/Crosswalks/municipality_latlon.csv
*   Data/Crosswalks/hand_coded_mine_locations.csv
*
* Output:
*   Working/Mines/mine_locations.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: Build each location source
*		Section 2: List of mining rights we need locations for
*		Section 3: Apply the sources in order, report, and save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

global MINES      "$WORKING_DIR/Mines"
global CROSSWALKS "$RAW_DIR/Crosswalks"

********************************************************************************
********************************************************************************
**********															 ***********
********** 			Section 1: Build each location source            ***********
**********															 ***********
********************************************************************************
********************************************************************************

****************************
** Source 1: SIGMINE points **
****************************

use process_number process_year centroid_lat centroid_lon using "$MINES/SIGMINE/sigmine_mine_level.dta", clear

tempfile sigmine
save `sigmine'

****************************
** Source 2: group averages **
****************************

/* Notes:

	Registry IDs look like "930.641/1989" - split into number (930641) and
	year (1989) so they match CFEM/SIGMINE. Type 4 = "Grupamento Mineiro".

*/

import delimited using "$LARGE_DATA_ROOT/SCM/microdados/ProcessoAssociacao.txt", ///
	delimiter(";") varnames(1) case(lower) stringcols(_all) encoding("ISO-8859-1") clear

keep if idtipoassociacao == "4"

* Group ID
generate group_number = real(subinstr(substr(dsprocesso, 1, strpos(dsprocesso, "/") - 1), ".", "", .))
generate group_year   = real(substr(dsprocesso, strpos(dsprocesso, "/") + 1, 4))

* Member ID - named like SIGMINE so it merges straight on
generate process_number = real(subinstr(substr(dsprocessoassociado, 1, strpos(dsprocessoassociado, "/") - 1), ".", "", .))
generate process_year   = real(substr(dsprocessoassociado, strpos(dsprocessoassociado, "/") + 1, 4))

merge m:1 process_number process_year using `sigmine', keep(match) nogenerate

collapse (mean) group_lat = centroid_lat group_lon = centroid_lon, by(group_number group_year)
rename (group_number group_year) (process_number process_year)

tempfile groups
save `groups'

****************************
** Source 3: hand-coded **
****************************

import delimited using "$CROSSWALKS/hand_coded_mine_locations.csv", clear varnames(1) encoding("UTF-8")

* lat/lon come in as text if the column is still empty.
destring lat lon, replace
keep if !missing(lat) & !missing(lon)
keep process_number process_year lat lon
rename (lat lon) (hand_lat hand_lon)

tempfile hand
save `hand'

****************************
** Source 4: town seats **
****************************

import delimited using "$CROSSWALKS/municipality_latlon.csv", clear varnames(1)
keep municipality municipality_code7 seat_lat seat_lon

tempfile seats
save `seats'

********************************************************************************
********************************************************************************
**********															 ***********
********** 	Section 2: List of mining rights we need locations for      ***********
**********															 ***********
********************************************************************************
********************************************************************************

****************************
** Rights that paid royalties **
****************************

use process_number process_year municipality_code royalty_value using "$MINES/CFEM/cfem_process_month.dta", clear

drop if missing(process_number) | missing(process_year)

* ~1,600 rows have a broken municipality code - blank it rather than drop
* the row, so the right still gets counted.
replace municipality_code = . if !inrange(municipality_code, 1000000, 9999999)

* Total royalties per right, and the town it paid the most in (for the
* last-resort seat location).
collapse (sum) royalty_value, by(process_number process_year municipality_code)
bysort process_number process_year: egen royalty_total = total(royalty_value)
bysort process_number process_year (royalty_value): keep if _n == _N

rename municipality_code municipality_code7
generate in_cfem = 1
keep process_number process_year municipality_code7 royalty_total in_cfem

tempfile cfem_rights
save `cfem_rights'

****************************
** Rights that ever reached a concession **
****************************

use process_number process_year date_concession_requested date_concession_granted using "$MINES/SCM/scm_process.dta", clear

keep if !missing(date_concession_requested) | !missing(date_concession_granted)
generate ever_concession = 1
keep process_number process_year ever_concession

merge 1:1 process_number process_year using `cfem_rights', nogenerate

replace in_cfem = 0 if missing(in_cfem)
replace ever_concession = 0 if missing(ever_concession)

********************************************************************************
********************************************************************************
**********															 ***********
********** 	Section 3: Apply the sources in order, report, and save     ***********
**********															 ***********
********************************************************************************
********************************************************************************

generate lat = .
generate lon = .
generate location_source = .

* 1: own SIGMINE point
merge 1:1 process_number process_year using `sigmine', keep(master match) nogenerate
replace location_source = 1 if !missing(centroid_lat)
replace lat = centroid_lat if location_source == 1
replace lon = centroid_lon if location_source == 1

* 2: group average
merge 1:1 process_number process_year using `groups', keep(master match) nogenerate
replace location_source = 2 if missing(location_source) & !missing(group_lat)
replace lat = group_lat if location_source == 2
replace lon = group_lon if location_source == 2

* 3: hand-coded - overrides everything above when filled in
merge 1:1 process_number process_year using `hand', keep(master match) nogenerate
replace location_source = 3 if !missing(hand_lat)
replace lat = hand_lat if location_source == 3
replace lon = hand_lon if location_source == 3

* 4: seat of the top royalty town
merge m:1 municipality_code7 using `seats', keep(master match) nogenerate
replace location_source = 4 if missing(location_source) & !missing(seat_lat)
replace lat = seat_lat if location_source == 4
replace lon = seat_lon if location_source == 4

label define location_source 1 "SIGMINE point" 2 "Group average" 3 "Hand-coded" 4 "Town seat"
label values location_source location_source

* How many rights got each source, and what share of royalties that covers.
tab location_source, missing
tab location_source if in_cfem [iweight = royalty_total]

keep process_number process_year lat lon location_source in_cfem ever_concession royalty_total municipality
rename municipality cfem_municipality

label variable process_number "Mining right number"
label variable process_year "Mining right year"
label variable lat "Latitude of the mining right"
label variable lon "Longitude of the mining right"
label variable location_source "Where the location came from"
label variable in_cfem "Ever paid royalties (1 = yes)"
label variable ever_concession "Ever requested or got a mining concession (1 = yes)"
label variable royalty_total "Total royalties paid, all years"
label variable cfem_municipality "Municipality it paid the most royalties in (6-digit)"

order process_number process_year lat lon location_source in_cfem ever_concession royalty_total cfem_municipality

compress
save "$MINES/mine_locations.dta", replace

di as result "Done - saved `=_N' mining rights to $MINES/mine_locations.dta"
