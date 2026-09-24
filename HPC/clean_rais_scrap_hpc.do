
******** SET YOUR HPC PATH HERE ********
local HPC_ROOT "/home/nn3495a-hpc/IDB/"

* Explicit log, on top of whatever -b batch mode makes on its own - this
* way there's a real log even if something goes wrong before Stata's own
* automatic logging would've kicked in. capture log close first in case a
* prior crashed run left one open.
capture log close
log using "`HPC_ROOT'/Mining/Code/clean_rais_scrap_hpc_run.log", replace text

local startyear = 2000
local endyear = 2025

* RESUME MODE - on/off switch.
*   1 = a year whose combined output already exists on disk for every
*       collapse type that applies to it gets skipped past Sections 1-4
*       (the expensive unzip/import/clean/collapse-per-state work) -
*       only Section 5 (rebuilding the across-years file) runs for it,
*       reading whatever's already there. Use this to pick back up after
*       a crash/interruption without redoing years that already finished.
*   0 = every year in the range gets fully reprocessed from scratch
*       regardless of what's already on disk - use this if the cleaning
*       logic itself changed and old output can't be trusted anymore.
local resume_mode = 1

* CNAE67 crosswalk (IBGE's 67-sector national-accounts activity
* classification) - built once here, not inside the year loop below,
* since it's the same file every year. See build_cnae67_crosswalk.py
* for the actual download/cleaning logic.
capture confirm file "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta"
if _rc {
	capture mkdir "`HPC_ROOT'"
	capture mkdir "`HPC_ROOT'/Data"
	capture mkdir "`HPC_ROOT'/Data/Crosswalks"
	shell python3 "`HPC_ROOT'/Mining/Code/build_cnae67_crosswalk.py" "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta"

	* shell doesn't check whether the script it ran actually succeeded -
	* it just moves on regardless, so confirm the file is really there
	* now. Without this, a failed download/build here silently turns
	* into a confusing "variable cnae67 not found" several steps later
	* instead of a clear error right where the real problem is.
	capture confirm file "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta"
	if _rc {
		di as error "build_cnae67_crosswalk.py did not produce the crosswalk file - run it directly (not through Stata) to see the real error."
		exit 601
	}
}

