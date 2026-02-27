# AGENTS.md

This repository is designed to be **agent-native**: work is defined in `specs/` and executed by specialised agents declared in `agents/`.

If you follow the conventions here, spec-kit and your agent fleet can route work predictably and enforce quality gates automatically.

## Where things live

### Agent registry

- `agents/registry/registry.yml` (preferred)
- Some repos use `agents/registry.yml`

This file defines the available agent IDs (for example `app-python`, `frontend-carbon`, `terraform-iac`).

### Routing rules

- `agents/routing.yml`

This defines **default ownership** when a task does not specify an owner, and optional path-based routing rules.

### Task contract

- `.specify/templates/task-block.md`

Every task in `specs/**/tasks.md` must include:

- `owner: <agent-id>`
- `acceptance:` (bullet list of observable outcomes)
- `validate:` (how to prove it works)

### Governance gates (CI)

- `.github/workflows/spec-governance.yml`
- `scripts/spec_governance/check_specs.py`

Pull requests will fail if:
- tasks are missing `owner/acceptance/validate`
- `owner:` is not a known agent id
- feature folders (non-placeholder) do not contain `spec.md`, `plan.md`, and `tasks.md`

## How to add a new feature

1. Create a folder under `specs/` (avoid placeholder names like `name-here`).
   Example:

```
specs/010-capture-client/
```

2. Copy the feature template from `.specify/templates/feature-template/` into the new folder:
- `spec.md`
- `plan.md`
- `tasks.md`

3. Populate tasks using the task block format.

## Quick rules

- If it is not in `specs/`, it is not work.
- If a task has no acceptance + validate, it is not done.
- If an owner is not a valid agent id, it will not pass CI.
