# GAP-8 单成员形态验收 Track List

更新日期：2026-06-12

范围：单主人 / 单宠物首发形态下，Home 与 FamilyReports 相关家庭感展示不得暗示“多人类才完整”；周报、财富页、成员胶囊需要有得体的单成员展示。

## Codex 已自动验收

- [x] 规则书已落地：`docs/specs/SingleMemberFamilyShape-logic.md`，明确单人单宠是完整 Ohana，单人形态用“本周照护者 / 椰子账户 / 1 位成员”等非竞争语义。
- [x] 红测已确认旧逻辑会失败：`scripts/test-simulator.sh -only-testing:OhanaTests/SingleMemberFamilyShapePresentationTests` 首次运行失败，4 个测试执行，14 个断言命中旧问题，包括“照护贡献排行”“照顾最多”“本周之星”“财富榜”“1成员”。
- [x] 展示判定点已统一：`SingleMemberFamilyShapePresentation` 集中处理单成员展示语义；源码扫描显示旧竞争文案只保留在该判定点的多人分支和测试断言中。
- [x] 周报已接入判定点：单人形态下贡献区、故事摘要、分享文本、故事胶囊、最近动态空态均走非竞争文案；多人形态保留排行语义。
- [x] 财富页已接入判定点：单行账户展示为“椰子账户”，不显示第 1 名排名徽章和冠军光环；多人 / 多行仍保留财富榜。
- [x] 绿洲成员胶囊已接入判定点：中文显示“1 位成员 / 2 位成员”，英文显示“1 member / 2 members”。
- [x] 负面文案扫描通过：`rg -n "1成员|加人才完整|加人才解锁|一个人不够|添加更多人类成员才完整" Ohana docs --glob '!docs/archive/**'` 仅命中文档规则/盘点，不命中 app 源码。
- [x] 目标测试已转绿：`scripts/test-simulator.sh -only-testing:OhanaTests/SingleMemberFamilyShapePresentationTests` 通过，4 个测试通过。
- [x] changed-file gate 通过：`scripts/dev-check-changed.sh` 通过，包含 SwiftFormat、UI V4、Accessibility、Smoothness、Runtime guardrails、Shared-care metadata。
- [x] 模块退出门通过：`scripts/module-exit-gate.sh` 通过；changed checks、runtime guardrails、localization coverage、全量测试均绿。全量测试摘要：XCTest 15 个单元测试通过，Swift Testing 719 个测试通过，UI tests 3 个通过。
- [x] 范围确认：本轮未改 SwiftData schema、迁移、路由、启动路径、CloudKit、联机、分享接受路径或付费门。

## 需要人工目检

- [ ] 准备一人一宠本地数据，进入首页和全功能菜单，确认没有“添加更多人类成员才完整 / 解锁家庭感 / 一个人不够”等暗示。
- [ ] 打开家庭周报空态，确认最近动态文案为照护动态语义，而不是“全家动态”或多人竞赛暗示。
- [ ] 完成至少一次照护打卡后打开家庭周报，确认贡献区显示“本周照护者”，故事文案不出现“照护贡献排行 / 照顾最多 / 本周之星”。
- [ ] 在家庭周报点击分享，确认分享文本中的人物标签为“本周照护者”，不是“本周之星”。
- [ ] 打开 Ohana 财富页：当只有一个可展示账户行时，标题显示“椰子账户”，行首是完成徽章，不是第 1 名排名样式；若有两行及以上，仍可显示“财富榜”。
- [ ] 打开绿洲进度卡，确认家庭贡献胶囊中文显示“1 位成员”，没有“1成员”。
- [ ] 如有多人测试数据，补充回归目检：两名及以上人类成员时，周报贡献排行与财富榜仍保留排序语义。

## 结论

自动验收已通过。以上人工目检项不阻塞 GAP-8 标记为通过，用于产品主人最终确认真实数据下的屏幕观感。
