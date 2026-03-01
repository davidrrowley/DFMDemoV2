# 19 — AI Portfolio Anomaly Detector

## Purpose

The deterministic validation rules (`MV_001`, `DATE_001`, `VAL_001`, `MAP_001`, `POP_001`)
check individual rows against fixed thresholds. None of them can detect portfolio-level
signals such as: a DFM's total holdings dropping 40% vs last month; a policy appearing for the
first time with a very large value; a currency concentration that would be unusual given prior
periods. These cross-period, portfolio-level patterns require a model with temporal context.

`nb_ai_anomaly_detector` calls GPT-4o with the current period's `policy_aggregates` alongside
the prior three periods, and asks it to identify movements that warrant investigation. The
output is a set of flagged observations in the `ai_anomaly_events` Delta table, available for
analyst review before the ADS load.

This is an AI step because the definition of "anomalous" is inherently contextual and relative:
a 30% increase is expected after a large inflow, unusual for a stable mandate, and alarming if
it appears in a position that should have been liquidated.

---

## Trigger condition

`nb_ai_anomaly_detector` is invoked by `nb_run_all` after `nb_aggregate` completes. It runs
unconditionally for every period (if Azure OpenAI is available). It is non-blocking.

---

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| `policy_aggregates` | Delta table | Current + prior 3 periods, all four DFMs |
| `azure_openai_config.json` | `/Files/config/` | Endpoint, anomaly detector deployment |

The notebook builds a structured JSON context payload for GPT-4o:

```json
{
  "current_period": "2026-01",
  "prior_periods": ["2025-12", "2025-11", "2025-10"],
  "data": {
    "wh_ireland": {
      "2026-01": { "total_bid_value_gbp": 48200000, "policy_count": 142 },
      "2025-12": { "total_bid_value_gbp": 45200000, "policy_count": 141 },
      ...
    },
    ...
  }
}
```

To avoid sending individual policy data to the LLM (data governance), only **DFM-level
aggregates** are included in the prompt. Policy-level anomaly detection is out of scope for
the PoC.

---

## Prompt design

**System prompt:**
```
You are a quantitative analyst assistant reviewing monthly fund manager holdings data.
You will be given a JSON object containing DFM-level portfolio totals for the current period
and the three preceding periods. Identify movements that a portfolio manager should be aware of.

For each observation return a JSON array where each element has:
- "dfm_id": the fund manager identifier
- "flag": a short label (e.g. "large_decrease", "new_currency_exposure", "policy_count_change")
- "severity": one of "high", "medium", "low"
- "reasoning": one sentence explaining the observation in plain English
- "pct_change": the percentage change that triggered the flag (null if not applicable)

Return ONLY the JSON array. No text outside the JSON.
```

---

## Output: `ai_anomaly_events` Delta table

| Column | Type | Description |
|--------|------|-------------|
| `event_id` | string | UUID |
| `run_id` | string | Current run |
| `period` | string | Reporting period |
| `dfm_id` | string | Affected DFM |
| `flag` | string | Short anomaly label |
| `severity` | string | `high` / `medium` / `low` |
| `reasoning` | string | One-sentence plain-English explanation from GPT-4o |
| `pct_change` | decimal(10,4) | Percentage change (nullable) |
| `status` | string | `open` (initial); analyst updates to `acknowledged` or `escalated` |
| `created_at` | timestamp | When written |
| `reviewed_by` | string | Null until actioned |
| `reviewed_at` | timestamp | Null until actioned |

Also written: `/Files/output/.../ai_anomaly_report.txt` — human-readable list of observations.

---

## Analyst workflow

1. After each run, the analyst checks the `AI Anomaly Report` section of the run summary
   (produced by `nb_ai_narrative`) or opens `ai_anomaly_report.txt`.
2. `high` severity flags are reviewed before ADS load is approved.
3. `medium` / `low` flags are informational — logged for pattern tracking over time.
4. The analyst marks each flag `acknowledged` or `escalated` in `ai_anomaly_events`.
5. `nb_ads_load` does **not** gate on anomaly flags — the load proceeds regardless. The flags
   are advisory; the analyst decides whether to hold the run.

---

## Guardrails

- Only DFM-level aggregates (not individual policy or security data) are sent to Azure OpenAI.
  This limits data exposure to aggregate totals, which are not commercially sensitive at the
  level of individual positions.
- If fewer than 2 prior periods exist in `policy_aggregates`, the notebook skips analysis and
  writes a single `ai_anomaly_events` row with `flag=insufficient_history`.

---

## Error handling

| Condition | Behaviour |
|-----------|-----------|
| Azure OpenAI call fails | Log warning; skip anomaly events for this run; pipeline continues |
| GPT-4o returns invalid JSON | Attempt JSON extraction; if unrecoverable, log `flag=llm_parse_error` |
| Fewer than 2 prior periods | Write `flag=insufficient_history`; no API call |

---

## Config (`azure_openai_config.json` additions)

```json
{
  "anomaly_detector_deployment": "gpt-4o",
  "anomaly_detector_max_tokens": 1500,
  "anomaly_detector_temperature": 0.2,
  "anomaly_min_prior_periods": 2
}
```

---

## Acceptance criteria

- `ai_anomaly_events` receives at least one row per run when prior periods exist.
- A seeded 40% DFM-level total decrease vs previous period produces a row with
  `severity=high`.
- No individual policy or security data appears in the LLM prompt (verified by inspection of
  the prompt construction code).
- When fewer than 2 prior periods exist, `flag=insufficient_history` is written and no Azure
  OpenAI call is made.
- `nb_ads_load` proceeds regardless of anomaly event severity.
