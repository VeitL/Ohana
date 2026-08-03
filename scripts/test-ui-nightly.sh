#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${OHANA_UI_TEST_SHARD_MANIFEST:-${SCRIPT_DIR}/ui-test-shards.tsv}"
NIGHTLY_SCRIPT="${SCRIPT_DIR}/test-ui-nightly.sh"
SHARD_SCRIPT="${SCRIPT_DIR}/test-ui-shard.sh"
AUDIT_SCRIPT="${SCRIPT_DIR}/audit-ui-test-shards.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/test-ui-nightly.sh [--print]

Runs every manifest shard sequentially through its normal governed
build-then-test lifecycle. The fixed cache keeps those builds incremental, and
the script stops at the first failed shard so a broken Simulator session cannot
contaminate later evidence. A source-frozen, atomic JSON receipt is written
under the shared TestResults evidence/receipts directory for every attempted
run, including failures. Managed xcresults keep their existing bounded
retention policy; this wrapper creates no DerivedData or timestamp log lane.

Environment:
  OHANA_UI_NIGHTLY_RECEIPT_PATH  Absolute JSON receipt override outside
                                 DerivedData
USAGE
}

print_only=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print)
      print_only=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "${REPO_ROOT}"
export SCHEME="${SCHEME:-OhanaUITests}"
if [[ "${SCHEME}" != "OhanaUITests" ]]; then
  echo "Nightly UI evidence requires SCHEME=OhanaUITests; got '${SCHEME}'." >&2
  exit 2
fi
if [[ "${SDK:-iphonesimulator}" != "iphonesimulator" ]]; then
  echo "Nightly UI evidence requires SDK=iphonesimulator." >&2
  exit 2
fi
if [[ "${CODE_SIGNING_ALLOWED:-NO}" != "NO" ]]; then
  echo "Nightly UI evidence requires CODE_SIGNING_ALLOWED=NO." >&2
  exit 2
fi
if [[ "${OHANA_TEST_CODE_COVERAGE:-NO}" != "NO" ]]; then
  echo "Nightly UI evidence requires code coverage off." >&2
  exit 2
fi
if [[ "${OHANA_TEST_PARALLEL_ENABLED:-NO}:${OHANA_TEST_MAXIMUM_WORKERS:-1}" != "NO:1" ]]; then
  echo "Nightly UI evidence requires parallel testing off and one worker." >&2
  exit 2
fi

load_shard_names() {
  awk -F '\t' '
    /^[[:space:]]*#/ || NF == 0 { next }
    !seen[$1]++ { print $1 }
  ' "${MANIFEST}"
}

if [[ "${print_only}" == "1" ]]; then
  "${AUDIT_SCRIPT}"
  while IFS= read -r shard; do
    [[ -n "${shard}" ]] || continue
    scripts/test-ui-shard.sh --print "${shard}"
  done < <(load_shard_names)
  exit 0
fi

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"
# shellcheck source=scripts/lib/test-build-provenance.sh
source "${REPO_ROOT}/scripts/lib/test-build-provenance.sh"

RUN_TEMP=""
CONTRACT_FIELDS_FILE=""
SHARD_ORDER_FILE=""
SHARD_RECORDS_DIR=""
RUN_ACTIVE=0
RUN_RESULT="running"
RUN_FAILURE_REASON="run did not reach its completion gate"
RUN_END_AT=""
RUN_END_EPOCH=""
RUN_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
RUN_STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_STARTED_EPOCH="$(date -u +%s)"
COMPLETED_SHARDS=0
PLANNED_TESTS=0
PLANNED_SHARDS=0
SOURCE_REVISION=""
SOURCE_DIRTY="unknown"
FROZEN_SOURCE_TREE_SHA256=""
FROZEN_BUILD_CONTRACT_SHA256=""
FROZEN_MANIFEST_SHA256=""
FROZEN_NIGHTLY_SCRIPT_SHA256=""
FROZEN_SHARD_SCRIPT_SHA256=""
FROZEN_AUDIT_SCRIPT_SHA256=""
FROZEN_XCODE_TEST_SCRIPT_SHA256=""
FROZEN_TEST_SIMULATOR_SCRIPT_SHA256=""
FROZEN_XCODE_VERSION=""
FROZEN_XCODE_VERSION_SHA256=""
FROZEN_DEVELOPER_DIR=""
FROZEN_SDK_VERSION=""
FROZEN_SDK_BUILD_VERSION=""
FROZEN_SIMULATOR_NAME=""
FROZEN_SIMULATOR_UDID=""
FROZEN_SIMULATOR_RUNTIME=""
FROZEN_SIMULATOR_OS=""
FROZEN_CONFIGURATION=""
FROZEN_BUILD_ARGS_SHA256=""
FROZEN_CONTRACT_FIELDS=()

NIGHTLY_SOURCE_PATHS=(
  Ohana
  Ohana.xcodeproj
  OhanaUITests
  OhanaWidgets
  Resources
  scripts/audit-ui-test-shards.sh
  scripts/ui-test-shards.tsv
  scripts/test-ui-nightly.sh
  scripts/test-ui-shard.sh
  scripts/xcode-test.sh
  scripts/test-simulator.sh
  scripts/resolve-test-scheme.sh
  scripts/strip-build-xattrs.sh
  scripts/lib/local-build-environment.sh
  scripts/lib/xcode-storage-lifecycle.sh
  scripts/lib/test-build-provenance.sh
)

