# DFM PoC Design Document

**Version:** 2.0  
**Date:** 2026-03-03  
**Status:** Draft  
**Owner:** Investment Operations Technology

## 1. Executive Summary

This PoC is positioned as the first implementation of a broader ingestion and standardisation product. The target flow is:

`source DFM raw files -> individual_dfm_consolidated -> aggregated_dfms_consolidated`

This shifts scope from recreating one workbook to establishing reusable adapter-profile patterns for many DFMs and file types.

## 2. Problem Statement

DFM data arrives in heterogeneous formats and may include multiple files per DFM per period. Manual workbook processing is hard to scale and hard to audit. The solution must standardize diverse input shapes into one stable contract before consolidation.

## 3. Design Principles

1. Configuration-led standardisation over notebook-led branching.
2. Explicit stage contracts and stage-gate controls.
3. Full provenance and transformation decision traceability.
4. Stable downstream contracts despite source variability.

## 4. Stage Architecture

### Stage 1 - Source DFM raw files

- Persist all rows and files with provenance.
- Capture parse and schema-drift diagnostics.
- Avoid destructive assumptions.

### Stage 2 - Individual DFM consolidated template

- Apply adapter-profile mapping and coercion.
- Resolve identifiers by configured priority.
- Apply policy/security mapping and include/remove logic.
- Persist decision traces and data-quality flags.

### Stage 3 - Aggregated DFMs consolidated template

- Consume only gate-passing Stage 2 records.
- Produce consolidated holdings and downstream projections.
- Run cross-DFM controls before publish.

## 5. Governance and Controls

Core control outputs:

- `dq_results`
- `dq_exception_rows`
- `run_audit_log`
- `parse_errors`
- `schema_drift_events`

Severity-based publication policy:

- `stop`: always blocks publish.
- `exception`: blocks unless approved.
- `warning`: publish allowed with trace.

## 6. Workbook Logic Positioning

Workbook `Edited`, `Check`, and `tpir_load` behavior is preserved as a Stage 2 reference profile (starting with WH Ireland). It validates conformance but does not define the whole system architecture.

## 7. Scale Path

- Current scope: 4 DFMs.
- Target: up to 60 DFMs.
- Onboarding model: add profile config and mapping artifacts; avoid core notebook logic changes.

## 8. Next Step

Implement notebook changes from updated contracts and stage gates, with regression checks to ensure downstream compatibility.
