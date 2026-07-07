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
- Open follow-ups: 7 total: P1 = 4, P2 = 3, P3 = 0.
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
| Deferred 1.x / first-release-unreachable | TFU-20260614-014 | CloudSync live-apply delete-wins and Gacha natural identity are implemented locally, but true CloudKit validation is unreachable while `cloudKitDatabase: .none`. | Keep in CloudKit 1.x planning for enablement validation; do not mix into first-release burn-down unless CloudKit is enabled. |
| External/manual validation | TFU-20260612-017, TFU-20260612-016, TFU-20260706-001 | Real iOS notification/UI/HealthKit behavior must be checked on device. Repo tests cannot close these alone. | Run GAP-9, GAP-6, and Human Workout HealthKit manual checks on a physical device. |

## Open Items

### TFU-20260614-014 - Enforce CloudSync Live-Apply Deletion Wins, Parent Lifecycle, And Natural Identity

- Priority / bucket: P1, deferred CloudKit 1.x / first-release-unreachable.
- Status: Implemented locally on 2026-07-08; open only for CloudKit 1.x enablement validation while CloudKit remains disabled.
- Why still open: repository tests now prove local tombstones block remote live-record resurrection and duplicate `GachaOwnedItem` records merge by owner + series + item natural identity. Live CloudKit sharing is still unreachable under the current `cloudKitDatabase: .none` configuration.
- Next action: when CloudKit is enabled, run a true shared-zone merge/deletion pass plus a fresh Domain review over the enabled CloudSync surface.
- Close when: CloudKit-enabled validation confirms delete-wins, parent lifecycle gating, natural identity, and downstream derived-state sync with no P0/P1 current-code findings.

### TFU-20260612-017 - Validate GAP-9 Memorial Mode On Real UI And Device Notifications

- Priority / bucket: P1, external/manual validation.
- Status: Open; paid-team signing path is verified, and simulator/unit/UI coverage now narrows the remaining risk to real-device notification and final device smoke behavior.
- Why still open: repo tests now cover member lifecycle write gates, memorial-safe Feature Hub destinations, pet/human mark-and-undo UI, pet memorial confirmation copy, memorial-pet Home/FAB -> Function Menu daily-care UI target filtering, stale Calendar route blocking, human delete cancel/wrong-name safeguards, FunctionMenu active-target filtering, weekly-report active-contribution filtering, future active-schedule cleanup plus notification-cancel dispatch for memorialized pet/human members, frozen wallet/economy writes, frozen-wallet history readability, and no recycle-bin/pending-delete language on memorial surfaces, but they still cannot prove real iOS notification delivery/cancellation/restoration or physical-device presentation behavior.
- Next action: run the remaining true-device portions of the GAP-9 checklist in `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`, prioritizing notification cancellation/restoration after mark/undo plus one unlocked-device UI smoke.
- Close when: real-device checklist is checked off and any device-specific defect is fixed or split into a scoped follow-up.

### TFU-20260612-016 - Validate GAP-6 Notification Delivery On Real Devices

- Priority / bucket: P1, external/manual validation.
- Status: Open; paid-team Push/iCloud entitlement signing path is verified, and simulator/unit/UI coverage now proves scheduler policy, weekly-report notification copy/classification, notification delegate handoff, action dispatch, observability labels, and Settings Debug observability-panel reachability, but physical notification delivery is not proven.
- Why still open: repo tests cannot prove permission prompts, banners, lock-screen/background delivery, Focus/DND interaction, or that iOS physically delivers taps/actions from notification UI into the app on device.
- Next action: run the remaining true-device portions of the GAP-6 checklist in `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级`, using the simulator policy/UI tests as preflight evidence only.
- Close when: real-device checklist is checked off and any delivery/routing defect is fixed or split into a scoped follow-up.

### TFU-20260706-001 - Validate Human Workout HealthKit On Real Device

