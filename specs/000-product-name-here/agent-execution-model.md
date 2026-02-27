# agent-execution-model.md

> **Template guidance:** Copy this file into `specs/00-product/agent-execution-model.md`.
>
> This defines how agents collaborate, how work is routed, and what quality gates are enforced.
> Update agent ids and links to match your `agents/registry.yml` and `agents/routing.yml`.

## Core Rules

- All work originates from `specs/` artefacts.
- Every task in `specs/**/tasks.md` must include:
  - `owner: <agent-id>`
  - `acceptance:`
  - `validate:`
- If a task has no owner, routing defaults apply (see `agents/routing.yml`).

## Agent Categories

### Orchestration
Responsible for routing, sequencing, dependencies, and risk.
- orchestrator
- stream scrum masters

### Implementation
Responsible for making changes and opening PRs.
- app-* agents
- infra/IaC agents
- UI agents
- API contract agents

### Quality & Review
Responsible for validation and governance.
- UX review
- security review
- QA/testing
- ADR logging

## Execution Lifecycle (Template)

1. **Intake:** Orchestrator validates spec completeness and routes to a stream owner.
2. **Planning:** Stream scrum master sequences tasks and confirms ownership.
3. **Architecture alignment:** Architect reviews boundaries and cross-cutting constraints.
4. **Implementation:** Implementation agents deliver PRs with evidence.
5. **Quality review:** Required reviewers validate (UX/security/QA/architecture).
6. **Quality gates:** CI enforces baseline checks (tests, lint, scans, ownership).
7. **Merge:** Only after gates pass and reviewers approve.

## Delegation Logic

Priority order:
1. Explicit task `owner:`
2. Feature default owner in `feature-map.md`
3. Path-based routing rules in `agents/routing.yml`
4. Orchestrator decision (documented)

## Global Quality Gates (Template)

- Spec alignment: task maps to feature scope and has acceptance/validation.
- Architecture consistency: boundaries respected; ADR required for breaking decisions.
- Security: required scans pass; threat model updated if new data flows introduced.
- UX: accessibility basics and design-system compliance for UI changes.
- Operational readiness: deterministic CI, observability considerations, rollback notes for infra.

## Escalation

Escalate to architecture/security when:
- security-sensitive change
- repeated gate failures
- cross-stream conflict
- breaking changes without ADR

