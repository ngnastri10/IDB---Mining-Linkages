* ==========================================================================
* HPC version of the RAIS Vinculos clean - CNPJ establishments only.
* Produces THREE output files from one pass over the raw data:
*
*   1. Municipality level - everyone (employed or not as of Dec 31), so
*      "share employed" itself is a real, non-trivial variable. Race,
*      nationality, education, age shares computed over this full group.
*
*   2. Municipality x industry (CNAE 2.0 Classe) - active/employed workers
*      only, since "what industry" only means something for someone
*      currently working. Wages, establishment size/legal nature shares,
*      demographic shares all computed among the employed here.
*
*   3. Same as #2 but at the finer Subclasse level instead of Classe.
*
* Verified against 2000, 2001, 2010, and 2015 headers (see
* rais_vinculos_headers_by_year.txt and rais_vinculos_variable_consistency.md
* in this same folder). Not yet handling 2025 - different delimiter (comma
* + quotes instead of semicolons), needs a different import command, not
* just different renames. Only nominal wages are kept - no SM (minimum
* wage multiple) columns.
*
* state and year are pulled straight from each raw filename (e.g.
* "AC2015.txt"), not just from the Section 1 local - see Section 2.
*
* Input:
*   `HPC_ROOT'/Data/RAIS/raw_txt/`year'/*.txt   (from pull_rais_hpc.py)
*
* Output:
*   `HPC_ROOT'/Data/RAIS/working/rais_municipality_`year'.dta
*   `HPC_ROOT'/Data/RAIS/working/rais_municipality_classe_`year'.dta
*   `HPC_ROOT'/Data/RAIS/working/rais_municipality_subclasse_`year'.dta
*   `HPC_ROOT'/Data/RAIS/working/rais_municipality_cnae_separations_`year'.dta
*
* File Organization:
*
*		Section 1: Point at the raw RAIS files for one year
*		Section 2: Import, rename, keep, destring - one state file at a time
*		Section 3: CNPJ filter, demographic buckets, the four collapses
*		Section 4: Combine states and save - municipality level
*		Section 5: Combine states and save - municipality x Classe
*		Section 6: Combine states and save - municipality x Subclasse
*		Section 7: Combine states and save - municipality x Classe separations
* ==========================================================================

clear all
set more off
set varabbrev off

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Point at the raw RAIS files for one year        ***********
**********															 ***********
********************************************************************************
********************************************************************************

******** SET YOUR HPC PATH HERE ********
local HPC_ROOT "/home/nn3495a-hpc/IDB"

******** SET THE YEAR TO CLEAN HERE - must match a year you already ran pull_rais_hpc.py for ********
local year 2015

local RAIS_RAW     "`HPC_ROOT'/Data/RAIS/raw_txt/`year'"
local RAIS_WORKING "`HPC_ROOT'/Data/RAIS/working"

capture mkdir "`HPC_ROOT'"
capture mkdir "`HPC_ROOT'/Data"
capture mkdir "`HPC_ROOT'/Data/RAIS"
capture mkdir "`HPC_ROOT'/Data/RAIS/working"

local state_files : dir "`RAIS_RAW'" files "*.txt"

local worker_files
foreach f of local state_files {
    if !strpos(upper("`f'"), "ESTB") & !strpos(upper("`f'"), "ESTAB") {
        local worker_files "`worker_files' `f'"
    }
}

di as result "Found `:word count `worker_files'' vinculos files for `year'"

if "`worker_files'" == "" {
    di as error "No .txt files found in `RAIS_RAW'."
    di as error "Run pull_rais_hpc.py for `year' first, or check the year set above."
    exit 601
}

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 2: Import, rename, keep, destring - one state     ***********
********** file at a time                                             ***********
**********															 ***********
********************************************************************************
********************************************************************************

tempfile muni_stack classe_stack subclasse_stack term_stack
local first = 1
local RAIS_RAW = "D:\Data\RAIS\raw_txt\2001"
local worker_files = "AP2001"

