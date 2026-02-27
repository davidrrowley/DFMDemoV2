<!--
  SYNC IMPACT REPORT
  ==================
  Version change:   (none) → 1.0.0  (initial ratification — all placeholders replaced)
  Modified principles: n/a (first fill; no prior principle titles existed)
  Added sections:
    - Core Principles (I–VII)
    - Platform & Technology Standards
    - Operating Model & Quality Gates
    - Governance
  Removed sections: n/a
  Templates checked:
    - .specify/templates/plan-template.md          ✅ Constitution Check gate aligns
    - .specify/templates/spec-template.md          ✅ Agent routing section aligns
    - .specify/templates/tasks-template.md         ✅ Task block owner/acceptance/validate aligns
    - .specify/templates/feature-template/spec.md  ✅ No conflicting guidance
    - .specify/templates/feature-template/plan.md  ✅ No conflicting guidance
    - .specify/templates/feature-template/tasks.md ✅ No conflicting guidance
  Deferred TODOs: none — all placeholders resolved.
-->

# DFMDemoV2 Constitution

## Core Principles

### I. Spec-First Delivery (NON-NEGOTIABLE)

All work MUST originate from a written spec in `specs/`. No code, infrastructure change,
or agent task may be initiated without a corresponding `spec.md` that includes testable
acceptance criteria. Specs are the single source of truth for intent; implementation
evidence (tests, ADRs, validation steps) MUST be traceable back to a spec artefact.

- Every feature folder under `specs/` MUST contain `spec.md`, `plan.md`, and `tasks.md`
  before implementation begins.
- Acceptance criteria MUST be written in observable, falsifiable terms
  (Given / When / Then or equivalent).
- Work not captured in `specs/` is not recognised work.

**Rationale**: Specs prevent scope drift, enable async agent handoff, and provide the
evidentiary chain required for autonomous delivery. Without them the operating loop
(Spec → Orchestrate → Execute → Verify → Document) cannot function.

### II. Agent-Native Ownership

Every task in `specs/**/tasks.md` MUST declare an `owner` that resolves to a known
agent-id in `agents/registry/agents.v1.yml`. Ownerless tasks MUST NOT be executed;
the Orchestrator applies `agents/routing.yml` defaults only when a task explicitly
omits an owner and routing rules cover that path.

- Agent = WHO + HOW it thinks (persona defined in the agent registry).
- Skill = WHAT it does (reusable, rubric-evaluated capability in `agents/skills/`).
- The `orchestrator` agent coordinates and delegates; it MUST NOT implement unless
  `break_glass=true` is recorded in the feature `tasks.md` with a time-box and rationale.
- CI MUST reject tasks missing `owner`, `acceptance`, or `validate` fields.

**Rationale**: Explicit ownership makes routing deterministic, enables parallelism,
and ensures accountability at every task boundary without requiring human triage.

### III. Test-First, Evidence-Driven Quality (NON-NEGOTIABLE)

Acceptance criteria MUST be defined — and, where automated tests are required, the
test skeletons MUST exist and FAIL — before implementation begins. Every PR MUST
include validation evidence demonstrating criteria are met.

- Contract tests MUST cover any new or changed API surface.
- Integration tests MUST cover inter-service communication and shared schemas.
- Unit tests MUST cover non-trivial logic in isolation.
- The Red-Green-Refactor cycle is the required development rhythm for all
  test-first work: write failing test → implement to pass → refactor.
- PRs without passing automated checks MUST NOT merge.

**Rationale**: Evidence-driven quality prevents "works on my machine" delivery and
gives the agent fleet a verifiable definition of done that does not depend on human
interpretation.

### IV. Observability as a First-Class Concern

All new services and significant feature additions MUST include an observability plan
before the first PR is raised. The plan is not optional post-hoc documentation.

- Structured logs with correlation IDs MUST be emitted for all significant operations.
- Metrics MUST be defined for core behaviours (request rate, error rate, latency
  where applicable).
- Health and readiness endpoints MUST be provided for any long-running service.
- Cross-service calls MUST include a minimal tracing plan (trace propagation headers
  at minimum).
- Secrets MUST NOT appear in log output at any verbosity level.

**Rationale**: The multi-agent, multi-platform architecture of this template creates
distributed failure modes that are invisible without structured observability.
Logging and metrics are a delivery requirement, not an operational nice-to-have.

### V. Security by Default

Security guardrails are non-negotiable constraints applied uniformly across all
agents, skills, and tools in this repository.

- Secrets (API keys, tokens, connection strings, credentials) MUST NEVER be committed
  to the repository. Use `.env` locally; use a secret store in deployed environments.