RECEIPT_PATH="${OHANA_UI_NIGHTLY_RECEIPT_PATH:-${OHANA_TEST_RESULT_ROOT}/evidence/receipts/last-ui-nightly.json}"
if [[ "${RECEIPT_PATH}" != /* ]]; then
  echo "OHANA_UI_NIGHTLY_RECEIPT_PATH must be absolute." >&2
  exit 2
fi
if python3 - "${RECEIPT_PATH}" "${OHANA_SHARED_DERIVED_DATA_ROOT}" <<'PY'
import os
import sys

receipt = os.path.realpath(sys.argv[1])
derived = os.path.realpath(sys.argv[2])
try:
    beneath = os.path.commonpath((receipt, derived)) == derived
except ValueError:
    beneath = False
if beneath:
    print("Nightly receipt must not be written beneath DerivedData.", file=sys.stderr)
    raise SystemExit(2)
if not receipt.endswith(".json"):
    print("Nightly receipt path must end in .json.", file=sys.stderr)
    raise SystemExit(2)
PY
then
  :
else
  receipt_path_status=$?
  exit "${receipt_path_status}"
fi

stable_file_sha256() {
  python3 - "$1" <<'PY'
import hashlib
import os
import sys

path = sys.argv[1]
try:
    before = os.stat(path, follow_symlinks=False)
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    after = os.stat(path, follow_symlinks=False)
except (FileNotFoundError, IsADirectoryError, PermissionError) as error:
    print(f"Nightly provenance could not hash {path}: {error}", file=sys.stderr)
    raise SystemExit(66)
identity_before = (
    before.st_dev,
    before.st_ino,
    before.st_mode,
    before.st_size,
    before.st_mtime_ns,
)
identity_after = (
    after.st_dev,
    after.st_ino,
    after.st_mode,
    after.st_size,
    after.st_mtime_ns,
)
if identity_before != identity_after:
    print(f"Nightly provenance input changed while hashing: {path}", file=sys.stderr)
    raise SystemExit(75)
print(digest.hexdigest())
PY
}

resolve_test_udid() {
  local resolved=""
  if [[ -n "${DESTINATION:-}" ]]; then
    if [[ "${DESTINATION}" =~ (^|,)id=([^,]+) ]]; then
      resolved="${BASH_REMATCH[2]}"
    else
      echo "DESTINATION must be an explicit iOS Simulator id." >&2
      return 2
    fi
  elif [[ -n "${OHANA_TEST_SIMULATOR_UDID:-}" ]]; then
    resolved="${OHANA_TEST_SIMULATOR_UDID}"
  else
    resolved="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}" || true)"
  fi
  if [[ -z "${resolved}" ]]; then
    echo "No available '${OHANA_TEST_SIMULATOR_NAME_FIXED}' Simulator." >&2
    return 70
  fi
  ohana_assert_test_simulator_udid "${resolved}" || return
  printf '%s\n' "${resolved}"
}

configuration_from_scheme() {
  local scheme_path="Ohana.xcodeproj/xcshareddata/xcschemes/${SCHEME}.xcscheme"
  sed -n '
    /<TestAction/,/>/ {
      s/.*buildConfiguration = "\([^"]*\)".*/\1/p
    }
  ' "${scheme_path}" | head -n 1
}

runtime_display_name() {
  local runtime="$1"
  local version="${runtime##*.}"
  version="${version#iOS-}"
  version="${version//-/.}"
  printf 'iOS %s\n' "${version}"
}

compute_current_snapshot() {
  CUR_SOURCE_TREE_SHA256="$(
    ohana_test_build_provenance_hash_inputs \
      "${REPO_ROOT}" \
      "${NIGHTLY_SOURCE_PATHS[@]}"
  )" || return
  CUR_MANIFEST_SHA256="$(stable_file_sha256 "${MANIFEST}")" || return
  CUR_NIGHTLY_SCRIPT_SHA256="$(stable_file_sha256 "${NIGHTLY_SCRIPT}")" || return
  CUR_SHARD_SCRIPT_SHA256="$(stable_file_sha256 "${SHARD_SCRIPT}")" || return
  CUR_AUDIT_SCRIPT_SHA256="$(stable_file_sha256 "${AUDIT_SCRIPT}")" || return
  CUR_XCODE_TEST_SCRIPT_SHA256="$(stable_file_sha256 "${SCRIPT_DIR}/xcode-test.sh")" || return
  CUR_TEST_SIMULATOR_SCRIPT_SHA256="$(stable_file_sha256 "${SCRIPT_DIR}/test-simulator.sh")" || return

  CUR_SOURCE_REVISION="$(git rev-parse --verify HEAD 2>/dev/null)" || {
    echo "Nightly provenance requires a Git HEAD revision." >&2
    return 66
  }
  if [[ -n "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
    CUR_SOURCE_DIRTY="true"
  else
    CUR_SOURCE_DIRTY="false"
  fi

  CUR_SIMULATOR_UDID="$(resolve_test_udid)" || return
  local simulator_metadata
  simulator_metadata="$(ohana_simulator_metadata "${CUR_SIMULATOR_UDID}")" || {
    echo "Simulator metadata is unavailable for ${CUR_SIMULATOR_UDID}." >&2
    return 70
  }
  CUR_SIMULATOR_NAME="$(printf '%s' "${simulator_metadata}" | awk -F '\t' '{ print $1 }')"
  CUR_SIMULATOR_RUNTIME="$(printf '%s' "${simulator_metadata}" | awk -F '\t' '{ print $2 }')"
  CUR_SIMULATOR_OS="$(runtime_display_name "${CUR_SIMULATOR_RUNTIME}")"

  CUR_XCODE_VERSION="$(xcodebuild -version)" || return
  CUR_XCODE_VERSION_SHA256="$(printf '%s\n' "${CUR_XCODE_VERSION}" | shasum -a 256 | awk '{ print $1 }')"
  CUR_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}" || return
  CUR_DEVELOPER_DIR="$(cd "${CUR_DEVELOPER_DIR}" && pwd -P)" || return
  CUR_SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)" || return
  CUR_SDK_BUILD_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-build-version)" || return
  CUR_CONFIGURATION="$(configuration_from_scheme)" || return
  if [[ -z "${CUR_CONFIGURATION}" ]]; then
    echo "Could not derive the ${SCHEME} TestAction build configuration." >&2
    return 66
  fi
  CUR_BUILD_ARGS_SHA256="$(ohana_test_build_provenance_build_args_sha256)" || return
}

