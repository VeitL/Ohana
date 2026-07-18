#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

cd "${REPO_ROOT}"

SIMULATOR_NAME="${OHANA_DOGFOOD_SIMULATOR_NAME:-${OHANA_DOGFOOD_SIMULATOR_NAME_FIXED}}"
PIN_FILE="${OHANA_DOGFOOD_PIN_FILE}"
STORE_IDENTITY_FILE="${OHANA_DOGFOOD_STORE_IDENTITY_FILE}"
INITIALIZATION_STATE_FILE="${OHANA_DOGFOOD_INITIALIZATION_STATE_FILE}"
BUNDLE_ID="com.guanchen.li.Ohana"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${OHANA_DOGFOOD_DERIVED_DATA_PATH:-${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}}"
DOGFOOD_USER_STATUS_SCRIPT="${REPO_ROOT}/scripts/dogfood-user-status.py"
BUILD_BEFORE_LAUNCH=1
MODE="launch"
REQUIRE_EXISTING_DATA=0
REQUIRE_READY_USER=0
REQUIRE_LONGITUDINAL_USER=0
REQUIRE_DAY30_USER=0
INITIALIZE_USER=0
REPAIR_DETACHED_ASSOCIATION=0
INITIALIZATION_RESUME=0
INITIALIZATION_LAUNCH_ONLY=0
SESSION_LOCK_DIR="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/locks/dogfood-session.lock"
OVERLAY_RECEIPT_PATH="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/dogfood-evidence/last-overlay.json"
SESSION_LOCK_ACQUIRED=0
PIN_NEEDS_CREATION=0

usage() {
  cat <<'USAGE'
Usage: scripts/run-dogfood-simulator.sh [--no-build] [--initialize] [--] [app launch args...]
       scripts/run-dogfood-simulator.sh --repair-detached [--no-build] [--] [app launch args...]
       scripts/run-dogfood-simulator.sh --status
       scripts/run-dogfood-simulator.sh --require-data
       scripts/run-dogfood-simulator.sh --require-ready
       scripts/run-dogfood-simulator.sh --require-longitudinal
       scripts/run-dogfood-simulator.sh --require-day30
       scripts/run-dogfood-simulator.sh --seal-user

Builds, installs, and launches Ohana on one pinned iOS Simulator without erasing
or uninstalling the app. The first resolved simulator UDID is saved under
.build/dogfood-simulator.udid so later runs keep using the same virtual phone.
Normal launch requires an existing primary store. --initialize is the only
first-install path and still creates all user data through normal product UI.

Options:
  --no-build       Reuse an existing dogfood build before install/launch
  --initialize     Explicitly allow the first install when no primary store exists
  --repair-detached
                   Explicitly reinstall the validated Release app when one unique,
                   sealed Dogfood data container remains detached after a failed
                   overlay. Verifies identity and durable bytes before and after.
  --status         Print pinned simulator, install, and data-container status
                   without booting, building, installing, launching, or erasing
  --require-data   Status mode plus non-zero exit if the installed app data
                   container or primary persistence store is missing
  --require-ready  Status mode plus non-zero exit until the synthetic Day-0
                   user baseline in docs/dogfood-testing.md is complete
  --require-longitudinal
                   Status mode plus non-zero exit until Day-7 data targets pass
  --require-day30  Status mode plus non-zero exit until Day-30 data targets pass
  --seal-user      After Day-0 readiness passes, pin the hashed SwiftData store
                   identity; never replaces a different existing identity pin

Environment:
  OHANA_DOGFOOD_SIMULATOR_UDID       Explicit simulator UDID to pin
  OHANA_DOGFOOD_SIMULATOR_NAME       Simulator name to resolve on first run
  OHANA_DOGFOOD_DERIVED_DATA_PATH    Must equal .build/DerivedData/dogfood
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
    --initialize)
      INITIALIZE_USER=1
      shift
      ;;
    --repair-detached)
      REPAIR_DETACHED_ASSOCIATION=1
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
    --require-ready)
      MODE="status"
      REQUIRE_EXISTING_DATA=1
      REQUIRE_READY_USER=1
      shift
      ;;
    --require-longitudinal)
      MODE="status"
      REQUIRE_EXISTING_DATA=1
      REQUIRE_READY_USER=1
      REQUIRE_LONGITUDINAL_USER=1
      shift
      ;;
    --require-day30)
      MODE="status"
      REQUIRE_EXISTING_DATA=1
      REQUIRE_READY_USER=1
      REQUIRE_DAY30_USER=1
      shift
      ;;
    --seal-user)
      MODE="seal"
      REQUIRE_EXISTING_DATA=1
      REQUIRE_READY_USER=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown Dogfood option: $1" >&2
      echo "Use -- before normal app launch arguments." >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${INITIALIZE_USER}" == "1" && "${MODE}" != "launch" ]]; then
  echo "--initialize cannot be combined with a read-only status option." >&2
  exit 2
fi
if [[ "${REPAIR_DETACHED_ASSOCIATION}" == "1" && "${INITIALIZE_USER}" == "1" ]]; then
  echo "--repair-detached cannot be combined with --initialize." >&2
  exit 2
fi
if [[ "${REPAIR_DETACHED_ASSOCIATION}" == "1" && "${MODE}" != "launch" ]]; then
  echo "--repair-detached cannot be combined with a read-only status option." >&2
  exit 2
fi

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
    if [[ ! -f "${PIN_FILE}" && "${INITIALIZE_USER}" != "1" ]]; then
      echo "Dogfood pin is missing; refusing an implicit repair from OHANA_DOGFOOD_SIMULATOR_UDID." >&2
      echo "A new Dogfood identity requires an explicit initialization decision." >&2
      exit 70
    fi
    printf '%s\n' "${OHANA_DOGFOOD_SIMULATOR_UDID}"
    return 0
  fi

  if [[ -f "${PIN_FILE}" ]]; then
    local pinned
    pinned="$(tr -d '[:space:]' < "${PIN_FILE}")"
    if [[ -n "${pinned}" ]] && simulator_exists "${pinned}" >/dev/null; then
      printf '%s\n' "${pinned}"
      return 0
    fi
    echo "Pinned Dogfood Simulator '${pinned}' is unavailable." >&2
    echo "Refusing to silently repin another phone; restore the device or explicitly repair the pin." >&2
    exit 70
  fi

  if [[ -f "${INITIALIZATION_STATE_FILE}" && \
        ( "${INITIALIZE_USER}" == "1" || "${MODE}" == "status" || "${MODE}" == "seal" ) ]]; then
    local pending
    pending="$(tr -d '[:space:]' < "${INITIALIZATION_STATE_FILE}")"
    if [[ -n "${pending}" ]] && simulator_exists "${pending}" >/dev/null; then
      printf '%s\n' "${pending}"
      return 0
    fi
    echo "Pending Dogfood initialization points to an unavailable Simulator: ${pending:-missing}." >&2
    echo "Refusing to resume on a different virtual phone." >&2
    exit 70
  fi

  if [[ "${INITIALIZE_USER}" != "1" ]]; then
    echo "Dogfood pin is missing at ${PIN_FILE}." >&2
    echo "Refusing to silently select or replace the long-lived synthetic user." >&2
    exit 70
  fi

  local resolved
  if ! resolved="$(resolve_simulator_by_name)"; then
    echo "No available iOS Simulator named '${SIMULATOR_NAME}'." >&2
    echo "Create one in Xcode > Devices and Simulators, or set OHANA_DOGFOOD_SIMULATOR_UDID." >&2
    exit 70
  fi

  printf '%s\n' "${resolved}"
}

