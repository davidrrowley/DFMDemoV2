# 08 — Design Rationale

> This document captures the *why* behind the PoC architecture.
> It records the key insights from reverse-engineering the DFM Excel estate so that design
> decisions can be traced back to concrete observations, not just conventions.

---

## The Core Insight

The Excel estate is not complex because the finance logic is complex.
It is complex because transformation and orchestration are embedded in worksheets.

Once the canonical contract (`tpir_load`) is identified and isolated:

- Ingestion becomes DFM-specific parsing.
- Aggregation becomes group by.
- Controls become rule definitions.
- State becomes versioned runs.

That is the essence of the PoC.

---

## Reverse-Engineering Learnings

### Learning 1 — The Real Contract Is `tpir_load`

Across WH Ireland, Pershing, and Castlebay templates the `tpir_load` sheet schema is identical.
The Confirm Consolidator macro simply concatenates `tpir_load` from each DFM and aggregates it.

**Design decision:** Make `tpir_load_equivalent` the target output of the pipeline. The 13-column
schema in `02_data_contracts.md` is authoritative.

---

### Learning 2 — The Macros Are Orchestration, Not Logic

VBA in the DFM templates performs file browsing, copy/paste into named ranges, audit stamping,
and sheet resets. The actual transformation logic lives in worksheet formulas across `Original Data`,
`Edited`, `Check`, and `tpir_load` sheets.

**Design decision:** Extract transformation logic into deterministic Python/Spark functions.
Macros are not recreated; their *intent* is replaced by notebook orchestration.

---

### Learning 3 — Rec_Output Is Just Aggregation

The `Rec_Output` sheet uses SUMIFS to group by DFM and policy and sum cash, bid, and accrued.
There is no additional logic beyond that aggregation.

**Design decision:** Implement `policy_aggregates` as a SQL GROUP BY. See `02_data_contracts.md`
for the grouping key and aggregate columns.

---

### Learning 4 — DFMs Are Consistent Internally But Different From Each Other

| DFM | Format | Notable differences |
|-----|--------|---------------------|
| Brown Shipley | CSV | European decimals, separate cash file |
| WH Ireland | XLSX | FX column present, no accrued |
| Pershing | Two CSVs | Credo-style + native valuation feed |
| Castlebay | XLSX | Header on row 3, date inferred from filename |

Inbound formats vary across DFMs but are stable per DFM.

**Design decision:** Use a DFM-specific extractor layer with a shared canonical model. All DFM
differences are isolated to extractor config and extractor functions. Everything after
`canonical_holdings` is common.

---

### Learning 5 — Some DFMs Have Multiple Upstream Formats

Pershing provides both a Credo-style positions feed and a native PSL valuation feed.
This confirmed the need for format detection and precedence rules within a single DFM extractor.

**Design decision:** Implement per-DFM format detection before mapping. Pershing extractor uses
`Positions.csv` as primary and PSL valuation as backfill. See `12_dfm_pershing.md` for precedence
rules.

---

### Learning 6 — Not All Rules Are Evaluable For All DFMs

- Brown Shipley lacks explicit FX rate fields.
- Castlebay lacks explicit cash and accrued columns.
- Some DFMs lack acquisition cost clarity.
- Some feeds lack a report date.

**Design decision:** The validation engine must record `fail`, `not_evaluable`, or `warning` and
never silently skip a row. Evaluability is a first-class outcome in `validation_events`.

---

### Learning 7 — Check Sheets Embed Control Philosophy

The `Check` sheets in the Excel templates reveal operational control concerns:
movement thresholds, missing policies, market value recomputation, stale reports,
residual cash under £1k, FX impacts, and exclusions.

These are *control requirements*, not formatting artefacts.

**Design decision:** Centralise controls as rule definitions in `config/rules_config.json`.
All rules are individually enable/disable-able. See `05_validations.md` for rule specifications.

---

### Learning 8 — Reset Macros Reveal Stateful Excel Behaviour

Excel templates require clearing data ranges, removing filters, and resetting audit stamps
before a new period can be loaded. Excel is stateful and mutable.

**Design decision:** No reset logic in the pipeline. Each run is immutable and versioned by
`run_id`. Re-running the same period produces no new rows due to row-hash de-duplication.
See `data-model.md` for the MERGE upsert contract.

---

### Learning 9 — Currency Handling Is Inconsistent Across Sources

Different DFMs provide GBP values in different ways:
- Some provide GBP directly.
- Some provide a reporting currency market value.
- Some provide local currency with an FX rate.
- Some provide local currency only.

GBP normalisation must be rule-driven and conservative.

**Design decision:** Only compute `bid_value_gbp` where explicit evidence exists. Apply the
five-step priority chain defined in `04_ingestion_framework.md`. If the chain is exhausted,
set `bid_value_gbp = null` and flag `FX_NOT_AVAILABLE`.

---

### Learning 10 — Acquisition Cost Is Often Dirty

In the Castlebay source, the Book Cost field sometimes appears as a date/time value due to
Excel cell formatting artefacts.

**Design decision:** Treat acquisition cost as optional in the PoC. If the field cannot be
parsed, write `null` and set the `ACQ_COST_UNPARSEABLE` flag. Acquisition cost does not block
ingestion of the row. `Acq_Cost_in_GBP` is always null in `tpir_load_equivalent`.

---

## AI Usage Boundaries

AI assistance is permitted for the following tasks:

| Permitted | Purpose |
|-----------|---------|
| Header detection suggestion | Identify the likely header row when it is not on row 1 |
| Column similarity suggestion | Map ambiguous source column names to canonical names |
| Drift explanation narrative | Explain detected schema changes in natural language |
| Exception narrative generation | Generate human-readable summaries of validation failures |

AI assistance is **not permitted** for the following:

| Prohibited | Reason |
|------------|--------|
| FX calculation inference | FX rates must come from authoritative sources only |
| Financial arithmetic | All numeric computations (MV_001, aggregations) must be deterministic |
| Silent data correction | Errors must be surfaced as flags or parse errors, never silently fixed |

See also: `plan.md` Constitution Check section.

---

## What This PoC Proves

A successful PoC run demonstrates:

1. The four DFM-specific Excel templates are not required for transformation.
2. The canonical `tpir_load` contract can be produced upstream, without worksheet formulas.
3. Controls can be centralised and parameterised in `rules_config.json`.
4. Aggregation logic (Rec_Output SUMIFS) is trivial once data is canonicalised.
5. Macro-driven state can be eliminated; each run is immutable and versioned.
6. Schema drift can be surfaced explicitly via `schema_drift_events`.
7. Finance rules can be expressed declaratively with deterministic outcomes.
8. European decimal formats can be handled at parse time via config.
9. Acquisition cost unreliability does not block ingestion.
10. Currency normalisation can be applied conservatively without guessing.
11. MV_001 is demonstrably evaluable for WH Ireland, Pershing, and Castlebay.

---

## Definition of Done

The PoC is complete when all of the following hold:

- All four DFMs ingest successfully from raw files in the landing zone.
- `canonical_holdings` is populated with non-zero rows for all four DFMs.
- `tpir_load_equivalent` matches the 13-column tpir_load schema.
- `policy_aggregates` is computed for all four DFMs.
- `MV_001` is evaluable for WH Ireland, Pershing, and Castlebay.
- Brown Shipley rows are parsed with European decimal handling applied.
- Report 1 (per DFM) and Report 2 (roll-up) are written to the output folder.
- `schema_drift_events` and `run_audit_log` are populated for the run.
- No Excel dependency remains in the execution path.

These criteria supplement the measurable success criteria in `spec.md` (SC-001 to SC-005).
