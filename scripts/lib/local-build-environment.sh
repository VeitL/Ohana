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
OHANA_DOGFOOD_STORE_IDENTITY_FILE="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/dogfood-store.identity"
OHANA_DOGFOOD_INITIALIZATION_STATE_FILE="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/dogfood-initialization.pending"
OHANA_DOGFOOD_SIMULATOR_NAME_FIXED="iPhone 17 Dogfood"
OHANA_TEST_SIMULATOR_NAME_FIXED="iPhone 17 Tests"
OHANA_LOCAL_BUILD_TMP_ROOT="${OHANA_LOCAL_BUILD_TMP_ROOT:-/private/tmp}"
OHANA_LOCAL_BUILD_TMP_TTL_HOURS="${OHANA_LOCAL_BUILD_TMP_TTL_HOURS:-24}"
OHANA_XCODE_DERIVED_DATA_ROOT="${OHANA_XCODE_DERIVED_DATA_ROOT:-${HOME}/Library/Developer/Xcode/DerivedData}"
OHANA_MINIMUM_FREE_GIB=20
OHANA_BUILD_WARNING_GIB=25
OHANA_SIMULATOR_CACHE_WARNING_GIB=10

ohana_absolute_path() {
  python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$1"
}

ohana_real_path() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
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
  du -skx "${path}" 2>/dev/null | awk 'NR == 1 { print $1 + 0 }'
}

