* ==========================================================================
* Clean RAIS Estabelecimentos: collapses establishment-level records down
* to counts by municipality x sector x year. Unlike Vinculos, this is one
* single national file per year (not split by state) - 8.3 million rows
* for 2015 alone - so this may take a while to run, but it's still just
* one import, not a loop.
*
* This local version stays single-year and assumes an already-extracted
* .txt is sitting in raw_txt/<year>/ - pull_rais.py deliberately does NOT
* decompress locally (see its own notes: .7z files get transferred to the
* HPC and extracted there instead), so this is really a convenience/
* testing script for whatever year you've extracted by hand. The real,
* full 2000-2025 run - unzip logic (both .7z and .zip), the year loop,
* building up the All_Years file - lives in HPC/clean_rais_estab_hpc.do.
*
* Merge keys (municipality, cnae95/cnae2/cnae2_subclass, year) use the
* exact same variable names as clean_rais.do's Vinculos output on
* purpose, so a future merge is a plain 1:1 join. Every other variable
* gets an "estab_" prefix so nothing collides once merged, and output
* lands in its own Estab/ subfolder, kept separate from wherever the
* Vinculos pipeline writes.
*
* Same idea as clean_rais.do's three Vinculos outputs: sector here means
* three different things depending on granularity, saved as three
* separate files rather than one, since they cover different year ranges
* and a downstream merge should pick the one it actually needs:
*   - CNAE95: every year 2000-2025.
*   - CNAE 2.0 Classe: 2007 onward (doesn't exist before that).
*   - CNAE 2.0 Subclasse: 2007 onward too - confirmed against real
*     headers this exists in Estabelecimentos every year CNAE 2.0 does,
*     same as Vinculos (where Subclasse also goes back to 2006/2007).
*
* Input:
*   <LARGE_DATA_ROOT>/RAIS/raw_txt/<year>/ - a file with "ESTB" or "ESTAB"
*   somewhere in its name (from pull_rais.py + manual/HPC extraction - not the per-state
*   Vinculos files)
*
* Output:
*   Working/RAIS/Estab/<foldername>/cleaned_estab_`year'.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session,
* and pull_rais.py + extraction for whatever year this is set to below.
*
* File Organization:
*
*		Section 1: Find the Estabelecimentos file for one year
*		Section 2: Import, rename, keep, destring
*		Section 3: Collapse, label, and save - once per CNAE granularity
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
********** Section 1: Find the Estabelecimentos file for one year     ***********
**********															 ***********
********************************************************************************
********************************************************************************

******** SET THE YEAR TO CLEAN HERE - must match a year you already ran pull_rais.py + extraction for ********
local year 2015

local RAIS_RAW     "$LARGE_DATA_ROOT/RAIS/raw_txt/`year'"
local RAIS_WORKING "$WORKING_DIR/RAIS/Estab"

capture mkdir "$WORKING_DIR/RAIS/Estab"

local all_files : dir "`RAIS_RAW'" files "*.txt"

local estab_file
foreach f of local all_files {
    if strpos(upper("`f'"), "ESTB") | strpos(upper("`f'"), "ESTAB") {
        local estab_file "`f'"
    }
}

if "`estab_file'" == "" {
    di as error "No Estabelecimentos file found in `RAIS_RAW'."
    di as error "Run pull_rais.py + extraction for `year' first, or check the year set above."
    exit 601
}

di as result "Using `estab_file'"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 2: Import, rename, keep, destring                  ***********
**********															 ***********
********************************************************************************
********************************************************************************

import delimited using "`RAIS_RAW'/`estab_file'", clear varnames(1) ///
    delimiter(";") encoding("windows-1252")

/* Notes:

Real headers checked directly across 2000-2025 (see
explore_rais_estab_headers.log) rather than assumed - years drift a lot
here:

- 2000/2001 use short, different terminology - checked against the real
  Ministry layout file for 2001 (RAIS_estabelecimento_layout2001.xls),
  not guessed. ESTOQUE = "Estoque de vínculos ativos em 31/12" - the
  same active-headcount concept as "Qtd Vínculos Ativos" later, so it
  maps directly to estab_total_employees. ESTOQUE ESTA = "...sob o
  regime estatutário..." - a clean match for estab_public_employees
  (2001 only, 2000 has neither field, just the one combined ESTOQUE).
  EST CLT OUT = "...sob o regime CLT E OUTROS..." - close to
  estab_private_employees but not a pure match, it's CLT plus other
  regimes combined for that one year; mapped anyway since it's the
  closest real signal available, but the label below flags the caveat.
- CNAE 95 Classe exists every year 2000-2025 - required, not optional.
  CNAE 2.0 Classe and CNAE 2.0 Subclasse both don't exist before 2007,
  but both are present every year from 2007 on - confirmed directly
  against the header log, they arrive together, same as in Vinculos
  (where both go back to 2006/2007). All three optional except CNAE95.
- 2023+ switches to comma-delimited with quoted, "- Código"-suffixed
  headers, same as Vinculos did around the same time.

municipality and cnae95/cnae2/cnae2_subclass are named to match
clean_rais.do's Vinculos output exactly - these are the merge keys for
the eventual merge script. Everything else gets an "estab_" prefix so
nothing collides once merged.

"Qtd Vinculos Ativos" (and its 2000/2001 equivalent) is a headline
number here - it's each establishment's own count of active-Dec-31
employees, already computed by the Ministry of Labor, not something we
have to derive ourselves the way we did from the Vinculos file. Summed
across establishments in a municipality x sector, this should land close
to what clean_rais.do produces from Vinculos - a useful cross-check.

"Ind Rais Negativa" flags an establishment that filed a "zero employees
this year" declaration - a real, required filing, not missing data.
Keeping these rather than dropping them (their employee count is already
0, so they don't distort the employment sums either way), but keeping
a count of how many per group in case that matters for the analysis.
*/

** Municipality (merge key - matches Vinculos naming) **
capture rename municipio municipality
capture rename município municipality
capture rename municípiocódigo municipality

** Sector, CNAE 95 Classe (merge key - present every year 2000-2025) **
capture rename clascnae95 cnae95
capture rename cnae95classe cnae95
capture rename cnae95classecódigo cnae95

** Sector, CNAE 2.0 Classe (merge key - doesn't exist before 2007) **
capture rename cnae20classe cnae2
capture rename cnae20classecódigo cnae2

** Sector, CNAE 2.0 Subclasse (merge key - doesn't exist before 2007) **
capture rename cnae20subclasse cnae2_subclass
capture rename cnae20subclassecodigo cnae2_subclass

* cnae2/cnae2_subclass carry a trailing check digit in the raw data
* that isn't part of the real classification code - confirmed directly
* against a real raw file: Classe "01113" is base code 0111 plus check
* digit 3, not the number 1113. Subclasse embeds the check digit in the
* middle instead of the end: "9499500" is base 9499 + check digit 5 +
* subclass suffix 00, not 9499500 itself. Without stripping these,
* cnae2 doesn't match the CNAE67 crosswalk (which uses the real base
* code) at all. tostring first (format-padded) in case Stata
* auto-imported the column as numeric and dropped the leading zero -
* capture wraps both since cnae2/cnae2_subclass may not exist yet this
* year (years before 2007), same reasoning as the destring loop below.
capture tostring cnae2, replace format(%05.0f)
capture replace cnae2 = substr(cnae2, 1, 4)
capture tostring cnae2_subclass, replace format(%07.0f)
capture replace cnae2_subclass = substr(cnae2_subclass, 1, 4) + substr(cnae2_subclass, 6, 2)

** Total employees (Dec 31 headcount, Ministry-computed) **
capture rename estoque estab_total_employees
capture rename qtdvínculosativos estab_total_employees
capture rename qtdvinculosativos estab_total_employees

** Private-sector employees (CLT). 2001's "EST CLT OUT" is CLT + Outros
** combined, not pure CLT - closest real signal available that year, but
** not an exact match (see notes above). 2000 has no equivalent field at
** all. **
capture rename qtdvínculosclt estab_private_employees
capture rename qtdvinculosclt estab_private_employees
capture rename estcltout estab_private_employees

** Public-sector employees (statutory). Confirmed exact match for 2001's
** "ESTOQUE ESTA" against the real layout file - 2000 has no equivalent
** field at all. **
capture rename qtdvínculosestatutários estab_public_employees
capture rename qtdvinculosestatutarios estab_public_employees
capture rename estoqueesta estab_public_employees

** Zero-employee filing flag (RAIS Negativa) **
capture rename indraisneg estab_noemployees_flag
capture rename indraisnegativa estab_noemployees_flag
capture rename indraisnegativacódigo estab_noemployees_flag

** Legal nature **
capture rename natjurid estab_legal_nature
capture rename naturezajurídica estab_legal_nature
capture rename naturezajurídicacódigo estab_legal_nature

* municipality, cnae95, estab_total_employees, estab_noemployees_flag,
* and estab_legal_nature exist in every year 2000-2025. cnae2,
* cnae2_subclass, estab_private_employees, and estab_public_employees
* don't - see notes above.
local needed_vars municipality cnae95 estab_total_employees ///
    estab_noemployees_flag estab_legal_nature
local optional_vars cnae2 cnae2_subclass estab_private_employees estab_public_employees

foreach v of local needed_vars {
    capture confirm variable `v'
    if _rc {
        di as error "`v' rename failed on `estab_file' - run describe and fix the rename above."
        exit 111
    }
}

foreach v of local optional_vars {
    capture confirm variable `v'
    if _rc {
        generate float `v' = .
    }
}

