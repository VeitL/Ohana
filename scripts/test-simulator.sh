#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"
# shellcheck source=scripts/lib/xcode-storage-lifecycle.sh
source "${REPO_ROOT}/scripts/lib/xcode-storage-lifecycle.sh"
# shellcheck source=scripts/lib/test-build-provenance.sh
source "${REPO_ROOT}/scripts/lib/test-build-provenance.sh"

cd "${REPO_ROOT}"

export COPYFILE_DISABLE="${COPYFILE_DISABLE:-1}"

ORIGINAL_XCODEBUILD_ARGS=("$@")
BUILD_XCODEBUILD_ARGS=()
while IFS= read -r -d '' argument; do
  BUILD_XCODEBUILD_ARGS+=("${argument}")
done < <(
  ohana_test_build_provenance_filter_build_args \
    ${ORIGINAL_XCODEBUILD_ARGS[@]+"${ORIGINAL_XCODEBUILD_ARGS[@]}"}
)

if [[ -n "${SCHEME:-}" ]]; then
  SCHEME_SOURCE="explicit"
else
  SCHEME="$(
    "${REPO_ROOT}/scripts/resolve-test-scheme.sh" \
      ${ORIGINAL_XCODEBUILD_ARGS[@]+"${ORIGINAL_XCODEBUILD_ARGS[@]}"}
  )"
  SCHEME_SOURCE="automatic"
fi
SDK="${SDK:-iphonesimulator}"
CODE_SIGNING_ALLOWED_VALUE="${CODE_SIGNING_ALLOWED:-NO}"
TEST_ACTION="${OHANA_TEST_ACTION:-build-then-test}"
TEST_CODE_COVERAGE="${OHANA_TEST_CODE_COVERAGE:-NO}"
TEST_PARALLEL_ENABLED="${OHANA_TEST_PARALLEL_ENABLED:-NO}"
TEST_MAXIMUM_WORKERS="${OHANA_TEST_MAXIMUM_WORKERS:-1}"
RESULT_BUNDLE_PATH=""
STRIP_XATTRS_SCRIPT="${REPO_ROOT}/scripts/strip-build-xattrs.sh"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${OHANA_TEST_DERIVED_DATA_ROOT:-${OHANA_TEST_DERIVED_DATA_PATH}}}"
resolved_test_udid=""
PROVENANCE_SOURCE_HASH=""
PROVENANCE_FIELDS=()
pre_available_kib=0
pre_derived_kib=0
pre_results_kib=0
TEST_SIMULATOR_SHUTDOWN_DONE=0

case "${TEST_ACTION}" in
  build-then-test|build-for-testing|test-without-building)
    ;;
  test)
    echo "OHANA_TEST_ACTION=test is no longer supported because it mixes building and execution." >&2
    echo "Use build-then-test (default), build-for-testing, or test-without-building." >&2
    exit 2
    ;;
  *)
    echo "Unsupported OHANA_TEST_ACTION=${TEST_ACTION}." >&2
    echo "Allowed actions: build-then-test, build-for-testing, test-without-building." >&2
    exit 2
    ;;
esac

if [[ "${SDK}" != "iphonesimulator" ]]; then
  echo "Refusing to test with SDK=${SDK}. Use iphonesimulator." >&2
  exit 2
fi

case "${TEST_CODE_COVERAGE}" in
  YES|NO) ;;
  *)
    echo "OHANA_TEST_CODE_COVERAGE must be YES or NO." >&2
    exit 2
    ;;
esac
case "${TEST_PARALLEL_ENABLED}:${TEST_MAXIMUM_WORKERS}" in
  NO:1) ;;
  YES:[1-9]|YES:[1-9][0-9]*)
    if [[ "${OHANA_ALLOW_PARALLEL_TESTING:-0}" != "1" ]]; then
      echo "Parallel testing requires explicit OHANA_ALLOW_PARALLEL_TESTING=1." >&2
      exit 2
    fi
    ;;
  *)
    echo "Local tests default to parallel testing off and one worker." >&2
    echo "Set OHANA_ALLOW_PARALLEL_TESTING=1 with a positive worker count to opt in." >&2
    exit 2
    ;;
esac

