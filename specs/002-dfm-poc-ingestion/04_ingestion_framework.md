# 04 — Ingestion Framework

## Common Ingestion Steps (all DFMs)

1. Discover files in `/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/`
2. Classify file role(s) per DFM config (positions, cash, valuation, etc.)
3. Parse (CSV/XLSX) using DFM config from `raw_parsing_config.json`
4. Extract required fields into a DFM staging DataFrame
5. Transform to canonical columns per DFM spec
6. Currency normalisation and GBP population
7. Append to `canonical_holdings`
8. Emit drift/parse errors as required

## Numeric Parsing Rules

Support both:
- UK/US style: `13,059.70` (thousands separator `,`, decimal `.`)
- European style: `3.479,29` (thousands separator `.`, decimal `,`)

Detection heuristic: if value contains both `.` and `,`, and `,` appears after `.`, treat as European. If `european_decimals: true` in DFM config, always use European parsing.

## Date Parsing Rules

Support:
- `dd-MMM-yyyy` — e.g. `31-Dec-2025`
- `dd/MM/yyyy` — e.g. `31/12/2025`
- ISO datetime — e.g. `2025-12-31T00:12:00.000`
- Filename inference — when no date field exists, extract date from filename (e.g. `31Dec25` → `2025-12-31`)

## De-duplication

Implement row-hash de-duplication per DFM role to avoid double counting duplicate file copies.

Hash key: concatenation of all source fields before transformation (SHA-256 or MD5 is acceptable for PoC).

De-duplication is applied within the ingestion notebook before writing to `canonical_holdings`.

## Currency Normalisation

1. If `local_currency` is `GBP` → `fx_rate = 1.0`, `bid_value_gbp = bid_value_local`
2. Else if DFM provides a GBP-denominated value column → use it directly
3. Else if `fx_rates.csv` is present → join on `local_currency` and convert
4. Else → `bid_value_gbp = null`, add flag `FX_NOT_AVAILABLE` to `data_quality_flags`

## Data Quality Flags

| Flag | Meaning |
|------|---------|
| `CURRENCY_ASSUMED_GBP` | Currency absent; GBP assumed |
| `FX_NOT_AVAILABLE` | FX rate not found; GBP value not computed |
| `PRICE_ABSENT` | Price field absent or null |
| `DATE_FROM_FILENAME` | Report date inferred from filename |
| `ACQ_COST_UNPARSEABLE` | Acquisition cost could not be parsed |
| `CASH_DEFAULTED` | Cash value defaulted to 0 |
| `ACCRUED_DEFAULTED` | Accrued interest defaulted to 0 |
