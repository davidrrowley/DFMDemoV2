# Agent Pipeline

This template repo is designed for **spec-driven delivery** with a lightweight **agent operating model**.

Spec-kit does not automatically orchestrate agents by itself. Instead, this repo makes agent usage **inevitable** by embedding routing, ownership, and quality gates into the artefacts spec-kit works from.

## Core flow

1. **Intake**
   - New work is introduced via a feature folder under `specs/` or a GitHub issue that links to one.
   - The default entry point is the product spec: `specs/000-product-name-here/spec.md` (rename to `00-product/` when initialized).

2. **Triage and routing**
   - If a task has an explicit owner, that agent executes it.
   - If no owner is provided, routing defaults are applied using `agents/routing.yml`.
   - Cross-stream dependencies are coordinated by the `orchestrator` agent.

3. **Delegation**
   - Work is split into small, independently verifiable tasks.
   - Every delegated task includes **acceptance criteria** and **validation steps**.
   - **Parallelization:** Mark tasks with empty or minimal `depends_on` lists as parallel-safe. The Orchestrator should delegate these simultaneously to different agents (via subagents if available) to maximize throughput and reduce latency.
   - **Continuity:** Maintain a running to-do list in `specs/<feature>/tasks.md` with a short "Last known state" note (date, last completed task, next task) so work can resume without re-running `/specify`.

4. **Implementation**
   - Implementer agents create PRs only (no direct merges).
   - Required evidence (tests, docs, ADRs, threat model updates) is produced as part of the PR.

5. **Quality gates**
   - CI checks verify: tasks are owned, owners exist in the registry, and routing rules remain valid.
   - Security and architecture gates are applied when triggers indicate.

6. **Decision traceability**
   - Material decisions are captured as ADRs under `docs/adr/`.
   - Architecture changes update `docs/architecture/architecture.md`.

## Artefacts that drive behaviour

- Agent catalogue (human-readable): `AGENTS.md`
- Agent registry (machine-readable): `agents/registry/agents.v1.yml`
- Routing defaults (machine-readable): `agents/routing.yml`
- Task ownership format: `agents/contracts/task-block.md`
- Governance checks: `scripts/agent/validate_agent_governance.py` and `.github/workflows/agent-governance.yml`

## Break-glass rules

The `orchestrator` coordinates by default and should not implement. If you must override this:
- record the reason in the feature `tasks.md`
- time-box the change
- open an ADR if it changes architecture or guardrails
