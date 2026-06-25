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
data_backup_files=(
  "Ohana/Domain/Services/DataBackupManager.swift"
  "Ohana/Domain/Services/DataBackupManager+Encode.swift"
  "Ohana/Domain/Services/DataBackupManager+Decode.swift"
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

require_pattern "$shared_container" 'Schema\(ArkSchemaV73\.models\)' \
  "SharedModelContainer should open the current ArkSchemaV73 model set."

require_pattern "$data_backup_dtos" 'var schemaVersion: Int = 26' \
  "OhanaBackup.schemaVersion should be 26 after adding plant launch backups."

require_pattern "$data_backup" 'guard backup\.schemaVersion <= 26' \
  "DataBackupManager import guard should allow backup schemaVersion 26."

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

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "Release data safety audit: passed."
  exit 0
fi

echo "Release data safety audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
