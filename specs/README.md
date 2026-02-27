# Specs Index

This folder contains the **product spec** and all **feature specs**.

## How to add a new feature

1. Create a new folder under `specs/` using a numeric prefix (e.g. `01-offline-capture/`, `02-search-nl/`).
2. Add `spec.md`, `plan.md`, and `tasks.md` using the templates in `.specify/templates/`.
3. In `tasks.md`, write parseable task blocks and set `owner:` for every task (see `agents/contracts/task-block.md`).
4. Keep shared decisions and system-wide rules in `specs/000-product-name-here/` (rename to `00-product/` when the product name is set).

## Structure: Product vs. Features

### Product Folder (`000-product-name-here/`)

**Purpose:** Cross-cutting concerns shared by all features.

**Contents:**
- `product-vision.md` — Problem space, target users, desired outcome
- `high-level-requirements.md` — Functional and non-functional requirements (HR-01 through HR-09)
- `data-model.md` — Canonical entity definitions, validation rules, relationships
- `feature-map.md` — All features in the product, ownership, and feature-to-requirement mapping
- `roadmap.md` — Sequencing of features into waves, delivery timeline
- `architecture.md` — System boundaries, key components, technology decisions
- `security-baseline.md` — Threat model, security requirements, compliance controls
- `nfr.md` — Non-functional requirements (performance, scalability, reliability, usability)

**Key rule:** Product-level files define constraints and patterns that *all features must follow*. Features should reference, not duplicate, this content.

### Feature Folders (`001-feature-name/`, `002-feature-name/`, etc.)

**Purpose:** Specification and delivery plan for one capability.

**Contents:**
- `spec.md` — User stories, acceptance criteria, edge cases, requirements specific to this feature
- `plan.md` — Agent routing, work breakdown, sequencing, risk mitigation
- `tasks.md` — Machine-readable task blocks with `owner`, `acceptance`, `validate` fields (see `agents/contracts/task-block.md`)
- `research.md` — Findings, options analysis, decisions (alternative: ADRs in `docs/adr/`)
- `quickstart.md` — Setup guide for developers working on this feature
- `checklists/` — Definition of Done, testing, deployment checklists (per feature type)
- `data-model.md` (optional) — Features extending product data model with feature-specific entities or notes

**Key rule:** Feature specs should be *self-contained* for their scope. Cross-cutting decisions and shared patterns belong in the product folder.

## Conventions

- `000-product-name-here/` is the **single source of truth** for data model, NFRs, security, and architecture.
- Feature folders reference product-level content; they do not duplicate it.
- Feature data models (if needed) reference the product data model as a baseline and document extensions only.

## Continuity

Use `specs/<feature>/tasks.md` as the **running to-do list** for the feature. Update status and `depends_on` as work progresses, and keep a short "Last known state" note at the top (date, last completed task, next task) so work can resume without re-running `/specify`.

### Example: Last Known State

```
## Last Known State

**Date:** 2026-02-14  
**Status:** Implementing F01 (Offline Capture)  
**Last completed:** T-007: API design for POST /captures  
**In progress:** T-008: Android capture UI implementation  
**Blocked:** T-009: Awaiting credential manager design (assigned to security-scrum-master)  
**Next:** T-010: iOS capture UI implementation (depends on T-008)
```

## File Navigation

| File | Purpose | Owner |
|------|---------|-------|
| **Product Level** | | |
| [product-vision.md](000-product-name-here/product-vision.md) | Why this product exists, problem space, target users | Architect, Product Owner |
| [high-level-requirements.md](000-product-name-here/high-level-requirements.md) | What the system must achieve (functional + NFR) | Architect, Orchestrator |
| [data-model.md](000-product-name-here/data-model.md) | Core entities, validation, relationships | Architect, Data team |
| [feature-map.md](000-product-name-here/feature-map.md) | All features, boundaries, ownership, requirement mapping | Orchestrator, Scrum Masters |
| [roadmap.md](000-product-name-here/roadmap.md) | Sequencing into waves, delivery timeline | Orchestrator, Product Owner |
| [architecture.md](000-product-name-here/architecture.md) | System components, boundaries, technology stack | Architect |
| [security-baseline.md](000-product-name-here/security-baseline.md) | Threat model, security requirements, compliance | Security Lead, Architect |
| [nfr.md](000-product-name-here/nfr.md) | Performance, scalability, reliability, usability targets | Architect, QA Lead |
| **Feature Level** | | |
| `[NN]-feature-name/spec.md` | User stories, acceptance, edge cases for this feature | Feature Lead |
| `[NN]-feature-name/plan.md` | Agent routing, sequencing, risk for this feature | Scrum Master, Orchestrator |
| `[NN]-feature-name/tasks.md` | Machine-readable task blocks (running to-do) | Implementation Team |
| `[NN]-feature-name/data-model.md` | *Optional*: Feature-specific entities or extensions | Data team, Feature Lead |
| `[NN]-feature-name/research.md` | Options analysis, findings, decisions | Feature Lead, Architect |

## Workflow

1. **Intake (Orchestrator):** Ensure `high-level-requirements.md` and `feature-map.md` are complete; triage and route to stream owner.
2. **Planning (Scrum Master):** Sequence tasks in feature `plan.md`; confirm ownership in `tasks.md`.
3. **Design (Architect):** Review feature against `architecture.md` and `security-baseline.md`; request ADRs if needed.
4. **Implementation (Teams):** Deliver tasks per `tasks.md`; update status and "Last known state" regularly.
5. **Review (QA + Security + UX):** Verify against `spec.md`, `nfr.md`, and `security-baseline.md`.
6. **Merge:** Merge PRs only after all reviews pass and quality gates are met.

---

**Quick Links:**
- Production issue? Check the relevant feature folder (`001-*`, `002-*`, etc.).
- Building a new feature? Start with [feature-map.md](000-product-name-here/feature-map.md) and copy the feature scaffold.
- Need to understand system design? Start with [architecture.md](000-product-name-here/architecture.md) and [data-model.md](000-product-name-here/data-model.md).
- Confused about requirements? Check [product-vision.md](000-product-name-here/product-vision.md) and [high-level-requirements.md](000-product-name-here/high-level-requirements.md).

