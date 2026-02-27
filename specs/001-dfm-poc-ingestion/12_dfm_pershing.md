# 12 — DFM: Pershing

## Inputs

| File | Role |
|------|------|
| `Positions.csv` | Primary positions (Credo-like) |
| `PSL_Valuation_Holdings_YYYYMMDD_*.csv` | Secondary / backfill |

## Positions.csv Mapping (primary)

| Canonical Column | Source Column | Notes |
|------------------|---------------|-------|
| `policy_id` | `AccountNumber` | Fallback: `PortfolioNumber` |
| `report_date` | `ReportDate` | Fallback: `PositionDate` |
| `isin` | `ISIN` | |
| `holding` | `Quantity` | |
| `local_bid_price` | `Price` | |
| `local_currency` | `LocalCurrencyISO` | |
| `bid_value_local` | `MarketValue` | |
| `bid_value_gbp` | See GBP rules below | |
| `accrued_interest_gbp` | See GBP rules below | |

### GBP Rules for Positions.csv

1. If `ReportingMarketValueISO == GBP` → `bid_value_gbp = ReportingMarketValue`
2. Else if `LocalCurrencyISO == GBP` → `bid_value_gbp = MarketValue`
3. Else if `FXRate` present and reporting currency is GBP → `bid_value_gbp = MarketValue * FXRate` (flag `FX_RATE_ASSUMED`)
4. Else → `bid_value_gbp = null`, flag `FX_NOT_AVAILABLE`

(Same logic applied to accrued interest.)

## Valuation Holdings Mapping (secondary/backfill)

| Canonical Column | Source Column |
|------------------|---------------|
| `policy_id` | `PSLAccountReference` |
| `report_date` | `ValueDate` |
| `holding` | `Holding` |
| `local_bid_price` | `Price` |
| `bid_value_local` | `Value` |
| `local_currency` | `CCYOfTheAsset` |
| `accrued_interest_local` | `AccruedInterest` |

GBP conversion: only if `CCYOfTheAsset == GBP` or FX rate available.

## De-duplication and Precedence

- Apply row-hash de-duplication within each file role
- Prefer `Positions.csv` rows; backfill missing policies/values from valuation holdings
- A policy present in `Positions.csv` is NOT backfilled from valuation holdings
