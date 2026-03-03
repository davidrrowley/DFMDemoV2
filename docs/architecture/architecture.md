# Architecture

## Overview

The platform is designed as an ingestion and standardisation product, not a single-workbook automation. The operating model is:

1. Source DFM raw files
2. Individual DFM consolidated template (`individual_dfm_consolidated`)
3. Aggregated DFMs consolidated template (`aggregated_dfms_consolidated`)

Workbook logic remains relevant as a Stage 2 profile behavior reference.

## Components

| Component | Responsibility |
|---|---|
| Landing zone (`/Files/landing/...`) | Raw source file intake per DFM/period |
| Config zone (`/Files/config/...`) | Adapter profiles, mapping rules, thresholds |
| Ingestion notebooks (`nb_ingest_*`) | Stage 1 persistence + Stage 2 standardization per profile |
| Validation notebook (`nb_validate`) | Stage gate checks and exception capture |
| Aggregation notebook (`nb_aggregate`) | Stage 3 consolidation and output projection |
| Reporting notebooks | Reconciliation and operational outputs |

## Stage contracts

| Stage | Logical output |
|---|---|
| Stage 1 | `source_dfm_raw` |
| Stage 2 | `individual_dfm_consolidated` |
| Stage 3 | `aggregated_dfms_consolidated` |

Control outputs:

- `dq_results`
- `dq_exception_rows`
- `run_audit_log`
- `parse_errors`
- `schema_drift_events`

## Gate policy

- Stage 1 gate confirms raw persistence and diagnostics.
- Stage 2 gate confirms contract conformance and required checks.
- Stage 3 publication only includes gate-passing Stage 2 rows.

## Adapter profile model

Each DFM can have one or more profiles and each profile can handle one or more file roles. Profiles are metadata-driven and define parser settings, mappings, identifier priority, and policy join behavior.

## Operational principles

- Preserve provenance from source row to published output.
- Keep deterministic calculations in all publish paths.
- Use config-led onboarding for new DFMs.
- Keep downstream consumer contracts stable (`tpir_load_equivalent`).
