# 00 — Overview

## Objective

Build a fast PoC that ingests raw confirmation inputs from four DFMs (Brown Shipley, WH Ireland, Pershing, Castlebay), transforms them into a canonical holdings dataset, produces a `tpir_load` equivalent dataset, runs centralised validations, and outputs policy-level aggregates equivalent to the Excel Rec_Output totals.

## Key Constraints

- Two evenings maximum
- AI-assisted development using Copilot is assumed
- Core finance calculations must be deterministic; AI may assist with drift detection and narrative only

## Out of Scope

- Full replacement of Excel templates in production
- Enterprise-grade ops (CI/CD, full alerting, retries)
- Bank holiday working day calendars (weekend-only PoC)

## Success Criteria

A single "run" produces:
- `canonical_holdings` (row-level)
- `tpir_load_equivalent` (standardised output schema)
- `policy_aggregates` (cash/bid/accrued totals by DFM+policy)
- `validation_events` (rule failures and not-evaluable records)
- Report 1 per DFM + Report 2 roll-up
- Audit + reconciliation summary

Output schema matches the templates' tpir_load contract. MV check is demonstrable for at least WH Ireland, Pershing, Castlebay (and Brown Shipley if feasible).

## Baseline Acceptance Checklist

- A repo folder with the specs above and config files created
- A Fabric Lakehouse with Delta tables: `canonical_holdings`, `tpir_load_equivalent`, `policy_aggregates`, `validation_events`, `run_audit_log`, `schema_drift_events`, `parse_errors`
- A single notebook run for one period that ingests: Brown Shipley Notification + Cash, WH Ireland XLSX, Pershing Positions + Valuation holdings, Castlebay XLSX
- `policy_aggregates` computed for all four DFMs
- `MV_001` implemented and evaluable for WH Ireland + Pershing + Castlebay
- Report 1 per DFM + Report 2 roll-up written to OneLake
