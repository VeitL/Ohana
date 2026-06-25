#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

task_file="docs/task-follow-ups.md"
testing_file="docs/testing-progress.md"

failures=()

fail() {
  failures+=("$1")
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "missing required file: $file"
}

require_file "$task_file"
require_file "$testing_file"
require_file "docs/archive/task-follow-ups-full-2026-06-25.md"
require_file "docs/archive/testing-progress-full-2026-06-25.md"

read -r actual_total actual_p0 actual_p1 actual_p2 actual_p3 < <(
  awk '
    /^### TFU-[0-9]{8}-[0-9]{3}/ {
      total += 1
      waiting = 1
      next
    }
    waiting && /^- Priority \/ bucket:/ {
      if ($0 ~ /P0/) { p0 += 1 }
      else if ($0 ~ /P1/) { p1 += 1 }
      else if ($0 ~ /P2/) { p2 += 1 }
      else if ($0 ~ /P3/) { p3 += 1 }
      waiting = 0
    }
    END {
      printf "%d %d %d %d %d\n", total, p0 + 0, p1 + 0, p2 + 0, p3 + 0
    }
  ' "$task_file"
)

if [[ "$actual_total" -ne $((actual_p0 + actual_p1 + actual_p2 + actual_p3)) ]]; then
  fail "$task_file has $actual_total TFU headings but only $((actual_p0 + actual_p1 + actual_p2 + actual_p3)) priority lines"
fi

summary_line="$(grep -E '^- Open follow-ups: [0-9]+ total: P1 = [0-9]+, P2 = [0-9]+, P3 = [0-9]+\.' "$task_file" || true)"
if [[ -z "$summary_line" ]]; then
  fail "$task_file missing compact Open follow-ups summary line"
else
  read -r declared_total declared_p1 declared_p2 declared_p3 < <(
    sed -E 's/^- Open follow-ups: ([0-9]+) total: P1 = ([0-9]+), P2 = ([0-9]+), P3 = ([0-9]+)\.$/\1 \2 \3 \4/' <<<"$summary_line"
  )
  [[ "$declared_total" -eq "$actual_total" ]] || fail "$task_file declares $declared_total open follow-ups, actual $actual_total"
  [[ "$declared_p1" -eq "$actual_p1" ]] || fail "$task_file declares P1=$declared_p1, actual P1=$actual_p1"
  [[ "$declared_p2" -eq "$actual_p2" ]] || fail "$task_file declares P2=$declared_p2, actual P2=$actual_p2"
  [[ "$declared_p3" -eq "$actual_p3" ]] || fail "$task_file declares P3=$declared_p3, actual P3=$actual_p3"
fi

p0_line="$(grep -E '^- Open P0: [0-9]+\.' "$task_file" || true)"
if [[ -z "$p0_line" ]]; then
  fail "$task_file missing Open P0 summary line"
else
  declared_p0="$(sed -E 's/^- Open P0: ([0-9]+)\.$/\1/' <<<"$p0_line")"
  [[ "$declared_p0" -eq "$actual_p0" ]] || fail "$task_file declares P0=$declared_p0, actual P0=$actual_p0"
fi

testing_total="$(sed -nE 's/^- Open follow-ups: ([0-9]+) total.*$/\1/p' "$testing_file" | head -n 1)"
testing_p1="$(sed -nE 's/^- Open P1: ([0-9]+) total.*$/\1/p' "$testing_file" | head -n 1)"
[[ -n "$testing_total" ]] || fail "$testing_file missing Open follow-ups summary"
[[ -n "$testing_p1" ]] || fail "$testing_file missing Open P1 summary"
if [[ -n "$testing_total" && "$testing_total" -ne "$actual_total" ]]; then
  fail "$testing_file declares $testing_total open follow-ups, actual $actual_total"
fi
if [[ -n "$testing_p1" && "$testing_p1" -ne "$actual_p1" ]]; then
  fail "$testing_file declares P1=$testing_p1, actual P1=$actual_p1"
fi

open_ids_file="$(mktemp)"
active_refs_file="$(mktemp)"
cleanup() {
  rm -f "$open_ids_file" "$active_refs_file"
}
trap cleanup EXIT

awk '/^### TFU-[0-9]{8}-[0-9]{3}/ { print $2 }' "$task_file" | sort -u > "$open_ids_file"
awk '
  /^## Active Module Pointers/ { active = 1; next }
  /^## Recent Validation Snapshots/ { active = 0 }
  active { print }
' "$testing_file" | grep -Eo 'TFU-[0-9]{8}-[0-9]{3}' | sort -u > "$active_refs_file" || true

missing_refs="$(comm -23 "$active_refs_file" "$open_ids_file" || true)"
if [[ -n "$missing_refs" ]]; then
  fail "$testing_file active pointers reference non-open TFUs: $(tr '\n' ' ' <<<"$missing_refs" | sed 's/[[:space:]]*$//')"
fi

stale_task_refs="$(
  {
    rg -n 'docs/task-follow-ups\.md.*TFU-[0-9]{8}-[0-9]{3}|TFU-[0-9]{8}-[0-9]{3}.*docs/task-follow-ups\.md' docs \
      --glob '*.md' \
      --glob '!docs/archive/**' \
      --glob '!docs/task-follow-ups.md' 2>/dev/null || true
  } |
  while IFS= read -r line; do
    ids="$(grep -Eo 'TFU-[0-9]{8}-[0-9]{3}' <<<"$line" | sort -u)"
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      if ! grep -qx "$id" "$open_ids_file"; then
        printf '%s\n' "$line"
        break
      fi
    done <<<"$ids"
  done
)"
if [[ -n "$stale_task_refs" ]]; then
  fail "non-archive docs point docs/task-follow-ups.md at non-open TFUs: $(tr '\n' ' ' <<<"$stale_task_refs" | sed 's/[[:space:]]*$//')"
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "doc-status-ledgers: FAIL"
  for failure in "${failures[@]}"; do
    echo "  - $failure"
  done
  exit 1
fi

echo "doc-status-ledgers: PASS (${actual_total} open TFUs; P0=${actual_p0}, P1=${actual_p1}, P2=${actual_p2}, P3=${actual_p3})"
