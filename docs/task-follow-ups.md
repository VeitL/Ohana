# Task Follow-ups

> Active backlog only. The pre-audit-sync version is archived at
> [`docs/archive/task-follow-ups-2026-07-10-pre-audit-sync.md`](archive/task-follow-ups-2026-07-10-pre-audit-sync.md).
> Older history is at
> [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md).
>
> Status ownership: [`docs/status-ledger-map.md`](status-ledger-map.md).

## Current Read

- Last compacted: 2026-07-20.
- Open follow-ups: 12 total: P1 = 7, P2 = 4, P3 = 1.
- Open P0: 0.
- First-release repository blocker: no known P0 defect, and two
  release-reachable P1 implementation/proof gaps remain. Human-first/D28
  repository and Simulator proof closed on 2026-07-18: the final repair batch
  passed 57/57 focused tests and 15/15 after its last warning-only isolation
  annotation; the complete release-static lane passed; optimized and WMO
  Simulator Release products compiled; and the protected Dogfood user passed
  a normal-UI Task Center branch/relaunch readback with sealed identity and no
  balance or test-artifact pollution. Signed-device acceptance remains open
  under the existing physical-device items. The Free / Personal worktree
  contains quota enforcement, three Personal products, StoreKit
  trial-eligibility handling, legacy Supporter
  grandfathering, downgrade protection, paid capability gates, and the paywall;
  its App + UI target compiles and its focused Unit artifact reports 67/67
  passing. Complete nine-language in-app commerce copy and real App Store /
  Sandbox acceptance remain open. The 2026-07-20 worktree also implements a
  privacy-bounded Personal Today Widget and a Free/Personal walk Live Activity
  with Dynamic Island presentation; 89 focused tests pass and clean plus final
  incremental optimized Simulator Release builds embed and validate the
  extension. Registering the two App
  Groups, producing a signed current package, and physical-device Widget /
  Dynamic Island acceptance remain open. The earlier storage and conflict-copy
  build Swift-source build blockers are cleared.
- First-release product/configuration gap: 1.0 is now Free plus Personal.
  Free allows 1 active Pet, 2 active Humans, 5 active Plants, and 3 ordinary
  active logical plans while preserving basic records, existing history,
  manual export, critical-health plans, and memorials. Personal is monthly,
  yearly, or Lifetime and adds unlimited active capacity plus approved advanced
  local tools and Supporter cosmetics. The app still deliberately has no Ohana
  account, login, developer backend, Family, Care+, or ads. D24 still approves
  iPhone-only, iOS 26.2+, with native
  iPad/watchOS deferred.
- Current decision: close TFU-20260715-003 and TFU-20260720-001 before final
  signed-device RC acceptance. The remaining CloudKit P1 is explicitly
  deferred and unreachable in the local-only first release. The future
  account design is recorded in
  `docs/planning/account-backend-extension.md`; the requested family invitation
  and explicit Human-linking flow is tracked below as P3 discovery only and does
  not activate an account, backend, or online collaboration capability. Do not
  claim RC/App Store readiness until all release-reachable P1 items are
  dispositioned.

## Priority Meaning

| Priority | Meaning |
| --- | --- |
| P0 | First-release-reachable data loss, privacy, corruption, crash, or core-flow blocker. Must close before RC sign-off. |
| P1 | Important correctness, release-proof, product-contract, or real-device gap. Must be explicitly dispositioned before release. |
| P2 | Non-blocking depth, polish, or broader validation debt. |
| P3 | Future improvement with no current release impact. |

## Open Items

### TFU-20260715-003 - Ship And Validate Free / Personal 1.0

- Priority / bucket: P1, current first-release implementation, Store
  configuration, quota migration, and purchase acceptance.
- Blocker: the current worktree implements the centralized Monthly / Yearly /
  Lifetime catalog, verified legacy Supporter grandfathering, Free quotas,
  logical-plan grouping, reactivation protection, downgrade grandfathering,
  StoreKit-sourced trial eligibility, paid capability gates, and paywall. The
  current App + UI target compiles and
  `.build/TestResults/PersonalFocused.xcresult` reports 67/67 focused Unit tests
  passing. Free space is about 44 GiB and no `* 2.swift` / `* 3.swift` conflict
  copies remain, so the earlier local build blockers are cleared. App Store
  Connect, Sandbox, second-device restore, subscription lifecycle, signed
  Storefront, assistive-technology, and complete nine-language App commerce
  copy remain absent.
- Next action: reconcile any remaining focused quota,
  plan-grouping/reactivation, capability, UI-contract, catalog, and entitlement
  selectors against the current source, and complete the remaining App commerce
  languages. Then validate StoreKit product
  loading, verified/unverified purchase, pending, cancel, failure,
  `currentEntitlements`, `Transaction.updates`, `AppStore.sync()`, offline,
  trial conversion, subscription expiration, Lifetime, refund/revocation, and
  restore. Keep ads absent and preserve Coconut / `ShopPurchaseRecord`
  ownership.
