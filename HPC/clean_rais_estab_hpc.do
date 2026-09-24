* ==========================================================================
* HPC version of clean_rais_estab.do - unzips, cleans, and collapses RAIS
* Estabelecimentos for every year in the range below, same overall shape
* as clean_rais_scrap_hpc.do's Vinculos pipeline (self-extracting,
* year loop, resume mode, builds up an All_Years file per output type)
* but simpler - Estabelecimentos is one single national file per year,
* not split by state, so there's no per-state loop or "append all
* states" step needed.
*
* Output lives in its own Estab/ subfolder, kept separate from wherever
* the Vinculos pipeline writes, so the two can be built/rerun completely
* independently and merged together later with a separate script. Merge
* keys (municipality, cnae95/cnae2/cnae2_subclass, year) use the exact
* same variable names as the Vinculos output on purpose, so that future
* merge is a plain 1:1 join. Every other variable gets an "estab_"
* prefix so nothing collides once the two are merged.
*
* Same idea as clean_rais_hpc.do's three Vinculos outputs: sector here
* means three different things depending on granularity, saved as three
* separate files rather than one, since they cover different year ranges:
*   - CNAE95: every year 2000-2025.
*   - CNAE 2.0 Classe: 2007 onward (doesn't exist before that).
*   - CNAE 2.0 Subclasse: 2007 onward too - confirmed against real
*     headers this exists in Estabelecimentos every year CNAE 2.0 does,
*     same as Vinculos (where Subclasse also goes back to 2006/2007).
*
* Input:
*   `HPC_ROOT'/Data/RAIS/raw_7z/`year'/ - an archive with "ESTB" or "ESTAB"
*   somewhere in its name, .7z or .zip (from pull_rais_hpc.py)
*
* Output:
*   `HPC_ROOT'/Mining/Working/RAIS/Estab/<foldername>/cleaned_estab_`year'.dta
*   `HPC_ROOT'/Mining/Working/RAIS/Estab/All_Years/<foldername>/cleaned_all_years.dta
*
* File Organization:
*
*		Section 1: Unzip the Estabelecimentos file for one year
*		Section 2: Import, rename, keep, destring
*		Section 3: Collapse, label, save - once per CNAE granularity
*		Section 4: Fold this year into the running All_Years file -
*		           always runs, even for years resume mode skipped
*		           past Sections 1-3 for
* ==========================================================================

clear all
set more off

******** SET YOUR HPC PATH HERE ********
local HPC_ROOT "/home/nn3495a-hpc/IDB"

* Explicit log, on top of whatever -b batch mode makes on its own - this
* way there's a real log even if something goes wrong before Stata's own
* automatic logging would've kicked in. capture log close first in case a
* prior crashed run left one open.
capture log close
log using "`HPC_ROOT'/Mining/Code/clean_rais_estab_hpc_run.log", replace text

******** SET THE YEAR RANGE HERE - must match years you've already run pull_rais_hpc.py for ********
local startyear 2000
local endyear 2025

* RESUME MODE - on/off switch.
*   1 = a year whose per-year output already exists on disk for every
*       collapse type that applies to it gets skipped past Sections 1-3
*       (the expensive unzip/import/clean/collapse work) - only Section
*       4 (folding it into the across-years file) runs for it, reading
*       whatever's already there. Use this to pick back up after a
*       crash/interruption without redoing years that already finished.
*   0 = every year in the range gets fully reprocessed from scratch
*       regardless of what's already on disk - use this if the cleaning
*       logic itself changed and old output can't be trusted anymore.
local resume_mode = 1

local RAIS_WORKING "`HPC_ROOT'/Mining/Working/RAIS"

* CNAE67 crosswalk (IBGE's 67-sector national-accounts activity
* classification) - built once here, not inside the year loop below,
* since it's the same file every year, and shared with the Vinculos
* pipeline (same file path) - if that job already built it, this just
* finds it already there. See build_cnae67_crosswalk.py for the actual
* download/cleaning logic.
capture confirm file "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta"
if _rc {
	capture mkdir "`HPC_ROOT'"
	capture mkdir "`HPC_ROOT'/Data"
	capture mkdir "`HPC_ROOT'/Data/Crosswalks"
	shell python3 "`HPC_ROOT'/Mining/Code/build_cnae67_crosswalk.py" "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta"

	* shell doesn't check whether the script it ran actually succeeded -
	* it just moves on regardless, so confirm the file is really there
	* now rather than let a failed build cascade into a confusing error
	* several steps later.
	capture confirm file "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta"
	if _rc {
		di as error "build_cnae67_crosswalk.py did not produce the crosswalk file - run it directly (not through Stata) to see the real error."
		exit 601
	}
}

forvalues year = `startyear'/`endyear' {

	di as result "=========================================="
	di as result "YEAR `year'"
	di as result "=========================================="

	* cnae2/cnae2_subclass only exist from 2007 onward - this determines
	* which collapse types (and so which folders/output files) apply to
	* this year. Computed once here and reused throughout (the resume
	* check right below, Section 3, and Section 4).
	local collapse_vars "cnae95"
	if `year' >= 2007 {
		local collapse_vars "`collapse_vars' cnae2 cnae2_subclass cnae67"
	}

	* RESUME CHECK - a year only counts as "already done" if EVERY
	* collapse type that applies to it already has its per-year file on
	* disk, not just some of them - same reasoning as the Vinculos
	* pipeline's resume check (an incomplete year should never be
	* mistaken for a done one).
	local year_done = 1
	foreach sector_var of local collapse_vars {
		local foldername = cond("`sector_var'" == "cnae95", "CNAE95", ///
							cond("`sector_var'" == "cnae2", "CNAE2", ///
							cond("`sector_var'" == "cnae2_subclass", "CNAE2_subclass", ///
							"CNAE67")))
		capture confirm file "`RAIS_WORKING'/Estab/`foldername'/cleaned_estab_`year'.dta"
		if _rc {
			local year_done = 0
		}
	}

	if `resume_mode' == 1 & `year_done' == 1 {

		di as result "Year `year' - resume_mode on and already fully processed, skipping straight to Section 4."

	}
	else {

	********************************************************************************
	********************************************************************************
	**********															 ***********
	********** Section 1: Unzip the Estabelecimentos file for one year    ***********
	**********															 ***********
	********************************************************************************
	********************************************************************************

	local RAIS_RAW_7Z "`HPC_ROOT'/Data/RAIS/raw_7z/`year'"
	local RAIS_RAW    "`HPC_ROOT'/Data/RAIS/raw_txt/`year'"

	capture mkdir "`HPC_ROOT'/Data/RAIS/raw_txt"
	capture mkdir "`RAIS_RAW'"

	* Reset every iteration - if raw_7z/`year' doesn't exist at all, the
	* dir calls below error and get captured, so this avoids silently
	* reusing a stale list from the previous year.
	local archives_7z ""
	local archives_zip ""
	capture local archives_7z : dir "`RAIS_RAW_7Z'" files "*.7z"
	capture local archives_zip : dir "`RAIS_RAW_7Z'" files "*.zip"
	local all_archives "`archives_7z' `archives_zip'"

	local estab_archive ""
	foreach f of local all_archives {
		if strpos(upper("`f'"), "ESTB") | strpos(upper("`f'"), "ESTAB") {
			local estab_archive "`f'"
		}
	}

	if "`estab_archive'" == "" {
		di as error "No ESTB/ESTAB .7z/.zip archive found for `year' - skipping."
		continue
	}

	local archive_ext = cond(strpos(upper("`estab_archive'"), ".ZIP") > 0, "zip", "7z")

	* Extract into an isolated temp subfolder regardless of format, then
	* just take whatever's the only file in there - confirmed on 2002
	* that a .zip's internal filename does NOT reliably match the
	* archive's own name (Estb2002.zip extracted to something called
	* consulta21554418.txt), so there's no point guessing a filename.
	capture mkdir "`RAIS_RAW'/_estab_temp"
	if "`archive_ext'" == "zip" {
		shell python3 -c "import zipfile; zipfile.ZipFile('`RAIS_RAW_7Z'/`estab_archive'').extractall('`RAIS_RAW'/_estab_temp')"
	}
	else {
		shell python3 -c "import py7zr; py7zr.SevenZipFile('`RAIS_RAW_7Z'/`estab_archive'').extractall('`RAIS_RAW'/_estab_temp')"
	}

	local temp_contents : dir "`RAIS_RAW'/_estab_temp" files "*"
	local n_temp_files : word count `temp_contents'

	if `n_temp_files' == 0 {
		di as error "Extraction produced no files for `year' - skipping."
		capture rmdir "`RAIS_RAW'/_estab_temp"
		continue
	}

	local estab_file : word 1 of `temp_contents'
	shell mv "`RAIS_RAW'/_estab_temp/`estab_file'" "`RAIS_RAW'/`estab_file'"
	capture rmdir "`RAIS_RAW'/_estab_temp"

	di as result "Using `estab_file' (from `estab_archive')"

	********************************************************************************
	********************************************************************************
	**********															 ***********
	********** Section 2: Import, rename, keep, destring                  ***********
	**********															 ***********
	********************************************************************************
	********************************************************************************

	* Delimiter inferred from extension - "txt"-like has meant semicolon
	* everywhere checked so far (2000-2021), "COMT"-like has meant comma
	* (2023+). Same lesson as Vinculos.
	local raw_delim = cond(strpos(upper("`estab_file'"), ".TXT") > 0, ";", ",")

	import delimited using "`RAIS_RAW'/`estab_file'", clear varnames(1) ///
		delimiter("`raw_delim'") encoding("windows-1252")

	/* Notes:

	Real headers checked directly across 2000-2025 (see
	explore_rais_estab_headers.log) rather than assumed - years drift a
	lot here:

	- 2000/2001 use short, different terminology - checked against the
	  real Ministry layout file for 2001
	  (RAIS_estabelecimento_layout2001.xls), not guessed. ESTOQUE =
	  "Estoque de vínculos ativos em 31/12" - the same active-headcount
	  concept as "Qtd Vínculos Ativos" later, so it maps directly to
	  estab_total_employees. ESTOQUE ESTA = "...sob o regime
	  estatutário..." - a clean match for estab_public_employees (2001
	  only, 2000 has neither field, just the one combined ESTOQUE). EST
	  CLT OUT = "...sob o regime CLT E OUTROS..." - close to
	  estab_private_employees but not a pure match, it's CLT plus other
	  regimes combined for that one year; mapped anyway since it's the
	  closest real signal available, but the label below flags the
	  caveat.
	- CNAE 95 Classe exists every year 2000-2025 - required, not
	  optional. CNAE 2.0 Classe and CNAE 2.0 Subclasse both don't exist
	  before 2007, but both are present every year from 2007 on -
	  confirmed directly against the header log, they arrive together,
	  same as in Vinculos (where both go back to 2006/2007). All three
	  optional except CNAE95.
	- 2023+ switches to comma-delimited with quoted, "- Código"-suffixed
	  headers, same as Vinculos did around the same time.

	municipality and cnae95/cnae2/cnae2_subclass are named to match the
	Vinculos output exactly - these are the merge keys for the eventual
	merge script. Everything else gets an "estab_" prefix so nothing
	collides once merged.

	"Qtd Vinculos Ativos" (and its 2000/2001 equivalent) is a headline
	number here - it's each establishment's own count of active-Dec-31
	employees, already computed by the Ministry of Labor, not something
	we have to derive ourselves the way we did from the Vinculos file.
	Summed across establishments in a municipality x sector, this should
	land close to what the Vinculos pipeline produces - a useful
	cross-check once merged.

	"Ind Rais Negativa" flags an establishment that filed a "zero
	employees this year" declaration - a real, required filing, not
	missing data. Keeping these rather than dropping them (their
	employee count is already 0, so they don't distort the employment
	sums either way), but keeping a count of how many per group in case
	that matters for the analysis.
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
	* that isn't part of the real classification code - confirmed
	* directly against a real raw file: Classe "01113" is base code 0111
	* plus check digit 3, not the number 1113. Subclasse embeds the check
	* digit in the middle instead of the end: "9499500" is base 9499 +
	* check digit 5 + subclass suffix 00, not 9499500 itself. Without
	* stripping these, cnae2 doesn't match the CNAE67 crosswalk (which
	* uses the real base code) at all - confirmed this broke the cnae67
	* merge, only ~4 of 67 codes matched, mostly by coincidence.
	* tostring first (format-padded) in case Stata auto-imported the
	* column as numeric and dropped the leading zero - capture wraps
	* both since cnae2/cnae2_subclass may not exist yet this year (years
	* before 2007), same reasoning as the destring loop below.
	capture tostring cnae2, replace format(%05.0f)
	capture replace cnae2 = substr(cnae2, 1, 4)
	capture tostring cnae2_subclass, replace format(%07.0f)
	capture replace cnae2_subclass = substr(cnae2_subclass, 1, 4) + substr(cnae2_subclass, 6, 2)

	** Total employees (Dec 31 headcount, Ministry-computed) **
	capture rename estoque estab_total_employees
	capture rename qtdvínculosativos estab_total_employees
	capture rename qtdvinculosativos estab_total_employees

	** Private-sector employees (CLT). 2001's "EST CLT OUT" is CLT +
	** Outros combined, not pure CLT - closest real signal available
	** that year, but not an exact match (see notes above). 2000 has no
	** equivalent field at all. **
	capture rename qtdvínculosclt estab_private_employees
	capture rename qtdvinculosclt estab_private_employees
	capture rename estcltout estab_private_employees

	** Public-sector employees (statutory). Confirmed exact match for
	** 2001's "ESTOQUE ESTA" against the real layout file - 2000 has no
	** equivalent field at all. **
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

	local rename_failed = 0
	foreach v of local needed_vars {
		capture confirm variable `v'
		if _rc {
			di as error "`v' rename failed on `estab_file' (`year') - run describe and fix the rename above."
			local rename_failed = 1
		}
	}

	if `rename_failed' == 1 {
		erase "`RAIS_RAW'/`estab_file'"
		continue
	}

	foreach v of local optional_vars {
		capture confirm variable `v'
		if _rc {
			generate float `v' = .
		}
	}

	keep `needed_vars' `optional_vars'

	* Each destrung separately and wrapped in capture - see
	* clean_rais_hpc.do for why (destring refuses to touch an
	* already-numeric variable).
	foreach v of local needed_vars {
		capture destring `v', replace force
	}
	foreach v of local optional_vars {
		capture destring `v', replace force
	}

	********************************************************************************
	********************************************************************************
	**********															 ***********
	********** Section 3: Collapse, label, save - once per CNAE           ***********
	********** granularity                                                ***********
	**********															 ***********
	********************************************************************************
	********************************************************************************

	/* Note:

	Same reasoning as clean_rais_hpc.do's three Vinculos outputs: CNAE95
	is grouped for every year, CNAE 2.0 Classe and CNAE 2.0 Subclasse
	only for years they actually exist (both 2007+, confirmed they
	arrive together in the header log) - built with the same
	cond()-based year check rather than running (and wasting output on)
	a collapse that would just be constant missing for years the field
	doesn't apply to.

	*/

	foreach sector_var of local collapse_vars {

		local foldername = cond("`sector_var'" == "cnae95", "CNAE95", ///
							cond("`sector_var'" == "cnae2", "CNAE2", ///
							cond("`sector_var'" == "cnae2_subclass", "CNAE2_subclass", ///
							"CNAE67")))

		preserve

		* CNAE67 only merged in on the pass that's actually collapsing by
		* it - by() below just references `sector_var' directly, so
		* cnae67 only needs to exist during this one pass, no separate
		* exclusion-list bookkeeping needed the way Vinculos's ds-based
		* collapse required (Estab's collapse uses explicit named
		* variables, not a generic exclusion list).
		if "`sector_var'" == "cnae67" {
			merge m:1 cnae2 using "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta", keep(master match) nogenerate
		}

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

		order year municipality `sector_var' estab_n_establishments ///
			estab_total_employees estab_private_employees estab_public_employees estab_total_noemployees

		capture mkdir "`RAIS_WORKING'/Estab"
		capture mkdir "`RAIS_WORKING'/Estab/`foldername'"
		save "`RAIS_WORKING'/Estab/`foldername'/cleaned_estab_`year'.dta", replace

		di as result "Done - saved `=_N' municipality x `foldername' rows for `year'"

		restore

	}

	erase "`RAIS_RAW'/`estab_file'"

	} // closes the "else" opened after the resume check above - Sections
	  // 1-3 only run when this year wasn't already fully done.

	********************************************************************************
	********************************************************************************
	**********															 ***********
	********** Section 4: Fold this year into the running All_Years file  ***********
	**********															 ***********
	********************************************************************************
	********************************************************************************

	* Always runs, whether Sections 1-3 above ran or got skipped by resume
	* mode - reads whichever per-year files exist (freshly made above, or
	* already on disk from an earlier run) and folds them into the
	* running All_Years file. collapse_vars was computed once at the top
	* of the year loop, reused here.
	foreach sector_var of local collapse_vars {

		local foldername = cond("`sector_var'" == "cnae95", "CNAE95", ///
							cond("`sector_var'" == "cnae2", "CNAE2", ///
							cond("`sector_var'" == "cnae2_subclass", "CNAE2_subclass", ///
							"CNAE67")))

		capture confirm file "`RAIS_WORKING'/Estab/`foldername'/cleaned_estab_`year'.dta"
		if _rc {
			di as error "Section 4: no per-year file for `year' `foldername' - Sections 1-3 likely found no data this year, skipping fold-in."
			continue
		}

		use "`RAIS_WORKING'/Estab/`foldername'/cleaned_estab_`year'.dta", clear

		* Check whether this foldername's All_Years file actually exists
		* yet, rather than comparing to `startyear' - cnae2 and
		* cnae2_subclass don't start until 2007, so "first year we've
		* ever seen this foldername" isn't the same thing as "first year
		* of the whole run" for those two.
		capture mkdir "`RAIS_WORKING'/Estab/All_Years"
		capture mkdir "`RAIS_WORKING'/Estab/All_Years/`foldername'"
		capture confirm file "`RAIS_WORKING'/Estab/All_Years/`foldername'/cleaned_all_years.dta"
		if _rc {
			save "`RAIS_WORKING'/Estab/All_Years/`foldername'/cleaned_all_years.dta", replace
		}
		else {
			append using "`RAIS_WORKING'/Estab/All_Years/`foldername'/cleaned_all_years.dta"
			save "`RAIS_WORKING'/Estab/All_Years/`foldername'/cleaned_all_years.dta", replace
		}

	}

}

log close
