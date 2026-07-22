# Cloud Sync TODO

This file tracks future CloudKit work that is intentionally deferred until the
product gate, capability profile, provisioning, CloudKit Dashboard, and
multi-device evidence all exist. The current target keeps CloudDocuments for
restricted iCloud Drive backup and its SwiftData containers use
`cloudKitDatabase: .none`; it declares no CloudKit service entitlement.

The target now declares APNs, `remote-notification`, and Sign in with Apple only
for the separately approved, fail-closed Family guardian service. Those
capabilities do not authorize CloudKit, do not change this TODO, and must not be
used to infer that family data sync is active. Guardian release gates live in
`docs/specs/GuardianSafety-logic.md`.

The 2026-06-24 signed-development build below is historical provisioning
evidence from an earlier capability profile. It is not evidence about the
current target and must not be used to re-enable CloudKit without an explicit
release decision.

## Deferred Until Developer Account

- [x] Historical: verify that a development profile could provision iCloud
  CloudKit and Remote Notifications. Evidence from the superseded profile:
  2026-06-24
  `xcodebuild -allowProvisioningUpdates -project Ohana.xcodeproj -scheme Ohana
  -configuration Debug -destination 'id=4CDF4314-5293-5DFE-AD4E-B510473B1367'
  -derivedDataPath /tmp/ohana-device-capability-debug build
  CODE_SIGNING_ALLOWED=YES` succeeded; signed entitlements include
  `aps-environment = development` and
  `iCloud.com.guanchen.li.Ohana`.
- [ ] Confirm production/release provisioning and CloudKit Dashboard setup for
  container `iCloud.com.guanchen.li.Ohana` before enabling CloudKit sync.
- [ ] Validate CloudKit Dashboard schema after first development-device sync, including custom household zones, uploadable record types, CKAsset-backed fields, and zone-wide `CKShare` records.
- [ ] Promote the verified CloudKit schema only after the development environment passes real-device sync and share flows.

## Real-Device Validation

- [ ] Test private-database sync with one Apple ID on two devices: create/edit/delete Household, Pet, Human, care logs, wallet ledger entries, and supported append-only logs.
- [ ] Test CKShare household invitation with two Apple IDs: owner creates a household share, participant accepts the system invite, both devices switch into the shared database scope, and both can sync changes.
- [ ] Verify silent-push driven fetches for private and shared database changes while the app is foregrounded, backgrounded, relaunched, and temporarily offline.
- [ ] Verify share revocation, participant removal, account sign-out, iCloud unavailable, and shared-zone-not-found recovery paths.
- [ ] Verify initial merge when the joining device already has local data, including rehoming existing sync metadata into the accepted household zone.

## Shared-Care Legacy Cleanup Validation

This checklist closes the care-maturity follow-up for CloudKit-applied
shared-care legacy metadata. It requires two physical iPhones running the same
signed build, CloudKit provisioning for `iCloud.com.guanchen.li.Ohana`, CloudKit Dashboard
access, app logs or performance-monitor output, and a way to install or restore
a legacy fixture containing `ohana_shared_*` note prefixes.

- [ ] Record the build number, git commit, iOS versions, Apple IDs, CloudKit
  environment, database scope, household ids, pet ids, and test timestamps before
  each run.
- [ ] Private database path: on device A, create shared feed, water, walk, and
  expense sessions for multiple pets. Let device B fetch them, relaunch device B,
  and verify no user-visible note or behavior note displays an `ohana_shared_*`
  prefix.
- [ ] Shared database path: invite a second Apple ID into a household, repeat the
  shared feed, water, walk, and expense session flow in the shared scope, then
  verify both owner and participant devices converge on the same structured
  `SharedCareSession` fields and visible notes.
- [ ] Legacy apply path: install or restore a fixture with legacy shared-care
  prefixes, launch with CloudKit enabled, and confirm startup maintenance runs
  once after CareLedger backfill. Capture the
  `startup_shared_care_note_cleanup` cleaned counts, skipped orphan counts, and
  missing session ids from logs or diagnostics.
