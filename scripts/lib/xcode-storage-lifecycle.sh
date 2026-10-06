#!/usr/bin/env bash

# Shared, project-wide Xcode serialization and xcresult retention. This file is
# sourced after local-build-environment.sh and performs no work while loading.

OHANA_XCODE_PROJECT_LOCK_DIR="${OHANA_XCODE_LOCK_ROOT}/project.lock"
OHANA_XCODE_PROJECT_LOCK_ACQUIRED=0
OHANA_MANAGED_RESULT_BUNDLE_PATH=""

ohana_acquire_xcode_project_lock() {
  local purpose="${1:-xcode}"
  local owner_pid=""

  case "${OHANA_ALLOW_CONCURRENT_XCODE_TESTS:-0}" in
    0) ;;
    1)
      echo "WARNING: OHANA_ALLOW_CONCURRENT_XCODE_TESTS=1 bypasses the project-wide Xcode lock." >&2
      echo "Concurrent local Xcode work can corrupt shared products and multiply disk usage." >&2
      return 0
      ;;
    *)
      echo "OHANA_ALLOW_CONCURRENT_XCODE_TESTS must be 0 or 1." >&2
      return 2
      ;;
  esac

  ohana_assert_safe_shared_cache_root || return
  mkdir -p "${OHANA_XCODE_LOCK_ROOT}"
  if ! mkdir "${OHANA_XCODE_PROJECT_LOCK_DIR}" 2>/dev/null; then
    owner_pid="$(tr -d '[:space:]' < "${OHANA_XCODE_PROJECT_LOCK_DIR}/pid" 2>/dev/null || true)"
    if [[ "${owner_pid}" =~ ^[1-9][0-9]*$ ]] && kill -0 "${owner_pid}" 2>/dev/null; then
      echo "Another Ohana Xcode build/test is active (pid ${owner_pid})." >&2
      if [[ -f "${OHANA_XCODE_PROJECT_LOCK_DIR}/purpose" ]]; then
        echo "Purpose: $(< "${OHANA_XCODE_PROJECT_LOCK_DIR}/purpose")" >&2
      fi
      echo "Lock: ${OHANA_XCODE_PROJECT_LOCK_DIR}" >&2
      echo "Wait for it to finish; concurrent local Xcode work is rejected by default." >&2
      return 75
    fi

    echo "Removing stale project Xcode lock${owner_pid:+ from pid ${owner_pid}}."
    rm -rf -- "${OHANA_XCODE_PROJECT_LOCK_DIR}"
    if ! mkdir "${OHANA_XCODE_PROJECT_LOCK_DIR}" 2>/dev/null; then
      echo "Could not acquire project Xcode lock: ${OHANA_XCODE_PROJECT_LOCK_DIR}" >&2
      return 75
    fi
  fi

  printf '%s\n' "$$" > "${OHANA_XCODE_PROJECT_LOCK_DIR}/pid"
  printf '%s\n' "${purpose}" > "${OHANA_XCODE_PROJECT_LOCK_DIR}/purpose"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${OHANA_XCODE_PROJECT_LOCK_DIR}/started-at"
  printf '%s\n' "${OHANA_LOCAL_BUILD_REPO_ROOT}" > "${OHANA_XCODE_PROJECT_LOCK_DIR}/worktree"
  OHANA_XCODE_PROJECT_LOCK_ACQUIRED=1
}

ohana_release_xcode_project_lock() {
  local owner_pid=""

  [[ "${OHANA_XCODE_PROJECT_LOCK_ACQUIRED}" == "1" ]] || return 0
  owner_pid="$(tr -d '[:space:]' < "${OHANA_XCODE_PROJECT_LOCK_DIR}/pid" 2>/dev/null || true)"
  if [[ "${owner_pid}" == "$$" ]]; then
    rm -f -- \
      "${OHANA_XCODE_PROJECT_LOCK_DIR}/pid" \
      "${OHANA_XCODE_PROJECT_LOCK_DIR}/purpose" \
      "${OHANA_XCODE_PROJECT_LOCK_DIR}/started-at" \
      "${OHANA_XCODE_PROJECT_LOCK_DIR}/worktree"
    rmdir "${OHANA_XCODE_PROJECT_LOCK_DIR}" 2>/dev/null || true
  fi
  OHANA_XCODE_PROJECT_LOCK_ACQUIRED=0
}

