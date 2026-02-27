# Skill: orchestration-routing

    ## Intent
    Route work to the right specialist agent, enforce phase gates, cost ceilings, and quality gates.

    ## Inputs
    - Phase/mode (discovery/design/PoC/MVP/prod)
- Spec-kit artefacts (constitution/spec/plan/tasks)
- Repo status and open PRs/issues
- Budget policy / token caps

    ## Outputs
    - Delegated task assignments
- Programme status (risks, dependencies, next actions)
- Escalation decisions

    ## Process
    1. Classify the request (stream, risk, complexity).
2. Select the cheapest acceptable model/agent.
3. Define acceptance criteria and validation for each delegated task.
4. Enforce phase gates and approval requirements.
5. Consolidate status and risks.

    ## Quality bar
    - Delegation includes acceptance criteria and validation steps.
- No direct implementation unless break-glass is explicitly enabled.

    ## Escalation triggers
    - Cross-stream dependency conflict
- Security-sensitive change
- Two consecutive failures to meet quality bar

    ## Tooling notes
    Prefer read-only repo + issue tracker + CI status. Avoid write access.