relative_primary_persistence_files() {
  local data_container="$1"
  local application_support="${data_container}/Library/Application Support"

  [[ -d "${application_support}" ]] || return 0
  find "${application_support}" -type f \( \
    -name '*.store' -o \
    -name '*.sqlite' \
  \) -print 2>/dev/null | sort | sed "s#^${data_container}/##"
}

relative_persistence_sidecars() {
  local data_container="$1"
  local application_support="${data_container}/Library/Application Support"

  [[ -d "${application_support}" ]] || return 0
  find "${application_support}" -type f \( \
    -name '*.store-wal' -o \
    -name '*.store-shm' -o \
    -name '*.sqlite-wal' -o \
    -name '*.sqlite-shm' \
  \) -print 2>/dev/null | sort | sed "s#^${data_container}/##"
}

primary_store_path() {
  local data_container="$1"
  local expected="${data_container}/Library/Application Support/default.store"

  [[ -f "${expected}" ]] || return 1
  printf '%s\n' "${expected}"
}

canonical_existing_path() {
  local path="$1"
  python3 - "${path}" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve(strict=True))
PY
}

persistent_data_fingerprint() {
  local data_container="$1"
  local bundle_id="$2"

  python3 - "${data_container}" "${bundle_id}" <<'PY'
import hashlib
import pathlib
import sys

container = pathlib.Path(sys.argv[1])
bundle_id = sys.argv[2]
candidates = [
    container / "Documents",
    container / "Library" / "Application Support",
    container / "Library" / "Preferences" / f"{bundle_id}.plist",
]
files: set[pathlib.Path] = set()
for candidate in candidates:
    if candidate.is_file() or candidate.is_symlink():
        files.add(candidate)
    elif candidate.is_dir():
        files.update(
            path
            for path in candidate.rglob("*")
            if (path.is_file() or path.is_symlink())
            and not path.name.endswith((".store-shm", ".sqlite-shm"))
        )

fingerprint = hashlib.sha256()
for path in sorted(files, key=lambda value: value.relative_to(container).as_posix()):
    relative = path.relative_to(container).as_posix()
    if path.is_symlink():
        content_digest = hashlib.sha256(
            ("symlink:" + str(path.readlink())).encode("utf-8")
        ).hexdigest()
        size = 0
    else:
        content = hashlib.sha256()
        size = 0
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                content.update(chunk)
                size += len(chunk)
        content_digest = content.hexdigest()
    fingerprint.update(relative.encode("utf-8"))
    fingerprint.update(b"\0")
    fingerprint.update(str(size).encode("ascii"))
    fingerprint.update(b"\0")
    fingerprint.update(content_digest.encode("ascii"))
    fingerprint.update(b"\n")

print(f"{len(files)}:{fingerprint.hexdigest()}")
PY
}

store_identity_hash() {
  local store_path="$1"

  python3 - "${store_path}" <<'PY'
import hashlib
import pathlib
import shutil
import sqlite3
import sys
import tempfile

path = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="ohana-dogfood-identity.") as raw:
    snapshot = pathlib.Path(raw) / path.name
    for suffix in ("", "-wal", "-shm"):
        source = pathlib.Path(f"{path}{suffix}")
        if source.is_file():
            shutil.copy2(source, pathlib.Path(f"{snapshot}{suffix}"))
    connection = sqlite3.connect(snapshot, timeout=2.0)
    try:
        row = connection.execute("SELECT Z_UUID FROM Z_METADATA LIMIT 1").fetchone()
    finally:
        connection.close()
if not row or not isinstance(row[0], str) or not row[0].strip():
    raise SystemExit("SwiftData Z_METADATA store UUID is missing")
print(hashlib.sha256(row[0].encode("utf-8")).hexdigest())
PY
}

assert_store_identity() {
  local store_path="$1"
  local expected=""
  local actual=""

  if [[ ! -f "${STORE_IDENTITY_FILE}" ]]; then
    echo "Dogfood store identity is not sealed at ${STORE_IDENTITY_FILE}." >&2
    echo "After completing Day-0 through normal UI, run scripts/run-dogfood-simulator.sh --seal-user." >&2
    exit 70
  fi
  expected="$(tr -d '[:space:]' < "${STORE_IDENTITY_FILE}")"
  if [[ ! "${expected}" =~ ^[0-9a-f]{64}$ ]]; then
    echo "SAFETY STOP: Dogfood store identity pin is malformed." >&2
    exit 69
  fi
  actual="$(store_identity_hash "${store_path}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "SAFETY STOP: Dogfood SwiftData store identity does not match the sealed user." >&2
    exit 69
  fi
}

seal_store_identity() {
  local store_path="$1"
  local actual=""
  local existing=""
  local temporary=""

  actual="$(store_identity_hash "${store_path}")"
  if [[ -f "${STORE_IDENTITY_FILE}" ]]; then
    existing="$(tr -d '[:space:]' < "${STORE_IDENTITY_FILE}")"
    if [[ "${existing}" == "${actual}" ]]; then
      echo "Dogfood SwiftData store identity is already sealed."
      return 0
    fi
    echo "SAFETY STOP: refusing to replace a different Dogfood store identity pin." >&2
    exit 69
  fi
  mkdir -p "$(dirname "${STORE_IDENTITY_FILE}")"
  temporary="${STORE_IDENTITY_FILE}.tmp.$$"
  printf '%s\n' "${actual}" > "${temporary}"
  chmod 600 "${temporary}"
  mv "${temporary}" "${STORE_IDENTITY_FILE}"
  echo "Sealed Dogfood SwiftData store identity at ${STORE_IDENTITY_FILE}."
}

