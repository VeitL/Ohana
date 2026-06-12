# GAP-4 Economy 总账恒等验收跟踪清单

状态：通过；Codex 自动 / 源码验收已完成，人工追踪项已列出
负责人：Codex 先验收可自动验证项；用户验收真实 UI / 正式包可达性项目
准备日期：2026-06-12

## 验收范围

本清单用于验收 GAP-4：宪法 D3/G2 的 Economy 总账恒等。首发正式口径为：正式岛屿总资产等于人类成员与宠物钱包余额之和；`system:legacy` 只作迁移兼容，不计入正式总资产、不进排行榜；账户余额与账本重放不一致时以账本为准自动修复；`legacyHistory` 只展示，不影响余额。

## Codex 已验收

- [x] 已写入规则书。
  - 证据：`docs/specs/Economy-logic.md` 已创建。
  - 结论：规则书覆盖 `system:legacy` 语义、账本重放、启动对账、排行榜口径、`legacyHistory` 非余额流水，以及开发余额测试工具的正式版边界。

- [x] 已写红测试证明旧行为不满足 GAP-4。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/CoconutWalletServiceTests`
  - 输出摘要：新增测试初跑失败；`testFormalIslandTotalExcludesLegacySystemCompatibilityBalance` 看到正式总资产 / 投影仍为 20 而期望 15；`testRefreshProjectionRepairsDriftedFormalAccountFromLedgerReplay` 看到漂移账户仍为 99 而期望账本重放 8。
  - 结论：红测试复现了 `system:legacy` 被计入正式总资产，以及刷新投影不修复账户漂移。

- [x] 钱包总账恒等测试通过。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/CoconutWalletServiceTests`
  - 输出摘要：`CoconutWalletServiceTests` 9 个 XCTest 通过。
  - 覆盖点：当前 schema in-memory 容器；legacy bootstrap 不双算旧历史；`system:legacy` 不计入正式总资产 / `QuestManager.coconutCount`；成员账户漂移按账本重放修复；负数余额被拒绝；重复 transaction key 被拒绝；财富页总资产与排行榜排除 `system:legacy`。

- [x] changed-file 门禁通过。
  - 命令：`scripts/dev-check-changed.sh`
  - 输出摘要：SwiftFormat 运行并格式化 1/4 个 Swift 文件；UI V4 audit、Accessibility audit、Smoothness risk audit、Runtime guardrails、Shared-care note metadata audit 均通过。
  - 结论：改动文件通过本地轻量门禁；命令建议最终跑构建 / 模块门禁，已列入下一项。

- [x] Oasis 旧余额夹具已按账本口径修正。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/OasisCritterDailyWishTests`
  - 输出摘要：`OasisCritterDailyWishTests` Swift Testing 18 个测试通过。
  - 结论：升级 / 唤醒用例的起始椰子余额先经过 bootstrap opening ledger，再验证扣款后投影刷新；符合“账本获胜”口径。

- [x] 模块退出门禁通过。
  - 命令：`scripts/module-exit-gate.sh`
  - 输出摘要：changed-file checks 通过；runtime guardrails 通过；localization coverage 通过；全量单元测试 706 个测试 / 56 个 suite 通过；UI tests 3 个测试通过；最终结果 `PASS — module may be committed`。
  - 结论：GAP-4 自动门禁通过，可以提交。

## 已记录的人工追踪项

以下项目需要真实 UI、迁移样本或正式包构建条件才能确认。根据 GAP-4 验收决策，这些项目记录在本 track list 中；自动门禁通过后不阻塞 GAP-4 标记通过。

- [ ] 真实迁移样本中，旧全岛余额差额不显示为正式总资产。
  - Codex 已验证：单元测试覆盖旧总数 20、成员钱包 10 + 5、`system:legacy` 5 时，正式总资产与投影为 15。
  - 仍需人工原因：需要真实历史数据或构造迁移样本，在 UI 中目检财富页 / 首页椰子展示。
  - 入口 → 操作 → 预期：安装带旧余额数据的构建 → 启动完成 bootstrap → 打开财富页；总资产显示成员 / 宠物钱包合计，不把历史系统差额加进去。
  - 实际结果：

- [ ] 财富页排行榜不出现“历史余额 / 系统账户”行。
  - Codex 已验证：`IslandWealthScreenModel` 单元测试覆盖人 / 宠 / `system:legacy` 三账户时，排行榜只包含人和宠。
  - 仍需人工原因：需要真实 UI 目检中文 / 英文 / 德语长文本、空数据和密集数据下的展示。
  - 入口 → 操作 → 预期：财富页 → 排行榜；只显示正式成员 / 宠物，不显示 `system:legacy` 或类似“历史余额”的行。
  - 实际结果：

- [ ] 椰子历史页总额不包含 `system:legacy`。
  - Codex 已验证：源码中历史页总额求和已排除 `ownerKind == system`。
  - 仍需人工原因：该总额是 UI 私有计算，需真实页面目检。
  - 入口 → 操作 → 预期：椰子历史页；顶部“当前椰子余额”与正式成员 / 宠物钱包合计一致，不包含历史系统差额。
  - 实际结果：

- [ ] 正式发布包中开发者余额测试工具不可达。
  - Codex 已验证：本轮已确认该工具是开发测试工具，不作为正式 Economy 语义；未把它纳入 GAP-4 修复。
  - 仍需人工原因：需要 release hardening / 正式包可达性检查确认设置页开发者工具不会进入首发用户路径。
  - 入口 → 操作 → 预期：正式配置构建 → 设置页遍历；不存在“椰子数量测试”等可直接改余额的开发工具入口。
  - 实际结果：

- [x] 最终签署。
  - 结论：自动验收通过；以下人工追踪项不阻塞 GAP-4 标记通过。
  - 实际结果：通过。

## 余留项记录

- [x] 本轮没有发现需要立即写入 `docs/task-follow-ups.md` 的真实 blocker。
- [ ] 如人工验收发现真实余留项，写入 `docs/task-follow-ups.md`。
