# Task Follow-ups

This document tracks concrete follow-ups discovered while finishing a task when
they cannot or should not be completed in the same turn. Keep it short and
actionable; long-term product ideas belong in planning docs instead.

## How To Use

- Add an entry only when a completed task leaves a real blocker, external action,
  cross-scope repair, validation gap, or follow-up that should not be forgotten.
- For the current repository task, a concrete accepted follow-up recorded here
  counts as handled even when the future owner-facing status remains `Open`.
  Keep the blocker, next step, and close condition explicit so the deferred work
  can be resumed without rediscovery.
- When a task cannot be completed locally because it requires a paid Apple
  Developer account, provisioning access, CloudKit Dashboard access, App Store
  Connect access, or physical devices that are not currently available, recording
  the concrete blocker, next step, and close condition here counts as completing
  the current repository task. The follow-up remains for the future external
  validation/action owner.
- Prefer one entry per actionable outcome. Include the blocker and the exact
  next step, not just a vague reminder.
- Close entries by changing `Status` to `Done` and adding a short `Closed` note.
- If there is no meaningful follow-up after a task, do not add noise here.

## Open Items

### TFU-20260612-022 - Add final Settings privacy and support actions

- Status: Open
- Priority: P2
- Area: Settings / About / Release Links
- Source task: Settings + Health Phase 6 remediation, 2026-06-12
- Blocker: The final public privacy-policy URL and owner-approved support
  contact channel are not both available in the repository. The release
  Settings screen now hides empty About actions instead of exposing dead rows.
- Next step: Provide the final privacy URL and support contact route, then add
  localized About rows that open real destinations.
- Close when: Settings About shows only actionable privacy/support entries and
  a lightweight validation proves each row opens the intended destination.

### TFU-20260612-021 - Audit deleted-human wallet and ledger visibility

- Status: Open
- Priority: P1
- Area: Economy / Members / Recycle Bin
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: Members now preserves human-scoped data during the 30-day recycle
  period and purges confirmed human-owned side rows at expiry, but deleting
  CoconutAccount / CoconutLedgerEntry ownership or hiding purged humans from
  formal asset and ledger projections belongs to the Economy module boundary.
- Next step: In the Economy phase, verify that recycled or permanently purged
  humans do not appear as active wallet owners, asset rows, rankings, or reward
  write targets, while historical ledger entries remain understandable.
- Close when: Economy tests and real UI checks prove deleted humans are excluded
  from active asset/ranking/reward surfaces and historical ledger visibility has
  the intended product treatment.

### TFU-20260612-020 - Finish Members localization coverage

- Status: Open
- Priority: P2
- Area: Members / Localization
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: Members still has a broad set of user-visible hardcoded Chinese
  strings in detail, edit, privacy, and read-only profile surfaces. Fixing it
  cleanly is a larger localization pass outside the P0 deletion/sync repair.
- Next step: Move Members detail/edit/privacy/Pet read content strings onto the
  registered localization path, authoring Chinese and English at minimum and
  preserving the existing fallback chain for other app languages.
- Close when: Members user-facing strings pass the localization audit and the
  main detail/edit/privacy screens remain visually clean in long languages.

### TFU-20260612-019 - Enforce human memorial read-only boundaries

- Status: Open
- Priority: P1
- Area: Members / Memorial / Command Boundaries
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: GAP-9 removed active-flow participation for deceased humans, but
  the Members command layer still allows profile edit, privacy toggles, and
  deletion routes while the UI says "纪念模式 · 只读". A hard boundary needs a
  focused route/command pass to avoid changing memorial behavior by accident.
- Next step: Define the allowed actions for deceased humans, then enforce the
  read-only boundary in Members routes and command services with focused tests.
- Close when: Deceased human profiles cannot be mutated through Members edit /
  privacy / destructive paths unless the action is explicitly allowed, and the
  UI copy matches the command behavior.

### TFU-20260612-018 - Remove duplicate member profile revision publishes

- Status: Open
- Priority: P2
- Area: Members / Domain Revisions / Smoothness
- Source task: Members Phase 6 remediation, 2026-06-12
- Blocker: `MemberCommandExecutor.update*Profile` already publishes member
  profile revisions, but several view callers publish another revision after
  the executor returns. This is not part of the P0 deletion/sync repair and
  should be fixed as a narrow smoothness/invalidations pass.
