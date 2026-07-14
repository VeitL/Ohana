---
name: self-improving
description: Use only when the user explicitly asks to turn a repeated failure or workflow problem into a durable rule, skill, audit, fixture, or checklist. Do not use for a one-off correction, ordinary implementation, normal debugging, or a simple requested rule edit.
---

# Self-Improving

Turn a demonstrated recurring problem into the smallest durable improvement.
Assume Codex already knows general software practice; preserve only
repository-specific knowledge that prevents meaningful recurrence.

## Workflow

1. State the observed failure and concrete evidence.
2. Identify the smallest root cause rather than documenting the full episode.
3. Choose one durable target: an existing rule, skill, test, audit, fixture, or
   checklist. Prefer executable protection when the failure is mechanically
   detectable; otherwise keep the rule short.
4. Check for conflict or duplication with current repository authority.
5. Define the cheapest proof matched to the changed artifact.
6. Obtain approval before mutation unless the current user request already
   explicitly authorizes that exact kind of change.

## Required Output

Return a concise Improvement Proposal containing the evidence, root cause, one
durable change, proof, risk, and rollback. Obtain explicit user approval before
mutation unless that exact change is already authorized by the current request.

## Constraints

- Do not create a second root rule file or store raw logs, secrets, or private
  data as reusable guidance.
- Do not turn a single preference into broad policy without evidence that it
  should recur.
- Do not require a fixed multi-section report when a short proposal is clear.
- Documentation or skill-only changes do not require app builds or Simulator
  validation.
- Read files under `references/` or `templates/` only when the user asks for a
  formal improvement proposal, evaluation design, or reusable library pattern.
