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
  broad @Query usage, synchronous image/file decoding in views, runtime loops,
  main-actor read-model aggregation, imperative SwiftData fetches in views,
  and unscoped detached tasks.

Scope note:
  The scan root is the whole Ohana/ tree. Never narrow this back to a
  subdirectory list: directory refactors silently removed 88% of files from
  this audit once before. The fixture tests in scripts/tests/ enforce a
  minimum scanned-file floor.

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
    find Ohana -type f -name '*.swift'
    return
  fi

  {
    git diff --name-only --diff-filter=ACMR HEAD -- Ohana 2>/dev/null || true
    git ls-files --others --exclude-standard -- Ohana 2>/dev/null || true
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

# Scope filtering happens in-process (cheap), then ONE rg invocation per rule
# across the scoped files (see audit-ui-v4.sh for why the per-file loop must
# never come back). Output format is load-bearing.
scan() {
  local id="$1"
  local pattern="$2"
  local message="$3"
  local scope_regex="$4"
  local exclude_regex="${5:-}"

  local scoped=()
  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    if [[ -n "$scope_regex" ]] && ! [[ "$file" =~ $scope_regex ]]; then
      continue
    fi
    if [[ -n "$exclude_regex" ]] && [[ "$file" =~ $exclude_regex ]]; then
      continue
    fi
    scoped+=("$file")
  done
  [[ ${#scoped[@]} -eq 0 ]] && return 0

  rg --pcre2 -nH --no-heading "$pattern" "${scoped[@]}" 2>/dev/null \
    | while IFS= read -r match; do
        case "$match" in
          *"smoothness: allow"*) continue ;;
        esac
        printf '[%s] %s\n  %s\n\n' "$id" "$match" "$message" >> "$warnings_file"
      done || true
}

scan \
  "broad-query-high-frequency" \
  '@Query' \
  "High-frequency and reusable SwiftUI surfaces should receive value snapshots from containers/read models instead of owning broad live queries." \
  '(^|/)Views/|^Ohana/Shared/' \
  '(Data|Route)Container\.swift$|^Ohana/App/RouteContainers/'

scan \
  "sync-image-decode-in-view" \
  'Data\(contentsOf:|UIImage\(data:|UIImage\(contentsOfFile:' \
  "Image/file decoding in a view path can steal the finger-first frame; prefer prepared assets, snapshot caches, or route-scoped async decode." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "runtime-loop-in-view" \
  'Timer\.publish\s*\(|TimelineView\s*\(\s*\.animation|repeatForever\s*\(' \
  "Timers, TimelineView(.animation), and repeatForever loops must be visible, policy-gated, and paused when hidden or reduced-work." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "main-actor-aggregation" \
  'Task\s*\{\s*@MainActor' \
  "Read-model/snapshot refresh must aggregate off the main actor (@ModelActor or background context) and deliver small Equatable snapshots back to the MainActor; deferred work that still runs on main steals scroll frames as data grows." \
  '(ReadModel|SnapshotStore|SnapshotBuilder)[^/]*\.swift$'

scan \
  "view-imperative-fetch" \
  'modelContext\.fetch\(|\.fetch\(FetchDescriptor' \
  "Views must not run imperative SwiftData fetches; containers/read models own data access and pass value snapshots down." \
  '(^|/)Views/' \
  '(Data|Route)Container\.swift$|^Ohana/App/RouteContainers/'

scan \
  "detached-task-in-view" \
  'Task\.detached' \
  "Detached tasks in views escape route-scoped cancellation; use .task(id:), route-scoped tasks, or a service entry point so work cancels when the page disappears." \
  '(^|/)Views/'

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