foreach f of local worker_files {

    import delimited using "`RAIS_RAW'/`f'.txt", clear varnames(1) ///
        delimiter(";") encoding("windows-1252")

    * State and year come straight from the filename (e.g. "AC2015.txt"),
    * not just the local set in Section 1 - ties both to the actual file
    * being read. Carried through every collapse below via (first), since
    * they're constant within one state's file.
    generate str2 state = upper(substr("`f'", 1, 2))
    generate int year = real(substr("`f'", 3, 4))

    /* Notes:

    Every rename below is grouped by variable, with one line per raw
    header text we've actually seen across 2000/2001/2010/2015 (capture
    means whichever ones don't match this particular file's era just
    silently do nothing - only the real match fires). "Tipo Estab" appears
    twice in the raw header (code, then name) with no distinguishing text,
    so Stata renames the second occurrence to avoid a duplicate - confirmed
    against a real sample row that the *second* one holds the literal text
    "CNPJ"/"CNO", not the first (numeric code).
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

    ** Establishment size **
    capture rename tamanho_estabelecimento estab_size
    capture rename tamanhoestabelecimentocódigo estab_size
    capture rename tamanhoestabelecimento estab_size

    ** Establishment type (the text version, e.g. "CNPJ") **
    capture rename tipo_estab1 estab_type
    capture rename tipo_estab_1 estab_type
    capture rename tipoestabelecimentonome estab_type
    capture rename v43 estab_type
    capture rename v34 estab_type

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

    local needed_vars municipality employed tenure cnae95 ///
        estab_size estab_type legal_nature wage_dec wage_avg ///
        age nationality educ term_month term_reason year  state

    foreach v of local needed_vars {
        capture confirm variable `v'
        if _rc {
            di as error "`v' rename failed on `f' - run describe and fix the rename above."
            exit 111
        }
    }

    * CNAE 2.0 (classe/subclasse) doesn't exist before ~2010, and monthly
    * wages don't exist before 2015 - all optional, not required. Filled
    * as missing for years that don't have them instead of stopping the file.
    local optional_vars cnae2 cnae2_subclass race wage_jan wage_feb wage_mar ///
        wage_apr wage_may wage_jun wage_jul wage_aug wage_sep wage_oct wage_nov
    foreach v of local optional_vars {
        capture confirm variable `v'
        if _rc {
            generate float `v' = .
        }
    }

    keep `needed_vars' `optional_vars' state year

   
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
    ********** Section 3: CNPJ filter, demographic buckets, the four      ***********
    ********** collapses                                                  ***********
    **********															 ***********
    ********************************************************************************
    ********************************************************************************

    /* Notes:

    Codes verified directly against the Ministry's own RAIS layout file
    (RAIS_vinculos_layout2020.xls), not assumed:

    Race: 1=Indigena, 2=Branca, 4=Preta, 6=Amarela, 8=Parda, 9=Nao
    identificado, -1=Ignorado (9 and -1 combined into one bucket).

    Nationality: 10=Brasileira, 20=Naturalidade Brasileira (both count as
    "Brazilian"), 21-80=specific foreign nationalities, -1=Ignorado.

    Education: 1-5=below high school (illiterate through fundamental
    complete), 6-7=high school (incomplete/complete), 8-11=higher ed
    (incomplete through doutorado), -1=Ignorado.

    Age brackets are not an official RAIS code - chosen here as standard
    labor-economics groupings (under 25 / 25-54 / 55+).

    Establishment size: the 10 official RAIS brackets, used directly
    rather than re-grouped - 1=Zero, 2=1-4, 3=5-9, 4=10-19, 5=20-49,
    6=50-99, 7=100-249, 8=250-499, 9=500-999, 10=1000+, -1=Ignorado.

    Legal nature uses CONCLA's leading digit: 1xxx = public
    administration, 2xxx = private enterprise (includes state-owned
    companies structured as businesses, e.g. Petrobras - legal structure,
    not who owns it), 3xxx = non-profit, 4xxx = individual, 5xxx =
    international.

    All of these (demographics, size, legal nature) are computed for every
    row here, active or not - employment status only gets applied as a
    filter later, right before the industry-level collapses.
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

    generate byte size_0        = (estab_size == 1) if !missing(estab_size)
    generate byte size_1_4      = (estab_size == 2) if !missing(estab_size)
    generate byte size_5_9      = (estab_size == 3) if !missing(estab_size)
    generate byte size_10_19    = (estab_size == 4) if !missing(estab_size)
    generate byte size_20_49    = (estab_size == 5) if !missing(estab_size)
    generate byte size_50_99    = (estab_size == 6) if !missing(estab_size)
    generate byte size_100_249  = (estab_size == 7) if !missing(estab_size)
    generate byte size_250_499  = (estab_size == 8) if !missing(estab_size)
    generate byte size_500_999  = (estab_size == 9) if !missing(estab_size)
    generate byte size_1000plus = (estab_size == 10) if !missing(estab_size)
    generate byte size_missing  = (estab_size == -1) | missing(estab_size)

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
	
	* Generate County Population Variable
	gen population = 1

    /* Notes:

    (mean) of a 0/1 dummy IS the share/proportion directly. This first
    collapse - municipality level, no industry, no employment filter - is
    why share_employed is meaningful: it's the mean of "employed" over
    EVERYONE, not just people already filtered down to the employed.
    */
}
    preserve

        collapse (mean) race_indigenous race_white race_black race_asian race_mixed race_missing ///
                        nat_brazilian nat_foreign nat_missing ///
                        educ_below_hs educ_hs educ_higher educ_missing ///
                        age_youth age_prime age_older age_missing age ///
                        term_fired term_resigned term_retired ///
                        share_employed = employed ///
                 (count) population ///
                 (firstnm) state year, ///
                 by(municipality)

        if `first' == 1 {
            save `muni_stack', replace
        }
        else {
            append using `muni_stack'
            save `muni_stack', replace
        }

    restore

    * Same unfiltered-population reasoning as share_employed - a fired
    * person isn't active as of Dec 31, so this has to run before the
    * employed==1 filter below, not after.
    preserve

        collapse (mean) term_fired term_resigned term_retired ///
                 (count) n_total = employed ///
                 (first) state year, ///
                 by(municipality cnae2)

        if `first' == 1 {
            save `term_stack', replace
        }
        else {
            append using `term_stack'
            save `term_stack', replace
        }

    restore

    * From here on, only active/employed vinculos - matches the definition
    * used everywhere else in this project. This is what the industry-level
    * collapses below are built on.
    keep if employed == 1

    local industry_vars race_indigenous race_white race_black race_asian race_mixed race_missing ///
        nat_brazilian nat_foreign nat_missing ///
        educ_below_hs educ_hs educ_higher educ_missing ///
        age_youth age_prime age_older age_missing age ///
        size_0 size_1_4 size_5_9 size_10_19 size_20_49 size_50_99 size_100_249 size_250_499 size_500_999 size_1000plus size_missing estab_size ///
        legalnat_public legalnat_private legalnat_nonprofit legalnat_individual legalnat_intl legalnat_missing ///
        tenure wage_dec wage_avg ///
        wage_jan wage_feb wage_mar wage_apr wage_may wage_jun wage_jul wage_aug wage_sep wage_oct wage_nov

    preserve

        collapse (mean) `industry_vars' (count) n_workers = employed ///
            (first) state year, ///
            by(municipality cnae2)

        if `first' == 1 {
            save `classe_stack', replace
        }
        else {
            append using `classe_stack'
            save `classe_stack', replace
        }

    restore

    collapse (mean) `industry_vars' (count) n_workers = employed ///
        (first) state year, ///
        by(municipality cnae2_subclass)

    if `first' == 1 {
        save `subclasse_stack', replace
        local first = 0
    }
    else {
        append using `subclasse_stack'
        save `subclasse_stack', replace
    }

    di as result "`f' done"

}

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 4: Combine states and save - municipality level    ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Same reasoning throughout Sections 4-7: states were collapsed
separately, so re-collapsing with an frequency weight on the count from
the prior stage properly re-averages shares/means across states instead
of naively re-averaging two group means as if the groups were equal size
(a share from 1,000 people and a share from 10 people aren't equally
trustworthy). fweight collapse doesn't carry the weight variable itself
forward, so each section recovers the total count with a quick merge
afterward. state/year ride along via (first) - each municipality only
ever appears in one state's file, so that's safe. */

