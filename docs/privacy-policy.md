# Ohana Privacy Policy / Ohana 隐私政策

Last updated / 更新日期：2026-07-12
Support / 支持：[guanchen.li.119@gmail.com](mailto:guanchen.li.119@gmail.com?subject=Ohana%20Support)

## Summary / 摘要

Ohana is a local-first care app. The Solo release does not operate developer-
hosted accounts, advertising, analytics SDKs, tracking, support uploads,
CloudKit sharing, APNs remote notifications, or remote data synchronization.
Your records are used on your device to provide the app's features.

Ohana 是一款本地优先的照护应用。当前 Solo 版本不运营开发者托管账号、广告、
分析 SDK、追踪、支持材料上传、CloudKit 共享、APNs 远程通知或远程数据同步。
你的记录仅在设备上用于提供应用功能。

## Data Ohana Stores / Ohana 存储的数据

Depending on the features you use, Ohana can store the following data on your
device:

- household, member, pet, and plant profiles;
- care, calendar, reminder, task, reward, expense, insurance, document, photo,
  and route records;
- human wellness records, including weight, workouts, medication, health
  metrics, health reports, and notes; and
- local preferences, app settings, and automatic-backup status.

根据你使用的功能，Ohana 可能在设备上存储家庭、成员、宠物和植物资料；照护、日历、
提醒、任务、奖励、费用、保单、文档、照片和路线记录；人类健康记录（包括体重、
运动、用药、健康指标、健康报告和笔记）；以及本地偏好、应用设置和自动备份状态。

Human profiles are local care records, not Ohana accounts. Ohana does not read
your Apple Account profile to create a Human. When you explicitly create a
Human, a name is required; gender and birthday are optional.

Human 档案是本地照护记录，不是 Ohana 账号。Ohana 不会读取你的 Apple 账号资料来
创建 Human。只有当你主动创建 Human 时需要填写姓名；性别和生日均为可选。

## Health and Apple Health / 健康与 Apple Health

If you set up Apple Health, Ohana reads the HealthKit data needed for the Human
Workout feature, including activity summaries, steps, walking/running distance,
active energy, exercise and stand time, activity goals, and recent workouts. It
does not write data back to HealthKit. HealthKit data is queried and displayed
on-device; recent HealthKit workouts are not copied into the local Human workout
log. Manual Ohana workout records remain local.

如果你设置 Apple Health，Ohana 会读取“人类运动”功能所需的 HealthKit 数据，包括
活动摘要、步数、步行/跑步距离、活动能量、锻炼与站立时间、活动目标和最近运动记录；
不会向 HealthKit 写入数据。HealthKit 数据仅在本机查询和显示，最近的 HealthKit
运动记录不会复制到本地 Human 运动日志；手动创建的 Ohana 运动记录仍保留在本机。

Ohana does **not** place personal human-health information in iCloud. This
includes HealthKit-derived data, human weight, medication and medication logs,
health metrics, health reports, and Human workout records.

Ohana **不会**将个人的人类健康信息存入 iCloud，包括 HealthKit 衍生数据、人类体重、
用药及用药记录、健康指标、健康报告和 Human 运动记录。

Ohana marks its local Application Support persistence root, including the
SwiftData store and Human Note attachment directories, as excluded from
OS-managed device backups. The only app-managed iCloud path in the Solo release
is the restricted iCloud Drive package described below.

Ohana 会将本地 Application Support 持久化根目录（包括 SwiftData 存储和
人类笔记附件目录）标记为不参与系统管理的设备备份。Solo 版本中唯一由应用管理的
iCloud 路径，是下文所述的受限 iCloud Drive 备份包。

## Backups and Exports / 备份与导出

Automatic backup is optional and writes a restricted package to the user's own
iCloud Drive container. That package excludes the human-health data listed
above, health-related calendar and reminder records, all free-text family-task
records, and derived economy/ledger sidecars that could repeat health text.

