# Tasks: DFM PoC - Ingestion Standardisation

**Feature**: `001-dfm-poc-ingestion`  
**Owner**: `app-python`

## T001 - Stage contracts baseline

owner: app-python

Define Stage 1/2/3 contracts in setup and schema docs.

acceptance:
- Stage contracts are documented and internally consistent
- Required provenance and decision fields are included

validate:
- Review `specs/000-dfm-poc-product/data-model.md`
- Review `specs/001-dfm-poc-ingestion/02_data_contracts.md`

---

## T002 - Adapter profile metadata

owner: app-python

Extend DFM registry and parsing config to support multi-file profile behavior and readiness flags.

acceptance:
- `dfm_registry.json` includes profile and stage readiness metadata
- `raw_parsing_config.json` includes identifier priority and mapping strategy fields

validate:
- Load configs as JSON without parse errors
- Confirm each existing DFM has at least one profile

---

## T003 - Stage 1 implementation readiness

owner: app-python

Define raw persistence requirements and diagnostics behavior.

acceptance:
- Stage 1 persistence contract is explicit
- Parse and drift diagnostics are mandatory

validate:
- Review `04_ingestion_framework.md`
- Confirm references to `source_dfm_raw`

---

## T004 - Stage 2 standardization readiness

owner: app-python

Define standardization logic boundaries and decision trace requirements.

acceptance:
- Stage 2 contract includes include/remove and identifier decision metadata
- Mapping sources and versions are represented

validate:
- Review `02_data_contracts.md`
- Review `data-model.md`

---

## T005 - Stage-gate validation pack

owner: app-python

Define required checks, severity policy, and publish-block behavior.

acceptance:
- Validation taxonomy includes Stage 1/2/3 gate semantics
- Publish-block behavior is defined by severity

validate:
- Review `05_validations.md`
- Confirm `dq_results` and `dq_exception_rows` outputs are specified

---

## T006 - Stage 3 consolidation readiness

owner: app-python

Define cross-DFM consolidation rules and downstream projection behavior.

acceptance:
- Stage 3 consumes gate-passing Stage 2 rows only
- `tpir_load_equivalent` compatibility remains explicit

validate:
- Review `01_architecture.md`
- Review `02_data_contracts.md`

---

## T007 - Notebook implementation plan handoff

owner: app-python

Prepare notebook change plan from updated stage contracts and config artifacts.

acceptance:
- Plan maps notebook changes to Stage 1/2/3 responsibilities
- Plan includes validation and regression checkpoints

validate:
- Cross-check plan against updated specs in `specs/000` and `specs/001`