build_current_contract() {
  CUR_CONTRACT_FIELDS=(
    "project=Ohana.xcodeproj"
    "scheme=${SCHEME}"
    "configuration=${CUR_CONFIGURATION}"
    "sdk_name=iphonesimulator"
    "sdk_version=${CUR_SDK_VERSION}"
    "sdk_build_version=${CUR_SDK_BUILD_VERSION}"
    "developer_dir=${CUR_DEVELOPER_DIR}"
    "xcode_version_sha256=${CUR_XCODE_VERSION_SHA256}"
    "destination_udid=${CUR_SIMULATOR_UDID}"
    "destination_name=${CUR_SIMULATOR_NAME}"
    "destination_runtime=${CUR_SIMULATOR_RUNTIME}"
    "code_signing_allowed=NO"
    "code_coverage=NO"
    "parallel_testing=${OHANA_TEST_PARALLEL_ENABLED:-NO}"
    "maximum_workers=${OHANA_TEST_MAXIMUM_WORKERS:-1}"
    "copyfile_disable=${COPYFILE_DISABLE:-1}"
    "build_args_sha256=${CUR_BUILD_ARGS_SHA256}"
    "input_scope=app+widgets+resources+ui+governed-entrypoints"
    "source_tree_sha256=${CUR_SOURCE_TREE_SHA256}"
    "source_revision=${CUR_SOURCE_REVISION}"
    "source_dirty=${CUR_SOURCE_DIRTY}"
    "manifest_sha256=${CUR_MANIFEST_SHA256}"
    "nightly_script_sha256=${CUR_NIGHTLY_SCRIPT_SHA256}"
    "shard_script_sha256=${CUR_SHARD_SCRIPT_SHA256}"
    "audit_script_sha256=${CUR_AUDIT_SCRIPT_SHA256}"
    "xcode_test_script_sha256=${CUR_XCODE_TEST_SCRIPT_SHA256}"
    "test_simulator_script_sha256=${CUR_TEST_SIMULATOR_SCRIPT_SHA256}"
    "test_action=sequential-build-then-test"
    "planned_tests=${PLANNED_TESTS}"
    "planned_shards=${PLANNED_SHARDS}"
  )
  CUR_BUILD_CONTRACT_SHA256="$(
    ohana_test_build_provenance_contract_sha256 "${CUR_CONTRACT_FIELDS[@]}"
  )" || return
}

freeze_snapshot() {
  FROZEN_SOURCE_TREE_SHA256="${CUR_SOURCE_TREE_SHA256}"
  FROZEN_MANIFEST_SHA256="${CUR_MANIFEST_SHA256}"
  FROZEN_NIGHTLY_SCRIPT_SHA256="${CUR_NIGHTLY_SCRIPT_SHA256}"
  FROZEN_SHARD_SCRIPT_SHA256="${CUR_SHARD_SCRIPT_SHA256}"
  FROZEN_AUDIT_SCRIPT_SHA256="${CUR_AUDIT_SCRIPT_SHA256}"
  FROZEN_XCODE_TEST_SCRIPT_SHA256="${CUR_XCODE_TEST_SCRIPT_SHA256}"
  FROZEN_TEST_SIMULATOR_SCRIPT_SHA256="${CUR_TEST_SIMULATOR_SCRIPT_SHA256}"
  SOURCE_REVISION="${CUR_SOURCE_REVISION}"
  SOURCE_DIRTY="${CUR_SOURCE_DIRTY}"
  FROZEN_XCODE_VERSION="${CUR_XCODE_VERSION}"
  FROZEN_XCODE_VERSION_SHA256="${CUR_XCODE_VERSION_SHA256}"
  FROZEN_DEVELOPER_DIR="${CUR_DEVELOPER_DIR}"
  FROZEN_SDK_VERSION="${CUR_SDK_VERSION}"
  FROZEN_SDK_BUILD_VERSION="${CUR_SDK_BUILD_VERSION}"
  FROZEN_SIMULATOR_NAME="${CUR_SIMULATOR_NAME}"
  FROZEN_SIMULATOR_UDID="${CUR_SIMULATOR_UDID}"
  FROZEN_SIMULATOR_RUNTIME="${CUR_SIMULATOR_RUNTIME}"
  FROZEN_SIMULATOR_OS="${CUR_SIMULATOR_OS}"
  FROZEN_CONFIGURATION="${CUR_CONFIGURATION}"
  FROZEN_BUILD_ARGS_SHA256="${CUR_BUILD_ARGS_SHA256}"
}

