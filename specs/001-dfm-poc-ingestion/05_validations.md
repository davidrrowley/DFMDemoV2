# 05 — Validations

## Validation Philosophy

- Deterministic rules
- Rules are "evaluable if fields exist"
- If not evaluable, record `status = not_evaluable` with reason in `details_json`

## Rules Baseline (PoC)

### DATE_001 — Stale report date (weekend-only)

**Severity**: warning

Warn if `report_date > month_end + 5 working days` (weekend-only calendar).

Evaluability: requires `report_date` to be non-null.

---

### MV_001 — MV recalculation

**Severity**: exception

Evaluable if `holding`, `local_bid_price`, and `bid_value_gbp` are all non-null (and `fx_rate` where needed).

Compute: `computed_mv = holding * local_bid_price * fx_rate`

Fail if:
```
abs(computed_mv - bid_value_gbp) > tolerance_abs_gbp
OR
abs(computed_mv - bid_value_gbp) / bid_value_gbp > tolerance_pct
```

(Use whichever is triggered first.)

**Threshold**: `tolerance_pct` **must be set to `0.02` (2%)** in `rules_config.json`. This matches the 98–102% operational check performed in the original Excel process. The value `0.001` (0.1%) used in earlier drafts was a documentation error.

`details_json` must include `computed_mv`, `reported_mv`, `abs_diff`, `pct_diff`.

---

### VAL_001 — No cash and/or no stock value (policy-level)

**Severity**: exception

Evaluated at `policy_aggregates` level.

Fail if `total_cash_value_gbp == 0 AND total_bid_value_gbp == 0`.

---

### POP_001 — Missing IH policy mapping

**Severity**: exception  
**Default**: enabled

If `policy_mapping.csv` is provided:
- Emit `fail` if DFM policy cannot map to any row in `policy_mapping.csv`.
- Emit `warning` if DFM policy maps to a row with `status = REMOVE` (ingested but excluded from `tpir_load_equivalent`).
- Emit `not_evaluable` if `policy_mapping.csv` is absent.

**Resolution workflow** (when POP_001 `fail` fires):

1. Identify the failing `(dfm_id, policy_id)` from `validation_events`.
2. Check the policy reference against the current IH Report in Spice: confirm whether the policy exists.
3. If **policy exists in Spice**: verify the DFM reference exactly matches the Spice reference (watch for leading zeros, format differences). If a mismatch is found, add a mapping row to `policy_mapping.csv` with `status = ACTIVE`.
4. If **policy does not exist in Spice**: flag to the DFM for investigation. Do not add to `policy_mapping.csv` until resolved.
5. If **policy is a known terminated exception**: add with `status = REMOVE`. The row will be excluded from `tpir_load_equivalent` but retained in `canonical_holdings`.
6. Re-upload `policy_mapping.csv` and re-run the pipeline for the affected period.

See `14_config_inputs.md` for the `policy_mapping.csv` schema and full maintenance guidance.

---

### MAP_001 — Unmapped securities

**Severity**: exception

MAP_001 is evaluated **after** the security master enrichment step (see `14_config_inputs.md` for the enrichment join logic). A row reaching MAP_001 means it was not resolved by the `security_master.csv` join.

PoC proxy rule applied at row level:
- If `security_id` is null/missing AND `bid_value_gbp < residual_cash_threshold_gbp` → classify as residual cash (flag, not fail)
- If `security_id` is null/missing AND `bid_value_gbp >= residual_cash_threshold_gbp` → exception

**Resolution workflow** (when MAP_001 exception fires):

1. Identify the failing row from `validation_events` — note the `dfm_id`, `policy_id`, and any partial identifiers (SEDOL, asset name) present in `details_json`.
2. Look up the security details using the available identifier (Bloomberg, Google Finance, or the DFM's fund factsheet).
3. Add a new row to the ISIN Master List workbook with `isin`, `sedol`, `asset_name`, `asset_class`, and `currency_iso`.
4. Re-export the workbook as `security_master.csv` and upload to `/Files/config/security_master.csv`.
5. Re-run the pipeline for the affected period.
6. Confirm MAP_001 no longer fires for that security.

See `14_config_inputs.md` for the `security_master.csv` schema and full maintenance guidance.

---

## Configuration

All rules and thresholds are parameterised in `config/rules_config.json`. Rules can be individually enabled/disabled.

## Output Schema

All events written to `validation_events`. See `02_data_contracts.md` for full schema.
