* ==========================================================================
* Give every mining right a "price group": which World Bank price its
* mineral follows (iron, gold, copper, ...), or blank if it has none.
*
* Why: the "priced" treatment groups and the price shock only use mines of
* minerals with a world price. That drops sand pits, gravel, clay, stone,
* mineral water, etc. So the list in Section 1 decides which mines are in
* the sample - it's a judgment call, and it's all in this one place.
*
* How each right gets its mineral:
*   - Rights that paid royalties (CFEM): the substance it paid the most
*     royalties on. Its price group comes from that substance only, even if
*     that's blank.
*   - Rights that never paid (the pipeline): any priced substance listed
*     for it in the ANM registry. If it lists more than one, the first one
*     in the registry file wins.
*
* Everything matches on the ORIGINAL Portuguese substance names, the same
* way in both sources. The English translation in clean_cfem.do is just for
* labels and can't change who's in the sample.
*
* The 10 price groups match the World Bank price series used in
* build_price_shock.py. Minerals with no World Bank series (manganese,
* niobium, ...) are left out, and so are some that do have one (coal,
* phosphate rock, potash) - see Code/open_decisions.md.
*
* At the end it prints two review tables: every substance we price (with
* number of rights and royalties), and the biggest substances we don't.
*
* Run after build_mine_timeline.do, before build_mine_distances.py.
*
* Input:
*   Working/Mines/CFEM/cfem_process_month.dta
*   LARGE_DATA_ROOT/SCM/microdados/ProcessoSubstancia.txt
*   LARGE_DATA_ROOT/SCM/microdados/Substancia.txt
*
* Output:
*   Working/Mines/mine_price_group.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: The price group list
*		Section 2: Rights that paid royalties (CFEM)
*		Section 3: Rights that never paid (registry)
*		Section 4: Combine, label, and save
*		Section 5: Review tables
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
********** 				Section 1: The price group list              ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

	Exact Portuguese names, not keywords - keywords catch things we don't
	want, like ARGILA FERRUGINOSA (iron-rich clay), OURO PIGMENTO (an
	arsenic mineral, not gold) or AGUA MINERAL FERRUGIN (mineral water).

	Names come from the CFEM data and the registry's Substancia.txt. A
	name only needs to be here once to work for both sources.

	Left out on purpose, to revisit:
	  - gold/tin gravels and rocks: ALUVIAO AURIFERO, CASCALHO AURIFERO,
	    ROCHA AURIFERA, CASCALHO/ROCHA ESTANIFERA (but ALUVIAO ESTANIFERO
	    is in, as tin)
	  - ARGILA BAUXITICA / ARGILA ALUMINOSA (clays, not bauxite)
	  - mixed or by-product minerals: FERRO MANGANES, ILMENO HEMATITA,
	    TITANO MAGNETITA, BAUXITA FOSFOROSA

*/