use `muni_stack', clear

collapse (mean) race_indigenous race_white race_black race_asian race_mixed race_missing ///
                nat_brazilian nat_foreign nat_missing ///
                educ_below_hs educ_hs educ_higher educ_missing ///
                age_youth age_prime age_older age_missing age ///
                term_fired term_resigned term_retired share_employed ///
         (first) state year ///
         [fweight = n_records_total], by(municipality)

tempfile muni_final
save `muni_final'

use `muni_stack', clear
collapse (sum) n_records_total, by(municipality)
merge 1:1 municipality using `muni_final', nogen

* Sanity check - the filename-derived year should always match what's
* set in Section 1, since RAIS_RAW only points at one year's folder.
assert year == `year'

label variable municipality "IBGE municipality code"
label variable state "State abbreviation (from filename)"
label variable n_records_total "Count of all CNPJ-establishment vinculos records (employed or not)"
label variable race_indigenous "Share Indigena"
label variable race_white "Share Branca (white)"
label variable race_black "Share Preta (black)"
label variable race_asian "Share Amarela (Asian)"
label variable race_mixed "Share Parda (mixed)"
label variable race_missing "Share race not identified/missing"
label variable nat_brazilian "Share Brazilian (native or naturalized)"
label variable nat_foreign "Share foreign nationality"
label variable nat_missing "Share nationality missing"
label variable educ_below_hs "Share below high school"
label variable educ_hs "Share high school (incomplete or complete)"
label variable educ_higher "Share higher education (incomplete through doutorado)"
label variable educ_missing "Share education missing"
label variable age_youth "Share age under 25"
label variable age_prime "Share age 25-54"
label variable age_older "Share age 55+"
label variable age_missing "Share age missing"
label variable age "Mean age"
label variable term_fired "Share terminated this year for dismissal (motivo 10-12)"
label variable term_resigned "Share terminated this year by resignation (motivo 20-22)"
label variable term_retired "Share terminated this year for retirement/death (motivo 40,50,60-64,70-80)"
label variable share_employed "Share of vinculos records active as of Dec 31 - a formal-employment retention proxy, not a true unemployment rate (RAIS only observes people who had a formal job connection at some point that year)"
label variable year "Calendar year"

order year state municipality n_records_total share_employed ///
    race_indigenous race_white race_black race_asian race_mixed race_missing ///
    nat_brazilian nat_foreign nat_missing ///
    educ_below_hs educ_hs educ_higher educ_missing ///
    age_youth age_prime age_older age_missing age ///
    term_fired term_resigned term_retired

save "`RAIS_WORKING'/rais_municipality_`year'.dta", replace

