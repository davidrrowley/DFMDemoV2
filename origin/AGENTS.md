# AGENTS

This repository uses a spec-driven, multi-agent workflow.

The purpose of the agent catalogue is repeatability: new projects start with the same structure, routing rules, and quality bars.

Note: this `origin/` file is a baseline snapshot for scaffold/refresh scripts. Edit root docs for live guidance.

## Where things live

- Spec-kit engine and templates: `.specify/`
- Constitution (shared principles and constraints): `.specify/memory/constitution.md`
- Feature specs (product + features): `specs/`
- Decisions (ADRs): `docs/adr/`
- Agent registry (contracts): `agents/registry/agents.v1.yml`
- Agent routing rules (delegation defaults): `agents/routing.yml`
- Agent personas (system prompts): `agents/prompts/*/system.md`
- Skills (reusable playbooks): `agents/skills/*`
- Policies: `agents/policies/*`
- Provider configs (optional): `agents/providers/*`
- Outputs written by agents (status, delegated tasks, notes): `agents/outputs/`

## Platform UI agents

- Web (Carbon): `frontend-carbon`
- Windows (Fluent UI): `windows-fluent`
- Android (Material 3): `android-material`

## How spec-kit should use agents

Spec-kit does not automatically discover or orchestrate agents. The way we "wire in" agent usage is by making routing explicit in the spec artefacts that spec-kit operates on.

### The minimum pattern

1) Write or update the feature spec in `specs/<feature>/spec.md`.
2) Plan the work in `specs/<feature>/plan.md` and include an **Agent routing** section referencing:
   - `AGENTS.md`
   - `agents/registry/agents.v1.yml`
   - `agents/routing.yml`
3) Break down the work in `specs/<feature>/tasks.md` using machine-readable task blocks with an explicit owner.

### Task block format (required)

Every task in `tasks.md` should include these fields:

- `owner:` an agent id from the registry (for example `frontend-carbon`, `app-typescript`, `terraform-iac`)
- `acceptance:` measurable acceptance criteria
- `validate:` concrete validation steps (tests, commands, evidence artefacts)

Example:

```md
### T-WEB-001: Add capture list page
owner: frontend-carbon
depends_on: []
acceptance:
- User can view recent captures
- List supports basic filtering (type, tag)
validate:
- Unit tests pass
- Storybook/Playwright screenshot added to docs
```

If a task has no `owner`, the Orchestrator applies `agents/routing.yml` rules.

## Working agreement

- Specs are the source of truth.
- Reuse skills rather than duplicating logic in prompts.
- Capture decisions as ADRs for traceability.
- Apply guardrails in `agents/policies/guardrails.md` for security and safety.
- Follow guardrail output structure and evidence expectations.
- **Parallelize where possible:** Mark independent tasks with empty `depends_on` lists. Route these to subagents simultaneously to reduce delivery latency.

## Governance entry points

- Guardrails and required output structure: `agents/policies/guardrails.md`
- Evidence and citation rules: `agents/policies/citations-and-evidence.md`
