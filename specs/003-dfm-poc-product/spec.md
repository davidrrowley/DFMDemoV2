# DFM PoC Ingestion — Product Spec

**Product:** DFM PoC Ingestion Platform  
**Product folder:** `specs/003-dfm-poc-product/`  
**Feature folder:** `specs/002-dfm-poc-ingestion/`  
**Status:** Draft  
**Owner:** `app-python`

---

## Objective

Build a fast, auditable Proof of Concept that replaces manual Excel-based DFM reconciliation with
an automated Microsoft Fabric pipeline. The pipeline ingests raw confirmation inputs from four
Discretionary Fund Managers (Brown Shipley, WH Ireland, Pershing, Castlebay), transforms them into
a canonical holdings dataset, runs centralised validations, and produces policy-level aggregates and
reports equivalent to the existing Excel Rec_Output templates.

---

## Context

Investment operations teams currently ingest DFM data by manually copying and reformatting files
from four DFMs into Excel workbooks. This process is:
- **Time-consuming:** Monthly reconciliation requires significant manual effort per DFM.
- **Error-prone:** Different numeric conventions (UK/US vs European), date formats, and column names
  create mapping errors.
- **Non-auditable:** No automated record of which files were used, how values were transformed, or
  which rows were excluded.

The PoC demonstrates that an automated, auditable pipeline is achievable within the two-evening
budget using Microsoft Fabric and AI-assisted development.

---

## Success Criteria

A PoC run for a single period (`YYYY-MM`) is considered successful when:

| # | Criterion |
|---|---|
| SC-01 | `nb_run_all` completes for one period without unrecoverable errors |
| SC-02 | `canonical_holdings` contains row-level data for all four DFMs |
| SC-03 | `tpir_load_equivalent` schema matches the existing tpir_load contract |
| SC-04 | `policy_aggregates` totals are comparable to Excel Rec_Output for all four DFMs |
| SC-05 | `MV_001` is evaluable for WH Ireland, Pershing, and Castlebay |
| SC-06 | `report1_<dfm_id>.csv` exists for all four DFMs in the output folder |
| SC-07 | `report2_rollup.csv` and `reconciliation_summary.json` exist in the output folder |
| SC-08 | `run_audit_log` has one row per DFM with correct status and row counts |
| SC-09 | Re-running the same period does not duplicate `canonical_holdings` rows |
| SC-10 | Disabling one DFM in `dfm_registry.json` does not break the run for other DFMs |

---

## Key Constraints

| Constraint | Value |
|---|---|
| Time budget | 2 evenings maximum |
| Platform | Microsoft Fabric (PySpark notebooks + Delta Lake) |
| Development approach | AI-assisted (GitHub Copilot); finance calculations human-reviewed |
| Finance calculation determinism | Must be deterministic; no AI-generated arithmetic in production paths |
| Out of scope | Production ops, CI/CD, bank holiday calendars, full Excel template replacement |

---

## Platform

- **Compute:** Microsoft Fabric — PySpark Notebooks
- **Storage:** Microsoft Fabric Lakehouse (OneLake + Delta Lake)
- **Orchestration:** `nb_run_all` notebook with optional Fabric Pipeline wrapper
- **Config:** JSON files in `/Files/config/` on OneLake

---

## Feature Catalogue

| Feature | Description | Owner | Spec |
|---|---|---|---|
| F01 — DFM Ingestion Pipeline | File discovery, parsing, normalisation, GBP conversion, de-duplication → `canonical_holdings` | `app-python` | `specs/002-dfm-poc-ingestion/` |
| F02 — Validation Engine | DATE_001, MV_001, VAL_001, MAP_001 → `validation_events` | `app-python` | `specs/002-dfm-poc-ingestion/05_validations.md` |
| F03 — Aggregation & Output | `policy_aggregates`, `tpir_load_equivalent`, Report 1, Report 2, recon summary | `app-python` | `specs/002-dfm-poc-ingestion/06_outputs_and_reports.md` |
| F04 — Audit & Governance | `run_audit_log`, `parse_errors`, `schema_drift_events` | `app-python` | `specs/002-dfm-poc-ingestion/07_audit_and_recon.md` |

---

## Delta Tables Produced

| Table | Type | Purpose |
|---|---|---|
| `canonical_holdings` | Delta (partitioned by period, dfm_id) | Normalised row-level holdings |
| `tpir_load_equivalent` | Delta | Output matching tpir_load contract |
| `policy_aggregates` | Delta | Cash/bid/accrued totals by DFM + policy |
| `validation_events` | Delta | Rule evaluation results |
| `run_audit_log` | Delta | Per-DFM per-run audit row |
| `schema_drift_events` | Delta | Schema changes in source files |
| `parse_errors` | Delta | Row-level parse failures |

---

## Spec-Kit Documents (this product folder)

| File | Description |
|---|---|
| [product-vision.md](product-vision.md) | Problem space, target users, desired outcome |
| [architecture.md](architecture.md) | Logical pipeline, notebooks, folder structure, design principles |
| [data-model.md](data-model.md) | Delta table schemas, validation rules, relationships |
| [high-level-requirements.md](high-level-requirements.md) | Functional and non-functional requirements (HR-01 to HR-09) |
| [feature-map.md](feature-map.md) | Feature boundaries, ownership, requirement mapping |
| [roadmap.md](roadmap.md) | Phase-based delivery sequencing |
| [nfr.md](nfr.md) | Non-functional requirements detail |
| [security-baseline.md](security-baseline.md) | PoC threat model and security controls |
| [tasks.md](tasks.md) | High-level product tasks |
| [quickstart.md](quickstart.md) | How to run the PoC |
| [research.md](research.md) | Design decision notes |
| [checklists/requirements.md](checklists/requirements.md) | Specification quality checklist |

## Feature Folder

| Folder | Description |
|---|---|
| [specs/002-dfm-poc-ingestion/](../002-dfm-poc-ingestion/) | All four feature specs, DFM mappings, config definitions |
