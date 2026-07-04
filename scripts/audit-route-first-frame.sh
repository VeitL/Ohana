#!/usr/bin/env bash
set -euo pipefail

# Route first-frame audit.
#
# Route/Data containers are allowed to own route-local data loading, but the
# first visible frame must stay a light shell. This audit catches the two shapes
# that repeatedly regress into first-frame stalls:
#
#   - first-frame @Query subscriptions inside a route/data container
#   - direct SwiftData fetch calls in route/data containers outside a
#     route-scoped @ModelActor loader
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
  route-first-frame-modelactor-live-model-return

SwiftData fetches owned by a route-scoped @ModelActor loader are allowed.
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
      git diff --name-only --diff-filter=ACMR HEAD -- Ohana 2>/dev/null || true
      git diff --cached --name-only --diff-filter=ACMR -- Ohana 2>/dev/null || true
      git ls-files --others --exclude-standard -- Ohana 2>/dev/null || true
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
      "route/data containers must not fetch SwiftData on the first frame; move fetch work into a route-scoped @ModelActor loader."
  done < <(
    python3 - "$file" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    lines = handle.read().splitlines()

brace_depth = 0
pending_model_actor = False
pending_actor_declaration = False
model_actor_body_depth = None
fetch_pattern = re.compile(r"([A-Za-z0-9_]+Context|context|modelContext)\.fetch\(")

for line_number, line in enumerate(lines, start=1):
    if model_actor_body_depth is not None and brace_depth < model_actor_body_depth:
        model_actor_body_depth = None

    if "@ModelActor" in line:
        pending_model_actor = True

    if pending_model_actor and re.search(r"\bactor\b", line):
        pending_actor_declaration = True

    opens = line.count("{")
    closes = line.count("}")
    if pending_actor_declaration and opens > 0:
        model_actor_body_depth = brace_depth + 1
        pending_actor_declaration = False
        pending_model_actor = False

    in_model_actor = model_actor_body_depth is not None and brace_depth >= model_actor_body_depth
    if (
        fetch_pattern.search(line)
        and "route-first-frame: allow" not in line
        and not in_model_actor
    ):
        print(f"{line_number}:{line}")

    brace_depth += opens - closes
PY
  )

  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    local line_number="${match%%:*}"
    warn "route-first-frame-modelactor-live-model-return" "$file" "$line_number" \
      "@ModelActor loaders must not return SwiftData models or result structs containing SwiftData models across actor boundaries; return Sendable IDs or value snapshots."
  done < <(
    python3 - "$file" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()

model_names = set()
for model_path in pathlib.Path("Ohana/Models").rglob("*.swift"):
    text = model_path.read_text(encoding="utf-8")
    model_names.update(re.findall(r"@Model\s+(?:final\s+)?class\s+([A-Za-z0-9_]+)", text))

def contains_model_type(type_expr):
    return any(re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", type_expr) for name in model_names)

struct_contains_model = {}
pending_struct = None
struct_depth = None
brace_depth = 0
property_pattern = re.compile(r"\b(?:let|var)\s+[A-Za-z0-9_]+\s*:\s*([^=]+)")

for line in lines:
    if struct_depth is not None and brace_depth < struct_depth:
        pending_struct = None
        struct_depth = None

    struct_match = re.search(r"\bstruct\s+([A-Za-z0-9_]+)", line)
    if struct_match and "{" in line:
        pending_struct = struct_match.group(1)
        struct_depth = brace_depth + line.count("{")
        struct_contains_model.setdefault(pending_struct, False)

    if pending_struct is not None:
        property_match = property_pattern.search(line)
        if property_match and contains_model_type(property_match.group(1)):
            struct_contains_model[pending_struct] = True

    brace_depth += line.count("{") - line.count("}")

brace_depth = 0
pending_model_actor = False
pending_actor_declaration = False
model_actor_body_depth = None
function_return_pattern = re.compile(r"^\s*(?!private\b)(?:public\s+|internal\s+|fileprivate\s+)?(?:nonisolated\s+)?func\b.*->\s*([^\{]+)")

for line_number, line in enumerate(lines, start=1):
    if model_actor_body_depth is not None and brace_depth < model_actor_body_depth:
        model_actor_body_depth = None

    if "@ModelActor" in line:
        pending_model_actor = True

    if pending_model_actor and re.search(r"\bactor\b", line):
        pending_actor_declaration = True

    opens = line.count("{")
    closes = line.count("}")
    if pending_actor_declaration and opens > 0:
        model_actor_body_depth = brace_depth + 1
        pending_actor_declaration = False
        pending_model_actor = False

    in_model_actor = model_actor_body_depth is not None and brace_depth >= model_actor_body_depth
    if in_model_actor:
        match = function_return_pattern.search(line)
        if match:
            return_type = match.group(1).strip()
            bare_return_type = re.sub(r"[\[\]\?\!<>,:\s]+", " ", return_type).strip().split()
            if contains_model_type(return_type) or any(struct_contains_model.get(token, False) for token in bare_return_type):
                print(f"{line_number}:{line}")

    brace_depth += opens - closes
PY
  )
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
