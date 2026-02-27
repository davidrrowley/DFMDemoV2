# Feature Map: DFM PoC Ingestion Platform

> **Scope:** Maps requirements to features, establishes feature boundaries, and defines default
> agent ownership. Start from `high-level-requirements.md`, then sequence features in `roadmap.md`.

## How to Use This File

1. Each feature corresponds to a coherent capability boundary in the pipeline.
2. Feature boundaries are defined explicitly to prevent cross-contamination of DFM-specific logic.
3. The feature folder `specs/001-dfm-poc-ingestion/` contains the detailed spec, plan, and tasks
   for all four features in this PoC — they are co-located because they share a common pipeline.

---

## Feature Catalogue

### F01 — DFM Ingestion Pipeline

**Purpose:** Discover, parse, normalise, and write DFM source files to `canonical_holdings`.

**Includes:**
- File discovery per DFM landing zone path
- Per-DFM parsing using `raw_parsing_config.json`
- Numeric convention handling (UK/US and European)
- Date parsing (dd-MMM-yyyy, dd/MM/yyyy, ISO, filename inference)
- GBP conversion via `apply_fx`
- Row-hash de-duplication via `canonical_holdings` MERGE upsert
- Data quality flag emission
- Parse error and schema drift event capture

**Satisfies:** HR-01, HR-02, HR-07, HR-08.3, HR-08.4  
**Default owner:** `app-python`  
**Feature folder:** `specs/001-dfm-poc-ingestion/`  
**Notebooks:** `nb_ingest_brown_shipley`, `nb_ingest_wh_ireland`, `nb_ingest_pershing`, `nb_ingest_castlebay`, `nb_run_all`

**Scope boundary:**
- F01 writes to `canonical_holdings`, `parse_errors`, `schema_drift_events`, and `run_audit_log` only.
- F01 does NOT compute aggregates, run validation rules, or produce reports.
- DFM-specific column mapping logic lives only in `raw_parsing_config.json` and the DFM ingestion notebook.

---

### F02 — Validation Engine

**Purpose:** Evaluate all validation rules across all DFMs in a single pass and write results to
`validation_events`.

**Includes:**
- DATE_001: Stale report date detection (warning)
- MV_001: MV recalculation check (exception) for WH Ireland, Pershing, Castlebay
- VAL_001: No cash and no stock check at policy level (exception)
- MAP_001: Unmapped security / residual cash proxy (exception)
- POP_001: Policy mapping check (optional, disabled by default)
- not_evaluable emission for rules where required fields are null
- Config-driven rule enable/disable and threshold parameterisation

**Satisfies:** HR-03, HR-08.1, HR-08.2  
**Default owner:** `app-python`  
**Feature folder:** `specs/001-dfm-poc-ingestion/`  
**Notebooks:** `nb_validate`  
**Config:** `rules_config.json`

**Scope boundary:**
- F02 reads from `canonical_holdings` and `policy_aggregates` only.
- F02 writes to `validation_events` only.
- F02 does NOT modify canonical rows or recalculate aggregates.

---

### F03 — Aggregation & Output

**Purpose:** Produce `policy_aggregates`, `tpir_load_equivalent`, and all output reports and the
reconciliation summary.

**Includes:**
- `policy_aggregates` computation grouped by `period`, `run_id`, `dfm_id`, `policy_id`
- `tpir_load_equivalent` with schema matching the tpir_load contract
- Report 1 per DFM (`report1_<dfm_id>.csv`) — validation failure summary
- Report 2 roll-up (`report2_rollup.csv`) — cross-DFM counts and top policies
- `reconciliation_summary.json` — totals by DFM + optional tie-out

**Satisfies:** HR-04, HR-05, HR-09.1, HR-09.4  
**Default owner:** `app-python`  
**Feature folder:** `specs/001-dfm-poc-ingestion/`  
**Notebooks:** `nb_aggregate`, `nb_reports`

