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
architecture_fixture_path="Ohana/Domain/__ArchitectureBoundaryFixture.swift"
architecture_model_fixture_path="Ohana/Models/__ArchitectureModelBoundaryFixture.swift"
member_view_revision_fixture_path="Ohana/Features/Members/Views/__MemberProfileRevisionBoundaryFixture.swift"
save_failure_fixture_path="Ohana/Features/Settings/__SaveFailureBoundaryFixture.swift"
governance_manifest_path="docs/governance/manifests/feature-ownership.json"
governance_manifest_backup="$(mktemp "${TMPDIR:-/tmp}/ohana-feature-ownership.XXXXXX")"
cp "$governance_manifest_path" "$governance_manifest_backup"

cleanup_architecture_fixture() {
  rm -f "$architecture_fixture_path"
  rm -f "$architecture_model_fixture_path"
  rm -f "$member_view_revision_fixture_path"
}

cleanup_governance_fixture() {
  rm -f CONTEXT.md UIRules.md RULES.md INSTRUCTIONS.md CLAUDE.md GEMINI.md .cursorrules
  rm -f "$save_failure_fixture_path"
  if [[ -f "$governance_manifest_backup" ]]; then
    cp "$governance_manifest_backup" "$governance_manifest_path"
    rm -f "$governance_manifest_backup"
  fi
}

trap 'cleanup_architecture_fixture; cleanup_governance_fixture' EXIT

assert_bad scripts/audit-ui-v4.sh "$fixtures/UiV4Bad.swift" \
  background system-text-color hardcoded-white-black material shadow \
  direct-go-lime hardcoded-motion plain-button regular-sheet \
  raw-textfield hardcoded-detent-height hardcoded-corner-radius
assert_good scripts/audit-ui-v4.sh "$fixtures/UiV4Good.swift"

assert_bad scripts/audit-accessibility.sh "$fixtures/A11yBad.swift" \
  icon-only-button image-needs-label-or-hidden small-hit-target \
  fixed-font-size color-only-meaning
assert_good scripts/audit-accessibility.sh "$fixtures/A11yGood.swift"

assert_bad scripts/audit-smoothness-risk.sh "$fixtures/SmoothnessBadSnapshotBuilder.swift" \
  broad-query-high-frequency sync-image-decode-in-view direct-attachment-image-decode-in-view \
  render-external-storage-signature render-external-storage-signature-map \
  render-live-avatar-data-parameter avatar-pipeline-direct-human-blob-read \
  feature-hub-live-avatar-provider pet-avatar-portrait-direct-blob-read \
  weekly-photo-memory-eager-blob milestone-photo-eager-blob \
  pet-photo-log-eager-blob plant-care-log-eager-blob \
  render-avatar-transparency-probe \
  render-photo-data-presence-probe render-image-data-presence-probe render-document-attachment-data-probe \
  eager-sharelink-export \
  runtime-loop-in-view main-actor-aggregation view-imperative-fetch detached-task-in-view
assert_good scripts/audit-smoothness-risk.sh "$fixtures/SmoothnessGood.swift"

assert_bad scripts/audit-route-first-frame.sh "$fixtures/RouteFirstFrameBadRouteContainer.swift" \
  route-first-frame-query route-first-frame-sync-fetch route-first-frame-service-fetch \
  route-first-frame-modelactor-live-model-return
assert_good scripts/audit-route-first-frame.sh "$fixtures/RouteFirstFrameGoodRouteContainer.swift"

assert_bad scripts/audit-localization-coverage.sh "$fixtures/LocalizationHardcodedChineseBad.swift" \
  localization-hardcoded-ui-chinese
assert_good scripts/audit-localization-coverage.sh "$fixtures/LocalizationHardcodedChineseGood.swift"

assert_bad scripts/audit-runtime-guardrails.sh "$fixtures/RuntimeBad.swift" \
  location-manager background-location always-location-request idle-timer \
  raw-timer-publisher repeat-forever timeline-animation
assert_good scripts/audit-runtime-guardrails.sh "$fixtures/RuntimeGood.swift"

