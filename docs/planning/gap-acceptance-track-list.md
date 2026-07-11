# 人工验收总 Track List

更新日期：2026-06-30

本文件是 GAP 建设阶段与模块门禁阶段唯一的人工验收 track list。后续不再新增 `gap-*-acceptance-track-list.md` 或模块单独 track list；需要人工目检、真机、真实 iCloud、真实通知或真实数据确认的项目，都追加到本文对应小节。

自动测试、源码审计和门禁结论记录在 `docs/testing-progress.md` 与各模块规则书中；本文只保留足够让产品主人逐项验收的清单和关键自动验收摘要。

真机执行时优先使用 `docs/release-true-device-test-plan.md`。该文件把本文的长验收项整理成“已测过 / 真机还要测 / 通过标准 / 记录”的中文执行视图；本文仍保留详细验收记录和最终人工验收状态。

当前产品删除模型以 `docs/specs/product-foundation.md` D8/D16、`docs/specs/RecycleBin-logic.md` 和各模块规则书为准：用户可见回收站、30 天恢复窗口和可恢复软删除已退役；删除是明确确认后的不可恢复物理删除，CloudSync 只可保留用户不可见、不可恢复的 sync tombstone 元数据。

## 总览

| 项目 | 状态 | 门禁 commit | 自动验收摘要 | 人工验收状态 |
|---|---|---|---|---|
| GAP-1 联机功能门 | 🟢 | `59b5ceedc` | `OnlineFeatureGate` 不变量、路由/设置/CKShare 接受路径、`scripts/module-exit-gate.sh` 均通过 | 待真实设备 / 真实 UI 抽查 |
| GAP-2 删除模型（原回收站退役） | 🟢 | `be0dd1eeb` / `8f6c792dc` recheck | 用户可见回收站退役；成员、档案与业务记录经 `PhysicalDeletionService` 写不可见 sync tombstone 后物理删除；全仓 gate / CI 复验通过 | 待真实 UI / 真机通知抽查 |
| GAP-3 自动备份 | 🟢 | `9b1ac1be1` | 自动备份服务、生命周期触发、App reset、plist/entitlements、Debug build、`scripts/module-exit-gate.sh` 均通过 | 待真机 iCloud Drive 抽查 |
| GAP-4 总账恒等 | 🟢 | `1951f7834` | 钱包总账恒等、`system:legacy` 排除、账本重放修复、Oasis 夹具、`scripts/module-exit-gate.sh` 均通过 | 待真实迁移样本 / 正式包抽查 |
| GAP-5 触顶感知 | 🟢 | `1a775bc7c` | `recordOnly` 九语言文案、反馈中心、changed gate、`scripts/module-exit-gate.sh` 均通过 | 待真实 UI / 长语言抽查 |
| GAP-6 通知分级 | 🟢 | `6bb766cc3` | 通知预算、夜间免打扰、合并、关键提醒豁免、周报语义、`scripts/module-exit-gate.sh` 均通过 | 待真机通知抽查 |
| GAP-7 补记结算 | 🟢 | `528cf2cdd` | 补记历史日期与操作日奖励结算测试、changed gate、`scripts/module-exit-gate.sh` 均通过；2026-06-30 补上手动喂食补记 UI 日期入口、执行器 backdate 传参测试、以及模拟器 UI 自动化两条历史日期保存/回读预检 | 待真实 UI 手选历史日期补记路径抽查 |
| GAP-8 单成员形态 | 🟢 | `6c4a98db2` | 单成员展示红绿测试、负面文案扫描、route 首帧硬门、changed gate、`scripts/module-exit-gate.sh` 均通过 | 首建人类、首宠、Home Oasis 五次注入 Lv0 -> Lv1、Settings 真机自动 smoke 已过；剩余为普通人工文案/菜单抽查 |
| GAP-9 离世退场 | 🟢 | `e6a45e72c` | 纪念模式规则书、未来计划可逆退场、离世成员活跃入口过滤、奖励冻结定向测试、changed gate、`scripts/module-exit-gate.sh` 均通过 | 待真实 UI / 真机通知抽查 |
| GAP-12 植物功能门 | 🟢 | `a1e0e0376` / `8f6c792dc` recheck | `PlantFeatureGate` 不变量、添加/路由/FunctionMenu、quest 引擎、心情信号、Oasis 植物历史隔离、`scripts/module-exit-gate.sh --full` 与 CI 均通过 | 待真实 UI 抽查 |
| Phase 6 Members | 🟢 | `ead1e5fe4` / `8f6c792dc` recheck | 创建派生日历事实 sync metadata；成员删除进入不可恢复物理删除 + sync tombstone；RequiredHumanProfileView a11y；全仓 gate / CI 复验通过 | 待真实 UI 抽查 |
| Phase 6 Oasis | 🟢 | `87423afd8` + 2026-07-11 repair | 生命树使用正式岛屿总额且支持无 Human；其他成员型 Oasis 消费保留当前主人钱包门；预算 / 冷却、休眠态救援、UI/a11y/smoothness/runtime 审计与窄测试通过 | 新签名 Release 覆盖安装后的旧 59🥥 样本注入待真机确认 |
| Phase 6 Settings + Health | 🟢 | `5d4e71928` / `8f6c792dc` recheck | Debug-only 设置开发工具、真实通知开关策略、Health 物理删除 + tombstone/read-only 不变量、目标测试与全仓 gate / CI 复验通过 | 待 Release 真机 / 真实 UI 抽查 |
| Phase 6 Economy | 🏁 | `92133da2a` / `8f6c792dc` recheck | 兑换入口首发门禁、冻结钱包写入拒绝、特殊奖励 active human 归属、隐私 / 冻结财富口径；最终纯复审 P0/P1/P2=0；全仓 gate / CI 复验通过 | 待真实 UI 抽查 |
| Phase 7 Walks | 🟢* | `e0c1d69d3` / `8f6c792dc` recheck | `WalkFeaturePolicy` active dog 硬门、删除/离世过滤、遛狗中便便事实+ledger、共享遛狗服务适配器、全仓 gate / CI 复验通过 | 待真机定位 / 真实 UI 抽查 |
| Phase 7 Gacha + Shop | 🟢* | `92763c164` / `8f6c792dc` recheck | 扭蛋概率/区间、合资抽取、冻结钱包、Shop 定价/汇率、购买合资、SwiftData 所有权迁移、备份恢复、Gacha/Shop CloudSync serializer/applier 与 schema 迁移目标测试均通过 | 待真机 App Icon / 真实 UI 抽查 |
| Phase 7 其余中小模块 smoke | 🟢* | `8f6c792dc` | Medication、FamilyTasks、Expenses、Calendar、CrewRoster、Documents、Insurance、Privacy、Security、CareLedger 等模块已过全仓 gate / CI；人工债集中到本文合并 smoke 小节 | Onboarding 首发核心链路真机自动 smoke 已过；CrewRoster / FunctionMenu / 其余真实 UI 抽查继续推进 |

## GAP-1 联机功能门

人工验收目标：首发版本无任何可达联机协作面；收到分享邀请时被得体拦截。

- [ ] 在真实设备或可用 iCloud 测试环境中打开 / 接收 CKShare 分享邀请链接。
  - 预期：App 不加入共享家庭，不启用云同步，本机数据保持不变，并显示“联机协作即将推出”提示。
  - 记录：

- [ ] 在真实 UI 中遍历首页 FAB 与全功能菜单。
  - 预期：不出现 FamilyTasks、家庭协作、悬赏榜、发布协作任务入口。
  - 记录：

- [ ] 在真实 UI 中打开设置页并扫描所有可见区块。
  - 预期：不出现“家庭同步”、邀请家人、绑定 iCloud 身份、立即重试家庭同步、共享状态提示、家庭协作体验测试。
  - 记录：2026-06-16 真机首测发现点击首页设置按钮闪退。处理：将 `AppSettingsSheetRouteContainer` 从 sheet 构建期同步 `@Query` 多张表改为页面出现后一帧受控 `ModelContext.fetch`，单表失败降级为空数据并记录 warning；`SettingsView` 生物识别能力探测从 `@State` 初始化延后到 `onAppear`，避免设置入口首帧同时做 SwiftData / LocalAuthentication 工作。新增 `SettingsRouteContainerTests` 锁住 Settings route 不再回退为同步 `@Query`。注意：本地 `scripts/test-simulator.sh -only-testing:OhanaTests/SettingsRouteContainerTests` 与 `scripts/build-debug-fast.sh` 均卡在 xcodebuild 收尾/等待阶段后被中止，未取得自动验证结论；下一轮真机需优先复测“首页设置按钮可打开且不闪退”，再继续扫描联机协作入口。
  - 记录：2026-06-17 真机复测仍发现点击设置页闪退。根因修正：上一轮只把 SwiftData fetch 延后，但 `AppSettingsSheetRouteContainer` 在 `data.hasLoaded == false` 时仍会先构建完整 `SettingsView`，导致 CloudSync / backup / sheet host / onAppear 探测等设置树在路由首帧被挂载；这违反轻交互首帧规则，也解释了为什么“延后 fetch”仍不能彻底挡住真机闪退。处理：为设置 sheet 增加轻量 `SettingsRouteLoadingView`，完整 `SettingsView` 只允许在 `SettingsRouteData.hasLoaded` 后构建，loading 状态仍保留关闭按钮。自动验证：`scripts/test-simulator.sh -only-testing:OhanaTests/SettingsRouteContainerTests -only-testing:OhanaTests/VerticalHomeTabMountPolicyTests` 在 iPhone 17 simulator 通过两次，`SettingsRouteContainerTests` 锁住 `if data.hasLoaded` 与 loading shell。关闭条件：真机重新 build 后点击设置页不闪退，并能继续完成联机入口扫描。
  - 记录：2026-06-17 同日真机复测发现上一条 loading shell 方案会停在 “Opening settings”。根因再修正：设置页可达性不应依赖 Household / Pet / Human / OasisElectronicPet 四张表 fetch 完成；这些数据只服务“设备身份 / 宠物管理 / 家庭同步”低频区块。把完整 `SettingsView` 挂在 `data.hasLoaded` 后面，是用一个 loading gate 替代了原始首帧问题，制造了新阻塞。最终处理：`AppSettingsSheetRouteContainer` 始终先呈现 `SettingsView`，数据数组初始为 nil；数据区在页面可用后异步补齐；`homeRevisionUpdates` 只 coalesce 加载，不再 cancel / restart 运行中的加载任务。自动验证：`scripts/test-simulator.sh -only-testing:OhanaTests/SettingsRouteContainerTests` 在 iPhone 17 simulator 通过，测试锁住“不出现 `SettingsRouteLoadingView` / `if data.hasLoaded` 阻断完整设置页”以及 `dataLoadTask` coalescing。关闭条件：真机点击设置按钮后应直接进入设置页；数据身份 / 宠物管理区可以稍后出现，但页面不能停在 opening shell。

- [ ] 在真实 UI 中打开照护周报。
  - 预期：周报正常显示，不出现悬赏榜内容、悬赏排行榜、家庭协作排行榜。
  - 记录：

## GAP-2 删除模型（原回收站退役）

人工验收目标：删除必须是明确确认后的不可恢复物理删除；普通入口不再出现已删除对象；用户不可看到回收站、恢复窗口、30 天清理或删除中转态。

自动验收已完成并在 2026-06-16 全仓复验：用户可见回收站退役；`PhysicalDeletionService` 统一 tombstone+delete；旧 V69/V70 回收字段只为 store compatibility 保留；`scripts/module-exit-gate.sh --full` 与 CI run `27607807044` 均通过。

- [ ] 在真实 UI 中扫描设置页、全功能菜单、首页 FAB、成员详情危险区。
  - 预期：不存在“回收站”、恢复、30 天清理、已删除中转态入口；删除入口必须有不可恢复确认语义。
  - 记录：