- [ ] Cascade delete path: delete a shared session on device A and verify device
  B applies the session tombstone plus linked care, walk, expense, and ledger
  tombstones without resurrecting child records or leaving dirty pending payloads.
- [ ] Orphan preservation path: restore a fixture where child care facts contain
  legacy shared-care prefixes but the `SharedCareSession` is missing. Verify the
  note is preserved, the cleanup reports a nonzero skipped orphan count, and
  `SharedCareSessionMaintenance.legacyOrphanNoteDiagnostics(context:)` reports
  source model, record id, missing session id, stock/target facts, linked legacy
  ids, and visible-note length without exporting the user note body.
- [ ] Sync-storm check: after cleanup and cascade-delete runs settle, force at
  least two more fetch/upload cycles on both devices and verify reconcile-driven
  `markModified` work does not produce repeated remote modifications, new dirty
  payloads, or changing CloudKit record change tags after the first expected
  upload.
- [ ] Evidence packet: save CloudKit Dashboard record counts, relevant log
  excerpts, dirty-payload counts, tombstone counts, orphan diagnostic counts,
  screenshots of visible notes, and any performance-monitor samples used to
  prove the cleanup was one-shot and privacy-safe.
- [ ] Close condition: private and shared database runs pass, visible metadata is
  gone from recoverable records, orphan records remain preserved with diagnostics,
  cascade tombstones converge on both devices, and no repeated remote
  modifications appear after the cleanup settles.

## Follow-Up Polish

- [ ] Tune user-facing copy for iCloud unavailable, share invitation, accepted share, revoked access, retry pending, and offline states in all supported localization fallbacks.
- [ ] Review member exit/removal permissions and decide which local data should remain visible after access is revoked.
- [ ] Add any real-device-only regressions from CloudKit testing as targeted unit, integration, or manual QA checklist coverage.

## CloudKit-Enable-Time Architecture (deferred from Domain review, 2026-06-14)

These come from the Domain adversarial review (TFU-20260614-010/011/012/014).
They are **unreachable at first release** because `cloudKitDatabase: .none`
means no remote records ever arrive — `CloudSyncRecordApplier.apply /
applyLiveRecord / applyHardDeletedRecord` cannot be triggered single-device.
They are real and must be done **before CloudKit is enabled in 1.x**, when there
is real remote data to validate against. Do **not** build this policy layer at
first release: there is no remote data to test it, so it would be building on sand.

- [ ] Build a `CloudSyncApplyDisposition` (or equivalent) policy layer: every
  `applyXxx` first passes a single policy that decides **deletion-wins**,
  **parent-active-required**, **owner-active-required**, and **natural-key
  merge**, then performs entity mutation. No `applyXxx` mutates directly.
- [ ] deletion-wins: a live remote Pet/Human/record must not resurrect a local
  delete tombstone (TFU-014).
- [ ] parent/owner lifecycle: late remote child/fact records must not insert
  under a deleted/deceased parent (orphan guard) (TFU-014).
- [ ] natural-key merge: `GachaOwnedItem` (and similar entities) must merge by natural key,
  not random id, to avoid duplicate ownership projection (TFU-014).
- [ ] remote delete must dispatch to the same domain delete outcome as local
  physical delete (Pet/Human/Event/SharedCareSession/feeding fact+stock+reminder
  cascade) — i.e. one delete dispatcher, not per-entity switches
  (TFU-010/011/012).
- [ ] remote CoconutLedger tombstone delete must replay the wallet account
  projection (TFU-010).
- [ ] upload builder must have a fetch case for every registered entity
  (Gacha/Shop), enforced by the registry-coverage audit (TFU-013 upload side).

> Reachability rule (applies to all module reviews): a finding that is provably
> unreachable at first release (gated off by `.none` / a disabled feature gate /
> a code path that cannot run single-device) does **not** block that module's
> first-release 🏁. It must be logged here with the gate evidence, and the review
> session must confirm the unreachability. First-release 🏁 = zero P0/P1 **within
> the first-release-reachable surface**.
