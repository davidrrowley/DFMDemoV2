# 10 — DFM: Brown Shipley

## Inputs

| File | Role |
|------|------|
| `Notification.csv` | Positions |
| `Notification - Cash.csv` | Cash |

## Parsing

- Header row detection required (header may not be on row 1)
- European decimals required (`european_decimals: true` in `raw_parsing_config.json`)

## Canonical Mapping

| Canonical Column | Source Column | Notes |
|------------------|---------------|-------|
| `policy_id` | `Client ID` | DFM-supplied identifier |
| `report_date` | `Value Date` | |
| `security_id` | `ISIN` | |
| `bid_value_local` | `Balance` | PoC assumption unless market value column exists |
| `accrued_interest_local` | `Accrued Interest` | |
| `cash_value_local` | `Accounting Balance` | From cash file |
| `local_currency` | (if present) | Assume GBP and flag if absent |

## GBP Rules

- If currency absent → assume GBP, `fx_rate = 1.0`, flag `CURRENCY_ASSUMED_GBP`
- If currency present and is GBP → `fx_rate = 1.0`
- If currency present and not GBP → join FX rates table if available; else `bid_value_gbp = null`, flag `FX_NOT_AVAILABLE`

## Notes

This is the hardest source. Acceptable PoC behaviour is to flag uncertainty rather than guess. MV_001 may be `not_evaluable` for many Brown Shipley rows if price data is absent.
