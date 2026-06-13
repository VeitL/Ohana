#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-derived-state-lifecycle.sh [--changed|--all|--soft|--update-baseline] [Swift files or directories...]

Purpose:
  Checklist audit for recurring derived-state lifecycle bugs:
  - Delete/recycle/tombstone paths should show restore/reschedule/cascade or
    other derived-state symmetry in the same service boundary.
  - Physical deletes should be paired with a CloudSync tombstone/recordDeletion
    hint unless explicitly allowed.

Baseline:
  Full-scope debt is ratcheted in
  docs/governance/manifests/recurring-findings-audit-baseline.json.

Allowlist:
  Add "derived-state: allow <reason>" on the line/file for deliberate
  exceptions approved by the product owner.
USAGE
}

mode="changed"
strict=1
update_baseline=0
targets=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed)
      mode="changed"
      shift
      ;;
    --all)
      mode="all"
      shift
      ;;
    --soft)
      strict=0
      shift
      ;;
    --update-baseline)
      update_baseline=1
      mode="all"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      targets+=("$1")
      shift
      ;;
  esac
done

python3 - "$mode" "$strict" "$update_baseline" ${targets[@]+"${targets[@]}"} <<'PY'
from __future__ import annotations

import datetime as dt
import json
import pathlib
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from typing import Any

ROOT = pathlib.Path.cwd()
BASELINE_PATH = ROOT / "docs/governance/manifests/recurring-findings-audit-baseline.json"
AUDIT_NAME = "derived-state-lifecycle"

mode = sys.argv[1]
strict = sys.argv[2] == "1"
update_baseline = sys.argv[3] == "1"
targets = [pathlib.Path(arg) for arg in sys.argv[4:]]


@dataclass(frozen=True)
class WarningItem:
    rule: str
    path: str
    line: int
    snippet: str
    message: str


def run_git(args: list[str]) -> list[str]:
    result = subprocess.run(["git", *args], text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line.strip()]


def collect_files() -> list[pathlib.Path]:
    if targets:
        found: list[pathlib.Path] = []
        for target in targets:
            path = target if target.is_absolute() else ROOT / target
            if path.is_dir():
                found.extend(path.rglob("*.swift"))
            elif path.is_file() and path.suffix == ".swift":
                found.append(path)
        return sorted(set(found))

    if mode == "all":
        return sorted((ROOT / "Ohana").rglob("*.swift"))

    changed = set(
        run_git(["diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--", "Ohana"])
        + run_git(["ls-files", "--others", "--exclude-standard", "--", "Ohana"])
    )
    return sorted(
        ROOT / path
        for path in changed
        if path.endswith(".swift") and (ROOT / path).is_file()
    )


