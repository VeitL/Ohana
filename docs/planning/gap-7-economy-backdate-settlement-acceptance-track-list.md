# GAP-7 补记结算验收 Track List

日期：2026-06-12

范围：宪法 D12 补记结算。补记历史照护记录时，照护事实保留用户选择的历史日期；椰子奖励的预算、冷却与钱包奖励流水按用户执行补记的操作日结算。首发版本不引入付费、联机或 CloudKit 语义。

## Codex 已自动验收

- [x] 规则书已更新到 `docs/specs/Economy-logic.md`。
  - 覆盖点：新增 ECO-009 / ECO-010 / ECO-011，明确照护事实历史日期、奖励预算/冷却操作日、钱包奖励流水操作日三条不变量。

- [x] 未改 SwiftData schema、路由、启动路径或 CloudKit 能力。
  - 证据：本轮代码改动只新增 `OhanaTests/EconomyBackdateSettlementTests.swift`；规则书和总账为文档改动。
  - 结论：GAP-7 是规则证明与测试补强，不启用任何远程同步或联机面。

- [x] Xcode 测试枚举确认 GAP-7 测试进入测试目标。
  - 命令：`xcodebuild -project Ohana.xcodeproj -scheme Ohana -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests -disableAutomaticPackageResolution -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO test -enumerate-tests -test-enumeration-style flat -test-enumeration-format text -test-enumeration-output-path - | rg -n "EconomyBackdate|backdatedCare"`
  - 输出摘要：枚举到 `OhanaTests/EconomyBackdateSettlementTests/backdatedCareRecordUsesOperationDayForBudget()` 与 `OhanaTests/EconomyBackdateSettlementTests/backdatedCareRecordUsesOperationTimeForCooldown()`。

- [x] 绿测证明“历史日期已触顶”不阻止操作日预算内补记奖励。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/EconomyBackdateSettlementTests`
  - 输出摘要：`EconomyBackdateSettlementTests` 2 tests / 1 suite passed。
  - 覆盖点：先把历史日期预算填到 `recordOnly`，再补记该历史日期；`PetCareLog.date` 与 `CareLedgerEvent.occurredAt` 保持历史日期，`EconomyBudgetUsageEvent` 与 `CoconutLedgerEntry` 使用操作日，奖励不被历史日期触顶拦掉。

- [x] 绿测证明冷却按操作时刻结算。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/EconomyBackdateSettlementTests`
  - 输出摘要：`EconomyBackdateSettlementTests` 2 tests / 1 suite passed。
  - 覆盖点：连续补记两个不同历史日期的喂食记录；第一条获得奖励，第二条命中操作时刻冷却，两个照护事实仍分别保留各自历史日期。

- [x] changed-file 门禁通过。
  - 命令：`scripts/dev-check-changed.sh`
  - 输出摘要：SwiftFormat 检查 `OhanaTests/EconomyBackdateSettlementTests.swift`，0 文件再格式化；changed-file 分类未建议 app build；行为测试已按建议执行。

- [x] 模块退出门禁通过。
  - 命令：`scripts/module-exit-gate.sh`
  - 输出摘要：changed-file checks、runtime guardrails、localization coverage 均通过；全量单元测试 `715 tests / 57 suites passed`；UI tests `3 tests passed`；最终结果 `PASS — module may be committed`。
  - 备注：Xcode 输出的 debugger snapshot、实体设备 `notification_proxy` 信息为环境噪声；命令目标仍为 iPhone 17 simulator。

## 人工追踪项

以下项目需要真实 UI 路径和人眼确认。根据当前验收策略，自动测试已覆盖核心业务不变量；这些项目记录为非阻塞追踪项，不阻塞 GAP-7 标记通过。

- [ ] 真实 UI 中创建一条历史日期的手动喂食补记，确认照护历史显示在所选历史日期，奖励反馈在当前操作时出现。
  - Codex 已验证：服务层 `PetCareLog` / `CareLedgerEvent` 历史日期与奖励流水操作日已通过单测。
  - 仍需人工原因：需要真实页面路径、日期选择器和奖励反馈视觉时机。
  - 入口 → 操作 → 预期：首页或喂食详情入口 → 选择过去日期并保存喂食 → 历史记录落在过去日期，当前操作日出现奖励反馈。
  - 实际结果：

- [ ] 真实 UI 中连续补记两条不同历史日期的喂食记录，确认第二条不会额外产出椰子，且页面仍保存照护事实。
  - Codex 已验证：服务层第二条命中操作时刻冷却，`reward == 0`，照护事实仍保存。
  - 仍需人工原因：需要真实奖励反馈文案/动效与记录刷新链路。
  - 入口 → 操作 → 预期：连续保存两条历史喂食补记 → 第一条有奖励，第二条显示冷却/无额外椰子语义，两个历史记录均存在。
  - 实际结果：

## 备注

- 本轮没有发现需要写入 `docs/task-follow-ups.md` 的真实 blocker、跨范围修复或产品豁免。
- 本轮没有更改生产逻辑；现有实现已符合 D12，本轮补齐规则书与不变量测试证明。
