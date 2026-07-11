#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

audit="scripts/audit-code-complexity.sh"
fixtures="scripts/tests/fixtures/Complexity"
thresholds=(
  OHANA_COMPLEXITY_FUNCTION_BODY_LIMIT=5
  OHANA_COMPLEXITY_TYPE_BODY_LIMIT=8
  OHANA_COMPLEXITY_CYCLOMATIC_LIMIT=3
  OHANA_COMPLEXITY_PARAMETER_LIMIT=3
)

set +e
bad_output="$(env "${thresholds[@]}" "$audit" "$fixtures/ComplexityBad.swift" 2>&1)"
bad_status=$?
set -e

if [[ "$bad_status" -ne 1 ]]; then
  echo "FAIL: complexity bad fixture expected exit 1, got ${bad_status}: ${bad_output}" >&2
  exit 1
fi

for rule in function_body_length type_body_length cyclomatic_complexity function_parameter_count; do
  if ! grep -qF "[$rule]" <<<"$bad_output"; then
    echo "FAIL: complexity bad fixture no longer fires [$rule]" >&2
    exit 1
  fi
done
echo "ok  complexity audit catches all four guarded rule families"

if ! good_output="$(env "${thresholds[@]}" "$audit" "$fixtures/ComplexityGood.swift" 2>&1)"; then
  echo "FAIL: complexity good fixture expected clean exit: ${good_output}" >&2
  exit 1
fi
echo "ok  complexity audit passes the good fixture"

scope_output="$($audit --all --soft)"
scope_count="$(grep -oE '[0-9]+ file\(s\)' <<<"$scope_output" | head -1 | grep -oE '^[0-9]+' || true)"
if [[ -z "$scope_count" || "$scope_count" -lt 900 ]]; then
  echo "FAIL: complexity --all scan scope collapsed (${scope_count:-unparseable} files)" >&2
  exit 1
fi
echo "ok  complexity audit --all scans ${scope_count} production file(s)"
