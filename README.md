# Mining Linkages Project - Code

Code for the IDB project on mining in Brazil and its links to local economies: when a mine opens near a town, what happens to local employment, wages and industries, especially industries that buy from or sell to mining?

The code builds one analysis file: a **municipality × industry (CNAE67) × year panel, 2007–2025**, with four kinds of variables:

| | What | Data |
|---|---|---|
| **Outcomes** | Local labor markets: jobs, wages, worker composition, establishments, Pix payment activity | RAIS, Central Bank (Pix) |
| **Treatment: extensive margin** | Where and when mines open, within 10/25/50/100 km of each town: treated (a mine opened nearby) vs. control (a mining concession nearby, but no mine ever opened) | CFEM royalties, SIGMINE locations, ANM registry |
| **Treatment: intensive margin** | A shift-share mineral price shock: world metal prices, weighted by the local mix of minerals and the municipality's mining employment share | World Bank prices, CFEM, RAIS |
| **Mechanisms** | How tied each industry is to mining (input-output linkages). Local concentration is still to build. | IBGE input-output matrix |

- **What every variable means:** [variable_dictionary.md](variable_dictionary.md)
- **Choices we made, and ones still open:** [open_decisions.md](open_decisions.md)

---

## Quick start

**Two folders, used throughout this README:**

| Name | What it is | Example |
|---|---|---|
| **Project folder** | A folder you make to hold everything. The code creates all its files here. | `C:\Projects\Mining` |
| **Repo folder** | This repo, cloned into the project folder. It's the folder with `master.do` in it. | `C:\Projects\Mining\IDB---Mining-Linkages` |

**Steps:**

1. **Make the project folder** (any name, anywhere) and **clone this repo into it.**
2. **In [`0. Configure File Paths/config.do`](0.%20Configure%20File%20Paths/config.do):** set `REPO_PATH` to your **repo folder**. The code works out the project folder from it. Two optional settings sit right below it:
   - **If short on disk space:** set `LARGE_DATA_ROOT` to another drive for the multi-GB files. Otherwise leave it blank and they go in `Large Data` inside your project folder.
   - **If on a Mac:** change `PYTHON` to `python3`.
3. **In [`master.do`](master.do):** set `repo_folder` at the top to the same **repo folder**. It needs it to find `config.do`.
4. **Put the RAIS files you were sent in place.** See [RAIS and the HPC](#rais-and-the-hpc).
5. **Run `master.do`.**

`master.do` runs everything in order: configure → pull → clean → build and merge → maps. Each stage has an on/off switch at the top: **1 = on, 0 = off.** They're all **off (0) by default**, so running it as-is only loads the setup (paths, packages). For a full run, turn them all on (set each to 1). If you're working from the data snapshot you were sent, leave `run_pull` at 0 (see [Data vintage](#data-vintage)).

You need **Stata** (built on Stata 16) and **Python 3**. The config step checks your Python packages and installs any that are missing. The list is in [`requirements.txt`](0.%20Configure%20File%20Paths/requirements.txt), and you can also install them by hand: `python -m pip install -r requirements.txt`.

## Folder layout

**In this repo (code only):**

| Folder | What's in it |
|---|---|
| `0. Configure File Paths/` | `config.do` (your paths, package checks), `requirements.txt`, and the helpers it uses |
| `1. Pull Raw Data/` | Python scripts that download each public source into `Data/` (or `LARGE_DATA_ROOT` for big ones) |
| `2. Clean Data/` | One cleaning script per source → `Working/` |
| `3. Merge Data/` | Mine locations, timelines, pipeline, price groups, distances, price shock, and the final merge |
| `4. Generate Results/` | Maps |
| `HPC/` | How RAIS was downloaded and cleaned on the HPC. **For reference only**; see below. |
| `master.do` | Runs everything in order |

**Created next to the repo, in your project folder (never committed):**

| Folder | What's in it |
|---|---|
| `Data/` | Raw downloads, untouched |
| `Working/` | Intermediate files built by the code |
| `Results/` | Figures, plus `master_log.txt` from the last full run |
| `Large Data/` (or wherever you pointed `LARGE_DATA_ROOT`) | RAIS files, the ANM registry microdata, map shapefiles, and the final panel (`Merged/municipality_cnae67_year.dta`, about 4.6 GB) |

## RAIS and the HPC

RAIS (formal employment) is far too big to process on a laptop, so it was downloaded and cleaned on a university HPC. The scripts are in `HPC/` so you can see exactly how the RAIS files were made. **You don't need to run them.** A different cluster would need its own job files anyway (e.g. SLURM instead of LSF).

You'll be sent two files. Put them here:

| File from the HPC | Where it goes |
|---|---|
| `Mining/Working/RAIS/All_Years/CNAE67/cleaned_all_years.dta` (workers, by municipality × CNAE67 × year) | `LARGE_DATA_ROOT/RAIS/Working/CNAE67/cleaned_all_years.dta` |
| `Mining/Working/RAIS/Estab/All_Years/CNAE67/cleaned_all_years.dta` (establishments) | `LARGE_DATA_ROOT/RAIS/Working/Estab/CNAE67/cleaned_all_years.dta` |

`master.do` checks the first one is there before the steps that need it, and stops with a clear message if not.

## Data vintage

The public sources are live datasets that their agencies keep updating: ANM (CFEM, SIGMINE, registry), the World Bank, IBGE and the Central Bank. A fresh pull can therefore give slightly different numbers than ours. Our current files were pulled:

| Source | Pulled |
|---|---|
| CFEM royalties, SIGMINE | 2026-09-10 |
| World Bank prices | 2026-09-11 |
| Pix | 2026-09-22 |
| ANM registry (SCM), IO matrix, crosswalks | 2026-09-23 |
| Map boundaries | 2026-09-24 |
| RAIS (cleaned on the HPC) | 2026-09-22 |

- **To reproduce our results:** use the data snapshot you were sent and leave `run_pull` at 0 in `master.do`.
- **To update to the latest data:** set `run_pull` to 1. Expect small changes, especially in recent years.

## Ground rules

- **Don't commit your version of `config.do`.** It holds your paths, and committing it would give everyone else your paths when they pull. To make git stop showing it as changed, run this once after cloning:
  ```
  git update-index --skip-worktree "0. Configure File Paths/config.do"
  ```
- **Never put data in this repo**, and never restricted data anywhere near it. Identified RAIS/CAGED and IBGE secure-room data come with legal data-handling terms this repo can't meet.
- **Judgment calls live in code, with comments:**
  - which minerals count as priced: Section 1 of [`build_price_groups.do`](3.%20Merge%20Data/build_price_groups.do)
  - which registry events mark a concession: top of [`reshape_scm.py`](2.%20Clean%20Data/SCM/reshape_scm.py)

  When you change one, note it in [open_decisions.md](open_decisions.md).
