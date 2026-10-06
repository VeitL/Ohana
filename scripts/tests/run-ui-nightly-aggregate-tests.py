#!/usr/bin/env python3
"""Exercise the acceptance gate with incomplete, conflicting and failed runs."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "aggregate-ui-nightly-receipts.py"
SPEC = importlib.util.spec_from_file_location("ui_aggregate", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
REVISION = "a" * 40


class AcceptanceFixtures(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ohana-ui-aggregate-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.manifest = self.root / "manifest.tsv"
        self.manifest.write_text("alpha\tOhanaUITests/Fixture/testOne\nalpha\tOhanaUITests/Fixture/testTwo\nbeta\tOhanaUITests/Fixture/testThree\n")
        self.plan = MODULE.read_plan(self.manifest)
        self.evidence = self.root / "evidence"
        self.evidence.mkdir()
        for index, (name, selectors) in enumerate(self.plan.items()):
            count = len(selectors)
            counts = {"planned": count, "executed": count, "passed": count, "failures": 0, "skipped": 0}
            record = {"name": name, **counts, "infrastructureFailures": 0, "result": "passed", "exitCode": 0,
                      "missingSelectors": [], "duplicateSelectors": [], "unexpectedSelectors": [], "evidenceErrors": []}
            document = {"schema": "ohana.ui-nightly-receipt.v1", "endedAt": "2026-10-01T00:00:00Z",
                "source": {"revision": REVISION, "dirty": False, "sourceTreeSHA256": "b" * 64},
                "environment": {"xcode": {"version": "Xcode 26.6\nBuild version 17F113", "developerDirectory": "/Applications/Xcode_26.6.app/Contents/Developer"},
                    "sdk": {"name": "iphonesimulator", "version": "26.5", "buildVersion": "23F81a"}, "configuration": "Debug",
                    "simulator": {"name": "iPhone 17 Tests", "os": "iOS 26.5", "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-5", "udid": f"isolated-runner-{index}"}},
                "frozenInputs": {"manifest": {"path": "scripts/ui-test-shards.tsv", "sha256": hashlib.sha256(self.manifest.read_bytes()).hexdigest()},
                    **{key: "c" * 64 for key in ("nightlyScriptSHA256", "shardScriptSHA256", "auditScriptSHA256", "xcodeTestScriptSHA256", "testSimulatorScriptSHA256")}},
                "command": {"selectedShard": name, "failurePolicy": "collect-all-shards"},
                "plan": {"tests": count, "shards": 1, "derivedFromAuditedManifest": True}, "shards": [record],
                "summary": {**counts, "infrastructureFailures": 0, "plannedShards": 1, "recordedShards": 1, "completedShards": 1},
                "result": {"status": "passed", "exitCode": 0, "integritySatisfied": True}}
            self.write_receipt(name, document)
            self.log_path(name).write_text("".join(self.terminal(selector, "passed") for selector in selectors))

    def receipt_path(self, name):
        return self.evidence / f"ohana-ui-nightly-{name}.json"

    def log_path(self, name):
        return self.evidence / f"ui-nightly-{name}.log"

    def write_receipt(self, name, document):
        self.receipt_path(name).write_text(json.dumps(document))

    def change(self, action, name="alpha"):
        document = json.loads(self.receipt_path(name).read_text())
        action(document)
        self.write_receipt(name, document)

    @staticmethod
    def terminal(selector, result):
        module, class_name, method = selector.split("/")
        return f"Test Case '-[{module}.{class_name} {method}]' {result} (0.001 seconds).\n"

    def result(self, jobs="success"):
        return MODULE.aggregate(self.manifest, self.evidence, REVISION, jobs)

    def assert_red(self):
        document = self.result()
        self.assertEqual(document["result"]["exitCode"], 65)
        self.assertFalse(document["result"]["fullAcceptanceSatisfied"])
        return document

    def outcome(self, result):
        selector = self.plan["alpha"][0]
        self.log_path("alpha").write_text(self.terminal(selector, result) + self.terminal(self.plan["alpha"][1], "passed"))
        def change(document):
            for counts in (document["summary"], document["shards"][0]):
                counts["passed"] = 1
                counts["failures" if result == "failed" else "skipped"] = 1
            document["shards"][0].update(result="failed", exitCode=65)
            document["result"].update(status="failed", exitCode=65, integritySatisfied=False)
        self.change(change)

    def test_complete_plan_and_distinct_runner_identities_pass(self):
        self.assertEqual(self.result()["result"]["exitCode"], 0)
        self.assertEqual(self.result()["summary"]["executed"], 3)

    def test_failed_group_does_not_hide_later_passing_group(self):
        self.outcome("failed")
        document = self.assert_red()
        self.assertEqual(document["summary"]["executed"], 3)
        self.assertEqual(document["summary"]["passed"], 2)
        self.assertEqual(document["summary"]["failures"], 1)
        self.assertEqual(document["evidenceErrors"], [])

    def test_skipped_is_not_passed(self):
        self.outcome("skipped")
        self.assertEqual(self.assert_red()["summary"]["skipped"], 1)

    def test_missing_group_reports_not_run(self):
        self.receipt_path("beta").unlink()
        self.log_path("beta").unlink()
        self.assertEqual(self.assert_red()["summary"]["notRun"], 1)

    def test_missing_log_cannot_use_receipt_counts_as_proof(self):
        self.log_path("alpha").unlink()
        self.assertEqual(self.assert_red()["summary"]["notRun"], 2)

    def test_duplicate_receipt_is_rejected(self):
        folder = self.evidence / "duplicate"
        folder.mkdir()
        (folder / self.receipt_path("alpha").name).write_bytes(self.receipt_path("alpha").read_bytes())
        self.assert_red()

    def test_duplicate_terminal_result_is_rejected(self):
        with self.log_path("alpha").open("a") as handle:
            handle.write(self.terminal(self.plan["alpha"][0], "passed"))
        self.assert_red()

    def test_unplanned_terminal_result_is_rejected(self):
        with self.log_path("alpha").open("a") as handle:
            handle.write(self.terminal("OhanaUITests/Fixture/testUnplanned", "passed"))
        self.assert_red()

    def test_log_receipt_disagreement_is_rejected(self):
        self.log_path("alpha").write_text(self.terminal(self.plan["alpha"][0], "failed") + self.terminal(self.plan["alpha"][1], "passed"))
        self.assert_red()

    def test_interrupted_checkpoint_is_not_final(self):
        self.change(lambda document: document["result"].update(status="running"))
        self.assert_red()

    def test_incomplete_shard_checkpoint_is_rejected(self):
        self.change(lambda document: document["summary"].update(completedShards=0))
        self.assert_red()

    def test_invalid_evidence_remains_red(self):
        self.change(lambda document: document["shards"][0].update(evidenceErrors=["source changed"]))
        self.assert_red()

    def test_wrong_revision_and_dirty_source_are_rejected(self):
        for key, value in (("revision", "d" * 40), ("dirty", True), ("sourceTreeSHA256", "d" * 64)):
            with self.subTest(key=key):
                original = json.loads(self.receipt_path("alpha").read_text())
                self.change(lambda document: document["source"].update({key: value}))
                self.assert_red()
                self.write_receipt("alpha", original)

    def test_toolchain_and_manifest_mismatch_are_rejected(self):
        original = json.loads(self.receipt_path("alpha").read_text())
        changes = [lambda document: document["environment"]["sdk"].update(version="27.0"),
                   lambda document: document["environment"]["simulator"].update(name="iPhone 17 Dogfood"),
                   lambda document: document["frozenInputs"]["manifest"].update(sha256="d" * 64),
                   lambda document: document["frozenInputs"].update(shardScriptSHA256="d" * 64)]
        for index, action in enumerate(changes):
            with self.subTest(index=index):
                self.change(action)
                self.assert_red()
                self.write_receipt("alpha", copy.deepcopy(original))

    def test_malformed_receipt_still_writes_missing_summary(self):
        self.receipt_path("alpha").write_text("{broken")
        self.assert_red()

    def test_workflow_failure_or_cancellation_cannot_be_green(self):
        for status in ("failure", "cancelled", "skipped"):
            self.assertEqual(self.result(status)["result"]["exitCode"], 65)

    def test_cli_writes_summary_before_returning_failure(self):
        self.outcome("failed")
        output = self.root / "summary.json"
        completed = subprocess.run([sys.executable, str(SCRIPT), "--manifest", str(self.manifest),
            "--evidence", str(self.evidence), "--revision", REVISION, "--output", str(output)], capture_output=True, text=True)
        self.assertEqual(completed.returncode, 65)
        self.assertEqual(json.loads(output.read_text())["summary"]["executed"], 3)
        self.assertIn("Failed: OhanaUITests/Fixture/testOne", completed.stdout)

    def test_matrix_is_manifest_derived_and_duplicate_manifest_rejected(self):
        matrix = subprocess.check_output([sys.executable, str(SCRIPT), "--manifest", str(self.manifest), "--matrix"], text=True)
        self.assertEqual(json.loads(matrix), {"shard": ["alpha", "beta"]})
        with self.manifest.open("a") as handle:
            handle.write("beta\tOhanaUITests/Fixture/testOne\n")
        with self.assertRaises(ValueError):
            MODULE.read_plan(self.manifest)


if __name__ == "__main__":
    unittest.main()
