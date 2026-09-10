# Mining Linkages Project — Code

Code for the mining booms / local economic linkages project (Brazil).

## Setup (do this first, before running anything)

Every script in this repo needs to know where your local `Data`, `Results`,
and `Working` folders are — and that's a different path for everyone, so it
isn't hardcoded anywhere. One shared file handles this for both Stata and
Python. Do these in order:

1. Make a new empty folder somewhere on your machine — this is your project
   root, and it's what will hold `Code`, `Data`, `Results`, and `Working`
   side by side.
2. Clone the repo *into* that folder (so you end up with, e.g.,
   `<your project root>\Code`).
3. Open `Code\config.do` and paste two paths at the top: `PROJECT_ROOT` (the
   project root folder from step 1) and `REPO_PATH` (wherever the repo
   actually landed in step 2 — usually `<root>\Code`, but stated explicitly
   rather than assumed).
4. Run `config.do` once at the start of each Stata session, before running
   any other do-file. It sets `PROJECT_ROOT` for Stata, writes `config.py` so
   Python scripts (like `pull_sigmine.py`) pick up the same path
   automatically, and creates `Data`, `Results`, and `Working` under your
   project root if they don't already exist.

If a Python script fails saying it can't find `config.py`, this is the step
you missed — run `config.do` in Stata first. There's no Python-only path
around this: apart from the raw-data pull scripts, this project is Stata
end to end, so everyone needs Stata regardless of where they start.

Heads up: `config.do` is tracked in git, not personal/gitignored like
`config.py` — so after you paste your own path and run it, `git status` will
show it as changed. Up to you whether to commit that (it'll just get
overwritten by the next person's path when they do the same) or leave it as
a local, uncommitted edit.

## What's in this repo

Code only — build/download scripts, cleaning, and analysis. No raw or processed
data lives here.

## What's not in this repo, and why

Raw data is large (multi-GB in several cases) and, where it comes from public
sources, directly re-downloadable — so it's not versioned in git. Once the
download scripts exist, running them will materialize the raw data locally
under the sibling `Data/` folder.

If/when restricted data (e.g. identified RAIS/CAGED, IBGE secure-room data)
enters the project, it must **not** be added to this repo under any
circumstances — those sources carry legal data-handling terms that this repo
cannot satisfy.

## Structure (placeholder — to be filled in)

- `build/` — download and cleaning scripts
- `analysis/` — estimation / regression code
