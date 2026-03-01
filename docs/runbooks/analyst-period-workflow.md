# Analyst Period Workflow

**Audience**: Investment operations analysts  
**When to use**: Every month, for each DFM holdings reconciliation period  
**Time estimate**: 20–30 minutes for pre-run preparation; 5–10 minutes for post-run review  
**Prerequisites**: Access to Fabric workspace, Spice/IH system, network share at `\\CORP\FILE\Phoenix\Finance\...`

---

## Overview

This runbook covers the end-to-end analyst workflow for a single monthly DFM reconciliation period. It replaces the original Excel macro-based process (Reset Workbook → Import FX Rates → Import ISIN Mappings → Import IH Report → Paste confirmation → Review → Paste to tpir_load → Run TPIR Upload Checker → Load to ADS).

The steps below map directly to the automated pipeline stages:

| Manual Excel step | Automated equivalent |
|---|---|
| Import FX Rates macro | Upload `fx_rates.csv` to OneLake config |
| Import ISIN Mappings macro | Upload `security_master.csv` to OneLake config |
| Import IH Report macro | Upload `policy_mapping.csv` to OneLake config |
| Open confirmation, paste to Original Data | Place DFM files in landing zone |
| Copy formulae on Edited tab | `nb_ingest_<dfm>` — handled automatically |
| Review C:G columns for #N/A | Inspect `MAP_001` and `POP_001` exceptions in Reports |
| Filter Edited, paste to tpir_load | `nb_aggregate` — handled automatically |
| Run TPIR Upload Checker | `nb_tpir_check` — handled automatically |
| Load to ADS | `nb_ads_load` — gated on TPIR check pass |

---

## Stage 1: Pre-Run Preparation

### Step 1.1 — Obtain DFM confirmation files

Collect the monthly confirmation files from each DFM. Each DFM sends files in a specific format — do not rename or reformat them:

| DFM | Expected files | Source |
|-----|---------------|--------|
| Brown Shipley | `Notification.csv`, `Notification - Cash.csv` | Email attachment from Brown Shipley |
| WH Ireland | `Standard Life Valuation Data *.xlsx` | Email attachment from WH Ireland |
| Pershing | `Positions.csv`, `PSL_Valuation_Holdings_*.csv` | Pershing portal download |
| Castlebay | `Cde OSB Val DDMMMYY.xlsx` | Email attachment from Castlebay |

Save each file set to a staging area before uploading to OneLake.

---

### Step 1.2 — Export FX Rates

1. Open the treasury FX system (or Bloomberg) and export spot rates for the last business day of the period.
2. Ensure the export includes all currencies represented in DFM source files: `USD`, `EUR`, `CHF`, `JPY`, `SEK`, `NOK`, `DKK`, `AUD`, `CAD`, `HKD`, `SGD` (and any new currencies that appeared this period).
3. Format as a CSV with columns `currency_code`, `rate_to_gbp`, `effective_date` (see `14_config_inputs.md` for schema).
4. Save as `fx_rates.csv`.

---

### Step 1.3 — Export IH Policy Mapping from Spice

1. Log into the Spice policy administration system.
2. Navigate to the DFM holdings report for the current period.
3. Download / export the policy list as a CSV.
4. Reformat to the `policy_mapping.csv` schema (columns: `dfm_id`, `dfm_policy_ref`, `ih_policy_ref`, `status`). See `14_config_inputs.md` for full schema.
5. Save as `policy_mapping.csv`.

> The raw IH Report is also available at:
> `\\CORP\FILE\Phoenix\Finance\Restrict\OPS\Assets Team\PRODUCTION\SLIL\Monthly Asset Reports\DFM\Administration\`

---

### Step 1.4 — Verify Security Master

1. Open the ISIN Master List workbook (maintained by the team).
2. Confirm it includes all securities known to appear this period.
3. Export the relevant columns as `security_master.csv` (columns: `isin`, `sedol`, `asset_name`, `asset_class`, `currency_iso`). See `14_config_inputs.md`.
4. Save as `security_master.csv`.

---

### Step 1.5 — Upload Config Files to OneLake

Upload all three config files to the Fabric Lakehouse `/Files/config/` folder, overwriting the previous period's files:

```
/Files/config/fx_rates.csv
/Files/config/policy_mapping.csv
/Files/config/security_master.csv
```

> Other config files (`dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`, `currency_mapping.json`) do not change monthly and only need updating when a new DFM is added or a rule threshold changes.

---

### Step 1.6 — Upload DFM Source Files to Landing Zone

Place each DFM's files in the correct landing zone path for the period (format: `YYYY-MM`):

```
/Files/landing/period=YYYY-MM/dfm=brown_shipley/source/Notification.csv
/Files/landing/period=YYYY-MM/dfm=brown_shipley/source/Notification - Cash.csv

