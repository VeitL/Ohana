# Ohana AI 协作模块测试与修复手册

目标：按依赖顺序逐模块"分析 → 修复 → 补测试 → 门禁 → 人工验收 → 提交"，全部走完后进入上架准备。
本文档是跨会话的工作协议：每个新 AI 会话开始时，让 AI 先读本文档和 `AGENTS.md`，再开始当前模块的工作。

诚实声明：没有任何流程能"保证"Apple 审核通过。本手册保证的是可控部分——代码质量、测试覆盖、合规审计、发布材料齐备——把审核风险压到最低。

---

## 一、角色分工

| 谁 | 负责什么 |
|---|---|
| AI | 静态分析、跑审计脚本、写/跑测试、修复代码、生成人工验收清单 |
| 你 | 决定修什么不修什么、模拟器/真机人工验收、产品判断、最终 commit 确认、App Store Connect 操作 |

AI 不可替代你的部分：真机手感、Apple 账号操作（证书/截图/审核答复）、"这个功能对用户是否成立"的判断。

## 二、工具箱（AI 必须用机器证据说话）

| 命令 | 用途 |
|---|---|
| `scripts/dev-check-changed.sh` | 改动文件的廉价首检（格式 + 变更文件审计） |
| `scripts/build-debug-fast.sh` | 快速 Debug 构建（iPhone 17 模拟器） |
| `scripts/test-simulator.sh -only-testing:OhanaTests/XxxTests` | 跑定向测试 |
| `scripts/audit-ui-v4.sh <路径或 --changed>` | UI token 合规 |
| `scripts/audit-accessibility.sh <路径或 --changed>` | 无障碍合规 |
| `scripts/audit-smoothness-risk.sh` | 流畅性风险（主线程聚合、广播 @Query 等） |
| `scripts/audit-runtime-guardrails.sh` | 定时器/定位/循环动画守门 |
| `scripts/audit-localization-coverage.sh` | 九语言 key 对齐 |
| `scripts/audit-architecture-boundaries.sh` | 分层边界 |
| `scripts/release-hardening-check.sh` | 上架前总检 |

规则：AI 报告"已验证"时必须附命令和输出摘要。没有输出的"已验证"一律不算数。

---

## 三、通用模块循环（每个模块走六步）

### 第 1 步：只分析，不修改

**Prompt 模板：**

> 请先读 `AGENTS.md` 和 `docs/ai-module-test-playbook.md`。然后对 `Ohana/Features/<模块名>` 做一次全面体检，**只分析，不要改任何代码**。对照规则逐项检查：
> 1. 架构边界：View 是否直接写 SwiftData、直接改 coconutBalance、绕过 domain service；可复用组件是否持有 ModelContext 或广播式 @Query。
> 2. 流畅性法则：用户首帧是否只做视觉状态变更；隐藏面是否真正卸载；是否有装饰性循环未经 AppWorkloadPolicy 管控；`.task(id:)` 依赖是否廉价。
> 3. 本地化：中英文案是否齐全；是否有 `appLanguage == "zh" ?` 三元表达式；日期/数字是否用本地化 helper。
> 4. 跑 `scripts/audit-ui-v4.sh Ohana/Features/<模块名>`、`scripts/audit-accessibility.sh Ohana/Features/<模块名>`、`scripts/audit-smoothness-risk.sh`，附输出。
> 5. 测试覆盖缺口：该模块的服务/命令/读模型在 `OhanaTests/` 里有没有对应测试。
>
> 输出一份分级清单：**P0**（崩溃、数据丢失、架构违规、隐私泄漏）、**P1**(功能缺陷、性能违规、本地化缺失)、**P2**(体验瑕疵、规范偏差)。每条必须带 `文件:行号` 和证据，不许凭印象。

**验收标准：** 每条问题有 file:line；分级明确；审计脚本输出已附上；AI 没有改任何文件（用 `git status --short` 验证）。

**注意事项：**
- "只分析不修改"必须写进 prompt，否则 AI 会顺手改代码污染基线。
- 分析报告先存档（可以让 AI 写到 `docs/planning/` 或会话里留存），修完后对照销项。

