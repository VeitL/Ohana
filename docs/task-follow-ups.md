# Task Follow-ups

> Active backlog only. Full pre-compaction history is archived at
> [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md).
>
> Release bar: first release is blocked only by **P0 and first-release-reachable**
> issues. P1/P2/P3, CloudKit `.none` work, feature-gated work, and manual device
> validation remain visible here but do not automatically block shipping.
>
> Status ownership map: [`docs/status-ledger-map.md`](status-ledger-map.md).

## Current Read

- Last compacted: 2026-06-25.
- Open follow-ups: 12 total: P1 = 3, P2 = 7, P3 = 2.
- Open P0: 0.
- Known first-release-reachable repository-code P1: none.
- P1 still open because of CloudKit 1.x deferred work or real-device validation.

## How To Update

- Keep only active work in this file. When a follow-up closes, add one short
  `Closed:` line and then move details to the archive during the next compaction.
- New entries must include: priority, reachability/bucket, blocker, next action,
  and close condition.
- Long command logs, full review transcripts, and repeated progress bullets do
  not belong here; put the durable evidence in `docs/testing-progress.md` or an
  archive note.
- After changing this file, run `scripts/audit-doc-status-ledgers.sh` or
  `scripts/dev-check-changed.sh` so the summary counts and active pointers stay
  aligned.

## P1 Triage

| Bucket | TFUs | Meaning | Next move |
| --- | --- | --- | --- |
| First-release-reachable repository code | None | No current repository-code P1 blocks the first release bar. | Keep this bucket empty unless a reachable launch blocker is found by current-code evidence. |
| Review-gate / likely implemented locally | None | No current Domain review-gate P1 remains open after the 2026-06-25 local closure pass. | Keep this bucket empty unless a fresh pure review finds current-code P1 evidence. |
| Deferred 1.x / first-release-unreachable | TFU-20260614-014 | CloudSync live-apply delete-wins, parent lifecycle, and natural identity are real work, but unreachable while `cloudKitDatabase: .none`. | Keep in CloudKit 1.x planning; do not mix into first-release burn-down unless CloudKit is enabled. |
| External/manual validation | TFU-20260612-017, TFU-20260612-016 | Real iOS notification/UI behavior must be checked on device. Repo tests cannot close these alone. | Run GAP-9 and GAP-6 manual checklists on a physical device. |

## Open Items

### TFU-20260614-014 - Enforce CloudSync Live-Apply Deletion Wins, Parent Lifecycle, And Natural Identity

- Priority / bucket: P1, deferred CloudKit 1.x / first-release-unreachable.
- Status: Open while CloudKit is disabled.
- Why still open: live remote apply can resurrect newer remote `Pet`/`Human` rows over local tombstones, accept child records after parent deletion, and duplicate `GachaOwnedItem` ownership by random id instead of natural key.
- Next action: add red tests for delete-wins, parent active/existence gating, and Gacha owned-item natural-key merge; then implement one CloudSync apply disposition layer.
- Close when: those tests fail before and pass after the policy layer, CloudSync/physical-deletion/home/economy/derived audits pass, and a fresh Domain review reports P0/P1 = 0 for the reachable surface.

### TFU-20260612-017 - Validate GAP-9 Memorial Mode On Real UI And Device Notifications

- Priority / bucket: P1, external/manual validation.
- Status: Open; paid-team signing path is verified, but real memorial notification/UI behavior is not.
- Why still open: simulator and unit tests cannot prove real iOS notification cancellation, restoration, or final memorial-mode visible behavior.
- Next action: run the GAP-9 manual checklist in `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`.
- Close when: real-device checklist is checked off and any device-specific defect is fixed or split into a scoped follow-up.

### TFU-20260612-016 - Validate GAP-6 Notification Delivery On Real Devices

