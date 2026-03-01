# 17 — AI Schema Drift Mapper

## Purpose

When a DFM changes its source file layout — adding, renaming, or reordering columns — the
pipeline currently writes `schema_drift_events` rows and fails to parse the affected rows
correctly until an analyst manually edits `raw_parsing_config.json`. This spec defines
`nb_ai_schema_mapper`, a notebook that calls Azure OpenAI GPT-4o to propose a revised config
mapping automatically, surfacing it for analyst review rather than leaving the analyst to
diagnose the drift from scratch.

This is an AI step because the task is ambiguous text matching: `"Settlement Ccy"`, `"Sttlmt
Currency"`, and `"CCY"` are semantically equivalent column names that no deterministic rule can
reliably map without a learned understanding of financial data vocabulary.

---

## Trigger condition

`nb_ai_schema_mapper` is invoked by `nb_run_all` **after** all DFM ingestion notebooks complete,
if and only if `schema_drift_events` contains one or more rows for the current `run_id` where
`drift_type = MISSING_COLUMN`. It is a non-blocking step: its output is advisory only.

---

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| `schema_drift_events` | Delta table | Rows for the current `run_id` and `dfm_id` |
| `raw_parsing_config.json` | `/Files/config/` | Current column mapping for the affected DFM |
| Sample rows from source file | Landing zone | First 5 data rows of the file that triggered drift |
| `azure_openai_config.json` | `/Files/config/` | Endpoint, deployment name, API version |

---

## Prompt design

The notebook constructs a system prompt and user message for GPT-4o:

**System prompt:**
```
You are a financial data integration assistant. You will be given:
1. The current column mapping configuration for a fund manager's file.
2. The actual column headers found in a new version of the file.
3. Sample rows from that new file.

Your task is to propose a revised column mapping that reconciles the differences.
Return ONLY a JSON object matching the structure of the input config, with the updated
field mappings. Do not explain your reasoning. Do not include any text outside the JSON.
```

**User message (constructed per DFM):**
```json
{
  "dfm_id": "<dfm_id>",
  "current_mapping": { ... },
  "actual_headers": [ ... ],
  "sample_rows": [ ... ]
}
```

---

## Output

The notebook writes one row to the `ai_resolution_suggestions` Delta table per missing column:

| Column | Type | Description |
|--------|------|-------------|
| `suggestion_id` | string | UUID |
| `run_id` | string | Current run |
| `period` | string | Current period |
| `suggestion_type` | string | `schema_mapping` |
| `dfm_id` | string | Affected DFM |
| `trigger_event_id` | string | FK to `schema_drift_events` row |
| `suggestion_json` | string | GPT-4o proposed config diff (JSON) |
| `confidence` | string | `high` / `medium` / `low` — inferred from GPT-4o response coherence check |
| `status` | string | `pending_review` (initial); analyst updates to `accepted` or `rejected` |
| `created_at` | timestamp | When suggestion was written |
| `reviewed_by` | string | Analyst id who actioned (null until reviewed) |
| `reviewed_at` | timestamp | When actioned (null until reviewed) |

The notebook also writes a human-readable summary to
`/Files/output/period=YYYY-MM/run_id=<run_id>/ai_schema_suggestions.txt`.

---

## Analyst workflow

1. After a run with schema drift, the analyst opens `ai_schema_suggestions.txt` or queries
   `ai_resolution_suggestions` filtered to `suggestion_type = schema_mapping`.
2. They review the proposed config diff against the actual file.
3. If the suggestion is correct, they apply it to `raw_parsing_config.json` manually and
   re-run the pipeline. The notebook does **not** modify `raw_parsing_config.json` autonomously.
4. They update the `status` field in `ai_resolution_suggestions` to `accepted` or `rejected`.

---

## Error handling

| Condition | Behaviour |
|-----------|-----------|
| Azure OpenAI call fails (5xx, timeout) | Log warning to `run_audit_log`; skip suggestion; pipeline continues |
| GPT-4o returns invalid JSON | Log `confidence=low`; write raw response to `suggestion_json` for manual review |
| No `schema_drift_events` for this run | Notebook exits immediately without calling Azure OpenAI |

---

## Config (`azure_openai_config.json`)

```json
{
  "endpoint": "https://<resource-name>.openai.azure.com/",
  "schema_mapper_deployment": "gpt-4o",
  "api_version": "2024-08-01-preview",
  "schema_mapper_max_tokens": 1000,
  "schema_mapper_temperature": 0.0
}
```

`temperature: 0.0` is required — this is a structured output task; creativity is undesirable.

---

## Acceptance criteria

- `ai_resolution_suggestions` receives a row with `suggestion_type=schema_mapping` when
  `schema_drift_events` contains a `MISSING_COLUMN` row for the current run.
- The `suggestion_json` field contains a valid JSON object matching the structure of
  `raw_parsing_config.json`.
- When Azure OpenAI is unavailable, the pipeline completes without error and
  `run_audit_log` records an `ai_schema_mapper_skipped` note.
- `nb_ai_schema_mapper` never writes to `raw_parsing_config.json` directly.
