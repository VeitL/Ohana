#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required." >&2
  exit 2
fi

data_backup="Ohana/Models/DataBackupManager.swift"
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

require_pattern "$shared_container" 'Schema\(ArkSchemaV56\.models\)' \
  "SharedModelContainer should open the current ArkSchemaV56 model set."

require_pattern "$data_backup" 'var schemaVersion: Int = 22' \
  "OhanaBackup.schemaVersion should be 22 after adding human metric backups."

require_pattern "$data_backup" 'guard backup\.schemaVersion <= 22' \
  "DataBackupManager import guard should allow backup schemaVersion 22."

require_section_pattern "$data_backup" 'struct HumanBackup' 'struct EventBackup' 'var passedAwayDate: String\?' \
  "HumanBackup should include passedAwayDate so human memorial state survives backup/restore."

require_pattern "$data_backup" 'passedAwayDate: d\(h\.passedAwayDate\)' \
  "encodeHuman should export Human.passedAwayDate."

require_pattern "$data_backup" 'h\.passedAwayDate = parseDate\(dto\.passedAwayDate\)' \
  "decodeHuman should restore Human.passedAwayDate."

require_pattern "$data_backup" 'struct HumanHealthMetricLogBackup: Codable' \
  "DataBackupManager should define HumanHealthMetricLogBackup."

require_pattern "$data_backup" 'var humanHealthMetricLogs: \[HumanHealthMetricLogBackup\]\?' \
  "OhanaBackup should include humanHealthMetricLogs."

require_pattern "$data_backup" 'FetchDescriptor<HumanHealthMetricLog>' \
  "DataBackupManager should fetch HumanHealthMetricLog during backup/import."

require_pattern "$data_backup" 'humanHealthMetricLogs: humanHealthMetricLogs\.map\(encodeHumanHealthMetricLog\)' \
  "buildBackup should encode human health metric logs."

require_pattern "$data_backup" 'decodeHumanHealthMetricLog\(dto, humans: humanById\)' \
  "applyBackup should decode human health metric logs with human relationships."

reject_pattern "$data_backup" '\b(pinHash|pinSalt|pinFailedAttempts|pinLockedUntil)\s*:' \
  "Backups must not encode PIN hash/salt/lockout fields."

reject_pattern "$data_backup" '\bh\.pin(Hash|Salt|FailedAttempts|LockedUntil)\b|\bdto\.pin(Hash|Salt|FailedAttempts|LockedUntil)\b' \
  "DataBackupManager must not read or restore Human PIN hash/salt/lockout fields."

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "Release data safety audit: passed."
  exit 0
fi

echo "Release data safety audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
