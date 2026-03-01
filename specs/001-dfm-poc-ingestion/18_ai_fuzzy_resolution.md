# 18 — AI Fuzzy Security and Policy Resolver

## Purpose

When `MAP_001` or `POP_001` fires because a security or policy cannot be found in the lookup
tables, the analyst currently must manually search the ISIN Master List or Spice exports to find
the correct row and add it. This spec defines `nb_ai_fuzzy_resolver`, which uses
`text-embedding-3-small` embeddings and cosine similarity to suggest the most likely matches
from the existing lookup tables, surfacing them as ranked candidates in `ai_resolution_suggestions`.

This is an AI step because the matching is ambiguous at the character level: DFM names like
`"Vodafone Grp PLC 8.125% 2014"` must be matched to master list entries like
`"Vodafone Group Public Limited Company 8.125% Notes due 2014"`. No deterministic string rule
handles this reliably across all DFMs and all asset classes.

---

## Trigger condition

`nb_ai_fuzzy_resolver` is invoked by `nb_run_all` after `nb_validate` completes, if and only
if `validation_events` contains one or more rows for the current `run_id` where
`rule_id IN ('MAP_001', 'POP_001')` and `status = 'fail'`. It is non-blocking.

---

## Approach: in-memory cosine similarity

At PoC scale (≤10,000 securities in `security_master.csv`, ≤5,000 policies in
`policy_mapping.csv`), Azure AI Search is not required. The notebook loads both lookup files
into the Spark driver, embeds each entry name using `text-embedding-3-small` in batches, and
performs in-memory top-k cosine similarity for each unresolved failure.

```python
# Pseudocode — shared_ai_utils.py
def embed_texts(texts: list[str], config: dict) -> list[list[float]]:
    # Calls Azure OpenAI text-embedding-3-small in batches of 100
    ...

def cosine_top_k(query_emb: list[float],
                 candidate_embs: list[list[float]],
                 candidates: list[str],
                 k: int = 3) -> list[tuple[str, float]]:
    # Returns [(candidate_name, score), ...] sorted descending
    ...
```

---

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| `validation_events` | Delta table | MAP_001 / POP_001 fail rows for current run_id |
| `canonical_holdings` | Delta table | Source rows for the unresolved failures (for context) |
| `security_master.csv` | `/Files/config/` | Full security master (ISIN, SEDOL, asset_name) |
| `policy_mapping.csv` | `/Files/config/` | Full policy mapping (dfm_policy_ref, ih_policy_ref, status) |
| `azure_openai_config.json` | `/Files/config/` | Endpoint, embedding deployment name |

---

## Output

One row per unresolved failure written to `ai_resolution_suggestions`:

| Column | Type | Description |
|--------|------|-------------|
| `suggestion_id` | string | UUID |
| `run_id` | string | Current run |
| `period` | string | Current period |
| `suggestion_type` | string | `security_match` or `policy_match` |
| `dfm_id` | string | Source DFM |
| `trigger_event_id` | string | FK to `validation_events` row |
| `unresolved_value` | string | The raw name/identifier that failed to match |
| `candidates_json` | string | JSON array of top-3: `[{"value": "...", "score": 0.94}, ...]` |
| `top_candidate` | string | Highest-scoring candidate name |
| `top_score` | decimal(5,4) | Cosine similarity score (0.0–1.0) |
| `status` | string | `pending_review` |
| `created_at` | timestamp | When written |
| `reviewed_by` | string | Null until actioned |
| `reviewed_at` | timestamp | Null until actioned |

Also written: `/Files/output/.../ai_fuzzy_resolutions.txt` — human-readable table of failures
and candidates for analyst review.

---

## Confidence thresholds

| Top score | Interpretation | Display in report |
|-----------|---------------|-------------------|
| ≥ 0.92 | High confidence — likely the correct match | ✅ "Strong match: ..." |
| 0.80–0.91 | Medium confidence — plausible match | ⚠️ "Possible match: ..." |
| < 0.80 | Low confidence — no reliable candidate found | ❌ "No confident match found" |

---

## Analyst workflow

1. After a run with MAP_001 or POP_001 failures, the analyst reviews
   `ai_fuzzy_resolutions.txt` or queries `ai_resolution_suggestions` filtered to the current
   `run_id`.
2. For high-confidence suggestions, they confirm and add the row to `security_master.csv` or
   `policy_mapping.csv`.
3. They re-run the pipeline for the same period (idempotency ensures no duplicate rows).
4. They mark the suggestion `accepted` or `rejected` in `ai_resolution_suggestions`.

The notebook does **not** modify `security_master.csv` or `policy_mapping.csv` autonomously.

---

## Error handling

| Condition | Behaviour |
|-----------|-----------|
| Embedding API call fails | Log warning; skip suggestion for that failure; continue |
| `security_master.csv` or `policy_mapping.csv` absent | Log `not_evaluable`; skip |
| No MAP_001/POP_001 failures | Notebook exits immediately; no API calls made |

---

## Config (`azure_openai_config.json` additions)

```json
{
  "embedding_deployment": "text-embedding-3-small",
  "embedding_batch_size": 100,
  "fuzzy_top_k": 3
}
```

---

## Acceptance criteria

- `ai_resolution_suggestions` receives a row with `suggestion_type=security_match` for each
  unique unresolved security in MAP_001 failures.
- `candidates_json` contains 3 ranked entries when ≥3 candidates exist in `security_master.csv`.
- A known mismatch (e.g. `"Vodafone Grp"` vs `"Vodafone Group PLC"`) produces
  `top_score ≥ 0.90`.
- No calls to Azure OpenAI embedding API are made when there are no MAP_001/POP_001 failures.
- `security_master.csv` and `policy_mapping.csv` are not modified by this notebook.
