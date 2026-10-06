#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

audit="scripts/audit-release-test-surface.sh"
fixtures="scripts/tests/fixtures/ReleaseTestSurface"
failures=0
output=""
status=0

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

run_audit() {
  set +e
  output="$("$audit" "$@" 2>&1)"
  status=$?
  set -e
}

assert_failure() {
  local label="$1"
  local expected_rule="$2"
  shift 2
  run_audit "$@"
  if [[ "$status" -ne 1 ]]; then
    fail "$label: expected exit 1, got $status: $output"
  elif ! grep -qF "[$expected_rule]" <<<"$output"; then
    fail "$label: expected rule [$expected_rule], got: $output"
  else
    echo "ok  $label"
  fi
}

assert_failure "source launch marker outside DEBUG" \
  release-test-launch-marker "$fixtures/SourceBadLaunchMarker.swift"
assert_failure "source Debug menu outside DEBUG" \
  release-debug-surface-marker "$fixtures/SourceBadDebugSurface.swift"
assert_failure "source marker in DEBUG else branch" \
  release-test-launch-marker "$fixtures/SourceBadElse.swift"
assert_failure "source marker in ambiguous DEBUG-or branch" \
  release-test-launch-marker "$fixtures/SourceBadOr.swift"

run_audit "$fixtures/SourceGood.swift"
if [[ "$status" -ne 0 ]]; then
  fail "DEBUG-guarded source fixture should pass: $output"
else
  echo "ok  DEBUG-guarded source fixture passes"
fi

run_audit --all
if [[ "$status" -ne 0 ]]; then
  fail "current production source should pass: $output"
else
  scanned_count="$(grep -oE '[0-9]+ file\(s\)' <<<"$output" | head -1 | grep -oE '^[0-9]+' || true)"
  if [[ -z "$scanned_count" || "$scanned_count" -lt 600 ]]; then
    fail "source scope floor collapsed: expected at least 600 files, got ${scanned_count:-unparseable}"
  else
    echo "ok  source audit scans $scanned_count files (floor 600)"
  fi
fi

run_audit --app "$fixtures/ArtifactGood.app"
if [[ "$status" -ne 0 ]]; then
  fail "clean app fixture should pass: $output"
elif ! grep -qF "scanned 2 executable(s)" <<<"$output"; then
  fail "clean app fixture no longer proves main App plus embedded extension scope: $output"
else
  echo "ok  artifact audit scans clean App and Widget executables"
fi

assert_failure "artifact main executable marker" \
  release-artifact-test-marker --app "$fixtures/ArtifactBadMain.app"
assert_failure "artifact embedded extension marker" \
  release-artifact-test-marker --app "$fixtures/ArtifactBadWidget.app"
assert_failure "artifact packaged StoreKit configuration" \
  release-artifact-test-resource --app "$fixtures/ArtifactBadResource.app"

if [[ "$failures" -gt 0 ]]; then
  echo "Release test-surface fixture tests: $failures failure(s)." >&2
  exit 1
fi
echo "Release test-surface fixture tests passed."
