* ==========================================================================
* Clean World Bank Pink Sheet metal prices: monthly, nominal USD, one row
* per year-month, 1960 onward.
*
* Input:
*   Data/WB Prices/CMO-Historical-Data-Monthly.xlsx
*
* Output:
*   Working/WB Prices/wb_commodity_prices_monthly.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: Import raw data & keep the metals columns
*		Section 2: Parse the year-month
*		Section 3: Label variables and save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

local WB_RAW     "$RAW_DIR/WB Prices"
local WB_WORKING "$WORKING_DIR/WB Prices"

capture mkdir "`WB_WORKING'"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Import raw data & keep the metals columns      ***********
**********															 ***********
********************************************************************************
********************************************************************************

import excel "`WB_RAW'/CMO-Historical-Data-Monthly.xlsx", ///
    sheet("Monthly Prices") cellrange(A5) firstrow case(lower) clear

/* Notes:

firstrow reads row 5 (commodity names) as variable names. Most of the
metals are one clean word so case(lower) is all they need - aluminum,
copper, lead, tin, nickel, zinc, gold, platinum, silver come in exactly
like that. "Iron ore, cfr spot" has a comma and spaces, so Stata mangles
it into something else - check the describe output below to confirm what,
and fix the capture renames if neither guess matches.

Column A's header cell is blank, so Stata names it after the spreadsheet
column letter instead - "a". Confirmed by the user directly.

Row 6 (units, e.g. "($/mt)") lands in the data as observation 1, not as
column labels, which also means every commodity column imports as string
(text mixed with numbers in the same column). We grab that unit text for
the variable labels below, then drop the row and destring.
*/

rename (a ironorecfrspot) (period_text iron)
keep period_text aluminum iron copper lead tin nickel zinc gold platinum silver

/* Notes:

Iron ore is priced in $/dmtu (dry metric ton unit - price per 1% Fe
content), not $/mt like the other metals - pulled below along with
everyone else's unit, so it'll show up in its own label rather than
needing to be remembered separately.
*/
foreach m in aluminum iron copper lead tin nickel zinc gold platinum silver {
    gen `m'_unit = `m'[1]
}

drop if _n == 1
drop if missing(period_text)

destring aluminum iron copper lead tin nickel zinc gold platinum silver, ///
    replace force

rename (aluminum iron copper lead tin nickel zinc gold platinum silver) ///
    (aluminum_price iron_price copper_price lead_price tin_price nickel_price zinc_price gold_price platinum_price silver_price)

********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 2: Parse the year-month              ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* period_text is like "1960M01" - split on "M" into year and month, then
build a real Stata monthly date so this merges/sorts properly. */

generate int year  = real(substr(period_text, 1, 4))
generate int month = real(substr(period_text, 6, 2))

generate year_month = ym(year, month)
format year_month %tm

drop period_text

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 3: Label variables and save                       ***********
**********															 ***********
********************************************************************************
********************************************************************************

local newnames year month year_month aluminum_price iron_price copper_price ///
    lead_price tin_price nickel_price zinc_price gold_price platinum_price silver_price

foreach v of local newnames {

    local lbl = cond("`v'" == "year", "Calendar year", ///
                cond("`v'" == "month", "Calendar month (1-12)", ///
                cond("`v'" == "year_month", "Year-month, Stata %tm date", ///
                cond("`v'" == "aluminum_price", "Aluminum, LME spot - see aluminum_unit for units", ///
                cond("`v'" == "iron_price", "Iron ore, CFR spot - see iron_unit for units, not the same unit as the other metals", ///
                cond("`v'" == "copper_price", "Copper, LME spot - see copper_unit for units", ///
                cond("`v'" == "lead_price", "Lead, LME spot - see lead_unit for units", ///
                cond("`v'" == "tin_price", "Tin, LME spot - see tin_unit for units", ///
                cond("`v'" == "nickel_price", "Nickel, LME spot - see nickel_unit for units", ///
                cond("`v'" == "zinc_price", "Zinc, LME spot - see zinc_unit for units", ///
                cond("`v'" == "gold_price", "Gold - see gold_unit for units", ///
                cond("`v'" == "platinum_price", "Platinum - see platinum_unit for units", ///
                cond("`v'" == "silver_price", "Silver - see silver_unit for units", ///
                "Error `v'")))))))))))))

    label variable `v' "`lbl'"

}

order year month year_month aluminum* iron* copper* lead* tin* nickel* zinc* gold* platinum* silver*

save "`WB_WORKING'/wb_commodity_prices_monthly.dta", replace

di as result "Done - saved `=_N' monthly commodity price observations to `WB_WORKING'/wb_commodity_prices_monthly.dta"
