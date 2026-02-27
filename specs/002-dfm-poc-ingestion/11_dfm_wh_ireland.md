# 11 — DFM: WH Ireland

## Input

| File | Role |
|------|------|
| Standard Life Valuation Data XLSX | Positions |

## Required Columns (confirmed)

- `Position as of Date`
- `Account Number`
- `ISIN`
- `Settled Quantity`
- `Display Price`
- `Settled Market Value (PC)`
- `Position Currency`
- `Position to Account Exchange Rate` (optional)
- `Settled Market Value (ABC)` and `Account Base Currency` (optional)

## Canonical Mapping

| Canonical Column | Source Column |
|------------------|---------------|
| `policy_id` | `Account Number` |
| `isin` | `ISIN` |
| `holding` | `Settled Quantity` |
| `local_bid_price` | `Display Price` |
| `bid_value_local` | `Settled Market Value (PC)` |
| `local_currency` | `Position Currency` |
| `report_date` | `Position as of Date` |
| `cash_value_gbp` | 0 (default, flag `CASH_DEFAULTED`) |
| `accrued_interest_gbp` | 0 (default, flag `ACCRUED_DEFAULTED`) |

## GBP Rules

Priority order:

1. If `Position Currency == GBP` → `bid_value_gbp = Settled Market Value (PC)`, `fx_rate = 1.0`
2. Else if `Account Base Currency == GBP` → `bid_value_gbp = Settled Market Value (ABC)`
3. Else if `Position to Account Exchange Rate` present → convert `Settled Market Value (PC)` using that rate
4. Else if `fx_rates.csv` available → convert using `Position Currency` rate
5. Else → `bid_value_gbp = null`, flag `FX_NOT_AVAILABLE`
