#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="changed"
update_baseline=0
strict=1
targets=()
baseline="docs/governance/manifests/swiftdata-save-failure-baseline.json"

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-swiftdata-save-failures.sh [--changed|--all] [Swift files or directories...]
  scripts/audit-swiftdata-save-failures.sh --update-baseline

Purpose:
  Reject try? context.save() and new ambiguous no-argument safeSave() or
  safeSaveResult() calls. Changed mode scans only the supplied/currently changed
  Swift files; all mode is the release/CI whole-app gate.
USAGE
}

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
    --update-baseline)
      mode="all"
      update_baseline=1
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

if [[ "$update_baseline" == "1" && ${#targets[@]} -gt 0 ]]; then
  echo "--update-baseline must scan the complete Ohana tree; do not pass targets." >&2
  exit 2
fi

python3 - "$mode" "$update_baseline" "$strict" "$baseline" ${targets[@]+"${targets[@]}"} <<'PY'
from __future__ import annotations

import collections
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path.cwd()
MODE = sys.argv[1]
UPDATE_BASELINE = sys.argv[2] == "1"
STRICT = sys.argv[3] == "1"
BASELINE = ROOT / sys.argv[4]
TARGETS = [pathlib.Path(value) for value in sys.argv[5:]]
ALLOW_MARKER = "save-failure-audit: allow"
AMBIGUOUS_RULE_ID = "swiftdata-ambiguous-safe-save"
SILENT_RULE_ID = "swiftdata-silent-save-discard"
SAFE_SAVE_RE = re.compile(
    r"\b(?:[A-Za-z0-9_]+Context|context|modelContext)\."
    r"(?:safeSave|safeSaveResult)\(\)"
)
SILENT_SAVE_RE = re.compile(
    r"^\s*try\?\s+(?:[A-Za-z0-9_]+Context|context|modelContext)\.save\(\)"
)


def relative(path: pathlib.Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def git_paths(args: list[str]) -> list[pathlib.Path]:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return []
    return [ROOT / line for line in result.stdout.splitlines() if line.strip()]


def collect_files() -> list[pathlib.Path]:
    if TARGETS:
        files: list[pathlib.Path] = []
        for raw in TARGETS:
            path = raw if raw.is_absolute() else ROOT / raw
            if path.is_dir():
                files.extend(path.rglob("*.swift"))
            elif path.is_file() and path.suffix == ".swift":
                files.append(path)
        return sorted(set(files))
    if MODE == "all":
        return sorted((ROOT / "Ohana").rglob("*.swift"))
    changed = git_paths(
        ["diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--", "Ohana"]
    )
    untracked = git_paths(
        ["ls-files", "--others", "--exclude-standard", "--", "Ohana"]
    )
    return sorted(
        {
            path
            for path in [*changed, *untracked]
            if path.is_file() and path.suffix == ".swift"
        }
    )


def read_lines(path: pathlib.Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore").splitlines()


def load_baseline(path: pathlib.Path) -> dict[str, list[str]]:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"SwiftData save failure audit: invalid baseline JSON: {exc}", file=sys.stderr)
        sys.exit(1)
    raw = data.get("allowedMatches", {})
    if not isinstance(raw, dict):
        print("SwiftData save failure audit: baseline missing allowedMatches.", file=sys.stderr)
        sys.exit(1)
    return {
        file_path: [line for line in lines if isinstance(line, str)]
        for file_path, lines in raw.items()
        if isinstance(file_path, str) and isinstance(lines, list)
    }


files = collect_files()
if not files:
    print("SwiftData save failure audit: no Swift files to scan.")
    sys.exit(0)

print(f"SwiftData save failure audit: scanning {len(files)} file(s).")

ambiguous_by_file: dict[str, list[tuple[int, str]]] = {}
silent_violations: list[tuple[str, int, str]] = []
for path in files:
    rel = relative(path)
    ambiguous: list[tuple[int, str]] = []
    for line_number, line in enumerate(read_lines(path), start=1):
        if ALLOW_MARKER in line:
            continue
        source = line.strip()
        if SILENT_SAVE_RE.search(line):
            silent_violations.append((rel, line_number, source))
        if SAFE_SAVE_RE.search(line):
            ambiguous.append((line_number, source))
    if ambiguous:
        ambiguous_by_file[rel] = ambiguous

if UPDATE_BASELINE:
    allowed = {
        file_path: sorted(source for _, source in matches)
        for file_path, matches in sorted(ambiguous_by_file.items())
    }
    payload = {
        "schema": "ohana.governance.swiftdata-save-failure-baseline.v1",
        "updated": dt.date.today().isoformat(),
        "policyDocuments": [
            "AGENTS.md",
            "docs/release-quality-gates.md",
            "docs/data-cache-sync-policy.md",
        ],
        "purpose": (
            "Ratcheted baseline for existing bare safeSave() or no-argument "
            "safeSaveResult() calls that leave save-failure handling ambiguous. "
            "New writes should pass publishFailureEvent explicitly, throw, or use "
            "an explicit user-visible failure contract."
        ),
        "command": "scripts/audit-release-data-safety.sh --update-save-baseline",
        "allowedMatches": allowed,
    }
    BASELINE.parent.mkdir(parents=True, exist_ok=True)
    BASELINE.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        f"SwiftData save failure baseline updated at {relative(BASELINE)} "
        f"({sum(len(values) for values in allowed.values())} match(es), "
        f"{len(allowed)} file(s))."
    )
    sys.exit(0)

allowed = load_baseline(BASELINE)
ambiguous_violations: list[tuple[str, int, str]] = []
for file_path, matches in ambiguous_by_file.items():
    allowed_counts = collections.Counter(allowed.get(file_path, []))
    seen_counts: collections.Counter[str] = collections.Counter()
    for line_number, source in matches:
        seen_counts[source] += 1
        if seen_counts[source] > allowed_counts[source]:
            ambiguous_violations.append((file_path, line_number, source))

for file_path, line_number, source in silent_violations:
    print(
        f"[{SILENT_RULE_ID}] {file_path}:{line_number} "
        "try? context.save() silently discards persistence failure; throw, handle "
        "the error, or use an explicit failure-reporting save boundary.",
        file=sys.stderr,
    )
    print(f"  {source}", file=sys.stderr)

for file_path, line_number, source in ambiguous_violations:
    print(
        f"[{AMBIGUOUS_RULE_ID}] {file_path}:{line_number} "
        "bare safeSave()/safeSaveResult() leaves persistence failure handling "
        "ambiguous; pass publishFailureEvent explicitly, throw, or add an explicit "
        "allow marker.",
        file=sys.stderr,
    )
    print(f"  {source}", file=sys.stderr)

violation_count = len(silent_violations) + len(ambiguous_violations)
if violation_count:
    print(
        f"SwiftData save failure audit: {violation_count} violation(s) across "
        f"{len({item[0] for item in [*silent_violations, *ambiguous_violations]})} "
        "file(s).",
        file=sys.stderr,
    )
    sys.exit(1 if STRICT else 0)

current_debt = sum(len(matches) for matches in ambiguous_by_file.values())
print(
    f"SwiftData save failure audit: passed ({len(files)} file(s), "
    f"{current_debt} ratcheted match(es) in scope)."
)
PY
