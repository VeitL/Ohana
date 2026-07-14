# Ohana Permission Rationale Draft

Status: Draft for App Store review notes, in-app rationale copy, and
`Info.plist` usage-description review.

Last updated: 2026-07-12

## Current Permission Inventory

| Surface | Current source | Trigger | Rationale |
| --- | --- | --- | --- |
| Camera | `NSCameraUsageDescription`, `AVCaptureDevice.requestAccess(for: .video)` | User taps camera for avatar or receipt capture | Take a photo the user explicitly requested and attach it to a member, pet, Moment, or receipt. |
| Photo Library | `NSPhotoLibraryUsageDescription`, `PhotosPicker` | User chooses an avatar or attachment image | Import only the user-selected image(s). Current PhotosPicker paths do not scan the full library. |
| Location When In Use | `NSLocationWhenInUseUsageDescription`, `LocationManager.requestWhenInUseAuthorization()` | User starts a walk or asks for a one-shot location | Record a walk route or attach the current place to a user-created Moment. |
| Location Always | `NSLocationAlwaysAndWhenInUseUsageDescription`, `requestAlwaysAuthorization()` | User upgrades while walk background tracking is needed | Continue recording the current walk route when Ohana is backgrounded or the screen is locked. |
| Notifications | `UNUserNotificationCenter.requestAuthorization` | User creates reminder/care/medication notification flows | Deliver local reminders and allow notification actions such as Done, Skip, or Tomorrow. |
| Face ID / Biometrics | `NSFaceIDUsageDescription`, `LAContext.evaluatePolicy` | User enables or uses member-gate biometrics | Let the device verify the current user as a shortcut to a local member PIN. Ohana receives only success/failure. |
| Apple Health / HealthKit | `NSHealthShareUsageDescription`, `HKHealthStore.requestAuthorization` | User taps the Apple Health setup action in Human Workout | Read steps, walking/running distance, active energy, exercise and stand time, Activity Summary goals, and workouts for the selected Human's read-only local summary. |
| iCloud Drive backup | iCloud ubiquity entitlement and `ICloudDriveAutomaticBackupFileStore` | Automatic backup is enabled or user taps Back Up Now | Save a backup file to the user's own iCloud Drive container. Developer does not receive it. |
| Remote notifications / CloudKit | Not declared by the Solo capability profile; dormant CloudKit code remains | Not reachable in the Solo release | Future-only. Adding APNs, `remote-notification`, CloudKit sharing, or remote sync requires an explicit capability change, policy update, and release validation. |

## Recommended System Purpose Strings

The current `Info.plist` default language is Chinese. English and German have
reviewed localized `InfoPlist.strings`; Spanish, Portuguese, French, Japanese,
Korean, and Italian currently carry explicit English fallback files so a
registered app language never falls through to an unrelated Chinese system
prompt. There is no separate `zh-Hans.lproj/InfoPlist.strings`; the default
Chinese strings remain the Simplified Chinese source.

### Camera

Current Chinese:

> 用于在你主动拍照时创建成员或宠物头像、时刻照片或收据附件。

Recommended Chinese:

> 用于在你主动拍照时创建成员或宠物头像、时刻照片或收据附件。

Recommended English:

> Used when you choose to take a member or pet avatar, Moment photo, or receipt attachment.

Review rationale:

- Requested only after the user taps a camera action.
- No continuous camera access after capture.
- Captured images stay local unless the user exports/backups/shares them.

### Photo Library

Current Chinese:

> 用于导入你选择的头像、时刻图片或收据附件；Ohana 只处理你选中的项目。

Recommended Chinese:

> 用于导入你选择的头像、时刻图片或收据附件；Ohana 只处理你选中的项目。

Recommended English:

> Used to import avatars, Moment images, or receipt attachments that you select.

Review rationale:

- Current code uses PhotosPicker for selected image import.
- Ohana should not scan the full library, read unrelated images, or upload photo
  metadata to the developer.

### Location While Using the App

Current Chinese:

> 用于在「记录时刻」中附加当前地点，以及在你主动开始遛狗时记录路线。

Recommended Chinese:

> 用于在你主动记录时刻或开始遛狗时，附加当前位置并记录本次路线。

Recommended English:

> Used when you add a location to a Moment or start a walk so Ohana can record that route.

Review rationale:

- Requested from walk/location actions, not at first launch.
- One-shot location is used for user-created location context.
- Route points are used for the active walk and local history.

### Location Always / Background Location

Current Chinese:

> 仅在你正在遛狗时使用，用于锁屏或切到后台后继续记录本次路线。

Recommended Chinese:

> 仅在你正在遛狗时使用，用于锁屏或切到后台后继续记录本次路线。

Recommended English:

> Used only during an active walk to keep recording the current route when the app is in the background or the screen is locked.

Review rationale:

- Always authorization is tied to an active walk and background route
  continuity.
- No advertising, analytics, geofencing, or background location when no walk is
  active.
- LocationManager clears background delivery when a walk stops or pauses.

### Face ID

Current Chinese:

> 用于在切换受保护成员或访问成员门禁时，通过系统 Face ID 代替输入本地 PIN。

Recommended Chinese:

> 用于在切换受保护成员或访问成员门禁时，通过系统 Face ID 代替输入本地 PIN。

Recommended English:

> Used to verify protected member switching with Face ID instead of entering the local PIN.

