# Failure Taxonomy

Use the smallest class that explains the miss. Multiple classes are allowed when the evidence supports them.

## Classes

- `missing-rule`: The workflow had no rule for a required invariant.
- `weak-rule`: A rule existed, but it was advisory prose rather than a required step, test, or audit.
- `wrong-precedence`: The agent followed a lower-priority source over the current request, AGENTS.md, governance docs, tests, or current code.
- `point-patch`: The agent fixed one manifestation of a cross-cutting root cause instead of proposing a structural gate.
- `review-fuse-missed`: A repeated root cause should have triggered review fuse or architecture work.
- `test-washing`: A test was changed or written to bless behavior that contradicts a higher rule.
- `missing-fixture`: An audit or guardrail lacked bad/good fixtures, so rule drift could go unnoticed.
- `weak-evidence`: The claimed verification did not cover the requirement's real scope.
- `tooling-gap`: A deterministic script, parser, audit, or template is needed because the same work is being rewritten.
- `memory-gap`: A useful reusable lesson exists only in conversation context and should become a skill pattern or checklist.

## Escalation

If the same class recurs across turns or features, prefer a structural proposal: type gate, command chokepoint, audit with fixtures, or mandatory checklist. Do not recommend another point patch for a cross-cutting invariant.
