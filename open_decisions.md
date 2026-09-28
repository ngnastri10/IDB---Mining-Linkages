# Open decisions and things to revisit

Running list of choices we made "for now" and gaps we left on purpose. Update this as items get resolved.

## Build progress (merge plan)

- [x] Step 1: pull the ANM registry microdata (`pull_scm.py`) and municipal seat coordinates (now `pull_crosswalks.py`, which also pulls the CNAE67 translator into `Data/Crosswalks/`)
- [x] Step 2: clean the registry into `Working/Mines/SCM/scm_process.dta` (`clean_scm.do`)
- [x] Step 3: mine locations, `Working/Mines/mine_locations.dta` (`build_mine_locations.do`)
- [x] Step 4: mine timeline, `Working/Mines/mine_timeline.dta` (`build_mine_timeline.do`). Rules: operating = every year between first and last payment; closed = no payments in 2025-2026; the registry "mining start" date is kept for comparison only.
  - **Early years are unreliable:** 2003 has 2,078 openings (leftover censoring), 2004 only 305 (likely a data gap). Treat openings as reliable from **2007 on**, which matches the RAIS start.
  - **2018 bump** in openings of bigger mines (R$100k+: 526 vs ~300 normal). Likely the CFEM law change, not real openings.
  - Registry "mining start" vs CFEM first payment: median gap 0, but 25% of registry dates are 6+ years later. It gets reported late, so CFEM stays the main measure.
- [x] Step 5: pipeline, `Working/Mines/mine_pipeline.dta` (`build_mine_pipeline.do`). The pipeline is the **control group**: viable (a concession was requested or granted) but never opened. No time cap; requested and granted are kept separate. 38,695 rights: 9,569 opened, 1,922 concession ended, 27,204 still pending. About 8k entered in the 2020s and may still open, so "never opened" is more reliable for older entries.
- [ ] Step 6: `build_mine_distances.py` (Python) writes `Working/Mines/municipality_year_mining.dta` (written, not run yet). One row per sede x year, 2003-2025.
  - Counts (`n_active_mine_10km`) plus binary (`active_mine_10km`) for active, opened, closed, requested, granted, never_opened.
  - Bands: rings 10km, 10_25km, 25_50km, 50_100km; cumulative 25km, 50km, 100km (10km is both).
  - `first_opened_year_<band>` and `mine_group_<band>` (1 treated, 2 control, 3 always treated, 4 no potential).
  - Treatment design: sample = groups 1 and 2; treated = first mine producing within the band 2008-2025; control = pipeline right nearby, no mine ever. Always-treated sedes (producing by 2007) are dropped per the staggered-DiD literature.
  - **Later:** consider requiring 2+ pre-years (openings 2009+) for event studies.