freeze_contract() {
  FROZEN_BUILD_CONTRACT_SHA256="${CUR_BUILD_CONTRACT_SHA256}"
  FROZEN_CONTRACT_FIELDS=("${CUR_CONTRACT_FIELDS[@]}")
  printf '%s\n' "${FROZEN_CONTRACT_FIELDS[@]}" > "${CONTRACT_FIELDS_FILE}"
}

base_snapshot_matches_frozen() {
  [[ "${CUR_SOURCE_TREE_SHA256}" == "${FROZEN_SOURCE_TREE_SHA256}" ]] || return 1
  [[ "${CUR_MANIFEST_SHA256}" == "${FROZEN_MANIFEST_SHA256}" ]] || return 1
  [[ "${CUR_NIGHTLY_SCRIPT_SHA256}" == "${FROZEN_NIGHTLY_SCRIPT_SHA256}" ]] || return 1
  [[ "${CUR_SHARD_SCRIPT_SHA256}" == "${FROZEN_SHARD_SCRIPT_SHA256}" ]] || return 1
  [[ "${CUR_AUDIT_SCRIPT_SHA256}" == "${FROZEN_AUDIT_SCRIPT_SHA256}" ]] || return 1
  [[ "${CUR_XCODE_TEST_SCRIPT_SHA256}" == "${FROZEN_XCODE_TEST_SCRIPT_SHA256}" ]] || return 1
  [[ "${CUR_TEST_SIMULATOR_SCRIPT_SHA256}" == "${FROZEN_TEST_SIMULATOR_SCRIPT_SHA256}" ]] || return 1
  [[ "${CUR_SOURCE_REVISION}" == "${SOURCE_REVISION}" ]] || return 1
  [[ "${CUR_SOURCE_DIRTY}" == "${SOURCE_DIRTY}" ]] || return 1
  [[ "${CUR_XCODE_VERSION}" == "${FROZEN_XCODE_VERSION}" ]] || return 1
  [[ "${CUR_XCODE_VERSION_SHA256}" == "${FROZEN_XCODE_VERSION_SHA256}" ]] || return 1
  [[ "${CUR_DEVELOPER_DIR}" == "${FROZEN_DEVELOPER_DIR}" ]] || return 1
  [[ "${CUR_SDK_VERSION}" == "${FROZEN_SDK_VERSION}" ]] || return 1
  [[ "${CUR_SDK_BUILD_VERSION}" == "${FROZEN_SDK_BUILD_VERSION}" ]] || return 1
  [[ "${CUR_SIMULATOR_NAME}" == "${FROZEN_SIMULATOR_NAME}" ]] || return 1
  [[ "${CUR_SIMULATOR_UDID}" == "${FROZEN_SIMULATOR_UDID}" ]] || return 1
  [[ "${CUR_SIMULATOR_RUNTIME}" == "${FROZEN_SIMULATOR_RUNTIME}" ]] || return 1
  [[ "${CUR_SIMULATOR_OS}" == "${FROZEN_SIMULATOR_OS}" ]] || return 1
  [[ "${CUR_CONFIGURATION}" == "${FROZEN_CONFIGURATION}" ]] || return 1
  [[ "${CUR_BUILD_ARGS_SHA256}" == "${FROZEN_BUILD_ARGS_SHA256}" ]] || return 1
}

verify_frozen_inputs() {
  local boundary="$1"
  compute_current_snapshot || return
  build_current_contract || return

  if ! base_snapshot_matches_frozen; then
    echo "Nightly source/toolchain snapshot changed at ${boundary}; evidence is invalid." >&2
    return 75
  fi
  if [[ "${CUR_SOURCE_TREE_SHA256}" != "${FROZEN_SOURCE_TREE_SHA256}" ]]; then
    echo "Nightly source tree changed at ${boundary}; evidence is invalid." >&2
    return 75
  fi
  if [[ "${CUR_MANIFEST_SHA256}" != "${FROZEN_MANIFEST_SHA256}" ]]; then
    echo "Nightly shard manifest changed at ${boundary}; evidence is invalid." >&2
    return 75
  fi
  if [[ "${CUR_NIGHTLY_SCRIPT_SHA256}" != "${FROZEN_NIGHTLY_SCRIPT_SHA256}" || \
    "${CUR_SHARD_SCRIPT_SHA256}" != "${FROZEN_SHARD_SCRIPT_SHA256}" || \
    "${CUR_AUDIT_SCRIPT_SHA256}" != "${FROZEN_AUDIT_SCRIPT_SHA256}" || \
    "${CUR_XCODE_TEST_SCRIPT_SHA256}" != "${FROZEN_XCODE_TEST_SCRIPT_SHA256}" || \
    "${CUR_TEST_SIMULATOR_SCRIPT_SHA256}" != "${FROZEN_TEST_SIMULATOR_SCRIPT_SHA256}" ]]; then
    echo "Nightly governed test scripts changed at ${boundary}; evidence is invalid." >&2
    return 75
  fi
  if [[ "${CUR_BUILD_CONTRACT_SHA256}" != "${FROZEN_BUILD_CONTRACT_SHA256}" ]]; then
    echo "Nightly build contract changed at ${boundary}; evidence is invalid." >&2
    return 75
  fi
}

