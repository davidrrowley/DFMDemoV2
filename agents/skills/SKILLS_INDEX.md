# Skills Index (Baseline)

This document lists the baseline skills provided by this template.

A **skill** is a reusable capability with a defined contract:

- `skill.md` — intent, inputs/outputs, process
- `prompt.md` — execution prompt
- `rubric.md` — quality evaluation

Use this index to understand what capabilities already exist before creating new ones.

---

## Orchestration & Delivery

### orchestration-routing
**Purpose:** Route work to specialist agents, enforce phase gates, and maintain coordination.

**Typical inputs**
- spec artefacts
- constraints
- dependencies

**Outputs**
- delegated tasks
- execution plan
- escalations

---

### spec-normalisation
**Purpose:** Convert raw requirements into structured, testable specs.

**Typical outputs**
- clarified requirements
- acceptance criteria
- open questions

---

### task-breakdown
**Purpose:** Turn specs and plans into executable task lists.

**Typical outputs**
- implementation tasks
- sequencing and dependencies

---

## Architecture & Engineering

### architecture-review
**Purpose:** Produce target architecture views, trade-offs, and ADR candidates.

**Typical outputs**
- architecture summary
- risks and mitigations
- ADR candidates

---

### adr-writing
**Purpose:** Convert decisions into ADRs with context, options, and consequences.

**Typical outputs**
- ADR markdown content
- follow-up actions

---

### code-review
**Purpose:** Review implementation for quality, maintainability, and alignment to standards.

**Typical outputs**
- review findings
- recommendations
- validation steps

---

## UX & Design

### ux-carbon-critique
**Purpose:** Evaluate UX against IBM Carbon guidance and accessibility expectations.

**Typical outputs**
- prioritized findings
- improvement suggestions
- a11y notes

---

## Security & Quality

### security-review
**Purpose:** Identify security risks and suggest mitigations.

**Typical outputs**
- risk list
- mitigation actions
- validation checks

---

### doc-hygiene
**Purpose:** Improve documentation clarity, consistency, and traceability.

**Typical outputs**
- structure improvements
- missing sections
- clarity fixes

---

## Guidance: When to create a new skill

Create a new skill when:

- the task is repeatable across projects
- it has a clear input/output contract
- it benefits from a rubric or quality gate

Do **not** create a new skill for one-off tasks; use an existing skill instead.

---

## Naming convention

Use kebab-case and action-oriented names:

```
good: architecture-review
good: threat-model
avoid: architectureStuff
avoid: misc
```

---

## Evolution

As this template evolves:

- add new skills under `agents/skills/<skill-name>/`
- update this index
- keep the README summary high-level
