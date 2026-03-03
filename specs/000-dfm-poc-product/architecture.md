# Architecture: DFM Ingestion and Standardisation Platform

> **Scope:** System boundaries, stage model, and design principles for a multi-DFM ingestion product.

## Logical Pipeline (Three Stages)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Stage 1: source DFM raw files                                          │
│ /Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/*                    │
│ Persist all files/rows with provenance and parse diagnostics            │
└───────────────────────────┬─────────────────────────────────────────────┘
                            │ adapter profile execution
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Stage 2: individual_dfm_consolidated                                   │
│ Profile-driven standardisation to canonical contract                    │
│ Identifier selection, policy mapping, currency normalisation,           │
│ include/remove decisions, row-level controls                            │
└───────────────────────────┬─────────────────────────────────────────────┘
                            │ stage gate (dq_results)
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Stage 3: aggregated_dfms_consolidated                                  │
│ Gate-passing union across DFMs + cross-DFM controls                    │
│ Downstream projections: policy_aggregates, tpir_load_equivalent        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Implementation Target (PoC)

| Component | Technology | Notes |
|---|---|---|
| Compute | Microsoft Fabric — PySpark Notebooks | One Fabric workspace per environment |
| Storage | Microsoft Fabric — Lakehouse (OneLake + Delta Lake) | Delta tables for all canonical data |
| Orchestration | `nb_run_all` notebook with `period` parameter | Optional Fabric Pipeline wrapper |
| Config | JSON files in `/Files/config/` | No secrets in config; Fabric environment secrets for credentials |
| Output | CSV + JSON files in `/Files/output/period=YYYY-MM/run_id=<run_id>/` | Written by `nb_reports` |
| Shared library | Python module imported by all DFM notebooks | Common parsing, FX, hashing, audit functions |

## Notebook Structure

| Notebook | Purpose | Inputs | Outputs |
|---|---|---|---|
| `nb_run_all` | Entrypoint; accepts `period` param; generates `run_id`; invokes DFM notebooks in sequence | `period`, config files | `run_id`, invokes child notebooks |
| `nb_ingest_brown_shipley` | Stage 1 + Stage 2 adapter execution for Brown Shipley profile(s) | Landing files, `raw_parsing_config.json` | `source_dfm_raw`, `individual_dfm_consolidated`, governance tables |
| `nb_ingest_wh_ireland` | Stage 1 + Stage 2 adapter execution for WH Ireland profile(s) | Landing files, `raw_parsing_config.json` | Same as above |
| `nb_ingest_pershing` | Stage 1 + Stage 2 adapter execution for Pershing profile(s) | Landing files, `raw_parsing_config.json` | Same as above |
| `nb_ingest_castlebay` | Stage 1 + Stage 2 adapter execution for Castlebay profile(s) | Landing files, `raw_parsing_config.json` | Same as above |
| `nb_validate` | Stage-gate rules engine | `individual_dfm_consolidated`, `rules_config.json` | `dq_results`, `dq_exception_rows` |
| `nb_aggregate` | Stage 3 consolidation and output projection | Stage 2 rows passing gate | `aggregated_dfms_consolidated`, `policy_aggregates`, `tpir_load_equivalent` |
| `nb_reports` | Report generation | `validation_events`, `policy_aggregates`, `canonical_holdings`, `run_audit_log` | `report1_<dfm_id>.csv`, `report2_rollup.csv`, `reconciliation_summary.json` |

## Shared Library Functions

All DFM notebooks import a shared Python module providing the following utilities:

| Function | Signature | Purpose |
|---|---|---|
| `parse_numeric` | `(value, european=False) → Decimal` | Parse numeric strings with UK/US (13,059.70) or European (3.479,29) decimal conventions |
| `parse_date` | `(value) → date` | Parse dates in dd-MMM-yyyy, dd/MM/yyyy, ISO datetime, or infer from filename |
| `apply_fx` | `(local_value, local_currency, fx_rates) → Decimal` | Convert local currency value to GBP using FX rate lookup |
| `row_hash` | `(df, cols) → df` | Compute deterministic SHA-256 row hash over specified columns for de-duplication |
| `emit_validation_event` | `(period, run_id, dfm_id, ...) → None` | Write a row to `validation_events` Delta table |
| `emit_audit` | `(dfm_id, run_id, ...) → None` | Write/update a row in `run_audit_log` Delta table |
| `emit_parse_error` | `(run_id, dfm_id, source_file, ...) → None` | Write a row to `parse_errors` Delta table |
| `emit_drift_event` | `(run_id, dfm_id, source_file, ...) → None` | Write a row to `schema_drift_events` Delta table |

## Folder Structure (OneLake)

```
/Files/
├── landing/
│   └── period=YYYY-MM/
│       └── dfm=<dfm_id>/
│           └── source/          ← Raw DFM source files drop here
├── config/
│   ├── dfm_registry.json        ← DFM identifiers and enabled/disabled flags
│   ├── raw_parsing_config.json  ← Per-DFM file discovery and column mapping config
│   ├── rules_config.json        ← Validation rule thresholds and enable/disable flags
│   ├── currency_mapping.json    ← Currency description → ISO code mapping
│   └── fx_rates.csv            ← FX rates for the period (GBP base)
└── output/
    └── period=YYYY-MM/
        └── run_id=<run_id>/
            ├── report1_brown_shipley.csv
            ├── report1_wh_ireland.csv
            ├── report1_pershing.csv
            ├── report1_castlebay.csv
            ├── report2_rollup.csv
            └── reconciliation_summary.json
```

## Delta Table Locations (Lakehouse)

All Delta tables live in the Fabric Lakehouse managed by OneLake:

- `source_dfm_raw`
- `individual_dfm_consolidated`
- `aggregated_dfms_consolidated`
- `tpir_load_equivalent`
- `policy_aggregates`
- `dq_results`
- `dq_exception_rows`
- `run_audit_log`
- `schema_drift_events`
- `parse_errors`

## Run Orchestration

`nb_run_all` accepts a `period` parameter (YYYY-MM format) and generates a `run_id` as a UTC
timestamp (e.g., `20251231T142300Z`). Execution order:

1. Load config (`dfm_registry.json`, `rules_config.json`, etc.)
2. For each enabled DFM in `dfm_registry.json`:
   - Invoke DFM-specific ingestion notebook, passing `period` and `run_id`
   - Catch and log failures; continue to next DFM
3. Invoke `nb_validate` (runs across all DFMs in one pass)
4. Invoke `nb_aggregate`
5. Invoke `nb_reports`
6. Finalise `run_audit_log` for all DFMs

## Design Principles

### 1. Adapter Profiles, Not Bespoke Pipelines
DFM and file-type differences are encoded in adapter profile metadata. Core stage logic stays shared.
Adding a new DFM should require profile and mapping updates, not notebook logic forks.

### 2. Fault-Tolerant Execution
If one DFM notebook raises an unrecoverable exception, `nb_run_all` catches it, logs it to
`run_audit_log` with `status=FAILED`, and continues with the next DFM. A single DFM failure never
blocks the rest of the pipeline.

### 3. Deterministic Finance Calculations
All numeric operations (GBP conversion, MV recalculation, policy aggregation) use deterministic
arithmetic. AI assistance is limited to drift detection, schema narrative, and boilerplate only.

### 4. Stage-Gated Publication
Stage 3 publication is driven by gate outcomes. Failing rows are preserved with context but do not
enter consolidated output.

### 5. Full Observability
Every run produces `run_audit_log` (one row per DFM), `parse_errors` (one row per failed row),
and `schema_drift_events` (one row per detected schema change). There is always a traceable record
of what happened.

### 6. Config-Driven Validation and Thresholds
Validation thresholds and enablement are parameterised in config. Rule packs are reusable across DFMs.

### 7. Compatibility During Migration
Physical table names may temporarily differ from logical stage names during notebook transition. Specs
remain authoritative for logical contracts.

---

## See Also

- [data-model.md](data-model.md) — Stage contracts and entity definitions
- [product-vision.md](product-vision.md) — Problem space and target outcomes
- [high-level-requirements.md](high-level-requirements.md) — Functional and NFR
- [security-baseline.md](security-baseline.md) — Security requirements and controls
- [specs/001-dfm-poc-ingestion/01_architecture.md](../001-dfm-poc-ingestion/01_architecture.md) — Feature-level architecture detail
