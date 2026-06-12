# 测试推进总账（跨会话唯一进度源）

> 工作协议见 `docs/ai-module-test-playbook.md`。任何会话开工前先读本文件；收工前**必须**更新本文件对应行，否则视为未完成。
> 状态图例：⬜ 未开始 ｜ 🔵 分析完成待修 ｜ 🟡 修复中 ｜ 🟢 已过门禁并提交 ｜ 🏁 对抗复审通过（成熟） ｜ ⛔ 阻塞（备注写明阻塞原因）
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
| 6 | 大模块（Feeding/Members/Oasis/Settings/Health/Economy） | 🟡 | Feeding 门禁通过并提交：`b49134977`；Members 门禁通过并提交：`ead1e5fe4`；Oasis/Settings/Health/Economy 待启动 |
| 6.5 | 宪法差距建设（联机门/回收站/自动备份） | ⬜ | 见下方「建设工作」表与 `docs/planning/constitution-gap-inventory.md` |
| 7 | 中小模块批量 | ⬜ | |
| 8 | 横向集成与全量回归 | ⬜ | 需总览会话主持 |
| 8.5 | 演进就绪审查（联网/订阅/账户地基） | ⬜ | 需总览会话主持；产出审查报告与少量铺垫，非新功能 |
| 9 | 上架工程（9A 前置/9B RC/9C 提审上线后） | ⬜ | 9A 前置项**现在就可并行启动**（开发者账号为最长前置）；详见手册 Phase 9 |

## 模块明细

| 模块 | Phase | 状态 | 开工日期 | 余留项（P1/P2 指针） | 门禁 commit | 交接备注 |
|---|---|---|---|---|---|---|
| Models | 1 | 🟢 | 2026-06-12 | TFU-20260612-012 已由 Domain gate commit `304971af` 关闭；TFU-20260612-013 已关闭 | `db44afe1` | V68 tombstone 默认值、fallback indicator、V67→V68 临时磁盘迁移测试已补并执行 |
| Domain | 2 | 🟢 | 2026-06-12 | P1 余留见 TFU-20260612-014 | `304971af` | 删除未引用的 `BatchAction` UI/奖励绕行路径；宠物活动清理由 `PetActivityRecordCleanupService` 负责，Members 调用点已迁移，`Pet` 模型不再执行清理副作用 |
| Shared | 3 | 🟢 | 2026-06-12 | P1 余留见 TFU-20260612-015 | `fcf998088` | 附件隐私清理器已改为 ImageIO 重编码，Shared smoothness 阻塞解除；QuickCare 阶段迁移 executor picker 的 Shared `@Query` |
| App | 4 | 🟢 | 2026-06-12 | 无 | `e48c13af7` | 启动/路由/运行时策略审计通过；隐私快照遮罩 a11y 与 shell 文案本地化已修复 |
| Home | 5 | 🟢 | 2026-06-12 | 无 | `b8e8710e` | Phase 5 审计与门禁通过；本轮未发现需修改的 Home P0/P1 项 |
| TodayFocus | 5 | 🟢 | 2026-06-12 | 无 | `b8e8710e` | Phase 5 审计与门禁通过；本轮未发现需修改的 TodayFocus P0/P1 项 |
| QuickCare | 5 | 🟢 | 2026-06-12 | 无 | `b8e8710e` | `ExecutorPickerBar` 的 SwiftData 查询已迁入 QuickCare feature 容器，Shared 只保留纯展示组件；空/多成员 picker smoke tests 已补 |
| Feeding | 6 | 🟢 | 2026-06-12 | 跨模块 read-model 余留见 TFU-20260612-006 | `b49134977` | CloudSync `Event` / `PetFoodRecord` 上传与 apply 支持已补；Feeding 计划、粮仓、断粮提醒、自动投喂日志会写入 dirty/tombstone；dashboard 内容 revision 与本地化已修复；模块门禁通过 |
| Members | 6 | 🟢 | 2026-06-12 | P1/P2 余留见 TFU-20260612-018~021 | `ead1e5fe4` | Human/Pet 删除聚合进入回收站并可恢复相关 Event/Reminder；Human 侧私密记录回收期保留、过期清理写 tombstone；成员创建生日/到家日 Event 与 Reminder 写 sync metadata；RequiredHumanProfileView a11y 修复；`scripts/module-exit-gate.sh` PASS；真实 UI 抽查见统一 track list |
| Oasis | 6 | ⬜ | | | | |
| Settings | 6 | ⬜ | | | | |
| Health | 6 | ⬜ | | | | |
| Economy | 6 | ⬜ | | | | |
| Medication | 7 | ⬜ | | | | |
| Walks | 7 | ⬜ | | | | |
| FamilyTasks | 7 | ⬜ | | | | |
| Expenses | 7 | ⬜ | | | | |
| DashboardRecords | 7 | ⬜ | | 历史验证阻塞 TFU-20260612-013 已由 cross-scope repair 关闭 | | 接手时留意 `WeightHistoryView 2.swift` 曾误入仓库并阻塞 app target 编译 |
| Calendar | 7 | ⬜ | | | | |
| CrewRoster | 7 | ⬜ | | | | |
| Gacha | 7 | ⬜ | | | | |
| Shop | 7 | ⬜ | | | | |
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

