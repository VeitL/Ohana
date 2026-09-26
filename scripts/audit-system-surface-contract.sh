#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

contract_file="${1:-Ohana/SystemSurfaces/SystemSurfaceContracts.swift}"
if [[ ! -f "$contract_file" ]]; then
  echo "System-surface contract audit: missing file: $contract_file" >&2
  exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "System-surface contract audit: ripgrep (rg) is required." >&2
  exit 2
fi

failures=()
write_section="$(mktemp "${TMPDIR:-/tmp}/ohana-system-surface-write.XXXXXX")"
trap 'rm -f -- "$write_section"' EXIT

fail() {
  failures+=("[$1] $2")
}

require_pattern() {
  local rule_id="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -q --pcre2 "$pattern" "$contract_file"; then
    fail "$rule_id" "$message"
  fi
}

awk '
  /^[[:space:]]*func write\(/ { inside = 1 }
  inside { print }
  inside && /^[[:space:]]*func removeSnapshotIfPresent\(/ { exit }
' "$contract_file" > "$write_section"

if [[ ! -s "$write_section" ]]; then
  fail "system-surface-write-boundary" "write(_:) could not be located."
else
  container_line="$(rg -n -m 1 --pcre2 'verifyBackupExclusion\(at: containerURL\)' "$write_section" | cut -d: -f1 || true)"
  atomic_line="$(rg -n -m 1 --pcre2 'data\.write\(to: snapshotURL, options: \[\.atomic\]\)' "$write_section" | cut -d: -f1 || true)"
  snapshot_line="$(rg -n -m 1 --pcre2 'verifyBackupExclusion\(at: snapshotURL\)' "$write_section" | cut -d: -f1 || true)"

  if [[ -z "$atomic_line" ]]; then
    fail "system-surface-atomic-write" "The snapshot must use an atomic write."
  fi
  if [[ -z "$container_line" || -z "$atomic_line" || -z "$snapshot_line" || \
        "$container_line" -ge "$atomic_line" || "$atomic_line" -ge "$snapshot_line" ]]; then
    fail "system-surface-backup-exclusion-order" \
      "The App Group container must be verified before the write and the final snapshot after it."
  fi
fi

require_pattern \
  "system-surface-backup-exclusion-set" \
  'values\.isExcludedFromBackup[[:space:]]*=[[:space:]]*true' \
  "The contract must set isExcludedFromBackup to true."
require_pattern \
  "system-surface-backup-exclusion-readback" \
  'forKeys:[[:space:]]*\[\.isExcludedFromBackupKey\]' \
  "The contract must read the exclusion resource value back."
require_pattern \
  "system-surface-backup-exclusion-verification" \
  'guard[[:space:]]+persisted[[:space:]]*==[[:space:]]*true' \
  "The read-back value must be required before the write is accepted."

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "System-surface contract audit: passed."
  exit 0
fi

echo "System-surface contract audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
