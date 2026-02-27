# 13 — DFM: Castlebay

## Input

| File | Role |
|------|------|
| `Cde OSB Val 31Dec25.xlsx` | Positions (two sheets) |

## Parsing

- Header row is row 3 (1-based index 3; `header_row_index_1based: 3` in config)
- Ingest both sheets: `Customer 1` and `Customer 2`

## Canonical Mapping

| Canonical Column | Source Column | Notes |
|------------------|---------------|-------|
| `policy_id` | `Account Name` | |
| `isin` | `ISIN Code` | |
| `security_id` | `ISIN Code` else `SEDOL` | |
| `holding` | `Quantity Held` | |
| `local_bid_price` | `Price in Stock Currency` | |
| `bid_value_local` | `Value in Market` | |
| `local_currency` | Derived from `Currency Description` | Via `currency_mapping.json` |
| `report_date` | Inferred from filename | `31Dec25` → `2025-12-31` |
| `cash_value_gbp` | 0 (default, flag `CASH_DEFAULTED`) | |
| `accrued_interest_gbp` | 0 (default, flag `ACCRUED_DEFAULTED`) | |
| `acq_cost` | Optional column | If unparseable: null + flag `ACQ_COST_UNPARSEABLE` |

## Currency Derivation

Apply `currency_mapping.json` (Castlebay section) to `Currency Description`. If the description is not found in the mapping, flag `CURRENCY_UNKNOWN` and leave `local_currency = null`.

## GBP Rules

- If `local_currency == GBP` → `fx_rate = 1.0`, `bid_value_gbp = bid_value_local`
- If `local_currency` is a foreign currency and `fx_rates.csv` available → convert
- Else → `bid_value_gbp = null`, flag `FX_NOT_AVAILABLE`

## Date Inference

Filename pattern: `Cde OSB Val 31Dec25.xlsx`
- Extract `31Dec25` → parse as `31-Dec-2025` → `report_date = 2025-12-31`
- Flag `DATE_FROM_FILENAME` in `data_quality_flags`
