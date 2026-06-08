# Privacy & Store Compliance

Ohana stores sensitive local data (health, medication, insurance, documents,
photos, location traces, family member info). Because the app ships with German
localization, assume an EU audience and GDPR obligations. This complements the
in-app member-privacy/PIN rules in `docs/app-architecture-governance.md`.

## App Store Privacy Requirements

- **Privacy manifest:** `Ohana/PrivacyInfo.xcprivacy` must stay accurate. It
  currently declares `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`),
  `NSPrivacyTracking=false`, and empty tracking domains / collected data types.
  Re-audit it whenever a required-reason API (file timestamps, disk space, system
  boot time, active keyboards) or any data collection/network call is added.
- **App Store privacy "nutrition label":** Keep the App Store Connect privacy
  questionnaire in sync with reality. Today Ohana is local-first and should
  report data as not collected / not linked / not used for tracking. If that ever
  changes (analytics, accounts, cloud sync), update the label in the same change.
- **Permission strings:** Camera / Photo / Location usage descriptions live only
  in `Ohana/Info.plist` + `en.lproj`/`de.lproj` `InfoPlist.strings` (zh/en/de).
  Do not reintroduce duplicate `INFOPLIST_KEY_*` permission strings in build
  settings — they override the localized strings.
- **No unused permissions/capabilities:** Do not declare a permission, entitlement,
  or background mode that the code does not actually use (e.g., HealthKit strings
  with no HealthKit integration). Remove or implement.
- **Encryption export compliance:** Set `ITSAppUsesNonExemptEncryption`
  appropriately in `Info.plist`/App Store Connect (standard OS crypto only ⇒
  typically exempt).

## GDPR / CCPA Obligations

Even though data is local, the user has rights over it:

- **Right to access / portability:** The user can export their data. The existing
  `DataBackupManager.exportJSON` (atomic, file-protected) satisfies portability;
  surface it as a clear user-facing "export my data" action.
- **Right to erasure:** Provide a clear, complete "delete all my data" path that
  removes SwiftData stores, the disk fallback (`ohana_disk_fallback`), the App
  Group container, cached avatars/images, exported backups, and relevant
  `UserDefaults`. Verify nothing sensitive survives a reset
  (see `AppResetService` and `scripts/audit-release-data-safety.sh`).
- **Data minimization:** Only persist what a feature needs. Backups must continue
  to exclude PIN hash/salt and other recovery-sensitive fields.
- **No silent collection:** No analytics/telemetry that leaves the device without
  explicit, revocable consent. MetricKit/diagnostics must remain privacy-safe
  (no names, notes, PIN, health values, precise routes, raw user text).
- **Children / sensitive data:** If the app could be used by minors or stores
  health data, keep the age rating and data-handling claims consistent with the
  store listing.

## Memorial / Account Edge Cases

- Deceased pet/human enters read-only memorial mode; future reminders and daily
  tasks must stop (enforced in services, not just UI).
- Member privacy (`PrivacyService`) cannot be bypassed via quick actions, all-
  features, stats, collaboration, or Today Focus.

## Release Checklist (privacy slice)

Before shipping a change that touches data, permissions, or background work:

- `PrivacyInfo.xcprivacy` still accurate.
- App Store privacy label still accurate.
- No unused permission/entitlement/background mode.
- Export and delete-my-data paths still complete (`audit-release-data-safety.sh`).
- Diagnostics still privacy-safe.
- Background location only during a running walk.
