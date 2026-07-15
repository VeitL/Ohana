#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${OHANA_UI_TEST_SHARD_MANIFEST:-${SCRIPT_DIR}/ui-test-shards.tsv}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/test-ui-nightly.sh [--print]

Builds the UI-test bundle once, then runs every manifest shard sequentially
with test-without-building. Each shard gets an independent xcresult and the
script continues after a failed shard so the final summary shows all failures.
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
scripts/audit-ui-test-shards.sh

derived_data_root="${REPO_ROOT}/.build/DerivedData/tests"
run_id="$(date +%Y%m%d-%H%M%S)-$$"
run_root="${OHANA_UI_NIGHTLY_RESULT_ROOT:-${REPO_ROOT}/.build/TestResults/ui-nightly}/${run_id}"

shards=()
while IFS= read -r shard; do
  [[ -n "${shard}" ]] && shards+=("${shard}")
done < <(
  awk -F '\t' '
    /^[[:space:]]*#/ || NF == 0 { next }
    !seen[$1]++ { print $1 }
  ' "${MANIFEST}"
)

if [[ "${print_only}" == "1" ]]; then
  printf 'OHANA_TEST_ACTION=build-for-testing DERIVED_DATA_PATH=%q scripts/test-simulator.sh -parallel-testing-enabled NO\n' \
    "${derived_data_root}"
  for shard in "${shards[@]}"; do
    DERIVED_DATA_PATH="${derived_data_root}" \
      OHANA_RESULT_BUNDLE_PATH="${run_root}/${shard}.xcresult" \
      scripts/test-ui-shard.sh --without-building --print "${shard}"
  done
  exit 0
fi

mkdir -p "${run_root}"
summary_path="${run_root}/summary.tsv"
printf 'stage\tstatus\tresult\n' > "${summary_path}"

echo "Nightly UI result directory: ${run_root}"
echo "Building UI tests once..."
if OHANA_TEST_ACTION=build-for-testing \
  DERIVED_DATA_PATH="${derived_data_root}" \
  scripts/test-simulator.sh -parallel-testing-enabled NO 2>&1 | tee "${run_root}/build.log"; then
  printf 'build\tPASS\t%s\n' "${run_root}/build.log" >> "${summary_path}"
else
  printf 'build\tFAIL\t%s\n' "${run_root}/build.log" >> "${summary_path}"
  echo "Nightly UI build failed. Summary: ${summary_path}" >&2
  exit 1
fi

failures=0
for shard in "${shards[@]}"; do
  result_bundle="${run_root}/${shard}.xcresult"
  echo "Running UI shard: ${shard}"
  if DERIVED_DATA_PATH="${derived_data_root}" \
    OHANA_RESULT_BUNDLE_PATH="${result_bundle}" \
    scripts/test-ui-shard.sh --without-building "${shard}" 2>&1 | tee "${run_root}/${shard}.log"; then
    printf '%s\tPASS\t%s\n' "${shard}" "${result_bundle}" >> "${summary_path}"
  else
    printf '%s\tFAIL\t%s\n' "${shard}" "${result_bundle}" >> "${summary_path}"
    failures=$((failures + 1))
  fi
done

echo "Nightly UI summary: ${summary_path}"
if [[ "${failures}" != "0" ]]; then
  echo "Nightly UI tests failed in ${failures} shard(s)." >&2
  exit 1
fi

echo "Nightly UI tests passed: ${#shards[@]} shards."
