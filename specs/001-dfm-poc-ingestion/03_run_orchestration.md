# 03 — Run Orchestration

## Folder Contracts (OneLake)

```
/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/*
/Files/config/*
/Files/output/period=YYYY-MM/run_id=<run_id>/*
```

## Run Entrypoint

Notebook `nb_run_all`, parameter: `period` (YYYY-MM format).

Generates `run_id` as UTC timestamp (e.g. `20251231T142300Z`).

## Run Behaviour

- Must continue across DFMs if one fails ingestion
- Must emit audit for every DFM, including "no files" cases
- DFM notebooks invoked in sequence; failures are caught, logged, and execution continues
- `run_id` is propagated to all child notebooks as a parameter

## Execution Order

1. Load config (`dfm_registry.json`, `rules_config.json`, etc.)
2. For each enabled DFM in `dfm_registry.json`:
   a. Invoke DFM-specific ingestion notebook
   b. Catch and log any failures
3. Invoke `nb_validate` (runs across all DFMs in one pass)
4. Invoke `nb_aggregate` (policy_aggregates + tpir_load_equivalent)
5. Invoke `nb_reports` (Report 1, Report 2, reconciliation summary)
6. Finalise `run_audit_log` for all DFMs

## Audit Status Values

| Status | Meaning |
|--------|---------|
| `OK` | All files processed, no errors |
| `NO_FILES` | No input files found for the period |
| `PARTIAL` | Some files processed; at least one parse error |
| `FAILED` | Notebook raised an unrecoverable exception |
