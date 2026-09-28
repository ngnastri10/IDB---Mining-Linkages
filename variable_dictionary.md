# Variable dictionary

Every variable in the final panel, `LARGE_DATA_ROOT/Merged/municipality_cnae67_year.dta`, built by `3. Merge Data/merge_municipality_cnae67_year.do`.

**One row = one municipality × CNAE67 industry × year, 2007–2025.** The panel is balanced: every municipality has all 67 industries in every year.

The first table is the snapshot. Click a family to jump to its full table, with one row per variable.

## Families at a glance

| # | Family | Variables | What it is | Varies by | Source |
|---|---|---|---|---|---|
| 1 | [IDs and panel structure](#1-ids-and-panel-structure) | 5 | Who, what industry, when | cell | RAIS + balancing |
| 2 | [Employment counts](#2-employment-counts) | 3 | How many jobs | cell | RAIS workers file |
| 3 | [Wages and tenure](#3-wages-and-tenure) | 14 | Average pay, time on the job | cell | RAIS workers file |
| 4 | [Worker demographics](#4-worker-demographics) | 21 | Education, age, race, sex, nationality | cell | RAIS workers file |
| 5 | [Employer characteristics](#5-employer-characteristics) | 11 | Size and legal type of the workplace | cell | RAIS workers file |
| 6 | [Hires and separations](#6-hires-and-separations) | 27 | Hires and exits by month, why people left | cell | RAIS workers file |
| 7 | [Establishments](#7-establishments) | 5 | Number of workplaces and their headcounts | cell | RAIS establishments file |
| 8 | [Input-output linkages to mining](#8-input-output-linkages-to-mining) | 10 | How tied the industry is to mining | industry | IBGE input-output matrix, 2015 |
| 9 | [Mine treatment](#9-mine-treatment) | 22 | Mines near the town: when, how many, who's in the sample | municipality × year | CFEM + SIGMINE + ANM registry |
| 10 | [Royalties](#10-royalties) | 3 | Mining royalties paid in the municipality | municipality × year | CFEM |
| 11 | [Price shock](#11-price-shock) | 9 | Shift-share mineral price shock | municipality × year | World Bank prices + CFEM + RAIS |
| 12 | [World Bank prices](#12-world-bank-prices) | 10 | International metal prices | year | World Bank Pink Sheet |
| 13 | [Pix payments](#13-pix-payments) | 12 | Instant-payment activity in the municipality | municipality × year | Central Bank of Brazil |

"Cell" means municipality × industry × year.

### Where the RAIS families come from

Families 2–6 are built on the HPC by `HPC/clean_rais_hpc.do` from the **RAIS workers file** ("Vínculos"). That file has one row per job held at any point during the year. A person with two jobs, or who changed jobs, shows up more than once. The script:

1. keeps every job record in the year, **not just jobs still active on December 31**;
2. turns category codes into 0/1 indicators (e.g. `race_white`);
3. collapses to municipality × CNAE67 × year. Most variables are **averages over job records**; the counts are **sums**.

Family 7 comes from the separate **RAIS establishments file**, one row per workplace, via `HPC/clean_rais_estab_hpc.do`.

Industries are mapped from CNAE 2.0 to CNAE67 with IBGE's official translator (`Data/Crosswalks/cnae2_to_cnae67.csv`, from `pull_crosswalks.py`).

**Balancing:** cells with no job records at all are added by `fillin` and flagged `filled_in = 1`. In those cells, counts are set to 0, but averages and shares stay **missing**: the average wage of zero workers doesn't exist.

---

## 1. IDs and panel structure

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `municipality` | Municipality, 6-digit IBGE code (no check digit) | RAIS | As in RAIS. Other sources' 7-digit codes are cut to 6 digits to match. |
| `state` | State, two-letter abbreviation (e.g. MG) | RAIS | From the first two digits of the municipality code. Copied onto filled-in rows. |
| `cnae67` | Industry, IBGE's 67-sector national-accounts classification | RAIS + IBGE translator | RAIS's CNAE 2.0 class (check digit stripped), mapped with `cnae2_to_cnae67`. Rows that don't map are dropped. |
| `year` | Calendar year, 2007–2025 | RAIS | RAIS reference year. |
| `filled_in` | 1 = the cell had no job records and was added to balance the panel | Merge | `fillin municipality cnae67 year`. |

## 2. Employment counts

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `number_employed` | Jobs active on December 31 | RAIS workers | Sum of the "active on Dec 31" flag. 0 in filled-in cells. **This is the usual employment measure.** |
| `population` | Number of job records during the year, active on Dec 31 or not | RAIS workers | Sum of 1 per job record. 0 in filled-in cells. |
| `employed` | Share of the year's job records still active on December 31 | RAIS workers | Average of the 0/1 "active on Dec 31" flag. |

## 3. Wages and tenure

All wages are **nominal reais**, averaged over job records in the cell.

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `wage_avg` | Average monthly pay over the months worked that year | RAIS workers | Average of RAIS "Vl Remun Média Nom". |
| `wage_dec` | December pay | RAIS workers | Average of RAIS "Vl Remun Dezembro Nom". |
| `wage_jan` … `wage_nov` | Pay in each month, January to November (11 variables: `wage_jan`, `wage_feb`, `wage_mar`, `wage_apr`, `wage_may`, `wage_jun`, `wage_jul`, `wage_aug`, `wage_sep`, `wage_oct`, `wage_nov`) | RAIS workers | Average of RAIS "Vl Rem <month>". **Only exists from 2015 on**; missing before. |
| `tenure` | Time in the job, in months | RAIS workers | Average of RAIS "Tempo Emprego". |

## 4. Worker demographics

Shares are averages of 0/1 indicators, so each is a share of job records.

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `age` | Average age, in years | RAIS workers | Average of "Idade". |
| `educ` | Average of the RAIS **education code** (1–11) | RAIS workers | Average of the category code. For shares, see `educ_*`. |
| `race` | Average of the RAIS **race code** | RAIS workers | Average of the category code. For shares, see `race_*`. |
| `share_male` | Share male | RAIS workers | Sex code 1 = male. |
| `race_indigenous` | Share Indigenous | RAIS workers | Race code 1. Among records with a race code. |
| `race_white` | Share white | RAIS workers | Race code 2. |
| `race_black` | Share Black | RAIS workers | Race code 4. |
| `race_asian` | Share Asian | RAIS workers | Race code 6. |
| `race_mixed` | Share mixed race (parda) | RAIS workers | Race code 8. |
| `race_missing` | Share with race unknown | RAIS workers | Race code 9, -1, or blank. |
| `nat_brazilian` | Share Brazilian | RAIS workers | Nationality codes 10, 20. |
| `nat_foreign` | Share foreign | RAIS workers | Nationality codes 21–80. |
| `nat_missing` | Share with nationality unknown | RAIS workers | Code -1 or blank. |
| `educ_below_hs` | Share below high school | RAIS workers | Education codes 1–5. |
| `educ_hs` | Share with high school (complete or incomplete) | RAIS workers | Education codes 6–7. |
| `educ_higher` | Share with some higher education or more | RAIS workers | Education codes 8–11. |
| `educ_missing` | Share with education unknown | RAIS workers | Code -1 or blank. |
| `age_youth` | Share aged 24 or under | RAIS workers | Age 0–24. |
| `age_prime` | Share aged 25–54 | RAIS workers | Age 25–54. |
| `age_older` | Share aged 55+ | RAIS workers | Age 55 and over. |
| `age_missing` | Share with age unknown | RAIS workers | Age blank. |

## 5. Employer characteristics

Characteristics of the **workplace each job is at**, as shares of job records.

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `size_0_9` | Share of jobs at workplaces with 0–9 employees | RAIS workers | Establishment size codes 1–3. |
| `size_10_99` | … 10–99 employees | RAIS workers | Size codes 4–6. |
| `size_100_499` | … 100–499 employees | RAIS workers | Size codes 7–8. |
| `size_500plus` | … 500+ employees | RAIS workers | Size codes 9–10. |
| `size_missing` | … size unknown | RAIS workers | Code -1 or blank. |
| `legalnat_public` | Share of jobs at public-sector employers | RAIS workers | Legal-nature code starting with 1 (1xxx). |
| `legalnat_private` | … private companies | RAIS workers | 2xxx. |
| `legalnat_nonprofit` | … nonprofits | RAIS workers | 3xxx. |
| `legalnat_individual` | … individuals as employers | RAIS workers | 4xxx. |
| `legalnat_intl` | … international organizations | RAIS workers | 5xxx. |
| `legalnat_missing` | … legal nature unknown | RAIS workers | Code -1 or blank. |

## 6. Hires and separations

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `hire_jan` … `hire_dec` | Number of hires in each month (12 variables: `hire_jan`, `hire_feb`, `hire_mar`, `hire_apr`, `hire_may`, `hire_jun`, `hire_jul`, `hire_aug`, `hire_sep`, `hire_oct`, `hire_nov`, `hire_dec`) | RAIS workers | Count of job records with that admission month. 0 in filled-in cells. |
| `term_jan` … `term_dec` | Number of separations in each month (12 variables: `term_jan`, `term_feb`, `term_mar`, `term_apr`, `term_may`, `term_jun`, `term_jul`, `term_aug`, `term_sep`, `term_oct`, `term_nov`, `term_dec`) | RAIS workers | Count of job records with that separation month. 0 in filled-in cells. |
| `term_fired` | Share of **all** job records that ended in a dismissal | RAIS workers | Separation reason codes 10–12. The denominator includes jobs that didn't end. |
| `term_resigned` | Share of all job records that ended in a resignation | RAIS workers | Reason codes 20–22. |
| `term_retired` | Share of all job records that ended in retirement or death | RAIS workers | Reason codes 40, 50, 60–64, 70–80. |

## 7. Establishments

From the RAIS establishments file (one row per workplace), collapsed to municipality × CNAE67 × year. Missing values after the merge become 0: the file lists every establishment, so no row means none.

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `estab_n_establishments` | Number of establishments | RAIS establishments | Count of establishments with a headcount recorded. |
| `estab_total_employees` | Employees on December 31 | RAIS establishments | Sum of the Ministry's own Dec 31 headcount ("Qtd Vínculos Ativos"). |
| `estab_private_employees` | Employees on regular private-sector contracts (CLT) | RAIS establishments | Sum of "Qtd Vínculos CLT". |
| `estab_public_employees` | Employees on public-sector (statutory) contracts | RAIS establishments | Sum of "Qtd Vínculos Estatutários". |
| `estab_total_noemployees` | Number of establishments that filed with no employees ("RAIS Negativa") | RAIS establishments | Sum of the no-employees flag. |

## 8. Input-output linkages to mining

Fixed per industry: the same value in every municipality and year. Built by `2. Clean Data/IO Matrix/clean_io_matrix.do` from IBGE's **2015** input-output matrix, the most recent one published.

"Mining" means three industries: **580** (coal and non-metallic minerals), **791** (iron ore) and **792** (non-ferrous metals). Oil and gas (680) is excluded.

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `backward_coal` | Share of this industry's output **sold to** industry 580 | IO matrix 2015 | direct coefficient × output of 580 ÷ output of this industry. |
| `backward_iron` | … sold to 791 (iron ore) | IO matrix 2015 | Same, with 791. |
| `backward_other` | … sold to 792 (non-ferrous metals) | IO matrix 2015 | Same, with 792. |
| `backward_nonironmining` | … sold to mining other than iron | IO matrix 2015 | `backward_coal + backward_other`. |
| `backward_allmining` | … sold to all three mining industries | IO matrix 2015 | `backward_iron + backward_nonironmining`. |
| `forward_coal` | Inputs **bought from** 580, per unit of this industry's output | IO matrix 2015 | IBGE's direct requirement coefficient (580 → this industry), as published. |
| `forward_iron` | … bought from 791 | IO matrix 2015 | Same, from 791. |
| `forward_other` | … bought from 792 | IO matrix 2015 | Same, from 792. |
| `forward_nonironmining` | … bought from mining other than iron | IO matrix 2015 | `forward_coal + forward_other`. |
| `forward_allmining` | … bought from all three mining industries | IO matrix 2015 | `forward_iron + forward_nonironmining`. |

## 9. Mine treatment

Same value for every industry in a municipality-year. These come from the **priced** version: only mines of minerals with a World Bank price (see `3. Merge Data/build_price_groups.do`). Switch to every mine with `local mine_version "all"` in the merge do-file.

**How it's built:**
- A "mine" is a mining right: one physical mine can hold several.
- A mine is **producing** in every year between its first and last CFEM royalty payment (`build_mine_timeline.do`).
- Its location is its SIGMINE point, else its group's average point, else the seat of the town where it paid the most royalties (`build_mine_locations.do`).
- Distance is straight-line from the town seat (`build_mine_distances.py`).

**Distance bands:**
- **Cumulative:** within 10, 25, 50, 100 km.
- **Rings:** 10–25, 25–50, 50–100 km. 10 km is both.
- Rings get only `treat_` and `n_mines_`. Use them together in one regression, with the sample set by the outer cumulative band.

**Groups** (`build_mine_distances.py`, cumulative bands):
- **treated:** the first mine in the band started producing 2008–2025
- **control:** a mining right in the band requested or got a concession but no mine ever opened (`build_mine_pipeline.do`)
- **always treated:** producing by 2007
- **no potential:** nothing in the band

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `treat_10km` | 1 from the year the first mine within 10 km started producing, and stays 1 | CFEM + SIGMINE | `year >= first_treat_year_10km`. |
| `treat_25km` | Same, within 25 km | CFEM + SIGMINE | Same. |
| `treat_50km` | Same, within 50 km | CFEM + SIGMINE | Same. |
| `treat_100km` | Same, within 100 km | CFEM + SIGMINE | Same. |
| `treat_10_25km` | Same, first mine in the 10–25 km ring | CFEM + SIGMINE | Same, ring version. |
| `treat_25_50km` | Same, 25–50 km ring | CFEM + SIGMINE | Same. |
| `treat_50_100km` | Same, 50–100 km ring | CFEM + SIGMINE | Same. |
| `n_mines_10km` | Number of mines producing that year, within 10 km | CFEM + SIGMINE | Count of rights in the band between first and last payment. |
| `n_mines_25km` | Same, within 25 km | CFEM + SIGMINE | Same. |
| `n_mines_50km` | Same, within 50 km | CFEM + SIGMINE | Same. |
| `n_mines_100km` | Same, within 100 km | CFEM + SIGMINE | Same. |
| `n_mines_10_25km` | Same, 10–25 km ring | CFEM + SIGMINE | Same. |
| `n_mines_25_50km` | Same, 25–50 km ring | CFEM + SIGMINE | Same. |
| `n_mines_50_100km` | Same, 50–100 km ring | CFEM + SIGMINE | Same. |
| `first_treat_year_10km` | Year the first mine within 10 km started producing | CFEM + SIGMINE | Earliest first-payment year among mines in the band. Missing if never. 2002–2003 means already producing when CFEM data start. |
| `first_treat_year_25km` | Same, within 25 km | CFEM + SIGMINE | Same. |
| `first_treat_year_50km` | Same, within 50 km | CFEM + SIGMINE | Same. |
| `first_treat_year_100km` | Same, within 100 km | CFEM + SIGMINE | Same. |
| `in_sample_10km` | 1 = treated or control at 10 km (the DiD sample) | CFEM + SIGMINE + ANM registry | Group 1 or 2. Use `keep if in_sample_10km`. |
| `in_sample_25km` | Same, 25 km (suggested main specification) | CFEM + SIGMINE + ANM registry | Same. |
| `in_sample_50km` | Same, 50 km | CFEM + SIGMINE + ANM registry | Same. |
| `in_sample_100km` | Same, 100 km | CFEM + SIGMINE + ANM registry | Same. |

## 10. Royalties

Same value for every industry in a municipality-year. Nominal reais. These are royalties **paid in this municipality** (where CFEM records the payment), all minerals, priced or not. They're not distance-based. No payments = 0.

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `royalty_total` | CFEM royalties paid in the municipality that year | CFEM | Sum over all payments. |
| `royalty_iron` | … on iron and iron ore | CFEM | Sum where the (English) substance is "Iron" or "Iron ore". |
| `royalty_noniron` | … on everything else | CFEM | `royalty_total - royalty_iron`. |

## 11. Price shock

Same value for every industry in a municipality-year. Built by `3. Merge Data/build_price_shock.py`. The formula is

> shock = `mining_emp_share_2007` × `price_index`, where price_index = Σ over minerals of weight × log(price in year ÷ price in 2007).

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `mining_emp_share_2007` | 2007 share of jobs in metal mining | RAIS | Dec 31 jobs in CNAE67 791 + 792 ÷ all Dec 31 jobs, 2007. Industry 580 is left out (it mixes coal with sand and stone quarries). |
| `price_index_10km` | Royalty-weighted mineral price index, log change vs 2007, mines within 10 km | World Bank + CFEM | Weights = each mineral's share of 2003–2006 royalties from priced mines within the band. Missing if no priced mine paid royalties nearby then. |
| `price_index_25km` | Same, 25 km | World Bank + CFEM | Same. |
| `price_index_50km` | Same, 50 km | World Bank + CFEM | Same. |
| `price_index_100km` | Same, 100 km | World Bank + CFEM | Same. |
| `shock_10km` | Shift-share price shock, 10 km | World Bank + CFEM + RAIS | `mining_emp_share_2007 × price_index_10km`. 0 where the index is missing (no exposure). |
| `shock_25km` | Same, 25 km | World Bank + CFEM + RAIS | Same. |
| `shock_50km` | Same, 50 km | World Bank + CFEM + RAIS | Same. |
| `shock_100km` | Same, 100 km | World Bank + CFEM + RAIS | Same. |

## 12. World Bank prices

Same value for every municipality and industry in a year. Nominal US dollars, the **yearly average of monthly prices** from the World Bank "Pink Sheet" (`2. Clean Data/WB Prices/clean_wb_prices.do`).

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `iron_price` | Iron ore, CFR spot, $ per dry metric ton unit (not per ton like most metals below) | World Bank | Yearly average. |
| `gold_price` | Gold | World Bank | Yearly average. |
| `copper_price` | Copper, LME | World Bank | Yearly average. |
| `aluminum_price` | Aluminum, LME | World Bank | Yearly average. |
| `nickel_price` | Nickel, LME | World Bank | Yearly average. |
| `tin_price` | Tin, LME | World Bank | Yearly average. |
| `zinc_price` | Zinc, LME | World Bank | Yearly average. |
| `lead_price` | Lead, LME | World Bank | Yearly average. |
| `silver_price` | Silver | World Bank | Yearly average. |
| `platinum_price` | Platinum | World Bank | Yearly average. |

Units are as in the Pink Sheet (the unit row is kept in `Working/WB Prices/wb_commodity_prices_monthly.dta` as `<metal>_unit`).

## 13. Pix payments

Same value for every industry in a municipality-year. From the Central Bank's open data (`2. Clean Data/PIX/clean_pix.do`). Pix started in **November 2020**: missing before 2020, and 2020 covers only November–December.

PF = individuals (pessoa física), PJ = businesses (pessoa jurídica).

| Variable | Meaning | Source | How it's built |
|---|---|---|---|
| `pix_value_payer_pf` | R$ sent by individuals in the municipality | Central Bank | Sum of monthly values over the year. |
| `pix_value_payer_pj` | R$ sent by businesses | Central Bank | Same. |
| `pix_value_receiver_pf` | R$ received by individuals | Central Bank | Same. |
| `pix_value_receiver_pj` | R$ received by businesses | Central Bank | Same. |
| `pix_count_payer_pf` | Number of transactions sent by individuals | Central Bank | Sum of monthly counts. |
| `pix_count_payer_pj` | Number sent by businesses | Central Bank | Same. |
| `pix_count_receiver_pf` | Number received by individuals | Central Bank | Same. |
| `pix_count_receiver_pj` | Number received by businesses | Central Bank | Same. |
| `pix_n_payers_pf` | Distinct individuals who paid at least once in a month | Central Bank | **Monthly average**, not a sum (the same person pays in many months). |
| `pix_n_payers_pj` | Distinct businesses who paid | Central Bank | Monthly average. |
| `pix_n_receivers_pf` | Distinct individuals who received | Central Bank | Monthly average. |
| `pix_n_receivers_pj` | Distinct businesses who received | Central Bank | Monthly average. |

