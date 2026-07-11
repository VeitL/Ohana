#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev-check-changed.sh [--soft] [--dry-run] [--fix-format] [--build] [files...]

Purpose:
  Run the cheapest useful validation for the current change set. This script is
  a read-only local dispatcher by default: it lints touched Swift files, runs
  changed-file audits only where they apply, validates shell/json syntax, and
  reports when a full app build or test run should be used as an escalation.

Defaults:
  - Uses changed and untracked files when no file arguments are provided.
  - Never rewrites source unless --fix-format is explicitly passed.
  - Does not run xcodebuild. Pass --build only when a full build is intentional.
  - Runs audits in strict mode. Pass --soft to print audit warnings without
    failing the command.

Examples:
  scripts/dev-check-changed.sh
  scripts/dev-check-changed.sh --soft
  scripts/dev-check-changed.sh --fix-format Ohana/Features/Home/Views/MyView.swift
  scripts/dev-check-changed.sh Ohana/Features/Home/Views/MyView.swift
  scripts/dev-check-changed.sh --build
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

soft=0
dry_run=0
run_build=0
fix_format=0
targets=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --soft)
      soft=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --build)
      run_build=1
      shift
      ;;
    --fix-format)
      fix_format=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      targets+=("$1")
      shift
      ;;
  esac
done