- Next step: Remove duplicate view-level revision publishes after confirming the
  executor emits the single intended mutation for Pet/Human edit paths.
- Close when: Each profile save publishes exactly one member profile revision
  and focused tests or an audit prevent the duplicate pattern from returning.

### TFU-20260612-017 - Validate GAP-9 memorial mode on real UI and device notifications

- Status: Open
- Priority: P1
- Area: Memorial / Notifications / Release Validation
- Source task: GAP-9 memorial exit, 2026-06-12
- Blocker: Repository tests prove data retention, active-flow filtering, undo
  restoration, and reward freeze invariants, but they cannot fully prove real
  iOS notification cancellation / rescheduling behavior or the final visible
  memorial experience across a real device data set.
- Next step: Run the GAP-9 manual checklist in
  `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`, especially
  marking/undoing a pet, checking notification cancellation and restoration,
  confirming memorial entry visibility, and scanning home/FAB/full-menu
  active targets.
- Close when: The GAP-9 track list's manual section is checked off on a real
  device and any device-specific notification or UI defect is fixed or split
  into its own scoped follow-up.

### TFU-20260612-016 - Validate GAP-6 notification delivery on real devices

- Status: Open
- Priority: P1
- Area: Notifications / Release Validation
- Source task: GAP-6 notification classification, 2026-06-12
- Blocker: Repository tests and simulator UI tests can prove scheduling policy,
  ledger visibility, and routing compile paths, but they cannot prove real iOS
  notification delivery, banners, permission prompts, Focus/DND interaction, or
  notification action behavior on physical devices.
- Next step: Run the GAP-6 manual checklist in
  `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级` on a real device
  with notification permission enabled, including routine budget, quiet-hours
  deferral, health-critical delivery, merge behavior, notification actions, and
  weekly report copy.
- Close when: The GAP-6 track list's manual section is checked off on a real
  device and any device-specific delivery or routing defect is either fixed or
  recorded as its own scoped follow-up.

### TFU-20260611-001 - App Store Connect privacy setup

- Status: Done
- Priority: P1
- Area: Release / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: Requires App Store Connect access and a public privacy policy URL;
  this cannot be completed from the repository alone.
- Next step: In App Store Connect, set the privacy questionnaire to "No, we do
  not collect data from this app" for the current zero-upload build, so the App
  Store label reads `Data Not Collected`.
- Close when: App Store Connect privacy answers are saved and the submitted
  privacy policy URL matches `docs/privacy-compliance.md`.

### TFU-20260611-002 - Wire Settings privacy policy row

- Status: Closed
- Priority: P2
- Area: Settings / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: The final public privacy policy URL is not available in the repo.
- Next step: Once the URL exists, connect the Settings screen's "隐私政策" row to
  open that URL and keep the copy localized.
- Close when: The row opens the published privacy policy from Settings and has
  a lightweight validation path.

### TFU-20260611-003 - Normalize sanitized image attachment filenames

- Status: Open
- Priority: P3
- Area: Documents / Expenses / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: Low-risk cosmetic cleanup touches several attachment creation paths
  and historical display behavior, so it should be handled as its own narrow
  pass instead of folded into sanitizer diagnostics.
- Next step: When image bytes are normalized to JPEG, normalize new attachment
  display filenames/extensions to `.jpg` or store an explicit sanitized content
  type, while preserving existing `isImage` behavior.
- Close when: Newly sanitized image attachments no longer show a misleading
  `.png` extension for JPEG bytes, and import/display paths still rely on
  explicit image metadata rather than filename alone.

### TFU-20260611-004 - Add cloud-sync mutation marks for feeding writes

- Status: Done
- Priority: P1
- Area: Cloud Sync / Feeding
- Source task: Feeding quick-action and stock-reminder repair follow-up,
  2026-06-11
- Blocker: Resolved in Feeding Phase 6 by adding CloudSync upload-pipeline
  support and mutation recorder coverage for feeding-owned sync facts.
- Next step: No remaining action for this follow-up. `Reminder` remains outside
  the current upload pipeline by design; feeding reminder sync is represented by
  the owning `Event` facts.
- Close when: Feeding stock records, feed rules, stock reminders, and auto-log
  materialized records enqueue upload/delete mutations, with focused CloudSync
  tests proving the registered entities are recorded.
