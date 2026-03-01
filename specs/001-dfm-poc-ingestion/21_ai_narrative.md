# 21 — AI Run Narrative Generator

## Purpose

At the end of each pipeline run, the analyst currently must open multiple artefacts —
`run_audit_log`, `tpir_check_result.json`, `reconciliation_summary.json`, `ai_anomaly_report.txt`,
validation reports — to assemble a picture of what happened. `nb_ai_narrative` collects all
run outcomes into a single structured JSON payload and calls GPT-4o to produce a concise,
plain-English run summary. This summary is stored in the `ai_run_narratives` Delta table and
written as `run_summary.txt` in the output folder. It is the first thing an analyst reads.

This is an AI step because translating a structured set of metrics, flags, and exception counts
into clear, narrative English that correctly contextualises the significance of each outcome
(e.g. "two novel MAP_001 failures require attention before approving the ADS load") is a
natural language generation task.

---

## Trigger condition

`nb_ai_narrative` is the final step invoked by `nb_run_all`, after all other notebooks have
completed (including `nb_ads_load`). It runs unconditionally.

---

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| `run_audit_log` | Delta table | Final status for each DFM |
| `validation_events` | Delta table | Failure / not_evaluable counts by rule for this run |
| `ai_triage_labels` | Delta table | Label counts (expected vs novel) |
| `ai_anomaly_events` | Delta table | Anomaly flags and severities for this run |
| `tpir_check_result.json` | `/Files/output/` | TPIR check pass/fail |
| `run_audit_log.ads_load_status` | Delta table | ADS load outcome |
| `azure_openai_config.json` | `/Files/config/` | Endpoint, narrative deployment |

The notebook assembles a single structured summary object:

```json
{
  "period": "2026-01",
  "run_id": "20260131T093012Z",
  "dfm_statuses": {
    "brown_shipley": "OK", "wh_ireland": "OK",
    "pershing": "PARTIAL", "castlebay": "OK"
  },
  "total_rows_ingested": 5834,
  "validation_summary": {
    "total_failures": 42,
    "expected": 38,
    "novel": 4,
    "novel_details": [...]
  },
  "anomaly_flags": [
    { "dfm_id": "wh_ireland", "flag": "large_increase", "severity": "medium",
      "reasoning": "WH Ireland total bid value increased 22% vs prior month" }
  ],
  "tpir_check_status": "passed",
  "ads_load_status": "committed",
  "ads_load_rows": 5834
}
```

---

## Prompt design

**System prompt:**
```
You are an investment operations assistant writing a concise run summary for an analyst.
You will be given a JSON object containing the outcomes of a monthly DFM holdings
reconciliation pipeline run. Write a 3–5 paragraph summary in plain English that:

1. States the overall outcome (successful / partial / failed) and the period.
2. Summarises which DFMs were processed and any ingestion issues.
3. Highlights novel validation failures that need analyst attention (if any).
4. Notes any portfolio anomaly flags, especially high-severity ones.
5. Confirms the TPIR check and ADS load outcome.

Use clear, direct language. Do not use technical jargon or acronyms without explaining them.
Do not repeat numeric data the analyst can read directly from the reports.
```

---

## Output

### `ai_run_narratives` Delta table

| Column | Type | Description |
|--------|------|-------------|
| `narrative_id` | string | UUID |
| `run_id` | string | Current run |
| `period` | string | Reporting period |
| `narrative_text` | string | Full generated summary |
| `input_summary_json` | string | The structured payload sent to GPT-4o (for audit) |
| `model_deployment` | string | Which deployment was called |
| `created_at` | timestamp | When written |

### `run_summary.txt`

Written to `/Files/output/period=YYYY-MM/run_id=<run_id>/run_summary.txt`. This is the
primary artefact the analyst reads first. It is also the input to the Copilot Studio "What
happened in the last run?" topic.

The file has a fixed preamble (deterministic data) followed by the AI-generated narrative:

```
=== DFM Reconciliation Run Summary ===
Period:  2026-01
Run ID:  20260131T093012Z
Generated: 2026-01-31 09:32:14 UTC

--- Pipeline Outcomes ---
Brown Shipley:  OK  (1,203 rows)
WH Ireland:     OK  (2,418 rows)
Pershing:       PARTIAL  (1,891 rows, 2 parse errors)
Castlebay:      OK  (322 rows)

TPIR Check:     PASSED
ADS Load:       COMMITTED  (5,834 rows)

--- AI-Generated Summary ---
<GPT-4o narrative text>

--- Action Required ---
⚠ Novel validation failures: 4  (see ai_fuzzy_resolutions.txt for candidates)
✅ No high-severity anomaly flags
```

---

## Fallback behaviour

If Azure OpenAI is unavailable, `nb_ai_narrative` writes `run_summary.txt` with the
deterministic preamble only, and adds:

```
[AI narrative unavailable — Azure OpenAI endpoint could not be reached]
```

The `ai_run_narratives` table receives a row with `narrative_text` set to the above message.
The pipeline does not fail.

---

## Config (`azure_openai_config.json` additions)

```json
{
  "narrative_deployment": "gpt-4o",
  "narrative_max_tokens": 800,
  "narrative_temperature": 0.4
}
```

A small amount of temperature is acceptable here — this is a communication task, not a
structured output task.

---

## Acceptance criteria

- `run_summary.txt` is written to the output folder for every run.
- The file contains the deterministic preamble block with correct period, run_id, DFM
  statuses, TPIR check result, and ADS load status.
- The `--- AI-Generated Summary ---` section contains at least one paragraph of coherent
  English text describing the run.
- When 4 novel failures exist, the `--- Action Required ---` section references them.
- When Azure OpenAI is unavailable, the file is still written with the preamble and a clear
  unavailability notice; `nb_run_all` does not raise an exception.
- `ai_run_narratives` has one row per run with `input_summary_json` stored for audit.