keep `needed_vars' `optional_vars'

* Each destrung separately and wrapped in capture - see clean_rais.do for
* why (destring refuses to touch an already-numeric variable).
foreach v of local needed_vars {
    capture destring `v', replace force
}
foreach v of local optional_vars {
    capture destring `v', replace force
}

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 3: Collapse, label, and save - once per CNAE       ***********
********** granularity                                                ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Note:

Same reasoning as clean_rais.do's three Vinculos outputs: CNAE95 is
grouped for every year, CNAE 2.0 Classe and CNAE 2.0 Subclasse only for
years they actually exist (both 2007+, confirmed they arrive together
in the header log) - built with the same cond()-based year check rather
than running (and wasting output on) a collapse that would just be
constant missing for years the field doesn't apply to.

*/

local collapse_vars "cnae95"
if `year' >= 2007 {
    local collapse_vars "`collapse_vars' cnae2 cnae2_subclass"
}

foreach sector_var of local collapse_vars {

    local foldername = cond("`sector_var'" == "cnae95", "CNAE95", ///
                        cond("`sector_var'" == "cnae2", "CNAE2", ///
                        "CNAE2_subclass"))

    preserve

    collapse (count) estab_n_establishments = estab_total_employees ///
             (sum) estab_total_employees estab_private_employees estab_public_employees ///
             estab_total_noemployees = estab_noemployees_flag, ///
             by(municipality `sector_var')

    generate int year = `year'

    label variable municipality "IBGE municipality code"
    label variable `sector_var' "Sector, `foldername'"
    label variable estab_n_establishments "Number of establishments"
    label variable estab_total_employees "Total employees"
    label variable estab_private_employees "Private-sector employees"
    label variable estab_public_employees "Public-sector employees"
    label variable estab_total_noemployees "Establishments with no employees"
    label variable year "Calendar year"

    order year municipality `sector_var' estab_n_establishments estab_total_employees estab_private_employees estab_public_employees estab_total_noemployees

    capture mkdir "`RAIS_WORKING'/`foldername'"
    save "`RAIS_WORKING'/`foldername'/cleaned_estab_`year'.dta", replace

    di as result "Done - saved `=_N' municipality x `foldername' rows to `RAIS_WORKING'/`foldername'/cleaned_estab_`year'.dta"

    restore

}