- Priority / bucket: P1, external/manual validation.
- Status: Open; simulator/build coverage can prove unavailable/unauthorized UI and local import persistence, but cannot prove real Apple Health authorization prompts or real HealthKit sample reads.
- Why still open: HealthKit read access, Activity Summary values, and real workout samples require a physical iPhone with Health data and user-granted permissions.
- Next action: install a signed build on a real device, open Human Workout, grant Apple Health read access, confirm activity rings/step/distance cards populate from Health data, import one workout, relaunch, and verify the imported Human workout remains local with Health source metadata.
- Close when: the real-device checklist passes or any device-specific HealthKit defect is fixed or split into a scoped follow-up.

### TFU-20260629-004 - Finish Pet Simulator GUI Deep Coverage

- Priority / bucket: P2, Pet simulator validation / UI-test coverage gap.
- Status: Open.
- Why still open: the pinned `iPhone 17` pet GUI coverage now passes first-pet onboarding, production-overlay first-pet onboarding, feeding manual/reminder quick actions with anti-repeat confirmation, permanent delete from basic info, delete cancel/wrong-name protection, Water detail route open/close plus write/readback through `QuickWaterCommandExecutor.recordWater` / `CareEventService.recordCareFact`, Water quick-care reward readback into Pet Bond Vault positive balance plus recent economy log, Water plan reminder save/delete Calendar pet-filter readback with localized title matching, Play quick-tap responsiveness, Feature Hub route-open coverage for potty, hygiene, walk, and health, Potty detail write/readback through `QuickPottyCommandExecutor.record` / `CareEventService.recordPottyFact`, cat litter scoop write/readback plus same-day repeat-submit guard coverage and cat litter full-change write/readback coverage through `QuickPottyCommandExecutor.recordLitterCare` / `CareEventService.recordCareFact`, cat litter plan reminder cancel/save/delete coverage through the quick-potty settings sync boundary, full litter-change reminder save/delete Calendar pet-filter readback with localized title matching, scoop-plan reminder save/delete Calendar list-view pet-filter readback with localized plan-title matching, Hygiene detail write/readback plus same-day repeat-tap guard coverage through `PetHygieneCommandExecutor` / `CareEventService.recordHygieneFact`, Health visit-record cancel/save write/readback through `PetHealthCommandExecutor.recordHealth` / `CareEventService`, Pet Basic Info memorial mark/undo cancel-confirm coverage through member lifecycle commands, memorial-pet Home live-care entry hiding after relaunch, stale Calendar event live-care route blocking after memorial, stale Calendar cleanup after permanent delete, Pet Basic Info edit cancel/save persistence coverage, Pet Basic Info empty-name save protection/readback coverage, Walk Home quick-action start/stop plus summary persistence/readback coverage through `WalkTrackingCommandExecutor.stopWalk` / `PetWalkingManager.stop`, active Walk card minimize-to-floating behavior with the large card and global bubble mutually exclusive plus tapping Walk again returning to the current embedded Walk card instead of starting a new walk, Calendar pet-linked event creation/filter readback through `CalendarCommandExecutor.createEvent(input:)`, manual Calendar event detail/edit/delete coverage, generated Feeding plan Calendar row -> Quick Feed coverage, and a suite-level Calendar recheck covering linked Pet Basic Info, Water detail, Feeding detail, Potty detail, Walk Summary, Play detail, Weight detail, Health detail, and Hygiene detail through `FocusHomeReminderDeepLinkRouter` without starting walk tracking from the row tap. Pet Bond Vault Feature Hub entry, zero-balance blocked-unlock readback, seeded positive unlock/spend readback through the UI-test Debug Coconuts shortcut, and Coconut Shop pet-effect purchase of Lime Glow through Home FAB -> Function Menu -> confirmation popup -> 1000🥥 to 700🥥 balance readback also pass. The real-user long-session coverage now keeps one Human and one Cat across first-pet creation, feeding setup, Home feed quick check-in and repeat confirmation, Water write/readback, Potty litter settings cancel/save, litter scoop write/readback and repeat disabled state, Hygiene write/readback and repeat guard, Health cancel/save write/readback, Calendar pet-linked event create/filter/readback, Bond Vault low-balance block, seeded positive unlock/spend, return navigation, sheet close paths, and Home re-entry state without resetting between each feature. A second real-user long-session keeps one Human and one Dog across Dog walk start/stop/readback, app relaunch state retention, Basic Info edit cancel/save readback, memorial mark/undo cancel-confirm paths, and permanent delete wrong-name/cancel/exact-name safeguards. A new existing-user no-reset smoke now first reuses any Home Human/Pet, seeds only if the simulator is in a damaged empty state, then covers Water write/readback, Calendar pet event create/filter/readback, Bond Vault balance readback, and same-test relaunch retention. A separate `xcodebuild test` command still did not preserve the app container reliably, so true old-user reuse across separate commands remains a harness/manual-runner gap. The latest 40-test selected pet GUI suite executed 40 selected tests with 38 passing on the first broad run; both failures were harness issues, not product write failures: stale deleted-pet card lookup called `isHittable` on an invalid XCTest element, and the Cat long-session Quick Feed path needed the existing frame-ready tap fallback when XCTest reported an enabled primary action as non-hittable. After hardening those UI-test helpers, the two focused reruns passed on the same pinned simulator. A focused 2026-06-30 rerun of `testFeedingManualPlanAndHomeQuickActionSmoke` now also proves that immediately after saving QuickFeed manual defaults and returning Home, `home-quick-action-feed` no longer remains in `待设置` / `Not set`, then completes the Home quick-feed and repeat-confirmation path. A later five-test 2026-06-30 GUI batch also reran Feeding, Walk minimize/resume, manual Calendar CRUD, generated Feeding Calendar deep-link, and Coconut Shop Lime Glow purchase together with 5/5 passing on the pinned simulator. The suite still does not exercise broader pet calendar care-type/deep-link paths beyond Basic Info/Water/Feeding/Potty/Walk/Play/Weight/Health/Hygiene and generated litter/scoop/water plan rows, broader pet shop/economy purchases beyond Bond Vault plus one Lime Glow effect purchase, deceased-pet Feature Hub non-memorial route blocking beyond stale Calendar event taps, stale-route protection after memorial/delete beyond stale Calendar event taps, broader edit-negative paths beyond empty-name protection, or reminder/task/ledger cross-feature paths in one long scenario beyond the covered Bond Vault ledger path.
- Next action: continue remaining negative and cross-feature GUI paths through pet calendar care-type deep-linking beyond Basic Info/Water/Feeding/Potty/Walk/Play/Weight/Health/Hygiene and generated litter/scoop/water plan rows, reminders/tasks/ledger readback beyond Bond Vault, deceased-pet Feature Hub non-memorial route blocking beyond stale Calendar event taps, stale routes after memorial/delete beyond stale Calendar event taps, broader pet shop/economy categories and negative purchase paths beyond the covered Lime Glow effect purchase, and invalid-value/broader edit-negative flows. For old-user realism across multiple validation commands, use `scripts/run-dogfood-simulator.sh --status --require-data` around manual dogfood passes so the same pinned simulator, installed app, and persistence store are verified instead of relying on `xcodebuild test` container behavior. Add narrow simulator tests as each real blocker is exposed.
- Close when: targeted pet GUI coverage proves create/edit/cancel, quick care, reminder/calendar, shop/economy, memorial/deceased, delete-cancel/delete-confirm, stale-route protection, and duplicate-write protection through either one maintainable suite or multiple real-user long sessions with passing xcresult evidence.

