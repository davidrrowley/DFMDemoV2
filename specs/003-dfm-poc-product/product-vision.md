# Product Vision: DFM PoC Ingestion Platform

> **Scope:** Product-level vision for the DFM PoC Ingestion Platform.
> This defines the problem space, target users, and desired outcomes for the entire platform.
> The DFM ingestion pipeline feature is sequenced in `roadmap.md` and detailed in
> `specs/002-dfm-poc-ingestion/`.

## Context

Investment operations teams at wealth management firms manage position and valuation data from multiple
Discretionary Fund Managers (DFMs). The current process relies on manually copying data from four
separate DFM sources into Excel-based reconciliation workbooks:

- **Fragmentation:** Each DFM delivers data in a different format (Brown Shipley Notification+Cash,
  WH Ireland XLSX, Pershing Positions+Valuation, Castlebay XLSX) with different column names,
  numeric conventions (UK/US vs European decimal separators), and date formats.
- **Manual effort:** Analysts copy, reformat, and paste data into Excel templates each month. This
  takes significant time and is highly error-prone.
- **Non-auditable:** There is no automated record of which source file was used, how values were
  transformed, or which rows were excluded. Re-running a past period requires re-doing all manual
  steps.
- **Fragile reconciliation:** The Excel Rec_Output SUMIFS totals are hard to trace back to source
  rows. MV recalculation checks (holding × bid price × FX rate) are done manually and inconsistently.
- **No governance:** Parse failures, schema changes in source files, and mapping gaps go undetected
  until a reconciliation problem surfaces.

This problem is becoming more acute as the number of DFMs and policy count grow, and as regulatory
requirements around data quality and audit trails tighten.

## Target Users

**Primary:**
- Investment operations analysts performing monthly DFM reconciliation
- DFM reconciliation leads who review validation exceptions and approve outputs

**Secondary:**
- Technology and data teams responsible for maintaining reconciliation infrastructure
- Compliance / audit functions requiring data lineage and traceability

**Environment:**
- Microsoft Fabric workspace (single-user PoC; workspace access managed by existing controls)
- OneLake for file storage (landing zone, config, outputs)
- PySpark notebooks for interactive execution

## Core Problem

Operations teams lack a **systematic, auditable pipeline** to:

1. **Ingest** source files from multiple DFMs with different formats and conventions.
2. **Normalise** data into a single canonical schema with GBP-equivalent values.
3. **Validate** holdings data deterministically — checking market value recalculations, stale dates,
   and missing values — at row and policy level.
4. **Aggregate** to policy-level totals matching the Excel Rec_Output structure.
5. **Report** exceptions, validation failures, and reconciliation summaries in a consistent format.
6. **Audit** every run with a traceable record of files, row counts, errors, and outcomes.

Without this platform:
- Reconciliation errors are caught late or not at all.
- Each month's process is a manual re-invention.
- Audit trails are incomplete, making it hard to respond to queries.
- Adding a new DFM requires bespoke Excel changes, not a config update.

## Desired Outcome

A single notebook run for any given period should produce:

- **`canonical_holdings`** — a Delta table of normalised, GBP-equivalent holdings rows sourced from
  all four DFMs, with full data quality flags and source traceability.
- **`tpir_load_equivalent`** — output schema matching the existing tpir_load contract, ready for
  downstream consumption.
- **`policy_aggregates`** — cash/bid/accrued totals by DFM + policy, directly comparable to the
  Excel Rec_Output SUMIFS totals.
- **`validation_events`** — a record of every rule evaluation (MV_001, DATE_001, VAL_001, MAP_001)
  including failures, warnings, and not-evaluable states.
- **Report 1** (per DFM) + **Report 2** (roll-up) — CSV reports written to OneLake for review.
- **`reconciliation_summary.json`** — a machine-readable summary of totals and row counts for
  tie-out.
- **`run_audit_log`** + **`parse_errors`** + **`schema_drift_events`** — governance tables providing
  full data lineage per run.

## Platform Boundaries

**In scope (PoC):**
- Microsoft Fabric Lakehouse (OneLake, Delta tables, PySpark notebooks)
- Four DFM source formats: Brown Shipley, WH Ireland, Pershing, Castlebay
- Monthly period-based ingestion (one `period=YYYY-MM` per run)
- Config-driven DFM isolation (`dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`)
- MV_001 check for WH Ireland, Pershing, Castlebay (Brown Shipley if feasible)
- Validation rules: DATE_001, MV_001, VAL_001, MAP_001 (POP_001 optional/disabled by default)
- Row-hash de-duplication to ensure idempotent re-runs
- European and UK/US numeric parsing (`parse_numeric`)
- FX conversion to GBP (`apply_fx`)

**Out of scope (PoC):**
- Full replacement of Excel templates in production
- Enterprise-grade ops: CI/CD pipelines, full alerting, automatic retries
- Bank holiday working-day calendars (weekend-only PoC)
- IH policy mapping (`POP_001` disabled by default; requires `policy_mapping.csv`)
- Multi-user access control beyond existing Fabric workspace permissions
- Real-time or intraday ingestion

## Key Constraints

| Constraint | Detail |
|---|---|
| Time budget | 2 evenings maximum for initial PoC build |
| Development approach | AI-assisted (GitHub Copilot); human review of finance logic |
| Finance calculation determinism | Core calculations (MV, aggregates) must be deterministic; AI may assist with drift detection and narrative only |
| Platform | Microsoft Fabric only (no on-premise or alternative cloud) |
| Data handling | Client data in Fabric OneLake governed by existing workspace access controls |

## Success Criteria

A PoC run is successful when:

- [ ] A single `nb_run_all` execution for one period ingests all four DFMs and completes without
  unrecoverable errors.
- [ ] `canonical_holdings` contains row-level data for all DFMs with GBP values and data quality flags.
- [ ] `tpir_load_equivalent` schema matches the existing tpir_load contract column set.
- [ ] `policy_aggregates` is computed for all four DFMs and matches Excel Rec_Output totals to within
  tolerance.
- [ ] `MV_001` is implemented and evaluable for WH Ireland, Pershing, and Castlebay.
- [ ] Report 1 per DFM and Report 2 roll-up are written to OneLake output folder.
- [ ] `run_audit_log` has one row per DFM per run with accurate row counts and status.
- [ ] Re-running the same period does not duplicate `canonical_holdings` rows (row-hash de-duplication).
- [ ] A DFM ingestion failure does not block other DFMs from completing.

---

## See Also

- [high-level-requirements.md](high-level-requirements.md) — Functional and non-functional requirements
- [feature-map.md](feature-map.md) — Feature boundaries and ownership
- [roadmap.md](roadmap.md) — Phase sequencing and delivery timeline
- [architecture.md](architecture.md) — System boundaries and key components
- [specs/002-dfm-poc-ingestion/](../002-dfm-poc-ingestion/) — Feature-level spec for the ingestion pipeline
