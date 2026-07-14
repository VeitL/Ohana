#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

failures=0
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/ohana-ci-policy.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

fail() {
  echo "not ok  $1" >&2
  failures=$((failures + 1))
}

pass() {
  echo "ok  $1"
}

format_repo="$temp_root/format-repo"
mkdir -p "$format_repo"
git -C "$format_repo" init -q
git -C "$format_repo" config user.email ci-policy@example.invalid
git -C "$format_repo" config user.name "CI Policy Fixture"
printf 'let legacy = 1\n' > "$format_repo/Legacy.swift"
printf 'let changed = 1\n' > "$format_repo/Changed.swift"
git -C "$format_repo" add Legacy.swift Changed.swift
git -C "$format_repo" commit -qm base
format_base="$(git -C "$format_repo" rev-parse HEAD)"
printf 'let changed = 2\n' > "$format_repo/Changed.swift"
printf 'let added = 1\n' > "$format_repo/Added.swift"
git -C "$format_repo" add Changed.swift Added.swift
git -C "$format_repo" commit -qm head

format_scope="$(OHANA_REPO_ROOT="$format_repo" "$repo_root/scripts/ci-swiftformat.sh" --base-ref "$format_base" --list)"
if grep -qFx 'Changed.swift' <<<"$format_scope" \
  && grep -qFx 'Added.swift' <<<"$format_scope" \
  && ! grep -qFx 'Legacy.swift' <<<"$format_scope"; then
  pass "SwiftFormat PR scope includes only added or modified Swift files"
else
  fail "SwiftFormat PR scope leaked unchanged historical files: $format_scope"
fi

warning_file="$temp_root/ReviewBand.swift"
hard_file="$temp_root/HardLimit.swift"
python3 - "$warning_file" "$hard_file" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text("// review\n" * 1300, encoding="utf-8")
Path(sys.argv[2]).write_text("// hard\n" * 1401, encoding="utf-8")
PY

warning_status=0
warning_output="$(scripts/audit-architecture-boundaries.sh "$warning_file" 2>&1)" || warning_status=$?
if [[ "$warning_status" -eq 0 ]] && grep -q 'above the 1200-line review target' <<<"$warning_output"; then
  pass "Swift file warning band is advisory"
else
  fail "Swift file warning band should pass with an advisory: $warning_output"
fi

hard_status=0
hard_output="$(scripts/audit-architecture-boundaries.sh "$hard_file" 2>&1)" || hard_status=$?
if [[ "$hard_status" -eq 1 ]] && grep -q 'exceeds the 1400-line hard limit' <<<"$hard_output"; then
  pass "New Swift files beyond the hard limit still fail"
else
  fail "Swift file hard limit did not fail as expected: $hard_output"
fi

resource_repo="$temp_root/resource-repo"
mkdir -p "$resource_repo/Resources/Test"
git -C "$resource_repo" init -q
git -C "$resource_repo" config user.email ci-policy@example.invalid
git -C "$resource_repo" config user.name "CI Policy Fixture"
python3 - "$resource_repo/Resources/Test/blob.bin" <<'PY'
from pathlib import Path
import sys

with Path(sys.argv[1]).open("wb") as handle:
    handle.truncate(1200 * 1024)
PY
git -C "$resource_repo" add Resources/Test/blob.bin
git -C "$resource_repo" commit -qm base
resource_base="$(git -C "$resource_repo" rev-parse HEAD)"
resource_manifest="$resource_repo/resource-budgets.json"
printf '%s\n' '{"resourceBudgets":[{"id":"fixture","path":"Resources/Test","warningMiB":1,"hardLimitMiB":3,"maxGrowthMiB":1}]}' > "$resource_manifest"

python3 - "$resource_repo/Resources/Test/blob.bin" <<'PY'
from pathlib import Path
import sys

with Path(sys.argv[1]).open("r+b") as handle:
    handle.truncate(1800 * 1024)
PY
resource_warning_status=0
resource_warning_output="$(
  OHANA_REPO_ROOT="$resource_repo" \
    OHANA_RESOURCE_BUDGET_MANIFEST="$resource_manifest" \
    "$repo_root/scripts/audit-resource-integrity.sh" --base-ref "$resource_base" --budgets-only 2>&1
)" || resource_warning_status=$?
if [[ "$resource_warning_status" -eq 0 ]] && grep -q 'within the 1 MiB allowance' <<<"$resource_warning_output"; then
  pass "Resource warning target allows small reviewed growth"
