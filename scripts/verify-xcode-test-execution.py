#!/usr/bin/env python3
"""Reject a successful process that did not execute its requested UI journey."""

import argparse
import collections
import json
import subprocess
import sys


def test_cases(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            yield value
        for child in value.values():
            yield from test_cases(child)
    elif isinstance(value, list):
        for child in value:
            yield from test_cases(child)


def verify(summary, tests=None, selectors=(), allow_repeated=False):
    issues = []
    executed = summary.get("passedTests", 0) + summary.get("failedTests", 0)
    if executed <= 0:
        issues.append("no test cases executed; process success is not test evidence")
    if summary.get("result") != "Passed" or summary.get("failedTests", 0) != 0:
        issues.append("result summary does not confirm a passing test run")
    if tests is None:
        return issues

    cases = list(test_cases(tests))
    identifiers = []
    for case in cases:
        identifier = case.get("nodeIdentifier", "").removesuffix("()")
        if identifier.count("/") == 1:
            identifier = "OhanaUITests/" + identifier
        if not identifier.startswith("OhanaUITests/") or identifier.count("/") != 2:
            issues.append("unidentified or synthetic UI test case: " + identifier)
        identifiers.append(identifier)
        if case.get("result") != "Passed":
            issues.append("UI case did not pass: " + identifier)
    if not cases:
        issues.append("UI result contains no original test cases")
    if len(cases) != summary.get("totalTestCount"):
        issues.append("UI case count disagrees with the result summary")
    if not allow_repeated:
        for identifier, count in collections.Counter(identifiers).items():
            if count != 1:
                issues.append("UI case executed more than once: " + identifier)

    requested = [selector.removesuffix("()") for selector in selectors]

    def matches(identifier, selector):
        return identifier == selector or identifier.startswith(selector + "/")

    for selector in requested:
        if not any(matches(identifier, selector) for identifier in identifiers):
            issues.append("requested UI selector did not execute: " + selector)
    for identifier in identifiers:
        if requested and not any(matches(identifier, selector) for selector in requested):
            issues.append("UI case executed outside the requested scope: " + identifier)
    return issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--scheme", required=True)
    parser.add_argument("--selector", action="append", default=[])
    parser.add_argument("--allow-repeated-tests", action="store_true")
    args = parser.parse_args()

    def query(kind):
        return json.loads(subprocess.check_output([
            "xcrun", "xcresulttool", "get", "test-results", kind,
            "--path", args.bundle, "--compact",
        ]))

    try:
        summary = query("summary")
        tests = query("tests") if args.scheme == "OhanaUITests" else None
        issues = verify(summary, tests, args.selector, args.allow_repeated_tests)
    except (OSError, subprocess.CalledProcessError, ValueError, TypeError, AttributeError) as error:
        issues = ["could not verify test execution: " + str(error)]
    if issues:
        for issue in issues:
            print("Test execution evidence rejected: " + issue, file=sys.stderr)
        return 66
    print("Verified executed test cases and requested UI scope.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
