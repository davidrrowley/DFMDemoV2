# Task Block Contract

Tasks in `specs/**/tasks.md` should be written as **parseable blocks**.

This contract exists so that:
- humans can scan quickly
- agents can be routed deterministically
- CI can validate governance cheaply

## Required fields

Each task must include:

- `owner:` an agent id from `agents/registry/agents.v1.yml`
- `acceptance:` list of acceptance criteria
- `validate:` list of validation steps

## Recommended fields

- `depends_on:` list of task IDs or links; leave empty or omit to signal parallel-safe work (agents route to subagents for simultaneous execution)
- `risk:` low | medium | high
- `evidence:` links to PR, test run, screenshots, logs

## Parallelization

When a task has no `depends_on` (or an empty list), the Orchestrator may delegate it to a subagent in parallel with other independent tasks. Use this to model work streams that can execute concurrently:

- Frontend, backend, and infra work often have no coupling
- Tests can run in parallel once their respective components are ready
- Documentation and threat modeling can proceed alongside implementation

## Example

```md
### T-API-001: Create capture ingestion endpoint
owner: app-typescript
depends_on: [T-ARCH-002]
risk: medium
acceptance:
- Endpoint accepts metadata + blob reference
- Validates authN/authZ and size limits
validate:
- Unit tests pass
- OpenAPI updated
- Manual test recorded in docs/runbooks/api.md
```
