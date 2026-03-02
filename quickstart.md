# Quickstart: Move From Planning to Execution

This guide is the repo-level execution entrypoint. Use it when you are ready to start implementation work from existing specs.

## 1. Confirm the operating model first

Activities:
- Work only from `specs/` features.
- Treat `tasks.md` as the source of execution truth.
- Ensure every task has `owner`, `acceptance`, and `validate`.

Read for depth:
- `AGENT_PIPELINE.md`
- `AGENTS.md`
- `agents/contracts/task-block.md`
- `agents/routing.yml`

## 2. Select the feature and verify spec completeness

Activities:
- Pick the active feature folder under `specs/`.
- Confirm `spec.md`, `plan.md`, and `tasks.md` all exist.
- Verify task owners match valid IDs in the registry.

Read for depth:
- `specs/README.md`
- `agents/registry/agents.v1.yml`
- `.github/workflows/spec-governance.yml`
- `scripts/spec_governance/check_specs.py`

## 3. Establish hard constraints before writing code

Activities:
- Review non-negotiable business and technical constraints.
- Confirm implementation choices do not violate platform/security limits.

Read for depth:
- `constraints.md`
- `docs/security/`
- `docs/standards/`

## 4. Build the day-0 execution baseline

Activities:
- Prepare platform prerequisites for the selected feature.
- Stage configuration files and required inputs.
- Create or verify core runtime artifacts before feature logic.

Read for depth (current ingestion feature):
- `specs/001-dfm-poc-ingestion/plan.md`
- `specs/001-dfm-poc-ingestion/tasks.md`
- `specs/001-dfm-poc-ingestion/quickstart.md`
- `specs/001-dfm-poc-ingestion/00_overview.md`

## 5. Execute in dependency order, parallelize safely

Activities:
- Start with setup/foundational tasks first.
- Run independent tasks in parallel only when `depends_on` allows it.
- Record progress in `tasks.md` using a short "Last known state" note.

Read for depth:
- `specs/001-dfm-poc-ingestion/tasks.md`
- `AGENT_PIPELINE.md`

Suggested first execution slice for ingestion:
- `T001` and `T002` (setup)
- `T003` to `T005` (foundational)
- Then move to user story phases (`T006+`) per dependencies

## 6. Validate continuously, not only at the end

Activities:
- For each completed task, prove the `acceptance` outcomes.
- Run the `validate` checks listed in the task block.
- Capture implementation evidence where defined.

Read for depth:
- `agents/policies/guardrails.md`
- `agents/policies/citations-and-evidence.md`
- `specs/001-dfm-poc-ingestion/05_validations.md`

## 7. Run governance checks before every PR

Activities:
- Run local spec governance checks before opening or updating a PR.
- Fix owner, acceptance, validate, or missing-file failures immediately.

Command:
```bash
python scripts/spec_governance/check_specs.py
```

Read for depth:
- `scripts/spec_governance/check_specs.py`
- `.github/workflows/spec-governance.yml`

## 8. Use this depth map by intent

- Governance and routing:
  - `AGENTS.md`
  - `AGENT_PIPELINE.md`
  - `agents/routing.yml`
  - `agents/registry/agents.v1.yml`
- Product context:
  - `specs/000-dfm-poc-product/spec.md`
  - `specs/000-dfm-poc-product/plan.md`
  - `specs/000-dfm-poc-product/roadmap.md`
  - `specs/000-dfm-poc-product/architecture.md`
- Ingestion implementation details:
  - `specs/001-dfm-poc-ingestion/spec.md`
  - `specs/001-dfm-poc-ingestion/plan.md`
  - `specs/001-dfm-poc-ingestion/tasks.md`
  - `specs/001-dfm-poc-ingestion/02_data_contracts.md`
  - `specs/001-dfm-poc-ingestion/05_validations.md`
  - `specs/001-dfm-poc-ingestion/06_outputs_and_reports.md`
  - `specs/001-dfm-poc-ingestion/07_audit_and_recon.md`

## 9. Full PoC enablement path (SC-01 to SC-17)

Activities:
- Complete the deterministic pipeline path and verify SC-01 through SC-10.
- Enable TPIR quality gate and ADS load path and verify SC-11 and SC-12.
- Enable Azure OpenAI-backed AI notebooks and verify SC-13 through SC-16.
- Enable Copilot Studio read-only analytics path and verify SC-17.

Read for depth:
- `docs/DFM_PoC_Design.md`
- `specs/001-dfm-poc-ingestion/tasks.md`
- `specs/001-dfm-poc-ingestion/15_tpir_upload_checker.md`
- `specs/001-dfm-poc-ingestion/16_ads_loading.md`
- `specs/001-dfm-poc-ingestion/17_ai_schema_mapping.md`
- `specs/001-dfm-poc-ingestion/18_ai_fuzzy_resolution.md`
- `specs/001-dfm-poc-ingestion/19_ai_anomaly_detection.md`
- `specs/001-dfm-poc-ingestion/20_ai_exception_triage.md`
- `specs/001-dfm-poc-ingestion/21_ai_narrative.md`

## 10. Files to edit before environment build

Edit the following files in `specs/001-dfm-poc-ingestion/config/` before first environment run:

- `dfm_registry.json` (Core): verify `enabled` flags for each DFM and confirm `dfm_id` values match expected landing paths.
- `raw_parsing_config.json` (Core): confirm filename patterns, sheet/header settings, and source-column mappings match your actual inbound files.
- `rules_config.json` (Core): set rule enablement and thresholds for your run policy.
- `currency_mapping.json` (Core): extend currency description mappings if new labels appear in source files.
- `fx_rates.csv` (Core): replace sample rows with period-specific FX rates.
- `security_master.csv` (Phase 8): load your security master rows (`isin`/`sedol`, names, class, currency).
- `policy_mapping.csv` (Phase 8): load DFM-to-IH policy mappings and mark `status` values (`ACTIVE`/`REMOVE`).
- `ads_config.json` (Phase 8): set ADS endpoint and runtime settings (`base_url`, `api_version`, `batch_size`, `timeout_seconds`, retry fields).
- `azure_openai_config.json` (Phase 9): set Azure OpenAI endpoint and confirm deployment names/limits match your provisioned resource.

Optional pre-build review (not required edits, but validate alignment):

- `infra/bicep/azure-openai.bicep`: confirm target region, model capacities, and the Fabric Managed Identity object ID you will pass at deployment.
- `constraints.md`: verify environment/security constraints are still valid for your tenant.

Recommended working file:

- `env-values-checklist.md`: capture all environment-specific values and signoff items before building.

## 11. Practical start-now checklist

- [ ] Choose the active feature folder in `specs/`
- [ ] Confirm `spec.md`, `plan.md`, `tasks.md` are present
- [ ] Verify task `owner` values against `agents/registry/agents.v1.yml`
- [ ] Complete setup and foundational tasks first
- [ ] Edit all environment-specific config files in `specs/001-dfm-poc-ingestion/config/` before first run
- [ ] Upload `security_master.csv`, `policy_mapping.csv`, and `ads_config.json` to `/Files/config/` for Phase 8
- [ ] Upload `azure_openai_config.json` to `/Files/config/` when enabling Phase 9 AI tasks
- [ ] Update task progress in `tasks.md` with current state and next task
- [ ] Run `python scripts/spec_governance/check_specs.py` before PR

---

If you are starting now on the current stream, begin with:
- `specs/001-dfm-poc-ingestion/tasks.md`
- `specs/001-dfm-poc-ingestion/quickstart.md`
- `constraints.md`
