* ==========================================================================
* Clean IBGE's 2015 Input-Output Matrix down to a simple, mergeable file.
* This is the data source for classifying each CNAE67 industry's backward
* and forward linkage to mining.
*
* Source: IBGE's official FTP:
* ftp://ftp.ibge.gov.br/Contas_Nacionais/Matriz_de_Insumo_Produto/2015/
* ftp://ftp.ibge.gov.br/Contas_Nacionais/Sistema_de_Contas_Nacionais/2015/tabelas_xls/sinoticas/
* 2015 is IBGE's most recent published Input-Output Matrix.
*
* Three tables get used, from two different workbooks:
*   - Tabela 14 ("Matriz D.Bn") - DIRECT requirements, industry x
*     industry. (Matriz_de_Insumo_Produto workbook)
*   - Tabela 02's "Total" row - intermediate consumption per industry
*     (same workbook), plus Tabela 10.2 - value added per industry, a
*     SEPARATE workbook (Sistema_de_Contas_Nacionais). Together these
*     give Output = Intermediate Consumption + Value Added.
*
* Mining, for our purposes, is 3 industries - 0680 (oil/gas) is excluded
* even though CNAE groups it in the same broad "Extractive Industries"
* section, since it comes from drilled wells, not an actual mine:
*   0580 - Coal mining and non-metallic mineral extraction
*   0791 - Iron ore extraction, including processing/beneficiation and
*          agglomeration (pelletizing/sintering) (iron ore specifically)
*   0792 - Non-ferrous metallic mineral extraction (other metals besides
*          iron - aluminum, tin, manganese, etc.), including
*          processing/beneficiation
*
* Input:
*   Data/IO Matrix/Matriz_de_Insumo_Produto_2015_Nivel_67.xls
*   Data/IO Matrix/tab10_2.xls
*   (both from pull_io_matrix.py)
*
* Output:
*   Working/IO Matrix/io_matrix_activity_totals_2015.dta
*   Working/IO Matrix/io_matrix_mining_classification.dta
*
* BEFORE running this file, run Code/config.do once in your Stata
* session, and pull_io_matrix.py to actually get the raw files.
*
* File Organization:
*
*		Section 1: Reshape the raw files (via Python helper) if needed
*		Section 2: Industry totals - intermediate consumption, value
*		           added, and output (IC + VA)
*		Section 3: Mining exposure classification - backward and
*		           forward linkage
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

global IOMATRIX_RAW     "$RAW_DIR/IO Matrix"
global IOMATRIX_WORKING "$WORKING_DIR/IO Matrix"

* Everything below builds its own path off these two globals inline
* ($IOMATRIX_RAW/filename.csv, etc.) - so any line can be run on its own,
* without re-running the rest of the file first, and without a separate
* global for every single file.
capture mkdir "$IOMATRIX_WORKING"

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 1: Reshape the raw files     		 ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

Both raw files are awkward shapes for Stata's import tools - let Python do
the reshape (reshape_io_matrix.py). It reads both workbooks and writes two
clean CSVs: the pairwise 67x67 matrix, and a 67-row industry totals file
(intermediate consumption + value added).

*/

capture confirm file "$IOMATRIX_RAW/Matriz_de_Insumo_Produto_2015_Nivel_67.xls"
if _rc {
    di as error "Raw IO matrix file not found: $IOMATRIX_RAW/Matriz_de_Insumo_Produto_2015_Nivel_67.xls"
    di as error "Run pull_io_matrix.py first."
    exit 601
}

capture confirm file "$IOMATRIX_RAW/tab10_2.xls"
if _rc {
    di as error "Value added file not found: $IOMATRIX_RAW/tab10_2.xls"
    di as error "Run pull_io_matrix.py first."
    exit 601
}

capture confirm file "$IOMATRIX_RAW/io_matrix_67_2015_long.csv"
local need_reshape = _rc
if !`need_reshape' {
    capture confirm file "$IOMATRIX_RAW/io_matrix_activity_totals_2015.csv"
    local need_reshape = _rc
}

if `need_reshape' {
    * "python", not "python3" - confirmed directly on Windows "python3"
    * resolves to the Microsoft Store stub, not the real install, and
    * fails silently rather than raising a visible error.
    shell python "$REPO_PATH/2. Clean Data/IO Matrix/reshape_io_matrix.py" "$IOMATRIX_RAW/Matriz_de_Insumo_Produto_2015_Nivel_67.xls" "$IOMATRIX_RAW/tab10_2.xls" "$IOMATRIX_RAW/io_matrix_67_2015_long.csv" "$IOMATRIX_RAW/io_matrix_activity_totals_2015.csv"

    * shell doesn't check whether the script it ran actually succeeded -
    * confirm both files are really there now rather than let a failed
    * reshape cascade into a confusing import error below.
    capture confirm file "$IOMATRIX_RAW/io_matrix_67_2015_long.csv"
    if _rc {
        di as error "reshape_io_matrix.py did not produce the long-format file - run it directly (not through Stata) to see the real error."
        exit 601
    }
    capture confirm file "$IOMATRIX_RAW/io_matrix_activity_totals_2015.csv"
    if _rc {
        di as error "reshape_io_matrix.py did not produce the industry totals file - run it directly (not through Stata) to see the real error."
        exit 601
    }
}

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 2: Industry totals             	 	 ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

	This section generates total output for each CNAE67 in 2015. To be used later 
	in calculations of exposure to mining.
	
*/

import delimited using "$IOMATRIX_RAW/io_matrix_activity_totals_2015.csv", clear varnames(1)

