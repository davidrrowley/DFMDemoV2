# Data Model: DFM PoC - Ingestion Pipeline

> Note: Product-level stage contracts are authoritative in `specs/000-dfm-poc-product/data-model.md`.

This feature document captures implementation notes for Stage 1/2/3 schema usage.

## Stage 1 Implementation Notes

`source_dfm_raw` is append-first and provenance-complete. It keeps source payload fidelity for replay and debugging.

## Stage 2 Implementation Notes

`individual_dfm_consolidated` is the standardization contract. It includes:

- normalized financial fields
- identifier resolution metadata
- include/remove outcomes
- transformation decision trace

## Stage 3 Implementation Notes

`aggregated_dfms_consolidated` is built from gate-passing Stage 2 records only.

## Control Tables

- `dq_results`
- `dq_exception_rows`
- `run_audit_log`
- `parse_errors`
- `schema_drift_events`

## Compatibility

During migration, existing physical tables may coexist with these logical names. Notebook updates should prioritize preserving downstream output contracts while transitioning to stage contract names.
