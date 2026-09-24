"""
Reshape two IBGE workbooks into clean, mergeable files:

1. The pairwise activity x activity file (Tabela 14 and Tabela 15 of
   Matriz_de_Insumo_Produto_2015_Nivel_67.xls): one row per (supplier
   activity, user activity) pair, with the direct and total requirement
   coefficients.
2. A per-activity totals file: intermediate consumption (Tabela 02's
   "Total" row, same workbook) plus value added (Tabela 10.2, a
   different workbook - Sistema_de_Contas_Nacionais). Combined, these
   give each activity's total OUTPUT (Output = Intermediate Consumption
   + Value Added) - a number IBGE doesn't publish directly as its own
   table, but needed to convert direct-requirement shares into real
   monetary flows or Ghosh-style allocation coefficients (both currently
   normalized the "wrong" way for that - see clean_io_matrix.do).

Tabela 14 ("Matriz D.Bn") = direct requirements, activity x activity -
confirmed directly against the raw file this is the right one (NOT
Tabela 11/"Matriz Bn", which turned out to be product-level - 134 rows
with product codes like "01911", not the 67 activity codes).
Tabela 15 ("Matriz de Leontief") = total (direct + indirect) requirements,
already computed by IBGE, same activity x activity shape as Tabela 14.

Coefficient convention (confirmed against IBGE's own row/column labels):
coefficient(row, column) = how much of ROW activity's output is needed,
per unit of COLUMN activity's output. So row = supplier, column = user.
To find what's upstream of mining, filter user_cnae67 == a mining code.
To find what's downstream of mining, filter supplier_cnae67 == a mining
code.

Value added is pulled from Tabela 10.2's 2015 CURRENT-price column -
confirmed directly which column that is by checking real values: iron
ore's nominal value added crashes hard in one specific column (matching
the real, well-known 2015 iron ore price collapse) while a neighboring
column doesn't - that's the current-price column, not the
inflation-adjusted constant-price one right next to it.

Kept as the FULL 67x67 matrix (not pre-filtered to mining) since it's
tiny either way (4,489 rows) and useful beyond just the mining
classification - filtering to mining-relevant pairs happens at whatever
analysis actually uses this, not baked in here.

Called from clean_io_matrix.do - not meant to be run standalone, though
nothing stops you from doing so directly.

Usage: python3 reshape_io_matrix.py <io_matrix_xls_path> <value_added_xls_path> <long_csv_output_path> <activity_totals_csv_output_path>
"""

import sys
from pathlib import Path

import pandas as pd

IO_MATRIX_PATH = Path(sys.argv[1])
VALUE_ADDED_PATH = Path(sys.argv[2])
LONG_OUT_PATH = Path(sys.argv[3])
TOTALS_OUT_PATH = Path(sys.argv[4])


def load_activity_matrix(path, sheet_name):
    """Read one Tabela (14 or 15) and return it as a long DataFrame:
    supplier_cnae67, user_cnae67, coefficient.
    """
    df = pd.read_excel(path, sheet_name=sheet_name, header=None)

    # Row 3 holds the column headers, one per activity, each cell like
    # "0191\nAgricultura, inclusive..." - the code is the text before the
    # newline. Real data columns start at column index 2 (0 and 1 are
    # the row-label code/description columns).
    header_row = df.iloc[3]
    col_codes = {}
    for col_idx in range(2, df.shape[1]):
        cell = header_row[col_idx]
        if pd.isna(cell):
            continue
        code = str(cell).split("\n")[0].strip()
        col_codes[col_idx] = code

    # Data rows start at row 5. Row label (supplier code) is column 0.
    # Stop at the first row without a valid-looking row label (catches
    # the "Fonte: IBGE..." footer row at the bottom of the sheet).
    records = []
    for row_idx in range(5, df.shape[0]):
        row_code_raw = df.iloc[row_idx, 0]
        if pd.isna(row_code_raw):
            continue
        row_code = str(row_code_raw).strip()
        if not row_code.isdigit():
            continue  # footer/source note row, not a real activity code

        for col_idx, col_code in col_codes.items():
            value = df.iloc[row_idx, col_idx]
            records.append((row_code, col_code, value))

    long_df = pd.DataFrame(records, columns=["supplier_cnae67", "user_cnae67", "value"])
    long_df["supplier_cnae67"] = long_df["supplier_cnae67"].astype(int)
    long_df["user_cnae67"] = long_df["user_cnae67"].astype(int)
    return long_df