* Output = Intermediate Consumption + Value Added - the standard national
* accounts identity. IBGE doesn't publish industry-level output as its own
* table; this reconstructs it from two tables that do exist (see header).
generate output = intermediate_consumption + value_added

label variable cnae67 "CNAE67 industry code"
label variable intermediate_consumption "Total intermediate consumption, 2015 current prices - IBGE's native units, not independently verified"
label variable value_added "Gross value added, 2015 current prices - IBGE's native units, not independently verified"
label variable output "Total output = intermediate consumption + value added (national accounts identity - not directly published by IBGE as its own table)"

save "$IOMATRIX_WORKING/io_matrix_activity_totals_2015.dta", replace

********************************************************************************
********************************************************************************
**********															 ***********
********** 		Section 3: Mining exposure classification    		 ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

Classifies each industry's linkage to mining, 2 ways:
	
	Backward Exposure: Share of the industry's OWN output that it sells to mining.
		How its Calculated Intuitively:

		1) IBGE publishes direct requirement coefficients, calculated as
		   [goods from this industry purchased by mining] / [total mining output]

		2) We already have [total mining output] (output_user here - mining is
		   the "user"/buyer in this direction). Multiply direct_coef by
		   output_user to get [goods from this industry purchased by mining] in
		   actual reais.

		3) Divide that by [total output of this industry] (output_supplier -
		   this industry is the "supplier" here) to get:

				[goods purchased by mining] / [total output of this industry]

	   In other words, the share of THIS industry's own output that mining
	   buys - backward_exposure.
	
	
	

	Forward Linkages - Share of the industry's OWN output that consists of
	mining inputs. 
		How its Calculated Intuitively:
		
		This is literally IBGE's raw direct requirement coefficient, no extra 
		calculations neededmath needed.


*/

************************************************
** Import Data & Merge Total Output Variables **
************************************************

import delimited using "$IOMATRIX_RAW/io_matrix_67_2015_long.csv", clear varnames(1)

* Keep only pairs where mining is on one side or the other.
keep if inlist(supplier_cnae67, 580, 791, 792) | inlist(user_cnae67, 580, 791, 792)

* Merge total output onto both sides.
foreach x in "supplier" "user" {

	rename `x'_cnae67 cnae67
	merge m:1 cnae67 using "$IOMATRIX_WORKING/io_matrix_activity_totals_2015.dta", keepusing(output)
	assert _merge == 3
	drop _merge
	rename output output_`x'
	rename cnae67 `x'_cnae67

}

*******************************************
*******************************************
** Calculate Forward & Backward Exposure **
*******************************************
*******************************************

* Keep these mining codes
local mining_codes "580, 791, 792"

preserve

*****************************************
** Backward (industry supplies mining) **
*****************************************

keep if inlist(user_cnae67, `mining_codes')

* Calculate $ flowing from industry i to mining
generate flow_level = direct_coef * output_user

* Divide $ flow by total output in industry i
generate backward_exposure = flow_level / output_supplier

* Rename variables & reshape 
keep supplier_cnae67 user_cnae67 backward_exposure
rename supplier_cnae67 cnae67
rename user_cnae67 mining_code
reshape wide backward_exposure, i(cnae67) j(mining_code)
rename (backward_exposure580 backward_exposure791 backward_exposure792) ///
       (backward_coal backward_iron backward_other)

* Generate exposure to all mining industries (coal + iron + other)
generate backward_nonironmining = backward_coal + backward_other
generate backward_allmining = backward_iron + backward_nonironmining

* Save file
tempfile backward
save `backward'

restore

****************************
** Forward (mining supplies industry) **
****************************

keep if inlist(supplier_cnae67, `mining_codes')

* direct_coef here is already normalized by the industry's own output
* (the industry is the buyer in this direction)
keep supplier_cnae67 user_cnae67 direct_coef
rename user_cnae67 cnae67
rename supplier_cnae67 mining_code
reshape wide direct_coef, i(cnae67) j(mining_code)

rename (direct_coef580 direct_coef791 direct_coef792) ///
       (forward_coal forward_iron forward_other)

generate forward_nonironmining = forward_coal + forward_other
generate forward_allmining = forward_iron + forward_nonironmining

merge 1:1 cnae67 using `backward', nogenerate

********************
** Label and save **
********************

label variable cnae67 "CNAE67 industry code"

label variable backward_coal "Backward linkage: share of this industry's own output sold to coal/non-metallic mining (580)"
label variable backward_iron "Backward linkage: share of this industry's own output sold to iron ore mining (791)"
label variable backward_other "Backward linkage: share of this industry's own output sold to other mining (792 - non-ferrous metals)"
label variable backward_nonironmining "Backward linkage: share of this industry's own output sold to mining excl. iron (580+792 summed)"
label variable backward_allmining "Backward linkage: share of this industry's own output sold to all 3 mining industries (summed)"

label variable forward_coal "Forward linkage: share of this industry's own output made up of coal/non-metallic mining (580) inputs"
label variable forward_iron "Forward linkage: share of this industry's own output made up of iron ore mining (791) inputs"
label variable forward_other "Forward linkage: share of this industry's own output made up of other mining (792 - non-ferrous metals) inputs"
label variable forward_nonironmining "Forward linkage: share of this industry's own output made up of mining excl. iron inputs (580+792 summed)"
label variable forward_allmining "Forward linkage: share of this industry's own output made up of all 3 mining industries' inputs (summed)"

order cnae67 ///
	backward_coal backward_iron backward_other backward_nonironmining backward_allmining ///
	forward_coal forward_iron forward_other forward_nonironmining forward_allmining

save "$IOMATRIX_WORKING/io_matrix_mining_classification.dta", replace


