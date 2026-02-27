# 01 — Architecture

## Logical Pipeline

1. Landing zone → discover files per DFM
2. Parse raw files → DFM staging
3. Map and normalise → `canonical_holdings`
4. Generate `tpir_load_equivalent`
5. Aggregate → `policy_aggregates`
6. Validate → `validation_events`
7. Produce reports + audit + recon artefacts

## Implementation Target (PoC)

Microsoft Fabric:

- One Lakehouse
- Notebooks (PySpark) for ingestion + validation + reporting
- Optional Pipeline wrapper

## Design Principle

DFM differences are isolated to extractor config and extractor functions. Everything after `canonical_holdings` is common.

## Folder Structure

```
/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/*
/Files/config/*
/Files/output/period=YYYY-MM/run_id=<run_id>/*
```

## Notebook Structure

| Notebook | Purpose |
|----------|---------|
| `nb_run_all` | Entrypoint; accepts `period` parameter; generates `run_id`; invokes DFM notebooks in sequence |
| `nb_ingest_brown_shipley` | Brown Shipley ingestion |
| `nb_ingest_wh_ireland` | WH Ireland ingestion |
| `nb_ingest_pershing` | Pershing ingestion |
| `nb_ingest_castlebay` | Castlebay ingestion |
| `nb_validate` | Validation rules engine |
| `nb_aggregate` | policy_aggregates + tpir_load_equivalent |
| `nb_reports` | Report 1 + Report 2 + reconciliation summary |

## Shared Library

Common functions extracted to a shared module:

- `parse_numeric(value, european=False)` — supports both UK/US and European decimal styles
- `parse_date(value)` — supports dd-MMM-yyyy, dd/MM/yyyy, ISO datetime, filename inference
- `apply_fx(local_value, local_currency, fx_rates)` — FX conversion to GBP
- `row_hash(df, cols)` — de-duplication hash
- `emit_validation_event(...)` — write to `validation_events`
- `emit_audit(dfm_id, run_id, ...)` — write to `run_audit_log`
