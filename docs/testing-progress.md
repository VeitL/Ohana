# 测试推进总账

> Active release and validation dashboard only. Full pre-compaction history is
> archived at [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md).
>
> Working protocol remains `docs/ai-module-test-playbook.md`. A task is not
> complete until this dashboard or `docs/task-follow-ups.md` reflects any durable
> status movement.

## Current Release Read

- Last compacted: 2026-06-25.
- Release bar: **Open P0 and first-release-reachable = 0**.
- Active phase: **Phase 9A / dogfooding and real-device validation**, status 🟡.
- Open follow-ups: 12 total in `docs/task-follow-ups.md`.
- Open P1: 4 total; none currently identified as active first-release repo-code
  work. Remaining P1s are review-gate evidence, CloudKit 1.x deferred work, or
  real-device validation.
- Current local validation: latest route first-frame correction batch passed
  cheap gates, full architecture/localization audits, and targeted simulator
  tests on the pinned `iPhone 17` destination.

## Validation Ladder

Run the narrowest trustworthy gate first:

1. `git diff --check`
2. `scripts/dev-check-changed.sh`
3. Targeted simulator tests with `scripts/test-simulator.sh` when behavior or compiler surface changes.
4. `scripts/build-debug-fast.sh` at coherent compiler-surface handoff points.
5. `scripts/module-exit-gate.sh` / CI at module or release handoff points.

Do not use generic simulator destinations to hide the pinned `iPhone 17` rule.
If simulator services are unavailable, run `scripts/diagnose-simulator.sh`, record
that as an environment blocker, and rerun simulator tests only after `simctl`
can see the pinned destination again.

## Phase Overview

| Phase | Scope | Status | Current note |
| --- | --- | --- | --- |
| 0 | Baseline cleanup | 🟢 | Submitted at `ff7ac89f`; later work may leave the tree dirty. |
| 1 | Models | 🟢 | Schema/migration gates passed; historical P0 follow-ups closed. |
| 2 | Domain | 🟢 | Local P1 closure reviews reduced remaining Domain P1 to review-gate/deferred/manual buckets. |
| 3 | Shared | 🟢 | Shared executor picker query moved out; no current blocking item. |
| 4 | App | 🟢 | Startup/route/runtime policy gates passed. |
| 5 | Home + TodayFocus + QuickCare | 🟢 | Home read-model refactor and quick-action actor-isolation cleanup are in place. |
| 6 | Large modules | 🟢 | Feeding/Members/Oasis/Settings/Health/Economy gates are recorded; real UI/device validation continues under Phase 9. |
| 6.5 | Constitution gaps | 🟢* | GAP-1/3-9/12 automatic gates passed; real-device/manual checklist remains. |
| 7 | Medium/small modules | 🟢* | Full/targeted gates passed; real UI, long-language, and device smoke remain. |
| 8 | Release-bar scan | 🟢* | P0 + first-release-reachable = 0; 🏁 is maturity, not release gate. |
| 8.5 | Online/subscription/account evolution | ⏭️ 1.x | Deferred while CloudSync `.none` / online surfaces are disabled. |
| 9 | App Store / dogfooding / RC | 🟡 | Developer Program path is available; run real-device GAP and RC checks next. |

`*` means automatic gates are green but manual/real-device acceptance debt remains.

## Module State Snapshot

| Group | Modules | State |
| --- | --- | --- |
| Mature by pure review | Economy | 🏁 |
| Core green | Models, Domain, Shared, App, Home, TodayFocus, QuickCare, Feeding, Members, Oasis, Settings, Health | 🟢 |
| Green with manual validation debt | Medication, Walks, FamilyTasks, Expenses, DashboardRecords, Calendar, CrewRoster, Gacha, Shop, Documents, Insurance, GrowthUnlock, Privacy, Achievements, Moments, Hygiene, HumanHealth, HumanNotes, Memorial, Milestones, Notifications, Onboarding, PetCare, PhotoAlbum, Plants, Security, Wishlist, Workouts, CareLedger, CatCare, FamilyReports, FunctionMenu | 🟢* |
| Deferred | GAP-10/11 and CloudKit 1.x work | 1.x |

For older module-by-module evidence, use the archive linked above.

## Active Module Pointers

Only modules with open follow-ups are listed here; closed-module evidence lives
in the archive.

