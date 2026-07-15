#!/usr/bin/env bash

# Shared local build/test safety policy. This file is sourced by entrypoint
# scripts; it intentionally performs no work while being loaded.

OHANA_LOCAL_BUILD_REPO_ROOT_INPUT="${OHANA_LOCAL_BUILD_REPO_ROOT:-$(dirname "${BASH_SOURCE[0]}")/../..}"
OHANA_LOCAL_BUILD_REPO_ROOT="$(cd "${OHANA_LOCAL_BUILD_REPO_ROOT_INPUT}" && pwd)"
unset OHANA_LOCAL_BUILD_REPO_ROOT_INPUT
OHANA_LOCAL_DERIVED_DATA_ROOT="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/DerivedData"
OHANA_TEST_DERIVED_DATA_PATH="${OHANA_LOCAL_DERIVED_DATA_ROOT}/tests"
OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED="${OHANA_LOCAL_DERIVED_DATA_ROOT}/dogfood"
OHANA_RELEASE_DERIVED_DATA_PATH="${OHANA_LOCAL_DERIVED_DATA_ROOT}/release"
OHANA_DOGFOOD_PIN_FILE="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/dogfood-simulator.udid"
OHANA_TEST_SIMULATOR_NAME_FIXED="iPhone 17 Tests"
OHANA_MINIMUM_FREE_GIB=20
OHANA_BUILD_WARNING_GIB=25
OHANA_SIMULATOR_CACHE_WARNING_GIB=10

ohana_absolute_path() {
  python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$1"
}

ohana_format_kib_as_gib() {
  awk -v kib="$1" 'BEGIN { printf "%.1f GiB", kib / 1024 / 1024 }'
}

ohana_format_kib_human() {
  awk -v kib="$1" 'BEGIN {
    if (kib < 1024 * 1024) {
      printf "%.1f MiB", kib / 1024
    } else {
      printf "%.1f GiB", kib / 1024 / 1024
    }
  }'
}

ohana_path_size_kib() {
  local path="$1"
  if [[ ! -e "${path}" ]]; then
    printf '0\n'
    return 0
  fi
  du -sk "${path}" 2>/dev/null | awk 'NR == 1 { print $1 + 0 }'
}

ohana_available_disk_kib() {
  df -Pk "${OHANA_LOCAL_BUILD_REPO_ROOT}" | awk 'NR == 2 { print $4 + 0 }'
}

ohana_simulator_cache_size_kib() {
  local devices_root="${HOME}/Library/Developer/CoreSimulator/Devices"
  local total=0
  local cache_path

  for cache_path in "${devices_root}"/*/data/Library/Caches; do
    [[ -d "${cache_path}" ]] || continue
    total=$((total + $(ohana_path_size_kib "${cache_path}")))
  done
  printf '%s\n' "${total}"
}

ohana_warn_storage_pressure() {
  local build_kib
  local simulator_cache_kib
  local build_limit_kib=$((OHANA_BUILD_WARNING_GIB * 1024 * 1024))
  local simulator_limit_kib=$((OHANA_SIMULATOR_CACHE_WARNING_GIB * 1024 * 1024))

  build_kib="$(ohana_path_size_kib "${OHANA_LOCAL_BUILD_REPO_ROOT}/.build")"
  if ((build_kib > build_limit_kib)); then
    echo "WARNING: repo .build is $(ohana_format_kib_as_gib "${build_kib}"); policy warning limit is ${OHANA_BUILD_WARNING_GIB} GiB." >&2
  fi

  simulator_cache_kib="$(ohana_simulator_cache_size_kib)"
  if ((simulator_cache_kib > simulator_limit_kib)); then
    echo "WARNING: Simulator Library/Caches total is $(ohana_format_kib_as_gib "${simulator_cache_kib}"); policy warning limit is ${OHANA_SIMULATOR_CACHE_WARNING_GIB} GiB." >&2
  fi

  if ((build_kib > build_limit_kib || simulator_cache_kib > simulator_limit_kib)); then
    echo "Run scripts/report-local-build-storage.sh before approving any cleanup." >&2
  fi
}

ohana_require_build_disk_space() {
  local available_kib
  local minimum_kib=$((OHANA_MINIMUM_FREE_GIB * 1024 * 1024))

  available_kib="$(ohana_available_disk_kib)"
  if ((available_kib < minimum_kib)); then
    echo "Refusing to build or test: only $(ohana_format_kib_as_gib "${available_kib}") is free; ${OHANA_MINIMUM_FREE_GIB} GiB is required." >&2
    ohana_warn_storage_pressure
    echo "No cache was deleted. Run scripts/report-local-build-storage.sh, review the report, then explicitly confirm a cleanup plan." >&2
    return 74
  fi

  ohana_warn_storage_pressure
}

ohana_expected_derived_data_path() {
  case "$1" in
    tests)
      printf '%s\n' "${OHANA_TEST_DERIVED_DATA_PATH}"
      ;;
    dogfood)
      printf '%s\n' "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}"
      ;;
    release)
      printf '%s\n' "${OHANA_RELEASE_DERIVED_DATA_PATH}"
      ;;
    *)
      echo "Unknown local build lane: $1" >&2
      return 2
      ;;
  esac
}

ohana_assert_fixed_derived_data_path() {
  local lane="$1"
  local requested_path="$2"
  local expected_path
  local requested_absolute

  expected_path="$(ohana_expected_derived_data_path "${lane}")" || return
  requested_absolute="$(ohana_absolute_path "${requested_path}")"
  if [[ "${requested_absolute}" != "${expected_path}" ]]; then
    echo "Refusing one-off DerivedData path for ${lane}: ${requested_absolute}" >&2
    echo "Required fixed path: ${expected_path}" >&2
    echo "Use only the tests, dogfood, and release cache lanes; task-*/tfu-* caches are forbidden." >&2
    return 2
  fi
}

