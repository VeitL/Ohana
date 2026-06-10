#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-ui-v4.sh [--changed|--all|--soft] [Swift files or directories...]

Purpose:
  Check new or modified SwiftUI views against Ohana V4 UI rules from ui规范.selection.json.

Modes:
  --changed  Scan changed Swift files under Ohana/. Default.
  --all      Scan all Swift files under Ohana/ (app target source).
  --soft     Print warnings but exit 0.

Scope note:
  The scan root is the whole Ohana/ tree (Features/, Views/, Shared/, App/,
  Utilities/, ...). Never narrow this back to a subdirectory list: directory
  refactors silently removed 88% of files from this audit once before. The
  fixture tests in scripts/tests/ enforce a minimum scanned-file floor.

Allowlist:
  Add "ui-v4: allow <reason>" on a line that intentionally violates a rule.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

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

if [[ ! -f "ui规范.selection.json" ]]; then
  echo "error: ui规范.selection.json not found at repo root." >&2
  exit 2
fi

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
  echo "V4 UI audit: no Swift view files to scan."
  exit 0
fi

warnings_file="$(mktemp)"
trap 'rm -f "$warnings_file"' EXIT

# One rg invocation per rule across ALL files. Never switch this back to a
# per-file loop: rules x files process spawning made the whole-repo scan take
# 70+ seconds; batched it is ~1s. Output format ([rule] path:line:content) is
# load-bearing for the full-scope ratchet parser and the fixture tests.
scan_rule() {
  local rule_id="$1"
  local pattern="$2"
  local message="$3"
  local suggestion="$4"

  rg --pcre2 -nH --no-heading "$pattern" "${files[@]}" 2>/dev/null \
    | while IFS= read -r match; do
        if [[ "$match" == *"ui-v4: allow"* ]]; then
          continue
        fi
        printf '[%s] %s\n  %s\n  Prefer: %s\n' "$rule_id" "$match" "$message" "$suggestion" >> "$warnings_file"
      done || true
}

scan_rule \
  "background" \
  'ArkBackgroundView\s*\(' \
  "Use the app-wide V4 page background." \
  "OhanaAppBackground()"

scan_rule \
  "system-text-color" \
  'foreground(?:Style|Color)\(\s*\.(primary|secondary)\b' \
  "System primary/secondary can drift from Ohana tokens in custom cards and sheets." \
  "Color.ohanaPrimaryText / Color.ohanaSecondaryText / Color.ohanaTertiaryText"

scan_rule \
  "hardcoded-white-black" \
  '(Color\.(white|black)\b|foreground(?:Style|Color)\(\s*\.(white|black)\b|background\(\s*\.(white|black)\b|fill\(\s*\.(white|black)\b|stroke(?:Border)?\(\s*\.(white|black)\b)' \
  "Hardcoded white/black is usually unsafe across dark/light mode." \
  "Color.ohanaPrimaryText, Color.ohanaCardSurface, Color.arkInk only for intentional ink-on-accent"

scan_rule \
  "material" \
  '\.(ultraThinMaterial|thinMaterial|regularMaterial)\b|presentationBackground\(\s*\.(ultraThinMaterial|thinMaterial|regularMaterial)' \
  "Native material often creates gray sheets/cards and can hide the V4 clear-glass intent." \
  "goTranslucentCard, goGlassBackground, or a local clear glass surface using ohanaGlassStroke"

scan_rule \
  "shadow" \
  '\.shadow\s*\(' \
  "V4 flat cards avoid decorative shadows in business views." \
  "Flat card/surface tokens; use shadow only for intentional overlays with an allow comment"

scan_rule \
  "hardcoded-motion" \
  'withAnimation\(\s*\.(spring|easeIn|easeOut|easeInOut|linear)|\.animation\(\s*\.(spring|easeIn|easeOut|easeInOut|linear)|Animation\.(spring|easeIn|easeOut|easeInOut|linear)' \
  "Visible state changes should use shared V4 motion tokens." \
  "GoMotion.page / GoMotion.feedback / GoMotion.fab / GoMotion.quick / GoMotion.reduced"

scan_rule \
  "plain-button" \
  '\.buttonStyle\(\s*\.plain\s*\)' \
  "Plain buttons miss the default V4 press feedback unless the interaction is truly inert." \
  "ScaleButtonStyle(), or add ui-v4: allow with a reason"

scan_rule \
  "regular-sheet" \
  'presentationBackground\(\s*\.(regularMaterial|ultraThinMaterial|thinMaterial)|presentationDetents\(\s*\[\s*\.large\s*\]\s*\)' \
  "New sheets should default to bottom clear glass and minimum useful height." \
  ".presentationBackground(.clear), pill close, compact detents unless the sheet is a long overview/history"

scan_rule \
  "raw-textfield" \
  '\bTextField\(' \
  "Raw TextField bypasses the V4 flat-input token (font, surface, stroke, focus emphasis drift per call site)." \
  "OhanaTextField(placeholder:text:style:), InlineNumericInput, or GoDraftInput; // ui-v4: allow only inside blessed input wrappers"

scan_rule \
  "hardcoded-detent-height" \
  'presentationDetents\(\s*\[[^]]*\.height\(\s*[0-9]' \
  "Per-sheet numeric detent heights fragment sheet geometry across the app." \
  "OhanaSheetDetents.overview/.full/.compactMedium, ohanaSheetPagePresentation/ohanaCompactSheetPresentation, or a computed adaptive height"

scan_rule \
  "hardcoded-corner-radius" \
  'cornerRadius:\s*[0-9]|\.cornerRadius\(\s*[0-9]|presentationCornerRadius\(\s*[0-9]' \
  "Literal corner radii drift (12/14/16/18/20/22/24... all coexist); use the semantic radius scale." \
  "OhanaRadius.input/.card/.cardLarge/.sheetCompact/.sheetPage/.inlinePopup"

if [[ ! -s "$warnings_file" ]]; then
  echo "V4 UI audit: passed (${#files[@]} file(s))."
  exit 0
fi

echo "V4 UI audit: found potential issues in ${#files[@]} file(s)."
echo
cat "$warnings_file"
echo
echo "Fix warnings or add an inline allowlist comment: // ui-v4: allow <reason>"

if [[ "$strict" -eq 1 ]]; then
  exit 1
fi
