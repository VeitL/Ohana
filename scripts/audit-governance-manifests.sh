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
    "release-device-matrix.json",
    "full-scope-audit-baseline.json",
    "recurring-findings-audit-baseline.json",
    "localization-hardcoded-ui-baseline.json",
    "swiftdata-save-failure-baseline.json",
    "dogfood-user-profile.json",
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

dogfood = manifests.get("dogfood-user-profile.json", {})
if dogfood:
    profile = dogfood.get("profile", {})
    first_pet = profile.get("firstPet", {})
    environment = dogfood.get("environment", {})
    readiness = dogfood.get("readiness", {})
    milestones = dogfood.get("milestones", {})
    for key in (
        "id",
        "operatorModel",
        "primaryHumanName",
        "appLanguage",
        "region",
        "currency",
        "measurementSystem",
        "timeZone",
        "initialEntitlement",
    ):
        require_text(profile, key, f"dogfood profile")
    for key in ("name", "species", "breed"):
        require_text(first_pet, key, "dogfood first Pet")
    if profile.get("operatorModel") != "one-local-operator":
        fail("dogfood profile must remain one-local-operator.")
    if profile.get("initialEntitlement") != "free":
        fail("dogfood profile must begin on the Free entitlement.")
    expected_locale = {
        "appLanguage": "en",
        "region": "DE",
        "currency": "EUR",
        "measurementSystem": "metric",
        "timeZone": "Europe/Berlin",
    }
    for key, expected in expected_locale.items():
        if profile.get(key) != expected:
            fail(f"dogfood profile {key} must remain {expected}.")
    for key in ("simulatorName", "bundleIdentifier", "configuration", "derivedDataPath"):
        require_text(environment, key, f"dogfood environment")
    if environment.get("simulatorName") != "iPhone 17 Dogfood":
        fail("dogfood environment must use the fixed iPhone 17 Dogfood name.")
    if environment.get("configuration") != "Release":
        fail("dogfood environment must use Release configuration.")
    if environment.get("bundleIdentifier") != "com.guanchen.li.Ohana":
        fail("dogfood environment must use the production app bundle identifier.")
    if environment.get("derivedDataPath") != ".build/DerivedData/dogfood":
        fail("dogfood environment must use the fixed Dogfood DerivedData lane.")
    for key in (
        "minActiveHumans",
        "minActivePets",
        "minCareRecords",
        "minCarePlans",
        "minLedgerEntries",
        "minStarterGiftLedgerEntries",
        "minCareRewardLedgerEntries",
        "minRewardedCareEvents",
        "minLinkedRewardedCareEvents",
    ):
        value = readiness.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value < 1:
            fail(f"dogfood readiness must define positive integer {key}.")
    if readiness.get("requireNoTestArtifacts") is not True:
        fail("dogfood readiness must reject test artifact files.")
    if readiness.get("requireOasisAccessUnlocked") is not True:
        fail("dogfood readiness must require product-level Oasis access.")
    if readiness.get("requireOasisVisitConfirmed") is not True:
        fail("dogfood readiness must require the first Oasis visit confirmation.")
    if readiness.get("requirePersonaLocale") is not True:
        fail("dogfood readiness must require the declared locale persona.")
    for key in (
        "requireOnboardingComplete",
        "requireActiveHumanSelection",
        "requireStarterGiftClaimed",
        "requireStarterGiftPendingCleared",
    ):
        if readiness.get(key) is not True:
            fail(f"dogfood readiness must set {key} to true.")
    for milestone_name in ("day7", "day30"):
        milestone = milestones.get(milestone_name)
        if not isinstance(milestone, dict):
            fail(f"dogfood milestones must define {milestone_name}.")
            continue
        for key in (
            "minHistoryDays",
            "minCareRecords",
            "minDistinctCareDays",
            "minWeightRecords",
            "minExpenseRecords",
            "minMoments",
        ):
            value = milestone.get(key)
            if not isinstance(value, int) or isinstance(value, bool) or value < 1:
                fail(f"dogfood {milestone_name} must define positive integer {key}.")
    day7 = milestones.get("day7", {})
    day30 = milestones.get("day30", {})
    if isinstance(day7, dict) and isinstance(day30, dict):
        for key in (
            "minHistoryDays",
            "minCareRecords",
            "minDistinctCareDays",
            "minWeightRecords",
            "minExpenseRecords",
            "minMoments",
        ):
            if isinstance(day7.get(key), int) and isinstance(day30.get(key), int):
                if day30[key] < day7[key]:
                    fail(f"dogfood day30 {key} must not be lower than day7.")

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
    warning = entry.get("warningMiB")
    hard_limit = entry.get("hardLimitMiB")
    max_growth = entry.get("maxGrowthMiB")
    if not isinstance(warning, int) or warning <= 0:
        fail(f"{where} must define positive integer warningMiB.")
    if not isinstance(hard_limit, int) or not isinstance(warning, int) or hard_limit <= warning:
        fail(f"{where} hardLimitMiB must be an integer above warningMiB.")
    if not isinstance(max_growth, int) or max_growth <= 0:
        fail(f"{where} must define positive integer maxGrowthMiB.")
    require_paths({"paths": [entry.get("path", "")]}, "paths", where)