metadata_data_containers_for_bundle() {
  local simulator_udid="$1"
  local bundle_id="$2"
  local containers_root="${HOME}/Library/Developer/CoreSimulator/Devices/${simulator_udid}/data/Containers/Data/Application"

  [[ -d "${containers_root}" ]] || return 0
  python3 - "${containers_root}" "${bundle_id}" <<'PY'
import pathlib
import plistlib
import sys

root = pathlib.Path(sys.argv[1])
bundle_id = sys.argv[2]
for metadata in sorted(root.glob("*/.com.apple.mobile_container_manager.metadata.plist")):
    try:
        with metadata.open("rb") as handle:
            payload = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException):
        continue
    if payload.get("MCMMetadataIdentifier") == bundle_id:
        print(metadata.parent)
PY
}

metadata_app_bundles_for_bundle() {
  local simulator_udid="$1"
  local bundle_id="$2"
  local containers_root="${HOME}/Library/Developer/CoreSimulator/Devices/${simulator_udid}/data/Containers/Bundle/Application"

  [[ -d "${containers_root}" ]] || return 0
  python3 - "${containers_root}" "${bundle_id}" <<'PY'
import pathlib
import plistlib
import sys

root = pathlib.Path(sys.argv[1])
bundle_id = sys.argv[2]
for metadata in sorted(root.glob("*/.com.apple.mobile_container_manager.metadata.plist")):
    try:
        with metadata.open("rb") as handle:
            payload = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException):
        continue
    if payload.get("MCMMetadataIdentifier") != bundle_id:
        continue
    for app_bundle in sorted(metadata.parent.glob("*.app")):
        try:
            with (app_bundle / "Info.plist").open("rb") as handle:
                app_info = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException):
            continue
        if app_info.get("CFBundleIdentifier") == bundle_id:
            print(app_bundle)
PY
}

app_build_summary() {
  local app_container="$1"
  local info_plist="${app_container}/Info.plist"
  local version="unknown"
  local build="unknown"

  if [[ -f "${info_plist}" ]]; then
    version="$(plutil -extract CFBundleShortVersionString raw -o - "${info_plist}" 2>/dev/null || true)"
    build="$(plutil -extract CFBundleVersion raw -o - "${info_plist}" 2>/dev/null || true)"
  fi
  printf '%s (%s)' "${version:-unknown}" "${build:-unknown}"
}

app_plist_value() {
  local app_path="$1"
  local key="$2"
  plutil -extract "${key}" raw -o - "${app_path}/Info.plist" 2>/dev/null || true
}

write_overlay_receipt() {
  local before_version="$1"
  local before_build="$2"
  local after_version="$3"
  local after_build="$4"
  local repair_detached="$5"
  local store_identity=""

  store_identity="$(tr -d '[:space:]' < "${STORE_IDENTITY_FILE}")"
  mkdir -p "$(dirname "${OVERLAY_RECEIPT_PATH}")"
  python3 - \
    "${OVERLAY_RECEIPT_PATH}" \
    "${before_version}" \
    "${before_build}" \
    "${after_version}" \
    "${after_build}" \
    "${repair_detached}" \
    "${store_identity}" <<'PY'
import datetime
import json
import pathlib
import sys
import time
import uuid

path = pathlib.Path(sys.argv[1])
before_version, before_build, after_version, after_build, repair_raw, store_identity = sys.argv[2:]
repair_detached = repair_raw == "1"
record = {
    "schema": "ohana.dogfood-overlay-receipt.v1",
    "receiptId": str(uuid.uuid4()),
    "createdAt": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "createdAtEpoch": int(time.time()),
    "beforeVersion": before_version or "unknown",
    "beforeBuild": before_build or "unknown",
    "afterVersion": after_version or "unknown",
    "afterBuild": after_build or "unknown",
    "isVersionChange": False if repair_detached else (before_version, before_build) != (after_version, after_build),
    "repairDetachedAssociation": repair_detached,
    "storeIdentity": store_identity,
    "sqliteQuickCheckVerified": True,
    "durableFingerprintVerified": True,
    "launchSucceeded": True,
}
temporary = path.with_suffix(".tmp")
temporary.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
temporary.replace(path)
PY
}

invalidate_overlay_receipt() {
  mkdir -p "$(dirname "${OVERLAY_RECEIPT_PATH}")"
  python3 - "${OVERLAY_RECEIPT_PATH}" <<'PY'
import datetime
import json
import pathlib
import sys
import time
import uuid

path = pathlib.Path(sys.argv[1])
record = {
    "schema": "ohana.dogfood-overlay-attempt.v1",
    "attemptId": str(uuid.uuid4()),
    "createdAt": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "createdAtEpoch": int(time.time()),
    "launchSucceeded": False,
}
temporary = path.with_suffix(".tmp")
temporary.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
temporary.replace(path)
PY
}

validate_app_artifact() {
  local app_path="$1"
  local info_plist="${app_path}/Info.plist"
  local artifact_bundle_id=""
  local artifact_version=""
  local artifact_build=""

  if [[ ! -f "${info_plist}" ]]; then
    echo "Built Dogfood app is missing Info.plist: ${info_plist}" >&2
    exit 66
  fi
  artifact_bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "${info_plist}" 2>/dev/null || true)"
  if [[ "${artifact_bundle_id}" != "${BUNDLE_ID}" ]]; then
    echo "SAFETY STOP: Dogfood artifact bundle id must be ${BUNDLE_ID}, got ${artifact_bundle_id:-missing}." >&2
    exit 69
  fi
  artifact_version="$(plutil -extract CFBundleShortVersionString raw -o - "${info_plist}" 2>/dev/null || true)"
  artifact_build="$(plutil -extract CFBundleVersion raw -o - "${info_plist}" 2>/dev/null || true)"
  if [[ -z "${artifact_version}" || -z "${artifact_build}" ]]; then
    echo "SAFETY STOP: Dogfood artifact must declare both App version and build." >&2
    exit 69
  fi
}

release_session_lock() {
  if [[ "${SESSION_LOCK_ACQUIRED}" == "1" ]]; then
    rm -f "${SESSION_LOCK_DIR}/pid"
    rmdir "${SESSION_LOCK_DIR}" 2>/dev/null || true
  fi
}

acquire_session_lock() {
  local owner_pid=""
  local stale_path=""

  mkdir -p "$(dirname "${SESSION_LOCK_DIR}")"
  if ! mkdir "${SESSION_LOCK_DIR}" 2>/dev/null; then
    owner_pid="$(tr -d '[:space:]' < "${SESSION_LOCK_DIR}/pid" 2>/dev/null || true)"
    if [[ -n "${owner_pid}" ]] && kill -0 "${owner_pid}" 2>/dev/null; then
      echo "Another Dogfood overlay/launch session is active (PID ${owner_pid})." >&2
      exit 75
    fi
    stale_path="${SESSION_LOCK_DIR}.stale.$(date +%s).$$"
    if ! mv "${SESSION_LOCK_DIR}" "${stale_path}" 2>/dev/null; then
      echo "Unable to quarantine stale Dogfood session lock: ${SESSION_LOCK_DIR}" >&2
      exit 75
    fi
    mkdir "${SESSION_LOCK_DIR}"
  fi
  printf '%s\n' "$$" > "${SESSION_LOCK_DIR}/pid"
  SESSION_LOCK_ACQUIRED=1
}