else
  fail "Resource warning target should not hard fail: $resource_warning_output"
fi

python3 - "$resource_repo/Resources/Test/blob.bin" <<'PY'
from pathlib import Path
import sys

with Path(sys.argv[1]).open("r+b") as handle:
    handle.truncate(2500 * 1024)
PY
resource_growth_status=0
resource_growth_output="$(
  OHANA_REPO_ROOT="$resource_repo" \
    OHANA_RESOURCE_BUDGET_MANIFEST="$resource_manifest" \
    "$repo_root/scripts/audit-resource-integrity.sh" --base-ref "$resource_base" --budgets-only 2>&1
)" || resource_growth_status=$?
if [[ "$resource_growth_status" -eq 1 ]] && grep -q 'maximum reviewed growth is 1 MiB' <<<"$resource_growth_output"; then
  pass "Excessive above-target resource growth fails"
else
  fail "Resource growth ratchet did not fail as expected: $resource_growth_output"
fi

python3 - "$resource_repo/Resources/Test/blob.bin" <<'PY'
from pathlib import Path
import sys

with Path(sys.argv[1]).open("r+b") as handle:
    handle.truncate(3200 * 1024)
PY
resource_hard_status=0
resource_hard_output="$(
  OHANA_REPO_ROOT="$resource_repo" \
    OHANA_RESOURCE_BUDGET_MANIFEST="$resource_manifest" \
    "$repo_root/scripts/audit-resource-integrity.sh" --base-ref "$resource_base" --budgets-only 2>&1
)" || resource_hard_status=$?
if [[ "$resource_hard_status" -eq 1 ]] && grep -q 'exceeds the 3 MiB hard source limit' <<<"$resource_hard_output"; then
  pass "Resource hard limit remains blocking"
else
  fail "Resource hard limit did not fail as expected: $resource_hard_output"
fi

unit_repo="$temp_root/unit-repo"
mkdir -p "$unit_repo/OhanaTests"
printf '%s\n' \
  'final class AppResetServiceTests {' \
  '  func testFirstResetPath() {}' \
  '  func testSecondResetPath() {}' \
  '}' > "$unit_repo/OhanaTests/AppResetServiceTests.swift"
fake_xcodebuild="$temp_root/fake-xcodebuild"
fake_xcodebuild_log="$temp_root/fake-xcodebuild.log"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "call" >> "$OHANA_FAKE_XCODEBUILD_LOG"' \
  'printf "\t%s" "$@" >> "$OHANA_FAKE_XCODEBUILD_LOG"' \
  'printf "\n" >> "$OHANA_FAKE_XCODEBUILD_LOG"' > "$fake_xcodebuild"
chmod +x "$fake_xcodebuild"

OHANA_REPO_ROOT="$unit_repo" \
  OHANA_XCODEBUILD_BIN="$fake_xcodebuild" \
  OHANA_FAKE_XCODEBUILD_LOG="$fake_xcodebuild_log" \
  OHANA_CI_DERIVED_DATA_PATH="$temp_root/unit-derived-data" \
  OHANA_CI_TEST_RESULT_ROOT="$temp_root/unit-results" \
  "$repo_root/scripts/ci-run-unit-tests.sh" >/dev/null

if [[ "$(wc -l < "$fake_xcodebuild_log" | tr -d ' ')" == "4" ]] \
  && grep -q -- '-skip-testing:OhanaTests/AppResetServiceTests' "$fake_xcodebuild_log" \
  && grep -q -- '-only-testing:OhanaTests/AppResetServiceTests/testFirstResetPath' "$fake_xcodebuild_log" \
  && grep -q -- '-only-testing:OhanaTests/AppResetServiceTests/testSecondResetPath' "$fake_xcodebuild_log"; then
  pass "Unit CI builds once and isolates every discovered AppReset test"
else
  fail "Unit CI reset isolation lost coverage: $(tr '\n' ' ' < "$fake_xcodebuild_log")"
fi

if [[ "$failures" -ne 0 ]]; then
  echo "CI policy fixture tests failed: $failures" >&2
  exit 1
fi

echo "CI policy fixture tests passed."