cp "$fixtures/ArchitectureBoundariesBad.swift" "$architecture_fixture_path"
run_audit scripts/audit-architecture-boundaries.sh --changed
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-architecture-boundaries.sh ArchitectureBoundariesBad.swift: expected strict exit 1, got $status"
else
  for rule in domain-feature-command-dependency domain-feature-reward-type-dependency domain-feature-implementation-dependency domain-feature-live-default-dependency domain-feature-taxonomy-literal domain-presentation-framework-dependency domain-platform-ui-framework-dependency; do
    if ! grep -qF "[$rule]" <<<"$output"; then
      fail "scripts/audit-architecture-boundaries.sh ArchitectureBoundariesBad.swift: rule [$rule] no longer fires"
    fi
  done
  echo "ok  scripts/audit-architecture-boundaries.sh catches Domain dependency rules"
fi
cp "$fixtures/ArchitectureBoundariesGood.swift" "$architecture_fixture_path"
run_audit scripts/audit-architecture-boundaries.sh --changed
if [[ "$status" -ne 0 ]]; then
  fail "scripts/audit-architecture-boundaries.sh ArchitectureBoundariesGood.swift: expected clean exit 0, got $status: $output"
else
  echo "ok  scripts/audit-architecture-boundaries.sh passes ArchitectureBoundariesGood.swift"
fi
cleanup_architecture_fixture

cp "$fixtures/ArchitectureModelBoundariesBad.swift" "$architecture_model_fixture_path"
run_audit scripts/audit-architecture-boundaries.sh --changed
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-architecture-boundaries.sh ArchitectureModelBoundariesBad.swift: expected strict exit 1, got $status"
else
  for rule in models-presentation-framework-dependency models-non-schema-source models-persistence-side-effect models-behavior-type models-writer-context-dependency; do
    if ! grep -qF "[$rule]" <<<"$output"; then
      fail "scripts/audit-architecture-boundaries.sh ArchitectureModelBoundariesBad.swift: rule [$rule] no longer fires"
    fi
  done
  echo "ok  scripts/audit-architecture-boundaries.sh catches Models boundary rules"
fi
cp "$fixtures/ArchitectureModelBoundariesGood.swift" "$architecture_model_fixture_path"
run_audit scripts/audit-architecture-boundaries.sh --changed
if [[ "$status" -ne 0 ]]; then
  fail "scripts/audit-architecture-boundaries.sh ArchitectureModelBoundariesGood.swift: expected clean exit 0, got $status: $output"
else
  echo "ok  scripts/audit-architecture-boundaries.sh passes ArchitectureModelBoundariesGood.swift"
fi
cleanup_architecture_fixture

cp "$fixtures/MemberProfileRevisionBoundaryBad.swift" "$member_view_revision_fixture_path"
run_audit scripts/audit-architecture-boundaries.sh --changed
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-architecture-boundaries.sh MemberProfileRevisionBoundaryBad.swift: expected strict exit 1, got $status"
elif ! grep -qF "[member-view-direct-profile-revision]" <<<"$output"; then
  fail "scripts/audit-architecture-boundaries.sh MemberProfileRevisionBoundaryBad.swift: rule [member-view-direct-profile-revision] no longer fires"
else
  echo "ok  scripts/audit-architecture-boundaries.sh catches direct Members view profile revision publishes"
fi
cp "$fixtures/MemberProfileRevisionBoundaryGood.swift" "$member_view_revision_fixture_path"
run_audit scripts/audit-architecture-boundaries.sh --changed
if [[ "$status" -ne 0 ]]; then
  fail "scripts/audit-architecture-boundaries.sh MemberProfileRevisionBoundaryGood.swift: expected clean exit 0, got $status: $output"
else
  echo "ok  scripts/audit-architecture-boundaries.sh passes MemberProfileRevisionBoundaryGood.swift"
fi
cleanup_architecture_fixture

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
  member-lifecycle-writer-token-bypass \
  member-lifecycle-schedule-delete-bypass member-lifecycle-feature-taxonomy-string \
  member-lifecycle-rehydrate-bypass member-lifecycle-rehydrate-disposition-unconsumed