di as result "Done - saved `=_N' municipality rows to `RAIS_WORKING'/rais_municipality_`year'.dta"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 5: Combine states and save - municipality x Classe ***********
**********															 ***********
********************************************************************************
********************************************************************************

use `classe_stack', clear

collapse (mean) race_indigenous race_white race_black race_asian race_mixed race_missing ///
                nat_brazilian nat_foreign nat_missing ///
                educ_below_hs educ_hs educ_higher educ_missing ///
                age_youth age_prime age_older age_missing age ///
                size_0 size_1_4 size_5_9 size_10_19 size_20_49 size_50_99 size_100_249 size_250_499 size_500_999 size_1000plus size_missing estab_size ///
                legalnat_public legalnat_private legalnat_nonprofit legalnat_individual legalnat_intl legalnat_missing ///
                tenure wage_dec wage_avg ///
                wage_jan wage_feb wage_mar wage_apr wage_may wage_jun wage_jul wage_aug wage_sep wage_oct wage_nov ///
         (first) state year ///
         [fweight = n_workers], by(municipality cnae2)

tempfile classe_final
save `classe_final'

use `classe_stack', clear
collapse (sum) n_workers, by(municipality cnae2)
merge 1:1 municipality cnae2 using `classe_final', nogen

assert year == `year'

label variable municipality "IBGE municipality code"
label variable state "State abbreviation (from filename)"
label variable cnae2 "Industry, CNAE 2.0 classe (5-digit)"
label variable n_workers "Count of active (Dec 31), CNPJ-establishment workers in this cell"
label variable race_indigenous "Share Indigena"
label variable race_white "Share Branca (white)"
label variable race_black "Share Preta (black)"
label variable race_asian "Share Amarela (Asian)"
label variable race_mixed "Share Parda (mixed)"
label variable race_missing "Share race not identified/missing"
label variable nat_brazilian "Share Brazilian (native or naturalized)"
label variable nat_foreign "Share foreign nationality"
label variable nat_missing "Share nationality missing"
label variable educ_below_hs "Share below high school"
label variable educ_hs "Share high school (incomplete or complete)"
label variable educ_higher "Share higher education (incomplete through doutorado)"
label variable educ_missing "Share education missing"
label variable age_youth "Share age under 25"
label variable age_prime "Share age 25-54"
label variable age_older "Share age 55+"
label variable age_missing "Share age missing"
label variable age "Mean age"
label variable size_0 "Share establishment size: 0 employees"
label variable size_1_4 "Share establishment size: 1-4"
label variable size_5_9 "Share establishment size: 5-9"
label variable size_10_19 "Share establishment size: 10-19"
label variable size_20_49 "Share establishment size: 20-49"
label variable size_50_99 "Share establishment size: 50-99"
label variable size_100_249 "Share establishment size: 100-249"
label variable size_250_499 "Share establishment size: 250-499"
label variable size_500_999 "Share establishment size: 500-999"
label variable size_1000plus "Share establishment size: 1000+"
label variable size_missing "Share establishment size missing"
label variable estab_size "Mean establishment size bracket (ordinal code, 1-10)"
label variable legalnat_public "Share public administration (legal nature 1xxx)"
label variable legalnat_private "Share private enterprise (legal nature 2xxx)"
label variable legalnat_nonprofit "Share non-profit (legal nature 3xxx)"
label variable legalnat_individual "Share individual (legal nature 4xxx)"
label variable legalnat_intl "Share international org (legal nature 5xxx)"
label variable legalnat_missing "Share legal nature missing"
label variable tenure "Mean job tenure, years"
label variable wage_dec "Mean December wage, nominal R$"
label variable wage_avg "Mean average monthly wage, nominal R$"
label variable wage_jan "Mean January wage, nominal R$"
label variable wage_feb "Mean February wage, nominal R$"
label variable wage_mar "Mean March wage, nominal R$"
label variable wage_apr "Mean April wage, nominal R$"
label variable wage_may "Mean May wage, nominal R$"
label variable wage_jun "Mean June wage, nominal R$"
label variable wage_jul "Mean July wage, nominal R$"
label variable wage_aug "Mean August wage, nominal R$"
label variable wage_sep "Mean September wage, nominal R$"
label variable wage_oct "Mean October wage, nominal R$"
label variable wage_nov "Mean November wage, nominal R$"
label variable year "Calendar year"

order year state municipality cnae2 n_workers ///
    race_indigenous race_white race_black race_asian race_mixed race_missing ///
    nat_brazilian nat_foreign nat_missing ///
    educ_below_hs educ_hs educ_higher educ_missing ///
    age_youth age_prime age_older age_missing age ///
    size_0 size_1_4 size_5_9 size_10_19 size_20_49 size_50_99 size_100_249 size_250_499 size_500_999 size_1000plus size_missing estab_size ///
    legalnat_public legalnat_private legalnat_nonprofit legalnat_individual legalnat_intl legalnat_missing ///
    tenure wage_dec wage_avg ///
    wage_jan wage_feb wage_mar wage_apr wage_may wage_jun wage_jul wage_aug wage_sep wage_oct wage_nov

save "`RAIS_WORKING'/rais_municipality_classe_`year'.dta", replace

