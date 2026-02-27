# Tasks: DFM PoC Ingestion Platform

**Product folder:** `specs/000-dfm-poc-product/`
**Feature folder:** `specs/001-dfm-poc-ingestion/`
**Owner:** `app-python`

> **Task hierarchy note:** These are product-level milestone tasks (one task ≈ one pipeline phase).
> Each T-PROD task is delivered by the feature-level implementation tasks in
> `specs/001-dfm-poc-ingestion/tasks.md` (T-DFM-*). The two sets are complementary, not
> alternatives: T-PROD tasks define acceptance milestones; T-DFM tasks define the implementation
> steps that achieve them.
>
> | T-PROD (milestone) | Delivered by T-DFM (implementation tasks) |
> |---|---|
> | T-PROD-001 | T-DFM-001, T-DFM-002, T-DFM-003 |
> | T-PROD-002 | T-DFM-010, T-DFM-011, T-DFM-012, T-DFM-013 |
> | T-PROD-003 | T-DFM-020, T-DFM-021 |
> | T-PROD-004 | T-DFM-030, T-DFM-031, T-DFM-032, T-DFM-033 |
> | T-PROD-005 | E2E acceptance — all T-DFM tasks must pass |

---

## T-PROD-001: Foundation — Lakehouse, Delta Tables, Config, Entrypoint

owner: app-python

Create the Fabric Lakehouse, all seven Delta tables with correct schemas, upload all config files
to OneLake (`dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`,
`currency_mapping.json`, `fx_rates.csv`), build the `nb_run_all` entrypoint notebook with the
DFM invocation loop and try/except fault isolation, and create the shared Python library with
skeleton functions (`parse_numeric`, `parse_date`, `apply_fx`, `row_hash`, `emit_audit`,
`emit_parse_error`, `emit_drift_event`, `emit_validation_event`).

acceptance:
- Fabric Lakehouse exists and is accessible via PySpark notebooks
- All seven Delta tables exist with schemas matching `data-model.md`: `canonical_holdings`, `tpir_load_equivalent`, `policy_aggregates`, `validation_events`, `run_audit_log`, `schema_drift_events`, `parse_errors`
- Config files are present at `/Files/config/` in OneLake
- `nb_run_all` accepts a `period` parameter, generates a `run_id` as UTC timestamp, and runs without errors when all DFMs are disabled in `dfm_registry.json`
- Shared Python library is importable from all DFM notebooks with all skeleton functions present

validate:
- Run `nb_run_all` with `period=2025-12` and all DFMs disabled; verify `run_id` is generated and no exceptions are raised
- Query each Delta table with `spark.catalog.listTables()`; confirm all seven are present
- Confirm all five config files are accessible in `/Files/config/`

---

## T-PROD-002: DFM Ingestion — All Four DFM Ingestion Notebooks

owner: app-python

Implement all four DFM ingestion notebooks (`nb_ingest_brown_shipley`, `nb_ingest_wh_ireland`,
`nb_ingest_pershing`, `nb_ingest_castlebay`). Each notebook must discover landing zone files,
parse per `raw_parsing_config.json`, map to the canonical schema, apply GBP conversion, compute
row-hash and MERGE upsert into `canonical_holdings`, emit parse errors, schema drift events, and
audit rows.

acceptance:
- `nb_ingest_brown_shipley` ingests Notification CSV and Cash CSV and writes rows to `canonical_holdings` with `dfm_id=brown_shipley`
- `nb_ingest_wh_ireland` ingests XLSX and writes rows to `canonical_holdings` with `dfm_id=wh_ireland`
- `nb_ingest_pershing` ingests Positions and Valuation XLSX, joins them, and writes rows to `canonical_holdings` with `dfm_id=pershing`
- `nb_ingest_castlebay` ingests XLSX using European numeric convention and writes rows to `canonical_holdings` with `dfm_id=castlebay`
- All four DFMs produce `run_audit_log` rows with `status=OK` or `status=PARTIAL` for a valid landing zone
- Re-running the same period does not increase `COUNT(*)` on `canonical_holdings` for that period (row-hash de-duplication)
- If one DFM notebook raises an exception, the other three still complete and `run_audit_log` shows `status=FAILED` for the failed DFM only

