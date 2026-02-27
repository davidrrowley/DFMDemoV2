# Skill: architecture-review

    ## Intent
    Produce a target architecture view with trade-offs and ADR candidates aligned to the spec.

    ## Inputs
    - `specs/**/spec.md`
- Constraints/non-functionals
- Existing architecture context (if any)

    ## Outputs
    - Architecture outline
- Trade-offs & decisions
- ADR candidates
- Risks and mitigations

    ## Process
    1. Restate the system goal and constraints.
2. Identify architecture style and key components.
3. Produce C4 views (context/container) as text descriptions.
4. Enumerate options and trade-offs.
5. Identify ADR candidates and risks.

    ## Quality bar
    - Covers runtime, data, security, operability.
- Decisions are explicit and traceable to requirements.

    ## Escalation triggers
    - Conflicting constraints
- Unclear ownership / shared services
- Requires new platform primitives

    ## Tooling notes
    Follow the calling agent's tool allow/deny list.
