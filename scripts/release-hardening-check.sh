#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

STATIC_ONLY=0
RUN_UI=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/release-hardening-check.sh [--static-only|--skip-build] [--with-ui]

Purpose:
  Run the canonical local release-hardening lane. The default runs full static
  audits and the complete unit suite. --with-ui appends sequential UI shards.
  Signing, Archive validation, and physical-device acceptance remain separate.

Options:
  --static-only  Run only checks that do not require CoreSimulator.
  --skip-build   Deprecated compatibility alias for --static-only.
  --with-ui      After the unit suite, run the complete sequential UI shard lane.
  --ui-all-soft  Deprecated compatibility no-op; static UI audits remain strict.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --static-only|--skip-build)
      STATIC_ONLY=1
      shift
      ;;
    --with-ui)
      RUN_UI=1
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

if [[ "${STATIC_ONLY}" == "1" && "${RUN_UI}" == "1" ]]; then
  echo "--with-ui requires simulator validation; remove --static-only/--skip-build." >&2
  exit 2
fi

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

section "UI test shard completeness"
scripts/audit-ui-test-shards.sh

section "Runtime guardrails"
scripts/audit-runtime-guardrails.sh --all

section "Architecture boundaries"
scripts/audit-architecture-boundaries.sh --all

section "Production complexity ratchet"
scripts/tests/run-code-complexity-fixture-tests.sh
scripts/audit-code-complexity.sh --all

section "Economy boundaries"
scripts/audit-economy-boundaries.sh --all

section "Member lifecycle"
scripts/audit-member-lifecycle-gate.sh --all

section "Derived-state lifecycle"
scripts/audit-derived-state-lifecycle.sh --all

section "Shared-care note metadata"
scripts/audit-shared-care-note-metadata.sh --all

section "Release data safety"
scripts/audit-release-data-safety.sh

section "Localization coverage"
scripts/audit-localization-coverage.sh

section "Governance manifests"
scripts/audit-governance-manifests.sh

section "Agent skill governance"
scripts/audit-agent-skill-governance.sh

section "Resource integrity"
scripts/audit-resource-integrity.sh

section "UI/accessibility/smoothness/route strict audits"
scripts/audit-ui-v4.sh --all
scripts/audit-accessibility.sh --all
scripts/audit-smoothness-risk.sh --all
scripts/audit-route-first-frame.sh --all

section "Secret scan (working tree)"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --no-git --redact --no-banner --source . --config .gitleaks.toml
else
  echo "gitleaks not installed locally; CI runs it. Install with: brew install gitleaks"
fi

section "Git size"
scripts/audit-git-size.sh

if [[ "${STATIC_ONLY}" == "1" ]]; then
  section "Simulator validation"
  echo "Skipped by --static-only. Full unit and optional UI lanes were not run."
else
  section "Full unit suite (includes app compilation)"
  scripts/test-unit.sh

  section "Full sequential UI shards"
  if [[ "${RUN_UI}" == "1" ]]; then
    scripts/test-ui-nightly.sh
  else
    echo "Not selected. Use --with-ui for RC UI regression."
  fi
fi

section "Release hardening lane complete"
