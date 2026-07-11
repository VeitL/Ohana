#!/usr/bin/env bash
# Module exit gate: run after finishing a module's fixes, BEFORE committing.
#
# Default mode is the fast changed-scope lane and does not start Xcode. Add one
# or more --test selectors for the business rules changed in this task. Use the
# full unit lane only for a broad module hand-off, and --full only at a phase or
# release boundary.
#
# Usage:
#   scripts/module-exit-gate.sh
#   scripts/module-exit-gate.sh --test OhanaTests/RelevantTests
#   scripts/module-exit-gate.sh --test OhanaTests/RelevantTests \
#     --test OhanaUITests/OhanaUITests/testOneHighValuePath
#   scripts/module-exit-gate.sh --unit
#   scripts/module-exit-gate.sh --full
#
# Exit code 0 = all steps passed; non-zero = at least one step failed.
# The summary at the end lists every failed step.

set -uo pipefail
cd "$(dirname "$0")/.."

MODE="changed"
RUN_FULL_UNIT=0
declare -a TEST_SELECTORS=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/module-exit-gate.sh
  scripts/module-exit-gate.sh --test <target/test> [--test <target/test> ...]
  scripts/module-exit-gate.sh --unit
  scripts/module-exit-gate.sh --full

Lanes:
  no arguments  Changed-file/static checks only; intended for low-risk edits.
  --test        Targeted Unit/Integration proof and, only when needed, one
                high-value UI path. The script adds -only-testing automatically.
  --unit        Changed checks plus the complete OhanaTests unit suite.
  --full        Whole-repository audits plus the complete OhanaTests unit suite.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      [[ $# -ge 2 ]] || {
        echo "--test requires a target/test selector." >&2
        exit 2
      }
      TEST_SELECTORS+=("$2")
      shift 2
      ;;
    --unit)
      RUN_FULL_UNIT=1
      shift
      ;;
    --full)
      MODE="all"
      RUN_FULL_UNIT=1
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

if [[ "${RUN_FULL_UNIT}" == "1" && ${#TEST_SELECTORS[@]} -gt 0 ]]; then
  echo "Choose targeted --test selectors or the full unit lane, not both." >&2
  exit 2
fi

declare -a FAILED=()
declare -a UNIT_TEST_ARGUMENTS=()
declare -a UI_TEST_ARGUMENTS=()

run_step() {
  local name="$1"
  shift
  echo ""
  echo "=== [gate] ${name} ==="
  if "$@"; then
    echo "--- [gate] PASS: ${name}"
  else
    echo "--- [gate] FAIL: ${name}"
    FAILED+=("${name}")
  fi
}

echo "=== [gate] mode: ${MODE} ==="
echo "=== [gate] working tree scope ==="
git status --short

run_step "changed-file checks (format + changed audits)" scripts/dev-check-changed.sh

if [[ "${MODE}" == "all" ]]; then
  run_step "ui-v4 audit (all)" scripts/audit-ui-v4.sh --all
  run_step "accessibility audit (all)" scripts/audit-accessibility.sh --all
  run_step "smoothness audit (all)" scripts/audit-smoothness-risk.sh --all
  run_step "route first-frame audit (all)" scripts/audit-route-first-frame.sh --all
  run_step "runtime guardrails (all)" scripts/audit-runtime-guardrails.sh --all
  run_step "architecture boundaries" scripts/audit-architecture-boundaries.sh
  run_step "economy boundaries (all)" scripts/audit-economy-boundaries.sh --all
  run_step "member lifecycle gate (all)" scripts/audit-member-lifecycle-gate.sh --all
  run_step "agent skill governance" scripts/audit-agent-skill-governance.sh
  run_step "derived-state lifecycle (all)" scripts/audit-derived-state-lifecycle.sh --all
else
  run_step "route first-frame audit (changed)" scripts/audit-route-first-frame.sh --changed
  run_step "runtime guardrails (changed)" scripts/audit-runtime-guardrails.sh --changed
  run_step "economy boundaries (changed)" scripts/audit-economy-boundaries.sh --changed
  run_step "member lifecycle gate (changed)" scripts/audit-member-lifecycle-gate.sh --changed
  run_step "agent skill governance" scripts/audit-agent-skill-governance.sh
  run_step "derived-state lifecycle (changed)" scripts/audit-derived-state-lifecycle.sh --changed
fi

run_step "localization coverage" scripts/audit-localization-coverage.sh

if [[ "${RUN_FULL_UNIT}" == "1" ]]; then
  run_step "full unit test suite (iPhone 17 simulator)" scripts/test-unit.sh
elif [[ ${#TEST_SELECTORS[@]} -gt 0 ]]; then
  for selector in "${TEST_SELECTORS[@]}"; do
    if [[ "${selector}" == -only-testing:* ]]; then
      normalized_selector="${selector#-only-testing:}"
    else
      normalized_selector="${selector}"
    fi
    case "${normalized_selector}" in
      OhanaTests/*)
        UNIT_TEST_ARGUMENTS+=("-only-testing:${normalized_selector}")
        ;;
      OhanaUITests/*)
        UI_TEST_ARGUMENTS+=("-only-testing:${normalized_selector}")
        ;;
      *)
        echo "Unsupported test selector: ${normalized_selector}" >&2
        echo "Selectors must start with OhanaTests/ or OhanaUITests/." >&2
        exit 2
        ;;
    esac
  done
  if [[ ${#UNIT_TEST_ARGUMENTS[@]} -gt 0 ]]; then
    run_step \
      "targeted Unit/Integration lane (iPhone 17 simulator)" \
      env SCHEME=OhanaUnitTests scripts/test-simulator.sh "${UNIT_TEST_ARGUMENTS[@]}"
  fi
  if [[ ${#UI_TEST_ARGUMENTS[@]} -gt 0 ]]; then
    run_step \
      "one targeted UI path (iPhone 17 simulator)" \
      env SCHEME=OhanaUITests scripts/test-simulator.sh -parallel-testing-enabled NO "${UI_TEST_ARGUMENTS[@]}"
  fi
else
  echo "=== [gate] simulator tests: not selected for this low-risk lane ==="
fi

echo ""
if ((${#FAILED[@]})); then
  echo "=== [gate] RESULT: FAIL — ${#FAILED[@]} step(s) failed ==="
  printf ' - %s\n' "${FAILED[@]}"
  exit 1
fi
echo "=== [gate] RESULT: PASS — selected validation lane passed ==="
