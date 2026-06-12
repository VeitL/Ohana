# 测试推进总账（跨会话唯一进度源）

> 工作协议见 `docs/ai-module-test-playbook.md`。任何会话开工前先读本文件；收工前**必须**更新本文件对应行，否则视为未完成。
> 状态图例：⬜ 未开始 ｜ 🔵 分析完成待修 ｜ 🟡 修复中 ｜ 🟢 已过门禁并提交 ｜ ⛔ 阻塞（备注写明阻塞原因）

## 阶段总览

| Phase | 范围 | 状态 | 备注 |
|---|---|---|---|
| 0 | 基线收尾（提交未完成改动） | 🟢 | 已于 2026-06-12 提交（`ff7ac89f`）；后续模块工作可能使当前工作区非空 |
| 1 | `Ohana/Models` | ⬜ | |
| 2 | `Ohana/Domain` | ⬜ | |
| 3 | `Ohana/Shared` | ⬜ | |
| 4 | `Ohana/App` | ⬜ | |
| 5 | Home + TodayFocus + QuickCare | ⬜ | |
| 6 | 大模块（Feeding/Members/Oasis/Settings/Health/Economy） | ⬜ | |
| 7 | 中小模块批量 | ⬜ | |
| 8 | 横向集成与全量回归 | ⬜ | 需总览会话主持 |
| 9 | 上架准备 | ⬜ | 需总览会话主持 + 人工操作 |

## 模块明细

| 模块 | Phase | 状态 | 开工日期 | 余留项（P1/P2 指针） | 门禁 commit | 交接备注 |
|---|---|---|---|---|---|---|
| Models | 1 | ⬜ | | | | |
| Domain | 2 | ⬜ | | | | |
| Shared | 3 | ⬜ | | | | |
| App | 4 | ⬜ | | | | |
| Home | 5 | ⬜ | | | | |
| TodayFocus | 5 | ⬜ | | | | |
| QuickCare | 5 | ⬜ | | | | |
| Feeding | 6 | ⬜ | | | | |
| Members | 6 | ⬜ | | | | |
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

- **状态**：模块会话开工时改 🟡 并填开工日期；`scripts/module-exit-gate.sh` 通过且 commit 后改 🟢 并填门禁 commit 哈希。
- **余留项**：未修的 P1/P2 写入 `docs/task-follow-ups.md`，此处只留一句指针（如「2 条 P2，见 task-follow-ups #Feeding」）。
- **交接备注**：写给下一个会话的人话，例如「HomeReadModelStore 主线程聚合未迁移，触碰 Home 时优先处理」。
- 总览会话每次对账后，在下方「对账日志」追加一行。

## 对账日志（总览会话维护）

| 日期 | 对账范围 | 结论/动作 |
|---|---|---|
| 2026-06-12 | 初始化 | Phase 0 完成（`ff7ac89f`）；总账与门禁脚本建立 |
