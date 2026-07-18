#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ohana-local-build-policy.XXXXXX")"
fake_repo="${fixture_root}/repo"
fake_home="${fixture_root}/home"
fake_bin="${fixture_root}/bin"
failures=0

cleanup() {
  rm -rf "${fixture_root}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

mkdir -p "${fake_repo}/.build" "${fake_home}" "${fake_bin}"
fake_repo="$(cd "${fake_repo}" && pwd)"
printf '%s\n' 'DOGFOOD-UDID' > "${fake_repo}/.build/dogfood-simulator.udid"

cat > "${fake_bin}/xcrun" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == "simctl list devices available -j" ]]; then
  cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"name":"iPhone 17","udid":"DOGFOOD-UDID","state":"Shutdown","isAvailable":true},
  {"name":"iPhone 17 Tests","udid":"TEST-UDID","state":"Shutdown","isAvailable":true},
  {"name":"iPhone 16","udid":"OTHER-UDID","state":"Shutdown","isAvailable":true}
]}}
JSON
  exit 0
fi
exit 64
SH

cat > "${fake_bin}/df" <<'SH'
#!/usr/bin/env bash
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf '/dev/fake 100000000 1 %s 1%% /\n' "${FAKE_AVAILABLE_KIB:-22020096}"
SH
chmod +x "${fake_bin}/xcrun" "${fake_bin}/df"

export OHANA_LOCAL_BUILD_REPO_ROOT="${fake_repo}"
export HOME="${fake_home}"
export PATH="${fake_bin}:${PATH}"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${repo_root}/scripts/lib/local-build-environment.sh"

[[ "${OHANA_TEST_DERIVED_DATA_PATH}" == "${fake_repo}/.build/DerivedData/tests" ]] || \
  fail "tests DerivedData lane drifted"
[[ "${OHANA_DOGFOOD_DERIVED_DATA_PATH_FIXED}" == "${fake_repo}/.build/DerivedData/dogfood" ]] || \
  fail "dogfood DerivedData lane drifted"
[[ "${OHANA_RELEASE_DERIVED_DATA_PATH}" == "${fake_repo}/.build/DerivedData/release" ]] || \
  fail "release DerivedData lane drifted"

if ! ohana_assert_fixed_derived_data_path tests "${OHANA_TEST_DERIVED_DATA_PATH}"; then
  fail "fixed tests DerivedData path was rejected"
fi
if ohana_assert_fixed_derived_data_path tests "${fake_repo}/.build/DerivedData/tfu-123" >/dev/null 2>&1; then
  fail "one-off TFU DerivedData path was accepted"
fi

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

resolved_test_udid="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}")"
[[ "${resolved_test_udid}" == "TEST-UDID" ]] || fail "test device name resolved to ${resolved_test_udid}"

set +e
low_disk_output="$(FAKE_AVAILABLE_KIB=$((19 * 1024 * 1024)) ohana_require_build_disk_space 2>&1)"
low_disk_status=$?
set -e
[[ "${low_disk_status}" == "74" ]] || fail "19 GiB disk preflight must exit 74"
grep -qF "20 GiB is required" <<< "${low_disk_output}" || fail "low-disk threshold message is missing"

if ! FAKE_AVAILABLE_KIB=$((21 * 1024 * 1024)) ohana_require_build_disk_space; then
  fail "21 GiB disk preflight should pass"
fi

grep -qF 'OHANA_TEST_SIMULATOR_NAME_FIXED="iPhone 17 Tests"' \
  "${repo_root}/scripts/lib/local-build-environment.sh" || fail "fixed test device name guard is missing"
grep -qF 'ohana_assert_test_simulator_udid' "${repo_root}/scripts/test-simulator.sh" || \
  fail "test entrypoint no longer calls the Dogfood guard"
grep -qF 'run_xcodebuild_action build-for-testing' "${repo_root}/scripts/test-simulator.sh" || \
  fail "test entrypoint no longer builds test products first"
grep -qF 'run_xcodebuild_action test-without-building' "${repo_root}/scripts/test-simulator.sh" || \
  fail "test entrypoint no longer reuses built products"
grep -qF 'OHANA_TEST_ACTION=build-for-testing' "${repo_root}/scripts/test-ui-nightly.sh" || \
  fail "UI nightly lane no longer builds once before its shards"
grep -qF 'scripts/test-ui-shard.sh --without-building' "${repo_root}/scripts/test-ui-nightly.sh" || \
  fail "UI nightly lane no longer runs shards without rebuilding"

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

if [[ "${failures}" -gt 0 ]]; then
  echo "Local build environment tests: ${failures} failure(s)." >&2
  exit 1
fi

echo "Local build environment tests passed."
