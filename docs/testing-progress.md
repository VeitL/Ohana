# 测试推进总账

> Active release and validation dashboard only. Full pre-compaction history is
> archived at [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md).
>
> Working protocol remains `docs/ai-module-test-playbook.md`. A task is not
> complete until this dashboard or `docs/task-follow-ups.md` reflects any durable
> status movement.
>
> Status ownership map: [`docs/status-ledger-map.md`](status-ledger-map.md).

## Current Release Read

- Last compacted: 2026-06-25.
- Release bar: **Open P0 = 0; first-release-reachable repo-code P1 = 0**.
- Active phase: **Phase 9A / dogfooding and real-device validation**, status 🟡.
- Open follow-ups: 11 total in `docs/task-follow-ups.md`.
- Open P1: 3 total; remaining P1s are CloudKit 1.x deferred work or
  real-device validation.
- Current local validation: Plants Oasis/shop ambience integration passed
  changed-file audits, architecture boundary audit, targeted
  `PlantLaunchTests`, `HomeCommandExecutorTests`, and `CoconutWalletServiceTests`
  on the pinned `iPhone 17` destination.

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
| 2 | Domain | 🟢 | TFU-20260612-014 closed by local current-code review; remaining Domain-adjacent P1 is deferred CloudKit 1.x work. |
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
| Domain / CloudSync | TFU-20260614-014 | CloudKit 1.x live-apply policy remains deferred while CloudKit is disabled. |
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
| 2026-06-25 | Plants Oasis/shop ambience integration | Plant care now feeds a lightweight Oasis ambience snapshot from plant-care ledger count without changing tree XP or paid care access. Lv.4 plant unlock enables lushness feedback, Lv.5 adds the Oasis-yield ambience layer, owned plant data keeps grandfather access, and the Coconut Shop now sells cosmetic-only plant decorations with inventory/equip support and Oasis stage visuals. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/audit-architecture-boundaries.sh` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests` PASS (35 Swift Testing tests); `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests -only-testing:OhanaTests/CoconutWalletServiceTests` PASS (`HomeCommandExecutorTests` 187 Swift Testing tests plus `CoconutWalletServiceTests` XCTest cases) on pinned `iPhone 17`. |
| 2026-06-25 | Plants Today Focus aggregation and pet-priority scheduling | Today Focus now lets pet care-plan events fill core slots first, emits at most one weighted plant-care quest, groups due plants by room and task type (for example, one living-room watering card for multiple plants), ranks plant groups by overdue days, health attention, task weight, and batch size, and batch completion writes each plant fact through `HomeCommandExecutor`. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/audit-architecture-boundaries.sh --all` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantFeatureGateXCTests/testQuestEngineOnlyGeneratesPlantQuestsWhenPlantCareIsIncluded` PASS (1 XCTest); `scripts/test-simulator.sh -only-testing:OhanaTests/OhanaTests` PASS (145 Swift Testing tests); `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` PASS (187 Swift Testing tests) on pinned `iPhone 17`. |
| 2026-06-25 | Plants reminder controls and notification policy | Plant reminders now have a Settings panel for global plant notification enablement, preferred reminder window, quiet weekends, travel mode, task-type muting, single-plant muting, and one-tap due-task deferral. Plant plan materialization honors task-type/user window preferences, notification policy suppresses plant pushes during travel mode and moves quiet-weekend pushes, notification payloads carry plant/task IDs for deep links, and overdue plant reminders first respect today's preferred window before falling back to immediate reminders. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/audit-architecture-boundaries.sh --all` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests` PASS (34 Swift Testing tests) on pinned `iPhone 17`. |
| 2026-06-25 | Plants explainable and learnable care plans | Plant care tasks now carry effective cadence, explanation copy, and learning summaries. Repeated wet-soil deferrals and repeated skipped watering extend watering cadence, repeated early watering shortens it, detail/dashboard surfaces show why tasks are due, Home plant care badges, calendar/reminder recurrence, and plant-care coconut eligibility read the same plan logic, and defer/skip logs remain backward compatible. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/audit-architecture-boundaries.sh --all` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests` PASS (29 Swift Testing tests) on pinned `iPhone 17`. |
| 2026-06-25 | Plants catalog and AI honesty logic | Local PlantCatalog now covers 100+ common indoor plants with aliases, Latin names, care difficulty, toxicity, light/water defaults, and ranked manual search; AddPlant shows match reason, safety, light, difficulty, and default plan chips with duplicate snapshots deferred past the first frame. Recognition policy now normalizes future provider results by deduping, clamping confidence, enriching from catalog, requiring real 3-candidate confirmation, and keeping fallback recognition empty instead of fabricating candidates. Plant Lv.4 preview energy no longer references Oasis implementation from Domain. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/audit-architecture-boundaries.sh --all` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests -only-testing:OhanaTests/PlantFeatureGateXCTests -only-testing:OhanaTests/GrowthUnlockPolicyTests` PASS (37 Swift Testing tests + 7 XCTest tests) on pinned `iPhone 17`. |
| 2026-06-25 | Plants profile creation UX safeguards | Plant add/edit/delete now warns about likely duplicate plants, applies care-relevant catalog defaults, previews which reminder/care-plan surfaces will be recalculated before saving edits, and gives destructive delete a 6-second undo window before the hard-delete command runs. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests` PASS (23 Swift Testing tests) on pinned `iPhone 17`. |
| 2026-06-25 | Plants structured environment profile | Plant profiles now persist room/location, light measurement, humidity/temperature preference, climate-source risk, drainage, acquisition, size, hydroponic, and succulent fields through SwiftData `ArkSchemaV74` and backup schema `27`; care-plan cadence and task copy now react to those fields. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/audit-release-data-safety.sh` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests -only-testing:OhanaTests/SharedModelContainerRecoveryTests -only-testing:OhanaTests/CloudSyncMetadataServiceTests -only-testing:OhanaTests/CoconutWalletServiceTests` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/SharedModelContainerRecoveryTests -only-testing:OhanaTests/CoconutWalletServiceTests/testCurrentSchemaCreatesInMemoryContainerAndKeepsLightweightStagesEmpty` PASS (5 XCTest tests). |
| 2026-06-25 | TFU-20260612-014 Domain boundary cleanup local closure | Water-care warning status now returns typed warning kinds instead of hardcoded generated titles, Home localizes the title at display time, and `LocalizationTests` lock English/German fallback behavior. Fresh current-code review found no Domain/Models SwiftUI leakage, no Domain notification singleton usage, and only allowed Domain registration comments/assertions for app-owned infrastructure. CI inspection was intentionally skipped per user instruction. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/audit-architecture-boundaries.sh --all` PASS; `scripts/audit-localization-coverage.sh` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/LocalizationTests` PASS (16 Swift Testing tests); `scripts/test-simulator.sh '-only-testing:OhanaTests/MemberLifecycleGateTests/waterCareCycleStatusUsesExplicitSnapshotInsteadOfPetCareLogRelationship()'` PASS (1 Swift Testing test) on pinned `iPhone 17`. |
| 2026-06-25 | TFU-20260625-001 onboarding UITest drift closure | Updated the shared onboarding flow helper for current first-run navigation, fixed Home feed snapshot invalidation after manual feed default changes, removed a time-dependent immediate manual-plan quick-check assertion, guarded UITest coordinate taps against non-finite frames, and added a Home signature regression test for feed defaults. Validation on pinned `iPhone 17`: `scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testCreateFirstHumanFromOnboarding` PASS; `scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testFeedingManualPlanAndHomeQuickActionSmoke` PASS; `scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testPetPermanentDeleteFromBasicInfoSmoke` PASS; `scripts/test-simulator.sh -only-testing:OhanaUITests` PASS (9 UITests); `scripts/test-simulator.sh '-only-testing:OhanaTests/HomeSnapshotBuilderTests/verticalSourceSignatureIncludesFeedDefaultChanges()'` PASS. |
| 2026-06-25 | CI release data-safety audit version alignment | CI run `28189731680` had `build-test` and `lint` green but failed `Release data-safety audit` because the audit still expected `ArkSchemaV72` and backup schema `25`. The audit was then aligned to `ArkSchemaV73` and backup schema `26`; current `ArkSchemaV74` / backup schema `27` evidence is recorded in the Plants structured environment row above. Validation: `scripts/audit-release-data-safety.sh` PASS; `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS. |
| 2026-06-25 | CI audit self-test repair after Plants push | CI run `28182441974` failed `audits` at architecture fixture self-tests because Plant views still called static plant plan/command services. Plant care-plan reads now go through `AppServices.plantCarePlans`, and plant care writes go through `HomeCommandExecutor` with `careNote` preserved for defer logs. Validation: `scripts/tests/run-audit-fixture-tests.sh` PASS; `scripts/audit-architecture-boundaries.sh --all` PASS; `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests` PASS (17 Swift Testing tests); `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` PASS (186 Swift Testing tests). |
| 2026-06-25 | TFU-20260625-002 Plants launch integration closure | Plants now materializes generated care plans into local Event/Reminder rows, honors single-plant reminder disable cleanup, refreshes the next plan after calendar/reminder/care completion, exposes dashboard location filtering and full launch-field detail editing, and has explicit Today Focus/calendar/economy/Oasis/shop coverage. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests` PASS (17 Swift Testing tests); `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` PASS (186 Swift Testing tests); `scripts/build-debug-fast.sh` PASS on pinned `iPhone 17`. |
| 2026-06-25 | Plants cross-module deep audit and gap split | Fixed Calendar/Home plant deep-link data flow and PlantCareLog backup/restore with photo/health status coverage. Validation: `scripts/dev-check-changed.sh` PASS; `scripts/test-simulator.sh -only-testing:OhanaTests/PlantLaunchTests` PASS (13 Swift Testing tests); `scripts/test-simulator.sh -only-testing:OhanaTests/AppRouteCoordinatorTests -only-testing:OhanaTests/HomeRouteCoordinatorTests -only-testing:OhanaTests/GrowthUnlockPolicyTests -only-testing:OhanaTests/PlantFeatureGateXCTests` PASS (72 route/gate tests + 5 XCTest PlantFeatureGate tests). Remaining Plants launch gap is TFU-20260625-002. |
| 2026-06-25 | Status ledger deep compaction guard | Active status ownership now lives in `docs/status-ledger-map.md`; `docs/task-follow-ups.md` remains the open backlog and `docs/testing-progress.md` remains the release/validation dashboard. Added `scripts/audit-doc-status-ledgers.sh` and wired it into `scripts/dev-check-changed.sh` for active status docs. |
| 2026-06-25 | TFU-20260623-001 Home quick-action actor-isolation cleanup | `HomeQuickActionRenderStateLogic` now owns pure quick-action render-state projection, `HomeInteractionSnapshotBuilder` no longer directly calls legacy default-MainActor helpers, and the guard still rejects `compatibilitySource`, `payload.source`, and `container.mainContext`. Validation: `git diff --check` PASS; `scripts/dev-check-changed.sh` PASS; CI YAML parse PASS; user-run Terminal targeted `scripts/test-simulator.sh -only-testing:OhanaTests/HomeReadModelStoreTests -only-testing:OhanaTests/HomeExpensePreviewStoreTests -only-testing:OhanaTests/HomeSnapshotBuilderTests` on pinned `iPhone 17` reported `TEST SUCCEEDED`. Codex shell CoreSimulator remains session-isolated and is now diagnosed by `scripts/diagnose-simulator.sh`. |
| 2026-06-25 | TFU-006 route first-frame correction after closure | Added deferred route containers for expense, insurance, documents, and milestones; `git diff --check`, `scripts/dev-check-changed.sh`, `scripts/audit-architecture-boundaries.sh --all`, `scripts/audit-localization-coverage.sh`, and targeted `scripts/test-simulator.sh '-only-testing:OhanaTests/MemberLifecycleGateTests/expenseHistoryDashboardUsesRouteScopedRowsInsteadOfPetExpenseRelationship()' '-only-testing:OhanaTests/MemberLifecycleGateTests/archiveFeatureViewsUseRouteScopedRowsInsteadOfPetRelationships()'` PASS on `iPhone 17` (2 Swift Testing tests, xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.25_07-03-31-+0200.xcresult`). |
| 2026-06-25 | P1 closure review batch | TFU-20260614-017/016/015/018/019, TFU-20260615-001, and TFU-20260614-013 marked Done from current-head guard/test evidence; raw Open P1 = 4. |
| 2026-06-25 | TFU-006 final Home/report health-alert closure | FamilyWeeklyReport and Home health alerts consume route/read-model inputs instead of relationship arrays; targeted simulator suites passed before current CoreSimulator outage. |
| 2026-06-24 | Domain generated-copy / adapter cleanup | Domain localization and adapter hard gates passed; at that time the remaining TFU-20260612-014 close condition was push/CI/fresh pure review. |
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
- Status-file consistency is guarded by `scripts/audit-doc-status-ledgers.sh`.

## Archive

- Full pre-compaction testing ledger: [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md)
- Full pre-compaction backlog: [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md)
