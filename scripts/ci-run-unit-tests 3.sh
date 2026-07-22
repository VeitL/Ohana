#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHANA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

xcodebuild_bin="${OHANA_XCODEBUILD_BIN:-xcodebuild}"
derived_data_path="${OHANA_CI_DERIVED_DATA_PATH:-${RUNNER_TEMP:-$repo_root/.build}/DerivedData}"
result_root="${OHANA_CI_TEST_RESULT_ROOT:-${RUNNER_TEMP:-$repo_root/.build}}"
destination="${OHANA_CI_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

if ! command -v "$xcodebuild_bin" >/dev/null 2>&1; then
  echo "error: xcodebuild executable is unavailable: $xcodebuild_bin" >&2
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

result_path="$result_root/TestResults-main.xcresult"
rm -rf "$result_path"
echo "Running the complete unit suite once from the built products."
"$xcodebuild_bin" test-without-building \
  "${common_args[@]}" \
  -resultBundlePath "$result_path" \
  -only-testing:OhanaTests \
  CODE_SIGNING_ALLOWED=NO

echo "Unit tests passed."
