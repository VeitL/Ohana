# Ohana AI Module Review and Change Playbook

Status: Active engineering workflow

Owner: Repository maintainer

Last reviewed: 2026-07-11

This playbook defines how an AI coding agent reviews, changes, validates, and
hands off one Ohana module. Product behavior comes from
`docs/specs/product-foundation.md`; repository authority and safety rules come
from `AGENTS.md`. If this playbook conflicts with either source, stop and use
the higher-authority source.

The superseded v2 phase plan is retained only as historical evidence at
`docs/archive/ai-module-test-playbook-v2-2026-07-10.md`.

## Test Portfolio Rules

These four rules are mandatory:

1. Prove every business rule with Unit/Integration tests. UI tests may prove
   navigation and visible integration, but they must not act as database,
   ledger, migration, reward, or cache auditors.
2. Keep one high-value UI path per module in the normal change lane. Do not
   multiply UI tests for every button permutation when the rule can be proved
   below the UI.
3. For every P0/P1 risk, test failure, recovery/retry, and repeated operation or
   idempotency. A happy-path-only test does not close a P0/P1 item.
4. Run tests at a frequency proportional to risk. Rounded corners and copy use
   cheap audits; a changed rule uses targeted Unit/Integration tests; broad
   module hand-offs use the full unit lane; the complete UI portfolio is a
   nightly/RC lane, not a per-edit tax.

## Required Reading

Read only what the task needs, in this order:

1. `AGENTS.md` for authority, navigation, safety, and validation rules.
2. `docs/specs/product-foundation.md` for product decisions and invariants.
3. The relevant `docs/specs/*-logic.md` file, if one exists.
4. `ui规范.selection.json` before any UI or shared-component change.
5. The governance document named by `AGENTS.md` for the affected risk class.
6. `docs/testing-progress.md` and `docs/task-follow-ups.md` only when the task
   changes durable release status or creates/closes a real follow-up.

Do not treat dated audit reports, planning files, archive material, or design
exports as current requirements. `docs/README.md` classifies those documents.

## Authority Matrix

| User request | Allowed repository mutation | Remote or release authority |
| --- | --- | --- |
| Review, audit, explain, diagnose, or report status | Read-only checks; write a report only when the user explicitly asks for a file | None |
| Change, fix, build, or refactor | Focused source, test, script, and directly related documentation changes | None by default |
| Commit | Only when the current user explicitly asks to commit | Commit only; no push |
| Push, open a PR, or run remote CI | Only the exact action explicitly requested | Limited to that action |
| Signing, provisioning, capability, entitlement, App Store Connect, or release work | Only when explicitly requested, with the requested scope | Limited to that action |
| New branch, worktree, or parallel session | Only when explicitly requested or after the user approves a concrete isolation need | None unless separately granted |

A broad instruction such as “finish”, “fix everything”, or “continue” expands
the in-repository task scope only as reasonably necessary. It does not grant
commit, push, remote-CI, signing, entitlement, deletion, or release authority.

## Read-Only Review Protocol

When the user requests a read-only review:

1. Start with `git status --short` and preserve all existing changes.
2. Inspect the complete task-relevant file set; do not infer content from names.
3. Separate code/document evidence, runtime evidence, inference, and unverified
   assumptions.
4. Run non-mutating builds, tests, lint, or audits when useful and available.
5. Do not modify source, tests, status ledgers, or rule files. A requested report
   file is the only exception.
6. State every command actually run and distinguish failures from “not run”.

“Analyze first” means no file mutation during that analysis pass. Do not mark a
module in progress or rewrite its logic specification before the user has
authorized an implementation task.

## Implementation Workflow

### 1. Establish the baseline

- Run `git status --short`.
- Identify the exact feature, domain boundary, reachable user path, and risk
  class.
- Read the relevant code, tests, product rules, and governance rules.
- Record assumptions only when they materially affect the solution.

### 2. Reconstruct the current behavior

For a business-bearing module, identify:

- entities, inputs, outputs, and the single source of truth;
- preconditions, invariants, state transitions, and failure recovery;
- persistence, deletion, privacy, time, cancellation, and idempotency behavior;
- derived effects such as rewards, reminders, tasks, notifications, read-model
  revisions, backups, and future sync metadata;
- existing automated and manual proof.

If two product interpretations would produce materially different behavior,
stop and ask the user. Do not block on cosmetic choices that can be inferred
from existing project patterns.

### 3. Choose the smallest root-cause fix

- Group findings that share one root cause.
- Prefer the narrowest change that enforces the real invariant at its owner.
- Do not rewrite a module merely to match an architectural preference.
- Escalate before schema, entitlement, signing, release configuration, or
  cross-feature product behavior changes that the user did not request.
- Preserve unrelated work and existing public behavior unless the requested fix
  requires changing it.

### 4. Add proportionate proof

