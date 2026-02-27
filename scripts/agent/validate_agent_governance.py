#!/usr/bin/env python3
"""Validate agent governance conventions.

Checks:
- Every task block in specs/**/tasks.md has an owner
- owner exists in agents/registry/agents.v1.yml
- routing.yml exists and is parseable

This is intentionally lightweight (no external deps beyond PyYAML).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

RE_TASK_HEADER = re.compile(r"^###\s+(T-[A-Z0-9\-]+)\s*:\s*(.+)\s*$")
RE_OWNER = re.compile(r"^owner:\s*([a-z0-9][a-z0-9\-]*)\s*$")


def load_agent_ids(repo_root: Path) -> set[str]:
    reg_path = repo_root / "agents" / "registry" / "agents.v1.yml"
    if not reg_path.exists():
        raise FileNotFoundError(f"Missing agent registry: {reg_path}")
    data = yaml.safe_load(reg_path.read_text(encoding="utf-8"))
    agents = data.get("agents", [])
    return {a.get("id") for a in agents if isinstance(a, dict) and a.get("id")}


def validate_tasks_file(path: Path, agent_ids: set[str]) -> list[str]:
    errors: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        m = RE_TASK_HEADER.match(lines[i])
        if not m:
            i += 1
            continue

        task_id = m.group(1)

        owner = None
        j = i + 1
        while j < len(lines) and not lines[j].startswith("### "):
            mo = RE_OWNER.match(lines[j].strip())
            if mo:
                owner = mo.group(1)
                break
            j += 1

        if not owner:
            errors.append(f"{path}: {task_id} missing owner:")
        elif owner not in agent_ids:
            errors.append(f"{path}: {task_id} owner '{owner}' not in agents registry")

        i = j if j > i else i + 1

    return errors


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]

    routing_path = repo_root / "agents" / "routing.yml"
    if not routing_path.exists():
        print(f"Missing routing rules file: {routing_path}", file=sys.stderr)
        return 2
    try:
        yaml.safe_load(routing_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"Failed to parse routing.yml: {e}", file=sys.stderr)
        return 2

    agent_ids = load_agent_ids(repo_root)
    if not agent_ids:
        print("No agents found in registry.", file=sys.stderr)
        return 2

    errors: list[str] = []
    for tasks_md in repo_root.glob("specs/**/tasks.md"):
        errors.extend(validate_tasks_file(tasks_md, agent_ids))

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    print("Agent governance checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
