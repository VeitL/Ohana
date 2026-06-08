#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-accessibility.sh [--changed|--all|--soft] [Swift files or directories...]

Purpose:
  Heuristic accessibility checks for Ohana SwiftUI views, per
  docs/accessibility-governance.md. These are conservative grep heuristics, not
  a full a11y audit; passing this does not prove VoiceOver/Dynamic Type quality.

Modes:
  --changed  Scan changed Swift files under Ohana/Views and Ohana/Utilities. Default.
  --all      Scan all Swift files under Ohana/Views and Ohana/Utilities.
  --soft     Print warnings but exit 0.

Allowlist:
  Add "a11y: allow <reason>" on a line that intentionally violates a rule.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="changed"
strict=1
targets=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed) mode="changed"; shift ;;
    --all) mode="all"; shift ;;
    --soft) strict=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) targets+=("$1"); shift ;;
  esac
done

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required." >&2
  exit 2
fi

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
  echo "Accessibility audit: no Swift view files to scan."
  exit 0
fi

warnings_file="$(mktemp)"
trap 'rm -f "$warnings_file"' EXIT

scan_rule() {
  local rule_id="$1"; local pattern="$2"; local message="$3"; local suggestion="$4"
  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    rg --pcre2 -n --no-heading "$pattern" "$file" 2>/dev/null | while IFS= read -r match; do
      [[ "$match" == *"a11y: allow"* ]] && continue
      printf '[%s] %s:%s\n  %s\n  Prefer: %s\n' "$rule_id" "$file" "$match" "$message" "$suggestion" >> "$warnings_file"
    done || true
  done
}

# 1. Icon-only buttons: a Button whose label is only an Image/Label-less icon
#    needs an accessibilityLabel. Heuristic: Button { Image(systemName: ...) }.
scan_rule \
  "icon-only-button" \
  'Button\s*\{[^}]*Image\(systemName:[^}]*\}\s*$' \
  "Icon-only Button needs a VoiceOver label." \
  ".accessibilityLabel(...) on the button (localized via L10n)"

# 2. decorative-looking images with no explicit a11y treatment nearby in line.
scan_rule \
  "image-needs-label-or-hidden" \
  'Image\(systemName:\s*"[^"]+"\)(?!.*(accessibilityLabel|accessibilityHidden|labelStyle))' \
  "Standalone SF Symbol should be labeled or hidden for VoiceOver." \
  ".accessibilityLabel(...) for meaningful icons, or .accessibilityHidden(true) for purely decorative"

# 3. Hardcoded tiny tap targets below the 44pt minimum.
scan_rule \
  "small-hit-target" \
  '\.frame\(\s*width:\s*(?:[0-9]|[1-3][0-9]|4[0-3])(?:\.0)?\s*,\s*height:\s*(?:[0-9]|[1-3][0-9]|4[0-3])(?:\.0)?\s*\)' \
  "Interactive controls must have at least a 44x44pt hit target." \
  "Use >=44pt frame or .contentShape + padding; add a11y: allow for non-interactive glyphs"

# 4. Fixed font sizes bypass Dynamic Type.
scan_rule \
  "fixed-font-size" \
  '\.font\(\s*\.system\(size:\s*[0-9]' \
  "Fixed point font sizes do not scale with Dynamic Type." \
  "OhanaFont.* tokens or .font(.body/.headline...) with relative sizing"

# 5. Color-only status signaling without text/symbol (heuristic: foregroundColor
#    set from a status color var named like *color* with no adjacent label).
scan_rule \
  "color-only-meaning" \
  '//\s*status-color-only' \
  "Do not convey state with color alone (fails Differentiate Without Color)." \
  "Pair color with an SF Symbol shape or text label"

if [[ ! -s "$warnings_file" ]]; then
  echo "Accessibility audit: passed (${#files[@]} file(s))."
  exit 0
fi

echo "Accessibility audit: found potential issues in ${#files[@]} file(s)."
echo
cat "$warnings_file"
echo
echo "Fix warnings or add an inline allowlist comment: // a11y: allow <reason>"

if [[ "$strict" -eq 1 ]]; then
  exit 1
fi