自动备份为可选功能，会将受限备份包写入用户自己的 iCloud Drive 容器。该备份包不包含
上列人类健康数据，也不包含关联的人类健康事项、提醒、任何自由文本家庭任务，以及可能
重复健康文本的经济和账本侧车记录。

Manual backup packages that can be saved to Files or shared through system
providers use the same restricted data boundary. Ohana does not offer a path
that exports human-health or HealthKit-derived records to iCloud.

可保存到“文件”或通过系统提供方分享的手动备份包采用相同的受限数据边界。Ohana 不提供
将人类健康或 HealthKit 衍生记录导出到 iCloud 的路径。

Other exported information may still be sensitive, including household, pet,
location, document, photo, and expense data. Share such files only with people
you trust. Ohana does not receive these files.

其他导出信息仍可能敏感，包括家庭、宠物、位置、文档、照片和费用数据。请仅与可信对象
分享此类文件；Ohana 开发者不会接收这些文件。

If an app reset cannot remove the app-managed automatic backup because iCloud
Drive is unavailable, Ohana keeps a visible pending-cleanup status and lets you
retry. You can also remove your own backup files in the Files app.

若因 iCloud Drive 不可用而无法在重置应用时删除 Ohana 管理的自动备份，Ohana 会保留
可见的待清理状态，并允许你重试。你也可在“文件”应用中删除自己的备份文件。

## Data Sharing / 数据共享

Ohana does not send app records to the developer. It does not sell, use for
advertising, or use for cross-app tracking your personal, health, location, or
care data. It has no current account backend, CloudKit collaboration, or
server-side sync feature.

Ohana 不会将应用记录发送给开发者，也不会出售、用于广告或跨应用追踪你的个人、健康、
位置或照护数据。当前版本没有账号后端、CloudKit 协作或服务端同步功能。

Choosing an iOS share destination is your action. The destination's privacy
practices are governed by that provider's policies.

选择 iOS 分享目的地是你的主动操作；该目的地的隐私做法由相应提供方的政策决定。

## Permissions / 权限

Ohana asks only for permissions used by an enabled feature:

- Camera and Photos, when you choose an image or attachment.
- Location while using the app, and background location only during an active
  dog walk.
- Notifications, for local reminders and their actions.
- HealthKit, for the read-only Human Workout integration.
- iCloud Drive, when you enable automatic restricted backup.

Ohana 仅在启用功能需要时请求权限：选取图像或附件时的相机和照片；使用应用期间的位置，
以及仅在活跃遛狗期间的后台位置；本地提醒及其操作的通知；只读人类运动整合的 HealthKit；
以及启用受限自动备份时的 iCloud Drive。

## Retention, Deletion, and Choices / 保留、删除与选择

You can edit or delete supported records in the app, reset local app data, and
turn automatic backup off in Settings. App Reset removes app-managed local data
and attempts to remove the app-managed automatic iCloud Drive backup. Deleting
or resetting app data does not automatically erase copies you deliberately
shared or moved outside the app.

你可以在应用中编辑或删除支持的记录、重置本地应用数据，并在 Settings 中关闭自动备份。
重置 App 会删除应用管理的本地数据，并尝试删除应用管理的 iCloud Drive 自动备份。删除或
重置应用数据不会自动抹除你主动分享或移出应用的副本。

## Changes and Contact / 变更与联系

We will update this policy before enabling an Ohana account, Apple or Google
login, CloudKit sharing, remote sync, analytics, advertising, support uploads,
or any new protected-data use. For privacy questions or support, email
[guanchen.li.119@gmail.com](mailto:guanchen.li.119@gmail.com?subject=Ohana%20Support).

在启用 Ohana 账号、Apple 或 Google 登录、CloudKit 共享、远程同步、分析、广告、支持
上传或任何新的受保护数据用途之前，我们会更新本政策。如有隐私问题或需要支持，请发送
邮件至 [guanchen.li.119@gmail.com](mailto:guanchen.li.119@gmail.com?subject=Ohana%20Support)。
