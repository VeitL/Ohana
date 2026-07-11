# Task Follow-ups

> Active backlog only. The pre-audit-sync version is archived at
> [`docs/archive/task-follow-ups-2026-07-10-pre-audit-sync.md`](archive/task-follow-ups-2026-07-10-pre-audit-sync.md).
> Older history is at
> [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md).
>
> Status ownership: [`docs/status-ledger-map.md`](status-ledger-map.md).

## Current Read

- Last compacted: 2026-07-11.
- Open follow-ups: 12 total: P1 = 8, P2 = 4, P3 = 0.
- Open P0: 0.
- First-release repository blocker: none.
- First-release proof/product/correctness gaps: TFU-20260710-007 through
  TFU-20260710-009.
- Current decision: continue hardening; do not claim RC/App Store readiness
  until the first-release P1 items are explicitly dispositioned.

## Priority Meaning

| Priority | Meaning |
| --- | --- |
| P0 | First-release-reachable data loss, privacy, corruption, crash, or core-flow blocker. Must close before RC sign-off. |
| P1 | Important correctness, release-proof, product-contract, or real-device gap. Must be explicitly dispositioned before release. |
| P2 | Non-blocking depth, polish, or broader validation debt. |
| P3 | Future improvement with no current release impact. |

## Open Items

### TFU-20260710-007 - Enforce Valid Expense Values At Domain And Restore Boundaries

- Priority / bucket: P1, first-release-reachable business/data correctness.
- Blocker: UI validation does not prevent command or restore paths from writing
  non-positive or non-finite expense values.
- Next action: define one domain invariant and reject invalid values in command,
  import/preflight, and rehydrate paths with localized recovery errors.
- Close when: zero, negative, NaN, and infinity tests fail before persistence;
  existing valid expense and backup round trips remain green.

### TFU-20260710-008 - Separate Reduce Motion From Efficient Motion

- Priority / bucket: P1, first-release accessibility/runtime behavior.
- Blocker: Reduce Motion maps to the same `.efficient` policy used for energy
  degradation, while some callers only test `allowsMotion`; motion semantics can
  remain active when the user requested reduction.
- Next action: define full/efficient/minimal behavior at `AppWorkloadPolicy`,
  audit callers, and add route/animation policy tests before device acceptance.
- Close when: Reduce Motion produces the documented minimal behavior across the
  core onboarding/Home/quick-care/modal paths without removing essential state
  feedback.

### TFU-20260710-009 - Decide And Verify The Supported Device Matrix

- Priority / bucket: P1, product/release configuration decision.
- Blocker: minimum iOS 26.2 and iPad support are current build facts, but the
  product has no approved launch-device policy or oldest-device proof.
- Next action: the product owner confirms minimum iOS, iPhone/iPad scope, and
  Storefront availability; then align project settings, docs, screenshots, and
  the physical-device test matrix in one release-config change.
- Close when: the signed Archive, App Store Connect device support, OS matrix,
  and recorded oldest-supported-device smoke run agree.

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
- Blocker: simulator/build proof cannot validate real Health authorization,
  Activity Summary values, or workout sample reads.
- Next action: run the signed Human Workout checklist with real Health data.
- Close when: permission, read-only summaries, selected workout import, relaunch
  persistence, denial, and revocation behavior are recorded.

### TFU-20260709-001 - Validate Solo Release Privacy And Runtime Paths On iPhone

- Priority / bucket: P1, external/manual validation.
- Blocker: local proof cannot establish OS backup contents, signed capability
  profile, public URLs, the final App Store Connect Apple ID/storefront record,
  hardware performance/energy, locked-screen location, or iCloud Drive failure
  recovery. The app hides Rate App until that Apple ID is verified.
- Next action: execute R1-R6 in `docs/release-true-device-test-plan.md`, including
  encrypted device backup/restore inspection for the new Application Support
  backup-exclusion policy.
- Close when: all R1-R6 results identify the signed Release build and device;
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
