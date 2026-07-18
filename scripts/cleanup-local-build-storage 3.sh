#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/cleanup-local-build-storage.sh
  scripts/cleanup-local-build-storage.sh --apply <plan-token>

The default is report-only. It preserves the fixed tests, dogfood, and release
DerivedData lanes plus the newest local Release Archive. --apply succeeds only
when its token exactly matches the current candidate list.

Simulator devices/caches, Xcode DeviceSupport, and arbitrary /private/tmp
artifacts are never deleted by this script.
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
    for path in "${OHANA_LOCAL_DERIVED_DATA_ROOT}"/* /private/tmp/OhanaDerivedData*; do
      [[ -e "${path}" ]] || continue
      if [[ "${path}" == "${OHANA_TEST_DERIVED_DATA_PATH}" || \
        "${path}" == "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" || \
        "${path}" == "${OHANA_RELEASE_DERIVED_DATA_PATH}" ]]; then
        continue
      fi
      modified="$(stat -f '%m' "${path}" 2>/dev/null || true)"
      [[ -n "${modified}" ]] && printf '%s\t%s\n' "${modified}" "${path}"
    done
  } | sort -nr | head -n 1 | cut -f 2- || true)"
fi

candidate_stream() {
  local path
  local newest_archive=""

  if [[ -d "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products" ]]; then
    for path in "${OHANA_TEST_DERIVED_DATA_PATH}"/*; do
      [[ -d "${path}/Build" ]] || continue
      printf '%s\n' "${path}"
    done
  fi

  for path in "${OHANA_LOCAL_DERIVED_DATA_ROOT}"/*; do
    [[ -e "${path}" ]] || continue
    case "$(basename "${path}")" in
      tests|dogfood|release)
        continue
        ;;
    esac
    [[ "${path}" != "${current_test_bridge}" ]] || continue
    printf '%s\n' "${path}"
  done

  for path in /private/tmp/OhanaDerivedData*; do
    [[ -e "${path}" ]] || continue
    [[ "${path}" != "${current_test_bridge}" ]] || continue
    printf '%s\n' "${path}"
  done

  if [[ -d /private/tmp/OhanaArchives ]]; then
    newest_archive="$({
      while IFS= read -r path; do
        modified="$(stat -f '%m' "${path}" 2>/dev/null || true)"
        [[ -n "${modified}" ]] && printf '%s\t%s\n' "${modified}" "${path}"
      done < <(find /private/tmp/OhanaArchives -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null)
    } | sort -nr | head -n 1 | cut -f 2- || true)"
    while IFS= read -r path; do
      [[ -n "${path}" && "${path}" != "${newest_archive}" ]] || continue
      printf '%s\n' "${path}"
    done < <(find /private/tmp/OhanaArchives -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | LC_ALL=C sort)
  fi
}

candidates=()
while IFS= read -r candidate; do
  [[ -n "${candidate}" ]] || continue
  candidates+=("${candidate}")
done < <(candidate_stream | LC_ALL=C sort -u)

if [[ ${#candidates[@]} -eq 0 ]]; then
  echo "No conservative cleanup candidates found."
  exit 0
fi

plan_token="$(printf '%s\n' "${candidates[@]}" | shasum -a 256 | awk '{ print substr($1, 1, 16) }')"
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
echo "  newest /private/tmp/OhanaArchives child"
echo "Candidates:"
for candidate in "${candidates[@]}"; do
  candidate_kib="$(ohana_path_size_kib "${candidate}")"
  reclaim_kib=$((reclaim_kib + candidate_kib))
  printf '  %9s  %s\n' "$(ohana_format_kib_human "${candidate_kib}")" "${candidate}"
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

for active_lock in "${REPO_ROOT}/.build/locks/lane-tests.lock" \
  "${REPO_ROOT}/.build/locks/lane-dogfood.lock" \
  "${REPO_ROOT}/.build/locks/lane-release.lock"; do
  if [[ -d "${active_lock}" ]]; then
    echo "Refusing cleanup while a current build/test lock exists: ${active_lock}" >&2
    exit 75
  fi
done

for candidate in "${candidates[@]}"; do
  rm -rf -- "${candidate}"
done

echo "Cleanup complete. Reclaimed approximately $(ohana_format_kib_human "${reclaim_kib}")."
echo "Dogfood, Tests, Release, Simulator devices, and DeviceSupport were preserved."