- [ ] 删除成员：宠物、人类成员、植物。
  - 预期：确认后对象立即退出首页、成员入口、选择器、详情入口、快捷照护目标和全功能菜单；没有恢复 UI；再次进入 App 后仍不出现。
  - 记录：
  - 记录：2026-06-17 真机手测新增 P0：在宠物基础资料危险区点击“彻底删除 xxx”后卡死。根因按首帧/手指帧模型重判：删除确认 sheet、route dismiss、keyboard focus 和 `PhysicalDeletionService` 级联物理删除同帧竞争，UI 尚未先退回稳定路由就开始重删除；同类风险也存在宠物卡背、人类详情和 CrewRoster 删除入口。处理：新增 `DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds`，所有成员永久删除入口先关闭 sheet/detail/overlay，再延迟提交 `MemberCommandExecutor.deletePet/deleteHuman`；宠物删除确认不再自动拉起键盘；补稳定 UI test identifiers，并在宠物全功能 Archive 区补“基础资料 / Profile”入口，避免测试只能靠不稳定导航。验证：`scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testPetPermanentDeleteFromBasicInfoSmoke` PASS（iPhone 17 simulator，52.207s，xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.17_22-44-42-+0200.xcresult`），覆盖首建主人、starter gift、首建宠、进基础资料、点击彻底删除、输入宠物名确认、回到可响应首页且宠物卡消失。关闭条件：真机同一路径二次确认不卡死。
  - 记录：2026-06-18 Codex 真机自动化二次验收未能关闭该项。第一次运行 `xcodebuild test -allowProvisioningUpdates -project Ohana.xcodeproj -scheme Ohana -configuration LocalDeviceDebug -destination 'id=00008150-001270342EA3401C' -derivedDataPath /tmp/ohana-device-gap2-delete -only-testing:OhanaUITests/OhanaUITests/testPetPermanentDeleteFromBasicInfoSmoke CODE_SIGNING_ALLOWED=YES` 在测试 runner 初始化前失败：`Timed out while enabling automation mode`，xcresult `/tmp/ohana-device-gap2-delete/Logs/Test/Test-Ohana-2026.06.18_09-48-25-+0200.xcresult`。第二次运行同路径、DerivedData `/tmp/ohana-device-gap2-delete-retry` 已进入 Ohana，约 190s 后 CoreDevice/XCTest 才完成 automation session setup；session 建好后 onboarding 元素很快可见，并已输入首个人类名称，但随后 CoreDevice/Mercury 远程连接失效：`An error occurred while communicating with a remote process`，xcresult `/tmp/ohana-device-gap2-delete-retry/Logs/Test/Test-Ohana-2026.06.18_09-52-14-+0200.xcresult`。结论：这不是删除确认行为 PASS；关闭条件仍保持“真机同一路径二次确认不卡死”，并额外记录真实设备 XCTest/无线 CoreDevice 自动化不稳定，需手动或有线自动化复测。
  - 记录：2026-06-19 用户真机复测确认宠物删除后不再卡死，但返回首页后卡片堆会全部消失，来回切换 tab 后才恢复。根因：删除当前展开 / 上下文宠物卡后，`VerticalSolidHomeWalletStack` 内部 `selectedCardId` 仍指向已删除卡；Home scene 仍处于 expanded hero progress，剩余卡片被当作非选中卡淡到 0，因此看起来全部消失。处理：新增 `FocusHomeCardDataSource.selectionReconciliation`，卡片集合变更时如果 selected/header context id 已不在当前 cards 中，立即无动画清理 selected card、hero snapshot、hero progress、header context 和 expanded 状态；新增 `homeCardSelectionReconciliationClearsDeletedSelectedCard` 测试锁住策略。关闭条件更新：真机删除宠物后应立即回到稳定首页，剩余人类 / 宠物卡不用切 tab 就可见且可点击。

- [ ] 真机允许通知后，删除带未来提醒的成员或事件。
  - 预期：确认删除后对应未来本地通知被取消或不再到达；App 内不保留可恢复 pending 提醒；不会出现删除后通知仍跳回已删除对象。
  - 记录：

- [ ] 删除珍贵档案：照片、文档、里程碑、保单。
  - 预期：确认删除后普通档案入口、相册、时间线、保单/里程碑页面不再显示；没有恢复或回收站入口；其他未删除档案不受影响。
  - 记录：

- [ ] 清空宠物记录。
  - 预期：已故宠物清空记录路径为 no-op；活跃宠物清空后普通时间线、周报和照护统计不再显示被清空记录；没有批次恢复入口。
  - 记录：

- [ ] 遍历首页 FAB、全功能菜单、成员选择器、设置页选择器。
  - 预期：已删除成员不出现在任何新增操作、详情入口、选择器、菜单卡片或快捷照护目标中。
  - 记录：

- [ ] 遍历 Feeding / QuickCare 相关页面。
  - 预期：已删除宠物不出现在普通喂食 / 快捷照护页面；历史共享会话不得把已删除宠物暴露给普通入口。
  - 记录：

- [ ] 用真实备份 UI 做一次删除后导出 / 导入验收。
  - 预期：导入后已删除对象不复活；备份恢复不会重新创建回收站条目或恢复按钮；未删除对象与记录正常保留。
  - 记录：

- [ ] 验收旧安装样本或历史数据中的 legacy recycle 字段。
  - 预期：旧字段不导致 UI 出现回收站、恢复窗口或删除中转态；普通入口仍只展示当前存在且 active 的对象。
  - 记录：

## GAP-3 自动备份

人工验收目标：自动备份在真实 iCloud Drive / Files App 中可见、可关闭、失败可见，且手动备份能力不回归。

- [ ] 真机登录 iCloud 后，自动备份能写入 Files / iCloud Drive。
  - 预期：设置 → 数据备份 → 自动备份开启 → 点“立即备份”；Files App / iCloud Drive 中可见 `Ohana/Ohana Backups/Ohana Automatic Backup.json`，设置页显示“上次成功”。
  - 记录：

- [ ] 关闭自动备份后不会自动写入。
  - 预期：关闭“自动备份”后杀进程重进 / 进后台；设置页保持“已关闭”，不会更新时间或写新文件。
  - 记录：

- [ ] iCloud 不可用时失败可见。
  - 预期：退出 iCloud 或关闭 iCloud Drive 后点击“立即备份”；设置页显示失败，不崩溃、不假成功，本机数据不变。
  - 记录：

- [ ] iCloud 空间不足 / 写入失败时降级得体。
  - 预期：设置页显示失败原因，后续可重试，不阻断普通使用。
  - 记录：

- [ ] 自动备份文件可用于真实 UI 恢复。
  - 预期：生成自动备份 → 重置 App → 从 iCloud Drive 选择 `Ohana Automatic Backup.json` 恢复；成员、宠物和记录恢复，PIN hash/salt 不出现在文件内容中。
  - 记录：

- [ ] 手动导出 / 加密导出仍可用。
  - 预期：手动生成备份与分享可用；恢复加密备份要求密码，密码错误有提示。
  - 记录：

- [ ] App reset 后自动备份关闭，Ohana 管理的自动备份文件被尝试清理。
  - 预期：重置后自动备份为关闭状态，Ohana 管理的自动备份文件被删除或系统稍后同步删除，手动导出的其他文件不受影响。
  - 记录：

- [ ] 真实 UI 目检设置页备份区块。
  - 预期：自动备份、手动导出、密码加密、从备份恢复各行不重叠、不遮挡，按钮可点，失败提示得体。
  - 记录：

## GAP-4 总账恒等

人工验收目标：正式岛屿总资产只等于人类成员 + 宠物钱包；历史兼容账户不进正式资产、排行榜或余额 UI。

- [ ] 真实迁移样本中，旧全岛余额差额不显示为正式总资产。
  - 预期：打开财富页后，总资产显示成员 / 宠物钱包合计，不把历史系统差额加进去。
  - 记录：

- [ ] 财富页排行榜不出现“历史余额 / 系统账户”行。
  - 预期：排行榜只显示正式成员 / 宠物，不显示 `system:legacy` 或类似“历史余额”的行。
  - 记录：

- [ ] 椰子历史页总额不包含 `system:legacy`。
  - 预期：顶部“当前椰子余额”与正式成员 / 宠物钱包合计一致，不包含历史系统差额。
  - 记录：

- [x] 首页顶部椰子按钮显示正式岛屿总余额，并随成员钱包变化刷新。
  - 预期：普通首页顶部椰子按钮显示人类成员 + 宠物钱包总和；创建额外人类只是新增成员卡，不自动切换当前主人，也不让顶部数字跳到新成员个人余额。展开某张成员卡时，顶部可临时显示该卡余额；普通态点击顶部椰子按钮打开全量椰子历史。
  - 记录：2026-06-18 真机手测新增 P1：建立第二个人类后，首页顶部椰子数按钮显示的椰子数量不对。根因：成员新增成功回调在 `AddEntityDestinationView`、Home sheet wrapper 和根 `ContentView` 三层都可能写 `currentActiveHumanId`，其中根回调会把当前主人强制切到新建人类；同时 Header 普通态仍按 active human 钱包口径显示，而不是正式岛屿总余额。处理：新增 `ActiveHumanSelectionPolicy.activeHumanIdAfterCreatingHuman`，统一规则为“只有当前选择为空时，首个人类创建才设为 active；新增额外人类不切换 active human”，并让上述三层保存回调全部消费同一 policy；Header 普通态改为显示人类 + 宠物钱包总和，普通态点击打开全量椰子历史。自动验证：`scripts/dev-check-changed.sh` PASS；`git diff --check` PASS；`scripts/test-simulator.sh -only-testing:OhanaTests/ActiveHumanSelectionPolicyTests` PASS（iPhone 17 simulator，2 tests）。关闭条件：真机建立第二个人类后，顶部椰子数量仍为正式岛屿总余额；账户切换只改变当前主人上下文，不把顶部普通态改成单人余额。
  - 记录：2026-06-18 真机手测新增 P1：宠物获得 1 个椰子后，椰子历史能看到流水，但首页顶部椰子按钮和宠物卡片都看不到更新。根因：`CoconutLedgerEntry` 已成功写入，`QuestManager.recordWalletProjection` 也更新了历史投影，但 `publishCoconutProjectionRevision` 只写 performance log，没有发布任何 Home 可监听的 read-model invalidation；因此纯钱包投影变化可能不会触发 Home payload 重取。处理：`ReadModelRevisionCenter` 新增独立 wallet projection revision，`QuestManager` 在钱包投影变化时发布受影响成员 id，Home data container 监听该 revision 并用既有 260ms coalescing 刷新 read model，避免污染 command mutation revision 计数。自动验证：新增 `CoconutWalletServiceTests.testWalletProjectionPublishesWalletRevisionWithoutCommandMutation` 覆盖钱包投影推进 wallet revision、但不推进 Home command revision；`scripts/dev-check-changed.sh` PASS；`git diff --check` PASS；当前本机 `xcodebuild` 环境卡住，`xcodebuild -list -project Ohana.xcodeproj` 也停在 invocation 后无输出，targeted test/build 尚未完成。关闭条件：真机宠物获得 1 个椰子后，椰子历史、首页顶部岛屿总余额、对应宠物卡余额三处一致更新。
  - 记录：2026-06-19 用户真机复测通过：建立第二个人类后，顶部椰子数仍显示人类 + 宠物岛屿总余额；宠物获得 1 个椰子后，椰子历史、顶部椰子按钮、宠物卡余额三处同步更新；普通态点击顶部椰子按钮打开全量椰子历史，展开成员 / 宠物卡时才进入该卡对应历史。该子项关闭。

- [ ] 正式发布包中开发者余额测试工具不可达。
  - 预期：正式配置构建的设置页不存在“椰子数量测试”等可直接改余额的开发工具入口。
  - 记录：

## GAP-5 触顶感知

人工验收目标：每日奖励触顶后记录仍成功，反馈温和、不暴露预算数字，多语言不破版。

- [ ] 真实 UI 中触发每日预算 `recordOnly` 后，照护记录仍保存成功。
  - 预期：触顶后再执行一次照护；记录保存成功，页面不报错、不提示失败。
  - 记录：

- [ ] 真实 UI 奖励反馈显示温和触顶标题。
  - 预期：触顶后完成一次照护；奖励反馈标题显示“今日椰子已装满，明天继续～”，不出现“预算”“剩余额度”“今日还能得 X 个椰子”等解释。
  - 记录：

- [ ] 九语言长文本在真实 UI 中不截断、不重叠。
  - 预期：切换英文、德文、法文、日文、韩文等语言后触发 `recordOnly`；标题不溢出、不遮挡数值、不与图标重叠。
  - 记录：

- [ ] Reduce Motion / Low Power Mode 下触顶反馈仍可理解。
  - 预期：反馈可以减少动效，但文案仍出现且可读。
  - 记录：

## GAP-6 通知分级

人工验收目标：真机系统通知符合优先级、预算、合并、夜间免打扰和周报语义。

自动化前置记录：2026-06-24 标准 `Ohana` Debug scheme 已能为真机
`Guanchen's iPhone` 编译并签名 `Ohana.app` 与 `OhanaUITests-Runner.app`；
产物 entitlements 包含 development Push 与 `iCloud.com.guanchen.li.Ohana`。
本次 `testFirstReleaseReachableHomeOasisAndSettingsSmoke` 未进入 UI 自动化：
Xcode preflight 停在 `Unlock Guanchen's iPhone to Continue`，等待后取消。
因此该记录只证明 paid-team 标准 scheme 的真机构建/runner 签名阶段可达，
不证明通知权限、到达、Focus/DND、banner 或 action 行为。

- [ ] 真机允许通知权限后，创建 5 条同一天 routine 提醒。
  - 预期：系统通知最多到达 4 条；第 5 条仍在 App 内待办中可见，不被自动完成、跳过或删除。
  - 记录：2026-06-30 simulator preflight 已通过 `OhanaNotificationsSchedulingTests.routineReminderSchedulingHonorsDailyBudget()` 证明 app 调度策略对 5 条同日 routine 只排程 4 条，并为第 5 条写入 `scheduleSkippedBudget` 账本；真机仍需证明权限允许后 iOS 实际通知到达数与展示行为。

- [ ] 真机创建 22:00-08:00 之间的非关键提醒。
  - 预期：系统通知延后到 08:30 后；App 内提醒列表仍显示原始计划时间。
  - 记录：2026-06-30 simulator preflight 已通过 `OhanaNotificationsSchedulingTests.nonCriticalReminderInQuietHoursIsDeferredButAppReminderStaysPending()` 证明 app 策略把 23:15 非关键提醒投递时间延后到次日 08:30，同时保留 App 内 reminder `pending` 状态和原始计划时间语义；真机仍需证明 iOS 真实投递时间。

- [ ] 真机创建夜间用药 / 疫苗 / 就医类健康关键提醒。
  - 预期：系统通知按用户设定时间到达，不被预算和免打扰延后。
  - 记录：2026-06-30 simulator preflight 已通过 `OhanaNotificationsSchedulingTests.healthCriticalRemindersBypassBudgetMergeAndQuietHours()` 证明夜间健康关键提醒不受 routine 预算、同类合并和 quiet-hours 延后影响，按原 scheduledAt 进入调度边界；真机仍需证明 Focus/DND/锁屏环境下的真实系统投递表现。

- [ ] 真机创建同一天、同成员、同类别的非用药提醒。
  - 预期：系统通知只到达第一条；App 内后续提醒仍 pending。
  - 记录：2026-06-30 simulator preflight 已通过 `OhanaNotificationsSchedulingTests.sameDaySameMemberSameCategoryNonMedicationRemindersAreMerged()` 证明同日同成员同类别非用药提醒只把第一条送入通知排程，后续 reminder 仍保持 `pending`，并记录 `scheduleMerged`；真机仍需证明系统层只实际到达第一条。

- [ ] 真机点击普通提醒通知以及“完成 / 跳过 / 明天再说”等通知动作。
  - 预期：仍能进入正确提醒处理路径。
  - 记录：2026-06-30 simulator/source preflight 已通过 `OhanaNotificationsSchedulingTests.notificationDelegateHandoffKeepsDefaultTapAndActionsSeparate()` 证明普通点击进入 reminder route、COMPLETE/SKIP/SNOOZE 进入 action payload，并通过 `ReminderActionCoordinatorTests.notificationSnoozeActionRoutesToOneDaySnooze()` 证明“明天再说”会进入一天 snooze 且请求重排；真机仍需证明用户从系统通知 UI 点击这些动作时 iOS 会真实交付给 app。

- [ ] 如有配对 Apple Watch，验证 iPhone 通知转发和 action 交付。
  - 预期：未安装原生 Ohana Watch app 时，手表仍可收到由 iPhone 转发的提醒；完成 / 跳过 / 明天再说各执行一次，iPhone 端不重复写事实或重排。此项只证明系统通知兼容性，不得宣传为原生 watchOS app 支持。
  - 记录：

- [ ] 真机等待或临时触发周报通知。
  - 预期：标题/正文只表达照护周报，不出现悬赏榜、指派、多人竞争或“谁更勤快”的语义。
  - 记录：2026-06-30 unit preflight 已通过 `OhanaNotificationsSchedulingTests.weeklyReportNotificationIsAmbientCareCopy()` 证明周报通知为 ambient / weeklyReport 分类，标题/正文保持照护周报语义，并在中英德文案中阻止悬赏榜、指派、竞争、“谁更勤快”等语义回退；真机仍需证明真实周报通知展示。

- [ ] 在开发/观测面板查看提醒调度账本。
  - 预期：能看到“夜间延后”“预算跳过”“同类合并”等中文动作名。
  - 记录：2026-06-30 unit preflight 已通过 `OhanaNotificationsSchedulingTests.reminderObservabilityShowsChineseSchedulingLedgerActions()` 证明调度账本 action 显示名包含“夜间延后”“预算跳过”“同类合并”；同日 simulator GUI smoke 已通过 `OhanaUITests.testReminderObservabilityPanelOpensFromDebugSettings` 证明 Settings Debug 快捷入口能打开 Reminder Observability 面板并看到 `reminder-observability-ledger-card`。这部分不依赖物理通知投递；若首发手动表仍要求全真机签字，可在真机上做一次 unlocked-device smoke，但剩余主要风险已不是系统通知送达。

## GAP-7 补记结算

人工验收目标：补记事实落在历史日期，奖励预算 / 冷却 / 钱包奖励按操作日结算。

- [ ] 真实 UI 中创建一条历史日期的手动喂食补记。
  - 预期：照护历史显示在所选历史日期，奖励反馈在当前操作时出现。
  - 记录：2026-06-30 simulator/unit/UI preflight 已补齐手动喂食“历史”卡片加号入口、补记弹窗 `quick-feed-manual-log-date` 时间选择器、以及 `QuickFeedCommandExecutor.recordManual(... date:)` 到 `ManualFeedCommand.recordManual(... date:)` 的传参链路；`ManualFeedCommandTests.quickFeedExecutorManualRecordUsesSelectedBackdate()` 在 pinned `iPhone 17` 模拟器上通过，证明指定历史日期会写入 `PetCareLog.date` 与 `CareLedgerEvent.occurredAt`。同日补齐 compact History dock secondary action 渲染，并通过 `OhanaUITests.testFeedingManualHistoryAddOpensBackdateLogSheetAndRecords` 证明模拟器 UI 可从 History “+”打开带日期控件的补记弹窗、选择 1 天前日期、保存并在历史列表读到 `quick-feed-log-row-manualMain-YYYYMMDD-*` 行；最新 xcresult `/tmp/OhanaDerivedData-gap7-backdate-two-days-1782820800/Logs/Test/Test-Ohana-2026.06.30_13-10-47-+0200.xcresult`。尚未用手工交互真实滚动/点选系统日期控件完成一条记录，因此本项保持未勾选。

- [ ] 真实 UI 中连续补记两条不同历史日期的喂食记录。
  - 预期：第一条有奖励，第二条显示冷却 / 无额外椰子语义，两个历史记录均存在。
  - 记录：2026-06-30 simulator/unit/UI preflight 复用 `EconomyBackdateSettlementTests.backdatedCareRecordUsesOperationTimeForCooldown()` 的经济规则证据，并通过 `ManualFeedCommandTests` suite 证明 UI 执行器已能传入手选日期；模拟器 UI 预检已实际从 History “+”连续保存 1 天前与 2 天前两条补记，并在 History 中回读两个 `manualMain` 历史日期行；最新 xcresult `/tmp/OhanaDerivedData-gap7-backdate-two-days-1782820800/Logs/Test/Test-Ohana-2026.06.30_13-10-47-+0200.xcresult`。尚未用手工交互真实滚动/点选系统日期控件连续完成两条记录，因此本项保持未勾选。

## GAP-8 单成员形态

人工验收目标：一人一宠就是完整 Ohana；周报、财富页、成员胶囊没有“多人类才完整”的暗示。

