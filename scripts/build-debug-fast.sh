#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

export COPYFILE_DISABLE="${COPYFILE_DISABLE:-1}"

SCHEME="${SCHEME:-Ohana}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SDK="${SDK:-iphonesimulator}"
REQUIRED_DESTINATION="platform=iOS Simulator,name=iPhone 17"
DESTINATION="${DESTINATION:-${REQUIRED_DESTINATION}}"
BRANCH_NAME="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
if [[ "${BRANCH_NAME}" == "HEAD" ]]; then
  BRANCH_NAME="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo detached)"
fi
SAFE_BRANCH="$(printf '%s' "${BRANCH_NAME}" | tr -c '[:alnum:]_.-' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//')"
WORKTREE_HASH="$(printf '%s' "${REPO_ROOT}" | shasum -a 256 | awk '{ print substr($1, 1, 12) }')"
BUILD_ID="${SAFE_BRANCH:-detached}-${WORKTREE_HASH}"
DEFAULT_DERIVED_DATA_ROOT="${OHANA_DERIVED_DATA_ROOT:-${REPO_ROOT}/.build/DerivedData}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${DEFAULT_DERIVED_DATA_ROOT}/${BUILD_ID}}"
LOCK_ROOT="${LOCK_ROOT:-${REPO_ROOT}/.build/locks}"
LOCK_DIR="${LOCK_DIR:-${LOCK_ROOT}/build-${BUILD_ID}.lock}"
LOCK_ACQUIRED=0

if [[ "${SDK}" != "iphonesimulator" ]]; then
  echo "Refusing to build with SDK=${SDK}. Use the fixed simulator SDK: iphonesimulator." >&2
  exit 2
fi

if [[ "${DESTINATION}" != "${REQUIRED_DESTINATION}" ]]; then
  echo "Refusing to build destination: ${DESTINATION}" >&2
  echo "Use the fixed simulator destination: ${REQUIRED_DESTINATION}" >&2
  exit 2
fi

cleanup() {
  if [[ "${LOCK_ACQUIRED}" == "1" ]]; then
    rm -f "${LOCK_DIR}/pid"
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

mkdir -p "${LOCK_ROOT}" "$(dirname "${DERIVED_DATA_PATH}")"
while ! mkdir "${LOCK_DIR}" 2>/dev/null; do
  if [[ -f "${LOCK_DIR}/pid" ]]; then
    LOCK_PID="$(cat "${LOCK_DIR}/pid" 2>/dev/null || true)"
    if [[ -n "${LOCK_PID}" ]] && ! kill -0 "${LOCK_PID}" 2>/dev/null; then
      rm -rf "${LOCK_DIR}"
      continue
    fi
  fi
  echo "Another build is already running for this worktree/branch."
  echo "Waiting on lock: ${LOCK_DIR}"
  sleep 2
done
LOCK_ACQUIRED=1
printf '%s\n' "$$" > "${LOCK_DIR}/pid"

echo "Building ${SCHEME} (${CONFIGURATION})"
echo "SDK: ${SDK}"
echo "Destination: ${DESTINATION}"
echo "DerivedData: ${DERIVED_DATA_PATH}"

if [[ "${OHANA_SKIP_SIMULATOR_PREFLIGHT:-0}" != "1" ]]; then
  SIMCTL_OUTPUT="$(
    xcrun simctl list devices available 2>&1
  )" || {
    echo "Simulator preflight failed: CoreSimulator is not available." >&2
    echo "The fixed build destination is still required: ${REQUIRED_DESTINATION}" >&2
    echo "simctl output:" >&2
    printf '%s\n' "${SIMCTL_OUTPUT}" >&2
    echo "Try opening Xcode > Settings > Platforms, installing the iOS simulator runtime, and creating an iPhone 17 simulator." >&2
    echo "If you are intentionally bypassing this preflight, set OHANA_SKIP_SIMULATOR_PREFLIGHT=1." >&2
    exit 70
  }

  if ! printf '%s\n' "${SIMCTL_OUTPUT}" | grep -Eq '^[[:space:]]+iPhone 17 \('; then
    echo "Simulator preflight failed: no available iPhone 17 simulator was found." >&2
    echo "The fixed build destination is required: ${REQUIRED_DESTINATION}" >&2
    echo "Available iPhone simulators:" >&2
    printf '%s\n' "${SIMCTL_OUTPUT}" | grep -E '^[[:space:]]+iPhone' >&2 || true
    echo "Create an iPhone 17 simulator in Xcode > Devices and Simulators, then rerun this script." >&2
    echo "If you are intentionally bypassing this preflight, set OHANA_SKIP_SIMULATOR_PREFLIGHT=1." >&2
    exit 70
  fi
fi

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
  build