### TFU-20260612-022 - Add Final Settings Privacy And Support Actions

- Priority / bucket: P2, release links / external content.
- Status: Open.
- Why still open: final public privacy-policy URL and approved support contact route are not both available in the repo.
- Next action: provide final URL/contact route, then add localized About rows that open real destinations.
- Close when: Settings About shows only actionable privacy/support rows and a lightweight validation proves each opens the intended destination.

### TFU-20260612-020 - Finish Members Localization Coverage

- Priority / bucket: P2, Members localization.
- Status: Open.
- Why still open: the 2026-06-28 human slices moved Human detail overview, basic-info edit/read surfaces, feature hubs, privacy placeholders, reminder/notes copy, route fallback/loading/missing copy, dynamic role/age/blood chips, `EditHumanSheet`, human-reachable CrewRoster edit/delete/accessibility copy, and shared avatar/crop controls onto `L10n`. The 2026-07-07 passes also moved pet personality home greetings onto unified `L10n.tr` copy with regression coverage, converted the Pet basic-info vet summary read model from prebuilt Chinese strings into value snapshots rendered through localized helpers, localized Pet breed care-tip output at the `PetBreedDatabase.careTips(for:l:)` source boundary, removed Pet/Human basic-info edit forms' Chinese `未填写` picker sentinel in favor of internal empty values plus localized display text, made Pet Basic Info species picker render localized labels over stable raw values, made new Pet species writes/defaults use canonical keys with legacy Chinese raw-value read compatibility across high-traffic home/profile/health/function-menu/shared-check-in surfaces, made Pet health alert species exceptions consume the same canonical helpers, made new Human gender selection/write/backup-export paths use canonical keys while retaining legacy Chinese raw-value read compatibility, centralized Human role/gender display through `HumanProfileOptions.localized*` helpers across Home snapshots, Human detail, all-features, CrewRoster, and privacy surfaces, moved Pet medication dose units and administration methods to stable keys with localized display plus legacy Chinese read compatibility, localized the sitter-card export watermark, hardened the sitter-card header/rows for long-language wrapping instead of fixed-width label columns, replaced Pet Basic Info read/vet-summary fixed label columns with adaptive horizontal/stacked rows guarded by source tests, replaced Plant Dashboard room-zone fixed cards with adaptive min/ideal/max width cards plus wrap-capable status chips, moved Pet medication list/detail cards onto adaptive long-language layouts, and changed Plant multi-select quick record from a flat care-type strip to a category-then-type picker with adaptive plant cards. The 2026-07-08 passes removed more fixed-width long-language pressure points from Plant care-log suggestion cards, Plant Detail edit focus/catalog choice cards, Pet Basic Info edit rows, and the legacy Edit Pet daily-portion row, with source guards for those regressions. The 2026-07-07 localization audit now has zero current direct user-visible hardcoded Chinese matches and the stale 600-line baseline was collapsed to an empty ratchet. The remaining risk is visual: broader Members/Pet/plant dense screens still need a final long-language sweep.
- Next action: continue the broader Members/Pet/plant visual long-language sweep, especially remaining pet detail layouts and plant high-density cards.
- Close when: Members user-facing strings pass localization coverage and main long-language screens remain visually clean.