- [ ] 准备一人一宠本地数据，进入首页和全功能菜单。
  - 预期：没有“添加更多人类成员才完整 / 解锁家庭感 / 一个人不够”等暗示。
  - 记录：2026-06-16 真机首测新增 P1：覆盖安装后不卸载、只重新 build 时，App 可能停在白屏或 icon + Ohana 启动画面；卸载后重装才正常。当前判断这不是 GAP-8 文案问题，而是首发一人一宠 smoke 的启动 / 保留数据恢复阻塞：旧本地 SwiftData / UserDefaults / onboarding handoff 状态在覆盖安装后仍存在，启动路径不能依赖干净安装。处理：启动前确保 Application Support 目录存在、保存首个人类后持久化 active human、恢复中断 onboarding 状态、首页 created-entity signal 改为一次性消费、避免 onboarding 完成时重复触发 navigation update；本轮进一步把 SwiftData `ModelContainer` 和 `AppServices` 从 `OhanaApp.init` 的同步启动路径移到 `OhanaBootstrapShell` 首帧之后创建，旧数据 / migration 打开慢时不再让用户停在系统启动图，并新增 `OnboardingHandoffResponsivenessTests.appBootstrapDefersSwiftDataContainerUntilAfterFirstShell` 防止回退。关闭条件：真机覆盖安装不卸载后可稳定启动；若仍停在 bootstrap shell，则继续查 SwiftData migration / store 恢复。
  - 记录：2026-06-16 真机首测新增 P1：添加首个人类和首个宠物后都会卡很久。当前判断首个人类路径与 onboarding -> Home -> starter gift / active human handoff 有关，首个宠物路径与 Home 卡片堆、CrewRoster / read-model 刷新、奖励 / 账本 / 提醒派生在保存后同帧争用有关。处理：首个人类 ID 从 `OnboardingView` 直接交给 `RootView` / `ContentView`，starter gift 评估不再依赖重启后的 `@AppStorage` 重新读取；onboarding 保存人类后不再双重完成 route；首页 created signal 只消费一次；本轮进一步把 Home join 保存等待从完整动画尾端提前到动效早期（非 Reduce Motion 820ms -> 140ms），标准保存成功关闭等待从 780ms -> 280ms；同时把 active-human 变化后的 route/reconcile/evaluation 分帧执行，并给 Home revision / day token 状态写入加等值保护，避免首建路径同一帧重复刷新。新增 `OnboardingHandoffResponsivenessTests.memberCreationSaveHandoffDoesNotWaitForFullAnimationTail` 与 `homeRefreshStateWritesAreDeduplicated` 防止回退。关闭条件：真机保存首个人类 / 首个宠物后快速回到首页，礼包和卡片在可接受时间内出现，没有长时间卡住。
  - 记录：2026-06-16 真机复测日志新增 P1 证据：`onChange(of: HomeReadModelRefreshKey) action tried to update multiple times per frame` 与 `Update NavigationRequestObserver tried to update multiple times per frame` 在 20:33 同时出现；后续 BoardServices / RemoteTextInput / KeyboardArbiter XPC interrupted 先按系统会话中断噪声处理，不作为业务根因。根因修正逻辑：之前的分帧依赖 `OhanaFrameScheduler.waitAfterNextFrame`，但它只有 `Task.yield()`，真机上仍可能留在 SwiftUI 同一 update frame；同时 Home read model 一次刷新连续发布 `snapshot/revision/payload/preparedTabs`，route coordinator 也会对 no-op sheet/fullScreen/path 清理发多次 `@Published`。处理：调度器改为 yield 后进入下一次 `DispatchQueue.main.async`；Home refresh key 的 revision/day token 事件合并为一次 pending 提交；Home read model 只由 `payload` 单次发布，兼容字段同步但不单独触发 objectWillChange；route presentation API 加 no-op guard，避免重复写导航状态。新增测试覆盖调度器跨 main-queue turn、Home 单发布提交和 route no-op guard。关闭条件：真机首建路径不再出现上述两条 SwiftUI Invalid Configuration fault。
  - 记录：2026-06-16 深挖后修正根因：点击「加入岛屿」卡死不是单个 `NavigationRequestObserver` warning，而是 onboarding 保存尚未提交时，RootView preflight 预挂载完整 `ContentView` / `NavigationStack`，Home 又立即启动 read model actor + 主线程 compatibility fetch（pets/humans/events/reminders/ledger/meds/tasks 等多表），与成员保存、active human handoff、starter gift 评估同段抢主线程。覆盖安装/旧数据比卸载重装更容易复现，是因为旧 store 让 Home 首刷 fetch 面变大。处理：RootView preflight 不再挂载完整 Home，只保留 onboarding 本地视觉 handoff；`ContentView` 仅在 `hasOnboarded` 后出现；加入岛屿后的 Home read model / appear handoff 分别延后 240ms / 180ms，让首帧和 starter gift 先完成。新增/更新 `OnboardingHandoffResponsivenessTests.onboardingHomePreflightDoesNotMountFullHomeBeforeCommit` 与 `onboardingHomeWorkloadHasPostJoinBreathingRoom` 防止回退。关闭条件：真机点击「加入岛屿」和保存完成瞬间不再出现 same-frame fault；覆盖安装旧数据样本下首建人/宠不会长时间停在首页不可交互状态。
  - 记录：2026-06-16 本轮自动复现确认 fresh 首建人类原先并非单纯等待不足：截图已经到 Home，但 XCTest 因主线程 / accessibility snapshot 忙碌 105s 超时，sample 显示主线程卡在 SwiftUI `Update.ensure` / AttributeGraph，console 同时出现 `Update NavigationRequestObserver tried to update multiple times per frame`。根因补强：starter gift 不应同时走专用 ceremony 和全局 reward overlay；fresh onboarding primary human 的 created-entity 到达效果与 starter / wallet evaluation 也不应在 Home / NavigationStack 首帧同周期触发。处理：`StarterGiftService` 改为静默写入钱包反馈、只显示专用 starter ceremony；`OnboardingHomeJoinHandoffGate` 增加 Home 视觉效果与 post-home effect 延迟；`ContentView` 将 onboarding createdEntitySignal 与 starter evaluation 延后到 Home 首帧稳定后；UI test 显式传 `-OHANA_UI_TESTS` 避免测试环境挂全局 reward overlay。验证：卸载后 fresh `scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testCreateFirstHumanFromOnboarding` 在 iPhone 17 simulator 通过（13.23s）；不卸载直接重启已安装 App，3s 截图为 Home + starter gift，进程存活，30s log 未见 `HomeReadModelRefreshKey` / `NavigationRequestObserver` same-frame fault。关闭条件仍需真机覆盖安装与首建宠物复测。
  - 记录：2026-06-16 针对真机“添加人类后从首页 Today Focus 建首个宠物，停在 Create Pet Card 倾斜卡片”的 P1 继续自动复现：普通 UI test 因 `-OHANA_UI_TESTS` 隐藏全局 reward overlay 而无法复现；新增 `-OHANA_ENABLE_PRODUCTION_OVERLAYS_IN_UI_TESTS` 后，`testCreateFirstPetFromTodayFocusWithProductionOverlaysAfterFirstHuman` 可稳定卡在同一画面，失败截图 `/tmp/ohana-first-pet-production-overlay-hang.png`，sample 指向 `CoconutRewardFeedbackOverlay.body` / `RewardBurstDots` / `AppWorkloadPolicy.shouldRunInteractionAnimation` 参与首宠保存后的同帧 SwiftUI 更新。根因：首宠 welcome reward 把 care/member creation 的保存 handoff 和全局奖励动效放进同一个可见帧，global overlay 竞争 sheet dismiss / `onComplete`，导致创建页停留。处理：首宠 welcome reward 改为静默写账（`postsRewardFeedback: false`），成员创建卡本身负责可见反馈；全局 `CoconutRewardFeedbackOverlay` 删除 burst dots 与 numeric transition，避免在 route/sheet handoff 时运行装饰动画；UI test 增加生产 overlay 开关与首宠 Today Focus 回归路径。验证：卸载后 fresh `scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testCreateFirstPetFromTodayFocusWithProductionOverlaysAfterFirstHuman` 在 iPhone 17 simulator 通过（26.74s）；随后 3 分钟 simulator log 未见 `HomeReadModelRefreshKey` / `NavigationRequestObserver` / `multiple times per frame` fault。关闭条件：真机重复“建主人 -> 关闭 starter gift -> 首页 Today Focus 建首宠”，保存后应快速回首页，且 console 不再出现同帧 SwiftUI fault。
  - 记录：2026-06-16 真机覆盖安装后仍停在系统 icon + Ohana 启动画面的复测继续深挖。证据：设备容器偏好显示并非 fresh onboarding（`ohana_has_onboarded=true`、存在 active human / pet order、starter gift 已处理），SwiftData store 文件存在且进程曾存活，因此根因不是“未建主人”或“缺 store”，而是覆盖安装旧数据下启动仍可能在 SwiftData / AppServices 创建前没有可见 SwiftUI 首帧，也缺少可拉取的启动阶段证据。处理：`OhanaApp` 不再在 `init` 同步创建 `SharedModelContainer.make()` / `AppServices`；新增极轻 `OhanaBootstrapShell`，首帧渲染后等待 96ms，再在后台队列打开 SwiftData container，随后回 MainActor 创建服务；bootstrap shell 不再使用 `OhanaAppBackground`、自定义字体或按钮样式，只保留纯渐变、系统字体、进度和慢启动重试；新增 DEBUG `Library/Application Support/ohana-startup-probe.log`，记录 `bootstrap.appear`、`first-frame-yield-complete`、`container-start/ready`、`services-ready`、`payload-set`，用于下次真机直接定位卡点。验证：`scripts/build-debug-fast.sh` 通过；`scripts/test-simulator.sh -only-testing:OhanaTests/OnboardingHandoffResponsivenessTests` 通过，日志显示 simulator 启动完整走到 `bootstrap.payload-set`；`Ohana Local Device` 产物在本机 Codex 环境被 File Provider/FinderInfo xattr 拦截，已补强 `scripts/strip-build-xattrs.sh` 清 Finder hidden flag，并通过手动清根目录 FinderInfo -> 真实证书签名 -> `codesign --verify --deep --strict` -> `devicectl install` 完成真机覆盖安装。当前未完成项：`devicectl process launch` 和进程列表查询卡在 CoreDevice usage assertion，未能由 Codex 侧拉到真机 `ohana-startup-probe.log`；关闭条件仍需用户手动点开已覆盖安装的真机 App，确认不再停系统启动图，若停在 bootstrap shell 则回传 probe 日志 tail。
  - 记录：2026-06-17 将“建人类 / 建宠物 / Settings / Oasis 首帧卡死”提升为首发门槛头号 P0 后做框架级补强。复核结论：问题不是单个页面 bug，而是 route/data container 可在首帧持有多张 `@Query` 或同步 fetch，AGENTS 的 finger-first frame law 缺少机械兜底；Settings 已经验证“只延后 fetch / loading gate”会制造新阻塞，正确形态应是先呈现轻壳或可用页面，再异步补数据。处理：新增 `scripts/audit-route-first-frame.sh` 和 bad/good fixture，dev-check 对 touched app Swift 强制执行，`--all --soft` 盘点当前仍有 11 个遗留宽 `@Query` route 风险；`MemberCardCreationView` 移除首帧 `@Query(Pet/Human)`，改为 `OhanaFrameScheduler` 后加载已有成员；`OasisRewardLiveDataStore` 改为可取消 / 合并 / 下一帧后刷新多表快照，`OasisRewardCommandExecutor.makeActionSnapshot` 不再在 UI snapshot 缺数据时 fallback 同步查询当前主人钱包；`OnboardingView` 的中断恢复改走 `AppServices.onboardingJourney`，移除 View 直接静态 coordinator fetch 和 `UserDefaults.standard.set`。验证：`scripts/tests/run-audit-fixture-tests.sh` PASS；`scripts/dev-check-changed.sh` PASS；`scripts/build-debug-fast.sh` PASS；`scripts/test-simulator.sh -only-testing:OhanaTests/OnboardingJourneyCoordinatorTests -only-testing:OhanaTests/OnboardingHandoffResponsivenessTests -only-testing:OhanaTests/SettingsRouteContainerTests` PASS（Swift Testing 14 tests）。关闭条件：真机覆盖安装后可进 App；保存首个人类 / 首宠后可快速回首页；切 Oasis 不再卡死；设置按钮不再停在 opening shell；若仍复现，优先查看新审计列出的 11 个遗留 route 首帧风险点，而不是继续逐个 UI 小补丁。
  - 记录：2026-06-17 P0 收口复审后继续完成框架闭环：上一条列出的 11 个遗留 route/data 首帧风险点已全部迁移，`Achievements / Calendar / CrewRoster / IslandWealth / IslandFood / FunctionMenu / ExpandedHumanFeatures / HumanDetailSheet / MemberProfile / QuickCare / CoconutShop` 不再在 route 首帧持有宽 `@Query`，统一改为首帧后 `OhanaFrameScheduler` 延迟加载、revision 合并刷新、消失时取消任务；`scripts/audit-route-first-frame.sh --all` 已从 soft 盘点升级为 strict PASS，并接入 `.github/workflows/ci.yml`、`scripts/module-exit-gate.sh` 和 `scripts/release-hardening-check.sh`，bad/good fixture 与扫描文件下限均通过，避免未来 route 容器重新引入首帧宽查询或同步 fetch。附带根因修复：Oasis 新增真实 Lv0 后，旧存量活动 baseline 会被映射到新阈值下的同等级进度，避免 fresh 用户得到 Lv0 规则的同时让回流用户被降级。验证：`scripts/audit-route-first-frame.sh --all` PASS（843 files）；`scripts/tests/run-audit-fixture-tests.sh` PASS；`scripts/dev-check-changed.sh` PASS；`scripts/build-debug-fast.sh` PASS；`scripts/test-simulator.sh -only-testing:OhanaTests/CoconutEconomySimulationTests -only-testing:OhanaTests/OhanaTests` PASS（133 tests）；`scripts/test-simulator.sh -only-testing:OhanaTests/OnboardingJourneyCoordinatorTests -only-testing:OhanaTests/OnboardingHandoffResponsivenessTests -only-testing:OhanaTests/SettingsRouteContainerTests -only-testing:OhanaTests/MemberCreationServiceTests -only-testing:OhanaTests/CoconutEconomySimulationTests -only-testing:OhanaTests/VerticalHomeTabMountPolicyTests` PASS（62 tests）。关闭条件保持人工：真机覆盖安装后不卸载可稳定进 App；首建主人、关闭 starter gift、Today Focus 建首宠、切 Oasis、打开 Settings 都不可卡死，console 不再出现 same-frame SwiftUI fault。
  - 记录：2026-06-17 首发头号 P0 本轮收口：自动 smoke 复现到“首建人类 -> starter gift -> Today Focus 建首宠 -> 切 Home 内嵌 Oasis -> 注入能量 -> 打开 Settings”整条首发可达链。新的具体根因不是 Settings 或建卡单点，而是 Home tab 内嵌 Oasis 仍会挂完整 `OasisRewardView` live 子树；该子树带 SwiftData / ledger / economy / reward 快照与动效工作，切到 Oasis 时会把首页 accessibility snapshot 和主线程首帧再次压住，且右下 FAB 依赖 full Oasis view 导致轻壳下可能无反应。处理：Home 内嵌 Oasis 改为 snapshot-only frozen shell，`OasisHomeTabContentPolicy` 在 Home 场景下永不挂 live tree content / active work；Home FAB 改走延后一帧的轻量 `injectEmbeddedOasisEnergy`，消费统一 `OasisTreeEnergyInjectionPolicy` 后刷新 snapshot，不再为了注入而挂完整 Oasis；未挂载 tab 直接占位，避免 preparing / hidden 页构建重子树；补齐 `home-tab-oasis`、`home-primary-action`、`oasis-screen`、`oasis-tree-level-control`、`home-settings-action`、`settings-screen` 等 smoke test identifiers。验证：`scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testFirstReleaseReachableHomeOasisAndSettingsSmoke` PASS（40.151s，之前在等待 `oasis-screen` 时可卡到 100s+）；`scripts/test-simulator.sh -only-testing:OhanaTests/VerticalHomeTabMountPolicyTests` PASS（26 tests，锁住 Home Oasis 始终 frozen）；`scripts/test-simulator.sh -only-testing:OhanaTests/OnboardingHandoffResponsivenessTests -only-testing:OhanaTests/SettingsRouteContainerTests -only-testing:OhanaTests/CoconutEconomySimulationTests -only-testing:OhanaTests/MemberCreationServiceTests` PASS（33 tests）；`scripts/dev-check-changed.sh` PASS；`scripts/audit-route-first-frame.sh --all` PASS（843 files）；`scripts/tests/run-audit-fixture-tests.sh` PASS；`scripts/build-debug-fast.sh` PASS；simulator 最近 30 分钟日志未命中 `HomeReadModelRefreshKey` / `NavigationRequestObserver` / `multiple times per frame` / `Invalid Configuration`。关闭条件：真机按同一路径复测，覆盖安装不卸载可启动，首建主人、关闭 starter gift、Today Focus 建首宠、切 Home Oasis、点击 FAB、打开 Settings 都不可卡死；若仍卡住，优先读取 `ohana-startup-probe.log` 与 route-first-frame 新审计命中的挂载点。
  - 记录：2026-06-17 真机前置复验已由 Codex 侧推进一层：`Ohana Local Device` 用 `/tmp/ohana-local-device-p0` DerivedData 重新构建并签名通过；仓库内 `.build/DerivedData/phase9a-local-device` 路径仍会让 bundle root 带 `com.apple.FinderInfo` 而 CodeSign 失败，因此本轮按签名污染例外切到 `/tmp`。验证：`codesign --verify --deep --strict /tmp/ohana-local-device-p0/Build/Products/LocalDeviceDebug-iphoneos/Ohana.app` PASS；`xcrun devicectl device install app --device 00008150-001270342EA3401C /tmp/ohana-local-device-p0/Build/Products/LocalDeviceDebug-iphoneos/Ohana.app` 覆盖安装 PASS；`xcrun devicectl device process launch --device 00008150-001270342EA3401C com.guanchen.li.Ohana.LocalDevice` PASS；进程列表显示 `/Ohana.app/Ohana` 正在运行；拉取 `Library/Application Support/ohana-startup-probe.log` 显示本次启动已走到 `bootstrap.payload-set`。未完成项：物理 `testFirstReleaseReachableHomeOasisAndSettingsSmoke` 自动化被签名配置挡住，标准 Debug bundle 需要个人团队不支持的 Push/iCloud profile，`LocalDeviceDebug` 又未给 test targets 配完整 bundle id / Swift version / Info.plist；所以“首建主人 -> starter gift -> Today Focus 建首宠 -> Home Oasis FAB -> Settings”仍需用户手动复测或后续新增 LocalDevice UITest scheme。P0 关闭条件仍是手动交互链不卡死。
  - 记录：2026-06-17 首发 P0 物理 UI smoke 已跑通。先修复 `LocalDeviceDebug` 下 test target 签名 / bundle id / generated plist / Swift version 后，物理 smoke 可在 `Guanchen’s iPhone` 上运行。首轮物理 smoke 证明人类、首宠、Home Oasis 与 FAB 已能走通，但点击 Settings 后出现真机 crash；xcresult crash log 指向 `SettingsView.body.getter -> LazyVStack.init -> Swift runtime generic metadata demangle`，根因是 Settings 首帧巨大 inline SwiftUI 泛型树在真机 Debug/XCTest 下触发 stack guard，而不是单纯 fetch 等待。处理：设置页移除首帧 DEBUG 开发工具区；将 inline `LazyVStack` 拆为 `SettingsView+MainSections.swift`，按 section 做类型擦除，并把 reset alerts 移到 Settings 根视图。验证：`xcodebuild test -allowProvisioningUpdates -project Ohana.xcodeproj -scheme Ohana -configuration LocalDeviceDebug -destination 'id=00008150-001270342EA3401C' -derivedDataPath /tmp/ohana-device-ui-p0-localconfig -only-testing:OhanaUITests/OhanaUITests/testFirstReleaseReachableHomeOasisAndSettingsSmoke CODE_SIGNING_ALLOWED=YES` PASS（1 UI test，46.921s，xcresult `/tmp/ohana-device-ui-p0-localconfig/Logs/Test/Test-Ohana-2026.06.17_13-20-42-+0200.xcresult`）。结论：覆盖安装启动层、首建主人、starter gift、Today Focus 建首宠、Home Oasis Lv0 -> Lv1 注入、Settings 可打开这条首发可达 P0 链路已由真机自动化清零；剩余 GAP-8 项是普通文案 / 菜单 / 周报人工抽查，不再是本 P0。
  - 记录：2026-06-17 route-first-frame 假绿复验追加。用户铁证指出旧 audit 放过 `AppAccountSwitcherRouteContainer` 的首帧 `@Query` 和 Oasis 首帧路径 service fetch；本轮先让真实 Settings / Oasis 文件在 audit 下报红，再迁移真实消费者：账户切换器和 Settings sheet 走 `RouteFirstFrameDeferredLoad` / `RouteFirstFrameDeferredMount`，Oasis render snapshot 不再同步 fetch 当前主人钱包，审计增加 route/data `@Query` ratchet、unmarked direct fetch 零容忍和 `rewards.currentHumanBalance(context:)` service bypass 零容忍。验证：`scripts/audit-route-first-frame.sh --all` PASS（845 files）；`scripts/tests/run-audit-fixture-tests.sh` PASS，bad fixture 同时抓 `@Query` / sync fetch / service fetch；`xcodebuild test -allowProvisioningUpdates -project Ohana.xcodeproj -scheme Ohana -configuration LocalDeviceDebug -destination 'id=00008150-001270342EA3401C' -derivedDataPath /tmp/ohana-device-route-first-frame-p0 -only-testing:OhanaUITests/OhanaUITests/testFirstReleaseReachableHomeOasisAndSettingsSmoke CODE_SIGNING_ALLOWED=YES` PASS（1 UI test，53.049s，xcresult `/tmp/ohana-device-route-first-frame-p0/Logs/Test/Test-Ohana-2026.06.17_14-07-40-+0200.xcresult`）。结论：本 P0 不再只靠脚手架或旧物理证据，route-first-frame 假绿修复后的首建主人、首建宠、Home Oasis、FAB 注入、Settings 路径已由真机自动化复验。
  - 记录：2026-06-30 simulator UI preflight 已通过 `OhanaUITests.testSingleHumanPetHomeAndFunctionMenuFeelComplete()` 覆盖 fresh 一人一宠：创建首个人类、创建首宠、关闭 starter gift、Oasis Lv0 -> Lv1 注入、回 Home 后通过 FAB -> More 打开 Function Menu root，并确认 `function-menu-group-dailyCare` 可见；同一测试在 Home 与 Function Menu 两处断言没有出现“添加更多人类 / 添加更多家庭成员 / 一个人不够 / Add another family member / more family members / one person is not enough”等单成员缺陷文案。通过证据：pinned `iPhone 17` simulator，`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-gap8-single-member-function-menu-1782822600 scripts/test-simulator.sh '-only-testing:OhanaUITests/OhanaUITests/testSingleHumanPetHomeAndFunctionMenuFeelComplete'`，xcresult `/tmp/OhanaDerivedData-gap8-single-member-function-menu-1782822600/Logs/Test/Test-Ohana-2026.06.30_13-17-45-+0200.xcresult`。本项仍保留未勾选，等待最终真机视觉目检签字。