terminate_dogfood_app_for_overlay() {
  local output=""
  local status=0

  set +e
  output="$(xcrun simctl terminate "${SIMULATOR_UDID}" "${BUNDLE_ID}" 2>&1)"
  status=$?
  set -e
  if [[ "${status}" == "0" ]]; then
    return 0
  fi
  if grep -qiE 'No such process|nothing to terminate|not running|process .*not found|was not found' <<< "${output}"; then
    return 0
  fi
  echo "SAFETY STOP: unable to terminate Dogfood before fingerprinting (status ${status})." >&2
  [[ -n "${output}" ]] && printf '%s\n' "${output}" >&2
  exit 69
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
  local metadata_app_bundles=""
  local metadata_app_bundle_count="0"
  local metadata_data_containers=""
  local metadata_data_container_count="0"
  local simctl_app_container=""
  local simctl_data_container=""
  local app_container_is_offline="0"
  local data_container_is_offline="0"
  local data_container_is_detached="0"
  simctl_app_container="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" app 2>/dev/null || true)"
  simctl_data_container="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
  app_container="${simctl_app_container}"
  data_container="${simctl_data_container}"
  metadata_app_bundles="$(metadata_app_bundles_for_bundle "${SIMULATOR_UDID}" "${BUNDLE_ID}" || true)"
  metadata_app_bundle_count="$(printf '%s\n' "${metadata_app_bundles}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
  metadata_data_containers="$(metadata_data_containers_for_bundle "${SIMULATOR_UDID}" "${BUNDLE_ID}" || true)"
  metadata_data_container_count="$(printf '%s\n' "${metadata_data_containers}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

  if [[ "${simulator_state}" == "Shutdown" ]]; then
    if [[ -z "${app_container}" && "${metadata_app_bundle_count}" == "1" ]]; then
      app_container="${metadata_app_bundles}"
      app_container_is_offline="1"
    fi
    if [[ -z "${data_container}" && "${metadata_data_container_count}" == "1" ]]; then
      data_container="${metadata_data_containers}"
      data_container_is_offline="1"
    fi
  fi
  if [[ -z "${app_container}" && "${metadata_app_bundle_count}" == "0" && \
        -z "${simctl_data_container}" && \
        "${metadata_data_container_count}" == "1" ]]; then
    data_container="${metadata_data_containers}"
    data_container_is_detached="1"
  fi

  local primary_store_count="0"
  local sidecar_count="0"
  local store_path=""
  local preferences_path=""
  local identity_status="unsealed"
  if [[ -n "${data_container}" && -d "${data_container}" ]]; then
    primary_store_count="$(relative_primary_persistence_files "${data_container}" | wc -l | tr -d '[:space:]')"
    sidecar_count="$(relative_persistence_sidecars "${data_container}" | wc -l | tr -d '[:space:]')"
    store_path="$(primary_store_path "${data_container}" || true)"
    preferences_path="${data_container}/Library/Preferences/${BUNDLE_ID}.plist"
    if [[ -n "${store_path}" && -f "${STORE_IDENTITY_FILE}" ]]; then
      local pinned_identity=""
      local current_identity=""
      pinned_identity="$(tr -d '[:space:]' < "${STORE_IDENTITY_FILE}")"
      current_identity="$(store_identity_hash "${store_path}" 2>/dev/null || true)"
      if [[ -n "${current_identity}" && "${current_identity}" == "${pinned_identity}" ]]; then
        identity_status="sealed/match"
      else
        identity_status="MISMATCH"
      fi
    fi
  fi

  echo "Dogfood simulator status"
  echo "  simulator: ${simulator_name} (${SIMULATOR_UDID})"
  echo "  runtime: ${simulator_runtime}"
  echo "  state: ${simulator_state}"
  echo "  pin file: ${PIN_FILE}"
  echo "  bundle id: ${BUNDLE_ID}"
  echo "  configuration: ${CONFIGURATION}"
  echo "  derived data: ${DERIVED_DATA_PATH}"
  echo "  store identity: ${identity_status}"

  if [[ -n "${app_container}" ]]; then
    if [[ "${app_container_is_offline}" == "1" ]]; then
      echo "  installed app: ${app_container} (offline metadata fallback)"
    else
      echo "  installed app: ${app_container}"
    fi
    echo "  installed version: $(app_build_summary "${app_container}")"
  else
    echo "  installed app: missing"
  fi

  if [[ -n "${data_container}" && -d "${data_container}" ]]; then
    if [[ "${data_container_is_detached}" == "1" ]]; then
      echo "  data container: ${data_container} (DETACHED FROM MISSING APP)"
    elif [[ "${data_container_is_offline}" == "1" ]]; then
      echo "  data container: ${data_container} (offline metadata fallback)"
    else
      echo "  data container: ${data_container}"
    fi
    echo "  primary stores: ${primary_store_count}"
    echo "  store sidecars: ${sidecar_count}"
    if [[ "${primary_store_count}" != "0" ]]; then
      relative_primary_persistence_files "${data_container}" | sed -n '1,8s/^/    - /p'
    fi
  else
    echo "  data container: missing"
    echo "  primary stores: 0"
    echo "  store sidecars: 0"
  fi
  if ((metadata_data_container_count > 1)); then
    echo "  data-container metadata matches: ${metadata_data_container_count} (AMBIGUOUS)"
  fi
  if ((metadata_app_bundle_count > 1)); then
    echo "  app-bundle metadata matches: ${metadata_app_bundle_count} (AMBIGUOUS)"
  fi

  if [[ "${MODE}" == "seal" ]]; then
    echo "  inspection phase: read-only; the ignored identity pin is written only after readiness passes"
  else
    echo "  status mode: read-only; no boot/build/install/launch/erase was performed"
  fi

  if [[ "${REQUIRE_EXISTING_DATA}" == "1" ]]; then
    if ((metadata_app_bundle_count > 1)); then
      echo "Dogfood existing-data check failed: multiple installed app bundles match the bundle id." >&2
      exit 67
    fi
    if ((metadata_data_container_count > 1)); then
      echo "Dogfood existing-data check failed: multiple app data containers match the bundle id." >&2
      exit 67
    fi
    if [[ -z "${app_container}" || -z "${data_container}" || ! -d "${data_container}" ]]; then
      echo "Dogfood existing-data check failed: app or data container is missing." >&2
      exit 67
    fi
    if [[ -z "${store_path}" ]]; then
      echo "Dogfood existing-data check failed: the expected default.store is missing." >&2
      exit 67
    fi
  fi

  if [[ -n "${store_path}" ]]; then
    local status_arguments=(
      --store "${store_path}"
      --preferences "${preferences_path}"
      --data-container "${data_container}"
    )
    if [[ "${REQUIRE_READY_USER}" == "1" ]]; then
      status_arguments+=(--require-ready)
    fi
    if [[ "${REQUIRE_LONGITUDINAL_USER}" == "1" ]]; then
      status_arguments+=(--require-longitudinal)
    fi
    if [[ "${REQUIRE_DAY30_USER}" == "1" ]]; then
      status_arguments+=(--require-day30)
    fi
    "${DOGFOOD_USER_STATUS_SCRIPT}" "${status_arguments[@]}"
  elif [[ "${REQUIRE_READY_USER}" == "1" ]]; then
    echo "Dogfood user readiness failed: no primary store is available." >&2
    exit 67
  fi
}

