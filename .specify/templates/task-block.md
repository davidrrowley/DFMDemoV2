## <TASK_ID> — <Short title>

owner: <agent-id>
stream: <orchestration|app|cloud|data|ux|security|quality|platform|devex>
depends_on: [<TASK_ID>, <TASK_ID>]

intent:
- <1–3 lines describing what this task is trying to achieve>

acceptance:
- <observable outcomes>
- <keep this testable>

validate:
- <exact checks to prove it works: commands, screenshots, queries, CI jobs>
- <include where evidence should be recorded>

evidence:
- agents/outputs/evidence/<feature>/<task-id>.md

risk:
- low|medium|high

cost_profile:
- cheap_text|cheap_router|balanced_reasoning|top_reasoning
