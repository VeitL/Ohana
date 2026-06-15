#!/usr/bin/env bash
set -euo pipefail

# Self-tests for the audit scripts. Two failure classes are covered:
#
#   1. Rule drift: a regex edit silently stops catching a known-bad pattern,
#      or starts flagging known-good code. Each audit runs against bad/good
#      fixture files under scripts/tests/fixtures/.
#   2. Scope drift: a directory refactor silently shrinks the scanned file
#      set (this actually happened: the Features/ refactor removed 88% of
#      files from three "whole repo" gates). Each audit's --all mode must
#      scan at least SCOPE_FLOOR Swift files.
#
# Run locally or in CI: scripts/tests/run-audit-fixture-tests.sh

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

SCOPE_FLOOR=600

failures=0
output=""
status=0

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

run_audit() {
  local script="$1"
  shift
  set +e
  output="$("$script" "$@" 2>&1)"
  status=$?
  set -e
}

# Bad fixture: strict mode must exit 1 and report every expected rule id.
assert_bad() {
  local script="$1"
  local fixture="$2"
  shift 2
  run_audit "$script" "$fixture"
  if [[ "$status" -ne 1 ]]; then
    fail "$script $fixture: expected strict exit 1, got $status"
    return
  fi
  local rule
  for rule in "$@"; do
    if ! grep -qF "[$rule]" <<<"$output"; then
      fail "$script $fixture: rule [$rule] no longer fires"
    fi
  done
  echo "ok  $script catches $# rule(s) in $(basename "$fixture")"
}

# Good fixture: must exit 0 with no warnings.
assert_good() {
  local script="$1"
  local fixture="$2"
  run_audit "$script" "$fixture"
  if [[ "$status" -ne 0 ]]; then
    fail "$script $fixture: expected clean exit 0, got $status: $output"
    return
  fi
  echo "ok  $script passes $(basename "$fixture")"
}

# Scope floor: --all must scan at least SCOPE_FLOOR Swift files.
assert_scope_floor() {
  local script="$1"
  run_audit "$script" --all --soft
  if [[ "$status" -ne 0 ]]; then
    fail "$script --all --soft: expected exit 0, got $status"
    return
  fi
  local count
  count="$(grep -oE '[0-9]+ file\(s\)' <<<"$output" | head -1 | grep -oE '^[0-9]+' || true)"
  if [[ -z "$count" ]]; then
    fail "$script --all --soft: could not parse scanned file count"
    return
  fi
  if [[ "$count" -lt "$SCOPE_FLOOR" ]]; then
    fail "$script --all: scanned only $count file(s), below floor $SCOPE_FLOOR — scan scope collapsed after a refactor?"
    return
  fi
  echo "ok  $script --all scans $count file(s) (floor $SCOPE_FLOOR)"
}

fixtures="scripts/tests/fixtures/Views"
agent_skill_fixtures="scripts/tests/fixtures/AgentSkills"

assert_bad scripts/audit-ui-v4.sh "$fixtures/UiV4Bad.swift" \
  background system-text-color hardcoded-white-black material shadow \
  hardcoded-motion plain-button regular-sheet \
  raw-textfield hardcoded-detent-height hardcoded-corner-radius
assert_good scripts/audit-ui-v4.sh "$fixtures/UiV4Good.swift"

assert_bad scripts/audit-accessibility.sh "$fixtures/A11yBad.swift" \
  icon-only-button image-needs-label-or-hidden small-hit-target \
  fixed-font-size color-only-meaning
assert_good scripts/audit-accessibility.sh "$fixtures/A11yGood.swift"

assert_bad scripts/audit-smoothness-risk.sh "$fixtures/SmoothnessBadSnapshotBuilder.swift" \
  broad-query-high-frequency sync-image-decode-in-view runtime-loop-in-view \
  main-actor-aggregation view-imperative-fetch detached-task-in-view
assert_good scripts/audit-smoothness-risk.sh "$fixtures/SmoothnessGood.swift"

assert_bad scripts/audit-runtime-guardrails.sh "$fixtures/RuntimeBad.swift" \
  location-manager background-location always-location-request idle-timer \
  raw-timer-publisher repeat-forever timeline-animation
assert_good scripts/audit-runtime-guardrails.sh "$fixtures/RuntimeGood.swift"

