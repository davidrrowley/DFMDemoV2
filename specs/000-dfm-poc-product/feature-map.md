# Feature Map: DFM Ingestion and Standardisation Platform

> Scope: Maps requirements to stage-aligned features and ownership.

## Feature Catalogue

### F01 - Stage 1 Raw Ingestion

Purpose: Persist all source files and rows for each DFM and file type with provenance.

Includes:
- File discovery and classification by adapter profile
- Header and schema handling
- Parse diagnostics and drift detection
- Raw row persistence without business-field loss

Primary outputs:
- `source_dfm_raw`
- `parse_errors`
- `schema_drift_events`
- `run_audit_log`

### F02 - Stage 2 DFM Standardisation

Purpose: Convert each DFM profile into the `individual_dfm_consolidated` contract.

Includes:
- Mapping and type coercion
- Identifier selection priority
- Policy mapping joins
- Include/remove decisions and reason codes
- Decision trace metadata

Primary outputs:
- `individual_dfm_consolidated`

### F03 - Validation and Gates

Purpose: Enforce deterministic controls before publication.

Includes:
- Rule execution by severity
- Stage-gate pass/fail determination
- Exception row capture
- Evaluable vs not-evaluable status tracking

Primary outputs:
- `dq_results`
- `dq_exception_rows`

### F04 - Stage 3 Consolidation and Publishing

Purpose: Build cross-DFM consolidated outputs from gate-passing Stage 2 rows.

Includes:
- Union and aggregation across DFMs
- Downstream output projection
- Cross-DFM controls and tie-out checks

Primary outputs:
- `aggregated_dfms_consolidated`
- `policy_aggregates`
- `tpir_load_equivalent`

### F05 - Governance and Operability

Purpose: Ensure each run is auditable and safe to operate at scale.

Includes:
- Run-state lineage across stages
- Stage-level counts and status
- Onboarding readiness checks for new profiles

Primary outputs:
- `run_audit_log`
- Report and reconciliation artifacts

## Boundary Rules

1. DFM-specific parsing logic is profile config, not downstream notebook logic.
2. Stage 2 standardisation does not publish to Stage 3 directly without gate outcomes.
3. Stage 3 only consumes rows that satisfy required gate severity rules.
4. All stages must preserve row-level provenance.
5. Onboarding new DFMs should be configuration-led.

## Dependency Order

1. F01 Stage 1 raw ingestion
2. F02 Stage 2 standardisation
3. F03 validation and gates
4. F04 Stage 3 consolidation and output projection
5. F05 governance and operational reporting
