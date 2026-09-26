#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

cd "${REPO_ROOT}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/xcode-test.sh
  scripts/xcode-test.sh --only-testing <target[/suite[/test]]> [...]
  scripts/xcode-test.sh --unit
  scripts/xcode-test.sh --ui
  scripts/xcode-test.sh --full
  scripts/xcode-test.sh [--build-for-testing|--without-building] [--coverage]
                        [--keep-success-result] [--print] [-- xcodebuild args...]

The default is one small AppWorkloadPolicy unit-test suite. All local Xcode
tests use one cache outside the source tree and shared across Git worktrees,
the disposable iPhone 17 Tests Simulator, one project-wide lock, and bounded
xcresult retention. Coverage, parallel workers, repetitions, full suites, and
UI tests are opt-in.
USAGE
}

scope="${OHANA_TEST_SCOPE:-smoke}"
action="build-then-test"
coverage="NO"
keep_success=0
print_only=0
selectors=()
xcode_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --only-testing)
      [[ $# -ge 2 && -n "$2" ]] || {
        echo "--only-testing requires a selector." >&2
        exit 2
      }
      selectors+=("$2")
      scope="selected"
      shift 2
      ;;
    --unit)
      scope="unit"
      shift
      ;;
    --ui)
      scope="ui"
      shift
      ;;
    --full)
      scope="full"
      shift
      ;;
    --build-for-testing)
      action="build-for-testing"
      shift
      ;;
    --without-building)
      action="test-without-building"
      shift
      ;;
    --coverage)
      coverage="YES"
      shift
      ;;
    --keep-success-result)
      keep_success=1
      shift
      ;;
    --print)
      print_only=1
      shift
      ;;
    --)
      shift
      xcode_args+=("$@")
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ${#selectors[@]} -gt 0 && "${scope}" != "selected" ]]; then
  echo "Do not combine explicit selectors with --unit, --ui, or --full." >&2
  exit 2
fi

case "${scope}" in
  smoke)
    selectors=("OhanaTests/AppWorkloadPolicyTests")
    ;;
  selected)
    ;;
  unit)
    selectors=("OhanaTests")
    ;;
  ui)
    selectors=("OhanaUITests")
    ;;
  full)
    selectors=()
    ;;
  *)
    echo "Unsupported OHANA_TEST_SCOPE=${scope}." >&2
    exit 2
    ;;
esac

containers=()
while IFS= read -r path; do
  [[ -n "${path}" ]] && containers+=("${path#./}")
done < <(find . -maxdepth 1 \( -name '*.xcworkspace' -o -name '*.xcodeproj' \) -print | LC_ALL=C sort)
if [[ ${#containers[@]} -ne 1 || "${containers[0]}" != "Ohana.xcodeproj" ]]; then
  echo "Expected exactly the top-level Ohana.xcodeproj; found ${#containers[@]} container(s)." >&2
  printf '  %s\n' "${containers[@]}" >&2
  exit 2
fi

selector_args=()
for selector in ${selectors[@]+"${selectors[@]}"}; do
  selector_args+=("-only-testing:${selector}")
done

if [[ -n "${SCHEME:-}" ]]; then
  resolved_scheme="${SCHEME}"
else
  resolved_scheme="$(
    "${REPO_ROOT}/scripts/resolve-test-scheme.sh" \
      ${selector_args[@]+"${selector_args[@]}"}
  )"
fi
test_plan="$(
  sed -n 's/.*reference = "container:\([^"]*\.xctestplan\)".*/\1/p' \
    "Ohana.xcodeproj/xcshareddata/xcschemes/${resolved_scheme}.xcscheme" 2>/dev/null | head -n 1
)"
test_udid=""
if [[ -n "${DESTINATION:-}" ]]; then
  if [[ "${DESTINATION}" =~ (^|,)id=([^,]+) ]]; then
    test_udid="${BASH_REMATCH[2]}"
  else
    echo "DESTINATION must be an explicit iOS Simulator id." >&2
    exit 2
  fi
elif [[ -n "${OHANA_TEST_SIMULATOR_UDID:-}" ]]; then
  test_udid="${OHANA_TEST_SIMULATOR_UDID}"
else
  test_udid="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}" || true)"
fi
if [[ -z "${test_udid}" ]]; then
  echo "No available '${OHANA_TEST_SIMULATOR_NAME_FIXED}' Simulator." >&2
  exit 70
fi
ohana_assert_test_simulator_udid "${test_udid}"

echo "Xcode container: project ${containers[0]}"
echo "Scheme: ${resolved_scheme}"
echo "Test plan: ${test_plan:-none (scheme target list)}"
echo "Scope: ${scope}"
echo "Destination: platform=iOS Simulator,id=${test_udid} (${OHANA_TEST_SIMULATOR_NAME_FIXED})"
echo "Shared cache: ${OHANA_LOCAL_BUILD_CACHE_ROOT}"
echo "Result policy: successful bundles deleted; failures keep ${OHANA_TEST_FAILURE_RETENTION_COUNT} for ${OHANA_TEST_FAILURE_RETENTION_DAYS} days"

