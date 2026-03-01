# 15 — TPIR Upload Checker

## Purpose

The TPIR Upload Checker is the pre-ADS quality gate. It validates that `tpir_load_equivalent` is structurally complete and free of blocking data issues before the payload is submitted to ADS. This is the automated equivalent of the manual "Run TPIR Upload Checker" step in the original Excel process.

The checker runs as a dedicated notebook (`nb_tpir_check`) invoked by `nb_run_all` after `nb_aggregate` completes and before `nb_ads_load` is called. If any blocking rule fails, ADS loading is suppressed for that run.

---

## Notebook: `nb_tpir_check`

**Location**: `notebooks/dfm_poc_ingestion/nb_tpir_check`

**Inputs**: `tpir_load_equivalent` Delta table (filtered to current `run_id`)

**Outputs**: `tpir_check_result.json` written to `/Files/output/period=YYYY-MM/run_id=<run_id>/`

**Side effects**: Appends a `tpir_check` row to `run_audit_log` with `status = TPIR_CHECK_PASSED` or `TPIR_CHECK_FAILED`

---

## Check Rules

### TC-001 — Schema completeness (blocking)

All 13 required columns must be present in `tpir_load_equivalent`:

```
Policyholder_Number, Security_Code, ISIN, Other_Security_ID, ID_Type,
Asset_Name, Acq_Cost_in_GBP, Cash_Value_in_GBP, Bid_Value_in_GBP,
Accrued_Interest, Holding, Loc_Bid_Price, Currency_Local
```

**Fail condition**: Any column missing or renamed.

**Severity**: blocking

---

### TC-002 — Non-empty dataset (blocking)

`tpir_load_equivalent` must contain at least one row for the current `run_id`.

**Fail condition**: Zero rows.

**Severity**: blocking

---

### TC-003 — Policyholder_Number not null (blocking)

`Policyholder_Number` must be non-null for every row.

**Fail condition**: Any row where `Policyholder_Number IS NULL`.

Emit count of failing rows in `tpir_check_result.json`.

**Severity**: blocking

---

### TC-004 — Bid_Value_in_GBP not null for non-cash rows (blocking)

For rows where `ID_Type != 'CASH'`, `Bid_Value_in_GBP` must be non-null.

**Fail condition**: Any non-cash row where `Bid_Value_in_GBP IS NULL`.

Emit count of failing rows and a sample of `Policyholder_Number` values.

**Severity**: blocking

---

### TC-005 — Currency_Local is a valid ISO-4217 code (blocking)

`Currency_Local` must be a 3-character uppercase string. Validated against the fixed list of known codes (`GBP`, `USD`, `EUR`, `CHF`, `JPY`, `SEK`, `NOK`, `DKK`, `AUD`, `CAD`, `HKD`, `SGD`) plus any codes present in `fx_rates.csv`.

**Fail condition**: Any row where `Currency_Local` does not match the valid code list.

Emit count of failing rows and the distinct unknown currency values.

**Severity**: blocking

---

### TC-006 — No REMOVE-status policies in output (warning)

Rows whose policy appears in `policy_mapping.csv` with `status = REMOVE` must not appear in `tpir_load_equivalent`.

**Fail condition**: Any row where the `(dfm_id, Policyholder_Number)` tuple is marked `REMOVE` in `policy_mapping.csv` (if file is present).

**Severity**: warning (does not block ADS load)

---

### TC-007 — Row count matches canonical_holdings (warning)

The row count of `tpir_load_equivalent` for this `run_id` must equal the row count of `canonical_holdings` for the same `run_id`.

**Fail condition**: Counts differ by more than 0 rows.

**Severity**: warning (projection issue; does not block ADS load but must be investigated)

---

## Output: `tpir_check_result.json`

Written to `/Files/output/period=YYYY-MM/run_id=<run_id>/tpir_check_result.json`.

```json
{
  "run_id": "2026-01-15T09:32:00Z",
  "period": "2025-12",
  "checked_at": "2026-01-15T09:45:12Z",
  "rows_checked": 1842,
  "status": "passed",
  "blocking_failures": [],
  "warnings": [
    {
      "rule": "TC-007",
      "message": "tpir_load_equivalent row count (1842) differs from canonical_holdings (1842) — counts match",
      "count": 0
    }
  ]
}
```

**`status` values**:
- `passed` — no blocking failures; ADS load may proceed
- `failed` — one or more blocking rules failed; ADS load is suppressed

On `failed`, the `blocking_failures` array contains one entry per failed rule:

```json
{
  "rule": "TC-003",
  "message": "Policyholder_Number is null for 3 rows",
  "count": 3,
  "sample": ["(null)", "(null)", "(null)"]
}
```

---

## Integration with `nb_run_all`

In `nb_run_all`, after `nb_aggregate` completes:

```python
nb_tpir_check.run(period=period, run_id=run_id)
result = load_json(f"/Files/output/period={period}/run_id={run_id}/tpir_check_result.json")

if result["status"] == "passed":
    nb_ads_load.run(period=period, run_id=run_id)
else:
    log.warning(f"TPIR check failed for run {run_id}; ADS load suppressed. Failures: {result['blocking_failures']}")
    update_audit_log(run_id=run_id, ads_load_status="skipped_tpir_check_failed")
```

---

## Configuration

TPIR check rules are configured in `config/rules_config.json` under the `tpir_check` key:

```json
{
  "tpir_check": {
    "TC-001": { "enabled": true },
    "TC-002": { "enabled": true },
    "TC-003": { "enabled": true },
    "TC-004": { "enabled": true },
    "TC-005": { "enabled": true },
    "TC-006": { "enabled": true },
    "TC-007": { "enabled": true }
  }
}
```

All rules are enabled by default. Individual rules may be disabled (e.g. TC-005 during initial PoC if currency codes are not yet fully populated).