capture program drop assign_price_group
program define assign_price_group
	* `name' is the variable holding the Portuguese substance name.
	args name

	generate price_group = ""

	replace price_group = "iron"     if inlist(`name', "MINÉRIO DE FERRO", "FERRO", "HEMATITA", "ITABIRITO", "LIMONITA", "MAGNETITA", "LATERITA FERRUGINOSA", "ÓXIDO DE FERRO")
	replace price_group = "gold"     if inlist(`name', "MINÉRIO DE OURO", "OURO", "OURO NATIVO")
	replace price_group = "copper"   if inlist(`name', "MINÉRIO DE COBRE", "COBRE", "COBRE NATIVO", "SULFETOS DE COBRE", "ÓXIDOS DE COBRE", "CARBONATOS DE COBRE", "SILICATOS DE COBRE", "PIRITA DE COBRE")
	replace price_group = "aluminum" if inlist(`name', "MINÉRIO DE ALUMÍNIO", "ALUMÍNIO", "BAUXITA", "LATERITA ALUMINOSA")
	replace price_group = "nickel"   if inlist(`name', "MINÉRIO DE NÍQUEL", "NÍQUEL", "SULFETOS DE NÍQUEL", "SILICATOS DE NÍQUEL", "LATERITA NIQUELÍFERA", "DUNITO NIQUELÍFERO")
	replace price_group = "tin"      if inlist(`name', "MINÉRIO DE ESTANHO", "ESTANHO", "CASSITERITA", "ALUVIÃO ESTANÍFERO", "PIRITA DE ESTANHO")
	replace price_group = "zinc"     if inlist(`name', "MINÉRIO DE ZINCO", "ZINCO", "ZINCITA", "HIDROZINCITA", "SULFETOS DE ZINCO", "ÓXIDOS DE ZINCO", "CARBONATOS DE ZINCO", "SILICATOS DE ZINCO")
	replace price_group = "lead"     if inlist(`name', "MINÉRIO DE CHUMBO", "CHUMBO", "GALENA", "SULFETOS DE CHUMBO", "ÓXIDOS DE CHUMBO", "CARBONATOS DE CHUMBO")
	replace price_group = "silver"   if inlist(`name', "MINÉRIO DE PRATA", "PRATA", "PRATA NATIVA")
	replace price_group = "platinum" if inlist(`name', "MINÉRIO DE PLATINA", "PLATINA", "PLATINA NATIVA", "PLATINA ALUVIONAR", "PLATINIRÍDIO", "PLATINÓIDES")
end

********************************************************************************
********************************************************************************
**********															 ***********
********** 		Section 2: Rights that paid royalties (CFEM)         ***********
**********															 ***********
********************************************************************************
********************************************************************************

use process_number process_year substance_original royalty_value using "$MINES/CFEM/cfem_process_month.dta", clear

drop if missing(process_number) | missing(process_year)

* The substance it paid the most royalties on (same rule as the main
* substance in build_mine_timeline.do, just on the Portuguese name).
collapse (sum) royalty_value, by(process_number process_year substance_original)
bysort process_number process_year: egen royalty_total = total(royalty_value)
bysort process_number process_year (royalty_value): keep if _n == _N

rename substance_original substance_pt
keep process_number process_year substance_pt royalty_total

assign_price_group substance_pt
generate price_group_source = 1

tempfile cfem_rights
save `cfem_rights'

********************************************************************************
********************************************************************************
**********															 ***********
********** 		Section 3: Rights that never paid (registry)         ***********
**********															 ***********
********************************************************************************
********************************************************************************

* Substance names, by registry substance ID.
import delimited using "$LARGE_DATA_ROOT/SCM/microdados/Substancia.txt", ///
	delimiter(";") varnames(1) case(lower) stringcols(_all) encoding("ISO-8859-1") clear

generate substance_pt = strtrim(nmsubstancia)
keep idsubstancia substance_pt

tempfile names
save `names'

* Every substance listed for every mining right.
import delimited using "$LARGE_DATA_ROOT/SCM/microdados/ProcessoSubstancia.txt", ///
	delimiter(";") varnames(1) case(lower) stringcols(_all) encoding("ISO-8859-1") clear

keep dsprocesso idsubstancia

* Remember the file order, so "the first priced substance" is well defined.
generate row = _n

merge m:1 idsubstancia using `names', keep(master match) nogenerate

assign_price_group substance_pt
keep if price_group != ""

* Registry IDs look like "930.641/1989" - split into number (930641) and
* year (1989) so they match CFEM.
generate process_number = real(subinstr(substr(dsprocesso, 1, strpos(dsprocesso, "/") - 1), ".", "", .))
generate process_year   = real(substr(dsprocesso, strpos(dsprocesso, "/") + 1, 4))

drop if missing(process_number) | missing(process_year)

* One row per right: its first priced substance.
bysort process_number process_year (row): keep if _n == 1

* Rights that paid royalties already have their CFEM answer - drop them here.
merge 1:1 process_number process_year using `cfem_rights', keepusing(price_group_source) keep(master) nogenerate

keep process_number process_year substance_pt price_group
generate price_group_source = 2

********************************************************************************
********************************************************************************
**********															 ***********
********** 			Section 4: Combine, label, and save              ***********
**********															 ***********
********************************************************************************
********************************************************************************

append using `cfem_rights'

label define price_group_source 1 "CFEM main substance" 2 "Registry substance"
label values price_group_source price_group_source

label variable process_number "Mining right number"
label variable process_year "Mining right year"
label variable substance_pt "Substance the price group comes from (Portuguese)"
label variable price_group "Priced mineral group (blank = no world price)"
label variable price_group_source "Where the substance came from"
label variable royalty_total "Total royalties paid, all years (CFEM rights only)"

order process_number process_year price_group substance_pt price_group_source royalty_total
sort process_number process_year

compress
save "$MINES/mine_price_group.dta", replace

di as result "Done - saved `=_N' mining rights to $MINES/mine_price_group.dta"

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 5: Review tables                     ***********
**********															 ***********
********************************************************************************
********************************************************************************

* How many rights got a price group, by source.
tab price_group price_group_source, missing

* Review 1: every CFEM substance we price, with how many rights and how
* much royalty money sits behind each name.
preserve
keep if price_group_source == 1
collapse (count) n_rights = process_number (sum) royalty_total, by(price_group substance_pt)
format royalty_total %18.0fc

gsort price_group -royalty_total
list price_group substance_pt n_rights royalty_total if price_group != "", noobs sepby(price_group)

* Review 2: the 30 biggest CFEM substances we DON'T price - check nothing
* here should be in Section 1.
keep if price_group == ""
gsort -royalty_total
list substance_pt n_rights royalty_total in 1/30, noobs
restore

* Review 3: registry substances behind the pipeline rights we price.
preserve
keep if price_group_source == 2
tab substance_pt price_group
restore