ohana_assert_fixed_derived_data_path dogfood "${DERIVED_DATA_PATH}"
DERIVED_DATA_PATH="${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}"

if [[ "${CONFIGURATION}" != "Release" ]]; then
  echo "Dogfood requires the Release configuration; Debug tools would contaminate the real-user history." >&2
  exit 2
fi
if [[ -n "${OHANA_BUNDLE_ID:-}" && "${OHANA_BUNDLE_ID}" != "${BUNDLE_ID}" ]]; then
  echo "Dogfood bundle id is fixed at ${BUNDLE_ID}; OHANA_BUNDLE_ID overrides are rejected." >&2
  exit 2
fi

SIMULATOR_UDID="$(choose_simulator_udid)"
SIMULATOR_DISPLAY_NAME="$(simulator_exists "${SIMULATOR_UDID}" || true)"
if [[ -z "${SIMULATOR_DISPLAY_NAME}" ]]; then
  echo "Pinned dogfood simulator '${SIMULATOR_UDID}' is not available." >&2
  exit 70
fi

ohana_assert_dogfood_simulator_udid "${SIMULATOR_UDID}"
if [[ ! -f "${PIN_FILE}" ]]; then
  if [[ "${INITIALIZE_USER}" == "1" ]]; then
    PIN_NEEDS_CREATION=1
  elif [[ ( "${MODE}" == "status" || "${MODE}" == "seal" ) && -f "${INITIALIZATION_STATE_FILE}" ]]; then
    if [[ "${MODE}" == "seal" ]]; then
      PIN_NEEDS_CREATION=1
    fi
  else
    echo "Dogfood pin creation is allowed only during explicit --initialize." >&2
    exit 70
  fi
fi

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}-iphonesimulator/Ohana.app"

if [[ "${MODE}" == "status" ]]; then
  print_status_and_validate
  exit 0
fi

if [[ "${MODE}" == "seal" ]]; then
  print_status_and_validate
  SEAL_DATA_CONTAINER="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
  SEAL_SIMULATOR_STATE="$(simulator_metadata "${SIMULATOR_UDID}" 2>/dev/null | awk -F '\t' '{ print $2 }' || true)"
  if [[ -z "${SEAL_DATA_CONTAINER}" && "${SEAL_SIMULATOR_STATE}" == "Shutdown" ]]; then
    SEAL_METADATA_DATA_CONTAINERS="$(metadata_data_containers_for_bundle "${SIMULATOR_UDID}" "${BUNDLE_ID}" || true)"
    SEAL_METADATA_DATA_CONTAINER_COUNT="$(printf '%s\n' "${SEAL_METADATA_DATA_CONTAINERS}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
    if [[ "${SEAL_METADATA_DATA_CONTAINER_COUNT}" == "1" ]]; then
      SEAL_DATA_CONTAINER="${SEAL_METADATA_DATA_CONTAINERS}"
    fi
  fi
  SEAL_STORE="$(primary_store_path "${SEAL_DATA_CONTAINER}" || true)"
  if [[ -z "${SEAL_STORE}" ]]; then
    echo "Unable to seal Dogfood: expected default.store is missing." >&2
    exit 67
  fi
  seal_store_identity "${SEAL_STORE}"
  if [[ "${PIN_NEEDS_CREATION}" == "1" ]]; then
    mkdir -p "$(dirname "${PIN_FILE}")"
    PIN_TEMPORARY="${PIN_FILE}.tmp.$$"
    printf '%s\n' "${SIMULATOR_UDID}" > "${PIN_TEMPORARY}"
    chmod 600 "${PIN_TEMPORARY}"
    mv "${PIN_TEMPORARY}" "${PIN_FILE}"
    rm -f "${INITIALIZATION_STATE_FILE}"
    echo "Finalized the pending Dogfood device pin after sealing the ready store."
  fi
  exit 0
fi

ohana_assert_safe_dogfood_launch_context "$@"

SIMULATOR_STATE_BEFORE="$(simulator_metadata "${SIMULATOR_UDID}" 2>/dev/null | awk -F '\t' '{ print $2 }' || true)"
SIMCTL_DATA_CONTAINER_BEFORE="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
SIMCTL_APP_CONTAINER_BEFORE="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" app 2>/dev/null || true)"
DATA_CONTAINER_BEFORE="${SIMCTL_DATA_CONTAINER_BEFORE}"
APP_CONTAINER_BEFORE="${SIMCTL_APP_CONTAINER_BEFORE}"
METADATA_APP_BUNDLES_BEFORE="$(metadata_app_bundles_for_bundle "${SIMULATOR_UDID}" "${BUNDLE_ID}" || true)"
METADATA_APP_BUNDLE_COUNT_BEFORE="$(printf '%s\n' "${METADATA_APP_BUNDLES_BEFORE}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
METADATA_DATA_CONTAINERS_BEFORE="$(metadata_data_containers_for_bundle "${SIMULATOR_UDID}" "${BUNDLE_ID}" || true)"
METADATA_DATA_CONTAINER_COUNT_BEFORE="$(printf '%s\n' "${METADATA_DATA_CONTAINERS_BEFORE}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
DETACHED_DATA_CONTAINER_BEFORE=""
PRIMARY_STORE_BEFORE=""

if ((METADATA_APP_BUNDLE_COUNT_BEFORE > 1)); then
  echo "SAFETY STOP: multiple installed Dogfood app bundles match ${BUNDLE_ID}." >&2
  printf '%s\n' "${METADATA_APP_BUNDLES_BEFORE}" | sed 's/^/  - /' >&2
  exit 69