- [x] Step 6 ran. **Priced-version** sedes by group (treated / control / always treated):
  - 10 km: 178 / 354 / 63. Thin treated, so use it as a robustness check.
  - **25 km: 425 / 916 / 226. Suggested main specification.**
  - 50 km: 772 / 1,359 / 632.
  - 100 km: 1,213 / 1,548 / 1,374.
  - (The "all" version is saturated at wide bands, e.g. 12 controls at 50 km. That's why we use "priced".)
- [ ] Step 7: final merge. Rewrite the draft `3. Merge Data/merge_municipality_cnae67_year.do`. **Decided (revised):** a lean mining set, 22 columns, from the **priced** version. Cumulative bands (10/25/50/100 km) get `treat_` (absorbing: 1 from the first opening on), `n_mines_` (producing now, the intensity measure), `first_treat_year_` and `in_sample_` (flag: 1 = treated or control). Rings (10_25/25_50/50_100 km) get `treat_` + `n_mines_` only. We use a flag instead of setting out-of-sample values to missing, because counts are real zeros. Estab: missing estab_* values become 0 after the merge (Estab lists every establishment, so no row = none).
- Estab check (2026-09-23): the file is fine (8 vars, unique keys, 2007-2025). 45,396 Vinculos cells (~1.7%) have workers but no Estab row, probably because the worker's and the establishment's CNAE differ. 20,142 Estab rows have no cnae67 (unmapped CNAE) and are dropped. There's a one-line switch at the top to flip to `all`. The full 97-column mining file stays separate; merge other bands in at analysis time with `merge m:1 municipality year`.

## TOP PRIORITY after the deadline

- **Done (first pass):** step 6 now writes two versions: `municipality_year_mining_priced.dta` (only minerals with a WB price) and `_all.dta` (everything). Each right gets its main CFEM substance, or its registry substances if it never paid royalties. Per-right groups are in `Working/Mines/mine_price_group.dta`.
  - **2026-09-28:** the mapping moved from the hand-made `Data/Crosswalks/substance_to_price_group.csv` into code: `3. Merge Data/build_price_groups.do`, one list of exact Portuguese names used for both CFEM and the registry. The old CSV treated the two sources inconsistently, so some rights change group. CFEM names now priced that weren't: ITABIRITO, SILICATOS DE NÍQUEL, GALENA, PLATINA, MINÉRIO DE PLATINA. Registry names now priced that weren't: MINÉRIO DE ALUMÍNIO, ALUMÍNIO, ALUVIÃO ESTANÍFERO. Treatment group counts may move a little - re-check after re-running.
  - **Reviewed 2026-09-28 (first run of `build_price_groups.do`):** 2,766 of 46,055 royalty-paying rights are priced, covering 87.9% of all royalties (iron alone ~R$54B). Every priced name is a clean match. The newly added CFEM names (ITABIRITO, GALENA, SILICATOS DE NÍQUEL, PLATINA) aren't any right's main substance, so they change nothing on the CFEM side. Gold gravels and ÓXIDO DE FERRO are too small to matter.
  - **DECIDE: add phosphate, potash and coal?** They have World Bank prices but are currently excluded. Royalties: phosphate (FOSFATO + APATITA) ~R$860M, potash (SILVINITA) ~R$258M, coal (CARVÃO) ~R$258M. For: real, internationally priced minerals; phosphate alone is bigger than zinc + tin + nickel. Against: not metals; coal overlaps CNAE 580, which is left out of the employment share because it mixes coal with quarrying. Adding them means new name lines in `build_price_groups.do`, plus the price series in `clean_wb_prices.do` and `build_price_shock.py`.
  - No World Bank price, so out regardless: manganese (~R$496M), niobium (PIROCLORO + NIÓBIO, ~R$322M), lithium (~R$126M). Limestone, granite, sand, water, etc. are out by design.
  - **Check after re-running `build_mine_distances.py`:** the registry side now also prices MINÉRIO DE ALUMÍNIO and ALUMÍNIO (~3,600 more pipeline rights as aluminum), which can grow the control group. Compare against the old counts (25 km: 425 / 916 / 226).
  - Still open: "ARGILA BAUXITICA" (bauxitic clay; one Nova Lima right paid ~R$1B) is NOT counted as aluminum.
  - The old `municipality_year_mining.dta` (no suffix) is obsolete. Delete it.
- (Original note) **Restrict which mines count as "mines" in step 6.** Right now every sand pit, clay quarry and gravel site counts. Result: 51% of sedes have a producing site within 10 km by 2025, and the wider bands are saturated. At 25 km there are only 126 controls vs 3,744 always-treated; at 50 km, 12 controls. Filter by minimum royalties and/or metallic/traded substances (`main_substance` in `mine_timeline.dta`, `royalty_total` in `mine_locations.dta`). It's a filter in `build_mine_distances.py`.
- Current 10 km groups: 1,885 treated, 348 control, 1,982 always treated, 1,355 no potential.

## Mine locations

- **Town-seat fallback is large by count.** 8,788 royalty-paying rights (19%) are placed at a town seat. They're mostly tiny (median R$3.7k in total royalties). For now we keep everything. Later, pick one:
  - a minimum size for counting mines (e.g. R$100k total royalties), or
  - count only rights with a real point (location_source 1-2).
- **Big mines with no SIGMINE point sit at their town seat, including Carajas** (852.145/1976, Parauapebas). Carajas alone is about R$24B in royalties, almost all of the town-seat royalty share. A quick hand-coding pass (20 biggest rights, `Data/Crosswalks/hand_coded_mine_locations.csv`) was **taken out on 2026-09-28**: it was done in a rush and never filled in. Decide on a proper, documented way to locate these before adding it back.
- **854 pipeline rights have no location at all.** They're not in SIGMINE and never paid royalties, so there's no town fallback. They're left out of the distance counts for now.
- **Many mining rights per physical mine.** Counting rights can overcount big complexes. Consider "any mine within X km" or weighting by royalties.
- **Straight-line distance** ignores rivers and roads. This matters in the Amazon. Note it as a limitation.
- SIGMINE matches only ~70% of rights that stopped paying (closed mines). The rest fall back to town seats.

## Openings, closings, pipeline

- **Registry event codes, checked 2026-09-28.** Every code picked in `reshape_scm.py` matches its official description in `Evento.txt` (descriptions are now written next to each code). Look-alike codes we did NOT pick, to decide on. First count how often each happens: re-run `pull_scm.py` to get `ProcessoEvento.txt` back (it's deleted after `reshape_scm.py` runs).
  1. **DECIDE: track denied/withdrawn concession requests?** Codes 390/2139 (request denied, MME/ANM) and 351/352 (request withdrawn, filed/approved). Right now a denied or withdrawn request looks "requested, still pending" forever and still counts as a pipeline right, so it can be a **control**. Argument for keeping them: a request still signals the area had mineral potential. This is the one that can change the control group.
  2. **DECIDE: count other ways a concession gets granted?** Codes 507/2142 (concession split off from another), 1785/2618 (concession covering researched areas), 488/2729 (concession absorbing another title). Rights granted this way with no request date never enter the pipeline. Probably few.
  3. Endings we don't count: 2140 (annulled, legal technicality), 2052 (lapsed under the protected-areas law), 2181 (cancelled by a court). These only affect the in-pipeline counts, not who's a control.
  4. Reversals are ignored: 696 undoes a lapse, but the code keeps the first "ended" date. Probably rare.

- **Artisanal gold permits (PLG) are excluded.** Only 28% of granted permits ever pay CFEM, and first payments jump in 2018 (rule change), so the timing is unreliable. Revisit with **MapBiomas** satellite mining data (it separates garimpo from industrial mining), which could prove openings physically.
- **Licensing regime (sand, gravel, clay) has no milestone dates.** We only picked concession-regime events. Add its events if small quarries should count.
- **"Mining start reported" is rare and recent**: 14% of concessions, mostly after 2010. CFEM first payment is the main opening measure; the registry date is only a cross-check.
- **CFEM left-censoring.** Openings only count from 2003 on, since anything paying in 2002 was probably already open.
- Possibly require sustained payments (not just a first payment) to call something an opening, since small operations pay on and off.

## CFEM / royalties

- **2017 CFEM law change** (Law 13,540/2017, I believe): higher rates (iron to 3.5%) and a gross-revenue base. Royalty values jump after 2018 for non-production reasons. Confirm before using royalties as a production measure.
- **Substance grouping.** The draft merge only splits iron vs non-iron. Matching the IO split (coal / iron / other) needs a mapping of all ~310 CFEM substances.
- ~1,600 CFEM rows have broken municipality codes. They're blanked, not dropped.

## Price shock / shift-share: FIRST PASS BUILT, revisit all of these

`build_price_shock.py` writes `Working/Mines/municipality_year_price_shock.dta`, which the merge picks up. Formula: shock = share x sum_k weight_k x log(P_kt / P_k,2007). The user wants to think more about each default:

1. **Mineral weights.** Current: each mineral's share of CFEM royalties from priced mines in **2003-2006** (pre-RAIS). Alternatives: count/area of priced mining rights incl. pipeline (closer to "what's in the ground"); SGB geology data (most exogenous, not pulled); ANM AMB production data.
2. **Which mines count for a town's weights.** Current: same distance bands as treatment (10/25/50/100 km from the sede). Alternative: only mines inside the municipality.
3. **Share.** Current: **2007 employment share in 791 + 792** (iron + non-ferrous metals). 580 is left out because it mixes coal with sand/stone quarrying. Alternatives: other base years, include coal, use royalties/GDP instead of employment.
4. **Prices.** Current: **log USD WB price relative to 2007**, yearly average. Alternatives: convert to BRL with the exchange rate (needs a pull), deflate, use changes instead of levels.
- Towns with no priced production nearby in 2003-2006 get price_index missing and shock = 0.
- **First-pass results (2026-09-23):**
  - The price index tracks the cycle well (25 km mean: 2011 +0.20, 2015 -0.41, 2025 +0.21).
  - BUT only 63 sedes have a nonzero shock at 25 km (36 at 10 km, 129 at 100 km).
  - Reason 1: the share is the town's OWN 2007 metal-mining jobs (>0 in only 228 munis). That's inconsistent with the distance design. **Fix:** a distance-based share (mining jobs within X km / all jobs within X km).
  - Reason 2: weights need production in 2003-2006, so DiD-treated towns (first mine after 2007) get no shock. As built, the shift-share and the DiD cover different towns. **Fix:** weights that exist before opening (pipeline rights' minerals, or geology).
- Also note: 2003-2006 CFEM data is itself shaky (2003 spike, 2004 gap, see step 4). That's another reason to reconsider the weights.

- **How to measure mining's importance to a place** (the share only has variation for about 60 sedes). Remember RAIS units are municipalities (large areas), not towns. Options discussed 2026-09-23:
  1. **Distance-based employment share** (mining jobs within X km / all jobs within X km). The user likes this one.
  2. Base-period CFEM royalties per capita within X km (also captures the fiscal channel).
  3. Mining output (royalty / CFEM rate) / municipal GDP. Needs IBGE PIB dos Municipios, and a pre-2017 base because of the rate change.
  4. Skip the share: shock = n_mines_Xkm (or treat_Xkm) x price_index. A one-line generate after the merge.
  5. Industry-varying shock: price_index x local mining x IO linkage (backward_/forward_). This fits the linkage story.

## Price shock / shift-share (older notes)

- Mineral weights per place: pick one of CFEM base-period royalty shares, SIGMINE area by substance, or SGB (Brazilian Geological Survey) deposit data (most exogenous). ANM's `AMB/Producao_Bruta.csv` (production by substance) is another option, not yet opened.
- The employment "share" should be fixed in a base year before openings.
- WB prices only cover traded metals. There's no price for niobium or manganese (fine, they're small). Non-metallic minerals have no world price.

## Panel / merge

- **Balance the RAIS panel:** counts become 0, averages (age, education, wages) stay missing.
- **Monthly municipality x CNAE67 x month file** later (hires by industry, for the linkage story).
- RAIS Estab: merge once pulled. The draft assumes `D:\Data\RAIS\Working\Estab\CNAE67\cleaned_all_years.dta`.
- Check that every RAIS cnae67 code matches the IO Matrix (watch the public/private education/health split).

## Final panel variables (found writing `variable_dictionary.md`, 2026-09-28)

- **`population` is misnamed.** It counts job records in the cell during the year (active on Dec 31 or not), not people. Rename (e.g. `n_job_records`) in the HPC collapse or the merge.
- **RAIS averages and shares cover every job record in the year**, not only jobs active on Dec 31. Decide whether to restrict to Dec 31 jobs. Check whether `wage_dec` is 0 for jobs that ended before December (that would pull the average down).
- **`race` and `educ` are averages of category codes** (meaningless / rough ordinal). Drop them from the collapse or keep only the `race_*` / `educ_*` shares.
- **`term_fired/resigned/retired` are shares of all job records**, not of separations. Fine if that's intended - otherwise divide by separations.
- **`royalty_iron` matches the English substance names** "Iron"/"Iron ore" from `clean_cfem.do`. Switch to the Portuguese name or `price_group` so the translation can't affect it.
- **Partial years:** Pix 2020 = Nov-Dec only. Check whether the last year of World Bank prices and CFEM is complete.
- **Dataset labels are thin** ("(mean) x", `cnae67` unlabeled). Add real labels in the merge do-file so they match `variable_dictionary.md`.
- `estab_total_noemployees` assumes the RAIS Negativa flag is coded 1 = yes - verify against the layout file.

## Mechanisms (not built yet)

- **Pre-existing local concentration (HHI)** by municipality, base year, from RAIS. It's a mechanism alongside the IO linkages. Still to decide: concentration across industries (possible with the current muni x CNAE67 data) or across firms within an industry (needs establishment-level data).

## IO Matrix

- Linkage shares are small (max backward ~4%, forward ~10%). Check which cnae67 codes hit the max, as a sanity check.
- Leontief (total requirements) version of forward linkage: optional robustness check.
- File names still say `io_matrix_activity_totals_2015` (we said "industry" everywhere else). Left as is.

## Housekeeping

- The `Data/SCM/` folder is empty (old Cessoes/Guia files removed) and can be deleted.
- Re-running `clean_scm.do` from scratch needs `pull_scm.py` first, since the event log gets deleted after filtering.
