# Template Consumption Update Matrix

This table lists the files to update when consuming the template, in the most logical completion order.

## Priority 1 - Identity and Governance

| Priority | File | What to update |
| --- | --- | --- |
| P1 | [.specify/memory/constitution.md](.specify/memory/constitution.md) | Replace all placeholders (project name, principles, governance rules, version/date). |
| P1 | [AGENTS.md](AGENTS.md) | Confirm agent model fits your org; update any agent IDs or references if you change registry or routing. |
| P1 | [AGENT_PIPELINE.md](AGENT_PIPELINE.md) | Update the default entry path once product folder is renamed; confirm pipeline flow matches your process. |
| P1 | [agents/registry/agents.v1.yml](agents/registry/agents.v1.yml) | Add/remove agents, adjust streams/roles, tooling permissions, and outputs to match your org. |
| P1 | [agents/routing.yml](agents/routing.yml) | Update default owners and path-based routing; align with your actual app/infra structure. |
| P1 | [agents/contracts/task-block.md](agents/contracts/task-block.md) | Ensure task block fields match how you plan to track acceptance/validation. |

## Priority 2 - Product-Level Specs

| Priority | File | What to update |
| --- | --- | --- |
| P2 | [specs/README.md](specs/README.md) | Rename product folder reference to your real product folder; ensure structure matches your plan. |
| P2 | [specs/000-product-name-here](specs/000-product-name-here) | Rename folder to your product name (for example specs/00-product) and update all internal links. |
| P2 | [specs/000-product-name-here/product-vision.md](specs/000-product-name-here/product-vision.md) | Replace with your real product vision, target users, and success criteria. |
| P2 | [specs/000-product-name-here/high-level-requirements.md](specs/000-product-name-here/high-level-requirements.md) | Replace HR list with your actual functional and non-functional requirements. |
| P2 | [specs/000-product-name-here/feature-map.md](specs/000-product-name-here/feature-map.md) | Define real feature boundaries, owners, reviewers, and requirement mapping. |
| P2 | [specs/000-product-name-here/roadmap.md](specs/000-product-name-here/roadmap.md) | Replace waves/timeline with your delivery plan. |
| P2 | [specs/000-product-name-here/architecture.md](specs/000-product-name-here/architecture.md) | Update system diagram, components, and tech stack to match your architecture. |
| P2 | [specs/000-product-name-here/security-baseline.md](specs/000-product-name-here/security-baseline.md) | Update threat model, security requirements, owners, and review cadence. |
| P2 | [specs/000-product-name-here/nfr.md](specs/000-product-name-here/nfr.md) | Replace NFR targets with your real performance, reliability, and scale goals. |
| P2 | [specs/000-product-name-here/data-model.md](specs/000-product-name-here/data-model.md) | Define canonical entities, relationships, and validation rules. |
| P2 | [specs/000-product-name-here/agent-execution-model.md](specs/000-product-name-here/agent-execution-model.md) | Update agent IDs and quality gates; move into product folder per guidance. |
| P2 | [specs/000-product-name-here/autonomous-delivery-patterns.md](specs/000-product-name-here/autonomous-delivery-patterns.md) | Tailor patterns to your delivery practices and compliance needs. |
| P2 | [specs/000-product-name-here/problem-statement.md](specs/000-product-name-here/problem-statement.md) | Optional: delete or leave as deprecated; update only if you still use this format. |
| P2 | [specs/000-product-name-here/checklists/requirements.md](specs/000-product-name-here/checklists/requirements.md) | Replace checklist with your real spec quality gate criteria. |
| P2 | [specs/000-product-name-here/contracts/openapi.yaml](specs/000-product-name-here/contracts/openapi.yaml) | Replace with your product-level API contracts (if applicable). |

## Priority 3 - First Real Feature Bundle