assert_bad scripts/audit-shared-care-note-metadata.sh "$fixtures/SharedCareNoteMetadataBad.swift" \
  shared-care-note-metadata
assert_good scripts/audit-shared-care-note-metadata.sh "$fixtures/SharedCareNoteMetadataGood.swift"

assert_bad scripts/audit-economy-boundaries.sh "$fixtures/RecurringEconomyBoundariesBad.swift" \
  coconut-balance-direct-write reward-actor-boundary reward-direct-awardaction \
  reward-direct-care-discipline reward-direct-care-discipline-disposition \
  care-fact-disposition-unconsumed pet-medication-dose-result-unconsumed \
  care-fact-executor-resolution-drops-fact care-command-result-unconsumed \
  care-derivation-direct-publish \
  pet-expense-ledger-boundary \
  care-secondary-executor-policy-unchecked \
  view-soft-gate-without-service-hard-gate
assert_good scripts/audit-economy-boundaries.sh "$fixtures/RecurringEconomyBoundariesGood.swift"

assert_bad scripts/audit-member-lifecycle-gate.sh "$fixtures/MemberLifecycleGateBadCommands.swift" \
  member-lifecycle-direct-write-gate member-lifecycle-missing-disposition \
  member-lifecycle-domain-ownership-matcher member-lifecycle-direct-schedule-writer \
  member-lifecycle-raw-effect-subject member-lifecycle-effect-dispatcher-bypass \
  member-lifecycle-schedule-delete-bypass member-lifecycle-feature-taxonomy-string \
  member-lifecycle-rehydrate-bypass member-lifecycle-rehydrate-disposition-unconsumed
run_audit scripts/audit-member-lifecycle-gate.sh --all "$fixtures/MemberLifecycleGateBadCommands.swift"
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-member-lifecycle-gate.sh --all MemberLifecycleGateBadCommands.swift: expected strict exit 1, got $status"
else
  for rule in member-lifecycle-direct-write-gate member-lifecycle-missing-disposition member-lifecycle-domain-ownership-matcher member-lifecycle-direct-schedule-writer member-lifecycle-raw-effect-subject member-lifecycle-effect-dispatcher-bypass member-lifecycle-schedule-delete-bypass member-lifecycle-feature-taxonomy-string member-lifecycle-rehydrate-bypass member-lifecycle-rehydrate-disposition-unconsumed; do
    if ! grep -qF "[$rule]" <<<"$output"; then
      fail "scripts/audit-member-lifecycle-gate.sh --all MemberLifecycleGateBadCommands.swift: rule [$rule] no longer fires"
    fi
  done
  echo "ok  scripts/audit-member-lifecycle-gate.sh --all catches member lifecycle fixture rules"
fi
assert_good scripts/audit-member-lifecycle-gate.sh "$fixtures/MemberLifecycleGateGoodCommands.swift"

assert_bad scripts/audit-agent-skill-governance.sh "$agent_skill_fixtures/SelfImprovingBad/SKILL.md" \
  skill-missing-required-output skill-missing-human-approval skill-missing-evidence \
  skill-auto-mutation skill-priority-over-governance
assert_good scripts/audit-agent-skill-governance.sh "$agent_skill_fixtures/SelfImprovingGood/SKILL.md"

assert_bad scripts/audit-derived-state-lifecycle.sh "$fixtures/DerivedStateLifecycleBad.swift" \
  derived-state-lifecycle-checklist physical-delete-without-tombstone \
  cloudsync-upload-builder-coverage physical-deletion-cascade-coverage
assert_good scripts/audit-derived-state-lifecycle.sh "$fixtures/DerivedStateLifecycleGood.swift"

assert_scope_floor scripts/audit-ui-v4.sh
assert_scope_floor scripts/audit-accessibility.sh
assert_scope_floor scripts/audit-smoothness-risk.sh
assert_scope_floor scripts/audit-runtime-guardrails.sh
assert_scope_floor scripts/audit-economy-boundaries.sh
assert_scope_floor scripts/audit-member-lifecycle-gate.sh
assert_scope_floor scripts/audit-derived-state-lifecycle.sh

echo
if [[ "$failures" -gt 0 ]]; then
  echo "Audit fixture tests: $failures failure(s)." >&2
  exit 1
fi
echo "Audit fixture tests: all passed."
