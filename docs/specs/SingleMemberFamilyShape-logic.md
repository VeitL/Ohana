# SingleMemberFamilyShape 规则书（GAP-8 单成员形态）

确认日期：2026-06-12

本规则书覆盖产品宪法 G9：一个生命 + 主理人即完整家庭。首发单机 / 单主人 / 免费版本中，家庭感功能不得把“多个人类操作者”当作完整家庭前提。

## 已确认产品决定

- “家庭”不是“多个人类”的同义词；一个人和一只宠物就是完整 Ohana。
- 心情、周报、名册、连胜、财富与照护贡献等家庭感功能在单人单宠场景下必须成立。
- 多人竞争语义只在确有多个可见人类成员时出现；单人形态使用“主理人节奏 / 本周照护者 / 椰子账户”等自洽文案。
- 不出现“添加更多人类成员才完整”“加人才解锁家庭感”“一个人不够”等暗示。
- 本轮不启用联机、邀请、指派、悬赏或 CloudKit；多人多设备协作仍由 `OnlineFeatureGate` 控制。

## 业务不变量

- SMF-001：单人单宠仍是完整家庭；家庭感入口不得因为 `humans.count <= 1` 显示残缺、锁态或“添加更多人类成员”引导。
- SMF-002：周报在单人形态下保留照护周报，但“照护贡献排行 / 本周之星 / 照顾最多”等竞争语义降级为“本周照护者 / 主理人节奏 / 记录了本周照护”。
- SMF-003：财富页在只有一个可展示账户行时不显示“财富榜”或第 1 名竞争样式，改为“椰子账户”。
- SMF-004：成员计数胶囊使用自然可读的单复数文案；单成员不得显示生硬的“1成员”。
- SMF-005：多人形态仍保留贡献排行、财富榜与排序能力；GAP-8 只补单成员降级展示，不删除多成员分析价值。

## 当前代码来源

- 周报聚合与分享文案：`Ohana/Features/FamilyReports/Views/FamilyWeeklyReportDashboardView.swift`。
- 财富页排行榜：`Ohana/Features/Economy/Views/IslandWealthDashboard2.swift` 与 `Ohana/Features/Economy/IslandWealthViewModel2.swift`。
- 绿洲 / 首页家庭贡献计数胶囊：`Ohana/Features/Oasis/Views/OasisProgressMilestoneCards.swift`。
- 顶部成员入口与成员名册：`Ohana/Features/Home/Views/FocusHomeHeaderView.swift`、`Ohana/Features/CrewRoster/Views/CrewRosterOverlay.swift`。

## 判定点

`SingleMemberFamilyShapePresentation` 是本轮统一展示判定点，负责把“单人可见家庭”降级为非竞争文案。它不读取 SwiftData、不判断付费、不触发路由，也不改变业务事实。

## 边界

- 本轮不改 SwiftData schema。
- 本轮不改启动路径、通知调度、CloudKit、联机或分享能力。
- 本轮不处理 GAP-9 离世退场；离世成员是否计入家庭形态由 GAP-9 规则书继续细化。
- 真机 UI 目检项记录在统一验收总表 `docs/planning/gap-acceptance-track-list.md#gap-8-单成员形态`；自动测试覆盖展示策略不变量。