- Closed: 2026-06-12 in Feeding Phase 6; `Event` and `PetFoodRecord` now have
  upload/apply support, Feeding write/delete paths call `CloudSyncMutationRecorder`,
  and focused CloudSync + Feeding command tests cover the dirty-state writes.

### TFU-20260611-005 - Route shared walk writes through an owning command/service

- Status: Open
- Priority: P2
- Area: Walks / Shared Care / Architecture
- Source task: Feeding quick-action and stock-reminder repair follow-up,
  2026-06-11
- Blocker: The violation is in an active Walks/shared-care workflow outside the
  feeding repair scope.
- Next step: Replace the static `CareEventService.recordSharedWalk` call in
  `PetWalkingManager` with the owning shared-care command/service boundary used
  by the current Walks workflow.
- Close when: Whole-repo architecture audit no longer reports the
  `PetWalkingManager` static service-call violation and the shared-walk path is
  covered by the relevant Walks/shared-care validation.

### TFU-20260612-006 - Finish CareLedger read-model migration for care surfaces

- Status: Open
- Priority: P0
- Area: Care / QuickCare / Hygiene / Read Models
- Source task: Care maturity remediation, 2026-06-12
- Blocker: This crosses QuickCare, Home snapshots, expanded quick-action state,
  expense previews, and legacy log compatibility. `PetHygieneDetailView` display
  state, `IslandHygieneDashboard` summaries, `QuickPlayDetailSheet` display
  history, `QuickPottyDetailSheet` owned potty/litter history, and
  `QuickWaterDetailSheet` water/change/filter history now read from
  `CareLedgerEvent` snapshots. `IslandFoodDashboard` feeding summaries and
  trends also read from `CareLedgerEvent`; its old `PetCareLog` input remains a
  stock-calculator compatibility source because food-kind/stock consumption
  semantics have not yet moved fully into ledger metadata. QuickFeed full
  history, plan-calendar auto occurrence state, overview, mode-history, and
  treat overview snapshots now aggregate `CareLedgerEvent` entries, with
  `PetCareLog` retained only as a legacy bridge for food-kind/treat-kind
  enrichment and edit/delete affordances. Home expanded human expense preview
  now reads lightweight `CareLedgerEvent` snapshots instead of direct
  `PetExpenseLog` rows, and Home expanded pet feed quick-action completion,
  count, attention, and menu policy now read lightweight feeding ledger
  snapshots instead of `pet.careLogs`. Home expanded `PetCareLog`-class quick
  actions such as water, litter, play, filter clean, cage cleaning, free flight,
  misting, and substrate change now read lightweight care ledger snapshots for
  completion, counts, recent-age text, and attention state. Home expanded walk
  and potty quick-action status now read lightweight walk/potty ledger
  snapshots for today's distance, completion, count, and recent abnormal potty
  status. Home expanded pet expense monthly total now reads lightweight pet
  expense ledger snapshots instead of `pet.expenseLogs`; old
  `PetExpenseLog` rows are already covered by the CareLedger backfill path.
  `PetWeightLog` is now included in CareLedger backfill, and Home expanded pet
  weight completion/latest status reads lightweight pet weight ledger snapshots
  instead of `pet.weightLogs`. The pet weight dashboard now renders metrics,
  chart points, and recent history from pet-weight `CareLedgerEvent` entries;
  `PetWeightLog` remains only as a deferred delete-command compatibility bridge
  when a ledger row carries a legacy id. `PetHygieneLog` is now included in CareLedger
  backfill, and Home expanded groom completion reads lightweight hygiene ledger
  snapshots instead of `pet.hygieneLogs`; Home groom command duplicate
  prevention also reads bounded `CareLedgerEvent` hygiene rows and only
  publishes a home mutation when a new hygiene fact is recorded. Feed
  anti-repeat checks in Home and QuickFeed detail now use feeding
  `CareLedgerEvent` snapshots instead of `pet.careLogs`, preserving actor-name
  warnings without depending on the legacy relationship array.
  `IslandPottyDashboard` now aggregates potty rhythm, type counts, 10-day pulse,
  and per-pet summaries from potty `CareLedgerEvent` entries instead of
  `pet.pottyLogs`. Home `VerticalSolidHomeSourceState`, `HomeReadModelStore`,
  `TodayFocusSnapshot`, and `TodayFocusEconomyService` now use lightweight
  `TodayFocusCareLedgerEntry` values for Today Focus care completion and daily
  reward gating instead of fetching today `PetCareLog`, `PetWalkLog`, or
  `PetPottyLog` rows. `TodayFocusService` has direct ledger-entry completion
  coverage for planned feed, walk, potty, and play-equivalent quests.
  `IslandQuestEngine` now consumes the same lightweight ledger entries when
  generating care-plan and family-level play quests, including event-scoped
  feed/water completion checks and actor-aware routine subtitles when ledger
  actor data is available.
  Legacy logs remain only as delete/claim/stock/typed-metric compatibility
  bridges where old commands or calculators still require the original model.
  Remaining fallback branches in Today Focus still read legacy relationship
  arrays only when no ledger-entry snapshot has been supplied.
