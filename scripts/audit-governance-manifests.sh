#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for stale_rule_dir in .cursor .windsurf; do
  if [[ -e "$stale_rule_dir" ]]; then
    echo "Governance manifest audit: failed." >&2
    echo " - $stale_rule_dir must not exist; AGENTS.md is the only root rule file." >&2
    exit 1
  fi
done

for stale_rule_file in CONTEXT.md UIRules.md RULES.md INSTRUCTIONS.md CLAUDE.md GEMINI.md .cursorrules; do
  if [[ -e "$stale_rule_file" ]]; then
    echo "Governance manifest audit: failed." >&2
    echo " - $stale_rule_file must not exist; AGENTS.md is the only root agent/navigation rule file." >&2
    exit 1
  fi
done

python3 - <<'PY'
from __future__ import annotations

import glob
import json
import pathlib
import re
import sys

ROOT = pathlib.Path.cwd()
MANIFEST_DIR = ROOT / "docs" / "governance" / "manifests"

REQUIRED_FILES = [
    "feature-ownership.json",
    "cache-ownership.json",
    "performance-slo.json",
    "privacy-ownership.json",
    "runtime-energy-ownership.json",
    "release-resource-ownership.json",
    "full-scope-audit-baseline.json",
    "recurring-findings-audit-baseline.json",
    "localization-hardcoded-ui-baseline.json",
    "swiftdata-save-failure-baseline.json",
]

failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def load(name: str) -> dict:
    path = MANIFEST_DIR / name
    if not path.is_file():
        fail(f"Missing manifest: {path.relative_to(ROOT)}")
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {exc}")
        return {}


def require_text(obj: dict, key: str, where: str) -> None:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip() or value.strip().upper() == "TBD":
        fail(f"{where} must define non-empty {key}.")


def require_list(obj: dict, key: str, where: str) -> None:
    value = obj.get(key)
    if not isinstance(value, list) or not value:
        fail(f"{where} must define non-empty {key}.")


def require_paths(obj: dict, key: str, where: str) -> None:
    value = obj.get(key)
    if not isinstance(value, list) or not value:
        fail(f"{where} must define non-empty {key}.")
        return
    for raw in value:
        if not isinstance(raw, str) or not raw.strip():
            fail(f"{where} contains an empty path in {key}.")
            continue
        matches = glob.glob(str(ROOT / raw), recursive=True)
        if not matches and not (ROOT / raw).exists():
            fail(f"{where} references missing path: {raw}")


def require_policy_docs(data: dict, name: str) -> None:
    require_list(data, "policyDocuments", name)
    for doc in data.get("policyDocuments", []):
        if isinstance(doc, str) and doc.strip() and not (ROOT / doc).exists():
            fail(f"{name} references missing policy document: {doc}")


manifests = {name: load(name) for name in REQUIRED_FILES}
swift_source = "\n".join(
    path.read_text(encoding="utf-8", errors="ignore")
    for path in (ROOT / "Ohana").rglob("*.swift")
)
swift_symbols = set(
    re.findall(
        r"\b(?:class|struct|enum|protocol|actor|typealias)\s+([A-Z][A-Za-z0-9_]*)\b",
        swift_source,
    )
)

for name, data in manifests.items():
    if not data:
        continue
    require_text(data, "schema", name)
    require_text(data, "updated", name)
    require_policy_docs(data, name)

feature = manifests.get("feature-ownership.json", {})
for entry in feature.get("features", []):
    where = f"feature {entry.get('id', '<missing id>')}"
    for key in ("id", "owner", "risk", "businessWriteBoundary"):
        require_text(entry, key, where)
    for key in ("activationTriggers", "routes", "services", "readModels", "tests", "sloIds"):
        require_list(entry, key, where)
    require_paths(entry, "ownedPaths", where)
    for raw_service in entry.get("services", []):
        if not isinstance(raw_service, str):
            fail(f"{where} services entries must be strings.")
            continue
        service_tokens = re.findall(r"\b[A-Z][A-Za-z0-9_]{2,}\b", raw_service)
        for token in service_tokens:
            if token not in swift_symbols:
                fail(
                    f"{where} services references unknown Swift symbol '{token}' "
                    f"in '{raw_service}'. Use a real type name or move prose outside services."
                )

cache = manifests.get("cache-ownership.json", {})
for entry in cache.get("caches", []):
    where = f"cache {entry.get('id', '<missing id>')}"
    for key in ("id", "owner", "scope", "sourceOfTruth", "invalidation", "expiry", "recovery"):
        require_text(entry, key, where)
    require_paths(entry, "paths", where)

