# Data Model: DFM PoC — Ingestion Pipeline

> **Note:** This feature implements the canonical data model defined at the product level.
> See [specs/000-dfm-poc-product/data-model.md](../000-dfm-poc-product/data-model.md) for the authoritative entity definitions, column-level schemas, and entity relationships.

This document covers feature-specific implementation notes: PySpark DDL, state machines, and ingestion-specific column behaviour that supplements the product-level schema.

---

## Delta Table DDL (PySpark Schema Definitions)

### `canonical_holdings`

```python
from pyspark.sql.types import (
    StructType, StructField, StringType, DecimalType,
    DateType, TimestampType, ArrayType, BooleanType
)

canonical_holdings_schema = StructType([
    StructField("period",                    StringType(),         nullable=False),
    StructField("run_id",                    StringType(),         nullable=False),
    StructField("dfm_id",                    StringType(),         nullable=False),
    StructField("dfm_name",                  StringType(),         nullable=False),
    StructField("source_file",               StringType(),         nullable=False),
    StructField("source_sheet",              StringType(),         nullable=True),
    StructField("source_row_id",             StringType(),         nullable=False),
    StructField("policy_id",                 StringType(),         nullable=False),
    StructField("policy_id_type",            StringType(),         nullable=False),  # "IH" or "DFM"
    StructField("dfm_policy_id",             StringType(),         nullable=True),
    StructField("security_id",               StringType(),         nullable=True),
    StructField("isin",                      StringType(),         nullable=True),
    StructField("other_security_id",         StringType(),         nullable=True),
    StructField("id_type",                   StringType(),         nullable=True),
    StructField("asset_name",                StringType(),         nullable=True),
    StructField("holding",                   DecimalType(28, 8),   nullable=False),
    StructField("local_bid_price",           DecimalType(28, 8),   nullable=False),
    StructField("local_currency",            StringType(),         nullable=False),
    StructField("fx_rate",                   DecimalType(28, 8),   nullable=True),
    StructField("cash_value_gbp",            DecimalType(28, 8),   nullable=False),
    StructField("bid_value_gbp",             DecimalType(28, 8),   nullable=True),
    StructField("accrued_interest_gbp",      DecimalType(28, 8),   nullable=False),
    StructField("report_date",               DateType(),           nullable=True),
    StructField("ingested_at",               TimestampType(),      nullable=False),
    StructField("row_hash",                  StringType(),         nullable=False),
    StructField("data_quality_flags",        ArrayType(StringType()), nullable=False),
])
# Partition by: period, dfm_id
```

### `tpir_load_equivalent`

```python
tpir_load_schema = StructType([
    StructField("Policyholder_Number",  StringType(),       nullable=False),
    StructField("Security_Code",        StringType(),       nullable=True),
    StructField("ISIN",                 StringType(),       nullable=True),
    StructField("Other_Security_ID",    StringType(),       nullable=True),
    StructField("ID_Type",              StringType(),       nullable=True),
    StructField("Asset_Name",           StringType(),       nullable=True),
    StructField("Acq_Cost_in_GBP",      DecimalType(28,8),  nullable=True),   # always null in PoC
    StructField("Cash_Value_in_GBP",    DecimalType(28,8),  nullable=False),
    StructField("Bid_Value_in_GBP",     DecimalType(28,8),  nullable=True),
    StructField("Accrued_Interest",     DecimalType(28,8),  nullable=False),
    StructField("Holding",              DecimalType(28,8),  nullable=False),
    StructField("Loc_Bid_Price",        DecimalType(28,8),  nullable=False),
    StructField("Currency_Local",       StringType(),       nullable=False),
    StructField("period",               StringType(),       nullable=False),
    StructField("run_id",               StringType(),       nullable=False),
    StructField("dfm_id",               StringType(),       nullable=False),
])
```

### `policy_aggregates`

```python
policy_aggregates_schema = StructType([
    StructField("period",                       StringType(),       nullable=False),
    StructField("run_id",                       StringType(),       nullable=False),
    StructField("dfm_id",                       StringType(),       nullable=False),
    StructField("dfm_name",                     StringType(),       nullable=False),
    StructField("policy_id",                    StringType(),       nullable=False),
    StructField("total_cash_value_gbp",         DecimalType(28,8),  nullable=False),
    StructField("total_bid_value_gbp",          DecimalType(28,8),  nullable=False),
    StructField("total_accrued_interest_gbp",   DecimalType(28,8),  nullable=False),
    StructField("row_count",                    IntegerType(),      nullable=False),
    StructField("computed_at",                  TimestampType(),    nullable=False),
])
# Grouping key: period, run_id, dfm_id, policy_id
```

