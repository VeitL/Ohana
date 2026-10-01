#!/usr/bin/env python3
"""Collect isolated manifest shards; never turn missing/partial evidence green."""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile


TERMINAL = re.compile(
    r"^\s*Test Case '-\[([^.\]\s]+)\.([^\]\s]+) (test[A-Za-z0-9_]+)\]' "
    r"(passed|failed|skipped)\b"
)
COUNTS = ("planned", "executed", "passed", "failures", "skipped")


def read_plan(path):
    plan = {}
    selectors = set()
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 2:
            raise ValueError(f"Manifest line {number}: expected two fields")
        name, selector = fields
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
            raise ValueError(f"Manifest line {number}: invalid shard name")
        if not re.fullmatch(r"OhanaUITests/[A-Za-z_][A-Za-z0-9_]*/test[A-Za-z0-9_]+", selector):
            raise ValueError(f"Manifest line {number}: invalid selector")
        if selector in selectors:
            raise ValueError(f"Manifest line {number}: duplicate selector {selector}")
        selectors.add(selector)
        plan.setdefault(name, []).append(selector)
    if not plan:
        raise ValueError("Empty UI manifest")
    return plan


def atomic_json(path, document):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as handle:
            json.dump(document, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def aggregate(manifest, evidence, revision, jobs_result=None):
    plan = read_plan(manifest)
    errors = []
    reference_source = reference_environment = reference_inputs = None
    records, cases = [], []
    manifest_hash = hashlib.sha256(manifest.read_bytes()).hexdigest()
    expected_files = {f"ohana-ui-nightly-{name}.json" for name in plan}
    for path in evidence.rglob("ohana-ui-nightly-*.json"):
        if path.name not in expected_files:
            errors.append(f"Unexpected receipt: {path.name}")

    def check(condition, message):
        if not condition:
            errors.append(message)

    for name, selectors in plan.items():
        receipt_paths = list(evidence.rglob(f"ohana-ui-nightly-{name}.json"))
        log_paths = list(evidence.rglob(f"ui-nightly-{name}.log"))
        receipt = None
        if len(receipt_paths) != 1:
            errors.append(f"{name}: expected one receipt, found {len(receipt_paths)}")
        else:
            try:
                receipt = json.loads(receipt_paths[0].read_text())
                if not isinstance(receipt, dict):
                    raise ValueError("receipt is not an object")
            except (ValueError, OSError) as exc:
                errors.append(f"{name}: unreadable receipt: {exc}")
                receipt = None
        events = {}
        if len(log_paths) != 1:
            errors.append(f"{name}: expected one complete log, found {len(log_paths)}")
        else:
            for line in log_paths[0].read_text(errors="replace").splitlines():
                match = TERMINAL.match(line)
                if not match:
                    continue
                module, class_name, method, outcome = match.groups()
                selector = f"{module}/{class_name}/{method}"
                if selector not in selectors:
                    errors.append(f"{name}: unexpected terminal selector {selector}")
                elif selector in events:
                    errors.append(f"{name}: duplicate terminal selector {selector}")
                else:
                    events[selector] = outcome
        missing = [selector for selector in selectors if selector not in events]
        counts = collections.Counter(events.values())
        observed = {"planned": len(selectors), "executed": len(events),
                    "passed": counts["passed"], "failures": counts["failed"],
                    "skipped": counts["skipped"]}
        record = {"name": name, **observed, "notRun": len(missing),
                  "missingSelectors": missing, "receipt": str(receipt_paths[0]) if len(receipt_paths) == 1 else None,
                  "log": str(log_paths[0]) if len(log_paths) == 1 else None,
                  "status": "missing", "completed": False, "infrastructureFailures": 0}
        cases.extend({"selector": selector, "shard": name, "result": events[selector]}
                     for selector in selectors if selector in events)
        if missing:
            errors.append(f"{name}: {len(missing)} planned selectors have no terminal result")
        if receipt is not None:
            try:
                source, environment, inputs = receipt["source"], receipt["environment"], receipt["frozenInputs"]
                check(receipt["schema"] == "ohana.ui-nightly-receipt.v1", f"{name}: wrong receipt schema")
                check(source["revision"] == revision and source["dirty"] is False, f"{name}: wrong revision or dirty source")
                check(bool(re.fullmatch(r"[0-9a-f]{64}", source["sourceTreeSHA256"] or "")), f"{name}: invalid frozen source hash")
                check(inputs["manifest"]["sha256"] == manifest_hash, f"{name}: manifest hash mismatch")
                check(set(inputs) == {"manifest", "nightlyScriptSHA256", "shardScriptSHA256", "auditScriptSHA256",
                                      "xcodeTestScriptSHA256", "testSimulatorScriptSHA256"}, f"{name}: incomplete governed inputs")
                check(all(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value)
                          for key, value in inputs.items() if key != "manifest"), f"{name}: invalid governed input hash")
                check(receipt["command"]["selectedShard"] == name, f"{name}: receipt belongs to another shard")
                check(receipt["command"]["failurePolicy"] == "collect-all-shards", f"{name}: wrong failure policy")
                check(receipt["plan"] == {"tests": len(selectors), "shards": 1, "derivedFromAuditedManifest": True}, f"{name}: wrong plan")
                check(len(receipt["shards"]) == 1 and receipt["shards"][0]["name"] == name, f"{name}: wrong recorded shard set")
                item = receipt["shards"][0]
                for key in COUNTS:
                    check(type(item[key]) is int and type(receipt["summary"][key]) is int
                          and item[key] == observed[key] and receipt["summary"][key] == observed[key], f"{name}: {key} receipt/log mismatch")
                check(receipt["summary"]["plannedShards"] == receipt["summary"]["recordedShards"] == receipt["summary"]["completedShards"] == 1,
                      f"{name}: incomplete receipt checkpoint")
                for key in ("missingSelectors", "duplicateSelectors", "unexpectedSelectors", "evidenceErrors"):
                    check(not item[key], f"{name}: receipt reports {key}")
                record["infrastructureFailures"] = item["infrastructureFailures"]
                check(item["infrastructureFailures"] == receipt["summary"]["infrastructureFailures"] == 0, f"{name}: infrastructure failure")
                result = receipt["result"]
                record["status"] = result["status"]
                record["exitCode"] = result["exitCode"]
                record["completed"] = result["status"] in ("passed", "failed") and receipt["endedAt"] is not None and receipt["summary"]["completedShards"] == 1
                check(result["status"] in ("passed", "failed") and receipt["endedAt"] is not None, f"{name}: interrupted/nonfinal receipt")
                if observed["failures"] or observed["skipped"] or missing:
                    check(item["result"] == result["status"] == "failed" and item["exitCode"] != 0 and result["exitCode"] != 0 and result["integritySatisfied"] is False,
                          f"{name}: failed/missing/skipped cases misreported as success")
                else:
                    check(item["result"] == result["status"] == "passed" and item["exitCode"] == result["exitCode"] == 0 and result["integritySatisfied"] is True,
                          f"{name}: passing cases lack a successful completion gate")
                comparable_environment = {"xcode": environment["xcode"], "sdk": environment["sdk"],
                    "configuration": environment["configuration"],
                    "simulator": {key: environment["simulator"][key] for key in ("name", "os", "runtimeIdentifier")}}
                check(comparable_environment["simulator"]["name"] == "iPhone 17 Tests", f"{name}: non-Tests simulator")
                check(environment["sdk"]["name"] == "iphonesimulator", f"{name}: wrong SDK")
                check(environment["xcode"]["version"].splitlines()[0] == "Xcode 26.6"
                      and environment["sdk"]["version"] == "26.5"
                      and comparable_environment["simulator"]["os"] == "iOS 26.5"
                      and comparable_environment["simulator"]["runtimeIdentifier"] == "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
                      and environment["configuration"] == "Debug", f"{name}: pinned CI stack not satisfied")
                if reference_source is None:
                    reference_source, reference_environment, reference_inputs = source, comparable_environment, inputs
                else:
                    check(source == reference_source, f"{name}: source differs across shards")
                    check(comparable_environment == reference_environment, f"{name}: toolchain/runtime differs across shards")
                    check(inputs == reference_inputs, f"{name}: governed inputs differ across shards")
            except (KeyError, IndexError, TypeError, ValueError, AttributeError) as exc:
                errors.append(f"{name}: invalid receipt fields: {exc}")
        records.append(record)
    if jobs_result is not None:
        check(jobs_result == "success", f"Workflow shard jobs concluded {jobs_result}")
    summary = {key: sum(item[key] for item in records) for key in COUNTS}
    summary.update(notRun=sum(item["notRun"] for item in records), plannedShards=len(plan),
                   recordedShards=sum(item["receipt"] is not None for item in records),
                   completedShards=sum(item["completed"] for item in records),
                   infrastructureFailures=sum(item["infrastructureFailures"] for item in records))
    passed = not errors and summary["executed"] == summary["planned"] and summary["failures"] == summary["skipped"] == 0
    return {"schema": "ohana.ui-regression-aggregate.v1", "revision": revision,
            "source": reference_source, "environment": reference_environment,
            "manifestSHA256": manifest_hash, "workflowShardJobsResult": jobs_result,
            "summary": summary, "shards": records, "cases": cases, "evidenceErrors": errors,
            "result": {"status": "passed" if passed else "failed", "exitCode": 0 if passed else 65,
                       "fullAcceptanceSatisfied": passed},
            "limitations": "Terminal counts plus frozen receipts prove execution scope. Failure root causes require preserved xcresult attachments; no physical-device or release evidence is claimed."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path(__file__).with_name("ui-test-shards.tsv"))
    parser.add_argument("--matrix", action="store_true")
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--revision")
    parser.add_argument("--jobs-result", choices=("success", "failure", "cancelled", "skipped"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.matrix:
        print(json.dumps({"shard": list(read_plan(args.manifest))}, separators=(",", ":")))
        return 0
    if args.evidence is None or args.output is None or not re.fullmatch(r"[0-9a-f]{40}", args.revision or ""):
        parser.error("aggregation requires --evidence, --output and a full --revision")
    document = aggregate(args.manifest, args.evidence, args.revision, args.jobs_result)
    atomic_json(args.output, document)
    summary = document["summary"]
    lines = [f"UI: {summary['executed']}/{summary['planned']} executed; {summary['passed']} passed, "
             f"{summary['failures']} failed, {summary['skipped']} skipped, {summary['notRun']} not run."]
    lines += [f"Failed: {case['selector']}" for case in document["cases"] if case["result"] == "failed"]
    lines += [f"Evidence: {error}" for error in document["evidenceErrors"]]
    print("\n".join(lines))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as handle:
            handle.write("\n".join(lines) + "\n")
    return document["result"]["exitCode"]


if __name__ == "__main__":
    raise SystemExit(main())
