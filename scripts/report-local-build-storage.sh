#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"
ohana_assert_storage_fixture_configuration "${REPO_ROOT}"

section() {
  printf '\n== %s ==\n' "$1"
}

print_path_size() {
  local path="$1"
  local label="${2:-${path}}"
  local size_kib
  size_kib="$(ohana_path_size_kib "${path}")"
  printf '%9s  %s\n' "$(ohana_format_kib_human "${size_kib}")" "${label}"
}

section "Disk gate"
available_kib="$(ohana_available_disk_kib)"
printf '%9s  free on the data volume\n' "$(ohana_format_kib_as_gib "${available_kib}")"
printf '%9s  minimum required before build/test\n' "${OHANA_MINIMUM_FREE_GIB} GiB"
if ((available_kib < OHANA_MINIMUM_FREE_GIB * 1024 * 1024)); then
  echo "status: BLOCKED"
else
  echo "status: ready"
fi
ohana_print_largest_storage_sources

section "Fixed DerivedData lanes"
print_path_size "${OHANA_TEST_DERIVED_DATA_PATH}" "tests (preserve)"
print_path_size "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" "dogfood (preserve)"
print_path_size "${OHANA_RELEASE_DERIVED_DATA_PATH}" "release (preserve)"
print_path_size "${OHANA_LOCAL_BUILD_REPO_ROOT}/.build" ".build total"

