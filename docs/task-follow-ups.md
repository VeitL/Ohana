# Task Follow-ups

> Active backlog only. The pre-audit-sync version is archived at
> [`docs/archive/task-follow-ups-2026-07-10-pre-audit-sync.md`](archive/task-follow-ups-2026-07-10-pre-audit-sync.md).
> Older history is at
> [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md).
>
> Status ownership: [`docs/status-ledger-map.md`](status-ledger-map.md).

## Current Read

- Last compacted: 2026-07-11.
- Open follow-ups: 9 total: P1 = 5, P2 = 4, P3 = 0.
- Open P0: 0.
- First-release repository blocker: none. TFU-20260711-002 is closed; the
  wallet, full architecture, production-complexity, and release-static gates
  pass on the current worktree.
- First-release product/configuration gap: none. D24 approves iPhone-only,
  iOS 26.2+, with native iPad/watchOS deferred.
- Current decision: finish the four physical-device P1 items. The remaining
  CloudKit P1 is explicitly deferred and unreachable in Solo. Do not claim
  RC/App Store readiness until all release-reachable P1 items are dispositioned.

## Priority Meaning

| Priority | Meaning |
| --- | --- |
| P0 | First-release-reachable data loss, privacy, corruption, crash, or core-flow blocker. Must close before RC sign-off. |
| P1 | Important correctness, release-proof, product-contract, or real-device gap. Must be explicitly dispositioned before release. |
| P2 | Non-blocking depth, polish, or broader validation debt. |
| P3 | Future improvement with no current release impact. |

## Open Items

### TFU-20260614-014 - Validate CloudSync Live-Apply Policy When Family Enables

- Priority / bucket: P1, deferred CloudKit 1.x / first-release-unreachable.
- Blocker: local tests cover delete-wins, parent lifecycle, and natural identity,
  but the Solo target has no CloudKit/APNs capability and uses
  `cloudKitDatabase: .none`.
- Next action: run shared-zone conflict/deletion validation only when the Family
  product gate and capability profile are explicitly enabled.
- Close when: two-device CloudKit evidence confirms convergence without
  resurrection, duplicate ownership, or derived-state drift.

### TFU-20260612-017 - Validate Memorial Mode On Real UI And Notifications

- Priority / bucket: P1, external/manual validation.
- Blocker: simulator tests cannot prove physical notification removal/delivery
  and final memorial-mode behavior on a real device.
- Next action: execute GAP-9 on a signed build and record device/OS/build evidence.
- Close when: deceased members remain out of active care/notification surfaces
  while permitted memorial content remains usable.

### TFU-20260612-016 - Validate Notification Delivery On Real Devices

- Priority / bucket: P1, external/manual validation.
- Blocker: repository tests prove scheduling policy and action routing, not
  system permission prompts, banners, lock-screen delivery, Focus/DND, or
  action delivery from notification UI.
- Next action: execute GAP-6 on physical devices.
- Close when: creation, delivery, tap/action routing, cancellation, and privacy
  presentation pass in foreground, background, and locked states.

### TFU-20260706-001 - Validate Human Workout HealthKit On A Real Device

- Priority / bucket: P1, external/manual validation.
- Progress: on 2026-07-11, the user confirmed that HealthKit authorization and
  the other displayed Health values matched on the physical-device signed
  build. Exercise, Stand, and the concentric activity rings did not populate.
  A selected workout did persist—the import control changed to its delete
  state—but the UI gave no visible success message. The local repair now reads
  Exercise Time and Stand Hour directly when Activity Summary is absent or
  partial, keeps ring goals unavailable instead of inventing them, and exposes
  localized import success/failure feedback. Targeted Unit/Integration passed
  7/7; this repair is not yet signed-device verified.
- Blocker: the repaired Exercise/Stand reads, real activity-goal rings, visible
  import feedback, relaunch persistence, denial, and revocation recovery remain
  unverified on a newly signed build with real Health data.
- Next action: install a newly signed build without clearing app data, grant the
  newly requested Exercise Time and Stand Hour reads if prompted, then repeat
  summary refresh, one selected-workout import, relaunch, denial, and revocation.
- Close when: permission, read-only summaries, selected workout import, relaunch
  persistence, denial, and revocation behavior are recorded.

### TFU-20260709-001 - Validate Solo Release Privacy And Runtime Paths On iPhone