for entry in release_resource.get("preSignChecks", []):
    where = f"pre-sign check {entry.get('id', '<missing id>')}"
    for key in ("id", "owner", "check", "releaseGate"):
        require_text(entry, key, where)
    require_paths(entry, "paths", where)

release_device = manifests.get("release-device-matrix.json", {})
if release_device:
    where = "release device matrix"
    require_text(release_device, "minimumIOS", where)
    require_text(release_device, "latestSimulatorName", where)
    require_text(release_device, "minimumHardwareAcceptance", where)

    expected_families = release_device.get("targetedDeviceFamilies")
    if expected_families != [1]:
        fail(f"{where} targetedDeviceFamilies must be exactly [1] for the approved iPhone-only release.")
    if release_device.get("nativeIPadApp") is not False:
        fail(f"{where} nativeIPadApp must be false for the approved first release.")
    if release_device.get("nativeWatchApp") is not False:
        fail(f"{where} nativeWatchApp must be false for the approved first release.")

    project_path = ROOT / "Ohana.xcodeproj" / "project.pbxproj"
    if not project_path.is_file():
        fail(f"{where} cannot find Ohana.xcodeproj/project.pbxproj.")
    else:
        project_text = project_path.read_text(encoding="utf-8")
        family_values = [
            value.strip().strip('"')
            for value in re.findall(r"TARGETED_DEVICE_FAMILY\s*=\s*([^;]+);", project_text)
        ]
        if not family_values:
            fail(f"{where} found no TARGETED_DEVICE_FAMILY settings.")
        elif any(value != "1" for value in family_values):
            fail(
                f"{where} requires every target configuration to use iPhone family 1; "
                f"found {sorted(set(family_values))}."
            )

        minimum_ios = release_device.get("minimumIOS")
        deployment_values = [
            value.strip().strip('"')
            for value in re.findall(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);", project_text)
        ]
        if not deployment_values:
            fail(f"{where} found no IPHONEOS_DEPLOYMENT_TARGET settings.")
        elif isinstance(minimum_ios, str) and any(value != minimum_ios for value in deployment_values):
            fail(
                f"{where} requires every explicit iOS deployment target to be {minimum_ios}; "
                f"found {sorted(set(deployment_values))}."
            )

        if "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad" in project_text:
            fail(f"{where} found an iPad orientation build setting in the iPhone-only project.")
        if "WATCHOS_DEPLOYMENT_TARGET" in project_text or "com.apple.product-type.application.watchapp" in project_text:
            fail(f"{where} found a native watchOS target while nativeWatchApp is false.")

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
                elif ".safeSave()" not in line and ".safeSaveResult()" not in line:
                    fail(f"{where} {path} allowed line no longer contains safeSave()/safeSaveResult(): {line}")

if failures:
    print("Governance manifest audit: failed.", file=sys.stderr)
    for item in failures:
        print(f" - {item}", file=sys.stderr)
    sys.exit(1)

print("Governance manifest audit: passed.")
PY
