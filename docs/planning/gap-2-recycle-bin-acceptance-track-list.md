# GAP-2 回收站验收跟踪清单

状态：通过；Codex 自动/源码验收已通过，真实 UI 体验项已记录为非阻塞追踪
负责人：Codex 先验收可自动验证项；用户验收真实设备 / 真实 UI 体验项
准备日期：2026-06-12

## 验收范围

本清单用于验收 GAP-2 Phase 6.5：成员与珍贵档案删除进入 30 天回收站；宠物记录批量清空以一个批次恢复；单条高频流水仍走即时删除但写 CloudSync tombstone；普通产品入口不展示已回收对象。

## Codex 已验收

- [x] 已写入规则书。
  - 证据：`docs/specs/RecycleBin-logic.md` 已创建。
  - 结论：规则书覆盖软删语义、30 天保留、批量清空单批次、最终清理 tombstone、App reset 绕过回收站。

- [x] SwiftData schema 已升到最新 V69，且保持轻量迁移。
  - 证据：`AGENTS.md` 与 `Ohana/Models/SharedModelContainer.swift` 均指向 `ArkSchemaV69`；`ArkMigrationPlan.stages` 为空。
  - 测试：`OhanaTests/SharedModelContainerRecoveryTests.testCloudSyncTombstoneDefaultLandsOnLatestLightweightSchema` 与 `testV67StoreOpensThroughLatestLightweightMigrationWithoutLosingCloudSyncRecord`。
  - 结论：V67 旧库可通过最新 schema 打开，CloudSync 记录未丢失。

- [x] 成员删除改为源对象软删，且不会提前写最终删除 tombstone。
  - 测试：`OhanaTests/RecycleBinServiceTests.memberDeleteRestoreKeepsOriginalObjectAndAggregateEvents`、`OhanaTests/HomeCommandExecutorTests` 中成员删除相关用例。
  - 结论：`Pet` / `Human` / `Plant` 进入回收站后从普通入口隐藏，恢复后以原对象重新可见。

- [x] 珍贵档案进入回收站并保留原始 payload。
  - 测试：`OhanaTests/RecycleBinServiceTests.preciousArchiveDeleteRestorePreservesPayloads`；`HomeCommandExecutorTests` 中照片、文档、里程碑、保险删除用例。
  - 结论：照片、文档、里程碑、保单在回收期间保留原 id、附件 / 外部存储 payload 和关系。

- [x] 宠物记录批量清空作为一个回收站批次恢复。
  - 测试：`OhanaTests/PetActivityRecordCleanupServiceTests.cleanupMovesPetActivityFactsToSingleRecycleBatchAndRestoresThem`。
  - 结论：照护记录、事件与宠物 streak 元数据进入同一批次；恢复批次会恢复记录与宠物状态。

- [x] 单条高频流水仍即时删除，但在同步管线实体上写 tombstone。
  - 测试：`OhanaTests/RecycleBinServiceTests.finalPurgeWritesTombstoneOnlyAtPermanentDelete`、`OhanaTests/HomeCommandExecutorTests`、`OhanaTests/QuickWaterCommandTests`。
  - 结论：单条删除不出现在回收站 UI；最终删除语义仍可被未来同步消费。

- [x] 普通入口排除已回收对象。
  - 证据：Home、Members、Settings、FunctionMenu、FamilyReports、FamilyTasks、Documents、Insurance、Milestones、Moments、PetCare、Feeding、QuickCare 的查询或快照入口已过滤 `trashedAt` 或聚合隐藏已回收成员子数据。
  - 测试：`OhanaTests/HomeCommandExecutorTests` 与 `OhanaTests/SharedPetActionRecorderTests.deletingPetReconcilesSurvivingSharedFeedSessionStockOwner`。
  - 结论：已回收成员不会从普通列表、路由容器、喂食 / 快捷照护明细继续露出。

- [x] 回收站设置入口已添加，基础 UI 通过静态审计。
  - 证据：`Ohana/Features/Settings/Views/SettingsView.swift` 新增回收站入口；`Ohana/Features/Settings/Views/RecycleBinView.swift` 新增列表、恢复、清理过期与空态。
  - 命令：`scripts/module-exit-gate.sh`
  - 输出摘要：UI V4 audit、Accessibility audit 均通过 touched UI Swift 文件。
  - 结论：UI 代码符合当前静态门禁；真实点击体验列入人工项。

- [x] 备份导出 / 导入保留回收状态。
  - 测试：`OhanaTests/RecycleBinServiceTests.backupRoundTripsTrashStatesAndRecycleBatches`。
  - 结论：`trashStates` 与 `recycleBinBatches` 会随备份往返。

- [x] 定向测试通过。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/RecycleBinServiceTests -only-testing:OhanaTests/PetActivityRecordCleanupServiceTests`
  - 输出摘要：5 tests in 2 suites passed。
  - 命令：`DERIVED_DATA_PATH="${TMPDIR%/}/OhanaDerivedData/gap2-clean-home-command-tests" LOCK_DIR="/Users/guanchenli/Documents/Space/Ohana/.build/locks/test-gap2-clean-home-command-tests.lock" scripts/test-simulator.sh -only-testing:OhanaTests/RecycleBinServiceTests -only-testing:OhanaTests/PetActivityRecordCleanupServiceTests -only-testing:OhanaTests/HomeCommandExecutorTests -only-testing:OhanaTests/QuickWaterCommandTests`
  - 输出摘要：157 tests in 4 suites passed。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/SharedModelContainerRecoveryTests -only-testing:OhanaTests/SharedPetActionRecorderTests`
  - 输出摘要：`SharedModelContainerRecoveryTests` 4 个 XCTest 通过；`SharedPetActionRecorderTests` 21 个 Swift Testing 测试通过。

