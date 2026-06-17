#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 <<'PY'
from __future__ import annotations

import datetime as dt
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path.cwd()
OHANA = ROOT / "Ohana"
BASELINE = ROOT / "docs/governance/manifests/route-first-frame-baseline.json"


def is_swift(file: pathlib.Path) -> bool:
    return file.suffix == ".swift" and file.is_file()


def relative(file: pathlib.Path) -> str:
    return file.relative_to(ROOT).as_posix()


def is_route_first_frame_file(file: pathlib.Path) -> bool:
    path = relative(file)
    return (
        path.endswith("RouteContainer.swift")
        or path.endswith("DataContainer.swift")
        or path.startswith("Ohana/App/RouteContainers/")
    )


def count(pattern: str, text: str) -> int:
    return len(re.findall(pattern, text))


swift_files = sorted(file for file in OHANA.rglob("*.swift") if is_swift(file))
route_files = [file for file in swift_files if is_route_first_frame_file(file)]
baseline_counts: dict[str, int] = {}
if BASELINE.exists():
    baseline_data = json.loads(BASELINE.read_text(encoding="utf-8"))
    baseline_counts = {
        str(file): int(count)
        for file, count in baseline_data.get("allowedQueryCounts", {}).items()
    }

all_query_occurrences = 0
all_fetch_occurrences = 0
first_frame_service_fetch_occurrences = 0
route_query_occurrences = 0
route_fetch_occurrences = 0
route_deferred_fetch_occurrences = 0
route_unmarked_fetch_occurrences = 0
route_files_with_query: list[tuple[str, int]] = []
route_files_with_fetch: list[tuple[str, int, int]] = []

fetch_re = re.compile(r"([A-Za-z_][A-Za-z0-9_]*Context|context|modelContext)\.fetch\(")

for file in swift_files:
    text = file.read_text(encoding="utf-8")
    all_query_occurrences += count(r"@Query\b", text)
    all_fetch_occurrences += len(fetch_re.findall(text))
    first_frame_service_fetch_occurrences += count(r"rewards\.currentHumanBalance\(context:", text)

for file in route_files:
    text = file.read_text(encoding="utf-8")
    query_count = count(r"@Query\b", text)
    fetch_lines = [line for line in text.splitlines() if fetch_re.search(line)]
    deferred_fetch_count = sum("route-first-frame: allow" in line for line in fetch_lines)
    unmarked_fetch_count = len(fetch_lines) - deferred_fetch_count

    route_query_occurrences += query_count
    route_fetch_occurrences += len(fetch_lines)
    route_deferred_fetch_occurrences += deferred_fetch_count
    route_unmarked_fetch_occurrences += unmarked_fetch_count

    if query_count:
        route_files_with_query.append((relative(file), query_count))
    if fetch_lines:
        route_files_with_fetch.append((relative(file), len(fetch_lines), deferred_fetch_count))

audit = subprocess.run(
    ["scripts/audit-route-first-frame.sh", "--all"],
    text=True,
    capture_output=True,
    check=False,
)

print("# Route First-Frame Inventory")
print()
print(f"Generated: {dt.date.today().isoformat()}")
print()
print("Command:")
print()
print("```bash")
print("scripts/report-route-first-frame-inventory.sh > docs/planning/route-first-frame-inventory.md")
print("```")
print()
print("## Gate")
print()
print("```text")
print((audit.stdout or audit.stderr).strip())
print("```")
print()
if audit.returncode != 0:
    print("Route first-frame audit is red; fix warnings before updating this inventory.", file=sys.stderr)
    sys.exit(audit.returncode)

print("## Current Snapshot")
print()
print("| Metric | Count |")
print("|---|---:|")
print(f"| Ohana Swift files | {len(swift_files)} |")
print(f"| Route/data container files scanned by this inventory | {len(route_files)} |")
print(f"| All `@Query` occurrences in `Ohana/` | {all_query_occurrences} |")
print(f"| All direct SwiftData `fetch` occurrences in `Ohana/` | {all_fetch_occurrences} |")
print(f"| Route/data `@Query` occurrences | {route_query_occurrences} |")
print(f"| Route/data ratchet baseline files | {len(baseline_counts)} |")
print(f"| Route/data ratchet baseline `@Query` allowance | {sum(baseline_counts.values())} |")
print(f"| Route/data direct SwiftData `fetch` occurrences | {route_fetch_occurrences} |")
print(f"| Route/data deferred fetch markers | {route_deferred_fetch_occurrences} |")
print(f"| Route/data unmarked direct fetch occurrences | {route_unmarked_fetch_occurrences} |")
print(f"| First-frame service fetch bypass patterns | {first_frame_service_fetch_occurrences} |")
print()

print("## Interpretation")
print()
print("- The active gate is strict: `scripts/audit-route-first-frame.sh --all` must pass.")
print("- This file is an inventory snapshot; the debt allowance is explicit in `docs/governance/manifests/route-first-frame-baseline.json`.")
print("- Existing route/data `@Query` subscriptions are ratcheted by file. New files default to zero, and any count above the baseline fails the audit.")
print("- Route/data container fetches are acceptable only when they are deferred after the first frame and marked with `// route-first-frame: allow deferred-fetch`.")
print("- First-frame service fetch bypasses, such as `rewards.currentHumanBalance(context:)` in render/snapshot builders, are zero-tolerance.")
print("- Non-route `@Query` / `fetch` counts are shown for future maturity work; they are not a first-frame route blocker by themselves.")
print()

print("## Route/Data Files With `@Query`")
print()
if route_files_with_query:
    print("| File | `@Query` count |")
    print("|---|---:|")
    for file, query_count in route_files_with_query:
        print(f"| `{file}` | {query_count} |")
else:
    print("None.")
print()

print("## Route/Data Files With Deferred Fetch")
print()
if route_files_with_fetch:
    print("| File | Fetch count | Deferred markers |")
    print("|---|---:|---:|")
    for file, fetch_count, deferred_count in route_files_with_fetch:
        print(f"| `{file}` | {fetch_count} | {deferred_count} |")
else:
    print("None.")
PY
