* ==========================================================================
* HPC version of clean_rais_estab.do - same logic, adapted to run
* standalone on the HPC (Unix paths, no config.do - there's only one path
* to set below, same idea as the "cd" at the top of your PATSTAT do-file).
*
* Collapses establishment-level records down to counts by municipality x
* sector x year. Unlike Vinculos, this is one single national file per
* year (not split by state) - 8.3 million rows for 2015 alone - so this
* may take a while to run, but it's still just one import, not a loop.
*
* Input:
*   `HPC_ROOT'/Data/RAIS/raw_txt/`year'/*ESTB*.txt or *ESTAB*.txt
*   (from pull_rais_hpc.py - the one file that isn't a per-state Vinculos file)
*
* Output:
*   `HPC_ROOT'/Data/RAIS/working/rais_estab_municipality_sector_`year'.dta
*
* File Organization:
*
*		Section 1: Find the Estabelecimentos file for one year
*		Section 2: Import, keep only what we need, destring
*		Section 3: Collapse, label, and save
* ==========================================================================

clear all
set more off

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Find the Estabelecimentos file for one year     ***********
**********															 ***********
********************************************************************************
********************************************************************************

******** SET YOUR HPC PATH HERE ********
local HPC_ROOT "/home/nn3495a-hpc/IDB"

******** SET THE YEAR TO CLEAN HERE - must match a year you already ran pull_rais_hpc.py for ********
local year 2015

local RAIS_RAW     "`HPC_ROOT'/Data/RAIS/raw_txt/`year'"
local RAIS_WORKING "`HPC_ROOT'/Data/RAIS/working"

* Stata's mkdir only creates one new level at a time (unlike Python's),
* so this builds the chain up piece by piece in case none of it exists
* yet - capture swallows the harmless "already exists" error at each step.
capture mkdir "`HPC_ROOT'"
capture mkdir "`HPC_ROOT'/Data"
capture mkdir "`HPC_ROOT'/Data/RAIS"
capture mkdir "`HPC_ROOT'/Data/RAIS/working"

local all_files : dir "`RAIS_RAW'" files "*.txt"

local estab_file
foreach f of local all_files {
    if strpos(upper("`f'"), "ESTB") | strpos(upper("`f'"), "ESTAB") {
        local estab_file "`f'"
    }
}

if "`estab_file'" == "" {
    di as error "No Estabelecimentos file found in `RAIS_RAW'."
    di as error "Run pull_rais_hpc.py for `year' first, or check the year set above."
    exit 601
}

di as result "Using `estab_file'"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 2: Import, keep only what we need, destring        ***********
**********															 ***********
********************************************************************************
********************************************************************************

import delimited using "`RAIS_RAW'/`estab_file'", clear varnames(1) ///
    delimiter(";") encoding("windows-1252")

/* Notes:

Only checked this against the 2015 layout - column names shift a bit
across years, so if the renames below fail on a different year, run
`describe` here to see what Stata actually named the columns and fix
the renames.

"Qtd Vinculos Ativos" is a headline number here - it's each
establishment's own count of active-Dec-31 employees, already computed by
the Ministry of Labor, not something we have to derive ourselves the way
we did from the Vinculos file. Summed across establishments in a
municipality x sector, this should land close to what clean_rais.do
produces from Vinculos - a useful cross-check.

"Ind Rais Negativa" flags an establishment that filed a "zero employees
this year" declaration - a real, required filing, not missing data.
Keeping these rather than dropping them (their vinculos count is already
0, so they don't distort the employment sums either way), but keeping
a count of how many per group in case that matters for the analysis.
*/

capture rename municipio municipality_code
capture rename munic_pio municipality_code

capture rename cnae_20_classe sector_cnae
capture rename cnae_2_0_classe sector_cnae

capture rename qtd_v_nculos_ativos active_vinculos
capture rename qtd_vinculos_ativos active_vinculos

capture rename qtd_v_nculos_clt clt_vinculos
capture rename qtd_vinculos_clt clt_vinculos

capture rename qtd_v_nculos_estatut_rios statutory_vinculos
capture rename qtd_vinculos_estatutarios statutory_vinculos
capture rename qtd_v_nculos_estatutarios statutory_vinculos

capture rename ind_rais_negativa rais_negativa

capture rename natureza_jur_dica legal_nature
capture rename natureza_juridica legal_nature

foreach v in municipality_code sector_cnae active_vinculos clt_vinculos statutory_vinculos rais_negativa legal_nature {
    capture confirm variable `v'
    if _rc {
        di as error "`v' rename failed on `estab_file' - run describe and fix the rename above."
        exit 111
    }
}

keep municipality_code sector_cnae active_vinculos clt_vinculos statutory_vinculos rais_negativa legal_nature

* Each destrung separately and wrapped in capture - see clean_rais_hpc.do
* for why (destring refuses to touch an already-numeric variable).
foreach v in municipality_code sector_cnae active_vinculos clt_vinculos statutory_vinculos rais_negativa legal_nature {
    capture destring `v', replace force
}

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 3: Collapse, label, and save                       ***********
**********															 ***********
********************************************************************************
********************************************************************************

collapse (count) n_establishments = active_vinculos ///
         (sum) active_vinculos clt_vinculos statutory_vinculos n_rais_negativa = rais_negativa, ///
         by(municipality_code sector_cnae)

generate int year = `year'

label variable municipality_code "IBGE municipality code, from RAIS Municipio"
label variable sector_cnae "Sector, CNAE 2.0 classe (5-digit)"
label variable n_establishments "Count of establishments in this municipality x sector x year"
label variable active_vinculos "Sum of each establishment's active (Dec 31) employee count"
label variable clt_vinculos "Sum of each establishment's CLT (private-sector formal) employee count"
label variable statutory_vinculos "Sum of each establishment's statutory (public-sector) employee count"
label variable n_rais_negativa "Count of establishments that filed a zero-employee (RAIS Negativa) declaration"
label variable year "Calendar year"

order year municipality_code sector_cnae n_establishments active_vinculos clt_vinculos statutory_vinculos n_rais_negativa

save "`RAIS_WORKING'/rais_estab_municipality_sector_`year'.dta", replace

di as result "Done - saved `=_N' municipality x sector rows to `RAIS_WORKING'/rais_estab_municipality_sector_`year'.dta"
