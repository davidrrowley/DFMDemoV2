# Skill: code-review

    ## Intent
    Review code changes for correctness, security, separation of concerns, and maintainability.

    ## Inputs
    - PR diff
- relevant standards and spec

    ## Outputs
    - review comments grouped by severity
- suggested fixes
- validation steps

    ## Process
    1. Validate against spec.
2. Check security and secrets.
3. Check maintainability and structure.
4. Identify edge cases.
5. Suggest tests.

    ## Quality bar
    Comments are actionable and prioritised; no bikeshedding.

    ## Escalation triggers
    Security issues; breaking changes; missing tests.
