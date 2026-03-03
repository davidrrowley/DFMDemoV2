# 02 - Data Contracts

## Stage 1 Contract: `source_dfm_raw`

Required fields:

| Column | Type | Notes |
|---|---|---|
| `period` | string | YYYY-MM |
| `run_id` | string | UTC run ID |
| `dfm_id` | string | DFM key |
| `profile_id` | string | Adapter profile key |
| `source_file` | string | Filename |
| `source_sheet` | string | Nullable |
| `source_row_id` | string | Source row pointer |
| `raw_record_json` | string | Full source record |
| `parse_status` | string | `ok`, `partial`, `error` |
| `ingested_at` | timestamp | Ingestion time |

## Stage 2 Contract: `individual_dfm_consolidated`

Required fields:

| Column | Type | Notes |
|---|---|---|
| `period` | string | YYYY-MM |
| `run_id` | string | UTC run ID |
| `dfm_id` | string | DFM key |
| `profile_id` | string | Adapter profile key |
| `source_file` | string | Provenance |
| `source_row_id` | string | Provenance |
| `row_hash` | string | Deterministic dedup key |
| `policyholder_number` | string | Nullable |
| `security_code` | string | Nullable |
| `isin` | string | Nullable |
| `sedol` | string | Nullable |
| `other_security_id` | string | Nullable |
| `id_type` | string | Nullable |
| `asset_name` | string | Nullable |
| `holding` | decimal | Required |
| `local_bid_price` | decimal | Nullable |
| `local_currency` | string | Nullable |
| `fx_rate` | decimal | Nullable |
| `cash_value_gbp` | decimal | Required |
| `bid_value_gbp` | decimal | Nullable |
| `accrued_interest_gbp` | decimal | Required |
| `include_flag` | string | `Include` or `Remove` |
| `exclusion_reason_code` | string | Nullable |
| `identifier_chosen` | string | Nullable |
| `decision_trace_json` | string | Nullable |
| `data_quality_flags` | array<string> | Required |

## Stage 3 Contract: `aggregated_dfms_consolidated`

Required fields:

| Column | Type | Notes |
|---|---|---|
| `period` | string | YYYY-MM |
| `run_id` | string | UTC run ID |
| `dfm_id` | string | Source DFM key |
| `policyholder_number` | string | Nullable |
| `security_code` | string | Nullable |
| `isin` | string | Nullable |
| `sedol` | string | Nullable |
| `asset_name` | string | Nullable |
| `holding` | decimal | Required |
| `cash_value_gbp` | decimal | Required |
| `bid_value_gbp` | decimal | Nullable |
| `accrued_interest_gbp` | decimal | Required |
| `source_count` | int | Required |
| `published_at` | timestamp | Required |

## Gate Output Contracts

### `dq_results`

| Column | Type | Notes |
|---|---|---|
| `period` | string | |
| `run_id` | string | |
| `dfm_id` | string | |
| `check_id` | string | |
| `severity` | string | `warning`, `exception`, `stop` |
| `status` | string | `pass`, `fail`, `not_evaluable` |
| `metric_value` | double | Nullable |
| `threshold_value` | double | Nullable |
| `details_json` | string | JSON details |
| `evaluated_at` | timestamp | |

### `dq_exception_rows`

| Column | Type | Notes |
|---|---|---|
| `period` | string | |
| `run_id` | string | |
| `dfm_id` | string | |
| `check_id` | string | |
| `source_file` | string | |
| `source_row_id` | string | |
| `failure_reason` | string | |
| `details_json` | string | JSON context |
| `created_at` | timestamp | |

## Downstream Output Contract

`tpir_load_equivalent` remains compatible with the existing 13-column downstream schema.
