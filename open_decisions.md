# Open decisions and to-do

Running list of choices we made. Update this as items get resolved.

## Open decisions

| # | Question | Options | Notes |
|---|---|---|---|
| 1 | Add phosphate, potash and coal to the priced minerals? | 1. Add all three<br>2. Add phosphate and potash only<br>3. Keep excluded (current) | All have World Bank prices, but aren't metals. Coal overlaps CNAE 580. |
| 2 | Count bauxitic clay (ARGILA BAUXITICA) as aluminum? | 1. Yes<br>2. No (current) | One Nova Lima right paid ~R$1B. |
| 3 | What to do with denied/withdrawn concession requests? | 1. Keep as controls (current)<br>2. Drop from the pipeline | Now they look "pending" forever. **Can change the control group.** Count them first. |
| 4 | Count other ways a concession gets granted? | 1. Yes, add the codes<br>2. No (current) | E.g. a concession split off from another. Probably few. |
| 5 | Price shock: which **share**? | 1. Town's own 2007 jobs in 791 + 792 (current)<br>2. Distance-based share (mining jobs ÷ all jobs within X km)<br>3. Royalties per capita within X km<br>4. Mining output ÷ municipal GDP<br>5. No share: `n_mines` × price index<br>6. × IO linkage (varies by industry) | Current share gives only 63 towns a shock at 25 km. Option 2 preferred so far. |
| 6 | Price shock: which **weights**? | 1. 2003–06 royalty shares of nearby priced mines (current)<br>2. Minerals of nearby pipeline rights<br>3. SIGMINE area by mineral<br>4. SGB geology<br>5. ANM production data | Option 1 gives no weights to towns whose first mine opens after 2007. Option 4 is the most exogenous. |
| 7 | Price shock: which **mines** count? | 1. Same distance bands as treatment (current)<br>2. Only mines inside the municipality | |
| 8 | Price shock: which **prices**? | 1. Log USD vs 2007, yearly average (current)<br>2. Convert to BRL<br>3. Deflate<br>4. Use changes | Option 2 needs an exchange-rate pull. |
| 9 | Minimum mine size? | 1. Keep all (current)<br>2. Minimum royalties (e.g. R$100k)<br>3. Only rights with a real location | 19% of mines sit at a town seat, mostly tiny. |
| 10 | Stricter opening definition? | 1. First payment (current)<br>2. Require sustained payments<br>3. For event studies, require 2+ pre-years (openings 2009+) | Small operations pay on and off. |
| 11 | Local concentration (HHI): across what? | 1. Across industries<br>2. Across firms within an industry | Option 2 needs establishment-level data. |

## To do

| # | Task | Notes |
|---|---|---|
| 1 | Re-run the mine build after the price-group change | From `build_mine_distances.py` on. 309 more pipeline rights are priced now; compare counts with the table below. |
| 2 | Add artisanal gold permits (PLG) to the controls | Now excluded from controls only; PLG mines paying CFEM already count as producing. Only 28% of permits ever pay CFEM, with a 2018 jump. MapBiomas could help date openings. |
| 3 | Locate big mines with no SIGMINE point | Carajás (~R$24B) is the big one; it sits at its town seat. Needs a documented method. |
| 4 | Clean up final panel variables | See the table below, then update `variable_dictionary.md`. |
| 5 | Royalties by mineral group | Coal / iron / other, to match the IO split. Now only iron vs non-iron. |
| 6 | Monthly municipality × CNAE67 × month file | Hires by industry, for the linkage story. |
| 7 | Check RAIS cnae67 codes all match the IO matrix | Watch the public/private education/health split. |
| 8 | IO linkages: exclude mining itself? | Max backward (4.1%) is mining selling to itself; max forward (9.7%) is steel. Optional Leontief check. |
| 9 | Delete empty `Data/SCM/` folder | |

**Panel variables to clean up:**

| Variable | Issue | Fix |
|---|---|---|
| `population` | Counts job records, not people | Rename (e.g. `n_job_records`) |
| RAIS averages/shares | Cover every job record in the year, not just Dec 31 jobs | Decide whether to restrict; check `wage_dec` for jobs that ended early |
| `race`, `educ` | Averages of category codes | Drop; keep the `race_*` / `educ_*` shares |
| `term_fired/resigned/retired` | Shares of all job records, not of separations | Keep or divide by separations |
| `royalty_iron` | Matches English names "Iron"/"Iron ore" | Match the Portuguese name or `price_group` |
| Pix, WB prices, CFEM | Pix 2020 is Nov–Dec only; last year may be partial | Check completeness |
| Dataset labels | Thin ("(mean) x"), `cnae67` unlabeled | Add labels in the merge |
| `estab_total_noemployees` | Assumes the RAIS Negativa flag is 1 = yes | Verify |

## Decisions made

| Decision | Why / details |
|---|---|
| A mine = a mining right, producing between its first and last CFEM payment | Closed if it paid nothing in 2025–2026. |
| CFEM first payment = opening date | Registry "mining start" is reported for only 15% of concessions, often years late. |
| Openings count from 2007 | RAIS starts in 2007; 2003 spike (censoring), 2004 gap. The 2018 bump is the CFEM law change. |
| Priced minerals only | The all-mines version saturates (12 controls at 50 km). Priced mines = 87.9% of royalties. List in `build_price_groups.do`. |
| Controls = the pipeline | Requested or got a concession, never opened, no time cap. ~8k entered in the 2020s and may still open. |
| Drop always-treated towns | Mine producing by 2007; standard for staggered DiD. |
| Location: SIGMINE point → group average → town seat | Hand-coded locations removed 2026-09-28. |
| Main spec: 25 km | See group counts below. |
| Lean mining set in the final merge | 22 columns; `in_sample_` flag instead of missing values; missing establishment values = 0. |

**Priced treatment groups** (2026-09-23 run):

| Band | Treated | Control | Always treated |
|---|---|---|---|
| 10 km (thin, robustness) | 178 | 354 | 63 |
| **25 km (main)** | **425** | **916** | **226** |
| 50 km | 772 | 1,359 | 632 |
| 100 km | 1,213 | 1,548 | 1,374 |

## Known limitations

| Limitation | Details |
|---|---|
| Straight-line distance | Ignores rivers and roads; matters in the Amazon. |
| Several rights per physical mine | Counts overcount big complexes. |
| Unlocated pipeline rights | 854 have no location and are left out. |
| Closed mines' locations | SIGMINE locates ~70%; the rest sit at their town seat. |
| 2017 CFEM law | Higher rates (iron to 3.5%), so royalties jump after 2018 for non-production reasons. |
| Broken municipality codes | 1,620 CFEM rows: kept for locations, dropped from royalty totals. |
| No world price | Manganese, niobium, lithium. |
| RAIS worker vs establishment files | 1.7% of worker cells have no establishment row; 20,142 establishment rows don't map to CNAE67. |
| Re-running `clean_scm.do` | Needs `pull_scm.py` first (event log is deleted after filtering). |
