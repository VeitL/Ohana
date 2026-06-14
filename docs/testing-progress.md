# 测试推进总账（跨会话唯一进度源）

> 工作协议见 `docs/ai-module-test-playbook.md`。任何会话开工前先读本文件；收工前**必须**更新本文件对应行，否则视为未完成。
> 状态图例：⬜ 未开始 ｜ 🔵 分析完成待修 ｜ 🟡 修复中 ｜ 🟢 已过门禁并提交 ｜ 🟢\* 已过门禁但带人工验收债（见 track list） ｜ 🏁 对抗复审通过（成熟） ｜ ⛔ 阻塞（备注写明阻塞原因）
> 🏁 准则见手册「模块成熟度准则」：核心模块（Domain、Economy、Feeding、Members、Home）必须 🏁 才能进 Phase 8；外围小模块 🟢 即可。

## 阶段总览

| Phase | 范围 | 状态 | 备注 |
|---|---|---|---|
| 0 | 基线收尾（提交未完成改动） | 🟢 | 已于 2026-06-12 提交（`ff7ac89f`）；后续模块工作可能使当前工作区非空 |
| 1 | `Ohana/Models` | 🟢 | 门禁通过并提交：`db44afe1`；P0 余留跨范围项 TFU-20260612-012 已由 Domain gate commit `304971af` 关闭，TFU-20260612-013 已由 `e16e6953` 关闭 |
| 2 | `Ohana/Domain` | 🟢 | 门禁通过并提交：`304971af`；P1 余留见 TFU-20260612-014 |
| 3 | `Ohana/Shared` | 🟢 | 门禁通过并提交：`fcf998088`；P1 余留见 TFU-20260612-015 |
| 4 | `Ohana/App` | 🟢 | 门禁通过并提交：`e48c13af7`；无 P1/P2 余留 |
| 5 | Home + TodayFocus + QuickCare | 🟢 | 门禁通过并提交：`b8e8710e`；TFU-20260612-015 已关闭，无 P1/P2 余留 |
| 6 | 大模块（Feeding/Members/Oasis/Settings/Health/Economy） | 🟢 | Feeding 门禁通过并提交：`b49134977`；Members 门禁通过并提交：`ead1e5fe4`；Oasis 门禁通过并提交：`87423afd8`；Settings/Health 门禁通过并提交：`5d4e71928`；Economy 原门禁：`662852a01`，复审修复轮门禁：`1679ddd66` |
| 6.5 | 宪法差距建设（联机门/删除模型/自动备份/植物门） | 🟢* | GAP-1、GAP-3~9 与 GAP-12 已过门禁并提交；GAP-2 用户可见回收站按 2026-06-14 产品决策退役，删除模型改为不可恢复物理删除 + 不可见 sync tombstone；*带验收债：人工/真机验收项见 `docs/planning/gap-acceptance-track-list.md`，必须在 🏁 复审与 Phase 9B 前清完 |
| 7 | 中小模块批量 | 🟡 | Walks 门禁通过（2026-06-13，`e0c1d69d3`）；按第一批高风险模块继续推进，注入复审模式预检清单 |
| 8 | 横向集成与全量回归 | ⬜ | 需总览会话主持 |
| 8.5 | 演进就绪审查（联网/订阅/账户地基） | ⬜ | 需总览会话主持；产出审查报告与少量铺垫，非新功能 |
| 9 | 上架工程（9A 前置/9B RC/9C 提审上线后） | ⬜ | 9A 前置项**现在就可并行启动**（开发者账号为最长前置）；详见手册 Phase 9 |

## 模块明细

| 模块 | Phase | 状态 | 开工日期 | 余留项（P1/P2 指针） | 门禁 commit | 交接备注 |
|---|---|---|---|---|---|---|
| Models | 1 | 🟢 | 2026-06-12 | TFU-20260612-012 已由 Domain gate commit `304971af` 关闭；TFU-20260612-013 已关闭 | `db44afe1` | V68 tombstone 默认值、fallback indicator、V67→V68 临时磁盘迁移测试已补并执行 |
| Domain | 2 | 🟢 | 2026-06-12 | TFU-20260614-016（本地 Human 删除后 retained active pet facts 仍保留 deleted executor id，首发可达 P1）；TFU-20260614-015（本地 Human 删除 shared-care child orphan P1 已本地修复）；TFU-20260614-014（CloudSync live apply deletion-wins / parent lifecycle / natural identity P1，首发不可达，推 1.x）；TFU-20260614-013 已本地修复；TFU-20260614-012/011/010/009 为前序修复记录；旧架构清理见 TFU-20260612-014 | `3aa7e464a` | 2026-06-14 TFU-013 修复后全新纯复审（Codex）发现 P0=0 / P1=3 / P2=0，不能 🏁。新 P1 指向同一根因：CloudSync live apply 缺少统一 deletion-wins、parent lifecycle 和 natural identity policy；live 远端记录可清掉本地删除 tombstone 并复活 Pet/Human，late child/fact 记录可在父成员删除后插入 orphan，GachaOwnedItem 可按随机 id 产生重复 ownership projection。已登记 TFU-20260614-014；Domain 保持 🟢。**2026-06-14 优先级纠偏（总览）**：TFU-014/012/011/010 的 remote/live apply、deletion-wins、natural-key merge 经核实**首发不可达**（`cloudKitDatabase: .none`，apply 靠 CloudKit 触发，单机跑不到），已移交 `docs/cloud-sync-todo.md`「CloudKit-Enable-Time Architecture」推 1.x，**不阻塞 Domain 首发 🏁**。Domain 首发 🏁 判据 = **首发可达面**（本地物理删除级联完整：Pet/Human 删除级联 wallet/ledger/shared/Gacha/Shop owned items；本地不变量：冻结门、executor 收口）零 P0/P1。2026-06-14 本地物理删除级联收口轮已补注册矩阵审计与入口族测试，`scripts/module-exit-gate.sh` PASS，commit `3aa7e464a` 已推送且 CI run `27510220670` 全绿；随后首发可达面纯复审（Codex，2026-06-14）发现 P0=0 / P1=1 / P2=0：删除唯一 shared-care executor human 会删除 session 但保留 active pet child `sharedSessionId` orphan。已登记 TFU-20260614-015；2026-06-14 no-CI 修复会话已本地补五类 shared-care child facts 红测并修绿，CI/最终纯复审按用户要求未执行；本轮首发可达面纯复审（Codex，2026-06-14，commit `3cc140333` 后）发现 P0=0 / P1=1 / P2=0：普通 retained active pet facts 删除 Human 后仍保留 deleted executor id 且 care ledger 被删/可被 backfill 重新写回 deleted actor。已登记 TFU-20260614-016；Domain 保持 🟢，不得 🏁。 |
| Shared | 3 | 🟢 | 2026-06-12 | P1 余留见 TFU-20260612-015 | `fcf998088` | 附件隐私清理器已改为 ImageIO 重编码，Shared smoothness 阻塞解除；QuickCare 阶段迁移 executor picker 的 Shared `@Query` |
| App | 4 | 🟢 | 2026-06-12 | 无 | `e48c13af7` | 启动/路由/运行时策略审计通过；隐私快照遮罩 a11y 与 shell 文案本地化已修复 |
| Home | 5 | 🟢 | 2026-06-12 | 无 | `b8e8710e` | Phase 5 审计与门禁通过；本轮未发现需修改的 Home P0/P1 项 |
| TodayFocus | 5 | 🟢 | 2026-06-12 | 无 | `b8e8710e` | Phase 5 审计与门禁通过；本轮未发现需修改的 TodayFocus P0/P1 项 |
| QuickCare | 5 | 🟢 | 2026-06-12 | 无 | `b8e8710e` | `ExecutorPickerBar` 的 SwiftData 查询已迁入 QuickCare feature 容器，Shared 只保留纯展示组件；空/多成员 picker smoke tests 已补 |
| Feeding | 6 | 🟢 | 2026-06-12 | 跨模块 read-model 余留见 TFU-20260612-006 | `b49134977` | CloudSync `Event` / `PetFoodRecord` 上传与 apply 支持已补；Feeding 计划、粮仓、断粮提醒、自动投喂日志会写入 dirty/tombstone；dashboard 内容 revision 与本地化已修复；模块门禁通过 |
| Members | 6 | 🟢 | 2026-06-12 | P1/P2 余留见 TFU-20260612-018~021 | `ead1e5fe4` | 2026-06-14 删除模型已改为不可恢复物理删除：Human/Pet/Plant 及相关 Event/Reminder/从属记录经 `PhysicalDeletionService` 写 sync tombstone 后删除；离世成员资料更新、首页显示开关、清空记录命令 no-op 且不发布假 revision；成员创建生日/到家日 Event 与 Reminder 写 sync metadata；RequiredHumanProfileView a11y 修复；真实 UI 抽查见统一 track list |
| Oasis | 6 | 🟢 | 2026-06-12 | 无 | `87423afd8` | 开工：2026-06-12；规则书见 `docs/specs/Oasis-logic.md`；当前主人钱包门、预算/冷却产出、一次性幂等奖励、休眠可唤回语义已落地；`scripts/module-exit-gate.sh` PASS；真实 UI 抽查见 `docs/planning/gap-acceptance-track-list.md#phase-6-oasis`；未改 schema / 路由 / 启动路径 / CloudKit |
| Settings | 6 | 🟢 | 2026-06-12 | P2 余留见 TFU-20260612-022 | `5d4e71928` | 规则书见 `docs/specs/Settings-logic.md`；开发/测试入口收进 Debug-only，通知开关接入 `NotificationDeliveryPolicy`，空 About 入口隐藏；目标测试、UI/a11y/smoothness/runtime 审计与 `scripts/module-exit-gate.sh` PASS；真实 UI / 真机通知抽查见统一 track list |
| Health | 6 | 🟢 | 2026-06-12 | 无 P1/P2 代码余留；真实 UI 抽查见统一 track list | `5d4e71928` | 规则书见 `docs/specs/Health-logic.md`；2026-06-14 删除模型已改为确认后物理删除 + sync tombstone，健康记录删除清理派生费用/日历事件/提醒/ledger，症状/发情记录不进入恢复态；已故宠物只读；schema 升至 `ArkSchemaV70` 且 legacy 字段仅为存储兼容；目标测试与 `scripts/module-exit-gate.sh` PASS；未启用 CloudKit、未改路由或启动路径 |
| Economy | 6 | 🏁 | 2026-06-14 | 无 P0/P1/P2 代码余留；真实 UI 抽查见统一 track list | `92133da2a` | 规则书见 `docs/specs/Economy-logic.md`；2026-06-14 care-derivation executor 架构会话已按产品主人 option A 收口：用户可见回收站和可恢复软删退役，删除走 `PhysicalDeletionService` 物理删除 + 不可见 sync tombstone，离世成员只读且照护写入/编辑/历史补记/派生 no-op；`CareFactWriteDisposition` 二态化，脏 executor id 不再丢 active target 事实；raw `DomainRevisionPublishing.publish` 加 token，care-family command/revision 路径消费 typed executor outcome；R5/derived lifecycle 审计和 fixture 已同步。最终 P1（Insurance expense fact 缺同边界 ledger）已由 `92133da2a` 修复：自动保费与报销统一进入 `ExpenseCommandService.recordPetExpense(... awardsReward: false)` 并补 `pet-expense-ledger-boundary` 审计。最终纯复审会话（Codex，2026-06-14，Insurance ledger 收口后全新纯复审）发现 P0=0 / P1=0 / P2=0；`scripts/module-exit-gate.sh` PASS（837 unit tests + 3 UI template tests），CI run `27505314629` 全绿（audits/lint/build-test）。legacy recycle 字段仅为既有 store compatibility 保留，活跃产品流不得读写。 |
| Medication | 7 | ⬜ | | | | |
| Walks | 7 | 🟢 | 2026-06-13 | 无 P1/P2 代码余留；真机定位 / 真实 UI 抽查见统一 track list | `e0c1d69d3` | 规则书见 `docs/specs/Walks-logic.md`；`WalkFeaturePolicy` 统一 active dog/lifecycle 判定，非狗 / 已离世宠物不可启动遛狗；删除后的 walk / poop marker 已物理移除且不作为产品可见状态；遛狗中便便写 `PetPottyLog` + `CareLedgerEvent` 并进入奖励管线；共享遛狗调用收进基础设施适配器；目标测试、changed gate 与 `scripts/module-exit-gate.sh` PASS；未改 schema / CloudKit / 启动路径 |
| FamilyTasks | 7 | ⬜ | | | | |
| Expenses | 7 | ⬜ | | | | |
| DashboardRecords | 7 | ⬜ | | 历史验证阻塞 TFU-20260612-013 已由 cross-scope repair 关闭 | | 接手时留意 `WeightHistoryView 2.swift` 曾误入仓库并阻塞 app target 编译 |
| Calendar | 7 | ⬜ | | | | |
| CrewRoster | 7 | ⬜ | | | | |
| Gacha | 7 | 🟢 | 2026-06-13 | 无 P1/P2 代码余留；真实 UI 抽查见统一 track list | `本次提交` | 与 Shop 合并一轮；规则书见 `docs/specs/GachaShop-logic.md`；Q1~Q8/Q11~Q13/Q15~Q16 选 A，Q9/Q10/Q14 选 B；大奖概率降至 2% 且奖额/id 保持 500🥥，留言概率补齐；抽取支持岛屿合资但当前主人仍拥有记录 / 奖励，冻结钱包硬拒绝；GachaOwnedItem / GachaDrawLog 已接入 CloudSync serializer/applier；目标测试、changed gate 与 `scripts/module-exit-gate.sh` PASS；schema 升至 `ArkSchemaV71`，未启用 CloudKit |
| Shop | 7 | 🟢 | 2026-06-13 | 无 P1/P2 代码余留；真机 App Icon / 真实 UI 抽查见统一 track list | `本次提交` | 与 Gacha 合并一轮；规则书见 `docs/specs/GachaShop-logic.md`；定价与隐藏汇率按规则书调整，Shop 购买支持岛屿合资；App Icon 改为先扣款后换图标，失败按出资人退款；非消耗品所有权迁至 `ShopPurchaseRecord`，旧 `purchasedShopItems` 启动迁移，备份恢复保留购买记录；购买履约收进 `ShopPurchaseFulfillmentService`，成员创建头像券复用 Shop/cofund/frozen 规则；ShopPurchaseRecord 已接入 CloudSync serializer/applier；目标测试、changed gate 与 `scripts/module-exit-gate.sh` PASS；schema 升至 `ArkSchemaV71`，未启用 CloudKit |
| Documents | 7 | ⬜ | | | | |
| Insurance | 7 | ⬜ | | | | |
| GrowthUnlock | 7 | ⬜ | | | | |
| Privacy | 7 | ⬜ | | | | |
| Achievements | 7 | ⬜ | | | | |
| Moments | 7 | ⬜ | | | | |
| Hygiene | 7 | ⬜ | | | | |
| HumanHealth | 7 | ⬜ | | | | |
| HumanNotes | 7 | ⬜ | | | | |
| Memorial | 7 | ⬜ | | | | |
| Milestones | 7 | ⬜ | | | | |
| Notifications | 7 | ⬜ | | | | |
| Onboarding | 7 | ⬜ | | | | |
| PetCare | 7 | ⬜ | | | | |
| PhotoAlbum | 7 | ⬜ | | | | |
| Plants | 7 | ⬜ | | | | |
| Security | 7 | ⬜ | | | | |
| Wishlist | 7 | ⬜ | | | | |
| Workouts | 7 | ⬜ | | | | |
| CareLedger | 7 | ⬜ | | | | |
| CatCare | 7 | ⬜ | | | | |
| FamilyReports | 7 | ⬜ | | | | |
| FunctionMenu | 7 | ⬜ | | | | |

