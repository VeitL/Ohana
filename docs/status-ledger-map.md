# Status Ledger Map

> This is the compact map for Ohana status files. It prevents status from being
> duplicated across several Markdown ledgers.

## Active Sources

| File | Owns | Does not own |
| --- | --- | --- |
| `docs/testing-progress.md` | Current release phase, release bar, latest validation snapshot, active module pointers. | Long logs, full historical module transcripts, detailed open-item descriptions. |
| `docs/task-follow-ups.md` | The active open follow-up backlog, priority, blocker, next action, and close condition. | Closed-item history, repeated validation output, detailed CloudKit device scripts. |
| `docs/cloud-sync-todo.md` | CloudKit and real-device sync work that is deferred while CloudKit is disabled or unproven. | General app P1/P2 backlog outside sync. |
| `docs/planning/gap-acceptance-track-list.md` | Manual acceptance debt that cannot be proven in repo tests or simulator-only runs. | Normal code follow-ups that can be closed by repo changes. |
| `docs/release-true-device-test-plan.md` | Chinese operator checklist for first-release physical-device testing, derived from the active ledgers. | Canonical release status, historical evidence, or follow-up ownership. |
| `docs/audits/<date>/` | Dated audit, market, release-classification, roadmap, and PR evidence for one commit. | Current release status, open-count ownership, or authority over later source changes. |
| `docs/archive/*-full-2026-06-25.md` | Full pre-compaction history for lookup. | Current status. |

## Update Rules

- If the work changes current release readiness or validation evidence, update
  `docs/testing-progress.md`.
- If the work leaves an actionable open item, update `docs/task-follow-ups.md`.
- If the item is only relevant when CloudKit is enabled, record it in
  `docs/cloud-sync-todo.md` and keep one pointer in `docs/task-follow-ups.md`
  only when it still affects release triage.
- If a manual/device check is impossible to automate now, record the checklist
  source in `docs/planning/gap-acceptance-track-list.md` and keep only the active
  blocker pointer in `docs/task-follow-ups.md`.
- If the user needs to execute true-device validation, keep
  `docs/release-true-device-test-plan.md` as the concise Chinese checklist and
  backfill pass/fail results to the owning ledger above.
- When a dated audit confirms a new current finding, add or update the owning
  active ledger in the same documentation batch. If the finding is rejected,
  record that disposition in the audit package instead. Never leave an audit
  report and the active release read asserting opposite current states.
- Do not paste full command logs into active ledgers. Keep the command name,
  result, and why it matters; archive long history during compaction.

## Guard

Run this after editing active status ledgers:

```bash
scripts/audit-doc-status-ledgers.sh
```

`scripts/dev-check-changed.sh` also runs this guard automatically when active
status ledgers or the guard itself are changed.
