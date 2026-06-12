# Ohana AI 协作模块测试与修复手册（v2 · 多会话架构）

目标：按依赖顺序逐模块"分析 → 修复 → 补测试 → 门禁 → 人工验收 → 提交"，全部走完后进入上架准备。

v2 核心变化：
1. **多会话架构**——每个模块在独立 AI 会话中处理（避免 context 膨胀），一个总览会话负责调度与对账；所有进度状态只存在于文件，不依赖任何会话的记忆。
2. **模块退出自动门禁**——每个模块完成后，运行 `scripts/module-exit-gate.sh`，自动跑全套审计 + **整个 app 的完整单元测试**，门禁不绿不许提交。

诚实声明：没有任何流程能"保证"Apple 审核通过。本手册保证的是可控部分——代码质量、测试覆盖、合规审计、发布材料齐备——把审核风险压到最低。

---

## 一、会话架构（总览会话 + 模块会话）

### 状态只活在文件里

| 文件 | 作用 |
|---|---|
| `docs/testing-progress.md` | **唯一进度源**：阶段/模块状态表、交接备注、对账日志 |
| `docs/ai-module-test-playbook.md` | 本文件：工作协议，每个新会话必读 |
| `docs/task-follow-ups.md` | 未修的 P1/P2 余留项 |
| `docs/specs/<模块>-logic.md` | **模块业务规则书**：从代码反推、经你确认的业务不变量（见循环第 1b 步），复审与未来开发的基准 |
| git history | 每个模块的门禁 commit |

会话记忆不可信。换会话、断会话、并行会话，一切以上述文件为准。

### 模块会话（Worker）

一个会话只负责**一个模块**的完整六步循环。开工 boot prompt（直接复制）：

> 读 `AGENTS.md`、`docs/ai-module-test-playbook.md`、`docs/testing-progress.md`。
> 本会话只负责 **<模块名>**（Phase <X>）。范围限定在 `Ohana/Features/<模块名>`（或对应地基层目录），不许越界修其他模块。
> 先把 `docs/testing-progress.md` 中该模块状态改为 🟡 并填开工日期，然后从六步循环第 1 步开始：只分析，不修改。

收工协议（缺一项视为未完成）：
1. `scripts/module-exit-gate.sh` 通过（贴输出摘要）。
2. 按 Conventional Commit 提交，scope 用模块名。
3. 更新 `docs/testing-progress.md`：状态 🟢、门禁 commit 哈希、余留项指针、给下一个会话的交接备注。
4. 未修项写入 `docs/task-follow-ups.md`。

### 总览会话（Orchestrator）

总览会话**不改任何业务代码**，只做调度、对账、抽查。需要时才开（建议每完成 2~3 个模块开一次，Phase 8/9 必须由它主持）。Boot prompt：

> 读 `docs/ai-module-test-playbook.md` 和 `docs/testing-progress.md`，用 `git log --oneline -20` 与总账对账。你是总览会话，不修改业务代码。请：
> 1. 报告当前阶段进度、与总账不一致的地方（有 commit 没登记、有登记没 commit）。
> 2. 抽查最近完成的模块：重跑 `scripts/module-exit-gate.sh` 验证门禁仍然绿；抽看该模块门禁 commit 的 diff 是否与其交接备注/清单对应。
> 3. 检查 `docs/task-follow-ups.md` 余留项有没有升级为阻塞的。
> 4. 给出下一个模块的开工 boot prompt，并在总账「对账日志」追加一行。

### 并行会话规则

默认串行。确需并行时遵守 `AGENTS.md`：每个并行模块用独立 worktree（`git worktree add ../Ohana-<模块> -b codex/<模块>`），两个会话绝不共用一个 worktree；并行模块必须无共享文件交集（例如 Phase 7 的两个互不相关的小模块），地基层（Phase 1~4）一律串行。

---

## 二、角色分工