> Economy architecture note (2026-06-14, Codex care-derivation executor
> architecture session, not a pure review):
> Product-owner option A is now the governing model: user-visible recycle bin
> and recoverable soft delete are retired; member deletion is irreversible
> physical delete with invisible sync tombstones, and deceased members are
> read-only/no-write. The care write disposition has been simplified to active
> write vs no-op, dirty executor ids no longer drop active-target facts, raw
> domain revision publishing is token-gated, and care-family command/revision
> paths consume typed executor outcomes. Legacy recycle fields remain only for
> store compatibility until a future schema retirement; active product flows must
> not read/write them. Validation for this architecture work includes
> `scripts/build-debug-fast.sh` PASS, targeted simulator suites PASS, economy
> and derived-state audits PASS with existing baselines only, fixture tests PASS,
> and `scripts/module-exit-gate.sh` PASS. Economy remains 🟢 and must not be marked 🏁 until a separate fresh pure
> adversarial review reports P0/P1=0.
>
> Economy final pure review note (2026-06-14, Codex final pure adversarial
> review after CI-green commit `c3c5e5f53`):
> P0=0 / P1=1 / P2=0. P1 remains TFU-20260614-006: Insurance policy auto
> payment schedule and claim reimbursement still insert `PetExpenseLog` without
> same-boundary `CareLedgerEvent` / expense-ledger discipline
> (`Ohana/Features/Insurance/InsuranceCommands.swift:164`,
> `Ohana/Features/Insurance/InsuranceCommands.swift:335`,
> `Ohana/Features/Insurance/InsuranceCommands.swift:384`), unlike
> `ExpenseCommandService.recordPetExpense` which writes both expense fact and
> ledger. Validation: CI run `27502634100` PASS (`audits`, `lint`,
> `build-test`), `scripts/audit-economy-boundaries.sh --all` PASS,
> `scripts/tests/run-audit-fixture-tests.sh` PASS,
> `scripts/audit-derived-state-lifecycle.sh --all` exit 0 with existing
> baseline warnings, and targeted simulator suites PASS (48 tests). Economy
> remains 🟢 and must not be marked 🏁.
>
> Economy current review note (2026-06-14, Codex fresh pure adversarial review):
> P0=0 / P1=3 / P2=1. P1 findings are tracked as TFU-20260614-004:
> QuickPotty detail still performs selection/settings/reminder/UI success effects
> before or without consuming command no-op for unknown shared potty, scoop, and
> full-change paths; `scripts/audit-economy-boundaries.sh --all` misses these
> QuickPotty result-consumption bad examples; clean-DerivedData targeted simulator
> build fails compiling `OhanaTests/HomeCommandExecutorTests.swift` because several
> tests use `executorHuman` without declaring/inserting the fixture. P2:
> `recordUnknownSharedPotty` still returns a detached fallback `PetPottyLog`
> instead of a typed shared result. Current inspection shows the prior TFU-003
> QuickFeed / QuickWater / shared expense revision / plural walk executor issues
> appear patched in this worktree, but this review still has P1. Validation:
> `scripts/audit-economy-boundaries.sh --all` PASS (792 files),
> `scripts/tests/run-audit-fixture-tests.sh` PASS, `git diff --check` PASS, clean
> DerivedData target suite FAIL at compile. Economy remains 🟢 and must not be
> marked 🏁.
>
> Economy previous review note (2026-06-14, Codex fresh pure adversarial review):
> P0=0 / P1=4 / P2=1. P1 findings are tracked as TFU-20260614-003:
> QuickFeed detail manual/treat and QuickWater detail planned/manual/water-change/
> filter paths still show success feedback after typed no-op results; Walk secondary
> `executorIds` are not validated with `EconomyWalletWritePolicy.canWrite`; shared
> expense no-op still publishes a success revision. P2: `recordUnknownSharedPotty`
> still returns a detached fallback `PetPottyLog` instead of a typed shared result.
> Validation run in this review: `scripts/audit-economy-boundaries.sh --all` PASS
> (792 files), `scripts/tests/run-audit-fixture-tests.sh` PASS, `git diff --check`
> PASS. Targeted simulator tests were attempted but did not reach xcodebuild because
> another `scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests`
> process held `.build/locks/test-main-b6cf423d5931-tests.lock`; the waiting process
> was cancelled with exit 130. Economy remains 🟢 and must not be marked 🏁.

