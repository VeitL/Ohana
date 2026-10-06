#!/usr/bin/env python3
"""Positive and negative fixtures for SF Symbol modifier-chain ownership."""

import importlib.util
import subprocess
import sys
from pathlib import Path


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/audit-sf-symbol-accessibility.py"
spec = importlib.util.spec_from_file_location("symbol_audit", SCRIPT)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

fixtures = [
    ("own multiline hidden", 'Image(systemName: "person.fill")\n.foregroundStyle(.green)\n.accessibilityHidden(true)', 0),
    ("own multiline label", 'Image(systemName: "person.fill")\n.accessibilityLabel(Text("Person"))', 0),
    ("unlabelled", 'Image(systemName: "person.fill")', 1),
    ("sibling label", 'Image(systemName: "person.fill")\nText("Person").accessibilityLabel("Person")', 1),
    ("other image hidden", 'Image(systemName: "person.fill")\nImage(systemName: "star").accessibilityHidden(true)', 1),
    ("nested child label", 'Image(systemName: "person.fill").overlay { Text("Person").accessibilityLabel("Person") }', 1),
    ("hidden false", 'Image(systemName: "person.fill").accessibilityHidden(false)', 1),
    ("hidden override", 'Image(systemName: "person.fill").accessibilityHidden(true).accessibilityHidden(false)', 1),
    ("comment is not a label", 'Image(systemName: "person.fill") // .accessibilityHidden(true)', 1),
    ("commented image", '/* Image(systemName: "person.fill") /* nested */ */', 0),
    ("same-line sibling", 'Image(systemName: "person.fill"); Text("Person").accessibilityLabel("Person")', 1),
    ("explicit exception", 'Image(systemName: "person.fill") // a11y: allow covered by text', 0),
    ("own modifier after nested child", 'Image(systemName: "person.fill").overlay { Text("Person") }.accessibilityHidden(true)', 0),
    ("string is not code", '#"Image(systemName: "person.fill")"#', 0),
]
failures = []
for name, source, expected in fixtures:
    actual = len(list(audit.unlabelled_symbols(source)))
    if actual != expected:
        failures.append(f"{name}: expected {expected}, got {actual}")
    else:
        print(f"ok {name}")

missing = subprocess.run([sys.executable, str(SCRIPT), str(ROOT / "scripts/tests/fixtures/MissingSymbolFixture.swift")], capture_output=True)
if missing.returncode == 0:
    failures.append("unreadable input falsely passed")
else:
    print("ok unreadable input fails closed")

if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)
print(f"SF Symbol accessibility fixtures passed: {len(fixtures) + 1} cases.")
