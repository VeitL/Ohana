# OnlineFeatureGate Logic

> 状态：当前首发边界。
> 最近核对：2026-07-15，依据 `OnlineFeatureGate`、`AppCapabilityProfile`、`AppFeatureRouteGuard`、`TaskCenterRouteContainer` 与 `FamilyTaskService`。
> 所有者：`OnlineFeatureGate` 与 `AppCapabilityProfile`；具体远端入口由 `AppFeatureRouteGuard` 和 CKShare / Settings 写入边界共同执行。

## Purpose

`OnlineFeatureGate` 只裁决需要远端传输、共享家庭身份或 CloudKit share
的联机能力。它不按模型名称裁决本机功能：`FamilyCollaborationTask` 虽沿用
collaboration 命名，但当前“家庭分工”是同一设备上的本地 SwiftData 记录，
不是账号、远程邀请或跨设备协作。

未来付费多设备同步和多主人协作应继续从这一门控演进，而不是在本机 Task
Center、Human 数量或 FamilyTask 写入路径散落新的在线判定。

## Launch Semantics

- 首发 `AppCapabilityProfile.shipsCloudFamilyCapabilities` 为 false，
  `OnlineFeatureGate.allows(.onlineCollaboration)` 也为 false。
- 关闭门控必须阻止 CloudKit share 接受、云同步设置、远端家庭邀请、共享
  database scope 切换，以及明确标为未来联机面的入口。
- 关闭门控不得隐藏本机 Task Center、`FamilyCollaborationTask`、家庭分工创建与
  审核、成员名册、提醒、照护记录、本地备份或
  家庭周报。
- 同一设备上存在多个 Human 只决定是否显示领取、分配和审核等本机控件，
  不能被解释为在线能力已开启。
- 本地 mutation metadata、schema 和备份 DTO 可以为兼容性保留；这不等于
  CloudKit 上传、拉取或共享家庭已经启用。

## Local Household Assignments

以下路径属于首发本机能力，不读取 `OnlineFeatureGate`：

- `TaskCenterRouteDataActor` 读取可见 `Event`、pending `Reminder` 和 active
  `FamilyCollaborationTask`，由 `TaskCenterSnapshotBuilder` 生成统一任务投影。
- `TaskCenterRouteContainer` 是清单 / 日历的统一用户入口；
  `TaskActionCommandExecutor` 把事件完成交给 `CalendarCommandExecutor`，把领取、
  提交、通过和驳回交给 `FamilyCollaborationCommandExecutor` / `FamilyTaskService`。
- `HomeReadModelStore` 不再投影 Today Focus；逾期、今天、待审核与系统旅程事项
  只在统一 Task Center 展示，并使用同一稳定任务 ID 与动作执行器，而不是打开
  成员页、Oasis quest 或旧协作 dashboard。
- `CrewRosterOverlay` 只管理成员名册，并通过 `onOpenTaskCenter` 跳转统一待办；
  Human 详情通过 `TaskCenterRouteContext.human` 打开成员筛选结果。
- `FamilyTaskService` 负责本机创建、指派、领取、提交、审核、提醒联动和悬赏
  转账事务。`FamilyCollaborationTaskBackup` 负责本地备份 / 恢复兼容。

完整投影与动作规则见 [`TaskCenter-logic.md`](TaskCenter-logic.md)。

## Gated Online Surfaces

### Future Collaboration UI

- `AppFeatureRouteGuard` 仍把 `FMDest.bountyBoard` 视为联机目的地；门控关闭时该
  旧 / 未来 dashboard 不可从首发导航到达。这不影响 Task Center 内可达的本机
  家庭悬赏。
- `FamilyCollaborationDashboardView`、`BountyBoardView` 和旧 day-zero bounty
  页面可以作为迁移或未来实现代码保留，但不得重新成为首发独立入口。
- `CrewRosterMode.collaboration` 只作 legacy route 兼容，`CrewRosterOverlay` 将其
  解析为成员名册，不恢复第二个一级面。

### Settings Cloud Sync

- `SettingsView` 不渲染家庭云同步区。
- `SettingsView+CloudSync` 的邀请、绑定、重试、保存和停止共享命令也必须在
  写入或启动远端服务前检查门控，不能只依赖 UI 隐藏。

### CKShare Invite And Accept

- `OhanaCloudSharingAppDelegate` 必须在调用 `CloudSyncHouseholdShareService`、
  写 accepted-share state、启用 cloud sync 或启动远端收发前拒绝 CKShare。
- `CloudSyncShareRuntime` 可以保留为未来实现细节，但当前没有可达的接受路径。
- Solo target 不注册 APNs，也不声明 `remote-notification` background mode 或
  CloudKit service entitlement；存在 dormant CloudKit 代码不构成现有能力。

## Blocked UX

用户在首发版打开他人的 CKShare 链接时，Ohana 必须显示明确且尊重的提示：

- 标题：“联机协作即将推出”
- 正文：“这个版本不会加入共享家庭，您的本机数据保持不变。”

应用不得崩溃、静默接受 share、启用同步，或把当前本地 store 切换成共享家庭。

## Reports And Economy

本地家庭周报、照护贡献和 Task Center 家庭分工属于单设备摘要，可以在首发
可达。涉及悬赏时，发布者确认和钱包转账继续遵守 `FamilyTaskService` 与 Economy
规则；门控关闭不是绕过或禁用本机经济不变量的理由。

在线排行榜、远端家庭成员贡献合并或跨设备悬赏状态仍属于未来联机能力，必须
留在 `OnlineFeatureGate` 后方。

## Entitlement Evolution

未来 entitlement 服务可以替换 `OnlineFeatureGate` 内部实现，但调用者仍只询问
是否允许 online collaboration。任何调用点都不得仅根据 CloudKit account state、
UserDefaults sync flag、Human 数量、build configuration、订阅字符串或产品 ID
自行推断联机可用性。