> Economy current review note (2026-06-14, Codex fresh pure adversarial review):
> P0=0 / P1=2 / P2=0. P1 findings are tracked as TFU-20260614-001:
> shared-care sourcePet is not a hard lifecycle gate when explicit active targets
> are supplied, and TFU-016's shared hygiene sessions are not recognized by
> `SharedCareSessionMaintenance` delete/reconcile/ledger paths. Validation run in
> this review: `scripts/audit-economy-boundaries.sh --all` PASS (792 files),
> `scripts/tests/run-audit-fixture-tests.sh` PASS, and targeted simulator suite
> PASS (46 tests). Economy remains 🟢 and must not be marked 🏁 until a later
> fresh pure review finds P0/P1=0.
>
> Economy repair note (2026-06-14, Codex fix session for TFU-20260614-001):
> Shared-care sourcePet lifecycle is now a hard no-op gate even when explicit
> active targets are supplied, and shared hygiene sessions now participate in
> `SharedCareSessionMaintenance` reconcile/delete/primary/ledger paths. New
> tests cover shared source no-op across feed/water/litter/generic care/walk/
> unknown potty plus hygiene session reconcile, cascade delete, and primary-fact
> deletion. Validation passed: `QuestManagerBatchAwardTests` 9 tests, key
> Economy simulator suite 55 tests, `scripts/audit-economy-boundaries.sh --all`,
> `scripts/tests/run-audit-fixture-tests.sh`, `scripts/dev-check-changed.sh`
> (exit 0; derived-state lifecycle checklist warnings only), and
> `git diff --check`; `QuestManagerBatchAwardTests` was rerun after SwiftFormat
> and remained PASS. Economy remains 🟢; a separate fresh pure adversarial
> review is still required before 🏁.
>
> Economy current review note (2026-06-14, Codex fresh pure adversarial review
> round 1 after TFU-20260614-001 repair):
> P0=0 / P1=1 / P2=0. P1 is tracked as TFU-20260614-002: non-empty explicit
> executor ids that are invalid, missing, or already purged are still treated as
> writable by `CareFactWritePolicy.executorCannotWrite`, so fact/ledger/
> reminder/revision/Oasis derived writes can occur before reward owner resolution
> rejects the wallet reward. Validation run in this review: targeted simulator
> suite PASS (55 tests), `scripts/audit-economy-boundaries.sh --all` PASS
> (792 files), and `scripts/tests/run-audit-fixture-tests.sh` PASS. Why this
> escaped prior rounds: previous rules and tests modeled frozen executor as an
> existing Human with `hasPassedAway`/`trashedAt`, but did not include the
> post-purge stale active-human id state; G4.1/ECO-026 and the module playbook
> were updated to make unresolved explicit executor a hard no-op boundary.
> Economy remains 🟢 and must not be marked 🏁.
>
> Economy current review note (2026-06-14, Codex fresh pure adversarial review
> round 2 with TFU-20260614-002 still open):
> P0=0 / P1=1 / P2=1. P1 remains TFU-20260614-002: non-empty explicit
> executor ids that are invalid, missing, or already purged still pass
> `CareFactWritePolicy.executorCannotWrite` as writable at the fact layer. P2:
> `CareEventRecording.recordUnknownSharedPotty` / `CareEventService.recordUnknownSharedPotty`
> still return a detached `PetPottyLog` fallback instead of a typed
> `SharedPetActionResult`; current QuickCare executor prechecks prevent an active
> success leak, so this is not upgraded to P1 in this round. Validation:
> targeted simulator suite PASS (242 tests), `scripts/audit-economy-boundaries.sh --all`
> PASS (792 files), and `scripts/tests/run-audit-fixture-tests.sh` PASS. Economy
> remains 🟢 and must not be marked 🏁.
>
> Economy previous review note (2026-06-13, Codex fresh pure adversarial review):
> P0=0 / P1=1 / P2=1. P1 is tracked as TFU-20260613-015
> (`PetWalkingManager.stop` single-walk path writes `PetWalkLog` + wallet reward /
> budget usage but no walk `CareLedgerEvent`; shared walk does write walk ledger).
> Economy remains 🟢 and must not be marked 🏁 until a later fresh pure review finds
> P0/P1=0.
>
> Economy repair note (2026-06-13, Codex fix session): TFU-20260613-015 is fixed
> and closed locally. Validation passed:
> `scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/QuestManagerBatchAwardTests`,
> `scripts/audit-economy-boundaries.sh --all`,
> `scripts/tests/run-audit-fixture-tests.sh`, and `git diff --check`. Economy
> remains 🟢; a separate fresh pure adversarial review is still required before
> 🏁.
>
> Economy current review note (2026-06-13, Codex fresh pure adversarial review
> after TFU-20260613-015): P0=0 / P1=2 / P2=1. P1 is tracked as
> TFU-20260613-016: deceased-pet historical Calendar / Today Focus /
> notification care completion still writes the history fact and then completes
> occurrence / reminder / success revision; R5 still allows
> `CalendarTaskCompletionSyncService.awardGeneratedCare` by function name without
> proving same-function disposition consumption. P2: legacy `QuestManager.batchAward`
> non-litter potty / hygiene still uses private direct fact/ledger helpers rather
> than a shared typed chokepoint. Economy remains 🟢 and must not be marked 🏁.
>
> Economy repair note (2026-06-13, Codex fix session): TFU-20260613-016 P1 is
> fixed locally. Calendar / Today Focus / notification memorial historical
> fact-only now writes only the history fact, does not complete occurrence or
> reminder, does not publish success revision, and can clean legacy no-ledger
> fact-only records on reopen. R5 now requires `awardGeneratedCare` to consume
> `CareFactWritePolicy.disposition` in the same function and has a matching bad
> fixture. Validation passed: targeted simulator suites 214 tests,
> `scripts/audit-economy-boundaries.sh --all`,
> `scripts/tests/run-audit-fixture-tests.sh`, `scripts/dev-check-changed.sh`, and
> `git diff --check`.
>
> Economy repair note (2026-06-14, Codex fix session): TFU-20260613-016 P2 is
> fixed locally. Legacy `QuestManager.batchAward` non-litter potty / hygiene now
> delegates to `SharedPetActionRecorder` typed shared child strategies and
> creates `SharedCareSession`; non-litter potty facts link back through
> `sharedSessionId`, and hygiene sessions point at the first `PetHygieneLog`
> through `primaryLegacyModelName/Id`. Validation passed:
> `scripts/test-simulator.sh -only-testing:OhanaTests/QuestManagerBatchAwardTests`
> (5 tests), the key simulator suite (214 tests),
> `scripts/audit-economy-boundaries.sh --all`,
> `scripts/tests/run-audit-fixture-tests.sh`, `scripts/dev-check-changed.sh`, and
> `git diff --check`. Economy stays 🟢 and still needs a fresh pure adversarial
> review before 🏁.

## 建设工作（宪法差距，2026-06-12 盘点）

