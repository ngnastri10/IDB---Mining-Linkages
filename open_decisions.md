# Open decisions and things to revisit

Running list of choices we made "for now" and gaps we left on purpose. Update this as items get resolved.

## Build progress (merge plan)

- [x] Step 1: pull the ANM registry microdata (`pull_scm.py`) and municipal seat coordinates (`pull_municipality_latlon.py`)
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

- **Done (first pass):** step 6 now writes two versions: `municipality_year_mining_priced.dta` (only minerals with a WB price) and `_all.dta` (everything). Mapping: `Data/Crosswalks/substance_to_price_group.csv`. Each right gets its main CFEM substance, or its registry substances if it never paid royalties. Per-right groups are in `Working/Mines/mine_price_group.dta`.
  - To review: "ARGILA BAUXITICA" (bauxitic clay; one Nova Lima right paid ~R$1B) is currently NOT counted as aluminum. Manganese, niobium, phosphate and coal have no WB price, so they're excluded. Check this is OK.
  - The old `municipality_year_mining.dta` (no suffix) is obsolete. Delete it.
- (Original note) **Restrict which mines count as "mines" in step 6.** Right now every sand pit, clay quarry and gravel site counts. Result: 51% of sedes have a producing site within 10 km by 2025, and the wider bands are saturated. At 25 km there are only 126 controls vs 3,744 always-treated; at 50 km, 12 controls. Filter by minimum royalties and/or metallic/traded substances (`main_substance` in `mine_timeline.dta`, `royalty_total` in `mine_locations.dta`). It's a filter in `build_mine_distances.py`.
- Current 10 km groups: 1,885 treated, 348 control, 1,982 always treated, 1,355 no potential.

## Mine locations

- **Town-seat fallback is large by count.** 8,788 royalty-paying rights (19%) are placed at a town seat. They're mostly tiny (median R$3.7k in total royalties). For now we keep everything. Later, pick one:
  - a minimum size for counting mines (e.g. R$100k total royalties), or
  - count only rights with a real point (location_source 1-3).
- **Hand-code Carajas** (852.145/1976, Parauapebas) in `Data/Crosswalks/hand_coded_mine_locations.csv`. It's about R$24B in royalties, and almost all of the town-seat royalty share. The other 19 rows in that file are optional.
- **854 pipeline rights have no location at all.** They're not in SIGMINE and never paid royalties, so there's no town fallback. They're left out of the distance counts for now.
- **Many mining rights per physical mine.** Counting rights can overcount big complexes. Consider "any mine within X km" or weighting by royalties.
- **Straight-line distance** ignores rivers and roads. This matters in the Amazon. Note it as a limitation.
- SIGMINE matches only ~70% of rights that stopped paying (closed mines). The rest fall back to town seats.

## Openings, closings, pipeline

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

## IO Matrix

- Linkage shares are small (max backward ~4%, forward ~10%). Check which cnae67 codes hit the max, as a sanity check.
- Leontief (total requirements) version of forward linkage: optional robustness check.
- File names still say `io_matrix_activity_totals_2015` (we said "industry" everywhere else). Left as is.

## Housekeeping

- The `Data/SCM/` folder is empty (old Cessoes/Guia files removed) and can be deleted.
- Re-running `clean_scm.do` from scratch needs `pull_scm.py` first, since the event log gets deleted after filtering.
