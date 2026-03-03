# 04 - Ingestion Framework

## Adapter-Profile Execution Model

Each DFM uses one or more adapter profiles. A profile defines file discovery, parsing, mapping, and identifier strategy for one file variant.

Profile metadata controls:

- file role patterns
- file format and sheet/header strategy
- numeric and date parsing strategy
- source-to-canonical column mapping
- identifier priority (`sedol`, `isin`, `security_code`, fallback)
- policy mapping join key strategy
- exclusion rule hooks

## Common Processing Steps

1. Discover files in `/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/`.
2. Classify each file against adapter profile role patterns.
3. Parse each source using profile-specific parser settings.
4. Persist Stage 1 rows to `source_dfm_raw`.
5. Standardize to Stage 2 `individual_dfm_consolidated`.
6. Persist parse and schema diagnostics.

## Stage 1 Rules

- Persist every discoverable row, even when parsing is partial.
- Capture `source_file`, `source_sheet`, `source_row_id`, and `raw_record_json`.
- Never discard rows silently.

## Stage 2 Rules

- Enforce canonical field set and expected data types.
- Apply policy and security mapping tables by effective period.
- Resolve identifier via configured priority; record `identifier_chosen`.
- Set `include_flag` and exclusion reasons deterministically.
- Record key transformation decisions in `decision_trace_json`.

## Deduplication

Use deterministic `row_hash` over stable provenance and key financial fields. Deduplication occurs before Stage 3 publication.

## Currency and Value Normalization

1. If local currency is GBP, set `fx_rate=1`.
2. Else use source-supplied GBP value if present.
3. Else apply source-supplied FX rate where available.
4. Else join to period FX table.
5. Else keep GBP result nullable and flag in `data_quality_flags`.

## Data Quality Flags

Flags are additive and must remain attached to Stage 2 rows.
