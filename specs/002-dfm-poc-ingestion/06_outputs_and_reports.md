# 06 — Outputs and Reports

## Outputs (Delta tables)

1. `tpir_load_equivalent` — schema defined in `02_data_contracts.md`
2. `policy_aggregates` — cash/bid/accrued totals by DFM + policy
3. `validation_events` — all rule results

## Reports (CSV in OneLake output folder)

Output path: `/Files/output/period=YYYY-MM/run_id=<run_id>/`

### Report 1 — Per DFM validation summary

Filename: `report1_<dfm_id>.csv`

Contents:
- Validation failures grouped by `policy_id` and `rule_id`
- Key numeric diffs for `MV_001` (computed_mv, reported_mv, abs_diff, pct_diff)
- `not_evaluable` counts by rule

Required columns:

| Column |
|--------|
| `dfm_id` |
| `policy_id` |
| `rule_id` |
| `severity` |
| `status` |
| `count` |
| `mv_computed` (nullable) |
| `mv_reported` (nullable) |
| `mv_abs_diff` (nullable) |
| `mv_pct_diff` (nullable) |

### Report 2 — Daily roll-up

Filename: `report2_rollup.csv`

Contents:
- Counts by DFM, rule, severity
- Top policies by exception count

Required columns:

| Column |
|--------|
| `dfm_id` |
| `rule_id` |
| `severity` |
| `status` |
| `count` |
| `top_policy_id` (nullable) |
| `top_policy_exception_count` (nullable) |
