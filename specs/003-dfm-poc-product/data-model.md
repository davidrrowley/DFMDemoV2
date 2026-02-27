# Data Model: DFM PoC Ingestion Platform

> **Scope:** Canonical entity definitions, Delta table schemas, validation rules, and relationships
> for all data produced by the DFM PoC Ingestion Platform.

## Overview

The platform produces seven Delta tables:

| Table | Role |
|---|---|
| `canonical_holdings` | Normalised row-level holdings from all DFMs |
| `tpir_load_equivalent` | Output schema matching the existing tpir_load contract |
| `policy_aggregates` | GBP totals by DFM + policy, matching Rec_Output SUMIFS |
| `validation_events` | Results of all validation rule evaluations |
| `run_audit_log` | One row per DFM per run; file and row counts, status |
| `schema_drift_events` | Schema changes detected in source files |
| `parse_errors` | Row-level parse failures from DFM ingestion |

---

## Canonical Table: `canonical_holdings`

**Purpose:** Single source of truth for normalised, GBP-equivalent holdings across all four DFMs.

**Partition strategy:** Partition by `period` and `dfm_id` for efficient per-run queries.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `period` | string | No | YYYY-MM format (e.g., `2025-12`) |
| `run_id` | string | No | UTC timestamp (e.g., `20251231T142300Z`) |
| `dfm_id` | string | No | One of: `brown_shipley`, `wh_ireland`, `pershing`, `castlebay` |
| `dfm_name` | string | No | Human-readable DFM name |
| `source_file` | string | No | Original filename from landing zone |
| `source_sheet` | string | Yes | Excel sheet name (null for CSV sources) |
| `source_row_id` | string | No | Row identifier within source file (e.g., `row_42`) |
| `policy_id` | string | No | Policy identifier (IH format if mapped, DFM format otherwise) |
| `policy_id_type` | string | No | `IH` if mapped from DFM to IH policy, `DFM` if unmapped |
| `dfm_policy_id` | string | Yes | Original DFM-side policy identifier, for traceability |
| `security_id` | string | Yes | Primary security identifier |
| `isin` | string | Yes | ISIN if present |
| `other_security_id` | string | Yes | Fallback security identifier |
| `id_type` | string | Yes | Type descriptor for `other_security_id` |
| `asset_name` | string | Yes | Human-readable asset or security name |
| `holding` | decimal(28,8) | No | Number of units / shares held |
| `local_bid_price` | decimal(28,8) | No | Bid price in local currency |
| `local_currency` | string | No | ISO 4217 currency code (e.g., `GBP`, `USD`, `EUR`) |
| `fx_rate` | decimal(28,8) | Yes | FX rate to GBP; null if currency is GBP |
| `cash_value_gbp` | decimal(28,8) | No | Cash value in GBP; defaults to 0 if not applicable |
| `bid_value_gbp` | decimal(28,8) | Yes | Bid value in GBP; null if cannot be computed |
| `accrued_interest_gbp` | decimal(28,8) | No | Accrued interest in GBP; defaults to 0 |
| `report_date` | date | Yes | Valuation date from source; null if not present |
| `ingested_at` | timestamp | No | UTC timestamp when row was written |
| `row_hash` | string | No | SHA-256 hash of deterministic columns; used for de-duplication |
| `data_quality_flags` | array\<string\> | No | List of flags (e.g., `HOLDING_ASSUMED_ZERO`, `DATE_INFERRED_FROM_FILENAME`, `FX_RATE_DEFAULTED`) |

**Validation rules:**
- `period` must match YYYY-MM pattern.
- `run_id` must match UTC timestamp pattern.
- `dfm_id` must be a registered DFM from `dfm_registry.json`.
- `holding` must be ≥ 0.
- `local_currency` must be a valid ISO 4217 code.
- `row_hash` must be unique per `period` + `dfm_id` combination (enforced by MERGE upsert).

**De-duplication:** Row-hash is computed over `(dfm_id, source_file, source_sheet, source_row_id, policy_id, security_id, holding, local_bid_price, local_currency)`. MERGE upsert matches on `row_hash` to prevent duplicates when re-running the same period.

---

## Output Table: `tpir_load_equivalent`

**Purpose:** Standardised output matching the tpir_load column contract expected by downstream systems.

| Column | Type | Nullable | Source mapping |
|---|---|---|---|
| `Policyholder_Number` | string | No | `canonical_holdings.policy_id` |
| `Security_Code` | string | Yes | `canonical_holdings.security_id` |
| `ISIN` | string | Yes | `canonical_holdings.isin` |
| `Other_Security_ID` | string | Yes | `canonical_holdings.other_security_id` |
| `ID_Type` | string | Yes | `canonical_holdings.id_type` |
| `Asset_Name` | string | Yes | `canonical_holdings.asset_name` |
| `Acq_Cost_in_GBP` | decimal(28,8) | Yes | Not computed in PoC; null |
| `Cash_Value_in_GBP` | decimal(28,8) | No | `canonical_holdings.cash_value_gbp` |
| `Bid_Value_in_GBP` | decimal(28,8) | Yes | `canonical_holdings.bid_value_gbp` |
| `Accrued_Interest` | decimal(28,8) | No | `canonical_holdings.accrued_interest_gbp` |
| `Holding` | decimal(28,8) | No | `canonical_holdings.holding` |
| `Loc_Bid_Price` | decimal(28,8) | No | `canonical_holdings.local_bid_price` |
| `Currency_Local` | string | No | `canonical_holdings.local_currency` |
| `period` | string | No | Run period |
| `run_id` | string | No | Run identifier |
| `dfm_id` | string | No | Source DFM identifier |

