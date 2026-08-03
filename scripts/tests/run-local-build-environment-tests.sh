#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ohana-local-build-policy.XXXXXX")"
outside_fixture_root="${fixture_root}.outside"
fake_repo="${fixture_root}/repo"
fake_home="${fixture_root}/home"
fake_bin="${fixture_root}/bin"
fake_tmp="${fixture_root}/private-tmp"
failures=0

cleanup() {
  rm -rf "${fixture_root}" "${outside_fixture_root}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

mkdir -p "${fake_repo}/.build" "${fake_home}" "${fake_bin}" "${fake_tmp}"
fake_repo="$(cd "${fake_repo}" && pwd)"
fake_home="$(cd "${fake_home}" && pwd)"
fake_bin="$(cd "${fake_bin}" && pwd)"
fake_tmp="$(cd "${fake_tmp}" && pwd)"
printf '%s\n' 'DOGFOOD-UDID' > "${fake_repo}/.build/dogfood-simulator.udid"

cat > "${fake_bin}/xcrun" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == "simctl list devices available -j" ]]; then
  test_state="${FAKE_TEST_SIMULATOR_STATE:-Shutdown}"
  cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"name":"iPhone 17 Dogfood","udid":"DOGFOOD-UDID","state":"Shutdown","isAvailable":true},
  {"name":"iPhone 17 Tests","udid":"TEST-UDID","state":"${test_state}","isAvailable":true},
  {"name":"iPhone 16","udid":"OTHER-UDID","state":"Shutdown","isAvailable":true}
]}}
JSON
  exit 0
fi
if [[ "$*" == "simctl terminate TEST-UDID dev.swiftui-preview-browser.host" ]]; then
  printf '%s\n' "$*" >> "${FAKE_SIMCTL_LOG:?}"
  if [[ "${FAKE_TERMINATE_ERROR:-0}" == "1" ]]; then
    echo "fixture terminate error" >&2
    exit 71
  fi
  if [[ "${FAKE_TERMINATE_NOT_FOUND:-0}" == "1" ]]; then
    echo "found nothing to terminate" >&2
    exit 3
  fi
  exit 0
fi
exit 64
SH

cat > "${fake_bin}/df" <<'SH'
#!/usr/bin/env bash
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf '/dev/fake 100000000 1 %s 1%% /\n' "${FAKE_AVAILABLE_KIB:-22020096}"
SH

cat > "${fake_bin}/lsof" <<'SH'
#!/usr/bin/env bash
if [[ -n "${FAKE_LSOF_ERROR_PATH:-}" && "$*" == *"${FAKE_LSOF_ERROR_PATH}"* ]]; then
  echo "lsof: fixture inspection error" >&2
  exit 3
fi
if [[ -n "${FAKE_LSOF_ACTIVE_PATH:-}" && "$*" == *"${FAKE_LSOF_ACTIVE_PATH}"* ]]; then
  printf '12345\n'
  exit 0
fi
exit 1
SH

cat > "${fake_bin}/pgrep" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "${fake_bin}/xcrun" "${fake_bin}/df" "${fake_bin}/lsof" "${fake_bin}/pgrep"

export OHANA_LOCAL_BUILD_REPO_ROOT="${fake_repo}"
export OHANA_LOCAL_BUILD_TMP_ROOT="${fake_tmp}"
export OHANA_LOCAL_BUILD_TMP_TTL_HOURS=48
export OHANA_LOCAL_BUILD_STORAGE_FIXTURE_MODE=1
export OHANA_LOCAL_BUILD_STORAGE_FIXTURE_ROOT="${fixture_root}"
export OHANA_XCODE_DERIVED_DATA_ROOT="${fake_home}/Library/Developer/Xcode/DerivedData"
export HOME="${fake_home}"
export TMPDIR="${fake_tmp}"
export PATH="${fake_bin}:${PATH}"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${repo_root}/scripts/lib/local-build-environment.sh"
# shellcheck source=scripts/lib/xcode-storage-lifecycle.sh
source "${repo_root}/scripts/lib/xcode-storage-lifecycle.sh"

expected_cache_root="${fake_home}/Library/Developer/Xcode/OhanaLocalBuild/Ohana-${OHANA_LOCAL_BUILD_CACHE_ID}"
[[ "${OHANA_LOCAL_BUILD_CACHE_ROOT}" == "${expected_cache_root}" ]] || \
  fail "shared external cache root drifted"
[[ "${OHANA_TEST_DERIVED_DATA_PATH}" == "${expected_cache_root}/DerivedData/tests" ]] || \
  fail "tests DerivedData lane drifted"
[[ "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" == "${expected_cache_root}/DerivedData/dogfood" ]] || \
  fail "dogfood DerivedData lane drifted"
[[ "${OHANA_DOGFOOD_STORE_IDENTITY_FILE}" == "${fake_repo}/.build/dogfood-store.identity" ]] || \
  fail "dogfood store identity pin escaped the ignored local build root"