- [ ] 打开家庭周报空态。
  - 预期：最近动态文案为照护动态语义，而不是“全家动态”或多人竞赛暗示。
  - 记录：

- [ ] 完成至少一次照护打卡后打开家庭周报。
  - 预期：贡献区显示“本周照护者”，故事文案不出现“照护贡献排行 / 照顾最多 / 本周之星”。
  - 记录：

- [ ] 在家庭周报点击分享。
  - 预期：分享文本中的人物标签为“本周照护者”，不是“本周之星”。
  - 记录：

- [ ] 打开 Ohana 财富页。
  - 预期：当只有一个可展示账户行时，标题显示“椰子账户”，行首是完成徽章，不是第 1 名排名样式；若有两行及以上，仍可显示“财富榜”。
  - 记录：

- [ ] 打开绿洲进度卡。
  - 预期：家庭贡献胶囊中文显示“1 位成员”，没有“1成员”。
  - 记录：

- [ ] 如有多人测试数据，补充回归目检。
  - 预期：两名及以上人类成员时，周报贡献排行与财富榜仍保留排序语义。
  - 记录：

## Phase 6 Settings + Health

人工验收目标：正式设置页无开发/空入口；通知开关在真机上影响系统通知；Health 删除为不可恢复物理删除；已故宠物只读。

自动验收已完成并在 2026-06-16 全仓复验：目标测试覆盖通知偏好跳过调度、Health 删除派生费用 / 日历事件 / 提醒 / ledger、症状与发情记录物理删除、已故宠物拒绝写入、legacy schema 兼容；`scripts/module-exit-gate.sh --full` 与 CI run `27607807044` 均通过。

- [ ] 用正式配置或 Release 包打开设置页并扫描所有区块。
  - 预期：没有“开发者工具”“椰子数量测试”“性能诊断”“UI/UX 规范查看”等开发入口；没有可点击但无效果的隐私政策 / 联系开发者空入口；评分入口可正常跳转。
  - 记录：

- [ ] 真机设置页通知区逐项切换“用药 / 喂食 / 护理 / 打卡提醒”。
  - 预期：开关状态能保持；关闭某项后，对应 App 内提醒仍存在，但不会注册或到达对应系统本地通知。
  - 记录：

- [ ] Settings 与 Health 切换中文、英文、德文及任一长语言目检。
  - 预期：主要设置、备份、健康记录、健康总览、健康弹窗文案不显示未本地化的正式中文硬编码，不重叠、不截断。
  - 记录：

- [ ] 在真实 UI 删除健康记录、症状记录、发情记录。
  - 预期：确认删除后普通 Health 页面、疫苗本、健康归档、岛屿健康总览立即移除对应内容；健康记录关联的费用、到期日历事件、提醒和系统通知不再可见或到达；没有恢复入口。
  - 记录：

- [ ] 对已故宠物打开 Health 相关入口。
  - 预期：历史内容只读；没有新增健康记录、症状、发情、用药或提醒的入口；不会产生新奖励。
  - 记录：

## GAP-9 离世退场

人工验收目标：离世不是删除；成员从活跃照护退场，历史和纪念入口保留，误标记可撤销。

自动化前置记录：2026-06-24 标准 `Ohana` Debug scheme 真机 UI smoke 已完成
iPhoneOS 编译和签名，`Ohana.app` 保留 development Push 与 iCloud entitlements，
`OhanaUITests-Runner.app` 也成功生成；XCTest 启动被锁屏设备挡住，错误为
`Unlock Guanchen's iPhone to Continue`，等待后取消。该记录不勾选下列 GAP-9
人工项；离世标记/撤销、纪念入口、未来通知取消/恢复仍需解锁真机后手动或自动复测。

- [ ] 在真实 UI 中标记一只宠物离世。
  - 预期：确认文案表达“未来照护安排退出活跃提醒、数据保留、可撤销”，不出现“删除未来提醒 / 事件”。
  - 记录：2026-06-30 simulator/source preflight 已通过 `OhanaUITests.testPetMemorialMarkCancelConfirmAndUndoFlow()` 覆盖取消/确认标记与结果读回，并通过 `MemberLifecycleGateTests.petMemorialConfirmationExplainsActiveReminderExitWithoutDeletionCopy()` 锁定确认文案为“未来照护安排退出活跃提醒、原有数据保留、可撤销”，且不出现“删除未来提醒 / 事件”语义；真机仍需确认物理设备上的 alert 展示与触控表现。

- [ ] 标记宠物离世后遍历首页、FAB、全功能菜单、QuickCare、Feeding、Today Focus。
  - 预期：离世宠物不再作为活跃照护目标、任务目标、Today Focus 委托目标或快捷打卡目标出现。
  - 记录：2026-06-30 simulator/source preflight 已通过 `OhanaUITests.testPetMemorialHidesHomeLiveCareEntrypoints()` 证明离世宠物重启后不再显示 Home 主卡和 Home quick actions，并在 Oasis Lv1 解锁后走 Home FAB -> More -> Function Menu -> daily care，证明 food aggregate 不再把该宠物作为活跃目标且不会打开 live pet route；同时通过 `MemberLifecycleGateTests.functionMenuSurfacesDoNotExposeDeceasedMembersAsActiveTargets()` 锁定全功能菜单聚合/分组/根视图只使用 active pets 与 visible active humans。真机仍需做一轮完整视觉遍历确认 FAB、QuickCare、Feeding、Today Focus 无设备展示遗漏。

- [ ] 标记宠物离世后打开日历 / 提醒相关页面。
  - 预期：未来照护安排不再作为 active pending 提醒打扰；历史事件、历史记录和纪念资料仍可查看。
  - 记录：2026-06-30 simulator preflight 已证明标记宠物离世会移除目标宠物的未来 active schedule 和对应提醒，同时保留过去历史与其他成员未来安排；真机仍需确认真实 UI 展示与系统通知不再到达。

- [ ] 撤销宠物离世。
  - 预期：宠物回到在世状态；由纪念流程退场的未来照护安排恢复；用户自己跳过 / 删除 / 完成的提醒不会被误恢复。
  - 记录：2026-06-30 simulator preflight 已通过 `OhanaUITests.testPetMemorialMarkCancelConfirmAndUndoFlow()` 证明撤销取消不会清除离世日期，撤销确认会恢复 live pet mark action；真机仍需确认物理设备 UI，并且系统通知恢复/重排仍归入下方通知项验证。

- [ ] 真机允许通知后，验证离世与撤销的通知表现。
  - 预期：标记离世会取消该宠物未来本地通知；撤销后未来 pending 提醒可重新排程或在下次通知维护中恢复，不崩溃、不静默丢失数据。
  - 记录：2026-06-30 simulator preflight 已证明宠物 / 人类进入纪念模式时，未来 active schedule 删除会把对应 notification id 分发到 app 的通知取消边界；真机仍需证明 iOS 实际取消已注册通知，以及撤销后真实 pending 通知能恢复或由维护任务重排。

- [ ] 标记一位人类成员进入纪念模式。
  - 预期：该成员不再出现在首页主卡、功能菜单人类目标、Today Focus 体重委托、周报活跃贡献统计或奖励账户写入路径。
  - 记录：2026-06-30 simulator/source preflight 已通过 `OhanaUITests.testHumanMemorialMarkCancelConfirmAndUndoFlow()` 覆盖人类纪念标记/撤销 UI，并通过 `MemberLifecycleGateTests.functionMenuSurfacesDoNotExposeDeceasedMembersAsActiveTargets()`、`MemberLifecycleGateTests.familyWeeklyReportActiveContributionExcludesDeceasedMembers()` 与 `MemberLifecycleGateTests.deceasedMembersRejectPresentationSecurityEconomyAndSettingsWrites()` 证明功能菜单目标、周报活跃贡献和奖励账户写入会排除离世人类；真机仍需确认首页/Today Focus 等物理设备展示。

- [ ] 打开离世宠物 / 人类的资料、档案、历史记录和钱包历史。
  - 预期：历史仍可查看，纪念语气得体；钱包历史保留但不再产生新的奖励写入。
  - 记录：2026-06-30 simulator/source preflight 已通过 `MemberLifecycleGateTests.memorialContentAllowsContentButNoCareOrEconomyDerivation()`、`MemberLifecycleGateTests.deceasedFeatureHubsExposeOnlyMemorialSafeDestinations()`、`MemberLifecycleGateTests.coconutHistoryKeepsFrozenMemberLedgerReadableWhileActiveTotalsExcludeThem()` 等测试证明纪念内容/档案入口可保留，活跃钱包合计排除冻结成员但历史 ledger 仍可读；真机仍需视觉确认资料、档案、历史和钱包页面的纪念语气。

- [ ] 在设置页、成员详情危险区和全功能菜单中检查纪念状态与删除入口。
  - 预期：纪念退场不显示为“待删除 / 30 天后清理”状态；不存在回收站入口；删除仍是单独的不可恢复确认流程。
  - 记录：2026-06-30 simulator/source preflight 已通过 `MemberLifecycleGateTests.memorialSurfacesDoNotUseRecycleBinOrPendingDeleteLanguage()` 证明纪念相关表面不使用回收站、待删除或 30 天清理语义，并通过 `OhanaUITests.testPetPermanentDeleteCancelAndWrongNameAreSafe()` 与 `OhanaUITests.testHumanPermanentDeleteCancelAndWrongNameAreSafe()` 覆盖永久删除仍是独立精确名称确认流程；真机仍需最终手动 smoke 确认设置页、成员详情危险区和全功能菜单展示。

## GAP-12 植物功能门

人工验收目标：首发版本无任何可达植物功能面；历史植物数据不影响今日焦点、心情、Oasis；植物代码与数据仍保留给未来解锁。

自动验收已完成并在 2026-06-16 全仓复验（门禁 commit `a1e0e0376`，recheck `8f6c792dc`）：`PlantFeatureGate` 首发恒关；添加植物、植物路由、首页植物 tab、FunctionMenu 植物集合全部不可达；quest 引擎不产植物任务；心情信号不读取植物状态；历史植物照护不喂给 Oasis 当前成长；`scripts/module-exit-gate.sh --full` 与 CI run `27607807044` 均通过。

- [ ] 真实 UI 遍历首页底部 tab、首页卡片、Today Focus 与心情提示。
  - 预期：不出现植物 tab、植物卡、浇水 / 施肥 quest、植物缺水或植物心情信号；有历史植物数据时也不出现。
  - 记录：

- [ ] 真实 UI 遍历添加入口、首页 FAB / 中央添加、全功能菜单与功能分组页。
  - 预期：不出现“添加植物”、植物集合、植物看板、植物详情、植物护理等入口。
  - 记录：

- [ ] 真实 UI 打开 Onboarding 与必填主人资料页。
  - 预期：首发引导文案只表达主人、宠物、提醒 / 本地照护，不出现植物 badge、植物承诺或植物作为首发能力的暗示。
  - 记录：

- [ ] 真实 UI 打开成长解锁 / 等级提示相关页面。
  - 预期：不出现“植物暂不开放 / Plants hidden”之类负面隐藏文案；若有成长提示，应保持中性未来节奏表达。
  - 记录：

- [ ] 使用带历史植物数据的本地样本打开 Oasis。
  - 预期：Oasis 当前生命树 / 情绪 / 奖励不因历史植物照护记录改变；植物历史不会作为当前首发成长信号露出。
  - 记录：

## Phase 6 Members

人工验收目标：成员创建与不可恢复删除在真实 UI 中符合规则书，且必填主人资料页无明显无障碍或视觉回归。

- [ ] 真实 UI 创建带生日和到家日的宠物成员。
  - 预期：宠物保存成功；日历 / 提醒中能看到生日与到家纪念相关内容；首页可见性符合最多 6 张卡规则。
  - 记录：

- [ ] 真实 UI 创建带生日的人类成员。
  - 预期：人类保存成功；生日相关日历事实可见；首页可见性符合最多 6 张卡规则。
  - 记录：

- [ ] 删除带生日提醒的人类成员。
  - 预期：删除确认表达不可恢复；删除后 Human、相关生日 Event / Reminder 和人类侧从属数据退出普通入口；没有恢复或回收站入口。
  - 记录：

- [ ] 删除带生日 / 到家日的宠物成员。
  - 预期：删除确认表达不可恢复；删除后宠物、相关日历事实、提醒和快捷入口一起退出普通 UI；没有恢复或回收站入口。
  - 记录：
  - 记录：2026-06-17 删除 UI 卡死已纳入 GAP-2 自动 smoke：`testPetPermanentDeleteFromBasicInfoSmoke` 从 fresh 首建宠物进入基础资料危险区，执行“彻底删除”确认后返回首页并断言被删宠物卡不再可见。当前自动证据覆盖宠物永久删除的 UI 可响应性；带生日 / 到家日派生日历事实的真机人工抽查仍待执行。

- [ ] 打开必填主人资料页。
  - 预期：顶部图标视觉正常；VoiceOver 不把纯装饰图标读成无意义 SF Symbol；按钮 / 可点区域没有小于 44pt 的明显问题。
  - 记录：

## Phase 6 Oasis

人工验收目标：Oasis 生命树是全岛共同消费出口，可使用 `system:island` 与所有活跃正式成员钱包；成员型互动仍由当前主人钱包承担。重复产出受预算 / 冷却约束，电子宠物休眠可唤回，`system:legacy` 永远不可用。

