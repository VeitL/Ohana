#!/usr/bin/env python3
"""Fixtures for false process success, UI coverage, and result identity."""

import importlib.util
from pathlib import Path
import unittest

source = Path(__file__).resolve().parents[1] / "verify-xcode-test-execution.py"
spec = importlib.util.spec_from_file_location("execution_evidence", source)
execution = importlib.util.module_from_spec(spec)
spec.loader.exec_module(execution)


def summary(passed=1, failed=0, skipped=0, result="Passed"):
    return {"result": result, "passedTests": passed, "failedTests": failed,
            "skippedTests": skipped, "totalTestCount": passed + failed + skipped}


def tree(*cases):
    return {"testNodes": [{"nodeType": "Test Suite", "children": [
        {"nodeType": "Test Case", "nodeIdentifier": identifier, "result": result}
        for identifier, result in cases
    ]}]}


class ExecutionEvidenceTests(unittest.TestCase):
    def test_zero_execution_rejects_exit_zero(self):
        self.assertTrue(execution.verify(summary(passed=0)))

    def test_unknown_result_rejects(self):
        self.assertTrue(execution.verify(summary(result="unknown")))

    def test_unit_execution_without_ui_identity_is_valid(self):
        self.assertEqual(execution.verify(summary(passed=2585)), [])

    def test_failed_summary_rejects(self):
        self.assertTrue(execution.verify(summary(failed=1)))

    def test_exact_ui_selector_executes(self):
        self.assertEqual(execution.verify(summary(), tree(("Case/testOne()", "Passed")),
                                          ["OhanaUITests/Case/testOne"]), [])

    def test_parenthesized_ui_selector_executes(self):
        self.assertEqual(execution.verify(summary(), tree(("Case/testOne()", "Passed")),
                                          ["OhanaUITests/Case/testOne()"]), [])

    def test_suite_selector_expands_to_all_its_cases(self):
        self.assertEqual(execution.verify(summary(passed=2), tree(
            ("Case/testOne()", "Passed"), ("Case/testTwo()", "Passed")),
            ["OhanaUITests/Case"]), [])

    def test_missing_selected_case_rejects_partial_pass(self):
        self.assertTrue(execution.verify(summary(), tree(("Case/testOne()", "Passed")),
                                         ["OhanaUITests/Case/testOne", "OhanaUITests/Case/testTwo"]))

    def test_wrong_case_does_not_satisfy_selector(self):
        self.assertTrue(execution.verify(summary(), tree(("Case/testOneExtra()", "Passed")),
                                         ["OhanaUITests/Case/testOne"]))

    def test_duplicate_case_rejects(self):
        self.assertTrue(execution.verify(summary(passed=2), tree(
            ("Case/testOne()", "Passed"), ("Case/testOne()", "Passed"))))

    def test_explicit_repetition_is_distinct_from_release_acceptance(self):
        self.assertEqual(execution.verify(summary(passed=2), tree(
            ("Case/testOne()", "Passed"), ("Case/testOne()", "Passed")),
            allow_repeated=True), [])

    def test_skipped_ui_case_rejects(self):
        self.assertTrue(execution.verify(summary(skipped=1), tree(
            ("Case/testOne()", "Passed"), ("Case/testTwo()", "Skipped"))))

    def test_synthetic_node_is_not_an_original_journey(self):
        self.assertTrue(execution.verify(summary(), tree(("Runner Failure", "Passed"))))

    def test_summary_count_mismatch_rejects(self):
        self.assertTrue(execution.verify(summary(passed=2), tree(("Case/testOne()", "Passed"))))


if __name__ == "__main__":
    unittest.main()