def load_intermediate_consumption(path):
    """Extract total intermediate consumption per activity from Tabela
    02 (same workbook as Tabelas 14/15) - the "Total" row, confirmed
    directly against the real file (row 133 in the 2015 version, found
    here by searching for the "Total" label instead of hardcoding the
    row number in case a future vintage shifts it).
    """
    df = pd.read_excel(path, sheet_name="02", header=None)

    # Unlike Tabelas 14/15, this header row has an extra "Total" column
    # mixed in among the 67 real activity columns (confirmed directly -
    # caused a real crash here first) - skip anything whose code isn't
    # purely digits.
    header_row = df.iloc[3]
    col_codes = {}
    for col_idx in range(2, df.shape[1]):
        cell = header_row[col_idx]
        if pd.isna(cell):
            continue
        code = str(cell).split("\n")[0].strip()
        if not code.isdigit():
            continue
        col_codes[col_idx] = code

    total_row_idx = None
    for row_idx in range(df.shape[0]):
        if str(df.iloc[row_idx, 0]).strip() == "Total":
            total_row_idx = row_idx
            break
    if total_row_idx is None:
        raise ValueError("Couldn't find the 'Total' row in Tabela 02 - check the raw file's structure.")

    records = [(code, df.iloc[total_row_idx, col_idx]) for col_idx, code in col_codes.items()]
    ic_df = pd.DataFrame(records, columns=["cnae67", "intermediate_consumption"])
    ic_df["cnae67"] = ic_df["cnae67"].astype(int)
    return ic_df


def load_value_added(path):
    """Extract 2015 current-price Value Added by activity from Tabela
    10.2 - column 12 confirmed directly against real values (see module
    docstring).

    Tabela 10.2 actually has 68 activities, not 67 - it splits commerce
    into two codes (4500 "Comercio e reparacao de veiculos automotores e
    motocicletas" and 4680 "Comercio por atacado e a varejo, exceto
    veiculos automotores") where the IO matrix's own Tabela 02 keeps
    commerce as a single combined code, 4580 - confirmed directly by
    checking both tables' row/column labels after a first pass left 4500
    and 4680 with no match. Summed back into 4580 here so this lines up
    with the 67-activity codes used everywhere else (same kind of
    split/combined mismatch as the education/health public-private
    codes found earlier in this project).
    """
    df = pd.read_excel(path, sheet_name="Plan1", header=None)

    records = []
    for row_idx in range(df.shape[0]):
        code_raw = df.iloc[row_idx, 0]
        if pd.isna(code_raw):
            continue
        code = str(code_raw).strip()
        if not code.isdigit():
            continue  # skips the header rows and the national-total row (code sits in a different column there)
        records.append((code, df.iloc[row_idx, 12]))

    va_df = pd.DataFrame(records, columns=["cnae67", "value_added"])
    va_df["cnae67"] = va_df["cnae67"].astype(int)

    # Collapse the 4500/4680 commerce split back into 4580.
    commerce_split = [4500, 4680]
    commerce_total = va_df.loc[va_df["cnae67"].isin(commerce_split), "value_added"].sum()
    va_df = va_df[~va_df["cnae67"].isin(commerce_split)]
    va_df = pd.concat(
        [va_df, pd.DataFrame([{"cnae67": 4580, "value_added": commerce_total}])],
        ignore_index=True,
    )

    return va_df


def main():
    print(f"Reading {IO_MATRIX_PATH}...")

    direct = load_activity_matrix(IO_MATRIX_PATH, "14")
    direct = direct.rename(columns={"value": "direct_coef"})

    leontief = load_activity_matrix(IO_MATRIX_PATH, "15")
    leontief = leontief.rename(columns={"value": "leontief_coef"})

    print(f"Tabela 14 (direct): {len(direct)} rows")
    print(f"Tabela 15 (Leontief): {len(leontief)} rows")

    combined = direct.merge(leontief, on=["supplier_cnae67", "user_cnae67"], how="outer")
    print(f"Combined: {len(combined)} rows (expect 67*67 = 4,489)")

    LONG_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    combined.to_csv(LONG_OUT_PATH, index=False)
    print(f"Saved to {LONG_OUT_PATH}")

    print(f"\nReading intermediate consumption from {IO_MATRIX_PATH}...")
    intermediate_consumption = load_intermediate_consumption(IO_MATRIX_PATH)

    print(f"Reading value added from {VALUE_ADDED_PATH}...")
    value_added = load_value_added(VALUE_ADDED_PATH)

    totals = intermediate_consumption.merge(value_added, on="cnae67", how="outer")
    print(f"Activity totals: {len(totals)} rows (expect 67)")

    TOTALS_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    totals.to_csv(TOTALS_OUT_PATH, index=False)
    print(f"Saved to {TOTALS_OUT_PATH}")


if __name__ == "__main__":
    main()
