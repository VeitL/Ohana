#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=()
scan_roots=()
budget_manifest="docs/governance/manifests/release-resource-ownership.json"

for path in Resources Ohana/Assets.xcassets Ohana/PrivacyInfo.xcprivacy; do
  [[ -e "$path" ]] && scan_roots+=("$path")
done
while IFS= read -r lproj; do
  scan_roots+=("$lproj")
done < <(find Ohana -maxdepth 1 -type d -name '*.lproj' 2>/dev/null | sort)

fail() {
  failures+=("$1")
}

check_dir_budget() {
  local path="$1"
  local limit_mib="$2"
  [[ -e "$path" ]] || return 0
  local size_kib
  size_kib="$(du -sk "$path" | awk '{ print $1 }')"
  local limit_kib=$((limit_mib * 1024))
  if (( size_kib > limit_kib )); then
    fail "$path is $((size_kib / 1024)) MiB; budget is ${limit_mib} MiB."
  fi
}

load_budget_lines() {
  if [[ ! -f "$budget_manifest" ]]; then
    printf 'error\tResource budget manifest is missing: %s\n' "$budget_manifest"
    return 0
  fi

  python3 - "$budget_manifest" <<'PY'
from __future__ import annotations

import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"error\t{path}: {exc}")
    sys.exit(0)

for entry in data.get("resourceBudgets", []):
    resource_path = entry.get("path")
    limit = entry.get("limitMiB")
    if isinstance(resource_path, str) and isinstance(limit, int):
        print(f"{resource_path}\t{limit}")
    else:
        print(f"error\tInvalid resource budget entry: {entry.get('id', '<missing id>')}")
PY
}

echo "== Resource size budgets =="
while IFS=$'\t' read -r path limit_mib; do
  [[ -n "${path:-}" ]] || continue
  if [[ "$path" == "error" ]]; then
    fail "$limit_mib"
    continue
  fi
  check_dir_budget "$path" "$limit_mib"
done < <(load_budget_lines)

while IFS=$'\t' read -r path _limit_mib; do
  [[ -n "${path:-}" && "$path" != "error" ]] || continue
  if [[ -e "$path" ]]; then
    du -sh "$path"
  fi
done < <(load_budget_lines)

echo
echo "== Finder / AppleDouble detritus =="
if [[ ${#scan_roots[@]} -gt 0 ]]; then
  while IFS= read -r -d '' file; do
  case "$(basename "$file")" in
    .DS_Store|._*|__MACOSX)
      fail "Forbidden signing detritus file exists in packaged resources: $file"
      ;;
  esac
  done < <(find "${scan_roots[@]}" \( -name '.DS_Store' -o -name '._*' -o -name '__MACOSX' \) -print0 2>/dev/null)
fi

if command -v xattr >/dev/null 2>&1; then
  echo
  echo "== Packaged resource xattrs =="
  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue
    while IFS= read -r attr; do
      [[ -n "$attr" ]] || continue
      case "$attr" in
        com.apple.provenance)
          # Common on locally-created files and not the CodeSign failure class.
          ;;
        com.apple.FinderInfo|com.apple.ResourceFork|com.apple.quarantine|*)
          fail "Packaged resource has signing-risk xattr '$attr': $file"
          ;;
      esac
    done < <(xattr "$file" 2>/dev/null || true)
  done < <(find "${scan_roots[@]}" -type f -print0 2>/dev/null)
else
  echo "xattr not available; skipping local extended-attribute scan."
fi

echo
echo "== Privacy manifest packaging =="
if [[ ! -f "Ohana/PrivacyInfo.xcprivacy" ]]; then
  fail "Ohana/PrivacyInfo.xcprivacy is missing."
elif ! plutil -lint "Ohana/PrivacyInfo.xcprivacy" >/dev/null; then
  fail "Ohana/PrivacyInfo.xcprivacy is not valid plist syntax."
else
  echo "ok  Ohana/PrivacyInfo.xcprivacy"
fi

if [[ ${#failures[@]} -eq 0 ]]; then
  echo
  echo "Resource integrity audit: passed."
  exit 0
fi

echo
echo "Resource integrity audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
