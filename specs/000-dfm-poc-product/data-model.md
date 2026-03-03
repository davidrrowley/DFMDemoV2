# Data Model: DFM Ingestion and Standardisation Platform

> Scope: Stage contracts, core entities, governance outputs, and relationships.

## Overview

The platform operates through three logical contracts:

| Stage | Logical contract | Purpose |
|---|---|---|
| Stage 1 | `source_dfm_raw` | Preserve all supplied source rows with provenance and parse diagnostics |
| Stage 2 | `individual_dfm_consolidated` | Canonical per-DFM standardisation contract |
| Stage 3 | `aggregated_dfms_consolidated` | Union of gate-passing Stage 2 records for downstream use |

## Stage 1: `source_dfm_raw`

Minimal-assumption row persistence for all input files.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `period` | string | No | YYYY-MM |
| `run_id` | string | No | UTC run identifier |
| `dfm_id` | string | No | DFM key |
| `profile_id` | string | No | Adapter profile used |
| `source_file` | string | No | Filename |
| `source_sheet` | string | Yes | Sheet name for workbook sources |
| `source_row_id` | string | No | Stable row pointer |
| `raw_record_json` | string | No | Full original record payload |
| `header_version` | string | Yes | Header signature/version |
| `parse_status` | string | No | `ok`, `partial`, `error` |
| `parse_error_code` | string | Yes | If parse failed |
| `ingested_at` | timestamp | No | Ingest time |

## Stage 2: `individual_dfm_consolidated`

Standardized holdings contract produced by adapter profiles.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `period` | string | No | YYYY-MM |
| `run_id` | string | No | UTC run identifier |
| `dfm_id` | string | No | DFM key |
| `profile_id` | string | No | Adapter profile used |
| `source_file` | string | No | Provenance |
| `source_sheet` | string | Yes | Provenance |
| `source_row_id` | string | No | Provenance |
| `row_hash` | string | No | Deterministic dedup key |
| `policyholder_number` | string | Yes | Mapped policy number |
| `account_number` | string | Yes | Source account reference |
| `security_code` | string | Yes | Standardized security code |
| `isin` | string | Yes | Identifier |
| `sedol` | string | Yes | Identifier |
| `other_security_id` | string | Yes | Fallback identifier |
| `id_type` | string | Yes | Identifier type |
| `asset_name` | string | Yes | Normalized asset name |
| `instrument_name` | string | Yes | Source description |
| `instrument_type` | string | Yes | Source classification |
| `holding` | decimal(28,8) | No | Quantity |
| `local_bid_price` | decimal(28,8) | Yes | Local price |
| `local_currency` | string | Yes | ISO code |
| `fx_rate` | decimal(28,8) | Yes | Conversion rate |
| `cash_value_gbp` | decimal(28,8) | No | GBP cash value |
| `bid_value_gbp` | decimal(28,8) | Yes | GBP bid value |
| `accrued_interest_gbp` | decimal(28,8) | No | GBP accrued |
| `acq_cost_in_gbp` | decimal(28,8) | Yes | Optional acquisition cost |
| `include_flag` | string | No | `Include` or `Remove` |
| `exclusion_reason_code` | string | Yes | Rule or override code |
| `mapping_version` | string | Yes | Mapping set version |
| `identifier_chosen` | string | Yes | E.g. `SEDOL`, `ISIN`, `SECURITY_CODE` |
| `decision_trace_json` | string | Yes | Transformation decisions |
| `data_quality_flags` | array<string> | No | Flags from parse + transform |
| `standardized_at` | timestamp | No | Stage 2 write time |

## Stage 3: `aggregated_dfms_consolidated`

Cross-DFM consolidated holdings derived from Stage 2 gate-passing rows.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `period` | string | No | YYYY-MM |
| `run_id` | string | No | UTC run identifier |
| `dfm_id` | string | No | Original DFM key |
| `policyholder_number` | string | Yes | Consolidated policy key |
| `security_code` | string | Yes | Consolidated security key |
| `isin` | string | Yes | Identifier |
| `sedol` | string | Yes | Identifier |
| `asset_name` | string | Yes | Asset name |
| `holding` | decimal(28,8) | No | Quantity |
| `cash_value_gbp` | decimal(28,8) | No | GBP cash |
| `bid_value_gbp` | decimal(28,8) | Yes | GBP bid |
| `accrued_interest_gbp` | decimal(28,8) | No | GBP accrued |
| `source_count` | int | No | Number of contributing Stage 2 rows |
| `published_at` | timestamp | No | Stage 3 publish time |

## Governance and Controls

| Table | Purpose |
|---|---|
| `dq_results` | Rule outcomes by run/DFM/check |
| `dq_exception_rows` | Failing row pointers with context |
| `run_audit_log` | Per-DFM per-stage operational status |
| `schema_drift_events` | Source schema changes |
| `parse_errors` | Parse failures and offending values |
| `policy_aggregates` | Policy-level totals for controls and reporting |
| `tpir_load_equivalent` | Downstream output contract projection |

## Relationships

```text
run_audit_log (run_id, dfm_id)
  -> source_dfm_raw (run_id, dfm_id)
  -> individual_dfm_consolidated (run_id, dfm_id)
  -> dq_results (run_id, dfm_id)
  -> dq_exception_rows (run_id, dfm_id)

individual_dfm_consolidated (run_id, dfm_id, row_hash)
  -> aggregated_dfms_consolidated (run_id, dfm_id)
  -> policy_aggregates (run_id, dfm_id, policyholder_number)
  -> tpir_load_equivalent (run_id, dfm_id)
```

## Stage-Gate Rules

- Stage 1 gate: all discovered files are persisted and parse outcomes are recorded.
- Stage 2 gate: rows conform to Stage 2 schema and required controls are evaluated.
- Stage 3 gate: only rows meeting required severity thresholds are published.

## Compatibility Note

During notebook migration, existing physical tables may temporarily coexist with these logical names. Product docs remain authoritative for logical stage contracts.