## 建设工作（宪法差距，2026-06-12 盘点）

| 工作项 | 优先级 | 状态 | 范围/验收 | 门禁 commit | 备注 |
|---|---|---|---|---|---|
| GAP-1 联机功能门 | P0 上架前 | 🟢 | FamilyTasks+云同步设置+CKShare 入口统一收进 `OnlineFeatureGate`；FamilyReports 留周报剥悬赏 | `59b5ceedc` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；验收通过，真实设备 / 真实 UI 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-1-联机功能门`；未做 CloudKit 启用 |
| GAP-2 回收站 | P0 上架前 | 🟢 | 成员+珍贵档案软删 30 天可恢复；流水直删但写 tombstone；涉及 schema 升版 | `8bddfe1a6` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-2-回收站`；schema 升至 `ArkSchemaV69` |
| GAP-3 自动备份 | P0 上架前 | 🟢 | 自动备份至 iCloud Drive 文件+失败可见+恢复端到端测试 | `9b1ac1be1` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实设备 / 真实 iCloud 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-3-自动备份`；未启用 CloudKit 同步 |
| GAP-4 总账恒等 | P1 上架前 | 🟢 | `QuestManager.coconutCount` 为钱包投影；正式岛屿总资产 ≡ 人类成员+宠物钱包；`system:legacy` 仅迁移兼容 | `1951f7834` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI / 正式包追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-4-总账恒等` |
| GAP-5 触顶感知 | P1 上架前 | 🟢 | 奖励触顶温和文案，九语言；recordOnly 记录照常完成且奖励反馈不暴露预算数字 | `1a775bc7c` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI / 长语言视觉追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-5-触顶感知` |
| GAP-6 通知分级 | P1 上架前 | 🟢 | 通知预算表 + 优先级/限额/合并/夜间免打扰 | `6bb766cc3` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真机通知到达 / 点击动作追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级`；未启用远程推送或 CloudKit 通知 |
| GAP-7 补记结算 | P1 上架前 | 🟢 | 补记历史日期的记录，奖励计入操作当日预算/冷却；不满足则修 | `528cf2cdd` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI 补记路径追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-7-补记结算`；未改 schema / 路由 / 启动路径 / CloudKit |
| GAP-8 单成员形态 | P1 上架前 | 🟢 | 单人单宠下排行榜、周报、心情、家人胶囊等逐面检查 | `6c4a98db2` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI 单人单宠目检项见 `docs/planning/gap-acceptance-track-list.md#gap-8-单成员形态`；未改 schema / 路由 / 启动路径 / CloudKit |
| GAP-9 离世退场 | P1 上架前 | 🟢 | Memorial 规则书逐模块写明离世行为并测试 | `e6a45e72c` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，未来计划可逆退场、离世成员活跃入口过滤、奖励冻结已补；真实 UI / 真机通知验收项见 `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`；未改 schema / 路由 / 启动路径 / CloudKit |
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
