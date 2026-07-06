#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required." >&2
  exit 2
fi

data_backup="Ohana/Domain/Services/DataBackupManager.swift"
data_backup_dtos="Ohana/Domain/Services/DataBackupDTOs.swift"
automatic_backup="Ohana/Domain/Services/AutomaticBackupService.swift"
data_backup_files=(
  "Ohana/Domain/Services/DataBackupManager.swift"
  "Ohana/Domain/Services/DataBackupManager+Encode.swift"
  "Ohana/Domain/Services/DataBackupManager+Decode.swift"
  "Ohana/Domain/Services/DataBackupMediaPackage.swift"
  "Ohana/Domain/Services/DataBackupDTOs.swift"
)
shared_container="Ohana/Models/SharedModelContainer.swift"

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

require_pattern "$shared_container" 'Schema\(ArkSchemaV84\.models\)' \
  "SharedModelContainer should open the current ArkSchemaV84 model set."

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

require_pattern "$automatic_backup" 'DataBackupManager\(\)\.exportJSON\(container: container\)' \
  "Live automatic backups should use DataBackupManager package export."

require_pattern "$automatic_backup" 'writeAutomaticBackup\(packageURL: URL, now: Date\)' \
  "Automatic backup file storage should receive and copy a backup package URL."

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

require_backup_pattern 'coconutLedgerEntries: coconutLedgerEntries\.map\(encodeCoconutLedgerEntry\)' \
  "buildBackup should export V58 CoconutLedgerEntry rows."

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

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "Release data safety audit: passed."
  exit 0
fi

echo "Release data safety audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
