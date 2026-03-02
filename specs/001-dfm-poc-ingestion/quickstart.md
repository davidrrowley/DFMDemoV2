# Quickstart: DFM PoC — Ingestion Pipeline

## Prerequisites

- Access to a Microsoft Fabric workspace with Lakehouse permissions (read + write).
- Access to OneLake Files for the target Lakehouse (to upload config and landing files).
- The four DFM source files for the period you want to run (see **Landing Zone** section).
- Config files from `specs/001-dfm-poc-ingestion/config/` uploaded to OneLake.

---

## Setup (One-Time)

### 1. Upload config files

Copy all files from `specs/001-dfm-poc-ingestion/config/` to `/Files/config/` in your Fabric Lakehouse:

```
/Files/config/dfm_registry.json
/Files/config/raw_parsing_config.json
/Files/config/rules_config.json
/Files/config/currency_mapping.json
/Files/config/fx_rates.csv
/Files/config/security_master.csv
/Files/config/policy_mapping.csv
/Files/config/ads_config.json
/Files/config/azure_openai_config.json
```

Use the Fabric UI (OneLake file explorer) or the Fabric REST API to upload.

Notes:
- `azure_openai_config.json` is required only when enabling Phase 9 AI augmentation tasks.
- `security_master.csv`, `policy_mapping.csv`, and `ads_config.json` are required for Phase 8 (TPIR + ADS load).

### 2. Set up AI backend (Phase 9 only)

If you plan to run Phase 9 AI augmentation (SC-13 to SC-17), choose your backend:

#### Option A: GitHub Models API (Default, PoC-recommended)

**Cost**: ~$5–20 for a complete PoC run.