| 谁 | 负责什么 |
|---|---|
| 模块会话 AI | 静态分析、跑审计、写/跑测试、修复、生成人工验收清单、跑退出门禁 |
| 总览会话 AI | 调度、对账、抽查复验、主持 Phase 8/9 |
| 你 | 圈定修复范围、模拟器/真机人工验收、产品判断、commit 确认、App Store Connect 操作 |

AI 不可替代你的部分：真机手感、Apple 账号操作（证书/截图/审核答复）、"这个功能对用户是否成立"的判断。

## 三、工具箱与模块退出门禁

| 命令 | 用途 |
|---|---|
| `scripts/module-exit-gate.sh` | **模块退出门禁**：changed 审计 + 本地化 parity + 全量单测，一条命令 |
| `scripts/module-exit-gate.sh --full` | **阶段边界门禁**：全仓 `--all` 审计 + 架构边界 + 全量单测 |
| `scripts/dev-check-changed.sh` | 改动文件的廉价首检 |
| `scripts/build-debug-fast.sh` | 快速 Debug 构建（iPhone 17 模拟器） |
| `scripts/test-simulator.sh -only-testing:OhanaTests/XxxTests` | 修复迭代中的定向测试 |
| `scripts/audit-*.sh` | 各专项审计（ui-v4 / accessibility / smoothness / runtime / localization / architecture） |
| `scripts/release-hardening-check.sh` | 上架前总检 |

门禁使用时机：
- **每个模块收工前**：`scripts/module-exit-gate.sh`（含全量单测——这保证"每个模块完成后，app 自己跑一遍测试"）。
- **每个 Phase 结束、进入下一 Phase 前**：`scripts/module-exit-gate.sh --full`，由总览会话执行。
- 修复迭代过程中用定向测试加速，门禁只在收工时跑（全量测试贵，不当心跳用）。

规则：AI 报告"已验证"必须附命令和输出摘要。没有输出的"已验证"一律不算数。

---

## 四、通用模块循环（模块会话内走六步）

### 第 1 步：双轨分析（只分析，不修改）

分析分两轨：**1a 规则合规体检**（代码形态是否合规）和 **1b 业务逻辑重建**（业务意图是否正确）。脚本只能查 1a；过去多轮人工检查反复发现的问题（重复奖励、共享状态错乱、逻辑不自洽）属于 1b，必须显式做。

**Prompt 模板（1a 合规体检）：**

> 对 `Ohana/Features/<模块名>` 做全面体检，**只分析，不要改任何代码**。对照 `AGENTS.md` 逐项检查：
> 1. 架构边界：View 是否直接写 SwiftData、直接改 coconutBalance、绕过 domain service；可复用组件是否持有 ModelContext 或广播式 @Query。
> 2. 流畅性法则：用户首帧是否只做视觉状态变更；隐藏面是否真正卸载；装饰性循环是否经 AppWorkloadPolicy 管控；`.task(id:)` 依赖是否廉价。
> 3. 本地化：中英文案是否齐全；是否有 `appLanguage == "zh" ?` 三元表达式；日期/数字是否用本地化 helper。
> 4. 跑 `scripts/audit-ui-v4.sh Ohana/Features/<模块名>`、`scripts/audit-accessibility.sh Ohana/Features/<模块名>`、`scripts/audit-smoothness-risk.sh --changed`，附输出。
> 5. 测试覆盖缺口：该模块的服务/命令/读模型在 `OhanaTests/` 里有没有对应测试。
>
> 输出分级清单：**P0**（崩溃、数据丢失、架构违规、隐私泄漏）、**P1**（功能缺陷、性能违规、本地化缺失）、**P2**（体验瑕疵、规范偏差）。每条带 `文件:行号` 和证据，不许凭印象。

**Prompt 模板（1b 业务逻辑重建）：**

