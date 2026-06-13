# 照护完成收口重构规格（care-completion choke point）

> 目的：终结 Economy 复审反复发现的"某入口完成照护却绕过事实/奖励管线"一类问题（G1/G2 违规）。把"一动作一事实一次派生"从**靠约定**（每个调用方记得调）变为**靠结构**（唯一收口点 + 审计锁死，绕过即编译期/门禁期暴露）。
> 来源：Economy 三轮复审，每轮捞出一个新的绕过入口（round-2 抓到 Calendar / TodayFocus / 通知完成路径）。总览会话 2026-06-13 根因调查产出。
> 类型：**根因重构轮**（手册「收口与防返工规则」第 4 条）。必须走治本护栏三件套。

## 角色边界

本规格由总览会话产出，落在真实符号上。实现由专门重构会话执行。

## 根因（精确版）

收口点**已经存在且正确**：`CareEventService.recordCareFact`（`Ohana/Domain/Services/CareEventService.swift:406`）做了三件一致的事——写业务事实（`PetCareLog`）、经 `dependencies.economy.awardCareAction` 走奖励管线、`dependencies.careLedger.recordPetCare` 记账本。QuickCare、PetCare 已正确路由through它。

问题是**采纳不完整**：`awardAction` / `awardCareAction` 在 10 个 feature command 文件被**直接调用**，绕过 `recordCareFact`：
`Moments/MomentCommands`、`Health/PetHealthCommands`、`Expenses/ExpenseCommands`、`Walks/PetWalkingManager`、`Milestones/PetMilestoneCommands`、`DashboardRecords/DashboardRecordCommands` 等。

绕过的后果分两类：
- **真照护动作绕过收口** → 可能漏写事实、漏记账本、漏派生（quest/streak），或奖励归属错误。这是复审反复抓的那类。
- **非照护奖励**（花费、时刻、streak 里程碑、每日全完成 bonus、gacha、手动成就）→ 这些**合法**地不是"照护事实"，但仍须经共享奖励原语，复用同一套 owner 解析、预算、冻结钱包门、账本和幂等纪律；不得继续 ad-hoc 直调 `awardAction`。

## 统一原则与已拍板决策（2026-06-13）

**收口是"奖励派生纪律"，不是"事实类型统一"。** 不要把所有奖励入口塞进 `recordCareFact`。分两个家族，**R5 审计同时覆盖两者**，二者都不准 ad-hoc 直调 `awardAction`：

- **家族 1 照护事实**（产出 `PetCareLog` 类）→ 走 `recordCareFact`。
- **家族 2 非照护奖励** → 各自写事实+账本 + 共享奖励原语（owner/预算/冻结门/幂等），**不塞进 `recordCareFact`**。
- 判定测试：**强行迁入需要伪造 `CareType` 吗？** 需要 → 家族 2。

三个 plan 问题的拍板（覆盖 Codex 原推荐中 Q1 的分歧）：

| Q | 决策 | 归属 | 关键理由 |
|---|---|---|---|
| Q1 花费 | **不迁入 CareEventService**；花费保留自己的 Expense 事实+账本，奖励走共享原语+R5；**含 human expense** | 家族 2 | Expense 无 CareType，硬塞需伪造 → 过度收口；pet/human 对称（D10），拒绝按物种拆分（否决原 B）；"豁免"= 受审计的纪律豁免，非放任直调 QuestManager |
| Q2 时刻 | 不迁，R5 纪律豁免 | 家族 2 | 照片/记忆非照护动作 |
| Q3 全清/补签 | 保持豁免 + 护栏 | 家族 2 聚合 | 叠在已收口照护动作之上的元奖励，迁入会重复计数 |

附带：花费可赚椰子是潜在 farm 向量（ECO-025 / TFU-20260613-010），本轮不处理，仅登记。落地后 Economy 的 🏁 需重新复审确认（本重构改了其复审代码基线）。

