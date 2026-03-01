# Constraints

## Business

- **PoC scope only** — This is a proof-of-concept targeting the four existing DFMs (Brown Shipley, WH Ireland, Pershing, Castlebay). Onboarding additional DFMs is out of scope for the PoC.
- **Single period per run** — The pipeline processes one `YYYY-MM` period per invocation. Multi-period backfill is out of scope for the PoC.
- **Preserve tpir_load contract** — The 13-column `tpir_load_equivalent` schema and `Policyholder_Number` key must exactly match the existing contract consumed by ADS. Any schema change requires a change request against the ADS team.
- **Manual config uploads remain** — For the PoC, the analyst manually uploads `fx_rates.csv`, `security_master.csv`, and `policy_mapping.csv` before each run. Automated sourcing of these inputs is a post-PoC enhancement.
- **Timeline** — PoC must complete within the current quarter. Full productionisation is a follow-on workstream.

## Technical

- **Platform: Microsoft Fabric only** — All compute, storage, and orchestration must use the Microsoft Fabric Lakehouse. No external compute (AWS, GCP, on-prem Spark) is permitted.
- **PySpark notebooks** — Implementation language is Python/PySpark running in Fabric notebooks. No Scala, Java, or R.
- **Delta Lake** — All persistent data (canonical_holdings, validation_events, etc.) must be in Delta format in OneLake. Parquet or CSV is permitted only for output reports and config inputs.
- **No outbound internet from notebooks — except Azure internal services** — Notebooks cannot make direct calls to external data sources (Bloomberg, company websites, etc.), and all reference data must be pre-uploaded to `/Files/config/` by the analyst. Azure-internal services accessed via Azure Managed Identity (Azure OpenAI, ADS REST API) are explicitly permitted, as they do not constitute outbound internet traffic from a network trust boundary perspective.
- **Azure OpenAI for AI capabilities** — The five AI steps (`nb_ai_schema_mapper`, `nb_ai_fuzzy_resolver`, `nb_ai_anomaly_detector`, `nb_ai_exception_triage`, `nb_ai_narrative`) must call the Azure OpenAI resource provisioned within the same tenant via `infra/bicep/azure-openai.bicep`. No calls to the public OpenAI API (`api.openai.com`) are permitted.
- **AI steps are non-blocking** — AI notebook failures must never cause `nb_run_all` to raise an unrecoverable exception. All AI steps degrade gracefully (see per-spec error handling sections 17–21).
- **ADS connection via REST API** — ADS is reached only via its REST API (defined in `apps/api/openapi.yaml`). No direct database connection or file-drop to ADS is in scope.
- **Authentication via Azure Managed Identity** — No secrets, passwords, or API keys may be stored in notebook code or config files. ADS and any other authenticated services must be accessed via Azure Managed Identity bearer tokens.
- **Run time ≤ 30 minutes** — End-to-end pipeline execution (ingestion through ADS load acknowledgement) must complete within 30 minutes on Fabric shared compute.
- **No bank holiday calendars** — `DATE_001` uses a weekend-only working day approximation. Full bank holiday calendar support is a post-PoC enhancement.

## Legal / compliance

- **No PII in logs or output** — Holdings data and policy references are commercially sensitive. `parse_errors`, `schema_drift_events`, and `run_audit_log` must not contain individual policyholder names, national insurance numbers, or other personal data. Policy reference numbers are permitted as they are internal system identifiers.
- **Data access restricted to Operations team** — The Fabric workspace and OneLake storage must be access-controlled to the investment operations team and authorised technical staff only.
- **FX rates from approved source** — Exchange rates used in `fx_rates.csv` must originate from the firm's approved market data provider (treasury system or Bloomberg). Use of unapproved rate sources would create a valuation compliance risk.
- **Audit trail mandatory** — All production runs must produce a `run_audit_log` row per DFM and a `reconciliation_summary.json`. These artefacts may be required for regulatory review or internal audit.
