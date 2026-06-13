#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-economy-boundaries.sh [--changed|--all|--soft|--update-baseline] [Swift files or directories...]

Purpose:
  Enforce recurring Economy/feature-gate findings:
  - R1: coconutBalance writes must stay inside the wallet mutation pipeline.
  - R2: reward calls must carry an executor/actor and must not route to system wallets.
  - R4: feature/frozen/read-only gates visible in Views must also have a service-layer hard gate.

Baseline:
  Full-scope debt is ratcheted in
  docs/governance/manifests/recurring-findings-audit-baseline.json.
  New or increased file/rule counts fail. Refresh the baseline only after
  deliberate review:
    scripts/audit-economy-boundaries.sh --all --update-baseline

Allowlist:
  Add "economy-boundary: allow <reason>" on the line/block for deliberate
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
AUDIT_NAME = "economy-boundaries"

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


def read_lines(path: pathlib.Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="ignore").splitlines()


def allowed_line(line: str) -> bool:
    return "economy-boundary: allow" in line


def is_allowed_balance_write(path: str) -> bool:
    allowed_exact = {
        "Ohana/Domain/Economy/CoconutWalletService.swift",
        "Ohana/Domain/Economy/CoconutWalletService+DeveloperOverride.swift",
        "Ohana/Domain/Services/DataBackupManager+Decode.swift",
        "Ohana/Models/Human.swift",
        "Ohana/Models/Pet.swift",
    }
    if path in allowed_exact:
        return True
    return (
        "CoconutWalletMutationWriter" in path
        or "CoconutWalletFundingPlanner" in path
    )


def is_view_path(path: str) -> bool:
    return (
        "/Views/" in path
        or path.startswith("Ohana/Shared/Components/")
        or path.endswith("View.swift")
        or path.endswith("View+Commands.swift")
        or path.endswith("View+Chrome.swift")
        or path.endswith("View+Runtime.swift")
        or path.endswith("View+Popups.swift")
    )


def is_service_path(path: str) -> bool:
    if is_view_path(path):
        return False
    return (
        "/Domain/" in path
        or "/Services/" in path
        or path.startswith("Ohana/App/")
        or path.endswith("Service.swift")
        or path.endswith("Manager.swift")
        or path.endswith("Managing.swift")
        or path.endswith("Commands.swift")
        or path.endswith("CommandService.swift")
        or path.endswith("CommandExecutor.swift")
        or path.endswith("Engine.swift")
        or path.endswith("RouteGuard.swift")
        or path.endswith("Models.swift")
    )


def collect_call(lines: list[str], start: int) -> tuple[str, int]:
    block: list[str] = []
    depth = 0
    started = False
    end = start
    for idx in range(start, len(lines)):
        line = lines[idx]
        block.append(line)
        for char in line:
            if char == "(":
                depth += 1
                started = True
            elif char == ")":
                depth -= 1
        end = idx
        if started and depth <= 0:
            break
        if idx - start > 80:
            break
    return "\n".join(block), end


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


def scan_coconut_balance_writes(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    if is_allowed_balance_write(path_str):
        return
    pattern = re.compile(r"\b(?!self\b)[A-Za-z_][A-Za-z0-9_]*\??\.coconutBalance\s*(?:=|\+=|-=)(?!=)")
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line):
            continue
        if pattern.search(line):
            add(
                warnings,
                "coconut-balance-direct-write",
                path_str,
                idx,
                line,
                "Coconut wallet balances must be mutated through the wallet mutation pipeline, not by direct model writes.",
            )


REWARD_CALL_RE = re.compile(
    r"\b(?:awardAction|addCoconuts|batchAward)\s*\(|\b[A-Za-z0-9_]+CommandService\.award\s*\("
)