## Recently Closed Pointers

Use the archive for full detail. High-signal closures already reflected in the current open count:

- TFU-20260612-006: CareLedger read-model migration closed; later route-first-frame correction recorded in `docs/testing-progress.md`.
- TFU-20260612-014: Domain presentation/infrastructure boundary cleanup closed on 2026-06-25 by local current-code guards and fresh review; CI inspection was intentionally skipped per user instruction.
- TFU-20260625-001: onboarding UITest helper drift closed on 2026-06-25 after the current first-run flow, feeding smoke, and pet-delete smoke passed in the full `OhanaUITests` suite on pinned `iPhone 17`.
- TFU-20260613-010: expense reward farm-risk review archived Done; ECO-025 now documents the current rule and says to open a new TFU if the policy changes.
- TFU-20260625-002: Plants launch integration closed on 2026-06-25; care-plan Event/Reminder materialization, per-plant reminder disable cleanup, plan refresh after care completion, dashboard location filtering, full-field detail editing, Today Focus/calendar/economy/Oasis/shop coverage, and targeted simulator tests are recorded in `docs/testing-progress.md`.
- TFU-20260614-013, 015, 016, 017, 018, 019 and TFU-20260615-001: current-head closure reviews completed on 2026-06-25; raw Open P1 count reduced to 4.
- TFU-20260623-001: Home quick-action render-state isolation cleanup closed after Terminal `iPhone 17` targeted suites reported `TEST SUCCEEDED`; Codex shell CoreSimulator remains a session blocker, now diagnosed by `scripts/diagnose-simulator.sh`.
- TFU-20260613-004: pet quick-access restore polish closed as stale against current product code. Pets now use physical deletion/memorial lifecycle rather than a restore-from-recycle-bin path; `MemberDeletionCommandService.deletePet` intentionally removes pet-scoped quick actions from `quickActionItems_v2`, and `HomeCommandExecutorTests.memberDeletionServiceDeletesPetRelatedEventsAndQuickAccess` covers that cleanup.
- TFU-20260611-005: shared-walk command/service boundary closed as current-code resolved. Multi-target walks route through `walkCareEvents.recordSharedWalk` / `SharedPetActionRecorder`, single-target walks use `DomainCareFactWriteAuthorizer` + `DomainCareFactWriter` + `DomainCareFactEffectsDispatcher`, and whole-repo architecture plus economy-boundary audits cover the path.
- TFU-20260629-003: Human Settings privacy batch-action UITest/smoothness gap closed on 2026-06-29 for the then-current PIN/privacy UI; that UI evidence is now superseded by the first-release local policy that hides member privacy/PIN controls and treats same-device member switching as attribution only.
- TFU-20260630-001: Coconut Shop Function Menu route blocker closed on 2026-06-30 after the current iPhone 17 simulator revalidation passed the Home FAB -> Function Menu -> Coconut Shop -> Lime Glow purchase UI test plus route, growth, gacha, catalog, and plant-shop guards.
- TFU-20260629-002: Plants simulator GUI coverage closed on 2026-07-03 after current evidence covered the launch-required simulator paths: full unlock/create/reminder/Calendar/care/delete, no-reset reminder toggle, no-reset detail profile sections, no-reset Settings bulk defer plus edit cancel/save, Calendar plant filter, catalog-first add flow, and wallet expand/collapse position stability including the mid-animation inactive-card jump root fix. Remaining plant work is tracked as true-device/manual acceptance in `docs/release-true-device-test-plan.md` or as non-launch future scope, not as a simulator focus blocker.
- TFU-20260611-003: sanitized image attachment filename polish closed on 2026-07-07. Document and receipt import paths now consume the shared sanitizer payload, successful JPEG rewrites surface `.jpg` filenames, fallback batch names remain unique, and `scripts/build-debug-fast.sh` passed on the pinned `iPhone 17` simulator.
- TFU-20260612-010: care status read-model and ledger analysis polish closed on 2026-07-07. `CareLedgerAnalysisView` now includes event-type distribution, actor/family-member breakdown, and a daily trend card; Hygiene/QuickCare status feedback shares `CareCycleStatus`, and Home groom quick-action attention reads from the hygiene ledger snapshot instead of view-local date math.
- TFU-20260613-003: CloudSync legacy soft-delete field round trip closed on 2026-07-08. Upload-pipeline recoverable entities serialize legacy trash fields, restore uploads clear them, and live remote apply preserves or clears those fields without turning the row into a deletion tombstone; future true shared-zone validation is covered by TFU-20260614-014 while CloudKit stays disabled.
- TFU-20260629-001: Human automated write-flow coverage closed on 2026-06-29; the combined pinned `iPhone 17` UI run passed route coverage, Home human quick actions, feature-hub record persistence, and extended health/workout/report/wishlist/profile writes.
- TFU-20260628-001: Home first-pet onboarding accessibility polish closed in the same validation pass; non-front Today Focus compact-stack cards are no longer mounted at rest, and expanded non-selected Home card surfaces are hidden from accessibility.
- TFU-20260612-018: duplicate Members profile revision publishes closed on 2026-06-28; profile executors own the single publish boundary and `scripts/audit-architecture-boundaries.sh` now guards against direct Members view publishes.
- TFU-20260612-019: human memorial read-only boundary closed by current guard coverage.
- TFU-20260611-001: App Store Connect privacy setup closed; final public URL/support row remains TFU-20260612-022.
- TFU-20260702-001: Plants oversized SwiftUI split closed on 2026-07-02 after `PlantDashboardView.swift` and `PlantDetailView.swift` were split below the oversized-file threshold and the architecture gate passed.

## Archive

- Full pre-compaction backlog: [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md)
- Full pre-compaction testing ledger: [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md)
