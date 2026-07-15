#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

cd "${REPO_ROOT}"

export COPYFILE_DISABLE="${COPYFILE_DISABLE:-1}"
STRIP_XATTRS_SCRIPT="${REPO_ROOT}/scripts/strip-build-xattrs.sh"

SCHEME="${SCHEME:-Ohana}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SDK="${SDK:-iphonesimulator}"
CODE_SIGNING_ALLOWED_VALUE="${CODE_SIGNING_ALLOWED:-NO}"
SWIFT_COMPILATION_MODE_VALUE="${OHANA_SWIFT_COMPILATION_MODE:-}"
SWIFT_OPTIMIZATION_LEVEL_VALUE="${OHANA_SWIFT_OPTIMIZATION_LEVEL:-}"
COMPILER_INDEX_STORE_ENABLE_VALUE="${OHANA_COMPILER_INDEX_STORE_ENABLE:-}"
BUILD_LANE="${OHANA_BUILD_LANE:-tests}"
EXPECTED_DERIVED_DATA_PATH="$(ohana_expected_derived_data_path "${BUILD_LANE}")"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${EXPECTED_DERIVED_DATA_PATH}}"
LOCK_ROOT="${REPO_ROOT}/.build/locks"
LOCK_DIR="${LOCK_ROOT}/lane-${BUILD_LANE}.lock"
LOCK_ACQUIRED=0

case "${SWIFT_COMPILATION_MODE_VALUE}" in
  ""|incremental|wholemodule)
    ;;
  *)
    echo "Unsupported OHANA_SWIFT_COMPILATION_MODE=${SWIFT_COMPILATION_MODE_VALUE}." >&2
    echo "Expected incremental, wholemodule, or an empty value." >&2
    exit 2
    ;;
esac

case "${SWIFT_OPTIMIZATION_LEVEL_VALUE}" in
  ""|-Onone|-O|-Osize)
    ;;
  *)
    echo "Unsupported OHANA_SWIFT_OPTIMIZATION_LEVEL=${SWIFT_OPTIMIZATION_LEVEL_VALUE}." >&2
    echo "Expected -Onone, -O, -Osize, or an empty value." >&2
    exit 2
    ;;
esac

case "${COMPILER_INDEX_STORE_ENABLE_VALUE}" in
  ""|YES|NO)
    ;;
  *)
    echo "Unsupported OHANA_COMPILER_INDEX_STORE_ENABLE=${COMPILER_INDEX_STORE_ENABLE_VALUE}." >&2
    echo "Expected YES, NO, or an empty value." >&2
    exit 2
    ;;
esac

if [[ "${SDK}" != "iphonesimulator" ]]; then
  echo "Refusing to build with SDK=${SDK}. Use iphonesimulator." >&2
  exit 2
fi

ohana_assert_fixed_derived_data_path "${BUILD_LANE}" "${DERIVED_DATA_PATH}"
DERIVED_DATA_PATH="${EXPECTED_DERIVED_DATA_PATH}"