command=("${REPO_ROOT}/scripts/test-simulator.sh")
command+=(${selector_args[@]+"${selector_args[@]}"})
command+=(${xcode_args[@]+"${xcode_args[@]}"})

if [[ "${print_only}" == "1" ]]; then
  printf 'SCHEME=%q OHANA_TEST_ACTION=%q OHANA_TEST_CODE_COVERAGE=%q OHANA_KEEP_SUCCESS_XCRESULT=%q OHANA_TEST_SIMULATOR_UDID=%q' \
    "${resolved_scheme}" "${action}" "${coverage}" "${keep_success}" "${test_udid}"
  printf ' %q' "${command[@]}"
  printf '\n'
  exit 0
fi

export SCHEME="${resolved_scheme}"
export OHANA_TEST_ACTION="${action}"
export OHANA_TEST_CODE_COVERAGE="${coverage}"
export OHANA_KEEP_SUCCESS_XCRESULT="${keep_success}"
export OHANA_TEST_SIMULATOR_UDID="${test_udid}"

entry_available_kib="$(ohana_available_disk_kib)"
entry_derived_kib="$(ohana_path_size_kib "${OHANA_TEST_DERIVED_DATA_PATH}")"
entry_results_kib="$(ohana_path_size_kib "${OHANA_TEST_RESULT_ROOT}")"

set +e
"${command[@]}"
test_status=$?
set -e

apply_reviewed_cleanup_scope() {
  local cleanup_scope="$1"
  local cleanup_report
  local cleanup_status
  local cleanup_token

  cleanup_report="$(
    "${REPO_ROOT}/scripts/cleanup-local-build-storage.sh" \
      --scope "${cleanup_scope}" 2>&1
  )"
  cleanup_status=$?
  printf '%s\n' "${cleanup_report}"
  [[ "${cleanup_status}" == "0" ]] || return "${cleanup_status}"
  if [[ "${cleanup_report}" != *"No conservative cleanup candidates found."* ]]; then
    cleanup_token="$(
      awk '/^Plan token:/ { print $3 }' <<< "${cleanup_report}"
    )"
    if [[ -z "${cleanup_token}" ]]; then
      echo "${cleanup_scope} cleanup report omitted its plan token." >&2
      return 75
    fi
    "${REPO_ROOT}/scripts/cleanup-local-build-storage.sh" \
      --scope "${cleanup_scope}" \
      --apply "${cleanup_token}"
  fi
}

minimum_free_kib() {
  if [[ ! "${OHANA_MINIMUM_FREE_GIB}" =~ ^[1-9][0-9]*$ || \
    ${#OHANA_MINIMUM_FREE_GIB} -gt 3 ]]; then
    return 2
  fi
  printf '%s\n' "$((10#${OHANA_MINIMUM_FREE_GIB} * 1024 * 1024))"
}

free_space_is_below_gate() {
  local minimum_kib
  minimum_kib="$(minimum_free_kib)" || return 2
  (( $(ohana_available_disk_kib) < minimum_kib ))
}

cache_cleanup_status=0
if [[ "${action}" != "build-for-testing" ]]; then
  set +e
  apply_reviewed_cleanup_scope test-app-cache
  app_cache_cleanup_status=$?
  set -e
  if [[ "${cache_cleanup_status}" == "0" && "${app_cache_cleanup_status}" != "0" ]]; then
    cache_cleanup_status="${app_cache_cleanup_status}"
  fi

  if [[ "${cache_cleanup_status}" == "0" ]] && free_space_is_below_gate; then
    echo "Post-test free space is below ${OHANA_MINIMUM_FREE_GIB} GiB; applying reviewed Tests-only pressure relief."
    set +e
    apply_reviewed_cleanup_scope test-transient-cache
    cache_cleanup_status=$?
    set -e
  fi
fi

final_available_kib="$(ohana_available_disk_kib)"
final_derived_kib="$(ohana_path_size_kib "${OHANA_TEST_DERIVED_DATA_PATH}")"
final_results_kib="$(ohana_path_size_kib "${OHANA_TEST_RESULT_ROOT}")"
awk \
  -v before_free="${entry_available_kib}" \
  -v after_free="${final_available_kib}" \
  -v before_derived="${entry_derived_kib}" \
  -v after_derived="${final_derived_kib}" \
  -v before_results="${entry_results_kib}" \
  -v after_results="${final_results_kib}" \
  'BEGIN {
    printf "Unified lifecycle after: free %.1f GiB (%+.1f MiB), DerivedData %.1f MiB (%+.1f MiB), results %.1f MiB (%+.1f MiB)\n",
      after_free / 1024 / 1024, (after_free - before_free) / 1024,
      after_derived / 1024, (after_derived - before_derived) / 1024,
      after_results / 1024, (after_results - before_results) / 1024
  }'

if [[ "${test_status}" == "0" && "${cache_cleanup_status}" != "0" ]]; then
  exit "${cache_cleanup_status}"
fi
exit "${test_status}"
