# autonomous-delivery-patterns.md

> **Template guidance:** Copy this file into `specs/00-product/autonomous-delivery-patterns.md`.
>
> These patterns describe *how* to run multi-agent delivery safely and efficiently in any new project using this template.

## Pattern 01: Spec-First Intake
Normalise inbound requests into feature specs before implementation.

## Pattern 02: Dependency-Graph Scheduling
Use `depends_on:` at task level; deliver in waves (foundations → experiences → advanced).

## Pattern 03: Parallel Workstreams with Boundaries
Run streams (platform, API, clients, web, data/AI, security) in parallel with explicit boundaries.

## Pattern 04: Cost-Aware Model Routing
Use the cheapest viable model; escalate only when triggered by complexity/risk.

## Pattern 05: Evidence-Driven Delivery
Every PR includes validation evidence (tests, screenshots, scan outputs, perf notes).

## Pattern 06: Two-Phase Contracting
Contract-first for APIs and schemas, then implementation behind stable contracts.

## Pattern 07: ADR-as-a-Gate
Breaking or cross-cutting decisions require ADRs before merge.

## Pattern 08: Security-by-Default Pipelines
Threat modelling + scanning wired into CI; mitigations tracked as tasks.

## Pattern 09: Feature Completion Checklists
Definition of Done differs by feature type (UI/API/infra/data).

## Pattern 10: Autonomous Backlog Grooming
Orchestrator routinely checks for missing owners, missing acceptance/validation, stale dependencies.

## Pattern 11: Break-Glass Implementation
Orchestrator may implement only with explicit `break_glass=true` and extra evidence.

## Pattern 12: Progressive Value Delivery
Deliver useful value early; improve capability incrementally (capture → search → organisation → distill → graph → enrichment).

