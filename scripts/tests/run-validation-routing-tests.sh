#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

ui_fixture_root="$(mktemp -d "Ohana/Features/__ValidationRoutingFixture.XXXXXX")"
model_fixture_root="$(mktemp -d "Ohana/Models/__ValidationRoutingFixture.XXXXXX")"
ui_fixture="$ui_fixture_root/Views/ValidationRoutingView.swift"
model_fixture="$model_fixture_root/ValidationRoutingModel.swift"

cleanup() {
  rm -rf -- "$ui_fixture_root" "$model_fixture_root"
}
trap cleanup EXIT

mkdir -p "$(dirname "$ui_fixture")"
printf 'import SwiftUI\nstruct ValidationRoutingView: View { var body: some View { Text("fixture") } }\n' > "$ui_fixture"
printf 'import Foundation\nstruct ValidationRoutingModel {}\n' > "$model_fixture"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

default_output="$(scripts/dev-check-changed.sh --dry-run "$ui_fixture")"
grep -qF "+ swiftformat --lint $ui_fixture" <<<"$default_output" || \
  fail "dev-check default lane must lint formatting without rewriting source"
if grep -qF "Release data safety contract audit" <<<"$default_output"; then
  fail "ordinary UI files must not trigger the whole release-data contract audit"
fi
grep -qF "scripts/audit-swiftdata-save-failures.sh --changed $ui_fixture" <<<"$default_output" || \
  fail "ordinary app Swift must keep the incremental save-failure guard"

fix_output="$(scripts/dev-check-changed.sh --dry-run --fix-format "$ui_fixture")"
grep -qF "+ swiftformat $ui_fixture" <<<"$fix_output" || \
  fail "--fix-format must explicitly select mutating SwiftFormat"
if grep -qF "+ swiftformat --lint" <<<"$fix_output"; then
  fail "--fix-format must not remain in lint-only mode"
fi

set +e
unscoped_fix_output="$(scripts/dev-check-changed.sh --dry-run --fix-format 2>&1)"
unscoped_fix_status=$?
set -e
[[ "$unscoped_fix_status" -eq 2 ]] || \
  fail "--fix-format without explicit targets must fail before touching a dirty tree"
grep -qF "requires explicit file or directory targets" <<<"$unscoped_fix_output" || \
  fail "unscoped --fix-format failure must explain the safety boundary"

model_output="$(scripts/dev-check-changed.sh --dry-run "$model_fixture")"
grep -qF "Release data safety contract audit for affected persistence/privacy files" <<<"$model_output" || \
  fail "model changes must escalate to the whole release-data contract audit"
if grep -qF "SwiftData save-failure audit for touched app Swift" <<<"$model_output"; then
  fail "model changes must not run both incremental and full data-safety lanes"
fi

system_surface_output="$(
  scripts/dev-check-changed.sh --dry-run Ohana/SystemSurfaces/SystemSurfaceSnapshotCoordinator.swift
)"
grep -qF "Release data safety contract audit for affected persistence/privacy files" \
  <<<"$system_surface_output" || \
  fail "system-surface snapshot changes must escalate to the whole release-data contract audit"
if grep -qF "SwiftData save-failure audit for touched app Swift" <<<"$system_surface_output"; then
  fail "system-surface snapshot changes must not run both incremental and full data-safety lanes"
fi
grep -qF "build recommended before final handoff" <<<"$system_surface_output" || \
  fail "system-surface source changes must recommend an app build"
grep -qF "targeted tests recommended" <<<"$system_surface_output" || \
  fail "system-surface coordinator changes must recommend targeted tests"

widget_output="$(
  scripts/dev-check-changed.sh --dry-run OhanaWidgets/TodayCareWidget.swift
)"
grep -qF "Release data safety contract audit for affected persistence/privacy files" \
  <<<"$widget_output" || \
  fail "Widget extension source changes must escalate to the data-safety contract audit"
if grep -qF "SwiftData save-failure audit for touched app Swift" <<<"$widget_output"; then
  fail "Widget extension changes must not run both incremental and full data-safety lanes"
fi
grep -qF "build recommended before final handoff" <<<"$widget_output" || \
  fail "Widget extension source changes must recommend an app build"
grep -qF "targeted tests recommended" <<<"$widget_output" || \
  fail "Widget extension source changes must recommend targeted tests"

system_surface_audit_output="$(
  scripts/dev-check-changed.sh --dry-run scripts/audit-system-surface-contract.sh
)"
grep -qF "Release data safety contract audit for affected persistence/privacy files" \
  <<<"$system_surface_audit_output" || \
  fail "system-surface audit changes must rerun the release data-safety contract"

system_surface_fence_audit_output="$(
  scripts/dev-check-changed.sh --dry-run scripts/audit-system-surface-reset-fence.sh
)"
grep -qF "Release data safety contract audit for affected persistence/privacy files" \
  <<<"$system_surface_fence_audit_output" || \
  fail "system-surface Reset fence audit changes must rerun the release data-safety contract"

if rg -q 'scripts/audit-[a-z0-9-]+\.sh' scripts/module-exit-gate.sh; then
  fail "module-exit-gate must delegate static checks instead of re-running audits"
fi

release_ci_audits=(
  audit-ui-test-shards.sh
  audit-runtime-guardrails.sh
  audit-architecture-boundaries.sh
  audit-economy-boundaries.sh
  audit-member-lifecycle-gate.sh
  audit-derived-state-lifecycle.sh
  audit-shared-care-note-metadata.sh
  audit-release-data-safety.sh
  audit-localization-coverage.sh
  audit-governance-manifests.sh
  audit-agent-skill-governance.sh
  audit-resource-integrity.sh
  audit-ui-v4.sh
  audit-accessibility.sh
  audit-smoothness-risk.sh
  audit-route-first-frame.sh
  audit-git-size.sh
)

for audit in "${release_ci_audits[@]}"; do
  grep -qF "$audit" scripts/release-hardening-check.sh || \
    fail "release-hardening is missing $audit"
  grep -qF "$audit" .github/workflows/ci.yml || \
    fail "CI is missing $audit"
done

echo "Validation routing tests passed."