> 现在做业务逻辑审查。**只读代码，从实现反推**本模块的全部业务规则，写成 `docs/specs/<模块>-logic.md`，包含：
> 1. **业务不变量**：用"任何情况下都成立"的句式列出（例：一次喂食事件最多产生一次椰子奖励；删除宠物后其所有喂食记录进入 tombstone 状态且不再参与统计）。
> 2. **状态机**：模块内有生命周期的对象（会话、任务、订单式流程）画出状态与迁移，标出代码里**到不了或出不去**的状态。
> 3. **边界与冲突**：多成员/多宠物/多设备并发操作同一数据时代码现在的实际行为；时区/跨午夜/系统时间回拨下的实际行为。
> 4. **可疑清单**：反推过程中发现的逻辑矛盾、二义性、和常识相悖的行为——明确写"代码现在是 X，我怀疑意图是 Y"。
>
> 注意：写"代码实际做什么"，不是"代码应该做什么"。每条规则标注来源 `文件:行号`。

然后**你逐条确认**这份规则书：意图对的打钩；与产品意图不符的就是 bug，并入 P0/P1 清单。确认过的规则书就是该模块的逻辑基准——复审、回归、未来加功能都对着它检查。

**验收标准：** 每条问题/规则有 file:line；审计输出已附；规则书经你逐条确认；1b 发现的意图分歧已并入分级清单；`git status --short` 确认 AI 没动文件（规则书除外）。

### 第 2 步：你来圈定修复范围（人工决策点）

**Prompt 模板：**

> 本轮只修 P0 全部 + P1 的第 X、Y 条。P2 不修，按格式记入 `docs/task-follow-ups.md`。
> 动手前先逐条报修复方案和影响面（动哪些文件、是否跨模块、是否触碰 SwiftData schema），等我确认。

**注意：** 一轮 3~5 条为宜；触碰 schema/路由/奖励管线的项单独成轮。

### 第 3 步：修复（先红后绿）

**Prompt 模板：**

> 按确认的方案修复。每个行为型 bug：先写能复现它的 Swift Testing 测试（in-memory SwiftData），确认是红的，再修到绿。
> 外科手术式改动：不重构无关代码、不改无关格式。每修完一条用 `git diff --stat` 报改动面。

**验收标准：** P0/P1 各有"先红后绿"测试（纯视觉瑕疵除外）；diff 每一行能对应清单某一条。Review 时**先看测试 diff 再看实现 diff**。

### 第 4 步：补测试覆盖

**Prompt 模板：**

> 为本模块核心服务/命令/读模型补 Swift Testing 单测（in-memory SwiftData），至少覆盖：空数据、密集数据、删除/隐私边界、失败写入。涉及奖励/提醒/任务联动的，验证"写一个业务事实后派生状态被正确同步"。
> 另外：把 `docs/specs/<模块>-logic.md` 里**每条已确认的业务不变量**固化为一个测试，测试注释引用规则编号。
> 命名描述行为。跑 `scripts/test-simulator.sh -only-testing:OhanaTests/<测试类>` 到全绿，贴输出。

**验收标准：** 模块每个 service / command executor / snapshot builder 至少一个测试文件；规则书每条不变量有对应测试（确实不可单测的标注原因）；不刷凑数测试。

这是让问题池收敛的关键：**每个发现都变成测试 + 规则书条目**，下一轮审查就不会重新发现同一类问题，而是只能发现新问题——直到发现不了为止。

### 第 5 步：模块退出门禁（自动）

> 跑 `scripts/module-exit-gate.sh`，贴完整输出。任何 FAIL：修掉后重跑整个门禁。需要豁免注释（`// ui-v4: allow` 等）的，逐条向我申请，不许自行添加。

**验收标准：** 门禁输出 `RESULT: PASS`。门禁包含全量单测——模块改动若打挂了其他模块的测试，在这里暴露，必须修复或按"外部阻塞"上报，不许绕过。

### 第 6 步：人工验收 + 提交 + 更新总账

**Prompt 模板：**

> 给我本模块的人工验收清单：5~10 条最重要用户路径，每条【入口 → 操作 → 预期】，包含适用的边界场景（空数据、密集数据、德语长文本、Reduce Motion、低电量、杀进程重进）。然后 `scripts/build-debug-fast.sh` 构建启动模拟器，等我逐条过。