| Priority | File | What to update |
| --- | --- | --- |
| P3 | [specs/001-feature-name-here](specs/001-feature-name-here) | Rename to real feature folder (for example specs/001-auth) and update all links. |
| P3 | [specs/001-feature-name-here/spec.md](specs/001-feature-name-here/spec.md) | Replace placeholder sections: user stories, requirements, success criteria. |
| P3 | [specs/001-feature-name-here/plan.md](specs/001-feature-name-here/plan.md) | Replace tech context, project structure, and dependencies. |
| P3 | [specs/001-feature-name-here/tasks.md](specs/001-feature-name-here/tasks.md) | Replace with real task blocks including owner, acceptance, and validate. |
| P3 | [specs/001-feature-name-here/research.md](specs/001-feature-name-here/research.md) | Replace decisions and rationale with real findings. |
| P3 | [specs/001-feature-name-here/data-model.md](specs/001-feature-name-here/data-model.md) | Add feature-specific data model extensions or references. |
| P3 | [specs/001-feature-name-here/quickstart.md](specs/001-feature-name-here/quickstart.md) | Replace setup, config, and run steps for this feature. |
| P3 | [specs/001-feature-name-here/checklists/requirements.md](specs/001-feature-name-here/checklists/requirements.md) | Replace with feature-specific spec quality checklist. |
| P3 | [specs/001-feature-name-here/contracts/openapi.yaml](specs/001-feature-name-here/contracts/openapi.yaml) | Replace with the feature's actual API contract. |

## Priority 4 - Repo Ops, CI, and Inputs

| Priority | File | What to update |
| --- | --- | --- |
| P4 | [README.md](README.md) | Update template text, repo description, and file index to match your structure. |
| P4 | [constraints.md](constraints.md) | Fill business, technical, and compliance constraints. |
| P4 | [data_flows.md](data_flows.md) | Document real data flows and trust boundaries. |
| P4 | [decision_candidate.md](decision_candidate.md) | Replace with your first real decision or keep as a template. |
| P4 | [stakeholder_notes.md](stakeholder_notes.md) | Capture stakeholder priorities, risks, and success criteria. |
| P4 | [.env.example](.env.example) | Update to match your runtime configuration needs. |
| P4 | [.github/workflows/ci.yml](.github/workflows/ci.yml) | Replace placeholder lint/test steps with actual commands. |
| P4 | [docs/onboarding.md](docs/onboarding.md) | Update onboarding steps to match your workflow and stack. |
| P4 | [docs/README.md](docs/README.md) | Add real doc structure expectations and pointers. |

## Priority 5 - Reusable spec-kit templates

| Priority | File | What to update |
| --- | --- | --- |
| P5 | [.specify/README.md](.specify/README.md) | Update placeholder guidance if you customize spec-kit usage. |
| P5 | [.specify/templates/constitution-template.md](.specify/templates/constitution-template.md) | Align template placeholders with your constitution format. |
| P5 | [.specify/templates/spec-template.md](.specify/templates/spec-template.md) | Update required sections and example content. |
| P5 | [.specify/templates/plan-template.md](.specify/templates/plan-template.md) | Update technical context and structure guidance. |
| P5 | [.specify/templates/tasks-template.md](.specify/templates/tasks-template.md) | Update task block guidance, examples, and required fields. |
| P5 | [.specify/templates/checklist-template.md](.specify/templates/checklist-template.md) | Update checklist criteria to your standards. |
| P5 | [.specify/templates/feature-template/spec.md](.specify/templates/feature-template/spec.md) | Make your default feature spec template match your process. |
| P5 | [.specify/templates/feature-template/plan.md](.specify/templates/feature-template/plan.md) | Update feature plan template for your tech stack. |
| P5 | [.specify/templates/feature-template/tasks.md](.specify/templates/feature-template/tasks.md) | Update feature task template to your routing and validation rules. |
| P5 | [.specify/templates/task-block.md](.specify/templates/task-block.md) | Ensure it mirrors [agents/contracts/task-block.md](agents/contracts/task-block.md). |