prepare_plan() {
  : > "${SHARD_ORDER_FILE}"
  while IFS= read -r shard; do
    [[ -n "${shard}" ]] || continue
    printf '%s\n' "${shard}" >> "${SHARD_ORDER_FILE}"
    awk -F '\t' -v selected="${shard}" '
      /^[[:space:]]*#/ || NF == 0 { next }
      $1 == selected { print $2 }
    ' "${MANIFEST}" > "${RUN_TEMP}/plan/${shard}.txt"
  done < <(load_shard_names)
  PLANNED_SHARDS="$(wc -l < "${SHARD_ORDER_FILE}" | tr -d '[:space:]')"
  PLANNED_TESTS="$(
    awk -F '\t' '/^[[:space:]]*#/ || NF == 0 { next } { count++ } END { print count + 0 }' \
      "${MANIFEST}"
  )"
  if [[ "${PLANNED_SHARDS}" -le 0 || "${PLANNED_TESTS}" -le 0 ]]; then
    echo "Nightly manifest must plan at least one shard and one test." >&2
    return 66
  fi
}

parse_shard_log() {
  local shard="$1"
  local order="$2"
  local child_status="$3"
  local started_at="$4"
  local started_epoch="$5"
  local ended_at="$6"
  local ended_epoch="$7"
  local log_path="$8"
  local record_path="${RUN_TEMP}/shards/${shard}.json"
  python3 - \
    "${shard}" \
    "${order}" \
    "${child_status}" \
    "${started_at}" \
    "${started_epoch}" \
    "${ended_at}" \
    "${ended_epoch}" \
    "${RUN_TEMP}/plan/${shard}.txt" \
    "${log_path}" \
    "${record_path}" <<'PY'
import json
import os
import pathlib
import re
import sys
import tempfile

(
    shard,
    order_raw,
    exit_raw,
    started_at,
    started_epoch_raw,
    ended_at,
    ended_epoch_raw,
    plan_raw,
    log_raw,
    record_raw,
) = sys.argv[1:]
plan_path = pathlib.Path(plan_raw)
log_path = pathlib.Path(log_raw)
record_path = pathlib.Path(record_raw)
planned = [line.strip() for line in plan_path.read_text(encoding="utf-8").splitlines() if line.strip()]
planned_set = set(planned)
terminal = re.compile(
    r"^\s*Test Case '-\[([^.\]\s]+)\.([^\]\s]+) (test[A-Za-z0-9_]+)\]' "
    r"(passed|failed|skipped)\b"
)
events = {}
duplicates = []
unexpected = []
staging_path = None
retained_path = None
retention = "not-created-or-unknown"
for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
    match = terminal.match(line)
    if match:
        module, class_name, method, outcome = match.groups()
        selector = f"{module}/{class_name}/{method}"
        if selector not in planned_set:
            unexpected.append(selector)
        elif selector in events:
            duplicates.append(selector)
        else:
            events[selector] = outcome
    if line.startswith("Managed result bundle: "):
        staging_path = line.split(": ", 1)[1]
    elif line.startswith("Preserved failed xcresult: "):
        retained_path = line.split(": ", 1)[1]
        retention = "failed-retained"
    elif line.startswith("Kept successful xcresult: "):
        retained_path = line.split(": ", 1)[1]
        retention = "success-retained"
    elif "Deleted successful xcresult (default retention policy)." in line:
        retention = "success-deleted"

missing = [selector for selector in planned if selector not in events]
passed = sum(outcome == "passed" for outcome in events.values())
failures = sum(outcome == "failed" for outcome in events.values())
skipped = sum(outcome == "skipped" for outcome in events.values())
executed = len(events)
exit_code = int(exit_raw)
infrastructure_failures = 1 if exit_code != 0 and failures == 0 else 0
evidence_errors = []
if duplicates:
    evidence_errors.append("duplicate terminal results")
if unexpected:
    evidence_errors.append("unplanned terminal results")
if missing:
    evidence_errors.append("planned selectors without terminal results")
if exit_code == 0 and failures:
    evidence_errors.append("failed tests with a zero shard exit status")
result = "passed"
if (
    exit_code != 0
    or executed != len(planned)
    or skipped != 0
    or failures != 0
    or duplicates
    or unexpected
):
    result = "failed"

record = {
    "order": int(order_raw),
    "name": shard,
    "command": ["scripts/test-ui-shard.sh", shard],
    "startedAt": started_at,
    "startedAtEpoch": int(started_epoch_raw),
    "endedAt": ended_at,
    "endedAtEpoch": int(ended_epoch_raw),
    "durationSeconds": max(0, int(ended_epoch_raw) - int(started_epoch_raw)),
    "planned": len(planned),
    "executed": executed,
    "passed": passed,
    "skipped": skipped,
    "failures": failures,
    "infrastructureFailures": infrastructure_failures,
    "exitCode": exit_code,
    "result": result,
    "evidenceErrors": evidence_errors,
    "missingSelectors": missing,
    "duplicateSelectors": sorted(set(duplicates)),
    "unexpectedSelectors": sorted(set(unexpected)),
    "countEvidence": {
        "source": "complete live xcodebuild XCTest terminal Test Case lines",
        "temporaryLogRetained": False,
    },
    "xcresult": {
        "stagingPath": staging_path,
        "retainedPath": retained_path,
        "retention": retention,
    },
}
record_path.parent.mkdir(parents=True, exist_ok=True)
descriptor, temporary_raw = tempfile.mkstemp(prefix=f".{record_path.name}.tmp.", dir=record_path.parent)
temporary = pathlib.Path(temporary_raw)
try:
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump(record, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, record_path)
finally:
    temporary.unlink(missing_ok=True)
PY
}

invalidate_shard_record() {
  local shard="$1"
  local reason="$2"
  python3 - "${RUN_TEMP}/shards/${shard}.json" "${reason}" <<'PY'
import json
import os
import pathlib
import sys
import tempfile

path = pathlib.Path(sys.argv[1])
record = json.loads(path.read_text(encoding="utf-8"))
record["result"] = "invalidated"
record["invalidationReason"] = sys.argv[2]
descriptor, temporary_raw = tempfile.mkstemp(prefix=f".{path.name}.tmp.", dir=path.parent)
temporary = pathlib.Path(temporary_raw)
try:
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump(record, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)
finally:
    temporary.unlink(missing_ok=True)
PY
}

shard_record_result() {
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["result"])' "$1"
}

write_receipt() {
  local exit_code="$1"
  python3 - \
    "${RECEIPT_PATH}" \
    "${RUN_ID}" \
    "${RUN_STARTED_AT}" \
    "${RUN_STARTED_EPOCH}" \
    "${RUN_END_AT}" \
    "${RUN_END_EPOCH}" \
    "${RUN_RESULT}" \
    "${exit_code}" \
    "${RUN_FAILURE_REASON}" \
    "${REPO_ROOT}" \
    "${SCHEME}" \
    "${SOURCE_REVISION}" \
    "${SOURCE_DIRTY}" \
    "${FROZEN_SOURCE_TREE_SHA256}" \
    "${FROZEN_BUILD_CONTRACT_SHA256}" \
    "${CONTRACT_FIELDS_FILE}" \
    "${FROZEN_MANIFEST_SHA256}" \
    "${FROZEN_NIGHTLY_SCRIPT_SHA256}" \
    "${FROZEN_SHARD_SCRIPT_SHA256}" \
    "${FROZEN_AUDIT_SCRIPT_SHA256}" \
    "${FROZEN_XCODE_TEST_SCRIPT_SHA256}" \
    "${FROZEN_TEST_SIMULATOR_SCRIPT_SHA256}" \
    "${PLANNED_TESTS}" \
    "${PLANNED_SHARDS}" \
    "${COMPLETED_SHARDS}" \
    "${FROZEN_XCODE_VERSION}" \
    "${FROZEN_DEVELOPER_DIR}" \
    "${FROZEN_SDK_VERSION}" \
    "${FROZEN_SDK_BUILD_VERSION}" \
    "${FROZEN_CONFIGURATION}" \
    "${FROZEN_SIMULATOR_NAME}" \
    "${FROZEN_SIMULATOR_UDID}" \
    "${FROZEN_SIMULATOR_RUNTIME}" \
    "${FROZEN_SIMULATOR_OS}" \
    "${SHARD_RECORDS_DIR}" \
    "${OHANA_TEST_FAILURE_RETENTION_COUNT}" \
    "${OHANA_TEST_FAILURE_RETENTION_DAYS}" <<'PY'
import json
import os
import pathlib
import sys
import tempfile

(
    receipt_raw,
    receipt_id,
    started_at,
    started_epoch_raw,
    ended_at_raw,
    ended_epoch_raw,
    requested_status,
    exit_raw,
    failure_reason,
    repo_root,
    scheme,
    revision,
    dirty_raw,
    source_tree_sha256,
    contract_sha256,
    contract_fields_raw,
    manifest_sha256,
    nightly_sha256,
    shard_sha256,
    audit_sha256,
    xcode_test_sha256,
    test_simulator_sha256,
    planned_tests_raw,
    planned_shards_raw,
    completed_shards_raw,
    xcode_version,
    developer_dir,
    sdk_version,
    sdk_build_version,
    configuration,
    simulator_name,
    simulator_udid,
    simulator_runtime,
    simulator_os,
    shard_dir_raw,
    failure_retention_count_raw,
    failure_retention_days_raw,
) = sys.argv[1:]

receipt_path = pathlib.Path(receipt_raw)
contract_fields = {}
contract_fields_path = pathlib.Path(contract_fields_raw) if contract_fields_raw else None
if contract_fields_path is not None and contract_fields_path.is_file():
    for line in contract_fields_path.read_text(encoding="utf-8").splitlines():
        if not line:
            continue
        key, value = line.split("=", 1)
        contract_fields[key] = value

shards = []
shard_dir = pathlib.Path(shard_dir_raw) if shard_dir_raw else None
if shard_dir is not None and shard_dir.is_dir():
    for path in shard_dir.glob("*.json"):
        shards.append(json.loads(path.read_text(encoding="utf-8")))
shards.sort(key=lambda item: item["order"])

planned_tests = int(planned_tests_raw)
planned_shards = int(planned_shards_raw)
summary = {
    "planned": planned_tests,
    "executed": sum(item["executed"] for item in shards),
    "passed": sum(item["passed"] for item in shards),
    "skipped": sum(item["skipped"] for item in shards),
    "failures": sum(item["failures"] for item in shards),
    "infrastructureFailures": sum(item["infrastructureFailures"] for item in shards),
    "plannedShards": planned_shards,
    "recordedShards": len(shards),
    "completedShards": int(completed_shards_raw),
}
integrity_satisfied = (
    planned_tests > 0
    and planned_shards > 0
    and len(shards) == planned_shards
    and summary["executed"] == planned_tests
    and summary["skipped"] == 0
    and summary["failures"] == 0
    and summary["infrastructureFailures"] == 0
    and all(item["result"] == "passed" for item in shards)
)
status = requested_status
exit_code = int(exit_raw)
reason = failure_reason
if requested_status == "passed" and not integrity_satisfied:
    status = "failed"
    exit_code = 65
    reason = "receipt count integrity gate failed"

document = {
    "schema": "ohana.ui-nightly-receipt.v1",
    "receiptId": receipt_id,
    "command": {
        "argv": ["scripts/test-ui-nightly.sh"],
        "display": f"SCHEME={scheme} scripts/test-ui-nightly.sh",
        "workingDirectory": repo_root,
        "scheme": scheme,
        "testAction": "sequential-build-then-test-per-shard",
    },
    "startedAt": started_at,
    "startedAtEpoch": int(started_epoch_raw),
    "endedAt": ended_at_raw or None,
    "endedAtEpoch": int(ended_epoch_raw) if ended_epoch_raw else None,
    "result": {
        "status": status,
        "exitCode": exit_code,
        "reason": reason or None,
        "integritySatisfied": integrity_satisfied,
    },
    "source": {
        "revision": revision or None,
        "dirty": {"true": True, "false": False}.get(dirty_raw),
        "sourceTreeSHA256": source_tree_sha256 or None,
    },
    "buildContract": {
        "schema": "ohana-test-build-provenance-v1",
        "sha256": contract_sha256 or None,
        "fields": contract_fields,
    },
    "frozenInputs": {
        "manifest": {"path": os.path.relpath(os.environ.get("OHANA_UI_TEST_SHARD_MANIFEST", "scripts/ui-test-shards.tsv"), repo_root), "sha256": manifest_sha256 or None},
        "nightlyScriptSHA256": nightly_sha256 or None,
        "shardScriptSHA256": shard_sha256 or None,
        "auditScriptSHA256": audit_sha256 or None,
        "xcodeTestScriptSHA256": xcode_test_sha256 or None,
        "testSimulatorScriptSHA256": test_simulator_sha256 or None,
    },
    "plan": {
        "tests": planned_tests,
        "shards": planned_shards,
        "derivedFromAuditedManifest": True if planned_tests and planned_shards else False,
    },
    "shards": shards,
    "summary": summary,
    "environment": {
        "xcode": {
            "version": xcode_version or None,
            "developerDirectory": developer_dir or None,
        },
        "sdk": {
            "name": "iphonesimulator",
            "version": sdk_version or None,
            "buildVersion": sdk_build_version or None,
        },
        "configuration": configuration or None,
        "simulator": {
            "name": simulator_name or None,
            "udid": simulator_udid or None,
            "runtimeIdentifier": simulator_runtime or None,
            "os": simulator_os or None,
        },
    },
    "retentionAndLimitations": {
        "receipt": "Atomically replaces the shared last-ui-nightly.json receipt; it is outside DerivedData.",
        "successfulXcresults": "Deleted by the governed test entrypoint by default.",
        "failedXcresults": f"At most {failure_retention_count_raw} failed bundles are kept for {failure_retention_days_raw} days; retained paths are recorded per shard when emitted.",
        "countEvidence": "Counts are parsed from complete live XCTest terminal Test Case lines because successful xcresults are deleted before this wrapper regains control.",
        "temporaryLogs": "Per-shard tee logs exist only for this wrapper process and are removed after the atomic receipt is finalized.",
        "doesNotProve": "This unsigned disposable-Simulator run does not prove signing, physical-device behavior, permissions, background delivery, StoreKit/iCloud, or external App Store state.",
    },
}

receipt_path.parent.mkdir(parents=True, exist_ok=True)
descriptor, temporary_raw = tempfile.mkstemp(prefix=f".{receipt_path.name}.tmp.", dir=receipt_path.parent)
temporary = pathlib.Path(temporary_raw)
try:
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temporary, 0o644)
    os.replace(temporary, receipt_path)
    try:
        directory_descriptor = os.open(receipt_path.parent, os.O_RDONLY)
    except OSError:
        directory_descriptor = None
    if directory_descriptor is not None:
        try:
            os.fsync(directory_descriptor)
        except OSError:
            pass
        finally:
            os.close(directory_descriptor)
