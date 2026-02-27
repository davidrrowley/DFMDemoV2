#!/usr/bin/env python3
import os
import re
import sys
from pathlib import Path

RE_OWNER = re.compile(r'^\s*owner:\s*([A-Za-z0-9_-]+)\s*$', re.MULTILINE)

def read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="replace")

def find_registry_file(repo_root: Path) -> Path | None:
    candidates = [
        repo_root / "agents" / "registry" / "registry.yml",
        repo_root / "agents" / "registry.yml",
        repo_root / "agents" / "registry" / "agents.yml",
    ]
    for c in candidates:
        if c.exists():
            return c
    return None

def parse_agent_ids(registry_text: str) -> set[str]:
    # Very lightweight YAML-ish parsing: extract '- id: <value>' lines.
    ids = set()
    for m in re.finditer(r'^\s*-\s*id:\s*([A-Za-z0-9_-]+)\s*$', registry_text, re.MULTILINE):
        ids.add(m.group(1))
    return ids

def is_placeholder_feature_dir(name: str) -> bool:
    # Template placeholders: ignore enforcement for these directories.
    lowered = name.lower()
    return "name-here" in lowered or lowered.startswith("000-") or lowered.startswith("001-")

def iter_feature_dirs(specs_root: Path):
    if not specs_root.exists():
        return
    for p in specs_root.iterdir():
        if p.is_dir():
            yield p

def validate_feature_structure(feature_dir: Path, errors: list[str]):
    # Enforce only for non-placeholder feature dirs.
    if is_placeholder_feature_dir(feature_dir.name):
        return
    # Only enforce on dirs that look like features (contain any md) or have tasks/spec/plan.
    md_files = list(feature_dir.glob("*.md"))
    has_any = any(f.name in ("spec.md", "plan.md", "tasks.md") for f in md_files) or len(md_files) > 0
    if not has_any:
        return

    required = ["spec.md", "plan.md", "tasks.md"]
    missing = [r for r in required if not (feature_dir / r).exists()]
    if missing:
        errors.append(f"[feature-structure] {feature_dir.as_posix()} missing: {', '.join(missing)}")

def split_tasks(text: str) -> list[str]:
    # Split by '---' lines, common in your tasks.md style.
    parts = re.split(r'^\s*---\s*$', text, flags=re.MULTILINE)
    # Keep only blocks that contain an owner: line or start with '##'
    blocks = []
    for p in parts:
        if "owner:" in p or re.search(r'^\s*##\s+', p, re.MULTILINE):
            blocks.append(p)
    return blocks

def validate_tasks(tasks_path: Path, valid_agent_ids: set[str], errors: list[str]):
    text = read_text(tasks_path)
    blocks = split_tasks(text)

    if not blocks:
        # If tasks.md exists, it should have at least one task block
        errors.append(f"[tasks] {tasks_path.as_posix()} contains no task blocks")
        return

    for i, block in enumerate(blocks, start=1):
        # Require owner / acceptance / validate in each block that looks like a task
        owner_m = RE_OWNER.search(block)
        if not owner_m:
            errors.append(f"[tasks] {tasks_path.as_posix()} task-block {i} missing 'owner:'")
            continue

        owner = owner_m.group(1)
        if owner not in valid_agent_ids:
            errors.append(f"[tasks] {tasks_path.as_posix()} task-block {i} owner '{owner}' not found in agent registry")

        if not re.search(r'^\s*acceptance:\s*$', block, re.MULTILINE):
            errors.append(f"[tasks] {tasks_path.as_posix()} task-block {i} missing 'acceptance:'")

        if not re.search(r'^\s*validate:\s*$', block, re.MULTILINE):
            errors.append(f"[tasks] {tasks_path.as_posix()} task-block {i} missing 'validate:'")

def main():
    repo_root = Path(os.getcwd())

    registry_file = find_registry_file(repo_root)
    if not registry_file:
        print("ERROR: Could not find agent registry file. Expected agents/registry/registry.yml or agents/registry.yml", file=sys.stderr)
        return 2

    agent_ids = parse_agent_ids(read_text(registry_file))
    if not agent_ids:
        print(f"ERROR: No agent IDs found in {registry_file.as_posix()} (expected '- id: <agent-id>' lines)", file=sys.stderr)
        return 2

    errors: list[str] = []

    specs_root = repo_root / "specs"
    for feature_dir in iter_feature_dirs(specs_root):
        validate_feature_structure(feature_dir, errors)
        tasks_path = feature_dir / "tasks.md"
        if tasks_path.exists() and not is_placeholder_feature_dir(feature_dir.name):
            validate_tasks(tasks_path, agent_ids, errors)

    if errors:
        print("Spec governance failed:")
        for e in errors:
            print(f" - {e}")
        return 1

    print("Spec governance passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
