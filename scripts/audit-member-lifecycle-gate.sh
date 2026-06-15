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
FUNC_DECL_RE = re.compile(
    r"\b(?:(?P<privacy>private|fileprivate)\s+)?(?:static\s+)?func\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\("
)
MEMBER_PARAM_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\s*:\s*(?:Pet|Human)\??\b")
WRITE_EFFECT_RE = re.compile(
    r"\bcontext\.(?:insert|delete|safeSave)\b"
    r"|\bcenter\.(?:add|removePendingNotificationRequests)\b"
    r"|CloudSyncMutationRecorder\.mark(?:Modified|Deleted)"
    r"|\b(?:pet|human)\.[A-Za-z_][A-Za-z0-9_]*\s*="
    r"|RainbowBridgeService\(\)\.(?:markPassedAway|undoPassedAway)"
    r"|CarePlanCalendarSync\.(?:suppressDefaultPlan|removeCalendarPlan|removeActiveCalendarPlans|ensureDefaultPlans|reconcileDefaultPlanOverrides|sync[A-Za-z0-9_]+)"
    r"|\b(?:upsert|upsertWithSingleReminder|removeCalendarPlan|removeActiveCalendarPlans)\("
    r"|WaterPlanWriter\.(?:replacePlan|deletePlan|deactivateReminderOperations|ensureUpcomingReminders)"
    r"|FeedingPlanWriter\.(?:replacePlan|deletePlan|deactivateManualReminderOperations|clearFeedModePlans|ensureUpcomingManualReminders|saveFoodPurchase|correctFoodStock|rebuildFoodStockReminder)"
    r"|OhanaNotifications\.current\.cancel"
)
GATE_CONSUMPTION_RE = re.compile(
    r"MemberLifecycleGate\.disposition"
    r"|MemberWritePolicy\.disposition"
    r"|CareFactWritePolicy\.disposition"
    r"|EconomyWalletWritePolicy\.canWrite"
    r"|SharedPetTargetResolver\.normalizedTargets"
    r"|MemberLifecycleActiveScheduleResolver\.reminderTargetsActiveMember"
    r"|canWriteActiveFeedData"
    r"|canWriteActiveCarePlan"
    r"|canWriteActiveWaterPlan"
    r"|canWriteActiveWaterData"
    r"|canWriteCollaboration"
    r"|canWriteRelatedPet"
    r"|reminderTargetsWritableMember"
    r"|pet\.canWriteHealthFacts"
    r"|HumanPasscodeService\.(?:setPasscode|changePasscode|removePasscode|clearPasscode|verify)"
    r"|CarePlanCalendarSync\.(?:suppressDefaultPlan|removeCalendarPlan|removeActiveCalendarPlans|ensureDefaultPlans|reconcileDefaultPlanOverrides|sync[A-Za-z0-9_]+)"
    r"|WaterPlanWriter\.(?:replacePlan|deletePlan|deactivateReminderOperations|ensureUpcomingReminders)"
    r"|FeedingPlanWriter\.(?:replacePlan|deletePlan|deactivateManualReminderOperations|clearFeedModePlans|ensureUpcomingManualReminders|saveFoodPurchase|correctFoodStock|rebuildFoodStockReminder|rebuildFoodStockReminders)"
    r"|MemberLifecycleActiveScheduleCleanup"
    r"|PetCareTrackingCommandService\.deleteCareLog"
    r"|PetPottyCommandService\.deletePottyLog"
    r"|PetHygieneCommandService\.delete"
    r"|CatCareCommandService\.undo"
)
DOMAIN_OWNERSHIP_RESOLVER_ALLOWLIST = {
    "Ohana/Domain/Services/MemberLifecycleActiveScheduleResolver.swift",
}
DOMAIN_EXACT_EVENT_MATCHER_FUNCTIONS = {
    "Ohana/Domain/Services/CarePlanCalendarSync.swift": {
        "existingEvent",
        "isDefaultGeneratedCalendarPlan",
        "shouldShowModeScopedPlanOccurrence",
        "waterMaintenanceKind",
        "isWaterMaintenancePlan",
        "waterMaintenancePlanEvents",
        "hasCustomFeedPlan",
        "hasCustomWaterPlan",
        "removeLegacyDefaultPlanEvents",
        "upsert",
        "upsertWithSingleReminder",
    },
    "Ohana/Domain/Services/CalendarTaskCompletionSyncService.swift": {
        "deleteCalendarGeneratedRecords",
        "deleteCalendarGeneratedFactOnlyRecords",
        "calendarLedgerEntries",
        "calendarGeneratedFactOnlyRecords",
    },
    "Ohana/Domain/Services/PetMedicationDoseLogging.swift": {
        "doseCount",
        "logDose",
    },
    "Ohana/Domain/Services/PetActivityRecordCleanupService.swift": {
        "deletePetActivityRecords",
    },
    "Ohana/Domain/Services/StartupFeedAutoLogMaintenanceService.swift": {
        "run",
    },
    "Ohana/Domain/Services/QuickActionReminderCompletionSyncService.swift": {
        "markMatchingReminderCompleted",
    },
}
DOMAIN_MEMBER_OWNER_TYPE_RE = re.compile(
    r"relatedEntityType\s*(?:==|!=)\s*(?:EntityKind\.(?:pet|human)\.rawValue|[\"'](?:pet|Pet|human|Human|human_note|pet_insurance)[\"'])"
)
DOMAIN_MEMBER_OWNER_ID_RE = re.compile(
    r"relatedEntityId\s*(?:==|!=)|idsMatch\(\s*event\.relatedEntityId\b|\bid\.uuidString\s*==\s*event\.relatedEntityId\b"
)
DOMAIN_MEMBER_ASSIGNEE_RE = re.compile(
    r"event\.assigneeId\s*==|idsMatch\(\s*event\.assigneeId\b"
)
EFFECT_SUBJECT_RESOLUTION_RE = re.compile(
    r"DomainSubjectResolver\.resolve"
    r"|DomainSubjectResolutionRequest"
    r"|DomainResolvedSubjectKey"
    r"|DomainEntityLinkRegistry\."
    r"|MemberLifecycleActiveScheduleResolver\."
)
EFFECT_EMISSION_RE = re.compile(
    r"\baffectedEntityIDs\b"
    r"|\baffected\.(?:insert|formUnion)\b"
    r"|\bpublish[A-Za-z0-9_]*\s*\("
    r"|publishDomainMutation\s*\("
    r"|DomainMutationResult\s*\("
    r"|CareWriteOutcome\.RevisionPayload\s*\("
    r"|OhanaNotifications\.current\."
    r"|notificationRoutes\.publishRouteEvent\s*\("
    r"|AppRouteNotificationEvent\s*\("
    r"|FocusHomeReminderDestination"
    r"|CareLedgerService\s*\("
    r"|\bcareLedger\.record\s*\("
)
RAW_EFFECT_OWNER_TYPE_RE = re.compile(
    r"\b(?:event\.)?relatedEntityType\s*(?:==|!=)"
)
RAW_EFFECT_OWNER_ID_RE = re.compile(
    r"\b(?:event\.)?relatedEntityId\s*(?:==|!=)"
    r"|UUID\s*\(\s*uuidString:\s*(?:event\.)?relatedEntityId\b"
    r"|idsMatch\(\s*(?:event\.)?relatedEntityId\b"
)
RAW_EFFECT_ASSIGNEE_RE = re.compile(
    r"\b(?:event\.)?assigneeId\s*(?:==|!=)"
    r"|idsMatch\(\s*(?:event\.)?assigneeId\b"
)
FEATURE_TAXONOMY_STRING_RE = re.compile(
    r'"(?:pet_food_stock|pet_auto_feeder|pet_water_plan|pet_insurance|'
    r'pet_medication_plan|pet_medication|human_medication|human_note)"'
)
FEATURE_TAXONOMY_ALLOWLIST = {
    "Ohana/Domain/Services/DomainEntityLinkRegistry.swift",
}
DIRECT_SCHEDULE_CONSTRUCTOR_RE = re.compile(r"\b(?:Event|Reminder)\s*\(")
DIRECT_SCHEDULE_INSERT_RE = re.compile(r"\b(?:context|modelContext)\.insert\s*\(")
AUTHORIZED_SCHEDULE_WRITER_RE = re.compile(
    r"DomainScheduleWriteAuthorizer\.authorizeCreate|DomainScheduleWriter\.createEvent"
)
REHYDRATE_ENTRY_PATHS = {
    "Ohana/Domain/Services/DataBackupManager.swift",
    "Ohana/Domain/Services/DataBackupManager+Decode.swift",
    "Ohana/Domain/Services/DataBackupManager+Encode.swift",
    "Ohana/Domain/Services/CloudSyncRecordApplier.swift",
}
REHYDRATE_ENTRY_FUNCTION_RE = re.compile(
    r"^(?:apply|apply[A-Za-z0-9_]*|decode[A-Za-z0-9_]*|insertLegacy[A-Za-z0-9_]*|upsertState)$"
)
REHYDRATE_DIRECT_INSERT_RE = re.compile(r"\b(?:context|modelContext)\.insert\s*\(")
REHYDRATE_DIRECT_MODEL_CONSTRUCTOR_RE = re.compile(
    r"\b(?:"
    r"Pet|Human|Household|Plant|WaterLog|WishlistItem|"
    r"CoconutAccount|CoconutLedgerEntry|FamilyCollaborationTask|CoconutExchangeRequest|"
    r"OasisUpgradeCoconut|OasisElectronicPet|OasisCritterFragmentBalance|OasisUnlock|OasisCritterActionLog|"
    r"GachaOwnedItem|GachaDrawLog|ShopPurchaseRecord|CloudSyncRecordState"
    r")\s*\("
)
REHYDRATE_DISPOSITION_TYPE_RE = re.compile(r"\bDomainRehydrateDisposition[A-Za-z0-9_]*\b")
REHYDRATE_QUARANTINE_DENIAL_RE = re.compile(
    r"case\s+\.quarantined(?:\([^)]*\))?\s*:\s*\n\s*false"
)
REHYDRATE_HISTORY_SCHEDULE_RE = re.compile(r"\brequiresHistoryOnlySchedule\b")
ALLOWED_RAW_SCHEDULE_CONSTRUCTOR_FUNCTIONS = {
    "Ohana/Domain/Services/DomainScheduleWriteKernel.swift": {
        "makeUnpersistedReminder",
        "constructEvent",
        "createReminder",
        "createReminders",
    },
    "Ohana/Domain/Services/DomainRehydrateWriteKernel.swift": {
        "upsertEvent",
        "upsertReminder",
    },
}
LEGACY_DIRECT_SCHEDULE_WRITER_FUNCTIONS = {}
CRITICAL_GATE_FUNCTIONS = {
    "Ohana/Domain/Services/CarePlanCalendarSync.swift": {
        "reconcileDefaultPlanOverrides",
        "ensureDefaultPlans",
        "syncWaterChangePlan",
        "syncFilterPlan",
        "syncLitterFullChangePlan",
        "syncScoopPlan",
        "syncPlayPlan",
        "upsert",
        "upsertWithSingleReminder",
    },
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
    "Ohana/Features/Medication/MedicationReminderService.swift": {
        "scheduleMedicationReminders",
        "scheduleHumanMedicationReminders",
    },
    "Ohana/Features/QuickCare/WaterManagementSupport.swift": {
        "replacePlan",
        "ensureUpcomingReminders",
    },
    "Ohana/Features/PetCare/PetCareCommands.swift": {"deleteCareLog", "deletePottyLog"},
    "Ohana/Features/CatCare/CatCareCommands.swift": {"undo"},
    "Ohana/Features/Hygiene/PetHygieneCommands.swift": {"delete"},
}


