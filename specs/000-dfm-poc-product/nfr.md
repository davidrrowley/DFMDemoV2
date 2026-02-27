# Non-Functional Requirements: DFM PoC Ingestion Platform

> **Purpose:** Quality attributes and PoC-specific constraints for all notebooks, tables, and
> outputs. These NFRs reflect the PoC context: a two-evening build on a single Fabric workspace,
> not a production system.

---

## NFR-01 — Determinism

**Requirement:** Core finance calculations must be deterministic. Given the same source files and
config, a run must always produce identical `canonical_holdings` rows, `policy_aggregates` totals,
and `tpir_load_equivalent` rows.

**Scope:** All numeric computations: GBP conversion (`apply_fx`), MV recalculation (MV_001),
policy aggregation sums.

**Constraints:**
- No floating-point arithmetic for monetary values; use `Decimal` or PySpark `DecimalType` with
  fixed precision (28,8).
- No random elements, shuffles, or timestamp-based seeds in finance calculations.
- AI-generated code for finance calculations must be reviewed and determinism must be verified.

**Measurement:** Re-run the same period twice with the same source files. Compare
`canonical_holdings`, `policy_aggregates`, and `tpir_load_equivalent` row-by-row (excluding
`run_id` and `ingested_at`). Rows must be identical.

**Note:** `run_id` and `ingested_at` are intentionally different between runs. All other columns
must match.

---

## NFR-02 — Run Performance

**Requirement:** A full four-DFM run for one period must complete within 30 minutes on a standard
Fabric notebook compute tier.

**Why:** The PoC must be practically usable by an analyst running a monthly period. A run that
takes hours is not usable for a two-evening PoC.

**Measurement:** Time `nb_run_all` execution from start to final audit log update.

**Constraints:** No optimisation work is expected for the PoC beyond avoiding unnecessary full
table scans. If performance is a problem, partition pruning on `period` and `dfm_id` should be the
first lever.

---

## NFR-03 — Observability

**Requirement:** Every run must produce a complete, queryable audit trail. There must be no silent
failures.

**What "observable" means for the PoC:**

| Observable | How |
|---|---|
| Which DFMs ran | `run_audit_log` (one row per DFM per run) |
| How many rows were ingested | `run_audit_log.rows_ingested` |
| Whether a DFM failed | `run_audit_log.status = FAILED` |
| Which rows could not be parsed | `parse_errors` table |
| Which columns changed in source files | `schema_drift_events` table |
| Which validation rules failed | `validation_events` table |
| What the totals were | `reconciliation_summary.json` |

**Constraints:**
- `nb_run_all` must write/update `run_audit_log` for every DFM, even those that raised exceptions.
- Uncaught exceptions in a DFM notebook must be caught by `nb_run_all` and recorded; they must not
  silently terminate the run.

---

## NFR-04 — Idempotency

**Requirement:** Re-running the same period must not produce duplicate rows in `canonical_holdings`.

**Implementation:** Row-hash de-duplication. A deterministic SHA-256 hash is computed over a stable
column set for each row. MERGE upsert into `canonical_holdings` matches on `row_hash`; existing
rows are updated rather than duplicated.

**Constraints:**
- The `row_hash` column set must not include `run_id`, `ingested_at`, or `data_quality_flags`
  (these change between runs).
- The hash column set must include all source-identity columns:
  `(dfm_id, source_file, source_sheet, source_row_id, policy_id, security_id, holding,
  local_bid_price, local_currency)`.

**Measurement:** Run the same period twice. COUNT(*) on `canonical_holdings` for that period
must be identical after both runs.

---

## NFR-05 — Config Portability

**Requirement:** No DFM-specific column names, file patterns, numeric conventions, or date formats
may appear outside `raw_parsing_config.json` and the DFM-specific ingestion notebook.

**Why:** If DFM-specific logic leaks into validation, aggregation, or reporting, adding a fifth DFM
requires changes to shared code — breaking the isolation design principle.

**Constraints:**
- `nb_validate`, `nb_aggregate`, and `nb_reports` must not contain any reference to `brown_shipley`,
  `wh_ireland`, `pershing`, or `castlebay` column names.
- The shared library must not contain DFM-specific branches.
- Enabling or disabling a DFM must require only a change to `dfm_registry.json`.

---

## NFR-06 — Data Quality Transparency

**Requirement:** Every field-level assumption made during normalisation must be recorded in
`data_quality_flags` on the canonical row.

**Examples of flags:**

| Flag | Meaning |
|---|---|
| `HOLDING_ASSUMED_ZERO` | `holding` was null; defaulted to 0 |
| `DATE_INFERRED_FROM_FILENAME` | `report_date` was inferred from the source filename |
| `DATE_MISSING` | `report_date` was null and could not be inferred |
| `FX_RATE_DEFAULTED` | FX rate was not in `fx_rates.csv`; used default (1.0 for GBP) |
| `BID_VALUE_NOT_COMPUTABLE` | `bid_value_gbp` could not be computed due to null inputs |
| `CURRENCY_MAPPED_FROM_DESCRIPTION` | Currency was looked up via `currency_mapping.json` |

**Measurement:** Sample 10 rows from `canonical_holdings`. Any row with a non-trivial assumption
must have at least one flag.

---

## NFR-07 — Error Resilience

**Requirement:** A failure in one DFM ingestion notebook must not prevent the remaining DFMs or
downstream steps from running.

**Constraints:**
- `nb_run_all` must wrap each DFM notebook invocation in a try/except block.
- On exception: log the traceback, write `run_audit_log` with `status=FAILED`, increment error
  count, and continue to the next DFM.
- `nb_validate`, `nb_aggregate`, and `nb_reports` must run even if some DFMs have `status=FAILED`
  in `run_audit_log` (they will simply have fewer rows to process).

**Measurement:** Intentionally corrupt a source file for one DFM. Verify that the run completes
and the other three DFMs produce valid output.

---

## NFR-08 — Time Constraint (PoC Build)

**Requirement:** The full PoC must be buildable within 2 evenings using AI-assisted development.

**Implications:**
- No enterprise-grade features: no CI/CD pipelines, no automated alerting, no retry queues.
- No bank holiday calendars (DATE_001 uses weekend-only logic).
- No production auth or multi-user access control.
- Notebook code favours clarity and correctness over performance optimisation.
- AI (GitHub Copilot) may generate boilerplate, schema creation, and non-finance logic. Finance
  calculations must be human-reviewed.

---

## NFR Summary

| NFR | Key Test | Priority |
|---|---|---|
| NFR-01 Determinism | Re-run same period; compare output rows | Critical |
| NFR-02 Run Performance | Time `nb_run_all`; must complete < 30 min | High |
| NFR-03 Observability | Verify audit log after every run | Critical |
| NFR-04 Idempotency | Re-run same period; count must not grow | Critical |
| NFR-05 Config Portability | Grep shared notebooks for DFM-specific strings | High |
| NFR-06 Data Quality Transparency | Inspect `data_quality_flags` on sample rows | High |
| NFR-07 Error Resilience | Corrupt one DFM; verify others succeed | Critical |
| NFR-08 Time Constraint | Build log / commit history | PoC constraint |

---

## See Also

- [high-level-requirements.md](high-level-requirements.md) — HR-09 covers NFRs at requirement level
- [architecture.md](architecture.md) — Design choices that support these NFRs
- [security-baseline.md](security-baseline.md) — Security-specific quality attributes
