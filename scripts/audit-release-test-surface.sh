#!/usr/bin/env bash
set -euo pipefail

ROOT="${OHANA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

soft=0
scan_all=0
app_path=""
source_paths=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-release-test-surface.sh --all [--soft]
  scripts/audit-release-test-surface.sh path/to/File.swift [...]
  scripts/audit-release-test-surface.sh --app /path/to/Ohana.app [--soft]

The source mode rejects shipping test launch markers, Debug menus, and
developer balance overrides unless they are inside a compiler branch that
requires DEBUG. The app mode scans the final Release executables and packaged
resources for the same test-only surface.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      scan_all=1
      shift
      ;;
    --app)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --app requires an .app path." >&2
        exit 2
      fi
      app_path="$2"
      shift 2
      ;;
    --soft)
      soft=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      source_paths+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$app_path" ]]; then
  if [[ "$scan_all" == "1" || "${#source_paths[@]}" -gt 0 ]]; then
    echo "error: --app cannot be combined with source paths or --all." >&2
    exit 2
  fi
  if [[ ! -d "$app_path" ]]; then
    echo "error: app bundle does not exist: $app_path" >&2
    exit 2
  fi

  failures=()
  executables=()
  main_executable="$app_path/Ohana"
  if [[ ! -f "$main_executable" && -f "$app_path/Info.plist" ]]; then
    executable_name="$(plutil -extract CFBundleExecutable raw -o - "$app_path/Info.plist" 2>/dev/null || true)"
    [[ -n "$executable_name" ]] && main_executable="$app_path/$executable_name"
  fi
  executables+=("$main_executable")

  if [[ -d "$app_path/PlugIns" ]]; then
    while IFS= read -r -d '' extension_path; do
      extension_name="$(basename "$extension_path" .appex)"
      if [[ -f "$extension_path/Info.plist" ]]; then
        extension_name="$(plutil -extract CFBundleExecutable raw -o - "$extension_path/Info.plist" 2>/dev/null || printf '%s' "$extension_name")"
      fi
      executables+=("$extension_path/$extension_name")
    done < <(find "$app_path/PlugIns" -type d -name '*.appex' -print0 | LC_ALL=C sort -z)
  fi

  forbidden_regex='OHANA_[A-Z0-9_]*UI_TEST[A-Z0-9_]*|OHANA_RESET_PERSISTENT_STATE|OHANA_REDUCED_VISUAL_EFFECTS|XCTest(ConfigurationFilePath|BundlePath|SessionIdentifier)|settings-debug-|UI Test Shortcuts|CoconutBalanceTest|coconut-balance-test-screen|settings\.coconut\.test|setDeveloperOverrideBalance|developer override|Codex Human Baseline|Seeded by UI tests|_uiTest|UITest'
  for executable_path in "${executables[@]}"; do
    if [[ ! -f "$executable_path" ]]; then
      failures+=("[release-artifact-executable] expected executable is missing: $executable_path")
      continue
    fi
    matches="$(strings -a "$executable_path" | LC_ALL=C grep -E "$forbidden_regex" | LC_ALL=C sort -u | head -20 || true)"
    if [[ -n "$matches" ]]; then
      failures+=("[release-artifact-test-marker] forbidden test-only marker in $executable_path: ${matches//$'\n'/; }")
    fi
  done

  while IFS= read -r -d '' resource_path; do
    failures+=("[release-artifact-test-resource] forbidden packaged test resource: $resource_path")
  done < <(
    find "$app_path" \
      \( -name '*.xctest' -o -name '*.storekit' -o -iname '*UITest*' -o -iname '*TestFixture*' \) \
      -print0 | LC_ALL=C sort -z
  )

  echo "Release artifact test-surface audit: scanned ${#executables[@]} executable(s), ${#failures[@]} violation(s)."
  if [[ "${#failures[@]}" -gt 0 ]]; then
    printf '%s\n' "${failures[@]}" >&2
    [[ "$soft" == "1" ]] && exit 0
    exit 1
  fi
  exit 0
fi

if [[ "$scan_all" == "1" ]]; then
  while IFS= read -r -d '' source_path; do
    source_paths+=("$source_path")
  done < <(find Ohana OhanaWidgets -type f -name '*.swift' -print0 | LC_ALL=C sort -z)
fi

if [[ "${#source_paths[@]}" -eq 0 ]]; then
  usage >&2
  exit 2
fi

set +e
python3 - "$soft" "${source_paths[@]}" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

soft = sys.argv[1] == "1"
paths = [pathlib.Path(raw) for raw in sys.argv[2:]]
patterns = (
    (
        "release-test-launch-marker",
        re.compile(
            r"OHANA_(?:[A-Z0-9_]*UI_TEST[A-Z0-9_]*|RESET_PERSISTENT_STATE|REDUCED_VISUAL_EFFECTS)"
            r"|XCTest(?:ConfigurationFilePath|BundlePath|SessionIdentifier)"
        ),
    ),
    (
        "release-debug-surface-marker",
        re.compile(
            r"settings-debug-|UI Test Shortcuts|CoconutBalanceTest|settings\.coconut\.test"
            r"|setDeveloperOverrideBalance"
        ),
    ),
)


def without_comments(line: str, in_block: bool) -> tuple[str, bool]:
    result: list[str] = []
    index = 0
    in_string = False
    escaped = False
    while index < len(line):
        if in_block:
            end = line.find("*/", index)
            if end == -1:
                return "".join(result), True
            in_block = False
            index = end + 2
            continue
        char = line[index]
        next_char = line[index + 1] if index + 1 < len(line) else ""
        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            result.append(char)
            index += 1
            continue
        if char == "/" and next_char == "/":
            break
        if char == "/" and next_char == "*":
            in_block = True
            index += 2
            continue
        result.append(char)
        index += 1
    return "".join(result), in_block


def branch_requires_debug(expression: str) -> bool:
    if "||" in expression or re.search(r"!\s*DEBUG\b", expression):
        return False
    return re.search(r"\bDEBUG\b", expression) is not None


violations: list[str] = []
scanned = 0
for path in paths:
    if not path.is_file():
        violations.append(f"[release-test-surface-input] source file is missing: {path}")
        continue
    scanned += 1
    debug_branches: list[bool] = []
    in_block_comment = False
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line, in_block_comment = without_comments(raw_line, in_block_comment)
        stripped = line.strip()
        directive = re.match(r"#(if|elseif|else|endif)\b(.*)", stripped)
        if directive:
            kind, expression = directive.groups()
            if kind == "if":
                debug_branches.append(branch_requires_debug(expression.strip()))
            elif kind == "elseif" and debug_branches:
                debug_branches[-1] = branch_requires_debug(expression.strip())
            elif kind == "else" and debug_branches:
                debug_branches[-1] = False
            elif kind == "endif" and debug_branches:
                debug_branches.pop()
            continue
        if any(debug_branches):
            continue
        for rule, pattern in patterns:
            match = pattern.search(line)
            if match:
                violations.append(
                    f"[{rule}] {path}:{line_number}: '{match.group(0)}' must be inside a DEBUG-only compiler branch"
                )

print(f"Release source test-surface audit: scanned {scanned} file(s), {len(violations)} violation(s).")
for violation in violations:
    print(violation, file=sys.stderr)
sys.exit(0 if soft or not violations else 1)
PY
status=$?
set -e
exit "$status"