- [ ] 无当前主人或当前主人已进入纪念模式时打开 Oasis。
  - 预期：生命树显示正式岛屿总额并可使用岛屿储备与活跃 Pet 钱包注入；需要当前主人的电子宠物消费 / 奖励保持禁用或提示选择主人；任何路径不读写 `system:legacy`，页面不崩溃。
  - 记录：2026-07-11 iPhone 17 Pro Max 的 clean-run 样本只有 Pet、没有 Human，总额显示 59🥥，点击生命树注入只震动不写能量。根因是 D17 的旧 50🥥 赠礼被写入 Pet，而 Oasis 注入及 action snapshot 硬依赖 current Human。当前工作区已把新赠礼改写入 `system:island`，旧 v2 成员赠礼以幂等成对转账重分类；生命树按岛屿储备、current Human、其余活跃成员的稳定顺序聚合扣款。无 Human 的 Unit/Integration 路径与 Pet-first 五次注入 Lv0 -> Lv1 UI 路径已通过。新签名 Release 已在不卸载的前提下覆盖安装；只读设备 store 证明旧样本已迁移为岛屿储备 50 + Pet 奖励 9、legacy 0 且总额仍为 59。最终点击后的 59→49 与能量 +10 仍待用户真机确认。

- [ ] 正式岛屿总额足够时连续注入生命树能量。
  - 预期：注入可重复执行，只受正式岛屿总额限制；生命树 XP 增加；每个实际出资账户各有可重放流水，岛屿储备流水不得伪装成成员贡献。
  - 记录：2026-06-17 真机 fresh install 发现 Oasis 右下角 FAB 注入能量无反应；产品期望是新装树应为 Lv0，用户手动注入后才升为 Lv1。根因：旧生命树模型没有真实 Lv0，`0` 能量会显示为 Lv1；注入成本 / XP 分散在 manager、executor、Oasis UI、Shop 和规则说明中，仍混用旧 `80🥥 -> 20XP`，而 starter gift 只给 50 椰子，所以 fresh 用户看起来“有启动礼但注入不可用”。同时 starter gift ceremony 文案仍暗示自动 Lv0 -> Lv1，和手动注入规则冲突；树视觉组件也会把 `level == 0` 夹到 Lv1 配置。处理：新增统一 `OasisTreeEnergyInjectionPolicy`，生命树等级加入 `lv0`，阈值改为 0/50/150...；Home/Oasis 快照、`BeautifulCoconutTree` 视觉配置、FAB 可用性、命令执行、Shop 加速、规则说明和 starter gift ceremony 全部消费同一策略；starter gift 只发 50 椰子，不再展示自动升级。2026-06-17 用户复核后继续改产品节奏：首包改为 `10🥥 -> 10XP`，因此新手礼包可完成 5 次注入，5 次后从 Lv0 到 Lv1；Lv5 每日椰子收益说明移入椰子树等级介绍，能量进度条不再显示 `Lv.5 🥥`。关闭条件：真机 fresh install 后 Oasis 树显示 Lv0；领取 starter gift 后有 50 椰子；点击礼包 CTA 后底栏才出现 Oasis tab 和点击提示；连续 5 次点击 Home/Oasis FAB 后升级为 Lv1，且不出现卡死或无响应。
  - 记录：2026-06-17 本轮补强 Home 内嵌 Oasis 的注入路径：为避免切 tab 首帧挂完整 `OasisRewardView`，Home Oasis tab 只呈现 frozen tree snapshot；右下 FAB 不再依赖 live Oasis view，而由 Home 延后一帧执行 `OasisTreeManager.injectEnergy(cost: OasisTreeEnergyInjectionPolicy.starterPackageCost, modelContext:)`，随后刷新 Home snapshot 并触发升级反馈。自动验证已更新为首发 UI smoke 中 fresh 用户领取 starter gift 后，Oasis tab 在礼包 CTA 后才出现，`home-primary-action` 连续 5 次注入后从 Lv0 到 Lv1；`VerticalHomeTabMountPolicyTests` 锁住 Home 内嵌 Oasis 不运行 active work，并新增 starter tab guard / 五次注入策略断言。
  - 记录：2026-06-17 真机发现结束一次遛狗后椰子树意外升级到 Lv2。根因：遛狗停止会按经济管线写 `CareLedgerEvent`，metadata 中的 care reward `growthXP` 被 `OasisTreeManager` 聚合进 `islandEnergy`，且 `CareLedgerRecording.syncLedgerEnergyIfNeeded` 对任意 `growthXP > 0` 都触发树能量刷新；这把普通照护成长奖励误当成“用户手动注入生命树能量”。处理：Oasis 树等级改为只读取显式手动注入产生的 `treeInjection` / `treeInjectionLarge` ledger `injectedXP`；`totalEnergy` 不再包含 care / walk / legacy activity baseline；generic care ledger sync 不再刷新树能量；升级椰子打开时即使旧记录带 `treeEnergyAmount` 也不再改 `injectedEnergy`，新升级椰子 catalog 不再产出树能量奖励。自动验证：`scripts/test-simulator.sh -only-testing:OhanaTests/OhanaTests` PASS（134 tests），新增/更新用例覆盖 walk/care `growthXP` 不能恢复树能量、非 `treeInjection` 的 `injectedXP` metadata 不能恢复树能量、旧升级椰子不能注入树能量、脏 `oasis_injectedEnergy` preference 无注入 ledger 时不能推进树等级、starter gift 五次 `10XP` 手动注入后才从 Lv0 升到 Lv1。关闭条件：真机完整遛狗停止后椰子树等级不变化；仍只有 Home/Oasis 显式注入能量会推进树等级。
  - 记录：2026-07-11 聚合资金修复的 targeted Unit/Integration 共 32 条通过；Pet-first、无 Human 的 UI 路径连续点击 `home-primary-action` 五次并从 Lv0 到 Lv1，1 条测试通过（41.138 秒）。覆盖岛屿赠礼归属、旧 Pet 赠礼迁移、岛屿储备计入总额、`system:legacy` 排除、聚合扣款、总额不足原子失败和重复注入。

- [ ] 正式岛屿总额不足时尝试生命树注入；当前主人余额不足时尝试电子宠物互动、升星或碎片唤醒。
  - 预期：对应动作被禁用或得体失败；余额不变、不产生负数、不写 `system:legacy` 兜底流水；生命树不得因某个单独成员不足而忽略其他正式可用余额。
  - 记录：

- [ ] 在同一操作日重复触发 Oasis 椰子产出。
  - 预期：每日打卡、生命树每日馈赠、树上椰子、电子宠物小愿望等重复产出不会绕过预算 / 冷却重复发椰子；已发生的打卡或收获事实仍能保留。
  - 记录：

- [ ] Oasis 与 DailyStreak 当天打卡互通。
  - 预期：从任一入口完成当天打卡后，另一入口显示已打卡；当天不会产生第二套 streak 或第二次打卡奖励。
  - 记录：2026-06-17 真机发现打开打卡连击页后关闭无响应或卡死，设备日志出现 `QUARANTINED DUE TO HIGH LOGGING VOLUME`。根因归类为首发可达首帧 P0：`DailyStreakDetailRouteContainer` 仍在 sheet 首帧挂 `Pet` / `Human` / `CareLedgerEvent` 三个 `@Query`，详情页打开后又自动触发当天打卡奖励写入和奖励反馈，导致 sheet 展示 / 关闭、ledger 刷新、奖励 overlay 与日志量在同一交互窗口竞争；同时通用 `OhanaSheetPageScaffold` 关闭按钮的唯一图标被 accessibility hidden，自动化和辅助功能树无法稳定找到关闭动作。处理：DailyStreak 路由迁移到 `RouteFirstFrameDeferredLoad`，首帧只呈现轻数据，下一帧后读取 pets / humans / week ledger 快照；打开详情页的自动打卡保留奖励事实但不主动发布奖励反馈；streak sheet route content 立即挂载，数据读取继续 deferred；通用 sheet close 改为真实可访问按钮；新增首页 streak 入口、DailyStreak screen 和通用 sheet close 测试锚点，并补 `testDailyStreakSheetOpensAndClosesFromHome`。自动验证：`scripts/audit-route-first-frame.sh --all` 通过；`scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testDailyStreakSheetOpensAndClosesFromHome` 通过。人工复测：2026-06-17 真机通过，首页打开打卡连击页后可关闭；随后确认 Oasis 与 DailyStreak 当天打卡互通，未出现第二套 streak 或第二次打卡奖励。关闭条件完成。

- [ ] 打开处于休眠 / 纪念状态的电子宠物详情并执行一键照顾。
  - 预期：文案是低压休眠 / 纪念语义，不说永久死亡；一键照顾后电子宠物回到健康状态，可继续互动，历史记录保留。
  - 记录：

- [ ] 打开首页 Oasis tab、离开再回来，并在 Reduce Motion 下重复一次。
  - 预期：首帧显示稳定的冻结树或轻量壳，不空白；进入后再刷新 live 数据；离开后动画 / 任务停止，Reduce Motion 下不出现突兀动效。
  - 记录：

## Phase 6 Economy

人工验收目标：首发 Economy 是纯单机、可理解、不可刷的轻量经济；正式用户不可达线下兑现入口；隐私只隐藏明细，离世钱包冻结，删除后的钱包退出产品可见面。

自动验收已完成并在 2026-06-16 全仓复验：目标测试覆盖 `system:legacy` 不进正式资产、隐私隐藏钱包计入总额但不出明细、离世钱包拒绝写入并退出活跃财富、删除成员物理移除后不参与钱包写入、特殊奖励无 actor 时归属 active human 且不写 system、成就 / 商店 / 宠物金库冻结钱包拒绝、Shop / Today Focus 兑换门关闭不变量、补记操作日结算与经济模拟；最终纯复审 P0/P1/P2=0；`scripts/module-exit-gate.sh --full` 与 CI run `27607807044` 均通过。

- [ ] 用真实 UI 打开商店并遍历所有分类。
  - 预期：不出现“货币兑换 / 家庭线下兑现 / Cash Exchange”分类、卡片、表单或待处理兑换区块；普通外观 / 头像 / 特效 / 称号 / 加成道具仍可浏览。
  - 记录：

- [ ] 在首页 Today Focus、首页 FAB、全功能菜单中遍历 Economy / Shop 相关入口。
  - 预期：不出现“确认线下收款”“待确认兑换”“已收到”等兑换卡片或动作；普通椰子历史、财富页、商店入口仍可打开。
  - 记录：

- [ ] 准备一个隐私锁住的人类成员钱包，打开 Ohana 财富页和椰子历史页。
  - 预期：全岛 / 当前椰子余额计入该隐私钱包；排行榜、筛选器、个人行和流水明细不泄漏该成员；解锁隐私后明细恢复。
  - 记录：

- [ ] 准备一个已离世成员 / 宠物，并删除一个非当前成员样本后，打开财富页、椰子历史页、成就领奖、商店购买和宠物金库。
  - 预期：离世钱包不进入活跃财富总额、榜单和趋势；历史流水仍可查看；领奖 / 购买 / 金库消费不可执行或显示“已冻结”语义；已删除成员不再作为可选钱包或筛选对象出现。
  - 记录：

- [ ] 在中文、英文、德文及任一长语言下打开财富页、椰子历史页、宠物金库、奖励反馈。
  - 预期：正式可见文案不显示未本地化的中文硬编码；长文本不重叠、不遮挡按钮或数值。
  - 记录：

- [ ] 用较多成员 / 宠物 / 钱包流水的真实数据打开财富页并切换时间范围、筛选对象。
  - 预期：首屏不空白；切换范围和对象时没有明显卡顿；榜单、趋势、总额与筛选结果稳定，不出现已隐藏 / 冻结 owner。
  - 记录：

## Phase 7 Walks

人工验收目标：遛狗只服务活跃狗狗；删除 / 离世对象不再进入启动、统计、详情和首页卡片；真实定位、权限与后台表现符合“只有遛狗中才定位”的边界。

自动验收已完成并在 2026-06-16 全仓复验：`WalkFeaturePolicy` 作为 Walks active dog/lifecycle 统一判定点；非狗、已离世、已删除宠物无法启动遛狗；共享遛狗目标只保留活跃狗狗；删除后的 walk / poop marker 物理移除并不作为产品可见状态；遛狗中标记便便会先写 `PetPottyLog` 与 `CareLedgerEvent`，再走奖励管线；全仓 gate / CI 复验通过。

- [ ] 在真实 UI 中分别准备狗、猫/其他非狗、已离世狗、已删除狗，遍历首页卡片、全功能菜单、宠物详情和 Walks 入口。
  - 预期：只有活跃狗狗可看到并进入开始遛狗；非狗、已离世、已删除宠物没有可达 active Walks 入口，深层返回也不会开始定位。
  - 记录：

- [ ] 在真机上对活跃狗狗执行一次完整遛狗：开始、暂停、继续、停止。
  - 预期：路线、时长、距离、停止总结正常；暂停后距离不继续增长；停止后定位会话结束，UI 回到非 active 状态。
  - 记录：
  - 记录：2026-06-17 真机 / 手测新增回归：首页宠物卡快捷操作点击“开始遛狗”后弹出 sheet / route，而不是已实现过的宠物卡翻面。根因：Home 有多条 quick walk 分支；`ExpandedQuickActionExecutor` 对 `"walk"` 的领域语义仍是调用 `startWalk`，但 Home wiring 把 `startWalk` 和 expanded FAB `quick("walk")` 接到了 `openFullScreen(.walk)` / `petWalkSummary`，同时 `openPetQuickKey("walk")` 与 route sheet modifier 仍各自打开 summary，导致“快捷开始”和“遛狗详情”混用。处理：新增统一 `startWalkFromQuickAction`，执行 `appServices.walking.start(pet:)`、标记 expanded walk card surface 可见并刷新卡片呈现；expanded FAB 分离 `openWalk`（快捷开始）与 `openWalkSummary`（详情 / 历史）；Home quick key 与 route sheet modifier 的 `"walk"` 也回到同一启动入口。验证：`scripts/test-simulator.sh -only-testing:OhanaTests/HomeRouteCoordinatorTests` PASS（30 tests，新增 `expandedFabRouterKeepsQuickWalkOnCardAndDetailWalkInSummary` 锁住 quick walk 与 detail summary 分流）；`scripts/dev-check-changed.sh` PASS；`git diff --check` PASS。关闭条件：真机复测宠物卡展开后点快捷遛狗应卡片翻面进入 walk tracker，不弹 sheet；Walks 详情 / 历史入口仍打开 summary。
  - 记录：2026-06-17 完整遛狗停止路径追加 Oasis 交叉验收：停止遛狗仍可写 walk fact / reward ledger，但 care reward `growthXP` 不能推进椰子树等级；详见 Phase 6 Oasis “连续注入生命树能量”记录。关闭条件：真机停止遛狗后 Walk 总结 / 奖励反馈正常，椰子树等级和注入进度不因本次 walk 自动变化。

- [ ] 在真机定位权限场景中分别测试首次授权、拒绝授权、仅使用期间授权、Always 升级提示。
  - 预期：权限提示清楚；拒绝后不崩溃、不写空路线；只有 active walk 期间出现定位行为，结束 / 暂停 / 无 active walk 后定位指示消失。
  - 记录：

- [ ] 在遛狗中添加便便标记后停止，打开详情地图、遛狗总结、照护记录和奖励反馈。
  - 预期：便便标记出现在本次路线详情；照护事实与奖励反馈得体；没有重复奖励或缺失照护事实。
  - 记录：

- [ ] 准备一个已删除或 legacy recycle-flagged 的 walk / poop marker 样本，打开 DogActivityCard、WalkSummarySheet、WalkDetailView 和 GlobalWalkBanner。
  - 预期：普通统计、周摘要、详情路线和 banner 不显示该 walk / poop marker；不会提供恢复入口。
  - 记录：

## Phase 7 Gacha + Shop

人工验收目标：扭蛋与商店作为首发经济消费出口，可理解、不可套利、状态反馈得体；所有权迁移后真实 UI 与库存表现符合预期。

自动验收已完成并在 2026-06-16 全仓复验（门禁 commit `92763c164`，recheck `8f6c792dc`）：目标测试覆盖大奖概率 2%、概率区间、Shop 新价格、隐藏汇率线性、扭蛋岛屿合资、冻结钱包拒绝、Shop 合资与重复非消耗品不二次扣款、旧 `purchasedShopItems` 导入 SwiftData、备份恢复保留购买记录、Gacha/Shop CloudSync serializer/applier、V67→最新 schema 轻量迁移；CI run `27607807044` PASS。

- [ ] 真机购买一个 App Icon，并处理系统弹窗的成功 / 失败或取消路径。
  - 为什么需要人工：系统 App Icon 切换弹窗与 SpringBoard 图标刷新依赖真机系统行为，单元测试只能验证扣款 / 退款顺序。
  - 预期：成功时先完成购买事实，再切换图标并显示已拥有 / 已选中；失败或取消时按实际出资人退款，不留下已拥有状态。
  - 记录：

- [ ] 真实 UI 打开商店，遍历 App Icon、2.5D 头像、外观特效、称号、加成道具和百宝箱。
  - 为什么需要人工：需要产品主人确认真实布局、分类可理解性和已购 / 库存视觉状态；自动测试已覆盖底层所有权与库存事实。
  - 预期：不出现 Cash Exchange / 线下兑现入口；非消耗品购买后在商店与百宝箱显示已拥有，重复点击不再次扣款；消耗品显示库存或激活状态。
  - 记录：

