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

`details_json` must include `computed_mv`, `reported_mv`, `abs_diff`, `pct_diff`.

---

### VAL_001 — No cash and/or no stock value (policy-level)

**Severity**: exception

Evaluated at `policy_aggregates` level.

Fail if `total_cash_value_gbp == 0 AND total_bid_value_gbp == 0`.

---

### POP_001 — Missing IH policy mapping (optional)

**Severity**: exception  
**Default**: disabled

If `policy_mapping.csv` is provided:
- Fail if DFM policy cannot map to IH policy.

---

### MAP_001 — Unmapped bonds / residual cash proxy (optional)

**Severity**: exception

PoC proxy rule applied at row level:
- If `security_id` is null/missing AND `bid_value_gbp < residual_cash_threshold_gbp` → classify as residual cash (flag, not fail)
- If `security_id` is null/missing AND `bid_value_gbp >= residual_cash_threshold_gbp` → exception

---

## Configuration

All rules and thresholds are parameterised in `config/rules_config.json`. Rules can be individually enabled/disabled.

## Output Schema

All events written to `validation_events`. See `02_data_contracts.md` for full schema.
