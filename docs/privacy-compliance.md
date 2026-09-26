# Privacy & Store Compliance

Last reviewed: 2026-08-04

Ohana stores sensitive local data (health, medication, insurance, documents,
photos, location traces, family member info). Because the app ships with German
localization, assume an EU audience and GDPR obligations. This complements the
in-app member-privacy/PIN rules in `docs/app-architecture-governance.md`.

## App Store Privacy Requirements

- **Privacy manifest:** `Ohana/PrivacyInfo.xcprivacy` must stay accurate. It
  currently declares `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`),
  `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`),
  `NSPrivacyAccessedAPICategorySystemBootTime` (`35F9.1`),
  `NSPrivacyTracking=false`, empty tracking domains, and an empty
  `NSPrivacyCollectedDataTypes` array for the local Free / Personal release.
  `OhanaWidgets/PrivacyInfo.xcprivacy` separately declares no tracking, no
  collection, and an empty required-reason list because its Release executable
  uses none of Apple's currently listed APIs; the resource audit and privacy
  contract test cover both manifests.
  Re-audit it whenever another required-reason API (disk space, system boot time,
  active keyboards, etc.) or any data collection/network call is added. At every
  release, also compare the final dependency set against Apple's then-current
  required-reason API and third-party SDK lists, recording the Xcode version,
  SDK version, review date, and source links even when repository code is
  unchanged.
- **App Store privacy "nutrition label":** Keep the App Store Connect privacy
  questionnaire in sync with the final Archive. For the local Free / Personal
  release, no app records are transmitted to the developer, so the intended
  answer is **Data Not Collected**, subject to the Xcode Privacy Report generated
  from the final release Archive and its dependency review. The report is
  release evidence, not a file expected to be embedded in the app binary.
  User-initiated exports, iCloud Drive backups, or shared
  files remain under the user's control and are not developer collection unless
  Ohana, a backend, or a third-party partner can access the transmitted data
  beyond the user's chosen share action. If that ever changes (Family guardian,
  analytics, CloudKit family sync, support uploads, third-party SDKs), update
  the manifest, label and policy before enabling the change.
- **StoreKit Personal:** Apple processes the Personal monthly/yearly
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
  are not transmitted. Family products and server-side transaction handling are
  not part of Ohana 1.0.
- **Privacy policy URL:** App Store Connect requires a public privacy policy URL
  for iOS. The release policy is `docs/privacy-policy.md`, and the in-app
  Settings link targets its public repository URL. It states that Ohana is
  local-first, does not track users or run analytics, and does not create an
  Ohana account or offer Family guardian in 1.0. Automatic
  iCloud Drive backups and every user-initiated external backup/export use the
  restricted export scope: human health/HealthKit records, free-text family
  tasks, and derived economy/ledger sidecars are excluded before an archive can
  reach iCloud or a share target.
  Reset cleanup reports a failed managed-iCloud-file deletion and offers retry;
  copies a user exported outside the app remain under that user's control.
- **Permission strings:** Camera / Photo / Location / Face ID usage descriptions
  live only in `Ohana/Info.plist` plus per-language `InfoPlist.strings`; the
  default `Info.plist` strings are Chinese, and all nine registered app languages
  now provide localized protected-resource prompts. Do not reintroduce duplicate
  `INFOPLIST_KEY_*` permission strings in build settings — they override the
  localized strings. Final RC device prompts and professional language review
  still own release acceptance. Draft review copy and in-app rationale live in
  `docs/permission-rationale-draft.md`.
- **Human health and lab-report import:** V97/V98 Human conditions,
  observations, health reports, and metric logs are sensitive local facts.
  Personal document scanning uses only Apple Vision/VisionKit on device. Source
  images and full OCR transcripts remain volatile in the active import flow and
  are released on cancellation, failure, completion, or route exit; they are not
  SwiftData rows, attachments, logs, notifications, Widget/Live Activity fields,
  or external-backup payloads. Only user-reviewed structured reports and metric
  values are committed atomically. The restricted iCloud/export package excludes
  all Human health facts, including the V97/V98 additions and lab provenance.
  Free may continue manual health records; Personal is required to start and
  persist a new document scan, while downgrade preserves existing records.
