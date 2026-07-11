#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${OHANA_UI_TEST_SHARD_MANIFEST:-${SCRIPT_DIR}/ui-test-shards.tsv}"
UI_TEST_ROOT="${REPO_ROOT}/OhanaUITests"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "UI test shard audit failed: manifest not found: ${MANIFEST}" >&2
  exit 2
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ohana-ui-shards.XXXXXX")"
cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

SOURCE_SELECTORS="${TEMP_DIR}/source-selectors.txt"
MANIFEST_SELECTORS="${TEMP_DIR}/manifest-selectors.txt"
MANIFEST_SHARDS="${TEMP_DIR}/manifest-shards.txt"
: > "${MANIFEST_SELECTORS}"
: > "${MANIFEST_SHARDS}"

syntax_failed=0
line_number=0
while IFS= read -r line || [[ -n "${line}" ]]; do
  line_number=$((line_number + 1))
  line="${line%$'\r'}"
  [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

  IFS=$'\t' read -r shard selector extra <<< "${line}"
  if [[ -z "${shard:-}" || -z "${selector:-}" || -n "${extra:-}" ]]; then
    echo "${MANIFEST}:${line_number}: expected exactly two tab-separated fields" >&2
    syntax_failed=1
    continue
  fi
  if [[ ! "${shard}" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "${MANIFEST}:${line_number}: invalid shard name '${shard}'" >&2
    syntax_failed=1
  fi
  if [[ ! "${selector}" =~ ^OhanaUITests/[A-Za-z_][A-Za-z0-9_]*/test[A-Za-z0-9_]+$ ]]; then
    echo "${MANIFEST}:${line_number}: invalid selector '${selector}'" >&2
    syntax_failed=1
  fi
  printf '%s\n' "${selector}" >> "${MANIFEST_SELECTORS}"
  printf '%s\n' "${shard}" >> "${MANIFEST_SHARDS}"
done < "${MANIFEST}"

if [[ "${syntax_failed}" != "0" ]]; then
  exit 1
fi

perl -ne '
  if (/^\s*(?:final\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*XCTestCase/) {
    $class_name = $1;
  }
  if (/^\s*extension\s+([A-Za-z_][A-Za-z0-9_]*)\b/) {
    $class_name = $1;
  }
  if (/^\s*func\s+(test[A-Za-z0-9_]+)\(\)/) {
    die "$ARGV:$.: XCTestCase class was not found before $1\n" unless $class_name;
    print "OhanaUITests/$class_name/$1\n";
  }
' "${UI_TEST_ROOT}"/*.swift > "${SOURCE_SELECTORS}"

if [[ ! -s "${SOURCE_SELECTORS}" ]]; then
  echo "UI test shard audit failed: no XCTest UI test methods were discovered." >&2
  exit 1
fi
if [[ ! -s "${MANIFEST_SELECTORS}" ]]; then
  echo "UI test shard audit failed: the manifest contains no selectors." >&2
  exit 1
fi

sort "${SOURCE_SELECTORS}" -o "${SOURCE_SELECTORS}"
sort "${MANIFEST_SELECTORS}" -o "${MANIFEST_SELECTORS}"

duplicate_selectors="$(uniq -d "${MANIFEST_SELECTORS}")"
missing_selectors="$(comm -23 "${SOURCE_SELECTORS}" "${MANIFEST_SELECTORS}")"
stale_selectors="$(comm -13 "${SOURCE_SELECTORS}" "${MANIFEST_SELECTORS}")"

failed=0
if [[ -n "${duplicate_selectors}" ]]; then
  echo "UI test shard audit failed: selectors assigned more than once:" >&2
  printf '%s\n' "${duplicate_selectors}" | sed 's/^/  - /' >&2
  failed=1
fi
if [[ -n "${missing_selectors}" ]]; then
  echo "UI test shard audit failed: source tests missing from the manifest:" >&2
  printf '%s\n' "${missing_selectors}" | sed 's/^/  - /' >&2
  failed=1
fi
if [[ -n "${stale_selectors}" ]]; then
  echo "UI test shard audit failed: manifest selectors not found in source:" >&2
  printf '%s\n' "${stale_selectors}" | sed 's/^/  - /' >&2
  failed=1
fi
if [[ "${failed}" != "0" ]]; then
  exit 1
fi

test_count="$(wc -l < "${SOURCE_SELECTORS}" | tr -d '[:space:]')"
shard_count="$(sort -u "${MANIFEST_SHARDS}" | wc -l | tr -d '[:space:]')"
echo "UI test shard audit passed: ${test_count} tests assigned exactly once across ${shard_count} shards."
