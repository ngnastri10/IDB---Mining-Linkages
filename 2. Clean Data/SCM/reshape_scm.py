"""
Boil ANM's Cadastro Mineiro microdata down to one row per mining right,
with the dates of the milestones we care about:

  research report approved   - a viable deposit was found
  concession requested       - company asks to mine
  concession granted         - government authorizes mining
  mining start reported      - company tells ANM it started mining (the opening)
  concession ended           - renounced, revoked, voided, lapsed

Each milestone keeps its FIRST date for that mining right.

The event log (ProcessoEvento.txt, ~1GB) has every administrative event
ever logged for every right - we keep only the milestone events above, and
once the output is saved, the big file gets deleted (re-run pull_scm.py to
get it back).

The event log is read line by line and only the first three fields
(process, event ID, date) are used - the long free-text note columns after
them sometimes contain stray semicolons, which would break a normal CSV
read.

Called from clean_scm.do, which passes the two paths below. Can also be
run directly with no arguments - then the paths come from config.py.

Usage: python reshape_scm.py [<microdata_folder> <output_csv_path>]
"""

import sys
from pathlib import Path

import pandas as pd

if len(sys.argv) == 3:
    MICRO_DIR = Path(sys.argv[1])
    OUT_PATH = Path(sys.argv[2])
else:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    try:
        import config
    except ImportError:
        raise SystemExit("Couldn't find config.py in the Code folder - run config.do in Stata first.")
    MICRO_DIR = Path(config.LARGE_DATA_ROOT) / "SCM" / "microdados"
    OUT_PATH = Path(config.LARGE_DATA_ROOT) / "SCM" / "scm_process_milestones.csv"

# Event IDs for each milestone - picked from Evento.txt by hand.
MILESTONES = {
    "date_research_approved": ["317", "291"],
    "date_concession_requested": ["350", "1781"],
    "date_concession_granted": ["400", "2132", "2611"],
    "date_mining_start": ["405", "1198", "1245"],
    "date_concession_ended": ["554", "499", "2135", "2913", "496", "2134", "498"],
}
EVENT_TO_MILESTONE = {ev: name for name, evs in MILESTONES.items() for ev in evs}


def read_table(name):
    return pd.read_csv(MICRO_DIR / name, sep=";", encoding="latin-1", dtype=str)


def load_milestones():
    """Scan the event log and keep only milestone events."""
    records = []
    event_path = MICRO_DIR / "ProcessoEvento.txt"
    with open(event_path, encoding="latin-1") as f:
        next(f)  # header
        for line in f:
            parts = line.split(";", 3)
            if len(parts) < 3:
                continue
            process, event_id, date = parts[0], parts[1], parts[2]
            milestone = EVENT_TO_MILESTONE.get(event_id)
            if milestone:
                records.append((process, milestone, date[:10]))

    events = pd.DataFrame(records, columns=["DSProcesso", "milestone", "date"])
    print(f"Milestone events kept: {len(events):,}")

    # First date of each milestone, one column per milestone.
    wide = events.groupby(["DSProcesso", "milestone"])["date"].min().unstack()
    return wide.reindex(columns=list(MILESTONES)).reset_index()


def main():
    process = read_table("Processo.txt")
    print(f"Mining rights in the registry: {len(process):,}")

    # Lookup tables are just ID;name - read by position so a renamed header
    # doesn't break anything.
    phase = read_table("FaseProcesso.txt").iloc[:, :2]
    phase.columns = ["IDFaseProcesso", "phase"]
    req = read_table("TipoRequerimento.txt").iloc[:, :2]
    req.columns = ["IDTipoRequerimento", "requirement_type"]

    process = process.merge(phase, on="IDFaseProcesso", how="left")
    process = process.merge(req, on="IDTipoRequerimento", how="left")

    out = process[["DSProcesso", "NRProcesso", "NRAnoProcesso", "BTAtivo",
                   "requirement_type", "phase", "DTProtocolo", "QTAreaHA"]].copy()
    out.columns = ["DSProcesso", "process_number", "process_year", "active",
                   "requirement_type", "phase", "date_filed", "area_hectares"]
    out["active"] = (out["active"] == "S").astype(int)
    out["date_filed"] = out["date_filed"].str[:10]
    # Brazilian decimal comma -> decimal point.
    out["area_hectares"] = out["area_hectares"].str.replace(",", ".", regex=False)

    out = out.merge(load_milestones(), on="DSProcesso", how="left")
    out = out.drop(columns="DSProcesso")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT_PATH, index=False)
    print(f"Saved {len(out):,} mining rights -> {OUT_PATH}")

    # Only delete the big event log once the output is really there.
    if OUT_PATH.exists() and OUT_PATH.stat().st_size > 0:
        (MICRO_DIR / "ProcessoEvento.txt").unlink()
        print("Deleted ProcessoEvento.txt (re-run pull_scm.py to get it back).")


if __name__ == "__main__":
    main()
