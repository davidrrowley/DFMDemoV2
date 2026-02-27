# High-Level Requirements: DFM PoC Ingestion Platform

> **Scope:** Functional and non-functional requirements for the DFM PoC Ingestion Platform.
> Each requirement maps to one or more features in `feature-map.md`.
> Technology-agnostic — implementation choices are documented in `architecture.md`.

---

## HR-01 Ingestion

The platform must ingest holdings data from all four DFMs for a given period.

- **HR-01.1 Multi-DFM support:** The system must support ingestion from Brown Shipley (Notification + Cash CSV), WH Ireland (XLSX), Pershing (Positions + Valuation XLSX), and Castlebay (XLSX).
- **HR-01.2 File discovery:** The system must discover all source files in the landing zone path `/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/` for a given period and DFM.
- **HR-01.3 Config-driven parsing:** Column mappings, skip rows, sheet names, numeric conventions, and date formats must be driven by `raw_parsing_config.json`, not hard-coded in notebook logic.
- **HR-01.4 Fault isolation:** A failure ingesting one DFM must not prevent other DFMs from being ingested. Failures must be caught, logged to `run_audit_log` with `status=FAILED`, and execution must continue.
- **HR-01.5 No-files handling:** If no source files are found for a DFM in the landing zone, the system must emit an audit row with `status=NO_FILES` and continue.
- **HR-01.6 Period parameter:** All ingestion must be driven by a `period` parameter (YYYY-MM) passed from `nb_run_all`.

---

## HR-02 Normalisation

The platform must normalise all ingested data into the canonical `canonical_holdings` schema.

- **HR-02.1 Canonical schema:** All DFM data must be mapped to the `canonical_holdings` schema as defined in `data-model.md`, regardless of source format differences.
- **HR-02.2 GBP conversion:** All monetary values must be converted to GBP equivalents using FX rates from `fx_rates.json`. Rows with non-GBP currency must have a valid `fx_rate`.
- **HR-02.3 Numeric convention support:** The parser must handle both UK/US decimal conventions (e.g., `13,059.70`) and European decimal conventions (e.g., `3.479,29`) via the `parse_numeric(value, european=False)` function.
- **HR-02.4 Date parsing:** The system must parse dates in dd-MMM-yyyy, dd/MM/yyyy, ISO datetime, and filename-inferred formats via the `parse_date(value)` function.
- **HR-02.5 Row-hash de-duplication:** Each row must have a deterministic `row_hash` computed over a stable column set. MERGE upsert must use `row_hash` to prevent duplicate rows when re-running the same period.
- **HR-02.6 Data quality flags:** Any field-level assumption made during normalisation (e.g., holding assumed zero, date inferred from filename) must be recorded in `data_quality_flags` on the canonical row.
- **HR-02.7 Source traceability:** Every canonical row must carry `source_file`, `source_sheet`, and `source_row_id` pointing back to its origin.

---

## HR-03 Validation

The platform must evaluate a baseline set of validation rules across all DFMs.

- **HR-03.1 DATE_001 — Stale report date:** Warn if `report_date > month_end + 5 working days` (weekend-only calendar). Severity: warning. Emit `not_evaluable` if `report_date` is null.
- **HR-03.2 MV_001 — MV recalculation:** Compute `holding × local_bid_price × fx_rate` and compare to `bid_value_gbp`. Fail if the absolute difference exceeds `tolerance_abs_gbp` OR percentage difference exceeds `tolerance_pct`. `details_json` must include `computed_mv`, `reported_mv`, `abs_diff`, `pct_diff`. Severity: exception. Evaluable for WH Ireland, Pershing, Castlebay (Brown Shipley if feasible). Emit `not_evaluable` if required fields are null.
- **HR-03.3 VAL_001 — No cash and no stock:** At policy_aggregates level, fail if `total_cash_value_gbp == 0 AND total_bid_value_gbp == 0`. Severity: exception.
- **HR-03.4 MAP_001 — Unmapped security proxy:** At row level, if `security_id` is null and `bid_value_gbp < residual_cash_threshold_gbp`, classify as residual cash (flag, not fail). If `security_id` is null and `bid_value_gbp >= residual_cash_threshold_gbp`, raise exception. Severity: exception.
- **HR-03.5 POP_001 — Policy mapping (optional):** Disabled by default. If `policy_mapping.csv` is present and the rule is enabled, fail if DFM policy cannot be mapped to an IH policy. Severity: exception.
- **HR-03.6 Config-driven thresholds:** All rule thresholds (tolerances, staleness windows, residual cash threshold) must be parameterised in `rules_config.json`. Individual rules must be individually enable/disableable.
- **HR-03.7 Evaluability:** If a rule cannot be evaluated due to missing fields, the system must emit a `validation_events` row with `status=not_evaluable` and a reason in `details_json`.

---

## HR-04 Aggregation

The platform must produce policy-level aggregates and the tpir_load_equivalent output.

- **HR-04.1 policy_aggregates:** Compute `total_cash_value_gbp`, `total_bid_value_gbp`, and `total_accrued_interest_gbp` grouped by `period`, `run_id`, `dfm_id`, `policy_id`. Null `bid_value_gbp` values must be treated as 0 in aggregation.
- **HR-04.2 tpir_load_equivalent:** Produce a Delta table with the tpir_load column schema as defined in `data-model.md`. Schema must match the existing tpir_load contract used by downstream systems.
- **HR-04.3 Rec_Output parity:** `policy_aggregates` totals must be directly comparable to Excel Rec_Output SUMIFS totals for cash/bid/accrued per DFM + policy.
- **HR-04.4 Deterministic aggregation:** Aggregation computations must be deterministic — given the same `canonical_holdings` rows, the same `policy_aggregates` and `tpir_load_equivalent` must always be produced.