- [ ] 真实 UI 执行一次扭蛋抽取，并查看抽取结果、收藏进度和椰子历史。
  - 为什么需要人工：抽取动画、结果卡、收藏进度和钱包历史的观感需要真实 UI 目检；业务概率和钱包写入已自动验证。
  - 预期：余额足够或岛屿合资足够时可抽；余额不足或当前主人钱包冻结时得体失败；大奖仍显示 / 发放 500🥥，但入口文案不暗示可套利。
  - 记录：

- [ ] 用带旧版 `purchasedShopItems` 的真实安装样本升级后打开商店和百宝箱。
  - 为什么需要人工：旧安装样本来自真实设备 / 备份数据，无法由当前单元测试完全代表。
  - 预期：旧版已购 App Icon / 特效 / 称号迁入 SwiftData 所有权；加成道具、头像券等消耗品不被误当作永久所有权；旧偏好仍保留。
  - 记录：

- [ ] 切换中文、英文、德文及任一长语言后打开扭蛋和商店全分类。
  - 为什么需要人工：长语言截断、按钮拥挤和商品卡可读性需要真实 UI 目检。
  - 预期：价格、库存、已购、抽取结果、错误提示不重叠、不遮挡主要按钮，长文案可理解。
  - 记录：

## Phase 7 其余中小模块 smoke

人工验收目标：把 `docs/testing-progress.md` 中 Phase 7 标为 `🟢*`、但未在上方单独展开的真实 UI / 真机 / 长语言债合并燃尽。该小节是 dogfooding smoke，不替代自动测试或规则书。

自动验收已完成（2026-06-16，门禁 commit `8f6c792dc`）：Phase 7 模块明细中的 Medication、FamilyTasks、Expenses、DashboardRecords、Calendar、CrewRoster、Documents、Insurance、GrowthUnlock、Privacy、Achievements、Moments、Hygiene、HumanHealth、HumanNotes、Memorial、Milestones、Notifications、Onboarding、PetCare、PhotoAlbum、Plants、Security、Wishlist、Workouts、CareLedger、CatCare、FamilyReports、FunctionMenu 已经通过全仓 audits、fixture tests、`scripts/module-exit-gate.sh --full` 与 CI run `27607807044`。

- [x] Feeding / Food Log：创建喂食计划，立即返回 Food Log / feed mode 区域。
  - 预期：保存计划后 feed mode 立即保持 plan mode，不先闪回 manual；计划历史、今日计划和后续提醒使用同一份最新计划事实。
  - 记录：2026-06-17 真机测试发现 P1：宠物建立喂食计划后，Food Log 页 feed mode 会先回到 manual，过很久才回切到正确 plan mode。根因：保存计划 command 已写入 Event 与 `FeedOperatingMode`，但 QuickFeed 页 deferred refresh 仍用父层 `@Query allEvents` 的旧数组解析 mode；旧数组里没有刚创建的 plan event，`FeedOperatingMode.resolved` 因 `manualReminderEvents.isEmpty` 把 UI 强制拉回 manual，直到外层 query 很久后刷新才恢复。处理：`SaveFeedPlanCommandResult` 带回写完后的 authoritative events；QuickFeed route 用 `latestAllEventsOverride/currentAllEvents` 驱动 feed home snapshot、stock snapshot、overview、plan calendar 和 mode sync；保存 / 删除计划后立即更新 route-scoped events，父层事件数量变更后再释放 override。回归：`ManualFeedCommandTests.savedPlanResultCarriesFreshEventsBeforeRouteQueryCatchesUp` 覆盖“route props 仍为空但 command result 已有计划事件”时 mode 立即解析为 `.manualReminder`。验证：`scripts/test-simulator.sh -only-testing:OhanaTests/ManualFeedCommandTests` PASS（18 tests）；`scripts/dev-check-changed.sh` PASS。
  - 记录：2026-06-17 真机继续发现 P1：设置好喂粮计划后，从首页宠物卡片快捷操作点 `feed`，再点二级菜单左侧 quick check-in 按钮会卡死。复查路径：左侧按钮不是 Food Log sheet，而是 `VerticalHomeEmbeddedQuickActions` 延后一帧后调用 `performPetQuickAction("feed", petID:)`；command 入口虽然会重新 fetch 最新数据，但此前读取的是全量 `Event`，刚建计划后的首次点击会在主线程把全局日历/提醒事实、计划解析、喂食写入和 revision 派发压到同一次交互尾部。处理：`HomeCommandExecutor.fetchQuickCareEvents` 改为只读取当前 pet 直接 schedule 事件，并单独补“今日该 pet 用药 dose 事件”，保留 medication 快捷判断所需事实但不再全仓扫 Event；新增 `HomeCommandExecutorTests.homeFeedQuickActionCompletesFreshPlanWhenCardSnapshotIsStale`，覆盖 Home 卡片快照仍旧但 store 已有新计划时，左侧 quick check-in 直接完成 plan reminder、不打开详情、不触发无关 medication reminder 重排。验证：`scripts/test-simulator.sh -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（183 tests）。关闭条件：真机复测“建喂食计划 -> 回首页宠物卡 feed -> 二级菜单左按钮”不卡死，并立即完成计划打卡。
  - 记录：2026-06-17 真机继续发现 P1：喂食手动模式下，从首页宠物卡片点打卡，出现反重复提醒后点 `Check in anyway` 会卡死。根因：`HomeRouteCoordinator.confirmAntiRepeatAction` 在 alert dismiss 的同一帧同步执行 pending business write；而手动喂食确认动作还绕过了 Home command queue，写完 fact 后没有走普通 Home revision / growth sync 手续。处理：确认按钮现在只清 alert 与 pending action，真实 pending action 通过 `OhanaFrameScheduler.runAfterNextFrame` 延后一帧执行；`VerticalSolidHomeView.performPetQuickAction` 把确认动作重新包进 `enqueueHomeCommand`；`ExpandedQuickActionExecutor` 的 anti-repeat pending action 改为返回 `Bool`，`HomeCommandExecutor` 只在确认后的手动 feed 成功写入时补发 Home mutation，计划 feed 已在 schedule completion 路径发 mutation 时不重复发。验证：`scripts/test-simulator.sh -only-testing:OhanaTests/HomeRouteCoordinatorTests -only-testing:OhanaTests/HomeCommandExecutorTests` PASS（212 tests）。关闭条件：真机复测“manual feed -> 最近已打卡提醒 -> Check in anyway”，alert 应立即关闭，随后完成喂食，不再卡住首页。
  - 记录：2026-06-17 本轮按用户要求由 Codex 在模拟器端完整复现喂食链路，不再只等真机逐项发现。首轮 UI smoke 真实复现 `home-quick-action-menu-feed` 点击后主线程 busy 30s；继续抓样本发现另一轮卡死在 `CoconutRewardFeedbackOverlay.body` / `CoconutRewardFeedbackCenter.enqueue` / `UINotificationFeedbackGenerator` 循环。根因补全：① QuickFeed settings-only sheet 隐藏了 manual default toggle，但仍用 `manualDefaultEnabled=false` 保存，导致 UI 显示 50g、实际保存 0g，首页 Feed 长期停在待设置；② 喂食写 fact 后同步串起 Today Focus completion、Home revision、Growth sync、Oasis / reward feedback，仍把业务派生挤进手指帧；③ `coconutRewardEvents` 用 `@Published lastCoconutRewardEvent` 伪装一次性事件，SwiftUI body 重建后重订阅会重放同一 reward event，造成 overlay / haptic / enqueue 循环。处理：settings-only manual default 强制保存可见克数并强制刷新 QuickFeed snapshot；Today Focus completion、Growth sync 与 Home revision 状态同步改为下一帧 / 延迟合并；奖励事件流改为 `PassthroughSubject` one-shot，并在 overlay 用 event id 去重、haptic 延后执行；新增 `testFeedingManualPlanAndHomeQuickActionSmoke` 覆盖 fresh 首建主人、starter gift、Today Focus 建宠、进入 Feed、保存 manual 默认、首页 quick feed、连续打卡确认、切 plan mode、从首页 plan quick feed。验证：`scripts/test-simulator.sh -only-testing:OhanaUITests/OhanaUITests/testFeedingManualPlanAndHomeQuickActionSmoke` PASS（iPhone 17 simulator，1 UI test，70.422s，xcresult `/var/folders/9j/7ldcxzn91d947mg4p_7wxmz40000gn/T/OhanaDerivedData/main-b6cf423d5931-tests/Logs/Test/Test-Ohana-2026.06.17_18-44-33-+0200.xcresult`）。关闭条件更新：上述三条真机喂食复测仍需用户二次确认，但模拟器已覆盖原 P1 卡死形态与 plan/manual 双模式回归。
  - 记录：2026-06-19 用户真机复测通过：创建喂食计划后立即返回 Food Log，feed mode 仍为 plan mode；首页宠物卡快捷 Feed 的左侧 quick check-in 按钮不卡死；手动模式下打卡并点击 `Check in anyway` 不卡死。该 smoke 子项关闭。

- [ ] Medication / Notifications：创建宠物用药、人类用药、普通提醒和健康关键提醒，并在真机上点通知。
  - 预期：提醒按成员和优先级正确出现；健康关键提醒不被夜间/预算错误延后；通知点击进入 typed route；完成 / 跳过不会重复写账或跳到错误成员。
  - 记录：2026-06-30 模拟器预检通过：`OhanaNotificationsSchedulingTests` 覆盖普通提醒预算上限与 skipped ledger、夜间延后且 App reminder 保持 pending、健康关键用药提醒绕过预算 / 合并 / 夜间延后、同日同成员同分类非用药合并、Observability 中文动作名、notification delegate 区分默认 tap 与 COMPLETE / SKIP / SNOOZE action payload（含 medication / humanMedication 上下文）、ambient once-per-day、关闭偏好跳过、宠物通知取消 subject resolution；`ReminderActionCoordinatorTests` 覆盖通知 action 窄查找、缺失 reminder 不写入、明天再说重排、manual feed complete / deceased executor、离世宠物 Calendar 通知不写历史 fact、Human medication 通知完成写 dose log、离世 Human medication action ignored、Pet medication 通知完成写 dose event / 扣 remaining amount / 重排；`HomeCommandExecutorTests` 覆盖宠物用药计划 create / update / delete 与 revision、人类用药计划 create / update / delete / activation / dose ledger / pending reversal、quick human medication fact / revision / deceased noop、普通 calendar / reminder command 边界；UI 侧 `testReminderObservabilityPanelOpensFromDebugSettings` 覆盖 Settings Debug -> Reminder Observability screen / ledger-card 可达。命令：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-medication-notifications-green-1782850800 scripts/test-simulator.sh '-only-testing:OhanaTests/OhanaNotificationsSchedulingTests' '-only-testing:OhanaTests/ReminderActionCoordinatorTests' '-only-testing:OhanaTests/HomeCommandExecutorTests' '-only-testing:OhanaUITests/OhanaUITests/testReminderObservabilityPanelOpensFromDebugSettings'`；结果：216 selected tests passed，0 failures，xcresult `/tmp/OhanaDerivedData-medication-notifications-green-1782850800/Logs/Test/Test-Ohana-2026.06.30_14-58-50-+0200.xcresult`。本项不关闭：真实 iOS notification permission / delivery、系统通知点按与 action delivery、Focus / DND / lockscreen 行为、`UNUserNotificationCenter` 前台呈现、长语言 banner / lockscreen 外观与真机手感仍需最终验收；Human medication add/readback UI 已由后续记录补齐。
  - 记录：2026-06-30 已补 Human medication add/readback simulator UI 预检：`OhanaUITests.testHumanRecordOperationsPersistFromFeatureHub` 在 pinned `iPhone 17` simulator 通过，覆盖 fresh onboarding / starter gift 后从 Home 人类卡进入 Human Feature Hub，打开 Medication tile，创建 `Vitamin D` human medication，保存后重新进入 Medication tile 并回读到该药名；同一路径还回归 weight / expense / note 的保存与回读。命令：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-human-medication-ui-1782871200 scripts/test-simulator.sh '-only-testing:OhanaUITests/OhanaUITests/testHumanRecordOperationsPersistFromFeatureHub'`；结果：1 UI test passed，xcresult `/tmp/OhanaDerivedData-human-medication-ui-1782871200/Logs/Test/Test-Ohana-2026.06.30_17-12-54-+0200.xcresult`。本项仍不勾选：真实 iOS notification permission / delivery、系统通知点按与 action delivery、Focus / DND / lockscreen 行为、`UNUserNotificationCenter` 前台呈现、长语言 banner / lockscreen 外观与真机手感仍需最终验收。

- [ ] Calendar / DashboardRecords / CareLedger：用密集样本打开日历、统计趋势、照护账本并切换筛选。
  - 预期：首屏不空白；长列表滚动稳定；筛选后不出现已删除成员、已离世 active 写入或错误 subject；账本与照护事实能互相解释。
  - 记录：2026-06-30 模拟器预检通过：`HomeCommandExecutorTests` 在 pinned `iPhone 17` simulator 覆盖 Calendar plan/reminder create、recurring、blank-title skip、completion -> care fact + undo、missing-executor fallback fact write、recurring split/truncate delete、create/complete/delete revision，以及 DashboardRecords / CareLedger 的 weight/expense/shared-expense fallback、delete fact + ledger/revision 边界；UI 侧 `testPetCalendarFilterShowsOnlyPetLinkedEvents`、`testPetCalendarHealthEventRowOpensHealthDetail`、`testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail` 覆盖 Calendar all/pet filter、pet health row deep-link、Water plan Calendar save/delete readback。命令：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-calendar-dashboard-careledger-green-1782842400 scripts/test-simulator.sh '-only-testing:OhanaTests/HomeCommandExecutorTests' '-only-testing:OhanaUITests/OhanaUITests/testPetCalendarFilterShowsOnlyPetLinkedEvents' '-only-testing:OhanaUITests/OhanaUITests/testPetCalendarHealthEventRowOpensHealthDetail' '-only-testing:OhanaUITests/OhanaUITests/testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail'`；结果：194 selected tests passed，0 failures，xcresult `/tmp/OhanaDerivedData-calendar-dashboard-careledger-green-1782842400/Logs/Test/Test-Ohana-2026.06.30_14-34-13-+0200.xcresult`。本项不关闭：密集样本长列表滚动、Dashboard trend / CareLedger 可视筛选、deleted / passed-away / legacy sample 目检与真机手感仍需最终验收。
  - 记录：2026-06-30 追加密集样本 / 账本快照预检通过：`DenseDataSnapshotPerformanceTests` 用 4 pets、4 humans、2 electronic pets、18,000+ events、200+ reminders、100+ tasks、500+ ledger entries、50+ photos 的 fixture 覆盖 Home / Today Focus / Calendar timeline snapshot 预算与 memorial / privacy-locked 维度；`HomeExpensePreviewStoreTests` 覆盖 QuickAction detail / dashboard 从 ledger 读取并按 subject、kind、月份过滤排序；`CareLedgerBackfillActorTests` 覆盖 idempotent backfill、partial-resume 去重、orphan legacy pet logs、pet weight kg 转换、hygiene backfill 和跨 batch care log 处理。命令：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-calendar-careledger-dense-1782865200 scripts/test-simulator.sh '-only-testing:OhanaTests/DenseDataSnapshotPerformanceTests' '-only-testing:OhanaTests/HomeExpensePreviewStoreTests' '-only-testing:OhanaTests/CareLedgerBackfillActorTests'`；结果：26 tests passed，0 failures，xcresult `/tmp/OhanaDerivedData-calendar-careledger-dense-1782865200/Logs/Test/Test-Ohana-2026.06.30_15-20-42-+0200.xcresult`。本项仍不关闭：真实长列表滚动、Dashboard trend / CareLedger 可视筛选、deleted / passed-away / legacy sample 目检与真机手感仍需最终验收。

- [ ] Expenses / Insurance / Documents：添加票据、保单附件、文档附件，并执行删除。
  - 预期：附件可预览；费用 / 保费 / 理赔写入后账本可见；确认删除后附件、费用事实和关联入口退出普通 UI；没有恢复或回收站入口。
  - 记录：2026-06-30 模拟器预检通过：`InsuranceExpenseLedgerTests` 覆盖保单自动缴费写 expense + CareLedger、理赔报销写负向 expense + CareLedger、重复批准不重复写入且不发奖励；`ExpenseReceiptSupportTests` 覆盖保险缴费日期、保险文档费用计划、报销去重、费用汇总、收据附件草稿和中英德文案；`PrivacyHardeningTests` 覆盖图片附件 GPS 元数据清洗、PDF 原始字节保留、收据 / 文档 command 保存前清洗；`PhysicalDeletionServiceTests` 覆盖文档删除同步删除附件并写 tombstone、宠物物理删除级联移除 expense / document / attachment / insurance / claim / CareLedger；`HomeCommandExecutorTests` 覆盖 pet expense 创建收据文档 + 双附件 + ledger、pet document create/update/delete revision、insurance policy/claim create/deactivate/delete revision、保单日历/缴费计划和理赔报销；UI 侧 `testHumanRecordOperationsPersistFromFeatureHub` 覆盖 Human Feature Hub 添加 expense 并回读 note。命令：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-expense-insurance-documents-1782844800 scripts/test-simulator.sh '-only-testing:OhanaTests/InsuranceExpenseLedgerTests' '-only-testing:OhanaTests/ExpenseReceiptSupportTests' '-only-testing:OhanaTests/PrivacyHardeningTests' '-only-testing:OhanaTests/PhysicalDeletionServiceTests' '-only-testing:OhanaTests/HomeCommandExecutorTests' '-only-testing:OhanaUITests/OhanaUITests/testHumanRecordOperationsPersistFromFeatureHub'`；结果：219 selected tests passed，0 failures，xcresult `/tmp/OhanaDerivedData-expense-insurance-documents-1782844800/Logs/Test/Test-Ohana-2026.06.30_14-42-30-+0200.xcresult`。本项不关闭：真实相册 / 文件选择、票据 / 保单 / 文档附件预览、UI 删除后入口消失目检和真机手感仍需最终验收。

