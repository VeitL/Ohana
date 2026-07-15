#!/usr/bin/env bash
# Fast local gate for the Domain/Economy write-kernel loop.
#
# Default mode is read-only and intentionally avoids xcodebuild:
#   - critical whole-repo architecture/domain audits
#   - audit fixture self-tests, so the audits prove bad/good shapes
#
# Add --tests for a targeted simulator lane and --build only when compiler
# surface changed. Full module/phase gates still belong to module-exit-gate.sh
# and CI.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

run_changed=0
run_audits=1
run_fixtures=1
run_tests=0
run_build=0
full_audits=0
dry_run=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/domain-kernel-fast-gate.sh [options]

Default:
  Read-only fast review gate:
    architecture boundaries --all
    economy boundaries --all
    member lifecycle gate --all
    derived-state lifecycle --all
    audit fixture self-tests

Options:
  --audit-only      Run only the default read-only audit/fixture lane.
  --changed         Also run scripts/dev-check-changed.sh. This may format Swift.
  --tests           Also run targeted Domain/Economy kernel simulator tests.
  --build           Also run scripts/build-debug-fast.sh.
  --full-audits     Expand audits to the CI-like UI/a11y/smoothness/runtime set.
  --full            Run changed checks, full audits, fixtures, targeted tests, and build.
  --no-fixtures     Skip audit fixture self-tests.
  --no-audits       Skip audit lane.
  --dry-run         Print selected commands without executing them.
  -h, --help        Show this help.

Environment:
  DOMAIN_KERNEL_TEST_TARGETS
    Optional whitespace-separated xcodebuild only-testing targets, for example:
    "OhanaTests/MemberLifecycleGateTests OhanaTests/QuestManagerBatchAwardTests"

Exit code:
  0 when all selected lanes pass; non-zero when any selected lane fails.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit-only)
      run_changed=0
      run_audits=1
      run_fixtures=1
      run_tests=0
      run_build=0
      full_audits=0
      shift
      ;;
    --changed)
      run_changed=1
      shift
      ;;
    --tests)
      run_tests=1
      shift
      ;;
    --build)
      run_build=1
      shift
      ;;
    --full-audits)
      full_audits=1
      shift
      ;;
    --full)
      run_changed=1
      run_audits=1
      run_fixtures=1
      run_tests=1
      run_build=1
      full_audits=1
      shift
      ;;
    --no-fixtures)
      run_fixtures=0
      shift
      ;;
    --no-audits)
      run_audits=0
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
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

declare -a FAILED=()
declare -a TEST_TARGETS=()

if [[ -n "${DOMAIN_KERNEL_TEST_TARGETS:-}" ]]; then
  # shellcheck disable=SC2206
  TEST_TARGETS=(${DOMAIN_KERNEL_TEST_TARGETS})
else
  TEST_TARGETS=(
    "OhanaTests/MemberLifecycleGateTests"
    "OhanaTests/OhanaTests"
    "OhanaTests/CareDerivationExecutorSuccessCharacterizationTests"
    "OhanaTests/CareCompletionChokepointCharacterizationTests"
    "OhanaTests/QuestManagerBatchAwardTests"
    "OhanaTests/InsuranceExpenseLedgerTests"
    "OhanaTests/ReminderActionCoordinatorTests"
    "OhanaTests/ReminderMaintenanceServiceTests"
    "OhanaTests/ManualFeedCommandTests"
    "OhanaTests/QuickWaterCommandTests"
    "OhanaTests/CatCareCommandTests"
    "OhanaTests/HomeCommandExecutorTests"
  )
fi

print_command() {
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

run_step() {
  local name="$1"
  shift
  local started ended elapsed
  started="$(date +%s)"
  echo ""
  echo "=== [domain-fast] ${name} ==="
  print_command "$@"
  if [[ "${dry_run}" == "1" ]]; then
    echo "--- [domain-fast] DRY-RUN: ${name}"
    return 0
  fi
  if "$@"; then
    ended="$(date +%s)"
    elapsed=$((ended - started))
    echo "--- [domain-fast] PASS: ${name} (${elapsed}s)"
  else
    ended="$(date +%s)"
    elapsed=$((ended - started))
    echo "--- [domain-fast] FAIL: ${name} (${elapsed}s)"
    FAILED+=("${name}")
  fi
}

echo "=== [domain-fast] selected lanes ==="
echo "changed=${run_changed} audits=${run_audits} fixtures=${run_fixtures} tests=${run_tests} build=${run_build} full_audits=${full_audits} dry_run=${dry_run}"
echo ""
echo "=== [domain-fast] working tree scope ==="
git status --short

if [[ "${run_changed}" == "1" ]]; then
  run_step "changed-file gate" scripts/dev-check-changed.sh
fi

if [[ "${run_audits}" == "1" ]]; then
  if [[ "${full_audits}" == "1" ]]; then
    run_step "ui-v4 audit (all)" scripts/audit-ui-v4.sh --all
    run_step "accessibility audit (all)" scripts/audit-accessibility.sh --all
    run_step "smoothness audit (all)" scripts/audit-smoothness-risk.sh --all
    run_step "runtime guardrails (all)" scripts/audit-runtime-guardrails.sh --all
  fi
  run_step "architecture boundaries (all)" scripts/audit-architecture-boundaries.sh --all
  run_step "economy boundaries (all)" scripts/audit-economy-boundaries.sh --all
  run_step "member lifecycle gate (all)" scripts/audit-member-lifecycle-gate.sh --all
  run_step "derived-state lifecycle (all)" scripts/audit-derived-state-lifecycle.sh --all
fi

if [[ "${run_fixtures}" == "1" ]]; then
  run_step "audit fixture self-tests" scripts/tests/run-audit-fixture-tests.sh
fi

if [[ "${run_tests}" == "1" ]]; then
  test_args=()
  for target in "${TEST_TARGETS[@]}"; do
    test_args+=("-only-testing:${target}")
  done
  run_step "targeted Domain/Economy kernel tests" scripts/test-simulator.sh "${test_args[@]}"
fi

if [[ "${run_build}" == "1" ]]; then
  run_step "debug build (iPhone 17 Tests simulator)" scripts/build-debug-fast.sh
fi

echo ""
if ((${#FAILED[@]})); then
  echo "=== [domain-fast] RESULT: FAIL - ${#FAILED[@]} step(s) failed ==="
  printf ' - %s\n' "${FAILED[@]}"
  exit 1
fi

echo "=== [domain-fast] RESULT: PASS ==="
