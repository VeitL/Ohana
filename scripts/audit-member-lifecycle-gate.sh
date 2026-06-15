#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-member-lifecycle-gate.sh [--changed|--all|--soft] [Swift files or directories...]

Purpose:
  R8: member write commands/services must not hand-roll deceased-member write
  gates with hasPassedAway/passedAwayDate. Write paths must consume
  MemberLifecycleGate or a compatibility shim that delegates to it.

Allowlist:
  Add "member-lifecycle-gate: allow <reason>" on an approved line/block for
  lifecycle implementations or non-write display/read logic.
USAGE
}

mode="changed"
strict=1
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

python3 - "$mode" "$strict" ${targets[@]+"${targets[@]}"} <<'PY'
from __future__ import annotations

import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass

ROOT = pathlib.Path.cwd()
mode = sys.argv[1]
strict = sys.argv[2] == "1"
targets = [pathlib.Path(arg) for arg in sys.argv[3:]]


@dataclass(frozen=True)
class WarningItem:
    path: str
    line: int
    snippet: str


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


def is_write_path(path: str) -> bool:
    name = pathlib.Path(path).name
    if targets and path.startswith("scripts/tests/fixtures/"):
        return True
    if "/Views/" in path and "+Commands" not in name:
        return False
    return (
        path.startswith("Ohana/Domain/")
        or path.startswith("Ohana/Features/")
    ) and (
        name.endswith("Commands.swift")
        or name.endswith("CommandService.swift")
        or name.endswith("CommandExecutor.swift")
        or name.endswith("Service.swift")
        or name.endswith("Managing.swift")
        or name.endswith("Manager.swift")
        or name.endswith("Writer.swift")
        or name.endswith("+Commands.swift")
    )


def allowed_path(path: str) -> bool:
    return path in {
        "Ohana/Domain/Services/MemberLifecycleGate.swift",
        "Ohana/Features/Memorial/RainbowBridgeService.swift",
    }


def allowed_line(line: str) -> bool:
    return "member-lifecycle-gate: allow" in line


DIRECT_GATE_RE = re.compile(
    r"\b(?:guard|if)\b.*(?:hasPassedAway|passedAwayDate\s*(?:==|!=|<|>|<=|>=))"
)
FUNC_DECL_RE = re.compile(r"\b(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
MEMBER_PARAM_RE = re.compile(r"\b(?:pet|human)\s*:\s*(?:Pet|Human)\b")
WRITE_EFFECT_RE = re.compile(
    r"\bcontext\.(?:insert|delete|safeSave)\b"
    r"|CloudSyncMutationRecorder\.mark(?:Modified|Deleted)"
    r"|CarePlanCalendarSync\.suppressDefaultPlan"
    r"|FeedingPlanWriter\.(?:replacePlan|deletePlan|deactivateManualReminderOperations|clearFeedModePlans|ensureUpcomingManualReminders|saveFoodPurchase|correctFoodStock|rebuildFoodStockReminder)"
    r"|OhanaNotifications\.current\.cancel"
)
GATE_CONSUMPTION_RE = re.compile(
    r"MemberLifecycleGate\.disposition"
    r"|MemberWritePolicy\.disposition"
    r"|CareFactWritePolicy\.disposition"
    r"|EconomyWalletWritePolicy\.canWrite"
    r"|SharedPetTargetResolver\.normalizedTargets"
    r"|canWriteActiveFeedData"
    r"|PetCareTrackingCommandService\.deleteCareLog"
    r"|PetPottyCommandService\.deletePottyLog"
    r"|PetHygieneCommandService\.delete"
    r"|CatCareCommandService\.undo"
)
CRITICAL_GATE_FUNCTIONS = {
    "Ohana/Features/Feeding/FeedingPlanWriter.swift": {
        "replacePlan",
        "deletePlan",
        "deactivateManualReminderOperations",
        "clearFeedModePlans",
        "ensureUpcomingManualReminders",
        "saveFoodPurchase",
        "correctFoodStock",
        "rebuildFoodStockReminder",
        "rebuildFoodStockReminders",
    },
    "Ohana/Features/PetCare/PetCareCommands.swift": {"deleteCareLog", "deletePottyLog"},
    "Ohana/Features/CatCare/CatCareCommands.swift": {"undo"},
    "Ohana/Features/Hygiene/PetHygieneCommands.swift": {"delete"},
}


def function_blocks(lines: list[str]) -> list[tuple[str, int, str]]:
    blocks: list[tuple[str, int, str]] = []
    idx = 0
    while idx < len(lines):
        match = FUNC_DECL_RE.search(lines[idx])
        if not match:
            idx += 1
            continue

        start = idx
        end = idx
        brace_depth = 0
        saw_open = False
        while end < len(lines):
            current = lines[end]
            brace_depth += current.count("{")
            if "{" in current:
                saw_open = True
            brace_depth -= current.count("}")
            if saw_open and brace_depth <= 0:
                break
            end += 1
        blocks.append((match.group(1), start + 1, "\n".join(lines[start : end + 1])))
        idx = max(end + 1, idx + 1)
    return blocks


def requires_lifecycle_gate(path: str, func_name: str, body: str) -> bool:
    if func_name in CRITICAL_GATE_FUNCTIONS.get(path, set()):
        return True
    if path.startswith("scripts/tests/fixtures/") and MEMBER_PARAM_RE.search(body) and WRITE_EFFECT_RE.search(body):
        return True
    return False


warnings: list[WarningItem] = []
files = collect_files()
for path in files:
    path_str = rel(path)
    if allowed_path(path_str) or not is_write_path(path_str):
        continue
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line):
            continue
        if DIRECT_GATE_RE.search(line):
            warnings.append(WarningItem(path_str, idx, line.strip()))
    for func_name, start_line, body in function_blocks(lines):
        if "member-lifecycle-gate: allow" in body:
            continue
        if requires_lifecycle_gate(path_str, func_name, body) and not GATE_CONSUMPTION_RE.search(body):
            warnings.append(
                WarningItem(
                    path_str,
                    start_line,
                    f"func {func_name} writes member-scoped data without MemberLifecycleGate/MemberWritePolicy",
                )
            )

for item in warnings:
    rule = "member-lifecycle-direct-write-gate"
    message = "write paths must use MemberLifecycleGate/MemberWritePolicy instead of hand-rolled deceased-member gates."
    if item.snippet.startswith("func ") and "without MemberLifecycleGate" in item.snippet:
        rule = "member-lifecycle-missing-disposition"
        message = "member-scoped write paths must consume MemberLifecycleGate/MemberWritePolicy before mutating."
    print(f"[{rule}] {item.path}:{item.line}: {message}")
    print(f"    {item.snippet}")

print(f"member lifecycle gate audit: scanned {len(files)} file(s); warnings={len(warnings)}")
if warnings and strict:
    sys.exit(1)
PY