- [ ] Privacy / Security：确认首发本地模式隐藏成员级隐私 / PIN 控件，并保留未来多设备成员保护的命令边界。
  - 预期：同一设备内切换成员只改变后续记录归属，不遮挡本地成员资料；Settings 不暴露成员隐私 / PIN 设置入口；已存 privateFields 与 passcode 命令边界保留但不作为首发 UI / 遮挡策略；多设备 / 多真人账户下的跨查看者隐藏验收延后到对应同步身份阶段。
  - 记录：2026-06-30 旧模拟器预检曾证明成员级 PIN / privateFields 命令边界、backup passcode 排除、inactive/deceased 写入拒绝，以及 Settings all-private/all-open UI 回读；该 UI 证据已被首发本地产品策略取代，不再作为 launch acceptance。保留有效部分：`HomeCommandExecutorTests`、`OhanaTests.humanPasscodeValidatesHashesAndLocksAfterFailures`、`OhanaTests.humanPasscodeIsNotIncludedInBackupAndRestore`、`MemberLifecycleGateTests.deceasedMembersRejectPresentationSecurityEconomyAndSettingsWrites` 仍覆盖未来命令边界与备份安全。当前首发验收改为：Settings check-in identity 可切换，成员隐私 / PIN 控件不可达，同设备 viewer 切换后成员资料仍可见。最新验证：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-human-local-privacy-1782913600 scripts/test-simulator.sh '-only-testing:OhanaTests/OhanaTests/privacyServiceMapsHumanQuickActions()' '-only-testing:OhanaTests/OhanaTests/backupRestoresHumanFieldsAndLogRelationships()' '-only-testing:OhanaTests/OhanaTests/privacyServiceCoversHumanSensitiveActions()' '-only-testing:OhanaTests/DenseDataSnapshotPerformanceTests'` PASS（4 Swift Testing tests，xcresult `/tmp/OhanaDerivedData-human-local-privacy-1782913600/Logs/Test/Test-Ohana-2026.06.30_22-11-35-+0200.xcresult`）；`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-human-local-privacy-1782913600 scripts/test-simulator.sh '-only-testing:OhanaUITests/OhanaUITests/testHumanSettingsAccountSwitcherHidesLocalPrivacyControls' '-only-testing:OhanaUITests/OhanaUITests/testHumanProfileStaysVisibleWhenViewedByOtherLocalMember'` PASS（2 UI tests，xcresult `/tmp/OhanaDerivedData-human-local-privacy-1782913600/Logs/Test/Test-Ohana-2026.06.30_22-17-19-+0200.xcresult`）。

- [ ] Onboarding / CrewRoster / FunctionMenu：从全新安装或 App reset 后走首启、建主人、建宠物、切换成员并遍历全功能菜单。
  - 预期：首启没有空白或死路；单人单宠可完成核心路径；功能菜单只显示首发可达功能；联机和植物入口仍被门禁收起。
  - 记录：2026-06-16 真机首测发现首次安装后添加人类，Home 先停在“Add your first pet / 0/1 setup”和 0 椰子一段时间，稍后才出现 starter coconut gift 弹层。根因：人类保存后 Home 预挂载成功，但 starter gift 的 onboarding 评估仍可能被普通 active-human 变化的 480ms 延迟、以及 root handoff 维护延迟遮住，导致用户看到半完成首页等待。处理：`ContentView` 对 fresh onboarding primary human 改为 hasOnboarded 后下一帧 immediate evaluation；普通 active-human 变化仍走原延迟，避免影响常规切换。新增 `OnboardingHandoffResponsivenessTests` 防止回退。验证：`scripts/test-simulator.sh -only-testing:OhanaTests/OnboardingHandoffResponsivenessTests` 在 iPhone 17 simulator 通过；过程中有连接实体机锁屏 warning，但测试目标仍为 simulator。注意：下一轮真机需复测“添加人类后 starter gift 弹层应几乎紧接出现，不再长时间停在 0/1 setup”。
  - 记录：2026-06-16 真机继续测试发现两个 P1 阻塞：第一，覆盖安装 / 重新 build 且不卸载旧 App 时，App 可停在白屏或 icon + Ohana 启动画面；只有卸载重装才恢复。解决方案逻辑：启动恢复不能依赖“干净安装”，必须把保留数据、旧 onboarding 标记、旧 active human、旧 SwiftData store 目录和中断 handoff 当成首发支持路径；本轮已把 SwiftData `ModelContainer` 和 `AppServices` 从 `OhanaApp.init` 同步启动路径移到首帧 `OhanaBootstrapShell` 之后创建，使旧数据 / migration 慢开不再卡在系统启动图，并保留启动耗时指标。第二，添加首个人类和首个宠物后都会长时间卡住。解决方案逻辑：首建保存的手指帧只应做最小 route / snapshot handoff，starter gift、钱包初始化、首页 read model、卡片堆刷新、提醒 / 账本 / 派生效果要延后、可取消、分帧；本轮已将首个人类 ID 直接 handoff 到 `ContentView` 并提前触发 starter gift，同时把 Home join 保存等待从 820ms 前移到 140ms，把标准保存成功关闭等待从 780ms 缩短到 280ms，并把 active-human route/reconcile/evaluation 与 Home refresh 状态写入分帧 / 去重。新增 `OnboardingHandoffResponsivenessTests` 覆盖 bootstrap 延迟创建容器、成员保存等待不回退、Home refresh state 去重。关闭条件：真机覆盖安装不卸载后可稳定启动；首建人/宠保存后首页不长卡，礼包和卡片在可接受时间内出现；再继续 FunctionMenu 首发入口扫描。
  - 记录：2026-06-16 真机复测追加日志：首建 / 首页停顿期间出现 SwiftUI Invalid Configuration：`HomeReadModelRefreshKey` 与 `NavigationRequestObserver` 同帧多次更新。方案补强：把“分帧”从调用约定下沉到 `OhanaFrameScheduler`，确保延迟任务离开当前 main-queue turn；Home read model 从多 `@Published` 改为 `payload` 单发布；Home revision/day token watcher 用 pending 合并；AppRouteCoordinator 对重复 sheet/fullScreen/path 更新做 no-op guard。关闭条件同步升级为：除不白屏 / 不长卡外，真机 console 不再出现这两条 SwiftUI same-frame fault。
  - 记录：2026-06-16 深挖后修正：上一轮“延后一帧挂载 Home”仍然把完整首页体系带进 onboarding 保存窗口，实机旧数据下仍可能卡住。最终方案改为 RootView preflight 不再挂载 `ContentView` / `NavigationStack`；`ContentView` 只能在 `hasOnboarded` 后出现；加入岛屿后 Home read model 与 Home appear warmup 通过 `OnboardingHomeJoinHandoffGate` 获得 240ms / 180ms 缓冲。根因归档：保存链、视觉 handoff 链、Home 聚合链之前没有硬边界。下一轮真机需用“不卸载覆盖 build + 旧数据”复测启动、首建人、首建宠，并观察 console 是否还有 `HomeReadModelRefreshKey` / `NavigationRequestObserver` same-frame fault。
  - 记录：2026-06-16 本轮自动复现与补强：fresh 首建人类在视觉到 Home 后仍会因 SwiftUI / accessibility snapshot 忙碌超时，sample 指向 `CoconutRewardFeedbackOverlay` 参与首帧 AttributeGraph 更新，console 同步出现 `NavigationRequestObserver` same-frame fault。处理同 GAP-8：starter gift 静默写账、专用 ceremony 负责反馈；onboarding createdEntitySignal 与 starter evaluation 通过 `OnboardingHomeJoinHandoffGate` 延后到 Home 稳定窗口；UI test 用 `-OHANA_UI_TESTS` 隔离全局 reward overlay。验证：fresh 首建人类 UI test 通过；保留数据直接重启 App 可到 Home + starter gift，未见 same-frame fault。下一步人工仍先测首宠创建、starter gift 关闭、FunctionMenu 首发入口扫描和真机覆盖安装旧数据。
  - 记录：2026-06-16 首宠路径追加自动复现与修复：从 fresh 首建人类进入 Home，关闭 starter gift 后点击 Today Focus 的首宠按钮，生产 overlay 打开时会卡在 `Create Pet Card` handoff 画面；sample 显示主线程被全局 coconut reward overlay 的 burst/dots/numeric 动效卷入 SwiftUI update。处理：首宠 welcome reward 不再发全局 reward feedback；全局 reward overlay 瘦身为轻量 pill，不在 sheet dismissal 同帧跑 burst dots；新增 `testCreateFirstPetFromTodayFocusWithProductionOverlaysAfterFirstHuman` 覆盖真实生产 overlay 条件。验证：该 UI test 已在 iPhone 17 simulator 通过（26.74s），3 分钟日志未见 same-frame fault。下一步人工按顺序复测：真机覆盖安装旧数据启动、首建主人、关闭 starter gift、Today Focus 建首宠、切换成员、FunctionMenu 首发入口扫描。
  - 记录：2026-06-16 覆盖安装旧数据启动阻塞继续处理：启动层已改为极轻 bootstrap shell + 首帧后后台打开 SwiftData + startup probe，防止旧 store / migration / AppServices 初始化把用户留在系统 launch screen。验证：simulator build 与 `OnboardingHandoffResponsivenessTests` 通过，probe 顺序到 `bootstrap.payload-set`；真机 `Ohana Local Device` 覆盖安装已完成。附带环境问题：本机 Codex 进程创建的真机 app bundle 根目录会带 `com.apple.FinderInfo` / hidden flag，Xcode final CodeSign 报 `resource fork, Finder information, or similar detritus not allowed`；已增强 `scripts/strip-build-xattrs.sh`，本轮通过手动清 FinderInfo 后真实签名并安装。剩余人工项：由于 CoreDevice launch/query 卡在 usage assertion，Codex 无法代替用户确认屏幕状态；用户下一步先手动点开真机 Ohana，观察是否进入 bootstrap shell/Home，并在卡住时回传 `ohana-startup-probe.log` 或截图。
  - 记录：2026-06-17 首发 smoke 自动路径已扩展到“首启 reset -> 建主人 -> starter gift -> Today Focus 建宠物 -> Home Oasis -> 注入能量 -> Settings”。根因补强同 GAP-8：Home 内嵌 Oasis 不应挂完整 live reward view，也不应为了 FAB 注入把 ledger/economy/snapshot 重活带进 tab 首帧；Settings 只作为首帧可打开性验收，不再允许卡在 opening shell。验证：`testFirstReleaseReachableHomeOasisAndSettingsSmoke` PASS（40.151s），`scripts/build-debug-fast.sh` PASS，最近 simulator 日志未见同帧 SwiftUI fault。下一步人工按这条顺序复测真机；通过后再继续 FunctionMenu / CrewRoster 的人工扫描。
  - 记录：2026-06-17 覆盖安装 / 启动层真机复验追加：同 GAP-8，`Ohana Local Device` 在 `Guanchen’s iPhone`（UDID `00008150-001270342EA3401C`）上完成 `/tmp` 派生目录构建、签名、覆盖安装和 `devicectl process launch`；设备容器中的 `ohana-startup-probe.log` 本次记录到 `bootstrap.payload-set`，证明覆盖安装后不再停在系统 icon / bootstrap 之前。物理 UI smoke 自动化仍因标准 Debug profile 与 LocalDeviceDebug test target 配置不可用而未跑；人工继续从“已安装 LocalDevice app”开始，按 Onboarding / 首宠 / Home Oasis / Settings 路径复测。
  - 记录：2026-06-17 首发核心链路物理 UI smoke 已补跑通过：`LocalDeviceDebug` test targets 配置后，`testFirstReleaseReachableHomeOasisAndSettingsSmoke` 在 `Guanchen’s iPhone` PASS（46.921s）。路径包含 launch/reset、创建首个人类、starter gift、从 Today Focus 创建首宠、切 Home Oasis、点击 FAB 让 Lv0 -> Lv1、打开 Settings。Settings 首轮物理 crash 已按 GAP-8 记录通过拆分 / 类型擦除修复。结论：Onboarding / 首宠 / Home Oasis / Settings 的首发 P0 核心链路自动化通过；FunctionMenu / CrewRoster / 其他模块真实 UI 扫描仍继续作为普通验收债。
  - 记录：2026-06-17 route-first-frame 假绿修复后重新跑同一条物理 smoke：`testFirstReleaseReachableHomeOasisAndSettingsSmoke` 在 `Guanchen’s iPhone` 再次 PASS（53.049s，xcresult `/tmp/ohana-device-route-first-frame-p0/Logs/Test/Test-Ohana-2026.06.17_14-07-40-+0200.xcresult`）。本次覆盖的是迁移 `AppAccountSwitcherRouteContainer` / `AppSettingsSheetRouteContainer` 和 Oasis service fetch 收口之后的代码，不再复用上一条旧证据。结论：Onboarding / 首宠 / Home Oasis / Settings 的首发 P0 核心链路在 route-first-frame 审计修正后仍绿。
  - 记录：2026-06-19 真机继续手测发现 P1：添加非首个人类或宠物后，保存完成会进入详情页，而首个人类 / 宠物是回到首页。根因：CrewRoster inline add 把“新增保存完成”和“选择已有成员”共用 `onSelectPet` / `onSelectHuman` 回调；两个上层 route container 都把 select 语义解释为打开详情，因此新增第二个成员会被当作用户点选已有卡片。处理：新增 `CrewRosterInlineAddCompletion` 与 `onInlinePetSaved` / `onInlineHumanSaved` 回调，inline add 保存完成只关闭新增 route 并走 Home 新成员保存 handoff；选择已有成员仍保留打开详情语义。补充判断：Home 卡片长按路径本身对首个人类和非首个人类相同，均进入同一人类 profile route；用户看到的“详情不一样”来自 CrewRoster / sheet / inline add 等卡片式入口混用不同 route。自动验证：路径审计、UI / a11y / smoothness / route-first-frame / runtime guardrail 通过；targeted simulator test 在本机 `xcodebuild` invocation 后无输出并被中止。关闭条件：真机从 CrewRoster 或首页新增第二个人类 / 宠物后应直接回首页并显示新卡片，不自动打开详情；在首页长按任意人类卡片进入的详情页应一致。
  - 记录：2026-06-19 产品交互规则更新：人类 / 宠物详情页入口统一改为“首页卡片放大后的右上角按钮”，不再使用长按卡片进入详情。处理：`FocusHomeVerticalSolidScene` 展开态新增右上角详情按钮，人类使用 person 图标、宠物使用 pawprint 图标；展开卡片本体和透明返回层移除长按详情手势，点击非按钮区域仍返回首页；旧 `FocusHomeWalletCardStackItem` 残留的“长按进入基本信息”提示和 hero 长按手势同步清理。验证：UI / a11y / smoothness / route-first-frame / runtime guardrail path audits 与 `git diff --check` 通过；2026-06-19 用户真机确认“点击卡片只放大；长按放大卡片不进入详情；只有右上角按钮进入对应人类 / 宠物详情页”。该交互关闭。
  - 记录：2026-06-19 真机复测追踪到展开态视觉瑕疵：卡片放大后 quick action 按钮会闪一下，新的右上角详情按钮跟着 quick action 节奏一起出现，同时卡片 surface 自带的旧右上角状态元素（`ok` / 椰子）仍留在展开态。处理：quick action thaw 从最后一刻挂载改为展开后段平滑淡入，避免 ready 时 opacity 跳变；详情按钮显示从 quick action reveal 中解耦，改为随卡片 hero 进度独立淡入，只有展开稳定后才允许点击；旧 status badge 跟随 compact header 在展开时淡出。关闭条件：真机卡片放大后右上角只保留详情按钮，旧 `ok` / 椰子 badge 不显示；详情按钮不再随 quick action 按钮闪动，快捷操作按钮自身不再 late-pop 闪烁。
  - 记录：2026-06-19 真机复测发现 P1：人类详情页只有第一个 / 当前 active human 显示删除成员按钮，其余人类详情没有删除入口；所有人类详情都没有标记离世按钮，而宠物详情正常。根因：`HumanDetailView` 和 `HumanBasicInfoDetailView` 各自散写危险区，并把删除入口绑在 `isViewingOwnProfile` 上；人类离世 command 已存在，但 full detail / basic info 未接 UI，只有 CrewRoster 编辑器有局部入口。处理：新增共享 `HumanLifecycleDangerZone`，full detail 和 basic info 都消费同一个“标记离世 / 撤销离世 / 彻底删除”组件；删除不再受 active human 限制，仍走输入姓名确认与既有 delayed destructive command；标记 / 撤销离世走 `MemberCommandExecutor.markHumanPassedAway` / `undoHumanPassedAway` 并发布 member lifecycle revision。验证：Members path UI / a11y / smoothness / route-first-frame / runtime guardrail audits 与 `git diff --check` 通过。关闭条件：真机任意人类详情页都显示标记离世和彻底删除；标记后显示离世摘要与撤销离世；删除仍不卡死并正确回到首页 / 账户切换流程。
  - 记录：2026-06-19 真机继续复测：展开卡片后右上角详情按钮已正常，但 quick action 按钮本身仍闪一下。二次根因：`FocusHomeVerticalSolidQuickActionLayer` 在 `isReady` 临界点从 clipped 分支切到 unclipped 分支，会重建操作层子树；视觉上表现为展开末段闪动。处理：quick action 层改为单一稳定树，始终使用同一个 reveal clip / opacity / disabled-animation 事务，只在 `isReady` 时打开 hit testing，避免 ready 阶段换分支。关闭条件：真机展开卡片后 quick action 不再闪，右上角详情按钮继续保持独立稳定。
  - 记录：2026-06-19 真机继续复测：删除人类后卡死，console 同时出现 TextInputUI `containerToPush is nil` 和 `Result accumulator timeout`。判断：日志本身更像键盘候选系统噪声，但触发点说明确认 sheet 的输入焦点、sheet dismiss、详情 route dismiss 和 destructive deletion handoff 仍挤在同一交互窗口。处理：人类删除确认 sheet 对齐宠物删除，补 `FocusState`、提交删除前先 resign keyboard、姓名匹配使用共享 `ConfirmationNameMatcher`；确认后先关闭 sheet 并延后 180ms 再进入详情 dismiss + 既有 delayed destructive command。关闭条件：真机删除任意人类不再卡死，删除后回到首页或账户切换状态，剩余卡片刷新不需要手动切 tab。
  - 记录：2026-06-19 真机继续复测：删除人类后 App 会停在首个人类的放大卡片页面，关闭并重开 App 后恢复正常。根因补充：破坏性删除虽然会发 `humanDeleted` route event 并 reset navigation root，但 Home 卡片栈缺少“外部删除事件强制归零 expanded/hero/header 状态”的显式输入；之前只靠 `onDisappear` 或卡片集合变化间接 reconciliation，真机时序下仍可能把旧 expanded 状态留在 Home。处理：`ContentView` 收到 `humanDeleted` 时刷新 `homeCardStateResetToken`，一路传入 `VerticalSolidHomeDashboardPage`，卡片栈收到 token 后无动画清理 `selectedCardId`、`activeHeroSnapshot`、hero progress、header context、expanded/animating flags；同时补 `cardIdentityKey` 变化时触发 selection reconciliation。关闭条件：真机删除任意人类后不能停在任何放大卡片页；返回 Home 时卡片栈应处于普通折叠态，剩余人类 / 宠物卡即时可见且可点击。

- [ ] PetCare / CatCare / Hygiene / Moments：执行快捷照护、猫砂、护理和 quick moment。
  - 预期：事实保存、奖励反馈、账本、Today Focus 状态和历史记录一致；重复点击不会重复奖励；已故对象只读或 no-op。
  - 记录：2026-06-30 已补一轮模拟器 / 业务层预检：`HomeCommandExecutorTests` 在 pinned `iPhone 17` simulator 上整套通过（191 tests），覆盖 Home 快捷照护、喂食计划 / 手动喂食、Water、Potty / litter、Hygiene、Health、Play、quick moment、Pet Photo Album、CareLedger / reward / cooldown / duplicate guard、已故 / 冻结钱包 fallback，以及 CatCare litter record / undo / revision 等命令边界；其中 `quickMomentServiceWritesPhotoFactAndLedger()`、`momentCommandExecutorPublishesQuickMomentRevision()`、`repeatableMomentRewardUsesBudgetAndCooldownPipeline()` 证明 quick moment 会写入照片事实 / ledger、发布 revision，并走预算与冷却奖励管线。验证：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-moments-petcare-preflight-1782829200 scripts/test-simulator.sh '-only-testing:OhanaTests/HomeCommandExecutorTests'` PASS（191 tests，xcresult `/tmp/OhanaDerivedData-moments-petcare-preflight-1782829200/Logs/Test/Test-Ohana-2026.06.30_14-04-57-+0200.xcresult`）。更早一次只筛 3 个 Swift Testing 方法的命令实际执行 0 tests，已丢弃不计证据。本项仍不勾选：现有 Pet GUI 长会话和本轮业务层已覆盖大部分模拟器可验证内容，但最终真机视觉手感、长时间连续点击、历史记录跨页读回和低性能设备手感仍需人工签收。

