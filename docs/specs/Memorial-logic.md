# Memorial 规则书（GAP-9 离世退场）

确认日期：2026-06-12

本规则书覆盖宪法 D7 / G4 的首发纪念模式语义。离世不是删除：成员数据、历史记录、钱包历史和纪念资料必须保留；成员从活跃照护、提醒、委托、周报活跃统计和奖励写入中退场；误标记必须可撤销。

## 已确认产品决定

- 宠物离世后，`Pet.passedAwayDate` 是纪念模式的单一生命周期事实。
- 未来宠物照护安排不得硬删除。`RainbowBridgeService` 将未来 `Reminder` 标记为纪念流程跳过，并将未来 `Event` 标记为纪念退场；二者都保留原始对象。
- 纪念退场不进入用户可见回收站，不设置 30 天过期清理；回收站只处理删除 / 清空记录，纪念模式只处理活跃退场。
- 撤销离世时，只恢复由纪念流程标记的提醒和事件；用户自己跳过、完成、删除或回收的内容不被误恢复。
- 离世成员不再进入首页主卡、功能菜单可见人类目标、Today Focus 人类体重委托、周报活跃贡献统计和奖励账户写入。
- 钱包历史保留；奖励入口遇到离世人类时跳过人类钱包写入，遇到离世宠物时已有奖励跳过防线。

## 业务不变量

- MEM-001：标记宠物离世只写 `passedAwayDate` 与纪念退场标记，不删除 `Pet`、历史记录、未来 `Reminder` 或未来 `Event`。
- MEM-002：宠物离世后，所选离世时间之后的 pending `Reminder` 必须取消系统通知，并以 `system:memorial:<petID>` 标记为 skipped。
- MEM-003：宠物离世后，所选离世时间之后的 active `Event` 必须以 `memorial:<petID>` 标记退场，`trashExpiresAt` 保持 nil，避免被 30 天回收站清理。
- MEM-004：撤销宠物离世必须清空 `passedAwayDate`，恢复纪念标记的未来 `Event`，并把纪念标记的 `Reminder` 恢复为 pending；非纪念标记内容不动。
- MEM-005：离世宠物不得进入 Today Focus / quest / 照护计划 / 周报活跃宠物 / 快捷照护目标 / 功能菜单活跃宠物。
- MEM-006：离世人类不得进入首页主卡、功能菜单可见人类目标、Today Focus 人类体重委托或周报活跃贡献统计。
- MEM-007：奖励入口不得向离世人类钱包写入奖励；离世宠物不得获得宠物照护奖励。
- MEM-008：纪念资料入口必须保留，用户仍能查看历史、档案、里程碑和钱包历史。
- MEM-009：纪念退场不得启用 CloudKit、远程通知、联机协作或 schema 迁移。
- MEM-010：任何 UI 文案不得承诺“删除未来提醒 / 事件”；应表达为“未来照护安排退出活跃提醒，原有数据保留，可撤销”。

## 模块收编清单

| 模块 / 文件 | 规则 |
|---|---|
| `Ohana/Features/Memorial/RainbowBridgeService.swift` | 纪念模式服务边界；负责宠物离世、未来提醒 / 事件退场、撤销恢复。 |
| `Ohana/Features/Members/MemberInteractionCommands.swift` | 成员生命周期命令入口；宠物委托给 `RainbowBridgeService`，人类写入 / 撤销 `passedAwayDate`。 |
| `Ohana/Features/Members/Views/PetBasicInfoDetailView+MemorialDanger.swift` | 宠物详情页文案不得说删除；只能说明活跃提醒退场、数据保留、可撤销。 |
| `Ohana/Features/CrewRoster/Views/CrewRosterOverlayEditors.swift` | CrewRoster 标记宠物离世文案同上。 |
| `Ohana/Features/Home/FocusHomeCardDataSource.swift` | 首页主卡排除离世宠物与离世人类。 |
| `Ohana/Features/FunctionMenu/Views/FunctionMenuRootView.swift`、`FeatureGroupDashboardView.swift`、`FeatureAggregateView.swift` | 功能菜单活跃宠物 / 可见人类目标排除离世成员。 |
| `Ohana/Features/TodayFocus/IslandQuestEngine.swift` | Today Focus 排除离世宠物；离世人类不再获得人类体重委托。 |
| `Ohana/Features/FamilyReports/Views/FamilyWeeklyReportDashboardView.swift` | 周报活跃宠物和活跃人类贡献统计排除离世成员。 |
| `Ohana/Features/Economy/QuestManager+Awards.swift`、`QuestManager.swift` | 奖励入口遇到离世宠物 / 人类时跳过对应钱包写入。 |
| `Ohana/Domain/Services/RecycleBinService.swift` | 不承载纪念退场；纪念标记的 `Event` 不设置过期时间，也不出现在用户回收站条目。 |

## 状态机

宠物生命周期：

1. `alive`：正常进入活跃照护、提醒、委托、奖励和首页。
2. `memorialized`：设置 `passedAwayDate`；未来提醒取消系统通知并退出 pending；未来事件退出活跃查询；历史和纪念入口保留。
3. `aliveRestored`：撤销离世；清除 `passedAwayDate`；纪念标记的未来提醒和事件恢复。

允许迁移：

- `alive -> memorialized`
- `memorialized -> aliveRestored`
- `aliveRestored -> memorialized`

禁止迁移：

- `memorialized -> hardDeletedByMemorial`
- `memorialized -> recycleBinExpiringMemorialPlans`

## 验收

- 自动测试：`RainbowBridgeServiceTests` 覆盖未来计划保留 / 退场、撤销恢复、离世人类奖励冻结。
- 自动测试：`MemberCreationServiceTests` 覆盖离世人类不出现在首页卡。
- 自动测试：`OhanaTests.islandQuestEngineDoesNotAssignWeightQuestToDeceasedHuman` 覆盖 Today Focus 不给离世人类派体重委托。
- 真实 UI / 真机通知验收记录在 `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`。

## 边界

- 本轮不改 SwiftData schema。
- 本轮不启用 CloudKit、远程推送或联机协作。
- 本轮不改启动路径。
- 本轮不做纪念页面大改版；只修正活跃退场、可撤销语义和错误删除文案。
