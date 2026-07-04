#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

SIMULATOR_NAME="${OHANA_DOGFOOD_SIMULATOR_NAME:-${OHANA_SIMULATOR_NAME:-iPhone 17}}"
PIN_FILE="${OHANA_DOGFOOD_SIMULATOR_PIN_FILE:-${REPO_ROOT}/.build/dogfood-simulator.udid}"
BUNDLE_ID="${OHANA_BUNDLE_ID:-com.guanchen.li.Ohana}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${OHANA_DOGFOOD_DERIVED_DATA_PATH:-${REPO_ROOT}/.build/DerivedData/dogfood}"
BUILD_BEFORE_LAUNCH=1

usage() {
  cat <<'USAGE'
Usage: scripts/run-dogfood-simulator.sh [--no-build] [--] [app launch args...]

Builds, installs, and launches Ohana on one pinned iOS Simulator without erasing
or uninstalling the app. The first resolved simulator UDID is saved under
.build/dogfood-simulator.udid so later runs keep using the same virtual phone.

Environment:
  OHANA_DOGFOOD_SIMULATOR_UDID       Explicit simulator UDID to pin
  OHANA_SIMULATOR_UDID               Shared simulator UDID override
  OHANA_DOGFOOD_SIMULATOR_NAME       Simulator name to resolve on first run
  OHANA_DOGFOOD_DERIVED_DATA_PATH    Stable dogfood build cache path
  OHANA_BUNDLE_ID                    App bundle id to launch
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --no-build)
      BUILD_BEFORE_LAUNCH=0
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

simulator_exists() {
  local udid="$1"
  xcrun simctl list devices available -j | python3 -c '
import json, sys

udid = sys.argv[1]
data = json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("udid") == udid and device.get("isAvailable"):
            print(device.get("name", "unknown"))
            raise SystemExit(0)
raise SystemExit(1)
' "${udid}"
}

resolve_simulator_by_name() {
  xcrun simctl list devices available -j | python3 -c '
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
            candidates.append((version, device["udid"], device["name"]))
if not candidates:
    raise SystemExit(1)
candidates.sort()
print(candidates[-1][1])
' "${SIMULATOR_NAME}"
}

choose_simulator_udid() {
  if [[ -n "${OHANA_DOGFOOD_SIMULATOR_UDID:-}" ]]; then
    printf '%s\n' "${OHANA_DOGFOOD_SIMULATOR_UDID}"
    return 0
  fi

  if [[ -n "${OHANA_SIMULATOR_UDID:-}" ]]; then
    printf '%s\n' "${OHANA_SIMULATOR_UDID}"
    return 0
  fi

  if [[ -f "${PIN_FILE}" ]]; then
    local pinned
    pinned="$(tr -d '[:space:]' < "${PIN_FILE}")"
    if [[ -n "${pinned}" ]] && simulator_exists "${pinned}" >/dev/null; then
      printf '%s\n' "${pinned}"
      return 0
    fi
    echo "Pinned dogfood simulator is unavailable; resolving '${SIMULATOR_NAME}' again." >&2
  fi

  local resolved
  if ! resolved="$(resolve_simulator_by_name)"; then
    echo "No available iOS Simulator named '${SIMULATOR_NAME}'." >&2
    echo "Create one in Xcode > Devices and Simulators, or set OHANA_DOGFOOD_SIMULATOR_UDID." >&2
    exit 70
  fi

  mkdir -p "$(dirname "${PIN_FILE}")"
  printf '%s\n' "${resolved}" > "${PIN_FILE}"
  printf '%s\n' "${resolved}"
}

SIMULATOR_UDID="$(choose_simulator_udid)"
SIMULATOR_DISPLAY_NAME="$(simulator_exists "${SIMULATOR_UDID}" || true)"
if [[ -z "${SIMULATOR_DISPLAY_NAME}" ]]; then
  echo "Pinned dogfood simulator '${SIMULATOR_UDID}' is not available." >&2
  exit 70
fi

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}-iphonesimulator/Ohana.app"

if [[ "${BUILD_BEFORE_LAUNCH}" == "1" ]]; then
  echo "Dogfood simulator: ${SIMULATOR_DISPLAY_NAME} (${SIMULATOR_UDID})"
  echo "DerivedData: ${DERIVED_DATA_PATH}"
  OHANA_SIMULATOR_UDID="${SIMULATOR_UDID}" \
    DERIVED_DATA_PATH="${DERIVED_DATA_PATH}" \
    CONFIGURATION="${CONFIGURATION}" \
    "${REPO_ROOT}/scripts/build-debug-fast.sh"
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Built app not found at ${APP_PATH}." >&2
  echo "Run without --no-build first, or set OHANA_DOGFOOD_DERIVED_DATA_PATH to the existing build cache." >&2
  exit 66
fi

xcrun simctl boot "${SIMULATOR_UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${SIMULATOR_UDID}" -b
open -a Simulator

echo "Installing ${APP_PATH}"
xcrun simctl install "${SIMULATOR_UDID}" "${APP_PATH}"

echo "Launching ${BUNDLE_ID}"
xcrun simctl launch "${SIMULATOR_UDID}" "${BUNDLE_ID}" "$@"
