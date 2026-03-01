# 20 — AI Exception Triage Classifier

## Purpose

After validation, `validation_events` may contain dozens of failure rows. Many are expected and
recurring — Brown Shipley always lacks price data for `MV_001`, certain Castlebay rows
consistently have no accrued interest — so the analyst must read through all failures to find the
ones that are genuinely new and need action. This creates noise that obscures real problems.

`nb_ai_exception_triage` calls GPT-4o for each unique `(dfm_id, rule_id, details_summary)`
combination in the current run's failures, comparing against the failure history from the prior
3 runs, and classifies each into one of three categories:

| Label | Meaning |
|-------|---------|
| `expected_design` | This failure is by design; the spec documents it as expected (e.g. BS prices absent) |
| `expected_recurring` | This failure has appeared in every prior period; no analyst action needed |
| `novel_investigate` | This failure is new or has changed pattern; analyst must investigate |

By default, the analyst report surfaces only `novel_investigate` rows. The full set remains
queryable in `ai_triage_labels`.

This is an AI step because classifying "is this the same as last month?" across variable
failure descriptions, different DFMs, and rule-specific detail formats is a reasoning task
that a simple string-match rule cannot handle reliably.

---

## Trigger condition

`nb_ai_exception_triage` runs after `nb_validate` completes for every run with at least one
`validation_events` failure. It is non-blocking.

---

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| `validation_events` | Delta table | Current run failures |
| `validation_events` (historical) | Delta table | Same DFM+rule failures for prior 3 runs |
| `azure_openai_config.json` | `/Files/config/` | Endpoint, triage deployment |

The notebook groups failures by `(dfm_id, rule_id)` and sends one call per group to GPT-4o.
It passes the current period's failure list alongside the prior period failures, requesting a
per-failure classification.

To control cost, GPT-4o-mini is the default deployment for this step (classification is lower
complexity than schema mapping or anomaly analysis). See `decision_candidate.md` for the
GPT-4o vs GPT-4o-mini decision.

---

## Prompt design

**System prompt:**
```
You are a financial data quality assistant. You will be given validation failures from a
DFM holdings reconciliation pipeline, alongside the same failures from prior months.

Classify each current failure as one of:
- "expected_design": the pipeline spec documents this as an expected known limitation
- "expected_recurring": this exact failure pattern appeared in all prior periods provided
- "novel_investigate": this failure is new, has changed, or has not appeared before

Return a JSON array where each element has:
- "failure_id": the validation_event row_id from the input
- "label": one of the three values above
- "reasoning": one sentence explaining the classification

Return ONLY the JSON array.
```

---

## Output: `ai_triage_labels` Delta table

| Column | Type | Description |
|--------|------|-------------|
| `label_id` | string | UUID |
| `run_id` | string | Current run |
| `period` | string | Reporting period |
| `validation_event_id` | string | FK to `validation_events` |
| `dfm_id` | string | Source DFM |
| `rule_id` | string | e.g. `MV_001`, `MAP_001` |
| `label` | string | `expected_design` / `expected_recurring` / `novel_investigate` |
| `reasoning` | string | One-sentence explanation from GPT-4o-mini |
| `created_at` | timestamp | When written |

The `nb_ai_narrative` notebook uses `ai_triage_labels` to build the analyst-facing run summary.

---

## Report integration

In the generated `run_summary.txt` (from `nb_ai_narrative`), the triage results appear as:

```
Validation Triage (42 failures total):
  - 38 expected (design or recurring) — no action required
  -  4 novel — REVIEW REQUIRED:
     • MAP_001: WH Ireland — "XYZ Corp Notes 2031" not in security master
     • POP_001: Pershing — Policy P99182 not in policy mapping
     ...
```

---

## Error handling

| Condition | Behaviour |
|-----------|-----------|
| Azure OpenAI call fails | All failures for the run labelled `novel_investigate` (safe default) |
| No prior period data | All failures labelled `novel_investigate` |
| GPT-4o-mini returns invalid JSON | Attempt extraction; fallback to `novel_investigate` |

---

## Config (`azure_openai_config.json` additions)

```json
{
  "triage_deployment": "gpt-4o-mini",
  "triage_max_tokens": 2000,
  "triage_temperature": 0.0,
  "triage_prior_periods": 3
}
```

---

## Acceptance criteria

- `ai_triage_labels` receives one row per `validation_events` failure row for the current run.
- A failure matching the same `(dfm_id, rule_id, details_summary)` as the prior 3 periods is
  classified `expected_recurring`.
- A new failure not present in prior periods is classified `novel_investigate`.
- Brown Shipley `MV_001 not_evaluable` failures (by design) are classified `expected_design`
  when the system prompt includes the known-limitation context.
- When GPT-4o-mini is unavailable, all failures default to `novel_investigate` and no failures
  are silently suppressed.