forvalues year = `startyear'/`endyear' {

	* cnae2/cnae2_subclass only exist from 2006 onward - this determines
	* which collapse types (and so which folders/output files) apply to
	* this year. Computed once here and reused throughout (Sections 3, 4,
	* 5, and the resume check right below) instead of recomputing the
	* same formula separately in each section.
	local collapse_var = cond(`year' < 2006, "cnae95", "cnae95 cnae2 cnae2_subclass cnae67")

	* RESUME CHECK - a year only counts as "already done" if EVERY
	* collapse type that applies to it already has its combined per-year
	* file on disk, not just some of them. A naive "does this year have
	* any output at all" check would wrongly call an incomplete year
	* done - which is exactly what broke last time: cnae2's file didn't
	* exist yet for years before 2006, and a since-fixed bug in Section 5
	* tried to append onto a file that was never created.
	local year_done = 1
	foreach var in "" `collapse_var' {
		local foldername = cond("`var'" == "", "Municipality Only", ///
						   cond("`var'" == "cnae95", "CNAE95", ///
						   cond("`var'" == "cnae2", "CNAE2", ///
						   cond("`var'" == "cnae2_subclass", "CNAE2_subclass", ///
						   "CNAE67"))))
		capture confirm file "`HPC_ROOT'/Mining/Working/RAIS/`year'/`foldername'/cleaned_`year'_allstates.dta"
		if _rc {
			local year_done = 0
		}
	}

	if `resume_mode' == 1 & `year_done' == 1 {

		di as result "Year `year' - resume_mode on and already fully processed, skipping straight to Section 5."

	}
	else {

	********************************************************************************
	********************************************************************************
	**********															 ***********
	********** 				Section 1: Unzip Large RAIS File             ***********
	**********														 	 ***********
	********************************************************************************
	********************************************************************************

	/* Notes:
	
		Files are zipped (.7z) on the HPC to save space. worker_files below
		holds base names only (no extension) - each gets extracted to
		raw_txt/ right before it's imported to Stata, then the .txt is erased right
		after that state is done, so only one state's worth of unzipped
		text ever sits on disk at once.
	*/
	
	* Set up local file paths
	local RAIS_RAW_7Z  "`HPC_ROOT'/Data/RAIS/raw_7z/`year'"
	local RAIS_RAW     "`HPC_ROOT'/Data/RAIS/raw_txt/`year'"
	local RAIS_WORKING "`HPC_ROOT'/Mining/Working/RAIS"

	* Set Up Directories
	capture mkdir "`HPC_ROOT'"
	capture mkdir "`HPC_ROOT'/Data"
	capture mkdir "`HPC_ROOT'/Data/RAIS"
	capture mkdir "`HPC_ROOT'/Data/RAIS/raw_txt"
	capture mkdir "`RAIS_RAW'"

	* Working Directory
	capture mkdir "`HPC_ROOT'/Mining"
	capture mkdir "`HPC_ROOT'/Mining/Working"
	capture mkdir "`HPC_ROOT'/Mining/Working/RAIS"
	capture mkdir "`HPC_ROOT'/Mining/Working/RAIS/`year'"

	* Get list of all zipped files in a given year
	local state_files : dir "`RAIS_RAW_7Z'" files "*.7z"

	* Only get file names that are NOT estab - estab done in another file
	local worker_files
	foreach f of local state_files {
		if !strpos(upper("`f'"), "ESTB") & !strpos(upper("`f'"), "ESTAB") {
			local base = substr("`f'", 1, length("`f'") - 3)
			local worker_files "`worker_files' `base'"
		}
	}
	
	* Throw error if no files in the folder
	if "`worker_files'" == "" {
		di as error "No .7z files found in `RAIS_RAW_7Z'."
		di as error "Run pull_rais_hpc.py for `year' first, or check the year set above."
		exit 601
	}


	
	foreach region of local worker_files {

		/* Notes: 
		
			This loop runs the full code for all states. The first step is to 
			unzip just the given state file. Use python shell to unzip the filen
			rather than stata.
			
			Unzip just this one file - Stata's own unzipfile only handles
			.zip, not .7z, so this shells out to Python's py7zr.
			
		*/
		
		
		shell python3 -c "import py7zr; py7zr.SevenZipFile('`RAIS_RAW_7Z'/`region'.7z').extractall('`RAIS_RAW'')"
		
		
		********************************************************************************
		********************************************************************************
		**********															 ***********
		********** 			Section 2: Import, rename, keep, destring        ***********
		**********														 	 ***********
		********************************************************************************
		********************************************************************************

		/* Notes:

			Two separate format changes, confirmed NOT to happen in the same
			year: region-grouping (multiple states combined into one file)
			starts in 2018, but the comma-delimited/.COMT/quoted-header
			format doesn't start until sometime after that - 2018 itself
			extracts as plain old-style semicolon-delimited .txt, just with
			region-grouped files instead of per-state ones. Since we don't
			know the exact year the second change happens either, detect it
			from the actual file on disk after extraction rather than
			guessing another year cutoff - whichever extension actually
			landed (.txt or .COMT) determines the delimiter too, since both
			come from the same export-system change on Brazil's end.

		*/

		******************
		** Import Files **
		******************

		capture confirm file "`RAIS_RAW'/`region'.txt"
		if !_rc {
			local raw_ext "txt"
			local raw_delim ";"
		}
		else {
			local raw_ext "COMT"
			local raw_delim ","
		}

		import delimited using "`RAIS_RAW'/`region'.`raw_ext'", clear varnames(1) ///
			delimiter("`raw_delim'") encoding("windows-1252")

		generate int year = `year'
		
		
		***************************************
		**** Rename Variables Into English ****
		***************************************


		/* Notes:

			Variable names are slightly different across years. Include all versions of
			each variable name and what they should map to.
		
		*/

		** Municipality **
		capture rename municipio municipality
		capture rename munic_pio municipality
		capture rename municípiocódigo municipality
		capture rename município municipality

		** Employment (active as of Dec 31) **
		capture rename vinculo_ativo_31_12 employed
		capture rename vinculo_ativo_3112 employed
		capture rename v_nculo_ativo_31_12 employed
		capture rename indvínculoativo3112código employed
		capture rename vínculoativo3112 employed

		** Tenure **
		capture rename tempo_emprego tenure
		capture rename tempoemprego tenure

		** Industry, CNAE 2.0 Classe (doesn't exist before ~2010) **
		capture rename cnae_20_classe cnae2
		capture rename cnae_2_0_classe cnae2
		capture rename cnae20classecódigo cnae2
		capture rename cnae20classe cnae2

		** Industry, CNAE 95 Classe (present ~1995 onward - required, unlike CNAE 2.0 below) **
		capture rename cnae95classe cnae95
		capture rename cnae95classecódigo cnae95

		** Industry, CNAE 2.0 Subclasse (doesn't exist before ~2010) **
		capture rename cnae_20_subclasse cnae2_subclass
		capture rename cnae_2_0_subclasse cnae2_subclass
		capture rename cnae20subclassecodigo cnae2_subclass
		capture rename cnae20subclasse cnae2_subclass

		* cnae2/cnae2_subclass carry a trailing check digit in the raw
		* data that isn't part of the real classification code -
		* confirmed directly against a real raw Estab file (same RAIS
		* CNAE 2.0 system, same convention): Classe "01113" is base code
		* 0111 plus check digit 3, not the number 1113. Subclasse embeds
		* the check digit in the middle instead of the end: "9499500" is
		* base 9499 + check digit 5 + subclass suffix 00, not 9499500
		* itself. Without stripping these, cnae2 doesn't match the
		* CNAE67 crosswalk (which uses the real base code) at all -
		* confirmed this broke the cnae67 merge in the Estab pipeline,
		* only ~4 of 67 codes matched, mostly by coincidence. tostring
		* first (format-padded) in case Stata auto-imported the column
		* as numeric and dropped the leading zero - capture wraps both
		* since cnae2/cnae2_subclass may not exist yet this year (years
		* before ~2010), same reasoning as the destring loop below.
		capture tostring cnae2, replace format(%05.0f)
		capture replace cnae2 = substr(cnae2, 1, 4)
		capture tostring cnae2_subclass, replace format(%07.0f)
		capture replace cnae2_subclass = substr(cnae2_subclass, 1, 4) + substr(cnae2_subclass, 6, 2)

		** Establishment size **
		capture rename tamanho_estabelecimento estab_size
		capture rename tamanhoestabelecimentocódigo estab_size
		capture rename tamanhoestabelecimento estab_size

		** Legal nature **
		capture rename natureza_jur_dica legal_nature
		capture rename natureza_juridica legal_nature
		capture rename naturezajurídicacódigo legal_nature
		capture rename naturezajurídica legal_nature

		** Wage, December (nominal R$ only, no SM) **
		capture rename vl_remun_dezembro_nom wage_dec
		capture rename vlremdezembronom wage_dec
		capture rename vlremundezembronom wage_dec

		** Wage, annual average (nominal R$ only, no SM) **
		capture rename vl_remun_m_dia_nom wage_avg
		capture rename vl_remun_media_nom wage_avg
		capture rename vlremmédianom wage_avg
		capture rename vlremunmédianom wage_avg

		** Wage, monthly Jan-Nov (doesn't exist before 2015) **
		capture rename vl_rem_janeiro_cc wage_jan
		capture rename vlremjaneirosc wage_jan
		capture rename vlremjaneirocc wage_jan
		capture rename vl_rem_fevereiro_cc wage_feb
		capture rename vlremfevereirosc wage_feb
		capture rename vlremfevereirocc wage_feb
		capture rename vl_rem_mar_o_cc wage_mar
		capture rename vl_rem_marco_cc wage_mar
		capture rename vlremmarçosc wage_mar
		capture rename vlremmarçocc wage_mar
		capture rename vl_rem_abril_cc wage_apr
		capture rename vlremabrilsc wage_apr
		capture rename vlremabrilcc wage_apr
		capture rename vl_rem_maio_cc wage_may
		capture rename vlremmaiosc wage_may
		capture rename vlremmaiocc wage_may
		capture rename vl_rem_junho_cc wage_jun
		capture rename vlremjunhosc wage_jun
		capture rename vlremjunhocc wage_jun
		capture rename vl_rem_julho_cc wage_jul
		capture rename vlremjulhosc wage_jul
		capture rename vlremjulhocc wage_jul
		capture rename vl_rem_agosto_cc wage_aug
		capture rename vlremagostosc wage_aug
		capture rename vlremagostocc wage_aug
		capture rename vl_rem_setembro_cc wage_sep
		capture rename vlremsetembrosc wage_sep
		capture rename vlremsetembrocc wage_sep
		capture rename vl_rem_outubro_cc wage_oct
		capture rename vlremoutubrosc wage_oct
		capture rename vlremoutubrocc wage_oct
		capture rename vl_rem_novembro_cc wage_nov
		capture rename vlremnovembrosc wage_nov
		capture rename vlremnovembrocc wage_nov

		** Age **
		capture rename idade age

		** Sex - plain ASCII header, no accents, present unchanged in
		** every year. Coded 1=Male, 2=Female (verified against real
		** 2015 data). Not directly rename-tested against every era's
		** actual describe output the way most other vars were, so watch
		** for a rename failure on the first run of a new year - it's in
		** needed_vars, so it'll error loudly rather than fail silently.
		capture rename sexotrabalhador sex
		capture rename sexocódigo sex

		** Race (doesn't exist before ~2010) **
		capture rename ra_a_cor race
		capture rename raca_cor race
		capture rename raçacorcódigo race
		capture rename raçacor race

		** Termination month **
		capture rename m_s_desligamento term_month
		capture rename mes_desligamento term_month
		capture rename mêsdesligamentocódigo term_month
		capture rename mêsdesligamento term_month

		** Admission (hire) month - same "Mês X" pattern as termination
		** month above, so the same sanitized variants apply. 0 = no hire
		** event this year (continuing employment), 1-12 = real hire
		** month (verified against real 2015 data, same convention as
		** term_month's 0=not terminated).
		capture rename m_s_admiss_o hire_month
		capture rename mes_admissao hire_month
		capture rename mêsadmissãocódigo hire_month
		capture rename mêsadmissão hire_month

		** Termination reason (10-12 = dismissal, see code table) **
		capture rename motivo_desligamento term_reason
		capture rename motivodesligamentocódigo term_reason
		capture rename motivodesligamento term_reason

		** Nationality **
		capture rename nacionalidade nationality

		** Education - wording changed around 2010, both forms handled **
		capture rename escolaridade_ap_s_2005 educ
		capture rename escolaridade_apos_2005 educ
		capture rename grau_instru_o_2005_1985 educ
		capture rename grau_instrucao_2005_1985 educ
		capture rename grau_instru_ao_2005_1985 educ
		capture rename escolaridadeapós2005código educ
		capture rename escolaridadeapós2005 educ
		capture rename grauinstrução20051985 educ

		*****************************
		**** Generate State Var  ****
		*****************************

		/* Notes:

		State comes from the municipality code's leading 2 digits (the
		official IBGE UF prefix). municipality's import-detected type
		varies by year/file (sometimes string, sometimes already numeric),
		so destring it first (capture, since destring on an already-numeric
		var otherwise errors), then convert back to a fixed plain-integer
		string with string() before taking substr() - doing it this way
		instead of dividing by a power of 10 avoids having to assume a
		fixed digit count, which turned out not to be safe: RAIS municipio
		codes are 6 digits here (e.g. 160030), not the 7-digit official
		IBGE code with its check digit.

		*/

		capture destring municipality, replace force
		generate str12 municipality_str = string(municipality, "%12.0f")

		generate str2 state = ""
		replace state = "RO" if substr(municipality_str, 1, 2) == "11"
		replace state = "AC" if substr(municipality_str, 1, 2) == "12"
		replace state = "AM" if substr(municipality_str, 1, 2) == "13"
		replace state = "RR" if substr(municipality_str, 1, 2) == "14"
		replace state = "PA" if substr(municipality_str, 1, 2) == "15"
		replace state = "AP" if substr(municipality_str, 1, 2) == "16"
		replace state = "TO" if substr(municipality_str, 1, 2) == "17"
		replace state = "MA" if substr(municipality_str, 1, 2) == "21"
		replace state = "PI" if substr(municipality_str, 1, 2) == "22"
		replace state = "CE" if substr(municipality_str, 1, 2) == "23"
		replace state = "RN" if substr(municipality_str, 1, 2) == "24"
		replace state = "PB" if substr(municipality_str, 1, 2) == "25"
		replace state = "PE" if substr(municipality_str, 1, 2) == "26"
		replace state = "AL" if substr(municipality_str, 1, 2) == "27"
		replace state = "SE" if substr(municipality_str, 1, 2) == "28"
		replace state = "BA" if substr(municipality_str, 1, 2) == "29"
		replace state = "MG" if substr(municipality_str, 1, 2) == "31"
		replace state = "ES" if substr(municipality_str, 1, 2) == "32"
		replace state = "RJ" if substr(municipality_str, 1, 2) == "33"
		replace state = "SP" if substr(municipality_str, 1, 2) == "35"
		replace state = "PR" if substr(municipality_str, 1, 2) == "41"
		replace state = "SC" if substr(municipality_str, 1, 2) == "42"
		replace state = "RS" if substr(municipality_str, 1, 2) == "43"
		replace state = "MS" if substr(municipality_str, 1, 2) == "50"
		replace state = "MT" if substr(municipality_str, 1, 2) == "51"
		replace state = "GO" if substr(municipality_str, 1, 2) == "52"
		replace state = "DF" if substr(municipality_str, 1, 2) == "53"
		drop municipality_str

		*********************************
		**** Keep Variables We Need  ****
		*********************************
		
		* Confirm all necessary variables are renamed & kept
		local needed_vars municipality employed tenure cnae95 ///
			estab_size legal_nature wage_dec wage_avg ///
			age nationality educ term_month term_reason sex hire_month year  state

		foreach v of local needed_vars {
			capture confirm variable `v'
			if _rc {
				di as error "`v' rename failed on `region' - run describe and fix the rename above."
				exit 111
			}
		}
		
		* Make placeholder variables that don't exist across all years
		local optional_vars cnae2 cnae2_subclass race wage_jan wage_feb wage_mar ///
			wage_apr wage_may wage_jun wage_jul wage_aug wage_sep wage_oct wage_nov
		foreach v of local optional_vars {
			capture confirm variable `v'
			if _rc {
				generate float `v' = .
			}
		}
		
		* Keep variables we need
		keep `needed_vars' `optional_vars' state year

		********************************
		**** Destring All Variables ****
		********************************
		
		destring employed, replace force

		local integer_vars municipality cnae2 cnae95 cnae2_subclass ///
			estab_size legal_nature age race nationality educ term_month term_reason ///
			sex hire_month
		foreach v of local integer_vars {
			capture destring `v', replace force
		}

		* Comma-decimal fields (Brazilian number format) - dpcomma tells
		* destring to treat "," as the decimal point, not a thousands marker.
		local comma_vars tenure wage_dec wage_avg ///
			wage_jan wage_feb wage_mar wage_apr wage_may wage_jun ///
			wage_jul wage_aug wage_sep wage_oct wage_nov
		foreach v of local comma_vars {
			capture destring `v', replace force dpcomma
		}

		********************************************************************************
		********************************************************************************
		**********															 ***********
		********** 		  Section 3: CNPJ filter, demographic buckets        ***********
		**********															 ***********
		********************************************************************************
		********************************************************************************

		/* Notes:
			
			This section makes binary variables to calculate share variables depending
			on the unit of analysis. 
			
			Codes verified directly against the Ministry's own RAIS layout file
			(RAIS_vinculos_layout2020.xls):
		
		*/

		generate byte race_indigenous = (race == 1) if !missing(race)
		generate byte race_white   = (race == 2) if !missing(race)
		generate byte race_black    = (race == 4) if !missing(race)
		generate byte race_asian  = (race == 6) if !missing(race)
		generate byte race_mixed    = (race == 8) if !missing(race)
		generate byte race_missing  = inlist(race, 9, -1) | missing(race)

		generate byte nat_brazilian = inlist(nationality, 10, 20) if !missing(nationality)
		generate byte nat_foreign   = inrange(nationality, 21, 80) if !missing(nationality)
		generate byte nat_missing   = (nationality == -1) | missing(nationality)

		generate byte educ_below_hs = inrange(educ, 1, 5) if !missing(educ)
		generate byte educ_hs       = inrange(educ, 6, 7) if !missing(educ)
		generate byte educ_higher   = inrange(educ, 8, 11) if !missing(educ)
		generate byte educ_missing  = (educ == -1) | missing(educ)

		generate byte age_youth   = inrange(age, 0, 24) if !missing(age)
		generate byte age_prime   = inrange(age, 25, 54) if !missing(age)
		generate byte age_older   = (age >= 55) if !missing(age)
		generate byte age_missing = missing(age)

		generate byte size_0_9      = inrange(estab_size, 1, 3) if !missing(estab_size)
		generate byte size_10_99    = inrange(estab_size, 4, 6) if !missing(estab_size)
		generate byte size_100_499  = inrange(estab_size, 7, 8) if !missing(estab_size)
		generate byte size_500plus  = inrange(estab_size, 9, 10) if !missing(estab_size)
		generate byte size_missing  = (estab_size == -1) | missing(estab_size)
		
		* size_bucket - commented out, not currently used (size_0_9 etc
		* above already cover this as dummies; size_bucket was just a
		* redundant string version).
		/*
		generate size_bucket = ""
		replace size_bucket = "0-9 Employees" if inrange(estab_size, 1, 3) & !missing(estab_size)
		replace size_bucket = "10-99 Employees" if inrange(estab_size, 4, 6) & !missing(estab_size)
		replace size_bucket = "100-499 Employees" if inrange(estab_size, 7, 8) & !missing(estab_size)
		replace size_bucket = "500+ Employees" if inrange(estab_size, 9, 10) & !missing(estab_size)
		*/

		* Legal nature buckets - restored. Was commented out earlier while
		* chasing an "invalid syntax" (r198) error that turned out to be
		* an unrelated cond() bug elsewhere in the file, not this block.
		generate int legalnat_bucket = floor(legal_nature/1000) if legal_nature > 0
		generate byte legalnat_public    = (legalnat_bucket == 1) if !missing(legalnat_bucket)
		generate byte legalnat_private   = (legalnat_bucket == 2) if !missing(legalnat_bucket)
		generate byte legalnat_nonprofit = (legalnat_bucket == 3) if !missing(legalnat_bucket)
		generate byte legalnat_individual = (legalnat_bucket == 4) if !missing(legalnat_bucket)
		generate byte legalnat_intl      = (legalnat_bucket == 5) if !missing(legalnat_bucket)
		generate byte legalnat_missing   = missing(legalnat_bucket) | legal_nature == -1
		drop legalnat_bucket

		* Termination reason buckets - 0 (not terminated), 90 (mutual
		* agreement), and -1 (missing) intentionally left out of all three,
		* per request - they just won't count toward any bucket's share.
		generate byte term_fired    = inrange(term_reason, 10, 12) if !missing(term_reason)
		generate byte term_resigned = inrange(term_reason, 20, 22) if !missing(term_reason)
		generate byte term_retired  = (inlist(term_reason, 40, 50) | inrange(term_reason, 60, 64) | inrange(term_reason, 70, 80)) if !missing(term_reason)

		* Termination month - 12 dummies, one per month, missing (not 0)
		* for rows that weren't terminated (term_month outside 1-12).
		* These get summed rather than averaged in the collapse below, so
		* the result is a COUNT of terminations per month, not a share -
		* averaging the raw month number itself would be meaningless.
		generate byte term_jan = (term_month == 1)  if inrange(term_month, 1, 12)
		generate byte term_feb = (term_month == 2)  if inrange(term_month, 1, 12)
		generate byte term_mar = (term_month == 3)  if inrange(term_month, 1, 12)
		generate byte term_apr = (term_month == 4)  if inrange(term_month, 1, 12)
		generate byte term_may = (term_month == 5)  if inrange(term_month, 1, 12)
		generate byte term_jun = (term_month == 6)  if inrange(term_month, 1, 12)
		generate byte term_jul = (term_month == 7)  if inrange(term_month, 1, 12)
		generate byte term_aug = (term_month == 8)  if inrange(term_month, 1, 12)
		generate byte term_sep = (term_month == 9)  if inrange(term_month, 1, 12)
		generate byte term_oct = (term_month == 10) if inrange(term_month, 1, 12)
		generate byte term_nov = (term_month == 11) if inrange(term_month, 1, 12)
		generate byte term_dec = (term_month == 12) if inrange(term_month, 1, 12)

		* Sex share - 1=Male, 2=Female (verified against real data). Just
		* one binary variable, not two - share_female is redundant with
		* share_male (1 - share_male) once this collapses to a mean.
		generate byte share_male = (sex == 1) if !missing(sex)

		* Hiring month - same idea as termination month above, just for
		* admissions instead: 12 count variables, missing (not 0) for
		* rows with no hire event this year (hire_month outside 1-12).
		* Summed, not averaged, in the collapse below - lets separations
		* (term_*) and hires (hire_*) be compared month by month.
		generate byte hire_jan = (hire_month == 1)  if inrange(hire_month, 1, 12)
		generate byte hire_feb = (hire_month == 2)  if inrange(hire_month, 1, 12)
		generate byte hire_mar = (hire_month == 3)  if inrange(hire_month, 1, 12)
		generate byte hire_apr = (hire_month == 4)  if inrange(hire_month, 1, 12)
		generate byte hire_may = (hire_month == 5)  if inrange(hire_month, 1, 12)
		generate byte hire_jun = (hire_month == 6)  if inrange(hire_month, 1, 12)
		generate byte hire_jul = (hire_month == 7)  if inrange(hire_month, 1, 12)
		generate byte hire_aug = (hire_month == 8)  if inrange(hire_month, 1, 12)
		generate byte hire_sep = (hire_month == 9)  if inrange(hire_month, 1, 12)
		generate byte hire_oct = (hire_month == 10) if inrange(hire_month, 1, 12)
		generate byte hire_nov = (hire_month == 11) if inrange(hire_month, 1, 12)
		generate byte hire_dec = (hire_month == 12) if inrange(hire_month, 1, 12)

		* These are all categorical codes - already turned into share/count
		* variables above, so the raw codes themselves get dropped here
		* rather than falling into the generic (mean) list below, where
		* averaging a category code is meaningless.
		drop term_reason term_month nationality legal_nature estab_size sex hire_month

		* Generate County Population Variable
		gen population = 1

		di as text "CHECKPOINT: reached end of Section 3 buckets, about to start collapse loop"


		********************************************************************************
		********************************************************************************
		**********															 ***********
		********** 		  		Section 3: Run All Collapses 		         ***********
		**********															 ***********
		********************************************************************************
		********************************************************************************
		
		/* Note:
		
			The data are collapsed 2 or 4 times (depending on the year).
			
				Collapse 1 (Municipal): All YEARS 
					At the municipality level. Done to get general municipality variables 
					(race/education/age/population etc.)
			
				Collapse 2 (Municipal X CNAE1995): ALL YEARS - collapse_var = cnae95
					At the municipal X industry level. Industry codes change in 2006 and
					are more refined however that drops earlier years. Collapse done using
					1995 industry codes to get all years.
					
				Collapse 3 (Municipal X CNAE2.0): Years 2006 and onward - collapse_var = cnae2
					At the municipal X industry level. Same as collapse 2 but only for 
					years 2006 and onward using most updated industry codes.
					
				Collapse 4 (Municipal X CNAE2.0 Sub-class): Years 2006 and onward - collapse_var = cnae2_subclass
					At the municipal X sub-industry level. Most recent industry codes
					are available at finer granularity so collapse done at finest granularity.

		*/

		* collapse_var already computed once at the top of the year loop.
		foreach var in "" `collapse_var' {

		* Make folders for each type of collapse - 5 outcomes need 4
		* nested cond()s (each cond() needs exactly 3 arguments:
		* condition, true-value, false-value).
		local foldername = cond("`var'" == "", "Municipality Only", ///
						   cond("`var'" == "cnae95", "CNAE95", ///
						   cond("`var'" == "cnae2", "CNAE2", ///
						   cond("`var'" == "cnae2_subclass", "CNAE2_subclass", ///
						   "CNAE67"))))

		cap mkdir "`HPC_ROOT'/Mining/Working/RAIS/`year'/`foldername'"
		
			******************************
			********** COLLAPSE **********
			******************************

			preserve

			* CNAE67 (IBGE's 67-sector activity classification) - only
			* merged in on the pass that's actually collapsing by it, not
			* every pass (cnae95/cnae2/cnae2_subclass/municipality-only
			* don't need it). cnae67_var mirrors that: "cnae67" on the
			* pass that merged it in, blank otherwise, so the ds
			* exclusion list below never names a variable that isn't
			* actually in the dataset this pass.
			local cnae67_var ""
			if "`var'" == "cnae67" {
				merge m:1 cnae2 using "`HPC_ROOT'/Data/Crosswalks/cnae2_to_cnae67.dta", keep(master match) nogenerate
				local cnae67_var "cnae67"
			}

			* Get all variables we calculate mean for. cnae95/cnae2/
			* cnae2_subclass/cnae67_var excluded regardless of which one
			* is `var' this pass - whichever one IS `var' would otherwise
			* be both a mean target and the by() variable (which Stata
			* rejects), and the others are category codes that shouldn't
			* be averaged either - they're only still in the dataset
			* because a later pass needs them as its own by() variable.
			* The 12 term_* and 12 hire_* month dummies are excluded too
			* since they're summed (counts) below instead, not averaged.
			* share_male isn't
			* excluded - that's a real share, meant to be averaged like
			* race/nat/educ.
			ds population state year municipality cnae95 cnae2 cnae2_subclass `cnae67_var' ///
				term_jan term_feb term_mar term_apr term_may term_jun ///
				term_jul term_aug term_sep term_oct term_nov term_dec ///
				hire_jan hire_feb hire_mar hire_apr hire_may hire_jun ///
				hire_jul hire_aug hire_sep hire_oct hire_nov hire_dec, not
			di as text "CHECKPOINT: var='`var'' r(varlist)=`r(varlist)'"

			collapse (mean) "`r(varlist)'" ///
					 (sum) population number_employed = employed ///
					 term_jan term_feb term_mar term_apr term_may term_jun ///
					 term_jul term_aug term_sep term_oct term_nov term_dec ///
					 hire_jan hire_feb hire_mar hire_apr hire_may hire_jun ///
					 hire_jul hire_aug hire_sep hire_oct hire_nov hire_dec ///
					 (firstnm) state year, ///
					 by(municipality "`var'")

			di as text "CHECKPOINT: collapse succeeded for var='`var''"

			save "`HPC_ROOT'/Mining/Working/RAIS/`year'/`foldername'/`region'_clean.dta", replace
			restore

		}

		* Free up disk space - this state's unzipped text isn't needed
		* again once its collapses above are saved.
		erase "`RAIS_RAW'/`region'.`raw_ext'"

	}

	********************************************************************************
	********************************************************************************
	**********															 ***********
	********** 		  		Section 4: Append All Files 		         ***********
	**********															 ***********
	********************************************************************************
	********************************************************************************

	/* Notes:

		The collapses above make 4 different types of files at different levels
		of aggregation (different industry codes), one file per state. This
		appends all states together within one year, once per collapse type.
		Moved outside the state-file loop above (it was nested inside it,
		which re-ran and re-saved this same step once per state instead of
		once per year).

	*/

	************************************
	** Merge All States Into One Year **
	************************************

	* collapse_var already computed once at the top of the year loop.
	foreach var in "" `collapse_var' {

		* Make folders for each type of collapse
		local foldername = cond("`var'" == "", "Municipality Only", ///
						   cond("`var'" == "cnae95", "CNAE95", ///
						   cond("`var'" == "cnae2", "CNAE2", ///
						   cond("`var'" == "cnae2_subclass", "CNAE2_subclass", ///
						   "CNAE67"))))

		* Point to the correct directory
		local dir "`HPC_ROOT'/Mining/Working/RAIS/`year'/`foldername'"
		cd "`dir'"

		* Append all files - "*_clean.dta" (not "*.dta") on purpose: that
		* matches only the per-state fragments (<region>_clean.dta), never
		* the combined output below (cleaned_`year'_allstates.dta), so a
		* rerun can't sweep its own prior output back in as an extra
		* "state" and double count everything (this is why the CNAE95
		* output came out with exactly 3 copies of every row earlier - we
		* reran this pipeline 3 times and each run re-absorbed the last).
		clear
		local files : dir "`dir'" files "*_clean.dta"
		append using `files'

		* Save one large file
		save "cleaned_`year'_allstates.dta", replace

	}

	} // closes the "else" opened after the resume check above - Sections
	  // 1-4 only run when this year wasn't already fully done.

	********************************************************************************
	********************************************************************************
	**********															 ***********
	********** 		  		Section 5: Append All Years 		         ***********
	**********															 ***********
	********************************************************************************
	********************************************************************************

	* Always runs, whether Sections 1-4 above ran or got skipped by resume
	* mode - reads whichever per-year files exist (freshly made above, or
	* already on disk from an earlier run) and folds them into the
	* running All_Years file. collapse_var was computed once at the top
	* of the year loop, reused here.
	foreach var in "" `collapse_var' {

		local foldername = cond("`var'" == "", "Municipality Only", ///
						   cond("`var'" == "cnae95", "CNAE95", ///
						   cond("`var'" == "cnae2", "CNAE2", ///
						   cond("`var'" == "cnae2_subclass", "CNAE2_subclass", ///
						   "CNAE67"))))

		local dir "`HPC_ROOT'/Mining/Working/RAIS/`year'/`foldername'"
		local final_dir "`HPC_ROOT'/Mining/Working/RAIS/All_Years/`foldername'"

		use "`dir'/cleaned_`year'_allstates.dta", clear

		* Check whether this foldername's file actually exists yet,
		* rather than comparing to the global startyear - cnae2 and
		* cnae2_subclass don't start until 2006, so "first year we've
		* ever seen this foldername" isn't the same thing as "first year
		* of the whole run" for those two.
		capture mkdir "`HPC_ROOT'/Mining/Working/RAIS/All_Years"
		capture mkdir "`final_dir'"
		capture confirm file "`final_dir'/cleaned_all_years.dta"
		if _rc {
			save "`final_dir'/cleaned_all_years.dta", replace
		}
		else {
			append using "`final_dir'/cleaned_all_years.dta"
			save "`final_dir'/cleaned_all_years.dta", replace
		}

	}

}

log close

