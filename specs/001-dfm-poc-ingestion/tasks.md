# Tasks: DFM PoC Ingestion

**Input**: Spec and plan from `specs/001-dfm-poc-ingestion/`
**Platform**: Microsoft Fabric — PySpark notebooks, Delta Lake, OneLake

---

## Phase 1: Foundation

### T-DFM-001: Create Fabric Lakehouse Delta tables and config upload

owner: app-python

Create all seven Delta tables (`canonical_holdings`, `tpir_load_equivalent`, `policy_aggregates`,
`validation_events`, `run_audit_log`, `schema_drift_events`, `parse_errors`) with schemas defined
in `02_data_contracts.md`. Upload config files to `/Files/config/`.

acceptance:
- All seven Delta tables created in the Lakehouse with correct schemas
- Config files (`dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`, `currency_mapping.json`) present under `/Files/config/`

validate:
- Run `spark.catalog.listTables()` and confirm all seven table names are present
- Read each config file and confirm JSON/CSV parses without error

---

### T-DFM-002: Implement nb_run_all entrypoint notebook

owner: app-python

Create notebook `nb_run_all` with a `period` parameter (YYYY-MM format). Generate `run_id` as UTC
timestamp. Invoke each DFM ingestion notebook in sequence, continuing on failure. Emit audit entry
per DFM including "no files" cases.

acceptance:
- Notebook accepts `period` parameter and generates `run_id`
- Execution continues when a single DFM ingestion fails
- `run_audit_log` receives one row per DFM per run regardless of outcome

validate:
- Run with a test period; verify `run_audit_log` has four rows (one per DFM)
- Introduce a deliberate failure in one DFM; confirm the other three still complete

---

## Phase 2: DFM Ingestion Notebooks

### T-DFM-010: Implement Brown Shipley ingestion notebook

owner: app-python

Parse `Notification.csv` (positions) and `Notification - Cash.csv` (cash) from the landing zone.
Apply header-row detection and European decimal parsing. Map to canonical columns per
`10_dfm_brown_shipley.md`. Apply GBP rules (assume GBP + flag if currency absent). Write rows
to `canonical_holdings`. Emit parse errors and schema drift events as required.

acceptance:
- Both Brown Shipley files parsed and written to `canonical_holdings` with `dfm_id = brown_shipley`
- Rows with absent currency flagged with `data_quality_flags` containing a currency assumption flag
- European decimal values (e.g. `3.479,29`) correctly parsed as numbers

validate:
- Count rows in `canonical_holdings` where `dfm_id = 'brown_shipley'` — must be > 0
- Spot-check a row with European decimal source and confirm numeric value is correct
- Confirm `data_quality_flags` non-empty for rows with assumed GBP currency

---

### T-DFM-011: Implement WH Ireland ingestion notebook

owner: app-python

Parse the Standard Life Valuation Data XLSX. Map to canonical columns per `11_dfm_wh_ireland.md`.
Apply GBP rules: use `Settled Market Value (PC)` when currency is GBP; use ABC column when base
currency is GBP; else use FX table if available; else null + flag. Set cash and accrued to 0 with
flags. Write rows to `canonical_holdings`.

acceptance:
- WH Ireland XLSX parsed and written to `canonical_holdings` with `dfm_id = wh_ireland`
- `bid_value_gbp` populated for GBP-denominated positions
- Rows where GBP conversion is not possible have `bid_value_gbp = null` and a flag in `data_quality_flags`

validate:
- Count rows where `dfm_id = 'wh_ireland'` — must be > 0
- For GBP rows confirm `bid_value_gbp = bid_value_local`
- Confirm non-GBP rows without FX either have `bid_value_gbp = null` or a computed value from ABC column

---

### T-DFM-012: Implement Pershing ingestion notebook

owner: app-python

Parse `Positions.csv` (primary) and PSL valuation holdings CSV (secondary). Implement row-hash
de-duplication and prefer `Positions.csv` rows; backfill missing policies/values from valuation
holdings per `12_dfm_pershing.md`. Apply GBP rules. Write rows to `canonical_holdings`.

acceptance:
- Both Pershing files ingested; `canonical_holdings` contains rows with `dfm_id = pershing`
- De-duplication applied — duplicate file copies do not produce double-counted rows
- `Positions.csv` rows take precedence over valuation holdings rows for the same position

validate:
- Introduce a duplicate file copy; confirm row count does not double
- Confirm rows sourced from `Positions.csv` are present and correctly mapped
- Confirm backfill applies only for policies absent from `Positions.csv`

---

### T-DFM-013: Implement Castlebay ingestion notebook

owner: app-python

Parse `Cde OSB Val 31Dec25.xlsx` — both `Customer 1` and `Customer 2` sheets. Header row is row 3.
Infer `report_date` from filename (`31Dec25` → `2025-12-31`). Map currency via
`currency_mapping.json`. Set cash and accrued to 0 with flags. Write rows to `canonical_holdings`.

acceptance:
- Both sheets from Castlebay XLSX parsed and written to `canonical_holdings` with `dfm_id = castlebay`
- `report_date` correctly inferred from filename
- Currency ISO codes correctly derived from `Currency Description` via `currency_mapping.json`

validate:
- Count rows where `dfm_id = 'castlebay'` — must be > 0 from both sheets
- Confirm `report_date = 2025-12-31` for all Castlebay rows
- Spot-check a row with "Pound Sterling" → `GBP`

---

## Phase 3: Validations

