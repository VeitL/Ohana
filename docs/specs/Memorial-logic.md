# Memorial 规则书（GAP-9 离世退场）

确认日期：2026-06-14
最近更新：2026-07-15

本规则书覆盖宪法 D7 / G4 的首发纪念模式语义。离世不是删除：成员数据、历史记录、钱包历史和纪念资料必须保留；成员从活跃照护、提醒、委托、周报活跃统计和奖励写入中退场；误标记必须可撤销。

## 已确认产品决定

- 宠物离世后，`Pet.passedAwayDate` 是纪念模式的单一生命周期事实。
- 未来宠物照护安排不得由纪念流程硬删除、软删除、跳过或恢复。`RainbowBridgeService` 只写 `passedAwayDate`；活跃查询和 command 边界负责让离世成员退出写入和派生。
- 纪念退场不产生用户可见删除中转态，不设置过期清理；成员删除属于 D8 不可恢复物理删除，和纪念标记是两条不同路径。
- 撤销离世时，只清空 `passedAwayDate`；不重排或恢复提醒 / 事件。
- 离世成员不再进入首页主卡、功能菜单可见人类目标、待办活跃目标、周报活跃贡献统计和奖励账户写入。
- 钱包历史保留；奖励入口遇到离世人类时跳过人类钱包写入，遇到离世宠物时已有奖励跳过防线。

## 业务不变量

- MEM-001：标记宠物离世只写 `passedAwayDate`，不删除、跳过、恢复或重排 `Pet`、历史记录、未来 `Reminder` 或未来 `Event`。
- MEM-002：宠物离世后，活跃提醒 / 日历 / 照护入口必须在查询或 command 边界排除离世成员，不能通过改写历史对象来实现。
- MEM-003：撤销宠物离世必须只清空 `passedAwayDate`；不得恢复用户自己跳过、完成或删除的内容，也不得重排非本命令创建的派生状态。
- MEM-004：离世成员资料和历史可读，但 profile 更新、清空记录、照护写入、奖励、ledger、reminder、stock、Oasis 和 revision 派生必须 no-op。
- MEM-005：离世宠物不得进入待办活跃目标 / 兼容 quest / 照护计划 / 周报活跃宠物 / 快捷照护目标 / 功能菜单活跃宠物。
- MEM-006：离世人类不得进入首页主卡、功能菜单可见人类目标、待办活跃目标或周报活跃贡献统计。
- MEM-007：奖励入口不得向离世人类钱包写入奖励；离世宠物不得获得宠物照护奖励。
- MEM-008：纪念资料入口必须保留，用户仍能查看历史、档案、里程碑和钱包历史。
- MEM-009：纪念退场不得启用 CloudKit、远程通知、联机协作或 schema 迁移。
- MEM-010：任何 UI 文案不得承诺“删除未来提醒 / 事件”；应表达为“未来照护安排退出活跃提醒，原有数据保留，可撤销”。

## 模块收编清单

| 模块 / 文件 | 规则 |
|---|---|
| `Ohana/Features/Memorial/RainbowBridgeService.swift` | 纪念模式服务边界；只负责宠物 `passedAwayDate` 标记与撤销。 |
| `Ohana/Features/Members/MemberInteractionCommands.swift` | 成员生命周期命令入口；宠物委托给 `RainbowBridgeService`，人类写入 / 撤销 `passedAwayDate`。 |
| `Ohana/Features/Members/Views/PetBasicInfoDetailView+MemorialDanger.swift` | 宠物详情页文案不得说删除；只能说明活跃提醒退场、数据保留、可撤销。 |
| `Ohana/Features/CrewRoster/Views/CrewRosterOverlayEditors.swift` | CrewRoster 标记宠物离世文案同上。 |
| `Ohana/Features/Home/FocusHomeCardDataSource.swift` | 首页主卡排除离世宠物与离世人类。 |
| `Ohana/Features/FunctionMenu/Views/FunctionMenuRootView.swift`、`FeatureGroupDashboardView.swift`、`FeatureAggregateView.swift` | 功能菜单活跃宠物 / 可见人类目标排除离世成员。 |
| `Ohana/Features/Tasks/TaskCenterSnapshotBuilder.swift` 与任务读取边界 | 待办排除离世成员的活跃目标；旧 `IslandQuestEngine` 继续保留相同排除语义用于兼容测试。 |
| `Ohana/Features/FamilyReports/Views/FamilyWeeklyReportDashboardView.swift` | 周报活跃宠物和活跃人类贡献统计排除离世成员。 |
| `Ohana/Features/Economy/QuestManager+Awards.swift`、`QuestManager.swift` | 奖励入口遇到离世宠物 / 人类时跳过对应钱包写入。 |
| `Ohana/Domain/Services/PhysicalDeletionService.swift` | 删除是不可恢复物理删除边界；不承载纪念退场，也不恢复离世成员。 |

## 状态机

宠物生命周期：

1. `alive`：正常进入活跃照护、提醒、委托、奖励和首页。
2. `memorialized`：设置 `passedAwayDate`；历史和纪念入口保留；所有写入和派生边界 no-op。
3. `aliveRestored`：撤销离世；清除 `passedAwayDate`；不自动恢复或重排提醒 / 事件。

允许迁移：

- `alive -> memorialized`
- `memorialized -> aliveRestored`
- `aliveRestored -> memorialized`

禁止迁移：

- `memorialized -> hardDeletedByMemorial`
- `memorialized -> recoverableDeletion`

## 验收

- 自动测试：`RainbowBridgeServiceTests` 覆盖未来计划不被纪念流程改写、撤销只清空生命周期字段、离世人类奖励冻结。
- 自动测试：`MemberCreationServiceTests` 覆盖离世人类不出现在首页卡。
- 自动测试：任务快照覆盖离世成员不进入活跃待办；旧 `islandQuestEngineDoesNotAssignWeightQuestToDeceasedHuman` 继续覆盖兼容引擎不派生离世人类目标。
- 真实 UI / 真机通知验收记录在 `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`。

## 边界

- 本轮不改 SwiftData schema。
- 本轮不启用 CloudKit、远程推送或联机协作。
- 本轮不改启动路径。
- 本轮不做纪念页面大改版；只修正活跃退场、可撤销语义和错误删除文案。