[[ "${OHANA_DOGFOOD_INITIALIZATION_STATE_FILE}" == "${fake_repo}/.build/dogfood-initialization.pending" ]] || \
  fail "dogfood initialization transaction escaped the ignored local build root"
[[ "${OHANA_DOGFOOD_SIMULATOR_NAME_FIXED}" == "iPhone 17 Dogfood" ]] || \
  fail "fixed Dogfood Simulator name drifted"
[[ "${OHANA_RELEASE_DERIVED_DATA_PATH}" == "${expected_cache_root}/DerivedData/release" ]] || \
  fail "release DerivedData lane drifted"
[[ "${OHANA_TEST_RESULT_ROOT}" == "${expected_cache_root}/TestResults" ]] || \
  fail "managed result root drifted"
[[ "${OHANA_XCODE_LOCK_ROOT}" == "${expected_cache_root}/Locks" ]] || \
  fail "shared project lock root drifted"
[[ "$(ohana_tmp_artifact_ttl_seconds)" == "$((48 * 60 * 60))" ]] || \
  fail "fixture tmp TTL override was ignored"
OHANA_LOCAL_BUILD_TMP_TTL_HOURS=23
if ohana_tmp_artifact_ttl_seconds >/dev/null 2>&1; then
  fail "tmp TTL shorter than 24 hours was accepted"
fi
OHANA_LOCAL_BUILD_TMP_TTL_HOURS=3000000000000000
if ohana_tmp_artifact_ttl_seconds >/dev/null 2>&1; then
  fail "overflowing tmp TTL was accepted"
fi
OHANA_LOCAL_BUILD_TMP_TTL_HOURS=48
OHANA_LOCAL_BUILD_STORAGE_FIXTURE_MODE=0
if ohana_assert_storage_fixture_configuration >/dev/null 2>&1; then
  fail "production mode accepted a fixture tmp root"
fi
OHANA_LOCAL_BUILD_TMP_ROOT=/private/tmp
if ohana_assert_storage_fixture_configuration "${repo_root}" >/dev/null 2>&1; then
  fail "production mode accepted an overridden repo root"
fi
OHANA_LOCAL_BUILD_TMP_ROOT="${fake_tmp}"
OHANA_LOCAL_BUILD_STORAGE_FIXTURE_MODE=1

mkdir -p "${outside_fixture_root}/ohana-old"
printf 'outside fixture\n' > "${outside_fixture_root}/ohana-old/payload.txt"
find "${outside_fixture_root}/ohana-old" -exec touch -t 202001010000 {} +
ln -s "${outside_fixture_root}" "${fixture_root}/linked-tmp"
set +e
symlink_root_output="$(OHANA_LOCAL_BUILD_TMP_ROOT="${fixture_root}/linked-tmp" \
  "${repo_root}/scripts/cleanup-local-build-storage.sh" 2>&1)"
symlink_root_status=$?
set -e
[[ "${symlink_root_status}" == "2" ]] || fail "symlinked fixture tmp root must exit 2"
[[ -d "${outside_fixture_root}/ohana-old" ]] || fail "symlinked fixture tmp root deleted outside content"

if ! ohana_assert_fixed_derived_data_path tests "${OHANA_TEST_DERIVED_DATA_PATH}"; then
  fail "fixed tests DerivedData path was rejected"
fi
if ohana_assert_fixed_derived_data_path tests "${fake_repo}/.build/DerivedData/tfu-123" >/dev/null 2>&1; then
  fail "one-off TFU DerivedData path was accepted"
fi

mkdir -p "${OHANA_XCODE_PROJECT_LOCK_DIR}"
printf '%s\n' "$$" > "${OHANA_XCODE_PROJECT_LOCK_DIR}/pid"
printf 'fixture-active\n' > "${OHANA_XCODE_PROJECT_LOCK_DIR}/purpose"
if ohana_acquire_xcode_project_lock fixture >/dev/null 2>&1; then
  fail "active project-wide Xcode lock was bypassed"
fi
rm -rf "${OHANA_XCODE_PROJECT_LOCK_DIR}"
mkdir -p "${OHANA_XCODE_PROJECT_LOCK_DIR}"
printf '99999999\n' > "${OHANA_XCODE_PROJECT_LOCK_DIR}/pid"
if ! ohana_acquire_xcode_project_lock fixture-stale; then
  fail "stale project-wide Xcode lock was not recovered"
fi
[[ "$(tr -d '[:space:]' < "${OHANA_XCODE_PROJECT_LOCK_DIR}/pid")" == "$$" ]] || \
  fail "recovered project-wide lock did not record its owner"
ohana_release_xcode_project_lock
if find "${OHANA_XCODE_LOCK_ROOT}" -mindepth 1 -maxdepth 1 -name '*.stale.*' -print -quit | grep -q .; then
  fail "stale lock recovery accumulated quarantine directories"
