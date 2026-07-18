#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"
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
RESULT_BUNDLE_PATH="${OHANA_RESULT_BUNDLE_PATH:-}"
STRIP_XATTRS_SCRIPT="${REPO_ROOT}/scripts/strip-build-xattrs.sh"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${OHANA_TEST_DERIVED_DATA_ROOT:-${OHANA_TEST_DERIVED_DATA_PATH}}}"
LOCK_ROOT="${REPO_ROOT}/.build/locks"
LOCK_DIR="${LOCK_ROOT}/lane-tests.lock"
LOCK_ACQUIRED=0
resolved_test_udid=""
PROVENANCE_SOURCE_HASH=""
PROVENANCE_FIELDS=()

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
  if [[ "${LOCK_ACQUIRED}" == "1" ]]; then
    rm -f "${LOCK_DIR}/pid"
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

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

if [[ -n "${RESULT_BUNDLE_PATH}" && -e "${RESULT_BUNDLE_PATH}" ]]; then
  echo "Refusing to overwrite existing result bundle: ${RESULT_BUNDLE_PATH}" >&2
  exit 2
fi

mkdir -p "${LOCK_ROOT}" "${DERIVED_DATA_PATH}"
while ! mkdir "${LOCK_DIR}" 2>/dev/null; do
  if [[ -f "${LOCK_DIR}/pid" ]]; then
    LOCK_PID="$(tr -d '[:space:]' < "${LOCK_DIR}/pid" 2>/dev/null || true)"
    if [[ -n "${LOCK_PID}" ]] && ! kill -0 "${LOCK_PID}" 2>/dev/null; then
      STALE_LOCK_DIR="${LOCK_DIR}.stale.$(date +%s).$$"
      echo "Test lock owner ${LOCK_PID} is gone; moving stale lock to ${STALE_LOCK_DIR}."
      mv "${LOCK_DIR}" "${STALE_LOCK_DIR}" 2>/dev/null || rm -rf "${LOCK_DIR}"
      continue
    fi
  else
    STALE_LOCK_DIR="${LOCK_DIR}.malformed.$(date +%s).$$"
    echo "Test lock is missing pid; moving malformed lock to ${STALE_LOCK_DIR}."
    mv "${LOCK_DIR}" "${STALE_LOCK_DIR}" 2>/dev/null || rm -rf "${LOCK_DIR}"
    continue
  fi
  echo "Another build or test is already using the fixed tests cache."
  echo "Waiting on lock: ${LOCK_DIR}"
  sleep 2
done
LOCK_ACQUIRED=1
printf '%s\n' "$$" > "${LOCK_DIR}/pid"

ohana_quiesce_test_simulator_companion_apps "${resolved_test_udid}"

if [[ -n "${RESULT_BUNDLE_PATH}" ]]; then
  mkdir -p "$(dirname "${RESULT_BUNDLE_PATH}")"
fi

echo "Xcode action: ${TEST_ACTION} (${SCHEME})"
if [[ "${SCHEME_SOURCE}" == "automatic" ]]; then
  echo "Scheme routing: selected ${SCHEME} from the requested test selectors."
fi
echo "SDK: ${SDK}"
echo "Destination: ${DESTINATION}"
echo "DerivedData: ${DERIVED_DATA_PATH}"
echo "Code signing: CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED_VALUE}"
if [[ -n "${RESULT_BUNDLE_PATH}" ]]; then
  echo "Result bundle: ${RESULT_BUNDLE_PATH}"
fi

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
    CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED_VALUE}"
    "${action}"
  )

  if [[ "${include_result_bundle}" == "1" && -n "${RESULT_BUNDLE_PATH}" ]]; then
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

sanitize_derived_data_products
exit "${test_status}"
