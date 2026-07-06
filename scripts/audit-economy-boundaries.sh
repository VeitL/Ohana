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
  - R5: feature/domain code must not call QuestManager.awardAction directly; use shared reward discipline primitives.
  - R5b: care rewards must enter audited care-fact chokepoints, not bare EconomyRewardDiscipline calls.
  - R5c: care-fact chokepoint results must consume disposition before publishing or applying derived effects.
  - R5d: explicit care executors that cannot resolve to a writable Human must be command no-op.
  - R5e: care command no-op results must be consumed before UI feedback/revision/secondary actor writes.
  - R6: care command/view code must not publish derived revision/no-op side effects outside CareDerivationExecutor.
  - R7: PetExpenseLog business writes must record a same-boundary CareLedgerEvent.

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


DIRECT_REWARD_CALL_RE = re.compile(r"\.[ \t]*(?:awardAction)\s*\(")
DIRECT_CARE_DISCIPLINE_CALL_RE = re.compile(
    r"\bEconomyRewardDiscipline\.[ \t]*(?:awardCareAction|awardSharedCareAction)\s*\("
)
CARE_FACT_CALL_RE = re.compile(
    r"\.\s*(?:recordSharedManualFeedFact|recordManualFeedFact|recordSharedWateringFact|"
    r"recordSharedCareFact|recordSharedLitterCareFact|recordTreatFeedFact|recordTreatFeed|"
    r"recordCareFact|recordPottyFact|recordHygieneFact|recordHealthFact|completePlannedFeed)\s*\("
)
CARE_FACT_DISPOSITION_CONSUME_RE = re.compile(
    r"\b(?:didWriteFact|didRecord|allowsDerivedEffects|disposition|writesFact)\b"
)
CARE_FACT_WRITE_POLICY_CONSUME_RE = re.compile(
    r"\b(?:CareFactWritePolicy\.disposition|DomainCareFactEffectsDispatcher|didWriteFact|allowsDerivedEffects|disposition)\b"
)
PET_MEDICATION_DOSE_RESULT_CONSUME_RE = re.compile(r"\bdidRecord\b")
CARE_COMMAND_RESULT_CALL_RE = re.compile(
    r"\b(?:commandExecutor\.)?(?:recordManual|recordTreat|recordWater|completePlannedWater|"
    r"recordWaterChange|recordFilterClean|recordSharedPetExpense|recordLitterCare|"
    r"recordUnknownSharedPotty)\s*\("
)
CARE_COMMAND_SUCCESS_EFFECT_RE = re.compile(
    r"\b(?:afterFoodLogSaved|showSaveConfirmation|showTreatSavedCelebration|"
    r"trigger[A-Za-z0-9_]*Feedback|scheduleCarePlanReminders|"
    r"UINotificationFeedbackGenerator|SharedPetSelectionMemory\.saveSelection|"
    r"LitterCareSettingsStore|syncScoopPlan|syncLitterChangePlan|"
    r"wroteBusinessFact\s*:\s*true)\b"
)
CARE_COMMAND_PRE_RESULT_DERIVED_EFFECT_RE = re.compile(
    r"\b(?:afterFoodLogSaved|showTreatSavedCelebration|"
    r"trigger[A-Za-z0-9_]*Feedback|scheduleCarePlanReminders|"
    r"SharedPetSelectionMemory\.saveSelection|LitterCareSettingsStore|"
    r"syncScoopPlan|syncLitterChangePlan|"
    r"UINotificationFeedbackGenerator\(\)\.notificationOccurred\(\.success\)|"
    r"wroteBusinessFact\s*:\s*true)\b"
)
CARE_COMMAND_RESULT_CONSUME_RE = re.compile(
    r"\b(?:didRecord|didWriteFact|allowsDerivedEffects)\b|"
    r"\bguard\s+(?:let\s+)?[A-Za-z0-9_]*\s*=|!=\s*nil"
)
CARE_DERIVATION_DIRECT_PUBLISH_RE = re.compile(
    r"\b(?:revisions\.publish(?:DomainMutation|[A-Za-z0-9_]*)\s*\(|"
    r"publishDomainMutation\s*\(|"
    r"AppPerformanceMonitor\.shared\.record\(\s*\"domain_command_noop\")"
)
CARE_DERIVATION_GATE_RE = re.compile(
    r"\b(?:CareDerivationExecutor|derivations\.derive|derive[A-Za-z0-9_]*\s*\()"
)
CARE_DERIVATION_CONTEXT_RE = re.compile(
    r"\b(?:recordCareFact|recordManualFeedFact|recordPottyFact|recordHygieneFact|"
    r"recordHealthFact|completePlannedFeedResult|completePlannedWaterResult|"
    r"recordDoseResult|recordManual|recordTreat|recordWater|recordWaterChange|"
    r"recordFilterClean|recordLitterCare|recordUnknownSharedPotty|"
    r"PetCareTrackingCommandResult|PetHygieneCheckInCommandResult|"
    r"PetMedicationDoseCommandResult|PetHealthCommandResult|"
    r"CalendarEventCompletionResult|TodayFocusEventCompletionCommandResult|"
    r"CareWriteOutcome|CareDerivationResult)\b"
)
PET_EXPENSE_LOG_CONSTRUCTOR_RE = re.compile(r"\bPetExpenseLog\s*\(")
PET_EXPENSE_CONTEXT_INSERT_RE = re.compile(r"\b(?:context|modelContext)\.insert\s*\(")
PET_EXPENSE_LEDGER_MARKER_RE = re.compile(
    r"\b(?:ExpenseCommandService\.recordPetExpense|recordPetExpense\s*\(|"
    r"recordSharedPetExpense\s*\(|recordSharedExpense\s*\(|recordLedger\s*\(|"
    r"careLedger\.record\s*\(|CareLedgerService\(\)\.record\s*\(|"
    r"legacyModelName\s*:\s*\"PetExpenseLog\")"
)
PET_EXPENSE_IMPORT_BOUNDARY_ALLOWLIST = {
    "Ohana/Domain/Services/CloudSyncRecordApplier.swift",
    "Ohana/Domain/Services/DataBackupManager+Decode.swift",
}


