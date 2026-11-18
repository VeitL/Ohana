# Privacy Policy

Updated: 2026-11-07

## Summary

Ohana is a local-first care app. The 1.0 Free release does not require a developer-
hosted account and does not use advertising, analytics SDKs, tracking, support
uploads, CloudKit sharing, or remote care-data synchronization.
Personal is a shaded Coming soon preview. Sale product loading, purchase,
explicit purchase restoration, and subscription-management entrypoints are
closed. Verified existing ownership and local saved data remain protected.
Your care records are used on your device to provide the app's features.
Ohana 1.0 does not offer an Ohana account, Family guardian, remote guardian
notifications, or a developer-hosted backend.

## Data Ohana Stores

Depending on the features you use, Ohana can store the following data on your
device:

- household, member, pet, and plant profiles;
- care, calendar, reminder, task, reward, expense, insurance, document, photo,
  and route records;
- human wellness records, including weight, workouts, medication, health
  metrics, health reports, and notes; and
- local preferences, app settings, and automatic-backup status.

Human profiles are local care records, not Ohana accounts. Ohana does not read
your Apple Account profile to create a Human. When you explicitly create a
Human, a name is required; gender and birthday are optional.

## Release Scope

Ohana 1.0 is an iPhone-only Free release. Personal is an unavailable preview.
Human profiles are local
care-content records, not operators or accounts. Local household assignments
may describe family roles on one device, but they do not invite another person,
send a message, or create remote collaboration.

Family guardian, Sign in with Apple for an Ohana account, remote guardian
notifications, CloudKit collaboration, and server-side care-data sync are not
part of this release. This policy will be updated before any such capability is
made available.

## Health and Apple Health

If you set up Apple Health, Ohana reads the HealthKit data needed for the Human
Workout feature, including activity summaries, steps, walking/running distance,
active energy, exercise and stand time, activity goals, and recent workouts. It
does not write data back to HealthKit. HealthKit data is queried and displayed
on-device; recent HealthKit workouts are not copied into the local Human workout
log. Manual Ohana workout records remain local.

New Free users do not have a lab-report scanning entry in 1.0. Previously saved
structured health reports and metrics remain readable and editable. Where a
verified existing entitlement permits scanning, it uses Apple on-device recognition. The
source pages and raw recognized text stay volatile: Ohana does not upload them
or save them to its database. Only the structured results that you select,
review item by item, and confirm are saved locally. This feature organizes
records and does not diagnose, interpret, or replace professional medical care.

Ohana does **not** place personal human-health information in iCloud. This
includes HealthKit-derived data, human weight, medication and medication logs,
health metrics, health reports, and Human workout records.

Ohana marks its local Application Support persistence root, including the
SwiftData store and Human Note attachment directories, as excluded from
OS-managed device backups. The only app-managed iCloud path in the Free release
is the restricted iCloud Drive package described below.

## Backups and Exports

Automatic backup is optional. Free keeps the latest restricted package
in the user's own iCloud Drive container. Ohana does not add password encryption
to automatic backup packages. That package excludes the human-health data listed
above, health-related calendar and reminder records, all free-text family-task
records, and derived economy/ledger sidecars that could repeat health text.

Manual backup packages that can be saved to Files or shared through system
providers use the same restricted data boundary. Ohana does not offer a path
that exports human-health or HealthKit-derived records to iCloud.

Other exported information may still be sensitive, including household, pet,
location, document, photo, and expense data. Share such files only with people
you trust. Ohana does not receive these files.

If an app reset cannot remove the app-managed automatic backup because iCloud
Drive is unavailable, Ohana keeps a visible pending-cleanup status and lets you
retry. You can also remove your own backup files in the Files app.

## Data Sharing

Ohana does not send local care records or app records to the developer. It does
not sell, use for advertising, or use for cross-app tracking your personal,
health, location, or care data. It does not use CloudKit collaboration or
server-side care-data sync.

Choosing an iOS share destination is your action. The destination's privacy
practices are governed by that provider's policies.

## In-App Purchase

The 1.0 Free release does not offer purchases or explicit Restore Purchases.
Apple owns any existing App Store purchase record. Ohana can read Apple-signed
and verified transaction/current-entitlement status on-device to reconcile
existing ownership, expiration, refunds or revocations. It does not load sale
offers while the release gate is closed. Ohana does not
receive or store your payment card, billing address, Apple Account password, or
other complete payment credentials.

Ohana does not send care records to the developer or associate Human, pet,
plant, health, location, or care data with the purchase. Free quota counts are
computed on-device and are not sent to the developer. Existing records, media,
profiles, plans, and Coconut Shop ownership remain protected when entitlements
expire. Deleting or resetting local app data does not delete Apple's App Store
purchase record; this preview does not provide a manual purchase-restoration path.

## Permissions

Ohana asks only for permissions used by an enabled feature:

- Camera and Photos, when you choose an image or attachment.
- Location while using the app, and background location only during an active
  dog walk.
- Notifications, for local reminders and their actions.
- HealthKit, for the read-only Human Workout integration.
- iCloud Drive, when you enable automatic restricted backup.

## Retention, Deletion, and Choices

You can edit or delete supported records in the app, reset local app data, and
turn automatic backup off in Settings. App Reset removes app-managed local data
and attempts to remove the app-managed automatic iCloud Drive backup. Deleting
or resetting app data does not automatically erase copies you deliberately
shared or moved outside the app.

## Changes and Contact

We will update this policy before enabling any Ohana account, Family guardian,
Google login, CloudKit sharing, remote care-data sync, analytics, advertising,
support uploads, or any new protected-data use. For privacy questions or support, email
[guanchen.li.119@gmail.com](mailto:guanchen.li.119@gmail.com?subject=Ohana%20Support).