### 第 2 步：你来圈定修复范围（人工决策点）

**Prompt 模板：**

> 本轮只修上面清单里的 P0 全部 + P1 的第 X、Y 条。P2 不修，把它们按格式记入 `docs/task-follow-ups.md`。
> 开始改之前，先逐条告诉我修复方案和影响面（会动哪些文件、是否跨出本模块、是否触碰 SwiftData schema），等我确认后再动手。

**验收标准：** 修复方案不跨模块边界；触碰 schema/路由/奖励管线的项被明确标出。

**注意事项：**
- 不要让 AI 一轮修十几条——diff 大了你 review 不动，出问题也没法定位。一轮 3~5 条为宜。
- 凡是涉及 SwiftData schema 的修复，单独成轮、单独 commit（要走 ArkSchemaV* 升版流程）。

### 第 3 步：修复（先写复现测试，再修）

**Prompt 模板：**

> 按确认的方案修复。对每个行为型 bug：先写一个能复现它的 Swift Testing 测试（in-memory SwiftData 容器），确认测试是红的，再修代码让它变绿。
> 外科手术式改动：不要重构无关代码、不要改无关格式、不要"顺手优化"。每改完一条，用 `git diff --stat` 给我看改动面。

**验收标准：** 每条 P0/P1 对应"先红后绿"的测试（纯 UI 瑕疵除外）；`git diff` 里每一行都能对应到清单上的某一条。

**注意事项：**
- 警惕 AI 为了让测试变绿而放宽断言或改测试——review 时先看测试 diff 再看实现 diff。
- AI 报告"修好了"但没贴测试输出 → 要求重跑并贴输出。

### 第 4 步：补测试覆盖

**Prompt 模板：**

> 为本模块的核心服务/命令/读模型补单元测试，用 Swift Testing（`@Test` + `#expect`）和 in-memory SwiftData 容器。至少覆盖：空数据、密集数据、删除/隐私边界、失败写入路径。涉及奖励/提醒/任务联动的服务，要验证"写一个业务事实后派生状态被正确同步"。
> 测试命名描述行为（如 `feedCommandAwardsCoconutOncePerEvent`）。跑 `scripts/test-simulator.sh -only-testing:OhanaTests/<新测试类>` 直到全绿，贴输出。

**验收标准：** 模块的每个 domain service / command executor / snapshot builder 至少有一个测试文件；新旧测试全绿。

**注意事项：**
- 优先测业务事实和不变量，不要让 AI 刷"getter/setter 式"的凑数测试。
- UI 视图本身不强求单测；路由映射、读模型聚合必须测。

### 第 5 步：机器门禁

**Prompt 模板：**

> 跑完整门禁并贴每条输出：
> 1. `scripts/dev-check-changed.sh`
> 2. `scripts/audit-ui-v4.sh --changed`、`scripts/audit-accessibility.sh --changed`
> 3. 涉及定时器/动画/定位时：`scripts/audit-runtime-guardrails.sh`
> 4. 涉及文案时：`scripts/audit-localization-coverage.sh`
> 5. `scripts/test-simulator.sh`（本模块相关测试）
> 有任何 warning：修掉，或逐条向我申请 `// ui-v4: allow` 类豁免——不许自行添加豁免注释。

**验收标准：** 全部脚本零新增 warning；豁免注释逐条经你批准。

**注意事项：**
- 豁免注释（`// runtime-guardrail: allow` 等）是后门，必须人工把关，否则审计会被慢慢掏空。
- 纯文案/纯视觉改动按 AGENTS.md 可跳过构建，但审计脚本不能跳。

### 第 6 步：人工验收 + 提交

**Prompt 模板（让 AI 给你生成验收清单）：**

> 给我一份本模块的人工验收清单：5~10 条最重要的用户路径，每条写清【入口 → 操作步骤 → 预期结果】。必须包含这些边界场景中适用的：空数据、密集数据、德语长文本、日语、Reduce Motion 开启、低电量模式、杀进程重进。然后用 `scripts/build-debug-fast.sh` 构建并启动模拟器，等我逐条过。

你在模拟器上逐条过；UI 重的模块建议同时在真机过一遍手感（动画、滚动、键盘）。

