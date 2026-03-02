# Environment Values Checklist

Use this file to capture all environment-specific values before building and running the PoC.

## 1. Workspace and platform

- Environment name (`staging` or `production`): `staging` (default in `infra/bicep/azure-openai.bicep`) 
- Microsoft Fabric workspace name: `TBD`
- Fabric workspace ID: `TBD`
- Fabric workspace Managed Identity object ID: `TBD`
- Lakehouse name: `TBD`
- Lakehouse OneLake base path: `TBD`
- Default reporting period (`YYYY-MM`): `2025-12` (example used in quickstarts; replace for actual run)

## 2. Core config values (SC-01 to SC-10)

Files to update:
- `specs/001-dfm-poc-ingestion/config/dfm_registry.json`
- `specs/001-dfm-poc-ingestion/config/raw_parsing_config.json`
- `specs/001-dfm-poc-ingestion/config/rules_config.json`
- `specs/001-dfm-poc-ingestion/config/currency_mapping.json`
- `specs/001-dfm-poc-ingestion/config/fx_rates.csv`

Checklist:
- DFM enablement confirmed (`dfm_registry.json`): `brown_shipley`, `wh_ireland`, `pershing`, `castlebay` are all enabled by default
- Source file naming patterns confirmed (`raw_parsing_config.json`): `TBD` (validate against inbound files)
- Rule thresholds confirmed (`rules_config.json`): `MV_001` tolerance defaults to `tolerance_abs_gbp=1.0` and `tolerance_pct=0.001`; `POP_001` defaults to `enabled=false`
- Currency descriptions mapped (`currency_mapping.json`): Castlebay mappings preloaded; extend if additional labels appear
- Current period FX rates loaded (`fx_rates.csv`): `TBD`

## 3. Phase 8 values (SC-11 to SC-12)

Files to update:
- `specs/001-dfm-poc-ingestion/config/security_master.csv`
- `specs/001-dfm-poc-ingestion/config/policy_mapping.csv`
- `specs/001-dfm-poc-ingestion/config/ads_config.json`

Checklist:
- Security master source/version: `TBD`
- Policy mapping source/version: `TBD`
- ADS base URL (`ads_config.json:base_url`): `https://ads.internal.example.com` (template value; replace)
- ADS API version (`ads_config.json:api_version`): `v1`
- ADS batch size (`ads_config.json:batch_size`): `500`
- ADS timeout seconds (`ads_config.json:timeout_seconds`): `60`
- ADS retry max attempts (`ads_config.json:retry_max_attempts`): `3`
- ADS retry backoff seconds (`ads_config.json:retry_backoff_seconds`): `5`

## 4. Phase 9 values (SC-13 to SC-17) — GitHub Models API

**Cost**: ~$5–20 for a complete PoC run (pay-as-you-go, no infrastructure).

**Important**: This phase uses **GitHub Models API** by default (no Azure OpenAI deployment needed for PoC). If you prefer Azure OpenAI later, update `use_github_models: false` in config and use the optional Bicep deployment below.

### GitHub Models Setup (Default for PoC)

Config file:
- `specs/001-dfm-poc-ingestion/config/azure_openai_config.json`

Required values:
- `use_github_models`: `true` (default)
- `github_token`: Create a Personal Access Token on github.com with `api` scope. See [GitHub Models docs](https://github.com/models).
- `github_models_endpoint`: `https://models.githubnext.com` (default; do not change)

Checklist:
- [ ] GitHub Personal Access Token created and added to `github_token` in config.
- [ ] Config file updated with your token.
- [ ] **Cost estimate**: Full PoC run (5 AI notebooks) ≈ $5–15 depending on test volume.

### Azure OpenAI (Optional, for Production Scale)

To use Azure OpenAI instead of GitHub Models, follow these steps:

#### 4a. Deploy infrastructure (Bicep)

File: `infra/bicep/azure-openai.bicep`

```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file infra/bicep/azure-openai.bicep \
  --parameters environmentName=staging fabricWorkspaceObjectId=<workspace-mi-object-id>
```

Bicep inputs:
- `environmentName`: `staging` or `production` (default: `staging`)
- `fabricWorkspaceObjectId`: Fabric workspace Managed Identity object ID (required)
- `location`: Resource group location (default)
- `gpt4oCapacityKtpm`: `30` (default)
- `gpt4oMiniCapacityKtpm`: `50` (default)
- `embeddingCapacityKtpm`: `100` (default)

#### 4b. Update config to use Azure OpenAI

In `azure_openai_config.json`:

- `use_github_models`: `false`
- `api_key`: Your Azure OpenAI API key (from deployed resource)
- `endpoint`: `https://<resource-name>.openai.azure.com/` (from deployed resource)
- `api_version`: `2024-08-01-preview` (keep as-is)

#### 4c. Verify identity and access

- Fabric workspace identity has `Cognitive Services OpenAI User` role on the Azure OpenAI resource (assigned by Bicep).
- Fabric workspace can retrieve the API key securely (e.g., via Azure Key Vault integration).

## 5. Identity and access checks

- Fabric workspace identity has access to OneLake files and Lakehouse tables.
- Fabric workspace identity has `Cognitive Services OpenAI User` on Azure OpenAI.
- ADS endpoint accepts Managed Identity bearer tokens from Fabric context.
- No secrets are committed in repository config files.

## 6. Pre-run signoff

- [ ] Core config files updated for target period.
- [ ] Phase 8 config files updated (if enabling ADS path).
- [ ] Azure OpenAI deployed and config updated (if enabling AI path).
- [ ] Governance check ready: `python scripts/spec_governance/check_specs.py`.
- [ ] Input files staged in `/Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/`.

Owner:
Date:
Notes:
