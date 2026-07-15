#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${OHANA_UI_TEST_SHARD_MANIFEST:-${SCRIPT_DIR}/ui-test-shards.tsv}"

cd "${REPO_ROOT}"

export SCHEME="${SCHEME:-OhanaUITests}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/test-ui-shard.sh --list
  scripts/test-ui-shard.sh [--without-building] [--print] <shard> [-- xcodebuild args...]

Runs one UI-test shard sequentially on the disposable iPhone 17 Tests device.
Normal mode builds once and then tests without rebuilding. --without-building
reuses a preceding build-for-testing run. Every run writes a distinct xcresult.

Environment:
  OHANA_UI_TEST_RESULT_ROOT        Default xcresult directory
  OHANA_RESULT_BUNDLE_PATH         Exact xcresult path override
  OHANA_UI_TEST_SHARD_MANIFEST     Alternate shard manifest
USAGE
}

list_shards() {
  awk -F '\t' '
    /^[[:space:]]*#/ || NF == 0 { next }
    !seen[$1]++ { order[++count] = $1 }
    { tests[$1]++ }
    END {
      for (item = 1; item <= count; item++) {
        shard = order[item]
        printf "%-24s %3d tests\n", shard, tests[shard]
      }
    }
  ' "${MANIFEST}"
}

mode="run"
action="build-then-test"
shard=""
xcode_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --list)
      scripts/audit-ui-test-shards.sh
      list_shards
      exit 0
      ;;
    --without-building)
      action="test-without-building"
      shift
      ;;
    --print)
      mode="print"
      shift
      ;;
    --)
      shift
      if [[ $# -gt 0 ]]; then
        xcode_args+=("$@")
      fi
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "${shard}" ]]; then
        echo "Only one shard may be selected." >&2
        exit 2
      fi
      shard="$1"
      shift
      ;;
  esac
done

if [[ -z "${shard}" ]]; then
  usage >&2
  exit 2
fi

scripts/audit-ui-test-shards.sh

selectors=()
while IFS=$'\t' read -r manifest_shard selector extra; do
  [[ -z "${manifest_shard}" || "${manifest_shard}" =~ ^[[:space:]]*# ]] && continue
  if [[ "${manifest_shard}" == "${shard}" ]]; then
    selectors+=("-only-testing:${selector}")
  fi
done < "${MANIFEST}"

if [[ ${#selectors[@]} -eq 0 ]]; then
  echo "Unknown UI test shard: ${shard}" >&2
  echo "Available shards:" >&2
  list_shards >&2
  exit 2
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
result_root="${OHANA_UI_TEST_RESULT_ROOT:-${REPO_ROOT}/.build/TestResults/ui-shards}"
result_bundle="${OHANA_RESULT_BUNDLE_PATH:-${result_root}/${timestamp}-${shard}-$$.xcresult}"
derived_data_root="${REPO_ROOT}/.build/DerivedData/tests"

command=(scripts/test-simulator.sh -parallel-testing-enabled NO)
command+=("${selectors[@]}")
if [[ ${#xcode_args[@]} -gt 0 ]]; then
  command+=("${xcode_args[@]}")
fi

if [[ "${mode}" == "print" ]]; then
  printf 'OHANA_TEST_ACTION=%q DERIVED_DATA_PATH=%q OHANA_RESULT_BUNDLE_PATH=%q' \
    "${action}" "${derived_data_root}" "${result_bundle}"
  printf ' %q' "${command[@]}"
  printf '\n'
  exit 0
fi

export OHANA_TEST_ACTION="${action}"
export DERIVED_DATA_PATH="${derived_data_root}"
export OHANA_RESULT_BUNDLE_PATH="${result_bundle}"

echo "UI shard: ${shard} (${#selectors[@]} tests)"
echo "Result bundle: ${result_bundle}"
exec "${command[@]}"