**通过后提交：**

> 全部验收通过。按 Conventional Commit 提交，scope 用模块名（如 `fix(feeding): ...`），commit message 概括本轮修复的问题清单。

**验收标准：** 验收清单逐条通过；一个模块一个（或少数几个按主题拆分的）commit；CI 绿。

---

## 四、分阶段计划与各阶段专属要点

### Phase 0：基线收尾（最先做）

当前工作区有 13 个未提交文件（SharedCareSession / SharedPetActionRecorder 及测试，加 Expenses、Feeding、Home、Oasis、DailyStreak 零散改动）。

**Prompt：**
> 用 `git diff` 逐文件审查当前未提交的改动，判断它们属于哪个任务、是否完整、有没有半成品。跑 `scripts/dev-check-changed.sh` 和相关测试。如果改动完整就帮我按主题分组提交；如果有半成品，明确告诉我缺什么，不要擅自补完。

**验收：** 工作区干净（`git status` 无未提交改动），CI 绿。此后所有模块工作都基于干净基线。

### Phase 1：`Ohana/Models`（SwiftData 模型层）

**专属检查点：** 当前 schema 版本（`SharedModelContainer.swift` 里的 `ArkSchemaV*`）与迁移计划一致；所有字段有轻量迁移友好的默认值；`ArkMigrationPlan.stages` 只在真有自定义迁移逻辑时非空。
**专属验收：** 写一个 in-memory 迁移兼容测试（旧 schema 数据 → 新 schema 打开不丢数据）。
**注意：** 这一层的任何修复若需要改字段，必须升版 schema，绝不允许原地改 V67。模型层修完后冻结——后续模块发现需要改模型时回到这里走完整流程。

### Phase 2：`Ohana/Domain`（服务/命令/事件/经济）

**专属检查点：** 每个用户动作"写一个业务事实一次"，奖励只走 `CoconutEconomyService` / `QuestManager` 管线；删除/纪念模式/隐私过滤边界；服务不 import SwiftUI。
**专属验收：** 核心服务（CareEventService、FamilyTaskService、经济管线、提醒调度）每个都有行为测试；椰子经济跑 `CoconutEconomySimulationTests` 全绿。
**注意：** Domain 改动是全 app 影响面，每轮修复后跑全量测试而不只是定向测试。

### Phase 3：`Ohana/Shared`（设计系统/组件/工具）

**专属检查点：** 组件硬编码值 vs `ui规范.selection.json` token；可复用组件不持有 ModelContext/@Query/定时器；`OhanaTextField`、`OhanaRadius`、`OhanaSheetDetents` 的使用一致性。
**专属验收：** `scripts/audit-ui-v4.sh --all` 在 Shared 范围零新增；改动过的共享组件在至少两个使用方页面上人工目检无回归。
**注意：** 共享组件改一处全 app 变，每个组件改动都要列出"谁在用它"（`rg` 调用方）并抽查。

### Phase 4：`Ohana/App`(入口/路由容器/运行时策略)

**专属检查点：** 启动路径对照 `docs/startup-and-lazy-loading-policy.md`（只允许 shell、路由宿主、容器、本地化、token、运行时策略、迁移检查）；路由全部走类型化 route；`AppWorkloadPolicy` 是唯一预算仲裁者。
**专属验收：** 启动相关测试（AppLifecycleCoordinator、AppRouteCoordinator、AppWorkloadPolicy）全绿；冷启动到首帧无新增 feature 扫描。
**注意：** 启动改动属于 release-risk 级，按 `docs/release-quality-gates.md` 高风险流程出报告。

### Phase 5：Home + TodayFocus + QuickCare（枢纽）

**专属检查点：** 流畅性法则全套——首帧、frozen snapshot、卡片展开/FAB/sheet 的 hero 路径、隐藏卡不渲染；`HomeReadModelStore` 的主线程聚合是棘轮债务，触碰时迁移到 off-main。
**专属验收：** 人工验收必须含密集数据（多宠物多成员多记录）下的滚动和卡片展开手感，真机过一遍；交互重的修复按 AGENTS.md"严格流畅性合规模式"出合规矩阵。
**注意：** 这是用户停留最久的界面，宁可多花一轮也不要带病进入下一阶段。

### Phase 6：大模块（依次：Feeding → Members → Oasis → Settings → Health → Economy）

每个模块走标准六步循环。专属注意：
- **Feeding**：喂食 → 奖励 → 账本 → 成就的跨功能链路，验收时要端到端核对一次记账只奖励一次。
- **Members**：隐私/锁定/纪念模式边界场景必测。
- **Oasis**：动画循环和 AppWorkloadPolicy 管控重点；Reduce Motion 验收必做。
- **Settings**：数据导出/重置/隐私开关属 release-risk，删除路径必须有测试。
- **Economy**：余额不变量——任何路径都不允许凭空加减椰子。

### Phase 7：中小模块批量（Medication、Walks、FamilyTasks、Expenses、DashboardRecords、Calendar、其余）

可以两三个模块并一轮，但每个模块仍要独立的分析清单和 commit。
**注意：** Walks 含后台定位——`scripts/audit-runtime-guardrails.sh` 必跑，验证只有进行中的遛狗保持后台定位。

### Phase 8：横向集成与全量回归

模块逐个修完不等于整体成立。这一阶段做跨模块验证：

**Prompt：**
> 模块级修复已全部完成。现在做横向验证：
> 1. 跑全量测试 `scripts/test-simulator.sh`，贴完整摘要。
> 2. 跑全部 `--all` 审计（ui-v4、accessibility、smoothness、runtime、localization、architecture、release-data-safety），贴输出。
> 3. 给我一份跨功能端到端人工验收清单，覆盖：新用户 onboarding 全流程；喂食/护理 → 奖励 → 账本 → 成就 → 通知链路；多成员家庭共享场景；切换全部 9 种语言抽查关键页面；删除宠物/成员的级联行为；杀进程恢复。

**验收：** 全量测试与审计零失败；端到端清单逐条人工通过（关键流程真机过）；MetricKit 无新增 hang/crash 信号。

### Phase 9：上架准备

**机器侧（AI 可做）：**
1. `scripts/release-hardening-check.sh` 全绿；对照 `docs/release-hardening-plan.md` 的 Required Gates 与冻结范围逐条核对。
2. Release 配置构建验证（不是只有 Debug）：archive 一次确认无 Release-only 编译错误。
3. `PrivacyInfo.xcprivacy` 与实际 API 使用核对（让 AI rg 扫描 required-reason API 实际用途并比对清单）。
4. `scripts/audit-localization-coverage.sh` 九语言 parity 零缺口；App Store 各语言元数据文案草拟。
5. 按 `docs/release-quality-gates.md` 模板出最终发布报告。

**人工侧（AI 不能替你做）：**
6. 真机至少一台主力机型完整过 Phase 8 清单；建议 TestFlight 内测 1~2 周，观察 MetricKit 崩溃率/卡顿。
7. App Store Connect：截图（各尺寸）、隐私问卷（与 PrivacyInfo 一致！不一致是高频被拒原因）、年龄分级、审核备注（说明需要的权限用途，如定位用于遛狗记录）。
8. 提审。被拒不慌：把拒绝信原文发给 AI 分析对应整改。

---

## 五、全程反模式清单（每个会话都适用）

1. **不要一次扫多个模块。** 上下文一大，分析质量直线下降。一个会话一个模块。
2. **不要接受没有输出的"已验证"。** 任何验证主张都要命令 + 输出摘要。
3. **测试 diff 先于实现 diff 看。** 防止为绿而绿。
4. **豁免注释一律人工审批。** `// xxx: allow` 是审计后门。
5. **schema、启动、隐私、删除路径的改动单独成轮。** 这些是 release-risk，不和普通修复混在一个 commit。
6. **会话变长就重开。** 新会话第一句：「读 `AGENTS.md` 和 `docs/ai-module-test-playbook.md`，我们继续 Phase X 的 <模块>，上一轮进度是 …」。
7. **进度记录在 `docs/task-follow-ups.md`**，不要依赖会话记忆。
8. **CI 红了停下。** 不绕过、不 force push，先修 CI。
