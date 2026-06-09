#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

SKIP_BUILD=0
SOFT_UI_ALL=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/release-hardening-check.sh [--skip-build] [--ui-all-soft]

Purpose:
  Run the release-hardening baseline checks in the expected order.

Options:
  --skip-build   Run checks that do not require CoreSimulator.
  --ui-all-soft  Deprecated compatibility option; full-scope ratchet now runs by default.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --ui-all-soft)
      SOFT_UI_ALL=1
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

section() {
  printf '\n== %s ==\n' "$1"
}

section "Working tree"
git status --short

section "Shell syntax"
bash -n scripts/build-debug-fast.sh
bash -n scripts/audit-runtime-guardrails.sh
bash -n scripts/audit-ui-v4.sh
bash -n scripts/audit-accessibility.sh
bash -n scripts/audit-localization-coverage.sh
bash -n scripts/audit-smoothness-risk.sh
bash -n scripts/audit-full-scope-ratchet.sh
bash -n scripts/audit-release-data-safety.sh
bash -n scripts/audit-governance-manifests.sh
bash -n scripts/audit-resource-integrity.sh
bash -n scripts/audit-git-size.sh
bash -n scripts/release-hardening-check.sh

section "Diff whitespace"
git diff --check

section "Runtime guardrails"
scripts/audit-runtime-guardrails.sh --all

section "Release data safety"
scripts/audit-release-data-safety.sh

section "Localization coverage"
scripts/audit-localization-coverage.sh

section "Governance manifests"
scripts/audit-governance-manifests.sh

section "Resource integrity"
scripts/audit-resource-integrity.sh

section "UI V4 changed files"
scripts/audit-ui-v4.sh --changed

section "Accessibility changed files"
scripts/audit-accessibility.sh --changed

section "Smoothness changed files"
scripts/audit-smoothness-risk.sh --changed

section "Full-scope UI/accessibility/smoothness ratchet"
scripts/audit-full-scope-ratchet.sh

if [[ "${SOFT_UI_ALL}" == "1" ]]; then
  section "UI V4 all files soft report"
  scripts/audit-ui-v4.sh --all --soft
fi

section "Git size"
scripts/audit-git-size.sh

if [[ "${SKIP_BUILD}" == "1" ]]; then
  section "Fixed simulator build"
  echo "Skipped by --skip-build. Run scripts/build-debug-fast.sh before release."
else
  section "Fixed simulator build"
  scripts/build-debug-fast.sh
fi

section "Release hardening baseline complete"