fi
if ((METADATA_DATA_CONTAINER_COUNT_BEFORE > 1)); then
  echo "SAFETY STOP: multiple Dogfood data containers match ${BUNDLE_ID}." >&2
  printf '%s\n' "${METADATA_DATA_CONTAINERS_BEFORE}" | sed 's/^/  - /' >&2
  exit 69
fi

if [[ "${SIMULATOR_STATE_BEFORE}" == "Shutdown" ]]; then
  if [[ -z "${APP_CONTAINER_BEFORE}" && "${METADATA_APP_BUNDLE_COUNT_BEFORE}" == "1" ]]; then
    APP_CONTAINER_BEFORE="${METADATA_APP_BUNDLES_BEFORE}"
  fi
  if [[ -z "${DATA_CONTAINER_BEFORE}" && "${METADATA_DATA_CONTAINER_COUNT_BEFORE}" == "1" ]]; then
    DATA_CONTAINER_BEFORE="${METADATA_DATA_CONTAINERS_BEFORE}"
  fi
fi

if [[ -z "${SIMCTL_DATA_CONTAINER_BEFORE}" && \
      -z "${APP_CONTAINER_BEFORE}" && \
      "${METADATA_APP_BUNDLE_COUNT_BEFORE}" == "0" && \
      -n "${METADATA_DATA_CONTAINERS_BEFORE}" ]]; then
  if [[ "${REPAIR_DETACHED_ASSOCIATION}" != "1" ]]; then
    echo "SAFETY STOP: Dogfood has detached pre-existing data for ${BUNDLE_ID}." >&2
    echo "Refusing installation because simctl would silently reconnect that old container." >&2
    echo "Use --repair-detached only after explicit authorization and read-only diagnosis." >&2
    printf '%s\n' "${METADATA_DATA_CONTAINERS_BEFORE}" | sed 's/^/  - /' >&2
    exit 69
  fi
  if [[ -n "${APP_CONTAINER_BEFORE}" || "${METADATA_DATA_CONTAINER_COUNT_BEFORE}" != "1" ]]; then
    echo "SAFETY STOP: detached repair requires one missing App and exactly one matching data container." >&2
    exit 69
  fi
  DETACHED_DATA_CONTAINER_BEFORE="$(canonical_existing_path "${METADATA_DATA_CONTAINERS_BEFORE}")"
  DATA_CONTAINER_BEFORE="${DETACHED_DATA_CONTAINER_BEFORE}"
elif [[ "${REPAIR_DETACHED_ASSOCIATION}" == "1" ]]; then
  echo "SAFETY STOP: --repair-detached requires exactly one detached Dogfood data container." >&2
  exit 69
fi

if [[ -n "${DATA_CONTAINER_BEFORE}" && -d "${DATA_CONTAINER_BEFORE}" ]]; then
  PRIMARY_STORE_BEFORE="$(primary_store_path "${DATA_CONTAINER_BEFORE}" || true)"
fi

if [[ "${INITIALIZE_USER}" == "1" ]]; then
  if [[ -f "${INITIALIZATION_STATE_FILE}" ]]; then
    PENDING_INITIALIZATION_UDID="$(tr -d '[:space:]' < "${INITIALIZATION_STATE_FILE}")"
    if [[ "${PENDING_INITIALIZATION_UDID}" != "${SIMULATOR_UDID}" ]]; then
      echo "SAFETY STOP: pending Dogfood initialization belongs to a different Simulator." >&2
      exit 69
    fi
    if [[ -e "${STORE_IDENTITY_FILE}" ]]; then
      echo "SAFETY STOP: pending initialization encountered a sealed SwiftData store." >&2
      echo "Use read-only status; do not resume initialization over sealed user data." >&2
      exit 69
    fi
    INITIALIZATION_RESUME=1
    if [[ -n "${PRIMARY_STORE_BEFORE}" ]]; then
      if [[ -z "${APP_CONTAINER_BEFORE}" ]]; then
        echo "SAFETY STOP: pending initialization has a detached store but no installed App." >&2
        exit 69
      fi
      "${DOGFOOD_USER_STATUS_SCRIPT}" \
        --store "${PRIMARY_STORE_BEFORE}" \
        --preferences "${DATA_CONTAINER_BEFORE}/Library/Preferences/${BUNDLE_ID}.plist" \
        --data-container "${DATA_CONTAINER_BEFORE}" \
        --require-safe \
        --json >/dev/null
      INITIALIZATION_LAUNCH_ONLY=1
    fi
  elif [[ -n "${APP_CONTAINER_BEFORE}" || -n "${DATA_CONTAINER_BEFORE}" || \
          -n "${METADATA_APP_BUNDLES_BEFORE}" || \
          -n "${METADATA_DATA_CONTAINERS_BEFORE}" || -e "${STORE_IDENTITY_FILE}" ]]; then
      echo "SAFETY STOP: --initialize is allowed only on a true first install with no prior app, data, metadata, or sealed store identity." >&2
      echo "Diagnose the existing state read-only; do not use initialization as recovery." >&2
      exit 69
  fi
else
  if [[ -z "${DATA_CONTAINER_BEFORE}" || -z "${PRIMARY_STORE_BEFORE}" ]]; then
    echo "Dogfood persistent user data is missing; refusing to silently create a replacement user." >&2
    echo "For the one-time first install only, run scripts/run-dogfood-simulator.sh --initialize." >&2
    exit 67
  fi
  assert_store_identity "${PRIMARY_STORE_BEFORE}"
fi

acquire_session_lock
trap release_session_lock EXIT

if [[ "${INITIALIZE_USER}" != "1" ]]; then
  invalidate_overlay_receipt
fi

if [[ "${INITIALIZE_USER}" == "1" && "${INITIALIZATION_RESUME}" == "0" ]]; then
  mkdir -p "$(dirname "${INITIALIZATION_STATE_FILE}")"
  INITIALIZATION_STATE_TEMPORARY="${INITIALIZATION_STATE_FILE}.tmp.$$"
  printf '%s\n' "${SIMULATOR_UDID}" > "${INITIALIZATION_STATE_TEMPORARY}"
  chmod 600 "${INITIALIZATION_STATE_TEMPORARY}"
  mv "${INITIALIZATION_STATE_TEMPORARY}" "${INITIALIZATION_STATE_FILE}"
fi