**Scope boundary:**
- F03 reads from `canonical_holdings` and `validation_events`.
- F03 writes `policy_aggregates`, `tpir_load_equivalent`, and CSV/JSON output files.
- F03 does NOT re-run validation rules or modify canonical holdings.

---

### F04 — Audit & Governance

**Purpose:** Produce complete data lineage and governance records for every run.

**Includes:**
- `run_audit_log` (one row per DFM per run)
- `parse_errors` (one row per failed source row)
- `schema_drift_events` (one row per detected schema change)
- Audit status values: `OK`, `NO_FILES`, `PARTIAL`, `FAILED`
- `run_id` propagation to all downstream tables

**Satisfies:** HR-06, HR-09.3  
**Default owner:** `app-python`  
**Feature folder:** `specs/001-dfm-poc-ingestion/`  
**Notebooks:** Written by DFM ingestion notebooks and finalised by `nb_run_all`

**Scope boundary:**
- F04 governance tables are written by F01 (ingestion), not by a separate notebook.
- F04 is cross-cutting: `run_id` and `dfm_id` must appear in every table row.
- F04 does NOT include reporting; reports are produced by F03.

---

## Feature Boundary Rules

1. **DFM-specific logic is F01-only.** No DFM column names, file patterns, or numeric conventions
   may appear in F02, F03, or F04 code or config.
2. **Validation never modifies data.** F02 (`nb_validate`) is read-only with respect to
   `canonical_holdings`. It only writes to `validation_events`.
3. **Aggregation is deterministic.** F03 computations must produce the same output for the same
   input, regardless of run order or run_id.
4. **Governance is never optional.** F04 audit rows must be written for every DFM on every run,
   including `NO_FILES` and `FAILED` states. Silent failures violate HR-09.3.
5. **Config changes require no code changes.** Enabling/disabling a DFM, adding a validation rule
   threshold, or changing a column mapping must be achievable by editing config JSON only.

---

## Requirement-to-Feature Mapping

| Requirement | F01 Ingestion | F02 Validation | F03 Aggregation | F04 Audit |
|---|:---:|:---:|:---:|:---:|
| HR-01 Ingestion | ✅ | | | |
| HR-02 Normalisation | ✅ | | | |
| HR-03 Validation | | ✅ | | |
| HR-04 Aggregation | | | ✅ | |
| HR-05 Reporting | | | ✅ | |
| HR-06 Audit & Governance | | | | ✅ |
| HR-07 Orchestration | ✅ | | | |
| HR-08 Data Quality | ✅ | ✅ | | |
| HR-09 Quality Attributes | ✅ | ✅ | ✅ | ✅ |

---

## Dependencies

Features must be delivered in this order within each phase:

- **Phase 1 (Foundation):** Delta tables, config, `nb_run_all` skeleton — prerequisite for all features.
- **Phase 2 (F01):** DFM ingestion populates `canonical_holdings` — prerequisite for F02, F03.
- **Phase 3 (F02):** Validation reads `canonical_holdings` and `policy_aggregates` — `policy_aggregates` must be available first (see Phase 4 below).
- **Phase 4 (F03):** Aggregation produces `policy_aggregates` and outputs — must run after F01; F02 depends on `policy_aggregates` from F03 for VAL_001.
- **F04:** Governance tables are written incrementally by F01 throughout execution.

> **Note:** F02 (VAL_001) depends on `policy_aggregates` from F03. In the execution pipeline,
> `nb_aggregate` runs before `nb_validate` to ensure `policy_aggregates` is available.

---

## See Also

- [high-level-requirements.md](high-level-requirements.md) — Full requirement definitions
- [roadmap.md](roadmap.md) — Phase-by-phase sequencing
- [architecture.md](architecture.md) — System design and notebook structure
- [specs/001-dfm-poc-ingestion/](../001-dfm-poc-ingestion/) — Feature-level specs, plan, and tasks
