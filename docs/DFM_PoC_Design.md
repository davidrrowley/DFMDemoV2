# DFM PoC Design Document

**Version:** 1.1  
**Date:** 2026-03-01  
**Status:** Draft  
**Owner:** Investment Operations Technology

> **Change log (v1.1):** Updated to reflect gap-closure work completed 2026-03-01. Additions: TPIR Upload Checker (`nb_tpir_check`), ADS loading (`nb_ads_load`), three new config inputs (`security_master.csv`, `policy_mapping.csv`, `ads_config.json`), corrected MV_001 tolerance (±2%), POP_001 enabled by default, extended pipeline diagram, updated audit log fields, Phase 8 in roadmap, SC-11/SC-12 in acceptance checklist.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Azure Infrastructure Layer](#3-azure-infrastructure-layer)
4. [Data Architecture](#4-data-architecture)
5. [Data Pipeline Design](#5-data-pipeline-design)
6. [Validation Engine](#6-validation-engine)
7. [Aggregation and Reporting](#7-aggregation-and-reporting)
8. [Governance and Audit](#8-governance-and-audit)
9. [Non-Functional Characteristics (Azure Well-Architected)](#9-non-functional-characteristics-azure-well-architected)
10. [Security Baseline](#10-security-baseline)
11. [Development Best Practices](#11-development-best-practices)
12. [Copilot Studio Integration](#12-copilot-studio-integration)
13. [Delivery Roadmap](#13-delivery-roadmap)
14. [Glossary](#14-glossary)

---

## 1. Executive Summary

Every month, investment operations analysts manually copy position and valuation data from four
Discretionary Fund Managers (DFMs) — Brown Shipley, WH Ireland, Pershing, and Castlebay — into
Excel workbooks to produce a reconciliation report. This process is slow, error-prone, and leaves
almost no audit trail.

This Proof of Concept (PoC) replaces that manual process with an automated data pipeline built on
**Microsoft Fabric**. In plain terms: instead of an analyst spending hours reformatting spreadsheets
each month, a single button-press runs a notebook that ingests all four DFM files, checks the
numbers, produces the same reconciliation totals as the Excel templates, and writes a full record
of everything it did.

The solution demonstrates five core capabilities:

1. **Automated ingestion** — the pipeline discovers and reads DFM files automatically, handling
   the different formats, date styles, and numeric conventions of each supplier.
2. **A single common view of holdings** — all DFM data is translated into a standardised format
   (the canonical holdings table) so that every downstream step works the same way regardless
   of which DFM the data came from.
3. **Deterministic validation** — the pipeline recalculates market values, checks for stale dates,
   and flags empty positions using reproducible rules. Every check is recorded, including cases
   where a check could not be performed and why.
4. **Policy-level aggregates** — the solution produces the same cash, bid, and accrued totals
   that analysts currently derive via Excel SUMIFS, ready for tie-out to the existing
   reconciliation output.
5. **Full audit trail** — every run records which files were processed, how many rows were
   ingested, which checks passed or failed, and a complete history of pipeline executions.

The PoC is built entirely within a **Microsoft Fabric** workspace using PySpark notebooks and
Delta Lake tables. No additional infrastructure is required beyond an existing Fabric licence.
The design is intentionally extensible: adding a fifth DFM requires only a new configuration
block and a new ingestion notebook — no changes to shared pipeline logic.

A forward-looking integration with **Microsoft Copilot Studio** is outlined in
[Section 12](#12-copilot-studio-integration), enabling analysts and stakeholders to query
reconciliation results conversationally using natural language.

---

## 2. Problem Statement

### 2.1 Current State

Investment operations teams manage position and valuation data from four DFMs. The current
process is entirely manual:

| Pain Point | Detail |
|---|---|
| **Fragmented formats** | Each DFM delivers data differently — Brown Shipley in CSV with European decimal notation, WH Ireland in XLSX, Pershing in two separate CSVs, Castlebay in XLSX with a non-standard header row. |
| **Manual effort** | Analysts copy, reformat, and paste data into Excel templates each month. This takes significant time and is highly error-prone. |
| **No audit trail** | There is no automated record of which source file was used, how values were transformed, or which rows were excluded. Re-running a past period requires repeating all manual steps. |
| **Fragile reconciliation** | Excel SUMIFS totals are hard to trace back to source rows. Market value recalculation checks are done manually and inconsistently. |
| **No governance** | Parse failures, schema changes in source files, and mapping gaps go undetected until a reconciliation problem surfaces. |

### 2.2 Target State

A single `nb_run_all` notebook execution for any given period:

- Ingests all four DFMs automatically from a landing zone.
- Produces a standardised, GBP-equivalent canonical holdings dataset.
- Runs deterministic validation rules and records the results.
- Produces policy-level aggregates comparable to the Excel Rec_Output.
- Writes per-DFM reports and a reconciliation summary to OneLake.
- Records a complete audit trail for the run.

---

## 3. Azure Infrastructure Layer

### 3.1 Platform Choice: Microsoft Fabric

The PoC runs entirely within a **Microsoft Fabric** workspace. Microsoft Fabric is a unified
analytics platform that provides compute (Spark notebooks), storage (OneLake + Delta Lake), and
orchestration (Fabric Pipelines) within a single managed service. No separate Azure Data Factory,
Azure Databricks, or Azure Synapse instance is required.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Microsoft Fabric Workspace                                             │
│                                                                         │
│  ┌──────────────────────┐   ┌────────────────────────────────────────┐  │
│  │  Fabric Lakehouse    │   │  PySpark Notebooks                     │  │
│  │  (OneLake + Delta)   │   │  nb_run_all, nb_ingest_*, nb_validate  │  │
│  │                      │   │  nb_aggregate, nb_reports              │  │
│  │  /Files/landing/     │   └────────────────────────────────────────┘  │
│  │  /Files/config/      │                                               │
│  │  /Files/output/      │   ┌────────────────────────────────────────┐  │
│  │  Delta tables (7)    │   │  Optional: Fabric Pipeline wrapper      │  │
│  └──────────────────────┘   └────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Key Infrastructure Components

| Component | Service | Purpose |
|---|---|---|
| **Workspace** | Microsoft Fabric | Logical container for all artefacts; access controlled by workspace membership |
| **Lakehouse** | Fabric Lakehouse | Managed storage combining OneLake (file storage) and Delta Lake (table storage) |
| **OneLake** | OneLake (Azure Data Lake Gen 2) | Stores landing files, config, and output reports |
| **Delta Tables** | Delta Lake (via Fabric) | Seven managed tables for all canonical, aggregate, and governance data |
| **Notebooks** | Fabric PySpark Notebooks | Python + PySpark for ingestion, validation, aggregation, reporting, and AI augmentation logic |
| **Pipeline (optional)** | Fabric Pipeline | Schedules and orchestrates `nb_run_all` for periodic execution |
| **Azure OpenAI** | Azure Cognitive Services | Provides GPT-4o, GPT-4o-mini, and text-embedding-3-small for AI augmentation steps; accessed via Managed Identity (no API keys) |
| **Environment Secrets** | Fabric Environment / Key Vault reference | Stores FX feed credentials and any future API keys — never in source files |

### 3.3 OneLake Folder Structure

```
/Files/
├── landing/
│   └── period=YYYY-MM/
│       └── dfm=<dfm_id>/
│           └── source/          ← Raw DFM source files uploaded here before each run
├── config/
│   ├── dfm_registry.json        ← Which DFMs are enabled/disabled
│   ├── raw_parsing_config.json  ← Per-DFM file patterns, column mappings, numeric conventions
│   ├── rules_config.json        ← Validation rule thresholds and enable/disable flags
│   ├── currency_mapping.json    ← Currency description → ISO code mapping
│   ├── fx_rates.csv             ← FX rates for the period (GBP base); uploaded monthly
│   ├── security_master.csv      ← ISIN/SEDOL → canonical asset name lookup; uploaded monthly
│   ├── policy_mapping.csv       ← DFM policy ref → IH/Spice policy ref; uploaded monthly
│   ├── ads_config.json          ← ADS REST API base URL and batch settings; env-specific
│   └── azure_openai_config.json ← Azure OpenAI endpoint, deployment names, token/temp settings
└── output/
    └── period=YYYY-MM/
        └── run_id=<run_id>/
            ├── report1_brown_shipley.csv
            ├── report1_wh_ireland.csv
            ├── report1_pershing.csv
            ├── report1_castlebay.csv
            ├── report2_rollup.csv
            ├── reconciliation_summary.json
            └── tpir_check_result.json   ← TPIR Upload Check pass/fail result
```

### 3.4 Well-Architected: Infrastructure Design Decisions

| Decision | Rationale |
|---|---|
| Single Fabric workspace per environment | Minimises infrastructure complexity for the PoC; workspace permissions provide access control without additional IAM configuration. |
| OneLake as the only storage layer | Eliminates the need for separate Azure Blob Storage accounts; OneLake is natively integrated with Fabric notebooks and Delta Lake. |
| Delta Lake for all canonical data | Provides ACID transactions, time travel (point-in-time recovery), schema enforcement, and efficient partition pruning — all without additional infrastructure. |
| Config in `/Files/config/` not in notebooks | Separates logic from configuration; enables DFM changes via config file upload without notebook edits or redeployment. |
| No production ops in scope | Explicit PoC constraint: CI/CD pipelines, automated alerting, and retry queues are out of scope for the two-evening build. These are documented as post-PoC hardening requirements. |

---

## 4. Data Architecture

### 4.1 Delta Table Catalogue

The pipeline produces seven Delta tables. All tables live in the Fabric Lakehouse managed by
OneLake and are queryable directly from notebooks or via Fabric SQL endpoint.

| Table | Role | Partition Strategy |
|---|---|---|
| `canonical_holdings` | Normalised, GBP-equivalent, row-level holdings from all DFMs | `period`, `dfm_id` |
| `tpir_load_equivalent` | Output matching the existing downstream tpir_load column contract | None (small table) |
| `policy_aggregates` | GBP totals by DFM + policy, equivalent to Excel Rec_Output SUMIFS | `period`, `dfm_id` |
| `validation_events` | Results of every validation rule evaluation (pass, fail, not_evaluable) | `period`, `dfm_id` |
| `run_audit_log` | One row per DFM per run; files processed, row counts, status | None (small table) |
| `schema_drift_events` | Schema changes detected in DFM source files | None (small table) |
| `parse_errors` | Row-level parse failures from DFM ingestion | None |
| `ai_resolution_suggestions` | **AI** — Schema mapping proposals and fuzzy match candidates | None |
| `ai_anomaly_events` | **AI** — Portfolio-level anomaly flags per period/DFM | None |
| `ai_triage_labels` | **AI** — Per-failure classification labels | None |
| `ai_run_narratives` | **AI** — LLM-generated plain-English run summaries | None |

### 4.2 Canonical Holdings Schema

`canonical_holdings` is the central table and the single source of truth for all downstream
processing. Every row represents one holding from one DFM, normalised to GBP.

| Column | Type | Description |
|---|---|---|
| `period` | string | Reporting period in YYYY-MM format |
| `run_id` | string | Unique run identifier (UTC timestamp, e.g. `20251231T142300Z`) |
| `dfm_id` | string | DFM identifier: `brown_shipley`, `wh_ireland`, `pershing`, `castlebay` |
| `dfm_name` | string | Human-readable DFM name |
| `source_file` | string | Original filename from the landing zone |
| `source_sheet` | string | Excel sheet name (null for CSV sources) |
| `source_row_id` | string | Row identifier within the source file |
| `policy_id` | string | Policy identifier |
| `policy_id_type` | string | `IH` if mapped to internal policy, `DFM` if unmapped |
| `security_id` | string | Primary security identifier |
| `isin` | string | ISIN (if present in source) |
| `asset_name` | string | Asset or security name |
| `holding` | decimal(28,8) | Units / shares held |
| `local_bid_price` | decimal(28,8) | Bid price in local currency |
| `local_currency` | string | ISO 4217 currency code |
| `fx_rate` | decimal(28,8) | FX rate to GBP; null if already GBP |
| `cash_value_gbp` | decimal(28,8) | Cash value in GBP |
| `bid_value_gbp` | decimal(28,8) | Bid value in GBP; null if not computable |
| `accrued_interest_gbp` | decimal(28,8) | Accrued interest in GBP |
| `report_date` | date | Valuation date from source |
| `ingested_at` | timestamp | UTC timestamp when the row was written |
| `row_hash` | string | SHA-256 hash over deterministic columns; used for de-duplication |
| `data_quality_flags` | array\<string\> | List of assumption flags (e.g., `FX_NOT_AVAILABLE`) |

### 4.3 Data Relationships

Every table carries `run_id` and `dfm_id`, enabling full cross-table joins for a single run:

```
run_audit_log (run_id, dfm_id)
    ├── canonical_holdings (run_id, dfm_id)
    │       ├── tpir_load_equivalent (run_id, dfm_id)
    │       ├── policy_aggregates (run_id, dfm_id, policy_id)
    │       └── validation_events (run_id, dfm_id, policy_id)
    ├── parse_errors (run_id, dfm_id)
    └── schema_drift_events (run_id, dfm_id)
```

### 4.4 Idempotency via Row-Hash De-duplication

To ensure that re-running the same period does not produce duplicate data, every row in
`canonical_holdings` carries a deterministic `row_hash` computed over its source-identity columns:

```
row_hash = SHA-256(dfm_id + source_file + source_sheet + source_row_id +
                   policy_id + security_id + holding + local_bid_price + local_currency)
```

When writing to `canonical_holdings`, the pipeline performs a MERGE upsert matching on
`row_hash`. Existing rows are updated; new rows are inserted. A re-run of the same period
produces no additional rows.

---

## 5. Data Pipeline Design

### 5.1 Pipeline Overview

The pipeline is triggered by running the `nb_run_all` notebook with a `period` parameter
(e.g., `2025-12`). It executes the following steps in sequence:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  1. nb_run_all — Entrypoint                                             │
│     Accepts period parameter, generates run_id, loads config           │
└───────────────────────────┬─────────────────────────────────────────────┘
                            │ For each enabled DFM (from dfm_registry.json)
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  2. DFM Ingestion Notebooks (run in sequence; failures caught and       │
│     logged; pipeline continues for remaining DFMs)                      │
│                                                                         │
│     nb_ingest_brown_shipley  │  nb_ingest_wh_ireland                   │
│     nb_ingest_pershing       │  nb_ingest_castlebay                    │
│                                                                         │
│     For each DFM:                                                       │
│     a. Discover files in landing zone                                   │
│     b. Parse raw files (CSV / XLSX) per DFM config                     │
│     c. Normalise to canonical schema + GBP conversion                  │
│     d. De-duplicate via row-hash MERGE → canonical_holdings            │
│     e. Emit parse_errors, schema_drift_events, run_audit_log           │
└───────────────────────────┬─────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────────┐
│  3. nb_aggregate                                                        │
│     Reads canonical_holdings → produces policy_aggregates              │
│     and tpir_load_equivalent Delta tables                              │
└───────────────────────────┬────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────────┐
│  4. nb_validate                                                         │
│     Reads canonical_holdings + policy_aggregates                       │
│     Evaluates DATE_001, MV_001, VAL_001, MAP_001                       │
│     Writes → validation_events                                         │
└───────────────────────────┬────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────────┐
│  5. nb_reports                                                          │
│     Reads validation_events + policy_aggregates + canonical_holdings   │
│     Writes report1_<dfm>.csv, report2_rollup.csv,                     │
│     reconciliation_summary.json → /Files/output/                      │
└───────────────────────────┬────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────────┐
│  6. nb_tpir_check                                                       │
│     Reads tpir_load_equivalent for current run_id                     │
│     Evaluates 7 quality rules (TC-001 to TC-007)                      │
│     Writes tpir_check_result.json (status: passed | failed)           │
└───────────────────────────┬────────────────────────────────────────────┘
                            │  [if status = passed]
                            ▼
┌────────────────────────────────────────────────────────────────────────┐
│  7. nb_ads_load                                                         │
│     Batches tpir_load_equivalent rows → POST /api/v1/tpir/load        │
│     Polls for committed status; updates run_audit_log                 │
│     (Suppressed if TPIR check status = failed)                        │
└───────────────────────────┬────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────────┐
│  8. Finalise run_audit_log for all DFMs                                │
└───────────────────────────┬────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────────┐
│  9. nb_ai_narrative (AI — final step)                                  │
│     Collects all run outcomes into structured payload                  │
│     Calls GPT-4o → plain-English run summary                          │
│     Writes run_summary.txt and ai_run_narratives                      │
└────────────────────────────────────────────────────────────────────────┘
```

AI augmentation steps run at various points during the above sequence — see
[Section 7.6](#76-ai-augmentation-steps) for the full AI pipeline overlay.

### 5.2 DFM Source Formats and Ingestion Differences

Each DFM delivers data differently. All differences are handled within the DFM-specific ingestion
notebook and `raw_parsing_config.json`. Everything downstream of `canonical_holdings` is shared.

| DFM | Format | Key Differences |
|---|---|---|
| **Brown Shipley** | Two CSV files: Notification + Cash | European decimal notation (`3.479,29`), no explicit FX rate, separate cash file |
| **WH Ireland** | Single XLSX | UK/US decimals, FX rate column provided, no accrued interest column |
| **Pershing** | Two files: Positions CSV + Valuation XLSX | Two-file join, position-level FX rate, backfill logic where valuation data supplements positions |
| **Castlebay** | Single XLSX | Header on row 3 (not row 1), report date inferred from filename, acquisition cost field unreliable |

### 5.3 Shared Library Functions

All ingestion notebooks import a shared Python module that provides common, reusable utility
functions. This prevents duplication and ensures that fixing a bug in numeric parsing
(for example) fixes it for all four DFMs simultaneously.

| Function | Purpose |
|---|---|
| `parse_numeric(value, european=False)` | Parses numeric strings supporting both UK/US format (`13,059.70`) and European format (`3.479,29`). Mode is config-driven per DFM. |
| `parse_date(value)` | Parses dates in `dd-MMM-yyyy`, `dd/MM/yyyy`, ISO datetime, or inferred from the source filename. |
| `apply_fx(local_value, local_currency, fx_rates)` | Converts a local currency value to GBP using a five-step priority chain: (1) already GBP, (2) GBP column provided, (3) position-level FX rate, (4) `fx_rates.csv`, (5) null + flag. |
| `row_hash(df, cols)` | Computes a deterministic SHA-256 hash over specified columns for de-duplication. |
| `emit_validation_event(...)` | Writes a row to the `validation_events` Delta table. |
| `emit_audit(dfm_id, run_id, ...)` | Writes or updates a row in the `run_audit_log` Delta table. |
| `emit_parse_error(...)` | Writes a row to the `parse_errors` Delta table. |
| `emit_drift_event(...)` | Writes a row to the `schema_drift_events` Delta table. |

### 5.4 Numeric and Date Parsing

A significant source of errors in the current manual process is the difference in numeric
conventions across DFMs. The pipeline handles this explicitly:

**Numeric conventions:**
- UK/US style: `13,059.70` (comma as thousands separator, period as decimal)
- European style: `3.479,29` (period as thousands separator, comma as decimal)

Detection heuristic: if a value contains both `.` and `,`, and the `,` appears after the `.`,
the value is treated as European format. For DFMs with `european_decimals: true` in
`raw_parsing_config.json`, European parsing is always applied.

**Date formats supported:**
- `dd-MMM-yyyy` — e.g., `31-Dec-2025`
- `dd/MM/yyyy` — e.g., `31/12/2025`
- ISO datetime — e.g., `2025-12-31T00:00:00.000`
- Filename inference — when no date field exists, the date is extracted from the filename
  (e.g., `holdings_31Dec25.xlsx` → `2025-12-31`) and the `DATE_FROM_FILENAME` flag is set.

### 5.5 GBP Conversion Priority Chain

To ensure that bid values are always expressed in GBP where possible, and that any inability to
convert is surfaced explicitly rather than silently ignored, the pipeline applies a five-step
priority chain for each row:

1. **Local GBP** — if `local_currency` is already `GBP`, `fx_rate = 1.0`; no conversion needed.
2. **GBP-denominated column** — if the DFM source provides a GBP market value column, use it directly.
3. **Position-level FX rate** — if a per-row FX rate is provided in the source file, apply it.
4. **`fx_rates.csv` lookup** — join on `local_currency` and apply the period FX rate.
5. **Not available** — set `bid_value_gbp = null` and add `FX_NOT_AVAILABLE` to `data_quality_flags`.

### 5.6 Config-Driven Design Principles

The pipeline is designed so that DFM differences are isolated to configuration and DFM-specific
ingestion notebooks. Nothing downstream of `canonical_holdings` knows which DFM the data came
from:

- **`dfm_registry.json`** controls which DFMs are enabled or disabled without code changes.
- **`raw_parsing_config.json`** controls all per-DFM parsing: header rows, sheet names, column
  mappings, numeric conventions, and date formats.
- **`rules_config.json`** controls validation thresholds and which rules are active.
- **`security_master.csv`** provides the ISIN/SEDOL → asset name lookup used to enrich
  `security_id` before `MAP_001` is evaluated. Uploaded by the analyst monthly.
- **`policy_mapping.csv`** maps DFM policy references to IH/Spice policy references, enabling
  `POP_001` to flag unmapped or terminated policies. Uploaded monthly from Spice.
- **`ads_config.json`** provides the ADS REST API base URL and batch settings; environment-specific
  (staging vs production), not committed to source control.
- Adding a fifth DFM requires only a new config block and a new ingestion notebook — no changes
  to validation, aggregation, reporting, or ADS load code.

### 5.7 Fault Tolerance

A failure in one DFM ingestion notebook must never block the rest of the pipeline:

1. `nb_run_all` wraps every DFM notebook invocation in a `try/except` block.
2. On an unrecoverable exception: the traceback is logged, `run_audit_log` is written with
   `status=FAILED`, and execution continues to the next DFM.
3. `nb_validate`, `nb_aggregate`, and `nb_reports` all run regardless of how many DFMs failed —
   they simply process fewer rows.
4. If no files are found for a DFM, `run_audit_log` is written with `status=NO_FILES` and
   the pipeline continues.

---

## 6. Validation Engine

### 6.1 Overview

After ingestion, `nb_validate` evaluates a set of deterministic rules across all DFMs in a
single pass. Every rule evaluation — whether it passes, fails, or cannot be assessed — is
recorded in the `validation_events` Delta table. There are no silent outcomes.

### 6.2 Validation Rules

| Rule | Description | Severity | DFMs |
|---|---|---|---|
| **DATE_001** | Stale report date. Warns if `report_date > month_end + 5 working days` (weekend-only calendar). Emits `not_evaluable` if `report_date` is null. | Warning | All |
| **MV_001** | Market value recalculation. Computes `holding × local_bid_price × fx_rate` and compares to `bid_value_gbp`. Fails if the absolute or percentage difference exceeds configured thresholds. Details include `computed_mv`, `reported_mv`, `abs_diff`, `pct_diff`. | Exception | WH Ireland, Pershing, Castlebay (Brown Shipley if feasible) |
| **VAL_001** | Empty policy. At `policy_aggregates` level, fails if both `total_cash_value_gbp == 0` and `total_bid_value_gbp == 0`. | Exception | All |
| **MAP_001** | Unmapped security / residual cash proxy. At row level, if `security_id` is null: flags as residual cash if `bid_value_gbp < residual_cash_threshold_gbp`; raises exception if `bid_value_gbp ≥ threshold`. | Exception | All |
| **POP_001** | Policy mapping check. If `policy_mapping.csv` is present, fails if a DFM policy cannot be mapped to an internal IH/Spice policy; emits `warning` for `REMOVE`-status policies; emits `not_evaluable` if file absent. | Exception | All (enabled by default) |

### 6.3 Evaluability

A core design principle is that a rule that cannot be evaluated is **not** the same as a rule
that passes. If required fields are null, the rule emits `status = not_evaluable` with a
reason in `details_json`. This makes gaps in the data visible rather than invisible:

- Brown Shipley rows without bid price data produce `MV_001 / not_evaluable` events.
- Rows without a `report_date` produce `DATE_001 / not_evaluable` events.
- Any row where the required fields for a rule are missing is accounted for.

### 6.4 Configuration

All rule thresholds are defined in `rules_config.json` and can be changed without code
modifications:

```json
{
  "MV_001": {
    "enabled": true,
    "tolerance_abs_gbp": 1.00,
    "tolerance_pct": 0.02
  },
  "DATE_001": {
    "enabled": true,
    "staleness_days": 5
  },
  "MAP_001": {
    "enabled": true,
    "residual_cash_threshold_gbp": 1000.00
  },
  "POP_001": {
    "enabled": true
  },
  "tpir_check": {
    "TC-001": { "enabled": true },
    "TC-002": { "enabled": true },
    "TC-003": { "enabled": true },
    "TC-004": { "enabled": true },
    "TC-005": { "enabled": true },
    "TC-006": { "enabled": true },
    "TC-007": { "enabled": true }
  }
}
```

> **MV_001 tolerance note:** `tolerance_pct` is set to `0.02` (2%), matching the 98–102% operational
> check performed in the original Excel process. Earlier drafts used `0.001` (0.1%), which was
> a documentation error.
```

---

## 7. Aggregation and Reporting

### 7.1 Policy Aggregates

`nb_aggregate` reads `canonical_holdings` and computes GBP totals grouped by DFM and policy.
These totals directly replicate the Excel Rec_Output SUMIFS values:

| Aggregate | Computation |
|---|---|
| `total_cash_value_gbp` | `SUM(canonical_holdings.cash_value_gbp)` per DFM + policy |
| `total_bid_value_gbp` | `SUM(COALESCE(canonical_holdings.bid_value_gbp, 0))` per DFM + policy |
| `total_accrued_interest_gbp` | `SUM(canonical_holdings.accrued_interest_gbp)` per DFM + policy |

Null `bid_value_gbp` values are treated as zero in aggregation (consistent with the Excel
template behaviour).

### 7.2 TPIR Load Equivalent

`nb_aggregate` also produces `tpir_load_equivalent`, a Delta table that projects
`canonical_holdings` to the 13-column schema expected by the downstream TPIR load process:

| Column | Source |
|---|---|
| `Policyholder_Number` | `canonical_holdings.policy_id` |
| `Security_Code` | `canonical_holdings.security_id` |
| `ISIN` | `canonical_holdings.isin` |
| `Other_Security_ID` | `canonical_holdings.other_security_id` |
| `ID_Type` | `canonical_holdings.id_type` |
| `Asset_Name` | `canonical_holdings.asset_name` |
| `Acq_Cost_in_GBP` | null (not available from PoC sources) |
| `Cash_Value_in_GBP` | `canonical_holdings.cash_value_gbp` |
| `Bid_Value_in_GBP` | `canonical_holdings.bid_value_gbp` |
| `Accrued_Interest` | `canonical_holdings.accrued_interest_gbp` |
| `Holding` | `canonical_holdings.holding` |
| `Loc_Bid_Price` | `canonical_holdings.local_bid_price` |
| `Currency_Local` | `canonical_holdings.local_currency` |

### 7.3 Output Reports

`nb_reports` produces three output artefacts, written to
`/Files/output/period=YYYY-MM/run_id=<run_id>/`:

**Report 1 — Per-DFM Validation Summary (`report1_<dfm_id>.csv`)**  
One file per DFM. Contains validation failures grouped by `policy_id` and `rule_id`, including
MV_001 numeric differences (computed vs reported market value, absolute diff, percentage diff),
and counts of `not_evaluable` records by rule.

**Report 2 — Cross-DFM Roll-up (`report2_rollup.csv`)**  
Single roll-up file. Contains counts by DFM, rule, and severity, plus the top policies by
exception count.

**Reconciliation Summary (`reconciliation_summary.json`)**  
Machine-readable JSON containing GBP totals and row counts by DFM, for programmatic tie-out:

```json
{
  "run_id": "20251231T142300Z",
  "period": "2025-12",
  "generated_at": "2025-12-31T14:23:05Z",
  "dfm_summary": [
    {
      "dfm_id": "wh_ireland",
      "canonical_row_count": 1250,
      "total_cash_value_gbp": 0.0,
      "total_bid_value_gbp": 45231876.50,
      "total_accrued_interest_gbp": 0.0
    }
  ]
}
```

### 7.4 TPIR Upload Check

Before any data is submitted to ADS, `nb_tpir_check` evaluates the `tpir_load_equivalent` table
against seven quality rules (TC-001 through TC-007). This is the automated equivalent of the
"Run TPIR Upload Checker" step in the original Excel process.

| Rule | Check | Blocking? |
|------|-------|-----------|
| TC-001 | All 13 required columns present | Yes |
| TC-002 | At least one row in `tpir_load_equivalent` | Yes |
| TC-003 | `Policyholder_Number` non-null for all rows | Yes |
| TC-004 | `Bid_Value_in_GBP` non-null for non-cash rows | Yes |
| TC-005 | `Currency_Local` is a valid ISO-4217 code | Yes |
| TC-006 | No `REMOVE`-status policies in output | Warning only |
| TC-007 | Row count matches `canonical_holdings` | Warning only |

The result is written to `tpir_check_result.json` in the run output folder with
`status: passed` or `status: failed`. ADS loading only proceeds on `passed`.
See `specs/001-dfm-poc-ingestion/15_tpir_upload_checker.md` for the full specification.

### 7.5 ADS Loading

If the TPIR check passes, `nb_ads_load` submits the `tpir_load_equivalent` data to ADS
(Asset Data Store) via REST API (see `apps/api/openapi.yaml` for the full API contract):

1. Batches rows into `POST /api/v1/tpir/load` requests (batch size configured in `ads_config.json`).
2. Polls `GET /api/v1/tpir/load/{runId}` until ADS confirms `status: committed`.
3. Updates `run_audit_log` with `ads_load_status`, `ads_load_rows`, and `ads_load_completed_at`.

Authentication uses Azure Managed Identity bearer tokens — no credentials in notebook code.
ADS implements run-level idempotency on `run_id`, so re-running the same period is safe.
See `specs/001-dfm-poc-ingestion/16_ads_loading.md` for the full specification.

### 7.6 AI Augmentation Steps

Five AI notebooks enrich the deterministic pipeline at specific points. All are non-blocking:
a failure in an AI step never causes `nb_run_all` to raise an unrecoverable exception.
Deterministic pipeline outputs (`canonical_holdings`, `tpir_load_equivalent`, `policy_aggregates`)
are never modified by AI steps.

```
After ingestion, if schema_drift_events present:
  → nb_ai_schema_mapper: proposes raw_parsing_config.json diffs via GPT-4o
    → ai_resolution_suggestions, ai_schema_suggestions.txt

After nb_aggregate, every run:
  → nb_ai_anomaly_detector: flags DFM-level portfolio movements vs prior 3 periods
    → ai_anomaly_events, ai_anomaly_report.txt

After nb_validate, if validation failures present:
  → nb_ai_exception_triage: classifies failures as expected_design /
    expected_recurring / novel_investigate via GPT-4o-mini
    → ai_triage_labels
  → nb_ai_fuzzy_resolver: embeds unresolved MAP_001/POP_001 securities/policies;
    returns cosine top-3 candidates from security_master / policy_mapping
    → ai_resolution_suggestions, ai_fuzzy_resolutions.txt

Final step (after nb_ads_load):
  → nb_ai_narrative: generates plain-English analyst-facing run summary via GPT-4o
    → ai_run_narratives, run_summary.txt
```

**Model allocation:**
- GPT-4o: schema mapping, anomaly detection, narrative generation
- GPT-4o-mini: exception triage (classification task; cost / quality tradeoff acceptable)
- text-embedding-3-small: fuzzy resolution (no LLM call; embeddings + cosine similarity only)

For full specifications see `specs/001-dfm-poc-ingestion/17_ai_schema_mapping.md` through
`21_ai_narrative.md`.

---

## 8. Governance and Audit

### 8.1 Run Audit Log

Every run produces one audit row per DFM in the `run_audit_log` Delta table. This row is
written at the start of each DFM ingestion notebook and updated (with `completed_at` and final
counts) when the notebook completes or fails. `nb_run_all` makes a final update when the full
run completes.

| Status | Meaning |
|---|---|
| `OK` | All files processed; no parse errors |
| `NO_FILES` | No source files found in the landing zone for this DFM and period |
| `PARTIAL` | At least one file processed; at least one parse error occurred |
| `FAILED` | The DFM notebook raised an unrecoverable exception |

Three additional columns track the downstream ADS load outcome (nullable on pre-Phase-8 rows):

| Column | Type | Values |
|--------|------|--------|
| `ads_load_status` | string | `committed`, `failed`, `skipped_tpir_check_failed`, `skipped_no_rows` |
| `ads_load_rows` | long | Number of rows accepted by ADS |
| `ads_load_completed_at` | timestamp | When ADS confirmed commitment |

### 8.2 Parse Errors

Every source row that fails to parse (bad numeric format, invalid date, missing required field)
is written to `parse_errors` with:
- The source file and row identifier (for traceability back to the original file).
- The error message explaining what went wrong.
- The raw cell value that caused the failure.

Parse errors do not stop the pipeline; the failing row is excluded from `canonical_holdings` and
processing continues.

### 8.3 Schema Drift Events

When a DFM source file contains unexpected or missing columns compared to the expected schema,
a row is written to `schema_drift_events` capturing:
- Which file changed.
- Which column changed.
- The type of change (`missing_column`, `unexpected_column`, `type_change`).

Schema drift does not cause an unrecoverable failure; ingestion continues with the available
columns. Drift events are surfaced in the run audit for analyst review.

### 8.4 Data Lineage

Full data lineage is provided by the combination of `run_id` and `dfm_id` on every row in
every table. For any row in any table, it is possible to trace back to:
- Which run produced it (`run_id`).
- Which DFM it came from (`dfm_id`).
- Which source file it came from (`source_file`).
- Which row in that file it came from (`source_row_id`).

Delta time travel provides additional point-in-time recovery for all tables.

---

## 9. Non-Functional Characteristics (Azure Well-Architected)

The design aligns to the five pillars of the Azure Well-Architected Framework, adapted to the
PoC scope and constraints.

### 9.1 Reliability

**Fault isolation:** A failure in any single DFM notebook is caught and logged; all other DFMs
and downstream steps continue. There is no single point of failure in the ingestion layer.

**Idempotency:** Row-hash de-duplication on `canonical_holdings` ensures that re-running the
same period is always safe. No data is duplicated; no manual cleanup is required before a re-run.

**State management:** Each run is fully versioned by `run_id`. Delta time travel allows recovery
to any previous run state. No reset macros or manual state clearing is required.

**Error transparency:** There are no silent failures. Every DFM has an audit row; every failed
row has a parse error record; every schema change has a drift event.

### 9.2 Security

See [Section 10](#10-security-baseline) for the full security baseline. Key points:

- No credentials in source files or config files.
- Access to all data is governed by Fabric workspace membership.
- Client portfolio data stays within the Fabric workspace (OneLake).
- All AI-generated code touching finance calculations is reviewed by a human.
- Audit tables are append-only and provide a complete data lineage trail.

### 9.3 Cost Optimisation

**PoC scope:** The PoC uses a single Fabric workspace with standard notebook compute. There are
no dedicated clusters, premium SKUs, or real-time streaming components.

**Partition pruning:** `canonical_holdings` and `validation_events` are partitioned by `period`
and `dfm_id`. Queries for a specific run only scan the relevant partitions.

**Delta Lake efficiency:** Delta Lake's columnar Parquet storage and Z-ordering (where applied)
reduce the data scanned per query, keeping notebook execution costs proportional to the volume
of data processed.

**No over-engineering:** The PoC deliberately avoids expensive infrastructure (dedicated
Spark clusters, Azure Data Factory, Azure Event Hubs) that would not be justified for a
monthly batch process at this data volume.

### 9.4 Operational Excellence

**Config-driven operation:** Adding or disabling a DFM, adjusting a validation threshold, or
changing a column mapping requires only a config file edit — no code deployment.

**Single entrypoint:** `nb_run_all` is the only notebook that needs to be run by an analyst.
All orchestration is encapsulated behind this single interface.

**Observability:** Every run produces a queryable audit trail (`run_audit_log`), a
machine-readable reconciliation summary, and CSV reports. Analysts can verify a run without
querying Delta tables directly.

**Reproducibility:** Any past period can be re-run by supplying the same landing zone files.
The output (excluding `run_id` and `ingested_at`) will always be identical.

### 9.5 Performance Efficiency

**Target:** A full four-DFM run for one period must complete within 30 minutes on standard
Fabric notebook compute.

**Partition pruning:** Period-and-DFM-level partitioning means each DFM notebook only reads
and writes its own partition, avoiding full table scans.

**MERGE upsert:** Delta Lake MERGE on `row_hash` is efficient for the expected PoC data volumes
(thousands to low tens of thousands of rows per DFM per period).

**No unnecessary full scans:** `nb_validate`, `nb_aggregate`, and `nb_reports` use `period`
filter predicates to limit reads to the current run's data only.

---

## 10. Security Baseline

### 10.1 Scope

This baseline applies to the PoC running in a single Fabric workspace. Production security
hardening is explicitly deferred. Known gaps are documented in [Section 10.5](#105-known-gaps).

### 10.2 Security Controls

| Control | Implementation |
|---|---|
| **No credentials in source control** | Config files (`dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`) contain structural config only — no API keys, passwords, or connection strings. FX feed credentials are managed via Fabric environment secrets or Key Vault references. |
| **Workspace access control** | Access to the Fabric workspace, OneLake, and Delta tables is governed by existing Fabric workspace membership. Only authorised team members can read source files or query tables. |
| **Client data handling** | Source DFM files (which contain client portfolio data) are stored only in the OneLake landing zone. They must not be downloaded to personal devices or shared externally. |
| **Audit trail as data lineage** | `run_audit_log`, `parse_errors`, and `schema_drift_events` are append-only tables providing a complete record of every run. These must be retained and not truncated. |
| **AI code review** | All AI-generated code touching finance calculations (GBP conversion, MV recalculation, policy aggregation) must be reviewed by a human before execution against real client data. |

### 10.3 Data Classification

| Data | Classification | Handling |
|---|---|---|
| Client portfolio positions and valuations | Confidential | Stored in OneLake only; access via workspace membership; not downloaded to personal devices |
| Policy identifiers | Pseudonymised | Treated as confidential; not mapped to client names in PoC outputs |
| Aggregated GBP totals | Confidential | Written to output CSVs and JSON; access via workspace membership |
| Config and thresholds | Internal | May be committed to source control; must not include client data or credentials |

### 10.4 Compliance Notes

| Area | Note |
|---|---|
| **GDPR / Data Privacy** | Portfolio data is pseudonymised by policy number. Policy numbers must not be mapped to client names in PoC outputs. |
| **Data Retention** | Source files and Delta tables must follow the firm's data retention policy. The PoC does not implement automated retention. |
| **Audit Obligations** | `run_audit_log` and `parse_errors` provide a record of data transformation. These should be retained for the period required by the firm's audit policy. |
| **Regulatory Reporting** | `tpir_load_equivalent` and `policy_aggregates` are inputs to regulatory reporting workflows. Any discrepancy between PoC outputs and Excel outputs must be investigated before the PoC is used to inform reporting. |

### 10.5 Known Gaps (Post-PoC Hardening Required)

The following gaps must be addressed before any production deployment:

1. **Authentication:** Notebooks use Fabric workspace identity. Production should implement explicit service principal authentication with minimum-privilege permissions.
2. **Row-level security:** `canonical_holdings` and `policy_aggregates` contain data for multiple DFMs. Production should implement row-level security by DFM and policy ownership.
3. **Secret management:** FX rates and future API connections should use Fabric Key Vault integration with automated secret rotation.
4. **Network isolation:** Production should use private endpoints for OneLake access, preventing public internet exposure.
5. **Penetration testing:** A formal security assessment should be conducted before production use.
6. **Automated scanning:** SAST and dependency scanning should be added to any CI/CD pipeline that builds shared library code.

---

## 11. Development Best Practices

### 11.1 Finance Calculation Determinism

All monetary arithmetic uses `Decimal` (Python) or `DecimalType(28, 8)` (PySpark) rather than
floating-point. This prevents accumulation errors in GBP conversion, MV recalculation, and
policy aggregation. No random elements, shuffles, or timestamp-based seeds are permitted in
finance calculations.

**AI assistance boundary:** GitHub Copilot is permitted for boilerplate generation, schema
creation, logging, and config loading. It is not permitted for financial arithmetic, FX rate
inference, or any logic that silently corrects data without surfacing the correction as a flag.

### 11.2 Configuration over Code

DFM-specific logic (column names, file patterns, numeric conventions, date formats) lives only
in `raw_parsing_config.json` and the DFM-specific ingestion notebook. Downstream shared
notebooks (`nb_validate`, `nb_aggregate`, `nb_reports`) contain no DFM-specific strings or
branches. This rule is enforceable by grepping shared notebooks for DFM identifiers.

### 11.3 Data Quality Transparency

Every field-level assumption made during normalisation is recorded in `data_quality_flags` on
the canonical row. Analysts can inspect flags to understand why a value is null or defaulted
without reading the pipeline code.

| Flag | Trigger |
|---|---|
| `CURRENCY_ASSUMED_GBP` | Currency field absent; GBP assumed |
| `FX_NOT_AVAILABLE` | FX rate could not be determined; `bid_value_gbp` is null |
| `PRICE_ABSENT` | Bid price field absent or null |
| `DATE_FROM_FILENAME` | `report_date` inferred from the source filename |
| `DATE_MISSING` | `report_date` absent and could not be inferred |
| `ACQ_COST_UNPARSEABLE` | Acquisition cost field could not be parsed |
| `CASH_DEFAULTED` | Cash value defaulted to 0 |
| `ACCRUED_DEFAULTED` | Accrued interest defaulted to 0 |

### 11.4 Validation Rule Design

Validation rules follow three principles:

1. **Evaluability is first-class.** A rule that cannot be evaluated emits `not_evaluable` —
   not a pass and not a fail. This makes data gaps visible.
2. **Config-driven thresholds.** Tolerances and staleness windows are in `rules_config.json`,
   not in notebook code. Rules can be individually enabled or disabled.
3. **Deterministic outcomes.** Given the same `canonical_holdings` rows and `rules_config.json`,
   the same `validation_events` rows are always produced.

### 11.5 Notebook Structuring Conventions

- Each notebook has a single, clearly defined responsibility.
- Notebooks do not call each other directly except via `nb_run_all`.
- Shared utilities live in the shared Python library, not copied between notebooks.
- Notebook parameters (`period`, `run_id`) are passed by `nb_run_all` — no notebook generates
  its own `run_id`.
- All reads and writes use the `period` and `dfm_id` partition columns to limit data scanned.

### 11.6 Source Control and Review

- Config files committed to source control must not contain credentials (see [Section 10.2](#102-security-controls)).
- All AI-generated code touching finance calculations must be reviewed in a pull request before
  running against real client data.
- Change review sign-off must be recorded in the pull request or notebook comment.

---

## 12. Copilot Studio Integration

### 12.1 Vision

Microsoft Copilot Studio enables the creation of conversational AI agents that can be connected
to data sources and exposed to business users via Microsoft Teams, SharePoint, or web chat. Once
the DFM pipeline is producing structured, queryable Delta tables and JSON/CSV output, Copilot
Studio can provide a natural-language interface to those results — removing the need for analysts
or stakeholders to write SQL or open notebooks to get answers.

### 12.2 What Copilot Studio Can Answer

The reconciliation outputs produced by the pipeline are well-suited to conversational query.
Typical questions an agent could answer:

| Question | Data Source |
|---|---|
| "What were the total bid values for WH Ireland in December 2025?" | `policy_aggregates` |
| "Were there any MV_001 exceptions for Pershing last month?" | `validation_events` |
| "How many rows were ingested for Castlebay in the last run?" | `run_audit_log` |
| "Show me the reconciliation summary for period 2025-12." | `reconciliation_summary.json` |
| "Which policies had validation exceptions this month?" | `validation_events` joined to `policy_aggregates` |
| "Did any DFMs fail to process in the last run?" | `run_audit_log` (status = FAILED or NO_FILES) |

### 12.3 Proposed Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DFM PoC Pipeline (Microsoft Fabric)                                    │
│                                                                         │
│  Delta Tables: canonical_holdings, policy_aggregates, validation_events │
│  Output Files: reconciliation_summary.json, report1_*, report2_rollup  │
│  Audit: run_audit_log                                                   │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │ Fabric SQL Endpoint / Power BI dataset
                               │ (or SharePoint connector for CSV/JSON)
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Microsoft Copilot Studio Agent                                         │
│                                                                         │
│  Topics:                                                                │
│  - "Show reconciliation summary"                                        │
│  - "Run status for [period]"                                            │
│  - "Validation exceptions for [DFM]"                                   │
│  - "Policy aggregate totals for [period] [DFM]"                        │
│                                                                         │
│  Data connectors:                                                       │
│  - Fabric SQL Endpoint (for Delta table queries)                        │
│  - SharePoint / OneDrive (for CSV/JSON report files)                   │
│  - Power Automate flow (to trigger nb_run_all for a new period)        │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │ Published to
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Microsoft Teams or SharePoint                                          │
│  (Investment Operations team channel)                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 12.4 Implementation Approach

**Phase 1 (PoC + 1 sprint): Data Connectivity**

1. Publish the Fabric Lakehouse `policy_aggregates` and `validation_events` tables via the
   Fabric SQL Analytics Endpoint.
2. Create a Power BI semantic model over the key reconciliation tables.
3. Configure the Copilot Studio agent to use Power BI as a knowledge source for structured queries.

**Phase 2: Conversational Topics**

Design Copilot Studio topics for the most common analyst queries:
- Run status check: "What happened in the last run for [period]?"
- Exception report: "Any MV exceptions for [DFM] in [period]?"
- Totals query: "What are the bid value totals for [DFM] in [period]?"

**Phase 3: Trigger Integration**

Connect a Power Automate flow to Copilot Studio so that analysts can trigger a new pipeline
run from the agent: "Run the DFM pipeline for 2026-01" → Power Automate calls the Fabric
REST API to execute `nb_run_all`.

### 12.5 Guardrails and Constraints

- Copilot Studio agents must **not** have write access to Delta tables. The agent is read-only
  (with the exception of the Power Automate trigger to start a run).
- All access to the Fabric SQL Endpoint and OneLake files must use service principal credentials
  managed via Azure Key Vault — not user credentials embedded in connectors.
- The agent must be published only within the organisation's Microsoft 365 tenant; it must not be
  accessible to external parties.
- Any generative AI summaries produced by Copilot Studio from reconciliation data must be
  reviewed before being shared with stakeholders outside the investment operations team.
- Finance calculations must remain in the pipeline; Copilot Studio presents results only — it
  does not recompute or interpret financial data.

---

## 13. Delivery Roadmap

### 13.1 PoC Phases

| Phase | Deliverable | Timing |
|---|---|---|
| **Phase 1 — Foundation** | Fabric Lakehouse, all seven Delta tables, config files, `nb_run_all` skeleton, shared Python library | Evening 1, first half (~1.5 h) |
| **Phase 2 — DFM Ingestion** | Four DFM ingestion notebooks, `canonical_holdings` population, governance tables | Evening 1–2 (~3.0 h) |
| **Phase 3 — Validation** | `nb_validate`, all four rules, `validation_events` | Evening 2, early (~1.0 h) |
| **Phase 4 — Aggregation & Outputs** | `nb_aggregate`, `nb_reports`, all output files | Evening 2, mid-late (~1.5 h) |
| **PoC Complete** | Full acceptance checklist (SC-01 to SC-10) passed | End of Evening 2 (~7 h total) |
| **Phase 8 — Reference Data, Quality Gate & ADS Load** | `security_master.csv` enrichment, POP_001 enabled, `nb_tpir_check`, `nb_ads_load`, extended E2E test (SC-11, SC-12) | Post-PoC sprint (~1 day) |
| **Phase 9 — AI Augmentation** | Azure OpenAI provisioning (`infra/bicep/azure-openai.bicep`), `shared_ai_utils.py`, five AI notebooks, four AI Delta tables, Copilot Studio agent (SC-13 to SC-17) | Post-PoC sprint (~2 days) |

### 13.2 Post-PoC Production Path

The PoC is designed to be a foundation for production. The key steps to move from PoC to
production readiness are:

1. **Security hardening** — service principal authentication, row-level security, private
   endpoints, penetration testing (see [Section 10.5](#105-known-gaps)).
2. **CI/CD pipeline** — automated notebook deployment, config validation, and regression testing
   on a representative sample dataset.
3. **Monitoring and alerting** — Fabric alerting on `run_audit_log` status; notifications to
   the investment operations team on run completion or failure.
4. **Scheduling** — Fabric Pipeline to schedule `nb_run_all` automatically on data availability
   or at a fixed monthly cadence.
5. **Copilot Studio integration** — Phase 1 data connectivity and topic design (see
   [Section 12.4](#124-implementation-approach)).
6. **Additional DFMs** — adding new DFMs via config block + ingestion notebook, with no
   changes to shared pipeline logic.
7. **Acquisition cost** — once source data quality is confirmed, `Acq_Cost_in_GBP` can be
   populated in `tpir_load_equivalent`.
8. **Bank holiday calendars** — replace the weekend-only `DATE_001` logic with a full working-day
   calendar once a calendar data source is available.

### 13.3 PoC Acceptance Checklist

| # | Criterion |
|---|---|
| SC-01 | `nb_run_all` completes for one period without unrecoverable errors |
| SC-02 | `canonical_holdings` contains row-level data for all four DFMs |
| SC-03 | `tpir_load_equivalent` schema matches the existing tpir_load contract |
| SC-04 | `policy_aggregates` totals are comparable to Excel Rec_Output for all four DFMs |
| SC-05 | `MV_001` is evaluable for WH Ireland, Pershing, and Castlebay |
| SC-06 | `report1_<dfm_id>.csv` exists for all four DFMs in the output folder |
| SC-07 | `report2_rollup.csv` and `reconciliation_summary.json` exist in the output folder |
| SC-08 | `run_audit_log` has one row per DFM with correct status and row counts |
| SC-09 | Re-running the same period does not duplicate `canonical_holdings` rows |
| SC-10 | Disabling one DFM in `dfm_registry.json` does not break the run for other DFMs |
| SC-11 | `tpir_check_result.json` shows `status: passed` at the end of a successful run |
| SC-12 | `run_audit_log` shows `ads_load_status = committed` and non-zero `ads_load_rows` after a successful run |
| SC-13 | `ai_resolution_suggestions` contains at least one candidate row for each MAP_001 failure in a test run with a known unmapped security |
| SC-14 | `ai_anomaly_events` flags a seeded 40% DFM-level portfolio decrease as `severity = high` |
| SC-15 | `ai_triage_labels` classifies Brown Shipley `MV_001 not_evaluable` failures as `expected_design` |
| SC-16 | `run_summary.txt` is non-empty and correctly references the period, run_id, and DFM count |
| SC-17 | Copilot Studio agent returns the correct GBP total when asked about the previous month's WH Ireland totals |

---

## 14. Glossary

| Term | Meaning |
|---|---|
| **Canonical holdings** | The normalised, GBP-equivalent, row-level holdings table that is the single source of truth for all downstream processing. |
| **DFM** | Discretionary Fund Manager. The four DFMs in scope are Brown Shipley, WH Ireland, Pershing, and Castlebay. |
| **Delta Lake** | An open-source storage layer that provides ACID transactions, time travel, and schema enforcement on top of Parquet files. Used by Microsoft Fabric Lakehouse. |
| **Fabric Lakehouse** | A Microsoft Fabric component that combines OneLake (file storage) with Delta Lake (table storage) in a single managed service. |
| **IH policy** | An internal (In-House) policy identifier used by the downstream tpir_load process. Some DFMs use their own policy identifiers that require mapping to IH format. |
| **MV_001** | The market value recalculation validation rule: `computed_mv = holding × local_bid_price × fx_rate` compared to `bid_value_gbp`. |
| **OneLake** | Microsoft's unified data lake storage layer, built on Azure Data Lake Storage Gen 2. All files and tables in a Fabric workspace are stored in OneLake. |
| **Period** | A reporting month in YYYY-MM format (e.g., `2025-12`). One pipeline run corresponds to one period. |
| **Rec_Output** | The Excel reconciliation output sheet that the PoC aims to replicate. It uses SUMIFS to aggregate cash, bid, and accrued values by DFM and policy. |
| **Row hash** | A deterministic SHA-256 hash computed over the source-identity columns of a canonical holdings row. Used for de-duplication via MERGE upsert. |
| **Run ID** | A unique UTC timestamp identifier for each pipeline run (e.g., `20251231T142300Z`). Every row in every table carries the `run_id` of the run that produced it. |
| **ADS** | Asset Data Store. The downstream system that receives and persists the `tpir_load_equivalent` dataset each period via REST API. ADS implements run-level idempotency on `run_id`. |
| **ai_anomaly_events** | Delta table storing portfolio-level anomaly flags generated by `nb_ai_anomaly_detector`. Each row records a DFM-level movement flag with severity and plain-English reasoning. |
| **ai_resolution_suggestions** | Delta table storing schema mapping proposals (from `nb_ai_schema_mapper`) and fuzzy match candidates (from `nb_ai_fuzzy_resolver`). Analyst-reviewed; never auto-applied. |
| **ai_run_narratives** | Delta table storing LLM-generated plain-English run summaries produced by `nb_ai_narrative`. One row per run. |
| **ai_triage_labels** | Delta table storing per-failure classification labels (`expected_design`, `expected_recurring`, `novel_investigate`) produced by `nb_ai_exception_triage`. |
| **Azure OpenAI** | Microsoft Azure's managed service for OpenAI models. Provides GPT-4o, GPT-4o-mini, and text-embedding-3-small deployments accessed via Azure Managed Identity. |
| **policy_mapping.csv** | Config file mapping DFM-originated policy references to canonical IH/Spice policy identifiers. Required by `POP_001`. Uploaded monthly before each run. |
| **security_master.csv** | Config file providing ISIN/SEDOL → asset name/class enrichment. Used to populate `security_id` and `asset_name` before `MAP_001` is evaluated. Upstream source is the ISIN Master List workbook. |
| **tpir_load** | The downstream data load process that consumes standardised holdings data. The PoC produces `tpir_load_equivalent`, a Delta table matching the tpir_load column contract. |
| **TPIR Upload Checker** | A seven-rule quality gate (`nb_tpir_check`) that validates `tpir_load_equivalent` before it is submitted to ADS. An automated equivalent of the manual TPIR Upload Checker tool in the original Excel process. Results are written to `tpir_check_result.json`. |
| **Validation event** | A row in the `validation_events` table recording the outcome of one rule evaluation for one row or policy: `fail`, `not_evaluable`, or (implicitly) pass if no row is emitted. |
| **Well-Architected Framework** | Microsoft Azure's framework of best practices across five pillars: Reliability, Security, Cost Optimisation, Operational Excellence, and Performance Efficiency. |
