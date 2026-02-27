# Engineering standards

## Branching and PRs
- Work happens in feature branches.
- Every change is reviewed via PR.
- PR descriptions must link to the relevant spec artefacts and include validation notes.

## Definition of done
A PR is eligible to merge when:
- acceptance criteria are met
- automated checks pass
- docs updated (runbook/ADR/README as appropriate)
- rollback notes exist for risky changes

## Decisions
Material decisions become ADR candidates. Use `docs/adr/` and keep ADRs short and concrete.

## Logging and observability
New services must define:
- structured logs (correlation IDs where applicable)
- metrics for core behaviours
- health endpoints and readiness
- minimal tracing plan if there are cross-service calls

## Secrets
- Use `.env` locally, never commit.
- Use a secret store in real environments.
