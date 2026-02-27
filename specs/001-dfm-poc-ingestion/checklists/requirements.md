# Specification Quality Checklist: DFM PoC — Ingestion Pipeline

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2025-12-31
**Feature**: [specs/001-dfm-poc-ingestion/spec.md](../spec.md)

---

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) in spec.md — only in plan.md
- [x] Focused on user value and analytical outcomes (ingestion, validation, reporting)
- [x] User stories are written from the perspective of an investment operations analyst
- [x] All mandatory sections completed (User Scenarios, Requirements, Assumptions, Success Criteria)

---

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] All 20 functional requirements (FR-001 to FR-020) are testable and unambiguous
- [x] Success criteria are measurable (row counts, file counts, evaluability of MV_001)
- [x] Success criteria are technology-agnostic (no Spark or Delta Lake specifics in spec.md)
- [x] All acceptance scenarios include Given/When/Then structure
- [x] Edge cases are identified (7 edge cases covering the main failure modes)
- [x] Scope is clearly bounded (PoC, single period per run, four DFMs, no prod ops)
- [x] Assumptions documented (manual landing zone, nb_setup prerequisite, weekend-only calendar)

---

## Feature Readiness

- [x] All four user stories are independently testable without implementing the others
- [x] User scenarios cover the primary analytical flow (ingest → validate → report → audit)
- [x] Feature meets measurable outcomes defined in Success Criteria (SC-001 to SC-005)
- [x] No implementation details leak into spec.md (no PySpark, no Delta Lake, no Fabric references)

---

## DFM-Specific Checks

- [x] All four DFMs (Brown Shipley, WH Ireland, Pershing, Castlebay) have source mapping documents (`10_dfm_*.md` through `13_dfm_*.md`)
- [x] All four DFMs have entries in `config/raw_parsing_config.json`
- [x] All four DFMs are registered in `config/dfm_registry.json`
- [x] All validation rules (MV_001, DATE_001, VAL_001, MAP_001) are parameterised in `config/rules_config.json`
- [x] Validation rules can be individually enabled/disabled via config (FR-012)
- [x] MV_001 evaluability limitation for Brown Shipley is documented in spec.md (Assumptions) and research.md
- [x] No AI-generated or probabilistic values used in financial calculations — all rules are deterministic (FR-011, FR-012)
- [x] Currency normalisation chain is deterministic and config-driven (five-step chain in FR-006 and research.md)
- [x] Row-hash de-duplication is required for all DFMs (FR-007) — not optional

---

## Notes

- Brown Shipley is the most complex DFM (header row detection, European decimals, GBP assumption). It is documented in `10_dfm_brown_shipley.md` and `research.md`. MV_001 `not_evaluable` for Brown Shipley is an acceptable PoC outcome.
- Castlebay's `report_date` null handling (when filename does not match expected pattern) is documented in `data-model.md` under "report_date Nullable Logic".
- Pershing backfill logic (Positions.csv precedence) is critical for correctness; it is covered in FR-005, research.md, and `12_dfm_pershing.md`.
- `Acq_Cost_in_GBP` is always null in `tpir_load_equivalent` — this is a known PoC limitation documented in the Assumptions section of spec.md.