if [[ "${INITIALIZATION_LAUNCH_ONLY}" == "1" ]]; then
  xcrun simctl boot "${SIMULATOR_UDID}" 2>/dev/null || true
  xcrun simctl bootstatus "${SIMULATOR_UDID}" -b
  open -a Simulator
  echo "Resuming the installed Dogfood App without reinstalling over its new store."
  xcrun simctl launch "${SIMULATOR_UDID}" "${BUNDLE_ID}" "$@"
  if [[ "${PIN_NEEDS_CREATION}" == "1" ]]; then
    mkdir -p "$(dirname "${PIN_FILE}")"
    PIN_TEMPORARY="${PIN_FILE}.tmp.$$"
    printf '%s\n' "${SIMULATOR_UDID}" > "${PIN_TEMPORARY}"
    chmod 600 "${PIN_TEMPORARY}"
    mv "${PIN_TEMPORARY}" "${PIN_FILE}"
  fi
  rm -f "${INITIALIZATION_STATE_FILE}"
  echo "Dogfood initialization transaction finalized; continue the normal UI baseline."
  exit 0
fi

if [[ "${BUILD_BEFORE_LAUNCH}" == "1" ]]; then
  echo "Dogfood simulator: ${SIMULATOR_DISPLAY_NAME} (${SIMULATOR_UDID})"
  echo "DerivedData: ${DERIVED_DATA_PATH}"
  OHANA_BUILD_LANE=dogfood \
    OHANA_DOGFOOD_SIMULATOR_UDID="${SIMULATOR_UDID}" \
    DERIVED_DATA_PATH="${DERIVED_DATA_PATH}" \
    CONFIGURATION="${CONFIGURATION}" \
    SCHEME=Ohana \
    "${REPO_ROOT}/scripts/build-debug-fast.sh"
fi
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Built app not found at ${APP_PATH}." >&2
  echo "Run without --no-build first, or set OHANA_DOGFOOD_DERIVED_DATA_PATH to the existing build cache." >&2
  exit 66
fi
validate_app_artifact "${APP_PATH}"
PREVIOUS_APP_VERSION="$(app_plist_value "${APP_CONTAINER_BEFORE}" CFBundleShortVersionString)"
PREVIOUS_APP_BUILD="$(app_plist_value "${APP_CONTAINER_BEFORE}" CFBundleVersion)"
ARTIFACT_APP_VERSION="$(app_plist_value "${APP_PATH}" CFBundleShortVersionString)"
ARTIFACT_APP_BUILD="$(app_plist_value "${APP_PATH}" CFBundleVersion)"

xcrun simctl boot "${SIMULATOR_UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${SIMULATOR_UDID}" -b
open -a Simulator

PERSISTENT_DATA_FINGERPRINT_BEFORE=""
if [[ "${INITIALIZE_USER}" != "1" ]]; then
  # Hash only durable app-owned locations while the process is stopped. A
  # Simulator overlay can legitimately remount the same logical data under a
  # new container UUID, so the path itself is not a continuity identity.
  if [[ "${REPAIR_DETACHED_ASSOCIATION}" == "1" ]]; then
    DATA_CONTAINER_BEFORE="${DETACHED_DATA_CONTAINER_BEFORE}"
    echo "Explicit detached-association repair authorized for one sealed Dogfood container."
  else
    BOOTED_APP_CONTAINER_BEFORE="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" app 2>/dev/null || true)"
    BOOTED_DATA_CONTAINER_BEFORE="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
    if [[ -z "${BOOTED_APP_CONTAINER_BEFORE}" || -z "${BOOTED_DATA_CONTAINER_BEFORE}" ]]; then
      echo "SAFETY STOP: Dogfood app/data association was not available after Simulator boot." >&2
      echo "Refusing installation until read-only status confirms whether detached repair is required." >&2
      exit 69
    fi
    APP_CONTAINER_BEFORE="${BOOTED_APP_CONTAINER_BEFORE}"
    terminate_dogfood_app_for_overlay
    DATA_CONTAINER_BEFORE="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
  fi
  PRIMARY_STORE_BEFORE=""
  if [[ -n "${DATA_CONTAINER_BEFORE}" && -d "${DATA_CONTAINER_BEFORE}" ]]; then
    PRIMARY_STORE_BEFORE="$(primary_store_path "${DATA_CONTAINER_BEFORE}" || true)"
  fi
  if [[ -z "${DATA_CONTAINER_BEFORE}" || -z "${PRIMARY_STORE_BEFORE}" ]]; then
    echo "SAFETY STOP: Dogfood persistent data disappeared before overlay installation." >&2
    exit 69
  fi
  assert_store_identity "${PRIMARY_STORE_BEFORE}"
  "${DOGFOOD_USER_STATUS_SCRIPT}" \
    --store "${PRIMARY_STORE_BEFORE}" \
    --preferences "${DATA_CONTAINER_BEFORE}/Library/Preferences/${BUNDLE_ID}.plist" \
    --data-container "${DATA_CONTAINER_BEFORE}" \
    --require-safe \
    --json >/dev/null
  PERSISTENT_DATA_FINGERPRINT_BEFORE="$(persistent_data_fingerprint "${DATA_CONTAINER_BEFORE}" "${BUNDLE_ID}")"
  PERSISTENT_DATA_FINGERPRINT_CONFIRM="$(persistent_data_fingerprint "${DATA_CONTAINER_BEFORE}" "${BUNDLE_ID}")"
  if [[ "${PERSISTENT_DATA_FINGERPRINT_CONFIRM}" != "${PERSISTENT_DATA_FINGERPRINT_BEFORE}" ]]; then
    echo "SAFETY STOP: Dogfood durable data was still changing after app termination." >&2
    exit 69
  fi
  if [[ "${REPAIR_DETACHED_ASSOCIATION}" == "1" ]]; then
    REPAIR_APP_CONTAINER_PREINSTALL="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" app 2>/dev/null || true)"
    REPAIR_DATA_CONTAINER_PREINSTALL="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
    REPAIR_METADATA_CONTAINERS_PREINSTALL="$(metadata_data_containers_for_bundle "${SIMULATOR_UDID}" "${BUNDLE_ID}" || true)"
    REPAIR_METADATA_COUNT_PREINSTALL="$(printf '%s\n' "${REPAIR_METADATA_CONTAINERS_PREINSTALL}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
    REPAIR_METADATA_CANONICAL_PREINSTALL=""
    if [[ "${REPAIR_METADATA_COUNT_PREINSTALL}" == "1" ]]; then
      REPAIR_METADATA_CANONICAL_PREINSTALL="$(canonical_existing_path "${REPAIR_METADATA_CONTAINERS_PREINSTALL}")"
    fi
    if [[ -n "${REPAIR_APP_CONTAINER_PREINSTALL}" || -n "${REPAIR_DATA_CONTAINER_PREINSTALL}" || \
          "${REPAIR_METADATA_COUNT_PREINSTALL}" != "1" || \
          "${REPAIR_METADATA_CANONICAL_PREINSTALL}" != "${DETACHED_DATA_CONTAINER_BEFORE}" ]]; then
      echo "SAFETY STOP: detached Dogfood state changed before the authorized repair install." >&2
      exit 69
    fi
    PERSISTENT_DATA_FINGERPRINT_PREINSTALL="$(persistent_data_fingerprint "${DETACHED_DATA_CONTAINER_BEFORE}" "${BUNDLE_ID}")"
    if [[ "${PERSISTENT_DATA_FINGERPRINT_PREINSTALL}" != "${PERSISTENT_DATA_FINGERPRINT_BEFORE}" ]]; then
      echo "SAFETY STOP: detached Dogfood durable data changed before repair installation." >&2
      exit 69
    fi
  fi
