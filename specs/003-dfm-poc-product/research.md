# Research Notes: DFM PoC Ingestion Platform

> **Purpose:** Design decision rationale and research notes for the DFM PoC. These notes capture
> the reasoning behind key technology and implementation choices so they can be revisited if
> requirements change.

---

## RN-01 — Why Microsoft Fabric and PySpark

**Decision:** Use Microsoft Fabric (PySpark Notebooks + Delta Lake) as the sole platform.

**Alternatives considered:**
- **Python scripts + local filesystem:** Simpler, but no shared storage, no Delta time travel, and
  no multi-user access via existing workspace controls.
- **Azure Databricks:** More mature, but requires a separate Azure resource and billing account.
  Fabric is already available to the firm's Microsoft 365 / Power BI tenant.
- **Azure Synapse Analytics:** Overlapping capability with Fabric; Fabric is the strategic direction
  for Microsoft data platforms.
- **Excel Power Query or Power BI Dataflows:** Familiar to operations teams but not code-first,
  not git-trackable, and cannot produce Delta tables.

**Rationale:**
- Fabric is accessible within the existing Microsoft 365 tenant — no new infrastructure provisioning.
- PySpark notebooks support Delta Lake natively with MERGE upsert for idempotent runs.
- OneLake provides a single landing zone for source files and outputs without additional blob
  storage configuration.
- The PoC can be built within the two-evening budget without infrastructure setup overhead.

**Risks:**
- Fabric compute tier may affect performance for large datasets. Mitigation: partition tables by
  `period` and `dfm_id` for efficient pruning.
- Fabric notebook parameterisation is slightly different from standard Databricks; `nb_run_all`
  must use Fabric-specific parameter cell syntax.

---

## RN-02 — Why Delta Lake Instead of CSV or Parquet

**Decision:** All canonical and output tables are Delta Lake tables, not CSV or Parquet files.

**Alternatives considered:**
- **CSV output only:** Simpler to produce, directly openable in Excel. But no schema enforcement,
  no atomic writes, no time travel, and no MERGE upsert for de-duplication.
- **Parquet files:** Columnar storage, good for read performance. But no ACID transactions, no
  MERGE, and no time travel for audit.
- **Azure SQL Database:** Full SQL semantics. But requires a separate Azure resource, JDBC
  connectivity from Fabric notebooks, and DDL schema management.

**Rationale:**
- Delta Lake MERGE upsert is the mechanism for row-hash de-duplication (NFR-04). Without MERGE,
  idempotent runs require full table deletion and re-insert, which is destructive.
- Delta time travel provides point-in-time recovery if a run produces incorrect data.
- Delta tables integrate natively with Fabric SQL Analytics Endpoint, enabling ad-hoc SQL queries
  against `canonical_holdings` and `policy_aggregates` without exporting data.
- Schema evolution support (Delta) means new columns in source files can be tracked in
  `schema_drift_events` without breaking existing Delta reads.

---

## RN-03 — Row-Hash De-Duplication Approach

**Decision:** Compute a deterministic SHA-256 row hash over a stable column set and use Delta
MERGE upsert matching on `row_hash` to prevent duplicates.

**The problem:** If `nb_run_all` is run twice for the same period (e.g., to pick up a corrected
source file), naive APPEND writes would double the row count in `canonical_holdings`. This would
corrupt `policy_aggregates` totals and validation results.

**Column set for hash:**
```
(dfm_id, source_file, source_sheet, source_row_id, policy_id, security_id,
 holding, local_bid_price, local_currency)
```

**Columns excluded from hash** (intentionally variable between runs):
- `run_id` — changes each run
- `ingested_at` — changes each run
- `data_quality_flags` — may change if parsing logic improves

**Why not use a natural key (dfm_id + source_file + source_row_id)?**
- `source_row_id` alone is not sufficient: the same row number may contain different data if the
  source file was corrected. The hash includes value columns to detect content changes.
- If a row's content changes between runs (e.g., corrected bid price in a re-delivered file),
  the hash changes and the MERGE UPDATE overwrites the old row with the new values.

**Determinism requirement:** `row_hash` is computed using a deterministic SHA-256 implementation.
Column values are cast to string with fixed precision before hashing to avoid floating-point
representation differences.

---

## RN-04 — European vs UK/US Decimal Handling

**Decision:** Implement `parse_numeric(value, european=False)` as a shared utility supporting both
decimal conventions, with the convention specified per DFM in `raw_parsing_config.json`.

**The problem:** DFM source files use different numeric conventions:
- Brown Shipley, WH Ireland, Pershing: UK/US convention — thousands separator is comma, decimal
  separator is period (e.g., `13,059.70`).
- Castlebay: European convention — thousands separator is period, decimal separator is comma
  (e.g., `3.479,29`).

If the wrong convention is applied, `3.479,29` parsed as UK/US would produce `3.47929` (stripped
of the trailing `,29`), which is a serious valuation error.

**Implementation:**
```python
def parse_numeric(value: str, european: bool = False) -> Decimal:
    if european:
        # Remove period thousands separators, replace comma decimal separator
        cleaned = value.replace('.', '').replace(',', '.')
    else:
        # Remove comma thousands separators
        cleaned = value.replace(',', '')
    return Decimal(cleaned)
```

**Config:** Each DFM entry in `raw_parsing_config.json` includes `"numeric_convention": "european"`
or `"numeric_convention": "uk_us"`.

**Why not auto-detect?** Auto-detection of numeric convention is unreliable for small numbers (e.g.,
`1,234` could be European `1.234` or UK/US `1234`). Explicit config eliminates ambiguity.

---

## RN-05 — Config-Driven DFM Isolation

**Decision:** All DFM-specific logic (column names, file patterns, sheet names, skip rows, numeric
convention, date format) lives exclusively in `raw_parsing_config.json` and the DFM ingestion
notebook. Nothing DFM-specific appears in shared validation, aggregation, or reporting code.

**The problem being solved:** If DFM-specific column names leak into `nb_validate` or `nb_aggregate`,
adding a fifth DFM requires changes to shared code — increasing the risk of breaking existing DFMs.

**Structure of `raw_parsing_config.json`:**
```json
{
  "dfms": {
    "wh_ireland": {
      "file_pattern": "*.xlsx",
      "sheet_detection": "auto",
      "skip_rows": 0,
      "numeric_convention": "uk_us",
      "date_format": "dd-MMM-yyyy",
      "column_mapping": {
        "Policy Ref": "policy_id",
        "ISIN": "isin",
        "Bid Price": "local_bid_price",
        ...
      }
    },
    "castlebay": {
      "numeric_convention": "european",
      ...
    }
  }
}
```

**Adding a fifth DFM:** Add an entry to `dfm_registry.json` (set enabled=true), add a config block
to `raw_parsing_config.json`, and create a new `nb_ingest_<dfm_id>` notebook. No changes to
`nb_validate`, `nb_aggregate`, `nb_reports`, or the shared library.

**Why not a single generic ingestion notebook?** A single generic notebook would require the
config to fully specify every step of the ingestion — including error handling branches, join logic
(Pershing requires joining Positions and Valuation), and multi-file handling (Brown Shipley has two
source files). The per-DFM notebook approach keeps complex DFM-specific logic readable and testable
in isolation.

---

## See Also

- [architecture.md](architecture.md) — How these decisions are reflected in the system design
- [nfr.md](nfr.md) — NFR-01 (determinism), NFR-04 (idempotency), NFR-05 (config portability)
- [specs/002-dfm-poc-ingestion/01_architecture.md](../002-dfm-poc-ingestion/01_architecture.md) — Feature-level architecture referencing these decisions
