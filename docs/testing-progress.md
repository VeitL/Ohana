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
| 6.5 | 宪法差距建设（联机门/回收站/自动备份/植物门） | 🟢* | GAP-1~9 与 GAP-12 全部过门禁并提交；*带验收债：人工/真机验收项见 `docs/planning/gap-acceptance-track-list.md`，必须在 🏁 复审与 Phase 9B 前清完 |
| 7 | 中小模块批量 | 🟡 | Walks 门禁通过（2026-06-13，`e0c1d69d3`）；按第一批高风险模块继续推进，注入复审模式预检清单 |
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
| Oasis | 6 | 🟢 | 2026-06-12 | 无 | `87423afd8` | 开工：2026-06-12；规则书见 `docs/specs/Oasis-logic.md`；当前主人钱包门、预算/冷却产出、一次性幂等奖励、休眠可唤回语义已落地；`scripts/module-exit-gate.sh` PASS；真实 UI 抽查见 `docs/planning/gap-acceptance-track-list.md#phase-6-oasis`；未改 schema / 路由 / 启动路径 / CloudKit |
| Settings | 6 | 🟢 | 2026-06-12 | P2 余留见 TFU-20260612-022 | `5d4e71928` | 规则书见 `docs/specs/Settings-logic.md`；开发/测试入口收进 Debug-only，通知开关接入 `NotificationDeliveryPolicy`，空 About 入口隐藏；目标测试、UI/a11y/smoothness/runtime 审计与 `scripts/module-exit-gate.sh` PASS；真实 UI / 真机通知抽查见统一 track list |
| Health | 6 | 🟢 | 2026-06-12 | 无 P1/P2 代码余留；真实 UI 抽查见统一 track list | `5d4e71928` | 规则书见 `docs/specs/Health-logic.md`；健康记录删除清理派生费用/日历事件/提醒/ledger，健康/症状/发情记录进回收站并可恢复，已故/回收宠物只读；schema 升至 `ArkSchemaV70`；目标测试与 `scripts/module-exit-gate.sh` PASS；未启用 CloudKit、未改路由或启动路径 |
| Economy | 6 | 🏁 | 2026-06-12 | 收口重构落地后复审清零；真实 UI 抽查见统一 track list | `本次提交` | 规则书见 `docs/specs/Economy-logic.md`；线下兑现入口首发门关闭，冻结钱包拒绝成就 / 商店 / 金库 / 奖励写入，特殊奖励与 legacy 兼容奖励无 actor 时归属 active human 且不写 system，隐私钱包计入总额但隐藏明细，离世 / 回收钱包退出活跃财富且历史保留；2026-06-13 复审修复轮已完成：重复喂药 / 时刻奖励进入预算冷却管线、首宠欢迎奖励不写 system、商店支持岛屿合资、兑换服务层硬门、财富趋势排除 system、遛狗先存事实再发奖；2026-06-13 TFU 修复轮补齐体重、补签、宠物花费、宠物健康、手动宠物里程碑奖励归属，其中手动里程碑按已确认产品意图归属当前 active human；`scripts/audit-economy-boundaries.sh --all` baseline 已归零；2026-06-13 第二轮修复补齐 Calendar / Today Focus / 通知完成宠物照护任务的照护事实 + `QuestManager.awardAction` 等价入口，旧 Calendar 完成奖励服务改为 no-op，撤销 occurrence 写反向钱包流水并 tombstone 生成事实 / ledger / budget 事件；2026-06-13 新视角复审发现并修复 Streak 连击奖励无 active human 时写 system wallet 的 P1；同日收口重构落地：表征测试先行，家族 1/家族 2 奖励均改走 `EconomyRewardDiscipline`，R5 `reward-direct-awardaction` 审计与 fixture 纳入 `scripts/audit-economy-boundaries.sh`，`scripts/module-exit-gate.sh` PASS，重审零 P0/P1 |
| Medication | 7 | ⬜ | | | | |
| Walks | 7 | 🟢 | 2026-06-13 | 无 P1/P2 代码余留；真机定位 / 真实 UI 抽查见统一 track list | `e0c1d69d3` | 规则书见 `docs/specs/Walks-logic.md`；`WalkFeaturePolicy` 统一 active dog/lifecycle 判定，非狗 / 已离世 / 回收宠物不可启动遛狗；Walks 统计与详情排除回收 walk / poop marker；遛狗中便便写 `PetPottyLog` + `CareLedgerEvent` 并进入奖励管线；共享遛狗调用收进基础设施适配器；目标测试、changed gate 与 `scripts/module-exit-gate.sh` PASS；未改 schema / CloudKit / 启动路径 |
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

## 建设工作（宪法差距，2026-06-12 盘点）

| 工作项 | 优先级 | 状态 | 范围/验收 | 门禁 commit | 备注 |
|---|---|---|---|---|---|
| GAP-1 联机功能门 | P0 上架前 | 🟢 | FamilyTasks+云同步设置+CKShare 入口统一收进 `OnlineFeatureGate`；FamilyReports 留周报剥悬赏 | `59b5ceedc` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；验收通过，真实设备 / 真实 UI 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-1-联机功能门`；未做 CloudKit 启用 |
| GAP-2 回收站 | P0 上架前 | 🏁 | 成员+珍贵档案软删 30 天可恢复；流水直删但写 tombstone；涉及 schema 升版 | `本次提交` | 开工：2026-06-12；门禁：`scripts/module-exit-gate.sh` PASS；自动验收通过，真实 UI 追踪项见 `docs/planning/gap-acceptance-track-list.md#gap-2-回收站`；schema 升至 `ArkSchemaV69`；2026-06-13 对抗复审 P1 已修：30 天到期改为服务层硬边界，恢复 Event/Reminder 后重新排未来本地通知，Pet 期满 purge 为级联子记录写 tombstone，单条流水直删路径写 CloudSync tombstone；2026-06-13 TFU 修复轮补齐 Calendar whole-event / recurrence 删除的 `Event` + `Reminder` tombstone，PetCare/Hygiene/DashboardRecords 删除业务 fact 时的 `CareLedgerEvent` tombstone，以及 CatCare undo 的 `Event` / `PetHygieneLog` tombstone；`scripts/audit-derived-state-lifecycle.sh --all` baseline 从 65 降至 63，剩余为跨模块存量债，TFU-20260613-009 保持 open；2026-06-13 第二轮修复补齐 Calendar 生成照护事实撤销、CarePlan / Feeding / Water 计划删除的上传管线实体 tombstone，并按产品拍板将 SymptomLog / HeatCycleLog 改为直删 + tombstone、PetHealthLog 保持珍贵档案回收；2026-06-13 新视角复审未发现新的 P0/P1，`RecycleBinServiceTests` 通过；同日收口重构后再次复审未发现新的 P0/P1，`scripts/audit-derived-state-lifecycle.sh --all` 无新增债，`scripts/module-exit-gate.sh` PASS，保持 🏁；未改路由 / 启动路径 / CloudKit |
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