- Priority / bucket: P1, external/manual validation.
- Status: Open; paid-team Push/iCloud entitlement signing path is verified, but notification delivery is not.
- Why still open: repo tests cannot prove banners, permission prompts, Focus/DND interaction, or notification action behavior on physical devices.
- Next action: run the GAP-6 manual checklist in `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级`.
- Close when: real-device checklist is checked off and any delivery/routing defect is fixed or split into a scoped follow-up.

### TFU-20260613-004 - Restore Pet Quick-Access Derived State

- Priority / bucket: P2, recycle-bin/member restore polish.
- Status: Open.
- Why still open: member deletion removes pet quick-access entries; restore currently does not recreate or recompute that derived state.
- Next action: decide intended restored-pet product behavior, then recreate previous quick access or recompute defaults during restore.
- Close when: restored pets have approved quick-action availability and a focused regression test covers it.

### TFU-20260629-004 - Finish Pet Simulator GUI Deep Coverage

- Priority / bucket: P2, Pet simulator validation / UI-test coverage gap.
- Status: Open.
- Why still open: the pinned `iPhone 17` pet GUI coverage now passes first-pet onboarding, production-overlay first-pet onboarding, feeding manual/reminder quick actions with anti-repeat confirmation, permanent delete from basic info, delete cancel/wrong-name protection, Water detail route open/close plus write/readback through `QuickWaterCommandExecutor.recordWater` / `CareEventService.recordCareFact`, Water quick-care reward readback into Pet Bond Vault positive balance plus recent economy log, Water plan reminder save/delete Calendar pet-filter readback with localized title matching, Play quick-tap responsiveness, Feature Hub route-open coverage for potty, hygiene, walk, and health, Potty detail write/readback through `QuickPottyCommandExecutor.record` / `CareEventService.recordPottyFact`, cat litter scoop write/readback plus same-day repeat-submit guard coverage and cat litter full-change write/readback coverage through `QuickPottyCommandExecutor.recordLitterCare` / `CareEventService.recordCareFact`, cat litter plan reminder cancel/save/delete coverage through the quick-potty settings sync boundary, full litter-change reminder save/delete Calendar pet-filter readback with localized title matching, scoop-plan reminder save/delete Calendar list-view pet-filter readback with localized plan-title matching, Hygiene detail write/readback plus same-day repeat-tap guard coverage through `PetHygieneCommandExecutor` / `CareEventService.recordHygieneFact`, Health visit-record cancel/save write/readback through `PetHealthCommandExecutor.recordHealth` / `CareEventService`, Pet Basic Info memorial mark/undo cancel-confirm coverage through member lifecycle commands, memorial-pet Home live-care entry hiding after relaunch, stale Calendar event live-care route blocking after memorial, stale Calendar cleanup after permanent delete, Pet Basic Info edit cancel/save persistence coverage, Pet Basic Info empty-name save protection/readback coverage, Walk Home quick-action start/stop plus summary persistence/readback coverage through `WalkTrackingCommandExecutor.stopWalk` / `PetWalkingManager.stop`, Calendar pet-linked event creation/filter readback through `CalendarCommandExecutor.createEvent(input:)`, and a suite-level Calendar recheck covering linked Pet Basic Info, Water detail, Feeding detail, Potty detail, Walk Summary, Play detail, Weight detail, Health detail, and Hygiene detail through `FocusHomeReminderDeepLinkRouter` without starting walk tracking from the row tap. Pet Bond Vault Feature Hub entry, zero-balance blocked-unlock readback, seeded positive unlock/spend readback through the UI-test Debug Coconuts shortcut, and Coconut Shop pet-effect purchase of Lime Glow through Home FAB -> Function Menu -> confirmation popup -> 1000🥥 to 700🥥 balance readback also pass. The real-user long-session coverage now keeps one Human and one Cat across first-pet creation, feeding setup, Home feed quick check-in and repeat confirmation, Water write/readback, Potty litter settings cancel/save, litter scoop write/readback and repeat disabled state, Hygiene write/readback and repeat guard, Health cancel/save write/readback, Calendar pet-linked event create/filter/readback, Bond Vault low-balance block, seeded positive unlock/spend, return navigation, sheet close paths, and Home re-entry state without resetting between each feature. A second real-user long-session keeps one Human and one Dog across Dog walk start/stop/readback, app relaunch state retention, Basic Info edit cancel/save readback, memorial mark/undo cancel-confirm paths, and permanent delete wrong-name/cancel/exact-name safeguards. A new existing-user no-reset smoke now first reuses any Home Human/Pet, seeds only if the simulator is in a damaged empty state, then covers Water write/readback, Calendar pet event create/filter/readback, Bond Vault balance readback, and same-test relaunch retention. A separate `xcodebuild test` command still did not preserve the app container reliably, so true old-user reuse across separate commands remains a harness/manual-runner gap. The latest 40-test selected pet GUI suite executed 40 selected tests with 38 passing on the first broad run; both failures were harness issues, not product write failures: stale deleted-pet card lookup called `isHittable` on an invalid XCTest element, and the Cat long-session Quick Feed path needed the existing frame-ready tap fallback when XCTest reported an enabled primary action as non-hittable. After hardening those UI-test helpers, the two focused reruns passed on the same pinned simulator. Earlier reruns also exposed a narrower product/readback gap: immediately after saving QuickFeed manual defaults, the Home feed quick-action accessibility label can still read `待设置` even though the subsequent quick-feed write and repeat confirmation work. The suite still does not exercise broader pet calendar care-type/deep-link paths beyond Basic Info/Water/Feeding/Potty/Walk/Play/Weight/Health/Hygiene and generated litter/scoop/water plan rows, broader pet shop/economy purchases beyond Bond Vault plus one Lime Glow effect purchase, deceased-pet Feature Hub non-memorial route blocking beyond stale Calendar event taps, stale-route protection after memorial/delete beyond stale Calendar event taps, broader edit-negative paths beyond empty-name protection, reminder/task/ledger cross-feature paths in one long scenario beyond the covered Bond Vault ledger path, or that immediate Home feed-label refresh after saving feeding defaults.
- Next action: continue remaining negative and cross-feature GUI paths through pet calendar care-type deep-linking beyond Basic Info/Water/Feeding/Potty/Walk/Play/Weight/Health/Hygiene and generated litter/scoop/water plan rows, reminders/tasks/ledger readback beyond Bond Vault, deceased-pet Feature Hub non-memorial route blocking beyond stale Calendar event taps, stale routes after memorial/delete beyond stale Calendar event taps, broader pet shop/economy categories and negative purchase paths beyond the covered Lime Glow effect purchase, invalid-value/broader edit-negative flows, and the immediate Home feed-label refresh after saving QuickFeed defaults. For old-user realism across multiple validation commands, add or use a persistent dogfooding/manual app-runner harness that installs once and drives the app without `xcodebuild test` clearing the container. Add narrow simulator tests as each real blocker is exposed.
- Close when: targeted pet GUI coverage proves create/edit/cancel, quick care, reminder/calendar, shop/economy, memorial/deceased, delete-cancel/delete-confirm, stale-route protection, and duplicate-write protection through either one maintainable suite or multiple real-user long sessions with passing xcresult evidence.