**Note:** `Acq_Cost_in_GBP` is not available from PoC sources and is always null. This column is
retained to preserve schema compatibility with the tpir_load contract.

---

## Aggregate Table: `policy_aggregates`

**Purpose:** GBP totals by DFM + policy, providing the equivalent of the Excel Rec_Output SUMIFS values.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `period` | string | No | YYYY-MM |
| `run_id` | string | No | UTC timestamp run identifier |
| `dfm_id` | string | No | DFM identifier |
| `dfm_name` | string | No | Human-readable DFM name |
| `policy_id` | string | No | Policy identifier |
| `total_cash_value_gbp` | decimal(28,8) | No | SUM of `canonical_holdings.cash_value_gbp` |
| `total_bid_value_gbp` | decimal(28,8) | No | SUM of `canonical_holdings.bid_value_gbp` (nulls treated as 0) |
| `total_accrued_interest_gbp` | decimal(28,8) | No | SUM of `canonical_holdings.accrued_interest_gbp` |
| `row_count` | int | No | Number of canonical_holdings rows contributing to this aggregate |
| `computed_at` | timestamp | No | UTC timestamp when aggregate was computed |

**Grouping key:** `period`, `run_id`, `dfm_id`, `policy_id`

---

## Validation Table: `validation_events`

**Purpose:** Record of every rule evaluation across all DFMs and policies for a given run.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `period` | string | No | YYYY-MM |
| `run_id` | string | No | UTC timestamp run identifier |
| `event_time` | timestamp | No | UTC timestamp when event was emitted |
| `dfm_id` | string | No | DFM identifier |
| `dfm_name` | string | No | Human-readable DFM name |
| `policy_id` | string | No | Policy identifier |
| `security_id` | string | Yes | Security identifier; null for policy-level rules |
| `rule_id` | string | No | Rule identifier (e.g., `MV_001`, `DATE_001`) |
| `severity` | string | No | `stop`, `exception`, or `warning` |
| `status` | string | No | `fail` or `not_evaluable` |
| `details_json` | string | No | JSON-encoded details; for MV_001 includes `computed_mv`, `reported_mv`, `abs_diff`, `pct_diff` |
| `source_file` | string | Yes | Source filename, if applicable |

**Validation rules:**
- `severity` must be one of `stop`, `exception`, `warning`.
- `status` must be one of `fail`, `not_evaluable`.
- `details_json` must be valid JSON.

---

## Governance Table: `run_audit_log`

**Purpose:** One row per DFM per run, written at the end of each ingestion notebook and updated
by `nb_run_all` on completion.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `run_id` | string | No | UTC timestamp run identifier |
| `period` | string | No | YYYY-MM |
| `dfm_id` | string | No | DFM identifier |
| `files_processed` | int | No | Number of source files discovered and processed |
| `rows_ingested` | int | No | Rows written to `canonical_holdings` |
| `parse_errors_count` | int | No | Rows written to `parse_errors` |
| `drift_events_count` | int | No | Rows written to `schema_drift_events` |
| `status` | string | No | `OK`, `NO_FILES`, `PARTIAL`, or `FAILED` |
| `started_at` | timestamp | No | DFM ingestion start timestamp |
| `completed_at` | timestamp | Yes | DFM ingestion end timestamp; null if still running |

**Status values:**

| Status | Meaning |
|---|---|
| `OK` | All files processed, no parse errors |
| `NO_FILES` | No input files found in landing zone for the period |
| `PARTIAL` | At least one file processed; at least one parse error |
| `FAILED` | Notebook raised an unrecoverable exception |

---

## Governance Table: `schema_drift_events`

**Purpose:** Record of schema changes detected in DFM source files (new columns, missing columns,
type changes).

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `run_id` | string | No | Run identifier |
| `dfm_id` | string | No | DFM identifier |
| `source_file` | string | No | Source filename where drift was detected |
| `column_name` | string | No | Column that changed |
| `drift_type` | string | No | `missing_column`, `unexpected_column`, `type_change` |
| `detected_at` | timestamp | No | UTC timestamp |

---

## Governance Table: `parse_errors`

**Purpose:** Row-level record of parse failures encountered during DFM ingestion.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `run_id` | string | No | Run identifier |
| `dfm_id` | string | No | DFM identifier |
| `source_file` | string | No | Source filename |
| `source_row_id` | string | No | Row identifier within source file |
| `error_message` | string | No | Human-readable error description |
| `raw_value` | string | Yes | The raw cell value that failed to parse |
| `detected_at` | timestamp | No | UTC timestamp |

---

## Relationships

```
run_audit_log (run_id, dfm_id)
    └── canonical_holdings (run_id, dfm_id)
            ├── tpir_load_equivalent (run_id, dfm_id)
            ├── policy_aggregates (run_id, dfm_id, policy_id)
            └── validation_events (run_id, dfm_id, policy_id)

run_audit_log (run_id, dfm_id)
    ├── parse_errors (run_id, dfm_id)
    └── schema_drift_events (run_id, dfm_id)
```

Every row in every table carries `run_id` and `dfm_id`, enabling full cross-table joins for a single run.

---

## See Also

- [architecture.md](architecture.md) — How tables are produced in the pipeline
- [high-level-requirements.md](high-level-requirements.md) — HR-02, HR-03, HR-04, HR-06
- [specs/002-dfm-poc-ingestion/02_data_contracts.md](../002-dfm-poc-ingestion/02_data_contracts.md) — Feature-level schema detail
