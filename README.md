# Baseline: Spec-Driven Multi-Agent Engineering Template

This repository is a baseline engineering template designed for:

- Spec-first delivery powered by spec-kit assets in `.specify/`
- A multi-agent catalogue (contracts, personas, skills, evals in `agents/`)
- IBM Carbon aligned UX structure (`apps/web/`)

The goal is repeatability: every new project starts with the same structure, guardrails, and working loop.

---

## Agent-native workflow

- Agent catalogue: `AGENTS.md`
- Operating pipeline: `AGENT_PIPELINE.md`
- Task block contract: `agents/contracts/task-block.md`
- Routing defaults: `agents/routing.yml`
- Governance checks: `.github/workflows/agent-governance.yml`

Platform UI agents: `frontend-carbon` (web), `windows-fluent` (Windows), `android-material` (Android).

Source of truth: root docs are canonical. The `origin/` tree is a baseline snapshot used by scaffold/refresh scripts.

## Start here

Specs drive delivery.

- Spec-kit engine and templates: `.specify/`
- Product and feature specs: `specs/`
- Agent operating model: `AGENTS.md`
- Agent contracts and routing: `agents/registry/agents.v1.yml`, `agents/routing.yml`

The constitution (shared principles and constraints) lives in:

```
.specify/memory/constitution.md
```

## Governance entry points

- Guardrails and required output structure: `agents/policies/guardrails.md`
- Evidence and citation rules: `agents/policies/citations-and-evidence.md`

## Quick start

### 1) Create a new feature spec bundle

From repo root, run:

```powershell
pwsh .\.specify\scripts\powershell\create-new-feature.ps1 -ShortName "demo" -Number 1 "Describe the feature in one paragraph"
```

This creates a folder under:

```
specs/<branch-name>/
```

with:

- `spec.md`
- (and later) `plan.md`, `tasks.md`

If you are on Windows PowerShell 5.1, install PowerShell 7 (`pwsh`) to run the spec-kit scripts.

### 2) Fill in the spec

Edit the newly created:

```
specs/<feature>/spec.md
```

Add testable acceptance criteria.

### 3) Orchestrate the work

Use the Orchestrator to route work to specialist agents.

Agent contracts live in:

```
agents/registry/agents.v1.yml
```

### 4) Build

Implement in:

```
apps/
```

---

## Operating model

This repo runs a simple loop:

```
Spec → Orchestrate → Execute → Verify → Document
```

- Spec: define outcomes and acceptance criteria in `specs/<feature>/`
- Orchestrate: route to the right agents via the registry
- Execute: agents run reusable skills (`agents/skills/`)
- Verify: include validation steps and evidence
- Document: capture key decisions as ADRs (`docs/adr/`)

---

## Continuity and resume

Keep a comprehensive, running to-do list in `specs/<feature>/tasks.md`. Update task status and `depends_on` as work progresses, and add a short "Last known state" note at the top (date, last completed task, next task). If a session is interrupted, resume from this note instead of re-running `/specify`.

---

## Agent model

- Agent = WHO + HOW it thinks (persona)
- Skill = WHAT it does (reusable capability with a rubric)

Skills live in:

```
agents/skills/<skill-name>/
```

Each skill contains:

- `skill.md` (contract)
- `prompt.md` (execution instructions)
- `rubric.md` (quality evaluation)

---

## Included skills (baseline)

This template ships with a starter set of skills. Full index:

```
agents/skills/SKILLS_INDEX.md
```

Common baseline capabilities include:

- orchestration-routing
- spec-normalisation
- task-breakdown
- architecture-review
- adr-writing
- code-review
- ux-carbon-critique
- security-review
- doc-hygiene

---

## Repository layout

```
.specify/   → spec-kit engine (templates, scripts, memory)
agents/     → agent registry, prompts, skills, policies, evals
apps/       → product code (web/api)
docs/       → standards, ADRs, runbooks
infra/      → infrastructure definitions
packages/   → shared libraries
```

---

## Platform UI standards

UI standards are defined per platform. Web uses IBM Carbon, Windows uses Fluent UI, and Android uses Material Design 3. See `docs/standards/ui-platform-standards.md`.

Platform UI agents: `frontend-carbon` (web), `windows-fluent` (Windows), `android-material` (Android).

---

## Repository file index

Descriptions are inferred from file paths and naming conventions. Update any row that needs a more precise purpose.

