# 照护派生执行器架构改造规格（CareDerivationExecutor）

> 类型：**架构改造**，不是复审修复轮。终结 Economy/care-completion 连续 14 轮复审不收敛的根因。
> 验收方式换掉：从"下一轮复审零发现"改为"**在架构上构造不出绕过路径**"。构造不出即收敛，不需要第 15 轮复审。
> 总览会话 2026-06-14 产出，落在真实符号上。实现由专门架构改造会话执行，护栏三件套强制。

## 病理（为什么加 disposition 字段没用，14 轮没收敛）

现状（已核实）：
- `CareWriteDisposition{didWriteFact, allowsDerivedEffects}` 已存在于 `CareEventService` 的 `PlannedCareCompletionResult` / `CareRecordResult` / `PottyRecordResult`（`Ohana/Domain/Services/CareEventService.swift:68/81/193/226`）。
- **但发副作用的权力仍散落在每个 command/view**：12+ 文件各自持有 `DomainRevisionPublishing`，在**每条分支**手动写 `guard result.didWriteFact else { publishNoop(...); return }`（见 `QuickPottyCommandExecutor.swift:95/117/225/233`）。
- 这个手动 guard **只挡 revision**；reward / ledger / reminder rebuild / stock update / feedback / `SharedPetSelectionMemory` / `mainFoodKind`·`dailyPortionGrams` 修改 / Oasis 是**另外的代码行**，各自要再记得 guard。

**结论**：disposition 是"建议"，不是"约束"。违反点 = 调用栈所有分支 × 所有派生点 ≈ 数百个手动 guard，复审只能采样，数学上不收敛。**必须取消 command 独立触发副作用的能力，让"漏 guard"无法表达。**

## 目标：唯一派生通道 + 焊死所有旁路

把"焊死所有窗户、只留一个统一通风口"做成代码结构。

### 通风口：`CareDerivationExecutor`（新建，单一派生执行器）
- **输入**：一个 `CareWriteOutcome`——service 返回的 `disposition` + 所有派生所需 payload（petID、logID、reward 参数、reminder/stock 上下文、feedback 上下文、shared session 信息、factDate/operationDate）。
- **内部一处 gate**：`guard outcome.allowsDerivedEffects else { return .noop }`——**所有**派生副作用在这一个判定之后统一发出（revision、reward via `EconomyRewardDiscipline`、ledger、reminder、stock、feedback、Oasis、selection memory）。
- **离世只读分支也在这里一处判定**：`outcome.kind == .noOp` 且 note 标明 deceased target / deceased executor 时，事实、奖励、ledger、reminder、stock、feedback、Oasis、revision 全部跳过。2026-06-14 二态模型取消旧纪念历史事实分支：离世成员不再补写历史照护事实。

### 焊死窗户（关键的第三步，决定收不收敛）
command 层在结构上**失去**直接发副作用的能力：
- command 不再注入 / 持有 `DomainRevisionPublishing`、reminder builder、stock updater、feedback、`EconomyRewardDiscipline`、Oasis、selection-memory 写入器。command 只能：`let outcome = service.record(...); return executor.derive(outcome)`。
- 实现手段：**已定 capability token（方案 A）**，2026-06-14。
  - **理由**：Ohana 是单 app target（无 SPM module，已核实）。单 module 下 Swift `internal` 对整个 module 可见，方案 B 的访问控制无法把派生 API 真正收进 executor 可达范围，会退化成"靠 R6 审计兜底"——即靠记得抓的采样模式，正是 14 轮不收敛的根因。token 的 `private init` 不依赖 module 边界，编译期封死，是单 module 下唯一能让违反"写不出来"的手段。
  - **结构**：`CareDerivationToken` 的 `init` 为 `private`，只有 `CareDerivationExecutor` 能构造。派生闸门 API 要求 `token` 参数；command 无 token → 编译不过。
  - **范围控制（关键，避免改 135 个叶子）**：token **不**加在 135 个 `publishXxx` 叶子上，而是加在**每类副作用的唯一出口闸门**——约 7–8 个：revision publisher（`DomainRevisionPublishing`/`SharedDomainRevisionPublisher` 的获取）、reward（`EconomyRewardDiscipline` 入口）、reminder scheduler、stock writer、feedback emitter、Oasis、selection-memory persist。command 失去这 7–8 个闸门的注入/构造能力即焊死全部窗户。
  - **R6 审计降为兜底**：主防线是 token 编译期封锁；R6 只防"新增了未加 token 的闸门"这类回归。
