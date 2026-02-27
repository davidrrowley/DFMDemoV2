# 02 — Data Contracts

## Canonical Table: `canonical_holdings` (Delta)

Required columns:

| Column | Type | Notes |
|--------|------|-------|
| `period` | string | YYYY-MM |
| `run_id` | string | UTC timestamp |
| `dfm_id` | string | |
| `dfm_name` | string | |
| `source_file` | string | |
| `source_sheet` | string | nullable |
| `source_row_id` | string | |
| `policy_id` | string | |
| `policy_id_type` | string | DFM or IH |
| `dfm_policy_id` | string | nullable, for traceability |
| `security_id` | string | nullable |
| `isin` | string | nullable |
| `other_security_id` | string | nullable |
| `id_type` | string | nullable |
| `asset_name` | string | nullable |
| `holding` | decimal | |
| `local_bid_price` | decimal | |
| `local_currency` | string | |
| `fx_rate` | decimal | nullable |
| `cash_value_gbp` | decimal | default 0 |
| `bid_value_gbp` | decimal | nullable if cannot compute |
| `accrued_interest_gbp` | decimal | default 0 |
| `report_date` | date | nullable |
| `ingested_at` | timestamp | |
| `data_quality_flags` | array\<string\> | |

## Output Table: `tpir_load_equivalent` (Delta)

Schema must match the templates' tpir_load header:

| Column |
|--------|
| `Policyholder_Number` |
| `Security_Code` |
| `ISIN` |
| `Other_Security_ID` |
| `ID_Type` |
| `Asset_Name` |
| `Acq_Cost_in_GBP` |
| `Cash_Value_in_GBP` |
| `Bid_Value_in_GBP` |
| `Accrued_Interest` |
| `Holding` |
| `Loc_Bid_Price` |
| `Currency_Local` |

## Output Table: `policy_aggregates` (Delta)

Group by: `period`, `run_id`, `dfm_id`, `policy_id`

Compute:
- `total_cash_value_gbp`
- `total_bid_value_gbp`
- `total_accrued_interest_gbp`

These correspond to the Excel Rec_Output SUMIFS totals for cash/bid/accrued.

## Table: `validation_events` (Delta)

| Column | Type | Notes |
|--------|------|-------|
| `period` | string | |
| `run_id` | string | |
| `event_time` | timestamp | |
| `dfm_id` | string | |
| `dfm_name` | string | |
| `policy_id` | string | |
| `security_id` | string | nullable |
| `rule_id` | string | |
| `severity` | string | stop, exception, or warning |
| `status` | string | fail or not_evaluable |
| `details_json` | string | JSON-encoded details |
| `source_file` | string | nullable |

## Governance Tables

### `run_audit_log` (Delta)

| Column | Type |
|--------|------|
| `run_id` | string |
| `period` | string |
| `dfm_id` | string |
| `files_processed` | int |
| `rows_ingested` | int |
| `parse_errors_count` | int |
| `drift_events_count` | int |
| `status` | string |
| `started_at` | timestamp |
| `completed_at` | timestamp |

### `schema_drift_events` (Delta)

| Column | Type |
|--------|------|
| `run_id` | string |
| `dfm_id` | string |
| `source_file` | string |
| `column_name` | string |
| `drift_type` | string |
| `detected_at` | timestamp |

### `parse_errors` (Delta)

| Column | Type |
|--------|------|
| `run_id` | string |
| `dfm_id` | string |
| `source_file` | string |
| `source_row_id` | string |
| `error_message` | string |
| `raw_value` | string |
| `detected_at` | timestamp |