fi

OHANA_KEEP_SUCCESS_XCRESULT=0
for fixture_index in 1 2 3 4; do
  fixture_result="${OHANA_TEST_RESULT_ROOT}/staging/failure-${fixture_index}.xcresult"
  mkdir -p "${fixture_result}"
  printf 'failure\n' > "${fixture_result}/payload.txt"
  ohana_finalize_managed_result_bundle 1 "${fixture_result}"
done
retained_failure_count="$({
  find "${OHANA_TEST_RESULT_ROOT}/failed" -mindepth 1 -maxdepth 1 -type d -name '*.xcresult' -print
} | wc -l | tr -d ' ')"
[[ "${retained_failure_count}" == "3" ]] || fail "managed failure count cap did not retain exactly three"
old_failure="$(find "${OHANA_TEST_RESULT_ROOT}/failed" -mindepth 1 -maxdepth 1 -type d -name '*.xcresult' -print | head -n 1)"
find "${old_failure}" -exec touch -t 202001010000 {} +
ohana_prune_managed_test_results
[[ ! -e "${old_failure}" ]] || fail "managed failure older than seven days was retained"

success_result="${OHANA_TEST_RESULT_ROOT}/staging/success-delete.xcresult"
mkdir -p "${success_result}"
ohana_finalize_managed_result_bundle 0 "${success_result}"
[[ ! -e "${success_result}" ]] || fail "successful xcresult was not deleted by default"
OHANA_KEEP_SUCCESS_XCRESULT=1
success_result="${OHANA_TEST_RESULT_ROOT}/staging/success-keep.xcresult"
mkdir -p "${success_result}"
ohana_finalize_managed_result_bundle 0 "${success_result}"
[[ -d "${OHANA_TEST_RESULT_ROOT}/success/latest.xcresult" ]] || \
  fail "explicit successful xcresult was not retained as latest"
OHANA_KEEP_SUCCESS_XCRESULT=0

set +e
dogfood_output="$(ohana_assert_test_simulator_udid DOGFOOD-UDID 2>&1)"
dogfood_status=$?
set -e
[[ "${dogfood_status}" == "2" ]] || fail "Dogfood test target must exit 2"
grep -qF "automated tests may not run on the pinned Dogfood Simulator" <<< "${dogfood_output}" || \
  fail "Dogfood rejection message is missing"

if ! ohana_assert_test_simulator_udid TEST-UDID; then
  fail "dedicated Test Simulator was rejected"
fi
if ohana_assert_test_simulator_udid OTHER-UDID >/dev/null 2>&1; then
  fail "non-test Simulator was accepted"
fi

if ! ohana_assert_dogfood_simulator_udid DOGFOOD-UDID; then
  fail "fixed Dogfood Simulator was rejected"
fi
if ohana_assert_safe_dogfood_launch_context -OHANA_UI_TESTS >/dev/null 2>&1; then
  fail "Dogfood accepted the UI-test launch marker"
fi
if ohana_assert_safe_dogfood_launch_context -OHANA_RESET_PERSISTENT_STATE >/dev/null 2>&1; then
  fail "Dogfood accepted the persistent reset launch marker"
fi
if ! ohana_assert_safe_dogfood_launch_context -AppleLanguages '(zh-Hans)'; then
  fail "Dogfood rejected ordinary Apple launch arguments"
fi

resolved_test_udid="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}")"
[[ "${resolved_test_udid}" == "TEST-UDID" ]] || fail "test device name resolved to ${resolved_test_udid}"

simctl_log="${fixture_root}/simctl.log"
: > "${simctl_log}"
if ! FAKE_TEST_SIMULATOR_STATE=Booted FAKE_SIMCTL_LOG="${simctl_log}" \
  ohana_quiesce_test_simulator_companion_apps TEST-UDID; then
  fail "booted Tests Simulator companion preflight failed"
fi
grep -qF "simctl terminate TEST-UDID dev.swiftui-preview-browser.host" "${simctl_log}" || \
  fail "booted Tests Simulator did not terminate the preview companion"

: > "${simctl_log}"
if ! FAKE_TEST_SIMULATOR_STATE=Shutdown FAKE_SIMCTL_LOG="${simctl_log}" \
  ohana_quiesce_test_simulator_companion_apps TEST-UDID; then
  fail "shutdown Tests Simulator companion preflight failed"
fi
[[ ! -s "${simctl_log}" ]] || fail "shutdown Tests Simulator attempted companion termination"

if ! FAKE_TEST_SIMULATOR_STATE=Booted FAKE_SIMCTL_LOG="${simctl_log}" \
  FAKE_TERMINATE_NOT_FOUND=1 ohana_quiesce_test_simulator_companion_apps TEST-UDID; then
  fail "already-stopped preview companion was treated as a failure"
fi

