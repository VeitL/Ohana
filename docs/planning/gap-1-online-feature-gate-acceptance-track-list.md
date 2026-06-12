# GAP-1 联机功能门验收跟踪清单

状态：通过；Codex 自动/源码验收已通过，真实设备体验项已记录为非阻塞追踪
负责人：Codex 先验收可自动验证项；用户验收真实设备体验项
准备日期：2026-06-12

## 验收范围

本清单用于验收 GAP-1 Phase 6.5：首发版本保持单机、单主人、免费，且不存在任何可达的联机协作面。未来付费联机解锁只允许通过 `OnlineFeatureGate` 演进。

## Codex 已验收

- [x] 已写入规则书。
  - 证据：`docs/specs/OnlineFeatureGate-logic.md` 已创建。
  - 结论：规则书覆盖门的判定语义、收编清单、CKShare 被挡 UX、FamilyReports 切法、D9 EntitlementService 演进衔接。

- [x] `OnlineFeatureGate` 是首发联机功能的唯一判定点，且首发恒关闭。
  - 命令：`rg -n "case \\.onlineCollaboration|false" Ohana/Domain/Services/OnlineFeatureGate.swift`
  - 输出摘要：只命中 `case .onlineCollaboration` 与 `false`。
  - 结论：首发联机协作恒为关闭。

- [x] 没有发现第二套联机付费/在线判定语义。
  - 命令：`rg -n "onlineCollaboration" Ohana -g '*.swift'`
  - 输出摘要：命中点均为 `OnlineFeatureGate` 定义或入口调用点。
  - 结论：业务入口调用同一判定点，没有散落的在线开关判断。

- [x] 首页 / Today Focus / 成员名册协作入口已被门收编。
  - 证据：`HomeReadModelStore` 在 gate 关闭时不拉取 `FamilyCollaborationTask`；`HomeRouteCoordinator` 与 `AppRouteCoordinator` 将 `.collaboration` 降级到本地 `.members`；`CrewRosterRouteContainer` 在 gate 关闭时不挂载协作查询容器。
  - 测试：`OhanaTests/OnlineFeatureGateTests.homeFamilyTaskSurfacesAreFedOnlyThroughOnlineGate`
  - 结论：自动验证通过；真实界面视觉遍历仍列入人工项。

- [x] 全功能菜单中的悬赏榜入口已被门收编。
  - 证据：`AppFeatureRouteGuard` 对 `.bountyBoard` 返回 suppress；`FunctionMenuDestinationRouter` 与 `FeatureGroupDashboardView` 仅在 gate 打开时构造 `BountyBoardView`。
  - 测试：`OhanaTests/OnlineFeatureGateTests.routeGuardBlocksOnlineSurfacesButKeepsWeeklyReport`
  - 结论：悬赏榜不可达；照护周报保留。

- [x] 设置页云同步区块已被门收编。
  - 证据：`SettingsView` 仅在 `OnlineFeatureGate.allows(.onlineCollaboration)` 时挂载 `householdSyncSection` 与 `FamilyCollaborationPlaygroundView`；`SettingsView+CloudSync` 的操作入口先检查 gate。
  - 测试：`OhanaTests/OnlineFeatureGateTests.settingsAndShareAcceptanceAreGuardedByOnlineGate`
  - 结论：设置页联机同步入口不可达。

- [x] CKShare 接受路径已在接受分享前被门拦截。
  - 证据：`OhanaCloudSharingAppDelegate` 在 `acceptShare(metadata:)` 与 `cloudSync?.setEnabled(true)` 之前检查 `OnlineFeatureGate`。
  - 测试：`OhanaTests/OnlineFeatureGateTests.settingsAndShareAcceptanceAreGuardedByOnlineGate`
  - 结论：源码与测试证明不会先接受分享再提示。

- [x] Gate 关闭时，启动路径不会启动云同步引擎。
  - 证据：`AppServices.makeCloudSyncService()` 在 gate 关闭时返回 `LocalDeviceCloudSyncService`。
  - 测试：`OhanaTests/OnlineFeatureGateTests.launchCloudSyncServiceCannotEnableWhileGateIsClosed`
  - 结论：首发启动路径保持本地 no-op cloud service。

- [x] CKShare 被挡时有可见、得体提示文案。
  - 证据：`OnlineFeatureGateNoticeCenter` 提供提示标题与正文；`RootView` 订阅通知并弹出 alert。
  - 测试：`OhanaTests/OnlineFeatureGateTests.blockedShareNoticeHasVisibleLaunchCopy`
  - 结论：自动验证提示文案存在；真实分享链接触发仍列入人工项。