**Steps**:
1. Create a [Personal Access Token](https://github.com/settings/tokens/new) on github.com with `api` scope.
2. Edit `/Files/config/azure_openai_config.json`:
   - Keep `use_github_models: true`
   - Replace `TBD` in `github_token` with your token
3. Upload the updated file to OneLake.

**Verification**: In a notebook, run:

```python
import json
with open('/lakehouse/default/Files/config/azure_openai_config.json', 'r') as f:
    cfg = json.load(f)
    print(f"Backend: {'GitHub Models' if cfg.get('use_github_models') else 'Azure OpenAI'}")
```

Output: `Backend: GitHub Models`

#### Option B: Azure OpenAI (Optional, Production)

**Cost**: ~$20–50/month for minimal capacity (covering PoC usage).

Use this only if you have Azure credits or want to test production-scale infrastructure.

**Steps**:
1. Deploy the Bicep template:
   ```bash
   az deployment group create \
     --resource-group <your-rg> \
     --template-file infra/bicep/azure-openai.bicep \
     --parameters environmentName=staging fabricWorkspaceObjectId=<mi-object-id>
   ```
2. After deployment, retrieve the endpoint and API key.
3. Edit `/Files/config/azure_openai_config.json`:
   - Set `use_github_models: false`
   - Replace `endpoint` with the deployed URL
   - Replace `api_key` with your key
4. Upload the updated file to OneLake.

### 3. Create Delta tables

Run notebook `nb_setup` (or execute the table-creation cells manually). This creates all seven Delta tables in the Lakehouse:

- `canonical_holdings`
- `tpir_load_equivalent`
- `policy_aggregates`
- `validation_events`
- `run_audit_log`
- `schema_drift_events`
- `parse_errors`

**Verify**: In a notebook cell, run:

```python
spark.catalog.listTables()
```

Confirm all seven names appear.

---

## Phase-gated enablement

- Core PoC (`SC-01` to `SC-10`): requires `dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`, `currency_mapping.json`, and `fx_rates.csv`.
- Phase 8 (`SC-11` to `SC-12`): additionally requires `security_master.csv`, `policy_mapping.csv`, and `ads_config.json`.
- Phase 9 (`SC-13` to `SC-17`): additionally requires GitHub Models API token (default, no infrastructure) or optional Azure OpenAI from `infra/bicep/azure-openai.bicep` and `azure_openai_config.json`.

---

## Landing Zone

Place source files in the following OneLake path structure before running:

```
/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/<filename>
```

Replace `YYYY-MM` with the period (e.g., `2025-12`) and `<dfm_id>` with one of the four registered identifiers:

| DFM | `dfm_id` | Expected files |
|-----|----------|----------------|
| Brown Shipley | `brown_shipley` | `Notification.csv`, `Notification - Cash.csv` |
| WH Ireland | `wh_ireland` | Standard Life Valuation Data XLSX (any name) |
| Pershing | `pershing` | `Positions.csv`, `PSL_Valuation_Holdings_YYYYMMDD_*.csv` |
| Castlebay | `castlebay` | `Cde OSB Val 31Dec25.xlsx` (date in filename) |

**Example** for period `2025-12`:

```
/Files/landing/period=2025-12/dfm=wh_ireland/source/SL_Valuation_Dec2025.xlsx
/Files/landing/period=2025-12/dfm=pershing/source/Positions.csv
/Files/landing/period=2025-12/dfm=pershing/source/PSL_Valuation_Holdings_20251231_001.csv
/Files/landing/period=2025-12/dfm=castlebay/source/Cde OSB Val 31Dec25.xlsx
/Files/landing/period=2025-12/dfm=brown_shipley/source/Notification.csv
/Files/landing/period=2025-12/dfm=brown_shipley/source/Notification - Cash.csv
```

---

## Running the Pipeline

### Full run via nb_run_all

1. Open notebook `nb_run_all` in your Fabric workspace.
2. Set the `period` parameter to `YYYY-MM` (e.g., `2025-12`).
3. Run all cells.

The notebook will:
- Generate a `run_id` (UTC timestamp, e.g., `20251231T142300Z`).
- Invoke each DFM ingestion notebook in sequence.
- Invoke `nb_validate`, `nb_aggregate`, and `nb_reports`.
- Write final `run_audit_log` rows.

**Expected duration**: Under 30 minutes for a full four-DFM run on Fabric shared compute.

### Individual notebooks (debugging)

You can also run each notebook independently in sequence, passing `period` and `run_id` as parameters:

```
nb_setup              → one-time setup only
nb_ingest_wh_ireland  → period, run_id
nb_ingest_pershing    → period, run_id
nb_ingest_castlebay   → period, run_id
nb_ingest_brown_shipley → period, run_id
nb_validate           → period, run_id
nb_aggregate          → period, run_id
nb_reports            → period, run_id
```

---

## Expected Outputs

After a complete run, check the following:

### Delta tables (query in any notebook)

```python
# Row counts per DFM
spark.read.table("canonical_holdings") \
    .filter(f"run_id = '{run_id}'") \
    .groupBy("dfm_id").count().show()

# Validation events
spark.read.table("validation_events") \
    .filter(f"run_id = '{run_id}'") \
    .groupBy("rule_id", "status").count().show()

# Audit log
spark.read.table("run_audit_log") \
    .filter(f"run_id = '{run_id}'").show()
```

### OneLake output folder

```
/Files/output/period=YYYY-MM/run_id=<run_id>/
├── report1_brown_shipley.csv
├── report1_wh_ireland.csv
├── report1_pershing.csv
├── report1_castlebay.csv
├── report2_rollup.csv
└── reconciliation_summary.json
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `run_audit_log` has `NO_FILES` for a DFM | Source files not in correct landing zone path | Check `dfm_id` spelling and folder structure exactly match the pattern above |
| `run_audit_log` has `FAILED` for a DFM | Notebook exception (parse error, schema mismatch) | Open the individual DFM notebook, re-run with the same `period` and `run_id`, and read the error cell output |
| `canonical_holdings` row count is 0 for a DFM | Files present but not parsed | Check `raw_parsing_config.json` header row settings; look in `parse_errors` table |
| European decimal values parsed incorrectly (Brown Shipley) | `european_decimals` flag not set in config | Verify `raw_parsing_config.json` has `"european_decimals": true` for `brown_shipley` |
| `report_date` is null for Castlebay rows | Filename does not match `DDMmmYY` pattern | Rename the file to match the expected pattern (e.g., `Cde OSB Val 31Dec25.xlsx`) |
| Report CSVs not written | `nb_reports` was not run or failed | Run `nb_reports` manually with the correct `period` and `run_id` parameters |
| ADS load step skipped or fails in Phase 8 | `ads_config.json` missing or malformed | Verify `/Files/config/ads_config.json` exists and fields match `16_ads_loading.md` |
| AI notebooks skip or fail to call model in Phase 9 | `azure_openai_config.json` missing or incomplete | Verify `/Files/config/azure_openai_config.json` exists and includes keys from specs 17-21 |
| Duplicate rows in `canonical_holdings` after re-run | MERGE upsert not working | Verify `row_hash` column is non-null; check for null values in hash-key source fields |
| `MV_001` shows no events for WH Ireland | Validation notebook not run, or `MV_001` disabled | Check `rules_config.json` has `"enabled": true` for `MV_001`; re-run `nb_validate` |
