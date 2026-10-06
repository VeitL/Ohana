#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ $# -gt 1 ]]; then
  echo "Usage: scripts/audit-system-surface-reset-fence.sh [combined-fixture.swift]" >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  coordinator_file="$1"
  runtime_file="$1"
  services_file="$1"
  tests_file="$1"
  backup_tests_file="$1"
else
  coordinator_file="Ohana/SystemSurfaces/SystemSurfaceSnapshotCoordinator.swift"
  runtime_file="Ohana/App/AppRuntimeAdapters.swift"
  services_file="Ohana/App/AppServices.swift"
  tests_file="OhanaTests/SystemSurfaceTests.swift"
  backup_tests_file="OhanaTests/AutomaticBackupServiceTests.swift"
fi

for file in "$coordinator_file" "$runtime_file" "$services_file" "$tests_file" "$backup_tests_file"; do
  if [[ ! -f "$file" ]]; then
    echo "System-surface Reset fence audit: missing file: $file" >&2
    exit 2
  fi
done

if ! command -v rg >/dev/null 2>&1; then
  echo "System-surface Reset fence audit: ripgrep (rg) is required." >&2
  exit 2
fi

failures=()

fail() {
  failures+=("[$1] $2")
}

section() {
  local file="$1"
  local start="$2"
  local end="$3"
  awk -v start="$start" -v end="$end" '
    $0 ~ start { inside = 1 }
    inside && $0 ~ end && $0 !~ start { exit }
    inside { print }
  ' "$file"
}

require_pattern() {
  local file="$1"
  local rule_id="$2"
  local pattern="$3"
  local message="$4"
  if ! rg -q -U --pcre2 "$pattern" "$file"; then
    fail "$rule_id" "$message"
  fi
}

require_section_pattern() {
  local file="$1"
  local start="$2"
  local end="$3"
  local rule_id="$4"
  local pattern="$5"
  local message="$6"
  local body
  body="$(section "$file" "$start" "$end")"
  if [[ -z "$body" ]] || ! rg -q -U --pcre2 "$pattern" <<<"$body"; then
    fail "$rule_id" "$message"
  fi
}