- Next step: Move remaining moment expanded quick-action consumers, feeding
  stock calculators, and command/delete/claim compatibility paths off direct
  `PetCareLog`, `PetPottyLog`, `PetWalkLog`, and `PetExpenseLog` queries where
  `CareLedgerEvent` has enough structured metadata, then cover each migrated
  surface with targeted tests. Reason not completed in the same round: feeding
  stock calculators still need legacy food-kind/stock metadata until that data
  is represented structurally in ledger metadata; Today Focus still retains
  legacy relationship-array fallbacks for compatibility when a caller has not
  supplied ledger snapshots; hygiene delete/detail compatibility still needs
  the original `PetHygieneLog` record for explicit user deletion; moment/photo
  status is a separate media-history read path rather than a CareLedgerEvent
  surface, so it needs its own scoped migration and tests.
- Current task disposition: Accepted follow-up for future migration scope. The
  current care-maturity remediation is complete because remaining direct legacy
  reads are either explicit compatibility bridges or cross-surface migrations
  documented here with exact next steps and close conditions.
- Close when: QuickCare and Hygiene user-facing read models no longer directly
  query the four legacy pet log models except for explicit backup/migration
  compatibility paths.

### TFU-20260612-007 - Validate shared-care CloudKit behavior on two devices

- Status: Done
- Priority: P0
- Area: Cloud Sync / Shared Care
- Source task: Care maturity remediation, 2026-06-12
- Blocker: The repository can prove local mutation metadata and tombstones, but
  it cannot prove real CloudKit propagation, conflict ordering, or sync-storm
  behavior without two signed-in devices or equivalent CloudKit integration
  infrastructure.
- Next step: Run the shared-care checklist in `docs/cloud-sync-todo.md` on two
  real devices, including private and shared database flows, cascade tombstones,
  legacy cleanup, orphan preservation diagnostics, and the sync-storm check.
- Closed: 2026-06-12 as an accepted external follow-up because the current owner
  does not have a paid developer account, CloudKit provisioning, or two signed-in
  devices. The required validation is preserved in `docs/cloud-sync-todo.md`.
- Close when: Shared-session cascade tombstones propagate correctly and
  reconcile-driven `markModified` calls do not create repeated upload loops.

### TFU-20260612-008 - Add missing CareEventService and care command tests

- Status: Open
- Priority: P1
- Area: Care / Tests
- Source task: Care maturity remediation, 2026-06-12
- Blocker: Planned-feed and planned-water happy paths now directly cover reward
  economy, reminder completion, family-task linkage, and ledger writes, but
  additional `CareEventService` edge/failure paths still rely on indirect
  coverage. Direct `CareEventService` coverage now includes the linked
  litter-to-potty write path with two ledger events plus quick-action reminder
  handoff, and the no-event planned feed/water failure path that must write no
  care facts, ledgers, rewards, or family-task completions. Reminder reopen now
  has direct coverage for the `ReminderCompletionService` to family-task handoff,
  and `FamilyTaskService.syncReopenedReminder` now proves completed reminder
  tasks reopen without mutating pending-review reward tasks. Planned-water
  catch-up rejection after the allowed window now directly proves no water log,
  ledger event, reward call, reminder completion, or family-task completion is
  written on the rejected path. Direct hygiene service coverage now proves
  `CareEventService.recordHygieneFact` writes a `PetHygieneLog`, hygiene ledger
  event, reward metadata, and quick-action reminder handoff with the expected
  actor/type/date. Direct potty service coverage now proves
  `CareEventService.recordPotty` writes a `PetPottyLog`, potty ledger event,
  reward metadata, and quick-action reminder handoff with the expected
  actor/type/date.