### `validation_events`

```python
validation_events_schema = StructType([
    StructField("period",       StringType(),   nullable=False),
    StructField("run_id",       StringType(),   nullable=False),
    StructField("event_time",   TimestampType(),nullable=False),
    StructField("dfm_id",       StringType(),   nullable=False),
    StructField("dfm_name",     StringType(),   nullable=False),
    StructField("policy_id",    StringType(),   nullable=False),
    StructField("security_id",  StringType(),   nullable=True),
    StructField("rule_id",      StringType(),   nullable=False),
    StructField("severity",     StringType(),   nullable=False),  # stop|exception|warning
    StructField("status",       StringType(),   nullable=False),  # fail|not_evaluable
    StructField("details_json", StringType(),   nullable=False),
    StructField("source_file",  StringType(),   nullable=True),
])
```

### `run_audit_log`

```python
run_audit_log_schema = StructType([
    StructField("run_id",               StringType(),   nullable=False),
    StructField("period",               StringType(),   nullable=False),
    StructField("dfm_id",               StringType(),   nullable=False),
    StructField("files_processed",      IntegerType(),  nullable=False),
    StructField("rows_ingested",        IntegerType(),  nullable=False),
    StructField("parse_errors_count",   IntegerType(),  nullable=False),
    StructField("drift_events_count",   IntegerType(),  nullable=False),
    StructField("status",               StringType(),   nullable=False),
    StructField("started_at",           TimestampType(),nullable=False),
    StructField("completed_at",         TimestampType(),nullable=True),
])
```

---

## State Machine: `run_audit_log.status`

```
        ┌─────────┐
        │ PENDING │  (row created at DFM ingestion start)
        └────┬────┘
             │
             ↓
        ┌─────────┐
        │ RUNNING │  (ingestion notebook executing)
        └────┬────┘
             │
     ┌───────┼──────────────────┐
     │       │                  │
     ↓       ↓                  ↓
  ┌────┐  ┌─────────┐   ┌──────────┐
  │ OK │  │ PARTIAL │   │ NO_FILES │
  └────┘  └─────────┘   └──────────┘
     │
     └── (unrecoverable exception)
             ↓
          ┌────────┐
          │ FAILED │
          └────────┘
```

| Status | Meaning |
|--------|---------|
| `OK` | All files processed, no parse errors |
| `PARTIAL` | At least one file processed; at least one row in `parse_errors` for this DFM |
| `NO_FILES` | No input files found in landing zone for the period |
| `FAILED` | Notebook raised an unrecoverable exception; `completed_at` may be null |

**Note**: `PENDING` and `RUNNING` are transient; they should not persist in the table after the notebook exits. If they do, it indicates the notebook was interrupted.

---

## `data_quality_flags` ArrayType Notes

- Every row in `canonical_holdings` must have a non-null `data_quality_flags` array.
- An empty array `[]` is valid when no flags apply.
- Flags are **additive** — a row may carry multiple flags simultaneously (e.g., `["CASH_DEFAULTED", "ACCRUED_DEFAULTED", "FX_NOT_AVAILABLE"]`).
- Downstream validation rules inspect this array to determine evaluability (e.g., `MV_001` is `not_evaluable` when `FX_NOT_AVAILABLE` is present and `bid_value_gbp` is null).

---

## Row-Hash Column Notes

- `row_hash` is an internal ingestion column — it is present in `canonical_holdings` but **not propagated** to `tpir_load_equivalent`, `policy_aggregates`, or `validation_events`.
- The hash is computed in the DFM ingestion notebook before any transformation; it operates on raw source field values.
- Hash input fields: `(dfm_id, source_file, source_sheet, source_row_id, policy_id, security_id, holding, local_bid_price, local_currency)`.
- MERGE upsert target: `WHEN MATCHED` on `row_hash` → skip (no update); `WHEN NOT MATCHED` → insert.

---

## `report_date` Nullable Logic

- `report_date` is nullable in `canonical_holdings`.
- For Castlebay rows, `report_date` is always derived from the filename; if the filename does not match the expected pattern, `report_date = null` and `DATE_FROM_FILENAME` flag is **not** set (absence of the flag signals inference failure).
- `DATE_001` (stale date check) emits `not_evaluable` when `report_date` is null.
- `report_date` is not required for any of the downstream aggregate or report computations.

---

## See Also

- [Product Data Model](../000-dfm-poc-product/data-model.md) — Authoritative entity definitions and relationships
- [02_data_contracts.md](02_data_contracts.md) — Supplementary schema reference
- [spec.md](spec.md) — Feature requirements and acceptance criteria
- [research.md](research.md) — Per-DFM mapping decisions and framework choices
