# 07 — Audit and Reconciliation

## `run_audit_log`

One row per DFM per run. Written at the end of each DFM ingestion notebook and updated by `nb_run_all` once all DFMs complete.

Fields:

| Field | Description |
|-------|-------------|
| `run_id` | Run identifier |
| `period` | Period (YYYY-MM) |
| `dfm_id` | DFM identifier |
| `files_processed` | Number of source files discovered and processed |
| `rows_ingested` | Rows written to `canonical_holdings` |
| `parse_errors_count` | Rows written to `parse_errors` |
| `drift_events_count` | Rows written to `schema_drift_events` |
| `status` | `OK`, `NO_FILES`, `PARTIAL`, or `FAILED` |
| `started_at` | Ingestion start timestamp |
| `completed_at` | Ingestion end timestamp |

## `reconciliation_summary.json`

Written to `/Files/output/period=YYYY-MM/run_id=<run_id>/reconciliation_summary.json`.

Contents:
- Totals by DFM for `total_cash_value_gbp`, `total_bid_value_gbp`, `total_accrued_interest_gbp` from `policy_aggregates`
- Row counts by DFM from `canonical_holdings`
- Optional tie-out to expected totals file (if present in `/Files/config/`)

Example structure:

```json
{
  "run_id": "20251231T142300Z",
  "period": "2025-12",
  "generated_at": "2025-12-31T14:23:05Z",
  "dfm_summary": [
    {
      "dfm_id": "wh_ireland",
      "canonical_row_count": 1250,
      "total_cash_value_gbp": 0.0,
      "total_bid_value_gbp": 45231876.50,
      "total_accrued_interest_gbp": 0.0
    }
  ]
}
```
