#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
resolver="${repo_root}/scripts/resolve-test-scheme.sh"
failures=0

assert_scheme() {
  local expected="$1"
  local label="$2"
  shift 2

  local actual
  actual="$("${resolver}" "$@")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL: ${label}: expected ${expected}, got ${actual}" >&2
    failures=$((failures + 1))
    return
  fi
  echo "ok  ${label} -> ${actual}"
}

assert_scheme Ohana "no selectors preserve the full scheme"
assert_scheme OhanaUnitTests "unit bundle selector" \
  '-only-testing:OhanaTests'
assert_scheme OhanaUnitTests "unit method selector with parentheses" \
  '-only-testing:OhanaTests/AppWorkloadPolicyTests/foregroundBudgetsRemainInteractive()'
assert_scheme OhanaUITests "UI method selector" \
  '-only-testing:OhanaUITests/OhanaUITests/testReduceMotionLaunch'
assert_scheme OhanaUITests "UI module selector" \
  '-only-testing:OhanaUITests/PlantModuleUITests/testPlantModuleUnlockCreateCareReminderCalendarAndDelete'
assert_scheme Ohana "mixed selectors preserve the full scheme" \
  '-only-testing:OhanaTests/AppWorkloadPolicyTests' \
  '-only-testing:OhanaUITests/OhanaUITests/testReduceMotionLaunch'
assert_scheme Ohana "unknown selector preserves the full scheme" \
  '-only-testing:ThirdPartyTests/SomeSuite'

if [[ "${failures}" -gt 0 ]]; then
  echo "Test scheme routing: ${failures} failure(s)." >&2
  exit 1
fi

echo "Test scheme routing: all passed."
