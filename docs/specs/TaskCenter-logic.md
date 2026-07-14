# Task Center 业务规则书

> 状态：当前首发实现。
> 最近核对：2026-07-14，依据 `TaskCenterRouteContainer`、`TaskCenterSnapshotBuilder`、`TaskActionCommandExecutor`、`TaskCareAssignmentCommandExecutor`、`FamilyTaskService` 与 Home / Members / Plant 路由符号。
> 所有者：`TaskCenterRouteContainer`（入口与加载）、`TaskCenterSnapshotBuilder`（投影）、`TaskActionCommandExecutor`（动作编排）、`TaskCareAssignmentCommandExecutor`（类型化照顾待办创建）。

## 1. 职责与入口

用户可见的底部区域名称是“待办”，内部 legacy tab 枚举仍为
`VerticalSolidHomeTab.calendar`。页内由 `TaskCenterSurface` 切换“清单 / 日历”：

- 清单负责可执行的宠物、植物、人类与家庭事项，以及领取、完成、提交、通过和
  驳回。
- 日历由 `CalendarRouteContainer` 保留完整时间视图；非行动型 Event 只需要在
  日历出现。带日期的本机 FamilyTask 由 `TaskCenterCalendarWorkflowStrip` 补充
  工作流操作；无日期 FamilyTask 只进入清单的“未排期”。
- 成员名册、Human 详情、Today Focus 和普通详情页都回到这个入口，不再各自维护
  一套任务中心。
- Pet / Plant 详情发起照顾待办时，路由携带值类型 `TaskCreationPreset`，创建页锁定
  当前对象和照顾类型；普通日历事项仍使用可编辑的对象选择器。

Task Center 不负责成员长期档案、体重趋势、植物领域分析或家庭洞察报表。

## 2. 统一快照

### TC-001 三类事实保持各自职责

- `Event` 提供日期、重复规则、发生次数、对象关联与 occurrence 完成状态。
- `Reminder` 提供提醒时间、通知状态及 Event / FamilyTask 之间的关联。
- `FamilyCollaborationTask` 提供发布者、指派 / 领取者、提交 / 审核状态和悬赏。

`TaskCenterRouteDataActor` 使用有界查询读取这些事实；跨 actor 只返回
`PersistentIdentifier` 和 `TaskCenterRouteDataReference` 等值，不返回 live
SwiftData model。主 actor 再由 `TaskCenterRouteData` 在当前 `ModelContext` 中重取
路由所需模型。

### TC-002 关联事实只显示一个任务项

`TaskCenterSnapshotBuilder` 通过 `relatedEventId` 或 `relatedReminderId` 找到关联
Event，并优先按同一 occurrence 日期匹配 FamilyTask。关联成功后生成单个
`TaskCenterItemSnapshot`，同时保留 `eventID`、`reminderID` 和 `familyTaskID`；不会
再把同一个 FamilyTask 作为独立项追加。

独立且未结束的 FamilyTask 也会生成快照；没有 due date 时进入 unscheduled。
Event 只有在 `isActionableTask` 为 true 时进入清单，普通信息事件仍由日历显示。

### TC-003 路由与 UI 只传稳定值

`TaskCenterItemSnapshot`、`TaskSubjectSnapshot`、`TaskActionCommand`、
`TaskActionResult`、`TaskCreationPreset`、`TaskCenterScope` 和
`TaskCenterRouteContext` 都是 Sendable 值。
路由可以按 all、human、pet 或 plant 过滤；Human scope 同时匹配任务 subject 与
发布者、指派者、领取者、完成者等 participant IDs。

`AppRoute.taskCenterContext` 为 Pet / Human / Plant 详情生成对象 scope；
`HumanDetailView` 使用 Human scope，“成员”名册的“查看待办”使用 all scope。

## 3. 统一动作边界

### TC-004 Task Center 动作先写业务事实，再推进工作流

