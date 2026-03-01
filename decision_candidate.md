# Decision candidate

## Decision

Confirm the transport mechanism for loading `tpir_load_equivalent` data into ADS (Asset Data Store).

## Context

The `16_ads_loading.md` spec and `apps/api/openapi.yaml` define ADS loading as a REST API call (`POST /api/v1/tpir/load`) authenticated via Azure Managed Identity. This assumed REST because `openapi.yaml` is the designated API contract file in the repo scaffold. However, the existing manual process loads via a standalone "TPIR Upload Checker" tool whose internal mechanism is undocumented — it may use a different transport (file-drop to a shared folder, SFTP, direct database insert, or a proprietary ADS client). The wrong assumption here could misalign the PoC output format with the real ADS intake path.

## Options

- **Option A — REST API (current assumption)**: ADS exposes a REST endpoint accepting JSON batches of tpir_load records. Authentication via Azure Managed Identity bearer token. Enables status polling, idempotency on `run_id`, and a clear API contract. Requires ADS team to expose an endpoint if one does not already exist.

- **Option B — File-drop to shared folder**: `nb_ads_load` writes a CSV (or JSON) file to a network share or OneLake path that ADS monitors and ingests. Simpler to implement in the PoC; no API contract required. Less robust — no acknowledgement, no idempotency, no structured error reporting.

- **Option C — SFTP transfer**: `tpir_load_equivalent` is exported as a fixed-format CSV and transferred to an SFTP server monitored by ADS. Common in legacy financial operations environments. Requires SFTP credentials and outbound connectivity from Fabric (may conflict with the "no outbound internet" constraint).

- **Option D — Direct database insert**: Pipeline writes directly to the ADS database (SQL or otherwise) using a JDBC connection. Bypasses any API/file layer but creates tight coupling to ADS schema and requires database credentials (conflicts with Managed Identity constraint).

## Recommendation

**Option A (REST API)** is the preferred approach for a new-build PoC: it provides a clean contract, idempotency on `run_id`, structured error responses, and aligns with the Managed Identity authentication constraint. The `apps/api/openapi.yaml` spec is ready.

**However, this decision must be confirmed with the ADS system owner before T023 (nb_ads_load) is implemented.** If ADS does not expose or plan to expose a REST endpoint, Option B (file-drop) is the lowest-friction fallback for the PoC.

## Consequences

- If Option A is confirmed: proceed with T022–T023 as specced; ADS team must provide the base URL and confirm the `run_id` idempotency contract.
- If Option B is chosen: `16_ads_loading.md` and `openapi.yaml` must be updated; `nb_ads_load` becomes a file-write operation; the TPIR check result still gates the write.
- If this is not resolved before T023 begins: T023 should be implemented with a configurable transport adapter so the mechanism can be switched without re-implementing the notebook logic.

---

## Decision: GPT-4o vs GPT-4o-mini for AI steps

### Context

The five AI pipeline steps (schema mapping, fuzzy resolution, anomaly detection, exception
triage, narrative generation) have different quality and latency requirements. Using GPT-4o for
all steps maximises quality but increases cost and latency. GPT-4o-mini is faster and cheaper
but may produce lower quality for complex reasoning tasks.

### Recommendation by step

| Step | Recommended model | Rationale |
|------|------------------|-----------|
| `nb_ai_schema_mapper` | GPT-4o | Schema mapping is ambiguous and must produce structured JSON precisely |
| `nb_ai_fuzzy_resolver` | `text-embedding-3-small` only | Fuzzy matching uses embeddings; no LLM call needed |
| `nb_ai_anomaly_detector` | GPT-4o | Cross-period reasoning requires deeper analytical capability |
| `nb_ai_exception_triage` | GPT-4o-mini | Classification task; lower complexity; cost/quality tradeoff acceptable |
| `nb_ai_narrative` | GPT-4o | Quality of analyst-facing narrative matters; GPT-4o-mini produces flatter prose |

This decision is captured in `azure_openai_config.json` via per-step deployment name fields
and can be changed without code modification.

**Status: Recommended — awaiting confirmation after T025 smoke test.**

---

## Decision: In-memory embedding search vs Azure AI Search

### Context

`nb_ai_fuzzy_resolver` must perform similarity search over `security_master.csv` (≤10,000
entries) and `policy_mapping.csv` (≤5,000 entries). Two options exist:

- **Option A — In-memory cosine similarity (recommended for PoC)**: Load both files into the
  Spark driver memory, embed all entries on first call (cached), perform cosine similarity in
  NumPy. No additional Azure resource required. Latency: ~5–15 seconds on first call; sub-second
  on subsequent calls within the same session.

- **Option B — Azure AI Search**: Index `security_master.csv` and `policy_mapping.csv` as
  vector search indexes. Requires provisioning Azure AI Search (Basic SKU ~£70/month),
  managing index refresh on file updates, and additional network connectivity.

### Recommendation

**Option A (in-memory)** for the PoC. At ≤15,000 total candidates, in-memory search is
practical. Azure AI Search should be revisited if the security master grows beyond ~50,000
entries or if sub-second latency on cold start becomes a requirement.

**Status: Decided — Option A adopted in `18_ai_fuzzy_resolution.md`.**