- **No unused permissions/capabilities:** Do not declare a permission, entitlement,
  or background mode that the code does not actually use. The local-only Free /
  Personal profile keeps
  CloudDocuments for the restricted iCloud Drive backup and HealthKit for the
  read-only Human Workout view. It also uses one App Group shared only with the
  embedded Widget Extension for a bounded, versioned Today Care JSON snapshot.
  The snapshot excludes free-form household titles, health/medication detail,
  attachments, location traces, authoritative records, and raw sensitive source
  data. It contains only a bounded derived projection (stable item IDs, localized
  labels, subject display names, due/urgency values, and aggregate counts). The
  App Group container is marked and read-back verified before a private write,
  and the final snapshot is marked and verified again after every atomic write.
  The projection expires in WidgetKit. App Reset first pauses refresh scheduling
  and invalidates every older refresh generation, then must either replace the
  projection with an unavailable value or remove it before persistent deletion
  can proceed; a delayed pre-reset read is not allowed to write afterward. If
  persistent deletion fails, the runtime releases the fence and immediately
  schedules a fresh projection from the still-existing source data. The 1.0 distribution
  profile must not declare Sign in with Apple, APNs, `remote-notification`,
  CloudKit sharing or Associated Domains. The source entitlement and
  `Info.plist` have removed Sign in with Apple, APNs, `remote-notification` and
  Guardian keys. The Developer Portal, final distribution profile and signed
  Archive must still be inspected; runtime flags and review notes cannot
  substitute for signed evidence.
- **Live Activity minimization:** The walk Live Activity carries only its local
  session/pet identifiers, a privacy-sensitive pet name, start/phase/timing,
  aggregate distance, and potty count. It never carries route coordinates,
  health/medication content, notes, rewards, or write actions. Discarding a
  recovery checkpoint and resetting the app end the matching system surface.
- **Encryption export compliance:** Set `ITSAppUsesNonExemptEncryption`
  appropriately in `Info.plist`/App Store Connect (standard OS crypto only ⇒
  typically exempt).

## GDPR / CCPA Obligations

Local care data remains subject to user rights:

- **Right to access / portability:** The current
  `DataBackupManager.exportJSON` package is an atomic, file-protected,
  deliberately restricted recovery backup. It excludes Human health details,
  free-text family-task content, PIN secrets, and derived economy/ledger
  sidecars, so it must not be described as a complete access or portability
  export. Before claiming a user-facing "export my data" right, provide and
  verify a separate locally generated access/export path whose documented scope
  covers the applicable user-authored data classes and clearly explains any
  lawful security exclusion.
- **Right to erasure:** Provide a clear, complete "delete all my data" path that
  removes the SwiftData primary store, any legacy `ohana_disk_fallback` files,
  local attachment/cache directories, app-managed iCloud backups, and relevant
  `UserDefaults`. Verify nothing sensitive survives a reset
  (see `AppResetService` and `scripts/audit-release-data-safety.sh`).
- **OS backup exclusion:** `LocalBackupExclusionPolicy` marks the local
  Application Support root and Human Note attachment paths for exclusion from
  OS-managed device backup and reads the resource value back. Reapply and verify
  the Application Support directory whenever the persistent store is opened,
  and reapply and verify each attachment output after every save, atomic replace,
  or move because replacement can change filesystem resource metadata.
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
- Xcode Privacy Report generated from the final release Archive and dependency
  review support the intended App Store Connect **Data Not Collected** answer
  for the local Free / Personal
  release.
- StoreKit Personal purchase, subscription, legacy Supporter grandfathering,
  and restore use only Apple-signed product / entitlement
  state; no payment credentials or care records enter app logs, exports, a
  developer backend, advertising, or analytics.
- Published privacy policy URL exists and matches the local-first Free /
  Personal-only behavior.
- No unused permission/entitlement/background mode.
- Restricted recovery backup scope and delete-my-data paths still match their
  contracts (`audit-release-data-safety.sh`); do not mark access/portability
  complete until its separate full-scope export gate has evidence.
- Local persistence and Human Note attachment backup-exclusion guards still
  pass, followed by a real-device encrypted-backup/restore check before release.
- Diagnostics still privacy-safe.
- Background location only during a running walk.
- V97/V98 health facts remain excluded from restricted backups and system
  surfaces; raw lab images/OCR remain volatile; Free/Personal scan gates and
  physical Camera/Photos denied/cancel/retry paths pass on the frozen RC.
- Family guardian remains unreachable and unshipped; any future Family,
  broader account, CloudKit or cross-platform work still requires
  `docs/planning/account-backend-extension.md` and separate approval.
