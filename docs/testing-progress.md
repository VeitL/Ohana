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
| 6 | 大模块（Feeding/Members/Oasis/Settings/Health/Economy） | 🟡 | Feeding 门禁通过并提交：`b49134977`；Members 1a/1b 分析完成，规则书待确认：2026-06-12 |
| 7 | 中小模块批量 | ⬜ | |
| 8 | 横向集成与全量回归 | ⬜ | 需总览会话主持 |
| 8.5 | 演进就绪审查（联网/订阅/账户地基） | ⬜ | 需总览会话主持；产出审查报告与少量铺垫，非新功能 |
| 9 | 上架准备 | ⬜ | 需总览会话主持 + 人工操作 |

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
| Members | 6 | 🔵 | 2026-06-12 | 待确认 MBR/S-MEM 修复范围 | | 第 1 步 1a/1b 完成：`docs/specs/Members-logic.md` 已生成待人工确认；当前审计 UI/smoothness/runtime PASS、a11y FAIL；第 2 步建议方案已准备：P0 先修 Human 删除级联与 Members Event CloudSync，P1 修 RequiredHumanProfileView a11y，本地化视范围确认，P2 暂记余留 |
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

## 填写规则

- **状态**：模块会话开工时改 🟡 并填开工日期；`scripts/module-exit-gate.sh` 通过且 commit 后改 🟢 并填门禁 commit 哈希；全新会话对抗复审零 P0/P1 后改 🏁，复审轮次与最后一轮发现数记入交接备注。
- **余留项**：未修的 P1/P2 写入 `docs/task-follow-ups.md`，此处只留一句指针（如「2 条 P2，见 task-follow-ups #Feeding」）。
- **交接备注**：写给下一个会话的人话，例如「HomeReadModelStore 主线程聚合未迁移，触碰 Home 时优先处理」。
- 总览会话每次对账后，在下方「对账日志」追加一行。

## 对账日志（总览会话维护）

| 日期 | 对账范围 | 结论/动作 |
|---|---|---|
| 2026-06-12 | 初始化 | Phase 0 完成（`ff7ac89f`）；总账与门禁脚本建立 |
