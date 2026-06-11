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

## Follow-Up Polish

- [ ] Tune user-facing copy for iCloud unavailable, share invitation, accepted share, revoked access, retry pending, and offline states in all supported localization fallbacks.
- [ ] Review member exit/removal permissions and decide which local data should remain visible after access is revoked.
- [ ] Add any real-device-only regressions from CloudKit testing as targeted unit, integration, or manual QA checklist coverage.
