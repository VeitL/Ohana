#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

export COPYFILE_DISABLE="${COPYFILE_DISABLE:-1}"

SCHEME="${SCHEME:-Ohana}"
SDK="${SDK:-iphonesimulator}"
CODE_SIGNING_ALLOWED_VALUE="${CODE_SIGNING_ALLOWED:-NO}"
REQUIRED_SIMULATOR_NAME="${OHANA_SIMULATOR_NAME:-iPhone 17}"
STRIP_XATTRS_SCRIPT="${REPO_ROOT}/scripts/strip-build-xattrs.sh"

BRANCH_NAME="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
if [[ "${BRANCH_NAME}" == "HEAD" ]]; then
  BRANCH_NAME="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo detached)"
fi
SAFE_BRANCH="$(printf '%s' "${BRANCH_NAME}" | tr -c '[:alnum:]_.-' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//')"
WORKTREE_HASH="$(printf '%s' "${REPO_ROOT}" | shasum -a 256 | awk '{ print substr($1, 1, 12) }')"
BUILD_ID="${SAFE_BRANCH:-detached}-${WORKTREE_HASH}-tests"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_ROOT="${TMP_ROOT%/}"
DEFAULT_DERIVED_DATA_ROOT="${OHANA_TEST_DERIVED_DATA_ROOT:-${TMP_ROOT}/OhanaDerivedData}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${DEFAULT_DERIVED_DATA_ROOT}/${BUILD_ID}}"
LOCK_ROOT="${LOCK_ROOT:-${REPO_ROOT}/.build/locks}"
LOCK_DIR="${LOCK_DIR:-${LOCK_ROOT}/test-${BUILD_ID}.lock}"
LOCK_ACQUIRED=0

if [[ "${SDK}" != "iphonesimulator" ]]; then
  echo "Refusing to test with SDK=${SDK}. Use the fixed simulator SDK: iphonesimulator." >&2
  exit 2
fi

if [[ -n "${DESTINATION:-}" && "${DESTINATION}" != platform=iOS\ Simulator,* ]]; then
  echo "Refusing to test destination: ${DESTINATION}" >&2
  echo "This script only tests on iOS Simulator destinations." >&2
  exit 2
fi

resolve_simulator_destination() {
  if [[ -n "${DESTINATION:-}" ]]; then
    return 0
  fi

  if [[ -n "${OHANA_SIMULATOR_UDID:-}" ]]; then
    DESTINATION="platform=iOS Simulator,id=${OHANA_SIMULATOR_UDID}"
    echo "Simulator: explicit OHANA_SIMULATOR_UDID=${OHANA_SIMULATOR_UDID}"
    return 0
  fi

  local simctl_json
  if ! simctl_json="$(xcrun simctl list devices available -j 2>/dev/null)"; then
    if [[ "${OHANA_SKIP_SIMULATOR_PREFLIGHT:-0}" == "1" ]]; then
      DESTINATION="platform=iOS Simulator,name=${REQUIRED_SIMULATOR_NAME}"
      echo "Simulator: CoreSimulator unavailable; falling back to name-based destination."
      return 0
    fi
    echo "Simulator preflight failed: CoreSimulator is not available." >&2
    "${REPO_ROOT}/scripts/diagnose-simulator.sh" --brief >&2 || true
    echo "If this only fails inside Codex, run the same test command in a normal Terminal or use CI for simulator proof." >&2
    exit 70
  fi

  local resolved
  resolved="$(
    printf '%s' "${simctl_json}" | python3 -c '
import json, re, sys

required_name = sys.argv[1]
data = json.load(sys.stdin)
candidates = []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    version = [int(part) for part in re.findall(r"\d+", runtime)]
    for device in devices:
        if device.get("name") == required_name and device.get("isAvailable"):
            candidates.append((version, device["udid"]))
if candidates:
    candidates.sort()
    print(candidates[-1][1])
' "${REQUIRED_SIMULATOR_NAME}"
  )" || resolved=""

  if [[ -z "${resolved}" ]]; then
    echo "Simulator preflight failed: no available simulator named '${REQUIRED_SIMULATOR_NAME}'." >&2
    "${REPO_ROOT}/scripts/diagnose-simulator.sh" --brief >&2 || true
    xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' >&2 || true
    exit 70
  fi

  DESTINATION="platform=iOS Simulator,id=${resolved}"
  echo "Simulator: resolved '${REQUIRED_SIMULATOR_NAME}' -> ${resolved} (newest installed runtime)"
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

resolve_simulator_destination

mkdir -p "${LOCK_ROOT}" "$(dirname "${DERIVED_DATA_PATH}")"
while ! mkdir "${LOCK_DIR}" 2>/dev/null; do
  if [[ -f "${LOCK_DIR}/pid" ]]; then
    LOCK_PID="$(cat "${LOCK_DIR}/pid" 2>/dev/null || true)"
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
  echo "Another test run is already running for this worktree/branch."
  echo "Waiting on lock: ${LOCK_DIR}"
  sleep 2
done
LOCK_ACQUIRED=1
printf '%s\n' "$$" > "${LOCK_DIR}/pid"

echo "Testing ${SCHEME}"
echo "SDK: ${SDK}"
echo "Destination: ${DESTINATION}"
echo "DerivedData: ${DERIVED_DATA_PATH}"
echo "Code signing: CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED_VALUE}"

sanitize_derived_data_products

set +e
xcodebuild \
  -project Ohana.xcodeproj \
  -scheme "${SCHEME}" \
  -sdk "${SDK}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -disableAutomaticPackageResolution \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED_VALUE}" \
  test \
  "$@"
test_status=$?
set -e

sanitize_derived_data_products
exit "${test_status}"