def scan_reward_actor_boundaries(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    if path_str.endswith("QuestManager+LegacyWallet.swift"):
        return

    idx = 0
    while idx < len(lines):
        line = lines[idx]
        stripped = line.strip()
        if allowed_line(line) or stripped.startswith("func ") or stripped.startswith("static func "):
            idx += 1
            continue
        if not REWARD_CALL_RE.search(line):
            idx += 1
            continue

        block, end = collect_call(lines, idx)
        if "economy-boundary: allow" in block:
            idx = end + 1
            continue

        reasons: list[str] = []
        if re.search(r"\b(actorKind|ownerKind)\s*:\s*\.system\b", block):
            reasons.append("system actor/owner")
        if re.search(r'\bsystem:legacy\b|CoconutWalletAccountKey\.legacySystem\b', block):
            reasons.append("system:legacy wallet")
        if re.search(r"\bactorId\s*:\s*nil\b", block):
            reasons.append("nil actorId")
        if (
            re.search(r"\b(?:awardAction|batchAward)\s*\(", block)
            and not re.search(r"\b(?:actorId|executorId)\s*:", block)
        ):
            reasons.append("missing executor/actor argument")

        if reasons:
            add(
                warnings,
                "reward-actor-boundary",
                path_str,
                idx + 1,
                stripped,
                "Reward calls must carry executor/actor ownership and must not fall back to system wallets: "
                + ", ".join(sorted(set(reasons)))
                + ".",
            )
        idx = end + 1


GATE_RULES: list[tuple[str, re.Pattern[str], re.Pattern[str], str]] = [
    (
        "online-feature-gate",
        re.compile(r"\bOnlineFeatureGate\.allows\s*\("),
        re.compile(r"\bOnlineFeatureGate\.allows\s*\("),
        "Online collaboration gates visible in UI must also be enforced in app/service entry points.",
    ),
    (
        "plant-feature-gate",
        re.compile(r"\bPlantFeatureGate\.allows\s*\("),
        re.compile(r"\bPlantFeatureGate\.allows\s*\("),
        "Plant gates visible in UI must also be enforced in route/service/quest entry points.",
    ),
    (
        "coconut-exchange-gate",
        re.compile(r"\bCoconutExchangeFeatureGate\.isEnabled\b"),
        re.compile(r"\bCoconutExchangeFeatureGate\.isEnabled\b"),
        "Coconut exchange UI gates must be backed by a service-layer feature-disabled guard.",
    ),
    (
        "wallet-frozen-gate",
        re.compile(r"\b(?:walletFrozen|currentHumanWalletIsFrozen|petWalletFrozen|EconomyWalletWritePolicy\.canWrite)\b"),
        re.compile(r"\b(?:EconomyWalletWritePolicy\.canWrite|isFrozenWrite|walletFrozen)\b"),
        "Frozen-wallet UI checks must be backed by command/service write rejection.",
    ),
    (
        "lifecycle-readonly-gate",
        re.compile(r"\b(?:passedAwayDate|trashedAt|isReadOnly|readOnly)\b"),
        re.compile(r"\b(?:passedAwayDate|trashedAt|readOnly|isReadOnly)\b"),
        "Memorial/recycle read-only UI checks must be backed by command/service lifecycle guards.",
    ),
]


def scan_service_gate_coverage(files: list[pathlib.Path], warnings: list[WarningItem]) -> None:
    occurrences: dict[str, list[tuple[str, int, str]]] = {rule: [] for rule, _, _, _ in GATE_RULES}
    hard_gate_seen: dict[str, bool] = {rule: False for rule, _, _, _ in GATE_RULES}

    for path in files:
        path_str = rel(path)
        if not path.is_file():
            continue
        lines = read_lines(path)
        content = "\n".join(line for line in lines if "economy-boundary: allow" not in line)
        for rule, view_re, service_re, _ in GATE_RULES:
            if is_service_path(path_str) and service_re.search(content):
                hard_gate_seen[rule] = True
            if is_view_path(path_str):
                for idx, line in enumerate(lines, start=1):
                    if allowed_line(line):
                        continue
                    if view_re.search(line):
                        occurrences[rule].append((path_str, idx, line))

    for rule, _, _, message in GATE_RULES:
        if hard_gate_seen[rule] or not occurrences[rule]:
            continue
        path_str, line, snippet = occurrences[rule][0]
        add(warnings, "view-soft-gate-without-service-hard-gate", path_str, line, snippet, message)


def scan(files: list[pathlib.Path]) -> list[WarningItem]:
    warnings: list[WarningItem] = []
    for path in files:
        if not path.is_file():
            continue
        lines = read_lines(path)
        scan_coconut_balance_writes(path, lines, warnings)
        scan_reward_actor_boundaries(path, lines, warnings)
    scan_service_gate_coverage(files, warnings)
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
        print(f"Economy boundaries audit: invalid baseline JSON: {exc}", file=sys.stderr)
        sys.exit(1)


def snapshot(warnings: list[WarningItem]) -> dict[str, Any]:
    counts: Counter[tuple[str, str]] = Counter((item.rule, item.path) for item in warnings)
    rules: dict[str, dict[str, Any]] = {}
    for (rule, path), count in sorted(counts.items()):
        entry = rules.setdefault(rule, {"totalWarnings": 0, "files": {}})
        entry["totalWarnings"] += count
        entry["files"][path] = count
    return {
        "command": "scripts/audit-economy-boundaries.sh --all",
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
    print("Economy boundaries audit: no Swift files to scan.")
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
    print(f"Economy boundaries audit: baseline updated at {BASELINE_PATH}.")

base_counts = baseline_counts(baseline)
current_counts: Counter[tuple[str, str]] = Counter((item.rule, item.path) for item in warnings)
increases = []
for key, count in sorted(current_counts.items()):
    old = base_counts.get(key, 0)
    if count > old:
        increases.append((key, old, count))

if warnings:
    print(f"Economy boundaries audit: review warnings in {len(files)} file(s).")
    print()
    for item in warnings:
        print(f"[{item.rule}] {item.path}:{item.line}: {item.snippet}")
        print(f"  {item.message}")
        print()
else:
    print(f"Economy boundaries audit: passed ({len(files)} file(s)).")

if increases:
    print("Economy boundaries audit: new or increased recurring findings debt:", file=sys.stderr)
    for (rule, path), old, count in increases[:80]:
        print(f" - {rule} {path}: {old} -> {count}", file=sys.stderr)
    if len(increases) > 80:
        print(f" - ... and {len(increases) - 80} more increase(s).", file=sys.stderr)

if strict and increases:
    sys.exit(1)
sys.exit(0)
PY