performance = manifests.get("performance-slo.json", {})
for entry in performance.get("flows", []):
    where = f"performance flow {entry.get('id', '<missing id>')}"
    for key in ("id", "owner", "interactionClass", "measurement", "evidence"):
        require_text(entry, key, where)
    for key in ("budgets", "probeNames"):
        require_list(entry, key, where)
    require_paths(entry, "paths", where)
    for probe in entry.get("probeNames", []):
        if not isinstance(probe, str) or not probe.strip():
            fail(f"{where} contains an empty probeNames entry.")
        elif probe not in swift_source:
            fail(f"{where} probe is not present in Swift source: {probe}")

privacy = manifests.get("privacy-ownership.json", {})
for entry in privacy.get("surfaces", []):
    where = f"privacy surface {entry.get('id', '<missing id>')}"
    for key in ("id", "owner", "storage", "userControl", "manifestEvidence"):
        require_text(entry, key, where)
    for key in ("dataCategories", "deletionPaths", "exportPaths"):
        require_list(entry, key, where)
    require_paths(entry, "paths", where)

runtime = manifests.get("runtime-energy-ownership.json", {})
for entry in runtime.get("runtimeSurfaces", []):
    where = f"runtime surface {entry.get('id', '<missing id>')}"
    for key in (
        "id",
        "owner",
        "scope",
        "visibilityGate",
        "lowPowerGate",
        "reduceMotionGate",
        "backgroundGate",
        "policyGate",
        "evidence",
    ):
        require_text(entry, key, where)
    require_list(entry, "runtimeClasses", where)
    require_paths(entry, "paths", where)

release_resource = manifests.get("release-resource-ownership.json", {})
for entry in release_resource.get("resourceBudgets", []):
    where = f"resource budget {entry.get('id', '<missing id>')}"
    for key in ("id", "owner", "path", "rationale", "releaseGate", "evidence"):
        require_text(entry, key, where)
    limit = entry.get("limitMiB")
    if not isinstance(limit, int) or limit <= 0:
        fail(f"{where} must define positive integer limitMiB.")
    require_paths({"paths": [entry.get("path", "")]}, "paths", where)

for entry in release_resource.get("preSignChecks", []):
    where = f"pre-sign check {entry.get('id', '<missing id>')}"
    for key in ("id", "owner", "check", "releaseGate"):
        require_text(entry, key, where)
    require_paths(entry, "paths", where)

full_scope = manifests.get("full-scope-audit-baseline.json", {})
if full_scope:
    where = "full-scope audit baseline"
    promotion = full_scope.get("promotionTarget")
    if not isinstance(promotion, dict):
        fail(f"{where} must define promotionTarget commands.")
    audits = full_scope.get("audits")
    if not isinstance(audits, dict):
        fail(f"{where} must define audits.")
    else:
        for audit_name in ("ui-v4", "accessibility", "smoothness"):
            audit = audits.get(audit_name)
            if not isinstance(audit, dict):
                fail(f"{where} missing audit: {audit_name}")
                continue
            require_text(audit, "command", f"{where} {audit_name}")
            total = audit.get("totalWarnings")
            if not isinstance(total, int) or total < 0:
                fail(f"{where} {audit_name} must define non-negative totalWarnings.")
            rules = audit.get("rules")
            if not isinstance(rules, dict):
                fail(f"{where} {audit_name} must define rules.")
                continue
            rule_total = 0
            for rule_id, rule_data in rules.items():
                if not isinstance(rule_data, dict):
                    fail(f"{where} {audit_name}.{rule_id} must be an object.")
                    continue
                files = rule_data.get("files")
                if not isinstance(files, dict):
                    fail(f"{where} {audit_name}.{rule_id} must define files.")
                    continue
                file_total = 0
                for path, count in files.items():
                    if not isinstance(path, str) or not path.endswith(".swift"):
                        fail(f"{where} {audit_name}.{rule_id} has invalid path: {path}")
                    if not isinstance(count, int) or count < 0:
                        fail(f"{where} {audit_name}.{rule_id} has invalid count for {path}.")
                    else:
                        file_total += count
                declared = rule_data.get("totalWarnings")
                if not isinstance(declared, int) or declared != file_total:
                    fail(
                        f"{where} {audit_name}.{rule_id} totalWarnings must equal "
                        f"sum(files): {declared} != {file_total}"
                    )
                rule_total += file_total
            if isinstance(total, int) and total != rule_total:
                fail(f"{where} {audit_name} totalWarnings must equal rule totals: {total} != {rule_total}")

