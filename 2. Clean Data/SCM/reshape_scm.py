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
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "0. Configure File Paths"))
    try:
        import config
    except ImportError:
        raise SystemExit("Couldn't find config.py in Code/0. Configure File Paths - run 0. Configure File Paths/config.do in Stata first.")
    MICRO_DIR = Path(config.LARGE_DATA_ROOT) / "SCM" / "microdados"
    OUT_PATH = Path(config.LARGE_DATA_ROOT) / "SCM" / "scm_process_milestones.csv"

# Event IDs for each milestone, picked by hand from ANM's event list
# (Evento.txt). The official description of each one is next to it.
# Checked against Evento.txt on 2026-09-28. Look-alike codes we did NOT
# pick (denied/withdrawn requests, other ways a concession gets granted or
# ended) are listed in Code/open_decisions.md.
MILESTONES = {
    # Research report approved. Not used anywhere downstream right now.
    "date_research_approved": [
        "317",   # DIR REQ LAV/RELATÓRIO PESQUISA APROVADO ART 30 I CM PUBL
        "291",   # DIR REQ LAV/RELATÓRIO PESQUISA APROVADO C/REDUÇÃO ÁREA PUBL
    ],
    # Company files for a mining concession - a right enters the pipeline here.
    "date_concession_requested": [
        "350",   # REQ LAV/REQUERIMENTO LAVRA PROTOC
        "1781",  # REQ LAV/REQUERIMENTO LAVRA PROTOC FORA DO PRAZO (filed late)
    ],
    # Concession granted (ordinance published by the ministry or ANM).
    "date_concession_granted": [
        "400",   # CONC LAV/PORTARIA CONCESSÃO DE LAVRA MME PUBL
        "2132",  # CONC LAV/PORTARIA CONCESSÃO DE LAVRA ANM PUBL
        "2611",  # CONC LAV/PORTARIA CONCESSÃO DE LAVRA GER/ANM PUBL
    ],
    # Company reports it started mining. Counts as "opened" in the pipeline.
    # 1198 and 1245 belong to other regimes (licensing, artisanal PLG).
    "date_mining_start": [
        "405",   # CONC LAV/INÍCIO DE LAVRA COMUNICADO PROTOC
        "1198",  # LICEN/INÍCIO DE LAVRA COMUNICADO PROTOC
        "1245",  # PLG/INÍCIO DE LAVRA COMUNICADO PROTOC
    ],
    # Concession ended: renounced, lapsed, annulled or revoked.
    "date_concession_ended": [
        "554",   # CONC LAV/RENÚNCIA CONCESSÃO LAVRA HOMOLOGADA PUBL
        "499",   # CONC LAV/PORTARIA CADUCIDADE CONCESSÃO LAVRA MME PUBL
        "2135",  # CONC LAV/PORTARIA CADUCIDADE CONCESSÃO LAVRA ANM PUBL
        "2913",  # CONC LAV/PORTARIA CADUCADA CONCESSÃO DE LAVRA MME PUBL
        "496",   # CONC LAV/PORTARIA NULIDADE CONCESSÃO DE LAVRA MME PUBL
        "2134",  # CONC LAV/PORTARIA NULIDADE CONCESSÃO DE LAVRA ANM PUBL
        "498",   # CONC LAV/PORTARIA REVOGAÇÃO CONCESSÃO DE LAVRA MME PUBL
    ],
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
