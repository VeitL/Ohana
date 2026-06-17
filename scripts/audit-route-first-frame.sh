#!/usr/bin/env bash
set -euo pipefail

# Route first-frame audit.
#
# Route/Data containers are allowed to own route-local data loading, but the
# first visible frame must stay a light shell. This audit catches the two shapes
# that repeatedly regress into first-frame stalls:
#
#   - first-frame @Query subscriptions inside a route/data container
#   - direct SwiftData fetch calls in route/data containers without an explicit
#     deferred-load marker
#
# Existing route/data @Query debt is frozen in
# docs/governance/manifests/route-first-frame-baseline.json. New files default
# to zero @Query; any increase over baseline fails.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

baseline_file="docs/governance/manifests/route-first-frame-baseline.json"
soft=0
mode="changed"
targets=()

usage() {
  cat <<'USAGE'
Usage: scripts/audit-route-first-frame.sh [--changed|--all] [--soft] [file ...]

Rule IDs:
  route-first-frame-query
  route-first-frame-sync-fetch
  route-first-frame-service-fetch

Allow a deferred fetch line with:
  // route-first-frame: allow deferred-fetch
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --soft)
      soft=1
      shift
      ;;
    --changed)
      mode="changed"
      shift
      ;;
    --all)
      mode="all"
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

declare -a files=()
declare -a baseline_files=()
declare -a baseline_counts=()

if [[ -f "$baseline_file" ]]; then
  while IFS=$'\t' read -r file count; do
    [[ -n "$file" ]] || continue
    baseline_files+=("$file")
    baseline_counts+=("$count")
  done < <(
    python3 - "$baseline_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
for file_path, count in sorted(data.get("allowedQueryCounts", {}).items()):
    print(f"{file_path}\t{count}")
PY
  )
fi

baseline_query_count_for() {
  local file="$1"
  local index
  for ((index = 0; index < ${#baseline_files[@]}; index += 1)); do
    if [[ "${baseline_files[$index]}" == "$file" ]]; then
      printf '%s\n' "${baseline_counts[$index]}"
      return 0
    fi
  done
  printf '0\n'
}

add_file() {
  local file="$1"
  [[ "$file" == *.swift ]] || return 0
  [[ -f "$file" ]] || return 0
  files+=("$file")
}

if [[ ${#targets[@]} -gt 0 ]]; then
  for file in "${targets[@]}"; do
    add_file "$file"
  done
elif [[ "$mode" == "all" ]]; then
  while IFS= read -r file; do
    add_file "$file"
  done < <(find Ohana -type f -name '*.swift' | sort)
else
  while IFS= read -r file; do
    add_file "$file"
  done < <(
    {
      git diff --name-only --diff-filter=ACMR -- '*.swift'
      git diff --cached --name-only --diff-filter=ACMR -- '*.swift'
      git ls-files --others --exclude-standard -- '*.swift'
    } | sort -u
  )
fi

is_route_first_frame_file() {
  local file="$1"
  case "$file" in
    *RouteContainer.swift|*DataContainer.swift|Ohana/App/RouteContainers/*.swift|*/Ohana/App/RouteContainers/*.swift)
      return 0
      ;;
  esac
  return 1
}

has_allow_marker() {
  local line="$1"
  [[ "$line" == *"route-first-frame: allow"* ]]
}

warnings=0

warn() {
  local rule="$1"
  local file="$2"
  local line="$3"
  local message="$4"
  printf '[%s] %s:%s %s\n' "$rule" "$file" "$line" "$message"
  warnings=$((warnings + 1))
}

scan_file() {
  local file="$1"

  local service_match
  while IFS= read -r service_match; do
    [[ -n "$service_match" ]] || continue
    local service_line_number="${service_match%%:*}"
    warn "route-first-frame-service-fetch" "$file" "$service_line_number" \
      "first-frame render/snapshot code must not call reward services that synchronously fetch active-human state; pass typed snapshot data into the render builder."
  done < <(grep -n 'rewards\.currentHumanBalance(context:' "$file" || true)

  is_route_first_frame_file "$file" || return 0

  local query_lines
  query_lines="$(grep -n '@Query' "$file" | grep -v 'route-first-frame: allow' || true)"
  local query_count
  query_count="$(printf '%s\n' "$query_lines" | sed '/^$/d' | wc -l | tr -d ' ')"
  local allowed_query_count
  allowed_query_count="$(baseline_query_count_for "$file")"
  if [[ "$query_count" -gt "$allowed_query_count" ]]; then
    local line
    line="$(printf '%s\n' "$query_lines" | head -1 | cut -d: -f1)"
    warn "route-first-frame-query" "$file" "$line" \
      "route/data containers may not add first-frame @Query subscriptions; use RouteFirstFrameDeferredLoad or a light shell plus deferred route data. baseline=$allowed_query_count current=$query_count"
  fi

  local match
  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    local line_number="${match%%:*}"
    local source="${match#*:}"
    if has_allow_marker "$source"; then
      continue
    fi
    warn "route-first-frame-sync-fetch" "$file" "$line_number" \
      "route/data containers must not fetch SwiftData on the first frame; defer through a route-scoped loader and mark the deferred fetch."
  done < <(grep -nE '([[:alnum:]_]+Context|context|modelContext)\.fetch\(' "$file" || true)
}

for file in "${files[@]}"; do
  scan_file "$file"
done

count="${#files[@]}"
if [[ "$warnings" -gt 0 ]]; then
  echo "Route first-frame audit: $warnings warning(s) ($count file(s))."
  if [[ "$soft" == "1" ]]; then
    exit 0
  fi
  exit 1
fi

echo "Route first-frame audit: passed ($count file(s))."
