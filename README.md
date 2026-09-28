# Mining Linkages Project - Code

Code for the IDB project on mining in Brazil and its links to local economies: when a mine opens near a town, what happens to local employment, wages and industries, especially industries that buy from or sell to mining?

The code builds one analysis file: a **municipality × industry (CNAE67) × year panel, 2007–2025**, with four kinds of variables:

|                                       | What                                                                                                                                                             | Data                                            |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| **Outcomes**                    | Local labor markets: jobs, wages, worker composition, establishments, Pix payment activity                                                                       | RAIS, Central Bank (Pix)                        |
| **Treatment: extensive margin** | Where and when mines open, within 10/25/50/100 km of each town: treated (a mine opened nearby) vs. control (a mining concession nearby, but no mine ever opened) | CFEM royalties, SIGMINE locations, ANM registry |
| **Treatment: intensive margin** | A shift-share mineral price shock: world metal prices, weighted by the local mix of minerals and the municipality's mining employment share                      | World Bank prices, CFEM, RAIS                   |
| **Mechanisms**                  | How tied each industry is to mining (input-output linkages). Local concentration is still to build.                                                              | IBGE input-output matrix                        |

- **What every variable means:** [variable_dictionary.md](variable_dictionary.md)
- **Choices we made, and ones still open:** [open_decisions.md](open_decisions.md)

---

## Quick start

**Two folders, used throughout this README:**

| Name                     | What it is                                                                          | Example                                      |
| ------------------------ | ----------------------------------------------------------------------------------- | -------------------------------------------- |
| **Project folder** | A folder you make to hold everything. The code creates all its files here.          | `C:\Projects\Mining`                       |
| **Repo folder**    | This repo, cloned into the project folder. It's the folder with `master.do` in it. | `C:\Projects\Mining\IDB---Mining-Linkages` |

**Steps:**

1. **Make the project folder** (any name, anywhere) and **clone this repo into it.**
2. **In [`0. Configure File Paths/config.do`](<0.%20Configure%20File%20Paths/config.do>):** set `REPO_PATH` to your **repo folder**. Optional:
   - **If short on disk space:** set `LARGE_DATA_ROOT` to another drive. Otherwise leave it blank.
   - **If on a Mac:** change `PYTHON` to `python3`.
3. **In [`master.do`](master.do):** set `repo_folder` at the top to the same **repo folder**.
4. **Put the RAIS files in place.** See [RAIS and the HPC](#rais-and-the-hpc).
5. **Run `master.do`.**

`master.do` runs everything in order. Each stage has a switch at the top: **1 = on, 0 = off.** They're all **off (0) by default**, so running it as-is only loads the setup. For a full run, set them all to 1. After your first full run, set `run_pull` back to 0 (see [Data vintage](#data-vintage)).

You need **Stata 16+** and **Python 3**. `config.do` installs any missing Python packages (listed in [`requirements.txt`](<0.%20Configure%20File%20Paths/requirements.txt>)).

## Folder layout

**In this repo (code only):**

| Folder                       | What's in it                                                                                        |
| ---------------------------- | --------------------------------------------------------------------------------------------------- |
| `0. Configure File Paths/` | `config.do` (your paths, package checks) and its helpers                                         |
| `1. Pull Raw Data/`        | Downloads each public source                                                                        |
| `2. Clean Data/`           | One cleaning script per source                                                                      |
| `3. Merge Data/`           | Mine locations, timelines, pipeline, price groups, distances, price shock, and the final merge      |
| `4. Generate Results/`     | Maps                                                                                                |
| `HPC/`                     | How RAIS was cleaned on the HPC. **Reference only.**                                              |
| `master.do`                | Runs everything in order                                                                            |

**Created by the code in the repo:**

| Folder                                                        | What's in it                                                                                                                        |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `Data/`                                                     | Raw downloads                                                                                                                       |
| `Working/`                                                  | Intermediate files                                                                                                                  |
| `Results/`                                                  | Figures and the run log                                                                                                             |
| `Large Data/` (or wherever you pointed `LARGE_DATA_ROOT`) | RAIS, registry microdata, map shapefiles, and the final panel (`Merged/municipality_cnae67_year.dta`)                             |

## RAIS and the HPC

RAIS is too large, so it was cleaned on an HPC. The `HPC/` scripts are there for reference; **you don't need to run them.**

Put cleaned HPC files here:

| File from the HPC                                                                                           | Where it goes                                                       |
| ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `Mining/Working/RAIS/All_Years/CNAE67/cleaned_all_years.dta` (workers)                                    | `LARGE_DATA_ROOT/RAIS/Working/CNAE67/cleaned_all_years.dta`       |
| `Mining/Working/RAIS/Estab/All_Years/CNAE67/cleaned_all_years.dta` (establishments)                       | `LARGE_DATA_ROOT/RAIS/Working/Estab/CNAE67/cleaned_all_years.dta` |

## Data vintage

The public sources keep getting updated, so your pull may differ slightly from ours. Ours were pulled:

| Source                                    | Pulled     |
| ----------------------------------------- | ---------- |
| CFEM royalties, SIGMINE                   | 2026-09-10 |
| World Bank prices                         | 2026-09-11 |
| Pix                                       | 2026-09-22 |
| ANM registry (SCM), IO matrix, crosswalks | 2026-09-23 |
| Map boundaries                            | 2026-09-24 |
| RAIS (cleaned on the HPC)                 | 2026-09-22 |

## Ground rules

- **Don't commit your version of `config.do`** (it holds your paths). To stop git showing it as changed, run once after cloning:

  ```
  git update-index --skip-worktree "0. Configure File Paths/config.do"
  ```
- **Never put data in this repo.**
- **Log changes in [open_decisions.md](open_decisions.md).**