- [x] 模块退出门通过。
  - 命令：`scripts/module-exit-gate.sh`
  - 输出摘要：changed-file checks、runtime guardrails、localization coverage、full unit suite、UI tests 全部通过；full unit suite 为 700 tests in 55 suites passed，UI tests 为 3 tests passed。
  - 结论：GAP-2 当前实现达到自动门禁要求。

## 已记录的人工追踪项

以下项目需要真实 UI、真实设备数据或人眼遍历才能确认。根据 2026-06-12 验收决定，这些项目已记录在本 track list 中，不阻塞 GAP-2 标记通过。

- [ ] 在真实 UI 中打开设置页的“回收站”。
  - Codex 已验证：设置页入口与 `RecycleBinView` 已接入，静态 UI / a11y 审计通过。
  - 仍需人工原因：需要确认真实滚动位置、空态、按钮间距、弹窗关闭、不同语言下文本呈现。
  - 预期：设置页存在回收站入口；空回收站有得体空态；列表、恢复、清理过期按钮可理解。
  - 实际结果：

- [ ] 删除并恢复成员：宠物、家庭成员、植物。
  - Codex 已验证：命令测试覆盖软删、恢复、普通列表隐藏、active human 路由语义。
  - 仍需人工原因：需要确认真实 UI 删除确认文案、列表刷新、详情页返回、回收站条目标题。
  - 预期：删除后普通首页 / 成员入口不再显示该对象；回收站显示条目；恢复后原对象回到原入口。
  - 实际结果：

- [ ] 删除并恢复珍贵档案：照片、文档、里程碑、保单。
  - Codex 已验证：单测覆盖 payload / 关系保留与恢复。
  - 仍需人工原因：需要人眼确认附件缩略图、文档标题、里程碑卡片、保单详情恢复后的真实渲染。
  - 预期：删除后普通档案入口不显示；回收站可恢复；恢复后原内容与附件正常显示。
  - 实际结果：

- [ ] 清空宠物记录后从回收站恢复。
  - Codex 已验证：批量清空单测覆盖一个 batch、记录隐藏、streak 元数据恢复。
  - 仍需人工原因：需要确认真实 UI 的“清空记录”确认文案、回收站批次标题、恢复后的时间线 / 周报 / 记录列表表现。
  - 预期：回收站只出现一个“宠物记录”批次；普通时间线和周报不显示已回收记录；恢复后记录回到原视图。
  - 实际结果：

- [ ] 遍历首页 FAB、全功能菜单、成员选择器、设置页选择器。
  - Codex 已验证：路由容器、查询和命令入口已过滤回收对象。
  - 仍需人工原因：源码测试不能完全替代人眼遍历所有视觉入口、分组标题和空状态。
  - 预期：已回收成员不出现在任何新增操作、详情入口、选择器、菜单卡片或快捷照护目标中。
  - 实际结果：

- [ ] 遍历 Feeding / QuickCare 相关页面。
  - Codex 已验证：食物仪表盘、QuickCare 明细和库存计算入口已排除已回收成员及其子记录。
  - 仍需人工原因：需要确认真实页面的历史列表、库存数字、共享喂食摘要没有视觉残留。
  - 预期：已回收宠物的记录不出现在普通喂食 / 快捷照护页面；共享会话关系保留但不把已回收宠物暴露给普通入口。
  - 实际结果：

- [ ] 用真实备份 UI 做一次导出 / 导入回收状态验收。
  - Codex 已验证：备份 DTO 与导入导出单测覆盖 `trashStates` 和 `recycleBinBatches`。
  - 仍需人工原因：需要确认真实文件选择、导出 JSON、导入后 UI 刷新链路。
  - 预期：导入后回收站条目仍存在，恢复动作仍可用，普通入口仍隐藏回收对象。
  - 实际结果：

- [ ] 验收 30 天过期清理的真实 UI 表现。
  - Codex 已验证：服务层最终清理写 tombstone 且物理删除。
  - 仍需人工原因：真实 UI 需要构造过期数据或调试数据，确认按钮文案、清理反馈和列表刷新。
  - 预期：只清理已过期条目；未过期条目保留；清理后普通入口不会恢复已永久删除对象。
  - 实际结果：

- [x] 最终签署。
  - 结论：2026-06-12 按用户授权，Codex 已完成自动验收并将剩余真实 UI 项转入本 track list；GAP-2 标记通过。
  - 实际结果：通过；门禁 commit 为 `8bddfe1a6`。

## 余留项记录

- [x] 本轮没有发现需要写入 `docs/task-follow-ups.md` 的真实 blocker、跨范围修复或验证缺口。
- [ ] 如人工验收发现真实余留项，写入 `docs/task-follow-ups.md`。
