# Economy 规则书

确认日期：2026-06-12  
最近更新：2026-06-13
适用范围：Phase 6 Economy 模块；覆盖椰子钱包、正式岛屿总资产、奖励预算 / 冷却、商店消费、宠物成长椰子、成就奖励、财富页与椰子历史。

本规则书覆盖宪法 D2/D3/D7/D12/D13/D14/G2/G4/G8 在 Economy 模块中的首发语义，并保留 GAP-4 总账恒等、GAP-5 触顶感知、GAP-7 补记结算的已验证规则。

## 已确认产品决定

- `system:legacy` 只作迁移兼容账户，不计入正式“岛屿总资产”，不出现在排行榜中。
- 当账户余额与账本事实重放结果不一致时，以账本为准，自动修正账户余额与 `QuestManager.coconutCount` 投影。
- 排行榜只显示正式成员钱包（人类成员 / 宠物）余额与贡献，不显示系统账户。
- `legacyHistory` 只用于历史展示，不影响余额；旧余额由 `openingBalance` 承接。
- 椰子预算触顶进入 `recordOnly` 后，照护记录照常保存；奖励反馈只提示温和满载文案，不展示预算数字、剩余额度或惩罚式解释。
- 补记历史照护记录照常进入照护事实历史日期；但椰子奖励的预算、冷却与钱包流水按用户执行补记的操作日结算。
- 首发版本隐藏“家庭线下兑现 / cash exchange”所有用户可达入口；`CoconutExchangeRequest` model、服务、备份兼容代码保留给 1.x 合资 / 转账事实，不作为首发用户经济面。
- 隐私锁住的人类钱包仍计入正式“岛屿总资产”；财富页与椰子历史隐藏该成员的个人行、流水与明细，但总资产数字继续满足 D3/G2。
- 特殊奖励必须归属到正式成员钱包：优先使用明确 actor；没有 actor 时归到当前 active human；若没有可用当前主人则不写钱包奖励，只保留业务事实。首发新奖励不得落入 `system` / `system:legacy`。
- 旧兼容钱包 API 也必须遵守相同归属规则：能解析到可写人类 / 宠物时才写钱包；无 actor 时只能归到当前 active human；解析不到可写正式成员时 no-op，不得创建或补写 `system` 正式余额流水。
- 照护、花费、喂药、遛狗、时刻等可重复用户动作奖励必须先按明确执行人 `executorId` 归属；只有没有明确执行人时，才允许回退到当前 active human。
- 离世或回收成员的钱包冻结：不再获得奖励、不再消费、不再领取成就，也不计入活跃财富总额 / 榜单 / 趋势；历史流水可见。撤销离世或从回收站恢复后才恢复钱包写入能力。
- 商店正式消费支持岛屿合资：买家钱包不足但全岛未冻结人类钱包总额足够时，可由其他人类钱包补差额；总额仍不足时必须整体拒绝且不写任何钱包或购买事实。
- FamilyTasks 悬赏功能首发由 `OnlineFeatureGate` 隐藏；未来解锁前，悬赏确认必须复用 Economy 钱包写入边界。悬赏转账失败时不得把任务标为完成，不得留下 payer / receiver 钱包流水或照护账本事件。
- Economy 首发可见 UI、奖励反馈、钱包流水标题与时间文案必须走已注册语言 fallback；Debug / Preview / 内部测试文案不作为本轮首发阻塞。
- 财富页使用 Economy screen snapshot / read model 聚合，SwiftUI 视图不直接在 body 中重放账本或扫描成员模型；后续若大数据仍卡顿，再继续拆后台 snapshot store。

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
- ECO-012：首发版 `CoconutExchangeFeatureGate` 恒为关闭；Shop 分类、兑换表单、Today Focus 兑换卡、Home 待读模型中的待确认兑换入口均不可达。直接调用 UI 命令或 `CoconutExchangeService` 创建 / 确认 / 取消也必须 no-op / 抛 feature-disabled，不产生兑换请求或钱包写入。
- ECO-013：财富页活跃总资产 = 所有未冻结正式成员钱包余额之和，包含隐私锁住的人类成员；排行榜、筛选器、流水列表和个人余额不得泄漏隐私锁住成员的明细，也不得把离世 / 回收成员当作活跃财富 owner 展示。
- ECO-014：特殊奖励与旧兼容钱包 API 不得创建新的 `system` 正式影响余额流水。`system:legacy` 仅可由迁移兼容和明确非余额历史承接使用。
- ECO-015：`Human.hasPassedAway` / `Pet.hasPassedAway` / `trashedAt != nil` 的成员钱包为冻结状态；成就领奖、宠物金库消费、特殊奖励、商店消费、兑换创建 / 确认 / 取消等 Economy 命令不得写入冻结钱包。
- ECO-016：宠物成长椰子只能用于该宠物自己的成长 / 外观 / 纪念历史。宠物离世或回收时金库展示历史和预览，但购买 / 投喂按钮必须不可执行。
- ECO-017：财富页 screen model 只吃不可变快照值。图表、榜单、总资产、筛选和颜色计算不得在 SwiftUI body 中直接依赖 SwiftData 模型对象。
- ECO-018：奖励归属以业务事实执行人为准。已有 `executorId` 的照护 / 花费 / 遛狗 / 喂药 / 时刻记录不得把奖励发给当前 active human；active human 只作为无明确执行人的兜底。
- ECO-019：商店购买以全岛未冻结人类钱包作为可支配池；买家优先出资，其他人类钱包只补差额并记录各自支出流水。任何一笔出资失败时必须回滚整笔购买。
- ECO-020：FamilyTasks 悬赏确认是钱包转账事实边界。若 payer 余额不足、钱包冻结、转账重复键冲突或持久化失败，确认命令必须返回失败并保持任务待审核；不得吞错后展示完成态，也不得落下半笔钱包 / ledger 事实。

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
- 首发兑换入口由 `CoconutExchangeFeatureGate` 统一关闭；Shop、Home read model、Today Focus snapshot 与 `CoconutExchangeService` 写命令均必须读取同一判定点。
- 奖励 owner 解析由 `EconomyRewardOwnerResolver` 统一：`Ohana/Features/Economy/EconomyRewardOwnerResolver.swift`。
- 商店合资出资计划由 `CoconutWalletFundingPlanner` 计算，钱包 mutation 由 `CoconutWalletMutationWriter` 写入；UI 只显示全岛可支配余额：`Ohana/Domain/Economy/CoconutWalletFundingPlanner.swift`。
- FamilyTasks 悬赏转账暂由隐藏的 FamilyTasks 服务调用 Economy wallet mutation 边界；失败时 `confirmCompletion` 返回 `false` 并保持待审核：`Ohana/Features/FamilyTasks/FamilyTaskService.swift`。
- 财富页以 `IslandWealthSnapshot` / `IslandWealthScreenModel` 为 UI 聚合边界。

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

冻结钱包状态：

1. `activeWallet`：正式在世 / 未回收成员，可正常收入与消费。
2. `frozenWallet`：成员离世或进入回收站，钱包历史可见但不可写。
3. `restoredWallet`：撤销离世或恢复回收后回到 `activeWallet`。

允许迁移：

- `activeWallet -> frozenWallet`
- `frozenWallet -> restoredWallet -> activeWallet`

## 边界

- 本轮不改 SwiftData schema。
- 本轮不启用 CloudKit，不修改联机同步语义。
- `system:legacy` 可继续保留在数据库中用于迁移兼容与开发测试，但正式资产总数、财富页排行榜、椰子历史总额不计入它。
- 补记结算只管“用户提交历史日期照护事实”的奖励预算 / 冷却日期；不改变 Today Focus 每日完成奖、商店、成就、里程碑、绿洲注入包、自动备份或通知预算语义。
- `CoconutExchangeRequest` 继续参与 schema、备份、恢复与历史数据兼容；首发只是入口不可达，不执行 CloudKit 或合资流程。
- 财富页 snapshot 化不改变余额事实源；它只改变 UI 聚合边界。