### T-DFM-020: Implement MV_001 market value recalculation check

owner: app-python

Implement `MV_001` from `rules_config.json`. For each row in `canonical_holdings` where
`holding`, `local_bid_price`, and `bid_value_gbp` are all non-null, compute
`holding * local_bid_price * fx_rate` and compare to `bid_value_gbp`. Emit a `fail` event to
`validation_events` when the absolute difference exceeds `tolerance_abs_gbp` or the percentage
difference exceeds `tolerance_pct`. Emit `not_evaluable` when required fields are absent.

acceptance:
- `MV_001` evaluable and producing results for WH Ireland, Pershing, and Castlebay rows
- `not_evaluable` status emitted for rows missing `holding`, `local_bid_price`, or `bid_value_gbp`
- `fail` events written to `validation_events` for rows exceeding tolerance

validate:
- Confirm at least one `MV_001` event exists in `validation_events` after a run
- Introduce a row with known MV discrepancy > tolerance; confirm it produces a `fail` event
- Confirm `not_evaluable` events appear for Brown Shipley rows where price/holding are unavailable

---

### T-DFM-021: Implement remaining validation rules

owner: app-python

Implement `DATE_001` (stale report date, weekend-only), `VAL_001` (no cash and/or no stock at
policy level), and `MAP_001` (unmapped bonds / residual cash proxy). Write all events to
`validation_events` with correct `severity` and `status` per `rules_config.json`.

acceptance:
- `DATE_001` fires a `warning` when `report_date` is more than 5 days after month-end
- `VAL_001` fires an `exception` for policies with both `total_cash_value_gbp = 0` and `total_bid_value_gbp = 0`
- `MAP_001` classifies rows with missing `security_id` as residual cash if `bid_value_gbp < 1000`, else exception

validate:
- Introduce a row with `report_date` 10 days after month-end; confirm `DATE_001 warning` in `validation_events`
- Confirm at least one `VAL_001` or `MAP_001` event for sample data (or confirm `not_evaluable` if no such case)

---

## Phase 4: Aggregation and Outputs

### T-DFM-030: Compute policy_aggregates

owner: app-python

Group `canonical_holdings` by `period`, `run_id`, `dfm_id`, `policy_id`. Compute
`total_cash_value_gbp`, `total_bid_value_gbp`, `total_accrued_interest_gbp`. Write to
`policy_aggregates` Delta table.

acceptance:
- `policy_aggregates` contains one row per distinct (period, run_id, dfm_id, policy_id) combination
- Aggregate totals match the sum of corresponding rows in `canonical_holdings`
- All four DFMs represented in `policy_aggregates` after a complete run

validate:
- Count distinct `(dfm_id, policy_id)` in `policy_aggregates` and confirm it matches manual grouping of `canonical_holdings`
- Spot-check one policy's `total_bid_value_gbp` against the sum of its rows in `canonical_holdings`

---

### T-DFM-031: Produce tpir_load_equivalent

owner: app-python

Select and rename columns from `canonical_holdings` to match the tpir_load contract schema
(as defined in `02_data_contracts.md`). Write to `tpir_load_equivalent` Delta table.

acceptance:
- `tpir_load_equivalent` contains all required columns: `Policyholder_Number`, `Security_Code`, `ISIN`, `Other_Security_ID`, `ID_Type`, `Asset_Name`, `Acq_Cost_in_GBP`, `Cash_Value_in_GBP`, `Bid_Value_in_GBP`, `Accrued_Interest`, `Holding`, `Loc_Bid_Price`, `Currency_Local`
- Row count matches `canonical_holdings`

validate:
- Run `spark.read.table("tpir_load_equivalent").columns` and confirm all 13 columns present
- Confirm row count equals `canonical_holdings` row count

---

### T-DFM-032: Write Report 1 (per DFM) and Report 2 (roll-up)

owner: app-python

Write Report 1 CSV per DFM to `/Files/output/period=YYYY-MM/run_id=<run_id>/report1_<dfm_id>.csv`
containing validation failures grouped by policy and rule (including MV_001 numeric diffs and
not_evaluable counts). Write Report 2 CSV roll-up with counts by DFM, rule, severity, and top
policies by exception count.

acceptance:
- Four Report 1 CSVs written (one per DFM) after a complete run
- One Report 2 CSV written per run
- Report 1 includes at least: `dfm_id`, `policy_id`, `rule_id`, `severity`, `status`, `count`
- Report 2 includes at least: `dfm_id`, `rule_id`, `severity`, `count`

validate:
- Confirm four Report 1 files and one Report 2 file exist in the output folder after a run
- Open a Report 1 CSV and confirm expected columns and at least one data row

---

### T-DFM-033: Write reconciliation summary and run audit log

owner: app-python

After all DFMs complete: compute `reconciliation_summary.json` (totals by DFM for cash/bid/accrued
from `policy_aggregates`, row counts by DFM). Update `run_audit_log` per DFM with
`files_processed`, `rows_ingested`, `parse_errors_count`, `drift_events_count`, and `status`.

acceptance:
- `reconciliation_summary.json` written to the run output folder with totals for all four DFMs
- `run_audit_log` contains one row per DFM per run with all required audit fields
- `status` field reflects `OK`, `NO_FILES`, `PARTIAL`, or `FAILED` correctly

validate:
- Read `reconciliation_summary.json` and confirm it contains entries for all four `dfm_id` values
- Query `run_audit_log` and confirm four rows with the current `run_id`
