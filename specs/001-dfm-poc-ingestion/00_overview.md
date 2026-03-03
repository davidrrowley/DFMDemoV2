# 00 - Overview

## Objective

Implement a profile-driven ingestion feature that standardizes heterogeneous DFM source files into a stable contract and then consolidates across DFMs.

Target operating model:

1. `source DFM raw files`
2. `individual_dfm_consolidated`
3. `aggregated_dfms_consolidated`

## Scope

- Current PoC DFMs: Brown Shipley, WH Ireland, Pershing, Castlebay.
- Future scale target: up to 60 DFMs via adapter-profile config.
- Each DFM may provide one or more files per period with different formats.

## Success Criteria

- Stage 1: all discovered source rows are persisted with provenance and parse outcomes.
- Stage 2: each enabled DFM emits contract-conformant `individual_dfm_consolidated` rows.
- Stage 2 controls: deterministic checks are captured in `dq_results` and `dq_exception_rows`.
- Stage 3: only gate-passing Stage 2 rows are published to `aggregated_dfms_consolidated`.
- Downstream compatibility: `tpir_load_equivalent` remains contract-compatible.

## Out of Scope

- Full production hardening and CI/CD automation.
- Full workbook UX replication.
- Non-deterministic AI decisions in publish paths.

## Baseline Acceptance Checklist

- Config artifacts define DFM profile behavior (file role, parsing, mapping, identifier priority).
- Stage contracts are documented and versioned in `contracts/schemas.yaml`.
- One end-to-end period run completes across all enabled DFMs.
- Gate outcomes and exceptions are persisted and auditable.
- Consolidated outputs are generated from gate-approved records only.
