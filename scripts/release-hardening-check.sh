#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/release-hardening-check.sh [--skip-build] [--ui-all-soft]

Purpose:
  Run the release-hardening baseline checks in the expected order.

Options:
  --skip-build   Run checks that do not require CoreSimulator.
  --ui-all-soft  Deprecated compatibility no-op; UI/accessibility/smoothness run as strict --all gates.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --ui-all-soft)
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
for script in scripts/*.sh scripts/tests/*.sh scripts/git-hooks/pre-commit; do
  bash -n "$script"
done

section "Diff whitespace"
git diff --check

section "Audit self-tests (fixtures + scope floor)"
scripts/tests/run-audit-fixture-tests.sh

section "Runtime guardrails"
scripts/audit-runtime-guardrails.sh --all

section "Architecture boundaries"
scripts/audit-architecture-boundaries.sh --all

section "Shared-care note metadata"
scripts/audit-shared-care-note-metadata.sh --all

section "Release data safety"
scripts/audit-release-data-safety.sh

section "Localization coverage"
scripts/audit-localization-coverage.sh

section "Governance manifests"
scripts/audit-governance-manifests.sh

section "Resource integrity"
scripts/audit-resource-integrity.sh

section "UI/accessibility/smoothness strict audits"
scripts/audit-ui-v4.sh --all
scripts/audit-accessibility.sh --all
scripts/audit-smoothness-risk.sh --all

section "Secret scan (working tree)"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --no-git --redact --no-banner --source . --config .gitleaks.toml
else
  echo "gitleaks not installed locally; CI runs it. Install with: brew install gitleaks"
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