- Priority / bucket: P1, external/manual validation.
- Progress: on 2026-07-11 a development-signed Release 1.0 (1) Archive succeeded
  from commit `eece7d642` plus the current dirty worktree. Strict code-sign
  verification passed; the product is arm64, iPhone-only, iOS 26.2+, contains
  no extension/watchOS content, and exposes HealthKit plus CloudDocuments but
  no CloudKit, APNs, or App Group entitlement. The profile includes the current
  iPhone 17 Pro Max, and the same archived app installed and launched on iOS
  26.5.2 (23F84). After explicit approval, the local app container was cleared
  by uninstalling the app; the same Archive was reinstalled and launched for a
  clean first-run smoke without deleting iCloud Drive/external backups. The
  public privacy-policy URL is anonymously reachable. The on-screen core smoke
  then reproduced a release blocker in the preserved one-Pet/no-Human sample:
  Oasis showed 59🥥 but tree injection only vibrated. The current worktree now
  assigns the 50🥥 D17 grant to `system:island`, migrates an old member-owned
  gift once without changing the total, and lets tree injection atomically use
  the formal island total. Targeted Unit/Integration passed 32/32 and the
  no-Human Pet-first five-injection UI path passed 1/1 on the iPhone 17 simulator.
  A new incremental `-O` Release device build passed strict signing, overlaid
  without uninstalling, and launched on the same iPhone. A read-only device
  store copy proves the migration committed exactly once: `system:island=50`,
  Pet=9, `system:legacy=0`, with paired -50/+50 transfer facts and a marker.
  On 2026-07-11, the user physically tapped tree injection on the already
  overlaid Release and confirmed the expected coconut deduction and energy
  increase. The preserved 59🥥 Oasis regression is therefore device-verified.
- Blocker: the current machine has only an Apple Development identity, so this
  does not establish App Store distribution, the final App Store Connect Apple
  ID/storefront, or Store validation of screenshots. The smallest physical
  iPhone, OS backup contents, hardware performance/energy, locked-screen
  location, notification dialogs, HealthKit data/revocation, and iCloud Drive
  failure recovery remain unverified. The app hides Rate App until the Store
  identity is verified.
- Next action: finish R1-R6 and run the same R0 smoke on the smallest supported
  physical iPhone; obtain App Store distribution/App Store Connect evidence
  and inspect an encrypted device backup for the Application Support exclusion
  policy.
- Close when: all R0-R6 results identify the signed Release build and device;
  any defect is fixed or split into a scoped follow-up.

### TFU-20260629-004 - Finish Pet Simulator GUI Depth

- Priority / bucket: P2, simulator/UI coverage depth.
- Blocker: broad Pet paths pass, but some negative/edit/shop/stale-route and
  cross-feature long-session combinations remain unautomated.
- Next action: add only narrow tests exposed by real regression risk; use the
  dogfood simulator for persistent old-user scenarios.
- Close when: the remaining release-relevant Pet negative paths have stable
  automated or recorded manual proof.

### TFU-20260612-020 - Finish Long-Language Visual Coverage

- Priority / bucket: P2, localization/accessibility polish.
- Blocker: source localization checks are strong, but dense Pet/Human/Plant
  screens still need a final long-language visual sweep.
- Next action: inspect core dense screens with long German text and maximum
  Dynamic Type; add targeted layout guards for actual failures.
- Close when: launch-critical screens remain readable without truncating
  actions or breaking interaction.

### TFU-20260710-010 - Retire Remaining Concurrency And Global-Lifecycle Debt

- Priority / bucket: P2, incremental engineering debt.
- Blocker: Avatar/Medication actor boundaries, notification registry lifetime,
  QuickFeed anonymous task ownership, and mixed `AppServices`/static registries
  weaken Swift 6 isolation and cancellation proof without a confirmed current
  user-visible failure.
- Next action: fix only when touching the owning surface: cross actors with IDs
  or DTOs, attach tasks to route owners, and prefer instance dependencies.
- Close when: strict-concurrency builds and targeted cancellation/isolation
  tests cover each listed boundary and no parallel registry owns the same work.

### TFU-20260710-011 - Finish Bounded Maintenance And Scoped Home Invalidation

- Priority / bucket: P2, performance/energy debt.
- Blocker: some backup/restore/reset work still lacks one cursor/budget/cancel
  contract, and legacy broad `homeRevision` invalidation remains beside scoped
  surface tokens; static evidence does not prove a current runtime regression.
- Next action: migrate one measured hot path at a time, with dense fixtures and
  ETTrace/Instruments or signpost evidence rather than broad refactoring.
- Close when: high-cost maintenance is bounded/cancellable/low-power aware and
  measured Home flows no longer depend on broad invalidation.

## Update Rules

- Keep only active work here. Archive closed detail during compaction.
- Every entry needs priority, blocker, next action, and close condition.
- Do not paste command transcripts into this file.
- Run `scripts/audit-doc-status-ledgers.sh` after changes.