di as result "Done - saved `=_N' municipality x classe rows to `RAIS_WORKING'/rais_municipality_classe_`year'.dta"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 6: Combine states and save - municipality x        ***********
********** Subclasse                                                  ***********
**********															 ***********
********************************************************************************
********************************************************************************

use `subclasse_stack', clear

collapse (mean) race_indigenous race_white race_black race_asian race_mixed race_missing ///
                nat_brazilian nat_foreign nat_missing ///
                educ_below_hs educ_hs educ_higher educ_missing ///
                age_youth age_prime age_older age_missing age ///
                size_0 size_1_4 size_5_9 size_10_19 size_20_49 size_50_99 size_100_249 size_250_499 size_500_999 size_1000plus size_missing estab_size ///
                legalnat_public legalnat_private legalnat_nonprofit legalnat_individual legalnat_intl legalnat_missing ///
                tenure wage_dec wage_avg ///
                wage_jan wage_feb wage_mar wage_apr wage_may wage_jun wage_jul wage_aug wage_sep wage_oct wage_nov ///
         (first) state year ///
         [fweight = n_workers], by(municipality cnae2_subclass)

tempfile subclasse_final
save `subclasse_final'

use `subclasse_stack', clear
collapse (sum) n_workers, by(municipality cnae2_subclass)
merge 1:1 municipality cnae2_subclass using `subclasse_final', nogen