validate:
- Upload sample source files for all four DFMs to the landing zone for `period=2025-12` and run `nb_run_all`
- Query `SELECT dfm_id, COUNT(*) FROM canonical_holdings WHERE period='2025-12' GROUP BY dfm_id` and confirm rows for all four DFMs
- Run `nb_run_all` again for the same period and confirm `COUNT(*)` on `canonical_holdings` is unchanged
- Corrupt one DFM source file and confirm the other three DFMs complete with `status=OK` in `run_audit_log`

---

## T-PROD-003: Validation — Validation Engine

owner: app-python

Implement `nb_validate` with all four baseline validation rules (DATE_001, MV_001, VAL_001,
MAP_001). All thresholds must be read from `rules_config.json` at runtime. Rules must be
individually enable/disableable. `not_evaluable` events must be emitted when required fields are
null. All results must be written to `validation_events`.

acceptance:
- `DATE_001` emits a warning event for any row where `report_date > month_end + 5 working days`; emits `not_evaluable` if `report_date` is null
- `MV_001` computes `holding × local_bid_price × fx_rate`, compares to `bid_value_gbp`, and emits an exception event where the difference exceeds configured tolerances; is evaluable for WH Ireland, Pershing, and Castlebay; `details_json` includes `computed_mv`, `reported_mv`, `abs_diff`, `pct_diff`
- `VAL_001` emits an exception event for any policy in `policy_aggregates` where both `total_cash_value_gbp` and `total_bid_value_gbp` are zero
- `MAP_001` emits a flag for residual cash rows and an exception for unmapped securities above the threshold
- Disabling a rule in `rules_config.json` prevents it from running

validate:
- Query `validation_events` for the run and confirm rows exist for at least three DFMs
- Confirm `MV_001` results exist for `wh_ireland`, `pershing`, and `castlebay`
- Confirm `not_evaluable` rows exist where source data has null `report_date` or null `holding`
- Disable `MV_001` in `rules_config.json`, re-run `nb_validate`, and confirm no MV_001 rows appear for that run

---

## T-PROD-004: Aggregation and Outputs — Reports and Reconciliation Summary

owner: app-python

Implement `nb_aggregate` (producing `policy_aggregates` and `tpir_load_equivalent`) and
`nb_reports` (producing Report 1 per DFM, Report 2 roll-up, and `reconciliation_summary.json`).
Finalise `run_audit_log` for all DFMs in `nb_run_all`.

acceptance:
- `policy_aggregates` contains one row per `dfm_id` + `policy_id` for the run with `total_cash_value_gbp`, `total_bid_value_gbp`, `total_accrued_interest_gbp` matching the sum of contributing canonical rows
- `tpir_load_equivalent` contains all columns from the tpir_load contract as defined in `data-model.md`
- `report1_brown_shipley.csv`, `report1_wh_ireland.csv`, `report1_pershing.csv`, `report1_castlebay.csv` are written to `/Files/output/period=YYYY-MM/run_id=<run_id>/`
- `report2_rollup.csv` is written to the output folder
- `reconciliation_summary.json` is written to the output folder and contains totals by DFM and row counts by DFM
- `reconciliation_summary.json` totals match `policy_aggregates` sums for the same run

validate:
- Run `nb_aggregate` followed by `nb_reports` and confirm all output files exist in the correct output path
- Query `policy_aggregates` for the run and compute manual sum for one DFM; confirm it matches the corresponding Report 1 CSV totals
- Open `reconciliation_summary.json` and confirm totals match `policy_aggregates` query results

---

## T-PROD-005: PoC Acceptance — End-to-End Run Validation

owner: app-python

Execute a full end-to-end `nb_run_all` run for one period with all four DFMs enabled. Verify every
item in the success criteria table in `spec.md`. Document any gaps as follow-up issues.

acceptance:
- `nb_run_all` completes for one period without unrecoverable errors
- `canonical_holdings` contains data for all four DFMs
- `tpir_load_equivalent` schema matches the tpir_load contract
- `policy_aggregates` totals are broadly comparable to Excel Rec_Output totals for at least two DFMs
- `MV_001` is evaluable and produces results for WH Ireland, Pershing, and Castlebay
- All four Report 1 CSVs, Report 2 roll-up, and `reconciliation_summary.json` exist in the output folder
- `run_audit_log` has four rows with valid status values
- Re-running the same period does not duplicate `canonical_holdings` rows
- Disabling one DFM in `dfm_registry.json` results in a three-DFM run completing without error

validate:
- Execute the end-to-end checklist in `quickstart.md` step by step
- Confirm every item in the Success Criteria table in `spec.md` is checked off
- If any item fails, record the failure in `run_audit_log` and document the gap as a follow-up issue