通过后：

> 验收通过。按 Conventional Commit 提交（scope 用模块名）。然后更新 `docs/testing-progress.md`（状态 🟢、门禁 commit、余留指针、交接备注），余留项写入 `docs/task-follow-ups.md`。

### 模块成熟度准则：对抗性复审（🟢 → 🏁）

🟢 只代表"本轮发现的问题修完且门禁绿"，**不代表成熟**。历史经验：每个全新会话都能在同一模块查出新问题——把这个现象变成流程武器：

- 模块 🟢 之后，**开一个全新会话**（零历史上下文）做对抗性复审。复审会话不读修复会话的清单，只读规则书和代码，避免视角被污染。
- **复审 Prompt 模板：**

  > 读 `AGENTS.md`、`docs/ai-module-test-playbook.md`、`docs/specs/<模块>-logic.md`。你是对抗性审查者，目标是**推翻**这个模块：在 `Ohana/Features/<模块名>` 里找出业务逻辑错误、规则书与代码的不一致、并发/时序漏洞、多成员多宠物边界错误、数据迁移隐患。假设之前的会话有遗漏，专挑没人测过的路径。输出 P0/P1/P2 清单，每条带 `文件:行号` 和复现思路。**只分析不修改。**

- **成熟判定：复审零 P0/P1 → 模块标 🏁（成熟）**。查出 P0/P1 → 回到六步循环修复，修完再换新会话复审。每轮发现都进规则书和测试，所以轮次是收敛的，通常 1~2 轮即净。
- **衔接规则**：在"业务逻辑重建（1b）"加入流程之前已 🟢 的模块没有规则书。其复审会话先执行 1b（从代码反推规则书、经你确认），再做对抗审查——一次会话完成补课和复审。
- P2 不阻塞 🏁，记入 task-follow-ups。
- 复审结论（轮次、最后一轮发现数）记入总账交接备注。

这是对"能不能保证成熟"最诚实的回答：无法证明没有 bug，但可以**测量收敛**——当带着敌意的全新视角也查不出实质问题时，模块才算成熟。核心模块（Domain、Economy、Feeding、Members、Home）必须 🏁 才能进 Phase 8；外围小模块 🟢 即可。

---

## 五、分阶段计划与各阶段专属要点

### Phase 0：基线收尾 ✅ 已完成

2026-06-12 已提交（`ff7ac89f`），工作区干净。

### Phase 1：`Ohana/Models`（SwiftData 模型层）

**专属检查点：** 当前 `ArkSchemaV*`（见 `SharedModelContainer.swift`）与迁移计划一致；字段默认值轻量迁移友好；`ArkMigrationPlan.stages` 只在真有自定义迁移时非空。
**专属验收：** in-memory 迁移兼容测试（旧 schema 数据 → 新 schema 打开不丢）。
**注意：** 改字段必须升版 schema，绝不原地改现有版本。模型层修完冻结——后续模块需要改模型时回到这里走完整流程。

### Phase 2：`Ohana/Domain`（服务/命令/事件/经济）

**专属检查点：** 每个用户动作"写一个业务事实一次"，奖励只走 `CoconutEconomyService` / `QuestManager` 管线；删除/纪念模式/隐私过滤边界；服务不 import SwiftUI。
**专属验收：** 核心服务每个有行为测试；`CoconutEconomySimulationTests` 全绿。
**注意：** Domain 影响全 app，本阶段每轮修复后跑全量测试（门禁本来就含全量，迭代中也别只跑定向）。

### Phase 3：`Ohana/Shared`（设计系统/组件/工具）

**专属检查点：** 硬编码值 vs `ui规范.selection.json` token；可复用组件不持有 ModelContext/@Query/定时器；`OhanaTextField`、`OhanaRadius`、`OhanaSheetDetents` 使用一致。
**专属验收：** 每个改动的共享组件列出全部调用方（`rg`），抽查至少两个使用页面目检无回归。