assert year == `year'

label variable municipality "IBGE municipality code"
label variable state "State abbreviation (from filename)"
label variable cnae2_subclass "Industry, CNAE 2.0 subclasse (7-digit)"
label variable n_workers "Count of active (Dec 31), CNPJ-establishment workers in this cell"
label variable race_indigenous "Share Indigena"
label variable race_white "Share Branca (white)"
label variable race_black "Share Preta (black)"
label variable race_asian "Share Amarela (Asian)"
label variable race_mixed "Share Parda (mixed)"
label variable race_missing "Share race not identified/missing"
label variable nat_brazilian "Share Brazilian (native or naturalized)"
label variable nat_foreign "Share foreign nationality"
label variable nat_missing "Share nationality missing"
label variable educ_below_hs "Share below high school"
label variable educ_hs "Share high school (incomplete or complete)"
label variable educ_higher "Share higher education (incomplete through doutorado)"
label variable educ_missing "Share education missing"
label variable age_youth "Share age under 25"
label variable age_prime "Share age 25-54"
label variable age_older "Share age 55+"
label variable age_missing "Share age missing"
label variable age "Mean age"
label variable size_0 "Share establishment size: 0 employees"
label variable size_1_4 "Share establishment size: 1-4"
label variable size_5_9 "Share establishment size: 5-9"
label variable size_10_19 "Share establishment size: 10-19"
label variable size_20_49 "Share establishment size: 20-49"
label variable size_50_99 "Share establishment size: 50-99"
label variable size_100_249 "Share establishment size: 100-249"
label variable size_250_499 "Share establishment size: 250-499"
label variable size_500_999 "Share establishment size: 500-999"
label variable size_1000plus "Share establishment size: 1000+"
label variable size_missing "Share establishment size missing"
label variable estab_size "Mean establishment size bracket (ordinal code, 1-10)"
label variable legalnat_public "Share public administration (legal nature 1xxx)"
label variable legalnat_private "Share private enterprise (legal nature 2xxx)"
label variable legalnat_nonprofit "Share non-profit (legal nature 3xxx)"
label variable legalnat_individual "Share individual (legal nature 4xxx)"
label variable legalnat_intl "Share international org (legal nature 5xxx)"
label variable legalnat_missing "Share legal nature missing"
label variable tenure "Mean job tenure, years"
label variable wage_dec "Mean December wage, nominal R$"
label variable wage_avg "Mean average monthly wage, nominal R$"
label variable wage_jan "Mean January wage, nominal R$"
label variable wage_feb "Mean February wage, nominal R$"
label variable wage_mar "Mean March wage, nominal R$"
label variable wage_apr "Mean April wage, nominal R$"
label variable wage_may "Mean May wage, nominal R$"
label variable wage_jun "Mean June wage, nominal R$"
label variable wage_jul "Mean July wage, nominal R$"
label variable wage_aug "Mean August wage, nominal R$"
label variable wage_sep "Mean September wage, nominal R$"
label variable wage_oct "Mean October wage, nominal R$"
label variable wage_nov "Mean November wage, nominal R$"
label variable year "Calendar year"

order year state municipality cnae2_subclass n_workers ///
    race_indigenous race_white race_black race_asian race_mixed race_missing ///
    nat_brazilian nat_foreign nat_missing ///
    educ_below_hs educ_hs educ_higher educ_missing ///
    age_youth age_prime age_older age_missing age ///
    size_0 size_1_4 size_5_9 size_10_19 size_20_49 size_50_99 size_100_249 size_250_499 size_500_999 size_1000plus size_missing estab_size ///
    legalnat_public legalnat_private legalnat_nonprofit legalnat_individual legalnat_intl legalnat_missing ///
    tenure wage_dec wage_avg ///
    wage_jan wage_feb wage_mar wage_apr wage_may wage_jun wage_jul wage_aug wage_sep wage_oct wage_nov

save "`RAIS_WORKING'/rais_municipality_subclasse_`year'.dta", replace

