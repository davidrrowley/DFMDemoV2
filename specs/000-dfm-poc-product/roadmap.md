# Roadmap: DFM PoC Ingestion Platform

> **Purpose:** Phase-based sequencing for the DFM PoC Ingestion Platform delivery.
> Each phase delivers a runnable, verifiable increment. Phases are sequential due to
> pipeline dependencies. Total budget: 2 evenings.

---

## Phase 1 — Foundation

**Goal:** Establish the Fabric Lakehouse, all Delta tables, config files, and the `nb_run_all`
entrypoint. Everything else depends on this foundation.

**Target features:** Pre-requisite for F01, F02, F03, F04

**Deliverables:**
- Fabric Lakehouse created and accessible via PySpark notebooks
- All seven Delta tables created with correct schemas:
  - `canonical_holdings`
  - `tpir_load_equivalent`
  - `policy_aggregates`
  - `validation_events`
  - `run_audit_log`
  - `schema_drift_events`
  - `parse_errors`
- Config files uploaded to `/Files/config/`:
  - `dfm_registry.json`
  - `raw_parsing_config.json`
  - `rules_config.json`
  - `currency_mapping.json`
  - `fx_rates.csv` (for the target period)
- `nb_run_all` skeleton: accepts `period` parameter, generates `run_id`, loads config,
  provides DFM invocation loop with try/catch
- Shared Python library module with skeleton functions (`parse_numeric`, `parse_date`,
  `apply_fx`, `row_hash`, `emit_audit`, `emit_parse_error`, `emit_drift_event`,
  `emit_validation_event`)

**Why first:** Without the Lakehouse structure, tables, and config, no notebook can write output.
All four feature notebooks depend on this foundation.

**Estimated effort:** Evening 1, first half

---

## Phase 2 — DFM Ingestion Notebooks (F01)

**Goal:** Implement all four DFM ingestion notebooks, populating `canonical_holdings` and the
governance tables.

**Target feature:** F01 — DFM Ingestion Pipeline

**Deliverables:**
- `nb_ingest_brown_shipley`: ingest Notification CSV + Cash CSV, map to canonical schema,
  apply FX, write to `canonical_holdings`, emit parse errors and drift events, write audit row
- `nb_ingest_wh_ireland`: ingest XLSX (auto-detect sheet), map to canonical schema,
  apply FX, write to `canonical_holdings`, emit parse errors and drift events, write audit row
- `nb_ingest_pershing`: ingest Positions XLSX + Valuation XLSX, map to canonical schema
  (joining positions and valuations), apply FX, write to `canonical_holdings`, emit governance rows
- `nb_ingest_castlebay`: ingest XLSX, map to canonical schema, apply FX, write to
  `canonical_holdings`, emit governance rows
- Row-hash de-duplication via MERGE upsert on `canonical_holdings`
- All numeric fields parsed via `parse_numeric` (supporting both UK/US and European conventions)
- All date fields parsed via `parse_date` (dd-MMM-yyyy, dd/MM/yyyy, ISO, filename inference)
- `data_quality_flags` populated for every assumption made

**Why second:** `canonical_holdings` is the input for validation, aggregation, and reporting.
Nothing downstream can run until canonical data is populated.

**Estimated effort:** Evening 1, second half + Evening 2, first portion

---

## Phase 3 — Validation Engine (F02)

**Goal:** Implement all baseline validation rules, writing results to `validation_events`.

**Target feature:** F02 — Validation Engine

**Deliverables:**
- `nb_validate` notebook implementing:
  - `DATE_001`: Stale report date (warning; weekend-only calendar)
  - `MV_001`: MV recalculation check (exception; WH Ireland, Pershing, Castlebay; + Brown Shipley if feasible)
  - `VAL_001`: No cash and no stock at policy level (exception; reads from `policy_aggregates`)
  - `MAP_001`: Unmapped security / residual cash proxy (exception)
- `not_evaluable` emission for all rules where required fields are null
- All thresholds read from `rules_config.json` at runtime
- Rules individually enable/disableable via `rules_config.json`
- `details_json` for MV_001 includes `computed_mv`, `reported_mv`, `abs_diff`, `pct_diff`

