# Skill: security-review

    ## Intent
    Perform a lightweight security review on a change, focusing on threat surfaces and mitigations.

    ## Inputs
    - architecture context
- change description/diff

    ## Outputs
    - risks
- mitigations
- checks to run

    ## Process
    1. Identify assets and trust boundaries.
2. Identify threats.
3. Check controls.
4. Define validations.
5. Escalate if needed.

    ## Quality bar
    Risks are credible and mitigations are practical and testable.

    ## Escalation triggers
    Sensitive data, auth changes, new external integrations.
