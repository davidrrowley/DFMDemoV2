# Architecture

## Overview

The DFM PoC is a serverless, batch-oriented data pipeline running entirely on Microsoft Fabric. It ingests monthly holdings files from four Discretionary Fund Managers, normalises them to a canonical GBP-denominated schema, applies a suite of validation rules, projects the result to the `tpir_load` contract schema, runs a pre-load quality check, and submits the data to the downstream Asset Data Store (ADS) via REST API.

The pipeline replaces a manual Excel-based process and preserves the existing tpir_load contract exactly so that ADS is unaffected.

For data flow diagrams see [data_flows.md](../../data_flows.md).

---

## Context and scope

- **Four DFMs in scope**: Brown Shipley, WH Ireland, Pershing, Castlebay
- **One period per run** (`YYYY-MM`); multi-period backfill is out of scope
- **Platform**: Microsoft Fabric (PySpark notebooks, Delta Lake, OneLake)
- **Output contract**: 13-column `tpir_load_equivalent` schema (unchanged from existing tpir_load)
- **Downstream**: ADS (Asset Data Store) via REST API
- See [constraints.md](../../constraints.md) for a full list of constraints

---

## Components

### Storage zones (OneLake)

| Zone | Path | Purpose |
|------|------|---------|
| Landing zone | `/Files/landing/period=YYYY-MM/dfm=<id>/source/` | Raw DFM source files (untrusted) |
| Config zone | `/Files/config/` | Analyst-uploaded reference data and pipeline config |
| Output zone | `/Files/output/period=YYYY-MM/run_id=<run_id>/` | Reports, TPIR check result, reconciliation summary |
| Delta tables | Fabric Lakehouse (managed) | All persistent pipeline state |

### Notebooks

| Notebook | Responsibility |
|----------|---------------|
| `nb_setup` | Creates Delta tables and validates config on first run |
| `nb_run_all` | Orchestrator: sets period/run_id, loops over DFMs, invokes all downstream notebooks, updates audit log |
| `nb_ingest_brown_shipley` | Ingest and normalise Brown Shipley CSV files |
| `nb_ingest_wh_ireland` | Ingest and normalise WH Ireland XLSX |
| `nb_ingest_pershing` | Ingest and normalise Pershing CSV + XLSX with dedup |
| `nb_ingest_castlebay` | Ingest and normalise Castlebay XLSX (two sheets, filename date) |
| `nb_validate` | Evaluate MV_001, DATE_001, VAL_001, MAP_001, POP_001 rules |
| `nb_aggregate` | Compute policy_aggregates and project tpir_load_equivalent |
| `nb_reports` | Write Report 1 CSVs, Report 2 roll-up, reconciliation_summary.json |
| `nb_tpir_check` | Run TPIR Upload Check (TC-001 through TC-007); write tpir_check_result.json |
| `nb_ads_load` | Submit tpir_load_equivalent to ADS REST API; update run_audit_log |

### Shared library

`shared_utils.py` — eight shared functions used across all DFM notebooks: `parse_numeric`, `parse_date`, `apply_fx`, `row_hash`, `emit_audit`, `emit_parse_error`, `emit_drift_event`, `emit_validation_event`.

### Delta tables (seven)

| Table | Description |
|-------|-------------|
| `canonical_holdings` | Normalised, GBP-equivalised, row-level holdings; partitioned by period and dfm_id |
| `tpir_load_equivalent` | 13-column projection matching the existing tpir_load contract |
| `policy_aggregates` | GBP totals per (period, run_id, dfm_id, policy_id) |
| `validation_events` | All rule evaluation results (fail, not_evaluable) |
| `run_audit_log` | One row per DFM per run; files processed, rows ingested, ADS load status |
| `parse_errors` | Row-level field parsing failures |
| `schema_drift_events` | Source file schema changes (missing/unexpected columns) |

### Config files (`/Files/config/`)

