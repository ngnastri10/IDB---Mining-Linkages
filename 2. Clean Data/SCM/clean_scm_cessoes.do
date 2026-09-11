* ==========================================================================
* Clean SCM Cessoes de Direitos: one row per rights-transfer record (a
* process can change hands more than once).
*
* Input:
*   Data/SCM/Cessoes/Cessoes_de_Direitos.csv
*
* Output:
*   Working/SCM/scm_cessoes_record.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: Import raw data & rename variables of interest
*		Section 2: Split process number/year, parse the date
*		Section 3: Label variables and save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

local SCM_RAW     "$RAW_DIR/SCM"
local SCM_WORKING "$WORKING_DIR/SCM"

capture mkdir "`SCM_WORKING'"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Import raw data & rename variables of interest ***********
**********															 ***********
********************************************************************************
********************************************************************************

import delimited using "`SCM_RAW'/Cessoes/Cessoes_de_Direitos.csv", ///
    clear varnames(1) encoding("windows-1252")

/* Notes:

Check this describe output before trusting the renames below. The
source headers have parentheses - "Municipio(s)", "Substancia(s)",
"Tipo(s) de Uso" - which we haven't seen before in any other ANM file,
so it's genuinely unclear how Stata turns those into variable names.
That's why those specific renames are wrapped in capture.
*/
describe

capture rename superintendência regional_office
capture rename superintendencia regional_office

rename fase_atual phase_at_record
rename titular holder_name

capture rename cpf_cnpj_do_titular taxpayer_id
capture rename cpfcnpjdotitular taxpayer_id

capture rename tipo_de_requerimento request_type
capture rename tipoderequerimento request_type

capture rename municipios municipality_text
capture rename municipio_s municipality_text
capture rename municípios municipality_text
capture rename municípios_ municipality_text

capture rename substâncias substance_text
capture rename substancias substance_text
capture rename substância_s substance_text
capture rename substancia_s substance_text

capture rename tipos_de_uso use_type_text
capture rename tipo_s_de_uso use_type_text

capture rename situação is_active_text
capture rename situacao is_active_text

capture rename data_da_cessão cession_date_text
capture rename data_da_cessao cession_date_text

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 2: Split process number/year, parse the date      ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

processo here is "820757/1998" - no periods, same format as SIGMINE and
CFEM already gave us as separate columns. Just split on "/" and
destring both sides.
*/

generate str process_number_str = substr(processo, 1, strpos(processo, "/") - 1)
generate str process_year_str   = substr(processo, strpos(processo, "/") + 1, .)

destring process_number_str, generate(process_number)
destring process_year_str, generate(process_year)

drop process_number_str process_year_str processo

* Sim/Nao -> 1/0
generate byte is_active = (is_active_text == "Sim")
drop is_active_text

* cession_date_text is DD/MM/YYYY - turn it into an actual Stata date.
generate cession_date = date(cession_date_text, "DMY")
format cession_date %td
drop cession_date_text

* municipality_text, substance_text, use_type_text can each list more
* than one value separated by commas - left as raw text, not split out.

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 3: Label variables and save                       ***********
**********															 ***********
********************************************************************************
********************************************************************************

local newnames process_number process_year regional_office request_type ///
    phase_at_record taxpayer_id holder_name municipality_text substance_text ///
    use_type_text is_active cession_date

foreach v of local newnames {

    local lbl = cond("`v'" == "process_number", "Process number, without the year", ///
                cond("`v'" == "process_year", "Year the process was originally filed", ///
                cond("`v'" == "regional_office", "ANM regional office that opened the process", ///
                cond("`v'" == "request_type", "Type of request that opened the process", ///
                cond("`v'" == "phase_at_record", "Process phase as of this record - not necessarily the current phase, see notes above", ///
                cond("`v'" == "taxpayer_id", "CPF/CNPJ of the titleholder", ///
                cond("`v'" == "holder_name", "Name of the titleholder at the time of this cession", ///
                cond("`v'" == "municipality_text", "Municipality name(s), raw text - can list more than one", ///
                cond("`v'" == "substance_text", "Mineral substance(s), raw text - can list more than one, not translated", ///
                cond("`v'" == "use_type_text", "Intended use(s), raw text - can list more than one", ///
                cond("`v'" == "is_active", "1 if this process is active as of this record", ///
                cond("`v'" == "cession_date", "Date this rights transfer took effect", ///
                "Error `v'"))))))))))))

    label variable `v' "`lbl'"

}

save "`SCM_WORKING'/scm_cessoes_record.dta", replace

di as result "Done - saved `=_N' cession records to `SCM_WORKING'/scm_cessoes_record.dta"
