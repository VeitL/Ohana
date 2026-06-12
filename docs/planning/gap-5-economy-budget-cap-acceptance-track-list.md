# GAP-5 Economy 触顶感知验收跟踪清单

状态：通过；Codex 自动 / 源码验收已完成，真实 UI 与长语言视觉项已记录为非阻塞追踪
负责人：Codex 先验收可自动验证项；用户验收真实 UI / 多语言视觉项目
准备日期：2026-06-12

## 验收范围

本清单用于验收 GAP-5：当每日椰子预算进入 `recordOnly` 触顶状态时，照护记录仍应照常完成；奖励反馈位置显示温和、透明、九语言可用的触顶文案，不展示剩余额度、预算数字或说教式解释。首发版本不引入付费、联机或 CloudKit 语义。

## Codex 已验收

- [x] 已写入规则书。
  - 证据：`docs/specs/Economy-logic.md` 已补充 ECO-008。
  - 结论：规则书覆盖 `recordOnly` 触顶时“记录照常完成 + 温和满载文案 + 不展示预算数字 / 剩余额度”的产品语义，并明确本轮不改 schema、不启用 CloudKit。

- [x] 已写红测试证明旧行为不满足 GAP-5。
  - 命令：`rm -rf /var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests && scripts/test-simulator.sh -only-testing:OhanaTests/OhanaTests`
  - 输出摘要：新增断言初跑失败；`coconutEconomyV2DailyBudgetUsesFatigueBeforeRecordOnly` 实际文案为“今日椰子预算已满，记录已保存 +2XP”，期望“今日椰子已装满，明天继续～”，且不应包含“预算”或数字 `2`。
  - 结论：红测试复现了旧触顶文案过硬、暴露预算语义和 XP 数字的问题。

- [x] `recordOnly` 裁决文案已覆盖九语言。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/OhanaTests`
  - 输出摘要：`OhanaTests/OhanaTests` 128 个 Swift Testing 测试通过。
  - 覆盖点：`recordOnly` 仍为 0 椰子 / 2 growth XP；中文、英文、德文、西班牙文、葡萄牙文、法文、日文、韩文、意大利文触顶文案均有断言；中文文案不包含“预算”或数字 `2`。

- [x] 奖励反馈中心不会因为 0 椰子触顶事件丢弃提示。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/OhanaTests`
  - 输出摘要：新增 `coconutRewardFeedbackCenterSurfacesRecordOnlyMessageWithoutCoconuts` 通过。
  - 结论：`amount == 0`、`growthXP == 2`、`budgetStage == recordOnly` 的事件仍会进入 `CoconutRewardFeedbackCenter.activeEvent`，奖励反馈位置可显示温和触顶标题。

- [x] 反馈 UI 已为长语言做静态适配。
  - 证据：`Ohana/Features/TodayFocus/Views/CheckInRewardFeedback.swift` 中触顶标题允许最多两行、可轻微缩放，并保持 leading 对齐。
  - 结论：长语言不会被强制单行截断；真实设备多语言目检列入人工追踪。

- [x] changed-file 门禁通过。
  - 命令：`scripts/dev-check-changed.sh`
  - 输出摘要：SwiftFormat 运行 3 个 Swift 文件且 0 文件再格式化；UI V4 audit、Accessibility audit、Smoothness risk audit、Runtime guardrails、Shared-care note metadata audit 均通过；命令建议目标测试，已执行。
  - 结论：改动文件通过本地轻量门禁。

- [x] 模块退出门禁通过。
  - 命令：`scripts/module-exit-gate.sh`
  - 输出摘要：changed-file checks 通过；runtime guardrails 通过；localization coverage 通过；全量单元测试 707 个测试 / 56 个 suite 通过；UI tests 3 个测试通过；最终结果 `PASS — module may be committed`。
  - 结论：GAP-5 自动门禁通过，可以提交。

## 已记录的人工追踪项

以下项目需要真实 UI、真实语言环境或人眼视觉判断才能确认。根据验收决策，这些项目记录在本 track list 中；自动门禁通过后不阻塞 GAP-5 标记通过。

- [ ] 真实 UI 中触发每日预算 `recordOnly` 后，照护记录仍保存成功。
  - Codex 已验证：策略层保持 `recordOnly.totalCoconuts == 0`、`growthXP == 2`、`reason == dailyBudgetRecordOnly`，反馈事件不会被丢弃。
  - 仍需人工原因：需要真实页面连续操作到当日触顶状态，确认记录列表 / 首页反馈 / 数据刷新链路。
  - 入口 → 操作 → 预期：首页或照护入口 → 连续完成照护直到触顶 → 再执行一次照护；记录保存成功，页面不报错、不提示失败。
  - 实际结果：

- [ ] 真实 UI 奖励反馈显示温和触顶标题。
  - Codex 已验证：中文策略文案为“今日椰子已装满，明天继续～”，不含“预算”或数字 `2`。
  - 仍需人工原因：需要人眼确认奖励 pill / toast 的真实位置、出现时机和动效。
  - 入口 → 操作 → 预期：触顶后完成一次照护；奖励反馈标题显示“今日椰子已装满，明天继续～”，不出现“预算”“剩余额度”“今日还能得 X 个椰子”等解释。若旁边仍显示 growth XP 数值，它只作为成长奖励数值，不应进入触顶说明标题。
  - 实际结果：

- [ ] 九语言长文本在真实 UI 中不截断、不重叠。
  - Codex 已验证：策略层九语言断言通过，反馈标题最多两行并可缩放。
  - 仍需人工原因：需要在真实语言、动态字号、窄屏宽度下目检。
  - 入口 → 操作 → 预期：切换英文、德文、法文、日文、韩文等语言 → 触发 `recordOnly` 奖励反馈；标题不溢出、不遮挡数值、不与图标重叠。
  - 实际结果：

- [ ] Reduce Motion / Low Power Mode 下触顶反馈仍可理解。
  - Codex 已验证：本轮未新增 runtime loop，也未改变奖励反馈中心的生命周期。
  - 仍需人工原因：需要系统设置状态和真实动画体验。
  - 入口 → 操作 → 预期：开启 Reduce Motion 或 Low Power Mode → 触发 `recordOnly`；反馈可以减少动效，但文案仍出现且可读。
  - 实际结果：

- [x] 最终签署。
  - 结论：自动验收通过；以上人工追踪项不阻塞 GAP-5 标记通过。
  - 实际结果：通过。

## 余留项记录

- [x] 本轮没有发现需要立即写入 `docs/task-follow-ups.md` 的真实 blocker、跨范围修复或验证缺口。
- [ ] 如人工验收发现真实余留项，写入 `docs/task-follow-ups.md`。
