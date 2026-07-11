# 复发问题机械化审计规格（recurring-findings audit）

> 目的：把对抗复审反复发现的 4 类业务逻辑问题，从"每个模块靠新会话人工复审才发现"变成"门禁当场拦截"。
> 来源证据：Economy 复审 7 条 P1、RecycleBin 复审 4 条 P1，归纳出 4 类复发根因。
> 交付标准：新增审计脚本进 `module-exit-gate.sh`，每条规则配 bad/good fixture（遵守 AGENTS.md「规则不可静默死亡」原则），CI 全绿。

## 角色边界

本规格由总览会话产出；**审计脚本的实现由一个专门的建设会话执行**（涉及真实代码模式扫描、误报调优、fixture，属于完整任务而非 orchestrator 内联）。规格落在真实符号上，session 不必从零摸索。

## 四类复发模式 → 审计规则

### R1 钱包写入只能在管线内（G2）
- **要抓**：`coconutBalance` 的赋值写入（`+=` / `-=` / `=`）出现在**奖励管线白名单之外**的文件，尤其 View 层。
- **已知活样本**（开工先核实是读/比较还是写）：`Ohana/Features/Home/Views/FocusHomeAuxiliaryViews.swift`、`FocusHomeHeaderView.swift`、`Ohana/Features/Achievements/Views/AchievementWallContentView+Progress.swift`。
- **白名单**（允许写入的管线归属文件）：`Ohana/Domain/Economy/CoconutWalletService.swift`、`CoconutWalletService+DeveloperOverride.swift`、新根因边界 `CoconutWalletMutationWriter` / `CoconutWalletFundingPlanner`、数据迁移/备份解码（`DataBackupManager+Decode.swift`）、模型定义本身（`Pet.swift` / `Human.swift` 的属性声明）。
- **必须排除误报**：`coconutBalance ==` / `>=` / `<=`（比较）、`let x = pet.coconutBalance`（读取）。正则要精确匹配赋值，不匹配比较与读取。
- **违规处置**：`// economy-boundary: allow <reason>` 需人工批准（同其他豁免）。

### R2 奖励归属按 executor，岛屿赠礼须显式批准（D3/G2）
- **要抓**：调用奖励发放 API（`awardAction` / `addCoconuts` / `batchAward` / `award` 等，符号见 `QuestManager+Awards`、`QuestManager+LegacyWallet`、`RewardEconomyCommands`、`StreakRewardManager`）时，actor 归属硬编码为 `system` / `system:legacy` / nil-fallback-to-system，或未由产品规则批准却写入 `system:island` 的路径。
- **依据**：有成员归属的奖励按明确 executor，缺失 actor 时归属可写 active Human；`system:legacy` 仅用于迁移兼容。只有 `product-foundation.md` / `Economy-logic.md` 明确批准的无成员岛屿赠礼（当前为 D17 启动赠礼）可写 `system:island`。
- **范围**：app 业务代码中任何**新增**对 system 钱包的写入都要有可追踪的产品规则与测试。

### R3 派生状态生命周期完整（D8/G5）
- **要抓**：删除/恢复路径是否成对——有删除写 tombstone 的地方，是否有对应的恢复重建（提醒重排、级联子记录 tombstone）。这条难纯静态抓全，**降级为 checklist 审计**：扫描含 `tombstone` / `isDeleted` / `recycl` 的文件，若同文件/同服务缺少 `reschedule` / `restore` / 级联处理的对称符号，标 warning 供人工确认。
- **依据**：RecycleBin 复审 4 条 P1 全是生命周期不对称（到期、恢复通知、级联 purge、直删 tombstone）。

### R4 关键边界在服务层硬门，不是 UI 软门（架构边界）
- **要抓**：功能门判定（`OnlineFeatureGate`、`PlantFeatureGate`、冻结钱包判定、回收/离世只读判定）只出现在 View 的 `if` 条件、却不在对应 domain service 入口处复核的路径。
- **依据**：Economy「兑换服务层硬门」、RecycleBin「30 天到期服务层硬边界」都是把 UI 软门提升为服务层硬门的修复。
- **实现思路**：列出已确立的服务层门判定符号，审计要求这些判定在 service 层至少出现一次（缺失=只有 UI 门=warning）。

## 集成

1. 新建 `scripts/audit-economy-boundaries.sh`（R1+R2+R4 的经济/边界部分）；R3 可并入 `audit-architecture-boundaries.sh` 或独立 `audit-derived-state-lifecycle.sh`。
2. 支持 `--changed` 与 `--all`，进 `module-exit-gate.sh`（changed 进模块门禁，all 进 `--full` 阶段门禁）。
3. 每条规则在 `scripts/tests/fixtures/` 加 bad/good 样本对，纳入 `run-audit-fixture-tests.sh` 的自检。
4. **先在全仓 `--all` 跑一遍，把现存违规登记为棘轮基线**（参照 full-scope-audit-baseline.json 模式）：存量是债、不是新规则的拦截对象；新代码零容忍。这样不会因为 Home View 里已有的 `coconutBalance` 写入而卡住所有模块。

## 验收

- 4 类规则各有 fixture 自检通过；
- 全仓基线建立，存量违规登记为债（带偿还指针，多数应在对应模块的下一轮复审修复轮清掉）；
- `module-exit-gate.sh` 集成后对新改动生效；
- CI 全绿。
