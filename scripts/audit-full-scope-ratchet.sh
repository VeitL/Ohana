#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASELINE="docs/governance/manifests/full-scope-audit-baseline.json"
UPDATE_BASELINE=0
STRICT_ZERO=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-full-scope-ratchet.sh [--update-baseline] [--strict-zero]

Purpose:
  Run whole-repo UI V4, accessibility, and smoothness audits and compare their
  warning counts against a per-file/per-rule baseline. This is the bridge from
  changed-file ratchets to full-scope strict gates:

  - New or increased debt fails CI.
  - Reduced debt passes and can be locked in with --update-baseline.
  - When the baseline reaches zero, replace this ratchet with direct --all
    strict audit commands.

Options:
  --update-baseline  Replace the baseline manifest with the current full-scope scan.
  --strict-zero      Ignore the baseline and fail unless all full-scope audits are clean.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-baseline)
      UPDATE_BASELINE=1
      shift
      ;;
    --strict-zero)
      STRICT_ZERO=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

python3 - "$BASELINE" "$UPDATE_BASELINE" "$STRICT_ZERO" <<'PY'
from __future__ import annotations

import datetime as dt
import json
import pathlib
import re
import subprocess
import sys
from collections import Counter
from typing import Any

baseline_path = pathlib.Path(sys.argv[1])
update_baseline = sys.argv[2] == "1"
strict_zero = sys.argv[3] == "1"

AUDITS = [
    ("ui-v4", ["scripts/audit-ui-v4.sh", "--all", "--soft"]),
    ("accessibility", ["scripts/audit-accessibility.sh", "--all", "--soft"]),
    ("smoothness", ["scripts/audit-smoothness-risk.sh", "--all", "--soft"]),
]

WARNING_RE = re.compile(r"^\[([^\]]+)\]\s+(.+?\.swift):\d+:", re.MULTILINE)


def run_audit(name: str, command: list[str]) -> dict[str, Any]:
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        print(f"Full-scope ratchet: {name} audit command failed.", file=sys.stderr)
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)

    counts: Counter[tuple[str, str]] = Counter()
    for rule, file_path in WARNING_RE.findall(result.stdout):
        counts[(rule, file_path)] += 1

    rules: dict[str, dict[str, Any]] = {}
    for (rule, file_path), count in sorted(counts.items()):
        entry = rules.setdefault(rule, {"totalWarnings": 0, "files": {}})
        entry["totalWarnings"] += count
        entry["files"][file_path] = count

    return {
        "command": " ".join(command),
        "totalWarnings": sum(counts.values()),
        "rules": rules,
    }


def snapshot() -> dict[str, Any]:
    audits = {name: run_audit(name, command) for name, command in AUDITS}
    return {
        "schema": "ohana.governance.full-scope-audit-baseline.v1",
        "updated": dt.date.today().isoformat(),
        "policyDocuments": [
            "AGENTS.md",
            "docs/governance/full-scope-ratchet-policy.md",
            "docs/design/ui规范.md",
            "docs/accessibility-governance.md",
            "docs/app-architecture-governance.md",
        ],
        "description": (
            "Full-repo UI/accessibility/smoothness ratchet baseline. "
            "CI fails when any file/rule warning count increases; reduce this "
            "manifest after cleanup until all totals reach zero."
        ),
        "promotionTarget": {
            "ui-v4": "scripts/audit-ui-v4.sh --all",
            "accessibility": "scripts/audit-accessibility.sh --all",
            "smoothness": "scripts/audit-smoothness-risk.sh --all",
        },
        "audits": audits,
    }


def load_baseline() -> dict[str, Any]:
    if not baseline_path.is_file():
        print(
            f"Full-scope ratchet: missing baseline {baseline_path}. "
            "Run scripts/audit-full-scope-ratchet.sh --update-baseline after "
            "reviewing the initial full-scope debt.",
            file=sys.stderr,
        )
        sys.exit(1)
    try:
        return json.loads(baseline_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Full-scope ratchet: invalid baseline JSON: {exc}", file=sys.stderr)
        sys.exit(1)


def file_counts(data: dict[str, Any], audit_name: str) -> dict[tuple[str, str], int]:
    audit = data.get("audits", {}).get(audit_name, {})
    rules = audit.get("rules", {})
    counts: dict[tuple[str, str], int] = {}
    if not isinstance(rules, dict):
        return counts
    for rule, rule_data in rules.items():
        files = rule_data.get("files", {}) if isinstance(rule_data, dict) else {}
        if not isinstance(files, dict):
            continue
        for file_path, count in files.items():
            if isinstance(file_path, str) and isinstance(count, int):
                counts[(rule, file_path)] = count
    return counts


current = snapshot()

if update_baseline:
    baseline_path.parent.mkdir(parents=True, exist_ok=True)
    baseline_path.write_text(
        json.dumps(current, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Full-scope ratchet: baseline updated at {baseline_path}.")

if strict_zero:
    failures = [
        f"{name}: {audit['totalWarnings']} warning(s)"
        for name, audit in current["audits"].items()
        if audit["totalWarnings"] > 0
    ]
    if failures:
        print("Full-scope ratchet: strict-zero failed.", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        sys.exit(1)
    print("Full-scope ratchet: strict-zero passed.")
    sys.exit(0)

baseline = current if update_baseline else load_baseline()
failures: list[str] = []
reductions: list[str] = []

for audit_name, current_audit in current["audits"].items():
    baseline_audit = baseline.get("audits", {}).get(audit_name, {})
    baseline_total = int(baseline_audit.get("totalWarnings", 0))
    current_total = int(current_audit.get("totalWarnings", 0))
    if current_total < baseline_total:
        reductions.append(f"{audit_name}: {baseline_total} -> {current_total}")

    baseline_counts = file_counts(baseline, audit_name)
    current_counts = file_counts(current, audit_name)

    for key, current_count in sorted(current_counts.items()):
        baseline_count = baseline_counts.get(key, 0)
        if current_count > baseline_count:
            rule, file_path = key
            failures.append(
                f"{audit_name} {rule} {file_path}: "
                f"{baseline_count} -> {current_count}"
            )

if failures:
    print("Full-scope ratchet: failed. New or increased debt detected.", file=sys.stderr)
    for failure in failures[:80]:
        print(f" - {failure}", file=sys.stderr)
    if len(failures) > 80:
        print(f" - ... and {len(failures) - 80} more increase(s).", file=sys.stderr)
    print(
        "Fix the new warnings. Only run --update-baseline after intentional "
        "cleanup has reduced the baseline.",
        file=sys.stderr,
    )
    sys.exit(1)

for audit_name, audit in current["audits"].items():
    print(f"Full-scope ratchet: {audit_name} {audit['totalWarnings']} warning(s).")

if reductions:
    print("Full-scope ratchet: debt reduced; update the baseline to lock it in:")
    for reduction in reductions:
        print(f" - {reduction}")
    print("   scripts/audit-full-scope-ratchet.sh --update-baseline")

if all(audit["totalWarnings"] == 0 for audit in current["audits"].values()):
    print("Full-scope ratchet: baseline is clean; promote CI to direct --all strict audits.")
else:
    print("Full-scope ratchet: passed. No file/rule warning count increased.")
PY