### TFU-20260629-002 - Finish Plant Simulator GUI Coverage

- Priority / bucket: P2, Plants simulator validation / UI-test focus blocker.
- Status: Open.
- Why still open: the one-time pinned `iPhone 17` plant GUI validation could not complete the full create/detail/reminder/calendar/delete pass. The first run reached plant creation, catalog matching, detail, defer/water/fertilize/pest/leaf actions, then failed because the test expected English care-history copy while Ohana still used the app's persisted language setting. After launching with `-appLanguage en`, reruns reached catalog selection and room entry, but `add-plant-location-input` initially did not receive keyboard focus. `PlantModuleUITests` now dismisses the keyboard after room entry and verifies text-field value acceptance. The latest 2026-06-30 full-flow reruns created the plant successfully and reached Settings; the Settings plant reminder route now refreshes after same-session plant creation. A no-reset diagnostic repeatedly reused the preserved `Codex Pothos 1782782564` household/plant state and reached the per-plant reminder control quickly. Follow-up reruns proved the default row hit point was the middle of the row, not the switch. Moving the identifier to a right-side compact control fixed hit targeting (`{347, 705}` on iPhone 17), and the tap frame now only updates local display state plus a pending service-backed write, but XCTest still waits for app idle after tapping that control and the runs had to be interrupted. Reminder/calendar/detail/delete coverage still cannot complete.
- Next action: continue from the preserved no-reset household/plant state rather than repeating the full cold-start loop. Inspect the Settings per-plant reminder control's post-tap idle behavior with runtime logs/instruments or a manual simulator session; then verify that leaving Settings flushes the pending write through `PlantReminderControlService.setPlantRemindersEnabled` and that Calendar/reminder readback updates. Prefer a real-user long-session or seeded baseline for the next broad GUI pass; reserve `-OHANA_RESET_PERSISTENT_STATE` for onboarding/empty-state coverage.
- Close when: the targeted plant UI test completes creation, edit/cancel if present, care logs/history, reminders/settings, dashboard/home/calendar/economy integration, delete/undo/final delete, and records passing xcresult/screenshot evidence.