| Module / Area | Open pointer | Meaning |
| --- | --- | --- |
| Domain / CloudSync | TFU-20260612-014, TFU-20260614-014 | Domain maturity review-gate plus CloudKit 1.x live-apply policy. |
| Members | TFU-20260612-018, TFU-20260612-020 | Duplicate profile revision publishes and remaining localization coverage. |
| Notifications / Memorial | TFU-20260612-016, TFU-20260612-017 | Real-device GAP-6 and GAP-9 validation. |
| Settings | TFU-20260612-022 | Final privacy/support URLs and rows. |
| Walks / Shared Care | TFU-20260611-005 | Shared walk write boundary should move to owning command/service. |
| Recycle Bin / Future Sync | TFU-20260613-003, TFU-20260613-004 | 1.x soft-delete CloudSync round-trip and restored-pet quick access. |
| Documents / Expenses | TFU-20260611-003 | Sanitized image attachment filename/content-type polish. |
| Care UI / Analysis | TFU-20260612-010 | Unified care status read models and ledger analysis expansion. |

## Active Manual / External Gates

| Gate | Status | Source |
| --- | --- | --- |
| GAP-6 notification delivery | Open P1 manual validation | `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级`, TFU-20260612-016 |
| GAP-9 memorial mode | Open P1 manual validation | `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`, TFU-20260612-017 |
| Phase 9 dogfooding / RC | In progress | real device, App Store Connect, TestFlight/RC checklist |
| CloudKit live apply policy | Deferred | TFU-20260614-014, `docs/cloud-sync-todo.md` |

## Recent Validation Snapshots

Keep this section short; move older detail to archive during compaction.

| Date | Snapshot | Evidence |
| --- | --- | --- |
| 2026-06-25 | TFU-20260623-001 Home quick-action actor-isolation cleanup | `HomeQuickActionRenderStateLogic` now owns pure quick-action render-state projection, `HomeInteractionSnapshotBuilder` no longer directly calls legacy default-MainActor helpers, and the guard still rejects `compatibilitySource`, `payload.source`, and `container.mainContext`. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; CI YAML parse PASS; user-run Terminal targeted `scripts/test-simulator.sh -only-testing:OhanaTests/HomeReadModelStoreTests -only-testing:OhanaTests/HomeExpensePreviewStoreTests -only-testing:OhanaTests/HomeSnapshotBuilderTests` on pinned `iPhone 17` reported `TEST SUCCEEDED`. Codex shell CoreSimulator remains session-isolated and is now diagnosed by `scripts/diagnose-simulator.sh`. |
| 2026-06-25 | TFU-006 route first-frame correction after closure | Added deferred route containers for expense, insurance, documents, and milestones; `git diff --check`, `scripts/dev-check-changed.sh`, `scripts/audit-architecture-boundaries.sh --all`, `scripts/audit-localization-coverage.sh`, and targeted `scripts/test-simulator.sh '-only-testing:OhanaTests/MemberLifecycleGateTests/expenseHistoryDashboardUsesRouteScopedRowsInsteadOfPetExpenseRelationship()' '-only-testing:OhanaTests/MemberLifecycleGateTests/archiveFeatureViewsUseRouteScopedRowsInsteadOfPetRelationships()'` PASS on `iPhone 17` (2 Swift Testing tests, xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_07-03-31-+0200.xcresult`). |
| 2026-06-25 | P1 closure review batch | TFU-20260614-017/016/015/018/019, TFU-20260615-001, and TFU-20260614-013 marked Done from current-head guard/test evidence; raw Open P1 = 4. |
| 2026-06-25 | TFU-006 final Home/report health-alert closure | FamilyWeeklyReport and Home health alerts consume route/read-model inputs instead of relationship arrays; targeted simulator suites passed before current CoreSimulator outage. |
| 2026-06-24 | Domain generated-copy / adapter cleanup | Domain localization and adapter hard gates passed; remaining TFU-20260612-014 close condition is push/CI/fresh pure review. |
| 2026-06-24 | Domain notification scheduler injection | Reminder notification side effects moved to injected `ReminderNotificationScheduling`; `OhanaNotifications.current` no longer appears in `Ohana/Domain`. |
| 2026-06-17 | Route first-frame infrastructure | `RouteFirstFrameDeferredLoad` and `RouteFirstFrameDeferredMount` added; strict route-first-frame audit catches first-frame `@Query` / sync fetch / service fetch regressions. |
| 2026-06-16 | Phase 8 release-bar scan | P0 + first-release-reachable cleared to zero; Phase 9 became the active release path. |
| 2026-06-16 | Full module gate / CI snapshot | `scripts/module-exit-gate.sh --full` and CI run `27607807044` passed for the then-current module state. |
| 2026-06-14 | Economy final pure review | P0=0 / P1=0 / P2=0 after Insurance expense ledger closure; Economy marked 🏁. |

## Update Rules

- This file should answer: current phase, release gate, latest validation, and where to go next.
- Do not paste long logs or every targeted test run. Keep one compact row per meaningful batch.
- Move old validation rows to the archive when the active file becomes hard to scan.
- Open follow-ups live in `docs/task-follow-ups.md`; this file should only point to them.

## Archive

- Full pre-compaction testing ledger: [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md)
- Full pre-compaction backlog: [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md)