- Close when: affected App/test targets compile and targeted tests execute with
  non-zero coverage; Free quotas and logical-plan deduplication pass; Personal
  is unlimited; all over-quota grandfather/downgrade paths preserve data and
  only block further increasing operations; Monthly / Yearly / Lifetime and
  legacy Supporter all produce the correct unified Personal entitlement; yearly
  trial eligibility comes from StoreKit; every failure leaves Free data and
  Coconut ownership unchanged; nine-language/accessibility coverage passes; a
  final signed 1.0 build loads the real localized Storefront products; Sandbox
  subscription, Lifetime, second-device restore, trial/expiration, and
  refund/revocation pass; agreements, tax/banking, metadata, review materials,
  and submission are ready and recorded in the active release dashboard.

### TFU-20260720-001 - Sign And Validate Widget And Walk Live Activity

- Priority / bucket: P1, current first-release capability and physical-device
  acceptance.
- Progress: the current worktree adds an embedded WidgetKit extension with a
  bounded Personal Today Widget, accessory presentation, typed deep links, and
  a walk Live Activity covering Lock Screen plus Dynamic Island expanded,
  compact, and minimal regions. The app owns the SwiftData projection, writes
  at most three minimized task DTOs through a dedicated App Group JSON file,
  preserves a recoverable active walk across relaunch, removes stale
  activities, and routes all update frequency through `AppWorkloadPolicy`.
  Seven focused suites execute 89/89 tests, and the unsigned Simulator and
  LocalDevice lanes compile and embed both app and extension. A clean-cache
  dual-architecture optimized Release build and the final incremental recheck also pass
  `ValidateEmbeddedBinary` for the extension.
- Blocker: `group.com.guanchen.li.Ohana` and
  `group.com.guanchen.li.Ohana.LocalDevice` have not been registered and
  approved in Developer Portal provisioning for both app and extension. No
  signed current Archive or physical-device run has therefore proved shared
  snapshot access, Home/Lock Screen Widget rendering, Dynamic Island behavior,
  foreground/background location handoff, or locked-device privacy.
- Next action: register each App Group on its matching app and Widget extension
  identifiers, regenerate profiles, then install one signed current Release.
  Exercise Personal, Free, downgrade, locked/redacted, stale, reset, and deep
  link Widget states; then run an active dog walk through start, pause, resume,
  distance/poop updates, relaunch, background/lock, deep link, and finish on a
  Dynamic Island-capable iPhone.
- Close when: the signed package embeds the extension with exact matching
  entitlements; all Widget families render current, locked, empty, and stale
  states without leaking deleted, deceased, health, or free-form task data;
  links restore the intended route from cold and warm launch; one active walk
  survives relaunch without duplication and ends cleanly; key long-language,
  Dynamic Type, Reduce Motion, Low Power, and locked-screen states are recorded.

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
  The former import control changed to delete after use but gave no visible
  result, which exposed a deeper source-model problem: HealthKit workouts were
  being copied into Ohana even though the screen can read them directly. The
  local repair now reads Exercise Time and Stand Hour directly, supports both
  active-energy and Apple Move Time goals, renders each available ring without
  hiding the other two, and presents HealthKit and PetWalk workouts as read-only
  live rows. Only Ohana manual workout facts remain deletable. Existing local
  external-source copies are preserved as fallback and hidden only while their
  live source is available. Targeted Unit/source-contract tests passed 10/10;
  this repair is not yet signed-device verified.
- Blocker: the repaired Exercise/Stand reads, active-energy or Move Time goal
  rings, direct read-only Recent Workouts, relaunch, denial, and revocation
  recovery remain unverified on a newly signed build with real Health data.
- Next action: install a newly signed build without clearing app data, grant the
  newly requested Exercise Time and Stand Hour reads if prompted, then repeat
  summary refresh; confirm Recent Workouts appear without import/delete controls;
  then test relaunch, a denied individual type, and permission revocation.
