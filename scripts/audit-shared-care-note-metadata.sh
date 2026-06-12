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
  scripts/audit-shared-care-note-metadata.sh [--changed|--all|--soft] [files...]

Purpose:
  Keep shared-care machine facts out of user-visible note fields. New shared
  care writes must store session id, target count, stock owner, and stock total
  on structured SharedCareSession/CareLedgerEvent fields. Legacy note prefixes
  may be parsed for compatibility, but production code must not write them.
USAGE
}

mode="changed"
strict=1
explicit_files=()

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
      explicit_files+=("$1")
      shift
      ;;
  esac
done

changed_swift_files() {
  {
    git diff --name-only --diff-filter=ACMR HEAD -- Ohana 2>/dev/null || true
    git ls-files --others --exclude-standard -- Ohana 2>/dev/null || true
  } | awk '/\.swift$/ { print }' | sort -u
}

swift_scope() {
  if [[ ${#explicit_files[@]} -gt 0 ]]; then
    for file in "${explicit_files[@]}"; do
      [[ -f "$file" && "$file" == *.swift ]] && printf '%s\n' "$file"
    done
  elif [[ "$mode" == "all" ]]; then
    find Ohana -type f -name '*.swift' | sort
  else
    changed_swift_files
  fi
}

files=()
while IFS= read -r file; do
  [[ -n "$file" ]] && files+=("$file")
done < <(swift_scope)

if [[ ${#files[@]} -eq 0 && "$mode" != "all" ]]; then
  echo "Shared-care note metadata audit: no Swift files to scan."
  exit 0
fi

pattern='SharedCareMetadata\.(note|legacyEncodedNote|prefix)\s*\(|(note\s*:|\.note\s*=)\s*("?[^"\n]*ohana_shared_|SharedCareMetadata\.(feedNotePrefix|waterNotePrefix|litterNotePrefix|unknownPottyNotePrefix|careNotePrefix|walkNotePrefix|expenseNotePrefix))'
matches="$(
  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    rg -n --with-filename --pcre2 "$pattern" "$file" || true
  done
)"

if [[ -n "$matches" ]]; then
  {
    echo "[shared-care-note-metadata]"
    echo "Shared-care machine metadata must not be written into user-visible note fields."
    echo "Use structured SharedCareSession/CareLedgerEvent fields for new writes; keep legacy note prefixes read-only."
    printf '%s\n' "$matches"
  } >&2
  if [[ "$strict" == "1" ]]; then
    exit 1
  fi
fi

echo "Shared-care note metadata audit: passed (${#files[@]} file(s))."