run_audit scripts/audit-member-lifecycle-gate.sh --all "$fixtures/MemberLifecycleGateBadCommands.swift"
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-member-lifecycle-gate.sh --all MemberLifecycleGateBadCommands.swift: expected strict exit 1, got $status"
else
  for rule in member-lifecycle-direct-write-gate member-lifecycle-missing-disposition member-lifecycle-domain-ownership-matcher member-lifecycle-direct-schedule-writer member-lifecycle-raw-effect-subject member-lifecycle-effect-dispatcher-bypass member-lifecycle-writer-token-bypass member-lifecycle-schedule-delete-bypass member-lifecycle-feature-taxonomy-string member-lifecycle-rehydrate-bypass member-lifecycle-rehydrate-disposition-unconsumed; do
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
assert_bad scripts/audit-agent-skill-governance.sh "$agent_skill_fixtures/GenericGovernanceBad/SKILL.md" \
  skill-source-of-truth-claim skill-repo-relative-command
assert_good scripts/audit-agent-skill-governance.sh "$agent_skill_fixtures/GenericGovernanceGood/SKILL.md"

run_audit scripts/audit-governance-manifests.sh
if [[ "$status" -ne 0 ]]; then
  fail "scripts/audit-governance-manifests.sh: expected current manifests to pass, got $status: $output"
else
  echo "ok  scripts/audit-governance-manifests.sh passes current manifests"
fi

cp "$fixtures/SaveFailureBoundaryBad.swift" "$save_failure_fixture_path"
run_audit scripts/audit-release-data-safety.sh
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-release-data-safety.sh SaveFailureBoundaryBad.swift: expected strict exit 1, got $status"
elif ! grep -qF "[swiftdata-silent-safe-save]" <<<"$output"; then
  fail "scripts/audit-release-data-safety.sh SaveFailureBoundaryBad.swift: rule [swiftdata-silent-safe-save] no longer fires"
else
  echo "ok  scripts/audit-release-data-safety.sh catches new bare safeSave"
fi
rm -f "$save_failure_fixture_path"
run_audit scripts/audit-release-data-safety.sh
if [[ "$status" -ne 0 ]]; then
  fail "scripts/audit-release-data-safety.sh: expected current data safety audit to pass, got $status: $output"
else
  echo "ok  scripts/audit-release-data-safety.sh passes current tree"
fi

: > CONTEXT.md
run_audit scripts/audit-governance-manifests.sh
rm -f CONTEXT.md
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-governance-manifests.sh CONTEXT.md fixture: expected strict exit 1, got $status"
elif ! grep -qF "AGENTS.md is the only root agent/navigation rule file" <<<"$output"; then
  fail "scripts/audit-governance-manifests.sh CONTEXT.md fixture: stale root rule file guard no longer fires"
else
  echo "ok  scripts/audit-governance-manifests.sh catches stale root rule files"
fi

python3 - <<'PY'
import json
from pathlib import Path

path = Path("docs/governance/manifests/feature-ownership.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["features"][0]["services"].append("GhostEconomyService")
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
run_audit scripts/audit-governance-manifests.sh
cp "$governance_manifest_backup" "$governance_manifest_path"
if [[ "$status" -ne 1 ]]; then
  fail "scripts/audit-governance-manifests.sh ghost service fixture: expected strict exit 1, got $status"
elif ! grep -qF "unknown Swift symbol 'GhostEconomyService'" <<<"$output"; then
  fail "scripts/audit-governance-manifests.sh ghost service fixture: unknown-symbol guard no longer fires"
else
  echo "ok  scripts/audit-governance-manifests.sh catches manifest service ghost symbols"
fi

assert_bad scripts/audit-derived-state-lifecycle.sh "$fixtures/DerivedStateLifecycleBad.swift" \
  derived-state-lifecycle-checklist physical-delete-without-tombstone \
  cloudsync-upload-builder-coverage physical-deletion-cascade-coverage
assert_good scripts/audit-derived-state-lifecycle.sh "$fixtures/DerivedStateLifecycleGood.swift"

assert_scope_floor scripts/audit-ui-v4.sh
assert_scope_floor scripts/audit-accessibility.sh
assert_scope_floor scripts/audit-smoothness-risk.sh
assert_scope_floor scripts/audit-route-first-frame.sh
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
