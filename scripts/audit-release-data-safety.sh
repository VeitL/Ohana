#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

update_save_baseline=0

usage() {
  cat <<'USAGE'
Usage: scripts/audit-release-data-safety.sh [--update-save-baseline]

Checks first-release data safety invariants. Existing bare safeSave() calls and
ambiguous no-argument safeSaveResult() calls are
ratcheted in docs/governance/manifests/swiftdata-save-failure-baseline.json;
new silent save-discard sites fail the audit.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-save-baseline)
      update_save_baseline=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required." >&2
  exit 2
fi

data_backup="Ohana/Domain/Services/DataBackupManager.swift"
data_backup_dtos="Ohana/Domain/Services/DataBackupDTOs.swift"
automatic_backup="Ohana/Domain/Services/AutomaticBackupService.swift"
physical_deletion="Ohana/Domain/Services/PhysicalDeletionService.swift"
data_backup_files=(
  "Ohana/Domain/Services/DataBackupManager.swift"
  "Ohana/Domain/Services/DataBackupManager+Encode.swift"
  "Ohana/Domain/Services/DataBackupManager+Decode.swift"
  "Ohana/Domain/Services/DataBackupMediaPackage.swift"
  "Ohana/Domain/Services/DataBackupDTOs.swift"
)
shared_container="Ohana/Models/SharedModelContainer.swift"
save_failure_baseline="docs/governance/manifests/swiftdata-save-failure-baseline.json"

failures=()

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -q --pcre2 "$pattern" "$file"; then
    failures+=("$message")
  fi
}

require_backup_pattern() {
  local pattern="$1"
  local message="$2"
  if ! rg -q --pcre2 "$pattern" "${data_backup_files[@]}"; then
    failures+=("$message")
  fi
}

require_section_pattern() {
  local file="$1"
  local start="$2"
  local end="$3"
  local pattern="$4"
  local message="$5"
  if ! awk -v start="$start" -v end="$end" '
    $0 ~ start { flag = 1 }
    $0 ~ end { flag = 0 }
    flag { print }
  ' "$file" | rg -q --pcre2 "$pattern"; then
    failures+=("$message")
  fi
}

reject_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -q --pcre2 "$pattern" "$file"; then
    failures+=("$message")
  fi
}

reject_backup_pattern() {
  local pattern="$1"
  local message="$2"
  if rg -q --pcre2 "$pattern" "${data_backup_files[@]}"; then
    failures+=("$message")
  fi
}

# Every persisted SwiftData model must either have a backup DTO contract or a
# deliberate exemption. This prevents new @Model types from silently falling out
# of user-owned export/restore coverage.
backup_contract_entries=(
  "CareLedgerEvent|struct CareLedgerEventBackup"
  "CloudSyncRecordState|EXEMPT:local CloudKit sync metadata, rebuilt by sync runtime"
  "CoconutAccount|struct CoconutAccountBackup"
  "CoconutExchangeRequest|struct CoconutExchangeRequestBackup"
  "CoconutLedgerEntry|struct CoconutLedgerEntryBackup"
  "EconomyBudgetUsageEvent|EXEMPT:derived daily budget guardrail state, not user-authored history"
  "Event|struct EventBackup"
  "FamilyCollaborationTask|struct FamilyCollaborationTaskBackup"
  "HeatCycleLog|struct HeatCycleLogBackup"
  "Household|struct HouseholdBackup"
  "Human|struct HumanBackup"
  "HumanHealthMetricLog|struct HumanHealthMetricLogBackup"
  "HumanHealthReport|struct HumanHealthReportBackup"
  "HumanMedication|struct HumanMedicationBackup"
  "HumanMedicationLog|struct HumanMedicationLogBackup"
  "HumanWeightLog|struct HumanWeightLogBackup"
  "HumanWorkoutLog|struct HumanWorkoutLogBackup"
  "InsuranceClaim|struct InsuranceClaimBackup"
  "Pet|struct PetBackup"
  "PetCareLog|struct PetCareLogBackup"
  "PetDocument|struct PetDocumentBackup"
  "PetDocumentAttachment|struct PetDocumentAttachmentBackup"
  "PetExpenseLog|struct PetExpenseLogBackup"
  "PetFoodRecord|struct PetFoodRecordBackup"
  "PetHealthLog|struct PetHealthLogBackup"
  "PetHygieneLog|struct PetHygieneLogBackup"
  "PetInsurance|struct PetInsuranceBackup"
  "PetMedication|struct PetMedicationBackup"
  "PetMilestone|struct PetMilestoneBackup"
  "PetPhotoLog|struct PetPhotoLogBackup"
  "PetPottyLog|struct PetPottyLogBackup"
  "PetRelationship|EXEMPT:legacy relationship model kept for schema compatibility until cleanup"
  "PetWalkLog|struct PetWalkLogBackup"
  "PetWeightLog|struct PetWeightLogBackup"
  "Plant|struct PlantBackup"
  "PlantCareLog|struct PlantCareLogBackup"
  "RecycleBinBatch|EXEMPT:short-lived recycle-bin grouping metadata, not durable user content"
  "Reminder|struct ReminderBackup"
  "SharedCareSession|struct SharedCareSessionBackup"
  "ShopPurchaseRecord|struct ShopPurchaseRecordBackup"
  "SymptomLog|struct SymptomLogBackup"
  "WaterLog|struct WaterLogBackup"
  "WishlistItem|struct WishlistItemBackup"
)

