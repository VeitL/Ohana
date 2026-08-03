#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ohana-ui-nightly-receipt.XXXXXX")"
fixture_repo="${fixture_root}/repo"
fake_bin="${fixture_root}/bin"
fake_home="${fixture_root}/home"
fake_tmp="${fixture_root}/tmp"
fake_developer_dir="${fixture_root}/Xcode.app/Contents/Developer"
failures=0

cleanup() {
  rm -rf -- "${fixture_root}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

mkdir -p \
  "${fixture_repo}/.build" \
  "${fixture_repo}/Ohana" \
  "${fixture_repo}/Ohana.xcodeproj/xcshareddata/xcschemes" \
  "${fixture_repo}/OhanaUITests" \
  "${fixture_repo}/OhanaWidgets" \
  "${fixture_repo}/Resources" \
  "${fixture_repo}/scripts/lib" \
  "${fake_bin}" \
  "${fake_home}" \
  "${fake_tmp}" \
  "${fake_developer_dir}" \
  "${fixture_root}/receipts"

cp "${repo_root}/scripts/test-ui-nightly.sh" "${fixture_repo}/scripts/test-ui-nightly.sh"
cp "${repo_root}/scripts/lib/local-build-environment.sh" \
  "${fixture_repo}/scripts/lib/local-build-environment.sh"
cp "${repo_root}/scripts/lib/test-build-provenance.sh" \
  "${fixture_repo}/scripts/lib/test-build-provenance.sh"

cat > "${fixture_repo}/.gitignore" <<'EOF'
.build/
EOF
cat > "${fixture_repo}/Ohana/Fixture.swift" <<'EOF'
struct Fixture {}
EOF
cat > "${fixture_repo}/OhanaUITests/FixtureTests.swift" <<'EOF'
final class FixtureTests {}
EOF
cat > "${fixture_repo}/Ohana.xcodeproj/xcshareddata/xcschemes/OhanaUITests.xcscheme" <<'EOF'
<Scheme>
  <TestAction buildConfiguration = "Debug">
  </TestAction>
</Scheme>
EOF
cat > "${fixture_repo}/scripts/ui-test-shards.tsv" <<'EOF'
alpha	OhanaUITests/FixtureTests/testAlphaOne
alpha	OhanaUITests/FixtureTests/testAlphaTwo
beta	OhanaUITests/FixtureTests/testBeta
EOF
cat > "${fixture_repo}/scripts/audit-ui-test-shards.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
cat > "${fixture_repo}/scripts/test-ui-shard.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -gt 0 ]] || exit 2
selected_shard="${!#}"
printf '%s\n' "$*" >> "${FAKE_UI_NIGHTLY_LOG:?}"
if [[ "${1:-}" == "--print" ]]; then
  exit 0
fi
printf 'Managed result bundle: /fixture/staging/%s.xcresult\n' "${selected_shard}"
failed=0
while IFS=$'\t' read -r shard selector; do
  [[ "${shard}" == "${selected_shard}" ]] || continue
  IFS=/ read -r module class_name method <<< "${selector}"
  outcome="passed"
  if [[ "${FAKE_UI_NIGHTLY_SKIP_SHARD:-}" == "${selected_shard}" && "${method}" == *One ]]; then
    outcome="skipped"
  elif [[ "${FAKE_UI_NIGHTLY_FAIL_SHARD:-}" == "${selected_shard}" && "${failed}" == "0" ]]; then
    outcome="failed"
    failed=1
  fi
  printf "Test Case '-[%s.%s %s]' %s (0.001 seconds).\n" \
    "${module}" "${class_name}" "${method}" "${outcome}"
done < "${OHANA_UI_TEST_SHARD_MANIFEST:?}"
if [[ "${FAKE_UI_NIGHTLY_MUTATE_SOURCE_SHARD:-}" == "${selected_shard}" ]]; then
  printf '\n// mutated during shard\n' >> "${FAKE_UI_NIGHTLY_REPO:?}/Ohana/Fixture.swift"
fi
if [[ "${FAKE_UI_NIGHTLY_MUTATE_MANIFEST_SHARD:-}" == "${selected_shard}" ]]; then
  printf '# mutated during shard\n' >> "${OHANA_UI_TEST_SHARD_MANIFEST:?}"
fi
if [[ "${failed}" == "1" ]]; then
  printf 'Preserved failed xcresult: /fixture/failed/%s.xcresult\n' "${selected_shard}"
  exit 17
fi
printf 'Deleted successful xcresult (default retention policy).\n'
EOF

for governed_script in \
  xcode-test.sh \
  test-simulator.sh \
  resolve-test-scheme.sh \
  strip-build-xattrs.sh; do
  cat > "${fixture_repo}/scripts/${governed_script}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
done
cat > "${fixture_repo}/scripts/lib/xcode-storage-lifecycle.sh" <<'EOF'
#!/usr/bin/env bash
EOF

cat > "${fake_bin}/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "simctl list devices available -j" ]]; then
  cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"name":"iPhone 17 Dogfood","udid":"DOGFOOD-UDID","state":"Shutdown","isAvailable":true},
  {"name":"iPhone 17 Tests","udid":"TEST-UDID","state":"Shutdown","isAvailable":true}
]}}
JSON
  exit 0