- Close when: permission, read-only summary and workout display, per-ring goal
  states, relaunch, denial, and revocation behavior are recorded.

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
  Those results continue to prove island-reserve migration and injection for
  that build, but they do not validate the current Human-first route, explicit
  claim gate, or D28 journey.
  A new incremental `-O` Release device build passed strict signing, overlaid
  without uninstalling, and launched on the same iPhone. A read-only device
  store copy proves the migration committed exactly once: `system:island=50`,
  Pet=9, `system:legacy=0`, with paired -50/+50 transfer facts and a marker.
  On 2026-07-11, the user physically tapped tree injection on the already
  overlaid Release and confirmed the expected coconut deduction and energy
  increase. The preserved 59🥥 Oasis regression is therefore device-verified.
  A 2026-07-12 device-local Apple identity prototype and a later provider-neutral
  backend prototype were evaluated but never became the product. On 2026-07-12
  both were removed: the current target has no Sign in with Apple entitlement,
  login UI, Auth SDK, Supabase project, or account data collection. Their signed
  Archive and simulator tests remain historical evidence only and cannot be used
  to describe or approve the current build. Future design is retained solely in
  `docs/planning/account-backend-extension.md`.
  Later on 2026-07-12, the current local-only worktree produced and verified
  `/tmp/OhanaArchives/2026-07-12-180306/Ohana-c2aa2af859-dirty.xcarchive`.
  The signed arm64/iPhone-only/iOS 26.2+ App contains HealthKit + CloudDocuments
  only and no Sign in with Apple, CloudKit, APNs, App Group, remote notification,
  extension, Supabase/crypto artifact, collected-data type, or tracking domain.
  It overlaid and launched on iPhone 17 Pro Max / iOS 26.5.2 without uninstalling
  or clearing data; the process remained present. User-observed data preservation
  and repaired HealthKit behavior still await confirmation.
- Blocker: the current machine has only an Apple Development identity, so this
  does not establish App Store distribution, the final App Store Connect Apple
  ID/storefront, or Store validation of screenshots. The smallest physical
  iPhone, OS backup contents, hardware performance/energy, locked-screen
  location, notification dialogs, HealthKit data/revocation, and iCloud Drive
  failure recovery remain unverified. The generated development profile permits
  broader APNs/iCloud capabilities than the signed Solo App claims; verify the
  distribution profile and Developer Portal capability state before release.
  The app hides Rate App until the Store identity is verified.
- Next action: on the already overlaid current local-only build, confirm preserved
  data and run the repaired HealthKit matrix; then finish R1-R6 and run the same
  core smoke on the smallest supported
  physical iPhone; obtain App Store distribution/App Store Connect evidence and
  inspect an encrypted device backup for the Application Support exclusion policy.
- Close when: all R0-R6 results identify the signed Release build and device;
  any defect is fixed or split into a scoped follow-up.

### TFU-20260629-004 - Finish Pet Simulator GUI Depth

- Priority / bucket: P2, simulator/UI coverage depth.
- Blocker: all 119/119 formal UI selectors now have cumulative trusted green
  evidence, but some negative/edit/shop/stale-route combinations remain outside
  the manifest. Two passing current-build Walk journeys reproducibly emit
  CoreLocation's main-thread UI-unresponsiveness runtime warning as the live
  route starts. The result bundles provide no stack or source location, and a
  source search finds no direct `locationServicesEnabled()` call, so App versus
  MapKit/CoreLocation attribution remains open; no visible stall was measured.
- Next action: add only narrow tests exposed by real regression risk. Attribute
  the Walk warning with a focused stack/profile or signpost before changing
  product code, rerun the narrow Walk path afterward, and cover locked-screen
  location on the physical-device lane. Use the Dogfood simulator only for
  non-destructive persistent old-user scenarios.
- Close when: remaining release-relevant Pet negative paths have stable
  automated or recorded manual proof and the Walk warning is either removed
  from product code or attributed to the platform with measured non-regression.

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

### TFU-20260715-001 - Design Secure Family Invitation And Explicit Human Linking

- Priority / bucket: P3, future Ohana Family account/backend discovery;
  first-release-unreachable.
- Blocker: Solo has no authenticated account, server-owned household membership,
  invitation service, or remote authorization boundary. An invitation code alone
  cannot safely establish identity or grant household access, and the permission,
  privacy, reward, and task behavior of an unlinked membership is not yet approved.
- Next action: only after D25's account activation trigger is approved, specify
  an idempotent invitation state machine covering owner/admin issuance,
  single-use expiry, authenticated redemption, revocation, retry/rate limits,
  roles, last-owner protection, and audit history. Keep Account, HouseholdMembership,
  and Human separate: joining creates a membership first, then the owner/admin may
  propose linking an unclaimed existing Human or the invitee may explicitly create
  a new Human. An adult existing-Human link requires the invitee's confirmation;
  define dependent/guardian handling and unlinked-member permissions before schema
  or UI work begins.
- Close when: the product foundation explicitly activates the account/Family
  capability, the identity and data threat model is approved, server authorization
  tests cover invitation and linking invariants, and signed-device flows prove
  create/share/enter/redeem/expire/revoke/retry plus explicit Human linking without
  silently creating, merging, or claiming a profile.

## Update Rules

- Keep only active work here. Archive closed detail during compaction.
- Every entry needs priority, blocker, next action, and close condition.
- Do not paste command transcripts into this file.
- Run `scripts/audit-doc-status-ledgers.sh` after changes.
