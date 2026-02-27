# Feature Specification: DFM PoC — Ingestion Pipeline

**Feature Branch**: `001-dfm-poc-ingestion`
**Created**: 2025-12-31
**Status**: Draft
**Input**: DFM source files in multiple formats (CSV, XLSX) from four fund managers: Brown Shipley, WH Ireland, Pershing, and Castlebay.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Run Period Ingestion for All DFMs (Priority: P1)

As an investment operations analyst, I can run a period ingestion for all four DFMs and receive a canonical holdings dataset so that I can verify positions are correctly ingested.

**Why this priority**: Without a populated `canonical_holdings` table, no downstream validation, aggregation, or reporting is possible. This is the foundational step.

**Independent Test**: Can be fully tested by placing sample input files in the landing zone for a test period and running `nb_run_all` — no downstream notebooks required.

**Acceptance Scenarios**:

1. **Given** input files are present in `/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/` for all four DFMs, **When** `nb_run_all` is executed with parameter `period=YYYY-MM`, **Then** `canonical_holdings` contains rows for all four DFMs with correct schema and non-zero row counts.
2. **Given** input files are present for at least one DFM, **When** `nb_run_all` runs and one DFM's notebook raises an exception, **Then** the other DFMs still complete and `run_audit_log` reflects `FAILED` for the failing DFM and `OK` for the others.

---

### User Story 2 — View Validation Results per DFM (Priority: P2)

As an analyst, I can see validation results (MV checks, stale date warnings) for each DFM so that I can identify data quality issues.

**Why this priority**: Validation is the core analytical value of the PoC; without it the ingestion is just an ETL exercise.

**Independent Test**: Can be fully tested by querying `validation_events` after Story 1 data is in `canonical_holdings`, without running any report notebooks.

**Acceptance Scenarios**:

1. **Given** `canonical_holdings` is populated with a complete run, **When** `nb_validate` runs, **Then** `validation_events` contains `MV_001` result rows for WH Ireland, Pershing, and Castlebay (either `fail` or `not_evaluable`).
2. **Given** a row in `canonical_holdings` where the absolute MV difference exceeds `tolerance_abs_gbp` from `rules_config.json`, **When** `nb_validate` runs, **Then** that row produces a `MV_001` event with `status = fail` and a populated `details_json` containing `computed_mv`, `reported_mv`, `abs_diff`, and `pct_diff`.
3. **Given** Brown Shipley rows lack `local_bid_price`, **When** `nb_validate` runs, **Then** those rows produce `MV_001` events with `status = not_evaluable`.

---

### User Story 3 — Download Reconciliation Reports (Priority: P3)

As an analyst, I can download Report 1 per DFM and a Report 2 roll-up so that I can share reconciliation summaries with stakeholders.

**Why this priority**: Reports are the delivery artefact; they convert the data pipeline output into something actionable without requiring Delta table access.

**Independent Test**: Can be fully tested by running `nb_reports` after Stories 1 and 2 are complete and checking the OneLake output folder.

**Acceptance Scenarios**:

1. **Given** a complete run (ingestion + validation), **When** `nb_reports` executes, **Then** exactly four Report 1 CSV files (`report1_brown_shipley.csv`, `report1_wh_ireland.csv`, `report1_pershing.csv`, `report1_castlebay.csv`) appear in `/Files/output/period=YYYY-MM/run_id=<run_id>/`.
2. **Given** a complete run, **When** `nb_reports` executes, **Then** one `report2_rollup.csv` file appears in the run output folder with columns `dfm_id`, `rule_id`, `severity`, `status`, `count`.

---

### User Story 4 — Inspect Run Audit Log and Reconciliation Summary (Priority: P4)

As an analyst, I can see the run audit log and reconciliation summary to understand what was processed and confirm completeness.

**Why this priority**: Auditability and data completeness assurance; verifies the pipeline ran as expected.

**Independent Test**: Can be fully tested by querying `run_audit_log` and reading `reconciliation_summary.json` after any complete run.

**Acceptance Scenarios**:

1. **Given** a complete run for four DFMs, **When** `run_audit_log` is queried for the `run_id`, **Then** exactly four rows are present — one per DFM — each with a non-null `completed_at` and a `status` of `OK`, `NO_FILES`, `PARTIAL`, or `FAILED`.
2. **Given** a complete run, **When** `reconciliation_summary.json` is read from the output folder, **Then** it contains a `dfm_summary` array with one entry per DFM, each including `canonical_row_count`, `total_cash_value_gbp`, `total_bid_value_gbp`, and `total_accrued_interest_gbp`.

---

### Edge Cases