Task Center 的 actionable row 和日历 FamilyTask strip 都把用户意图交给
`TaskActionCommandExecutor`：

1. Event-backed 完成先调用 `CalendarCommandExecutor`。
2. Calendar 路径负责照护事实、Event occurrence、Reminder、普通照护奖励与 ledger
   派生；FamilyTask 悬赏转账仍只发生在发布者审核通过时。
3. 只有 Calendar 完成成功后，executor 才继续推进关联 FamilyTask。
4. 领取、独立任务完成、提交、通过和驳回由
   `FamilyCollaborationCommandExecutor` / `FamilyTaskService` 执行。
5. 成功后 `TaskCenterRouteContainer` 重新加载统一快照。

因此照护事实写入失败时，Task Center 不得先完成关联 FamilyTask 或发放悬赏。
`TaskActionCommand.idempotencyKey` 由来源 ID、occurrence 日期和动作组成；已完成的
Event / FamilyTask 由 executor 返回 `alreadyApplied`，底层 Calendar、Reminder、
FamilyTask 和钱包命令继续拥有各自的持久化幂等与事务边界。

Today Focus 只把值命令交给 executor；executor 自己有界读取所需 Event、FamilyTask、
当前 Human 和关联 Pet，View 不直接执行 SwiftData fetch。

### TC-005 家庭分工状态机

本机 FamilyTask 使用以下主流程：

```mermaid
stateDiagram-v2
    active --> claimed: claim
    active --> completed: complete without reward
    claimed --> completed: complete without reward
    active --> pendingReview: submit rewarded task
    claimed --> pendingReview: submit rewarded task
    pendingReview --> completed: creator approves and transfer succeeds
    pendingReview --> active: creator rejects unclaimed task
    pendingReview --> claimed: creator rejects claimed task
```

- 有悬赏任务由执行者完成时进入 pendingReview；发布者确认且钱包转账成功后才进入
  completed。
- 确认失败保持 pendingReview，不允许半笔钱包或 ledger 事实。
- 驳回只重新打开任务及关联 Reminder；已经由 Event completion 记录的现实照护
  事实不因此删除。
- 无悬赏任务可以直接完成，并同步完成关联 Reminder。

经济边界见 [`Economy-logic.md`](Economy-logic.md)。

### TC-006 Solo 与多 Human 呈现

家庭分工仍是本机 Solo 数据。奖励为 0 的普通分工可直接完成；正数悬赏才进入
提交 / 审核，并在审核通过后转账。只有存在至少两位在世 Human 时，
`TaskCenterSnapshotBuilder.availableActions` 才显示 claim、submit、approve 和 reject，
`TaskCenterRouteContainer.requestAdd` 才提供“家庭分工 / 日历事项”的选择。单 Human
下直接创建日历事项，不展示分配、领取或审核控件；已有的无悬赏本机 FamilyTask
可直接完成，悬赏任务不得由同一 Human 自审。

多人家庭的清单额外提供“全部 / 当前成员 / 等待他人 / 待审核”筛选；这些筛选与
human、pet、plant 对象 scope 叠加，不会改变底层任务状态。单 Human 时整组筛选
隐藏，避免把本地档案误呈现成在线操作者。

这项本机能力不读取 `OnlineFeatureGate`；跨设备身份、邀请、同步和远端协作仍由
[`OnlineFeatureGate-logic.md`](OnlineFeatureGate-logic.md) 约束。

## 4. Today Focus 与成员路由

### TC-007 Today Focus 是统一快照的高优先级投影

`HomeReadModelStore` 读取 Task Center 所需的 Event、Reminder、FamilyTask 与对象值，
再由同一个 `TaskCenterSnapshotBuilder` 生成项目。Today Focus 只保留逾期、今天和
待审核项目，并继续按 active Human 的执行 / 审核责任过滤；它不再把 care Event
包装为另一套 Oasis quest。

