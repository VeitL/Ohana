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

check_avatar_manifest() {
  local label="$1"
  local directory="$2"
  local expected_extension="$3"
  [[ -d "$directory" ]] || return 0

  python3 - "$label" "$directory" "$expected_extension" <<'PY'
from __future__ import annotations

import json
import pathlib
import sys

label = sys.argv[1]
directory = pathlib.Path(sys.argv[2])
expected_extension = sys.argv[3]
manifest_path = directory / "manifest.json"
errors: list[str] = []

if not manifest_path.exists():
    errors.append(f"{label}: missing manifest.json")
else:
    try:
        entries = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{label}: manifest parse failed: {exc}")
        entries = []

    referenced: set[str] = set()
    if not isinstance(entries, list):
        errors.append(f"{label}: manifest root must be a list")
        entries = []

    for index, entry in enumerate(entries):
        filename = entry.get("filename") if isinstance(entry, dict) else None
        if not isinstance(filename, str) or not filename:
            errors.append(f"{label}: manifest entry {index} has no filename")
            continue
        if filename != filename.strip():
            errors.append(f"{label}: manifest filename has surrounding whitespace: {filename!r}")
        if not filename.endswith(expected_extension):
            errors.append(f"{label}: manifest filename must use {expected_extension}: {filename}")
        if filename in referenced:
            errors.append(f"{label}: duplicate manifest filename: {filename}")
        referenced.add(filename)
        if not (directory / filename).is_file():
            errors.append(f"{label}: manifest references missing file: {filename}")

    packaged = {
        path.name
        for path in directory.iterdir()
        if path.is_file() and path.suffix.lower() in {".png", ".webp"}
    }
    source_pngs = sorted(name for name in packaged if name.endswith(".png"))
    if source_pngs:
        preview = ", ".join(repr(name) for name in source_pngs[:8])
        errors.append(f"{label}: source PNGs must not live in packaged avatar directory: {preview}")

    unreferenced = sorted(name for name in packaged if name.endswith(expected_extension) and name not in referenced)
    if unreferenced:
        preview = ", ".join(repr(name) for name in unreferenced[:8])
        errors.append(f"{label}: packaged files not referenced by manifest: {preview}")

for error in errors:
    print(error)

sys.exit(1 if errors else 0)
PY
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
echo "== Avatar manifest integrity =="
if ! check_avatar_manifest "Human avatars" "Resources/Avatars/HumanAvatarAssets" ".webp"; then
  fail "Human avatar manifest integrity failed."
else
  echo "ok  Human avatars"
fi
if ! check_avatar_manifest "Pet avatars" "Resources/Avatars/PetAvatarAssets" ".webp"; then
  fail "Pet avatar manifest integrity failed."
else
  echo "ok  Pet avatars"
fi

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