### TFU-20260613-003 - Round-Trip Recycle-Bin Soft-Delete Fields In CloudSync

- Priority / bucket: P2, future CloudSync / 1.x.
- Status: Open.
- Why still open: first release keeps CloudKit off, but future sync must serialize/apply `trashedAt`, `trashExpiresAt`, `trashBatchId`, and `trashedByHumanId` consistently.
- Next action: before CloudKit unlock, extend serializer/apply/import paths and registry tests for recoverable entities and bulk-clear batches.
- Close when: remote soft delete and remote restore reproduce the same recycle-bin state locally without premature tombstones.

### TFU-20260612-022 - Add Final Settings Privacy And Support Actions

- Priority / bucket: P2, release links / external content.
- Status: Open.
- Why still open: final public privacy-policy URL and approved support contact route are not both available in the repo.
- Next action: provide final URL/contact route, then add localized About rows that open real destinations.
- Close when: Settings About shows only actionable privacy/support rows and a lightweight validation proves each opens the intended destination.

### TFU-20260612-020 - Finish Members Localization Coverage

- Priority / bucket: P2, Members localization.
- Status: Open.
- Why still open: the 2026-06-28 human slices moved Human detail overview, basic-info edit/read surfaces, feature hubs, privacy placeholders, reminder/notes copy, route fallback/loading/missing copy, dynamic role/age/blood chips, `EditHumanSheet`, human-reachable CrewRoster edit/delete/accessibility copy, and shared avatar/crop controls onto `L10n`, but broader Members Pet/plant-specific surfaces still contain user-visible hardcoded Chinese strings.
- Next action: continue with Pet edit/read/danger-zone surfaces plus sitter-card and Pet health/medication copy, authoring Chinese and English at minimum.
- Close when: Members user-facing strings pass localization coverage and main long-language screens remain visually clean.

### TFU-20260611-005 - Route Shared Walk Writes Through Owning Command/Service

- Priority / bucket: P2, Walks/shared-care architecture.
- Status: Open.
- Why still open: active Walks/shared-care workflow still has a static service-call boundary violation in `PetWalkingManager`.
- Next action: route shared walk writes through the owning shared-care command/service boundary used by the current Walks workflow.
- Close when: whole-repo architecture audit no longer reports the violation and relevant Walks/shared-care validation covers the path.

