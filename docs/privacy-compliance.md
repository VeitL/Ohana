# Privacy & Store Compliance

Ohana stores sensitive local data (health, medication, insurance, documents,
photos, location traces, family member info). Because the app ships with German
localization, assume an EU audience and GDPR obligations. This complements the
in-app member-privacy/PIN rules in `docs/app-architecture-governance.md`.

## App Store Privacy Requirements

- **Privacy manifest:** `Ohana/PrivacyInfo.xcprivacy` must stay accurate. It
  currently declares `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`),
  `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`),
  `NSPrivacyTracking=false`, and empty tracking domains / collected data types.
  Re-audit it whenever another required-reason API (disk space, system boot time,
  active keyboards, etc.) or any data collection/network call is added.
- **App Store privacy "nutrition label":** Keep the App Store Connect privacy
  questionnaire in sync with reality. For the current no-developer-collection
  build, answer "No, we do not collect data from this app"; the App Store label
  should read **Data Not Collected**. User-initiated exports, iCloud Drive
  backups, or shared files remain under the user's control and are not developer
  collection unless Ohana, a backend, or a third-party partner can access the
  transmitted data beyond the user's chosen share action. If that ever changes
  (analytics, accounts, CloudKit family sync, support uploads, third-party SDKs),
  update the label in the same change.
- **Privacy policy URL:** App Store Connect requires a public privacy policy URL
  for iOS. The release policy is `docs/privacy-policy.md`, and the in-app
  Settings link targets its public repository URL. It states that Ohana is
  local-first, does not track users, does not run analytics, does not create a
  developer account, and does not transmit app data to the developer. Automatic
  iCloud Drive backups and every user-initiated external backup/export use the
  restricted export scope: human health/HealthKit records, free-text family
  tasks, and derived economy/ledger sidecars are excluded before an archive can
  reach iCloud or a share target.
  Reset cleanup reports a failed managed-iCloud-file deletion and offers retry;
  copies a user exported outside the app remain under that user's control.
- **Permission strings:** Camera / Photo / Location / Face ID usage descriptions
  live only in `Ohana/Info.plist` plus per-language `InfoPlist.strings`; the
  default `Info.plist` strings are Chinese, English/German are reviewed, and the
  other registered languages currently use explicit English fallbacks. Do not
  reintroduce duplicate `INFOPLIST_KEY_*` permission strings in build settings —
  they override the localized strings. Draft review copy and in-app rationale
  live in `docs/permission-rationale-draft.md`.
- **No unused permissions/capabilities:** Do not declare a permission, entitlement,
  or background mode that the code does not actually use. The Solo profile keeps
  CloudDocuments for the restricted iCloud Drive backup and HealthKit for the
  read-only Human Workout view. It declares no Sign in with Apple, APNs,
  `remote-notification` background mode, CloudKit sharing service, or App Group.
  Remove or implement any future mismatch.
- **Encryption export compliance:** Set `ITSAppUsesNonExemptEncryption`
  appropriately in `Info.plist`/App Store Connect (standard OS crypto only ⇒
  typically exempt).

## GDPR / CCPA Obligations

Even though data is local, the user has rights over it:

- **Right to access / portability:** The user can export their data. The existing
  `DataBackupManager.exportJSON` (atomic, file-protected) satisfies portability;
  surface it as a clear user-facing "export my data" action.
- **Right to erasure:** Provide a clear, complete "delete all my data" path that
  removes the SwiftData primary store, any legacy `ohana_disk_fallback` files,
  local attachment/cache directories, app-managed iCloud backups, and relevant
  `UserDefaults`. Verify nothing sensitive survives a reset
  (see `AppResetService` and `scripts/audit-release-data-safety.sh`).
- **OS backup exclusion:** `LocalBackupExclusionPolicy` marks the local
  Application Support root and Human Note attachment paths as excluded from
  OS-managed device backup and verifies the resource value after writing it.
  Keep `LocalBackupExclusionPolicyTests` and
  `scripts/audit-release-data-safety.sh` aligned with this boundary.
- **Data minimization:** Only persist what a feature needs. Backups must continue
  to exclude PIN hash/salt and other recovery-sensitive fields.
- **No silent collection:** No analytics/telemetry that leaves the device without
  explicit, revocable consent. MetricKit/diagnostics must remain privacy-safe
  (no names, notes, PIN, health values, precise routes, raw user text).
- **Children / sensitive data:** If the app could be used by minors or stores
  health data, keep the age rating and data-handling claims consistent with the
  store listing.

## Memorial / Local Member Edge Cases

- Deceased pet/human enters read-only memorial mode; future reminders and daily
  tasks must stop (enforced in services, not just UI).
- Member privacy (`PrivacyService`) cannot be bypassed via quick actions, all-
  features, stats, collaboration, or Task Center.
- Human profiles are local content records, not authenticated operators. A
  member name is required when explicitly creating a Human; gender and birthday
  remain optional and are never inferred from the device's Apple account.

## Release Checklist (privacy slice)

Before shipping a change that touches data, permissions, or background work:

- `PrivacyInfo.xcprivacy` still accurate.
- App Store privacy label still accurate (`Data Not Collected` for the current
  zero-upload build).
- Published privacy policy URL exists and matches the current local-first /
  zero-upload behavior.
- No unused permission/entitlement/background mode.
- Export and delete-my-data paths still complete (`audit-release-data-safety.sh`).
- Local persistence and Human Note attachment backup-exclusion guards still
  pass, followed by a real-device encrypted-backup/restore check before release.
- Diagnostics still privacy-safe.
- Background location only during a running walk.
- Any future account/backend work first satisfies
  `docs/planning/account-backend-extension.md`; that planning document does not
  authorize a capability or data-collection change.
