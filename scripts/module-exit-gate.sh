#!/usr/bin/env bash
# Module exit gate: run after finishing a module's fixes, BEFORE committing.
#
# Default mode runs changed-scope checks plus the FULL unit test suite on the
# pinned iPhone 17 simulator, so every module hand-off proves the whole app
# still passes its tests — not just the module that was touched.
#
# Usage:
#   scripts/module-exit-gate.sh           # module hand-off gate
#   scripts/module-exit-gate.sh --full    # phase-boundary gate (whole-repo audits)
#
# Exit code 0 = all steps passed; non-zero = at least one step failed.
# The summary at the end lists every failed step.

set -uo pipefail
cd "$(dirname "$0")/.."

MODE="changed"
if [[ "${1:-}" == "--full" ]]; then
  MODE="all"
elif [[ -n "${1:-}" ]]; then
  echo "Usage: scripts/module-exit-gate.sh [--full]" >&2
  exit 2
fi

declare -a FAILED=()

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
  run_step "runtime guardrails (all)" scripts/audit-runtime-guardrails.sh --all
  run_step "architecture boundaries" scripts/audit-architecture-boundaries.sh
  run_step "economy boundaries (all)" scripts/audit-economy-boundaries.sh --all
  run_step "member lifecycle gate (all)" scripts/audit-member-lifecycle-gate.sh --all
  run_step "derived-state lifecycle (all)" scripts/audit-derived-state-lifecycle.sh --all
else
  run_step "runtime guardrails (changed)" scripts/audit-runtime-guardrails.sh --changed
  run_step "economy boundaries (changed)" scripts/audit-economy-boundaries.sh --changed
  run_step "member lifecycle gate (changed)" scripts/audit-member-lifecycle-gate.sh --changed
  run_step "derived-state lifecycle (changed)" scripts/audit-derived-state-lifecycle.sh --changed
fi

run_step "localization coverage" scripts/audit-localization-coverage.sh
run_step "full unit test suite (iPhone 17 simulator)" scripts/test-simulator.sh

echo ""
if ((${#FAILED[@]})); then
  echo "=== [gate] RESULT: FAIL — ${#FAILED[@]} step(s) failed ==="
  printf ' - %s\n' "${FAILED[@]}"
  exit 1
fi
echo "=== [gate] RESULT: PASS — module may be committed ==="