def direct_reward_call_allowed(path: str) -> bool:
    allowed_exact = {
        "Ohana/Features/Economy/EconomyRewardDiscipline.swift",
    }
    return path in allowed_exact


def scan_direct_reward_chokepoint(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    if direct_reward_call_allowed(path_str):
        return
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line):
            continue
        if DIRECT_REWARD_CALL_RE.search(line):
            add(
                warnings,
                "reward-direct-awardaction",
                path_str,
                idx,
                line,
                "QuestManager.awardAction is the low-level reward primitive; feature and domain callers must use EconomyRewardDiscipline care/non-care entry points.",
            )


ALLOWED_CARE_DISCIPLINE_CONTEXTS: dict[str, set[str]] = {
    "Ohana/Features/Economy/CareEventEconomyAwarder.swift": {
        "awardCareAction",
        "awardSharedCareAction",
    },
    "Ohana/Domain/Services/CalendarTaskCompletionSyncService.swift": {
        "awardGeneratedCare",
    },
    "Ohana/Domain/Services/PetMedicationDoseLogging.swift": {
        "recordDoseResult",
    },
    "Ohana/Features/DashboardRecords/DashboardRecordCommands.swift": {
        "recordPetWeight",
    },
    "Ohana/Features/Health/PetHealthCommands.swift": {
        "recordHealth",
    },
    "Ohana/Features/Walks/PetWalkingManager.swift": {
        "stop",
    },
    "scripts/tests/fixtures/Views/RecurringEconomyBoundariesBad.swift": {
        "awardGeneratedCare",
        "recordDoseResult",
    },
}

CARE_DISCIPLINE_CONTEXTS_REQUIRING_WRITE_POLICY: dict[str, set[str]] = {
    "Ohana/Domain/Services/CalendarTaskCompletionSyncService.swift": {
        "awardGeneratedCare",
    },
    "Ohana/Domain/Services/PetMedicationDoseLogging.swift": {
        "recordDoseResult",
    },
    "Ohana/Features/DashboardRecords/DashboardRecordCommands.swift": {
        "recordPetWeight",
    },
    "Ohana/Features/Health/PetHealthCommands.swift": {
        "recordHealth",
    },
    "Ohana/Features/Walks/PetWalkingManager.swift": {
        "stop",
    },
    "scripts/tests/fixtures/Views/RecurringEconomyBoundariesBad.swift": {
        "awardGeneratedCare",
        "recordDoseResult",
    },
}


FUNC_SIGNATURE_RE = re.compile(
    r"^\s*(?:(?:private|fileprivate|internal|public|open|static|class|mutating|nonisolated)\s+)*func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("
)


def enclosing_function_name(lines: list[str], index: int) -> str | None:
    for cursor in range(index, -1, -1):
        match = FUNC_SIGNATURE_RE.search(lines[cursor])
        if match:
            return match.group(1)
    return None


