#!/usr/bin/env bash
set -euo pipefail

ROOT="${OHANA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

failures=()
warnings=()
scan_roots=()
budget_manifest="${OHANA_RESOURCE_BUDGET_MANIFEST:-docs/governance/manifests/release-resource-ownership.json}"
base_ref=""
budgets_only=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-resource-integrity.sh [--base-ref <git-ref>] [--budgets-only]

Size policy:
  Source resource bytes are a review proxy, not the shipped app size. A path
  above warningMiB emits an advisory. It fails only above hardLimitMiB, or when
  growth from --base-ref exceeds maxGrowthMiB while already above the warning.
  Signing detritus, manifest integrity, known CodeSign-risk xattrs, and privacy
  packaging remain unconditional hard failures; unclassified metadata warns.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-ref)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --base-ref requires a git ref." >&2
        exit 2
      fi
      base_ref="$2"
      shift 2
      ;;
    --budgets-only)
      budgets_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for path in Resources Ohana/Assets.xcassets Ohana/PrivacyInfo.xcprivacy; do
  [[ -e "$path" ]] && scan_roots+=("$path")
done
while IFS= read -r lproj; do
  scan_roots+=("$lproj")
done < <(find Ohana -maxdepth 1 -type d -name '*.lproj' 2>/dev/null | sort)

fail() {
  failures+=("$1")
}

warn() {
  warnings+=("$1")
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::warning title=Resource budget::$1" >&2
  else
    echo "warning: $1" >&2
  fi
}

if [[ -n "$base_ref" ]] && ! git cat-file -e "${base_ref}^{commit}" 2>/dev/null; then
  fail "Resource budget base ref is not available: $base_ref"
  base_ref=""
fi

measure_resource_bytes() {
  local path="$1"
  python3 - "$path" "$base_ref" <<'PY'
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

path = pathlib.Path(sys.argv[1])
base_ref = sys.argv[2]

if path.is_file():
    current_bytes = path.stat().st_size
elif path.is_dir():
    current_bytes = sum(candidate.stat().st_size for candidate in path.rglob("*") if candidate.is_file())
else:
    current_bytes = 0

base_bytes = -1
if base_ref:
    result = subprocess.run(
        ["git", "ls-tree", "-r", "-l", "-z", base_ref, "--", str(path)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode == 0:
        base_bytes = 0
        for entry in result.stdout.split(b"\0"):
            if not entry:
                continue
            match = re.match(rb"^\S+\s+\S+\s+\S+\s+([0-9]+)\t", entry)
            if match:
                base_bytes += int(match.group(1))

print(f"{current_bytes}\t{base_bytes}")
PY
}

check_dir_budget() {
  local path="$1"
  local warning_mib="$2"
  local hard_limit_mib="$3"
  local max_growth_mib="$4"
  [[ -e "$path" ]] || return 0

  local current_bytes base_bytes
  IFS=$'\t' read -r current_bytes base_bytes < <(measure_resource_bytes "$path")
  local warning_bytes=$((warning_mib * 1024 * 1024))
  local hard_limit_bytes=$((hard_limit_mib * 1024 * 1024))
  local max_growth_bytes=$((max_growth_mib * 1024 * 1024))
  local current_mib
  current_mib="$(awk -v bytes="$current_bytes" 'BEGIN { printf "%.2f", bytes / 1048576 }')"

  printf '%s: %s MiB logical source bytes (review %s MiB, hard %s MiB)\n' \
    "$path" "$current_mib" "$warning_mib" "$hard_limit_mib"

  if (( current_bytes > hard_limit_bytes )); then
    fail "$path is ${current_mib} MiB and exceeds the ${hard_limit_mib} MiB hard source limit."
    return
  fi

  if (( current_bytes <= warning_bytes )); then
    return
  fi

  if (( base_bytes >= 0 )); then
    local growth_bytes=$((current_bytes - base_bytes))
    local base_mib growth_mib
    base_mib="$(awk -v bytes="$base_bytes" 'BEGIN { printf "%.2f", bytes / 1048576 }')"
    growth_mib="$(awk -v bytes="$growth_bytes" 'BEGIN { printf "%+.2f", bytes / 1048576 }')"
    if (( growth_bytes > max_growth_bytes )); then
      fail "$path is ${current_mib} MiB, above its ${warning_mib} MiB review target, and grew ${growth_mib} MiB from ${base_mib} MiB; maximum reviewed growth is ${max_growth_mib} MiB."
      return
    fi
    warn "$path is ${current_mib} MiB, above its ${warning_mib} MiB review target; growth from $base_ref is ${growth_mib} MiB and remains within the ${max_growth_mib} MiB allowance."
  else
    warn "$path is ${current_mib} MiB, above its ${warning_mib} MiB review target but below the ${hard_limit_mib} MiB hard source limit."
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
    warning = entry.get("warningMiB")
    hard_limit = entry.get("hardLimitMiB")
    max_growth = entry.get("maxGrowthMiB")
    if all(
        (
            isinstance(resource_path, str),
            isinstance(warning, int),
            isinstance(hard_limit, int),
            isinstance(max_growth, int),
            warning > 0 if isinstance(warning, int) else False,
            hard_limit > warning if isinstance(hard_limit, int) and isinstance(warning, int) else False,
            max_growth > 0 if isinstance(max_growth, int) else False,
        )
    ):
        print(f"{resource_path}\t{warning}\t{hard_limit}\t{max_growth}")
    else:
        print(f"error\tInvalid resource budget entry: {entry.get('id', '<missing id>')}")
PY
}

echo "== Resource size budgets =="
while IFS=$'\t' read -r path warning_mib hard_limit_mib max_growth_mib; do
  [[ -n "${path:-}" ]] || continue
  if [[ "$path" == "error" ]]; then
    fail "$warning_mib"
    continue
  fi
  check_dir_budget "$path" "$warning_mib" "$hard_limit_mib" "$max_growth_mib"
done < <(load_budget_lines)

if [[ "$budgets_only" -eq 1 ]]; then
  echo
  if [[ ${#failures[@]} -eq 0 ]]; then
    echo "Resource budget audit: passed with ${#warnings[@]} advisory warning(s)."
    exit 0
  fi
  echo "Resource budget audit: failed." >&2
  printf ' - %s\n' "${failures[@]}" >&2
  exit 1
fi

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
        com.apple.provenance|com.apple.TextEncoding)
          # Common local metadata and not the CodeSign resource-fork class.
          ;;
        com.apple.FinderInfo|com.apple.ResourceFork|com.apple.quarantine)
          fail "Packaged resource has signing-risk xattr '$attr': $file"
          ;;
        *)
          warn "Packaged resource has an unclassified xattr '$attr': $file; the signed Release archive remains authoritative."
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
  echo "Resource integrity audit: passed with ${#warnings[@]} advisory warning(s)."
  exit 0
fi

echo
echo "Resource integrity audit: failed." >&2
printf ' - %s\n' "${failures[@]}" >&2
exit 1
