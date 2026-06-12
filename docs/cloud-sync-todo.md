# Cloud Sync TODO

This file tracks CloudKit and real-device follow-up work that is intentionally deferred until a paid Apple Developer account, provisioning access, and two physical iPhones with separate Apple IDs are available.

## Deferred Until Developer Account

- [ ] Enable and verify production-capable iCloud CloudKit and Remote Notifications provisioning for the Ohana app target.
- [ ] Confirm the CloudKit container `iCloud.HT.Ohana` exists for the signed team and is attached to the app identifier.
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
signed build, CloudKit provisioning for `iCloud.HT.Ohana`, CloudKit Dashboard
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