- [ ] Achievements / Milestones / GrowthUnlock / Wishlist：完成一次成就领取、里程碑创建、成长解锁查看和心愿单兑换。
  - 预期：奖励和消费都进入正确钱包/账本；余额不足和冻结钱包反馈得体；长文案不遮挡主要按钮。
  - 记录：2026-06-30 已补模拟器 / 业务层预检：`HomeCommandExecutorTests`、`HumanWishlistCommandTests`、`GrowthUnlockPolicyTests` 与 `OhanaUITests.testHumanWishlistRedeemSpendsCoconutsFromFeatureHub` 在 pinned `iPhone 17` simulator 上同批通过。业务层覆盖成就奖励领取只写一次并进入 ledger、冻结钱包不领取、宠物里程碑 seed / 创建奖励 / 删除 ledger、心愿单创建 / 兑换 / 删除 revision、余额不足 no-op、成长解锁策略与 roadmap 可见性；UI 层覆盖 fresh onboarding 后从 Human Feature Hub 创建心愿并完成兑换，验证 `human-wishlist-redeemed-state`。验证：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-achievements-growth-wishlist-1782832800 scripts/test-simulator.sh '-only-testing:OhanaTests/HomeCommandExecutorTests' '-only-testing:OhanaTests/HumanWishlistCommandTests' '-only-testing:OhanaTests/GrowthUnlockPolicyTests' '-only-testing:OhanaUITests/OhanaUITests/testHumanWishlistRedeemSpendsCoconutsFromFeatureHub'` PASS（unit side: 204 tests in 3 suites；UI side: 1 test；xcresult `/tmp/OhanaDerivedData-achievements-growth-wishlist-1782832800/Logs/Test/Test-Ohana-2026.06.30_14-08-20-+0200.xcresult`）。本项仍不勾选：成就墙 / 里程碑 / 成长解锁的真实 UI 文案、按钮遮挡与真机触感尚未逐项人工签收，当前证据主要证明业务边界和心愿单 UI 兑换。

- [ ] HumanHealth / HumanNotes / Workouts：添加、查看、删除人类健康、笔记和锻炼记录。
  - 预期：首发本地同设备查看者切换不遮挡成员资料；删除后普通入口不再显示；不会产生错误奖励或错误成员 revision。
  - 记录：2026-06-30 已补模拟器 / 业务层预检：`HomeCommandExecutorTests` 与 `OhanaUITests.testHumanExtendedModuleOperationsPersistFromFeatureHub` 在 pinned `iPhone 17` simulator 上同批通过。业务层覆盖 quick / detail workout 写入 ledger、workout 删除移除 fact 与 ledger、health metric 写入 / 删除、health report 创建 / 更新 / 删除与 revision、human note 写入附件 / reminder 与删除 no-op 边界，并覆盖 quick workout / medication / metric / note revision 发布；UI 层覆盖 fresh onboarding 后从 Human Feature Hub 添加健康指标、锻炼记录、健康报告、心愿单和 Basic Info 个人资料笔记并完成回读。验证：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-human-health-notes-workouts-1782836400 scripts/test-simulator.sh '-only-testing:OhanaTests/HomeCommandExecutorTests' '-only-testing:OhanaUITests/OhanaUITests/testHumanExtendedModuleOperationsPersistFromFeatureHub'` PASS（unit side: 191 tests；UI side: 1 test；xcresult `/tmp/OhanaDerivedData-human-health-notes-workouts-1782836400/Logs/Test/Test-Ohana-2026.06.30_14-13-57-+0200.xcresult`）。本项当时仍不勾选；后续记录继续补齐删除与隐私查看者切换，最终仍需真机键盘 / 长文案 / 手感逐项人工签收。
  - 记录：2026-06-30 已补删除后入口消失的 simulator UI 预检：`OhanaUITests.testHumanExtendedModuleDeletesDisappearFromFeatureHub` 在 pinned `iPhone 17` simulator 通过，覆盖 fresh onboarding 后从 Human Feature Hub 创建并删除 TSH 健康指标、Workout、Health Report 和 Human Note，并逐项断言删除后可见入口 / 行不再存在。过程中修复真实可达性 / 路由缺口：Human Feature Hub -> Checkup Metrics 加回 `NavigationStack` 以允许进入指标详情；TSH metric detail 补稳定 delete action 标识和可点击 hit area；Home 人类 workout quick action 支持长按进入 history/detail；Workout history 关闭按钮补 `human-workout-close-action`，UI test 关闭 helper 不再把隐私锁按钮误当返回键。验证：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-human-delete-ui-current-1782867600 scripts/test-simulator.sh '-only-testing:OhanaUITests/OhanaUITests/testHumanExtendedModuleDeletesDisappearFromFeatureHub'` PASS（1 UI test，xcresult `/tmp/OhanaDerivedData-human-delete-ui-current-1782867600/Logs/Test/Test-Ohana-2026.06.30_16-12-39-+0200.xcresult`）。本项仍不勾选：隐私查看者切换已由后续记录补齐；真机键盘 / 长文案 / 手感，以及真实设备上的最终视觉签收仍未完成。
  - 记录：2026-06-30 旧“隐私查看者切换”模拟器预检曾证明 all-private owner 对 viewer 显示 private lock；该验收已被首发本地策略取代。当前期望是 `OhanaUITests.testHumanProfileStaysVisibleWhenViewedByOtherLocalMember`：fresh owner + viewer、切换 active human 到 viewer、通过 UI-test typed Human profile route 打开 owner profile，并断言不出现 private profile lock。该测试已在 pinned `iPhone 17` simulator 通过（见 Privacy / Security 条目同一 xcresult）。本项仍不勾选：真机键盘 / 长文案 / 手感，以及真实设备上的最终视觉签收仍未完成。

- [ ] PhotoAlbum / FamilyReports：打开相册大图、批量照片样本和家庭周报。
  - 预期：大图不卡死、不泄漏隐私附件；周报只表达照护周报，不出现悬赏榜、协作排行或多人竞赛暗示。
  - 记录：2026-06-30 已完成家庭周报中可由模拟器覆盖的语义预检：周报贡献文案改为照护摘要 / 照护者语义并用 `SingleMemberFamilyShapePresentationTests` 阻止“排行 / 最多 / 本周之星 / ranking / Most care / Star of the week”等竞赛文案回流；`FamilyWeeklyReportDashboardView` 补稳定 UI 标识；`ManualFeedCommandTests.quickFeedManualRecordAppearsInWeeklyReportEntries()` 证明 QuickFeed 手动喂食写出的 `CareLedgerEvent` 会进入周报统计条目；`OhanaUITests.testFamilyWeeklyReportOpensFromDebugSettingsWithoutCompetitionCopy` 通过 Settings UI-test shortcut 在 iPhone 17 simulator 打开家庭周报并验证 screen、成员贡献卡、最近活动卡和无竞赛文案。验证：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-family-weekly-report-semantics-1782824400 scripts/test-simulator.sh '-only-testing:OhanaTests/ManualFeedCommandTests'` PASS（23 tests，xcresult `/tmp/OhanaDerivedData-family-weekly-report-semantics-1782824400/Logs/Test/Test-Ohana-2026.06.30_13-57-54-+0200.xcresult`）；`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-family-weekly-report-semantics-1782824400 scripts/test-simulator.sh '-only-testing:OhanaUITests/OhanaUITests/testFamilyWeeklyReportOpensFromDebugSettingsWithoutCompetitionCopy'` PASS（1 UI test，xcresult `/tmp/OhanaDerivedData-family-weekly-report-semantics-1782824400/Logs/Test/Test-Ohana-2026.06.30_13-58-30-+0200.xcresult`）。本项仍不勾选：相册大图、批量照片样本、隐私附件泄漏检查、以及最终真机视觉 / 性能手感签收还未完成。
  - 记录：2026-06-30 已补相册侧模拟器预检与一个真实隐私缺口修复：`PetPhotoAlbumCommandService.createPhotos` 与 `MomentCommandService.recordMoment` 入库 `PetPhotoLog.imageData` 前复用 `AttachmentPrivacySanitizer` 清洗图片 bytes，防止 EXIF GPS 等源图片元数据进入 SwiftData，同时保留 quick moment 显式位置字段。`PrivacyHardeningTests` 新增 `petPhotoAlbumSanitizesImageBytesBeforeSave()` 与 `quickMomentSanitizesPhotoBytesBeforeSave()`，连同既有附件隐私测试在 pinned `iPhone 17` simulator 通过（8 tests，xcresult `/tmp/OhanaDerivedData-photoalbum-privacy-1782861600/Logs/Test/Test-Ohana-2026.06.30_15-13-42-+0200.xcresult`）。相册业务边界同批预检通过：`HomeCommandExecutorTests` 覆盖相册批量 create / note update / delete、revision 发布和 tombstone；`CareCompletionChokepointCharacterizationTests` 覆盖 quick moment 照片事实不混入 care facts / ledger / reward 以及离世宠物 memorial moment 只写照片；`PhysicalDeletionServiceTests` 覆盖永久删除宠物级联移除 `PetPhotoLog`；`DenseDataSnapshotPerformanceTests` 覆盖 dense fixture 至少 50 条照片样本；`MemberLifecycleGateTests` 覆盖相册 / moments timeline 使用 route-scoped photo rows 而非 `pet.photoLogs` 广读，以及离世宠物 memorial photo 无照护派生。验证命令：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-photoalbum-privacy-1782861600 scripts/test-simulator.sh '-only-testing:OhanaTests/HomeCommandExecutorTests' '-only-testing:OhanaTests/CareCompletionChokepointCharacterizationTests' '-only-testing:OhanaTests/PhysicalDeletionServiceTests' '-only-testing:OhanaTests/DenseDataSnapshotPerformanceTests' '-only-testing:OhanaTests/MemberLifecycleGateTests'` PASS（330 tests，xcresult `/tmp/OhanaDerivedData-photoalbum-privacy-1782861600/Logs/Test/Test-Ohana-2026.06.30_15-16-30-+0200.xcresult`）。本项仍不勾选：真实 PhotosPicker 权限 / picker 行为、相册大图 viewer、真实批量照片样本的视觉与性能、以及最终真机视觉 / 隐私 / 手感签收还未完成。

- [ ] Memorial / Plants：打开纪念对象历史资料，并用带历史植物数据的样本遍历首页、Today Focus、Oasis、FunctionMenu。
  - 预期：纪念对象历史可读但无活跃写入；首发植物功能不可达，历史植物数据不影响当前可见状态或奖励。
  - 记录：2026-06-30 模拟器预检通过：植物 / route 侧 `PlantFeatureGateXCTests`、`PlantLaunchTests`、`HomeRouteCoordinatorTests` 在 pinned `iPhone 17` simulator 通过，覆盖 Plant entry surface 需 Lv4 或 existing plant data grandfather、locked preview / catalog favorite 不解锁入口、植物任务只在 includesPlants 时生成、Plant FunctionMenu / AddEntity 在 Lv4 前导向 growth roadmap、Lv4 后才允许进入、历史植物 care logs / photos / reminder preferences backup round-trip、植物 reminder materialization / mute / defer / deep-link、植物 Calendar completion / reminder completion 写 care log + ledger、聚合植物任务完成条件、植物照护奖励 / 冷却 / member daily budget / Oasis care echo / shop free boundary。纪念生命周期侧完整 `MemberLifecycleGateTests` 通过，覆盖 memorial content 允许历史/档案内容但不允许 care fact / derived effects / economy、离世对象 Feature Hub 只暴露 memorial-safe destinations、纪念文案不使用回收站 / 待删除 / 30-day 语义、冻结钱包历史 ledger 仍可读但 active total 排除、FunctionMenu / 周报活跃贡献排除离世成员、离世对象不能写 walk goal / summary / care facts / family tasks / privacy/security/economy/settings，且 memorial photo 可写但无照护派生。命令：`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-memorial-plants-1782852600 scripts/test-simulator.sh '-only-testing:OhanaTests/PlantFeatureGateXCTests' '-only-testing:OhanaTests/PlantLaunchTests' '-only-testing:OhanaTests/HomeRouteCoordinatorTests'`，结果 84 tests passed，xcresult `/tmp/OhanaDerivedData-memorial-plants-1782852600/Logs/Test/Test-Ohana-2026.06.30_15-08-34-+0200.xcresult`；`DERIVED_DATA_PATH=/tmp/OhanaDerivedData-memorial-plants-1782852600 scripts/test-simulator.sh '-only-testing:OhanaTests/MemberLifecycleGateTests'`，结果 102 tests passed，xcresult `/tmp/OhanaDerivedData-memorial-plants-1782852600/Logs/Test/Test-Ohana-2026.06.30_15-07-40-+0200.xcresult`。本项不关闭：真机仍需用实际纪念对象历史资料和带历史植物数据样本遍历 Home / Today Focus / Oasis / FunctionMenu，确认视觉入口、长列表/长文案、历史资料语气和手感；本轮没有跑植物完整 GUI create/care/delete 长链，也没有替代真实历史样本目检。

## 验收后记录规则

- 人工验收通过后，在对应条目的“记录”后补日期、设备 / 构建、结果。
- 人工验收发现真实余留项时，写入 `docs/task-follow-ups.md`，并在本文对应条目下标注 follow-up 链接或标题。
- 新 GAP 或模块的人工验收项追加到本文，不再创建单独的 `gap-*-acceptance-track-list.md` 或模块 track list 文件。
