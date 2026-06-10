#!/usr/bin/env bash
set -euo pipefail

# Verify installed tool versions against scripts/ci-tool-versions.env.
#
# Usage:
#   scripts/check-tool-versions.sh swiftlint swiftformat
#   scripts/check-tool-versions.sh rg gitleaks
#
# Each named tool must be installed and match its pin at the configured level.
# A mismatch is not an emergency — it means brew moved ahead (or lags) of the
# pin. Read the tool changelog, bump scripts/ci-tool-versions.env in its own
# commit, and rerun.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci-tool-versions.env
source "${repo_root}/scripts/ci-tool-versions.env"

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <tool> [tool...]   (tools: swiftlint swiftformat rg gitleaks)" >&2
  exit 2
fi

failures=0

installed_version() {
  local tool="$1"
  local raw=""
  case "$tool" in
    swiftlint) raw="$(swiftlint version 2>/dev/null || true)" ;;
    swiftformat) raw="$(swiftformat --version 2>/dev/null || true)" ;;
    rg) raw="$(rg --version 2>/dev/null | head -1 || true)" ;;
    gitleaks) raw="$(gitleaks version 2>/dev/null || true)" ;;
    *) echo "unknown tool: $tool" >&2; return 1 ;;
  esac
  printf '%s\n' "$raw" | grep -oE '[0-9]+(\.[0-9]+)*' | head -1
}

check_tool() {
  local tool="$1"
  local pinned match
  case "$tool" in
    swiftlint) pinned="$SWIFTLINT_PINNED"; match="$SWIFTLINT_MATCH" ;;
    swiftformat) pinned="$SWIFTFORMAT_PINNED"; match="$SWIFTFORMAT_MATCH" ;;
    rg) pinned="$RIPGREP_PINNED"; match="$RIPGREP_MATCH" ;;
    gitleaks) pinned="$GITLEAKS_PINNED"; match="$GITLEAKS_MATCH" ;;
    *) echo "unknown tool: $tool" >&2; failures=$((failures + 1)); return ;;
  esac

  local version
  version="$(installed_version "$tool")"
  if [[ -z "$version" ]]; then
    echo "FAIL: $tool is not installed (pinned ${pinned})." >&2
    failures=$((failures + 1))
    return
  fi

  local actual
  case "$match" in
    MAJOR) actual="${version%%.*}" ;;
    MAJOR_MINOR) actual="$(printf '%s' "$version" | cut -d. -f1-2)" ;;
    *) echo "FAIL: $tool has unknown match level ${match}." >&2; failures=$((failures + 1)); return ;;
  esac

  if [[ "$actual" != "$pinned" ]]; then
    echo "FAIL: $tool ${version} does not match pin ${pinned} (${match})." >&2
    echo "      Read the changelog, then bump scripts/ci-tool-versions.env deliberately." >&2
    failures=$((failures + 1))
    return
  fi
  echo "ok  $tool ${version} matches pin ${pinned} (${match})."
}

for tool in "$@"; do
  check_tool "$tool"
done

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
