# Implementation Plan: DFM PoC — Ingestion Pipeline

**Branch**: `001-dfm-poc-ingestion` | **Date**: 2025-12-31 | **Spec**: [specs/001-dfm-poc-ingestion/spec.md](spec.md)

## Summary

Deliver a Microsoft Fabric Lakehouse pipeline (PySpark notebooks + Delta Lake) that ingests raw holdings files from four DFMs (Brown Shipley, WH Ireland, Pershing, Castlebay), normalises them to a canonical GBP-equivalent dataset, runs a configurable set of validation rules, and writes Report 1 per DFM, a Report 2 roll-up, an audit log, and a reconciliation summary — all in a single parameterised run.

---

## Technical Context

**Language/Version**: Python 3.11+ (Microsoft Fabric Spark runtime)
**Primary Dependencies**: PySpark (Fabric runtime — no install required), Delta Lake (built-in), openpyxl ≥ 3.1 (for XLSX parsing; verify availability in target Fabric runtime), pandas ≥ 2.0 (for in-notebook DataFrame manipulation; built into Fabric runtime)
**Storage**: Microsoft Fabric Lakehouse — Delta tables in the managed metastore; flat files (config, landing, output) in OneLake `/Files/`
**Testing**: Manual notebook validation; spot-checks of computed values against known source totals; row count assertions in acceptance steps
**Target Platform**: Microsoft Fabric shared Spark compute — no local execution; notebooks must be run in a Fabric workspace
**Project Type**: data pipeline (PySpark notebooks + Delta Lake; no application server, no API)
**Performance Goals**: Single period run (all four DFMs) completes within 30 minutes on Fabric shared compute
**Constraints**: PoC only; time-boxed to 2 evenings; all DFM differences isolated to config and extractor functions; AI-assisted; no CI/CD pipeline required
**Scale/Scope**: Four DFMs, single period per run, expected dozens to hundreds of holdings rows per DFM per period

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- No blocking constitution rules apply to this PoC.
- Core finance calculations (MV_001, currency normalisation, aggregation) must be deterministic — no probabilistic or AI-generated numeric results.
- Config-driven DFM isolation: no DFM-specific logic hardcoded outside its extractor notebook or config file.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-dfm-poc-ingestion/
├── spec.md               # Feature requirements and user stories
├── plan.md               # This file
├── tasks.md              # Task blocks with owner/acceptance/validate
├── research.md           # DFM-specific mapping decisions and framework choices
├── quickstart.md         # How to run the PoC end-to-end
├── data-model.md         # Feature-level Delta table DDL and state machines
├── checklists/
│   └── requirements.md   # Specification quality checklist
├── contracts/
│   └── schemas.yaml      # Data contract schemas (input, canonical, outputs)
├── config/               # DFM config files (dfm_registry, raw_parsing_config, etc.)
└── 0x_/1x_ docs          # Supplementary reference (architecture, data contracts, DFM mappings)
```

### Notebook Structure (Fabric Lakehouse)

```text
Notebooks/
├── nb_setup              # One-time: create Delta tables, validate config files present
├── nb_run_all            # Entry point: period parameter, run_id generation, DFM sequence
├── nb_ingest_brown_shipley  # Brown Shipley extractor
├── nb_ingest_wh_ireland     # WH Ireland extractor
├── nb_ingest_pershing       # Pershing extractor
├── nb_ingest_castlebay      # Castlebay extractor
├── nb_validate           # Cross-DFM validation rules (MV_001, DATE_001, VAL_001, MAP_001)
├── nb_aggregate          # policy_aggregates + tpir_load_equivalent
└── nb_reports            # Report 1 per DFM, Report 2 roll-up, reconciliation_summary.json
```

### Config Structure (OneLake `/Files/config/`)

```text
Files/config/
├── dfm_registry.json         # DFM identifiers, enabled flags
├── raw_parsing_config.json   # Per-DFM parse settings (header row, sheet, decimal mode)
├── rules_config.json         # Validation rule thresholds and enable flags
├── currency_mapping.json     # Currency description → ISO code (Castlebay)
└── fx_rates.csv              # FX rates for non-GBP currency conversion
```

---

## Constitution Check (Post-Design)

- All numeric calculations use deterministic arithmetic; no AI inference in financial computations.
- DFM logic is isolated: each `nb_ingest_*` notebook references only its own config keys.
- Config-driven enable/disable for all validation rules.
- Row-hash de-duplication applied before all writes to `canonical_holdings`.

---

## Complexity Tracking

| Item | Justification |
|------|---------------|
| Eight notebooks | One entry point + one per DFM + shared validation/aggregation/reports; each independently testable |
| MERGE upsert on `canonical_holdings` | Required for idempotent re-runs; avoids truncate-reload which would lose audit history |

---

## Implementation Strategy

### Phase 1 — Foundation

**Goal**: Running Lakehouse with all Delta tables created and config files uploaded.

1. Create Fabric Lakehouse.
2. Run `nb_setup` to create all seven Delta tables with schemas from `02_data_contracts.md`.
3. Upload config files to `/Files/config/`.
4. Implement `nb_run_all` with `period` parameter, `run_id` generation, DFM sequence loop, and failure isolation.

**Validation**: `spark.catalog.listTables()` shows all seven tables; `nb_run_all` with an empty landing zone produces four `NO_FILES` rows in `run_audit_log`.

---

### Phase 2 — DFM Ingestion Notebooks

**Goal**: All four DFMs write rows to `canonical_holdings` with correct schema and data quality flags.

DFM implementation order (simplest to hardest):

1. **WH Ireland** (`nb_ingest_wh_ireland`) — XLSX, single sheet, well-structured; GBP priority rules clearly defined.
2. **Pershing** (`nb_ingest_pershing`) — Two CSV files, row-hash de-duplication, backfill logic.
3. **Castlebay** (`nb_ingest_castlebay`) — Multi-sheet XLSX, header row 3, filename date inference, currency mapping.
4. **Brown Shipley** (`nb_ingest_brown_shipley`) — Header row detection, European decimals, GBP assumption, MV_001 likely `not_evaluable`.

Each notebook follows the common ingestion steps in `04_ingestion_framework.md`:
- Discover → Classify → Parse → Stage → Map to canonical → Currency normalise → De-duplicate → MERGE upsert → Emit errors/drift.

**Validation**: Per-DFM row count > 0 in `canonical_holdings`; spot-check mapped values against source.

---

### Phase 3 — Validation Notebook

**Goal**: `validation_events` populated with `MV_001`, `DATE_001`, `VAL_001`, `MAP_001` results.

1. Implement `nb_validate` reading from `canonical_holdings` and `policy_aggregates`.
2. Apply rules in order: `DATE_001` (per-row), `MV_001` (per-row), `VAL_001` (per-policy), `MAP_001` (per-row).
3. Emit `fail` or `not_evaluable` events to `validation_events` with correct `severity` and `details_json`.
4. Rules are enabled/disabled per `rules_config.json`.

**Validation**: `MV_001` events present for WH Ireland, Pershing, Castlebay; `not_evaluable` for Brown Shipley rows missing price data.

---

### Phase 4 — Outputs

**Goal**: Report 1, Report 2, `reconciliation_summary.json`, and final `run_audit_log` rows written.

1. `nb_aggregate`: compute `policy_aggregates` from `canonical_holdings`; project `tpir_load_equivalent`.
2. `nb_reports`:
   - Report 1 per DFM: validation failures + not_evaluable counts grouped by `policy_id` + `rule_id`.
   - Report 2 roll-up: counts by DFM + rule + severity.
   - `reconciliation_summary.json`: DFM-level totals from `policy_aggregates` + row counts.
3. `nb_run_all` (post-loop): update `run_audit_log` `completed_at` and final `status` for all DFMs.

**Validation**: Four Report 1 CSVs + one Report 2 CSV in output folder; `reconciliation_summary.json` contains all four DFMs.
