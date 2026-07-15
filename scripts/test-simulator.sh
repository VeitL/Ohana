#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

cd "${REPO_ROOT}"

export COPYFILE_DISABLE="${COPYFILE_DISABLE:-1}"

if [[ -n "${SCHEME:-}" ]]; then
  SCHEME_SOURCE="explicit"
else
  SCHEME="$("${REPO_ROOT}/scripts/resolve-test-scheme.sh" "$@")"
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

set +e
case "${TEST_ACTION}" in
  build-then-test)
    echo "Building test products once..."
    run_xcodebuild_action build-for-testing 0 "$@"
    test_status=$?
    if [[ "${test_status}" == "0" ]]; then
      sanitize_derived_data_products
      echo "Running tests without rebuilding..."
      run_xcodebuild_action test-without-building 1 "$@"
      test_status=$?
    fi
    ;;
  build-for-testing)
    run_xcodebuild_action build-for-testing 1 "$@"
    test_status=$?
    ;;
  test-without-building)
    if [[ ! -d "${DERIVED_DATA_PATH}/Build/Products" ]]; then
      echo "Fixed tests cache has no built products. Run build-for-testing first." >&2
      test_status=66
    else
      run_xcodebuild_action test-without-building 1 "$@"
      test_status=$?
    fi
    ;;
esac
set -e

sanitize_derived_data_products
exit "${test_status}"