for ((argument_index = 0; argument_index < ${#ORIGINAL_XCODEBUILD_ARGS[@]}; argument_index++)); do
  argument="${ORIGINAL_XCODEBUILD_ARGS[argument_index]}"
  case "${argument}" in
    -test-iterations|-retry-tests-on-failure|-run-tests-until-failure)
      if [[ "${OHANA_ALLOW_TEST_REPETITION:-0}" != "1" ]]; then
        echo "Test repetition is off by default; ${argument} requires OHANA_ALLOW_TEST_REPETITION=1." >&2
        exit 2
      fi
      ;;
    -enableCodeCoverage|-parallel-testing-enabled|-maximum-parallel-testing-workers)
      echo "Do not pass ${argument} directly." >&2
      echo "Use the governed OHANA_TEST_CODE_COVERAGE or OHANA_TEST_PARALLEL_* controls." >&2
      exit 2
      ;;
  esac
done

ohana_assert_fixed_derived_data_path tests "${DERIVED_DATA_PATH}"
DERIVED_DATA_PATH="${OHANA_TEST_DERIVED_DATA_PATH}"
PROVENANCE_STAMP_PATH="${DERIVED_DATA_PATH}/.ohana-test-build-provenance-v1.json"

destination_udid() {
  local destination="$1"
  if [[ "${destination}" =~ (^|,)id=([^,]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

resolve_test_destination() {
  local resolved=""

  if [[ -n "${OHANA_SIMULATOR_UDID:-}" ]]; then
    echo "Refusing shared OHANA_SIMULATOR_UDID for automated tests." >&2
    echo "Use OHANA_TEST_SIMULATOR_UDID; it must identify '${OHANA_TEST_SIMULATOR_NAME_FIXED}'." >&2
    return 2
  fi

  if [[ -n "${OHANA_SIMULATOR_NAME:-}" && "${OHANA_SIMULATOR_NAME}" != "${OHANA_TEST_SIMULATOR_NAME_FIXED}" ]]; then
    echo "Refusing automated test simulator name '${OHANA_SIMULATOR_NAME}'." >&2
    echo "Required device: ${OHANA_TEST_SIMULATOR_NAME_FIXED}." >&2
    return 2
  fi

  if [[ -n "${DESTINATION:-}" ]]; then
    if [[ "${DESTINATION}" != platform=iOS\ Simulator,* ]]; then
      echo "Refusing to test destination: ${DESTINATION}" >&2
      echo "This script only tests on an explicit iOS Simulator id." >&2
      return 2
    fi
    resolved="$(destination_udid "${DESTINATION}" || true)"
    if [[ -z "${resolved}" ]]; then
      echo "Refusing name-only or generic test destination: ${DESTINATION}" >&2
      echo "Use the dedicated '${OHANA_TEST_SIMULATOR_NAME_FIXED}' device or an explicit id." >&2
      return 2
    fi
  elif [[ -n "${OHANA_TEST_SIMULATOR_UDID:-}" ]]; then
    resolved="${OHANA_TEST_SIMULATOR_UDID}"
  else
    resolved="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}" || true)"
    if [[ -z "${resolved}" ]]; then
      echo "Simulator preflight failed: no available '${OHANA_TEST_SIMULATOR_NAME_FIXED}' device." >&2
      echo "After reclaiming at least ${OHANA_MINIMUM_FREE_GIB} GiB, run scripts/prepare-test-simulator.sh." >&2
      OHANA_SIMULATOR_NAME="${OHANA_TEST_SIMULATOR_NAME_FIXED}" \
        "${REPO_ROOT}/scripts/diagnose-simulator.sh" --brief >&2 || true
      return 70
    fi
  fi

  ohana_assert_test_simulator_udid "${resolved}" || return
  resolved_test_udid="${resolved}"
  DESTINATION="platform=iOS Simulator,id=${resolved}"
  echo "Test Simulator: ${OHANA_TEST_SIMULATOR_NAME_FIXED} (${resolved})"
}

cleanup() {
  local exit_status=$?
  set +e
  if [[ -n "${RESULT_BUNDLE_PATH}" ]]; then
    ohana_finalize_managed_result_bundle "${exit_status}" "${RESULT_BUNDLE_PATH}"
    RESULT_BUNDLE_PATH=""
  fi
  shutdown_test_simulator
  ohana_release_xcode_project_lock
}
trap cleanup EXIT

shutdown_test_simulator() {
  [[ "${TEST_SIMULATOR_SHUTDOWN_DONE}" == "0" ]] || return 0
  [[ -n "${resolved_test_udid}" ]] || return 0
  case "${OHANA_KEEP_TEST_SIMULATOR_BOOTED:-0}" in
    0)
      xcrun simctl shutdown "${resolved_test_udid}" >/dev/null 2>&1 || true
      echo "Test Simulator left shutdown: ${OHANA_TEST_SIMULATOR_NAME_FIXED} (${resolved_test_udid})"
      ;;
    1)
      echo "Explicitly leaving the Tests Simulator booted."
      ;;
    *)
      echo "OHANA_KEEP_TEST_SIMULATOR_BOOTED must be 0 or 1." >&2
      return 2
      ;;
  esac
  TEST_SIMULATOR_SHUTDOWN_DONE=1
}

sanitize_derived_data_products() {
  local products_dir="${DERIVED_DATA_PATH}/Build/Products"
  if [[ -x "${STRIP_XATTRS_SCRIPT}" && -d "${products_dir}" ]]; then
    "${STRIP_XATTRS_SCRIPT}" "${products_dir}" || true
  fi
}

provenance_input_scope() {
  case "${SCHEME}" in
    OhanaUITests)
      printf '%s\n' "app+ui"
      ;;
    OhanaUnitTests)
      printf '%s\n' "app+unit"
      ;;
    *)
      printf '%s\n' "app+unit+ui"
      ;;
  esac
}