### Phase 4：`Ohana/App`（入口/路由容器/运行时策略）

**专属检查点：** 启动路径对照 `docs/startup-and-lazy-loading-policy.md`；路由全部类型化；`AppWorkloadPolicy` 是唯一预算仲裁者。
**注意：** 启动改动属 release-risk，按 `docs/release-quality-gates.md` 高风险流程出报告。

### Phase 5：Home + TodayFocus + QuickCare（枢纽）

**专属检查点：** 流畅性法则全套——首帧、frozen snapshot、卡片展开/FAB/sheet 的 hero 路径、隐藏卡不渲染；`HomeReadModelStore` 主线程聚合是棘轮债务，触碰时迁移 off-main。
**专属验收：** 密集数据下滚动与卡片展开手感真机过；交互重的修复按 AGENTS.md"严格流畅性合规模式"出合规矩阵。

### Phase 6：大模块（依次 Feeding → Members → Oasis → Settings → Health → Economy）

- **Feeding**：喂食 → 奖励 → 账本 → 成就跨功能链路，端到端核对一次记账只奖励一次。
- **Members**：隐私/锁定/纪念模式边界必测。
- **Oasis**：动画循环 AppWorkloadPolicy 管控；Reduce Motion 验收必做。
- **Settings**：数据导出/重置/隐私开关属 release-risk，删除路径必须有测试。
- **Economy**：余额不变量——任何路径不允许凭空加减椰子。

### Phase 7：中小模块批量

每个模块仍独立会话、独立清单、独立 commit；互不相关的模块可按「并行会话规则」用 worktree 并行。
**注意：** Walks 含后台定位——`audit-runtime-guardrails.sh` 必跑，验证只有进行中的遛狗保持后台定位。

### Phase 8：横向集成与全量回归（总览会话主持）

模块逐个绿不等于整体成立。总览会话 prompt：

> 模块级修复已全部完成（对照 `docs/testing-progress.md` 核实全部 🟢）。现在：
> 1. 跑 `scripts/module-exit-gate.sh --full`，贴完整摘要。
> 2. 给我跨功能端到端人工验收清单：新用户 onboarding 全流程；喂食/护理 → 奖励 → 账本 → 成就 → 通知链路；多成员家庭共享场景；9 种语言抽查关键页面；删除宠物/成员级联行为；杀进程恢复；云同步往返。
> 3. 列出 `docs/task-follow-ups.md` 中所有余留项，逐条判定：上架前必修 / 可放入首版后。

**验收：** `--full` 门禁全绿；端到端清单逐条人工通过（关键流程真机）；MetricKit 无新增 hang/crash 信号。

### Phase 8.5：演进就绪审查（总览会话主持，为未来版本铺路）

目的：确保现在的架构不会让未来的主流演进（联网同步、订阅付费、账户体系）变成重写。这是审查 + 少量铺垫，不是现在就实现这些功能。

**A. 单机/联网双模式就绪**（已在进行：`docs/cloud-sync-todo.md`、CloudSyncRecordState、V68 tombstone 都是这条线）

> 审查清单：
> 1. 所有业务事实写入是否都过 domain service 单一入口（这是同步拦截点，散写 = 未来漏同步）。
> 2. 每个可同步模型是否有稳定 UUID、修改时间戳、tombstone 删除（不许物理删除可同步记录）。
> 3. 每个模型写明冲突策略（last-write-wins 还是字段级合并），多设备时钟偏移下的行为。
> 4. **椰子经济必须可由事实流重放推导**：余额 = 账本事实的确定性折叠，不允许只存余额快照——否则双设备同步必出鬼账。验收方式：写一个"重放账本 == 当前余额"的不变量测试。
> 5. 断网状态下每个写路径的行为（本地排队？报错？），UI 是否有未同步标识的挂载点。

**B. 订阅（免费/付费）就绪**

