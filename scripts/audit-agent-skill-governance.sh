#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

python3 - "$@" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path.cwd()

args = list(sys.argv[1:])
soft = False
paths: list[str] = []
for arg in args:
    if arg == "--soft":
        soft = True
    elif arg in {"--all", "--changed"}:
        continue
    else:
        paths.append(arg)

if not paths:
    paths = [".codex/skills"]


def expand_path(raw: str) -> list[pathlib.Path]:
    path = (ROOT / raw).resolve()
    if not path.exists():
        return []
    if path.is_file():
        return [path] if path.suffix.lower() in {".md", ".yaml", ".yml"} else []
    return sorted(
        p for p in path.rglob("*")
        if p.is_file() and p.suffix.lower() in {".md", ".yaml", ".yml"}
    )


files: list[pathlib.Path] = []
seen: set[pathlib.Path] = set()
for raw in paths:
    for path in expand_path(raw):
        if path not in seen:
            files.append(path)
            seen.add(path)

if not files:
    print("Agent skill governance audit: no skill files to scan.")
    sys.exit(0)


def is_self_improving(path: pathlib.Path, text: str) -> bool:
    lower = text.lower()
    rel = path.relative_to(ROOT).as_posix().lower()
    return (
        "self-improving" in rel
        or "name: self-improving" in lower
        or "self-improving" in lower
        or "self improving" in lower
    )


def is_negated(line: str) -> bool:
    lower = line.lower()
    return any(
        phrase in lower
        for phrase in (
            "do not",
            "don't",
            "must not",
            "cannot",
            "never",
            "not allowed",
            "disallowed",
            "forbidden",
        )
    )


def report(path: pathlib.Path, line_no: int, rule: str, message: str) -> None:
    rel = path.relative_to(ROOT)
    issues.append(f"{rel}:{line_no}: [{rule}] {message}")


issues: list[str] = []

for path in files:
    text = path.read_text(encoding="utf-8")
    if not is_self_improving(path, text):
        continue

    lower = text.lower()
    lines = text.splitlines()

    if path.name == "SKILL.md":
        if "required output" not in lower or "improvement proposal" not in lower:
            report(path, 1, "skill-missing-required-output", "Self-improving skills must require an Improvement Proposal output.")
        if not re.search(r"\b(explicit|human|user)\s+approval\b|\bapproved by the user\b", lower):
            report(path, 1, "skill-missing-human-approval", "Self-improving skills must require explicit human approval before mutation.")
        if "evidence" not in lower:
            report(path, 1, "skill-missing-evidence", "Self-improving skills must require evidence for proposed improvements.")

    for idx, line in enumerate(lines, start=1):
        lower_line = line.lower()
        if is_negated(lower_line):
            continue

        mutation_action = r"(?:edit|edits|modify|modifies|patch|patches|write|writes|update|updates|commit|commits|change|changes)"
        auto_mutates = (
            re.search(rf"\b(auto(?:matically)?|silently)\b.*\b{mutation_action}\b", lower_line)
            or re.search(rf"\b{mutation_action}\b.*\bwithout\b.*\bapproval\b", lower_line)
        )
        if auto_mutates:
            report(path, idx, "skill-auto-mutation", "Self-improving skills must not claim authority to mutate files automatically.")

        priority_violation = (
            "higher priority than agents.md" in lower_line
            or "overrides agents.md" in lower_line
            or "ignore agents.md" in lower_line
            or "above repository governance" in lower_line
        )
        if priority_violation:
            report(path, idx, "skill-priority-over-governance", "Self-improving skills must not outrank AGENTS.md or governance docs.")

if issues:
    print("Agent skill governance audit: found issues in skill governance files.")
    for issue in issues:
        print(issue)
    sys.exit(0 if soft else 1)

print(f"Agent skill governance audit: passed ({len(files)} file(s)).")
PY
