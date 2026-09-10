# Mining Linkages Project — Code

Code for the mining booms / local economic linkages project (Brazil).

## Setup (do this first, before running anything)

Every script in this repo needs to know where your local `Data`, `Results`,
and `Working` folders are — and that's a different path for everyone, so it
isn't hardcoded anywhere. Instead:

1. Copy `config_template.py` (in this same folder) and rename the copy to
   `config.py`.
2. Open `config.py` and set `PROJECT_ROOT` to the folder on **your**
   machine that contains your `Data`/`Results`/`Working` folders (i.e. the
   folder that `Code` itself sits inside).
3. That's it. `config.py` is gitignored — your path stays local and never
   gets pushed or overwrites anyone else's.

If a script fails saying it can't find `config.py`, this is the step you
missed.

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