- Next step: Add focused tests for the remaining `CareEventService` error and
  service failure paths not covered by the planned-feed/planned-water chains,
  the hygiene and potty service tests, the reopen tests, no-event tests, or the
  existing catch-up/rejected planned-care tests.
  `PetHygieneCommandService` record/delete/plan/executor coverage exists in
  `HomeCommandExecutorTests`, and the grooming overdue warning path is now
  covered in `OhanaTests`. `CatCareCommandService` now has dedicated command
  coverage for non-hygiene records and wrong-pet undo isolation.
  `QuickPottyCommandExecutor` and `QuickPottyUnknownClaimStore` now cover the
  unknown shared potty claim flow in `HomeCommandExecutorTests`.
- Current task disposition: Accepted follow-up for future negative-path
  expansion. The current remediation has direct coverage for the high-risk
  success chains, no-write guard paths, catch-up rejection, reopen syncing,
  hygiene, potty, command services, and unknown-potty claim flow; the remaining
  tests are incremental edge/failure coverage rather than a blocker for this
  closeout.
- Close when: The listed services have direct behavior tests covering success,
  edge, and migration/recovery paths instead of relying only on indirect shared
  care tests.

### TFU-20260612-009 - Harden care fetch failures and large-data reconciliation

- Status: Done
- Priority: P2
- Area: Care / Performance / Diagnostics
- Source task: Care maturity remediation, 2026-06-12
- Resolution: Shared-session maintenance now logs fetch failures and uses
  legacy-model + legacy-id predicates for ledger cleanup. `CareLedgerBackfillService`
  now checks existing ledger rows with legacy-model + legacy-id predicates instead
  of building a full existing-ledger key set. PetCare, Potty, and Hygiene command
  delete paths now use exact ledger predicates and warning fetch helpers.
  QuickPotty now logs fetch failures and narrows latest-log and unknown-claim
  lookups to the target pet/session. `HomeCommandExecutor` now logs fetch failures
  on its quick-care entry-point fetches and narrows recent care log fetches to
  the target pet. `ReminderActionCoordinator` now logs reminder/medication lookup
  fetch failures. `QuickPlayCommandExecutor` and `QuickWaterCommandExecutor` now
  log command-executor fetch failures. QuickCare detail views now log legacy-plan
  lookup failures. Feeding command read helpers, quick-feed executor fetches,
  stock expense lookup, and stock reminder reconciliation now log fetch failures,
  and care plan calendar sync, quick-action reminder completion sync, reminder
  maintenance, and calendar task completion cleanup now log fetch failures.
  Startup feed auto-log maintenance, human requirement resolution, member theme
  color normalization, and avatar asset compaction now log fetch failures.
  Backup restore de-duplication now logs fetch failures and aborts restore
  instead of treating failed reads as empty stores. `FamilyTaskService` now logs
  legacy bounty, reminder linkage, human lookup, and wallet-transfer fetch
  failures. `CoconutWalletService`, coconut bootstrap import, and developer
  wallet overrides now log account/projection fetch failures instead of silently
  treating failed reads as empty wallet state. `HomeReadModelStore` now logs
  home entity, event, reminder, legacy compatibility, family-task, and exchange
  request fetch failures instead of silently collapsing the home snapshot to
  empty sections. `TodayFocusEconomyService` now logs Today Focus economy input
  fetch failures instead of treating missing pets, humans, plants, reminders,
  events, and same-day care logs as successful empty reads.
  `EventCompletionCommandService` now logs calendar completion reward lookups for
  same-day care logs, existing reward transactions, and reward executor humans.
  `StarterGiftService` now logs starter-gift human/pet/ledger count reads and
  active-human lookup failures instead of treating failed onboarding reads as
  fresh-install empty state. `OnboardingJourneyCoordinator` now logs recorded
  care-fact lookup failures, and `RainbowBridgeService` now logs future reminder
  and event cleanup fetch failures while narrowing those fetches to future
  relevant rows. `CatCareCommandService` now logs undo artifact fetch failures
  and narrows undo lookups to the target event/log identifiers.
  `MedicationCommands` now logs human medication reminder-sync fetch failures
  and pet/human medication calendar cleanup fetch failures instead of silently
  treating failed reads as empty medication/event sets.
  `DashboardRecordCommands` now logs dashboard ledger cleanup fetch failures and
  uses legacy-model + legacy-id predicates when deleting weight/expense ledger
  events. `PetMilestoneCommands` and `WorkoutCommands` now log ledger cleanup
  fetch failures and use legacy-model + legacy-id predicates when deleting
  milestone/workout ledger events. `HumanWishlistCommands` and
  `PetDocumentCommands` now log ledger cleanup fetch failures, narrow ledger
  cleanup to legacy-model + legacy-id predicates, and avoid silently treating
  document payer lookup failures as missing payers. Core `QuestManager` reward
  paths, backdate check-in active-human resolution, persisted economy budget
  reads, care-object counting, and reminder auto-completion now log fetch
  failures and avoid broad human scans on reward attribution.
  `MemberDeletionCommands` now logs fetch failures while resolving remaining
  humans and pet-related events during deletion. `Pet` model helpers now log
  shared feed-session and activity-event fetch failures, while activity event
  cleanup filters by pet in the SwiftData predicate. `HumanMedicationLogStore`
  now logs failed matching-log fetches before falling back to create/update
  behavior. Gacha draw-log and owned-item fetches now log failures before
  falling back to empty collections. `CoconutLogView` member snapshot fetches
  now log human/pet read failures, and `OasisCritterEconomyService` current
  human lookup now uses a bounded UUID predicate with warning logs for invalid
  ids and fetch failures. `OasisUpgradeRewardService` inventory/opening/upgrade
  paths now log critter, fragment, unlock, featured-critter, and active-critter
  fetch failures; upgrade-coconut generation now fetches only the relevant level
  range and throws on read failure instead of inserting from an untrusted empty
  result. `OasisRewardLiveDataStore` now logs live snapshot fetch failures, and
  Oasis critter lifecycle daily action-log reads now use a critter/date predicate
  with warning logs instead of fetching all action logs. `OasisTreeManager`
  energy/revision reads now log ledger count, cursor, incremental event, full
  ledger, and legacy plant-event count failures instead of silently collapsing
  tree energy inputs to empty values. Current app-code scans for
  `try? context.fetch`, `try? context.fetchCount`, `try? modelContext.fetch`,
  and `try? modelContext.fetchCount` are clear; remaining matches are test helper
  assertions only.