recurring = manifests.get("recurring-findings-audit-baseline.json", {})
if recurring:
    where = "recurring findings audit baseline"
    audits = recurring.get("audits")
    if not isinstance(audits, dict):
        fail(f"{where} must define audits.")
    else:
        for audit_name in ("economy-boundaries", "derived-state-lifecycle"):
            audit = audits.get(audit_name)
            if not isinstance(audit, dict):
                fail(f"{where} missing audit: {audit_name}")
                continue
            require_text(audit, "command", f"{where} {audit_name}")
            total = audit.get("totalWarnings")
            if not isinstance(total, int) or total < 0:
                fail(f"{where} {audit_name} must define non-negative totalWarnings.")
            rules = audit.get("rules")
            if not isinstance(rules, dict):
                fail(f"{where} {audit_name} must define rules.")
                continue
            rule_total = 0
            for rule_id, rule_data in rules.items():
                if not isinstance(rule_data, dict):
                    fail(f"{where} {audit_name}.{rule_id} must be an object.")
                    continue
                files = rule_data.get("files")
                if not isinstance(files, dict):
                    fail(f"{where} {audit_name}.{rule_id} must define files.")
                    continue
                file_total = 0
                for path, count in files.items():
                    if not isinstance(path, str) or not path.endswith(".swift"):
                        fail(f"{where} {audit_name}.{rule_id} has invalid path: {path}")
                    if not isinstance(count, int) or count < 0:
                        fail(f"{where} {audit_name}.{rule_id} has invalid count for {path}.")
                    else:
                        file_total += count
                declared = rule_data.get("totalWarnings")
                if not isinstance(declared, int) or declared != file_total:
                    fail(
                        f"{where} {audit_name}.{rule_id} totalWarnings must equal "
                        f"sum(files): {declared} != {file_total}"
                    )
                rule_total += file_total
            if isinstance(total, int) and total != rule_total:
                fail(f"{where} {audit_name} totalWarnings must equal rule totals: {total} != {rule_total}")

localization_baseline = manifests.get("localization-hardcoded-ui-baseline.json", {})
if localization_baseline:
    where = "localization hardcoded UI baseline"
    require_text(localization_baseline, "purpose", where)
    require_text(localization_baseline, "command", where)
    allowed = localization_baseline.get("allowedMatches")
    if not isinstance(allowed, dict):
        fail(f"{where} must define allowedMatches.")
    else:
        for path, lines in allowed.items():
            if not isinstance(path, str) or not path.endswith(".swift"):
                fail(f"{where} has invalid Swift path: {path}")
                continue
            if not (ROOT / path).is_file():
                fail(f"{where} references missing Swift file: {path}")
            if not isinstance(lines, list) or not lines:
                fail(f"{where} {path} must define non-empty allowed lines.")
                continue
            for line in lines:
                if not isinstance(line, str) or not line.strip():
                    fail(f"{where} {path} contains an empty allowed line.")
                elif not re.search(r"[\u3400-\u9fff]", line):
                    fail(f"{where} {path} allowed line no longer contains Chinese text: {line}")

save_failure_baseline = manifests.get("swiftdata-save-failure-baseline.json", {})
if save_failure_baseline:
    where = "SwiftData save failure baseline"
    require_text(save_failure_baseline, "purpose", where)
    require_text(save_failure_baseline, "command", where)
    allowed = save_failure_baseline.get("allowedMatches")
    if not isinstance(allowed, dict):
        fail(f"{where} must define allowedMatches.")
    else:
        for path, lines in allowed.items():
            if not isinstance(path, str) or not path.endswith(".swift"):
                fail(f"{where} has invalid Swift path: {path}")
                continue
            if not (ROOT / path).is_file():
                fail(f"{where} references missing Swift file: {path}")
            if not isinstance(lines, list) or not lines:
                fail(f"{where} {path} must define non-empty allowed lines.")
                continue
            for line in lines:
                if not isinstance(line, str) or not line.strip():
                    fail(f"{where} {path} contains an empty allowed line.")
                elif ".safeSave()" not in line:
                    fail(f"{where} {path} allowed line no longer contains safeSave(): {line}")

if failures:
    print("Governance manifest audit: failed.", file=sys.stderr)
    for item in failures:
        print(f" - {item}", file=sys.stderr)
    sys.exit(1)

print("Governance manifest audit: passed.")
PY