def enclosing_function_start(lines: list[str], index: int) -> int | None:
    for cursor in range(index, -1, -1):
        if FUNC_SIGNATURE_RE.search(lines[cursor]):
            return cursor
    return None


def enclosing_function_bounds(lines: list[str], index: int) -> tuple[int, int] | None:
    start = enclosing_function_start(lines, index)
    if start is None:
        return None
    depth = 0
    opened = False
    for cursor in range(start, len(lines)):
        for char in lines[cursor]:
            if char == "{":
                depth += 1
                opened = True
            elif char == "}":
                depth -= 1
        if opened and depth <= 0:
            return (start, cursor)
    return (start, len(lines) - 1)


def function_bounds(lines: list[str]) -> list[tuple[str, int, int]]:
    bounds: list[tuple[str, int, int]] = []
    for idx, line in enumerate(lines):
        match = FUNC_SIGNATURE_RE.search(line)
        if not match:
            continue
        block_bounds = enclosing_function_bounds(lines, idx)
        if block_bounds is None:
            continue
        bounds.append((match.group(1), block_bounds[0], block_bounds[1]))
    return bounds


def same_file_expense_ledger_callee(lines: list[str], producer_block: str, producer_start: int) -> bool:
    for helper_name, start, end in function_bounds(lines):
        if start == producer_start:
            continue
        block = "\n".join(lines[start:end + 1])
        call_re = re.compile(r"\b" + re.escape(helper_name) + r"\s*\(")
        if call_re.search(producer_block) and PET_EXPENSE_LEDGER_MARKER_RE.search(block):
            return True
    return False


def same_file_expense_ledger_caller(lines: list[str], producer_name: str, producer_start: int) -> bool:
    call_re = re.compile(r"\b" + re.escape(producer_name) + r"\s*\(")
    for _, start, end in function_bounds(lines):
        if start == producer_start:
            continue
        block = "\n".join(lines[start:end + 1])
        if call_re.search(block) and PET_EXPENSE_LEDGER_MARKER_RE.search(block):
            return True
    return False


def direct_care_discipline_allowed(path: str, lines: list[str], index: int) -> bool:
    allowed_functions = ALLOWED_CARE_DISCIPLINE_CONTEXTS.get(path)
    if not allowed_functions:
        return False
    function_name = enclosing_function_name(lines, index)
    return function_name in allowed_functions


def direct_care_discipline_requires_write_policy(path: str, function_name: str | None) -> bool:
    required_functions = CARE_DISCIPLINE_CONTEXTS_REQUIRING_WRITE_POLICY.get(path)
    return bool(required_functions and function_name in required_functions)


def direct_care_discipline_consumes_write_policy(lines: list[str], index: int) -> bool:
    start = enclosing_function_start(lines, index)
    if start is None:
        return False
    function_prefix = "\n".join(lines[start:index + 1])
    return bool(CARE_FACT_WRITE_POLICY_CONSUME_RE.search(function_prefix))


def scan_direct_care_discipline_chokepoint(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line):
            continue
        if DIRECT_CARE_DISCIPLINE_CALL_RE.search(line):
            function_name = enclosing_function_name(lines, idx - 1)
            if direct_care_discipline_allowed(path_str, lines, idx - 1):
                if direct_care_discipline_requires_write_policy(path_str, function_name) and not direct_care_discipline_consumes_write_policy(lines, idx - 1):
                    add(
                        warnings,
                        "reward-direct-care-discipline-disposition",
                        path_str,
                        idx,
                        line,
                        "R5 care reward allowlisted functions must consume CareFactWritePolicy/disposition before calling EconomyRewardDiscipline.",
                    )
                    continue
                continue
            add(
                warnings,
                "reward-direct-care-discipline",
                path_str,
                idx,
                line,
                "Care rewards must enter an audited care-fact chokepoint; do not call EconomyRewardDiscipline.awardCareAction/awardSharedCareAction as a standalone reward.",
            )


