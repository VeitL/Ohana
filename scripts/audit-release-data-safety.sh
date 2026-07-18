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
data_backup_app_state="Ohana/Domain/Services/DataBackupManager+AppState.swift"
data_backup_dtos="Ohana/Domain/Services/DataBackupDTOs.swift"
data_backup_preflight="Ohana/Domain/Services/DataBackupPreflightValidator.swift"
automatic_backup="Ohana/Domain/Services/AutomaticBackupService.swift"
physical_deletion="Ohana/Domain/Services/PhysicalDeletionService.swift"
app_reset="Ohana/App/AppResetService.swift"
app_runtime_adapters="Ohana/App/AppRuntimeAdapters.swift"
app_services="Ohana/App/AppServices.swift"
data_backup_files=(
  Ohana/Domain/Services/DataBackupManager*.swift
  "Ohana/Domain/Services/DataBackupMediaPackage.swift"
  "Ohana/Domain/Services/DataBackupPreflightValidator.swift"
  "Ohana/Domain/Services/DataBackupRuntime.swift"
  "Ohana/Domain/Services/DataBackupDTOs.swift"
)
shared_container="Ohana/Models/SharedModelContainer.swift"
local_backup_exclusion="Ohana/Shared/Utilities/LocalBackupExclusionPolicy.swift"
human_note_attachments="Ohana/Features/HumanNotes/HumanNoteAttachmentStore.swift"
human_note_commands="Ohana/Features/HumanNotes/HumanNoteCommands.swift"
member_deletion_commands="Ohana/Features/Members/MemberDeletionCommands.swift"
human_note_attachment_tests="OhanaTests/HumanNoteAttachmentLifecycleTests.swift"
data_backup_atomic_tests="OhanaTests/DataBackupAtomicRestoreTests.swift"
v90_migration_fixture="OhanaTests/Fixtures/ArkSchemaV90/default.store"
v90_migration_manifest="OhanaTests/Fixtures/ArkSchemaV90/manifest.json"
settings_backup="Ohana/Features/Settings/Views/SettingsView+Backup.swift"
settings_chrome="Ohana/Features/Settings/Views/SettingsView+Chrome.swift"

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
  ' "$file" | rg --pcre2 "$pattern" >/dev/null; then
    failures+=("$message")
  fi
}