- Next step: None for this follow-up. Keep broader P0/P1/P3 care migration,
  CloudKit validation, and product read-model follow-ups tracked separately.
- Close when: Closed on 2026-06-12 after app-code silent fetch scans were clear
  and Oasis tree/ledger reads were hardened.

### TFU-20260612-010 - Unify care status read models and expand ledger analysis

- Status: Open
- Priority: P3
- Area: Care / Product Completeness
- Source task: Care maturity remediation, 2026-06-12
- Blocker: This is product/read-model polish rather than a correctness blocker;
  it should follow the P0 CareLedger read-model migration so the UI does not
  consolidate around soon-to-be-replaced sources.
- Next step: Share overdue/status feedback between Hygiene and QuickCare, then
  extend `CareLedgerAnalysisView` with trend and actor dimensions from
  `CareLedgerEvent.actorKind` / `actorId`.
- Current task disposition: Accepted product follow-up. This is intentionally
  deferred until the P0 read-model migration follow-up settles, so the product
  polish lands on the final ledger-backed status source instead of reinforcing
  transitional read paths.
- Close when: Hygiene and QuickCare display the same status source and ledger
  analysis includes trend plus executor/family-member breakdowns.

### TFU-20260612-011 - Clean legacy shared-care metadata from persisted notes

