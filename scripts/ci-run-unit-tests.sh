#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHANA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

xcodebuild_bin="${OHANA_XCODEBUILD_BIN:-xcodebuild}"
derived_data_path="${OHANA_CI_DERIVED_DATA_PATH:-${RUNNER_TEMP:-$repo_root/.build}/DerivedData}"
result_root="${OHANA_CI_TEST_RESULT_ROOT:-${RUNNER_TEMP:-$repo_root/.build}}"
reset_test_source="${OHANA_APP_RESET_TEST_SOURCE:-OhanaTests/AppResetServiceTests.swift}"
destination="${OHANA_CI_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

if ! command -v "$xcodebuild_bin" >/dev/null 2>&1; then
  echo "error: xcodebuild executable is unavailable: $xcodebuild_bin" >&2
  exit 2
fi
if [[ ! -f "$reset_test_source" ]]; then
  echo "error: isolated reset-test source is missing: $reset_test_source" >&2
  exit 2
fi

mkdir -p "$derived_data_path" "$result_root"

common_args=(
  -project Ohana.xcodeproj
  -scheme OhanaUnitTests
  -configuration Debug
  -sdk iphonesimulator
  -destination "$destination"
  -derivedDataPath "$derived_data_path"
  -disableAutomaticPackageResolution
  -skipPackagePluginValidation
  -enableCodeCoverage NO
  -quiet
)

echo "Building unit-test products once."
"$xcodebuild_bin" build-for-testing \
  "${common_args[@]}" \
  -only-testing:OhanaTests \
  CODE_SIGNING_ALLOWED=NO

test_without_building() {
  local result_path="$1"
  shift
  rm -rf "$result_path"
  "$xcodebuild_bin" test-without-building \
    "${common_args[@]}" \
    -resultBundlePath "$result_path" \
    "$@" \
    CODE_SIGNING_ALLOWED=NO
}

set +e
echo "Running the main unit suite without the crash-prone reset class."
test_without_building \
  "$result_root/TestResults-main.xcresult" \
  -only-testing:OhanaTests \
  -skip-testing:OhanaTests/AppResetServiceTests
main_status=$?

isolated_status=0
isolated_count=0
while IFS= read -r test_name; do
  [[ -n "$test_name" ]] || continue
  isolated_count=$((isolated_count + 1))
  echo "Running isolated reset test: $test_name"
  test_without_building \
    "$result_root/TestResults-app-reset-${test_name}.xcresult" \
    -only-testing:"OhanaTests/AppResetServiceTests/${test_name}"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    isolated_status=$status
  fi
done < <(
  python3 - "$reset_test_source" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
for name in re.findall(r"^\s*func\s+(test[A-Za-z0-9_]+)\s*\(", source, flags=re.MULTILINE):
    print(name)
PY
)
set -e

if [[ "$isolated_count" -eq 0 ]]; then
  echo "error: no AppResetServiceTests methods were discovered for isolated execution." >&2
  exit 1
fi
if [[ "$main_status" -ne 0 || "$isolated_status" -ne 0 ]]; then
  echo "Unit tests failed: main=$main_status isolated-reset=$isolated_status" >&2
  exit 1
fi

echo "Unit tests passed: main suite plus $isolated_count isolated reset test(s)."
