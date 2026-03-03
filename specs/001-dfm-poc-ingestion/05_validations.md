# 05 - Validations

## Validation Philosophy

- Deterministic rule execution only.
- Every check writes a record to `dq_results`.
- Row-level failures write pointers to `dq_exception_rows`.
- `not_evaluable` is valid when required inputs are unavailable.

## Stage-Gate Taxonomy

| Gate | Purpose | Required Outcome |
|---|---|---|
| Stage 1 gate | Parsing and raw persistence integrity | File/row persistence complete with diagnostics |
| Stage 2 gate | Contract and quality conformance | Required checks pass or are approved exceptions |
| Stage 3 gate | Publish eligibility | No blocking severity failures |

## Baseline Checks

### DATE_001 - Stale report date

- Severity: `warning`
- Rule: flag if report date exceeds configured staleness window.

### MV_001 - Market value recalculation

- Severity: `exception`
- Rule: compare computed value against reported value.
- Threshold baseline: `tolerance_pct = 0.02`.

### VAL_001 - Zero-cash and zero-bid policy

- Severity: `exception`
- Rule: fail when both totals are zero for a policy in scope.

### MAP_001 - Unmapped security

- Severity: `exception`
- Rule: fail when identifier resolution is missing above residual threshold.

### POP_001 - Unmapped policy

- Severity: `exception`
- Rule: fail when policy mapping is missing.

## Publish-Block Policy

- `stop`: always blocks Stage 3 publication.
- `exception`: blocks unless explicitly approved in governance workflow.
- `warning`: does not block but must be logged.

## Required Outputs

- `dq_results` for all checks and all evaluated scopes.
- `dq_exception_rows` for failing rows with run/DFM/source context.