| File | Purpose |
| --- | --- |
| .editorconfig | EditorConfig settings. |
| .env.example | Environment variable template. |
| .gitattributes | Git attributes configuration. |
| .github/dependabot.yml | Dependabot update configuration. |
| .github/ISSUE_TEMPLATE/.gitkeep | Placeholder to keep issue template directory in git. |
| .github/ISSUE_TEMPLATE/bug-report.md | GitHub issue template. |
| .github/ISSUE_TEMPLATE/feature-task.md | GitHub issue template. |
| .github/PULL_REQUEST_TEMPLATE.md | Pull request template. |
| .github/workflows/agent-governance.yml | GitHub Actions workflow. |
| .github/workflows/ci.yml | GitHub Actions workflow. |
| .github/workflows/codeql.yml | GitHub Actions workflow. |
| .github/workflows/release.yml | GitHub Actions workflow. |
| .github/workflows/security.yml | GitHub Actions workflow. |
| .gitignore | Git ignore rules. |
| .markdownlint-cli2.jsonc | Markdownlint configuration. |
| .prettierrc | Prettier configuration. |
| .specify/memory/constitution.md | Project constitution and constraints. |
| .specify/README.md | Spec-kit usage notes. |
| .specify/scripts/powershell/check-prerequisites.ps1 | Spec-kit PowerShell automation script. |
| .specify/scripts/powershell/common.ps1 | Spec-kit PowerShell automation script. |
| .specify/scripts/powershell/create-new-feature.ps1 | Spec-kit PowerShell automation script. |
| .specify/scripts/powershell/setup-plan.ps1 | Spec-kit PowerShell automation script. |
| .specify/scripts/powershell/update-agent-context.ps1 | Spec-kit PowerShell automation script. |
| .specify/specs/.gitkeep | Placeholder to keep spec template directory in git. |
| .specify/templates/agent-file-template.md | Spec-kit template file. |
| .specify/templates/checklist-template.md | Spec-kit template file. |
| .specify/templates/constitution-template.md | Spec-kit template file. |
| .specify/templates/plan-template.md | Spec-kit template file. |
| .specify/templates/spec-template.md | Spec-kit template file. |
| .specify/templates/tasks-template.md | Spec-kit template file. |
| AGENT_PIPELINE.md | Agent operating pipeline and quality gates. |
| AGENTS.md | Agent catalogue and workflow requirements. |
| agents/contracts/agent-registry.schema.json | Agent registry schema. |
| agents/contracts/agent-routing.schema.json | Agent routing schema. |
| agents/contracts/task-block.md | Task block contract for specs. |
| agents/evals/.gitkeep | Placeholder to keep evals directory in git. |
| agents/outputs/.gitkeep | Placeholder to keep outputs directory in git. |
| agents/policies/citations-and-evidence.md | Citation and evidence rules. |
| agents/policies/guardrails.md | Guardrails and output requirements. |
| agents/prompts/adr-logger/system.md | Agent persona and system prompt. |
| agents/prompts/api-design/system.md | Agent persona and system prompt. |
| agents/prompts/app-dotnet/README.md | Agent prompt usage notes. |
| agents/prompts/app-dotnet/system.md | Agent persona and system prompt. |
| agents/prompts/app-go/README.md | Agent prompt usage notes. |
| agents/prompts/app-go/system.md | Agent persona and system prompt. |
| agents/prompts/app-java/README.md | Agent prompt usage notes. |
| agents/prompts/app-java/system.md | Agent persona and system prompt. |
| agents/prompts/app-python/README.md | Agent prompt usage notes. |
| agents/prompts/app-python/system.md | Agent persona and system prompt. |
| agents/prompts/app-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/appsec-tooling/system.md | Agent persona and system prompt. |
| agents/prompts/app-typescript/README.md | Agent prompt usage notes. |
| agents/prompts/app-typescript/system.md | Agent persona and system prompt. |
| agents/prompts/android-material/README.md | Agent prompt usage notes. |
| agents/prompts/android-material/system.md | Agent persona and system prompt. |
| agents/prompts/architect/system.md | Agent persona and system prompt. |
| agents/prompts/azure-fullstack/README.md | Agent prompt usage notes. |
| agents/prompts/azure-fullstack/system.md | Agent persona and system prompt. |
| agents/prompts/cicd-engineer/system.md | Agent persona and system prompt. |
| agents/prompts/cloud-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/data-analytics-scrum-master/README.md | Agent prompt usage notes. |
| agents/prompts/data-analytics-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/devex-tooling-scrum-master/README.md | Agent prompt usage notes. |
| agents/prompts/devex-tooling-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/frontend-carbon/system.md | Agent persona and system prompt. |
| agents/prompts/orchestrator/system.md | Agent persona and system prompt. |
| agents/prompts/platform-infra-scrum-master/README.md | Agent prompt usage notes. |
| agents/prompts/platform-infra-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/qa-testing-scrum-master/README.md | Agent prompt usage notes. |
| agents/prompts/qa-testing-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/repo-steward/system.md | Agent persona and system prompt. |
| agents/prompts/security-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/speckit-requirements/system.md | Agent persona and system prompt. |
| agents/prompts/terraform-iac/README.md | Agent prompt usage notes. |
| agents/prompts/terraform-iac/system.md | Agent persona and system prompt. |
| agents/prompts/threat-model/system.md | Agent persona and system prompt. |
| agents/prompts/ux-critic/system.md | Agent persona and system prompt. |
| agents/prompts/ux-design-scrum-master/README.md | Agent prompt usage notes. |
| agents/prompts/ux-design-scrum-master/system.md | Agent persona and system prompt. |
| agents/prompts/windows-fluent/README.md | Agent prompt usage notes. |
| agents/prompts/windows-fluent/system.md | Agent persona and system prompt. |
| agents/providers/claude/subagents/architect.md | Claude subagent prompt. |
| agents/providers/claude/subagents/orchestrator-pgm.md | Claude subagent prompt. |
| agents/providers/microsoft/README.md | Provider configuration notes. |
| agents/providers/openai/README.md | Provider configuration notes. |
| agents/README.md | Agents directory overview. |
| agents/registry/agents.v1.yml | Agent registry definitions. |
| agents/routing.yml | Default agent routing rules. |
| agents/skills/adr-writing/prompt.md | Skill execution prompt. |
| agents/skills/adr-writing/rubric.md | Skill quality rubric. |
| agents/skills/adr-writing/skill.md | Skill contract and intent. |
| agents/skills/architecture-review/prompt.md | Skill execution prompt. |
| agents/skills/architecture-review/rubric.md | Skill quality rubric. |
| agents/skills/architecture-review/skill.md | Skill contract and intent. |
| agents/skills/code-review/prompt.md | Skill execution prompt. |
| agents/skills/code-review/rubric.md | Skill quality rubric. |
| agents/skills/code-review/skill.md | Skill contract and intent. |
| agents/skills/doc-hygiene/prompt.md | Skill execution prompt. |
| agents/skills/doc-hygiene/rubric.md | Skill quality rubric. |
| agents/skills/doc-hygiene/skill.md | Skill contract and intent. |
| agents/skills/orchestration-routing/prompt.md | Skill execution prompt. |
| agents/skills/orchestration-routing/rubric.md | Skill quality rubric. |
| agents/skills/orchestration-routing/skill.md | Skill contract and intent. |
| agents/skills/README.md | Skills overview and structure. |
| agents/skills/security-review/prompt.md | Skill execution prompt. |
| agents/skills/security-review/rubric.md | Skill quality rubric. |
| agents/skills/security-review/skill.md | Skill contract and intent. |
| agents/skills/SKILLS_INDEX.md | Index of available skills. |
| agents/skills/spec-normalisation/prompt.md | Skill execution prompt. |
| agents/skills/spec-normalisation/rubric.md | Skill quality rubric. |
| agents/skills/spec-normalisation/skill.md | Skill contract and intent. |
| agents/skills/task-breakdown/prompt.md | Skill execution prompt. |
| agents/skills/task-breakdown/rubric.md | Skill quality rubric. |
| agents/skills/task-breakdown/skill.md | Skill contract and intent. |
| agents/skills/ux-carbon-critique/prompt.md | Skill execution prompt. |
| agents/skills/ux-carbon-critique/rubric.md | Skill quality rubric. |
| agents/skills/ux-carbon-critique/skill.md | Skill contract and intent. |
| agents/tools/.gitkeep | Placeholder to keep tools directory in git. |
| apps/api/openapi.yaml | API contract definition. |
| apps/api/README.md | API app overview. |
| apps/api/src/.gitkeep | Placeholder to keep API source directory in git. |
| apps/android/README.md | Android app overview. |
| apps/android/src/.gitkeep | Placeholder to keep Android source directory in git. |
| apps/web/carbon/fonts/README.md | Font guidance for Carbon UI. |
| apps/web/carbon/layout/.gitkeep | Placeholder to keep Carbon layout directory in git. |
| apps/web/carbon/theme.scss | Carbon theme overrides. |
| apps/web/public/.gitkeep | Placeholder to keep web public directory in git. |
| apps/web/README.md | Web app overview. |
| apps/web/src/.gitkeep | Placeholder to keep web source directory in git. |
| apps/windows/README.md | Windows app overview. |
| apps/windows/src/.gitkeep | Placeholder to keep Windows source directory in git. |
| constraints.md | Project constraints and non-negotiables. |
| data_flows.md | System data flow notes. |
| decision_candidate.md | Draft decision record for review. |
| docs/adr/0000-template.md | ADR template. |
| docs/adr/index.md | ADR index. |
| docs/api/versioning.md | API versioning guidelines. |
| docs/architecture/architecture.md | System architecture overview. |
| docs/architecture/README.md | Architecture docs index. |
| docs/architecture/risks.md | Architecture risks and mitigations. |
| docs/onboarding.md | Project onboarding guide. |
| docs/README.md | Docs entry point and guidance. |
| docs/runbooks/ci-cd.md | Operational runbook. |
| docs/runbooks/incident-basics.md | Operational runbook. |
| docs/runbooks/local-dev.md | Operational runbook. |
| docs/security/mitigations.md | Security mitigations. |
| docs/security/README.md | Security docs index. |
| docs/security/threat_model.md | Threat model. |
| docs/standards/accessibility.md | Engineering standards document. |
| docs/standards/engineering-standards.md | Engineering standards document. |
| docs/standards/security-baseline.md | Engineering standards document. |
| docs/standards/ui-platform-standards.md | Engineering standards document. |
| docs/standards/ux-standards-carbon.md | Engineering standards document. |
| eslint.config.js | ESLint configuration. |
| infra/local/docker-compose.yml | Local infrastructure compose file. |
| infra/README.md | Infrastructure overview. |
| justfile | Just task runner commands. |
| LICENSE | Project license. |
| origin/.github/ISSUE_TEMPLATE/.gitkeep | Baseline snapshot of: Placeholder to keep issue template directory in git. |
| origin/.github/ISSUE_TEMPLATE/bug-report.md | Baseline snapshot of: GitHub issue template. |
| origin/.github/ISSUE_TEMPLATE/feature-task.md | Baseline snapshot of: GitHub issue template. |
| origin/.github/PULL_REQUEST_TEMPLATE.md | Baseline snapshot of: Pull request template. |
| origin/.specify/memory/constitution.md | Baseline snapshot of: Project constitution and constraints. |
| origin/.specify/README.md | Baseline snapshot of: Spec-kit usage notes. |
| origin/.specify/scripts/powershell/check-prerequisites.ps1 | Baseline snapshot of: Spec-kit PowerShell automation script. |
| origin/.specify/scripts/powershell/common.ps1 | Baseline snapshot of: Spec-kit PowerShell automation script. |
| origin/.specify/scripts/powershell/create-new-feature.ps1 | Baseline snapshot of: Spec-kit PowerShell automation script. |
| origin/.specify/scripts/powershell/setup-plan.ps1 | Baseline snapshot of: Spec-kit PowerShell automation script. |
| origin/.specify/scripts/powershell/update-agent-context.ps1 | Baseline snapshot of: Spec-kit PowerShell automation script. |
| origin/.specify/specs/.gitkeep | Baseline snapshot of: Placeholder to keep spec template directory in git. |
| origin/.specify/templates/agent-file-template.md | Baseline snapshot of: Spec-kit template file. |
| origin/.specify/templates/checklist-template.md | Baseline snapshot of: Spec-kit template file. |
| origin/.specify/templates/constitution-template.md | Baseline snapshot of: Spec-kit template file. |
| origin/.specify/templates/plan-template.md | Baseline snapshot of: Spec-kit template file. |
| origin/.specify/templates/spec-template.md | Baseline snapshot of: Spec-kit template file. |
| origin/.specify/templates/tasks-template.md | Baseline snapshot of: Spec-kit template file. |
| origin/AGENTS.md | Baseline snapshot of: Agent catalogue and workflow requirements. |
| origin/agents/evals/.gitkeep | Baseline snapshot of: Placeholder to keep evals directory in git. |
| origin/agents/outputs/.gitkeep | Baseline snapshot of: Placeholder to keep outputs directory in git. |
| origin/agents/policies/citations-and-evidence.md | Baseline snapshot of: Citation and evidence rules. |
| origin/agents/policies/guardrails.md | Baseline snapshot of: Guardrails and output requirements. |
| origin/agents/prompts/api-design/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/appsec-tooling/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/android-material/README.md | Baseline snapshot of: Agent prompt usage notes. |
| origin/agents/prompts/android-material/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/architect/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/cicd-engineer/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/frontend-carbon/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/orchestrator/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/repo-steward/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/speckit-requirements/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/threat-model/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/ux-critic/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/prompts/windows-fluent/README.md | Baseline snapshot of: Agent prompt usage notes. |
| origin/agents/prompts/windows-fluent/system.md | Baseline snapshot of: Agent persona and system prompt. |
| origin/agents/providers/claude/subagents/architect.md | Baseline snapshot of: Claude subagent prompt. |
| origin/agents/providers/claude/subagents/orchestrator-pgm.md | Baseline snapshot of: Claude subagent prompt. |
| origin/agents/providers/microsoft/README.md | Baseline snapshot of: Provider configuration notes. |
| origin/agents/providers/openai/README.md | Baseline snapshot of: Provider configuration notes. |
| origin/agents/registry/agents.v1.yml | Baseline snapshot of: Agent registry definitions. |
| origin/agents/routing.yml | Baseline snapshot of: Default agent routing rules. |
| origin/agents/skills/adr-writing/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/adr-writing/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/adr-writing/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/architecture-review/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/architecture-review/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/architecture-review/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/code-review/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/code-review/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/code-review/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/doc-hygiene/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/doc-hygiene/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/doc-hygiene/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/orchestration-routing/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/orchestration-routing/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/orchestration-routing/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/README.md | Baseline snapshot of: Skills overview and structure. |
| origin/agents/skills/security-review/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/security-review/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/security-review/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/spec-normalisation/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/spec-normalisation/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/spec-normalisation/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/task-breakdown/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/task-breakdown/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/task-breakdown/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/skills/ux-carbon-critique/prompt.md | Baseline snapshot of: Skill execution prompt. |
| origin/agents/skills/ux-carbon-critique/rubric.md | Baseline snapshot of: Skill quality rubric. |
| origin/agents/skills/ux-carbon-critique/skill.md | Baseline snapshot of: Skill contract and intent. |
| origin/agents/tools/.gitkeep | Baseline snapshot of: Placeholder to keep tools directory in git. |
| origin/apps/api/src/.gitkeep | Baseline snapshot of: Placeholder to keep API source directory in git. |
| origin/apps/android/README.md | Baseline snapshot of: Android app overview. |
| origin/apps/android/src/.gitkeep | Baseline snapshot of: Placeholder to keep Android source directory in git. |
| origin/apps/web/carbon/layout/.gitkeep | Baseline snapshot of: Placeholder to keep Carbon layout directory in git. |
| origin/apps/web/public/.gitkeep | Baseline snapshot of: Placeholder to keep web public directory in git. |
| origin/apps/web/src/.gitkeep | Baseline snapshot of: Placeholder to keep web source directory in git. |
| origin/apps/windows/README.md | Baseline snapshot of: Windows app overview. |
| origin/apps/windows/src/.gitkeep | Baseline snapshot of: Placeholder to keep Windows source directory in git. |
| origin/docs/adr/0000-template.md | Baseline snapshot of: ADR template. |
| origin/docs/adr/index.md | Baseline snapshot of: ADR index. |
| origin/docs/architecture/architecture.md | Baseline snapshot of: System architecture overview. |
| origin/docs/architecture/README.md | Baseline snapshot of: Architecture docs index. |
| origin/docs/architecture/risks.md | Baseline snapshot of: Architecture risks and mitigations. |
| origin/docs/onboarding.md | Baseline snapshot of: Project onboarding guide. |
| origin/docs/README.md | Baseline snapshot of: Docs entry point and guidance. |
| origin/docs/runbooks/ci-cd.md | Baseline snapshot of: Operational runbook. |
| origin/docs/runbooks/incident-basics.md | Baseline snapshot of: Operational runbook. |
| origin/docs/runbooks/local-dev.md | Baseline snapshot of: Operational runbook. |
| origin/docs/security/mitigations.md | Baseline snapshot of: Security mitigations. |
| origin/docs/security/README.md | Baseline snapshot of: Security docs index. |
| origin/docs/security/threat_model.md | Baseline snapshot of: Threat model. |
| origin/docs/standards/accessibility.md | Baseline snapshot of: Engineering standards document. |
| origin/docs/standards/engineering-standards.md | Baseline snapshot of: Engineering standards document. |
| origin/docs/standards/security-baseline.md | Baseline snapshot of: Engineering standards document. |
| origin/docs/standards/ui-platform-standards.md | Baseline snapshot of: Engineering standards document. |
| origin/docs/standards/ux-standards-carbon.md | Baseline snapshot of: Engineering standards document. |
| origin/origin-metadata.md | Baseline snapshot of: Metadata about the origin snapshot. |
| origin/packages/ui-carbon/src/.gitkeep | Baseline snapshot of: Placeholder to keep UI package source directory in git. |
| origin/provenance/deep-research-agent-catalogue.docx | Baseline snapshot of: Provenance or research document (binary). |
| origin/README.md | Baseline snapshot of: Repository overview and quick start. |
| origin-metadata.md | Metadata about the origin snapshot. |
| packages/ui-carbon/README.md | UI Carbon package overview. |
| packages/ui-carbon/src/.gitkeep | Placeholder to keep UI package source directory in git. |
| provenance/deep-research-agent-catalogue.docx | Provenance or research document (binary). |
| README.md | Repository overview and quick start. |
| repo | Empty marker file. |
| scripts/agent/validate_agent_governance.py | Validate agent governance rules. |
| scripts/install-agent-pack.ps1 | Install agent pack assets. |
| scripts/install-content-pack.ps1 | Install content pack assets. |
| scripts/install-speckit.ps1 | Install spec-kit assets. |
| scripts/README.md | Scaffold usage instructions. |
| scripts/README-speckit.md | Spec-kit install instructions. |
| scripts/scaffold.manifest.txt | Scaffold manifest for verification. |
| scripts/scaffold.ps1 | Scaffold repo structure. |
| scripts/verify-scaffold.ps1 | Verify scaffold integrity. |
| specs/000-product-name-here/checklists/requirements.md | Feature requirements checklist. |
| specs/000-product-name-here/contracts/openapi.yaml | Feature API contract. |
| specs/000-product-name-here/data-model.md | Feature data model notes. |
| specs/000-product-name-here/plan.md | Feature plan and routing. |
| specs/000-product-name-here/quickstart.md | Feature quickstart guidance. |
| specs/000-product-name-here/research.md | Feature research notes. |
| specs/000-product-name-here/spec.md | Feature specification. |
| specs/000-product-name-here/tasks.md | Feature task breakdown. |
| specs/001-feature-name-here/checklists/requirements.md | Feature requirements checklist. |
| specs/001-feature-name-here/contracts/openapi.yaml | Feature API contract. |
| specs/001-feature-name-here/data-model.md | Feature data model notes. |
| specs/001-feature-name-here/plan.md | Feature plan and routing. |
| specs/001-feature-name-here/quickstart.md | Feature quickstart guidance. |
| specs/001-feature-name-here/research.md | Feature research notes. |
| specs/001-feature-name-here/spec.md | Feature specification. |
| specs/001-feature-name-here/tasks.md | Feature task breakdown. |
| specs/README.md | Specs index and conventions. |
| stakeholder_notes.md | Stakeholder notes and context. |
| tsconfig.base.json | Base TypeScript configuration. |

---

## Guardrails

Read once:

```
agents/policies/guardrails.md
```

Core principles:

- no secrets in repo
- no destructive actions without approval
- decisions must be traceable
- specs drive implementation
- outputs include summary, assumptions, recommendations, validation, and risks

---

## Definition of done

A change is complete when:

- acceptance criteria exist in the spec
- validation steps are documented
- risks and rollback are clear
- significant decisions become ADRs

---

## Template maintenance (maintainers only)

This section is only relevant when evolving the template itself.

- Rebuild or repair structure:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\scaffold.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-scaffold.ps1
```

- Refresh baseline content from `origin/`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1 -Force
```

Keep edits in root docs. Use the refresh scripts only to update `origin/` snapshots.
