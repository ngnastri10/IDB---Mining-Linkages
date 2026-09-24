* ==========================================================================
* Clean RAIS Vinculos: collapses individual worker-level employment
* records down to active-employment counts by municipality x sector x
* year. One state file at a time (some states are millions of rows), so
* the big raw microdata never all sits in memory or gets saved anywhere -
* only the small collapsed counts do.
*
* Input:
*   <LARGE_DATA_ROOT>/RAIS/raw_txt/<year>/*.txt  (from pull_rais.py)
*
* Output:
*   Working/RAIS/rais_municipality_sector_`year'.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session,
* and pull_rais.py for whatever year this is set to below.
*
* File Organization:
*
*		Section 1: Point at the raw RAIS files for one year
*		Section 2: Import, keep only what we need, and collapse - one
*		           state file at a time
*		Section 3: Append every state together, label, and save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

if "$LARGE_DATA_ROOT" == "" {
    di as error "LARGE_DATA_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Point at the raw RAIS files for one year        ***********
**********															 ***********
********************************************************************************
********************************************************************************

******** SET THE YEAR TO CLEAN HERE - must match a year you already ran pull_rais.py for ********
local year 2015

local RAIS_RAW     "$LARGE_DATA_ROOT/RAIS/raw_txt/`year'"
local RAIS_WORKING "$WORKING_DIR/RAIS"

capture mkdir "$WORKING_DIR/RAIS"

/* Notes:

Vinculos files are one per state - ESTB<year>.txt (or RAIS_ESTAB_PUB.txt
in newer years) is the separate Estabelecimentos file and has a totally
different set of columns, so it's explicitly excluded from the loop below
rather than assumed away.
*/

local state_files : dir "`RAIS_RAW'" files "*.txt"

local vinculos_files
foreach f of local state_files {
    if !strpos(upper("`f'"), "ESTB") & !strpos(upper("`f'"), "ESTAB") {
        local vinculos_files "`vinculos_files' `f'"
    }
}

di as result "Found `:word count `vinculos_files'' vinculos files for `year'"

if "`vinculos_files'" == "" {
    di as error "No .txt files found in `RAIS_RAW'."
    di as error "Run pull_rais.py for `year' first, or check the year set above."
    exit 601
}

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 2: Import, keep only what we need, and collapse -  ***********
********** one state file at a time                                   ***********
**********															 ***********
********************************************************************************
********************************************************************************

tempfile stacked
local first = 1

foreach f of local vinculos_files {

    import delimited using "`RAIS_RAW'/`f'", clear varnames(1) ///
        delimiter(";") encoding("windows-1252")

    /* Notes:

    Only checked this against the 2015 layout - column names shift a bit
    across years (there's a separate layout file per year on the FTP
    server), so if the renames below fail on a different year, run
    `describe` here to see what Stata actually named the columns and fix
    the renames.
    */

    capture rename municipio municipality_code
    capture rename munic_pio municipality_code

    capture rename cnae_20_classe sector_cnae
    capture rename cnae_2_0_classe sector_cnae

    capture rename vinculo_ativo_31_12 active_dec31
    capture rename vinculo_ativo_3112 active_dec31
    capture rename v_nculo_ativo_31_12 active_dec31

    capture confirm variable municipality_code
    if _rc {
        di as error "municipality_code rename failed on `f' - run describe and fix the rename above."
        exit 111
    }
    capture confirm variable sector_cnae
    if _rc {
        di as error "sector_cnae rename failed on `f' - run describe and fix the rename above."
        exit 111
    }
    capture confirm variable active_dec31
    if _rc {
        di as error "active_dec31 rename failed on `f' - run describe and fix the rename above."
        exit 111
    }

    keep municipality_code sector_cnae active_dec31

    * Each destrung separately and wrapped in capture - destring refuses
    * to touch a variable that's already numeric, and whether these come
    * in numeric or string depends on what Stata's auto-detection made of
    * the full ~50-column file, which isn't worth relying on.
    capture destring municipality_code, replace force
    capture destring sector_cnae, replace force
    capture destring active_dec31, replace force

    * Only currently-employed-as-of-Dec-31 vinculos count as employment -
    * a record can exist for a job that already ended mid-year.
    keep if active_dec31 == 1

    collapse (count) employment_count = active_dec31, by(municipality_code sector_cnae)

    if `first' == 1 {
        save `stacked', replace
        local first = 0
    }
    else {
        append using `stacked'
        save `stacked', replace
    }

    di as result "`f' done - `=_N' municipality x sector rows so far"

}

use `stacked', clear

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 3: Append every state together, label, and save    ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* States were collapsed separately, so the same municipality x sector
combo can't repeat within a state, but nothing stops two different state
files from producing the same combo (shouldn't happen if municipality
codes are unique to a state, but summing rather than assuming avoids
silently dropping a duplicate if that assumption is ever wrong). */

collapse (sum) employment_count, by(municipality_code sector_cnae)

generate int year = `year'

label variable municipality_code "IBGE municipality code, from RAIS Municipio"
label variable sector_cnae "Sector, CNAE 2.0 classe (5-digit)"
label variable employment_count "Count of active (Dec 31) vinculos in this municipality x sector x year"
label variable year "Calendar year"

order year municipality_code sector_cnae employment_count

save "`RAIS_WORKING'/rais_municipality_sector_`year'.dta", replace

di as result "Done - saved `=_N' municipality x sector rows to `RAIS_WORKING'/rais_municipality_sector_`year'.dta"
