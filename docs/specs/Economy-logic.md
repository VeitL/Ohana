# Economy 规则书（GAP-4 总账恒等 / GAP-5 触顶感知 / GAP-7 补记结算）

确认日期：2026-06-12

本规则书覆盖宪法 D3/G2 在 Economy 钱包与总账中的首发语义，并补充 D14 预算触顶感知与 D12 补记结算。

## 已确认产品决定

- `system:legacy` 只作迁移兼容账户，不计入正式“岛屿总资产”，不出现在排行榜中。
- 当账户余额与账本事实重放结果不一致时，以账本为准，自动修正账户余额与 `QuestManager.coconutCount` 投影。
- 排行榜只显示正式成员钱包（人类成员 / 宠物）余额与贡献，不显示系统账户。
- `legacyHistory` 只用于历史展示，不影响余额；旧余额由 `openingBalance` 承接。
- 椰子预算触顶进入 `recordOnly` 后，照护记录照常保存；奖励反馈只提示温和满载文案，不展示预算数字、剩余额度或惩罚式解释。
- 补记历史照护记录照常进入照护事实历史日期；但椰子奖励的预算、冷却与钱包流水按用户执行补记的操作日结算。

## 业务不变量

- ECO-001：正式岛屿总资产在任何时候都等于所有正式成员钱包余额之和。正式成员钱包只包括 `ownerKind == human` 与 `ownerKind == pet` 的 `CoconutAccount`，不包括 `ownerKind == system` / `system:legacy`。
- ECO-002：每个正式成员钱包余额必须能由该账户下 `affectsBalance == true` 的 `CoconutLedgerEntry.delta` 重放得到。
- ECO-003：`QuestManager.coconutCount` 是 UI 投影缓存，不是经济事实源；刷新投影时必须使用 ECO-001 的正式岛屿总资产。
- ECO-004：启动后的钱包 bootstrap / 对账必须在首帧后执行，不阻塞启动首帧；发现账户余额与账本重放不一致时，自动以账本重放结果修正账户余额、成员缓存余额与投影。
- ECO-005：`legacyHistory` 流水永不影响余额，它只作为历史展示资料存在；迁移期的旧余额由 `openingBalance` 事实承接。
- ECO-006：排行榜与财富页正式资产展示不得显示 `system:legacy`，也不得把系统兼容余额伪装成成员贡献。
- ECO-007：开发 / 设置余额测试工具属于非正式测试工具。它不得作为首发用户经济语义的依据；正式发布前该入口必须不可达，由 release hardening / 开发者工具隐藏检查覆盖。
- ECO-008：当每日椰子预算进入 `recordOnly` 触顶状态时，照护记录必须照常完成；奖励反馈位置显示温和文案“今日椰子已装满，明天继续～”的九语言版本，不展示剩余额度、预算数字或说教式解释。
- ECO-009：补记历史照护记录时，`PetCareLog` / `CareLedgerEvent` 的照护事实时间必须保持用户选择的历史日期；不得为了经济防刷改写事实时间。
- ECO-010：补记历史照护记录获得的椰子奖励必须按操作日进入 `EconomyBudgetUsageEvent` 与冷却判断。历史日期已经触顶不得阻止今天的诚实补记获得今天预算内的奖励；今天已经触顶或处于冷却时，历史补记只记录事实，不额外产出椰子。
- ECO-011：补记产生的钱包奖励流水应按操作日显示在椰子历史中；照护历史仍按照护事实日期显示。两条时间轴不得互相污染。

## 当前代码来源

