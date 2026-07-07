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
MODE="launch"
REQUIRE_EXISTING_DATA=0

usage() {
  cat <<'USAGE'
Usage: scripts/run-dogfood-simulator.sh [--no-build] [--status] [--require-data] [--] [app launch args...]

Builds, installs, and launches Ohana on one pinned iOS Simulator without erasing
or uninstalling the app. The first resolved simulator UDID is saved under
.build/dogfood-simulator.udid so later runs keep using the same virtual phone.

Options:
  --no-build       Reuse an existing dogfood build before install/launch
  --status         Print pinned simulator, install, and data-container status
                   without booting, building, installing, launching, or erasing
  --require-data   Status mode plus non-zero exit if the installed app data
                   container or a persistence-store file is missing

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
    --status)
      MODE="status"
      shift
      ;;
    --require-data)
      MODE="status"
      REQUIRE_EXISTING_DATA=1
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

simulator_metadata() {
  local udid="$1"
  xcrun simctl list devices available -j | python3 -c '
import json, sys

udid = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    for device in devices:
        if device.get("udid") == udid and device.get("isAvailable"):
            print("\t".join([
                device.get("name", "unknown"),
                device.get("state", "unknown"),
                runtime,
            ]))
            raise SystemExit(0)
raise SystemExit(1)
' "${udid}"
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

relative_persistence_files() {
  local data_container="$1"
  find "${data_container}" -type f \( \
    -name '*.store' -o \
    -name '*.store-*' -o \
    -name '*.sqlite' -o \
    -name '*.sqlite-*' \
  \) -print 2>/dev/null | sort | sed "s#^${data_container}/##"
}

print_status_and_validate() {
  local metadata
  metadata="$(simulator_metadata "${SIMULATOR_UDID}" || true)"

  local simulator_name="${SIMULATOR_DISPLAY_NAME}"
  local simulator_state="unknown"
  local simulator_runtime="unknown"
  if [[ -n "${metadata}" ]]; then
    simulator_name="$(printf '%s' "${metadata}" | awk -F '\t' '{ print $1 }')"
    simulator_state="$(printf '%s' "${metadata}" | awk -F '\t' '{ print $2 }')"
    simulator_runtime="$(printf '%s' "${metadata}" | awk -F '\t' '{ print $3 }')"
  fi

  local app_container=""
  local data_container=""
  app_container="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" app 2>/dev/null || true)"
  data_container="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"

  local persistence_count="0"
  if [[ -n "${data_container}" && -d "${data_container}" ]]; then
    persistence_count="$(relative_persistence_files "${data_container}" | wc -l | tr -d '[:space:]')"
  fi

  echo "Dogfood simulator status"
  echo "  simulator: ${simulator_name} (${SIMULATOR_UDID})"
  echo "  runtime: ${simulator_runtime}"
  echo "  state: ${simulator_state}"
  echo "  pin file: ${PIN_FILE}"
  echo "  bundle id: ${BUNDLE_ID}"
  echo "  derived data: ${DERIVED_DATA_PATH}"

  if [[ -n "${app_container}" ]]; then
    echo "  installed app: ${app_container}"
  else
    echo "  installed app: missing"
  fi

  if [[ -n "${data_container}" && -d "${data_container}" ]]; then
    echo "  data container: ${data_container}"
    echo "  persistence files: ${persistence_count}"
    if [[ "${persistence_count}" != "0" ]]; then
      relative_persistence_files "${data_container}" | sed -n '1,8s/^/    - /p'
    fi
  else
    echo "  data container: missing"
    echo "  persistence files: 0"
  fi

  echo "  status mode: read-only; no boot/build/install/launch/erase was performed"

  if [[ "${REQUIRE_EXISTING_DATA}" == "1" ]]; then
    if [[ -z "${app_container}" || -z "${data_container}" || ! -d "${data_container}" ]]; then
      echo "Dogfood existing-data check failed: app or data container is missing." >&2
      exit 67
    fi
    if [[ "${persistence_count}" == "0" ]]; then
      echo "Dogfood existing-data check failed: no persistence-store files were found." >&2
      exit 67
    fi
  fi
}

SIMULATOR_UDID="$(choose_simulator_udid)"
SIMULATOR_DISPLAY_NAME="$(simulator_exists "${SIMULATOR_UDID}" || true)"
if [[ -z "${SIMULATOR_DISPLAY_NAME}" ]]; then
  echo "Pinned dogfood simulator '${SIMULATOR_UDID}' is not available." >&2
  exit 70
fi

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}-iphonesimulator/Ohana.app"

if [[ "${MODE}" == "status" ]]; then
  print_status_and_validate
  exit 0
fi

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
