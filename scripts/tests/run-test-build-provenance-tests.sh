#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=scripts/lib/test-build-provenance.sh
source "${REPO_ROOT}/scripts/lib/test-build-provenance.sh"

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ohana-test-build-provenance.XXXXXX")"
fixture_repo="${fixture_root}/repo"
stamp_path="${fixture_repo}/.build/DerivedData/tests/.ohana-test-build-provenance-v1.json"
failures=0

cleanup() {
  rm -rf "${fixture_root}"
}
trap cleanup EXIT

pass() {
  printf 'ok  %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${label}"
  else
    fail "${label}: expected '${expected}', got '${actual}'"
  fi
}

assert_not_equal() {
  local left="$1"
  local right="$2"
  local label="$3"
  if [[ "${left}" != "${right}" ]]; then
    pass "${label}"
  else
    fail "${label}: both values were '${left}'"
  fi
}

ui_input_hash() {
  ohana_test_build_provenance_hash_inputs "${fixture_repo}" \
    Ohana \
    OhanaUITests \
    Ohana.xcodeproj/project.pbxproj \
    Ohana.xcodeproj/xcshareddata/xcschemes/OhanaUITests.xcscheme \
    scripts/strip-build-xattrs.sh
}

unit_input_hash() {
  ohana_test_build_provenance_hash_inputs "${fixture_repo}" \
    Ohana \
    OhanaTests \
    Ohana.xcodeproj/project.pbxproj \
    Ohana.xcodeproj/xcshareddata/xcschemes/OhanaUnitTests.xcscheme \
    scripts/strip-build-xattrs.sh
}

stamp_fields() {
  local scheme="$1"
  local sdk_version="$2"
  local input_scope="$3"
  local source_hash="$4"
  local build_args_hash="$5"
  printf '%s\0' \
    "project=Ohana.xcodeproj" \
    "scheme=${scheme}" \
    "sdk_name=iphonesimulator" \
    "sdk_version=${sdk_version}" \
    "sdk_build_version=23F100" \
    "developer_dir=/Applications/Xcode.app/Contents/Developer" \
    "xcode_version_sha256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
    "destination_udid=TEST-UDID" \
    "code_signing_allowed=NO" \
    "copyfile_disable=1" \
    "build_args_sha256=${build_args_hash}" \
    "input_scope=${input_scope}" \
    "source_tree_sha256=${source_hash}"
}

write_fixture_stamp() {
  local scheme="$1"
  local sdk_version="$2"
  local input_scope="$3"
  local source_hash="$4"
  local build_args_hash="$5"
  local fields=()
  while IFS= read -r -d '' field; do
    fields+=("${field}")
  done < <(stamp_fields "${scheme}" "${sdk_version}" "${input_scope}" "${source_hash}" "${build_args_hash}")
  ohana_test_build_provenance_write_stamp "${stamp_path}" "${fields[@]}"
}

validate_fixture_stamp() {
  local scheme="$1"
  local sdk_version="$2"
  local input_scope="$3"
  local source_hash="$4"
  local build_args_hash="$5"
  local fields=()
  while IFS= read -r -d '' field; do
    fields+=("${field}")
  done < <(stamp_fields "${scheme}" "${sdk_version}" "${input_scope}" "${source_hash}" "${build_args_hash}")
  ohana_test_build_provenance_validate_stamp "${stamp_path}" "${fields[@]}"
}

mkdir -p \
  "${fixture_repo}/Ohana/Features/Home" \
  "${fixture_repo}/OhanaUITests" \
  "${fixture_repo}/OhanaTests" \
  "${fixture_repo}/Ohana.xcodeproj/xcshareddata/xcschemes" \
  "${fixture_repo}/scripts"
printf 'struct AppRoot {}\n' > "${fixture_repo}/Ohana/App.swift"
printf 'struct HomeView {}\n' > "${fixture_repo}/Ohana/Features/Home/HomeView.swift"
printf 'final class UITests {}\n' > "${fixture_repo}/OhanaUITests/OhanaUITests.swift"
printf 'final class UnitTests {}\n' > "${fixture_repo}/OhanaTests/OhanaTests.swift"
printf '// project\n' > "${fixture_repo}/Ohana.xcodeproj/project.pbxproj"
printf '<Scheme name="OhanaUITests"/>\n' > \
  "${fixture_repo}/Ohana.xcodeproj/xcshareddata/xcschemes/OhanaUITests.xcscheme"
printf '<Scheme name="OhanaUnitTests"/>\n' > \
  "${fixture_repo}/Ohana.xcodeproj/xcshareddata/xcschemes/OhanaUnitTests.xcscheme"
printf '#!/usr/bin/env bash\n' > "${fixture_repo}/scripts/strip-build-xattrs.sh"
printf 'fixture documentation\n' > "${fixture_repo}/README.md"

