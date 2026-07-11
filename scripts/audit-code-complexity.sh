#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-code-complexity.sh [--changed|--all|--soft|--write-baseline] [Swift files or directories...]

Purpose:
  Keep production logic complexity on a shrinking ratchet without promoting
  the mature codebase's existing debt into hundreds of blocking lint errors.
  The audit tracks each declaration by file, rule, and normalized declaration
  text, so line movement stays quiet while new or growing hotspots fail.

Defaults:
  function body > 120 lines
  type body > 800 lines
  cyclomatic complexity > 25
  function parameters > 10

  Tests, generated sources, localization/catalog data, and Settings DesignLab
  are excluded because these rules are intended to guard production behavior.
USAGE
}

mode="changed"
strict=1
write_baseline=0
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
    --write-baseline)
      mode="all"
      write_baseline=1
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

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: swiftlint is required for the complexity audit." >&2
  exit 2
fi

if [[ ${#targets[@]} -gt 0 ]]; then
  mode="targeted"
fi

body_limit="${OHANA_COMPLEXITY_FUNCTION_BODY_LIMIT:-120}"
type_limit="${OHANA_COMPLEXITY_TYPE_BODY_LIMIT:-800}"
complexity_limit="${OHANA_COMPLEXITY_CYCLOMATIC_LIMIT:-25}"
parameter_limit="${OHANA_COMPLEXITY_PARAMETER_LIMIT:-10}"
baseline_path="${OHANA_COMPLEXITY_BASELINE:-docs/governance/manifests/code-complexity-baseline.json}"

for value in "$body_limit" "$type_limit" "$complexity_limit" "$parameter_limit"; do
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: complexity thresholds must be positive integers." >&2
    exit 2
  fi
done

changed_swift_files() {
  {
    git diff --name-only --diff-filter=ACMR HEAD -- Ohana 2>/dev/null || true
    git ls-files --others --exclude-standard -- Ohana 2>/dev/null || true
  } | awk '/\.swift$/ { print }' | sort -u
}

swift_scope() {
  if [[ ${#targets[@]} -gt 0 ]]; then
    for target in "${targets[@]}"; do
      if [[ -d "$target" ]]; then
        find "$target" -type f -name '*.swift' | sort
      elif [[ -f "$target" && "$target" == *.swift ]]; then
        printf '%s\n' "$target"
      fi
    done
  elif [[ "$mode" == "all" ]]; then
    find Ohana -type f -name '*.swift' | sort
  else
    changed_swift_files
  fi
}

is_excluded() {
  case "$1" in
    Ohana/Features/Settings/DesignLab/*|\
    Ohana/Shared/Localization.swift|\
    Ohana/Shared/Media/PetAvatarAssetCatalog.swift|\
    Ohana/Features/Plants/PlantCatalog.swift|\
    Ohana/Features/Plants/PlantCatalogLocalization.swift|\
    *.generated.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

files=()
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  if [[ "$file" == "$repo_root/"* ]]; then
    file="${file#"$repo_root/"}"
  fi
  if ! is_excluded "$file"; then
    files+=("$file")
  fi
done < <(swift_scope | sort -u)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Code complexity: no Swift files to scan."
  exit 0
fi

config_file="$(mktemp "${TMPDIR:-/tmp}/ohana-code-complexity-config.XXXXXX.yml")"
output_file="$(mktemp "${TMPDIR:-/tmp}/ohana-code-complexity-output.XXXXXX.json")"
error_file="$(mktemp "${TMPDIR:-/tmp}/ohana-code-complexity-error.XXXXXX.log")"
trap 'rm -f "$config_file" "$output_file" "$error_file"' EXIT

python3 - "$config_file" "$body_limit" "$type_limit" "$complexity_limit" "$parameter_limit" <<'PY'
from pathlib import Path
import sys

path, body, type_body, complexity, parameters = sys.argv[1:]
Path(path).write_text(
    f"""only_rules:
  - function_body_length
  - type_body_length
  - cyclomatic_complexity
  - function_parameter_count
function_body_length:
  warning: {body}
  error: {body}
type_body_length:
  warning: {type_body}
  error: {type_body}
cyclomatic_complexity:
  warning: {complexity}
  error: {complexity}
function_parameter_count:
  warning: {parameters}
  error: {parameters}
""",
    encoding="utf-8",
)
PY

swiftlint_status=0
swiftlint lint \
  --config "$config_file" \
  --quiet \
  --force-exclude \
  --reporter json \
  --no-cache \
  "${files[@]}" >"$output_file" 2>"$error_file" || swiftlint_status=$?

if ! python3 - "$output_file" <<'PY'
import json
import sys

try:
    value = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if isinstance(value, list) else 1)
PY
then
  echo "error: SwiftLint did not produce valid JSON for the complexity audit (status ${swiftlint_status})." >&2
  cat "$error_file" >&2
  exit 2
fi

if [[ "$write_baseline" == "0" && "$mode" != "targeted" && ! -f "$baseline_path" ]]; then
  echo "error: missing complexity baseline: $baseline_path" >&2
  exit 2
fi

comparison_status=0
python3 - \
  "$output_file" \
  "$baseline_path" \
  "$repo_root" \
  "$mode" \
  "$write_baseline" \
  "$body_limit" \
  "$type_limit" \
  "$complexity_limit" \
  "$parameter_limit" \
  "${#files[@]}" <<'PY' || comparison_status=$?
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from urllib.parse import unquote, urlparse

(
    output_path,
    baseline_path,
    repo_root,
    mode,
    write_baseline_raw,
    body_limit,
    type_limit,
    complexity_limit,
    parameter_limit,
    file_count,
) = sys.argv[1:]
write_baseline = write_baseline_raw == "1"
thresholds = {
    "function_body_length": int(body_limit),
    "type_body_length": int(type_limit),
    "cyclomatic_complexity": int(complexity_limit),
    "function_parameter_count": int(parameter_limit),
}


def relative_file(raw: str) -> str:
    if raw.startswith("file://"):
        raw = unquote(urlparse(raw).path)
    root = repo_root.rstrip("/") + "/"
    return raw[len(root):] if raw.startswith(root) else raw


def measured_value(reason: str) -> int:
    values = re.findall(r"\d+", reason)
    return int(values[-1]) if values else 0


raw_violations = json.load(open(output_path, encoding="utf-8"))
groups = defaultdict(lambda: {"count": 0, "maximum": 0})
source_lines = {}
for item in raw_violations:
    rule = item.get("rule_id", "unknown")
    raw_path = item.get("file", "")
    path = relative_file(raw_path)
    signature = item.get("text", "").strip()
    if not signature:
        source_path = Path(raw_path)
        lines = source_lines.get(source_path)
        if lines is None:
            try:
                lines = source_path.read_text(encoding="utf-8").splitlines()
            except OSError:
                lines = []
            source_lines[source_path] = lines
        line = int(item.get("line", 0))
        if 0 < line <= len(lines):
            signature = lines[line - 1].strip()
    signature = " ".join((signature or "<unknown declaration>").split())
    key = (path, rule, signature)
    groups[key]["count"] += 1
    groups[key]["maximum"] = max(groups[key]["maximum"], measured_value(item.get("reason", "")))

entries = [
    {
        "file": path,
        "rule": rule,
        "signature": signature,
        "count": values["count"],
        "maximum": values["maximum"],
    }
    for (path, rule, signature), values in sorted(groups.items())
]

if write_baseline:
    payload = {
        "version": 1,
        "thresholds": thresholds,
        "entries": entries,
    }
    target = Path(baseline_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Code complexity: wrote {len(entries)} baseline declaration(s) from {file_count} file(s) to {baseline_path}.")
    raise SystemExit(0)

issues = []
if mode == "targeted":
    issues = [(entry, None, "targeted violation") for entry in entries]
    grandfathered = 0
else:
    baseline = json.load(open(baseline_path, encoding="utf-8"))
    if baseline.get("version") != 1:
        print(f"error: unsupported complexity baseline version in {baseline_path}.", file=sys.stderr)
        raise SystemExit(2)
    if baseline.get("thresholds") != thresholds:
        print(
            f"error: complexity thresholds do not match {baseline_path}; update the baseline only with an intentional threshold change.",
            file=sys.stderr,
        )
        raise SystemExit(2)
    baseline_groups = {
        (entry["file"], entry["rule"], entry["signature"]): entry
        for entry in baseline.get("entries", [])
    }
    grandfathered = 0
    for entry in entries:
        key = (entry["file"], entry["rule"], entry["signature"])
        previous = baseline_groups.get(key)
        if previous is None:
            issues.append((entry, None, "new hotspot"))
            continue
        grandfathered += 1
        if entry["count"] > previous.get("count", 0):
            issues.append((entry, previous, "violation count grew"))
        elif entry["maximum"] > previous.get("maximum", 0):
            issues.append((entry, previous, "measured complexity grew"))

if not issues:
    print(
        f"Code complexity: passed ({file_count} file(s), {grandfathered} grandfathered declaration(s), no new or growing hotspots)."
    )
    raise SystemExit(0)

print(f"Code complexity: failed ({file_count} file(s)).")
for entry, previous, reason in issues:
    baseline_summary = "none" if previous is None else f"count={previous['count']}, maximum={previous['maximum']}"
    print(f"\n[{entry['rule']}]\n{entry['file']}: {entry['signature']}")
    print(
        f"{reason}; current count={entry['count']}, maximum={entry['maximum']}; baseline {baseline_summary}."
    )
raise SystemExit(1)
PY

if [[ "$comparison_status" -eq 2 ]]; then
  exit 2
fi
if [[ "$comparison_status" -ne 0 && "$strict" == "1" ]]; then
  exit 1
fi
exit 0