require_section_order() {
  local file="$1"
  local start="$2"
  local end="$3"
  local rule_id="$4"
  local first="$5"
  local second="$6"
  local message="$7"
  local body first_line second_line
  body="$(section "$file" "$start" "$end")"
  first_line="$(rg -n -m 1 --pcre2 "$first" <<<"$body" | cut -d: -f1 || true)"
  second_line="$(rg -n -m 1 --pcre2 "$second" <<<"$body" | cut -d: -f1 || true)"
  if [[ -z "$body" || -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    fail "$rule_id" "$message"
  fi
}

schedule_start='func scheduleRefresh[(]reason: String[)][[:space:]]*[{]'
prepare_start='func prepareForAppReset[(][)][[:space:]]*[{]'
finish_start='func finishAppReset[(][)][[:space:]]*[{]'
wait_start='func waitForRefreshQuiescenceForTesting[(][)] async[[:space:]]*[{]'
refresh_start='func refresh[(]reason: String, generation: UInt64[)] async[[:space:]]*[{]'
write_start='func write[(]'
current_start='func isCurrent[(]generation: UInt64[)] -> Bool[[:space:]]*[{]'
reset_start='func reset[(]context: ModelContext, options: AppResetService[.]Options[)] async throws -> AppResetService[.]ResetResult[[:space:]]*[{]'
ui_reset_start='func resetForUITests[(]context: ModelContext[)] throws[[:space:]]*[{]'

require_section_pattern "$coordinator_file" "$schedule_start" "$prepare_start" \
  "reset-fence-schedule-pause" \
  '^[[:space:]]*guard !isResetInProgress else \{ return \}' \
  "Refresh scheduling must reject work while Reset is paused."

require_section_pattern "$coordinator_file" "$prepare_start" "$finish_start" \
  "reset-fence-prepare-pause" \
  '^[[:space:]]*isResetInProgress = true' \
  "Reset preparation must pause the coordinator."

require_section_pattern "$coordinator_file" "$prepare_start" "$finish_start" \
  "reset-fence-prepare-generation" \
  '^[[:space:]]*refreshGeneration &\+= 1' \
  "Reset preparation must invalidate every older refresh generation."

require_section_order "$coordinator_file" "$prepare_start" "$finish_start" \
  "reset-fence-prepare-cancel" \
  'refreshGeneration &\+= 1' 'refreshTask\?\.cancel\(\)' \
  "Reset preparation must cancel the old task after invalidating its generation."

require_section_pattern "$coordinator_file" "$refresh_start" "$write_start" \
  "reset-fence-post-await" \
  'try await loadSnapshot\(\)(?s:.*?)isCurrent\(generation: generation\)' \
  "A delayed load must re-check the generation after its suspension point."

require_section_order "$coordinator_file" "$write_start" "$current_start" \
  "reset-fence-prewrite" \
  'guard isCurrent\(generation: generation\)' 'try store\.write\(snapshot\)' \
  "The final snapshot write must be generation-gated."

require_section_order "$coordinator_file" "$finish_start" "$wait_start" \
  "reset-fence-finish-generation" \
  'refreshGeneration &\+= 1' 'isResetInProgress = false' \
  "Finishing Reset must invalidate old work before reopening scheduling."

require_section_order "$runtime_file" "$reset_start" "$ui_reset_start" \
  "reset-fence-runtime-order" \
  '^[[:space:]]*prepareRuntimeForReset\(\)' 'await automaticBackups\.prepareForAppReset\(\)' \
  "The runtime fence must start before automatic-backup quiescence suspends."

require_section_pattern "$runtime_file" "$reset_start" "$ui_reset_start" \
  "reset-fence-runtime-defer" \
  'defer[[:space:]]*\{(?s:.*?)finishRuntimeAfterReset\(\)' \
  "Reset must release the runtime fence from defer on every exit."

require_section_pattern "$runtime_file" "$reset_start" "$ui_reset_start" \
  "reset-fence-failure-recovery" \
  'finishRuntimeAfterReset\(\)(?s:.*?)if !didCompletePersistentReset(?s:.*?)recoverRuntimeAfterFailedReset\(\)' \
  "A failed persistent Reset must reopen the fence and request projection recovery."

require_section_pattern "$runtime_file" "$reset_start" "$ui_reset_start" \
  "reset-fence-success-boundary" \
  'deletePersistentData: deletePersistentData[[:space:]]*\)[[:space:]]*didCompletePersistentReset = true' \
  "Reset success must be recorded only after the persistent Reset boundary returns."

require_pattern "$services_file" "reset-fence-live-wiring" \
  'graph\.systemSurfaces\.prepareForAppReset\(\)(?s:.*?)graph\.systemSurfaces\.finishAppReset\(\)(?s:.*?)graph\.systemSurfaces\.scheduleRefresh\(reason: "appReset\.failed"\)' \
  "The live composition root must wire pause, release, and failed-Reset recovery to one coordinator."

require_pattern "$tests_file" "reset-fence-deterministic-test" \
  'resetFencePreventsDelayedRefreshFromRewritingPersonalSnapshot(?s:.*?)await loader\.waitUntilStarted\(\)(?s:.*?)func waitUntilStarted\(\) async' \
  "The delayed-refresh regression must use an explicit start handshake instead of timing yields."

require_pattern "$backup_tests_file" "reset-fence-failure-test" \
  'persistentResetFailureReleasesFenceAndRefreshesExistingProjection(?s:.*?)#expect\(didRecoverRuntimeAfterFailure\)' \
  "A persistent Reset failure must have an executable recovery regression test."

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "System-surface Reset fence audit: passed."
  exit 0
fi

echo "System-surface Reset fence audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