fi
if [[ "$*" == "--sdk iphonesimulator --show-sdk-version" ]]; then
  printf '26.5\n'
  exit 0
fi
if [[ "$*" == "--sdk iphonesimulator --show-sdk-build-version" ]]; then
  printf '23F100\n'
  exit 0
fi
exit 64
EOF
cat > "${fake_bin}/xcodebuild" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == "-version" ]]; then
  printf 'Xcode 26.4\nBuild version 17F100\n'
  exit 0
fi
exit 64
EOF
cat > "${fake_bin}/xcode-select" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == "-p" ]]; then
  printf '%s\n' '${fake_developer_dir}'
  exit 0
fi
exit 64
EOF

chmod +x \
  "${fixture_repo}/scripts/audit-ui-test-shards.sh" \
  "${fixture_repo}/scripts/test-ui-nightly.sh" \
  "${fixture_repo}/scripts/test-ui-shard.sh" \
  "${fixture_repo}/scripts/"*.sh \
  "${fake_bin}/xcrun" \
  "${fake_bin}/xcodebuild" \
  "${fake_bin}/xcode-select"

printf 'DOGFOOD-UDID\n' > "${fixture_repo}/.build/dogfood-simulator.udid"
git -C "${fixture_repo}" init -q
git -C "${fixture_repo}" config user.email fixture@example.invalid
git -C "${fixture_repo}" config user.name Fixture
git -C "${fixture_repo}" add .
git -C "${fixture_repo}" commit -qm fixture

manifest="${fixture_repo}/scripts/ui-test-shards.tsv"
nightly_log="${fixture_root}/nightly.log"

run_nightly() {
  local receipt_path="$1"
  shift
  env \
    PATH="${fake_bin}:${PATH}" \
    HOME="${fake_home}" \
    TMPDIR="${fake_tmp}" \
    OHANA_LOCAL_BUILD_REPO_ROOT="${fixture_repo}" \
    OHANA_LOCAL_BUILD_CACHE_PARENT="${fixture_root}/cache" \
    OHANA_LOCAL_BUILD_CACHE_ID=0123456789abcdef \
    OHANA_UI_TEST_SHARD_MANIFEST="${manifest}" \
    OHANA_UI_NIGHTLY_RECEIPT_PATH="${receipt_path}" \
    OHANA_TEST_SIMULATOR_UDID=TEST-UDID \
    FAKE_UI_NIGHTLY_REPO="${fixture_repo}" \
    FAKE_UI_NIGHTLY_LOG="${nightly_log}" \
    "$@" \
    "${fixture_repo}/scripts/test-ui-nightly.sh"
}

success_receipt="${fixture_root}/receipts/success.json"
: > "${nightly_log}"
set +e
success_output="$(run_nightly "${success_receipt}" 2>&1)"
success_status=$?
set -e
[[ "${success_status}" == "0" ]] || \
  fail "success fixture exited ${success_status}: ${success_output}"
[[ "$(cat "${nightly_log}")" == $'alpha\nbeta' ]] || \
  fail "success fixture did not execute each shard once in manifest order"
