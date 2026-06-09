#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required." >&2
  exit 2
fi

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-smoothness-risk.sh [--changed|--all|--soft] [Swift files or directories...]

Purpose:
  Catch common mature-app smoothness risks in high-frequency SwiftUI surfaces:
  broad @Query usage, synchronous image/file decoding in views, and runtime loops.

Allowlist:
  Add "smoothness: allow <reason>" on the line for deliberate exceptions.
USAGE
}

mode="changed"
strict=1
targets=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed)
      mode="changed"
      shift
      ;;
    --all)
      mode="all"
      shift
      ;;
    --soft)
      strict=0
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

collect_files() {
  if [[ ${#targets[@]} -gt 0 ]]; then
    for target in "${targets[@]}"; do
      if [[ -d "$target" ]]; then
        find "$target" -type f -name '*.swift'
      elif [[ -f "$target" && "$target" == *.swift ]]; then
        printf '%s\n' "$target"
      fi
    done
    return
  fi

  if [[ "$mode" == "all" ]]; then
    find Ohana/Views Ohana/Utilities -type f -name '*.swift'
    return
  fi

  {
    git diff --name-only --diff-filter=ACMR HEAD -- Ohana/Views Ohana/Utilities 2>/dev/null || true
    git ls-files --others --exclude-standard -- Ohana/Views Ohana/Utilities 2>/dev/null || true
  } | awk '/\.swift$/ { print }'
}

files=()
while IFS= read -r file; do
  [[ -n "$file" ]] && files+=("$file")
done < <(collect_files | sort -u)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Smoothness risk audit: no Swift files to scan."
  exit 0
fi

warnings_file="$(mktemp)"
trap 'rm -f "$warnings_file"' EXIT

scan() {
  local id="$1"
  local pattern="$2"
  local message="$3"
  local scope_regex="$4"

  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    if [[ -n "$scope_regex" ]] && ! [[ "$file" =~ $scope_regex ]]; then
      continue
    fi
    rg --pcre2 -n --with-filename --no-heading "$pattern" "$file" 2>/dev/null | while IFS= read -r match; do
      case "$match" in
        *"smoothness: allow"*) continue ;;
      esac
      printf '[%s] %s\n  %s\n\n' "$id" "$match" "$message" >> "$warnings_file"
    done || true
  done
}

scan \
  "broad-query-high-frequency" \
  '@Query' \
  "High-frequency and reusable SwiftUI surfaces should receive value snapshots from containers/read models instead of owning broad live queries." \
  '^Ohana/Views/(Home|Components)/'

scan \
  "sync-image-decode-in-view" \
  'Data\(contentsOf:|UIImage\(data:|UIImage\(contentsOfFile:' \
  "Image/file decoding in a view path can steal the finger-first frame; prefer prepared assets, snapshot caches, or route-scoped async decode." \
  '^Ohana/Views/'

scan \
  "runtime-loop-in-view" \
  'Timer\.publish\s*\(|TimelineView\s*\(\s*\.animation|repeatForever\s*\(' \
  "Timers, TimelineView(.animation), and repeatForever loops must be visible, policy-gated, and paused when hidden or reduced-work." \
  '^Ohana/Views/'

if [[ ! -s "$warnings_file" ]]; then
  echo "Smoothness risk audit: passed (${#files[@]} file(s))."
  exit 0
fi

echo "Smoothness risk audit: review warnings in ${#files[@]} file(s)."
echo
cat "$warnings_file"
echo "Add // smoothness: allow <reason> only for deliberate, measured exceptions."
if [[ "$strict" -eq 1 ]]; then
  exit 1
fi
