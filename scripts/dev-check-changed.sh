#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev-check-changed.sh [--soft] [--dry-run] [--build] [files...]

Purpose:
  Run the cheapest useful validation for the current change set. This script is
  a fast local dispatcher: it formats touched Swift files, runs changed-file
  audits only where they apply, validates shell/json syntax, and reports when a
  full app build or test run should be used as an escalation.

Defaults:
  - Uses changed and untracked files when no file arguments are provided.
  - Does not run xcodebuild. Pass --build only when a full build is intentional.
  - Runs audits in strict mode. Pass --soft to print audit warnings without
    failing the command.

Examples:
  scripts/dev-check-changed.sh
  scripts/dev-check-changed.sh --soft
  scripts/dev-check-changed.sh Ohana/Features/Home/Views/MyView.swift
  scripts/dev-check-changed.sh --build
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

soft=0
dry_run=0
run_build=0
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
  esac
done

echo "dev-check: validating ${#files[@]} changed file(s)."
if [[ "$dry_run" == "1" ]]; then
  echo "dev-check: dry run; commands will be printed but not executed."
fi

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

if [[ ${#swift_files[@]} -gt 0 ]]; then
  if command -v swiftformat >/dev/null 2>&1; then
    run "swiftformat touched Swift files" swiftformat "${swift_files[@]}"
  else
    echo "dev-check: swiftformat not found; skipping formatting."
  fi
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
  run "Smoothness audit for touched app Swift" scripts/audit-smoothness-risk.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Route first-frame audit for touched app Swift" scripts/audit-route-first-frame.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Runtime guardrails for touched app Swift" scripts/audit-runtime-guardrails.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Shared-care note metadata audit for touched app Swift" scripts/audit-shared-care-note-metadata.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Economy boundaries audit for touched app Swift" scripts/audit-economy-boundaries.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Member lifecycle gate audit for touched app Swift" scripts/audit-member-lifecycle-gate.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
  run "Derived-state lifecycle audit for touched app Swift" scripts/audit-derived-state-lifecycle.sh ${audit_mode[@]+"${audit_mode[@]}"} "${app_swift_files[@]}"
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