grep -qF 'Nightly UI tests passed: 3 tests across 2 shards.' <<< "${success_output}" || \
  fail "success fixture omitted its dynamic count summary"
if ! python3 - "${success_receipt}" <<'PY'
import json
import pathlib
import sys

receipt = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["schema"] == "ohana.ui-nightly-receipt.v1"
assert receipt["result"] == {
    "exitCode": 0,
    "integritySatisfied": True,
    "reason": None,
    "status": "passed",
}
assert receipt["plan"] == {"derivedFromAuditedManifest": True, "shards": 2, "tests": 3}
assert receipt["summary"]["planned"] == 3
assert receipt["summary"]["executed"] == 3
assert receipt["summary"]["skipped"] == 0
assert receipt["summary"]["failures"] == 0
assert receipt["summary"]["infrastructureFailures"] == 0
assert receipt["source"]["dirty"] is False
assert len(receipt["source"]["revision"]) == 40
assert len(receipt["source"]["sourceTreeSHA256"]) == 64
assert len(receipt["buildContract"]["sha256"]) == 64
assert receipt["buildContract"]["fields"]["planned_tests"] == "3"
assert receipt["buildContract"]["fields"]["planned_shards"] == "2"
assert receipt["environment"]["configuration"] == "Debug"
assert receipt["environment"]["simulator"] == {
    "name": "iPhone 17 Tests",
    "os": "iOS 26.5",
    "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
    "udid": "TEST-UDID",
}
assert [item["name"] for item in receipt["shards"]] == ["alpha", "beta"]
assert [item["planned"] for item in receipt["shards"]] == [2, 1]
assert [item["executed"] for item in receipt["shards"]] == [2, 1]
assert all(item["xcresult"]["retention"] == "success-deleted" for item in receipt["shards"])
assert "successful xcresults" in receipt["retentionAndLimitations"]["countEvidence"]
PY
then
  fail "success receipt omitted or misreported release-proof fields"
fi
if find "${fixture_root}/receipts" -maxdepth 1 -name '.*.tmp.*' -print -quit | grep -q .; then
  fail "atomic receipt writer left a temporary sibling"
fi

setup_failure_receipt="${fixture_root}/receipts/setup-failure.json"
cat > "${setup_failure_receipt}" <<'JSON'
{
  "schema": "ohana.ui-nightly-receipt.v1",
  "receiptId": "stale-passed",
  "result": {
    "exitCode": 0,
    "integritySatisfied": true,
    "reason": null,
    "status": "passed"
  }
}
JSON
: > "${nightly_log}"
set +e
setup_failure_output="$(
  run_nightly \
    "${setup_failure_receipt}" \
    TMPDIR="${fixture_root}/missing-setup-temp" \
    2>&1
)"
setup_failure_status=$?
set -e
[[ "${setup_failure_status}" != "0" ]] || \
  fail "setup-failure fixture unexpectedly passed"
[[ ! -s "${nightly_log}" ]] || \
  fail "setup-failure fixture reached a UI shard"
if ! python3 - "${setup_failure_receipt}" <<'PY'
import json
import pathlib
import sys

receipt = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["schema"] == "ohana.ui-nightly-receipt.v1"
assert receipt["receiptId"] != "stale-passed"
assert receipt["result"]["status"] == "failed"
assert receipt["result"]["exitCode"] != 0
assert receipt["result"]["integritySatisfied"] is False
assert receipt["summary"]["executed"] == 0
assert receipt["summary"]["recordedShards"] == 0
PY
then
  fail "early setup failure preserved or failed to replace the stale passed receipt: ${setup_failure_output}"
fi

failure_receipt="${fixture_root}/receipts/failure.json"
: > "${nightly_log}"
set +e
failure_output="$(run_nightly "${failure_receipt}" FAKE_UI_NIGHTLY_FAIL_SHARD=alpha 2>&1)"
failure_status=$?
set -e
[[ "${failure_status}" == "17" ]] || \
  fail "failed shard status was not preserved: ${failure_status}"
[[ "$(cat "${nightly_log}")" == "alpha" ]] || \
  fail "failure fixture did not stop before the next shard"
grep -qF 'failed shard: alpha.' <<< "${failure_output}" || \
  fail "failure fixture did not identify its shard"