refresh_test_build_provenance_contract() {
  local input_scope
  local source_paths=(
    Ohana
    Ohana.xcodeproj
    scripts/test-simulator.sh
    scripts/resolve-test-scheme.sh
    scripts/strip-build-xattrs.sh
    scripts/lib/local-build-environment.sh
    scripts/lib/xcode-storage-lifecycle.sh
    scripts/lib/test-build-provenance.sh
  )
  input_scope="$(provenance_input_scope)"
  case "${input_scope}" in
    app+ui)
      source_paths+=(OhanaUITests)
      ;;
    app+unit)
      source_paths+=(OhanaTests)
      ;;
    *)
      source_paths+=(OhanaTests OhanaUITests)
      ;;
  esac

  PROVENANCE_SOURCE_HASH="$(
    ohana_test_build_provenance_hash_inputs "${REPO_ROOT}" "${source_paths[@]}"
  )" || return

  local build_args_hash
  local developer_dir
  local sdk_version
  local sdk_build_version
  local xcode_version_hash
  build_args_hash="$(
    ohana_test_build_provenance_build_args_sha256 \
      ${BUILD_XCODEBUILD_ARGS[@]+"${BUILD_XCODEBUILD_ARGS[@]}"}
  )" || return
  developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}" || return
  developer_dir="$(cd "${developer_dir}" && pwd -P)" || return
  sdk_version="$(xcrun --sdk "${SDK}" --show-sdk-version)" || return
  sdk_build_version="$(xcrun --sdk "${SDK}" --show-sdk-build-version)" || return
  xcode_version_hash="$(xcodebuild -version | shasum -a 256 | awk '{print $1}')" || return

  PROVENANCE_FIELDS=(
    "project=Ohana.xcodeproj"
    "scheme=${SCHEME}"
    "sdk_name=${SDK}"
    "sdk_version=${sdk_version}"
    "sdk_build_version=${sdk_build_version}"
    "developer_dir=${developer_dir}"
    "xcode_version_sha256=${xcode_version_hash}"
    "destination_udid=${resolved_test_udid}"
    "code_signing_allowed=${CODE_SIGNING_ALLOWED_VALUE}"
    "code_coverage=${TEST_CODE_COVERAGE}"
    "parallel_testing=${TEST_PARALLEL_ENABLED}"
    "maximum_workers=${TEST_MAXIMUM_WORKERS}"
    "copyfile_disable=${COPYFILE_DISABLE}"
    "build_args_sha256=${build_args_hash}"
    "input_scope=${input_scope}"
    "source_tree_sha256=${PROVENANCE_SOURCE_HASH}"
  )
}

has_scheme_test_products() {
  local products_dir="${DERIVED_DATA_PATH}/Build/Products"
  [[ -d "${products_dir}" ]] || return 1
  find "${products_dir}" -maxdepth 1 -type f -name "${SCHEME}_*.xctestrun" -print -quit \
    | grep -q .
}