reject_section_pattern() {
  local file="$1"
  local start="$2"
  local end="$3"
  local pattern="$4"
  local message="$5"
  if awk -v start="$start" -v end="$end" '
    $0 ~ start { flag = 1 }
    $0 ~ end { flag = 0 }
    flag { print }
  ' "$file" | rg --pcre2 "$pattern" >/dev/null; then
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
  "HumanNoteRecord|struct HumanNoteRecordBackup"
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
  "PresenceCheckIn|struct PresenceCheckInBackup"
  "PresenceParticipationPeriod|struct PresenceParticipationPeriodBackup"
  "PresenceRewardReceipt|struct PresenceRewardReceiptBackup"
  "RecycleBinBatch|EXEMPT:short-lived recycle-bin grouping metadata, not durable user content"
  "Reminder|struct ReminderBackup"
  "SafetyContact|EXEMPT:device-local phone-number data, intentionally excluded from every backup destination"
  "SharedCareSession|struct SharedCareSessionBackup"
  "SharedCareUndoReceipt|EXEMPT:local short-lived crash-recovery coordination state, not user-authored history"
  "ShopPurchaseAttempt|EXEMPT:local shop fulfillment recovery state, not user-authored history"
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

require_pattern "$shared_container" 'Schema\(ArkSchemaV93\.models\)' \
  "SharedModelContainer should open the current ArkSchemaV93 model set."

require_pattern "$local_backup_exclusion" 'values\.isExcludedFromBackup = true' \
  "Local persistence must set URLResourceValues.isExcludedFromBackup before storing private data."

require_pattern "$local_backup_exclusion" 'forKeys: \[\.isExcludedFromBackupKey\]' \
  "Local backup exclusion must be read back and verified after it is applied."

require_pattern "$shared_container" 'LocalBackupExclusionPolicy\.prepareApplicationSupportDirectory\(\)' \
  "SharedModelContainer must exclude the Application Support persistence root from OS-managed backup before opening SwiftData."

require_pattern "$human_note_attachments" 'LocalBackupExclusionPolicy\.excludeFromDeviceBackup\(directory\)' \
  "Human Note attachment directories must be excluded from OS-managed backup."

require_pattern "$human_note_attachments" 'LocalBackupExclusionPolicy\.excludeFromDeviceBackup\(url\)' \
  "Human Note attachment files must be excluded after atomic writes."

require_pattern "$human_note_commands" 'let attachmentCleanup = cleanDeletedAttachments\(' \
  "Human Note deletion must run attachment cleanup only after its SwiftData commit succeeds."

require_pattern "$human_note_commands" 'HumanNoteAttachmentStore\.deleteUnreferencedAttachments\(' \
  "Human Note deletion must preserve attachment paths still referenced by surviving notes."

require_pattern "$member_deletion_commands" 'let attachmentCleanup = cleanDeletedHumanAttachments\(' \
  "Human deletion must clean its attachment directory only after its SwiftData commit succeeds."

require_pattern "$member_deletion_commands" 'HumanNoteAttachmentStore\.deleteHumanDirectory\(' \
  "Human deletion must use the Human Notes directory cleanup boundary."

require_section_pattern "$app_reset" 'let preservedDefaults' 'HumanNoteAttachmentStore\.deleteAll\(storage: attachmentStorage\)' \
  'try deletePersistentModels\(context: context, deletePersistentData: deletePersistentData\)' \
  "Delete-all Reset must remove the Human Notes root after the database commit."

require_pattern "$app_reset" 'HumanNoteAttachmentStore\.deleteAll\(storage: attachmentStorage\)' \
  "Delete-all Reset must remove the Human Notes root after persistent data deletion succeeds."

require_pattern "$human_note_attachment_tests" 'noteDeletionPreservesSharedReferenceThenRemovesItWhenLastReferenceIsDeleted' \
  "Release data safety must test shared Human Note attachment references and repeated deletion."

require_pattern "$human_note_attachment_tests" 'noteDeletionSaveFailurePreservesDatabaseReferenceAndFile' \
  "Release data safety must prove failed note deletion saves do not remove live attachment files."

require_pattern "$human_note_attachment_tests" 'humanDeletionClearsOwnedAndOrphanFilesButPreservesSharedReference' \
  "Release data safety must test Human-directory cleanup without breaking surviving shared references."

require_pattern "$human_note_attachment_tests" 'appResetStoreDeletionFailureLeavesDatabaseAndAttachmentRootUntouched' \
  "Release data safety must prove failed Reset store deletion leaves the Human Notes root intact."

require_pattern "OhanaTests/LocalBackupExclusionPolicyTests.swift" 'marksDirectoriesAndFilesAsExcludedFromDeviceBackup' \
  "Release data safety must test directory and file backup-exclusion resource values."

require_pattern "$app_reset" 'deletePersistentData: \{ \$0\.deleteAllData\(\) \}' \
  "Delete-all reset must use the full-store deletion boundary so every current and future persisted model is removed."

require_pattern "$app_reset" '"economyV2\."' \
  "Delete-all reset must clear economyV2 daily-budget defaults together with persistent guardrail events."

require_pattern "OhanaTests/AppResetServiceTests.swift" 'fetch\(FetchDescriptor<EconomyBudgetUsageEvent>\(\)\)\.isEmpty' \
  "AppResetService tests must prove economy budget guardrail rows are deleted."

require_pattern "$automatic_backup" 'private var activeRunTask: Task<AutomaticBackupRunResult, Never>\?' \
  "AutomaticBackupService must own the active run task instead of guarding it with an unowned Boolean."

require_pattern "$automatic_backup" 'func prepareForAppReset\(\) async' \
  "AutomaticBackupService must expose the shared asynchronous Reset quiescence boundary."

require_pattern "$automatic_backup" 'generation &\+= 1' \
  "Reset must invalidate the active automatic-backup generation before local deletion."

require_pattern "$automatic_backup" 'guard checkpoint\(runID: runID, generation: runGeneration\)' \
  "Automatic backup must check its generation after suspended export/write stages before publishing files or success status."

reject_pattern "$automatic_backup" 'removeManagedAutomaticBackupsSynchronously' \
  "Delete-all must not bypass the shared asynchronous backup coordinator with a second synchronous cleaner."

reject_pattern "$app_reset" 'ICloudDriveAutomaticBackupFileStore' \
  "AppResetService must not construct a second iCloud backup cleaner outside the shared coordinator."

require_pattern "$app_runtime_adapters" 'await automaticBackups\.prepareForAppReset\(\)' \
  "The production Reset adapter must quiesce the shared automatic-backup instance before deleting local data."

require_pattern "$app_runtime_adapters" 'await automaticBackups\.removeManagedAutomaticBackupsForReset\(\)' \
  "The production Reset adapter must remove the managed file through the same automatic-backup instance."

require_pattern "$app_services" 'automaticBackups: automaticBackups' \
  "AppServices must inject one AutomaticBackupService instance into both lifecycle backup and Reset ownership."

require_pattern "$settings_chrome" 'try await appServices\.appReset\.reset\(context: modelContext\)' \
  "Settings Delete-All must await the coordinated asynchronous Reset result."

require_pattern "OhanaTests/AutomaticBackupServiceTests.swift" 'resetDuringNonCooperativeExportFencesOldGenerationAndAllowsANewBackup' \
  "Release data safety must deterministically test Reset during a non-cooperative export."

require_pattern "OhanaTests/AutomaticBackupServiceTests.swift" 'resetWaitsForAnInFlightManagedWriteThenRemovesItsFileAndStatus' \
  "Release data safety must deterministically test Reset during the managed-file write."

require_pattern "$settings_backup" 'free-text family tasks' \
  "Settings backup disclosure must name free-text family-task exclusion, not only Human health data."

require_pattern "$settings_backup" 'derived economy/ledger sidecars' \
  "Settings backup disclosure must name derived economy/ledger sidecar exclusion."

while IFS= read -r localized_strings; do
  reject_pattern "$localized_strings" '备份含全部宠物、家庭成员、日志、健康档案及应用状态' \
    "Localized resources must not retain the obsolete claim that backups include all Human health records."
done < <(find Ohana -name Localizable.strings -type f -print)

require_pattern "$data_backup_dtos" 'var schemaVersion: Int = 32' \
  "OhanaBackup.schemaVersion should be 32 after adding presence and safety-contact data."

require_pattern "$data_backup_preflight" 'backup\.schemaVersion >= 1, backup\.schemaVersion <= 32' \
  "Restore preflight should accept supported backup schema versions through 32."

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

require_pattern "$data_backup" 'DataBackupPreflightValidator\.validate\(backup, existing: existingIdentities\)' \
  "Restore must strictly validate the decoded backup before opening the live transaction."

require_pattern "$data_backup_preflight" 'fieldName == "id"' \
  "Restore preflight must validate every primary record UUID."

require_pattern "$data_backup_preflight" 'Set\(ids\)\.count == ids\.count' \
  "Restore preflight must reject duplicate primary record identities."

require_pattern "$data_backup_preflight" 'isDateField\(fieldName\)' \
  "Restore preflight must reject malformed required dates."

require_pattern "$data_backup_preflight" 'validateRequiredRelationships' \
  "Restore preflight must validate required relationship references."

require_pattern "$data_backup" 'context\.autosaveEnabled = false' \
  "Restore must disable main-context autosave while preparing its single transaction."

require_pattern "$data_backup" 'DataBackupRestoreDefaults\(snapshot: defaults\.dictionaryRepresentation\(\)\)' \
  "Restore must stage preference-dependent planning in memory instead of writing a temporary defaults domain."

reject_pattern "$data_backup" 'UserDefaults\(suiteName: .*restore-staging' \
  "Restore must not persist a crash-leftover staging UserDefaults domain."

require_pattern "$data_backup" 'context\.transaction\(block: changes\)' \
  "Restore must use one SwiftData transaction as its live-store commit boundary."

reject_section_pattern "$data_backup" 'private func prepareBackupChanges' 'private func insertLegacyShopPurchaseRecords' \
  'safeSave(Result)?|context\.save\(|saveRestoreCheckpoint' \
  "Restore preparation must not save intermediate SwiftData checkpoints."

require_section_pattern "$data_backup" 'private func prepareBackupChanges' 'private func insertLegacyShopPurchaseRecords' \
  'persistChanges: false' \
  "Restore must keep shared-care legacy cleanup inside the outer transaction."

require_section_pattern "$data_backup" 'private func prepareBackupChanges' 'private func insertLegacyShopPurchaseRecords' \
  'saveChanges: false' \
  "Restore must keep legacy economy and plant reconciliation inside the outer transaction."

require_pattern "$data_backup_atomic_tests" 'DataBackupRestorePhase\.allCases' \
  "Restore atomicity tests must inject a failure at every declared restore phase."

require_pattern "$data_backup_atomic_tests" 'malformedRequiredValuesFailBeforeAnyLiveMutation' \
  "Restore tests must prove malformed identity/date/relationship inputs fail before live mutation."

require_pattern "$data_backup_atomic_tests" 'transactionSaveFailureRollsBackPreparedChanges' \
  "Restore tests must prove commit failure preserves the original store and defaults."

require_pattern "$data_backup_atomic_tests" 'restoreLimitsAndMediaReaderRejectOversizeOrTampering' \
  "Restore tests must prove manifest limits and media byte-count tampering are rejected."

reject_pattern "$physical_deletion" 'deleteRows\(fetchAll\(CoconutLedgerEntry\.self' \
  "PhysicalDeletionService must preserve append-only CoconutLedgerEntry rows during member deletion."

require_pattern "$physical_deletion" 'retireWalletAccounts\(ownerKind:' \
  "PhysicalDeletionService should retire wallet accounts instead of deleting economy audit rows."

require_pattern "$data_backup_dtos" 'struct PlantReminderPreferencesBackup' \
  "Plant reminder preferences should be represented in backup app state."

require_pattern "$data_backup_app_state" 'applyPlantReminderPreferences' \
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

require_backup_pattern 'humanHealthReports: [[:alnum:]_.]+\.map\(encodeHumanHealthReport\)' \
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

require_pattern "OhanaTests/SharedModelContainerRecoveryTests.swift" 'testRealV90BinaryStoreMigratesToV91AndPersistsAttributionFacts' \
  "Release data safety should exercise the real V90 binary fixture through V91 attribution writes and relaunch."

if [[ ! -s "$v90_migration_fixture" ]]; then
  failures+=("Release data safety should keep the real V90 SQLite migration fixture.")
fi
if [[ -f "$v90_migration_manifest" ]]; then
  require_pattern "$v90_migration_manifest" '"sourceSchemaTarget"[[:space:]]*:[[:space:]]*"ArkSchemaV90"' \
    "The V90 migration fixture manifest should identify its source schema target."
  require_pattern "$v90_migration_manifest" '"sha256"[[:space:]]*:[[:space:]]*"[0-9a-f]{64}"' \
    "The V90 migration fixture manifest should record a SHA-256 digest."
  if [[ -s "$v90_migration_fixture" ]]; then
    manifest_fixture_sha="$(awk -F '"' '$2 == "sha256" { print $4; exit }' "$v90_migration_manifest")"
    actual_fixture_sha="$(shasum -a 256 "$v90_migration_fixture" | awk '{ print $1 }')"
    if [[ -z "$manifest_fixture_sha" || "$manifest_fixture_sha" != "$actual_fixture_sha" ]]; then
      failures+=("The V90 migration fixture no longer matches its reviewed provenance digest.")
    fi
  fi
else
  failures+=("Release data safety should keep provenance for the real V90 SQLite migration fixture.")
fi

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

save_failure_arguments=(--all)
if [[ "$update_save_baseline" == "1" ]]; then
  save_failure_arguments=(--update-baseline)
fi
if ! scripts/audit-swiftdata-save-failures.sh "${save_failure_arguments[@]}"; then
  failures+=("New bare safeSave()/safeSaveResult() sites must not leave SwiftData save failure handling ambiguous; pass publishFailureEvent explicitly, throw, or use an explicit allow marker.")
fi

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "Release data safety audit: passed."
  exit 0
fi

echo "Release data safety audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