section "Legacy DerivedData candidates"
legacy_count=0
for path in "${OHANA_LOCAL_DERIVED_DATA_ROOT}"/*; do
  [[ -e "${path}" ]] || continue
  ohana_is_fixed_derived_data_lane "${path}" && continue
  print_path_size "${path}" "${path}"
  legacy_count=$((legacy_count + 1))
done
if [[ "${legacy_count}" == "0" ]]; then
  echo "none"
fi

section "Simulator devices and cache"
dogfood_udid="$(ohana_pinned_dogfood_udid || true)"
test_udid="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}" || true)"
simulator_rows="$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, sys

payload = json.load(sys.stdin)
rows = []
for runtime, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable"):
            rows.append((device.get("udid", ""), device.get("name", ""), runtime, device.get("state", "")))
for row in rows:
    print("\t".join(row))
' || true)"
if [[ -z "${simulator_rows}" ]]; then
  echo "CoreSimulator unavailable"
else
  while IFS=$'\t' read -r udid name runtime state; do
    [[ -n "${udid}" ]] || continue
    role="other"
    if [[ "${udid}" == "${dogfood_udid}" ]]; then
      role="DOGFOOD PRESERVE"
    elif [[ "${udid}" == "${test_udid}" ]]; then
      role="TESTS DISPOSABLE"
    fi
    device_root="${HOME}/Library/Developer/CoreSimulator/Devices/${udid}"
    device_kib="$(ohana_path_size_kib "${device_root}")"
    cache_kib="$(ohana_path_size_kib "${device_root}/data/Library/Caches")"
    printf '%s | %s | %s | %s | total %s | cache %s\n' \
      "${name}" "${udid}" "${runtime}" "${role}/${state}" \
      "$(ohana_format_kib_human "${device_kib}")" \
      "$(ohana_format_kib_human "${cache_kib}")"
    if ((cache_kib > OHANA_SIMULATOR_CACHE_WARNING_GIB * 1024 * 1024)); then
      echo "  largest cache owners:"
      while IFS=$'\t' read -r owner_kib owner_path; do
        [[ -n "${owner_kib}" && -n "${owner_path}" ]] || continue
        printf '    %9s  %s\n' \
          "$(ohana_format_kib_human "${owner_kib}")" "$(basename "${owner_path}")"
      done < <(du -sk "${device_root}/data/Library/Caches"/* 2>/dev/null | sort -nr | head -n 5 || true)
    fi
  done <<< "${simulator_rows}"
fi

if [[ -n "${dogfood_udid}" ]]; then
  app_data="$(xcrun simctl get_app_container "${dogfood_udid}" com.guanchen.li.Ohana data 2>/dev/null || true)"
  if [[ -n "${app_data}" && -d "${app_data}" ]]; then
    print_path_size "${app_data}" "Ohana Dogfood app data (preserve)"
  fi
fi

section "Xcode DeviceSupport"
device_support_root="${HOME}/Library/Developer/Xcode/iOS DeviceSupport"
print_path_size "${device_support_root}" "DeviceSupport total"
device_support_count=0
for path in "${device_support_root}"/*; do
  [[ -e "${path}" ]] || continue
  print_path_size "${path}" "$(basename "${path}")"
  device_support_count=$((device_support_count + 1))
done
if [[ "${device_support_count}" == "0" ]]; then
  echo "none"
fi
echo "Keep only OS/build versions for physical devices that still need to connect; this report never deletes them."

section "${OHANA_LOCAL_BUILD_TMP_ROOT} build and archive roots"
tmp_count=0
for path in "${OHANA_LOCAL_BUILD_TMP_ROOT}"/OhanaDerivedData* \
  "${OHANA_LOCAL_BUILD_TMP_ROOT}"/OhanaArchives; do
  [[ -e "${path}" ]] || continue
  label="${path}"
  if [[ "${path}" == "${OHANA_LOCAL_BUILD_TMP_ROOT}/OhanaArchives" ]]; then
    label="${path} (preserve; cleanup never deletes this tree)"
  fi
  print_path_size "${path}" "${label}"
  tmp_count=$((tmp_count + 1))
done
if [[ "${tmp_count}" == "0" ]]; then
  echo "none"
fi

section "${OHANA_LOCAL_BUILD_TMP_ROOT}/ohana-* artifacts"
tmp_artifact_count=0
tmp_artifact_kib=0
tmp_candidate_count=0
tmp_candidate_kib=0
ohana_tmp_artifact_ttl_seconds >/dev/null
echo "Expiry threshold: ${OHANA_LOCAL_BUILD_TMP_TTL_HOURS} h; age uses the newest item in each artifact tree."
for path in "${OHANA_LOCAL_BUILD_TMP_ROOT}"/ohana-*; do
  [[ -e "${path}" || -L "${path}" ]] || continue
  size_kib="$(ohana_path_size_kib "${path}")"
  age_seconds="$(ohana_path_age_seconds "${path}" || true)"
  state="$(ohana_tmp_artifact_state "${path}" "${age_seconds}")"
  if [[ -n "${age_seconds}" ]]; then
    age_label="$(ohana_format_age_seconds "${age_seconds}")"
  else
    age_label="unknown"
  fi
  case "${state}" in
    candidate)
      disposition="EXPIRED CANDIDATE"
      tmp_candidate_count=$((tmp_candidate_count + 1))
      tmp_candidate_kib=$((tmp_candidate_kib + size_kib))
      ;;
    recent)
      disposition="preserve: recent"
      ;;
    active)
      disposition="preserve: open files"
      ;;
    unsafe)
      disposition="preserve: unsafe boundary/owner/symlink"
      ;;
    *)
      disposition="preserve: activity/age could not be verified"
      ;;
  esac
  printf '%9s  age %-9s  %-39s  %s\n' \
    "$(ohana_format_kib_human "${size_kib}")" "${age_label}" "${disposition}" "${path}"
  tmp_artifact_kib=$((tmp_artifact_kib + size_kib))
  tmp_artifact_count=$((tmp_artifact_count + 1))
done
if [[ "${tmp_artifact_count}" == "0" ]]; then
  echo "none"
else
  printf '%9s  %s artifact(s) total\n' \
    "$(ohana_format_kib_human "${tmp_artifact_kib}")" "${tmp_artifact_count}"
  printf '%9s  %s expired safe candidate(s)\n' \
    "$(ohana_format_kib_human "${tmp_candidate_kib}")" "${tmp_candidate_count}"
fi

section "Read-only Git and system Xcode growth detectors"
conflict_summary="$(ohana_git_numbered_conflict_copy_summary)"
conflict_count="${conflict_summary%%$'\t'*}"
conflict_kib="${conflict_summary#*$'\t'}"
printf '%9s  %s numbered conflict copy/copies under .git/objects or .git/index*\n' \
  "$(ohana_format_kib_human "${conflict_kib}")" "${conflict_count}"
if ((conflict_count > 0)); then
  echo "WARNING: numbered Finder/conflict copies are not Git object names and can grow every sync cycle. Report only; this script never deletes .git."
fi

print_path_size "${OHANA_XCODE_DERIVED_DATA_ROOT}" "Xcode default DerivedData total (report only)"
xcode_ohana_count=0
xcode_ohana_kib=0
for path in "${OHANA_XCODE_DERIVED_DATA_ROOT}"/Ohana-*; do
  [[ -e "${path}" ]] || continue
  size_kib="$(ohana_path_size_kib "${path}")"
  xcode_ohana_kib=$((xcode_ohana_kib + size_kib))
  xcode_ohana_count=$((xcode_ohana_count + 1))
done
printf '%9s  %s Ohana-named Xcode cache(s)\n' \
  "$(ohana_format_kib_human "${xcode_ohana_kib}")" "${xcode_ohana_count}"
echo "These system caches sit outside Ohana's fixed lanes and may come from Xcode UI builds or older repo checkouts; inspect them separately."

section "Next step"
echo "No files were changed or deleted."
echo "Run scripts/cleanup-local-build-storage.sh to print the exact conservative cleanup plan and confirmation token."