if ! python3 - "${failure_receipt}" <<'PY'
import json
import pathlib
import sys

receipt = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["result"]["status"] == "failed"
assert receipt["result"]["exitCode"] == 17
assert receipt["result"]["integritySatisfied"] is False
assert receipt["summary"]["failures"] == 1
assert receipt["summary"]["recordedShards"] == 1
assert receipt["shards"][0]["xcresult"]["retention"] == "failed-retained"
assert receipt["shards"][0]["xcresult"]["retainedPath"] == "/fixture/failed/alpha.xcresult"
PY
then
  fail "failure receipt was missing or incorrect"
fi

skip_receipt="${fixture_root}/receipts/skip.json"
: > "${nightly_log}"
set +e
skip_output="$(run_nightly "${skip_receipt}" FAKE_UI_NIGHTLY_SKIP_SHARD=alpha 2>&1)"
skip_status=$?
set -e
[[ "${skip_status}" == "65" ]] || fail "a skipped test did not fail closed: ${skip_status}"
if ! python3 - "${skip_receipt}" <<'PY'
import json
import pathlib
import sys

receipt = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["result"]["status"] == "failed"
assert receipt["summary"]["executed"] == 2
assert receipt["summary"]["skipped"] == 1
assert receipt["shards"][0]["result"] == "failed"
PY
then
  fail "skip receipt did not preserve the count-gate failure"
fi

source_receipt="${fixture_root}/receipts/source-mutation.json"
: > "${nightly_log}"
set +e
source_output="$(run_nightly "${source_receipt}" FAKE_UI_NIGHTLY_MUTATE_SOURCE_SHARD=alpha 2>&1)"
source_status=$?
set -e
[[ "${source_status}" == "75" ]] || \
  fail "source mutation did not invalidate Nightly evidence: ${source_status}"
grep -qF 'source/toolchain snapshot changed at after shard alpha' <<< "${source_output}" || \
  fail "source mutation failure was not explained"
if ! python3 - "${source_receipt}" <<'PY'
import json
import pathlib
import sys

receipt = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["result"]["status"] == "failed"
assert receipt["result"]["exitCode"] == 75
assert receipt["shards"][0]["result"] == "invalidated"
PY
then
  fail "source mutation receipt did not mark the shard invalid"
fi
git -C "${fixture_repo}" show HEAD:Ohana/Fixture.swift > "${fixture_repo}/Ohana/Fixture.swift"

manifest_receipt="${fixture_root}/receipts/manifest-mutation.json"
: > "${nightly_log}"
set +e
manifest_output="$(run_nightly "${manifest_receipt}" FAKE_UI_NIGHTLY_MUTATE_MANIFEST_SHARD=alpha 2>&1)"
manifest_status=$?
set -e
[[ "${manifest_status}" == "75" ]] || \
  fail "manifest mutation did not invalidate Nightly evidence: ${manifest_status}"
if ! python3 - "${manifest_receipt}" <<'PY'
import json
import pathlib
import sys

receipt = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert receipt["result"]["status"] == "failed"
assert receipt["result"]["exitCode"] == 75
assert receipt["shards"][0]["result"] == "invalidated"
PY
then
  fail "manifest mutation receipt did not mark the shard invalid"
fi
git -C "${fixture_repo}" show HEAD:scripts/ui-test-shards.tsv > "${manifest}"

: > "${nightly_log}"
set +e
print_output="$(
  PATH="${fake_bin}:${PATH}" \
    OHANA_UI_TEST_SHARD_MANIFEST="${manifest}" \
    FAKE_UI_NIGHTLY_LOG="${nightly_log}" \
    "${fixture_repo}/scripts/test-ui-nightly.sh" --print 2>&1
)"
print_status=$?
set -e
[[ "${print_status}" == "0" ]] || fail "print fixture failed: ${print_output}"
[[ "$(cat "${nightly_log}")" == $'--print alpha\n--print beta' ]] || \
  fail "print fixture did not preserve shard order"

if [[ "${failures}" -ne 0 ]]; then
  echo "UI Nightly receipt fixture tests: ${failures} failure(s)." >&2
  exit 1
fi

echo "UI Nightly receipt fixture tests passed."