di as result "Done - saved `=_N' municipality x subclasse rows to `RAIS_WORKING'/rais_municipality_subclasse_`year'.dta"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 7: Combine states and save - municipality x        ***********
********** industry job separations (all vinculos, not just employed) ***********
**********															 ***********
********************************************************************************
********************************************************************************

use `term_stack', clear

collapse (mean) term_fired term_resigned term_retired ///
         (first) state year ///
         [fweight = n_total], by(municipality cnae2)

tempfile term_final
save `term_final'

use `term_stack', clear
collapse (sum) n_total, by(municipality cnae2)
merge 1:1 municipality cnae2 using `term_final', nogen

assert year == `year'

label variable municipality "IBGE municipality code"
label variable state "State abbreviation (from filename)"
label variable cnae2 "Industry, CNAE 2.0 classe (5-digit)"
label variable n_total "Count of all vinculos records (employed or not) in this cell"
label variable term_fired "Share terminated this year for dismissal (motivo 10-12)"
label variable term_resigned "Share terminated this year by resignation (motivo 20-22)"
label variable term_retired "Share terminated this year for retirement/death (motivo 40,50,60-64,70-80)"
label variable year "Calendar year"

order year state municipality cnae2 n_total term_fired term_resigned term_retired

save "`RAIS_WORKING'/rais_municipality_cnae_separations_`year'.dta", replace

di as result "Done - saved `=_N' municipality x cnae2 separation rows to `RAIS_WORKING'/rais_municipality_cnae_separations_`year'.dta"