: > "${simctl_log}"
if FAKE_TEST_SIMULATOR_STATE=Booted FAKE_SIMCTL_LOG="${simctl_log}" \
  ohana_quiesce_test_simulator_companion_apps DOGFOOD-UDID >/dev/null 2>&1; then
  fail "Dogfood was accepted by the test-only companion preflight"
fi
[[ ! -s "${simctl_log}" ]] || fail "test-only companion preflight touched Dogfood"

recent_tmp="${fake_tmp}/ohana-recent"
mkdir -p "${recent_tmp}"
printf 'recent\n' > "${recent_tmp}/payload.txt"
mkdir -p "${fake_repo}/.git/objects/aa" "${fake_repo}/.git/objects/pack" \
  "${OHANA_XCODE_DERIVED_DATA_ROOT}/Ohana-old-checkout"
printf 'object-copy\n' > "${fake_repo}/.git/objects/aa/0123456789 2"
printf 'pack-copy\n' > "${fake_repo}/.git/objects/pack/pack-fixture 2.pack"
printf 'index-copy\n' > "${fake_repo}/.git/index 2"
printf 'normal\n' > "${fake_repo}/.git/objects/aa/0123456789"
printf 'xcode-cache\n' > "${OHANA_XCODE_DERIVED_DATA_ROOT}/Ohana-old-checkout/cache.bin"
conflict_summary="$(ohana_git_numbered_conflict_copy_summary)"
[[ "${conflict_summary%%$'\t'*}" == "3" ]] || fail "numbered .git conflict-copy detector count drifted"

set +e
low_disk_output="$(FAKE_AVAILABLE_KIB=$((19 * 1024 * 1024)) ohana_require_build_disk_space 2>&1)"
low_disk_status=$?
set -e
[[ "${low_disk_status}" == "74" ]] || fail "19 GiB disk preflight must exit 74"
grep -qF "20 GiB is required" <<< "${low_disk_output}" || fail "low-disk threshold message is missing"
grep -qF "Largest tracked local storage sources" <<< "${low_disk_output}" || \
  fail "low-disk gate did not report tracked growth sources"
grep -qF "${recent_tmp}" <<< "${low_disk_output}" || \
  fail "low-disk gate did not name the growing Ohana tmp artifact"
grep -qF ".git numbered conflict copies" <<< "${low_disk_output}" || \
  fail "low-disk gate did not name numbered .git conflict copies"
grep -qF "${OHANA_XCODE_DERIVED_DATA_ROOT}" <<< "${low_disk_output}" || \
  fail "low-disk gate did not name Xcode default DerivedData"

if ! FAKE_AVAILABLE_KIB=$((21 * 1024 * 1024)) ohana_require_build_disk_space; then
  fail "21 GiB disk preflight should pass"
fi

grep -qF 'OHANA_TEST_SIMULATOR_NAME_FIXED="iPhone 17 Tests"' \
  "${repo_root}/scripts/lib/local-build-environment.sh" || fail "fixed test device name guard is missing"
grep -qF 'OHANA_DOGFOOD_SIMULATOR_NAME_FIXED="iPhone 17 Dogfood"' \
  "${repo_root}/scripts/lib/local-build-environment.sh" || fail "fixed Dogfood device name guard is missing"
grep -qF 'CONFIGURATION="${CONFIGURATION:-Release}"' \
  "${repo_root}/scripts/run-dogfood-simulator.sh" || fail "Dogfood no longer defaults to Release"
grep -qF 'ohana_assert_safe_dogfood_launch_context "$@"' \
  "${repo_root}/scripts/run-dogfood-simulator.sh" || fail "Dogfood launch argument guard is missing"
grep -qF 'rm -rfx -- "${quarantine_path}"' \
  "${repo_root}/scripts/cleanup-local-build-storage.sh" || fail "cleanup no longer refuses cross-filesystem traversal"
grep -qF 'ohana_assert_test_simulator_udid' "${repo_root}/scripts/test-simulator.sh" || \
  fail "test entrypoint no longer calls the Dogfood guard"
grep -qF 'run_xcodebuild_action build-for-testing' "${repo_root}/scripts/test-simulator.sh" || \
  fail "test entrypoint no longer builds test products first"
grep -qF 'run_xcodebuild_action test-without-building' "${repo_root}/scripts/test-simulator.sh" || \
  fail "test entrypoint no longer reuses built products"
grep -qF 'scripts/test-ui-shard.sh "${shard}"' "${repo_root}/scripts/test-ui-nightly.sh" || \
  fail "UI nightly lane no longer gives every shard a complete build-then-test lifecycle"
grep -qF 'scripts/test-ui-shard.sh --print "${shard}"' \
  "${repo_root}/scripts/test-ui-nightly.sh" || \
  fail "UI nightly print mode no longer mirrors the normal shard lifecycle"
if rg -q -- '--build-for-testing|--without-building' \
  "${repo_root}/scripts/test-ui-nightly.sh"; then
  fail "UI nightly lane reintroduced a split build/test Simulator lifecycle"
