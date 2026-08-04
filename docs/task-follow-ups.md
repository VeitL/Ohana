# Task Follow-ups

> Active backlog only. The pre-audit-sync version is archived at
> [`docs/archive/task-follow-ups-2026-07-10-pre-audit-sync.md`](archive/task-follow-ups-2026-07-10-pre-audit-sync.md).
> Older history is at
> [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md).
>
> Status ownership: [`docs/status-ledger-map.md`](status-ledger-map.md).

## Current Read

- Last compacted: 2026-08-04.
- Open follow-ups: 13 total: P1 = 8, P2 = 4, P3 = 1.
- Open P0: 0.
- Current local evidence: the complete Unit suite executes 2,310 tests with 0
  failures, and the complete release static lane passes. The current
  132-selector / 9-shard UI campaign records 130 pass and 2 fail; after the two
  repairs, both exact former failures pass 2/2 through the governed entrypoint.
  Per the product owner's instruction the unchanged full campaign was not rerun,
  so no single-pass 132/132 claim is made. One guarded WMO Release overlay and
  normal-UI Human detail/gender-menu open-cancel journey pass with the sealed
  existing-user store intact. Commit `3ee93cf718` also has a verified local
  Apple Development-signed WMO Release Archive and an Archive-generated Xcode
  Privacy Report after the Widget File Timestamp overdeclaration was removed.
  The distribution-signed Archive and physical-device lanes remain separate.
- First-release product/configuration gap: 1.0 remains iPhone-only,
  iOS 26.2+, Free plus Personal. The repository now contains nine-locale
  App metadata, 36 IAP localization drafts for Monthly/Yearly/Lifetime plus
  conditional restore-only legacy Supporter, review notes, screenshot plan and
  compliance checklist. D34 places local Human health conditions, observations,
  manual records and Personal on-device lab-report scanning in 1.0; the current
  implementation, migration, backup/reset/privacy, complete Unit/static,
  failure-cleared UI campaign and protected Dogfood evidence are recorded.
  Real App Store Connect, Sandbox, second-device restore,
  subscription lifecycle, signed Storefront and assistive-technology evidence
  remain absent.
- Family/Care+ remain outside 1.0. Solo now closes Guardian at compile/runtime,
  UI, deep-link, notification, APNs handling and default outbox boundaries, and
  the Solo privacy manifest declares no developer collection. The authorized
  source cleanup has removed Sign in with Apple, APNs, Guardian keys and
  `remote-notification`, while preserving HealthKit, CloudDocuments, the
  production App Group, `fetch` and active-walk `location`. The current local
  Archive's App/Widget entitlements and embedded privacy manifests pass
  inspection. Xcode outputs a parseable 805-byte PDF with a zero-area empty page;
  Poppler renders it blank, consistent with both manifests declaring no tracking
  and no collected data. The Archive scan confirms the App's three declared
  required-reason categories, Widget's empty required-reason list, and no
  third-party package/framework. Developer Portal, distribution profiles, and
  repetition from the final distribution-signed Archive remain open.
- Current decision: close TFU-20260715-003 and TFU-20260720-001 before final
  signed-device RC acceptance. The remaining CloudKit P1 is explicitly
  deferred and unreachable in the local-only first release. The future
  broader account design is recorded in
  `docs/planning/account-backend-extension.md`; the approved minimum Family
  guardian implementation and external launch gates are tracked separately
  below and do not activate CloudKit or full online collaboration. Do not
  claim RC/App Store readiness merely because the containing commit freezes the
  traceable local source; all release-reachable P1 items still require explicit
  disposition and their owning signed/device/external evidence.

## Priority Meaning

| Priority | Meaning |
| --- | --- |
| P0 | First-release-reachable data loss, privacy, corruption, crash, or core-flow blocker. Must close before RC sign-off. |
| P1 | Important correctness, release-proof, product-contract, or real-device gap. Must be explicitly dispositioned before release. |
| P2 | Non-blocking depth, polish, or broader validation debt. |
| P3 | Future improvement with no current release impact. |

## Open Items

### TFU-20260722-001 - Deploy And Validate Family App Guardian

- Priority / bucket: P1 for any Family release; unreachable and non-blocking
  while the local Free / Personal release keeps the guardian flag false.
- Progress: the worktree contains V96 local projections and reliable Presence
  outbox, Sign in with Apple / Cognito client flow, per-installation APNs endpoint
  registration, invitations, guardian dashboard, annual Family StoreKit catalog,
  server-side JWS / App Store Server Notifications V2 verification, and an AWS
  SAM stack for API Gateway, Lambda, DynamoDB, EventBridge Scheduler, SQS / DLQ
  and SNS in `eu-central-1`. Guardian rules, privacy and safety-contract tests
  pass 17/17; the
  affected historical iOS selection passes 353 tests in 9 suites; cfn-lint and
  production dependency imports pass. The current Solo release additionally
  requires a non-shipping compile capability plus runtime configuration, hides
  Guardian settings/UI, rejects its deep links and notification routes, skips
  APNs handling/default outbox staging, and removes Family collection claims
  from the Solo privacy manifest. The 2026-07-29 cross-cut selection passes
  270/270; Family purchase remains fail-closed.
- Blocker: no production AWS deployment, controlled HTTPS invite host /
  Associated Domains, Cognito Apple configuration, production and sandbox SNS
  platform apps, APNs delivery evidence, App Store Server Notifications V2,
  App Store Connect Family SKU, privacy questionnaire, Sandbox lifecycle, or
  two-account / two-device acceptance exists. Simulator cannot prove notification
  permission, actual delivery, uninstall token invalidation or recovery.