def function_blocks(lines: list[str]) -> list[tuple[str, int, str, bool]]:
    blocks: list[tuple[str, int, str, bool]] = []
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
        blocks.append((
            match.group("name"),
            start + 1,
            "\n".join(lines[start : end + 1]),
            match.group("privacy") is not None,
        ))
        idx = max(end + 1, idx + 1)
    return blocks


def requires_lifecycle_gate(path: str, func_name: str, body: str, is_private: bool) -> bool:
    if func_name in CRITICAL_GATE_FUNCTIONS.get(path, set()):
        return True
    if path.startswith("scripts/tests/fixtures/") and MEMBER_PARAM_RE.search(body) and WRITE_EFFECT_RE.search(body):
        return True
    if is_private:
        return False
    if MEMBER_PARAM_RE.search(body) and WRITE_EFFECT_RE.search(body):
        return True
    return False


warnings: list[WarningItem] = []
domain_ownership_warnings: list[WarningItem] = []
effect_subject_warnings: list[WarningItem] = []
feature_taxonomy_warnings: list[WarningItem] = []
rehydrate_bypass_warnings: list[WarningItem] = []
files = collect_files()
for path in files:
    path_str = rel(path)
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    if path_str not in FEATURE_TAXONOMY_ALLOWLIST:
        for idx, line in enumerate(lines, start=1):
            stripped = line.lstrip()
            if allowed_line(line) or stripped.startswith("//") or stripped.startswith("///"):
                continue
            if FEATURE_TAXONOMY_STRING_RE.search(line):
                feature_taxonomy_warnings.append(
                    WarningItem(
                        path_str,
                        idx,
                        line.strip(),
                    )
                )
    checks_rehydrate_bypass = path_str in REHYDRATE_ENTRY_PATHS or (
        targets and path_str.startswith("scripts/tests/fixtures/")
    )
    if checks_rehydrate_bypass:
        for func_name, start_line, body, _ in function_blocks(lines):
            if "member-lifecycle-gate: allow" in body:
                continue
            if not REHYDRATE_ENTRY_FUNCTION_RE.search(func_name):
                continue
            if REHYDRATE_DIRECT_INSERT_RE.search(body) or REHYDRATE_DIRECT_MODEL_CONSTRUCTOR_RE.search(body):
                rehydrate_bypass_warnings.append(
                    WarningItem(
                        path_str,
                        start_line,
                        f"func {func_name} constructs or inserts restore/apply models outside a rehydrate writer",
                    )
                )
    text = "\n".join(lines)
    if REHYDRATE_DISPOSITION_TYPE_RE.search(text):
        if ".quarantined" in text and not REHYDRATE_QUARANTINE_DENIAL_RE.search(text):
            rehydrate_bypass_warnings.append(
                WarningItem(
                    path_str,
                    1,
                    "DomainRehydrateDisposition.quarantined must deny active persistence instead of acting as metadata",
                )
            )
        if ".legacyHistoryOnly" in text and not REHYDRATE_HISTORY_SCHEDULE_RE.search(text):
            rehydrate_bypass_warnings.append(
                WarningItem(
                    path_str,
                    1,
                    "DomainRehydrateDisposition.legacyHistoryOnly must be consumed by schedule writers as non-actionable history",
                )
            )

    for func_name, start_line, body, _ in function_blocks(lines):
        if "member-lifecycle-gate: allow" in body:
            continue
        if (
            DIRECT_SCHEDULE_CONSTRUCTOR_RE.search(body)
            and func_name not in ALLOWED_RAW_SCHEDULE_CONSTRUCTOR_FUNCTIONS.get(path_str, set())
        ):
            warnings.append(
                WarningItem(
                    path_str,
                    start_line,
                    f"func {func_name} directly constructs raw Event/Reminder outside the schedule writer or rehydrate boundary",
                )
            )

    checks_domain_ownership = (
        path_str.startswith("Ohana/Domain/")
        or (targets and path_str.startswith("scripts/tests/fixtures/"))
    )
    if checks_domain_ownership and path_str not in DOMAIN_OWNERSHIP_RESOLVER_ALLOWLIST:
        for func_name, start_line, body, _ in function_blocks(lines):
            if func_name in DOMAIN_EXACT_EVENT_MATCHER_FUNCTIONS.get(path_str, set()):
                continue
            if "member-lifecycle-gate: allow" in body:
                continue
            if (
                "MemberLifecycleActiveScheduleResolver." not in body
                and DOMAIN_MEMBER_OWNER_TYPE_RE.search(body)
                and DOMAIN_MEMBER_OWNER_ID_RE.search(body)
            ):
                domain_ownership_warnings.append(
                    WarningItem(
                        path_str,
                        start_line,
                        f"func {func_name} hand-rolls Event/Reminder -> member ownership from relatedEntityType/relatedEntityId",
                    )
                )
            if "MemberLifecycleActiveScheduleResolver." not in body and DOMAIN_MEMBER_ASSIGNEE_RE.search(body):
                domain_ownership_warnings.append(
                    WarningItem(
                        path_str,
                        start_line,
                        f"func {func_name} hand-rolls human ownership from event.assigneeId",
                    )
                )

    checks_effect_subject = (
        path_str.startswith("Ohana/Domain/")
        or path_str.startswith("Ohana/Features/")
        or (targets and path_str.startswith("scripts/tests/fixtures/"))
    )
    if checks_effect_subject:
        for func_name, start_line, body, _ in function_blocks(lines):
            if "member-lifecycle-gate: allow" in body:
                continue
            if EFFECT_SUBJECT_RESOLUTION_RE.search(body):
                continue
            if not EFFECT_EMISSION_RE.search(body):
                continue
            raw_owner_guess = RAW_EFFECT_OWNER_TYPE_RE.search(body) and RAW_EFFECT_OWNER_ID_RE.search(body)
            raw_assignee_guess = RAW_EFFECT_ASSIGNEE_RE.search(body)
            if raw_owner_guess or raw_assignee_guess:
                effect_subject_warnings.append(
                    WarningItem(
                        path_str,
                        start_line,
                        f"func {func_name} emits effects from raw relatedEntityType/relatedEntityId or assigneeId",
                    )
                )

    if allowed_path(path_str) or not is_write_path(path_str):
        continue
    for idx, line in enumerate(lines, start=1):
        if allowed_line(line):
            continue
        if DIRECT_GATE_RE.search(line):
            warnings.append(WarningItem(path_str, idx, line.strip()))
    for func_name, start_line, body, is_private in function_blocks(lines):
        if "member-lifecycle-gate: allow" in body:
            continue
        if (
            DIRECT_SCHEDULE_CONSTRUCTOR_RE.search(body)
            and DIRECT_SCHEDULE_INSERT_RE.search(body)
            and not AUTHORIZED_SCHEDULE_WRITER_RE.search(body)
            and func_name not in LEGACY_DIRECT_SCHEDULE_WRITER_FUNCTIONS.get(path_str, set())
        ):
            warnings.append(
                WarningItem(
                    path_str,
                    start_line,
                    f"func {func_name} directly constructs/inserts Event or Reminder instead of using DomainScheduleWriter",
                )
            )
        if requires_lifecycle_gate(path_str, func_name, body, is_private) and not GATE_CONSUMPTION_RE.search(body):
            warnings.append(
                WarningItem(
                    path_str,
                    start_line,
                    f"func {func_name} writes member-scoped data without MemberLifecycleGate/MemberWritePolicy",
                )
            )