fi
grep -qF 'OHANA_XCODE_PROJECT_LOCK_DIR="${OHANA_XCODE_LOCK_ROOT}/project.lock"' \
  "${repo_root}/scripts/lib/xcode-storage-lifecycle.sh" || \
  fail "project-wide Xcode lock is missing"
grep -qF 'OHANA_TEST_FAILURE_RETENTION_COUNT="${OHANA_TEST_FAILURE_RETENTION_COUNT:-3}"' \
  "${repo_root}/scripts/lib/local-build-environment.sh" || \
  fail "failure result count cap drifted"
grep -qF 'OHANA_TEST_FAILURE_RETENTION_DAYS="${OHANA_TEST_FAILURE_RETENTION_DAYS:-7}"' \
  "${repo_root}/scripts/lib/local-build-environment.sh" || \
  fail "failure result expiry drifted"
grep -qF 'TEST_CODE_COVERAGE="${OHANA_TEST_CODE_COVERAGE:-NO}"' \
  "${repo_root}/scripts/test-simulator.sh" || fail "coverage no longer defaults off"
grep -qF 'TEST_PARALLEL_ENABLED="${OHANA_TEST_PARALLEL_ENABLED:-NO}"' \
  "${repo_root}/scripts/test-simulator.sh" || fail "parallel testing no longer defaults off"

if ! "${repo_root}/scripts/tests/run-ui-nightly-receipt-tests.sh"; then
  fail "UI Nightly receipt fixtures failed"
fi

if rg -n '/tmp/OhanaDerivedData|DerivedData/(ui-tests|task-|tfu-)' \
  "${repo_root}/scripts/test-simulator.sh" \
  "${repo_root}/scripts/build-debug-fast.sh" \
  "${repo_root}/scripts/build-release-fast.sh" \
  "${repo_root}/scripts/run-dogfood-simulator.sh" \
  "${repo_root}/scripts/archive-release-local.sh" >/dev/null; then
  fail "active build entrypoints still contain a one-off DerivedData lane"
fi
if rg -n 'DerivedData/ui-tests' \
  "${repo_root}/scripts/test-ui-shard.sh" \
  "${repo_root}/scripts/test-ui-nightly.sh" >/dev/null; then
  fail "UI test wrappers still use a separate DerivedData cache"
fi

expired_tmp="${fake_tmp}/ohana-expired"
active_tmp="${fake_tmp}/ohana-active"
error_tmp="${fake_tmp}/ohana-uninspectable"
archive_child="${fake_tmp}/OhanaArchives/Release-old.xcarchive"
outside_tmp="${fixture_root}/outside/ohana-outside"
symlink_tmp="${fake_tmp}/ohana-escape"
mkdir -p "${expired_tmp}" "${active_tmp}" "${error_tmp}" "${archive_child}" "${outside_tmp}"
printf 'expired\n' > "${expired_tmp}/payload.txt"
printf 'active\n' > "${active_tmp}/payload.txt"
printf 'uninspectable\n' > "${error_tmp}/payload.txt"
printf 'archive\n' > "${archive_child}/payload.txt"
printf 'outside\n' > "${outside_tmp}/payload.txt"
find "${expired_tmp}" "${active_tmp}" "${error_tmp}" "${archive_child}" "${outside_tmp}" \
  -exec touch -t 202001010000 {} +
ln -s "${outside_tmp}" "${symlink_tmp}"
export FAKE_LSOF_ACTIVE_PATH="${active_tmp}"
export FAKE_LSOF_ERROR_PATH="${error_tmp}"

mkdir -p "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products" \
  "${OHANA_TEST_DERIVED_DATA_PATH}/Logs/Build" \
  "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" \
  "${OHANA_RELEASE_DERIVED_DATA_PATH}" \
  "${fake_repo}/.build/DerivedData/Tests/Build/Products" \
  "${fake_repo}/.build/DerivedData/Dogfood" \
  "${fake_repo}/.build/DerivedData/Release"
printf 'fixed\n' > "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/proof.txt"
printf 'legacy\n' > "${fake_repo}/.build/DerivedData/Tests/Build/Products/proof.txt"

if ohana_assert_safe_tmp_artifact_path "${outside_tmp}" >/dev/null 2>&1; then
  fail "out-of-bound Ohana tmp artifact was accepted"
fi
if ohana_assert_safe_tmp_artifact_path "${symlink_tmp}" >/dev/null 2>&1; then
  fail "symlinked Ohana tmp artifact was accepted"
fi

set +e
storage_report_output="$("${repo_root}/scripts/report-local-build-storage.sh" 2>&1)"
storage_report_status=$?
set -e
[[ "${storage_report_status}" == "0" ]] || fail "storage report exited ${storage_report_status}"
grep -qF "${expired_tmp}" <<< "${storage_report_output}" || \
  fail "storage report omitted expired Ohana tmp artifact"