def rel(path: pathlib.Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def add(warnings: list[WarningItem], rule: str, path: str, line: int, snippet: str, message: str) -> None:
    warnings.append(
        WarningItem(
            rule=rule,
            path=path,
            line=line,
            snippet=snippet.strip(),
            message=message,
        )
    )


DELETE_MARKER_RE = re.compile(
    r"\b(?:tombstone|isDeletionTombstone|trashExpiresAt|trashedAt|isDeleted|RecycleBin|recycl|purgeExpired|context\.delete|\.delete\s*\()",
    re.IGNORECASE,
)
SYMMETRY_RE = re.compile(
    r"\b(?:restore|reschedule|scheduleManyIfNeeded|cascade|child|children|recordDeletion|tombstone|isDeletionTombstone|rebuild|reopen|pending|quick\s*access)",
    re.IGNORECASE,
)
PHYSICAL_DELETE_RE = re.compile(r"\b(?:context|modelContext)\.delete\s*\(|\.delete\s*\(")
TOMBSTONE_HINT_RE = re.compile(
    r"\b(?:tombstone|isDeletionTombstone|recordDeletion|markDeleted|CloudSyncMutationRecorder|markDirty|sync metadata)",
    re.IGNORECASE,
)


def first_match(lines: list[str], pattern: re.Pattern[str]) -> tuple[int, str] | None:
    for idx, line in enumerate(lines, start=1):
        if "derived-state: allow" in line:
            continue
        if pattern.search(line):
            return idx, line
    return None


def scan_file(path: pathlib.Path, warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    text = path.read_text(encoding="utf-8", errors="ignore")
    if "derived-state: allow" in text:
        return
    lines = text.splitlines()

    marker = first_match(lines, DELETE_MARKER_RE)
    if marker is not None and not SYMMETRY_RE.search(text):
        line, snippet = marker
        add(
            warnings,
            "derived-state-lifecycle-checklist",
            path_str,
            line,
            snippet,
            "Delete/recycle/tombstone lifecycle code must show restore, reschedule, cascade, tombstone, or derived-state rebuilding symmetry in the same service boundary.",
        )

    physical_delete = first_match(lines, PHYSICAL_DELETE_RE)
    if physical_delete is not None and not TOMBSTONE_HINT_RE.search(text):
        line, snippet = physical_delete
        add(
            warnings,
            "physical-delete-without-tombstone",
            path_str,
            line,
            snippet,
            "Physical SwiftData deletes should be paired with a tombstone/recordDeletion hint unless the path is deliberately local-only.",
        )


def scan(files: list[pathlib.Path]) -> list[WarningItem]:
    warnings: list[WarningItem] = []
    for path in files:
        if path.is_file():
            scan_file(path, warnings)
    return sorted(warnings, key=lambda item: (item.rule, item.path, item.line, item.snippet))


def load_baseline() -> dict[str, Any]:
    if not BASELINE_PATH.is_file():
        return {
            "schema": "ohana.governance.recurring-findings-audit-baseline.v1",
            "updated": dt.date.today().isoformat(),
            "policyDocuments": [
                "AGENTS.md",
                "docs/planning/recurring-findings-audit-spec.md",
            ],
            "description": (
                "Ratchet baseline for recurring adversarial-review findings. "
                "Stored counts are accepted debt; new or increased file/rule "
                "counts fail the audits."
            ),
            "audits": {},
        }
    try:
        return json.loads(BASELINE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Derived state lifecycle audit: invalid baseline JSON: {exc}", file=sys.stderr)
        sys.exit(1)


def snapshot(warnings: list[WarningItem]) -> dict[str, Any]:
    counts: Counter[tuple[str, str]] = Counter((item.rule, item.path) for item in warnings)
    rules: dict[str, dict[str, Any]] = {}
    for (rule, path), count in sorted(counts.items()):
        entry = rules.setdefault(rule, {"totalWarnings": 0, "files": {}})
        entry["totalWarnings"] += count
        entry["files"][path] = count
    return {
        "command": "scripts/audit-derived-state-lifecycle.sh --all",
        "totalWarnings": sum(counts.values()),
        "rules": rules,
    }


def baseline_counts(baseline: dict[str, Any]) -> dict[tuple[str, str], int]:
    audit = baseline.get("audits", {}).get(AUDIT_NAME, {})
    rules = audit.get("rules", {}) if isinstance(audit, dict) else {}
    counts: dict[tuple[str, str], int] = {}
    if not isinstance(rules, dict):
        return counts
    for rule, payload in rules.items():
        files = payload.get("files", {}) if isinstance(payload, dict) else {}
        if not isinstance(files, dict):
            continue
        for path, count in files.items():
            if isinstance(rule, str) and isinstance(path, str) and isinstance(count, int):
                counts[(rule, path)] = count
    return counts


files = collect_files()
if not files:
    print("Derived state lifecycle audit: no Swift files to scan.")
    sys.exit(0)

warnings = scan(files)
current_snapshot = snapshot(warnings)
baseline = load_baseline()

if update_baseline:
    baseline.setdefault("audits", {})[AUDIT_NAME] = current_snapshot
    baseline["updated"] = dt.date.today().isoformat()
    BASELINE_PATH.parent.mkdir(parents=True, exist_ok=True)
    BASELINE_PATH.write_text(
        json.dumps(baseline, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Derived state lifecycle audit: baseline updated at {BASELINE_PATH}.")

base_counts = baseline_counts(baseline)
current_counts: Counter[tuple[str, str]] = Counter((item.rule, item.path) for item in warnings)
increases = []
for key, count in sorted(current_counts.items()):
    old = base_counts.get(key, 0)
    if count > old:
        increases.append((key, old, count))

if warnings:
    print(f"Derived state lifecycle audit: review warnings in {len(files)} file(s).")
    print()
    for item in warnings:
        print(f"[{item.rule}] {item.path}:{item.line}: {item.snippet}")
        print(f"  {item.message}")
        print()
else:
    print(f"Derived state lifecycle audit: passed ({len(files)} file(s)).")

if increases:
    print("Derived state lifecycle audit: new or increased recurring findings debt:", file=sys.stderr)
    for (rule, path), old, count in increases[:80]:
        print(f" - {rule} {path}: {old} -> {count}", file=sys.stderr)
    if len(increases) > 80:
        print(f" - ... and {len(increases) - 80} more increase(s).", file=sys.stderr)

if strict and increases:
    sys.exit(1)
sys.exit(0)
PY