- `QuestManager.coconutCount` 已标注为 SwiftData 钱包投影缓存，源头是 `CoconutAccount` / `CoconutLedgerEntry`：`Ohana/Features/Economy/QuestManager.swift:91`。
- 钱包账户与流水模型定义在 `CoconutWalletModels`：`Ohana/Models/CoconutWalletModels.swift:83`、`Ohana/Models/CoconutWalletModels.swift:124`。
- 钱包写入由 `CoconutWalletService.apply` 同时更新账户与插入流水，并阻止余额变负：`Ohana/Domain/Economy/CoconutWalletService.swift:248`。
- 当前 `refreshQuestProjection` 会刷新 `QuestManager` 投影：`Ohana/Domain/Economy/CoconutWalletService.swift:453`。
- 启动路径在首帧后调度钱包 bootstrap：`Ohana/App/ContentView.swift:250`。
- 迁移导入会创建 `system:legacy` 兼容账户承接旧全岛总数差额：`Ohana/Domain/Economy/CoconutWalletService.swift:842`。
- `legacyHistory` 迁移流水以 `affectsBalance == false` 写入：`Ohana/Domain/Economy/CoconutWalletService.swift:888`。
- 每日预算裁决与 `recordOnly` 反馈文案定义在 `CoconutEconomyPolicyV2`：`Ohana/Features/Economy/CoconutEconomyPolicyV2.swift:55`、`Ohana/Features/Economy/CoconutEconomyPolicyV2.swift:120`。
- 奖励反馈 UI 通过 `CoconutRewardFeedbackOverlay` 展示事件标题：`Ohana/Features/TodayFocus/Views/CheckInRewardFeedback.swift:89`。
- 普通照护记录先用用户选择的 `date` 写照护事实，再调用经济奖励入口；奖励入口默认以当前操作时间做预算 / 冷却裁决：`Ohana/Domain/Services/CareEventService.swift:82`、`Ohana/Domain/Services/CareEventRecording.swift:567`、`Ohana/Features/Economy/QuestManager+Awards.swift:17`。
- 预算使用事件的 `dayKey` 来自经济奖励裁决日期，`createdAt` 保留真实写入时间：`Ohana/Features/Economy/CoconutEconomyPolicyV2.swift:653`。

## 状态机

钱包账户状态：

1. `missing`：账户尚未创建。
2. `bootstrapped`：迁移或首次写入创建账户，并写入 `openingBalance` 或业务流水。
3. `balanced`：账户余额等于账本事实重放结果。
4. `drifted`：账户余额与账本事实重放结果不一致。
5. `reconciled`：启动后或显式刷新时，以账本为准修复为 `balanced`。

允许迁移：

- `missing -> bootstrapped`：bootstrap 或钱包写入创建账户。
- `bootstrapped -> balanced`：写入事务成功后账户与流水一致。
- `balanced -> drifted`：旧数据、导入数据、测试工具或异常写入造成不一致。
- `drifted -> reconciled -> balanced`：对账服务按账本重放修复账户与投影。

补记结算状态：

1. `historicalFactDraft`：用户选择历史日期并提交照护记录。
2. `careFactRecorded`：照护事实写入历史日期，照护账本按历史日期展示。
3. `rewardEvaluatedOnOperationDay`：奖励管线按操作日读取每日预算与冷却。
4. `rewardGranted`：操作日预算 / 冷却允许时，钱包流水按操作日写入。
5. `recordOnly`：操作日预算触顶或处于冷却时，照护事实仍保留，椰子奖励为 0。

允许迁移：

- `historicalFactDraft -> careFactRecorded`
- `careFactRecorded -> rewardEvaluatedOnOperationDay`
- `rewardEvaluatedOnOperationDay -> rewardGranted`
- `rewardEvaluatedOnOperationDay -> recordOnly`

## 边界

- 本轮不改 SwiftData schema。
- 本轮不启用 CloudKit，不修改联机同步语义。
- `system:legacy` 可继续保留在数据库中用于迁移兼容与开发测试，但正式资产总数、财富页排行榜、椰子历史总额不计入它。
- 补记结算只管“用户提交历史日期照护事实”的奖励预算 / 冷却日期；不改变 Today Focus 每日完成奖、商店、成就、里程碑、绿洲注入包、自动备份或通知预算语义。