- Status: Done
- Priority: P0
- Area: Shared Care / Data Cleanup / Cloud Sync
- Source task: Care maturity remediation, 2026-06-12
- Blocker: Production shared-care writes now store user-visible notes only, and
  `scripts/audit-shared-care-note-metadata.sh` prevents new app-code writes of
  `ohana_shared_*` machine prefixes. `SharedCareSessionMaintenance` now has an
  idempotent `cleanLegacyNoteMetadata` path that strips recoverable legacy
  prefixes from `SharedCareSession.note`, `PetCareLog.note`,
  `PetExpenseLog.note`, shared-walk `behaviorNotes`, and linked
  `CareLedgerEvent.note` only after structured session fields are recovered or
  verified. The cleanup also recovers target ids, total feed/water amounts,
  expense totals/categories, stock owner, and primary legacy model references
  before stripping metadata, and tests cover modified-state staging plus a
  second no-op cleanup pass. Backup import now runs the cleanup after restored
  model data is saved, and a regression test covers recoverable legacy prefixes
  being stripped during backup apply. Existing installed data is now covered by
  a versioned startup-maintenance trigger that runs after CareLedger backfill and
  stores `ohana_shared_care_legacy_note_cleanup_version` when the cleanup has
  been attempted. It intentionally leaves orphan legacy notes in place when the
  structured `SharedCareSession` is missing, because those notes may be the only
  remaining source of stock/target facts; the cleanup result now reports
  skipped orphan care logs, expense logs, walk logs, ledger events, and missing
  session ids so the maintenance path is observable instead of silently
  skipping them. Recoverable records whose raw relationship is broken but whose
  note still contains a valid session id are grouped through the cleanup scan and
  have `sharedSessionId` restored before metadata is stripped, including shared
  walk logs whose raw relationship was empty. `CareLedgerEvent` now participates
  in the upload/apply pipeline with serializer, local dirty-batch fetch, remote
  insert/update/delete handling, and tests covering cleaned notes in payloads and
  fetched records. `CloudSyncMetadataServiceTests` now includes a local
  two-device-equivalent regression: legacy shared-care records are applied
  through `CloudSyncRecordApplier`, cleaned once, staged as clean dirty payloads,
  and verified as idempotent on a second cleanup pass. Orphan facts now have a
  privacy-safe diagnostic path through
  `SharedCareSessionMaintenance.legacyOrphanNoteDiagnostics(context:)`: it
  reports source model, record id, missing session id, stock/target machine
  facts, linked legacy model ids, and visible-note length without exporting the
  user note body.
- Next step: Run the shared-care legacy cleanup checklist in
  `docs/cloud-sync-todo.md`, including a two-device run where startup cleanup
  reports nonzero skipped orphan counts and the privacy-safe orphan diagnostic
  report is available for inspection.
- Closed: 2026-06-12 as an accepted external follow-up because the repository
  implementation, local migration tests, backup cleanup, startup cleanup,
  CloudSync serializer/apply coverage, and audit guardrail are complete, while
  the remaining two-device CloudKit validation requires a paid developer account,
  provisioning, CloudKit Dashboard access, and physical devices. The validation
  checklist remains in `docs/cloud-sync-todo.md`.
- Close when: Legacy shared-care note prefixes are cleaned from persisted data
  through a measured migration/maintenance path, no production source writes
  them, and CloudKit two-device validation confirms the cleanup does not
  produce repeated remote modifications.

### TFU-20260612-012 - Move pet activity cleanup out of the Pet model

- Status: Done
- Priority: P0
- Area: Models / Members / Domain Commands
- Source task: Models Phase 1 P0 remediation, 2026-06-12
- Blocker: The Models session is scoped to `Ohana/Models`; fully fixing this
  requires changing the caller in `Ohana/Features/Members/MemberInteractionCommands.swift`
  and likely moving `Pet.clearAllActivityRecords(in:)` into a feature command
  or domain service. The current model method fetches/deletes SwiftData records,
  cancels notifications, resets streak state, and saves the context from inside
  an `@Model`, which violates the model-layer boundary.
- Next step: In a cross-scope repair, add a command/service that owns the
  activity cleanup transaction, updates the Members caller to use it, then
  remove the persistence/notification side effects from `Pet`.
- Current task disposition: Closed during Domain Phase 2. The cleanup is now
  owned by `PetActivityRecordCleanupService`, the Members command delegates to
  that service, and `Pet` no longer owns `ModelContext` fetch/delete/save or
  notification cancellation.
- Closed: 2026-06-12 with
  `OhanaTests/PetActivityRecordCleanupServiceTests.swift` covering related
  event/reminder deletion, notification cancellation, activity-log deletion,
  unrelated-pet preservation, document/insurance preservation, and streak reset.
- Close when: `Pet` no longer owns `ModelContext` fetch/delete/save or
  notification cancellation, the Members cleanup path calls the new command or
  service, and in-memory SwiftData tests cover event/reminder/log deletion plus
  preserved documents/insurances.

