# Ohana Privacy Policy Draft

Status: Draft for owner/legal review. This is not the published privacy policy
URL yet.

Last updated: 2026-06-24

Contact: guanchen.li.119@gmail.com

## Short Version

Ohana is a local-first family and pet care app. The current first-release
posture is:

- Ohana does not run ads, tracking, analytics SDKs, or developer-operated user
  accounts.
- Ohana does not send app data to the developer.
- Your care records, member records, pet records, reminders, documents, photos,
  routes, and privacy settings are stored on your device.
- Automatic backup is currently on by default and can be turned off. When it is
  on, Ohana saves a backup file to your own iCloud Drive container. The
  developer does not receive that backup.
- Family CloudKit sync/collaboration is gated off in the current release. If it
  is enabled later, this policy and App Store privacy answers must be updated
  before release.

Apple's App Store privacy label uses "collect" to mean data transmitted off the
device in a way that lets the developer or third-party partners access it. Under
the current app posture, Ohana should remain a "Data Not Collected" app because
the developer does not receive user data. User-controlled iCloud Drive backups
and exports still contain sensitive data and must be disclosed clearly here.

## What Ohana Stores

Ohana may store the following information on your device, depending on the
features you use:

- Household, member, and pet profiles, including names, avatars, species, dates,
  and preferences.
- Care logs such as feeding, water, walks, potty, grooming, play, medication,
  health, weight, notes, and shared-care history.
- Human wellness records such as weight, workouts, medication, notes, expenses,
  and privacy settings.
- Reminders, family tasks, notification preferences, and completion history.
- Photos or image attachments you choose to add, such as avatars, Moments, and
  receipt images.
- Expense records, receipts, documents, insurance, and other attachments you add.
- Walk routes and location markers when you actively start a walk or choose to
  attach a location to a Moment.
- Coconut wallet, rewards, streaks, quests, purchase records inside the app, and
  other local progress data.
- Local PIN state and member privacy settings. Backup code is designed not to
  export PIN hash, salt, failed-attempt, or lockout fields.
- iCloud Drive backup status, such as whether automatic backup is enabled, last
  attempt/success/failure time, file name, path, and byte count.

## How Data Is Used

Ohana uses this data to provide the app's care, reminder, backup, privacy, and
progress features. Examples include:

- Showing home cards, dashboards, Today Focus, calendars, and member/pet detail
  pages.
- Logging care events and showing recent history.
- Scheduling local reminders and medication notifications.
- Protecting member-specific private fields with local PIN and optional Face ID.
- Exporting or restoring user-controlled backup files.
- Recording a walk route only while a walk is active.

Ohana does not use your data for advertising, cross-app tracking, analytics
profiling, or sale to data brokers.

## Backups, Exports, and iCloud

Ohana supports backup/export workflows that can contain sensitive app data:

- Automatic backup currently writes `Ohana Automatic Backup.json` into the user's
  iCloud Drive container when enabled. The setting is available in Settings >
  Data Backup and can be turned off.
- Manual export creates a user-controlled backup file. If you share that file,
  the destination and recipients are chosen by you.
- Backups may include sensitive household, pet, care, health, medication,
  expense, photo, document, and route data. Keep exported files private.
- Backups intentionally exclude local PIN hash/salt/lockout fields.

Ohana's developer does not operate an iCloud account, server, or support upload
pipeline that receives your backup. Apple may process iCloud Drive data under
your Apple ID and Apple's iCloud terms.

## Permissions

Ohana asks for permissions only when a feature needs them:

- Camera: used when you choose to take a member or pet avatar photo, Moment
  photo, or receipt photo.
- Photo Library: used when you choose images for avatars or attachments. Current
  code primarily uses Apple's PhotosPicker so Ohana receives only the items you
  select.
- Location While Using the App: used when you choose to attach a location to a
  Moment or actively start a walk route.
- Location Always: requested only to keep recording an active walk route while
  the app is in the background or the screen is locked.
- Notifications: used for reminders, care routines, medication reminders, and
  related local notification actions.
- Face ID / biometrics: optional shortcut for local member PIN gates. Ohana
  receives only success or failure from the system, not biometric data.
- iCloud Drive: used for the automatic backup file if the feature is enabled and
  the device is signed in to iCloud.

Ohana does not currently request Contacts, Microphone, Bluetooth, Local Network,
App Tracking Transparency, or HealthKit permissions.

## Sharing With Others

Current release:

- No data is sent to the developer.
- No ads, analytics SDKs, or tracking partners receive app data.
- Files are shared only when you choose to export or share them through iOS.
- iCloud Drive backups stay in the user's iCloud container.

Future releases:

- Family CloudKit collaboration is currently disabled by `OnlineFeatureGate`.
  If Ohana enables it, this policy must explain what data syncs through iCloud,
  who can access shared household records, how revocation works, and how App
  Store privacy answers change.

## Retention and Deletion

Ohana keeps app data until you edit it, delete it, reset the app, delete the app,
or remove backup files you created.

Current expected controls:

- Delete individual pets, members, logs, reminders, expenses, documents, and
  related records from inside the app where supported.
- Export your data from Settings > Data Backup.
- Reset app data from Settings when you want to remove local records under
  Ohana's control.
- Delete automatic backup files from iCloud Drive / Files if you do not want
  them retained in iCloud.

Deletion from one location may not automatically remove copies you exported,
shared, restored elsewhere, or stored in iCloud Drive outside the app's control.

## Security

Ohana uses platform-provided storage protections where available, including local
SwiftData storage, iOS file protection for backup files, and system Face ID /
biometric APIs for optional member-gate verification.

Local member PIN is a soft household privacy feature, not a replacement for
device-level security. Protect your device passcode and iCloud account.

## Children and Sensitive Data

Ohana can store sensitive household, pet, health, medication, route, document,
and expense information. Do not enter information you are not allowed to store or
share. If the app is used for minors or family members, the household owner is
responsible for using it appropriately and complying with local laws.

## Your Choices and Rights

Depending on where you live, you may have rights to access, export, correct, or
delete your data. Because Ohana is local-first and the developer does not receive
your app data in the current release, the practical controls are inside your
device, iCloud Drive, and any backup/export files you choose to create.

Use Settings > Data Backup to export a copy of your data. Use app deletion,
in-app reset, and iCloud Drive file deletion to remove data from locations under
your control.

## Changes to This Policy

This policy must be updated before releasing any change that adds developer data
collection, analytics, ads, accounts, support uploads, third-party SDK data
collection, CloudKit family sync, or any new protected-resource permission.

## Draft Review Checklist

Before publishing:

- Confirm the support contact above, or replace it with the final support
  website/email before publishing.
- Decide whether to publish one English policy URL or localized URLs.
- Confirm App Store Connect privacy label still matches this policy.
- Confirm automatic backup default and Settings copy match this policy.
- Confirm CloudKit collaboration remains gated off for the submitted build.
- Confirm `PrivacyInfo.xcprivacy`, `Info.plist`, and localized
  `InfoPlist.strings` still match the release binary.

## Sources Used For This Draft

- Apple App Privacy Details:
  https://developer.apple.com/app-store/app-privacy-details/
- Apple App Store Connect privacy policy URL help:
  https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Apple requesting access to protected resources:
  https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources
- Apple privacy manifest files:
  https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
