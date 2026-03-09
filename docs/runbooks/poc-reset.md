# PoC Reset Runbook

Use this runbook to reset Fabric PoC data to a clean state before rerunning ingestion end-to-end.

## Scope

Reset is implemented by `infra/fabric/notebooks/nb_poc_reset.ipynb`.

The notebook:
- Truncates core pipeline tables while preserving schemas.
- Optionally truncates Stage 1 raw landing tables.
- Optionally truncates AI-assist tables.
- Optionally drops reconciliation validation objects:
  - `vw_holdings_price_validation`
  - `holdings_price_validation`

It does not remove `/Files/config/*` reference inputs by default.

## Safety Gate

The notebook will only run destructive operations when:

- `confirmation_token = RESET_POC_DATA`

Any other value causes an immediate stop.

## How To Run

1. Open `infra/fabric/notebooks/nb_poc_reset.ipynb` in Fabric.
2. Set parameters in the first code cell:
   - `confirmation_token = "RESET_POC_DATA"`
   - `include_stage1_raw_tables = True` (recommended for full clean reset)
   - `include_ai_tables = True` (optional)
   - `drop_reconciliation_objects = True` (recommended)
3. Run all cells.
4. Confirm post-reset counts are zero in the final verification cell.
5. Run setup + ingestion again (`nb_setup_tables`, `nb_run_all`, validations).

## Post-Reset Checks

Run these checks in SQL to confirm clean state:

```sql
SELECT COUNT(*) AS c FROM individual_dfm_consolidated;
SELECT COUNT(*) AS c FROM aggregated_dfms_consolidated;
SELECT COUNT(*) AS c FROM tpir_load_equivalent;
SELECT COUNT(*) AS c FROM dq_results;
SELECT COUNT(*) AS c FROM dq_exception_rows;
SELECT COUNT(*) AS c FROM run_audit_log;
```

All should return `0` for a full reset.

## Notes

- This is for non-production PoC environments.
- Because reset uses `TRUNCATE TABLE`, table definitions remain in place for immediate reruns.