> 审查清单：
> 1. 是否存在（或预留）**单一 entitlement 判定点**：全 app 只问一个 `EntitlementService` "能否使用 X"，禁止未来散落 `if isPremium` ——现在就检查有没有散落的功能开关可以收拢。
> 2. 免费层边界草案：哪些走 feature gate（整功能锁）、哪些走 limit gate（数量/历史长度上限）。Gate 点是否落在 typed route / domain service 层（可控），而不是 View 内部条件渲染（失控）。
> 3. Entitlement 检查必须本地缓存，不许在高频 UI 路径做网络/收据验证（违反流畅性法则）。
> 4. Apple 规则预检：椰子若未来可付费购买则属虚拟货币（不可过期、需披露）；付费墙必须有恢复购买入口；订阅需隐私政策 + 使用条款链接。**当前版本先确保经济系统与真钱完全隔离**，避免审核误判。
> 5. 付费墙作为 typed route 预留（哪怕现在指向空页面规划）。

**C. 其他主流演进的地基检查**

> 1. **账户体系**：当前无账户、数据在本地。预审"本地数据日后绑定账户"的迁移路径：用户身份是否已有稳定本地 ID 可未来映射。
> 2. **数据导出/删除**（GDPR/个保法）：导出是否覆盖全部用户数据；"删除一切"路径是否真删（结合 tombstone 策略想清楚导出含不含已删除项）。
> 3. **强制更新挂载点**：预留远端 minimum-version 检查的位置（哪怕现在不联网），避免未来出现无法淘汰的旧版本带着 bug 永远在线。
> 4. **评分引导 / What's New**：路由层预留，非必须。
>
> 每条结论三选一：✅ 已就绪 / 🔧 需小铺垫（列出最小改动）/ 📋 记录为未来版本设计约束（写入 `docs/task-follow-ups.md` 或专门的演进文档）。**不要现在过度建设**——本阶段产出是审查报告和少量低风险铺垫，不是新功能。

### Phase 9：上架准备（总览会话主持 + 人工）

**机器侧（AI 可做）：**
1. `scripts/release-hardening-check.sh` 全绿；对照 `docs/release-hardening-plan.md` Required Gates 与冻结范围逐条核对。
2. Release 配置 archive 一次，确认无 Release-only 编译错误。
3. `PrivacyInfo.xcprivacy` 与实际 API 使用核对（rg 扫描 required-reason API 用途并比对清单）。
4. `scripts/audit-localization-coverage.sh` 九语言 parity 零缺口；App Store 各语言元数据文案草拟。
5. 按 `docs/release-quality-gates.md` 模板出最终发布报告。

**人工侧（AI 不能替你做）：**
6. 真机主力机型完整过 Phase 8 清单；TestFlight 内测 1~2 周，看 MetricKit 崩溃率/卡顿。
7. App Store Connect：各尺寸截图、隐私问卷（必须与 PrivacyInfo 一致——不一致是高频被拒原因）、年龄分级、审核备注（写明权限用途，如定位用于遛狗记录）。
8. 提审。被拒不慌：拒绝信原文发给 AI 分析整改。

---

## 六、全程反模式清单（每个会话适用）

1. **一个会话一个模块。** 模块会话不许越界修别的模块；发现跨模块问题写交接备注，由总览会话调度。
2. **不接受没有输出的"已验证"。** 任何验证主张要命令 + 输出摘要。
3. **测试 diff 先于实现 diff 看。** 防止为绿而绿。
4. **豁免注释一律人工审批。** `// xxx: allow` 是审计后门。
5. **schema、启动、隐私、删除路径单独成轮单独 commit。**
6. **收工必更新 `docs/testing-progress.md`。** 没更新总账 = 没完成；总览会话对账时以 git history 为准纠偏。
7. **门禁不绿不提交，CI 红了停下。** 不绕过、不 force push。
8. **并行必用独立 worktree。** 两个会话共用一个 worktree 是事故之源。