def scan_care_fact_disposition_consumption(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    if path_str in {
        "Ohana/Domain/Services/CareEventRecording.swift",
        "Ohana/Domain/Services/CareEventService+RecordingAdapter.swift",
        "Ohana/Domain/Services/CareEventService.swift",
    }:
        return

    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if allowed_line(line):
            continue
        if stripped.startswith("func ") or stripped.startswith("static func "):
            continue
        if not CARE_FACT_CALL_RE.search(line):
            continue

        window = "\n".join(lines[idx - 1:min(len(lines), idx + 50)])
        if "economy-boundary: allow" in window:
            continue
        if CARE_FACT_DISPOSITION_CONSUME_RE.search(window):
            continue

        add(
            warnings,
            "care-fact-disposition-unconsumed",
            path_str,
            idx,
            line,
            "Care-fact chokepoint results must consume didWriteFact/allowsDerivedEffects/disposition before publishing revisions, feedback, plans, reminders, stock changes, or other derived effects.",
        )


def scan_pet_medication_dose_result_consumption(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line) or ".recordDose" not in line:
            continue

        prefix = "\n".join(lines[max(0, idx - 8):idx])
        if "PetMedicationCommandExecutor" not in prefix:
            continue

        window = "\n".join(lines[idx - 1:min(len(lines), idx + 30)])
        if "economy-boundary: allow" in window:
            continue
        if PET_MEDICATION_DOSE_RESULT_CONSUME_RE.search(window):
            continue

        add(
            warnings,
            "pet-medication-dose-result-unconsumed",
            path_str,
            idx,
            line,
            "Pet medication dose command results must consume didRecord before scheduling reminders, publishing success feedback, or refreshing UI state.",
        )


def scan_care_fact_executor_resolution(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    for idx, line in enumerate(lines, start=1):
        if "executorCannotWrite" not in line or not re.search(r"\bfunc\s+executorCannotWrite\s*\(", line):
            continue
        body = "\n".join(lines[idx - 1:min(len(lines), idx + 60)])
        drop_fact_patterns = [
            r"UUID\(uuidString:\s*executorId\)[\s\S]{0,120}?else\s*\{[\s\S]{0,80}?return true",
            r"context\.fetch\(descriptor\)\.first[\s\S]{0,120}?else\s*\{[\s\S]{0,80}?return true",
        ]
        if any(re.search(pattern, body) for pattern in drop_fact_patterns):
            add(
                warnings,
                "care-fact-executor-resolution-drops-fact",
                path_str,
                idx,
                line,
                "Care fact executor write policy must not drop active-pet facts for dirty executor ids; invalid/missing explicit executors should keep the fact path and let rewards use fallback ownership.",
            )


def scan_care_command_result_success_consumption(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line) or not CARE_COMMAND_RESULT_CALL_RE.search(line):
            continue

        function_start = enclosing_function_start(lines, idx - 1)
        pre_start = 0 if function_start is None else function_start + 1
        pre_window = "\n".join(lines[pre_start:idx - 1])
        window = "\n".join(lines[max(0, idx - 12):min(len(lines), idx + 45)])
        if "economy-boundary: allow" in window:
            continue
        if CARE_COMMAND_PRE_RESULT_DERIVED_EFFECT_RE.search(pre_window):
            add(
                warnings,
                "care-command-result-unconsumed",
                path_str,
                idx,
                line,
                "Care command derived effects must not run before the command result is known to have recorded a fact.",
            )
            continue
        if not CARE_COMMAND_SUCCESS_EFFECT_RE.search(window):
            continue
        if CARE_COMMAND_RESULT_CONSUME_RE.search(window):
            continue
        add(
            warnings,
            "care-command-result-unconsumed",
            path_str,
            idx,
            line,
            "Care command results must consume didRecord/didWriteFact/allowsDerivedEffects before UI success feedback, selection/default persistence, reminders, or revision success.",
        )


def scan_secondary_executor_write_policy(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line):
            continue
        if "SharedCareParticipantIDs.normalized" not in line or "sharedExecutorIds" not in line:
            continue

        window = "\n".join(lines[max(0, idx - 12):min(len(lines), idx + 20)])
        if "economy-boundary: allow" in window:
            continue
        if "anyExecutorCannotWrite" in window or "executorIdsCannotWrite" in window:
            add(
                warnings,
                "care-secondary-executor-policy-unchecked",
                path_str,
                idx,
                line,
                "Secondary explicit care executor ids must not gate active-target fact writes; unresolved/non-writable executors are handled by reward-owner fallback, not by dropping the fact.",
            )


def scan_care_derivation_direct_publish(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    if path_str in {
        "Ohana/Domain/Events/DomainRevisionPublishing.swift",
        "Ohana/Domain/Services/CareDerivationExecutor.swift",
    }:
        return
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line) or not CARE_DERIVATION_DIRECT_PUBLISH_RE.search(line):
            continue
        bounds = enclosing_function_bounds(lines, idx - 1)
        if bounds is None:
            continue
        start, end = bounds
        function_block = "\n".join(lines[start:end + 1])
        function_prefix = "\n".join(lines[start:idx])
        if "economy-boundary: allow" in function_block:
            continue
        if not CARE_DERIVATION_CONTEXT_RE.search(function_block):
            continue
        if CARE_DERIVATION_GATE_RE.search(function_prefix):
            continue
        add(
            warnings,
            "care-derivation-direct-publish",
            path_str,
            idx,
            line,
            "Care command/view code that writes care facts must publish revision/no-op derived effects through CareDerivationExecutor in the same function, not by direct revision/no-op calls.",
        )


def scan_pet_expense_ledger_boundary(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    if path_str in PET_EXPENSE_IMPORT_BOUNDARY_ALLOWLIST:
        return

    for idx, line in enumerate(lines, start=1):
        if allowed_line(line) or not PET_EXPENSE_LOG_CONSTRUCTOR_RE.search(line):
            continue
        bounds = enclosing_function_bounds(lines, idx - 1)
        if bounds is None:
            continue
        start, end = bounds
        function_block = "\n".join(lines[start:end + 1])
        if "economy-boundary: allow" in function_block:
            continue
        if not PET_EXPENSE_CONTEXT_INSERT_RE.search(function_block):
            continue
        if PET_EXPENSE_LEDGER_MARKER_RE.search(function_block):
            continue
        if same_file_expense_ledger_callee(lines, function_block, start):
            continue
        function_name = enclosing_function_name(lines, idx - 1)
        if function_name and same_file_expense_ledger_caller(lines, function_name, start):
            continue
        add(
            warnings,
            "pet-expense-ledger-boundary",
            path_str,
            idx,
            line,
            "PetExpenseLog business writes must record a same-boundary CareLedgerEvent or enter ExpenseCommandService.recordPetExpense/shared expense recording.",
        )


def scan_physical_deletion_wallet_reconciliation(path: pathlib.Path, lines: list[str], warnings: list[WarningItem]) -> None:
    path_str = rel(path)
    if path_str != "Ohana/Domain/Services/PhysicalDeletionService.swift":
        return

    content = "\n".join(lines)
    if "CoconutLedgerEntry.self" not in content:
        return
    if "reconcileWalletAfterEconomyDeletion" in content and "saveChanges: false" in content:
        return

    add(
        warnings,
        "physical-deletion-wallet-replay",
        path_str,
        1,
        "PhysicalDeletionService",
        "Physical deletion that removes CoconutLedgerEntry rows must replay surviving wallet balances before the outer save.",
    )


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
        re.compile(r"\b(?:passedAwayDate|hasPassedAway|isReadOnly|readOnly)\b"),
        re.compile(r"\b(?:passedAwayDate|hasPassedAway|readOnly|isReadOnly)\b"),
        "Deceased/read-only UI checks must be backed by command/service lifecycle guards.",
    ),
]


def scan_service_gate_coverage(files: list[pathlib.Path], warnings: list[WarningItem]) -> None:
    occurrences: dict[str, list[tuple[str, int, str]]] = {rule: [] for rule, _, _, _ in GATE_RULES}
    hard_gate_seen: dict[str, bool] = {rule: False for rule, _, _, _ in GATE_RULES}
    service_files = files
    if any(rel(path).startswith("Ohana/") for path in files):
        service_files = sorted((ROOT / "Ohana").rglob("*.swift"))

    for path in service_files:
        path_str = rel(path)
        if not path.is_file():
            continue
        lines = read_lines(path)
        content = "\n".join(line for line in lines if "economy-boundary: allow" not in line)
        for rule, view_re, service_re, _ in GATE_RULES:
            if is_service_path(path_str) and service_re.search(content):
                hard_gate_seen[rule] = True

    for path in files:
        path_str = rel(path)
        if not path.is_file():
            continue
        lines = read_lines(path)
        for rule, view_re, _, _ in GATE_RULES:
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
        scan_direct_reward_chokepoint(path, lines, warnings)
        scan_direct_care_discipline_chokepoint(path, lines, warnings)
        scan_care_fact_disposition_consumption(path, lines, warnings)
        scan_pet_medication_dose_result_consumption(path, lines, warnings)
        scan_care_fact_executor_resolution(path, lines, warnings)
        scan_care_command_result_success_consumption(path, lines, warnings)
        scan_secondary_executor_write_policy(path, lines, warnings)
        scan_care_derivation_direct_publish(path, lines, warnings)
        scan_pet_expense_ledger_boundary(path, lines, warnings)
        scan_physical_deletion_wallet_reconciliation(path, lines, warnings)
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
