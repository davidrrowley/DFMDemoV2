# Implementation Plan: DFM PoC Ingestion Platform

**Product:** DFM PoC Ingestion Platform  
**Feature folder:** `specs/001-dfm-poc-ingestion/`  
**Owner:** `app-python`

---

## Approach

All implementation targets Microsoft Fabric (PySpark notebooks + Delta Lake). DFM differences are
isolated to extractor config (`raw_parsing_config.json`) and DFM-specific ingestion notebooks.
Everything downstream of `canonical_holdings` is shared and DFM-agnostic.

Development is AI-assisted using GitHub Copilot. Finance calculations (GBP conversion, MV
recalculation, policy aggregation) must be human-reviewed for correctness and determinism.

---

## Implementation Phases

### Phase 1 — Foundation

**Goal:** Establish all infrastructure before any DFM notebook is written.

**Tasks:**
1. Create Fabric Lakehouse and enable Delta Lake.
2. Create all seven Delta tables with schemas from `data-model.md`:
   `canonical_holdings`, `tpir_load_equivalent`, `policy_aggregates`, `validation_events`,
   `run_audit_log`, `schema_drift_events`, `parse_errors`.
3. Upload config files to `/Files/config/`:
   `dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`,
   `currency_mapping.json`, `fx_rates.csv`.
4. Create `nb_run_all` entrypoint notebook with:
   - `period` parameter (YYYY-MM)
   - `run_id` generation (UTC timestamp)
   - Config loading
   - DFM invocation loop (try/except per DFM)
5. Create shared Python library with skeleton functions.

**Gate:** All Delta tables exist and are queryable. `nb_run_all` runs without errors (no DFMs
enabled yet).

---

### Phase 2 — DFM Ingestion Notebooks (F01)

**Goal:** Populate `canonical_holdings` from all four DFM source formats.

**Tasks (one per DFM):**
1. **Brown Shipley** (`nb_ingest_brown_shipley`):
   - Discover Notification CSV + Cash CSV in landing zone
   - Parse per `raw_parsing_config.json` (UK/US numeric convention)
   - Map to canonical schema; compute `cash_value_gbp`, `bid_value_gbp`
   - Write to `canonical_holdings` (MERGE on `row_hash`)
   - Emit `parse_errors`, `schema_drift_events`, `run_audit_log`
2. **WH Ireland** (`nb_ingest_wh_ireland`):
   - Discover XLSX; auto-detect sheet name
   - Parse (UK/US numeric convention)
   - Map to canonical schema; compute GBP values
   - Write to `canonical_holdings`, emit governance rows
3. **Pershing** (`nb_ingest_pershing`):
   - Discover Positions XLSX + Valuation XLSX
   - Join positions and valuations on security key
   - Parse (UK/US numeric convention)
   - Map to canonical schema; compute GBP values
   - Write to `canonical_holdings`, emit governance rows
4. **Castlebay** (`nb_ingest_castlebay`):
   - Discover XLSX (European numeric convention)
   - Parse using `parse_numeric(value, european=True)`
   - Map to canonical schema; compute GBP values
   - Write to `canonical_holdings`, emit governance rows

**Gate:** `canonical_holdings` contains rows for all four DFMs. `run_audit_log` has four rows
with `status=OK` or `status=PARTIAL`.

---

### Phase 3 — Validation Engine (F02)

**Goal:** Implement all baseline validation rules in `nb_validate`.

**Tasks:**
1. Implement `DATE_001` (stale report date; weekend-only calendar).
2. Implement `MV_001` (MV recalculation; evaluable for WH Ireland, Pershing, Castlebay).
3. Implement `VAL_001` (no cash and no stock at policy level; reads `policy_aggregates`).
4. Implement `MAP_001` (unmapped security / residual cash proxy).
5. Implement `not_evaluable` emission for all rules.
6. All thresholds read from `rules_config.json` at runtime.

**Gate:** `validation_events` contains rows for at least one DFM. MV_001 produces results for
WH Ireland, Pershing, and Castlebay.

---

### Phase 4 — Aggregation and Outputs (F03)

**Goal:** Produce all aggregated outputs, reports, and the reconciliation summary.

**Tasks:**
1. **`nb_aggregate`:**
   - Compute `policy_aggregates` (grouped by `period`, `run_id`, `dfm_id`, `policy_id`)
   - Produce `tpir_load_equivalent` with correct column set
2. **`nb_reports`:**
   - Write `report1_<dfm_id>.csv` for each DFM
   - Write `report2_rollup.csv`
   - Write `reconciliation_summary.json`
3. **`nb_run_all` finalisation:**
   - Update `run_audit_log` `completed_at` for all DFMs

**Gate:** All output files exist in `/Files/output/period=YYYY-MM/run_id=<run_id>/`.
`reconciliation_summary.json` totals match `policy_aggregates` values.

---

## Design Principles

| Principle | Implementation |
|---|---|
| DFM isolation | DFM-specific logic in config + DFM notebook only |
| Fault tolerance | `nb_run_all` try/except per DFM; failed DFMs do not block others |
| Determinism | `Decimal` types for all monetary values; no random elements |
| Idempotency | `row_hash` de-duplication via MERGE upsert on `canonical_holdings` |
| Config-driven | Thresholds, mappings, enable/disable flags in JSON config |
| AI-assisted | Copilot for boilerplate; human review for all finance calculations |

---

## See Also

- [roadmap.md](roadmap.md) — Phase timing and completion milestones
- [tasks.md](tasks.md) — Task-level breakdown with acceptance criteria
- [architecture.md](architecture.md) — Notebook structure and folder layout
- [specs/001-dfm-poc-ingestion/plan.md](../001-dfm-poc-ingestion/plan.md) — Feature-level plan detail