- Missing or empty input files for one or more DFMs — pipeline must continue for remaining DFMs and write `NO_FILES` to audit.
- Input files with European decimal format (`3.479,29`) vs. UK/US format (`3,479.29`) — incorrect decimal parsing would corrupt all numeric values.
- Duplicate file copies placed in the landing zone — row-hash de-duplication must prevent double-counting.
- All GBP conversion methods unavailable for a row (`FX_NOT_AVAILABLE`) — `bid_value_gbp` must be null and MV_001 must be `not_evaluable` for those rows.
- A policy exists in the Pershing valuation holdings file but not in `Positions.csv` — backfill logic must detect and apply it.
- `report_date` cannot be inferred from filename (Castlebay) — `DATE_FROM_FILENAME` flag absent; `report_date` must be null and `DATE_001` must be `not_evaluable`.
- Run interrupted mid-execution (notebook timeout, cluster restart) — partial state in `canonical_holdings`; re-run must be idempotent via row-hash MERGE.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST discover all source files in `/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/` for each enabled DFM.
- **FR-002**: System MUST parse CSV and XLSX source files using per-DFM configuration from `raw_parsing_config.json`, including header row detection and sheet selection.
- **FR-003**: System MUST support both UK/US numeric format (`13,059.70`) and European numeric format (`3.479,29`); the parsing mode must be config-driven per DFM.
- **FR-004**: System MUST support four date formats: `dd-MMM-yyyy`, `dd/MM/yyyy`, ISO datetime, and filename-inferred date; `DATE_FROM_FILENAME` flag must be set when filename inference is used.
- **FR-005**: System MUST map source fields to the canonical schema defined in `02_data_contracts.md` using the DFM-specific mapping in the corresponding `1x_dfm_*.md` files.
- **FR-006**: System MUST normalise all monetary values to GBP using the five-step priority chain: (1) local GBP, (2) GBP-denominated column, (3) position-level FX rate, (4) `fx_rates.csv`, (5) null + `FX_NOT_AVAILABLE` flag.
- **FR-007**: System MUST apply row-hash de-duplication (SHA-256 or MD5 of deterministic source fields) before writing to `canonical_holdings` to prevent double-counting from duplicate files.
- **FR-008**: System MUST write all ingested rows to the `canonical_holdings` Delta table via MERGE upsert on `row_hash`.
- **FR-009**: System MUST emit `parse_errors` rows for rows that fail field-level parsing; ingestion of remaining rows must continue.
- **FR-010**: System MUST emit `schema_drift_events` rows when a source file is missing expected columns or contains unexpected columns.
- **FR-011**: System MUST evaluate `MV_001` for rows in `canonical_holdings` where `holding`, `local_bid_price`, and `bid_value_gbp` are all non-null; otherwise emit `not_evaluable`.
- **FR-012**: System MUST evaluate `DATE_001`, `VAL_001`, and `MAP_001` per the rules and thresholds defined in `rules_config.json`; all rules must be individually enable/disable-able.
- **FR-013**: System MUST compute `policy_aggregates` by grouping `canonical_holdings` on `(period, run_id, dfm_id, policy_id)` and summing cash, bid, and accrued values.
- **FR-014**: System MUST produce `tpir_load_equivalent` by projecting `canonical_holdings` to the 13-column tpir_load schema.
- **FR-015**: System MUST write four Report 1 CSVs (one per DFM) to the run output folder after each complete run.
- **FR-016**: System MUST write one Report 2 roll-up CSV to the run output folder after each complete run.
- **FR-017**: System MUST write `reconciliation_summary.json` to the run output folder after each complete run.
- **FR-018**: System MUST write one row to `run_audit_log` per DFM per run, including `NO_FILES` cases, with fields: `files_processed`, `rows_ingested`, `parse_errors_count`, `drift_events_count`, `status`, `started_at`, `completed_at`.
- **FR-019**: System MUST continue executing across DFMs even when one DFM notebook raises an unrecoverable exception; that DFM's audit status must be `FAILED`.
- **FR-020**: System MUST set `data_quality_flags` ArrayType field on every canonical row; flags must include one or more of: `CURRENCY_ASSUMED_GBP`, `FX_NOT_AVAILABLE`, `PRICE_ABSENT`, `DATE_FROM_FILENAME`, `ACQ_COST_UNPARSEABLE`, `CASH_DEFAULTED`, `ACCRUED_DEFAULTED`.

### Key Entities

- **`canonical_holdings`**: Normalised, GBP-equivalent, row-level holdings for all DFMs in a given run.
- **`tpir_load_equivalent`**: Output dataset projected to the 13-column tpir_load contract schema.
- **`policy_aggregates`**: GBP totals per DFM + policy, equivalent to Excel Rec_Output SUMIFS values.
- **`validation_events`**: Record of every rule evaluation (fail / not_evaluable) for a run.
- **`run_audit_log`**: One row per DFM per run; files processed, rows ingested, parse errors, status.
- **`parse_errors`**: Row-level parse failure records from DFM ingestion notebooks.
- **`schema_drift_events`**: Column-level schema change records from DFM source files.
- **`reconciliation_summary`**: JSON file written to the output folder; DFM-level GBP totals and row counts.

---

## Assumptions

- Input files are manually placed in the landing zone before a run is triggered.
- The Fabric Lakehouse, Delta tables, and config files have been created via `nb_setup` before the first run.
- The PoC targets a single period per run; multi-period batch execution is out of scope.
- Bank holiday calendars are not available; `DATE_001` uses a weekend-only working day approximation.
- `Acq_Cost_in_GBP` is not available from any DFM source and is always null in `tpir_load_equivalent`.
- The four DFM identifiers (`brown_shipley`, `wh_ireland`, `pershing`, `castlebay`) are fixed and registered in `dfm_registry.json`.
- MV_001 is expected to be `not_evaluable` for most Brown Shipley rows due to absent price data.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a complete run, `canonical_holdings` contains non-zero rows for all four DFMs (`brown_shipley`, `wh_ireland`, `pershing`, `castlebay`).
- **SC-002**: `MV_001` is evaluable (produces at least one `fail` or `not_evaluable` event) for WH Ireland, Pershing, and Castlebay.
- **SC-003**: Four Report 1 CSVs and one Report 2 roll-up CSV are written to the run output folder after every complete run.
- **SC-004**: `run_audit_log` contains exactly one row per DFM per run; `completed_at` is non-null for all four rows.
- **SC-005**: Re-running the same period does not increase the total row count in `canonical_holdings` (row-hash de-duplication is effective).