ohana_now_epoch() {
  local now_epoch="${OHANA_LOCAL_BUILD_NOW_EPOCH:-}"

  if [[ -z "${now_epoch}" ]]; then
    date +%s
    return
  fi
  if [[ ! "${now_epoch}" =~ ^[1-9][0-9]*$ || ${#now_epoch} -gt 10 ]]; then
    echo "Invalid OHANA_LOCAL_BUILD_NOW_EPOCH: ${now_epoch}" >&2
    return 2
  fi
  printf '%s\n' "${now_epoch}"
}

ohana_tmp_artifact_ttl_seconds() {
  local invalid_ttl=0

  if [[ ! "${OHANA_LOCAL_BUILD_TMP_TTL_HOURS}" =~ ^[1-9][0-9]*$ || \
    ${#OHANA_LOCAL_BUILD_TMP_TTL_HOURS} -gt 4 ]]; then
    invalid_ttl=1
  elif ((10#${OHANA_LOCAL_BUILD_TMP_TTL_HOURS} < 24 || \
    10#${OHANA_LOCAL_BUILD_TMP_TTL_HOURS} > 8760)); then
    invalid_ttl=1
  fi
  if [[ "${invalid_ttl}" == "1" ]]; then
    echo "Invalid OHANA_LOCAL_BUILD_TMP_TTL_HOURS: ${OHANA_LOCAL_BUILD_TMP_TTL_HOURS}" >&2
    echo "Ohana tmp cleanup requires a TTL from 24 through 8760 hours." >&2
    return 2
  fi
  printf '%s\n' "$((10#${OHANA_LOCAL_BUILD_TMP_TTL_HOURS} * 60 * 60))"
}

ohana_assert_storage_fixture_configuration() {
  local expected_repo_root="${1:-${OHANA_LOCAL_BUILD_REPO_ROOT}}"
  local fixture_mode="${OHANA_LOCAL_BUILD_STORAGE_FIXTURE_MODE:-0}"
  local fixture_root="${OHANA_LOCAL_BUILD_STORAGE_FIXTURE_ROOT:-}"
  local tmp_root_absolute

  tmp_root_absolute="$(ohana_absolute_path "${OHANA_LOCAL_BUILD_TMP_ROOT}")"
  ohana_tmp_artifact_ttl_seconds >/dev/null || return
  if [[ "${fixture_mode}" == "1" ]]; then
    if [[ -z "${fixture_root}" || ! -d "${fixture_root}" || \
      ! -d "${OHANA_LOCAL_BUILD_REPO_ROOT}" || ! -d "${OHANA_LOCAL_BUILD_TMP_ROOT}" ]] || \
      ! ohana_path_is_equal_or_beneath "${OHANA_LOCAL_BUILD_REPO_ROOT}" "${fixture_root}" || \
      ! ohana_path_is_equal_or_beneath "${tmp_root_absolute}" "${fixture_root}"; then
      echo "Refusing invalid local-build storage fixture boundaries." >&2
      return 2
    fi
    return
  fi
  if [[ "${fixture_mode}" != "0" || "${tmp_root_absolute}" != "/private/tmp" || \
    "$(ohana_real_path "${OHANA_LOCAL_BUILD_REPO_ROOT}")" != "$(ohana_real_path "${expected_repo_root}")" || \
    -n "${OHANA_LOCAL_BUILD_NOW_EPOCH:-}" ]]; then
    echo "Refusing production storage overrides; fixture roots and clocks require isolated fixture mode." >&2
    return 2
  fi
}

ohana_path_latest_mtime_epoch() {
  local path="$1"

  [[ -e "${path}" ]] || return 1
  find "${path}" -xdev -exec stat -f '%m' {} + 2>/dev/null | \
    awk 'NR == 1 || $1 > newest { newest = $1 } END { if (NR > 0) print newest }'
}

ohana_path_age_seconds() {
  local path="$1"
  local latest_mtime
  local now_epoch

  latest_mtime="$(ohana_path_latest_mtime_epoch "${path}")" || return
  now_epoch="$(ohana_now_epoch)" || return
  if ((now_epoch <= latest_mtime)); then
    printf '0\n'
  else
    printf '%s\n' "$((now_epoch - latest_mtime))"
  fi
}

ohana_format_age_seconds() {
  local age_seconds="$1"

  if ((age_seconds < 60 * 60)); then
    awk -v seconds="${age_seconds}" 'BEGIN { printf "%.1f min", seconds / 60 }'
  elif ((age_seconds < 24 * 60 * 60)); then
    awk -v seconds="${age_seconds}" 'BEGIN { printf "%.1f h", seconds / 60 / 60 }'
  else
    awk -v seconds="${age_seconds}" 'BEGIN { printf "%.1f d", seconds / 60 / 60 / 24 }'
  fi
}

ohana_path_is_equal_or_beneath() {
  local path_absolute
  local root_absolute

  path_absolute="$(ohana_real_path "$1")"
  root_absolute="$(ohana_real_path "$2")"
  [[ "${path_absolute}" == "${root_absolute}" || "${path_absolute}" == "${root_absolute}/"* ]]
}

ohana_paths_refer_to_same_item() {
  [[ -e "$1" && -e "$2" && "$1" -ef "$2" ]]
}

ohana_is_fixed_derived_data_lane() {
  local path="$1"
  local basename_lower
  local fixed_path

  for fixed_path in "${OHANA_TEST_DERIVED_DATA_PATH}" \
    "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" \
    "${OHANA_RELEASE_DERIVED_DATA_PATH}"; do
    if [[ "$(ohana_absolute_path "${path}")" == "${fixed_path}" ]] || \
      ohana_paths_refer_to_same_item "${path}" "${fixed_path}"; then
      return 0
    fi
  done
  if [[ "$(dirname "$(ohana_absolute_path "${path}")")" == "${OHANA_LOCAL_DERIVED_DATA_ROOT}" ]]; then
    basename_lower="$(basename "${path}" | tr '[:upper:]' '[:lower:]')"
    case "${basename_lower}" in
      tests|dogfood|release) return 0 ;;
    esac
  fi
  return 1
}

ohana_path_is_mount_point() {
  python3 -c 'import os, sys; raise SystemExit(0 if os.path.ismount(sys.argv[1]) else 1)' "$1"
}

ohana_tree_has_mount_boundary() {
  python3 - "$1" <<'PY'
import os
import stat
import sys

try:
    root = os.path.abspath(sys.argv[1])
    root_info = os.lstat(root)
    if not stat.S_ISDIR(root_info.st_mode):
        raise SystemExit(1)
    root_device = root_info.st_dev
    stack = [root]
    while stack:
        current = stack.pop()
        with os.scandir(current) as entries:
            for entry in entries:
                info = entry.stat(follow_symlinks=False)
                if stat.S_ISDIR(info.st_mode):
                    if info.st_dev != root_device:
                        raise SystemExit(0)
                    stack.append(entry.path)
except OSError:
    raise SystemExit(2)
raise SystemExit(1)
PY
}

ohana_assert_safe_tmp_artifact_path() {
  local path="$1"
  local path_absolute
  local path_real
  local root_absolute
  local root_real
  local owner_uid
  local mount_boundary_status

  path_absolute="$(ohana_absolute_path "${path}")"
  root_absolute="$(ohana_absolute_path "${OHANA_LOCAL_BUILD_TMP_ROOT}")"
  path_real="$(ohana_real_path "${path}")"
  root_real="$(ohana_real_path "${OHANA_LOCAL_BUILD_TMP_ROOT}")"

  if [[ "${root_absolute}" == "/" || "${root_real}" == "/" || \
    "$(dirname "${path_absolute}")" != "${root_absolute}" || \
    "$(dirname "${path_real}")" != "${root_real}" ]]; then
    echo "Refusing out-of-bound Ohana tmp artifact: ${path_absolute}" >&2
    return 2
  fi
  case "$(basename "${path_absolute}")" in
    ohana-?*) ;;
    *)
      echo "Refusing non-Ohana tmp artifact: ${path_absolute}" >&2
      return 2
      ;;
  esac
  if [[ ! -e "${path}" ]]; then
    echo "Refusing missing Ohana tmp artifact: ${path_absolute}" >&2
    return 2
  fi
  if [[ -L "${path}" ]]; then
    echo "Refusing symlinked Ohana tmp artifact: ${path_absolute}" >&2
    return 2
  fi
  if ohana_path_is_mount_point "${path}"; then
    echo "Refusing mounted Ohana tmp artifact: ${path_absolute}" >&2
    return 2
  fi
  if ohana_tree_has_mount_boundary "${path}"; then
    echo "Refusing Ohana tmp artifact with a nested mount: ${path_absolute}" >&2
    return 2
  else
    mount_boundary_status=$?
  fi
  if [[ "${mount_boundary_status}" == "2" ]]; then
    echo "Refusing Ohana tmp artifact whose mount boundaries cannot be inspected: ${path_absolute}" >&2
    return 2
  fi
  if ohana_path_is_equal_or_beneath "${path_absolute}" "${OHANA_LOCAL_BUILD_TMP_ROOT}/OhanaArchives" || \
    ohana_path_is_equal_or_beneath "${path_absolute}" "${OHANA_TEST_DERIVED_DATA_PATH}" || \
    ohana_path_is_equal_or_beneath "${path_absolute}" "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" || \
    ohana_path_is_equal_or_beneath "${path_absolute}" "${OHANA_RELEASE_DERIVED_DATA_PATH}"; then
    echo "Refusing protected local build path: ${path_absolute}" >&2
    return 2
  fi
  owner_uid="$(stat -f '%u' "${path}" 2>/dev/null || true)"
  if [[ -z "${owner_uid}" || "${owner_uid}" != "$(id -u)" ]]; then
    echo "Refusing Ohana tmp artifact not owned by the current user: ${path_absolute}" >&2
    return 2
  fi
}

ohana_path_has_open_files() {
  local path="$1"
  local lsof_output
  local lsof_status

  if ! command -v lsof >/dev/null 2>&1; then
    return 2
  fi
  if [[ -d "${path}" ]]; then
    if lsof_output="$(lsof -n -P -t +D "${path}" 2>&1)"; then
      return 0
    else
      lsof_status=$?
    fi
  else
    if lsof_output="$(lsof -n -P -t "${path}" 2>&1)"; then
      return 0
    else
      lsof_status=$?
    fi
  fi
  if [[ "${lsof_status}" == "1" && -z "${lsof_output}" ]]; then
    return 1
  fi
  return 2
}

ohana_tmp_artifact_state() {
  local path="$1"
  local age_seconds
  local lsof_status
  local ttl_seconds

  if ! ohana_assert_safe_tmp_artifact_path "${path}" >/dev/null 2>&1; then
    printf 'unsafe\n'
    return
  fi
  age_seconds="${2:-}"
  if [[ -z "${age_seconds}" ]]; then
    age_seconds="$(ohana_path_age_seconds "${path}" || true)"
  fi
  ttl_seconds="$(ohana_tmp_artifact_ttl_seconds || true)"
  if [[ -z "${age_seconds}" || -z "${ttl_seconds}" ]]; then
    printf 'uninspectable\n'
    return
  fi
  if ((age_seconds < ttl_seconds)); then
    printf 'recent\n'
    return
  fi
  if ohana_path_has_open_files "${path}"; then
    printf 'active\n'
    return
  else
    lsof_status=$?
  fi
  if [[ "${lsof_status}" == "2" ]]; then
    printf 'uninspectable\n'
    return
  fi
  printf 'candidate\n'
}

ohana_tmp_artifact_candidate_stream() {
  local path

  for path in "${OHANA_LOCAL_BUILD_TMP_ROOT}"/ohana-*; do
    [[ -e "${path}" || -L "${path}" ]] || continue
    if [[ "$(ohana_tmp_artifact_state "${path}")" == "candidate" ]]; then
      printf '%s\n' "${path}"
    fi
  done
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

ohana_git_numbered_conflict_copy_stream() {
  local git_root="${OHANA_LOCAL_BUILD_REPO_ROOT}/.git"

  {
    find "${git_root}/objects" -type f -print 2>/dev/null || true
    find "${git_root}" -mindepth 1 -maxdepth 1 -type f -name 'index *' -print 2>/dev/null || true
  } | awk -F / '$NF ~ / [0-9]+(\.[^.]+)?$/ { print }'
}

ohana_git_numbered_conflict_copy_summary() {
  local count=0
  local path
  local total_kib=0

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    count=$((count + 1))
    total_kib=$((total_kib + $(ohana_path_size_kib "${path}")))
  done < <(ohana_git_numbered_conflict_copy_stream)
  printf '%s\t%s\n' "${count}" "${total_kib}"
}

ohana_print_largest_storage_sources() {
  local path
  local size_kib
  local simulator_cache_kib
  local simulator_devices_root="${HOME}/Library/Developer/CoreSimulator/Devices"
  local device_support_root="${HOME}/Library/Developer/Xcode/iOS DeviceSupport"
  local conflict_summary
  local conflict_count
  local source_count=0

  echo "Largest tracked local storage sources:"
  while IFS=$'\t' read -r size_kib path; do
    [[ -n "${size_kib}" && -n "${path}" ]] || continue
    printf '  %9s  %s\n' "$(ohana_format_kib_human "${size_kib}")" "${path}"
    source_count=$((source_count + 1))
  done < <(
    {
      for path in "${OHANA_LOCAL_DERIVED_DATA_ROOT}"/*; do
        [[ -e "${path}" ]] || continue
        size_kib="$(ohana_path_size_kib "${path}")"
        ((size_kib > 0)) && printf '%s\t%s\n' "${size_kib}" "${path}"
      done
      for path in "${OHANA_LOCAL_BUILD_TMP_ROOT}"/ohana-* \
        "${OHANA_LOCAL_BUILD_TMP_ROOT}"/OhanaDerivedData*; do
        [[ -e "${path}" || -L "${path}" ]] || continue
        size_kib="$(ohana_path_size_kib "${path}")"
        ((size_kib > 0)) && printf '%s\t%s\n' "${size_kib}" "${path}"
      done
      path="${OHANA_LOCAL_BUILD_TMP_ROOT}/OhanaArchives"
      if [[ -e "${path}" ]]; then
        size_kib="$(ohana_path_size_kib "${path}")"
        ((size_kib > 0)) && printf '%s\t%s (preserve)\n' "${size_kib}" "${path}"
      fi
      simulator_cache_kib="$(ohana_simulator_cache_size_kib)"
      ((simulator_cache_kib > 0)) && \
        printf '%s\t%s\n' "${simulator_cache_kib}" "Simulator Library/Caches total"
      size_kib="$(ohana_path_size_kib "${simulator_devices_root}")"
      ((size_kib > 0)) && printf '%s\t%s\n' "${size_kib}" "Simulator devices total (preserve)"
      size_kib="$(ohana_path_size_kib "${device_support_root}")"
      ((size_kib > 0)) && printf '%s\t%s\n' "${size_kib}" "${device_support_root} (preserve)"
      size_kib="$(ohana_path_size_kib "${OHANA_XCODE_DERIVED_DATA_ROOT}")"
      ((size_kib > 0)) && printf '%s\t%s\n' "${size_kib}" "${OHANA_XCODE_DERIVED_DATA_ROOT} (report only)"
      conflict_summary="$(ohana_git_numbered_conflict_copy_summary)"
      conflict_count="${conflict_summary%%$'\t'*}"
      size_kib="${conflict_summary#*$'\t'}"
      ((conflict_count > 0 && size_kib > 0)) && \
        printf '%s\t%s\n' "${size_kib}" ".git numbered conflict copies (${conflict_count}; report only)"
    } | LC_ALL=C sort -t $'\t' -k1,1nr | head -n 8
  )
  if [[ "${source_count}" == "0" ]]; then
    echo "  none found"
  fi
}

ohana_warn_storage_pressure() {
  local reason="${1:-warning}"
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
  if [[ "${reason}" == "low-disk" ]]; then
    ohana_print_largest_storage_sources >&2
  fi
}

ohana_require_build_disk_space() {
  local available_kib
  local minimum_kib=$((OHANA_MINIMUM_FREE_GIB * 1024 * 1024))

  available_kib="$(ohana_available_disk_kib)"
  if ((available_kib < minimum_kib)); then
    echo "Refusing to build or test: only $(ohana_format_kib_as_gib "${available_kib}") is free; ${OHANA_MINIMUM_FREE_GIB} GiB is required." >&2
    ohana_warn_storage_pressure low-disk
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

ohana_quiesce_test_simulator_companion_apps() {
  local selected_udid="$1"
  local metadata
  local selected_state
  local bundle_id
  local output
  local terminate_status

  ohana_assert_test_simulator_udid "${selected_udid}" || return
  metadata="$(ohana_simulator_metadata "${selected_udid}")" || return 70
  selected_state="$(printf '%s' "${metadata}" | awk -F '\t' '{ print $3 }')"
  [[ "${selected_state}" == "Booted" ]] || return 0

  # Preview/mirroring hosts are useful for interactive inspection, but they can
  # steal foreground focus between an XCUIElement lookup and its semantic tap.
  # Quiesce them only on the disposable Tests device before XCTest starts.
  for bundle_id in dev.swiftui-preview-browser.host; do
    if output="$(xcrun simctl terminate "${selected_udid}" "${bundle_id}" 2>&1)"; then
      echo "Stopped test-only Simulator companion: ${bundle_id}"
      continue
    else
      terminate_status=$?
    fi
    if grep -qF "found nothing to terminate" <<< "${output}"; then
      continue
    fi
    echo "Simulator companion preflight failed for ${bundle_id}:" >&2
    echo "${output}" >&2
    return "${terminate_status}"
  done
}

ohana_assert_dogfood_simulator_udid() {
  local selected_udid="$1"
  local pinned_udid
  local metadata
  local selected_name

  pinned_udid="$(ohana_pinned_dogfood_udid || true)"
  if [[ -n "${pinned_udid}" && "${selected_udid}" != "${pinned_udid}" ]]; then
    echo "SAFETY STOP: Dogfood is pinned to ${pinned_udid}; refusing alternate Simulator ${selected_udid}." >&2
    return 2
  fi

  metadata="$(ohana_simulator_metadata "${selected_udid}" || true)"
  if [[ -z "${metadata}" ]]; then
    echo "Pinned Dogfood Simulator '${selected_udid}' is not available." >&2
    return 70
  fi
  selected_name="$(printf '%s' "${metadata}" | awk -F '\t' '{ print $1 }')"
  if [[ "${selected_name}" != "${OHANA_DOGFOOD_SIMULATOR_NAME_FIXED}" ]]; then
    echo "SAFETY STOP: Dogfood requires '${OHANA_DOGFOOD_SIMULATOR_NAME_FIXED}', got '${selected_name}' (${selected_udid})." >&2
    echo "Never pin '${OHANA_TEST_SIMULATOR_NAME_FIXED}' or another disposable device as Dogfood." >&2
    return 2
  fi
}

ohana_assert_safe_dogfood_launch_context() {
  local argument

  if [[ -n "${XCTestConfigurationFilePath:-}" || \
    -n "${XCTestBundlePath:-}" || \
    -n "${XCTestSessionIdentifier:-}" ]]; then
    echo "SAFETY STOP: Dogfood may not launch from an XCTest process." >&2
    return 2
  fi

  for argument in "$@"; do
    case "${argument}" in
      -OHANA_*)
        echo "SAFETY STOP: Dogfood rejects Ohana test/debug launch argument '${argument}'." >&2
        echo "Use normal product UI on the persistent synthetic user." >&2
        return 2
        ;;
    esac
  done
}