- Next action: deploy the guarded stack in `eu-central-1`, configure Apple and
  AWS secrets without logging them, add the verified invite host to Associated
  Domains, configure App Store Server Notifications and Family Yearly, update
  the App Store privacy label, then run the two-device matrix in
  `docs/specs/GuardianSafety-logic.md`.
- Close when: first valid missed-day initial, second valid missed-day single
  follow-up, recovery, guardian
  acknowledgement, pause, revoke, entitlement loss, offline outbox, invalid
  token and account deletion all pass on two signed physical devices; server
  logs contain no names, scores or care data; nine languages and accessibility
  pass; only then may `OHANAGuardianSafetyEnabled` and the Family SKU be enabled.

### TFU-20260715-003 - Ship And Validate Free / Personal 1.0

- Priority / bucket: P1, current first-release implementation, Store
  configuration, quota migration, and purchase acceptance.
- Progress: the current worktree implements the centralized Monthly / Yearly /
  Lifetime catalog, verified legacy Supporter grandfathering, Free quotas,
  logical-plan grouping, reactivation protection, downgrade grandfathering,
  StoreKit-sourced trial eligibility, paid capability gates, and paywall. D34 also
  adds Free manual Human health conditions/observations/records plus Personal
  on-device lab-report scanning behind `PersonalFeature.documentScanning`, with a
  production command gate, downgrade retention, item-by-item confirmation, volatile
  source image/OCR handling and restricted-backup exclusion. The current full
  Unit suite executes 2,310 tests with 0 failures, and the current release static
  lane passes. The 132-selector / 9-shard UI campaign records 130 pass and 2
  fail; after repairing the two failed paths, their exact selectors pass 2/2.
  Per owner instruction the unchanged campaign was not rerun, so no single-pass
  132/132 claim is made. One guarded WMO Release overlay plus a normal-UI Human
  detail/gender-menu open-cancel journey passes with the sealed ready store
  preserved at 2 Humans / 1 Pet / 16 care facts / 8 plans / 52 ledger facts /
  0 test artifacts.
  The repository now includes nine App locales and 36 IAP localization drafts
  for Monthly/Yearly/Lifetime plus conditional restore-only legacy Supporter,
  review notes, screenshots and compliance checklists. New D34 validation evidence
  is intentionally not inherited from that historical artifact.
- Blocker: App Store Connect account/product status, whether legacy Supporter
  has real production history, Sandbox, second-device restore, subscription
  lifecycle, signed Storefront, assistive technology, final screenshots and
  professional language review remain absent. D34 additionally requires a signed
  Camera/Photos journey, a real existing-install upgrade/readback, and confirmation
  that cancelled/failed scans leave no source page or OCR persistence.
- Next action: build and inspect the signed WMO Archive from the containing
  source-freeze commit without rerunning the unchanged full UI campaign, then
  validate StoreKit product
  loading, verified/unverified purchase, pending, cancel, failure,
  `currentEntitlements`, `Transaction.updates`, `AppStore.sync()`, offline,
  trial conversion, subscription expiration, Lifetime, refund/revocation, and
  restore. Keep ads absent and preserve Coconut / `ShopPurchaseRecord`
  ownership.
- Close when: affected App/test targets compile and targeted tests execute with
  non-zero coverage; Free quotas and logical-plan deduplication pass; Personal
  is unlimited; all over-quota grandfather/downgrade paths preserve data and
  only block further increasing operations; Monthly / Yearly / Lifetime produce
  the correct unified Personal entitlement; if the account owner confirms real
  legacy Supporter production history, its verified restore also maps to
  Personal Lifetime, otherwise the SKU is not recreated and no restore claim is
  submitted; yearly trial eligibility comes from StoreKit; every failure leaves
  Free data and
  Coconut ownership unchanged; Free cannot bypass `documentScanning`, Personal can
  import only explicitly reviewed structured items, downgrade preserves those
  items, old stores upgrade without losing health facts, and raw pages/OCR never
  enter persistence, logs, system surfaces or restricted backups; nine-language/
  accessibility coverage passes; a
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
- Blocker: production `group.com.guanchen.li.Ohana` has not been registered and
  approved in Developer Portal provisioning for both app and extension. The
  `group.com.guanchen.li.Ohana.LocalDevice` group is only needed if the separate
  local-development target remains in use; it is not an App Store 1.0 gate. No
  signed current Archive or physical-device run has therefore proved shared
  snapshot access, Home/Lock Screen Widget rendering, Dynamic Island behavior,
  foreground/background location handoff, or locked-device privacy.
- Next action: register the production App Group on the App Store app and Widget
  extension identifiers, regenerate profiles, then install one signed current
  Release. Configure the LocalDevice group separately only for its matching
  local-development identifiers when that target is maintained.
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
  but the target has no CloudKit service entitlement and uses
  `cloudKitDatabase: .none`. Family guardian APNs is a separate service and does
  not satisfy CloudKit evidence.
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
  both were removed: at that checkpoint the target had no Sign in with Apple entitlement,
  login UI, Auth SDK, Supabase project, or account data collection. Their signed
  Archive and simulator tests remain historical evidence only and cannot be used
  to describe or approve the current build. Future design is retained solely in
  `docs/planning/account-backend-extension.md`.
  Later on 2026-07-12, that local-only worktree produced and verified
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
- Close when: all R0-R7 results identify the signed Release build and device;
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