backup_contract_has_model() {
  local needle="$1"
  local entry model pattern
  for entry in "${backup_contract_entries[@]}"; do
    IFS='|' read -r model pattern <<< "$entry"
    if [[ "$model" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

while IFS= read -r model; do
  if ! backup_contract_has_model "$model"; then
    failures+=("SwiftData model $model must have a backup DTO contract or explicit audit exemption.")
  fi
done < <(awk '
  /^[[:space:]]*@Model/ { pending = 1; next }
  pending && /^[[:space:]]*final[[:space:]]+class[[:space:]]+/ {
    print $3
    pending = 0
  }
' Ohana/Models/*.swift | sort -u)

for entry in "${backup_contract_entries[@]}"; do
  IFS='|' read -r model pattern <<< "$entry"
  if [[ "$pattern" == EXEMPT:* ]]; then
    continue
  fi
  require_pattern "$data_backup_dtos" "$pattern" \
    "SwiftData model $model should have a matching backup DTO, or a documented exemption if intentionally excluded."
done

require_pattern "$shared_container" 'Schema\(ArkSchemaV85\.models\)' \
  "SharedModelContainer should open the current ArkSchemaV85 model set."

require_pattern "$data_backup_dtos" 'var schemaVersion: Int = 30' \
  "OhanaBackup.schemaVersion should be 30 after externalizing backup media."

require_pattern "$data_backup" 'guard backup\.schemaVersion <= 30' \
  "DataBackupManager import guard should allow backup schemaVersion 30."

require_pattern "$data_backup_dtos" 'struct BackupMediaPackageInfo' \
  "OhanaBackup should describe the out-of-line backup media package."

require_pattern "$data_backup_dtos" 'struct BackupMediaReference' \
  "Media-bearing backup DTOs should be able to reference package media instead of inline base64."

require_backup_pattern 'DataBackupMediaPackageWriter' \
  "DataBackupManager should export media through the package writer instead of a single inline JSON blob."

require_backup_pattern 'DataBackupMediaPackageReader' \
  "DataBackupManager should import package media references."

require_backup_pattern 'manifestFileName = "manifest\.json"' \
  "DataBackupManager should keep a manifest file in backup packages."

require_backup_pattern 'mediaDirectoryName = "media"' \
  "DataBackupManager should keep out-of-line media in a media directory."

require_pattern "$automatic_backup" 'DataBackupManager\.packageFileExtension' \
  "Automatic backups should write the same .ohanabackup package format as manual exports."

require_pattern "$automatic_backup" 'func exportBackupPackage\(container: ModelContainer\) async throws -> URL' \
  "Automatic backup exporting should return a package URL, not a single in-memory JSON blob."

require_pattern "$automatic_backup" 'DataBackupManager\(\)\.exportJSON\(' \
  "Live automatic backups should use DataBackupManager package export."

require_pattern "$automatic_backup" 'scope: \.automaticICloudDriveRestricted' \
  "Live automatic backups must use the restricted iCloud Drive export scope."

require_pattern "$automatic_backup" 'writeAutomaticBackup\(packageURL: URL, now: Date\)' \
  "Automatic backup file storage should receive and copy a backup package URL."

reject_pattern "$physical_deletion" 'deleteRows\(fetchAll\(CoconutLedgerEntry\.self' \
  "PhysicalDeletionService must preserve append-only CoconutLedgerEntry rows during member deletion."

require_pattern "$physical_deletion" 'retireWalletAccounts\(ownerKind:' \
  "PhysicalDeletionService should retire wallet accounts instead of deleting economy audit rows."

require_pattern "$data_backup_dtos" 'struct PlantReminderPreferencesBackup' \
  "Plant reminder preferences should be represented in backup app state."

require_pattern "$data_backup" 'applyPlantReminderPreferences' \
  "DataBackupManager should restore plant reminder preferences."

require_pattern "$data_backup" 'PlantBackupRestoreReconcileService\.rebuildPlantCarePlans' \
  "DataBackupManager should rebuild plant care schedules after restoring plant data."

require_section_pattern "$data_backup_dtos" 'struct HumanBackup' 'struct EventBackup' 'var passedAwayDate: String\?' \
  "HumanBackup should include passedAwayDate so human memorial state survives backup/restore."

require_backup_pattern 'passedAwayDate: d\(h\.passedAwayDate\)' \
  "encodeHuman should export Human.passedAwayDate."

require_backup_pattern 'passedAwayDate: parseDate\(dto\.passedAwayDate\)' \
  "decodeHumanSnapshot should carry Human.passedAwayDate into the rehydrate snapshot."

require_pattern "Ohana/Domain/Services/DomainGeneralRehydrateWriteKernel.swift" 'human\.passedAwayDate = snapshot\.passedAwayDate' \
  "DomainGeneralRehydrateWriter should restore Human.passedAwayDate."

require_section_pattern "$data_backup_dtos" 'struct PlantBackup' 'struct PlantCareLogBackup' 'var archivedAt: String\?' \
  "PlantBackup should include archivedAt so plant archive lifecycle survives backup/restore."

require_backup_pattern 'archivedAt: d\(p\.archivedAt\)' \
  "encodePlant should export Plant.archivedAt."

require_backup_pattern 'archivedAt: dto\.archivedAt\.flatMap \{ iso\.date\(from: \$0\) \}' \
  "decodePlantSnapshot should carry Plant.archivedAt into the rehydrate snapshot."

require_pattern "Ohana/Domain/Services/DomainGeneralRehydrateWriteKernel.swift" 'plant\.archivedAt = snapshot\.archivedAt' \
  "DomainGeneralRehydrateWriter should restore Plant.archivedAt."

require_pattern "$data_backup_dtos" 'struct HumanHealthMetricLogBackup: Codable' \
  "DataBackupManager should define HumanHealthMetricLogBackup."

require_pattern "$data_backup_dtos" 'var humanHealthMetricLogs: \[HumanHealthMetricLogBackup\]\?' \
  "OhanaBackup should include humanHealthMetricLogs."

require_backup_pattern 'FetchDescriptor<HumanHealthMetricLog>' \
  "DataBackupManager should fetch HumanHealthMetricLog during backup/import."

require_backup_pattern 'humanHealthMetricLogs: humanHealthMetricLogs\.map\(encodeHumanHealthMetricLog\)' \
  "buildBackup should encode human health metric logs."

require_backup_pattern 'insertHumanHealthMetricLogIfNeeded' \
  "applyBackup should import human health metric logs through the member-content rehydrate writer."

require_backup_pattern 'decodeHumanHealthMetricLogSnapshot\(dto\)' \
  "applyBackup should decode human health metric logs into rehydrate snapshots."

require_pattern "$data_backup_dtos" 'struct HumanHealthReportBackup: Codable' \
  "DataBackupManager should define HumanHealthReportBackup."

require_pattern "$data_backup_dtos" 'var humanHealthReports: \[HumanHealthReportBackup\]\?' \
  "OhanaBackup should include humanHealthReports."

require_backup_pattern 'FetchDescriptor<HumanHealthReport>' \
  "DataBackupManager should fetch HumanHealthReport during backup/import."

require_backup_pattern 'humanHealthReports: humanHealthReports\.map\(encodeHumanHealthReport\)' \
  "buildBackup should encode human health reports."

require_backup_pattern 'insertHumanHealthReportIfNeeded' \
  "applyBackup should import human health reports through the member-content rehydrate writer."

require_backup_pattern 'decodeHumanHealthReportSnapshot\(dto\)' \
  "applyBackup should decode human health reports into rehydrate snapshots."

require_pattern "$data_backup_dtos" 'var coconutAccounts: \[CoconutAccountBackup\]\?' \
  "OhanaBackup should include V58 CoconutAccount backups."

require_pattern "$data_backup_dtos" 'var coconutLedgerEntries: \[CoconutLedgerEntryBackup\]\?' \
  "OhanaBackup should include V58 CoconutLedgerEntry backups."

require_backup_pattern 'coconutAccounts: coconutAccounts\.map\(encodeCoconutAccount\)' \
  "buildBackup should export V58 CoconutAccount rows."

require_backup_pattern 'let backupCoconutLedgerEntries = scope\.excludesHumanHealthData' \
  "Restricted exports must explicitly scope CoconutLedgerEntry sidecars before encoding."

require_backup_pattern 'coconutLedgerEntries: backupCoconutLedgerEntries\.map\(encodeCoconutLedgerEntry\)' \
  "buildBackup should encode only the export-scoped CoconutLedgerEntry rows."

require_backup_pattern 'let backupEconomyBudgetUsageEvents = scope\.excludesHumanHealthData' \
  "Restricted exports must explicitly scope derived economy-budget sidecars."

require_backup_pattern 'economyBudgetUsageEvents: backupEconomyBudgetUsageEvents\.map\(encodeEconomyBudgetUsageEvent\)' \
  "buildBackup should encode only the export-scoped economy-budget rows."

require_backup_pattern 'let backupFamilyTasks = scope\.excludesHumanHealthData' \
  "Restricted exports must explicitly scope free-text family tasks."

require_backup_pattern 'let coconutLogProjection = backupCoconutLedgerEntries' \
  "Legacy wallet-log projection must use the same restricted wallet scope."

require_backup_pattern 'insertCoconutAccountIfNeeded' \
  "applyBackup should import V58 CoconutAccount rows through the general rehydrate writer."

require_backup_pattern 'decodeCoconutAccountSnapshot\(dto\)' \
  "applyBackup should decode V58 CoconutAccount rows into rehydrate snapshots."

require_backup_pattern 'upsertCoconutLedgerEntry' \
  "applyBackup should import V58 CoconutLedgerEntry rows through the general rehydrate writer."

require_backup_pattern 'decodeCoconutLedgerEntrySnapshot\(dto\)' \
  "applyBackup should decode V58 CoconutLedgerEntry rows into rehydrate snapshots."

reject_backup_pattern '\b(pinHash|pinSalt|pinFailedAttempts|pinLockedUntil)\s*:' \
  "Backups must not encode PIN hash/salt/lockout fields."

reject_backup_pattern '\bh\.pin(Hash|Salt|FailedAttempts|LockedUntil)\b|\bdto\.pin(Hash|Salt|FailedAttempts|LockedUntil)\b' \
  "DataBackupManager must not read or restore Human PIN hash/salt/lockout fields."

require_pattern "Ohana/Models/Pet.swift" 'canAttemptAvatarImageAttachmentLoad' \
  "Pet legacy avatar reads should use tolerant attachment semantics for upgraded stores."

require_pattern "Ohana/Models/Human.swift" 'canAttemptAvatarImageAttachmentLoad' \
  "Human legacy avatar reads should use tolerant attachment semantics for upgraded stores."

require_pattern "Ohana/Models/Plant.swift" 'canAttemptAvatarImageAttachmentLoad' \
  "Plant legacy avatar reads should use tolerant attachment semantics for upgraded stores."

require_pattern "Ohana/Models/PlantCareLog.swift" 'canAttemptPhotoAttachmentLoad' \
  "Plant care log legacy photos should remain loadable when state is unknown after upgrade."

require_pattern "Ohana/Shared/Media/SwiftDataMediaBlobLoader.swift" 'persistRepairIfNeeded' \
  "SwiftDataMediaBlobLoader should persist lazy attachment index repairs after blob loads."

require_pattern "Ohana/Shared/Media/MediaAttachmentPresenceBackfillService.swift" 'avatarImageData != nil' \
  "MediaAttachmentPresenceBackfillService should backfill upgraded avatar presence using store-level nil checks."

require_pattern "Ohana/App/StartupMaintenanceCoordinator.swift" 'media_attachment_presence_backfill' \
  "Startup maintenance should run the one-time media attachment presence backfill after first render."

require_pattern "OhanaTests/MediaAttachmentUpgradeCompatibilityTests.swift" 'unknownAttachmentStatesRemainLoadableAfterLightweightMigrationDefaults' \
  "Release data safety should cover upgraded stores whose attachment states default to unknown."

require_pattern "OhanaTests/SharedModelContainerRecoveryTests.swift" 'testV67StoreOpensThroughLatestLightweightMigrationWithCoreUserData' \
  "Release data safety should cover a realistic old-store upgrade with core user data, not only metadata rows."

require_pattern "Ohana/Shared/Media/AttachmentPrivacySanitizer.swift" 'SanitizedAttachmentPayload' \
  "Attachment sanitizer should return both sanitized bytes and the normalized display filename."

require_pattern "Ohana/Shared/Media/AttachmentPrivacySanitizer.swift" 'normalizedJPEGFilename' \
  "Attachment sanitizer should normalize successful JPEG rewrites to .jpg display filenames."

require_pattern "Ohana/Features/Documents/PetDocumentCommands.swift" 'sanitizedAttachment\(attachment, index:' \
  "Pet document writes should normalize attachment filenames through the shared sanitizer payload."

require_pattern "Ohana/Features/Documents/Views/AddDocumentSheet.swift" 'startingAttachmentCount' \
  "Pet document photo batch imports should assign stable per-photo fallback filenames instead of duplicating photo.jpg."

require_pattern "Ohana/Features/Expenses/ExpenseReceiptSupport.swift" 'sanitizedAttachment\(attachment, index:' \
  "Expense receipt document drafts should normalize attachment filenames through the shared sanitizer payload."

require_pattern "OhanaTests/PrivacyHardeningTests.swift" 'imageAttachmentSanitizerNormalizesFilenameOnlyAfterJPEGRewrite' \
  "Privacy hardening tests should prove JPEG rewrite filename normalization and decode-failure preservation."

if rg -n --pcre2 '^[[:space:]]*try\?[[:space:]]+(?:modelContext|context)\.save\(\)' Ohana --glob '*.swift' >/tmp/ohana-release-data-safety-silent-save.txt; then
  failures+=("App code must not silently discard SwiftData save failures with try? context.save(); use safeSave/safeSaveResult or explicit do/catch.")
fi

if ! python3 - "$save_failure_baseline" "$update_save_baseline" <<'PY'; then
from __future__ import annotations

import collections
import datetime as dt
import json
import pathlib
import re
import sys

ROOT = pathlib.Path.cwd()
BASELINE = ROOT / sys.argv[1]
UPDATE_BASELINE = sys.argv[2] == "1"
ALLOW_MARKER = "save-failure-audit: allow"
RULE_ID = "swiftdata-ambiguous-safe-save"
SAFE_SAVE_RE = re.compile(r"\b(?:[A-Za-z0-9_]+Context|context|modelContext)\.(?:safeSave|safeSaveResult)\(\)")


def relative(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()


def scan_file(path: pathlib.Path) -> list[dict[str, object]]:
    matches: list[dict[str, object]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    for line_number, line in enumerate(lines, start=1):
        if ALLOW_MARKER in line:
            continue
        if SAFE_SAVE_RE.search(line):
            matches.append({"line": line_number, "source": line.strip()})
    return matches


def load_baseline(path: pathlib.Path) -> dict[str, list[str]]:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"SwiftData save failure audit: invalid baseline JSON: {exc}", file=sys.stderr)
        sys.exit(1)
    raw = data.get("allowedMatches", {})
    if not isinstance(raw, dict):
        print("SwiftData save failure audit: baseline missing allowedMatches.", file=sys.stderr)
        sys.exit(1)
    allowed: dict[str, list[str]] = {}
    for file_path, lines in raw.items():
        if isinstance(file_path, str) and isinstance(lines, list):
            allowed[file_path] = [line for line in lines if isinstance(line, str)]
    return allowed


matches_by_file: dict[str, list[dict[str, object]]] = {}
for path in sorted((ROOT / "Ohana").rglob("*.swift")):
    matches = scan_file(path)
    if matches:
        matches_by_file[relative(path)] = matches

if UPDATE_BASELINE:
    allowed = {
        file_path: sorted(str(match["source"]) for match in matches)
        for file_path, matches in sorted(matches_by_file.items())
        if matches
    }
    payload = {
        "schema": "ohana.governance.swiftdata-save-failure-baseline.v1",
        "updated": dt.date.today().isoformat(),
        "policyDocuments": [
            "AGENTS.md",
            "docs/release-quality-gates.md",
            "docs/data-cache-sync-policy.md",
        ],
        "purpose": (
            "Ratcheted baseline for existing bare safeSave() or no-argument "
            "safeSaveResult() calls that leave save-failure handling ambiguous. "
            "New writes should pass publishFailureEvent explicitly, throw, or use "
            "an explicit user-visible failure contract."
        ),
        "command": "scripts/audit-release-data-safety.sh",
        "allowedMatches": allowed,
    }
    BASELINE.parent.mkdir(parents=True, exist_ok=True)
    BASELINE.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"SwiftData save failure baseline updated at {relative(BASELINE)} ({sum(len(v) for v in allowed.values())} match(es), {len(allowed)} file(s)).")
    sys.exit(0)

allowed = load_baseline(BASELINE)
violations: list[tuple[str, int, str]] = []
for file_path, matches in matches_by_file.items():
    allowed_counts = collections.Counter(allowed.get(file_path, []))
    seen_counts: collections.Counter[str] = collections.Counter()
    for match in matches:
        source = str(match["source"])
        seen_counts[source] += 1
        if seen_counts[source] > allowed_counts[source]:
            violations.append((file_path, int(match["line"]), source))

if violations:
    for file_path, line_number, source in violations:
        print(
            f"[{RULE_ID}] {file_path}:{line_number} "
            "bare safeSave()/safeSaveResult() leaves persistence failure handling ambiguous; pass publishFailureEvent explicitly, throw, or add an explicit allow marker.",
            file=sys.stderr,
        )
        print(f"  {source}", file=sys.stderr)
    print(
        f"SwiftData save failure audit: {len(violations)} new match(es) "
        f"across {len({item[0] for item in violations})} file(s).",
        file=sys.stderr,
    )
    sys.exit(1)

current_debt = sum(len(matches) for matches in matches_by_file.values())
baseline_debt = sum(len(lines) for lines in allowed.values())
print(f"SwiftData save failure audit: passed ({current_debt} current baseline match(es), {baseline_debt} allowed).")
PY
  failures+=("New bare safeSave()/safeSaveResult() sites must not leave SwiftData save failure handling ambiguous; pass publishFailureEvent explicitly, throw, or use an explicit allow marker.")
fi

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "Release data safety audit: passed."
  exit 0
fi

echo "Release data safety audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
if [[ -s /tmp/ohana-release-data-safety-silent-save.txt ]]; then
  cat /tmp/ohana-release-data-safety-silent-save.txt >&2
fi
exit 1