for item in domain_ownership_warnings:
    print(f"[member-lifecycle-domain-ownership-matcher] {item.path}:{item.line}: Domain Event/Reminder -> Pet/Human ownership must use MemberLifecycleActiveScheduleResolver.")
    print(f"    {item.snippet}")

for item in rehydrate_bypass_warnings:
    if "DomainRehydrateDisposition" in item.snippet:
        print(f"[member-lifecycle-rehydrate-disposition-unconsumed] {item.path}:{item.line}: rehydrate disposition cases must be consumed as hard persistence/history policy, not metadata.")
    else:
        print(f"[member-lifecycle-rehydrate-bypass] {item.path}:{item.line}: restore/sync/apply entrypoints must submit snapshots to a rehydrate writer instead of constructing or inserting persistence models directly.")
    print(f"    {item.snippet}")

for item in effect_subject_warnings:
    print(f"[member-lifecycle-raw-effect-subject] {item.path}:{item.line}: effects, revisions, notifications, routes, and ledgers must consume typed DomainSubjectResolution/DomainResolvedSubjectKey instead of guessing from raw relatedEntity/assignee fields.")
    print(f"    {item.snippet}")

for item in feature_taxonomy_warnings:
    print(f"[member-lifecycle-feature-taxonomy-string] {item.path}:{item.line}: persisted member schedule link taxonomy strings must live in DomainEntityLinkRegistry and be referenced through typed registry constants.")
    print(f"    {item.snippet}")

