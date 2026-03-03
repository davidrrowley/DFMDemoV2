# DFM PoC Ingestion — Product Spec

**Product:** DFM Ingestion and Standardisation Platform  
**Product folder:** `specs/000-dfm-poc-product/`  
**Feature folder:** `specs/001-dfm-poc-ingestion/`  
**Status:** Draft  
**Owner:** `app-python`

---

## Objective

Build an auditable ingestion and standardisation product for heterogeneous DFM inputs.

The core operating model is:

1. `source DFM raw files`
2. `individual_dfm_consolidated` template
3. `aggregated_dfms_consolidated` template

This PoC validates the model for four DFMs today and establishes a configuration-led pattern to onboard up to 60 DFMs without rewriting core pipeline logic.

---

## Context

Investment operations currently rely on manual workbook flows to normalize DFM files before reconciliation and downstream publication. The current process is:

- Time-consuming: repetitive monthly transformations per DFM.
- Error-prone: file format and heading differences vary by DFM and by file type.
- Hard to govern: no robust lineage for parsing, mapping, exclusion, and inclusion decisions.

Workbook logic still matters, but it now acts as one reference implementation of Stage 2 behavior, not the architecture for the full product.

---

## Stage Model

| Stage | Contract | Purpose |
|---|---|---|
| Stage 1 | `source DFM raw files` | Persist every supplied file and row with provenance; minimal assumptions |
| Stage 2 | `individual_dfm_consolidated` | Standardise each DFM into a shared canonical contract via adapter profiles |
| Stage 3 | `aggregated_dfms_consolidated` | Union and control across DFMs for downstream stability and reporting |

---

## Success Criteria

A PoC run for one period (`YYYY-MM`) is successful when all stage gates pass.

| # | Criterion |
|---|---|
| SC-01 | `nb_run_all` completes one period without unrecoverable orchestration error |
| SC-02 | Stage 1 persists all discovered files/rows for enabled DFMs with provenance |
| SC-03 | Stage 2 produces `individual_dfm_consolidated` for each enabled DFM using profile config only |
| SC-04 | Stage 2 contract includes required lineage and transformation-decision metadata |
| SC-05 | Stage 2 validation pack writes deterministic check outcomes and exception rows |
| SC-06 | Stage 3 produces `aggregated_dfms_consolidated` from gate-passing Stage 2 rows only |
| SC-07 | `tpir_load_equivalent` schema remains compatible with existing downstream contract |
| SC-08 | Policy-level totals are comparable to workbook outputs within agreed tolerance |
| SC-09 | `run_audit_log` includes one row per DFM with stage-level status and counts |
| SC-10 | Re-running the same period is idempotent (no duplicate Stage 2 rows) |
| SC-11 | Disabling one DFM or profile does not block other enabled DFMs |
| SC-12 | Onboarding a new DFM is achievable through registry + profile + mapping config updates |

---

## Key Constraints

| Constraint | Value |
|---|---|
| Time budget | 2 evenings maximum for initial PoC baseline |
| Platform | Microsoft Fabric (PySpark notebooks + Delta Lake) |
| Development approach | AI-assisted (GitHub Copilot); finance calculations human-reviewed |
| Deterministic finance logic | Required in all stage-gate and publication paths |
| Out of scope | Full production hardening, enterprise CI/CD, complete workbook UX replacement |

---

## Platform

- Compute: Microsoft Fabric PySpark notebooks
- Storage: Microsoft Fabric Lakehouse (OneLake + Delta Lake)
- Orchestration: `nb_run_all` with optional Fabric Pipeline wrapper
- Config: profile and rules metadata in `/Files/config/`

---

## Feature Catalogue

| Feature | Description | Owner | Spec |
|---|---|---|---|
| F01 — Adapter-Profile Ingestion | Stage 1 to Stage 2 standardisation by DFM/file-type profile | `app-python` | `specs/001-dfm-poc-ingestion/` |
| F02 — Validation and Gates | Deterministic controls and stage-gate outcomes | `app-python` | `specs/001-dfm-poc-ingestion/05_validations.md` |
| F03 — Consolidation and Outputs | Stage 3 aggregation and downstream projections | `app-python` | `specs/001-dfm-poc-ingestion/06_outputs_and_reports.md` |
| F04 — Audit and Governance | Run-level and row-level observability across all stages | `app-python` | `specs/001-dfm-poc-ingestion/07_audit_and_recon.md` |

---

## Core Tables

| Table | Type | Purpose |
|---|---|---|
| `source_dfm_raw` | Delta | Stage 1 normalized raw landing persistence with provenance |
| `individual_dfm_consolidated` | Delta | Stage 2 canonical contract per DFM |
| `aggregated_dfms_consolidated` | Delta | Stage 3 consolidated holdings across DFMs |
| `tpir_load_equivalent` | Delta | Downstream consumer contract projection |
| `policy_aggregates` | Delta | Policy-level cash/bid/accrued totals |
| `dq_results` | Delta | Stage-gate rule outcomes |
| `dq_exception_rows` | Delta | Failing row pointers and reason context |
| `run_audit_log` | Delta | Per-DFM per-run and per-stage audit state |
| `schema_drift_events` | Delta | Schema changes in source files |
| `parse_errors` | Delta | Row-level parse failures |

---

## Spec-Kit Documents (this product folder)

| File | Description |
|---|---|
| [product-vision.md](product-vision.md) | Problem space, target users, desired outcome |
| [architecture.md](architecture.md) | Stage architecture, notebook responsibilities, design principles |
| [data-model.md](data-model.md) | Stage contracts, schema model, and relationships |
| [high-level-requirements.md](high-level-requirements.md) | Functional and non-functional requirements |
| [feature-map.md](feature-map.md) | Feature boundaries and ownership |
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
| [specs/001-dfm-poc-ingestion/](../001-dfm-poc-ingestion/) | Detailed ingestion, validation, consolidation, and config contracts |