/Files/landing/period=YYYY-MM/dfm=wh_ireland/source/Standard Life Valuation Data *.xlsx

/Files/landing/period=YYYY-MM/dfm=pershing/source/Positions.csv
/Files/landing/period=YYYY-MM/dfm=pershing/source/PSL_Valuation_Holdings_*.csv

/Files/landing/period=YYYY-MM/dfm=castlebay/source/Cde OSB Val DDMMMYY.xlsx
```

**Do not mix files from different periods in the same landing zone folder.**

---

## Stage 2: Trigger the Pipeline Run

### Step 2.1 — Open the run notebook

1. Open the Fabric workspace.
2. Navigate to `notebooks/dfm_poc_ingestion/nb_run_all`.
3. Set the notebook parameter `period` to the current period in `YYYY-MM` format (e.g. `2025-12`).

### Step 2.2 — Run the notebook

Click **Run all** (or **Run** for the parameters cell first, then the main cell).

The notebook will:
1. Discover and ingest files for all four DFMs
2. Run validations (MV_001, DATE_001, VAL_001, MAP_001, POP_001)
3. Compute aggregates and produce `tpir_load_equivalent`
4. Execute the TPIR Upload Check
5. Load to ADS (if TPIR check passes)

Expected runtime: ≤30 minutes on Fabric shared compute.

---

## Stage 3: Post-Run Review

### Step 3.1 — Check run audit log

Query `run_audit_log` to confirm all four DFMs completed:

```sql
SELECT dfm_id, status, rows_ingested, parse_errors_count, completed_at, ads_load_status
FROM run_audit_log
WHERE run_id = '<run_id>'
ORDER BY dfm_id
```

Expected: four rows with `status IN ('OK', 'PARTIAL')`. A `FAILED` or `NO_FILES` status requires investigation before proceeding.

---

### Step 3.2 — Review Report 1 CSVs (per-DFM validation summary)

Download the four Report 1 files from:
```
/Files/output/period=YYYY-MM/run_id=<run_id>/report1_<dfm_id>.csv
```

For each DFM:
- Review any rows where `rule_id = MV_001` and `status = fail` — the `mv_pct_diff` column shows the percentage deviation; values outside ±2% require investigation and should be flagged to the DFM.
- Review `MAP_001` exceptions — these indicate securities missing from `security_master.csv`. Follow the maintenance workflow in `14_config_inputs.md` to add them and re-run.
- Review `POP_001` exceptions — these indicate policies in the DFM file that are not in `policy_mapping.csv`. Check Spice and update `policy_mapping.csv` per the workflow in `14_config_inputs.md`.

---

### Step 3.3 — Check TPIR Upload Check result

Read `tpir_check_result.json`:
```
/Files/output/period=YYYY-MM/run_id=<run_id>/tpir_check_result.json
```

If `status: failed`, review the `blocking_failures` list and resolve before re-running. Do not proceed to ADS load until this shows `status: passed`.

---

### Step 3.4 — Confirm ADS Load

In `run_audit_log`, confirm:
```
ads_load_status = 'committed'
ads_load_rows > 0
```

If `ads_load_status = 'skipped_tpir_check_failed'`, the TPIR check failed — see Step 3.3.  
If `ads_load_status = 'failed'`, the ADS load encountered a server error — contact the ADS system administrator.

---

## Stage 4: Re-Run Guidance

If any of the following were resolved after the initial run (new ISIN added to security_master, new policy mapping added, FX rates corrected):

1. Re-upload the updated config file to `/Files/config/`.
2. Re-run `nb_run_all` with the same `period` parameter.
3. The pipeline is **idempotent**: re-running does not duplicate rows in `canonical_holdings` (SHA-256 row-hash MERGE). It does create a new `run_id` and new output files.
4. After re-run, repeat the post-run review steps above.

---

## Known Issues and Exceptions

| Issue | What to do |
|-------|-----------|
| Brown Shipley European decimal values appear wrong | Confirm `european_decimals: true` is set in `raw_parsing_config.json` for `brown_shipley` |
| Castlebay date shows as null | File was renamed — re-upload with original filename format `Cde OSB Val DDMMMYY.xlsx`; the date is inferred from the filename |
| MV_001 `not_evaluable` for all Brown Shipley rows | Expected behaviour — Brown Shipley source files do not include bid prices |
| Policy appears in DFM file but not in IH Report | Flag to the DFM; add to `policy_mapping.csv` with `status=REMOVE` if confirmed terminated |
| ADS returns HTTP 503 | Retry after 15 minutes; if persistent, contact ADS system administrator |