grep -F "${expired_tmp}" <<< "${storage_report_output}" | grep -qF "EXPIRED CANDIDATE" || \
  fail "storage report did not classify expired Ohana tmp artifact"
grep -F "${recent_tmp}" <<< "${storage_report_output}" | grep -qF "preserve: recent" || \
  fail "storage report did not preserve recent Ohana tmp artifact"
grep -F "${active_tmp}" <<< "${storage_report_output}" | grep -qF "preserve: open files" || \
  fail "storage report did not preserve active Ohana tmp artifact"
grep -F "${error_tmp}" <<< "${storage_report_output}" | grep -qF "could not be verified" || \
  fail "storage report treated lsof error as a safe candidate"
grep -F "${symlink_tmp}" <<< "${storage_report_output}" | grep -qF "preserve: unsafe" || \
  fail "storage report did not preserve unsafe Ohana tmp symlink"
grep -F "${fake_tmp}/OhanaArchives" <<< "${storage_report_output}" | grep -qF "cleanup never deletes this tree" || \
  fail "storage report did not mark OhanaArchives as protected"
grep -qF "3 numbered conflict copy/copies" <<< "${storage_report_output}" || \
  fail "storage report omitted numbered .git conflict-copy count"
grep -qF "older repo checkouts" <<< "${storage_report_output}" || \
  fail "storage report omitted old-repo Xcode DerivedData guidance"

set +e
cleanup_report_output="$("${repo_root}/scripts/cleanup-local-build-storage.sh" 2>&1)"
cleanup_report_status=$?
set -e
[[ "${cleanup_report_status}" == "0" ]] || fail "cleanup report-only mode exited ${cleanup_report_status}"
grep -qF "REPORT ONLY: nothing was deleted" <<< "${cleanup_report_output}" || \
  fail "cleanup default was not report-only"
[[ -d "${expired_tmp}" ]] || fail "cleanup report-only mode deleted an expired artifact"
[[ -d "${recent_tmp}" ]] || fail "cleanup report-only mode deleted a recent artifact"
candidate_block="$(awk '/^Candidates:$/ { inside = 1; next } /^Estimated reclaim:/ { inside = 0 } inside' <<< "${cleanup_report_output}")"
grep -qF "${expired_tmp}" <<< "${candidate_block}" || \
  fail "cleanup plan omitted expired safe Ohana tmp artifact"
if grep -qF "${recent_tmp}" <<< "${candidate_block}"; then
  fail "cleanup plan included recent Ohana tmp artifact"
fi
if grep -qF "${active_tmp}" <<< "${candidate_block}"; then
  fail "cleanup plan included active Ohana tmp artifact"
fi
if grep -qF "${error_tmp}" <<< "${candidate_block}"; then
  fail "cleanup plan included uninspectable Ohana tmp artifact"
fi
if grep -qF "${fake_tmp}/OhanaArchives" <<< "${candidate_block}"; then
  fail "cleanup plan included protected OhanaArchives content"
fi
plan_token="$(awk '/^Plan token:/ { print $3 }' <<< "${cleanup_report_output}")"
[[ -n "${plan_token}" ]] || fail "cleanup report omitted plan token"

printf 'changed\n' > "${expired_tmp}/payload.txt"
touch -t 202001010000 "${expired_tmp}" "${expired_tmp}/payload.txt"
set +e
changed_snapshot_output="$("${repo_root}/scripts/cleanup-local-build-storage.sh" --apply "${plan_token}" 2>&1)"
changed_snapshot_status=$?
set -e
[[ "${changed_snapshot_status}" == "2" ]] || fail "changed candidate snapshot must reject its old token"
[[ -d "${expired_tmp}" ]] || fail "changed candidate snapshot was deleted with an old token"
cleanup_report_output="$("${repo_root}/scripts/cleanup-local-build-storage.sh" 2>&1)"
plan_token="$(awk '/^Plan token:/ { print $3 }' <<< "${cleanup_report_output}")"

set +e
wrong_token_output="$("${repo_root}/scripts/cleanup-local-build-storage.sh" --apply wrong-token 2>&1)"
wrong_token_status=$?
set -e
[[ "${wrong_token_status}" == "2" ]] || fail "wrong cleanup token must exit 2"
grep -qF "plan token does not match" <<< "${wrong_token_output}" || \
  fail "wrong cleanup token rejection message is missing"
[[ -d "${expired_tmp}" ]] || fail "wrong cleanup token deleted an artifact"