- Destructive commands (deletes, drops, force-pushes, hard resets) MUST NOT be
  executed without explicit human approval and a documented rollback plan.
- Changes to protected branches MUST go through a PR; no direct pushes are permitted.
- Security-sensitive changes (new data flows, auth changes, secret handling, IaC
  affecting network or IAM) MUST receive human review and include a rollback plan
  before merging.
- The threat model in `specs/000-product-name-here/security-baseline.md` MUST be
  updated when new data flows are introduced.

**Rationale**: Autonomous agents executing at speed amplify the blast radius of
security mistakes. Guardrails remove ambiguity about what is and is not acceptable,
making safe behaviour the path of least resistance.

### VI. Simplicity and Justified Complexity

The simplest solution that satisfies the acceptance criteria is the correct solution.
Complexity MUST be justified, not assumed.

- YAGNI (You Aren't Gonna Need It): do not add abstractions, layers, or dependencies
  that are not required by current acceptance criteria.
- Every new dependency MUST be security-checked before introduction (advisory DB scan).
- Additional projects, services, or architectural layers beyond what the plan specifies
  MUST be documented in the Complexity Tracking table in `plan.md`, stating why the
  simpler alternative was rejected.
- Material architectural decisions MUST be captured as ADRs under `docs/adr/` and kept
  short and concrete.
- Prefer the cheapest adequate agent model for each task; escalate only when complexity
  or risk justifies the cost.

**Rationale**: Complexity is the primary driver of defects, maintenance burden, and
agent confusion. Keeping things simple by default — and making complexity explicit —
preserves the long-term health of the template and any project derived from it.

### VII. PR-Driven, Traceable Delivery

All changes to the codebase MUST travel through a pull request. PRs are the audit
trail linking implementation back to spec intent.

- Work MUST happen in feature branches; no changes are made directly to `main` or
  other protected branches.
- PR descriptions MUST link to the relevant spec artefacts (`spec.md`, `plan.md`,
  `tasks.md`) and include validation notes.
- A PR is eligible to merge only when: acceptance criteria are met, automated checks
  pass, documentation is updated (runbook / ADR / README as appropriate), and rollback
  notes exist for risky changes.
- Implementer agents create PRs only; merge authority rests with human reviewers or
  explicitly delegated merge agents.
- CI governance MUST validate: tasks are owned, owners exist in the registry, routing
  rules remain valid, and non-placeholder feature folders contain the full artefact set.

**Rationale**: PR-driven delivery gives the operating loop its Verify step and
produces an auditable record of what changed, why, and who (or what agent) authorised it.

## Platform & Technology Standards

This template supports delivery across three UI platforms and a polyglot back-end.
Agent routing and technology choices MUST align with the following standards.

### UI Platforms

| Platform | Design System | Routing Default | Reviewer |
|----------|--------------|-----------------|----------|
| Web (`apps/web/`) | IBM Carbon Design System | `frontend-carbon` | `ux-critic` |
| Windows | Microsoft Fluent UI | `windows-fluent` | `ux-critic` |
| Android | Material Design 3 | `android-material` | `ux-critic` |

UI work MUST target the design system for its platform. Cross-platform deviations
require an ADR justifying the divergence.

### Back-End & Infrastructure Languages

Approved languages and their primary use contexts:

| Language / Runtime | Primary Use |
|--------------------|-------------|
| TypeScript / Node.js | API services (`apps/api/`), tooling scripts |
| .NET (C#) | Windows platform services, enterprise integrations |
| Go | High-throughput services, CLI tooling |
| Java | JVM-ecosystem integrations, batch processing |
| Python | Data pipelines, ML/AI agent skills, scripting |
| Terraform (HCL) | Infrastructure-as-code (`infra/`) |

Language choices outside this list require an ADR and Architect sign-off.

### Path-Based Routing

The canonical routing rules are authoritative in `agents/routing.yml`. Key defaults:

- `apps/web/**` → `frontend-carbon` (reviewer: `ux-critic`)
- `apps/api/**` → `app-typescript` (reviewer: `api-design`)
- `infra/**` → `terraform-iac` (reviewer: `cloud-scrum-master`)
- `docs/security/**` → `appsec-tooling` (reviewer: `threat-model`)
- `docs/adr/**` → `adr-logger` (reviewer: `architect`)

Any change to routing defaults MUST be reflected in both `agents/routing.yml` and
this constitution via a PATCH or MINOR version bump.

### Dependency Management

- All new external dependencies MUST be scanned against the GitHub Advisory Database
  before being introduced.
- Dependencies with known critical or high-severity vulnerabilities MUST NOT be added
  without an explicit, time-boxed remediation plan documented in the relevant ADR.
- Lock files (`package-lock.json`, `go.sum`, `requirements.txt` pins, etc.) MUST be
  committed and kept current.

## Operating Model & Quality Gates

### The Delivery Loop

Every feature follows this loop without exception:

```
Spec → Orchestrate → Execute → Verify → Document
```

1. **Spec** — Define outcomes and acceptance criteria in `specs/<feature>/spec.md`.
2. **Orchestrate** — Route to the right agents via `agents/registry/agents.v1.yml`
   and `agents/routing.yml`. The `orchestrator` agent owns this step.
3. **Execute** — Agents run reusable skills from `agents/skills/`. Implementer agents
   produce PRs; they do not merge.
4. **Verify** — Automated checks pass; acceptance criteria are evidenced; human review
   approves the PR.
5. **Document** — ADRs, runbooks, and README updates are part of the PR, not follow-up.

### Quality Gates (CI-Enforced)

The following gates are enforced by CI and MUST pass before any PR merges:

- All tasks in `specs/**/tasks.md` include `owner`, `acceptance`, and `validate`.
- Every `owner` value resolves to a known agent-id in `agents/registry/agents.v1.yml`.
- Non-placeholder feature folders contain `spec.md`, `plan.md`, and `tasks.md`.
- Routing rules in `agents/routing.yml` reference only valid agent-ids.
- No secrets detected in committed content (secret-scanning gate).

### Constitution Check (Plan Gate)

Every feature plan (`plan.md`) MUST include a Constitution Check section that
explicitly verifies compliance with Principles I–VII before Phase 0 research begins
and re-checks after Phase 1 design. A plan that cannot clear the Constitution Check
MUST NOT proceed to task generation.

### Evidence Requirements

Every agent output MUST include:

- **Summary** — what was done and why.
- **Assumptions / open questions** — explicit, not implicit.
- **Validation steps** — how to prove it works.
- **Risks and rollback notes** — required for any risky change.

Factual claims MUST cite evidence (primary sources or repo artefacts). If evidence is
missing, the agent MUST say so and MUST NOT invent it.

### Decision Traceability

- Material decisions (technology choices, architecture changes, security trade-offs,
  breaking changes) MUST become ADR candidates.
- ADRs live in `docs/adr/` and follow the repo's ADR format.
- Architecture changes MUST update `docs/architecture/architecture.md`.
- The `adr-logger` agent owns ADR creation; the `architect` agent reviews.

## Governance

This constitution supersedes all other guidance for this repository. Where a specific
doc (README, AGENTS.md, guardrails, engineering standards) conflicts with this
constitution, the constitution takes precedence and the conflicting doc MUST be
updated via an amendment PR.

### Amendment Procedure

1. Open a PR with the proposed change to `.specify/memory/constitution.md`.
2. PR description MUST state: the principle(s) affected, the reason for the change,
   and the version bump type (MAJOR / MINOR / PATCH) with justification.
3. If the amendment changes agent routing, platform standards, or security guardrails,
   an ADR MUST be included in the same PR.
4. The PR requires approval from a human maintainer before merging.
5. On merge, `LAST_AMENDED_DATE` MUST be updated to the merge date.

### Versioning Policy

Constitution versions follow semantic versioning:

- **MAJOR** — Backward-incompatible governance changes: removal or redefinition of a
  principle, removal of a required quality gate, or change to the amendment procedure.
- **MINOR** — Additive changes: new principle, new section, materially expanded
  guidance, new platform standard, new required CI gate.
- **PATCH** — Non-semantic refinements: clarifications, wording improvements, typo
  fixes, example updates, date updates.

### Compliance Review

- All PRs MUST verify that changes comply with the constitution's principles,
  particularly Principles I (spec-first), V (security), and VII (PR-driven).
- The `orchestrator` agent MUST check constitution compliance as part of its triage
  step before delegating any work package.
- A compliance review of the full constitution SHOULD be conducted at the start of
  each major delivery wave; findings MUST be addressed before new feature work begins.

### Runtime Guidance

For day-to-day agent operating guidance, refer to:

- `AGENTS.md` — agent catalogue and quick rules
- `AGENT_PIPELINE.md` — core flow and artefact index
- `agents/policies/guardrails.md` — non-negotiable runtime guardrails
- `agents/policies/citations-and-evidence.md` — evidence and citation standards
- `docs/standards/engineering-standards.md` — branching, PR, and observability standards

---

**Version**: 1.0.0 | **Ratified**: 2026-02-27 | **Last Amended**: 2026-02-27