ohana_pinned_dogfood_udid() {
  if [[ ! -f "${OHANA_DOGFOOD_PIN_FILE}" ]]; then
    return 1
  fi
  tr -d '[:space:]' < "${OHANA_DOGFOOD_PIN_FILE}"
}

ohana_require_dogfood_pin() {
  local pinned
  pinned="$(ohana_pinned_dogfood_udid || true)"
  if [[ -z "${pinned}" ]]; then
    echo "Refusing automated Simulator work: Dogfood UDID pin is missing at ${OHANA_DOGFOOD_PIN_FILE}." >&2
    echo "Run scripts/run-dogfood-simulator.sh --status and restore the pin before testing." >&2
    return 2
  fi
  printf '%s\n' "${pinned}"
}

ohana_resolve_simulator_by_name() {
  local required_name="$1"
  local simctl_json

  if ! simctl_json="$(xcrun simctl list devices available -j 2>/dev/null)"; then
    echo "Simulator preflight failed: CoreSimulator is not available." >&2
    return 70
  fi

  printf '%s' "${simctl_json}" | python3 -c '
import json, re, sys

required_name = sys.argv[1]
payload = json.load(sys.stdin)
candidates = []
for runtime, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    version = [int(part) for part in re.findall(r"\d+", runtime)]
    for device in devices:
        if device.get("name") == required_name and device.get("isAvailable"):
            candidates.append((version, device.get("udid", "")))
if not candidates:
    raise SystemExit(1)
candidates.sort()
print(candidates[-1][1])
' "${required_name}"
}

ohana_simulator_metadata() {
  local udid="$1"
  xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, sys

udid = sys.argv[1]
payload = json.load(sys.stdin)
for runtime, devices in payload.get("devices", {}).items():
    for device in devices:
        if device.get("udid") == udid and device.get("isAvailable"):
            print("\t".join((device.get("name", ""), runtime, device.get("state", ""))))
            raise SystemExit(0)
raise SystemExit(1)
' "${udid}"
}

ohana_assert_test_simulator_udid() {
  local selected_udid="$1"
  local dogfood_udid
  local metadata
  local selected_name

  dogfood_udid="$(ohana_require_dogfood_pin)" || return
  if [[ "${selected_udid}" == "${dogfood_udid}" ]]; then
    echo "SAFETY STOP: automated tests may not run on the pinned Dogfood Simulator (${dogfood_udid})." >&2
    echo "Use the dedicated '${OHANA_TEST_SIMULATOR_NAME_FIXED}' device." >&2
    return 2
  fi

  metadata="$(ohana_simulator_metadata "${selected_udid}" || true)"
  if [[ -z "${metadata}" ]]; then
    echo "Simulator preflight failed: ${selected_udid} is not an available Simulator." >&2
    return 70
  fi
  selected_name="$(printf '%s' "${metadata}" | awk -F '\t' '{ print $1 }')"
  if [[ "${selected_name}" != "${OHANA_TEST_SIMULATOR_NAME_FIXED}" ]]; then
    echo "SAFETY STOP: automated tests require '${OHANA_TEST_SIMULATOR_NAME_FIXED}', got '${selected_name}' (${selected_udid})." >&2
    return 2
  fi
}

ohana_assert_dogfood_simulator_udid() {
  local selected_udid="$1"
  local pinned_udid

  pinned_udid="$(ohana_pinned_dogfood_udid || true)"
  if [[ -n "${pinned_udid}" && "${selected_udid}" != "${pinned_udid}" ]]; then
    echo "SAFETY STOP: Dogfood is pinned to ${pinned_udid}; refusing alternate Simulator ${selected_udid}." >&2
    return 2
  fi

  if ! ohana_simulator_metadata "${selected_udid}" >/dev/null; then
    echo "Pinned Dogfood Simulator '${selected_udid}' is not available." >&2
    return 70
  fi
}
