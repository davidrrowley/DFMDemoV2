# DFM PoC Ingestion — Implementation Plan

## Approach

All implementation targets Microsoft Fabric (PySpark notebooks + Delta Lake). DFM differences are isolated to extractor config and extractor functions. Everything after `canonical_holdings` is common.

## Phases

### Phase 1 — Foundation

- Create Fabric Lakehouse
- Create all Delta tables: `canonical_holdings`, `tpir_load_equivalent`, `policy_aggregates`, `validation_events`, `run_audit_log`, `schema_drift_events`, `parse_errors`
- Upload config files to `/Files/config/`
- Set up `nb_run_all` entrypoint notebook with `period` parameter and `run_id` generation

### Phase 2 — DFM Ingestion Notebooks

For each DFM (Brown Shipley, WH Ireland, Pershing, Castlebay):
- Discover and classify input files in `/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/`
- Parse raw files per DFM config (`raw_parsing_config.json`)
- Map fields to canonical schema (`canonical_holdings`)
- Apply currency normalisation and GBP computation
- Implement row-hash de-duplication
- Write to `canonical_holdings` Delta table
- Emit parse errors to `parse_errors`, schema drift to `schema_drift_events`

### Phase 3 — Validations

Implement rules from `rules_config.json`:
- `DATE_001` — stale report date check (weekend-only)
- `MV_001` — MV recalculation check (evaluable for WH Ireland, Pershing, Castlebay)
- `VAL_001` — policy-level no cash/stock check
- `MAP_001` — unmapped bonds / residual cash proxy

Write results to `validation_events`.

### Phase 4 — Aggregation and Outputs

- Compute `policy_aggregates` from `canonical_holdings` (grouped by period, run_id, dfm_id, policy_id)
- Produce `tpir_load_equivalent` with schema matching tpir_load contract
- Write Report 1 (per DFM) and Report 2 (roll-up) as CSVs to `/Files/output/`
- Write `reconciliation_summary.json`
- Update `run_audit_log` per DFM

## Design Principles

- DFM differences in config/extractor only; all downstream logic shared
- Continue across DFMs if one fails ingestion
- Emit audit for every DFM including "no files" cases
- Numeric parsing supports both UK/US (13,059.70) and European (3.479,29) styles
- Date parsing supports dd-MMM-yyyy, dd/MM/yyyy, ISO datetime, filename inference