selector_a='-only-testing:OhanaUITests/OhanaUITests/testPetA'
selector_b='-only-testing:OhanaUITests/OhanaUITests/testPetB'
skip_selector='-skip-testing:OhanaUITests/OhanaUITests/testPetC'
args_hash_a="$(ohana_test_build_provenance_build_args_sha256 \
  -parallel-testing-enabled NO "${selector_a}" "${skip_selector}")"
args_hash_b="$(ohana_test_build_provenance_build_args_sha256 \
  -parallel-testing-enabled NO "${selector_b}")"
assert_equal "${args_hash_a}" "${args_hash_b}" \
  "same-scheme selector changes do not invalidate build arguments"

configuration_hash="$(ohana_test_build_provenance_build_args_sha256 \
  -parallel-testing-enabled NO -configuration Release "${selector_b}")"
assert_not_equal "${args_hash_a}" "${configuration_hash}" \
  "non-selector build options remain provenance inputs"

filtered_args=()
while IFS= read -r -d '' argument; do
  filtered_args+=("${argument}")
done < <(ohana_test_build_provenance_filter_build_args \
  -parallel-testing-enabled NO "${selector_a}" "${skip_selector}" -configuration Debug)
if [[ ${#filtered_args[@]} -eq 4 \
  && "${filtered_args[0]}" == "-parallel-testing-enabled" \
  && "${filtered_args[1]}" == "NO" \
  && "${filtered_args[2]}" == "-configuration" \
  && "${filtered_args[3]}" == "Debug" ]]; then
  pass "selector filtering preserves every other argument and its order"
else
  fail "selector filtering changed non-selector argument boundaries"
fi

ui_hash_initial="$(ui_input_hash)"
touch "${fixture_repo}/Ohana/App.swift"
ui_hash_after_touch="$(ui_input_hash)"
assert_equal "${ui_hash_initial}" "${ui_hash_after_touch}" \
  "touch-only input changes do not invalidate content provenance"

printf 'updated fixture documentation\n' > "${fixture_repo}/README.md"
ui_hash_after_docs="$(ui_input_hash)"
assert_equal "${ui_hash_initial}" "${ui_hash_after_docs}" \
  "scope-external documentation changes do not invalidate UI products"

unit_hash_initial="$(unit_input_hash)"
printf 'final class UnitTests { func changed() {} }\n' > \
  "${fixture_repo}/OhanaTests/OhanaTests.swift"
ui_hash_after_unit_change="$(ui_input_hash)"
unit_hash_after_unit_change="$(unit_input_hash)"
assert_equal "${ui_hash_initial}" "${ui_hash_after_unit_change}" \
  "Unit-only test changes do not invalidate the UI scheme scope"
assert_not_equal "${unit_hash_initial}" "${unit_hash_after_unit_change}" \
  "Unit test content changes invalidate the Unit scheme scope"

printf 'final class UITests { func changed() {} }\n' > \
  "${fixture_repo}/OhanaUITests/OhanaUITests.swift"
ui_hash_after_ui_change="$(ui_input_hash)"
assert_not_equal "${ui_hash_initial}" "${ui_hash_after_ui_change}" \
  "dirty UI test content invalidates UI products"

printf 'final class SparseFixture {}\n' > \
  "${fixture_repo}/OhanaUITests/Sparse Fixture.swift"
ui_hash_with_untracked_file="$(ui_input_hash)"
assert_not_equal "${ui_hash_after_ui_change}" "${ui_hash_with_untracked_file}" \
  "untracked files in a synchronized target invalidate products"
rm "${fixture_repo}/OhanaUITests/Sparse Fixture.swift"
ui_hash_after_untracked_removal="$(ui_input_hash)"
assert_equal "${ui_hash_after_ui_change}" "${ui_hash_after_untracked_removal}" \
  "removing an untracked input restores the content digest"

cp "${fixture_repo}/Ohana/App.swift" "${fixture_repo}/Ohana/App.swift.saved"
rm "${fixture_repo}/Ohana/App.swift"
ui_hash_after_delete="$(ui_input_hash)"
assert_not_equal "${ui_hash_after_ui_change}" "${ui_hash_after_delete}" \
  "deleted target inputs invalidate products"
mv "${fixture_repo}/Ohana/App.swift.saved" "${fixture_repo}/Ohana/App.swift"

ui_hash_restored="$(ui_input_hash)"
chmod +x "${fixture_repo}/Ohana/App.swift"
ui_hash_after_mode_change="$(ui_input_hash)"
assert_not_equal "${ui_hash_restored}" "${ui_hash_after_mode_change}" \
  "input mode changes invalidate products"
chmod -x "${fixture_repo}/Ohana/App.swift"

set +e
missing_output="$(validate_fixture_stamp \
  OhanaUITests 26.5 app+ui "${ui_hash_after_ui_change}" "${args_hash_a}" 2>&1)"
missing_status=$?
set -e
if [[ "${missing_status}" -eq 66 ]] \
  && grep -qF "no successful build-for-testing provenance stamp exists" <<< "${missing_output}" \
  && grep -qF "OHANA_TEST_ACTION=build-then-test" <<< "${missing_output}"; then
  pass "missing stamps fail closed with an actionable rebuild message"
else
  fail "missing stamp validation returned ${missing_status}: ${missing_output}"
fi

write_output="$(write_fixture_stamp \
  OhanaUITests 26.5 app+ui "${ui_hash_after_ui_change}" "${args_hash_a}")"
if [[ "${write_output}" =~ ^[0-9a-f]{64}$ && -f "${stamp_path}" ]]; then
  pass "successful build provenance writes an atomic self-hashed stamp"
else
  fail "stamp write did not return a SHA-256 contract"
fi

if validate_fixture_stamp \
  OhanaUITests 26.5 app+ui "${ui_hash_after_ui_change}" "${args_hash_b}"; then
  pass "a different selector in the same scheme reuses the stamped build"
else
  fail "same-scheme selector reuse was rejected"
fi

stored_scheme="$(ohana_test_build_provenance_stamp_field "${stamp_path}" scheme)"
assert_equal "OhanaUITests" "${stored_scheme}" "stamp metadata preserves its active scheme"

if find "$(dirname "${stamp_path}")" -maxdepth 1 -name ".$(basename "${stamp_path}").tmp.*" \
  -print -quit | grep -q .; then
  fail "atomic stamp write left a sibling temporary file"
else
  pass "atomic stamp write leaves no temporary residue"
fi

set +e
scheme_output="$(validate_fixture_stamp \
  OhanaUnitTests 26.5 app+unit "${ui_hash_after_ui_change}" "${args_hash_b}" 2>&1)"
scheme_status=$?
set -e
if [[ "${scheme_status}" -eq 66 ]] \
  && grep -qF "Changed fields:" <<< "${scheme_output}" \
  && grep -qF "scheme" <<< "${scheme_output}"; then
  pass "the shared active stamp rejects a different scheme"
else
  fail "different-scheme validation returned ${scheme_status}: ${scheme_output}"
fi

set +e
sdk_output="$(validate_fixture_stamp \
  OhanaUITests 26.6 app+ui "${ui_hash_after_ui_change}" "${args_hash_b}" 2>&1)"
sdk_status=$?
set -e
if [[ "${sdk_status}" -eq 66 ]] && grep -qF "sdk_version" <<< "${sdk_output}"; then
  pass "SDK changes invalidate the active stamp"
else
  fail "SDK mismatch validation returned ${sdk_status}: ${sdk_output}"
fi

set +e
source_output="$(validate_fixture_stamp \
  OhanaUITests 26.5 app+ui "${ui_hash_initial}" "${args_hash_b}" 2>&1)"
source_status=$?
set -e
if [[ "${source_status}" -eq 66 ]] && grep -qF "source_tree_sha256" <<< "${source_output}"; then
  pass "source changes invalidate the active stamp"
else
  fail "source mismatch validation returned ${source_status}: ${source_output}"
fi

cp "${stamp_path}" "${stamp_path}.valid"
printf '{ malformed\n' > "${stamp_path}"
set +e
malformed_output="$(validate_fixture_stamp \
  OhanaUITests 26.5 app+ui "${ui_hash_after_ui_change}" "${args_hash_b}" 2>&1)"
malformed_status=$?
set -e
if [[ "${malformed_status}" -eq 66 ]] && grep -qF "stamp is malformed" <<< "${malformed_output}"; then
  pass "malformed stamps fail closed"
else
  fail "malformed stamp validation returned ${malformed_status}: ${malformed_output}"
fi
mv "${stamp_path}.valid" "${stamp_path}"

ohana_test_build_provenance_invalidate_stamp "${stamp_path}"
if [[ ! -e "${stamp_path}" ]]; then
  pass "build-start invalidation removes the previous active stamp"
else
  fail "stamp invalidation left the previous stamp in place"
fi

set +e
missing_field_output="$(ohana_test_build_provenance_write_stamp \
  "${stamp_path}" "scheme=OhanaUITests" 2>&1)"
missing_field_status=$?
set -e
if [[ "${missing_field_status}" -eq 64 ]] \
  && grep -qF "missing required stamp field" <<< "${missing_field_output}"; then
  pass "weak or incomplete stamp contracts are rejected"
else
  fail "incomplete stamp write returned ${missing_field_status}: ${missing_field_output}"
fi

if [[ "${failures}" -ne 0 ]]; then
  echo "Test build provenance fixture tests: ${failures} failure(s)." >&2
  exit 1
fi

echo "Test build provenance fixture tests passed."