ohana_prune_managed_test_results() {
  local failure_root="${OHANA_TEST_RESULT_ROOT}/failed"
  local staging_root="${OHANA_TEST_RESULT_ROOT}/staging"
  local path
  local retained=0

  if [[ ! "${OHANA_TEST_FAILURE_RETENTION_COUNT}" =~ ^[0-9]+$ || \
    ${#OHANA_TEST_FAILURE_RETENTION_COUNT} -gt 3 || \
    ! "${OHANA_TEST_FAILURE_RETENTION_DAYS}" =~ ^[0-9]+$ || \
    ${#OHANA_TEST_FAILURE_RETENTION_DAYS} -gt 4 ]]; then
    echo "Invalid managed xcresult retention configuration." >&2
    return 2
  fi
  ohana_assert_safe_shared_cache_root || return
  mkdir -p "${failure_root}" "${staging_root}"

  find "${failure_root}" -mindepth 1 -maxdepth 1 -type d -name '*.xcresult' \
    -mtime "+${OHANA_TEST_FAILURE_RETENTION_DAYS}" -exec rm -rf -- {} + 2>/dev/null || true
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    retained=$((retained + 1))
    if ((retained > OHANA_TEST_FAILURE_RETENTION_COUNT)); then
      rm -rf -- "${path}"
    fi
  done < <(
    find "${failure_root}" -mindepth 1 -maxdepth 1 -type d -name '*.xcresult' \
      -exec stat -f '%m	%N' {} + 2>/dev/null | sort -nr | cut -f 2-
  )

  find "${staging_root}" -mindepth 1 -maxdepth 1 -type d -name '*.xcresult' \
    -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true
  find "${OHANA_TEST_DERIVED_DATA_PATH}/Logs/Test" -type d -name '*.xcresult' \
    -mtime +1 -prune -exec rm -rf -- {} + 2>/dev/null || true
}

ohana_prepare_managed_result_bundle() {
  local label="${1:-test}"
  local safe_label

  case "${OHANA_KEEP_SUCCESS_XCRESULT:-0}" in
    0|1) ;;
    *)
      echo "OHANA_KEEP_SUCCESS_XCRESULT must be 0 or 1." >&2
      return 2
      ;;
  esac
  if [[ -n "${OHANA_RESULT_BUNDLE_PATH:-}" ]]; then
    echo "OHANA_RESULT_BUNDLE_PATH is no longer accepted for local tests." >&2
    echo "Result paths are managed under ${OHANA_TEST_RESULT_ROOT}." >&2
    return 2
  fi

  ohana_prune_managed_test_results || return
  safe_label="$(printf '%s' "${label}" | tr -cs '[:alnum:]._' '-' | sed 's/^-*//; s/-*$//')"
  [[ -n "${safe_label}" ]] || safe_label="test"
  OHANA_MANAGED_RESULT_BUNDLE_PATH="${OHANA_TEST_RESULT_ROOT}/staging/${safe_label}-$(date -u +%Y%m%dT%H%M%SZ)-$$.xcresult"
  if [[ -e "${OHANA_MANAGED_RESULT_BUNDLE_PATH}" ]]; then
    echo "Refusing existing managed result path: ${OHANA_MANAGED_RESULT_BUNDLE_PATH}" >&2
    return 2
  fi
  printf '%s\n' "${OHANA_MANAGED_RESULT_BUNDLE_PATH}"
}

ohana_finalize_managed_result_bundle() {
  local status="$1"
  local result_path="$2"
  local final_path
  local label

  [[ -n "${result_path}" ]] || return 0
  [[ -e "${result_path}" ]] || {
    ohana_prune_managed_test_results
    return
  }
  if ! ohana_path_is_equal_or_beneath "${result_path}" "${OHANA_TEST_RESULT_ROOT}/staging"; then
    echo "Refusing unmanaged xcresult finalization: ${result_path}" >&2
    return 2
  fi

  if [[ "${status}" == "0" ]]; then
    if [[ "${OHANA_KEEP_SUCCESS_XCRESULT:-0}" == "1" ]]; then
      final_path="${OHANA_TEST_RESULT_ROOT}/success/latest.xcresult"
      mkdir -p "$(dirname "${final_path}")"
      rm -rf -- "${final_path}"
      mv -- "${result_path}" "${final_path}"
      echo "Kept successful xcresult: ${final_path}"
    else
      rm -rf -- "${result_path}"
      echo "Deleted successful xcresult (default retention policy)."
    fi
  else
    label="$(basename "${result_path}")"
    final_path="${OHANA_TEST_RESULT_ROOT}/failed/failure-${label}"
    mkdir -p "$(dirname "${final_path}")"
    mv -- "${result_path}" "${final_path}"
    echo "Preserved failed xcresult: ${final_path}" >&2
  fi
  ohana_prune_managed_test_results
}
