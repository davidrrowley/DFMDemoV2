# DFM PoC Ingestion — Spec

## Objective

Build a fast PoC that ingests raw confirmation inputs from four DFMs (Brown Shipley, WH Ireland, Pershing, Castlebay), transforms them into a canonical holdings dataset, produces a `tpir_load` equivalent dataset, runs centralised validations, and outputs policy-level aggregates equivalent to the Excel Rec_Output totals.

## Key Constraints

- Two evenings maximum
- AI-assisted development using Copilot
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

## Spec-Kit Documents

| File | Description |
|------|-------------|
| [00_overview.md](00_overview.md) | Objective, constraints, success criteria |
| [01_architecture.md](01_architecture.md) | Logical pipeline and implementation target |
| [02_data_contracts.md](02_data_contracts.md) | Canonical table schemas |
| [03_run_orchestration.md](03_run_orchestration.md) | Folder contracts and run behaviour |
| [04_ingestion_framework.md](04_ingestion_framework.md) | Common ingestion steps and parsing rules |
| [05_validations.md](05_validations.md) | Validation rules baseline |
| [06_outputs_and_reports.md](06_outputs_and_reports.md) | Report definitions |
| [07_audit_and_recon.md](07_audit_and_recon.md) | Audit log and reconciliation |
| [10_dfm_brown_shipley.md](10_dfm_brown_shipley.md) | Brown Shipley source mapping |
| [11_dfm_wh_ireland.md](11_dfm_wh_ireland.md) | WH Ireland source mapping |
| [12_dfm_pershing.md](12_dfm_pershing.md) | Pershing source mapping |
| [13_dfm_castlebay.md](13_dfm_castlebay.md) | Castlebay source mapping |

## Config Files

| File | Description |
|------|-------------|
| [config/dfm_registry.json](config/dfm_registry.json) | DFM identifiers and modes |
| [config/raw_parsing_config.json](config/raw_parsing_config.json) | Per-DFM parsing configuration |
| [config/rules_config.json](config/rules_config.json) | Validation rule thresholds |
| [config/currency_mapping.json](config/currency_mapping.json) | Currency description to ISO code mapping |

## Platform

Microsoft Fabric — one Lakehouse, PySpark notebooks, optional Pipeline wrapper.

## Owner

app-python
