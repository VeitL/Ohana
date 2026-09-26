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

section "Shared external Xcode cache"
echo "Cache identity: ${OHANA_LOCAL_BUILD_CACHE_ID}"
echo "Common repository: ${OHANA_LOCAL_BUILD_COMMON_REPO_ROOT}"
print_path_size "${OHANA_TEST_DERIVED_DATA_PATH}" "tests (active shared lane)"
print_path_size "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" "dogfood build cache (active; Simulator data separately protected)"
print_path_size "${OHANA_RELEASE_DERIVED_DATA_PATH}" "release (active shared lane)"
print_path_size "${OHANA_TEST_RESULT_ROOT}" "managed TestResults"
print_path_size "${OHANA_LOCAL_BUILD_CACHE_ROOT}" "shared cache total"
print_path_size "${OHANA_LOCAL_BUILD_REPO_ROOT}/.build" ".build total"

section "Legacy worktree-local DerivedData"
legacy_count=0
worktree_rows="$(git -C "${OHANA_LOCAL_BUILD_REPO_ROOT}" worktree list --porcelain 2>/dev/null | \
  awk '/^worktree / { sub(/^worktree /, ""); print }' || true)"
[[ -n "${worktree_rows}" ]] || worktree_rows="${OHANA_LOCAL_BUILD_REPO_ROOT}"
while IFS= read -r worktree_root; do
  [[ -n "${worktree_root}" ]] || continue
  for path in "${worktree_root}/.build/DerivedData"/*; do
    [[ -e "${path}" ]] || continue
    print_path_size "${path}" "${path} (legacy candidate)"
    legacy_count=$((legacy_count + 1))
  done
done <<< "${worktree_rows}"
if [[ "${legacy_count}" == "0" ]]; then
  echo "none"
fi

section "Managed xcresult retention"
failure_count="$({ find "${OHANA_TEST_RESULT_ROOT}/failed" -mindepth 1 -maxdepth 1 \
  -type d -name '*.xcresult' 2>/dev/null || true; } | wc -l | tr -d ' ')"
success_count="$({ find "${OHANA_TEST_RESULT_ROOT}/success" -mindepth 1 -maxdepth 1 \
  -type d -name '*.xcresult' 2>/dev/null || true; } | wc -l | tr -d ' ')"
staging_count="$({ find "${OHANA_TEST_RESULT_ROOT}/staging" -mindepth 1 -maxdepth 1 \
  -type d -name '*.xcresult' 2>/dev/null || true; } | wc -l | tr -d ' ')"
printf '%9s  %s retained failure(s); cap %s, expiry %s days\n' \
  "$(ohana_format_kib_human "$(ohana_path_size_kib "${OHANA_TEST_RESULT_ROOT}/failed")")" \
  "${failure_count}" "${OHANA_TEST_FAILURE_RETENTION_COUNT}" "${OHANA_TEST_FAILURE_RETENTION_DAYS}"
printf '%9s  %s explicitly retained success result(s)\n' \
  "$(ohana_format_kib_human "$(ohana_path_size_kib "${OHANA_TEST_RESULT_ROOT}/success")")" \
  "${success_count}"
printf '%9s  %s in-progress/stale staging result(s)\n' \
  "$(ohana_format_kib_human "$(ohana_path_size_kib "${OHANA_TEST_RESULT_ROOT}/staging")")" \
  "${staging_count}"
legacy_result_count=0
while IFS= read -r worktree_root; do
  [[ -n "${worktree_root}" ]] || continue
  for path in "${worktree_root}"/.build/*.xcresult "${worktree_root}"/.build/TestResults; do
    [[ -e "${path}" ]] || continue
    print_path_size "${path}" "${path} (legacy result candidate)"
    legacy_result_count=$((legacy_result_count + 1))
  done
done <<< "${worktree_rows}"
[[ "${legacy_result_count}" != "0" ]] || echo "no legacy worktree results"

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

if [[ "${OHANA_LOCAL_BUILD_STORAGE_FIXTURE_MODE:-0}" == "0" ]]; then
  section "CoreSimulator amplification detectors"
  print_path_size "${HOME}/Library/Developer/CoreSimulator" "CoreSimulator user data total (report only)"
  runtime_volume_kib="$({
    du -sk "/Library/Developer/CoreSimulator/Volumes" 2>/dev/null || true
  } | awk 'NR == 1 { print $1 + 0 }')"
  printf '%9s  %s\n' \
    "$(ohana_format_kib_human "${runtime_volume_kib:-0}")" \
    "installed Simulator runtime volumes (report only)"
  print_path_size "${HOME}/Library/Logs/CoreSimulator" "CoreSimulator logs currently linked on disk"
  deleted_log_rows="$(
    lsof -nP +L1 2>/dev/null | awk '
      $NF ~ /\/CoreSimulator\.log$/ { print }
    ' || true
  )"
  if [[ -n "${deleted_log_rows}" ]]; then
    echo "WARNING: deleted-but-open CoreSimulator log(s) still consume blocks:"
    printf '  %s\n' "${deleted_log_rows}"
    echo "A failed diagnostics export can copy each hidden log in full, multiplying one leak into several GiB."
  else
    echo "no deleted-but-open CoreSimulator log detected"
  fi

  echo "Active Xcode/test processes:"
  active_xcode_rows="$(
    {
      pgrep -x -l xcodebuild 2>/dev/null || true
      pgrep -x -l xctest 2>/dev/null || true
    } | LC_ALL=C sort -u
  )"
  if [[ -n "${active_xcode_rows}" ]]; then
    printf '  %s\n' "${active_xcode_rows}"
  else
    echo "  none"
  fi

  diagnostic_roots=()
  user_tmp_root="${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)}"
  if [[ -n "${user_tmp_root}" && -d "${user_tmp_root}" ]]; then
    while IFS= read -r path; do
      [[ -n "${path}" ]] && diagnostic_roots+=("$(dirname "$(dirname "${path}")")")
    done < <(
      find "${user_tmp_root}" -maxdepth 5 -type f \
        -path '*/simctl_diagnostics/CoreSimulator.log' -print 2>/dev/null || true
    )
  fi
  if [[ ${#diagnostic_roots[@]} -gt 0 ]]; then
    echo "Simulator diagnostic exports in user TMPDIR (report only; ownership may be another project):"
    printf '%s\n' "${diagnostic_roots[@]}" | LC_ALL=C sort -u | while IFS= read -r path; do
      print_path_size "${path}" "${path}"
    done
  else
    echo "no Simulator diagnostic export with a copied CoreSimulator.log found in user TMPDIR"
  fi

  unavailable_count="$(
    xcrun simctl list devices -j 2>/dev/null | python3 -c '
import json, sys
payload = json.load(sys.stdin)
print(sum(1 for devices in payload.get("devices", {}).values()
          for device in devices if not device.get("isAvailable", True)))
' 2>/dev/null || echo 0
  )"
  clone_count="$(
    xcrun simctl list devices -j 2>/dev/null | python3 -c '
import json, sys
payload = json.load(sys.stdin)
print(sum(1 for devices in payload.get("devices", {}).values()
          for device in devices if "clone" in device.get("name", "").lower()))
' 2>/dev/null || echo 0
  )"
  echo "Unavailable Simulator devices: ${unavailable_count}"
  echo "Clone-named Simulator devices: ${clone_count}"
  echo "The audit never deletes runtimes, DeviceSupport, healthy devices, or the pinned Dogfood phone."
fi

section "Next step"
echo "No files were changed or deleted."
echo "Run scripts/cleanup-local-build-storage.sh to print the exact conservative cleanup plan and confirmation token."