---

## HR-05 Reporting

The platform must produce per-DFM and roll-up reports, and a reconciliation summary.

- **HR-05.1 Report 1 — Per-DFM validation summary:** For each DFM, write `report1_<dfm_id>.csv` to `/Files/output/period=YYYY-MM/run_id=<run_id>/`. Contents: validation failures grouped by `policy_id` and `rule_id`; MV_001 numeric diffs; `not_evaluable` counts by rule.
- **HR-05.2 Report 2 — Daily roll-up:** Write `report2_rollup.csv` with counts by DFM, rule, severity; top policies by exception count.
- **HR-05.3 reconciliation_summary.json:** Write a JSON file containing totals by DFM (`total_cash_value_gbp`, `total_bid_value_gbp`, `total_accrued_interest_gbp`) from `policy_aggregates`, and row counts by DFM from `canonical_holdings`. Optional tie-out to an expected totals file if present in `/Files/config/`.

---

## HR-06 Audit & Governance

The platform must produce a complete audit trail for every run.

- **HR-06.1 run_audit_log:** Write one row per DFM per run to `run_audit_log` with `files_processed`, `rows_ingested`, `parse_errors_count`, `drift_events_count`, `status`, `started_at`, `completed_at`.
- **HR-06.2 parse_errors:** Write one row to `parse_errors` for every source row that cannot be parsed, including `source_row_id`, `error_message`, and `raw_value`.
- **HR-06.3 schema_drift_events:** Write one row to `schema_drift_events` for every schema deviation detected in a source file (missing column, unexpected column, type change).
- **HR-06.4 Completeness:** Every DFM must always have an audit row, even if no files were found (`NO_FILES`) or an exception occurred (`FAILED`).
- **HR-06.5 Data lineage:** Every row in `canonical_holdings`, `tpir_load_equivalent`, `policy_aggregates`, `validation_events`, `parse_errors`, and `schema_drift_events` must carry `run_id` and `dfm_id`.

---

## HR-07 Orchestration

The platform must provide a single-entry orchestration notebook.

- **HR-07.1 Single entrypoint:** `nb_run_all` must be the sole entrypoint for a period run, accepting a `period` parameter.
- **HR-07.2 run_id generation:** `nb_run_all` must generate a unique `run_id` as a UTC timestamp and propagate it to all child notebooks.
- **HR-07.3 Execution order:** DFM ingestion notebooks must be invoked before `nb_validate`, which must complete before `nb_aggregate`, which must complete before `nb_reports`.
- **HR-07.4 DFM registry:** Enabled/disabled DFMs must be controlled by `dfm_registry.json`. Disabling a DFM in config must prevent its ingestion notebook from being invoked.

---

## HR-08 Data Quality

The platform must handle incomplete and ambiguous source data gracefully.

- **HR-08.1 Assumption flagging:** Every assumption made during parsing (zero holdings, inferred dates, defaulted FX rates) must add a flag to `data_quality_flags` on the canonical row.
- **HR-08.2 not_evaluable states:** Validation rules must emit `not_evaluable` (not `fail`) when required input fields are null. The reason must be captured in `details_json`.
- **HR-08.3 Parse error capture:** Rows that cannot be parsed must be written to `parse_errors` and excluded from `canonical_holdings`. The run must continue.
- **HR-08.4 Schema drift detection:** Source file schema changes must be detected and written to `schema_drift_events`. Drift must not cause an unrecoverable exception; the ingestion must continue with available columns.

---

## HR-09 Quality Attributes (Non-Functional)

- **HR-09.1 Determinism:** Given the same source files and config, a run must always produce identical `canonical_holdings`, `policy_aggregates`, and `tpir_load_equivalent` rows. No random elements in finance calculations.
- **HR-09.2 Reproducibility:** Any past period can be re-run by supplying the same landing zone files and config. Re-runs must produce the same output (modulo `run_id` and `ingested_at` timestamps), with de-duplication preventing duplicate canonical rows.
- **HR-09.3 Observability:** Every run must produce `run_audit_log`, `parse_errors`, and `schema_drift_events`. There must be no "silent" failures.
- **HR-09.4 Error resilience:** A single DFM failure must never block other DFMs or downstream steps from running.
- **HR-09.5 Config portability:** No DFM-specific logic may appear outside extractor config (`raw_parsing_config.json`) and the DFM ingestion notebook. All downstream logic must be DFM-agnostic.
- **HR-09.6 Run performance:** A full four-DFM run for one period must complete within 30 minutes.
- **HR-09.7 Idempotency:** Re-running the same period must not produce duplicate rows in `canonical_holdings` (row-hash de-duplication).

---

## Requirement Ownership

All requirements are owned by `app-python`.

| Requirement Group | Feature | Agent |
|---|---|---|
| HR-01, HR-02, HR-07 | F01: DFM Ingestion Pipeline | `app-python` |
| HR-03, HR-08 | F02: Validation Engine | `app-python` |
| HR-04, HR-05 | F03: Aggregation & Output | `app-python` |
| HR-06 | F04: Audit & Governance | `app-python` |
| HR-09 | Cross-cutting (all features) | `app-python` |

---

## See Also

- [feature-map.md](feature-map.md) — Requirements mapped to features
- [nfr.md](nfr.md) — Non-functional requirements detail
- [data-model.md](data-model.md) — Entity and schema definitions
- [specs/002-dfm-poc-ingestion/05_validations.md](../002-dfm-poc-ingestion/05_validations.md) — Validation rule detail