### TFU-20260611-003 - Normalize Sanitized Image Attachment Filenames

- Priority / bucket: P3, low-risk privacy/document polish.
- Status: Open.
- Why still open: normalized JPEG bytes can still display misleading historical or imported filename extensions.
- Next action: normalize new sanitized image filenames/extensions to `.jpg` or store explicit sanitized content type.
- Close when: new sanitized image attachments no longer show misleading `.png` extensions while import/display still rely on explicit image metadata.

### TFU-20260612-010 - Unify Care Status Read Models And Expand Ledger Analysis

- Priority / bucket: P3, product/read-model polish.
- Status: Open.
- Why still open: Hygiene and QuickCare status feedback and ledger analysis dimensions are not fully unified.
- Next action: share overdue/status feedback and extend `CareLedgerAnalysisView` with trend and actor breakdowns.
- Close when: Hygiene/QuickCare display the same status source and ledger analysis includes trend plus executor/family-member breakdowns.

## Recently Closed Pointers

Use the archive for full detail. High-signal closures already reflected in the current open count:

- TFU-20260612-006: CareLedger read-model migration closed; later route-first-frame correction recorded in `docs/testing-progress.md`.
- TFU-20260612-014: Domain presentation/infrastructure boundary cleanup closed on 2026-06-25 by local current-code guards and fresh review; CI inspection was intentionally skipped per user instruction.
- TFU-20260625-001: onboarding UITest helper drift closed on 2026-06-25 after the current first-run flow, feeding smoke, and pet-delete smoke passed in the full `OhanaUITests` suite on pinned `iPhone 17`.
- TFU-20260613-010: expense reward farm-risk review archived Done; ECO-025 now documents the current rule and says to open a new TFU if the policy changes.
- TFU-20260625-002: Plants launch integration closed on 2026-06-25; care-plan Event/Reminder materialization, per-plant reminder disable cleanup, plan refresh after care completion, dashboard location filtering, full-field detail editing, Today Focus/calendar/economy/Oasis/shop coverage, and targeted simulator tests are recorded in `docs/testing-progress.md`.
- TFU-20260614-013, 015, 016, 017, 018, 019 and TFU-20260615-001: current-head closure reviews completed on 2026-06-25; raw Open P1 count reduced to 4.
- TFU-20260623-001: Home quick-action render-state isolation cleanup closed after Terminal `iPhone 17` targeted suites reported `TEST SUCCEEDED`; Codex shell CoreSimulator remains a session blocker, now diagnosed by `scripts/diagnose-simulator.sh`.
- TFU-20260629-003: Human Settings privacy batch-action UITest/smoothness gap closed on 2026-06-29 after Settings route data stopped reloading for `privacy.*` revisions and the account security sheet moved privacy toggles/batch actions to optimistic first-frame state plus deferred writes; targeted pinned `iPhone 17` UITest now taps all-private and all-open and verifies both readbacks without XCTest idle or snapshot timeouts.
- TFU-20260629-001: Human automated write-flow coverage closed on 2026-06-29; the combined pinned `iPhone 17` UI run passed route coverage, Home human quick actions, feature-hub record persistence, and extended health/workout/report/wishlist/profile writes.
- TFU-20260628-001: Home first-pet onboarding accessibility polish closed in the same validation pass; non-front Today Focus compact-stack cards are no longer mounted at rest, and expanded non-selected Home card surfaces are hidden from accessibility.
- TFU-20260612-018: duplicate Members profile revision publishes closed on 2026-06-28; profile executors own the single publish boundary and `scripts/audit-architecture-boundaries.sh` now guards against direct Members view publishes.
- TFU-20260612-019: human memorial read-only boundary closed by current guard coverage.
- TFU-20260611-001: App Store Connect privacy setup closed; final public URL/support row remains TFU-20260612-022.

## Archive

- Full pre-compaction backlog: [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md)
- Full pre-compaction testing ledger: [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md)
