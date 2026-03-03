# Fabric Notebook Migration Plan

## Goal

Align Fabric notebooks with the updated stage contracts:

1. Stage 1: `source_dfm_raw`
2. Stage 2: `individual_dfm_consolidated`
3. Stage 3: `aggregated_dfms_consolidated`

## Migration Strategy

- Preserve downstream compatibility (`tpir_load_equivalent`) during transition.
- Migrate notebook responsibilities by stage, not by one-off workbook logic.
- Keep DFM-specific behavior in profile config.

## Notebook Changes

### `nb_setup.ipynb`

- Create stage contract tables (`source_dfm_raw`, `individual_dfm_consolidated`, `aggregated_dfms_consolidated`).
- Keep existing tables during transition if needed for compatibility.
- Ensure `dq_results` and `dq_exception_rows` exist and include stage context.

### `nb_ingest_wh_ireland.ipynb`
### `nb_ingest_pershing.ipynb`
### `nb_ingest_castlebay.ipynb`
### `nb_ingest_brown_shipley.ipynb`

- Split behavior logically:
  - Stage 1 raw persistence to `source_dfm_raw`.
  - Stage 2 standardization to `individual_dfm_consolidated`.
- Use profile metadata from `raw_parsing_config.json`.
- Emit identifier decision metadata and include/remove outcomes.

### `nb_validate.ipynb`

- Evaluate gate checks against Stage 2 rows.
- Write aggregated outcomes to `dq_results`.
- Write failing row pointers to `dq_exception_rows`.
- Enforce publish-block logic by severity.

### `nb_aggregate.ipynb`

- Read Stage 2 gate-passing rows only.
- Build `aggregated_dfms_consolidated`.
- Project `policy_aggregates` and `tpir_load_equivalent`.

### `nb_reports.ipynb`

- Update report sources to Stage 3 and gate outputs.
- Include stage-level run summaries and exception counts.

### `nb_run_all.ipynb`

- Orchestrate explicit stage progression.
- Track stage-level status in `run_audit_log`.
- Continue fault isolation per DFM/profile.

## Validation Gates for Migration

1. Schema gate
- New stage tables match `contracts/schemas.yaml`.

2. Data gate
- Stage 1 row counts align with landed source rows.
- Stage 2 includes required provenance and decision metadata.

3. Publish gate
- Stage 3 excludes blocked rows and includes only approved records.

4. Compatibility gate
- `tpir_load_equivalent` remains unchanged for downstream consumers.

5. Regression gate
- Existing report outputs remain available and consistent.

## Rollout Sequence

1. Apply `nb_setup.ipynb` schema updates.
2. Migrate one DFM adapter end-to-end (WH Ireland baseline).
3. Migrate remaining DFM adapters.
4. Switch validation and aggregation to stage contracts.
5. Run full period regression and sign-off.
