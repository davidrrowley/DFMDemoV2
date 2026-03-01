# 16 — ADS Loading

## Purpose

ADS (Asset Data Store) is the downstream authoritative repository that consumes the `tpir_load_equivalent` dataset each period. Loading to ADS is the final step of the pipeline — the automated equivalent of "Load to ADS" in the original Excel process.

ADS loading is gated: `nb_ads_load` only executes if `nb_tpir_check` has produced a `tpir_check_result.json` with `status: passed` for the current `run_id`. See `15_tpir_upload_checker.md` for the gating logic.

---

## Target System

**System**: ADS (Asset Data Store)  
**Protocol**: REST API (HTTPS)  
**API spec**: `apps/api/openapi.yaml`  
**Base URL**: Configured in `/Files/config/ads_config.json`  
**Authentication**: Bearer token from Azure Managed Identity (no secrets in notebook code)

---

## Config File: `ads_config.json`

Location: `/Files/config/ads_config.json`

```json
{
  "base_url": "https://ads.internal.example.com",
  "api_version": "v1",
  "batch_size": 500,
  "timeout_seconds": 60,
  "retry_max_attempts": 3,
  "retry_backoff_seconds": 5
}
```

`base_url` is environment-specific. In the PoC environment this points to the ADS staging endpoint.

---

## Notebook: `nb_ads_load`

**Location**: `notebooks/dfm_poc_ingestion/nb_ads_load`

**Inputs**:
- `tpir_load_equivalent` Delta table (filtered to current `run_id`)
- `/Files/output/period=YYYY-MM/run_id=<run_id>/tpir_check_result.json` (must exist with `status: passed`)
- `/Files/config/ads_config.json`

**Outputs**:
- Updates `run_audit_log` with `ads_load_status`, `ads_load_rows`, `ads_load_completed_at`

**Invocation context**: Called by `nb_run_all` after `nb_tpir_check`; never invoked standalone in production.

---

## API Contract

The ADS ingest endpoint is:

```
POST /api/v1/tpir/load
```

Full schema is defined in `apps/api/openapi.yaml`.

### Request

Content-Type: `application/json`

The request body is a JSON object carrying the `run_id`, `period`, and the `records` array:

```json
{
  "run_id": "2026-01-15T09:32:00Z",
  "period": "2025-12",
  "source": "dfm_poc_pipeline",
  "records": [
    {
      "Policyholder_Number": "001234560",
      "Security_Code": "LG001",
      "ISIN": "GB0031348658",
      "Other_Security_ID": null,
      "ID_Type": "ISIN",
      "Asset_Name": "Legal & General UK Index",
      "Acq_Cost_in_GBP": null,
      "Cash_Value_in_GBP": 0.00,
      "Bid_Value_in_GBP": 12543.21,
      "Accrued_Interest": 0.00,
      "Holding": 1250.000,
      "Loc_Bid_Price": 10.0346,
      "Currency_Local": "GBP"
    }
  ]
}
```

Records are sent in batches of `batch_size` (configured in `ads_config.json`). Each batch is a separate POST request.

### Response

```json
{
  "run_id": "2026-01-15T09:32:00Z",
  "batch_index": 0,
  "rows_accepted": 500,
  "status": "accepted"
}
```

**`status` values**:
- `accepted` — batch processed successfully
- `partial` — some rows rejected; see `rejected_rows` array
- `rejected` — entire batch rejected; see `error` field

### Status Check (polling)

```
GET /api/v1/tpir/load/{run_id}
```

Returns final load status once ADS has committed the data:

```json
{
  "run_id": "2026-01-15T09:32:00Z",
  "period": "2025-12",
  "total_rows_accepted": 1842,
  "total_rows_rejected": 0,
  "status": "committed",
  "committed_at": "2026-01-15T09:48:22Z"
}
```

---

## Load Logic

```python
# Pseudocode — see nb_ads_load for full implementation

check_tpir_result(period, run_id)          # raises if status != passed

rows = spark.read.table("tpir_load_equivalent") \
             .filter(f"run_id = '{run_id}'") \
             .toPandas().to_dict("records")

for batch in chunked(rows, batch_size):
    response = post_with_retry(
        url=f"{base_url}/api/v1/tpir/load",
        payload={"run_id": run_id, "period": period, "source": "dfm_poc_pipeline", "records": batch},
        retries=retry_max_attempts,
        backoff=retry_backoff_seconds
    )
    assert response["status"] in ("accepted", "partial")

final_status = poll_load_status(run_id, timeout=300)

update_audit_log(
    run_id=run_id,
    ads_load_status=final_status["status"],   # committed | failed
    ads_load_rows=final_status["total_rows_accepted"],
    ads_load_completed_at=final_status["committed_at"]
)
```

---

## Audit Log Extensions

The `run_audit_log` table gains three new columns to track the ADS load outcome:

| Column | Type | Description |
|--------|------|-------------|
| `ads_load_status` | string | `committed`, `failed`, `skipped_tpir_check_failed`, `skipped_no_rows` |
| `ads_load_rows` | long | Number of rows accepted by ADS |
| `ads_load_completed_at` | timestamp | When ADS confirmed commitment |

These columns are nullable on existing rows (written as null for runs before this feature is enabled).

---

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| `tpir_check_result.json` absent or `status != passed` | Raise; set `ads_load_status = skipped_tpir_check_failed`; do not call ADS |
| HTTP 4xx from ADS (client error) | Raise immediately; set `ads_load_status = failed`; do not retry |
| HTTP 5xx from ADS (server error) | Retry up to `retry_max_attempts` with exponential backoff; then raise and set `ads_load_status = failed` |
| `partial` response (some rows rejected) | Log rejected rows to parse_errors; continue remaining batches; final status reflects partial load |
| Timeout waiting for `committed` status | Set `ads_load_status = failed`; emit alert to `run_audit_log` |

---

## Idempotency

ADS must implement run-level idempotency: a second POST for the same `run_id` must be a no-op (return `accepted` with `rows_accepted=0` and the original counts). This prevents double-loading if `nb_ads_load` is re-run after a partial failure.

The pipeline itself does not need to track this — ADS owns idempotency at the `run_id` level.
