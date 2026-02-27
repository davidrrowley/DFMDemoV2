# Agents

This folder contains agent contracts, prompts, skills, and policies used by the template.

## Structure
- registry/agents.v1.yml: source of truth for agent roster and contracts
- prompts/*/system.md: persona and guardrails for each agent
- skills/*: reusable skill contracts and rubrics
- policies/*: global guardrails and evidence expectations

## Adding a new agent
1. Add a contract entry in registry/agents.v1.yml.
2. Create a prompt folder in prompts/<agent-id>/ with system.md.
3. Reference existing skills or add a new skill if the work is repeatable.

## Contracts

- Task blocks: `contracts/task-block.md`
- Registry schema: `contracts/agent-registry.schema.json`
- Routing schema: `contracts/agent-routing.schema.json`