- Add a regression test for behavior defects when the behavior is testable.
- Use in-memory SwiftData containers for persistence and domain tests.
- For P0/P1 work, failure, recovery/retry, and repeat/idempotency are required;
  add cancellation, deletion/privacy, and lifecycle cases when applicable.
- Use UI tests only for behavior that Unit/Integration tests cannot prove, and
  select one high-value module path for the normal change lane.
- Never weaken an existing assertion merely to make a refactor pass.

### 5. Validate locally

Start with the narrowest trustworthy command and escalate by risk:

```bash
scripts/dev-check-changed.sh
scripts/test-simulator.sh -only-testing:OhanaTests/<RelevantTests>
scripts/build-debug-fast.sh
scripts/module-exit-gate.sh
scripts/module-exit-gate.sh --test OhanaTests/<RelevantTests>
scripts/module-exit-gate.sh --unit
scripts/module-exit-gate.sh --full
```

`scripts/module-exit-gate.sh` without arguments is the low-risk changed/static
lane and does not start Xcode. `--test` may be repeated for targeted
Unit/Integration selectors and, only when the changed user flow needs it, one
high-value UI selector. `--unit` runs all `OhanaTests`; `--full` adds whole-repo
audits. Full UI shards run through `scripts/test-ui-nightly.sh` at nightly or RC
frequency.

Use the UI, accessibility, runtime, privacy, localization, persistence, and
release audits required by `AGENTS.md`. Local SwiftLint, SwiftFormat, and audit
scripts are real evidence when they run successfully; do not claim those gates
exist only in CI. A successful build does not prove runtime behavior, real
device permissions, background delivery, energy use, iCloud, or App Store
configuration.

### 6. Update durable status only when it changed

- `docs/testing-progress.md`: compact current release and validation status.
- `docs/task-follow-ups.md`: only open blockers, external validation, important
  deferred repairs, or cross-scope work.
- `docs/planning/gap-acceptance-track-list.md`: true-device/manual acceptance.
- `docs/cloud-sync-todo.md`: future CloudKit work while the Solo gate is closed.

Do not paste long command transcripts into active ledgers. Put dated evidence
in `docs/audits/<date>/` or the appropriate archive and link to it. Do not create
a follow-up merely because a nice-to-have improvement exists.

### 7. Hand off honestly

Report:

- outcome and files changed;
- commands run and their actual result;
- what is not runtime- or device-verified;
- remaining risks and their active-ledger IDs, if any;
- whether commit, push, remote CI, signing, or release actions were not requested
  and therefore were not performed.

## Module Review Checklist

For every business-bearing module, check the applicable rows:

| Area | Questions |
| --- | --- |
| Product fit | Is the path first-release reachable? Does it match D1-D23 and G1-G8? |
| Ownership | Does one service or command own the business fact and its invariant? |
| State | Is source-of-truth ownership clear? Is derived state recomputed or invalidated correctly? |
| Concurrency | Are tasks structured, cancellable, actor-safe, idempotent, and protected from stale responses? |
| Persistence | Are writes atomic enough for the invariant? Are schema and migration rules followed? |
| Lifecycle | Do delete, memorial, reset, background, relaunch, and interrupted operations recover correctly? |
| Privacy | Are restricted data, logs, backups, exports, routes, and field-level access consistently filtered? |
| Performance | Is the interaction first-frame light? Are broad queries, decoding, timers, and aggregation gated? |
| Accessibility | Do labels, values, focus, target size, Dynamic Type, motion, and color semantics hold? |
| Localization | Are Chinese and English authored and registered-language fallbacks preserved? |
| Testing | Do tests cover the invariant and the important failure/recovery boundary rather than implementation detail? |

FamilyTasks/online collaboration is future-gated in the Solo release. Plants is
first-release reachable and must receive the same business, persistence,
performance, accessibility, and test scrutiny as other launch modules.

## Parallel and Git Safety

Default to the current worktree and a single session. Do not create a branch or
worktree merely because multiple files are involved. If isolation would
materially reduce a real conflict, explain the conflict and obtain approval
before creating it.

Never overwrite, revert, stage, commit, or push unrelated user changes. Never
use destructive Git commands without an explicit request. Commit structure can
be recommended, but no commit is created until the user asks.

## Definition of Done

A module change is complete only when:

- the requested behavior and its real invariant are implemented;
- the change is limited to the authorized scope;
- regression proof exists at the appropriate layer;
- required local gates pass, or failures are reported with exact causes;
- no privacy, persistence, concurrency, accessibility, or capability claim is
  stronger than the evidence;
- active ledgers reflect any durable blocker or closure without duplicating
  dated evidence;
- the handoff names unverified simulator, physical-device, cloud, energy, and
  App Store assumptions;
- no commit, push, worktree, remote CI, signing, entitlement, or release action
  occurred without explicit authorization.
