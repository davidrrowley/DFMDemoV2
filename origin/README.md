# Baseline: Spec-Driven Multi-Agent Engineering Template

This repository is a baseline engineering template designed for:

- Spec-first delivery powered by spec-kit assets in `.specify/`
- A multi-agent catalogue (contracts, personas, skills, evals in `agents/`)
- IBM Carbon aligned UX structure (`apps/web/`)

The goal is repeatability: every new project starts with the same structure, guardrails, and working loop.

Note: this `origin/` content is a baseline snapshot for scaffold/refresh scripts. Edit root docs for live guidance.

---

## Start here

Specs drive delivery.

- Spec-kit engine and templates: `.specify/`
- Product and feature specs: `specs/`
- Agent operating model: `AGENTS.md`
- Agent contracts and routing: `agents/registry/agents.v1.yml`, `agents/routing.yml`

Platform UI agents: `frontend-carbon` (web), `windows-fluent` (Windows), `android-material` (Android).

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
