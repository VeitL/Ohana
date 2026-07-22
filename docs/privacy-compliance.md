# Privacy & Store Compliance

Last reviewed: 2026-07-22

Ohana stores sensitive local data (health, medication, insurance, documents,
photos, location traces, family member info). Because the app ships with German
localization, assume an EU audience and GDPR obligations. This complements the
in-app member-privacy/PIN rules in `docs/app-architecture-governance.md`.

## App Store Privacy Requirements

- **Privacy manifest:** `Ohana/PrivacyInfo.xcprivacy` must stay accurate. It
  currently declares `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`),
  `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`),
  `NSPrivacyTracking=false`, empty tracking domains, and the optional Family
  guardian's User ID, Device ID, Purchase History, and Product Interaction as
  linked, non-tracking data used only for App Functionality.
  Re-audit it whenever another required-reason API (disk space, system boot time,
  active keyboards, etc.) or any data collection/network call is added.
- **App Store privacy "nutrition label":** Keep the App Store Connect privacy
  questionnaire in sync with reality. A binary that contains or enables Family
  guardian must not use the historical **Data Not Collected** answer: disclose
  linked User ID, Device ID, Purchase History, and Product Interaction for App
  Functionality, with no tracking. User-initiated exports, iCloud Drive
  backups, or shared files remain under the user's control and are not developer
  collection unless Ohana, a backend, or a third-party partner can access the
  transmitted data beyond the user's chosen share action. If that ever changes
  (analytics, CloudKit family sync, support uploads, third-party SDKs), update
  the label in the same change. Free / Personal care records remain local and
  are not developer collection.
- **StoreKit Personal / Family:** Apple processes the Personal monthly/yearly
  auto-renewable subscriptions, Personal Lifetime non-consumable purchase, and
  the historical Supporter Pack non-consumable that grandfathers verified owners
  into Personal Lifetime. Ohana reads StoreKit-provided product metadata plus
  Apple-signed and verified transaction/current-entitlement status on-device to
  present, complete, restore, recognize expiration, refunds or revocations, and
  deliver local Personal capabilities. It does not receive payment card,
  billing address, Apple Account password, or full payment credentials; it does
  not associate
  the purchase with Human, pet, plant, health, location, or care records or send
  those records to the developer. Free quota counts are computed on-device and
  are not transmitted. Family is the narrow exception: the backend validates
  the Family JWS and App Store Server Notifications V2, retaining only minimum
  transaction identifiers, product, expiry and status; it never receives
  payment credentials or care records.
- **Privacy policy URL:** App Store Connect requires a public privacy policy URL
  for iOS. The release policy is `docs/privacy-policy.md`, and the in-app
  Settings link targets its public repository URL. It states that Ohana is
  local-first, does not track users or run analytics, and creates a minimum-data
  developer account only when the user enables Family guardian. Automatic
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
  or background mode that the code does not actually use. The local-only Free /
  Personal profile keeps
  CloudDocuments for the restricted iCloud Drive backup and HealthKit for the
  read-only Human Workout view. It also uses one App Group shared only with the
  embedded Widget Extension for a bounded, versioned Today Care JSON snapshot.
  The snapshot excludes free-form household titles, health/medication detail,
  attachments, location traces, and business facts; it is excluded from backup,
  expires in WidgetKit, and is removed by App Reset. The profile declares Sign
  in with Apple, APNs and `remote-notification` only for fail-closed Family
  guardian handling; CloudKit sharing remains absent. Associated Domains must
  wait for a controlled production invite host. The runtime flag stays false
  until backend, capability and two-device release gates pass.
- **Live Activity minimization:** The walk Live Activity carries only its local
  session/pet identifiers, a privacy-sensitive pet name, start/phase/timing,
  aggregate distance, and potty count. It never carries route coordinates,
  health/medication content, notes, rewards, or write actions. Discarding a
  recovery checkpoint and resetting the app end the matching system surface.
- **Encryption export compliance:** Set `ITSAppUsesNonExemptEncryption`
  appropriately in `Info.plist`/App Store Connect (standard OS crypto only ⇒
  typically exempt).

## GDPR / CCPA Obligations

Local care data and the optional Family account data remain subject to user rights:

- **Right to access / portability:** The user can export their data. The existing
  `DataBackupManager.exportJSON` (atomic, file-protected) satisfies portability;
  surface it as a clear user-facing "export my data" action.
- **Right to erasure:** Provide a clear, complete "delete all my data" path that
  removes the SwiftData primary store, any legacy `ohana_disk_fallback` files,
  local attachment/cache directories, app-managed iCloud backups, and relevant
  `UserDefaults`. Verify nothing sensitive survives a reset
  (see `AppResetService` and `scripts/audit-release-data-safety.sh`).
- **Family account erasure:** Family account deletion immediately revokes
  guardian scheduling and device endpoints. Related server records are deleted
  within 30 days; minimum notification audit expires within 90 days. A failed
  remote deletion remains visible and retryable rather than pretending the
  account is gone.
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
- App Store privacy label discloses Family User ID, Device ID, Purchase History
  and Product Interaction as linked App Functionality data, non-tracking; it
  does not claim that local care records are collected.
- StoreKit Personal purchase, subscription, legacy Supporter grandfathering,
  and restore use only Apple-signed product / entitlement
  state; no payment credentials or care records enter app logs, exports, a
  developer backend, advertising, or analytics.
- Published privacy policy URL exists and matches local-first Free / Personal
  plus the optional minimum-data Family guardian behavior.
- No unused permission/entitlement/background mode.
- Export and delete-my-data paths still complete (`audit-release-data-safety.sh`).
- Local persistence and Human Note attachment backup-exclusion guards still
  pass, followed by a real-device encrypted-backup/restore check before release.
- Diagnostics still privacy-safe.
- Background location only during a running walk.
- Family guardian follows `docs/specs/GuardianSafety-logic.md`; broader account,
  CloudKit or cross-platform work still requires
  `docs/planning/account-backend-extension.md` and separate approval.