点击项目会按同一个 `TaskCenterItemSnapshot.id` 聚焦待办；卡片上的直接动作也调用
`TaskActionCommandExecutor`。因此 Today Focus 的每个任务都必须能在待办页按稳定
ID 找到。“查看全部待办”会清除具体焦点，不得跳回旧协作 dashboard。

### TC-008 成员页不拥有任务数据

`CrewRosterOverlay` 只查询和呈现 Human / Pet 名册；legacy
`CrewRosterMode.collaboration` 解析为 `.members`。它的 `onOpenTaskCenter` 只负责
路由交接，不读取 FamilyTask。

`AppHumanRouteContainer` 把 Human ID 包装成 `TaskCenterRouteContext.human`；
Human 详情页的待办按钮打开该筛选，而不是复制任务列表或写入逻辑。

## 5. 类型化照顾待办创建

### TC-009 Event、Reminder 与可选 FamilyTask 一次落盘

`TaskCareKind` 明确区分宠物喂水、喂食、猫砂、玩耍、卫生及可排期植物照顾；
`Event.taskCareKindRaw` 持久化该语义，Calendar 完成不再依赖标题猜测。
`TaskCareAssignmentCommandExecutor` 在同一保存边界内创建：

1. 一个带对象和 care marker 的 Event；
2. 每个 occurrence 一个内部 Reminder；
3. 仅当发布者与执行者是不同 active Human 时，每个 occurrence 一个关联 FamilyTask。

通知权限被拒绝只会跳过系统通知排期，不会删除内部 Reminder。循环悬赏创建前按
全部 occurrence 校验发布者当前余额；0 奖励生成普通分工。保存成功后才异步排期
通知并发布刷新 revision。

V89 将 `Reminder.scheduledAt` 定义为通知投递时间，将可选 `occurrenceAt` 定义为
真实任务发生时间。完成、重新打开、Task Center 关联和 FamilyTask due date 都使用
`resolvedOccurrenceAt`；旧记录缺少该字段时回退 `scheduledAt`，保持历史兼容。

对象归档、离世或删除时，创建先整体拒绝；物理删除还必须清理以 Human、Pet 或
Plant 为 subject 的 FamilyTask，避免留下不可操作的孤儿分工。

## 6. 边界与验证

- Task Center 使用有界 Event window、pending Reminder 上限和 active FamilyTask
  上限；不得在可复用 SwiftUI row 中新增无界 `@Query` 聚合。
- 已归档 Plant、离世 Pet / Human 及其 active schedule 不进入可执行快照；成员
  生命周期门继续由 `MemberLifecycleActiveScheduleResolver` 与 `MemberLifecycleGate`
  裁决。
- `TaskCenterSnapshotBuilderTests` 当前覆盖关联去重、独立 / 未排期 FamilyTask、
  四类 subject、单 / 多 Human 动作和 Human scope 指标。
- `TaskActionCommandExecutorTests` 当前覆盖关联宠物 / 植物照护先写事实再进入审核、
  事实失败不推进投影、独立任务幂等、单 Human 无悬赏直接完成与悬赏自审拒绝；
  完整 FamilyTask 状态与悬赏失败边界继续由 `MemberLifecycleGateTests` 和 Economy
  tests 验证。
- `TaskCareAssignmentCommandExecutorTests` 覆盖 Solo / 多 Human 创建、重复 occurrence
  关联、失效对象整批拒绝、循环奖励总额校验，以及跨日提前通知不改变照顾
  occurrence；`DataBackupCoverageTests` 与 `SharedModelContainerRecoveryTests` 覆盖
  V89 codec、旧备份默认值与轻量迁移。
- `AppRouteCoordinatorTests` 当前覆盖 profile scope 与 focused FamilyTask context；
  成员 handoff、Today Focus 聚焦及普通进入清空焦点应继续由 Home route / source
  policy tests 守护。