stamp_successful_test_build() {
  local source_hash_before_build="$1"
  refresh_test_build_provenance_contract || return
  if [[ "${PROVENANCE_SOURCE_HASH}" != "${source_hash_before_build}" ]]; then
    echo "Build inputs changed while build-for-testing was running." >&2
    echo "Refusing to stamp potentially mixed products; rerun after edits settle." >&2
    return 75
  fi
  if ! has_scheme_test_products; then
    echo "build-for-testing succeeded but no ${SCHEME} xctestrun product was found." >&2
    echo "Refusing to stamp an incomplete fixed tests cache." >&2
    return 66
  fi
  ohana_test_build_provenance_write_stamp \
    "${PROVENANCE_STAMP_PATH}" \
    "${PROVENANCE_FIELDS[@]}" >/dev/null
}

validate_test_build_provenance() {
  if ! has_scheme_test_products; then
    echo "Fixed tests cache has no ${SCHEME} test products." >&2
    echo "Run this request with OHANA_TEST_ACTION=build-then-test." >&2
    return 66
  fi
  refresh_test_build_provenance_contract || return
  ohana_test_build_provenance_validate_stamp \
    "${PROVENANCE_STAMP_PATH}" \
    "${PROVENANCE_FIELDS[@]}"
}

resolve_test_destination
ohana_require_build_disk_space
ohana_acquire_xcode_project_lock "tests:${SCHEME}:${TEST_ACTION}"
mkdir -p "${DERIVED_DATA_PATH}"
RESULT_BUNDLE_PATH="$(ohana_prepare_managed_result_bundle "${SCHEME}-${TEST_ACTION}")"
pre_available_kib="$(ohana_available_disk_kib)"
pre_derived_kib="$(ohana_path_size_kib "${DERIVED_DATA_PATH}")"
pre_results_kib="$(ohana_path_size_kib "${OHANA_TEST_RESULT_ROOT}")"

ohana_quiesce_test_simulator_companion_apps "${resolved_test_udid}"

echo "Xcode action: ${TEST_ACTION} (${SCHEME})"
if [[ "${SCHEME_SOURCE}" == "automatic" ]]; then
  echo "Scheme routing: selected ${SCHEME} from the requested test selectors."
fi
echo "SDK: ${SDK}"
echo "Destination: ${DESTINATION}"
echo "DerivedData: ${DERIVED_DATA_PATH}"
echo "Code signing: CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED_VALUE}"
echo "Code coverage: ${TEST_CODE_COVERAGE}"
echo "Parallel testing: ${TEST_PARALLEL_ENABLED} (workers ${TEST_MAXIMUM_WORKERS})"
echo "Managed result bundle: ${RESULT_BUNDLE_PATH}"
echo "Storage before: free $(ohana_format_kib_as_gib "${pre_available_kib}"), DerivedData $(ohana_format_kib_human "${pre_derived_kib}"), results $(ohana_format_kib_human "${pre_results_kib}")"

sanitize_derived_data_products

