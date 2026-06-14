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

require_pattern "$shared_container" 'Schema\(ArkSchemaV72\.models\)' \
  "SharedModelContainer should open the current ArkSchemaV72 model set."

require_pattern "$data_backup_dtos" 'var schemaVersion: Int = 25' \
  "OhanaBackup.schemaVersion should be 25 after adding shop purchase backups."

require_pattern "$data_backup" 'guard backup\.schemaVersion <= 25' \
  "DataBackupManager import guard should allow backup schemaVersion 25."

require_section_pattern "$data_backup_dtos" 'struct HumanBackup' 'struct EventBackup' 'var passedAwayDate: String\?' \
  "HumanBackup should include passedAwayDate so human memorial state survives backup/restore."

require_backup_pattern 'passedAwayDate: d\(h\.passedAwayDate\)' \
  "encodeHuman should export Human.passedAwayDate."

require_backup_pattern 'h\.passedAwayDate = parseDate\(dto\.passedAwayDate\)' \
  "decodeHuman should restore Human.passedAwayDate."

require_pattern "$data_backup_dtos" 'struct HumanHealthMetricLogBackup: Codable' \
  "DataBackupManager should define HumanHealthMetricLogBackup."

require_pattern "$data_backup_dtos" 'var humanHealthMetricLogs: \[HumanHealthMetricLogBackup\]\?' \
  "OhanaBackup should include humanHealthMetricLogs."

require_backup_pattern 'FetchDescriptor<HumanHealthMetricLog>' \
  "DataBackupManager should fetch HumanHealthMetricLog during backup/import."

require_backup_pattern 'humanHealthMetricLogs: humanHealthMetricLogs\.map\(encodeHumanHealthMetricLog\)' \
  "buildBackup should encode human health metric logs."

require_backup_pattern 'decodeHumanHealthMetricLog\(dto, humans: humanById\)' \
  "applyBackup should decode human health metric logs with human relationships."

require_pattern "$data_backup_dtos" 'var coconutAccounts: \[CoconutAccountBackup\]\?' \
  "OhanaBackup should include V58 CoconutAccount backups."

require_pattern "$data_backup_dtos" 'var coconutLedgerEntries: \[CoconutLedgerEntryBackup\]\?' \
  "OhanaBackup should include V58 CoconutLedgerEntry backups."

require_backup_pattern 'coconutAccounts: coconutAccounts\.map\(encodeCoconutAccount\)' \
  "buildBackup should export V58 CoconutAccount rows."

require_backup_pattern 'coconutLedgerEntries: coconutLedgerEntries\.map\(encodeCoconutLedgerEntry\)' \
  "buildBackup should export V58 CoconutLedgerEntry rows."

require_backup_pattern 'decodeCoconutAccount\(dto\)' \
  "applyBackup should import V58 CoconutAccount rows."

require_backup_pattern 'decodeCoconutLedgerEntry\(dto\)' \
  "applyBackup should import V58 CoconutLedgerEntry rows."

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
