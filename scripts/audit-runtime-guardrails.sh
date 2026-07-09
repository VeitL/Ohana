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
  scripts/audit-runtime-guardrails.sh [--changed|--all|--soft] [Swift files or directories...]

Purpose:
  Catch App Store / energy-sensitive runtime patterns: scattered Core Location,
  background location, raw timers, animation timelines, and decorative loops.

Allowlist:
  Add "runtime-guardrail: allow <reason>" on a line for intentional exceptions.
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
  echo "Runtime guardrails: no Swift files to scan."
  exit 0
fi

warnings_file="$(mktemp)"
trap 'rm -f "$warnings_file"' EXIT

# Files WITHOUT any runtime-policy reference, precomputed once with a single
# rg pass. Timer/loop rules only scan these (policy-aware files are exempt).
non_policy_files=()
while IFS= read -r f; do
  [[ -n "$f" ]] && non_policy_files+=("$f")
done < <(
  rg --files-without-match \
    'AppWorkloadPolicy|AppPerformanceMode\.systemPrefersReducedWork|shouldReduceWork|powerSavingMode|reduceMotion' \
    "${files[@]}" 2>/dev/null || true
)

# One rg invocation per rule (see audit-ui-v4.sh for why the per-file loop must
# never come back). Output format is load-bearing for the fixture tests.
scan() {
  local id="$1"
  local pattern="$2"
  local message="$3"
  local allowed="$4"

  local -a targets
  if [[ "$id" == "raw-timer-publisher" || "$id" == "repeat-forever" || "$id" == "timeline-animation" ]]; then
    targets=("${non_policy_files[@]+"${non_policy_files[@]}"}")
  else
    targets=("${files[@]}")
  fi

  local scoped=()
  for file in "${targets[@]+"${targets[@]}"}"; do
    [[ -f "$file" ]] || continue
    [[ "$file" == "$allowed" ]] && continue
    scoped+=("$file")
  done
  [[ ${#scoped[@]} -eq 0 ]] && return 0

  rg --pcre2 -nH --no-heading "$pattern" "${scoped[@]}" 2>/dev/null \
    | while IFS= read -r match; do
        case "$match" in
          *"$allowed"*|*"runtime-guardrail: allow"*) continue ;;
        esac
        printf '[%s] %s\n  %s\n  Allowed home: %s\n\n' "$id" "$match" "$message" "$allowed" >> "$warnings_file"
      done || true
}

scan \
  "location-manager" \
  'CLLocationManager\s*\(' \
  "Location manager creation must stay centralized so background indicators and battery behavior remain predictable." \
  "Ohana/Features/Walks/LocationManager.swift"

scan \
  "background-location" \
  'allowsBackgroundLocationUpdates\s*=\s*true' \
  "Background location may only be enabled for a running dog walk." \
  "Ohana/Features/Walks/LocationManager.swift"

scan \
  "always-location-request" \
  'requestAlwaysAuthorization\s*\(' \
  "Always location prompts must stay behind the running-walk flow." \
  "Ohana/Features/Walks/LocationManager.swift"

scan \
  "idle-timer" \
  'isIdleTimerDisabled\s*=\s*true' \
  "The app should not keep the display awake globally; only explicit active flows may opt in." \
  "Ohana/Features/Walks/PetWalkingManager.swift"

scan \
  "raw-timer-publisher" \
  'Timer\.publish\s*\(' \
  "Timers should be visible-page scoped and guarded by AppWorkloadPolicy when they repeat." \
  "AppWorkloadPolicy"

scan \
  "repeat-forever" \
  'repeatForever\s*\(' \
  "Decorative loops should stop in background, low power, Reduce Motion, or invisible pages." \
  "AppWorkloadPolicy"

scan \
  "timeline-animation" \
  'TimelineView\s*\(\s*\.animation' \
  "Animation timelines should be paused by AppWorkloadPolicy or visibility." \
  "AppWorkloadPolicy"

scan \
  "orphan-revision-center" \
  'ReadModelRevisionCenter\s*\(\s*\)' \
  "Ad-hoc revision centers publish into the void; use ReadModelRevisionCenter.shared so AppServices-subscribed UI observers see every mutation." \
  "Ohana/Domain/Events/DomainCommandPipeline.swift"

if [[ ! -s "$warnings_file" ]]; then
  echo "Runtime guardrails: passed (${#files[@]} file(s))."
  exit 0
fi

echo "Runtime guardrails: review warnings in ${#files[@]} file(s)."
echo
cat "$warnings_file"
echo "Add // runtime-guardrail: allow <reason> only for intentional exceptions."
if [[ "$strict" -eq 1 ]]; then
  exit 1
fi