fi

echo "Installing ${APP_PATH}"
xcrun simctl install "${SIMULATOR_UDID}" "${APP_PATH}"

DATA_CONTAINER_AFTER="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
if [[ "${INITIALIZE_USER}" != "1" ]]; then
  if [[ -z "${DATA_CONTAINER_AFTER}" || ! -d "${DATA_CONTAINER_AFTER}" ]]; then
    echo "SAFETY STOP: Dogfood data container disappeared during overlay installation." >&2
    exit 69
  fi
  if [[ -z "$(primary_store_path "${DATA_CONTAINER_AFTER}" || true)" ]]; then
    echo "SAFETY STOP: Dogfood primary store disappeared during overlay installation." >&2
    exit 69
  fi
  if [[ "${REPAIR_DETACHED_ASSOCIATION}" == "1" ]]; then
    METADATA_DATA_CONTAINERS_AFTER="$(metadata_data_containers_for_bundle "${SIMULATOR_UDID}" "${BUNDLE_ID}" || true)"
    METADATA_DATA_CONTAINER_COUNT_AFTER="$(printf '%s\n' "${METADATA_DATA_CONTAINERS_AFTER}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
    METADATA_DATA_CONTAINER_CANONICAL_AFTER=""
    if [[ "${METADATA_DATA_CONTAINER_COUNT_AFTER}" == "1" ]]; then
      METADATA_DATA_CONTAINER_CANONICAL_AFTER="$(canonical_existing_path "${METADATA_DATA_CONTAINERS_AFTER}")"
    fi
    if [[ "${METADATA_DATA_CONTAINER_COUNT_AFTER}" != "1" || \
          "$(canonical_existing_path "${DATA_CONTAINER_AFTER}")" != "${DETACHED_DATA_CONTAINER_BEFORE}" || \
          "${METADATA_DATA_CONTAINER_CANONICAL_AFTER}" != "${DETACHED_DATA_CONTAINER_BEFORE}" ]]; then
      echo "SAFETY STOP: detached repair did not reconnect the original authoritative data container." >&2
      printf '%s\n' "${METADATA_DATA_CONTAINERS_AFTER}" | sed '/^$/d;s/^/  - /' >&2
      exit 69
    fi
    APP_CONTAINER_AFTER="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" app 2>/dev/null || true)"
    if [[ -z "${APP_CONTAINER_AFTER}" || ! -d "${APP_CONTAINER_AFTER}" ]]; then
      echo "SAFETY STOP: detached repair did not restore an installed App container." >&2
      exit 69
    fi
    validate_app_artifact "${APP_CONTAINER_AFTER}"
    INSTALLED_APP_VERSION="$(app_plist_value "${APP_CONTAINER_AFTER}" CFBundleShortVersionString)"
    INSTALLED_APP_BUILD="$(app_plist_value "${APP_CONTAINER_AFTER}" CFBundleVersion)"
    if [[ "${INSTALLED_APP_VERSION}" != "${ARTIFACT_APP_VERSION}" || \
          "${INSTALLED_APP_BUILD}" != "${ARTIFACT_APP_BUILD}" ]]; then
      echo "SAFETY STOP: repaired Dogfood App does not match the validated Release artifact." >&2
      exit 69
    fi
  fi
  PERSISTENT_DATA_FINGERPRINT_AFTER="$(persistent_data_fingerprint "${DATA_CONTAINER_AFTER}" "${BUNDLE_ID}")"
  if [[ "${PERSISTENT_DATA_FINGERPRINT_AFTER}" != "${PERSISTENT_DATA_FINGERPRINT_BEFORE}" ]]; then
    echo "SAFETY STOP: Dogfood durable-data fingerprint changed during overlay installation." >&2
    exit 69
  fi
  PRIMARY_STORE_AFTER="$(primary_store_path "${DATA_CONTAINER_AFTER}")"
  assert_store_identity "${PRIMARY_STORE_AFTER}"
  "${DOGFOOD_USER_STATUS_SCRIPT}" \
    --store "${PRIMARY_STORE_AFTER}" \
    --preferences "${DATA_CONTAINER_AFTER}/Library/Preferences/${BUNDLE_ID}.plist" \
    --data-container "${DATA_CONTAINER_AFTER}" \
    --require-safe \
    --json >/dev/null
  if [[ "${DATA_CONTAINER_AFTER}" == "${DATA_CONTAINER_BEFORE}" ]]; then
    echo "Dogfood durable data preserved across overlay (container path unchanged)."
  else
    echo "Dogfood durable data preserved across overlay; CoreSimulator remounted the logical data container."
    echo "  before: ${DATA_CONTAINER_BEFORE}"
    echo "  after:  ${DATA_CONTAINER_AFTER}"
  fi
  if [[ "${REPAIR_DETACHED_ASSOCIATION}" == "1" ]]; then
    echo "Dogfood detached App association repaired with sealed identity and byte-identical durable data."
  fi
fi

echo "Launching ${BUNDLE_ID}"
xcrun simctl launch "${SIMULATOR_UDID}" "${BUNDLE_ID}" "$@"

if [[ "${INITIALIZE_USER}" != "1" ]]; then
  write_overlay_receipt \
    "${PREVIOUS_APP_VERSION}" \
    "${PREVIOUS_APP_BUILD}" \
    "${ARTIFACT_APP_VERSION}" \
    "${ARTIFACT_APP_BUILD}" \
    "${REPAIR_DETACHED_ASSOCIATION}"
fi

if [[ "${INITIALIZE_USER}" == "1" ]]; then
  if [[ "${PIN_NEEDS_CREATION}" == "1" ]]; then
    mkdir -p "$(dirname "${PIN_FILE}")"
    PIN_TEMPORARY="${PIN_FILE}.tmp.$$"
    printf '%s\n' "${SIMULATOR_UDID}" > "${PIN_TEMPORARY}"
    chmod 600 "${PIN_TEMPORARY}"
    mv "${PIN_TEMPORARY}" "${PIN_FILE}"
  fi
  rm -f "${INITIALIZATION_STATE_FILE}"
  echo "Complete the synthetic user baseline through normal UI, then run:"
  echo "  scripts/run-dogfood-simulator.sh --require-ready"
fi