finally:
    temporary.unlink(missing_ok=True)
PY
}

receipt_status() {
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["result"]["status"])' \
    "${RECEIPT_PATH}"
}

finalize_run() {
  local original_status=$?
  local final_status="${original_status}"
  local writer_status=0
  trap - EXIT INT TERM HUP
  set +e
  if [[ "${RUN_ACTIVE}" == "1" ]]; then
    if [[ -z "${RUN_END_AT}" ]]; then
      RUN_END_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      RUN_END_EPOCH="$(date -u +%s)"
    fi
    if [[ "${original_status}" != "0" && "${RUN_RESULT}" == "running" ]]; then
      RUN_RESULT="failed"
    fi
    write_receipt "${original_status}"
    writer_status=$?
    if [[ "${writer_status}" != "0" ]]; then
      echo "Failed to atomically write Nightly receipt: ${RECEIPT_PATH}" >&2
      [[ "${final_status}" != "0" ]] || final_status=74
    elif [[ "${original_status}" == "0" && "$(receipt_status)" != "passed" ]]; then
      echo "Nightly receipt integrity gate rejected the apparent success." >&2
      final_status=65
    else
      echo "Nightly receipt: ${RECEIPT_PATH}"
    fi
  fi
  if [[ -n "${RUN_TEMP}" && -d "${RUN_TEMP}" ]]; then
    rm -rf -- "${RUN_TEMP}"
  fi
  exit "${final_status}"
}