## 修复策略：升为唯一收口 + 审计锁死（不新建重复服务）

### 第 1 步 厘清两类奖励
- **照护完成类**（喂食/喝水/便便/遛狗/用药剂量/清洁/健康记录等"用户完成了一次照护"）→ **必须**经 `CareEventService` 的照护事实收口族。
- **非照护奖励**（花费、时刻、连胜里程碑、每日全完成、gacha 抽取、手动成就/里程碑）→ 保持自己的事实类型和账本，经共享奖励原语，不强制进照护事实收口。
- 规则书需明确列出每个 `awardAction` 现有调用点属于哪类（开工先产出这张归类表，作为 plan 问题让产品主人确认边界模糊项）。

### 第 2 步 把照护完成类调用迁移进收口
- 将照护完成类的直接 `awardAction` 调用，改为经 `CareEventService` 既有或新增的照护事实收口族方法；不为非 `CareType` 事实伪造 `CareType`。
- 覆盖 round-2 已修的 Calendar / TodayFocus / 通知完成路径——确认它们现在也经收口（第二轮可能是点对点补的，本轮统一收口）。

### 第 3 步 审计锁死（新增 R5，扩展 `audit-economy-boundaries.sh`）
- **R5**：直接 `awardAction` 只允许在共享奖励原语 / 照护事实收口内部。家族 1 入口必须经 `CareEventService` 照护事实收口族；家族 2 入口必须经共享奖励原语并保留自己的事实+账本。任何 feature command/View 直接调用 `awardAction` = 违规；`// economy-boundary: allow <reason>` 需人工批准。
- 这条把"绕过"从"复审才发现"提前到"门禁当场拦截"——根因从此结构上不可复发。
- 配 bad/good fixture，进 `run-audit-fixture-tests.sh`。
- 全仓建棘轮基线：迁移完成后存量应清零；若有暂不迁移的合法例外，登记为债带偿还指针。

## 护栏三件套（这是重构，强制）

1. **表征测试先行**：迁移前，为每个受影响入口的当前外部可观察行为（写了哪些事实、发了多少奖励给谁、记了什么账本、推进了哪些派生）写"锁行为"测试，全绿后才动结构。以规则书 + 宪法 G1/G2 为行为基准。
2. **重构 commit 与行为 commit 分离**：把"调用路由从 `awardAction` 改为 `recordCareFact`"这种行为等价的迁移做成纯重构 commit（表征测试零改动且全绿）；任何顺带的行为修正单独 commit（先红后绿）。
3. **expand–contract**：先让 `recordCareFact` 覆盖新类型/新入口（新路径），切换调用方，门禁全绿后下一个 commit 再收紧旧直调路径并加 R5 审计。每步可回滚。

## 验收

- 所有照护完成类入口经唯一收口；R5 审计对新代码生效且 fixture 自检通过；
- 表征测试证明迁移行为等价（事实/奖励/账本/派生在迁移前后逐项相等）；
- `scripts/module-exit-gate.sh` PASS，CI 绿；
- 完成后 **Economy 重新对抗复审**：若本轮根治到位，应首次出现零 P0/P1 → 标 🏁。这是收敛的判定点。

## 风险与边界

- **不要过度收口**：非照护奖励（streak/gacha/手动成就）强行塞进照护收口会制造错误抽象。归类表是本轮第一个 plan 问题。
- **遛狗的特殊性**：`PetWalkingManager` 是"先存事实再发奖"（Walks 规则书已确立），遛狗结束发奖的时序不能被收口改坏——表征测试必须锁住遛狗的"先事实后奖励"顺序。
- **共享照护**：`awardSharedCareAction`（多宠一次操作）也要纳入收口考量，对应 `SharedCareSession`。
- **离世/冻结/回收钱包**：收口点必须保留现有 `EconomyWalletWritePolicy.canWrite` 门（G4），不能在迁移中丢失。