- [x] Day 0 Promise 旧悬赏承诺面没有首发入口。
  - 测试：`OhanaTests/OnlineFeatureGateTests.legacyDayZeroPromiseHasNoLaunchEntryPoint`
  - 结论：旧承诺面源码仍存在，但没有首发挂载入口。

- [x] 照护周报保留，悬赏榜被剥离。
  - 证据：`.familyWeeklyReport` 仍可见；`.bountyBoard` 被 route guard suppress；周报可见文案调整为照护贡献。
  - 测试：`OhanaTests/OnlineFeatureGateTests.routeGuardBlocksOnlineSurfacesButKeepsWeeklyReport`
  - 结论：自动验证通过；真实页面视觉确认仍列入人工项。

- [x] 目标测试通过。
  - 命令：`scripts/test-simulator.sh -only-testing:OhanaTests/OnlineFeatureGateTests -only-testing:OhanaTests/AppRouteCoordinatorTests -only-testing:OhanaTests/HomeRouteCoordinatorTests -only-testing:OhanaTests/CloudSyncMetadataServiceTests`
  - 输出摘要：144 tests in 4 suites passed。
  - 结论：门不变量、路由协调、CloudSync 内部未来引擎测试均通过。

- [x] 模块退出门通过。
  - 命令：`scripts/module-exit-gate.sh`
  - 输出摘要：changed-file checks、runtime guardrails、localization coverage、full unit suite、UI tests 全部通过；full unit suite 为 696 tests in 54 suites passed，UI tests 为 3 tests passed。
  - 结论：GAP-1 当前实现达到自动门禁要求。

## 已记录的人工追踪项

以下项目需要真实设备、真实 UI 或 iCloud 分享环境才能做人眼确认。根据 2026-06-12 验收决定，这些项目已记录在本 track list 中，不阻塞 GAP-1 标记通过。

- [ ] 在真实设备或可用 iCloud 测试环境中打开 / 接收 CKShare 分享邀请链接。
  - Codex 已验证：源码会在 `acceptShare` 与 `cloudSync.setEnabled(true)` 前拦截。
  - 仍需人工原因：当前会话没有真实分享链接、iCloud 分享发起端和可观察设备状态。
  - 预期：App 不加入共享家庭，不启用云同步，本机数据保持不变，并显示“联机协作即将推出”提示。
  - 实际结果：

- [ ] 在真实 UI 中遍历首页 FAB 与全功能菜单。
  - Codex 已验证：路由与目标测试证明 `.bountyBoard`、`.crewRoster(.collaboration)` 不可达。
  - 仍需人工原因：源码/测试无法完全替代人眼确认所有视觉入口、图标状态、文案呈现。
  - 预期：不出现 FamilyTasks、家庭协作、悬赏榜、发布协作任务入口。
  - 实际结果：

- [ ] 在真实 UI 中打开设置页并扫描所有可见区块。
  - Codex 已验证：设置页云同步区块与协作 playground 均被 gate 包住。
  - 仍需人工原因：需要确认实际构建中的分组、滚动区域和开发者工具入口无视觉残留。
  - 预期：不出现“家庭同步”、邀请家人、绑定 iCloud 身份、立即重试家庭同步、共享状态提示、家庭协作体验测试。
  - 实际结果：

- [ ] 在真实 UI 中打开照护周报。
  - Codex 已验证：周报 route 保留，悬赏榜 route 被隐藏，周报文案已改为照护贡献。
  - 仍需人工原因：需要人眼确认页面实际渲染、空状态、排行榜标题与周报内容没有悬赏/协作残留。
  - 预期：周报正常显示，不出现悬赏榜内容、悬赏排行榜、家庭协作排行榜。
  - 实际结果：

- [x] 最终人工签署。
  - 结论：2026-06-12 验收通过；上方真实设备 / 真实 UI 项保留为非阻塞追踪项。
  - 通过后动作：Codex 按 Conventional Commit 提交，scope 使用 `online-gate`；随后将 `docs/testing-progress.md` 中 GAP-1 更新为 🟢，补入门禁 commit 与交接备注。
  - 实际结果：通过，进入提交与总账回填。

## 余留项记录

- [ ] 如人工验收发现真实余留项，写入 `docs/task-follow-ups.md`。
- [ ] 如人工验收没有 meaningful follow-up，保持 `docs/task-follow-ups.md` 不变。