set +e
apply_output="$("${repo_root}/scripts/cleanup-local-build-storage.sh" --apply "${plan_token}" 2>&1)"
apply_status=$?
set -e
[[ "${apply_status}" == "0" ]] || fail "correct cleanup token exited ${apply_status}: ${apply_output}"
[[ ! -e "${expired_tmp}" ]] || fail "correct cleanup token did not delete expired safe artifact"
[[ -d "${recent_tmp}" ]] || fail "correct cleanup token deleted recent artifact"
[[ -d "${active_tmp}" ]] || fail "correct cleanup token deleted active artifact"
[[ -d "${archive_child}" ]] || fail "correct cleanup token deleted protected OhanaArchives content"
[[ -d "${outside_tmp}" ]] || fail "correct cleanup token deleted out-of-bound content"
[[ -L "${symlink_tmp}" ]] || fail "correct cleanup token deleted refused symlink"
[[ -d "${OHANA_TEST_DERIVED_DATA_PATH}" ]] || fail "active shared Tests lane was deleted"
[[ -d "${OHANA_TEST_DERIVED_DATA_PATH}/Logs/Build" ]] || fail "active shared Tests Logs/Build child was deleted"
[[ -d "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" ]] || fail "active shared Dogfood build lane was deleted"
[[ -d "${OHANA_RELEASE_DERIVED_DATA_PATH}" ]] || fail "active shared Release lane was deleted"
[[ ! -e "${fake_repo}/.build/DerivedData/Tests" ]] || fail "legacy worktree Tests lane was retained"
[[ ! -e "${fake_repo}/.build/DerivedData/Dogfood" ]] || fail "legacy worktree Dogfood build cache was retained"
[[ ! -e "${fake_repo}/.build/DerivedData/Release" ]] || fail "legacy worktree Release lane was retained"

mkdir -p "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Intermediates.noindex"
printf 'intermediate\n' > \
  "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Intermediates.noindex/rebuildable.txt"
mkdir -p \
  "${OHANA_TEST_DERIVED_DATA_PATH}/ModuleCache.noindex" \
  "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.app.dSYM" \
  "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.swiftmodule"
printf 'module cache\n' > "${OHANA_TEST_DERIVED_DATA_PATH}/ModuleCache.noindex/rebuildable.txt"
printf 'symbols\n' > \
  "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.app.dSYM/rebuildable.txt"
printf 'module output\n' > \
  "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.swiftmodule/rebuildable.txt"
printf 'runtime product\n' > \
  "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.app"
set +e
intermediates_report_output="$(
  "${repo_root}/scripts/cleanup-local-build-storage.sh" --scope test-intermediates 2>&1
)"
intermediates_report_status=$?
set -e
[[ "${intermediates_report_status}" == "0" ]] || \
  fail "test-intermediates report exited ${intermediates_report_status}"
grep -qF "test-rebuildable-cache" <<< "${intermediates_report_output}" || \
  fail "test-intermediates report omitted the candidate kind"
grep -qF "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products" <<< "${intermediates_report_output}" || \
  fail "test-intermediates report omitted the preserved Products tree"
intermediates_token="$(
  awk '/^Plan token:/ { print $3 }' <<< "${intermediates_report_output}"
)"
set +e
intermediates_apply_output="$(
  "${repo_root}/scripts/cleanup-local-build-storage.sh" \
    --scope test-intermediates \
    --apply "${intermediates_token}" 2>&1
)"
intermediates_apply_status=$?
set -e
[[ "${intermediates_apply_status}" == "0" ]] || \
  fail "test-intermediates apply exited ${intermediates_apply_status}: ${intermediates_apply_output}"
[[ ! -e "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Intermediates.noindex" ]] || \
  fail "test-intermediates apply retained rebuildable intermediates"
[[ ! -e "${OHANA_TEST_DERIVED_DATA_PATH}/ModuleCache.noindex" ]] || \
  fail "test-intermediates apply retained the module cache"
[[ ! -e "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.app.dSYM" ]] || \
  fail "test-intermediates apply retained standalone dSYMs"
[[ ! -e "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.swiftmodule" ]] || \
  fail "test-intermediates apply retained standalone Swift modules"
[[ -f "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/proof.txt" ]] || \
  fail "test-intermediates apply deleted a built test product"
[[ -f "${OHANA_TEST_DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/Ohana.app" ]] || \
  fail "test-intermediates apply deleted an executable product"

test_dead_root="${fake_home}/Library/Developer/CoreSimulator/Devices/TEST-UDID/data/Library/Caches/com.apple.containermanagerd/Dead"
safe_dead_cache="${test_dead_root}/temp.ohana"
unrelated_dead_cache="${test_dead_root}/temp.unrelated"
mkdir -p \
  "${safe_dead_cache}/APP-UUID/Ohana.app" \
  "${unrelated_dead_cache}/APP-UUID/Other.app"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.guanchen.li.Ohana</string></dict></plist>' \
  > "${safe_dead_cache}/APP-UUID/Ohana.app/Info.plist"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>MCMMetadataIdentifier</key><string>com.guanchen.li.Ohana</string></dict></plist>' \
  > "${safe_dead_cache}/APP-UUID/.com.apple.mobile_container_manager.metadata.plist"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.example.Other</string></dict></plist>' \
  > "${unrelated_dead_cache}/APP-UUID/Other.app/Info.plist"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>MCMMetadataIdentifier</key><string>com.example.Other</string></dict></plist>' \
  > "${unrelated_dead_cache}/APP-UUID/.com.apple.mobile_container_manager.metadata.plist"