if [[ "$fix_format" == "1" && ${#targets[@]} -eq 0 ]]; then
  echo "--fix-format requires explicit file or directory targets; refusing to rewrite the whole dirty tree." >&2
  exit 2
fi

run() {
  local label="$1"
  shift
  echo "dev-check: $label"
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
  if [[ "$dry_run" == "0" ]]; then
    "$@"
  fi
}

validate_json() {
  local file="$1"
  echo "dev-check: json syntax: $file"
  printf '+ %q %q %q %q\n' python3 -m json.tool "$file"
  if [[ "$dry_run" == "0" ]]; then
    python3 -m json.tool "$file" >/dev/null
  fi
}

collect_changed_files() {
  if [[ ${#targets[@]} -gt 0 ]]; then
    for target in "${targets[@]}"; do
      if [[ -d "$target" ]]; then
        find "$target" -type f
      elif [[ -f "$target" ]]; then
        printf '%s\n' "$target"
      fi
    done
    return
  fi

  {
    git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  }
}

files=()
while IFS= read -r file; do
  [[ -n "$file" && -f "$file" ]] && files+=("$file")
done < <(collect_changed_files | sort -u)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "dev-check: no changed files to validate."
  exit 0
fi

swift_files=()
app_swift_files=()
ui_swift_files=()
shell_files=()
json_files=()
status_doc_files=()
ui_test_shard_files=()
release_data_safety_reasons=()
agent_skill_governance_reasons=()
governance_manifest_reasons=()
build_reasons=()
test_reasons=()

for file in "${files[@]}"; do
  case "$file" in
    *.swift)
      swift_files+=("$file")
      [[ "$file" == Ohana/* ]] && app_swift_files+=("$file")
      case "$file" in
        Ohana/*/Views/*|Ohana/Features/*/Views/*|Ohana/Shared/Components/*|Ohana/Shared/Design/*|Ohana/Features/Settings/DesignLab/*)
          ui_swift_files+=("$file")
          ;;
      esac
      case "$file" in
        Ohana/Models/*|Ohana/App/*|Ohana/Domain/*|Ohana/Shared/Components/*|Ohana/Shared/Design/*|*Service.swift|*Manager.swift|*Command*.swift|*Executor*.swift|*Route*.swift)
          build_reasons+=("$file")
          ;;
      esac
      case "$file" in
        Ohana/Models/*|*Service.swift|*Command*.swift|*Executor*.swift|OhanaTests/*|OhanaUITests/*)
          test_reasons+=("$file")
          ;;
      esac
      ;;
    *.sh)
      shell_files+=("$file")
      ;;
    *.json)
      json_files+=("$file")
      ;;
    *.md)
      case "$file" in
        docs/task-follow-ups.md|docs/testing-progress.md|docs/cloud-sync-todo.md|docs/status-ledger-map.md)
          status_doc_files+=("$file")
          ;;
      esac
      ;;
  esac

  case "$file" in
    Ohana/Models/*|Ohana/Domain/Services/*|Ohana/App/AppResetService.swift|Ohana/App/AppRuntimeAdapters.swift|Ohana/App/AppServices.swift|Ohana/App/StartupMaintenanceCoordinator.swift|Ohana/Shared/Media/*|Ohana/Shared/Utilities/LocalBackupExclusionPolicy.swift|Ohana/Features/HumanNotes/*|Ohana/Features/Members/MemberDeletionCommands.swift|Ohana/Features/Settings/Views/SettingsView+Backup.swift|Ohana/Features/Settings/Views/SettingsView+Chrome.swift|Ohana/Features/Documents/*|Ohana/Features/Expenses/ExpenseReceiptSupport.swift|OhanaTests/*Backup*.swift|OhanaTests/*Restore*.swift|OhanaTests/*Deletion*.swift|OhanaTests/*Privacy*.swift|OhanaTests/*Migration*.swift|OhanaTests/*Recovery*.swift|OhanaTests/*Attachment*.swift|OhanaTests/AppResetServiceTests.swift|OhanaTests/AutomaticBackupServiceTests.swift|OhanaTests/LocalBackupExclusionPolicyTests.swift|OhanaTests/SharedModelContainerRecoveryTests.swift|Ohana/*.lproj/Localizable.strings|docs/governance/manifests/swiftdata-save-failure-baseline.json|scripts/audit-release-data-safety.sh|scripts/audit-swiftdata-save-failures.sh)
      release_data_safety_reasons+=("$file")
      ;;
  esac

  case "$file" in
    AGENTS.md|.codex/skills/*|scripts/audit-agent-skill-governance.sh)
      agent_skill_governance_reasons+=("$file")
      ;;
  esac

  case "$file" in
    AGENTS.md|docs/README.md|docs/status-ledger-map.md|docs/*-governance.md|docs/*-policy.md|docs/release-quality-gates.md|docs/governance/manifests/*.json|ui规范.selection.json|Ohana.xcodeproj/project.pbxproj|scripts/audit-governance-manifests.sh)
      governance_manifest_reasons+=("$file")
      ;;
  esac

  if [[ "$file" == "scripts/audit-doc-status-ledgers.sh" ]]; then
    status_doc_files+=("$file")
  fi

  case "$file" in
    OhanaUITests/*.swift|scripts/ui-test-shards.tsv|scripts/audit-ui-test-shards.sh|scripts/test-ui-shard.sh|scripts/test-ui-nightly.sh)
      ui_test_shard_files+=("$file")
      ;;
  esac
done

echo "dev-check: validating ${#files[@]} changed file(s)."
if [[ "$dry_run" == "1" ]]; then
  echo "dev-check: dry run; commands will be printed but not executed."
fi

run "diff whitespace for tracked targets" git diff --check -- "${files[@]}"

if [[ ${#shell_files[@]} -gt 0 ]]; then
  for file in "${shell_files[@]}"; do
    run "bash -n $file" bash -n "$file"
  done
fi

if [[ ${#json_files[@]} -gt 0 ]]; then
  for file in "${json_files[@]}"; do
    validate_json "$file"
  done
fi

if [[ ${#status_doc_files[@]} -gt 0 ]]; then
  run "status ledger audit" scripts/audit-doc-status-ledgers.sh
fi

if [[ ${#ui_test_shard_files[@]} -gt 0 ]]; then
  run "UI test shard completeness" scripts/audit-ui-test-shards.sh
fi

if [[ ${#swift_files[@]} -gt 0 ]]; then
  if command -v swiftformat >/dev/null 2>&1; then
    if [[ "$fix_format" == "1" ]]; then
      run "swiftformat fix for explicitly selected Swift files" swiftformat "${swift_files[@]}"
    else
      run "swiftformat lint for touched Swift files" swiftformat --lint "${swift_files[@]}"
    fi
  else
    echo "dev-check: swiftformat not found; skipping format lint."
  fi
fi

if [[ ${#agent_skill_governance_reasons[@]} -gt 0 ]]; then
  run "agent skill governance" scripts/audit-agent-skill-governance.sh
fi

if [[ ${#governance_manifest_reasons[@]} -gt 0 ]]; then
  run "governance manifests" scripts/audit-governance-manifests.sh
fi

audit_mode=()
if [[ "$soft" == "1" ]]; then
  audit_mode+=(--soft)
fi

if [[ ${#ui_swift_files[@]} -gt 0 ]]; then
  run "UI V4 audit for touched UI Swift" scripts/audit-ui-v4.sh ${audit_mode[@]+"${audit_mode[@]}"} "${ui_swift_files[@]}"
  run "Accessibility audit for touched UI Swift" scripts/audit-accessibility.sh ${audit_mode[@]+"${audit_mode[@]}"} "${ui_swift_files[@]}"
fi

if [[ ${#app_swift_files[@]} -gt 0 ]]; then
  if command -v swiftlint >/dev/null 2>&1; then
    run "Production complexity ratchet for changed app Swift" scripts/audit-code-complexity.sh --changed
  else
    echo "dev-check: swiftlint not found; CI will run the production complexity ratchet."
  fi
  run "Localization hardcoded UI audit for touched app Swift" scripts/audit-localization-coverage.sh --changed "${app_swift_files[@]}"
  run "Smoothness audit for touched app Swift" scripts/audit-smoothness-risk.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Route first-frame audit for touched app Swift" scripts/audit-route-first-frame.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Runtime guardrails for touched app Swift" scripts/audit-runtime-guardrails.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Shared-care note metadata audit for touched app Swift" scripts/audit-shared-care-note-metadata.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Economy boundaries audit for touched app Swift" scripts/audit-economy-boundaries.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Member lifecycle gate audit for touched app Swift" scripts/audit-member-lifecycle-gate.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Derived-state lifecycle audit for touched app Swift" scripts/audit-derived-state-lifecycle.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
fi
if [[ ${#release_data_safety_reasons[@]} -gt 0 ]]; then
  run "Release data safety contract audit for affected persistence/privacy files" scripts/audit-release-data-safety.sh
elif [[ ${#app_swift_files[@]} -gt 0 ]]; then
  run "SwiftData save-failure audit for touched app Swift" \
    scripts/audit-swiftdata-save-failures.sh --changed "${app_swift_files[@]}"
fi

if [[ ${#build_reasons[@]} -gt 0 ]]; then
  echo "dev-check: build recommended before final handoff because compiler-surface files changed:"
  printf '  - %s\n' "${build_reasons[@]}" | sort -u
else
  echo "dev-check: no app build recommended by changed-file classification."
fi

if [[ ${#test_reasons[@]} -gt 0 ]]; then
  echo "dev-check: targeted tests recommended if behavior changed in:"
  printf '  - %s\n' "${test_reasons[@]}" | sort -u
fi

if [[ "$run_build" == "1" ]]; then
  run "scripts/build-debug-fast.sh" scripts/build-debug-fast.sh
else
  echo "dev-check: skipped xcodebuild. Pass --build for an intentional full app build."
fi
