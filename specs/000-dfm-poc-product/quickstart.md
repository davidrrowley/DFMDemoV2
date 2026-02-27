# Quickstart: DFM PoC Ingestion Platform

> **Audience:** Investment operations analysts and developers running the DFM PoC ingestion pipeline
> for the first time or for a new period.

---

## Prerequisites

Before running the pipeline, confirm the following:

### Fabric Workspace

- [ ] You have access to the Fabric workspace containing the DFM PoC Lakehouse.
- [ ] The Lakehouse is named per your environment (e.g., `dfm_poc_lakehouse`).
- [ ] All seven Delta tables exist: `canonical_holdings`, `tpir_load_equivalent`,
  `policy_aggregates`, `validation_events`, `run_audit_log`, `schema_drift_events`, `parse_errors`.
  (If not, run the table creation notebook from Phase 1 of `plan.md`.)

### Config Files

- [ ] The following config files exist at `/Files/config/` in OneLake:
  - `dfm_registry.json` — DFM identifiers and enabled/disabled flags
  - `raw_parsing_config.json` — Per-DFM file discovery and column mapping
  - `rules_config.json` — Validation rule thresholds and enable/disable flags
  - `currency_mapping.json` — Currency description → ISO code mapping
  - `fx_rates.json` — FX rates for GBP conversion (update for each period)

### Source Files

- [ ] Source DFM files for the target period have been placed in the correct landing zone paths:

  | DFM | Landing zone path |
  |---|---|
  | Brown Shipley | `/Files/landing/period=YYYY-MM/dfm=brown_shipley/source/` |
  | WH Ireland | `/Files/landing/period=YYYY-MM/dfm=wh_ireland/source/` |
  | Pershing | `/Files/landing/period=YYYY-MM/dfm=pershing/source/` |
  | Castlebay | `/Files/landing/period=YYYY-MM/dfm=castlebay/source/` |

  Replace `YYYY-MM` with the actual period (e.g., `2025-12`).

- [ ] Expected source files per DFM:
  - **Brown Shipley:** `*notification*.csv` + `*cash*.csv`
  - **WH Ireland:** `*.xlsx` (single file; sheet name auto-detected)
  - **Pershing:** `*positions*.xlsx` + `*valuation*.xlsx`
  - **Castlebay:** `*.xlsx` (European decimal convention)

---

## Initial Setup (First Run Only)

If this is the first time setting up the PoC:

1. **Create the Lakehouse** in your Fabric workspace.
2. **Run the setup notebook** (Phase 1 of `plan.md`) to create all Delta tables.
3. **Upload config files** to `/Files/config/` via the Fabric Lakehouse Files explorer.
4. **Review `dfm_registry.json`** and ensure all four DFMs are set to `"enabled": true`.
5. **Update `fx_rates.json`** with the correct FX rates for your period (GBP base).

---

## Running a Period Ingestion

### Step 1 — Upload source files

Upload your DFM source files to the correct landing zone paths (see Prerequisites above).

### Step 2 — Open `nb_run_all`

In the Fabric workspace, open the `nb_run_all` notebook.

### Step 3 — Set the period parameter

In the notebook parameters cell, set:

```python
period = "2025-12"  # Replace with your target period (YYYY-MM)
```

### Step 4 — Run all cells

Click **Run all** (or use the Fabric Pipeline trigger if configured).

The notebook will:
1. Generate a `run_id` (UTC timestamp, e.g., `20251231T142300Z`)
2. Load all config files
3. Invoke each enabled DFM notebook in sequence
4. Invoke `nb_validate`
5. Invoke `nb_aggregate`
6. Invoke `nb_reports`
7. Finalise `run_audit_log` for all DFMs

### Step 5 — Check the audit log

After the run completes, query `run_audit_log` for your `run_id`:

```sql
SELECT dfm_id, files_processed, rows_ingested, parse_errors_count, status
FROM run_audit_log
WHERE run_id = '20251231T142300Z'
ORDER BY dfm_id
```

Expected: four rows, one per DFM, with `status` = `OK` or `PARTIAL`.

If any DFM has `status = FAILED`, check the `parse_errors` table and the notebook output for
the failed DFM.

---

## Expected Outputs

After a successful run, the following should be available:

### Delta Tables (Lakehouse)

| Table | What to check |
|---|---|
| `canonical_holdings` | `SELECT dfm_id, COUNT(*) FROM canonical_holdings WHERE period='2025-12' GROUP BY dfm_id` — should show rows for all four DFMs |
| `policy_aggregates` | `SELECT dfm_id, COUNT(*) FROM policy_aggregates WHERE run_id='...' GROUP BY dfm_id` — one row per DFM+policy |
| `tpir_load_equivalent` | `SELECT COUNT(*) FROM tpir_load_equivalent WHERE run_id='...'` — should match `canonical_holdings` count |
| `validation_events` | `SELECT rule_id, status, COUNT(*) FROM validation_events WHERE run_id='...' GROUP BY rule_id, status` |
| `run_audit_log` | Four rows, one per DFM |

### Output Files (OneLake `/Files/output/period=YYYY-MM/run_id=<run_id>/`)

| File | Description |
|---|---|
| `report1_brown_shipley.csv` | Brown Shipley validation summary |
| `report1_wh_ireland.csv` | WH Ireland validation summary |
| `report1_pershing.csv` | Pershing validation summary |
| `report1_castlebay.csv` | Castlebay validation summary |
| `report2_rollup.csv` | Cross-DFM roll-up: counts by rule and severity |
| `reconciliation_summary.json` | Totals by DFM (cash/bid/accrued) + row counts |

---

## Comparing Outputs to Excel

To compare `policy_aggregates` totals to the Excel Rec_Output:

1. Open `reconciliation_summary.json` in a text editor or Fabric notebook.
2. For each DFM, note `total_bid_value_gbp`, `total_cash_value_gbp`, `total_accrued_interest_gbp`.
3. Compare to the corresponding SUMIFS totals in the Excel Rec_Output tab for the same period.
4. Differences > tolerance should be investigated:
   - Check `parse_errors` for the DFM (rows excluded from canonical).
   - Check `canonical_holdings.data_quality_flags` for assumptions made.
   - Check `validation_events` for MV_001 failures that might indicate price discrepancies.

---

## Re-Running a Period

Re-running `nb_run_all` for the same `period` is safe. Row-hash de-duplication ensures that
`canonical_holdings` is not duplicated. The new `run_id` is appended to all governance tables,
giving a full history of runs for the period.

---

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `run_audit_log.status = NO_FILES` for a DFM | No source files in landing zone | Upload source files to the correct path |
| `run_audit_log.status = FAILED` for a DFM | Notebook exception during ingestion | Check `parse_errors` table and notebook cell output |
| `policy_aggregates` totals don't match Excel | Parse errors excluded rows, or FX rate mismatch | Check `parse_errors` count and `fx_rates.json` |
| `validation_events` has no MV_001 rows | `local_bid_price` or `holding` null for DFM | Check `canonical_holdings.data_quality_flags` for the DFM |
| Output files not in `/Files/output/` | `nb_reports` did not run or raised an error | Check `nb_run_all` cell output for the reports step |

---

## See Also

- [spec.md](spec.md) — Product overview and success criteria
- [architecture.md](architecture.md) — Pipeline structure and notebook descriptions
- [security-baseline.md](security-baseline.md) — Data handling requirements for analysts
- [specs/001-dfm-poc-ingestion/](../001-dfm-poc-ingestion/) — Feature-level specs and DFM mappings
