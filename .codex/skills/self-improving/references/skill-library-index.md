# Skill Library Index

Use this index to store reusable patterns, not task logs.

## review-fuse-root-cause

Use when repeated findings share one root cause.
Procedure: cluster by root cause, count recurrence, stop point patches, propose a structural gate, and reserve pure review for the end.
Evidence: review history, TFU entries, and a gate or audit that makes the old bypass impossible.

## guardrail-trio

Use when doing approved architecture repair.
Procedure: characterization tests first, separate refactor and behavior commits or checkpoints, then expand-contract migration.
Evidence: tests before refactor, independent behavior-fix proof, and reversible batches.

## bad-good-audit-fixture

Use when turning a recurring rule into an audit.
Procedure: create one bad fixture that must fail with named rule ids and one good fixture that must pass; add a scanned-file floor when whole-repo scope matters.
Evidence: fixture test output and audit command output.

## proposal-before-mutation

Use when a lesson might change rules, skills, scripts, tests, or governance.
Procedure: produce an Improvement Proposal, list conflicts and rollback, then stop for approval.
Evidence: user approval before mutation.

## pure-review-no-mutation

Use when the current session is a pure review.
Procedure: classify findings, cite evidence, do not edit files, and do not claim completion based on self-repair.
Evidence: git status unchanged except explicitly allowed review notes.