| 工作项 | 优先级 | 状态 | 范围/验收 | 门禁 commit | 备注 |
|---|---|---|---|---|---|
| GAP-1 联机功能门 | P0 上架前 | 🟢 | FamilyTasks+云同步设置+CKShare 入口统一收进 `OnlineFeatureGate`；FamilyReports 留周报剥悬赏 | `59b5ceedc` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；验收通过，真实设备 / 真实 UI 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-1-联机功能门`；未做 CloudKit 启用 |
| GAP-2 删除模型 | P0 上架前 | 🟢 | 用户可见回收站按 2026-06-14 产品决策退役；成员删除为确认后不可恢复物理删除，CloudSync 仅保留用户不可见 sync tombstone；旧 V69 schema 和 legacy 字段只为 store compatibility 保留 | `本次提交` | 旧 GAP-2 回收站验收记录作历史参考，不再代表当前产品模型；本轮改为 `PhysicalDeletionService` 统一 tombstone+delete，移除回收站 UI/恢复路径/备份恢复态，并更新 derived-state lifecycle 审计。仍需随 Economy 架构改造通过最终纯复审后再判断成熟度，不标 🏁 |
| GAP-3 自动备份 | P0 上架前 | 🟢 | 自动备份至 iCloud Drive 文件+失败可见+恢复端到端测试 | `9b1ac1be1` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实设备 / 真实 iCloud 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-3-自动备份`；未启用 CloudKit 同步 |
| GAP-4 总账恒等 | P1 上架前 | 🟢 | `QuestManager.coconutCount` 为钱包投影；正式岛屿总资产 ≡ 人类成员+宠物钱包；`system:legacy` 仅迁移兼容 | `1951f7834` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI / 正式包追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-4-总账恒等` |
| GAP-5 触顶感知 | P1 上架前 | 🟢 | 奖励触顶温和文案，九语言；recordOnly 记录照常完成且奖励反馈不暴露预算数字 | `1a775bc7c` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI / 长语言视觉追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-5-触顶感知` |
| GAP-6 通知分级 | P1 上架前 | 🟢 | 通知预算表 + 优先级/限额/合并/夜间免打扰 | `6bb766cc3` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真机通知到达 / 点击动作追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级`；未启用远程推送或 CloudKit 通知 |
| GAP-7 补记结算 | P1 上架前 | 🟢 | 补记历史日期的记录，奖励计入操作当日预算/冷却；不满足则修 | `528cf2cdd` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI 补记路径追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-7-补记结算`；未改 schema / 路由 / 启动路径 / CloudKit |
| GAP-8 单成员形态 | P1 上架前 | 🟢 | 单人单宠下排行榜、周报、心情、家人胶囊等逐面检查 | `6c4a98db2` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI 单人单宠目检项见 `docs/planning/gap-acceptance-track-list.md#gap-8-单成员形态`；未改 schema / 路由 / 启动路径 / CloudKit |
| GAP-9 离世退场 | P1 上架前 | 🟢 | Memorial 规则书逐模块写明离世行为并测试 | `e6a45e72c` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，未来计划可逆退场、离世成员活跃入口过滤、奖励冻结已补；真实 UI / 真机通知验收项见 `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`；未改 schema / 路由 / 启动路径 / CloudKit |
| GAP-12 植物功能门 | P0 上架前 | 🟢 | D19：植物全部表面收进独立功能门（添加植物/植物卡/植物 quest/心情信号/FunctionMenu 与路由入口），代码与 Plant 模型保留；已知表面分布：AppFeatureRouteGuard、AddEntityRoute、FunctionMenu、Onboarding/必填主人页、GrowthUnlock、TodayFocusService/QuestEngine/Card、Home snapshot/components、Oasis、Plants 模块本体 | `本次提交` | 开工：2026-06-13；机制复用 OnlineFeatureGate 模式但独立开关；Q1~Q6 全选 A；规则书见 `docs/specs/PlantFeatureGate-logic.md`；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-12-植物功能门`；未删 Plant 模型或 Plants 模块，未启用 CloudKit |
| GAP-10/11 合资+联机设计 | 1.x | ⬜ | 推迟，见 inventory | | |

## 待拍板问题（提问协议的异步兜底；产品主人答复后销项）

| 编号 | 提出会话/模块 | 问题（含选项与推荐） | 状态 |
|---|---|---|---|
| | | （暂无） | |

## 填写规则

- **状态**：模块会话开工时改 🟡 并填开工日期；`scripts/module-exit-gate.sh` 通过且 commit 后改 🟢 并填门禁 commit 哈希；全新会话对抗复审零 P0/P1 后改 🏁，复审轮次与最后一轮发现数记入交接备注。
- **余留项**：未修的 P1/P2 写入 `docs/task-follow-ups.md`，此处只留一句指针（如「2 条 P2，见 task-follow-ups #Feeding」）。
- **交接备注**：写给下一个会话的人话，例如「HomeReadModelStore 主线程聚合未迁移，触碰 Home 时优先处理」。
- 总览会话每次对账后，在下方「对账日志」追加一行。

## 对账日志（总览会话维护）

| 日期 | 对账范围 | 结论/动作 |
|---|---|---|
| 2026-06-12 | 初始化 | Phase 0 完成（`ff7ac89f`）；总账与门禁脚本建立 |
| 2026-06-12 | 宪法差距盘点 | 产品宪法 v1.1（D1~D18/G1~G10）逐条对照代码：3 个 P0 建设模块（联机门/回收站/自动备份，已拍板都上架前做）、6 项 P1 并入模块会话、合资推 1.x；裁剪三项全部拍板（联机面全收进门、周报留悬赏剥）。明细见 `docs/planning/constitution-gap-inventory.md`，新增 Phase 6.5 |
| 2026-06-12 | 9A 前置项 | **9A.1 付费 Apple Developer 账号已办妥** ✅。解锁：真机签名安装（dogfooding）、App Store Connect 建档、TestFlight（9B 时用）。注意：CloudKit 验证虽技术上解锁，但按 D4 仍属 1.x，不得因账号到位而提前开工。待办：App Store Connect 注册 Bundle ID + 建档抢注 app 名称 |
| 2026-06-12 | GAP 批次对账 | 账实核对：GAP-1~9、Members、Oasis 共 11 项的门禁 commit 全部存在且成对（fix+gate 记录）、工作区干净、AGENTS.md schema 行已同步 V69、九本规则书在 `docs/specs/`。发现：① main 领先 origin 9 个提交未推送→CI（含 SwiftLint 严格）未验证最近批次；② 64 项人工/真机验收债集中在 track list，已在 Phase 6.5 行标注 🟢*；③ 总览会话重跑 `module-exit-gate.sh` 抽查 **PASS**（全量单测+审计绿）。流程修正：验收债规则与 🟢* 状态入手册、收工协议加推送+CI 要求、复审采样节奏入手册 |
| 2026-06-12 | Phase 6 收尾检验 + 宪法 v1.3 | Settings/Health（`5d4e71928`）与 Economy（`662852a01`）账实一致、schema V70 已同步、工作区干净。**违规两项**：① main 领先 origin 14 提交未推送（收工协议第 5 条连续未执行，CI 空转）；② 对抗复审为零（采样规则被跨过两次）。**裁定：Phase 7 开工前必须先 push+CI 绿 + 完成 Economy 与 RecycleBin 两个复审采样**。新决策入宪：D19 植物功能门（GAP-12 登记，P0）、D20 多语言扩展就绪（8.5 增审查项） |
| 2026-06-13 | Economy 复审修复轮 | 对 7 条 P1 + 2 条 P2 按根因归组执行：表征测试提交 `7c7f18b08`，纯重构提交 `67afc59a7`，行为修复提交 `1679ddd66`。新增 legacy 无 actor 不写 system、FamilyTasks 悬赏失败保持待审核且无半笔账测试；`scripts/module-exit-gate.sh` PASS。Economy 状态降回 🟢，需下一轮重新对抗复审清零后才可回 🏁 |
| 2026-06-14 | 架构改造执行检阅 | 读 Codex 完整执行过程 + 核实代码。**纠错**:一度疑 token 是空壳（`rg` 把 `CareDerivationToken` 渲染成 `n`），读实际文件确认 token 真实（`fileprivate init`），方向对、executor 框架与一批 command 迁移有实质进展。**但发现三问，不能放行**：① **P0 数据丢失**——`executorCannotWrite`（CareEventService.swift:145）对无效 UUID/已删 Human 返回 true→disposition `.noOp`→连事实都不写，违反 G3（删成员后缓存 id 当 executor 记照护→事实静默丢失）；② **证人被改**——Codex 把旧表征测试 `executorId:"human-1"`→真实 UUID 让其变绿，把 #1 回归洗白，无测试盯防；③ **焊死未完成**——token 没加到 `DomainRevisionPublishing.publish` 闸门（无 token 参数），command 仍能直接 publish 绕过，验收"构造不出绕过"不满足，主防线退回 R6 采样；④ 工程卫生：巨大未提交脏树、无分簇提交（不可二分回滚）、停在全量门禁红。**新增手册铁律「表征测试不可篡改」**。待产品决策：无效/脏 executorId 是否该丢事实 |
| 2026-06-14 | 复审熔断 → 架构改造 | Economy/care-completion 连续 14 轮复审未收敛。诊断：复审驱动横切不变量数学上不收敛（违反点=分支×派生点，组合爆炸，复审只采样）；且 `disposition{didWriteFact,allowsDerivedEffects}` 字段早已存在但只是建议——发副作用权力仍散落在 12+ command（各自手动逐分支 guard，且只挡 revision、漏 reminder/stock/feedback/Oasis）。**用户选路线 A（架构封死）**：建 `CareDerivationExecutor` 单一派生执行器，收走 command 的副作用触发权，让违反编译期/审计期无法表达。规格 `docs/planning/care-derivation-executor-spec.md`。**熔断规则入手册**（同根因≥3轮或"加了字段还在漏"=权力没收走→禁止再开复审修复轮，转架构改造，验收=构造不出绕过，全程只结尾做一次复审）。**停止 Economy 复审-修复循环**，TFU-013~007 系列以架构改造统一终结 |
| 2026-06-13 | 评估 Codex 自诊断 | Codex 给 5 条原因,经评估重排:#2 返回类型不表达状态=杠杆根因(#1 入口驱动是其果、#4 审计抓不到语义是二阶);**采纳 Codex #3**——不变量是 fact→ledger→budget→reminder→revision→stock→UI 整条派生链,故 `allowsDerivedEffects` 必须是**每个派生点的统一闸门**,不能只在 reward 层消费(否则下一轮又漏一层);#5（规则当天加严）半真,但 TFU-011 的 executor 回落/共享未过滤在旧 G4/ECO-018 下本就违规,不可全归于"标准变了"。**Codex 漏掉的元因**:协议规定同根因≥3轮必开重构轮,却连续点对点=AI 能分析却不反思自己选了治标→靠流程强制不靠自觉。下一轮结构验收钉死:disposition 沿完整派生链做闸门+强制消费+审计 |
| 2026-06-13 | 收敛诊断（冻结门打地鼠） | TFU-011→012→013 同一根因（冻结成员生命周期门）连续 3 轮复现，沿调用栈层层外推（owner→事实写入→命令层），属点对点打地鼠而非结构封死。诊断：① 它是负向不变量（要求副作用不发生），开放式枚举难穷尽；② 真根因=命令层用 `reward==0` 猜状态，缺类型化处置信号；③ 根因重构轮该触发未触发。**裁定：下一轮是结构轮不是补丁轮**——收口返回 `CareFactWriteDisposition{didWriteFact, allowsDerivedEffects}`，command 必须消费，配审计禁止猜状态；UI 层硬挡回收/离世成员进选择器。收敛判据=下一轮复审"构造不出绕过"而非"又找到第 N 个绕过点"。手册「根因重构轮」加强制触发（同根因≥2轮即停止点对点）|
| 2026-06-13 | 收口重构检阅 | 收口重构落地核验:护栏三件套 commit 分离正确(表征`471b22d41`→纯重构`6ce358843`→行为修复独立)、`EconomyRewardDiscipline` 10+ 文件采纳、R5 `reward-direct-awardaction` 审计绿(792 文件)+fixture 自检过、推送/工作区干净。**纠正:Economy 🏁→🟢**——重构改了 10+ 奖励路由,重构后只有机器门禁+自我断言,缺全新会话对抗复审(全新复审发生在重构之前,抓到 Streak P1 已修)。**新增「🏁 完整性防呆」入手册**:🏁 只能纯复审会话授予、需引用复审会话独立证据、改业务代码自动失效。GAP-2 的"收口重构后复审仍零"亦属自我断言,但 GAP-2 未被本重构结构性改动,风险低,保留 🏁 但注记 |
| 2026-06-13 | 收口 plan 决策 | Codex 只读 plan 完成，归类表已确认。三问拍板：Q1 花费不迁入 CareEventService（家族 2，含 human，共享奖励原语+R5）、Q2 时刻豁免、Q3 全清/补签豁免。统一原则「收口=奖励派生纪律非事实类型统一，两家族均受 R5 覆盖」已记入 `Economy-logic.md` ECO-024 与规格文档。花费 farm-risk 登记 ECO-025 / TFU-20260613-010。后续收口重构与复审确认见同日「收口重构落地 + Economy/GAP-2 复审确认」。 |
| 2026-06-13 | 检阅 + 收口根因 | 对账：推送/CI 绿、工作区干净、R1-R4 审计落地（棘轮 baseline 63 条债、fixture 自检过、Economy boundaries 清版）。**根因发现**：Economy 三轮复审反复捞绕过入口的真因是「一动作一事实一次派生」靠约定（10 个 command 各自调 `awardAction`）而非结构。收口点 `CareEventService.recordCareFact` 已存在但采纳不完整。产出重构规格 `docs/planning/care-completion-chokepoint-spec.md`（升为唯一收口 + R5 审计锁死），待派重构会话。状态未变：🏁 仍为 0、验收债 91/0 未燃尽（真机签名未配） |
| 2026-06-13 | 流程优化轮（4 项决策） | ① 复发问题机械化：规格 `docs/planning/recurring-findings-audit-spec.md`（R1 钱包写入白名单/R2 奖励归属/R3 派生状态生命周期/R4 服务层硬门），待建设会话实现并进门禁。② 验收债：已涨到 91 项且真机签名未配——绑定 dogfooding 燃尽、签名先配，入手册 9A.3。③ 双轨制：高风险走完整轨、低风险走轻量轨，分级清单 `docs/planning/phase7-risk-tiers.md` 待主人圈定。④ 流程治本轮：新增 Phase 7.9 整合轮（Phase 7 后做）。另：核验发现 Gacha+Shop 已完成（schema V71）、Phase 7 已实际启动 |
| 2026-06-13 | Phase 7 开工前裁定 | 核验：推送已清零 ✓、Economy 修复轮按治本协议执行（表征→重构→行为三连 commit）✓、GAP-2 四条 P1 全修 ✓、GAP-12 植物门完成 ✓。**修正：GAP-2 的 🏁 降回 🟢**（修复后无新一轮复审记录，不符 🏁 判定）。**硬阻塞：CI build-test 红**（TFU-20260613-007 P1：FamilyTasks 地图视图等非 Economy 面编译失败；TFU-006：CI 工具版本 pin 过期）。**裁定：Phase 7 前先开 CI 修复轮清掉 TFU-006/007；Economy 与 GAP-2 的重新复审与 Phase 7 并行，不阻塞开工** |
| 2026-06-13 | Phase 7 调度补充 | Economy 与 GAP-2 重新复审改为 Phase 7 并行项，只挡 Phase 8 不挡 Phase 7；Phase 7 模块 boot prompt 必须追加「复审模式预检清单」：奖励预算/冷却管线、executor/system 钱包归属、删除/恢复派生状态生命周期、服务层硬门 vs UI 软门，命中任一类直接列 P1。批次顺序：第一批 Walks、Gacha+Shop、Medication、Memorial、Onboarding；第二批 Calendar、Notifications、Expenses、DashboardRecords、Achievements、GrowthUnlock；第三批 Documents、Insurance、Wishlist、Moments、PhotoAlbum、CrewRoster、FunctionMenu 等低风险模块可并行快跑。FamilyTasks 与 Plants 已在门后，仅做编译通过 + 不可达轻量核验 |
| 2026-06-13 | CI 修复轮收口 | TFU-20260613-006/007 已关闭：工具 pin 已刷新并经 CI tool-version 步验证，`build-test` 在 GitHub Actions run `27452421109` 对 commit `33f32ef1a` 绿；本地补充验证 `scripts/dev-check-changed.sh`、`scripts/build-debug-fast.sh`、`scripts/test-simulator.sh -only-testing:OhanaTests/CoconutWalletServiceTests`、SwiftLint 0.63.3 strict lint 均通过。剩余 CI 红点仅 `Architecture boundaries audit`，已单独登记 TFU-20260613-008，不并入本 CI 修复轮；Phase 7 可按第一批从 Walks 开始 |
| 2026-06-13 | Phase 7 Gacha + Shop 收口 | Gacha 与 Shop 合并建设完成：规则书 `docs/specs/GachaShop-logic.md` 已落地；概率 / 定价 / 汇率 / 合资 / 冻结钱包 / App Icon 失败退款 / SwiftData 所有权迁移 / 备份恢复 / CloudSync serializer-applier / schema V71 均有目标测试覆盖；`scripts/dev-check-changed.sh` 与 `scripts/module-exit-gate.sh` PASS。真机 App Icon、真实 UI 分类遍历、真实扭蛋动画、旧安装样本迁移和长语言目检留在统一人工验收 track list |
| 2026-06-13 | 流程/CI 收口推送 | 已推送 `e6f47f843`、`8634babe0`、`92763c164`、`c43dfaf36` 至 `origin/main`。GitHub Actions run `27463715466`：`build-test` 绿（iPhone 17 simulator，UITests 按新 CI 规则跳过，unit suite 完成）、`lint` 绿（SwiftLint strict + SwiftFormat lint），`audits` 红在已登记 TFU-20260613-008 的 `Architecture boundaries audit`；日志显示本轮还新增 / 加重 Gacha+Shop 相关架构信号，已补进 TFU-008，后续单独开架构审计修复轮，不重复触发同一红点 |
| 2026-06-13 | Architecture boundaries 修复轮收口 | TFU-20260613-008 已关闭：规则书 `docs/specs/ArchitectureBoundaryRepair-logic.md` 落地，architecture audit 本地 PASS；修复点包括 `@Query` 数据容器归位、OnlineFeatureGate typed notice publisher、Shop/RecycleBin/Memorial 静态服务调用收进 `AppServices` / infrastructure adapters，并按批准刷新 oversized Swift file ratchet baseline。追加修复 release data-safety audit 版本 pin（`ArkSchemaV71` / backup schema `25`）。GitHub Actions run `27464485820` 对 `90ee16ba4` 全绿：`audits`、`lint`、`build-test` 均 PASS。下一步回到 Economy 与 GAP-2/RecycleBin 重新对抗复审，二者只挡 Phase 8 |
| 2026-06-13 | 复发问题机械化审计建设 | R1/R2/R4 落地为 `scripts/audit-economy-boundaries.sh`，R3 落地为 `scripts/audit-derived-state-lifecycle.sh`；两者均有 bad/good fixture 并纳入 `scripts/tests/run-audit-fixture-tests.sh`、`scripts/dev-check-changed.sh`、`scripts/module-exit-gate.sh` 与 CI `audits` job。全仓棘轮基线写入 `docs/governance/manifests/recurring-findings-audit-baseline.json`：Economy 边界存量 5 条，派生状态生命周期存量 65 条；存量债登记为 TFU-20260613-009。该机制只防新增/加重，不替代 Economy 与 GAP-2/RecycleBin 的重新对抗复审 |
| 2026-06-13 | Economy + GAP-2 重新对抗复审 | 复审未清零，二者继续只挡 Phase 8 不挡 Phase 7。Economy P1：5 个奖励入口仍缺 executor 显式传入，`scripts/audit-economy-boundaries.sh --all` 复现 5 条 `reward-actor-boundary` baseline；会导致业务事实 actor 与钱包收入 owner 分离。GAP-2 / RecycleBin：上一轮四条 P1 已被 `RecycleBinServiceTests` 覆盖，但全仓删除边界仍有 P1 复发，`scripts/audit-derived-state-lifecycle.sh --all` 复现 65 条 baseline，其中 Calendar / PetCare / Hygiene / DashboardRecords / CatCare 存在上传管线实体物理删除无 tombstone。状态：Economy 与 GAP-2 均降为 🔵，修复后需再次对抗复审零 P0/P1 才能 🏁 |
| 2026-06-13 | TFU-20260613-009 P1 修复轮 | 已修复 Economy 与 GAP-2 重新复审中命中的 P1 子集：奖励归属入口补显式 executor / active-human 归属测试，Calendar / PetCare / Hygiene / DashboardRecords / CatCare 删除边界补 CloudSync tombstone。新增 `OhanaTests/RecurringFindingsRepairTests.swift` 6 条回归测试；`scripts/audit-economy-boundaries.sh --all` baseline 归零，`scripts/audit-derived-state-lifecycle.sh --all` baseline 从 65 降到 63。TFU-20260613-009 仍保持 Open，因为剩余 63 条 derived-state 存量债尚未逐项修复或批准 allow；Economy 与 GAP-2 状态回到 🟢，但必须再次对抗复审零 P0/P1 才可 🏁 |
| 2026-06-13 | Economy + GAP-2 第二轮重新对抗复审 | 复审仍未清零，二者继续只挡 Phase 8 不挡 Phase 7。自动审计结果：`scripts/audit-economy-boundaries.sh --all` PASS（791 files，baseline 0）；`scripts/audit-derived-state-lifecycle.sh --all` 仍有 63 条既有 baseline。新增 P1：① Calendar / Today Focus / 通知完成照护任务入口未统一进入照护事实 + 奖励预算管线，导致同一动作不同入口奖励 / ledger 不等价；② Calendar 生成的 `PetCareLog` / `PetPottyLog` / `PetHygieneLog` / `CareLedgerEvent` 撤销时物理删除无 tombstone；③ CarePlan / Water 计划删除 `Event` 时无 tombstone。规则冲突待拍板：Health 规则书与现代码将健康 / 症状 / 发情单条记录放进回收站，但宪法 D16 要求单条高频流水直删且底层 tombstone。状态：Economy 与 GAP-2 均降为 🔵，修复前不能 🏁 |
| 2026-06-13 | Economy + GAP-2 第二轮 P1 修复轮 | 已按产品选择修复第二轮复审新增 P1：Calendar / Today Focus / 通知照护完成统一写照护事实并走 `QuestManager.awardAction`；旧 Calendar 完成奖励服务保留 no-op；Calendar occurrence 撤销冲销钱包并 tombstone 生成事实 / ledger / budget 事件；CarePlan / Feeding / Water 计划删除写 `Event` / `Reminder` tombstone；SymptomLog / HeatCycleLog 改为直删 + tombstone，PetHealthLog 保持回收站。新增 / 更新 `OhanaTests/RecurringFindingsRepairTests.swift` 与 `OhanaTests/HomeCommandExecutorTests.swift` 覆盖；本地窄测试 PASS，`scripts/module-exit-gate.sh` PASS（771 个单测 + 3 个模板 UI tests）；CI 按用户确认跳过。Economy 与 GAP-2 状态回到 🟢，但仍需全新会话重新对抗复审零 P0/P1 才可 🏁 |
| 2026-06-13 | Economy + GAP-2 新视角清零复审 | RecycleBin 未发现新的 P0/P1；Economy 发现 1 条 P1（Streak 连击奖励无 active human 时仍 fallback 写 system wallet），已修为无 active human 或冻结 pet 时直接不发奖、不记 claimed、不写 system。验证：`scripts/dev-check-changed.sh` PASS，`scripts/audit-economy-boundaries.sh --all` PASS，`scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（159 tests），`scripts/test-simulator.sh -only-testing:OhanaTests/RecycleBinServiceTests` PASS（9 tests）。Economy 与 GAP-2 均标 🏁，人工 / 真机 UI 验收债仍留统一 track list |
| 2026-06-13 | 收口重构落地 + Economy/GAP-2 复审确认 | 按护栏三件套完成 Economy 收口：表征测试 `CareCompletionChokepointCharacterizationTests` 先行，纯重构新增 `EconomyRewardDiscipline`，家族 1 照护奖励与家族 2 非照护奖励均通过共享奖励纪律入口，未把花费/时刻/全清/补签伪装成 `CareType`；R5 `reward-direct-awardaction` 审计与 bad/good fixture 纳入 `scripts/audit-economy-boundaries.sh`。验证：`scripts/tests/run-audit-fixture-tests.sh` PASS，`scripts/audit-economy-boundaries.sh --all` PASS（792 files），`scripts/audit-derived-state-lifecycle.sh --all` 无新增债（仍有既有 baseline），`scripts/module-exit-gate.sh` PASS。落地后重新攻击 Economy 与 RecycleBin，未发现新的 P0/P1，二者保持 🏁；CI run `27468716740` 已推送后检查，检查时状态为 in_progress。 |
| 2026-06-14 | Economy 全新纯对抗复审 | 本轮纯复审会话（Codex，2026-06-14，用户要求“全新纯对抗复审”）发现 Economy P0=0 / P1=4 / P2=1，不能标 🏁，状态保持 🟢。P1：shared manual feed 在 recorder no-op gate 前触发 first-meal special reward / flag；planned feed / water catch-up 被错误固化为 0 奖励而非 operation-day 预算结算；Insurance 保费 / 报销直接写 `PetExpenseLog` 但缺同边界 expense ledger 纪律；`HomeCommandExecutorTests` 目标套件仍有 1 个失败。P2：`recordUnknownSharedPotty` no-op 时仍返回 detached `PetPottyLog`，API 容易误判成功。已登记 TFU-20260614-006。验证：`scripts/audit-economy-boundaries.sh --all` PASS（792 files），`scripts/tests/run-audit-fixture-tests.sh` PASS，`DERIVED_DATA_PATH=/tmp/OhanaDerivedData/economy-pure-review-20260614 scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` FAIL（174 tests，1 failure），`git diff --check` PASS。 |
| 2026-06-14 | Care 派生执行器架构改造收口 | 按产品主人 option A 落地二态删除/离世模型：用户可见回收站与可恢复软删退役，删除走物理删除 + 不可见 sync tombstone，离世成员只读且不写照护事实/编辑/派生；`CareFactWriteDisposition` 简化为 active/no-op，dirty executor 不再导致 active target 事实丢失；raw domain revision publish 加 token，care-family command/revision/UI feedback 入口消费 typed `CareWriteOutcome`；旧 `RecycleBinService`/UI/备份恢复态移除，GAP-2 改为删除模型历史项。TFU-20260614-002~005/007 已由架构/新产品规则关闭，TFU-20260614-006 仍保留 Insurance expense ledger 与最终纯复审债。验证截至本地：targeted simulator suites PASS、`scripts/build-debug-fast.sh` PASS、economy/derived audits 与 fixture tests PASS、`scripts/module-exit-gate.sh` PASS（834 unit tests + 3 UI template tests）。push/CI 待本会话结尾执行。Economy 保持 🟢，不得 🏁，完成后还需全新纯对抗复审 P0/P1=0。 |
| 2026-06-14 | 总览检阅简化落地 | 实质核查：**进步**——工程卫生 A（分阶段 commit `689329394`/`be0dd1eeb`、工作区干净、已推送）；旧语义扫净（`memorialHistoricalFactOnly`=0、活跃 `trashedAt` 过滤=0、`RecycleBinService`=0、`PhysicalDeletionService` 建好）；token 真焊到通用 `publish(_:token:)` 闸门（上轮缺陷已修）。**P0（确凿，不能 🏁）**——缺陷3「脏 executor 丢事实」**未真修，且代码直接违反刚写进宪法的 ECO-026④/G4.1④**：测试 `executorId:"human-1"`→`PetCareLog isEmpty` 锁定了"非法/已删 executor → no-op 丢事实"，而宪法明文要求"不可解析/已删/不可写 executor 仍写 active 对象事实+fallback 归属"。Codex 对账日志(283)自称"dirty executor 不再丢事实"与该测试矛盾。真实风险：删成员后缓存 id 当 executor 记照护→事实静默丢失。只修了 nil/空 executor，未修 invalid/已删。**P1（轻，可接受）**——照护类 `publishPetCareRecord` 等仍不要 token 且 command 仍持有 `revisions`，"编译期构造不出绕过"未 100%，靠 R6 文本审计兜底。**裁定**：修复 P0（让 executorCannotWrite 的"不可解析/fetch 不到"分支对 active 对象走 fallback 写事实，而非 noOp；改正锁定错误行为的测试），CI 待绿，之后才可开最终纯复审 |
| 2026-06-14 | 最终纯复审检阅(收敛确认) | Economy 架构改造后最终纯复审 P0=0/P1=1/P2=0。**核实 P1 属实**：InsuranceCommands 自动保费/报销手搓 `PetExpenseLog`（:384/392）但整文件无 `CareLedgerEvent`，绕过统一 expense 入口，违反 ECO-024 家族2。**元判断=收敛铁证**：14 轮泥潭的 care-completion/executor 线本轮 **0 发现**（token 闸门+单一 executor 通道封死成功），唯一余留是一个**无关的孤立问题**（Insurance 绕 ledger，根因同构=绕过统一入口但不同域），非同根因反复——路线 A 架构封死达成收敛。P1 不破坏 G2 椰子余额（保费是真钱非椰子），是花费两源一致性问题。**裁定**：小修（优先让 Insurance 走统一 expense 入口治本，否则补同边界 ledger）+ 给审计加"写 PetExpenseLog 必须配 ledger"堵盲区，修后开最后一次纯复审零 P0/P1 → Economy 🏁。care 线视为已收敛 |
| 2026-06-14 | 总览自纠(P0 误判) | **撤回 2026-06-14「总览检阅简化落地」记录的 P0**：那条"脏 executor 丢事实违反 ECO-026④/证人被改"是**误判**。当时只 `sed` 了 QuickWaterCommandTests 230-250 行，错过测试名 `quickWaterExecutorNoopsForDeceasedPetAtCommandBoundary` 与 `pet.passedAwayDate` setup——该测试是**离世 pet → no-op**（符合宪法 ECO-026②），`human-1` 只是顺带 executor，非"脏 executor 丢事实"。代码铁证：`CareEventService.disposition`（:114）`executorId _:` 被忽略，写不写事实只看 `EconomyWalletWritePolicy.canWrite(pet)`，executor 仅决定归属——`7ded53a6a` 已正确修复。**元教训：检阅者不免检**；这是第二次因读片段未读全文/上下文差点冤判（前次 token 被 rg 渲染成 `n`）。手册「测试断言必须符合宪法」铁律保留（规则对），但当时举的 human-1 例子是误读。Economy 🏁 在可核实维度成立（见下条） |
| 2026-06-14 | Economy 🏁 核查 | Economy 标 🏁（`92133da2a`）核实：① Insurance P1 真修——`InsuranceCommands` 保费/报销改走统一入口 `ExpenseCommandService.recordPetExpense`（:335/386），治本（自动继承 ledger 纪律），非补丁；② disposition 二态正确（pet active→写、离世/删除→no-op，executor 不进判定）；③ CI run `27505314629` = success，headSha=`92133da2a`（含 Insurance 修复）；④ git 干净已推送，治理改动（oversized 豁免/baseline 瘦身/手册铁律）已入库。轻提醒：`docs: record final pure review`(67937) 在 Insurance fix(92133) 之前、`mark mature`(f88818) 纯 docs，"修复后复审"未单独成 commit，时序命名略乱但 CI 在修复后全绿+总账声称修后复审零发现，🏁 成立。**Economy = 核心五模块首个 🏁** |
| 2026-06-14 | Domain 复审优先级纠偏 | Codex Domain 复审 6 轮（TFU-009~014）同根因未收敛，**自己**诊断出横切根因并提议熔断成 CloudSyncApplyDisposition policy 层——方法论对（内化了 care-executor 教训）。**但总览核实**：CloudSync remote/live apply 首发不可达（`cloudKitDatabase: .none`，apply 靠 CloudKit 触发，单机跑不到）。**裁定**：① 首发只收口**本地物理删除级联**（可达真 P1，用"删 parent 构造不出漏 owned entity"注册矩阵审计封死）；② TFU-010/011/012/014 的 remote/live apply policy 层（Codex 建议的架构对、时机错）推 1.x，移交 `cloud-sync-todo.md`「CloudKit-Enable-Time Architecture」，1.x 有真实远端数据再做；③ 立**可达性规则**入 cloud-sync-todo：复审发现若可证首发不可达（门挡/死代码），不阻塞该模块首发 🏁，但须登记+复审确认。避免在 `.none` 死代码上烧架构弹药。Domain 首发 🏁 判据=首发可达面零 P0/P1 |
| 2026-06-14 | Economy 最终纯复审清零 | 修复提交 `92133da2a` 后，本轮全新纯复审会话（Codex，2026-06-14，Insurance ledger 收口）结论：P0=0 / P1=0 / P2=0，Economy 标 🏁。核验：Insurance 自动保费与报销均走 `ExpenseCommandService.recordPetExpense(... awardsReward: false)`，无裸 `PetExpenseLog`；新增 R7 `pet-expense-ledger-boundary` 审计能抓坏例并放行统一入口；`scripts/audit-economy-boundaries.sh --all` PASS（804 files），`scripts/tests/run-audit-fixture-tests.sh` PASS，`scripts/module-exit-gate.sh` PASS（837 unit tests + 3 UI template tests），CI run `27505314629` 全绿（audits/lint/build-test）。 |
| 2026-06-14 | Domain 当前代码纯对抗复审 | 本轮是 Domain 模块（`Ohana/Domain/`）针对 care-derivation executor、PhysicalDeletionService、二态 disposition、CloudSync 后的首次当前代码纯复审；会话身份：Codex Domain pure adversarial review，2026-06-14。结论：P0=0 / P1=5 / P2=2，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-009。P1：care-family typed revision publish/no-op 仍可无 token 绕过 executor；Pet/Human 物理删除未清理钱包/ledger/shared session 等字符串 ID orphan；`CareLedgerEvent` 写入不建 CloudSync dirty state；远端 `CoconutLedgerEntry` apply 后不重放 `CoconutAccount` projection；raw `CoconutWalletDelta` 可绕过冻结钱包硬门。P2：unknown shared potty no-op 返回 detached log；shared manual feed first-meal 派生仍在 recorder 事实前。验证：`scripts/audit-economy-boundaries.sh --all` PASS（804 files）；`scripts/audit-derived-state-lifecycle.sh --all` exit 0（804 files，Domain 无新增命中但有既有跨模块 warnings）；targeted simulator 命令 `scripts/test-simulator.sh -only-testing:OhanaTests/SharedPetActionRecorderTests/deletingPetReconcilesSurvivingSharedFeedSessionStockOwner` TEST SUCCEEDED 但 Swift Testing 过滤命中 0 tests，仅证明测试目标可编译，不作为行为证明。 |
| 2026-06-14 | Domain P1/P2 修复会话 | Codex Domain repair session 针对 TFU-20260614-009 完成当前 worktree 修复：移除 care-family typed revision/no-op publisher 出口并让 no-op care command 走 `CareDerivationExecutor`；`PhysicalDeletionService` 清理 Pet/Human 相关 wallet account、wallet ledger、care ledger、shared session 字符串引用并保留 sync tombstone；`CareLedgerService.record` 写 CloudSync dirty state；CloudSync 远端 `CoconutLedgerEntry` apply 后通过 `CoconutWalletService.reconcileFormalAccountBalancesWithLedger` 重放 projection；raw wallet delta 冻结门按 owner id/account key fail closed；unknown shared potty no-op 返回 nil；shared manual feed first-meal 延后到 recorder 成功后。验证 PASS：`scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests -only-testing:OhanaTests/CloudSyncMetadataServiceTests -only-testing:OhanaTests/CoconutWalletServiceTests`、`scripts/test-simulator.sh -only-testing:OhanaTests/SharedPetActionRecorderTests -only-testing:OhanaTests/QuestManagerBatchAwardTests`、`scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests`、`scripts/tests/run-audit-fixture-tests.sh`、`scripts/module-exit-gate.sh`（841 unit tests + 3 UI template tests）。Domain 仍保持 🟢，不得 🏁；待推送 CI 绿后开全新纯对抗复审。 |
| 2026-06-14 | Domain 全新纯对抗复审（`f5cc637c8` 后） | 本轮纯复审会话（Codex，2026-06-14，用户要求“全新纯对抗复审”）结论：P0=0 / P1=2 / P2=0，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-010。P1-1：`CloudSyncRecordApplier.apply`/`applyHardDeletedRecord` 对远端 Pet/Human 删除只调用 `deleteLocalModel` 裸 `context.delete`，绕过 `PhysicalDeletionService.deletePet/deleteHuman` 的 wallet account、wallet ledger、care ledger、shared session 字符串引用级联，本机可留下 orphan 派生状态。P1-2：同一 delete applier 对远端 `CoconutLedgerEntry` tombstone 裸删 ledger，未调用 `CoconutWalletService.reconcileFormalAccountBalancesWithLedger`，`CoconutAccount` / member balance projection 会保留旧余额，违反 G2。验证：`scripts/audit-economy-boundaries.sh --all` PASS（804 files）；`scripts/audit-derived-state-lifecycle.sh --all` exit 0（804 files，报告既有 warnings，未拦 CloudSync delete 盲区）；`scripts/tests/run-audit-fixture-tests.sh` PASS；`scripts/test-simulator.sh -only-testing:OhanaTests/CloudSyncMetadataServiceTests -only-testing:OhanaTests/PhysicalDeletionServiceTests -only-testing:OhanaTests/CoconutWalletServiceTests` PASS（Swift Testing 89 + XCTest 16）；`scripts/test-simulator.sh -only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests -only-testing:OhanaTests/ReminderActionCoordinatorTests -only-testing:OhanaTests/SharedPetActionRecorderTests` PASS（Swift Testing 54；XCTest 过滤 0）。 |
| 2026-06-14 | Domain CloudSync remote-delete 修复 + 后续纯对抗复审 | Codex 修复 TFU-20260614-010 原两项 P1：远端 Pet/Human tombstone/hard deletion 现在调用 `PhysicalDeletionService.deletePet/deleteHuman`，远端 `CoconutLedgerEntry` tombstone 删除后调用 `CoconutWalletService.reconcileFormalAccountBalancesWithLedger`；新增 `CloudSyncMetadataServiceTests` 红测覆盖 pet cascade 与 ledger projection replay。按用户要求跳过 CI、不推送。本轮随后开启全新纯对抗复审，结论 P0=0 / P1=2 / P2=1，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-011。P1-1：`CloudSyncRecordApplier.deleteLocalModel` 对远端 `Event` 删除仍裸 `context.delete`（`Ohana/Domain/Services/CloudSyncRecordApplier.swift:993`），绕过 `PhysicalDeletionService.deleteEvent` 的通知取消与 reminder delete/mark 边界（`Ohana/Domain/Services/PhysicalDeletionService.swift:13`）。P1-2：远端 `SharedCareSession` 删除仍裸删 session（`Ohana/Domain/Services/CloudSyncRecordApplier.swift:1029`），绕过 `SharedCareSessionMaintenance.deleteCascade` 的 child facts + ledger 级联（`Ohana/Domain/Services/SharedCareSessionMaintenance.swift:132`）。P2：远端 pet-scoped fact tombstones 仍裸删单 fact（`Ohana/Domain/Services/CloudSyncRecordApplier.swift:997` 等），不消费本地 command delete 的 ledger 清理和 shared session reconcile 纪律。验证：新增 red tests 初跑失败符合预期；修复后 `scripts/test-simulator.sh -only-testing:OhanaTests/CloudSyncMetadataServiceTests` PASS（87 Swift Testing tests）；`scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests -only-testing:OhanaTests/CoconutWalletServiceTests -only-testing:OhanaTests/SharedPetActionRecorderTests` PASS（XCTest 16 + Swift Testing 29）；`scripts/audit-derived-state-lifecycle.sh --all` exit 0（804 files，既有 warnings）；`scripts/audit-economy-boundaries.sh --all` PASS；`scripts/tests/run-audit-fixture-tests.sh` PASS；`scripts/dev-check-changed.sh` PASS；`git diff --check` PASS。 |
| 2026-06-14 | Domain CloudSync delete-dispatch 修复后纯对抗复审 | Codex 修复 TFU-20260614-011 原 P1/P2：远端 Event 删除走 `PhysicalDeletionService.deleteEvent`，远端 SharedCareSession 删除走 `SharedCareSessionMaintenance.deleteCascade`，远端 pet-scoped fact 删除走 `PhysicalDeletionService.deletePetScopedRecord` 并清 ledger / reconcile shared session；按用户要求跳过 CI、不推送。本轮随后开启全新纯对抗复审，结论 P0=0 / P1=1 / P2=0，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-012。P1：CloudSync 远端 feeding `PetCareLog` 或 `PetFoodRecord` tombstone/hard deletion 删除事实后不触发 `FeedingPlanWriter.rebuildFoodStockReminders`，与本地 `FeedRecordCommand.deleteLog` / `deleteFoodRecord` 不等价，可留下旧 `pet_food_stock` Event/Reminder。验证：新增 red tests 初跑失败符合预期；修复后 `scripts/test-simulator.sh -only-testing:OhanaTests/CloudSyncMetadataServiceTests` PASS（91 Swift Testing tests）；`scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests -only-testing:OhanaTests/CoconutWalletServiceTests -only-testing:OhanaTests/SharedPetActionRecorderTests -only-testing:OhanaTests/OhanaNotificationsSchedulingTests` PASS（XCTest 16 + Swift Testing 38）；`scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（176 tests，修复过程中曾红 1 条后已修绿）；`scripts/audit-derived-state-lifecycle.sh --all` exit 0（804 files，既有 warnings）；`scripts/audit-economy-boundaries.sh --all` PASS；`scripts/tests/run-audit-fixture-tests.sh` PASS；`scripts/dev-check-changed.sh` PASS；`git diff --check` PASS。 |
| 2026-06-14 | Domain feeding stock reminder 修复后纯对抗复审 | Codex 修复 TFU-20260614-012 原 P1：远端 feeding `PetCareLog` / `PetFoodRecord` tombstone 或 hard deletion 现在通过 delete dispatcher 捕获 affected pet 并重建 `pet_food_stock` reminders；按用户要求跳过 CI、不推送。本轮随后开启全新纯对抗复审，结论 P0=0 / P1=2 / P2=0，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-013。P1-1：`CloudSyncEntityRegistry.uploadPipelineEntityNames` 包含 `GachaOwnedItem` / `GachaDrawLog` / `ShopPurchaseRecord`，业务入口会 `markModified`，serializer/applier 也支持，但 `CloudSyncUploadBatchBuilder.localModel` 无三者 fetch case，dirty payload 构建会抛 `missingLocalModel`。P1-2：`PhysicalDeletionService.deleteHuman` 的 human-scoped cascade 未删除 `GachaOwnedItem.ownerHumanId`、`GachaDrawLog.ownerHumanId`、`ShopPurchaseRecord.buyerHumanId` 记录；删除成员后人属 Gacha/Shop 数据残留，且 Gacha 缺本地 `markDeleted` tombstone overload。验证：新增 red tests 初跑失败符合预期；修复后 `scripts/test-simulator.sh -only-testing:OhanaTests/CloudSyncMetadataServiceTests` PASS（93 Swift Testing tests）；`scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests -only-testing:OhanaTests/SharedPetActionRecorderTests -only-testing:OhanaTests/CoconutWalletServiceTests -only-testing:OhanaTests/OhanaNotificationsSchedulingTests -only-testing:OhanaTests/ManualFeedCommandTests -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（XCTest 16 + Swift Testing 227）；`scripts/dev-check-changed.sh` PASS；纯复审只读护栏：`scripts/audit-derived-state-lifecycle.sh` PASS（12 files）；`scripts/audit-economy-boundaries.sh` PASS（12 files）；`scripts/tests/run-audit-fixture-tests.sh` PASS（804 files floor）；`git diff --check` PASS。 |
| 2026-06-14 | Domain TFU-20260614-013 Gacha/Shop lifecycle 修复 | Codex repair session 本地修复 Gacha/Shop CloudSync upload 与 human-delete lifecycle P1：`CloudSyncUploadBatchBuilder` 补 `GachaOwnedItem` / `GachaDrawLog` / `ShopPurchaseRecord` fetch case；`CloudSyncMutationRecorder` 补 Gacha delete tombstone overload；`PhysicalDeletionService.deleteHuman` 级联删除人属 Gacha/Shop 记录并写 tombstone。新增红测：registered Gacha/Shop dirty payload 构建、成员删除后 Gacha/Shop 物理删除 + tombstone；新增 `cloudsync-upload-builder-coverage` derived-state 审计和 bad/good fixture，堵住“注册 upload pipeline 但 builder 漏接”的矩阵盲区。验证：修复前 `CloudSyncMetadataServiceTests` 红在 `missingLocalModel`，`HomeCommandExecutorTests` 红在 3 类记录/3 个 tombstone 未删除；修复后 `scripts/test-simulator.sh -only-testing:OhanaTests/CloudSyncMetadataServiceTests` PASS（94 tests）、`scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（177 tests）、`scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests` PASS（4 tests）、`scripts/tests/run-audit-fixture-tests.sh` PASS、`scripts/audit-derived-state-lifecycle.sh --all` exit 0（804 files，只有既有 baseline warnings）、`scripts/audit-economy-boundaries.sh --all` PASS、`scripts/dev-check-changed.sh` PASS、`git diff --check` PASS。按用户方向跳过 CI；Domain 保持 🟢，不得 🏁，下一步必须全新纯对抗复审 P0/P1=0。 |
| 2026-06-14 | Domain TFU-013 后全新纯对抗复审 | 本轮纯复审会话（Codex，2026-06-14，用户要求“复审”）结论：P0=0 / P1=3 / P2=0，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-014。P1 同根因：CloudSync live apply 缺少统一 deletion-wins / parent lifecycle / natural identity policy。P1-1：live remote `Pet` / `Human` 若 `lastModifiedAt` 新于本地 deletion tombstone，会绕过 stale gate、重新 insert/update 并清掉 tombstone，违反 D8/G5。P1-2：live child/fact apply 不校验 parent active/existing；pet-scoped facts 在 `petReference` 为 nil 时仍 insert，Gacha/Shop 也接受已删除 human id，late remote record 可在成员删除后重建 orphan。P1-3：`GachaOwnedItem` 按随机 id 合并，不按 owner+series+item natural key 合并，和 registry 的 `ownedCount maxValue` 策略不一致，可产生重复 ownership projection。验证：`scripts/audit-derived-state-lifecycle.sh --all` exit 0（804 files，仅既有 baseline warnings，未抓本 P1）、`scripts/audit-economy-boundaries.sh --all` PASS、`scripts/tests/run-audit-fixture-tests.sh` PASS、`scripts/test-simulator.sh -only-testing:OhanaTests/CloudSyncMetadataServiceTests` PASS（94 tests，证明现有测试未覆盖该竞争）、`git diff --check` PASS。 |
| 2026-06-14 | Domain 本地物理删除级联架构收口 | 按总览裁定，本轮只收首发可达的本地路径，CloudSync remote/live apply policy 继续推 `docs/cloud-sync-todo.md` 1.x。新增 `CloudSyncEntityRegistry.physicalDeletionOwnerships` 与 `PhysicalDeletionService.localPhysicalDeletionCascadeCoverage` 注册矩阵；`deletePet/deleteHuman` 级联覆盖 Event/Reminder、PetRelationship、FamilyCollaborationTask、SharedCareSession、wallet account/ledger、CareLedgerEvent、EconomyBudgetUsageEvent、GachaOwnedItem/GachaDrawLog/ShopPurchaseRecord 及其他 Pet/Human owned/scoped 记录，并写不可见 sync tombstone。新增入口族红测：`physicalDeletionCoverageMatchesCloudSyncRegistryOwnershipManifest`、`deletePetCascadesFirstReleaseRegisteredOwnedEntities`、`deleteHumanCascadesFirstReleaseRegisteredOwnedEntities`；新增 derived-state lifecycle `physical-deletion-cascade-coverage` 审计和 bad/good fixture，确保 registry 新增 owned entity 但 deletion coverage 漏接会红门。验证：修复前 `PhysicalDeletionServiceTests` 红在 Pet Event/Reminder、PetRelationship、FamilyCollaborationTask 与 Human Event/Reminder、SharedCareSession、CoconutExchangeRequest、FamilyCollaborationTask 残留；修复后 `PhysicalDeletionServiceTests` PASS（7 tests）、`PhysicalDeletionServiceTests + CloudSyncMetadataServiceTests + HomeCommandExecutorTests` PASS（278 tests）、`scripts/tests/run-audit-fixture-tests.sh` PASS、`scripts/audit-derived-state-lifecycle.sh --all` exit 0（仅既有 baseline warnings）、`scripts/audit-architecture-boundaries.sh --all` PASS、`scripts/dev-check-changed.sh` PASS、`scripts/module-exit-gate.sh` PASS（854 unit tests + 3 UI template tests）。Domain 保持 🟢，待推送 CI 绿后开首发可达面纯复审，P0/P1=0 才能标 🏁。 |
| 2026-06-14 | Domain 本地物理删除级联最终纯复审 | 本轮首发可达面纯对抗复审（Codex，2026-06-14，commit `3aa7e464a` + CI run `27510220670` 全绿后）结论：P0=0 / P1=1 / P2=0，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-015。P1：`PhysicalDeletionService.deleteHuman` 把 `SharedCareSession.executorIds` 只含被删 human 的 session 物理删除，但 active pet child facts 必须保留，当前不会清 `PetCareLog` / `PetWalkLog` / `PetExpenseLog` 等 child 的 `sharedSessionId`，可留下指向已删除 session 的 orphan。现有 `deleteHumanCascadesFirstReleaseRegisteredOwnedEntities` 只构造 session，不构造 child log，入口族测试漏断言。验证：只读复审命令包括 `git status --short`（纯复审开始前干净）、`rg cloudKitDatabase`（确认首发 `.none`）、schema/model/registry/PhysicalDeletionService/SharedCareSessionMaintenance 代码扫描、`scripts/audit-derived-state-lifecycle.sh --all`（exit 0，仅既有 baseline warnings）。 |
| 2026-06-14 | Domain TFU-20260614-015 shared-care child orphan no-CI 修复 | Codex repair session 按用户要求“修复，不ci”本地修复最终纯复审 P1。`PhysicalDeletionService.deleteHuman` 删除 human executor 时，现在统一 scrub shared-care child facts：唯一 executor 被删导致 `SharedCareSession` 删除时，保留 active pet 的 `PetCareLog` / `PetPottyLog` / `PetHygieneLog` / `PetExpenseLog` / `PetWalkLog` 并清空 `sharedSessionId` 与已删 executor；多 executor 时 session 保留，child executor metadata 同步收敛到 survivor。实现拆入 `PhysicalDeletionService+SharedCareScrubbing.swift`，未增长 oversized baseline 文件。新增入口族红测覆盖五类 child facts 的 detach/scrub 两路径。验证 PASS：修复前新增红测失败；修复后 `scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests` PASS（9 tests）、`scripts/dev-check-changed.sh` PASS、`scripts/audit-architecture-boundaries.sh --all` PASS、`scripts/audit-derived-state-lifecycle.sh --all` exit 0（仅既有 baseline warnings）、`scripts/audit-economy-boundaries.sh --all` PASS、`git diff --check` PASS。按用户要求未推送/未跑 CI；误触发的 docs-only CI run `27510604402` 已取消。Domain 保持 🟢，不得 🏁；后续需用户批准 push/CI 后再开首发可达面纯复审。 |
| 2026-06-14 | Domain 首发可达面纯对抗复审（`3cc140333` 后） | 本轮纯复审会话（Codex，2026-06-14，用户要求“Domain 纯对抗复审会话(首发可达面)”）明确排除 CloudSync remote/live apply：主容器三层配置均 `cloudKitDatabase: .none`，`OnlineFeatureGate.allows(.onlineCollaboration)` 恒 false，remote/live apply 继续按 `docs/cloud-sync-todo.md` 推 1.x。首发可达面结论：P0=0 / P1=1 / P2=0，Domain 保持 🟢，不得 🏁；已登记 TFU-20260614-016。P1：`PhysicalDeletionService.deleteHuman` 只 scrub shared-care child facts；普通 active pet facts（care/potty/hygiene/health/walk/weight/food/pet expense）保留被删 human 的 `executorId`，同时 `deleteHumanScopedRows` 删除 `actorId == humanId` 的 `CareLedgerEvent`。结果是 active pet fact 留存但 ledger 消失；`CareLedgerBackfillService.backfill` 又会从 retained `log.executorId` 把 deleted human id 回填到 ledger，备份编码也会导出这些 executor id。验证：`scripts/audit-economy-boundaries.sh --all` PASS（805 files）；`scripts/audit-derived-state-lifecycle.sh --all` exit 0（805 files，仅 review warnings）；`scripts/audit-architecture-boundaries.sh --all` PASS；`scripts/tests/run-audit-fixture-tests.sh` PASS；`scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests -only-testing:OhanaTests/CoconutWalletServiceTests -only-testing:OhanaTests/SharedPetActionRecorderTests` PASS（XCTest 16 + Swift Testing 34）。 |
| 2026-06-14 | Domain TFU-20260614-016 retained executor no-CI 修复 | Codex repair session 按用户要求“修复，不ci”本地修复首发可达面 P1。`PhysicalDeletionService.deleteHuman` 现在先维护 shared-care session，再对 retained active pet fact keys 做统一兜底：普通 active pet care/potty/hygiene/health/walk/weight/food/pet expense facts 保留但清 deleted human executor；matching `CareLedgerEvent` 与 pet-owned `CoconutLedgerEntry` 保留，actor 有 retained survivor executor 时回落到 survivor，没有 survivor 时收敛为 unknown/nil，避免删除 human 后 active fact/ledger/backfill/backup 重新出现 deleted human id。新增红测覆盖普通 fact 入口族、shared-only-executor ledger、shared survivor ledger、backfill 幂等与 backup 导出。验证：新增红测先红（23 issues）；修复后 `scripts/test-simulator.sh -only-testing:OhanaTests/PhysicalDeletionServiceTests` PASS（10 tests，格式化后复跑仍 PASS）；`scripts/test-simulator.sh -only-testing:OhanaTests/CareLedgerBackfillActorTests -only-testing:OhanaTests/CoconutWalletServiceTests -only-testing:OhanaTests/SharedPetActionRecorderTests` PASS（XCTest 16 + Swift Testing 31）；`scripts/dev-check-changed.sh` PASS（SwiftFormat checked 2 Swift files, 0 formatted；changed-file audits PASS，提示已用 targeted tests 覆盖）；`scripts/audit-economy-boundaries.sh --all` PASS（805 files）；`scripts/audit-derived-state-lifecycle.sh --all` exit 0（805 files，仅既有 review warnings）；`scripts/audit-architecture-boundaries.sh --all` PASS；`git diff --check` PASS。按用户要求未跑 CI、未推送、未开最终纯复审；Domain 保持 🟢，不得 🏁。 |
