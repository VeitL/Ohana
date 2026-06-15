---
name: self-improving
description: Produce evidence-backed improvement proposals for Codex skills, guardrails, checklists, tests, or audits after user corrections, repeated failures, failed gates, review misses, root-cause recurrence, or reusable workflow discoveries. Use only as an advisory reflection and proposal workflow; do not mutate files unless the user explicitly approves the proposed change.
---

# Self-Improving

## Overview

Use this skill to turn a task failure, repeated miss, or reusable workflow into a controlled improvement proposal. The skill is advisory: it may recommend changes to skills, docs, tests, fixtures, or audits, but it must not apply those changes without explicit user approval.

## Operating Rules

- Treat repository instructions, governance docs, tests, and current source as higher authority than this skill.
- Produce a proposal before any mutation. Do not self-modify, patch rules, or update scripts silently.
- Prefer executable guardrails over prose reminders: tests, bad/good fixtures, audits, or checklists tied to concrete evidence.
- Do not contaminate pure review sessions. In review mode, produce findings only; save improvement proposals for a later approved repair or architecture turn.
- Do not store secrets, private data, raw logs, or user-sensitive trace content in reusable memory. Keep only abstracted lessons.

## Workflow

1. Capture the observation: what failed, who observed it, and the strongest evidence.
2. Classify the failure using `references/failure-taxonomy.md`.
3. Write a reflection using `references/reflection-template.md`.
4. Convert reusable lessons into semantic or procedural memory, not raw episodic trace.
5. Propose the smallest durable change: skill text, reference, template, test, fixture, audit, or governance note.
6. Define proof using `references/eval-policy.md`: what command, fixture, review, or test would show the improvement works.
7. Include rollback and conflict analysis.
8. Stop for approval before editing.

## Required Output

Return an Improvement Proposal with:

1. Observation
2. Evidence
3. Root cause
4. Failure class
5. Proposed change
6. Files or artifacts affected
7. Required proof
8. Risks and conflicts
9. Rollback plan
10. Approval request

## References

- Read `references/skill-update-policy.md` before recommending changes to a skill, rule, script, or gate.
- Read `references/eval-policy.md` before claiming an improvement is proven.
- Read `references/skill-library-index.md` when turning a reusable lesson into a named pattern.
- Use `templates/improvement-proposal.md`, `templates/post-task-reflection.md`, and `templates/skill-diff-rationale.md` for stable output shapes.