| File | Purpose | Updated |
|------|---------|--------|
| `dfm_registry.json` | DFM IDs and enabled flags | On DFM onboarding |
| `raw_parsing_config.json` | Per-DFM file parsing rules | On DFM onboarding |
| `rules_config.json` | Validation rule thresholds and enable/disable flags | When thresholds change |
| `currency_mapping.json` | Currency description → ISO code (Castlebay) | Rarely |
| `fx_rates.csv` | Monthly FX spot rates | Every period |
| `security_master.csv` | ISIN/SEDOL → asset name lookup | Every period (when new securities appear) |
| `policy_mapping.csv` | DFM policy ref → IH policy ref mapping | Every period (when new/changed policies appear) |
| `ads_config.json` | ADS REST API base URL and batch settings | On environment change |

---

## Data flows

See [data_flows.md](../../data_flows.md) for the four core flows and trust boundary diagram.

Key trust boundaries:
- **Landing zone**: untrusted (externally sourced from DFMs)
- **Config zone**: trusted analyst-prepared (validated on load)
- **Pipeline compute**: trusted internal Fabric workspace
- **ADS**: trusted downstream (Managed Identity auth)

---

## Deployment and environments

| Environment | Purpose | ADS endpoint |
|------------|---------|-------------|
| PoC / Staging | Development and analyst testing | `ads-staging.internal.example.com` |
| Production | Live monthly runs | `ads.internal.example.com` |

All notebooks and config files live in the Fabric Lakehouse workspace. No containerisation, no CI/CD pipeline for notebooks in the PoC. Promotion from staging to production is a manual notebook copy.

Environment-specific settings (ADS base URL) are isolated in `/Files/config/ads_config.json` — no environment-specific code in notebooks.

---

## Observability

| Signal | Source | Where |
|--------|--------|-------|
| Run-level status | `nb_run_all` | `run_audit_log` Delta table |
| Per-DFM row counts, parse errors | `nb_ingest_*` | `run_audit_log`, `parse_errors` |
| Schema changes | `nb_ingest_*` | `schema_drift_events` |
| Validation failures | `nb_validate` | `validation_events` |
| TPIR check pass/fail | `nb_tpir_check` | `tpir_check_result.json` |
| ADS load status | `nb_ads_load` | `run_audit_log` (`ads_load_status`, `ads_load_rows`) |
| Period reconciliation | `nb_reports` | `reconciliation_summary.json` |
| Analyst-readable reports | `nb_reports` | Report 1 CSVs, Report 2 roll-up CSV |

No external monitoring system (e.g. Datadog, Azure Monitor alerts) is in scope for the PoC. Post-PoC recommendation: add Azure Monitor alerts on `run_audit_log` rows where `status = FAILED` or `ads_load_status = failed`.

---

## Security and compliance

- **Authentication**: All ADS API calls use Azure Managed Identity bearer tokens. No secrets in code or config.
- **Authorisation**: Fabric workspace access is restricted to the investment operations team and authorised technical staff.
- **Data sensitivity**: Holdings data and policy references are commercially sensitive. No PII may appear in audit logs. See [constraints.md](../../constraints.md).
- **FX rate source**: Must originate from the firm's approved market data provider. See [constraints.md](../../constraints.md).
- **Audit trail**: `run_audit_log` and `reconciliation_summary.json` are retained per run for regulatory review. Delta table versioning provides change history.

---

## Decisions

Key architectural decisions are recorded in [docs/adr/](../adr/). Relevant decisions include:

- Python/PySpark over Scala for notebook implementation (lower onboarding cost, team familiarity)
- SHA-256 row-hash for idempotent MERGE upsert (avoids full-period re-delete on re-run)
- tpir_load contract preserved exactly (ADS boundary not crossed)
- REST API for ADS load (enables status polling and idempotency via run_id)
- `POP_001` enabled by default (operational reconciliation requirement; was disabled in initial PoC scaffold)
- `tolerance_pct = 0.02` for MV_001 (matches the 98–102% operational check from the Excel process)