Review rationale:

- Optional member-gate convenience.
- The system handles biometric matching; Ohana receives only success or failure.
- PIN remains available as fallback.

### Notifications

No `Info.plist` usage-description key is required for user notifications, but
App Review and users still need clear context before the system prompt.

Recommended in-app rationale before requesting notifications:

Chinese:

> Ohana 可以提醒你喂食、喝水、用药、任务和家庭照护事项。通知只用于你创建或启用的提醒，可在设置中关闭。

English:

> Ohana can remind you about feeding, water, medication, tasks, and care routines you create or enable. You can turn notifications off in Settings.

Review rationale:

- Notifications are for local reminders and user-enabled care flows.
- Medication notification privacy can hide detailed pet medication content.
- No marketing push should be sent unless a future policy explicitly adds it and
  obtains appropriate consent.

### Apple Health / HealthKit

Current Chinese:

> 用于在你主动设置 Apple Health 时读取步数、距离、活动能量、锻炼与站立时间、活动目标和运动记录，并在本机显示此成员的健康摘要。

Recommended Chinese:

> 用于在你主动设置 Apple Health 时读取步数、距离、活动能量、锻炼与站立时间、活动目标和运动记录，并在本机显示此成员的健康摘要。

Recommended English:

> Used when you set up Apple Health to read steps, distance, active energy, exercise and stand time, activity goals, and workouts for this member's local summary.

Review rationale:

- Requested only after the user taps the Human Workout Apple Health setup
  action.
- V1 is read-only: Ohana declares `NSHealthShareUsageDescription` and does not
  declare `NSHealthUpdateUsageDescription`.
- HealthKit daily activity and recent workouts are queried and shown as
  read-only page data. They are not copied into the local Human workout log.
- Ohana manual workouts remain local records. Existing external-source copies
  created by older builds are preserved as fallback and are not exported.
- Ohana does not send Apple Health data to the developer.

### iCloud Drive Backup

iCloud Drive does not use a TCC purpose string, but the Settings UI and privacy
policy need plain-language disclosure.

Recommended Settings support text:

Chinese:

> 自动备份会把一份受限的 Ohana 备份文件保存到你的 iCloud Drive。它可包含家庭、宠物、照片、文件、路线和账单数据，但不包含人类健康、HealthKit、体重、运动、用药、健康报告、自由文本家庭任务或派生经济/账本侧车。手动导出同样受此限制，因为它也可能保存到 iCloud 或其他文件服务。不会发送给开发者。你可以关闭自动备份或删除 iCloud Drive 中的备份文件。

English:

> Automatic backup saves a restricted Ohana backup file to your iCloud Drive. It may include household, pet, photo, document, route, and expense data, but it excludes human health, HealthKit, weight, workout, medication, health-report data, free-text family tasks, and derived economy/ledger sidecars. Manual export uses the same restriction because it can also be saved to iCloud or another file provider. The file is not sent to the developer. You can turn automatic backup off or delete the file from iCloud Drive.

Review rationale:

- Backup is user-controlled and stored in the user's Apple iCloud account.
- The developer does not receive the file.
- Automatic backup excludes human-health/HealthKit data and PIN
  hash/salt/lockout fields, but may still contain other sensitive app content.

## App Review Notes

Suggested short review note for the current release:

> Ohana is local-first and does not send user data to the developer. Camera,
> photo, location, local notification, Face ID, Apple Health read access, and iCloud
> Drive backup features are user initiated. Apple Health access is read-only and
> used to show the selected Human's local workout summary and history. Location
> Always is used only during an active walk to continue recording the route in the
> background. Family CloudKit collaboration code is gated off in the current
> release by `OnlineFeatureGate.allows(.onlineCollaboration) == false`. The Solo
> target does not declare APNs, the `remote-notification` background mode, or a
> CloudKit service entitlement or Sign in with Apple capability.

## Must Not Claim Yet

Do not claim the following until implemented and revalidated:

- Production CloudKit family sync. The code exists, but the current gate is
  false, the Solo capability profile does not declare the required capabilities,
  and real-device CloudKit validation is still deferred.
- Developer-hosted accounts, account sync, or uploads of health, care, route,
  note, photo, document, PIN, or economy-ledger data.
- Analytics, advertising, tracking, support upload, or third-party crash-report
  collection.

## Release Checklist

- `Ohana/Info.plist` purpose strings match this document.
- `Ohana/en.lproj/InfoPlist.strings` and `Ohana/de.lproj/InfoPlist.strings`
  match the final approved wording.
- The other registered language directories contain an explicit safe English
  fallback until reviewed native-language permission copy is approved; do not
  silently delete those files.
- If a `zh-Hans.lproj/InfoPlist.strings` file is added later, keep it in sync
  with the default Chinese `Info.plist` wording.
- `docs/privacy-policy.md` is published at the Settings privacy-policy URL
  before App Store submission.
- App Store Connect privacy answers are updated if an account backend, CloudKit
  sync, analytics, tracking, support upload, or any third-party SDK data
  collection is enabled.

## Sources Used For This Draft

- Apple requesting access to protected resources:
  https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources
- Apple "Write clear purpose strings" Tech Talk:
  https://developer.apple.com/videos/play/tech-talks/110152/
- Apple App Privacy Details:
  https://developer.apple.com/app-store/app-privacy-details/
