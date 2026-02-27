# Skills

A **skill** is a reusable capability with a defined contract (inputs/outputs), a prompt, and an evaluation rubric.

Pattern:
- `skill.md`: intent, steps, I/O contract
- `prompt.md`: the executable prompt body used by agents
- `rubric.md`: how to evaluate the output
- `examples/`: sample inputs/outputs
- `tests/`: automated or semi-automated checks (future)

Create one folder per skill, e.g. `agents/skills/architecture-review/`.
