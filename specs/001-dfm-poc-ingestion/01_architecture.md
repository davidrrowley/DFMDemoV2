# 01 - Architecture

## Logical Pipeline

1. Stage 1: discover and persist source rows to `source_dfm_raw`.
2. Stage 2: adapter-profile standardization to `individual_dfm_consolidated`.
3. Stage 2 gate: execute controls and write `dq_results` + `dq_exception_rows`.
4. Stage 3: publish gate-passing rows to `aggregated_dfms_consolidated`.
5. Project downstream outputs: `policy_aggregates` and `tpir_load_equivalent`.

## Design Principle

DFM/file-type variation is configuration-led through adapter profiles. Shared downstream logic remains DFM-agnostic.

## Folder Structure

```text
/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/*
/Files/config/*
/Files/output/period=YYYY-MM/run_id=<run_id>/*
```

## Notebook Responsibilities

| Notebook | Purpose |
|---|---|
| `nb_run_all` | Entrypoint and stage orchestration |
| `nb_ingest_brown_shipley` | Stage 1 + Stage 2 adapter execution for Brown Shipley |
| `nb_ingest_wh_ireland` | Stage 1 + Stage 2 adapter execution for WH Ireland |
| `nb_ingest_pershing` | Stage 1 + Stage 2 adapter execution for Pershing |
| `nb_ingest_castlebay` | Stage 1 + Stage 2 adapter execution for Castlebay |
| `nb_validate` | Gate checks and exception outputs |
| `nb_aggregate` | Stage 3 consolidation and output projection |
| `nb_reports` | Reconciliation and run reporting |

## Stage Gate Policy

- Stage 1 gate: parse and persistence complete, with diagnostics captured.
- Stage 2 gate: required controls evaluated and persisted.
- Stage 3 gate: publish blocked for rows that fail required severity rules.