set +e
app_cache_report_output="$(
  "${repo_root}/scripts/cleanup-local-build-storage.sh" --scope test-app-cache 2>&1
)"
app_cache_report_status=$?
set -e
[[ "${app_cache_report_status}" == "0" ]] || \
  fail "test-app-cache report exited ${app_cache_report_status}"
grep -qF "${safe_dead_cache}" <<< "${app_cache_report_output}" || \
  fail "test-app-cache report omitted a metadata-verified Ohana candidate"
if grep -qF "${unrelated_dead_cache}" <<< "${app_cache_report_output}"; then
  fail "test-app-cache report included an unrelated app"
fi
app_cache_token="$(awk '/^Plan token:/ { print $3 }' <<< "${app_cache_report_output}")"
set +e
app_cache_apply_output="$(
  "${repo_root}/scripts/cleanup-local-build-storage.sh" \
    --scope test-app-cache \
    --apply "${app_cache_token}" 2>&1
)"
app_cache_apply_status=$?
set -e
[[ "${app_cache_apply_status}" == "0" ]] || \
  fail "test-app-cache apply exited ${app_cache_apply_status}: ${app_cache_apply_output}"
[[ ! -e "${safe_dead_cache}" ]] || \
  fail "test-app-cache apply retained a verified dead Ohana replacement"
[[ -d "${unrelated_dead_cache}" ]] || \
  fail "test-app-cache apply deleted an unrelated app cache"

download_cache_root="${fake_home}/Library/Developer/CoreSimulator/Devices/TEST-UDID/data/Library/Caches/com.apple.nsurlsessiond/Downloads/com.apple.MobileAsset.DownloadService"
partial_download="${download_cache_root}/CFNetworkDownload_fixture.tmp"
installed_asset="${download_cache_root}/installed.asset"
host_profile_cache="${fake_tmp}/com.ohana.trip.local"
mkdir -p "${partial_download}" "${installed_asset}" "${host_profile_cache}/SESSION"
printf 'partial\n' > "${partial_download}/payload.bin"
printf 'installed\n' > "${installed_asset}/payload.bin"
printf 'profile\n' > "${host_profile_cache}/SESSION/profile.profraw"
set +e
transient_report_output="$(
  "${repo_root}/scripts/cleanup-local-build-storage.sh" --scope test-transient-cache 2>&1
)"
transient_report_status=$?
set -e
[[ "${transient_report_status}" == "0" ]] || \
  fail "test-transient-cache report exited ${transient_report_status}"
grep -qF "${partial_download}" <<< "${transient_report_output}" || \
  fail "test-transient-cache report omitted an unfinished download"
grep -qF "${host_profile_cache}" <<< "${transient_report_output}" || \
  fail "test-transient-cache report omitted an Ohana host profile cache"
if grep -qF "${installed_asset}" <<< "${transient_report_output}"; then
  fail "test-transient-cache report included an installed asset"
fi
transient_token="$(awk '/^Plan token:/ { print $3 }' <<< "${transient_report_output}")"
set +e
transient_apply_output="$(
  "${repo_root}/scripts/cleanup-local-build-storage.sh" \
    --scope test-transient-cache \
    --apply "${transient_token}" 2>&1
)"
transient_apply_status=$?
set -e
[[ "${transient_apply_status}" == "0" ]] || \
  fail "test-transient-cache apply exited ${transient_apply_status}: ${transient_apply_output}"
[[ ! -e "${partial_download}" ]] || \
  fail "test-transient-cache apply retained an unfinished download"
[[ ! -e "${host_profile_cache}" ]] || \
  fail "test-transient-cache apply retained an Ohana host profile cache"
[[ -d "${installed_asset}" ]] || \
  fail "test-transient-cache apply deleted an installed asset"

set +e
stale_token_output="$("${repo_root}/scripts/cleanup-local-build-storage.sh" --apply "${plan_token}" 2>&1)"
stale_token_status=$?
set -e
[[ "${stale_token_status}" == "2" ]] || fail "stale cleanup token with no candidates must exit 2"

set +e
empty_plan_output="$("${repo_root}/scripts/cleanup-local-build-storage.sh" 2>&1)"
empty_plan_status=$?
set -e
[[ "${empty_plan_status}" == "0" ]] || fail "empty cleanup plan exited ${empty_plan_status}"
grep -qF "No conservative cleanup candidates found" <<< "${empty_plan_output}" || \
  fail "empty cleanup plan message is missing"

if [[ "${failures}" -gt 0 ]]; then
  echo "Local build environment tests: ${failures} failure(s)." >&2
  exit 1
fi

echo "Local build environment tests passed."
