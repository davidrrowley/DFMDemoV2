# Guardrails (repo-local)

These guardrails apply to every agent, skill, and tool in this repository.

## Non-negotiables
- No secrets in the repo. Never paste API keys, tokens, connection strings, or credentials.
- No destructive commands unless explicitly approved in the plan.
- No direct changes to protected branches. Use PRs.
- If a change is security-sensitive, require human approval and a rollback plan.

## Evidence expectations
- If you make factual claims, cite evidence (primary sources or repo artefacts).
- If evidence is missing, say so. Do not invent it.

## Quality expectations
Every output includes:
- Summary (what and why)
- Assumptions / open questions
- Recommendations / changes
- Validation steps
- Risks and rollback notes