run_xcodebuild_action() {
  local action="$1"
  local include_result_bundle="$2"
  local xcodebuild_args=(
    -project Ohana.xcodeproj
    -scheme "${SCHEME}"
    -sdk "${SDK}"
    -destination "${DESTINATION}"
    -derivedDataPath "${DERIVED_DATA_PATH}"
    -disableAutomaticPackageResolution
    -skipPackagePluginValidation
    -enableCodeCoverage "${TEST_CODE_COVERAGE}"
    -parallel-testing-enabled "${TEST_PARALLEL_ENABLED}"
    -maximum-parallel-testing-workers "${TEST_MAXIMUM_WORKERS}"
    CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED_VALUE}"
    "${action}"
  )

  if [[ "${include_result_bundle}" == "1" ]]; then
    xcodebuild_args+=(
      -resultBundlePath "${RESULT_BUNDLE_PATH}"
    )
  fi
  if [[ $# -gt 2 ]]; then
    shift 2
    xcodebuild_args+=("$@")
  fi

  xcodebuild "${xcodebuild_args[@]}"
}

source_hash_before_test=""
set +e
case "${TEST_ACTION}" in
  build-then-test)
    echo "Building test products once..."
    ohana_test_build_provenance_invalidate_stamp "${PROVENANCE_STAMP_PATH}"
    refresh_test_build_provenance_contract
    test_status=$?
    source_hash_before_build="${PROVENANCE_SOURCE_HASH}"
    if [[ "${test_status}" == "0" ]]; then
      run_xcodebuild_action build-for-testing 0 \
        ${BUILD_XCODEBUILD_ARGS[@]+"${BUILD_XCODEBUILD_ARGS[@]}"}
      test_status=$?
    fi
    if [[ "${test_status}" == "0" ]]; then
      stamp_successful_test_build "${source_hash_before_build}"
      test_status=$?
    fi
    if [[ "${test_status}" == "0" ]]; then
      source_hash_before_test="${PROVENANCE_SOURCE_HASH}"
      sanitize_derived_data_products
      echo "Running tests without rebuilding..."
      run_xcodebuild_action test-without-building 1 \
        ${ORIGINAL_XCODEBUILD_ARGS[@]+"${ORIGINAL_XCODEBUILD_ARGS[@]}"}
      test_status=$?
    fi
    ;;
  build-for-testing)
    ohana_test_build_provenance_invalidate_stamp "${PROVENANCE_STAMP_PATH}"
    refresh_test_build_provenance_contract
    test_status=$?
    source_hash_before_build="${PROVENANCE_SOURCE_HASH}"
    if [[ "${test_status}" == "0" ]]; then
      run_xcodebuild_action build-for-testing 1 \
        ${BUILD_XCODEBUILD_ARGS[@]+"${BUILD_XCODEBUILD_ARGS[@]}"}
      test_status=$?
    fi
    if [[ "${test_status}" == "0" ]]; then
      stamp_successful_test_build "${source_hash_before_build}"
      test_status=$?
    fi
    ;;
  test-without-building)
    validate_test_build_provenance
    test_status=$?
    source_hash_before_test="${PROVENANCE_SOURCE_HASH}"
    if [[ "${test_status}" == "0" ]]; then
      run_xcodebuild_action test-without-building 1 \
        ${ORIGINAL_XCODEBUILD_ARGS[@]+"${ORIGINAL_XCODEBUILD_ARGS[@]}"}
      test_status=$?
    fi
    ;;
esac

if [[ "${TEST_ACTION}" != "build-for-testing" && -n "${source_hash_before_test}" ]]; then
  refresh_test_build_provenance_contract
  provenance_status=$?
  if [[ "${provenance_status}" != "0" ]]; then
    test_status="${provenance_status}"
  elif [[ "${PROVENANCE_SOURCE_HASH}" != "${source_hash_before_test}" ]]; then
    echo "Build inputs changed while tests were running." >&2
    echo "The xcresult was preserved, but it does not represent the current worktree." >&2
    test_status=75
  fi
fi
set -e

shutdown_test_simulator

set +e
ohana_finalize_managed_result_bundle "${test_status}" "${RESULT_BUNDLE_PATH}"
result_lifecycle_status=$?
RESULT_BUNDLE_PATH=""
if [[ "${test_status}" == "0" && "${result_lifecycle_status}" != "0" ]]; then
  test_status="${result_lifecycle_status}"
fi
set -e

sanitize_derived_data_products
post_available_kib="$(ohana_available_disk_kib)"
post_derived_kib="$(ohana_path_size_kib "${DERIVED_DATA_PATH}")"
post_results_kib="$(ohana_path_size_kib "${OHANA_TEST_RESULT_ROOT}")"
awk \
  -v before_free="${pre_available_kib}" \
  -v after_free="${post_available_kib}" \
  -v before_derived="${pre_derived_kib}" \
  -v after_derived="${post_derived_kib}" \
  -v before_results="${pre_results_kib}" \
  -v after_results="${post_results_kib}" \
  'BEGIN {
    printf "Storage after: free %.1f GiB (%+.1f MiB), DerivedData %.1f MiB (%+.1f MiB), results %.1f MiB (%+.1f MiB)\n",
      after_free / 1024 / 1024, (after_free - before_free) / 1024,
      after_derived / 1024, (after_derived - before_derived) / 1024,
      after_results / 1024, (after_results - before_results) / 1024
  }'
remaining_test_processes="$(
  {
    pgrep -x -l xcodebuild 2>/dev/null || true
    pgrep -x -l xctest 2>/dev/null || true
  } | LC_ALL=C sort -u
)"
if [[ -n "${remaining_test_processes}" ]]; then
  echo "WARNING: Xcode test processes still visible after the action:" >&2
  printf '  %s\n' "${remaining_test_processes}" >&2
else
  echo "Residual xcodebuild/xctest processes: none"
fi
exit "${test_status}"