**Why third:** Validation reads from `canonical_holdings` (from Phase 2) and `policy_aggregates`
(from Phase 4). In the execution pipeline, `nb_aggregate` runs before `nb_validate` to ensure
`policy_aggregates` is ready for VAL_001.

**Estimated effort:** Evening 2, early

---

## Phase 4 — Aggregation and Outputs (F03)

**Goal:** Produce `policy_aggregates`, `tpir_load_equivalent`, and all output reports.

**Target feature:** F03 — Aggregation & Output

**Deliverables:**
- `nb_aggregate`:
  - Compute `policy_aggregates` (grouped by `period`, `run_id`, `dfm_id`, `policy_id`)
  - Produce `tpir_load_equivalent` matching tpir_load column contract
- `nb_reports`:
  - Write `report1_<dfm_id>.csv` per DFM to `/Files/output/`
  - Write `report2_rollup.csv` to `/Files/output/`
  - Write `reconciliation_summary.json` to `/Files/output/`
- Final `run_audit_log` update for all DFMs by `nb_run_all`

**Why fourth:** Aggregation reads from `canonical_holdings` (Phase 2). Reports read from both
`policy_aggregates` and `validation_events` (Phase 3). Reports are the last step before the audit
is finalised.

**Estimated effort:** Evening 2, mid-to-late

---

## PoC Completion Milestone

**Goal:** A single `nb_run_all` execution for one target period produces all required outputs,
passes baseline acceptance criteria, and all governance tables are populated.

**Acceptance checklist:**

- [ ] `nb_run_all` completes for one period without unrecoverable errors
- [ ] `canonical_holdings` contains data for all four DFMs
- [ ] `tpir_load_equivalent` schema matches tpir_load contract
- [ ] `policy_aggregates` totals are comparable to Excel Rec_Output for all four DFMs
- [ ] `MV_001` validation is evaluable and produces results for WH Ireland, Pershing, Castlebay
- [ ] `report1_<dfm_id>.csv` exists for all four DFMs in the output folder
- [ ] `report2_rollup.csv` exists in the output folder
- [ ] `reconciliation_summary.json` exists in the output folder
- [ ] `run_audit_log` has one row per DFM with accurate status and counts
- [ ] Re-running the same period does not duplicate `canonical_holdings` rows
- [ ] One DFM can be disabled in `dfm_registry.json` and the rest still run successfully

**Target date:** End of Evening 2

---

## Phase Summary

| Phase | Features | Key output | Estimated timing | Est. hours |
|---|---|---|---|---|
| Phase 1 — Foundation | Pre-requisite | Delta tables, config, `nb_run_all` skeleton | Evening 1, first half | ~1.5 h |
| Phase 2 — DFM Ingestion | F01 | `canonical_holdings`, parse errors, drift events, audit rows | Evening 1–2 | ~3.0 h |
| Phase 3 — Validation | F02 | `validation_events` | Evening 2, early | ~1.0 h |
| Phase 4 — Aggregation & Outputs | F03 | `policy_aggregates`, `tpir_load_equivalent`, reports | Evening 2, mid-late | ~1.5 h |
| PoC Completion | All | Full acceptance checklist passed | End of Evening 2 | ~7.0 h total |

> **Evening definition:** Each evening is assumed to be approximately 3–3.5 focused hours.
> Total budget is ~7 hours. If Phase 2 runs long, defer MAP_001 and POP_001 to Phase 3 scope cut.

---

## Key Sequencing Rules

1. **Foundation before everything.** No notebook can run without Delta tables and config.
2. **F01 before F02 and F03.** `canonical_holdings` must be populated before validation or aggregation can run.
3. **F03 (`nb_aggregate`) before F02 (`nb_validate`).** VAL_001 requires `policy_aggregates` from `nb_aggregate`.
4. **F04 is continuous.** Audit and governance rows are written throughout ingestion, not as a final step.
5. **PoC scope is fixed.** Do not expand beyond the four DFMs, four validation rules, and two-evening budget without explicit scope change.

---

## See Also

- [feature-map.md](feature-map.md) — Feature ownership and boundaries
- [tasks.md](tasks.md) — Task-level breakdown with owner, acceptance, and validate
- [architecture.md](architecture.md) — Notebook structure and pipeline
- [specs/001-dfm-poc-ingestion/plan.md](../001-dfm-poc-ingestion/plan.md) — Feature-level implementation plan