destination_udid() {
  local destination="$1"
  if [[ "${destination}" =~ (^|,)id=([^,]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

resolve_build_destination() {
  local selected_udid=""

  case "${BUILD_LANE}" in
    release)
      if [[ -n "${DESTINATION:-}" && "${DESTINATION}" != "generic/platform=iOS Simulator" ]]; then
        echo "Release compiler validation uses generic/platform=iOS Simulator, not ${DESTINATION}." >&2
        return 2
      fi
      DESTINATION="generic/platform=iOS Simulator"
      ;;
    tests)
      if [[ -n "${OHANA_SIMULATOR_UDID:-}" ]]; then
        echo "Refusing shared OHANA_SIMULATOR_UDID in the tests build lane." >&2
        echo "Use OHANA_TEST_SIMULATOR_UDID for '${OHANA_TEST_SIMULATOR_NAME_FIXED}'." >&2
        return 2
      fi
      if [[ -n "${DESTINATION:-}" ]]; then
        selected_udid="$(destination_udid "${DESTINATION}" || true)"
        if [[ -z "${selected_udid}" ]]; then
          echo "Tests builds require an explicit Simulator id." >&2
          return 2
        fi
      elif [[ -n "${OHANA_TEST_SIMULATOR_UDID:-}" ]]; then
        selected_udid="${OHANA_TEST_SIMULATOR_UDID}"
      else
        selected_udid="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}" || true)"
      fi
      if [[ -z "${selected_udid}" ]]; then
        echo "No available '${OHANA_TEST_SIMULATOR_NAME_FIXED}' device." >&2
        echo "After reclaiming at least ${OHANA_MINIMUM_FREE_GIB} GiB, run scripts/prepare-test-simulator.sh." >&2
        return 70
      fi
      ohana_assert_test_simulator_udid "${selected_udid}" || return
      DESTINATION="platform=iOS Simulator,id=${selected_udid}"
      ;;
    dogfood)
      if [[ -n "${DESTINATION:-}" ]]; then
        selected_udid="$(destination_udid "${DESTINATION}" || true)"
      else
        selected_udid="${OHANA_DOGFOOD_SIMULATOR_UDID:-}"
      fi
      if [[ -z "${selected_udid}" ]]; then
        selected_udid="$(ohana_pinned_dogfood_udid || true)"
      fi
      if [[ -z "${selected_udid}" ]]; then
        echo "Dogfood build lane requires the pinned Dogfood Simulator." >&2
        return 2
      fi
      ohana_assert_dogfood_simulator_udid "${selected_udid}" || return
      DESTINATION="platform=iOS Simulator,id=${selected_udid}"
      ;;
  esac
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

resolve_build_destination
ohana_require_build_disk_space

mkdir -p "${LOCK_ROOT}" "${DERIVED_DATA_PATH}"
while ! mkdir "${LOCK_DIR}" 2>/dev/null; do
  if [[ -f "${LOCK_DIR}/pid" ]]; then
    LOCK_PID="$(tr -d '[:space:]' < "${LOCK_DIR}/pid" 2>/dev/null || true)"
    if [[ -n "${LOCK_PID}" ]] && ! kill -0 "${LOCK_PID}" 2>/dev/null; then
      STALE_LOCK_DIR="${LOCK_DIR}.stale.$(date +%s).$$"
      echo "Build lock owner ${LOCK_PID} is gone; moving stale lock to ${STALE_LOCK_DIR}."
      mv "${LOCK_DIR}" "${STALE_LOCK_DIR}" 2>/dev/null || rm -rf "${LOCK_DIR}"
      continue
    fi
  else
    STALE_LOCK_DIR="${LOCK_DIR}.malformed.$(date +%s).$$"
    echo "Build lock is missing pid; moving malformed lock to ${STALE_LOCK_DIR}."
    mv "${LOCK_DIR}" "${STALE_LOCK_DIR}" 2>/dev/null || rm -rf "${LOCK_DIR}"
    continue
  fi
  echo "Another ${BUILD_LANE} build is already using its fixed cache."
  echo "Waiting on lock: ${LOCK_DIR}"
  sleep 2
done
LOCK_ACQUIRED=1
printf '%s\n' "$$" > "${LOCK_DIR}/pid"

echo "Building ${SCHEME} (${CONFIGURATION})"
echo "Build lane: ${BUILD_LANE}"
echo "SDK: ${SDK}"
echo "Destination: ${DESTINATION}"
echo "DerivedData: ${DERIVED_DATA_PATH}"
echo "Code signing: CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED_VALUE}"
if [[ -n "${SWIFT_COMPILATION_MODE_VALUE}" ]]; then
  echo "Swift compilation mode: ${SWIFT_COMPILATION_MODE_VALUE}"
fi
if [[ -n "${SWIFT_OPTIMIZATION_LEVEL_VALUE}" ]]; then
  echo "Swift optimization: ${SWIFT_OPTIMIZATION_LEVEL_VALUE}"
fi
if [[ -n "${COMPILER_INDEX_STORE_ENABLE_VALUE}" ]]; then
  echo "Index store: COMPILER_INDEX_STORE_ENABLE=${COMPILER_INDEX_STORE_ENABLE_VALUE}"
fi

sanitize_derived_data_products

xcodebuild_settings=(
  "CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED_VALUE}"
)
if [[ -n "${SWIFT_COMPILATION_MODE_VALUE}" ]]; then
  xcodebuild_settings+=("SWIFT_COMPILATION_MODE=${SWIFT_COMPILATION_MODE_VALUE}")
fi
if [[ -n "${SWIFT_OPTIMIZATION_LEVEL_VALUE}" ]]; then
  xcodebuild_settings+=("SWIFT_OPTIMIZATION_LEVEL=${SWIFT_OPTIMIZATION_LEVEL_VALUE}")
fi
if [[ -n "${COMPILER_INDEX_STORE_ENABLE_VALUE}" ]]; then
  xcodebuild_settings+=("COMPILER_INDEX_STORE_ENABLE=${COMPILER_INDEX_STORE_ENABLE_VALUE}")
fi

set +e
xcodebuild \
  -project Ohana.xcodeproj \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk "${SDK}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -disableAutomaticPackageResolution \
  -skipPackagePluginValidation \
  -showBuildTimingSummary \
  "${xcodebuild_settings[@]}" \
  build
build_status=$?
set -e

sanitize_derived_data_products
exit "${build_status}"