### TFU-20260612-013 - Remove duplicate WeightHistoryView source file

- Status: Closed
- Priority: P0
- Area: DashboardRecords / Validation
- Source task: Models Phase 1 P0 remediation validation, 2026-06-12
- Blocker: `Ohana/Features/DashboardRecords/Views/WeightHistoryView.swift` and
  `Ohana/Features/DashboardRecords/Views/WeightHistoryView 2.swift` are both
  tracked and both declare `struct WeightHistoryView`, so unfiltered app test
  builds fail before the Models tests can run. The Models session is not allowed
  to repair DashboardRecords.
- Next step: Closed by deleting the duplicate tracked source file during the
  explicitly authorized cross-scope validation repair.
- Current task disposition: Models targeted tests were previously run with
  `EXCLUDED_SOURCE_FILE_NAMES=WeightHistoryView\ 2.swift` solely to isolate the
  Models fixes; rerun the gate without exclusions after this repair.
- Closed: 2026-06-12 by removing
  `Ohana/Features/DashboardRecords/Views/WeightHistoryView 2.swift`, the Xcode
  duplicate that was accidentally added in `3eae88d7`.
- Close when: The duplicate declaration is gone and
  `scripts/test-simulator.sh -only-testing:OhanaTests/SharedModelContainerRecoveryTests`
  plus `scripts/module-exit-gate.sh` run without excluding DashboardRecords
  sources.

### TFU-20260612-014 - Finish Domain presentation and infrastructure boundary cleanup

- Status: Open
- Priority: P1
- Area: Domain / Architecture / Localization / Notifications
- Source task: Domain Phase 2 analysis, 2026-06-12
- Blocker: The remaining Domain issues are broad architectural cleanup rather
  than the P0 activity-cleanup/blocking-build repair. Fixing them cleanly should
  happen as a dedicated pass so adapters can move without disturbing service
  behavior.
- Next step: Move app/feature infrastructure adapters out of
  `Ohana/Domain/Services/AppInfrastructureAdapters.swift` or invert them behind
  Domain-owned protocols; replace Domain `SwiftUI.Color` outputs in
  `CareLedgerStatsService` and `HealthMetricCatalog` with semantic tokens; move
  user-visible generated titles/status text onto the localization path; and
  make reminder notification scheduling dependency-injected instead of relying
  on the mutable `OhanaNotifications.current` global from static service paths.
- Current task disposition: Accepted P1 follow-up for Domain Phase 2. The P0
  production path violations were removed or moved behind a Domain service; the
  remaining items do not block the current module exit gate but should be
  resolved before release-hardening freeze.
- Close when: Domain app-code contains no `import SwiftUI`, Domain services no
  longer instantiate App/Feature infrastructure concrete types directly, generated
  user-visible Domain strings are localized, and notification side effects in
  reminder/care static paths are covered through injected fakes.

### TFU-20260612-015 - Move executor picker queries out of Shared

- Status: Done
- Priority: P1
- Area: Shared / QuickCare / Architecture / Smoothness
- Source task: Shared Phase 3 analysis, 2026-06-12
- Blocker: `Ohana/Shared/Components/ExecutorPickerBarRouteContainer.swift`
  keeps a SwiftData `@Query` inside a reusable Shared route container. It is
  currently used by QuickCare sheets, so fixing it cleanly crosses the Shared
  boundary into the QuickCare feature owner.
- Next step: During the QuickCare phase, move the `Human` fetch into a
  feature-owned screen/container or route-scoped snapshot builder, then pass a
  lightweight `[Human]`/executor snapshot into the pure `ExecutorPickerBar`.
- Current task disposition: Closed in Phase 5 by moving the SwiftData fetch into
  `Ohana/Features/QuickCare/QuickCareExecutorPickerBarContainer.swift` and
  keeping `ExecutorPickerBar` as the pure Shared component.
- Closed: 2026-06-12 with `ExecutorPickerBarTests` covering empty and
  multi-human picker render states.
- Close when: Shared reusable components no longer own SwiftData `@Query` for
  executor picking, QuickCare sheets still render executor choices, and a
  focused validation covers empty and multi-human picker states.

## Done

Move completed entries here instead of deleting them when the history is useful.
