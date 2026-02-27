# Skill: task-breakdown

    ## Intent
    Convert a spec and plan into actionable tasks with acceptance criteria and validation steps.

    ## Inputs
    - `specs/**/spec.md`
- `specs/**/plan.md`

    ## Outputs
    - updated `specs/**/tasks.md`
- dependencies and sequencing notes

    ## Process
    1. Identify workstreams (cloud/app/security/quality).
2. Decompose into tasks.
3. Add owner, acceptance criteria, validation, rollback.
4. Identify dependencies.
5. Flag risky tasks for approval.

    ## Quality bar
    Tasks are executable, scoped, and testable.

    ## Escalation triggers
    Unclear requirements; missing ownership; risky change without rollback.
