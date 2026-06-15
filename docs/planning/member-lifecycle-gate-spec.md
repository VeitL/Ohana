# 成员生命周期门架构改造规格（MemberLifecycleGate）

> 类型：**架构改造**，不是复审修复轮。终结 Domain 第二横切根因（TFU-20260614-018/019 等）——"成员状态变化（离世/删除）后，能不能写"的判定散落在各 command/view，靠约定、没收口。
> 验收方式：**在任一成员写入路径构造不出"不过 gate 直接写"**（编译期/审计期），不是复审查全。
> 总览会话 2026-06-15 产出，落在真实符号上。实现由专门架构会话执行，护栏三件套强制。
> 与 care-derivation-executor、删除级联注册矩阵同构（这是同一招的第三次应用：把散落判定收回单一收口，让违反无法表达）。

## 病理（为什么散落、为什么打地鼠）

现状（已核实）：
- "成员能不能写"的判定有**多个不一致实现**：`CareFactWritePolicy.disposition`（`CareEventService.swift:114`，用 `EconomyWalletWritePolicy.canWrite(pet)`）、`CoconutExchangeManaging.canWrite(human)`（= `!human.hasPassedAway`）、`CalendarTaskCompletionSyncService.canWritePetTaskFact`（又包一层）。
- `hasPassedAway` / `passedAwayDate` **散落在约 173 个文件**，大量在各 feature command/view 里自己 `if pet.hasPassedAway` / `guard !canWrite`。
- 后果：每个对成员写业务事实/派生的 command 各自记得判断 deceased，**漏一个就是一个 P1**。TFU-019 明示："D7 memorial 只读未落服务层硬门，document/photo/insurance/medication/moment/milestone/human health/workout/wishlist/note 等 command 可对去世成员写 ledger/reward/reminder/health"。

**根因**：成员写入门是**靠约定**（每个 caller 记得判断），不是**靠结构**（统一收口）。复审每换一个 feature command 就发现同根因新表现 → 不收敛。

## 目标：单一生命周期门 + 写入路径强制消费

### 收口点：`MemberLifecycleGate`（新建，单一判定源）
- **唯一判定函数**：`MemberLifecycleGate.disposition(member, writeKind) -> MemberWriteDisposition`。member 是 Pet 或 Human；writeKind 见下。
- 收编现有所有散落判定：`CareFactWritePolicy.disposition`、`EconomyWalletWritePolicy.canWrite`、`CoconutExchangeManaging.canWrite`、`canWritePetTaskFact` 统一委托到这一个 gate（不删它们的调用点，改为内部调 gate，单一判定源）。
- `MemberWriteDisposition`：`allow` / `deny(reason)`；memorial 类额外带 `economyDerivationAllowed: false`（纪念内容不进经济系统，D7）。

### writeKind 分类（按 D7 v1.5「照护只读，回忆可写」）
- **`care`**（离世 → deny）：照护事实/健康/用药/体重/花费/保险保费/CareLedgerEvent/reward/reminder/quest/streak/mood；Human 侧健康/体重/锻炼/用药/笔记提醒。**离世成员不得新增/编辑/补记照护事实，不触发任何经济或照护派生。**
- **`memorial`**（离世 → allow，但 `economyDerivationAllowed = false`）：照片、回忆文字、纪念日、悼念笔记。
- **`profileEdit`**（离世 → deny 普通资料编辑）：撤销离世标记是**显式生命周期动作**，走单独入口，不经普通 profileEdit gate。
- **边界模糊项是 plan 第一问**（产品确认）：Document（证件存档=中性还是 care？）、Milestone（照护成就 vs 纪念日，可能要分两类）、Insurance（保费=care/经济，理赔档案=？）、Wishlist（对去世成员适用吗）、Moment（=memorial）。开工先产出「每个成员写入 command → writeKind」归类表，模糊项问我。

### 焊死写入路径（关键第三步）
所有对成员写业务事实/派生的 **domain command service 入口**强制先过 gate、消费 disposition：
- command service 拿到 `deny` → 整体 no-op（不写事实、不派生），返回 typed 结果（复用 `CareWriteOutcome`/disposition 模式，让调用方知道是 no-op）。
- **审计规则 R8（新增，扩展 `audit-economy-boundaries.sh` 或 derived-state）**：feature command/service 在写成员业务事实/派生前，若**自行用 `hasPassedAway`/`passedAwayDate` 做写入门判定**（而非过 `MemberLifecycleGate`）= 违规。
  - **难点与边界**：展示层读 `hasPassedAway`（灰显、彩虹桥标记、纪念页）是**合法**的，不能一刀切禁所有读。R8 只针对**写入路径**（command/service 里 `guard !hasPassedAway else { return }` 这类决定"写不写"的判定），不针对展示。实现上聚焦 `*CommandService` / `*Commands.swift` 的写入函数，View 展示读不在范围。配 bad/good fixture：bad=command 自行 `guard !hasPassedAway` 写 fact；good=command 过 gate。

## 与「删除引用完整性」的分界（不要混进本规格）

第二横切根因有两半，本规格**只管写入门**：
- **写入门（本规格）**：离世/active 成员能不能写——`MemberLifecycleGate`。
- **删除引用完整性（已有架构，不重做）**：删成员后 `executorId`/`sharedSessionId`/ledger actorId 的清/回落——归 `PhysicalDeletionService` + 删除级联注册矩阵（`physicalDeletionOwnerships`），TFU-015/016 在那条线补漏，不进本 gate。

## 护栏三件套（强制）

1. **表征测试先行**：迁移前为每个成员写入入口的**当前正常成功路径 + 当前 deceased 行为**写"锁行为"测试，全绿后才动结构。
2. **重构 commit 与行为 commit 分离**：把"散落判定改为过 gate"（行为等价的迁移）做成纯重构 commit；gate 暴露的真实行为偏差（某 command 本该 deny 却 allow）单独成行为修复 commit（先红后绿）。
3. **expand–contract 分批**：按 command 簇迁移（先 care 类 CareEventService 已有雏形 → Health/Medication → Expense/Insurance → Milestone/Document → Human 侧 → memorial 类）。每批独立可回滚。

## 验收（不用复审驱动）

- **结构判据**：在任一成员写入 command 里构造"不过 gate、自行判断 deceased 写 fact" → 编译不过 或 R8 拦。
- 表征测试全绿（行为等价 + deceased 行为符合 D7 v1.5）；TFU-018/019 各有对应测试锁死。
- 散落判定收编为单一判定源（`rg` 证明 `CareFactWritePolicy`/`CoconutExchangeManaging.canWrite` 等都委托 gate，无第二实现）。
- `scripts/module-exit-gate.sh` PASS，CI 绿。
- 完成后开**一次**全新纯复审（首发可达面），零 P0/P1 → 这一类（成员写入门）焊死。

## 风险

- **173 文件大部分是展示读，不是写入**——不要误收编展示路径（那会破坏纪念页/灰显）。R8 严格限定写入路径。
- writeKind 分类错会造成"该 allow 的 memorial 被 deny"（用户给去世宠物加不了纪念照片）或"该 deny 的 care 被 allow"（违反 D7）——归类表必须经产品确认。
- gate 是 Phase 7 后续模块（Memorial、各 feature 复审）的共同地基，做完它们直接继承。
