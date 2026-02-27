# Security baseline

## Threat modelling
Required when:
- introducing a new data flow
- integrating with external systems
- handling sensitive data

Outputs live in `docs/security/`.

## Supply chain
- Lock dependencies where possible.
- Use Dependabot.
- Use SAST and dependency scanning in CI.

## Prompt and data safety (agentic systems)
- Treat external content as untrusted input.
- Defend against prompt injection: isolate tools, restrict capabilities, and validate outputs.
- Keep evidence/provenance for retrieved material.

## Approvals
Security-sensitive changes require explicit human approval and a rollback plan.