- **审计规则 R6（新增，扩展 `audit-economy-boundaries.sh`）**：command/view 文件出现直接 `publish` / `publishNoop` / reminder build / stock update / care feedback / `EconomyRewardDiscipline.*` 调用 = 违规。配 allowlisted-内 bad fixture。**注意 R6 是兜底，主防线是结构让它编译不过。**

## 要收进 executor 的完整派生清单（来自 14 轮的全部副作用）

| 派生 | 当前散落处 | 14 轮对应问题 |
|---|---|---|
| revision publish / noop | 12+ command 各自 | 013/014/003/004/007 |
| reward（按家族） | `EconomyRewardDiscipline` 已收口，但 command 仍可裸调 | 011/012/014 |
| ledger | walk 单宠漏写、shared 不一致 | 015 |
| reminder rebuild | manual feed no-op 仍 rebuild | 013/014 |
| stock（mainFoodKind/dailyPortionGrams） | feed no-op 仍改默认 | 013/006 |
| success feedback / 返回值 | no-op 仍返回 success/detached log | 002/003/014/007 |
| `SharedPetSelectionMemory` | potty no-op 仍保存 | 004 |
| shared session | source 未 gate、hygiene 无 sharedSessionId | 001 |
| Oasis | 历史/no-op 仍触发 | 007 |
| budget/cooldown 结算日 | 历史 occurrence 用 fact day | 005/006 |

executor 用一个 `allowsDerivedEffects` + `kind`（active / noop）统一裁决全部，**operationDate vs factDate 也在 executor 一处分离**（active 历史事实用历史日、budget/cooldown/reward 用操作日，解决 005/006）。离世成员不进入 historical fact-only：其结果是完整 no-op。

## 护栏三件套（架构改造，强制且严格）

1. **表征测试先行**：为**每个 command 的正常成功路径**写"锁行为"测试（写了哪些事实/派生、给谁发奖、什么 feedback），全绿后才动结构。这是大改不改坏的唯一安全网。
2. **expand–contract 分批**：不要一次改完 12+ command。按 command 簇分批（先 QuickCare 一簇 → Feeding → Calendar/通知 → shared → Health/Dashboard）。每批：executor 先并行可用 → 切换该簇 command → 门禁绿 → 删该簇旧 publishing 依赖。每批独立可回滚。
3. **重构 commit 与行为 commit 分离**：路由迁移（行为等价）与真实行为修正（先红后绿）严格分开。

## 验收（不再用复审）

- **结构判据**：尝试在任一 command 里直接发一个派生副作用而不经 executor——**编译不过 或 R6 拦截**。构造不出绕过 = 收敛。
- 全部表征测试绿（行为等价）；14 轮清单里每类问题有对应测试锁死。
- `scripts/module-exit-gate.sh` PASS，CI 绿。
- 完成后 **一次** 全新纯复审确认零 P0/P1 → Economy 标 🏁。**这是最后一次复审**——若架构对，它必然零发现；若它还能找到绕过，说明窗户没焊死，回架构层而不是再开修复轮。

## 风险

- 跨文件大改（12+ command + 派生子系统）。风险靠表征测试 + 分批 expand-contract 控制，不靠缩小范围。
- 若某派生确实需要 command 侧上下文，作为 `CareWriteOutcome` 的 payload 传入 executor，**不要**因此给 command 开后门。
- 这是 Phase 7 护理模块（PetCare/CatCare/Hygiene/Medication）的共同地基，做完它们直接继承，不必各自再踩 disposition。