for item in warnings:
    rule = "member-lifecycle-direct-write-gate"
    message = "write paths must use MemberLifecycleGate/MemberWritePolicy instead of hand-rolled deceased-member gates."
    if item.snippet.startswith("func ") and "without MemberLifecycleGate" in item.snippet:
        rule = "member-lifecycle-missing-disposition"
        message = "member-scoped write paths must consume MemberLifecycleGate/MemberWritePolicy before mutating."
    elif item.snippet.startswith("func ") and "DomainScheduleWriter" in item.snippet:
        rule = "member-lifecycle-direct-schedule-writer"
        message = "member-scoped Event/Reminder writes must go through DomainScheduleWriteAuthorizer and DomainScheduleWriter."
    elif item.snippet.startswith("func ") and "raw Event/Reminder" in item.snippet:
        rule = "member-lifecycle-raw-schedule-constructor"
        message = "raw Event/Reminder construction is allowed only inside DomainScheduleWriter or explicit rehydrate/apply boundaries."
    print(f"[{rule}] {item.path}:{item.line}: {message}")
    print(f"    {item.snippet}")

total_warnings = len(warnings) + len(domain_ownership_warnings) + len(effect_subject_warnings) + len(feature_taxonomy_warnings) + len(rehydrate_bypass_warnings)
print(f"member lifecycle gate audit: scanned {len(files)} file(s); warnings={total_warnings}")
if total_warnings and strict:
    sys.exit(1)
PY