signal_exit() {
  local signal_name="$1"
  local signal_status="$2"
  RUN_RESULT="interrupted"
  RUN_FAILURE_REASON="received ${signal_name}"
  exit "${signal_status}"
}

trap finalize_run EXIT
trap 'signal_exit SIGINT 130' INT
trap 'signal_exit SIGTERM 143' TERM
trap 'signal_exit SIGHUP 129' HUP

# Replace any stale success receipt before temporary-directory or plan setup.
# From this point onward, every catchable setup failure is finalized as failed;
# an uncatchable termination can leave only this explicit running sentinel.
RUN_ACTIVE=1
write_receipt 0

RUN_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/ohana-ui-nightly.XXXXXX")"
CONTRACT_FIELDS_FILE="${RUN_TEMP}/contract-fields.txt"
SHARD_ORDER_FILE="${RUN_TEMP}/shard-order.txt"
SHARD_RECORDS_DIR="${RUN_TEMP}/shards"
mkdir -p "${RUN_TEMP}/plan" "${SHARD_RECORDS_DIR}"
: > "${CONTRACT_FIELDS_FILE}"
: > "${SHARD_ORDER_FILE}"

if ! compute_current_snapshot; then
  RUN_FAILURE_REASON="could not capture the initial Nightly source/build snapshot"
  exit 66
fi
freeze_snapshot

if ! "${AUDIT_SCRIPT}"; then
  RUN_FAILURE_REASON="UI shard manifest audit failed"
  exit 65
fi

# The audit reads both test source and the manifest. Recheck its inputs before
# declaring the audited plan frozen.
if ! compute_current_snapshot; then
  RUN_FAILURE_REASON="could not recapture Nightly inputs after the shard audit"
  exit 66
fi
if ! base_snapshot_matches_frozen; then
  RUN_FAILURE_REASON="Nightly inputs changed during the shard audit"
  echo "Nightly inputs changed during the shard audit; evidence is invalid." >&2
  exit 75
fi
prepare_plan
build_current_contract
freeze_contract
write_receipt 0

echo "Nightly frozen source: ${FROZEN_SOURCE_TREE_SHA256}"
echo "Nightly build contract: ${FROZEN_BUILD_CONTRACT_SHA256}"
echo "Nightly plan: ${PLANNED_TESTS} tests across ${PLANNED_SHARDS} shards"
echo "Nightly destination: ${FROZEN_SIMULATOR_NAME} (${FROZEN_SIMULATOR_UDID}), ${FROZEN_SIMULATOR_OS}"

shard_order=0
while IFS= read -r shard; do
  [[ -n "${shard}" ]] || continue
  shard_order=$((shard_order + 1))
  if ! verify_frozen_inputs "before shard ${shard}"; then
    RUN_FAILURE_REASON="frozen Nightly inputs changed before shard ${shard}"
    exit 75
  fi

  planned_for_shard="$(wc -l < "${RUN_TEMP}/plan/${shard}.txt" | tr -d '[:space:]')"
  shard_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  shard_started_epoch="$(date -u +%s)"
  shard_log="${RUN_TEMP}/${shard}.log"
  echo "Running UI shard: ${shard} (${planned_for_shard} planned)"
  set +e
  scripts/test-ui-shard.sh "${shard}" 2>&1 | tee "${shard_log}"
  pipeline_status=("${PIPESTATUS[@]}")
  set -e
  shard_status="${pipeline_status[0]}"
  if [[ "${pipeline_status[1]}" != "0" ]]; then
    echo "Nightly could not capture the complete ${shard} output log." >&2
    shard_status=74
  fi
  shard_ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  shard_ended_epoch="$(date -u +%s)"
  parse_shard_log \
    "${shard}" \
    "${shard_order}" \
    "${shard_status}" \
    "${shard_started_at}" \
    "${shard_started_epoch}" \
    "${shard_ended_at}" \
    "${shard_ended_epoch}" \
    "${shard_log}"

  if ! verify_frozen_inputs "after shard ${shard}"; then
    RUN_FAILURE_REASON="frozen Nightly inputs changed while shard ${shard} ran"
    invalidate_shard_record "${shard}" "${RUN_FAILURE_REASON}"
    write_receipt 75
    exit 75
  fi

  shard_result="$(shard_record_result "${RUN_TEMP}/shards/${shard}.json")"
  if [[ "${shard_result}" != "passed" ]]; then
    RUN_FAILURE_REASON="shard ${shard} failed execution or count integrity"
    write_receipt "${shard_status}"
    echo "Nightly UI tests stopped after ${COMPLETED_SHARDS}/${PLANNED_SHARDS} completed shard(s); failed shard: ${shard}." >&2
    echo "Inspect the managed failure result and run scripts/xcode-storage-audit.sh before retrying a repeated failure." >&2
    if [[ "${shard_status}" == "0" ]]; then
      exit 65
    fi
    exit "${shard_status}"
  fi

  COMPLETED_SHARDS=$((COMPLETED_SHARDS + 1))
  write_receipt 0
done < "${SHARD_ORDER_FILE}"

RUN_RESULT="passed"
RUN_FAILURE_REASON=""
RUN_END_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_END_EPOCH="$(date -u +%s)"
echo "Nightly UI tests passed: ${PLANNED_TESTS} tests across ${PLANNED_SHARDS} shards."
