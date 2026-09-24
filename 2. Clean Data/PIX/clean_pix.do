* ==========================================================================
* Clean Pix transactions by municipality: monthly, one row per
* municipality x month, since Nov 2020.
*
* No industry breakdown is available crossed with municipality in Pix's
* open data (see pull_pix.py's notes) - this is municipality-level
* economic activity only, not municipality x sector. Kept at monthly
* granularity rather than collapsed to annual here.
*
* Input:
*   Data/PIX/pix_transacoes_municipio.csv
*
* Output:
*   Working/PIX/pix_municipio_monthly.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session,
* and pull_pix.py to actually get the raw file.
*
* File Organization:
*
*		Section 1: Import raw data
*		Section 2: Rename, parse the year-month, destring
*		Section 3: Label variables and save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

local PIX_RAW     "$RAW_DIR/PIX"
local PIX_WORKING "$WORKING_DIR/PIX"

capture mkdir "`PIX_WORKING'"

********************************************************************************
********************************************************************************
**********															 ***********
********** 					Section 1: Import raw data               ***********
**********															 ***********
********************************************************************************
********************************************************************************

import delimited using "`PIX_RAW'/pix_transacoes_municipio.csv", ///
    clear varnames(1) encoding("utf-8")

/* Notes:

	PF = Pessoa Física (individual), PJ = Pessoa Jurídica (business).
	Pagador = payer, Recebedor = receiver. VL_ = value (R$), QT_ = count of
	transactions, QT_PES_ = count of distinct people/firms involved (not
	transactions - a person who pays 10 times in a month counts once here).

*/


**********************
** Rename Variables **
**********************

rename ( /*
     
	 Original: Time Variable
	 */ anomes /*
     Original: Geographic ID Variables 
	 */ municipio_ibge municipio estado_ibge estado /*
     Original: Value of Transfers Variables (R$) 
	 */ vl_pagadorpf vl_pagadorpj vl_recebedorpf vl_recebedorpj /*
     Original: Transaction Count Variables 
	 */ qt_pagadorpf qt_pagadorpj qt_recebedorpf qt_recebedorpj /*
     Original: Distinct-Participant Count Variables 
	 */ qt_pes_pagadorpf qt_pes_pagadorpj qt_pes_recebedorpf qt_pes_recebedorpj) /*
    
	

     Final: Time Variable 
	 */ (year_month_raw /*
     Final: Geographic ID Variables 
	 */ municipality municipality_name pix_state_code_ibge state_name /*
     Final: Value of Transfers Variables (R$) 
	 */ pix_value_payer_pf pix_value_payer_pj pix_value_receiver_pf pix_value_receiver_pj /*
     Final: Transaction Count Variables 
	 */ pix_count_payer_pf pix_count_payer_pj pix_count_receiver_pf pix_count_receiver_pj /*
     Final: Distinct-Participant Count Variables 
	 */ pix_n_payers_pf pix_n_payers_pj pix_n_receivers_pf pix_n_receivers_pj)


******************************
** Keep Necessary Variables **
******************************
	
local needed_vars municipality year_month_raw municipality_name state_name ///
    pix_state_code_ibge pix_value_payer_pf pix_count_payer_pf ///
    pix_value_payer_pj pix_count_payer_pj pix_value_receiver_pf pix_count_receiver_pf ///
    pix_value_receiver_pj pix_count_receiver_pj pix_n_payers_pf pix_n_payers_pj ///
    pix_n_receivers_pf pix_n_receivers_pj

* municipality_name/state_name are real text (city/state names) -
* everything else in needed_vars is actually numeric and needs destring.
local text_vars municipality_name state_name
local numeric_vars : list needed_vars - text_vars

keep `needed_vars'

foreach v of local numeric_vars {
    capture destring `v', replace force dpcomma
}

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 2: Parse the year-month              ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* year_month_raw is like 202301 (YYYYMM as an integer) - split into year
and month, then build a real Stata monthly date so this merges/sorts
properly, same approach as clean_wb_prices.do. */

generate int year  = floor(year_month_raw / 100)
generate int month = mod(year_month_raw, 100)

generate year_month = ym(year, month)
format year_month %tm

drop year_month_raw

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 3: Label variables and save          ***********
**********															 ***********
********************************************************************************
********************************************************************************

label variable municipality "IBGE municipality code"
label variable year "Calendar year"
label variable month "Calendar month"
label variable year_month "Year-month, Stata %tm date"
label variable municipality_name "Municipality name"
label variable state_name "State name"
label variable pix_state_code_ibge "IBGE state code"
label variable pix_value_payer_pf "Total R$ value sent by individuals (PF)"
label variable pix_count_payer_pf "Count of Pix transactions sent by individuals (PF)"
label variable pix_value_payer_pj "Total R$ value sent by businesses (PJ)"
label variable pix_count_payer_pj "Count of Pix transactions sent by businesses (PJ)"
label variable pix_value_receiver_pf "Total R$ value received by individuals (PF)"
label variable pix_count_receiver_pf "Count of Pix transactions received by individuals (PF)"
label variable pix_value_receiver_pj "Total R$ value received by businesses (PJ)"
label variable pix_count_receiver_pj "Count of Pix transactions received by businesses (PJ)"
label variable pix_n_payers_pf "Count of distinct individuals (PF) who paid at least once"
label variable pix_n_payers_pj "Count of distinct businesses (PJ) who paid at least once"
label variable pix_n_receivers_pf "Count of distinct individuals (PF) who received at least once"
label variable pix_n_receivers_pj "Count of distinct businesses (PJ) who received at least once"

order year month year_month municipality municipality_name state_name ///
    pix_state_code_ibge pix_value_payer_pf pix_count_payer_pf ///
    pix_value_payer_pj pix_count_payer_pj pix_value_receiver_pf pix_count_receiver_pf ///
    pix_value_receiver_pj pix_count_receiver_pj pix_n_payers_pf pix_n_payers_pj ///
    pix_n_receivers_pf pix_n_receivers_pj

save "`PIX_WORKING'/pix_municipio_monthly.dta", replace

di as result "Done - saved `=_N' municipality x month Pix observations to `PIX_WORKING'/pix_municipio_monthly.dta"
