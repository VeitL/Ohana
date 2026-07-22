#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"
ohana_assert_storage_fixture_configuration "${REPO_ROOT}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/cleanup-local-build-storage.sh
  scripts/cleanup-local-build-storage.sh --apply <plan-token>

The default is report-only. It preserves the fixed tests, dogfood, and release
DerivedData lanes and the complete local Release Archive tree. --apply succeeds
only when its token exactly matches the current candidate snapshot.

Simulator devices/caches and Xcode DeviceSupport are never deleted. Direct
Ohana `ohana-*` temporary artifacts are eligible only after their newest
content exceeds the configured TTL and no open files are detected.
USAGE
}

mode="report"
provided_token=""
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--apply" && $# -eq 2 ]]; then
    mode="apply"
    provided_token="$2"
  elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
  else
    usage >&2
    exit 2
  fi
fi

current_test_bridge=""
if [[ ! -d "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products" ]]; then
  current_test_bridge="$({
    for path in "${OHANA_LOCAL_DERIVED_DATA_ROOT}"/* \
      "${OHANA_LOCAL_BUILD_TMP_ROOT}"/OhanaDerivedData*; do
      [[ -e "${path}" ]] || continue
      if ohana_is_fixed_derived_data_lane "${path}"; then
        continue
      fi
      modified="$(stat -f '%m' "${path}" 2>/dev/null || true)"
      [[ -n "${modified}" ]] && printf '%s\t%s\n' "${modified}" "${path}"
    done
  } | sort -nr | head -n 1 | cut -f 2- || true)"
fi

cleanup_candidate_kind() {
  local path="$1"
  local path_absolute
  local parent_absolute
  local basename_value
  local mount_boundary_status

  [[ -e "${path}" && ! -L "${path}" ]] || return 2
  path_absolute="$(ohana_absolute_path "${path}")"
  parent_absolute="$(dirname "${path_absolute}")"
  basename_value="$(basename "${path_absolute}")"

  if [[ "${parent_absolute}" == "${OHANA_LOCAL_DERIVED_DATA_ROOT}" ]]; then
    ohana_is_fixed_derived_data_lane "${path}" && return 2
    ohana_path_is_mount_point "${path}" && return 2
    if ohana_tree_has_mount_boundary "${path}"; then
      return 2
    else
      mount_boundary_status=$?
    fi
    [[ "${mount_boundary_status}" == "1" ]] || return 2
    printf 'legacy-derived-data\n'
    return
  fi
  if [[ "$(ohana_real_path "${parent_absolute}")" == "$(ohana_real_path "${OHANA_LOCAL_BUILD_TMP_ROOT}")" && \
    "${basename_value}" == OhanaDerivedData* ]]; then
    ohana_path_is_mount_point "${path}" && return 2
    if ohana_tree_has_mount_boundary "${path}"; then
      return 2
    else
      mount_boundary_status=$?
    fi
    [[ "${mount_boundary_status}" == "1" ]] || return 2
    printf 'legacy-tmp-derived-data\n'
    return
  fi
  if ohana_assert_safe_tmp_artifact_path "${path}" >/dev/null 2>&1; then
    printf 'expired-ohana-tmp\n'
    return
  fi
  return 2
}

candidate_stream() {
  local path

  for path in "${OHANA_LOCAL_DERIVED_DATA_ROOT}"/*; do
    [[ -e "${path}" ]] || continue
    ohana_is_fixed_derived_data_lane "${path}" && continue
    [[ "${path}" != "${current_test_bridge}" ]] || continue
    printf '%s\n' "${path}"
  done

  for path in "${OHANA_LOCAL_BUILD_TMP_ROOT}"/OhanaDerivedData*; do
    [[ -e "${path}" ]] || continue
    [[ "${path}" != "${current_test_bridge}" ]] || continue
    printf '%s\n' "${path}"
  done

  ohana_tmp_artifact_candidate_stream
}

candidates=()
while IFS= read -r candidate; do
  [[ -n "${candidate}" ]] || continue
  candidates+=("${candidate}")
done < <(candidate_stream | LC_ALL=C sort -u)

if [[ ${#candidates[@]} -eq 0 ]]; then
  if [[ "${mode}" == "apply" ]]; then
    echo "Refusing cleanup: the confirmed plan no longer has any candidates." >&2
    exit 2
  fi
  echo "No conservative cleanup candidates found."
  exit 0
fi

validated_candidates=()
for candidate in "${candidates[@]}"; do
  if cleanup_candidate_kind "${candidate}" >/dev/null; then
    validated_candidates+=("${candidate}")
  else
    echo "Refusing cleanup candidate outside the approved boundaries: ${candidate}" >&2
    exit 2
  fi
done
candidates=("${validated_candidates[@]}")

candidate_tree_fingerprint() {
  python3 - "$1" <<'PY'
import hashlib
import os
import stat
import struct
import sys

root = os.path.abspath(sys.argv[1])
root_device = os.lstat(root).st_dev
digest = hashlib.sha256()

def add_bytes(value):
    digest.update(struct.pack(">Q", len(value)))
    digest.update(value)

stack = [(root, b".")]
while stack:
    path, relative = stack.pop()
    info = os.lstat(path)
    add_bytes(relative)
    ctime_ns = 0 if relative == b"." else info.st_ctime_ns
    add_bytes(struct.pack(
        ">QQQQQQQQQQ",
        info.st_mode,
        info.st_dev,
        info.st_ino,
        info.st_uid,
        info.st_gid,
        info.st_nlink,
        info.st_size,
        info.st_mtime_ns,
        ctime_ns,
        info.st_blocks,
    ))
    if relative == b"." and stat.S_ISREG(info.st_mode):
        content_digest = hashlib.sha256()
        with open(path, "rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                content_digest.update(chunk)
        add_bytes(content_digest.digest())
    if stat.S_ISDIR(info.st_mode) and info.st_dev == root_device:
        children = sorted(os.scandir(path), key=lambda item: os.fsencode(item.name), reverse=True)
        for child in children:
            child_relative = os.path.join(os.fsdecode(relative), child.name)
            stack.append((child.path, os.fsencode(child_relative)))

print(digest.hexdigest())
PY
}

candidate_plan_token() {
  local candidate

  {
    for candidate in "${candidates[@]}"; do
      printf '%s\0%s\0' "${candidate}" "$(candidate_tree_fingerprint "${candidate}")"
    done
  } | shasum -a 256 | awk '{ print substr($1, 1, 16) }'
}

plan_token="$(candidate_plan_token)"
reclaim_kib=0

echo "Conservative cleanup plan"
echo "Preserve:"
echo "  ${OHANA_TEST_DERIVED_DATA_PATH}"
echo "  ${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}"
echo "  ${OHANA_RELEASE_DERIVED_DATA_PATH}"
if [[ -n "${current_test_bridge}" ]]; then
  echo "  ${current_test_bridge} (newest current-test bridge until fixed tests products exist)"
fi
echo "  pinned Dogfood Simulator and all Simulator device data"
echo "  all ${OHANA_LOCAL_BUILD_TMP_ROOT}/OhanaArchives content"
echo "  ${OHANA_LOCAL_BUILD_TMP_ROOT}/ohana-* newer than ${OHANA_LOCAL_BUILD_TMP_TTL_HOURS} h, active, or uninspectable"
echo "Candidates:"
for candidate in "${candidates[@]}"; do
  candidate_kib="$(ohana_path_size_kib "${candidate}")"
  candidate_kind="$(cleanup_candidate_kind "${candidate}")"
  reclaim_kib=$((reclaim_kib + candidate_kib))
  printf '  %9s  %-24s  %s\n' \
    "$(ohana_format_kib_human "${candidate_kib}")" "${candidate_kind}" "${candidate}"
done
echo "Estimated reclaim: $(ohana_format_kib_human "${reclaim_kib}")"
echo "Plan token: ${plan_token}"

if [[ "${mode}" == "report" ]]; then
  echo "REPORT ONLY: nothing was deleted."
  echo "After reviewing every path, rerun: scripts/cleanup-local-build-storage.sh --apply ${plan_token}"
  exit 0
fi

if [[ "${provided_token}" != "${plan_token}" ]]; then
  echo "Refusing cleanup: plan token does not match the current candidate list." >&2
  echo "Rerun without --apply and review the new report." >&2
  exit 2
fi

if pgrep -x xcodebuild >/dev/null 2>&1; then
  echo "Refusing cleanup while xcodebuild is running." >&2
  exit 75
fi

for active_lock in "${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/locks/lane-tests.lock" \
  "${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/locks/lane-dogfood.lock" \
  "${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/locks/lane-release.lock"; do
  if [[ -d "${active_lock}" ]]; then
    echo "Refusing cleanup while a current build/test lock exists: ${active_lock}" >&2
    exit 75
  fi
done

for candidate in "${candidates[@]}"; do
  candidate_kind="$(cleanup_candidate_kind "${candidate}" || true)"
  if [[ -z "${candidate_kind}" ]]; then
    echo "Refusing cleanup because a candidate crossed a safety boundary: ${candidate}" >&2
    exit 75
  fi
  if [[ "${candidate_kind}" == "expired-ohana-tmp" && \
    "$(ohana_tmp_artifact_state "${candidate}")" != "candidate" ]]; then
    echo "Refusing cleanup because an Ohana tmp artifact became recent, active, or uninspectable: ${candidate}" >&2
    exit 75
  fi
  if ohana_path_has_open_files "${candidate}"; then
    echo "Refusing cleanup while files are open under: ${candidate}" >&2
    exit 75
  else
    lsof_status=$?
  fi
  if [[ "${lsof_status}" == "2" ]]; then
    echo "Refusing cleanup because open-file inspection is unavailable for: ${candidate}" >&2
    exit 75
  fi
done

fresh_plan_token="$(candidate_plan_token)"
if [[ "${fresh_plan_token}" != "${plan_token}" ]]; then
  echo "Refusing cleanup because a candidate changed during safety checks." >&2
  exit 75
fi

for candidate in "${candidates[@]}"; do
  candidate_fingerprint="$(candidate_tree_fingerprint "${candidate}")"
  quarantine_path="$(dirname "${candidate}")/.ohana-cleanup-${plan_token}-$(basename "${candidate}")"
  if [[ -e "${quarantine_path}" || -L "${quarantine_path}" ]]; then
    echo "Refusing cleanup because the quarantine path already exists: ${quarantine_path}" >&2
    exit 75
  fi
  if ! mv -- "${candidate}" "${quarantine_path}"; then
    echo "Refusing cleanup because candidate quarantine failed: ${candidate}" >&2
    exit 75
  fi
  if [[ "$(candidate_tree_fingerprint "${quarantine_path}")" != "${candidate_fingerprint}" ]]; then
    mv -- "${quarantine_path}" "${candidate}"
    echo "Refusing cleanup because a candidate changed during quarantine: ${candidate}" >&2
    exit 75
  fi
  if ohana_path_has_open_files "${quarantine_path}"; then
    mv -- "${quarantine_path}" "${candidate}"
    echo "Refusing cleanup because a quarantined candidate is active: ${candidate}" >&2
    exit 75
  else
    lsof_status=$?
  fi
  if [[ "${lsof_status}" == "2" ]]; then
    mv -- "${quarantine_path}" "${candidate}"
    echo "Refusing cleanup because quarantined activity could not be verified: ${candidate}" >&2
    exit 75
  fi
  if ! rm -rfx -- "${quarantine_path}"; then
    echo "Cleanup stopped with a quarantined candidate still present: ${quarantine_path}" >&2
    exit 75
  fi
done

echo "Cleanup complete. Reclaimed approximately $(ohana_format_kib_human "${reclaim_kib}")."
echo "Dogfood, Tests, Release, OhanaArchives, Simulator devices, and DeviceSupport were preserved."
