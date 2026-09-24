"""
Pull Pix (Brazil's instant payment system) transaction statistics by
municipality from the Central Bank of Brazil's open data OData API.

This is aggregated, publicly published data (monthly totals by
municipality x payer/receiver x person type) - the Central Bank doesn't
publish individual transaction records.

IMPORTANT: TransacoesPixPorMunicipio is a parameterized OData function,
not a plain queryable entity set - two things are required together, or
it 400s:
  1. A "DataBase" function parameter (any non-empty date string satisfies
     it - it doesn't actually filter anything itself, it just unlocks
     the function; confirmed directly, a query with DataBase='202011'
     alone still returned rows from every other month too).
  2. An explicit $filter=AnoMes eq <yyyymm> to actually scope the result
     to one month.
Both confirmed directly with curl against the live API (2026-09) - the
raw XML $metadata calls the parameter "DataBase" (not "BaseDate", which
is what BCB's own web-app URL bar showed - that URL turned out to be the
app's internal display state, not a real callable request; pasting it
directly 400s the same way a bare "BaseDate" parameter does). So this
loops one API call per month, Nov 2020 (when Pix launched) through the
current month, pulling text/csv directly and concatenating every month
into one file. One month's data is ~5,570 rows (one per municipality),
confirmed directly, so $top below comfortably covers it with room to
spare.

There's no municipality x industry breakdown available in Pix's open
data - industry (CnaePorteRecebedor) and municipality
(TransacoesPixPorMunicipio) are separate entities, neither crossed with
the other. This pulls the municipality one only.

Source (browse/click through it yourself here first if you want):
https://dadosabertos.bcb.gov.br/dataset/pix
Data navigator (build/test a query by hand):
https://olinda.bcb.gov.br/olinda/servico/Pix_DadosAbertos/versao/v1/aplicacao#!/

Reruns are safe - this always rebuilds the whole file from scratch
rather than appending, so there's no duplication risk, just a bit of
re-fetching. The whole series is small (a few hundred thousand rows
total), so that's cheap.

Municipality/state names come back with accented Portuguese characters
(e.g. "GOIÁS", "SÃO PAULO") - confirmed directly these are correctly
UTF-8 encoded on the wire, not corrupted. Stripped to plain ASCII here
anyway ("GOIAS", "SAO PAULO") so the raw file behaves the same on every
co-author's machine regardless of locale/default encoding, rather than
relying on every downstream tool being told to read UTF-8 correctly.

Same config.py setup as the other pull scripts - see pull_sigmine.py if
this errors out on missing config.py.
"""

import sys
import time
import unicodedata
import urllib.request
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

try:
    import config
except ImportError:
    raise SystemExit(
        "Couldn't find config.py in the Code folder.\n"
        "Run config.do in Stata first (once per session) - see the README."
    )

if not Path(config.PROJECT_ROOT).is_dir():
    raise SystemExit(
        f"PROJECT_ROOT in config.py doesn't point to a real folder:\n"
        f"  {config.PROJECT_ROOT}\n"
        f"Run config.do again with the right paths."
    )

DATA_DIR = Path(config.PROJECT_ROOT) / "Data" / "PIX"

BASE_URL = (
    "https://olinda.bcb.gov.br/olinda/servico/Pix_DadosAbertos/versao/v1/"
    "odata/TransacoesPixPorMunicipio(DataBase=@DataBase)"
)
# Real field names, confirmed against the raw XML $metadata directly.
SELECT_FIELDS = (
    "AnoMes,Municipio_Ibge,Municipio,Estado_Ibge,Estado,Sigla_Regiao,"
    "Regiao,VL_PagadorPF,QT_PagadorPF,VL_PagadorPJ,QT_PagadorPJ,"
    "VL_RecebedorPF,QT_RecebedorPF,VL_RecebedorPJ,QT_RecebedorPJ,"
    "QT_PES_PagadorPF,QT_PES_PagadorPJ,QT_PES_RecebedorPF,QT_PES_RecebedorPJ"
)
# top=10000 comfortably covers all ~5,570 municipalities in one month's
# call (confirmed directly: one month is exactly 5,570 rows) - no need
# for further paging once $filter scopes it to one month.
TOP = 10000

FIRST_YEAR_MONTH = (2020, 11)  # Pix launched November 2020


def strip_accents(text):
    """Transliterate accented characters to their plain-ASCII base letter
    (e.g. "GOIÁS" -> "GOIAS", "SÃO PAULO" -> "SAO PAULO").

    NFKD decomposes each accented character into a base letter plus a
    separate combining-accent codepoint; encoding to ASCII with
    errors="ignore" then just drops the accent marks, leaving the plain
    base letters untouched. Only the municipality/state name columns
    actually have accents, but this runs on the whole CSV text since
    everything else (digits, commas, plain region codes) is already
    ASCII and passes through unchanged either way.
    """
    decomposed = unicodedata.normalize("NFKD", text)
    return decomposed.encode("ascii", errors="ignore").decode("ascii")


def year_months_through_today(first_year, first_month):
    """Yield every (year, month) from first_year/first_month through the
    current calendar month."""
    today = date.today()
    year, month = first_year, first_month
    while (year, month) <= (today.year, today.month):
        yield year, month
        month += 1
        if month == 13:
            month = 1
            year += 1


def fetch_month_csv(year, month, attempts=3):
    """GET one month's municipality data as raw CSV text.

    Needs both the DataBase function parameter (to invoke the function
    at all) and an explicit $filter on AnoMes (to actually scope results
    to this one month) - see the module docstring for why both are
    required.
    """
    year_month = f"{year:04d}{month:02d}"
    url = (
        f"{BASE_URL}?@DataBase='{year_month}'"
        f"&$filter=AnoMes%20eq%20{year_month}&$top={TOP}"
        f"&$format=text/csv&$select={SELECT_FIELDS}"
    )
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                csv_text = response.read().decode("utf-8-sig")
                return strip_accents(csv_text)
        except Exception as e:
            if attempt == attempts:
                raise
            print(f"    Attempt {attempt} failed ({e}), retrying...")
            time.sleep(3)


def main():
    print(f"Project root (from config.py): {config.PROJECT_ROOT}")
    print(f"Data will be saved under: {DATA_DIR}\n")

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    file_path = DATA_DIR / "pix_transacoes_municipio.csv"

    header_written = False
    months_done = 0
    months_skipped = []

    with open(file_path, "w", newline="", encoding="utf-8") as out_file:
        for year, month in year_months_through_today(*FIRST_YEAR_MONTH):
            label = f"{year:04d}-{month:02d}"
            print(f"  Fetching {label}...")
            try:
                csv_text = fetch_month_csv(year, month)
            except Exception as e:
                print(f"    Could not fetch {label} after retrying: {e}")
                months_skipped.append(label)
                continue

            lines = [ln for ln in csv_text.splitlines() if ln.strip()]
            if len(lines) <= 1:
                # Header only (or nothing) - most likely the current
                # month just hasn't been published yet.
                print(f"    No data rows for {label} - probably not published yet, skipping.")
                months_skipped.append(label)
                continue

            if not header_written:
                out_file.write(lines[0] + "\n")
                header_written = True
            out_file.write("\n".join(lines[1:]) + "\n")
            months_done += 1

    print(f"\nDone - pulled {months_done} months into {file_path}")
    if months_skipped:
        print(f"Skipped (no data / failed): {', '.join(months_skipped)}")


if __name__ == "__main__":
    main()
