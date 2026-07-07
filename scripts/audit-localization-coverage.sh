#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STRICT=0
mode="all"
update_baseline=0
targets=()

usage() {
  cat <<'USAGE'
Usage: scripts/audit-localization-coverage.sh [--all|--changed] [--strict] [--update-baseline] [file ...]

Checks Localizable.strings syntax, registered language resources, key parity,
legacy language branching, and direct hardcoded Chinese UI literals. Existing
direct Chinese UI literal debt is ratcheted in
docs/governance/manifests/localization-hardcoded-ui-baseline.json; new matches
fail the audit.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
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
    --update-baseline)
      update_baseline=1
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

status=0
hardcoded_chinese_baseline="docs/governance/manifests/localization-hardcoded-ui-baseline.json"

echo "== Localizable.strings syntax =="
find Ohana -name Localizable.strings -print0 | while IFS= read -r -d '' file; do
  plutil -lint "$file"
done

echo
echo "== Registered language resources =="
localization_sources=(
  "Ohana/Shared/LocalizationSettings.swift"
  "Ohana/Shared/Localization.swift"
  "Ohana/Models/Localization.swift"
)
lprojs=()
while IFS= read -r lproj; do
  lprojs+=("$lproj")
done < <(
  for source in "${localization_sources[@]}"; do
    [[ -f "$source" ]] || continue
    perl -ne 'print "$1\n" if /lprojName:\s*"([^"]+)"/' "$source"
  done | sort -u
)
if [[ ${#lprojs[@]} -eq 0 ]]; then
  while IFS= read -r lproj; do
    lprojs+=("$lproj")
  done < <(find Ohana -maxdepth 1 -name '*.lproj' -type d -exec basename {} .lproj \; | sort -u)
fi
for lproj in "${lprojs[@]:-}"; do
  file="Ohana/${lproj}.lproj/Localizable.strings"
  if [[ -f "$file" ]]; then
    echo "ok  $file"
  elif [[ "$lproj" == "zh-Hans" ]]; then
    echo "ok  source literals provide zh-Hans fallback"
  else
    echo "missing  $file"
    status=1
  fi
done

echo
echo "== Key parity =="
base="Ohana/en.lproj/Localizable.strings"
if [[ -f "$base" ]]; then
  base_keys="$(mktemp)"
  perl -ne 'print "$1\n" if /^"((?:\\"|[^"])*)"\s*=/' "$base" | sort -u > "$base_keys"
  while IFS= read -r -d '' file; do
    [[ "$file" == "$base" ]] && continue
    keys="$(mktemp)"
    perl -ne 'print "$1\n" if /^"((?:\\"|[^"])*)"\s*=/' "$file" | sort -u > "$keys"
    missing_count="$(comm -23 "$base_keys" "$keys" | wc -l | tr -d ' ')"
    extra_count="$(comm -13 "$base_keys" "$keys" | wc -l | tr -d ' ')"
    if [[ "$missing_count" == "0" && "$extra_count" == "0" ]]; then
      echo "ok  $file"
    else
      echo "warn  $file: missing=$missing_count extra=$extra_count compared with en"
      if [[ "$STRICT" == "1" ]]; then
        status=1
      fi
    fi
    rm -f "$keys"
  done < <(find Ohana -name Localizable.strings -print0)
  rm -f "$base_keys"
else
  echo "missing  $base"
  status=1
fi

echo
echo "== Legacy language branching =="
legacy="$(rg -n '\bisEn\s*\?|if\s+[^\\n]*\bisEn\b|guard\s+[^\\n]*\bisEn\b|!\s*isEn\b' Ohana --glob '*.swift' || true)"
if [[ -z "$legacy" ]]; then
  echo "ok  no legacy isEn branching"
else
  echo "$legacy"
  if [[ "$STRICT" == "1" ]]; then
    status=1
  else
    echo "warn  legacy branches remain; migrate UI copy to L10n.tr/text"
  fi
fi

echo
echo "== Direct user-visible Chinese literals =="
python_args=(--mode "$mode" --baseline "$hardcoded_chinese_baseline")
if [[ "$update_baseline" == "1" ]]; then
  python_args+=(--update-baseline)
fi
if [[ ${#targets[@]} -gt 0 ]]; then
  python_args+=(--)
  python_args+=("${targets[@]}")
fi
if ! python3 - "${python_args[@]}" <<'PY'; then
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path.cwd()
ALLOW_MARKER = "localization-audit: allow"
RULE_ID = "localization-hardcoded-ui-chinese"
DIRECT_UI_LITERAL_RE = re.compile(
    r"""
    (?:
      \b(?:Text|Button|Label|Toggle|Picker|NavigationLink|ShareLink|TextField|
          SecureField|DatePicker|Menu|Link|Section|DisclosureGroup|
          emptyText|editLabel|secondaryButton|destructiveButton)\s*\(\s*
      |
      \.(?:accessibilityLabel|accessibilityHint|navigationTitle|alert|
          confirmationDialog)\s*\(\s*
    )
    "(?P<literal>(?:\\"|[^"\n])*[\u3400-\u9fff](?:\\"|[^"\n])*)"
    """,
    re.VERBOSE,
)
DIRECT_UI_NAMED_LITERAL_RE = re.compile(
    r"""
    \b(?:placeholder|title|label)\s*:\s*
    "(?P<literal>(?:\\"|[^"\n])*[\u3400-\u9fff](?:\\"|[^"\n])*)"
    """,
    re.VERBOSE,
)
DIRECT_INPUT_LITERAL_RE = re.compile(
    r"""
    \b(?:GoDraftTextField|GoDraftInput|OhanaTextField|PlantCreationBufferedTextField|
        CrewRosterEditorTextField|InlineNumericInput)\s*\(\s*
    "(?P<literal>(?:\\"|[^"\n])*[\u3400-\u9fff](?:\\"|[^"\n])*)"
    """,
    re.VERBOSE,
)
INPUT_HELPER_CALL_RE = re.compile(
    r"\b(?:GoDraftTextField|GoDraftInput|OhanaTextField|PlantCreationBufferedTextField|CrewRosterEditorTextField|InlineNumericInput)\s*\("
)
LEADING_STRING_LITERAL_RE = re.compile(
    r'^\s*"(?P<literal>(?:\\"|[^"\n])*[\u3400-\u9fff](?:\\"|[^"\n])*)"\s*,?'
)


def relative(path: pathlib.Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def git_files(*args: str) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return [line for line in result.stdout.splitlines() if line.strip()]


def add_target(raw: str, files: set[pathlib.Path]) -> None:
    path = (ROOT / raw).resolve() if not pathlib.Path(raw).is_absolute() else pathlib.Path(raw)
    if path.is_dir():
        files.update(candidate for candidate in path.rglob("*.swift") if candidate.is_file())
    elif path.is_file() and path.suffix == ".swift":
        files.add(path)


def collect_files(mode: str, targets: list[str]) -> list[pathlib.Path]:
    files: set[pathlib.Path] = set()
    if targets:
        for target in targets:
            add_target(target, files)
    elif mode == "changed":
        for raw in set(
            git_files("diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--", "Ohana")
            + git_files("diff", "--cached", "--name-only", "--diff-filter=ACMR", "--", "Ohana")
            + git_files("ls-files", "--others", "--exclude-standard", "--", "Ohana")
        ):
            add_target(raw, files)
    else:
        files.update(candidate for candidate in (ROOT / "Ohana").rglob("*.swift") if candidate.is_file())
    return sorted(files, key=relative)


def scan_file(path: pathlib.Path) -> list[dict[str, object]]:
    matches: list[dict[str, object]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    pending_input_literal_lines = 0
    for line_number, line in enumerate(lines, start=1):
        if ALLOW_MARKER in line:
            pending_input_literal_lines = 0
            continue
        if (
            DIRECT_UI_LITERAL_RE.search(line)
            or DIRECT_UI_NAMED_LITERAL_RE.search(line)
            or DIRECT_INPUT_LITERAL_RE.search(line)
            or (pending_input_literal_lines > 0 and LEADING_STRING_LITERAL_RE.search(line))
        ):
            matches.append({"line": line_number, "source": line.strip()})
        if INPUT_HELPER_CALL_RE.search(line):
            pending_input_literal_lines = 4
        elif pending_input_literal_lines > 0:
            pending_input_literal_lines -= 1
    return matches


def load_baseline(path: pathlib.Path) -> dict[str, list[str]]:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Direct user-visible Chinese literal audit: invalid baseline JSON: {exc}", file=sys.stderr)
        sys.exit(1)
    raw = data.get("allowedMatches", {})
    if not isinstance(raw, dict):
        print("Direct user-visible Chinese literal audit: baseline missing allowedMatches.", file=sys.stderr)
        sys.exit(1)
    allowed: dict[str, list[str]] = {}
    for file_path, lines in raw.items():
        if isinstance(file_path, str) and isinstance(lines, list):
            allowed[file_path] = [line for line in lines if isinstance(line, str)]
    return allowed


def write_baseline(path: pathlib.Path, matches_by_file: dict[str, list[dict[str, object]]]) -> None:
    allowed = {
        file_path: sorted(str(match["source"]) for match in matches)
        for file_path, matches in sorted(matches_by_file.items())
        if matches
    }
    payload = {
        "schema": "ohana.governance.localization-hardcoded-ui-baseline.v1",
        "updated": dt.date.today().isoformat(),
        "policyDocuments": [
            "AGENTS.md",
            "docs/specs/product-foundation.md",
            "docs/design/ohana-ui-spec.md",
        ],
        "purpose": (
            "Ratcheted baseline for existing direct hardcoded Chinese user-visible "
            "SwiftUI and UI helper literals, including placeholder/title/label strings. New matches fail "
            "scripts/audit-localization-coverage.sh."
        ),
        "command": "scripts/audit-localization-coverage.sh --all",
        "allowedMatches": allowed,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    total = sum(len(lines) for lines in allowed.values())
    print(f"Direct user-visible Chinese literal baseline updated at {relative(path)} ({total} match(es), {len(allowed)} file(s)).")


parser = argparse.ArgumentParser()
parser.add_argument("--mode", choices=("all", "changed"), default="all")
parser.add_argument("--baseline", required=True)
parser.add_argument("--update-baseline", action="store_true")
parser.add_argument("targets", nargs="*")
args = parser.parse_args()

files = collect_files(args.mode, args.targets)
matches_by_file: dict[str, list[dict[str, object]]] = {}
for file_path in files:
    matches = scan_file(file_path)
    if matches:
        matches_by_file[relative(file_path)] = matches

baseline_path = ROOT / args.baseline
if args.update_baseline:
    write_baseline(baseline_path, matches_by_file)
    sys.exit(0)

allowed = load_baseline(baseline_path)
violations: list[tuple[str, int, str]] = []
for file_path, matches in matches_by_file.items():
    allowed_counts = collections.Counter(allowed.get(file_path, []))
    seen_counts: collections.Counter[str] = collections.Counter()
    for match in matches:
        source = str(match["source"])
        seen_counts[source] += 1
        if seen_counts[source] > allowed_counts[source]:
            violations.append((file_path, int(match["line"]), source))

if violations:
    for file_path, line_number, source in violations:
        print(
            f"[{RULE_ID}] {file_path}:{line_number} "
            "user-visible copy with Chinese must use L10n/AppLocalizedText or an explicit audit allow marker."
        )
        print(f"  {source}")
    print(
        f"Direct user-visible Chinese literal audit: {len(violations)} new match(es) "
        f"across {len({item[0] for item in violations})} file(s).",
        file=sys.stderr,
    )
    sys.exit(1)

baseline_debt = sum(len(lines) for lines in allowed.values())
current_debt = sum(len(matches) for matches in matches_by_file.values())
print(
    f"Direct user-visible Chinese literal audit: passed ({len(files)} file(s), "
    f"{current_debt} current baseline match(es), {baseline_debt} allowed)."
)
PY
  status=1
fi

exit "$status"
