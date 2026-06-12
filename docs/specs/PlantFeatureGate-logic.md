# PlantFeatureGate Logic

## Purpose

`PlantFeatureGate` 是 D19 / GAP-12 的单一首发判定点。首发版本聚焦宠物照护，植物作为未来模块保留模型、数据层和代码，但用户不可到达任何植物功能面。

植物门与 `OnlineFeatureGate` 互不耦合：联机关闭不代表植物关闭，植物关闭也不代表联机关闭。未来若植物作为免费更新、付费解锁或与联机套餐组合推出，调用方仍只问 `PlantFeatureGate`，由 gate 内部演进到 entitlement / 远端配置 / 本地开关。

## Launch Semantics

- 首发 gate 恒为关闭。
- gate 关闭时，用户不能添加植物、看到植物 tab、打开植物卡片、进入植物详情、从 FunctionMenu 进入植物面、收到植物 quest、看到植物心情/负反馈信号。
- `Plant`、`PlantCareLog`、Plants 模块源码、备份/恢复、回收站底层、CloudSync registry 保留，用于数据安全、未来迁移和解锁时复用。
- gate 不依赖 `OnlineFeatureGate`、CloudKit、iCloud、家庭人数、build configuration、UserDefaults 字符串或订阅 product id。
- gate 关闭时，植物历史事实不应影响首发用户可见体验；数据可以留存，但 Today Focus、Oasis 可见状态、心情信号不得因为植物数据改变。

## Collected Surfaces

### Single Decision Point

- `Ohana/Domain/Services/PlantFeatureGate.swift`：唯一产品判定点，首发恒返回 false。
- `Ohana/App/AppFeatureRouteGuard.swift`：路由、FunctionMenu、Home tab、AddEntity、读模型加载统一委托到 `PlantFeatureGate`。
- `Ohana/Features/GrowthUnlock/GrowthUnlockPolicy.swift`：只保留未来等级/路线图语义，不再用 `plantsAreOutOfScope` 充当首发植物门。
- `Ohana/Features/Members/Views/AddEntityRoute.swift`：`EntityType.plant.isAvailable` 委托到 `PlantFeatureGate`，不再硬编码 false。

### Home And App Routes

- `Ohana/App/ContentView.swift`：`onOpenPlant` 保留未来回调，当前 `AppRouteCoordinator.openPlant` 拦截。
- `Ohana/App/AppRouteCoordinator.swift`：`openPlant` 和 `.plantProfile` push 必须 gate closed 时 no-op / intercept。
- `Ohana/App/RouteContainers/AppRouteDestinationContainers.swift`：`.plantProfile` destination gate closed 时不得挂载 `AppPlantRouteContainer`。
- `Ohana/Features/Home/HomeRouteCoordinator.swift`：`openAddEntity(.plant)` gate closed 时只进入安全 fallback，不打开添加植物页。
- `Ohana/Features/Home/VerticalSolidHomeModels.swift`：`.plants` tab 保留枚举，`visibleTabs` gate closed 时不包含 `.plants`。
- `Ohana/Features/Home/Views/VerticalSolidHomeView*.swift` 和 `VerticalSolidHomeBottomBar.swift`：植物 page / center action / bottom label 保留未来代码，gate closed 时不进入。
- `Ohana/Features/Home/HomeReadModelStore.swift`：gate closed 时不 fetch `Plant`。
- `Ohana/Features/Home/VerticalSolidHomeSnapshotBuilder.swift`：gate closed 时不生成植物快照、植物签名或 Today Focus 植物输入。

### Function Menu

- `Ohana/Features/FunctionMenu/FunctionMenuModels.swift`：`.plants`、`.plantsDashboard`、`.plantDetail` 保留为未来 route 值。
- `Ohana/Features/FunctionMenu/Views/FunctionMenuRootView.swift`：候选功能组可包含 `.plants`，但 visible filter 必须经 `AppFeatureRouteGuard`，gate closed 时不显示。
- `Ohana/Features/FunctionMenu/Views/FunctionMenuSheet.swift`：direct landing 初始目的地必须先经 `visibleFunctionDestination`。
- `Ohana/Features/FunctionMenu/Views/FunctionMenuDestinationRouter.swift`：Plants destination 保留，gate closed 时由上层 router decision suppress，不挂载植物页面。

### Today Focus, Quest, And Mood

- `Ohana/Features/TodayFocus/IslandQuestEngine.swift`：gate closed 时，即使调用方传入 `plants`，也不得产生 `q_water_plant*` / `q_fertilize_plant*`。
- `Ohana/Features/Home/Views/FocusHomeAuxiliaryViews.swift`：gate closed 时 Today Focus snapshot 不保留植物快照、植物 quest 或植物 negative signal。
- `Ohana/Shared/Components/IslandNegativeFeedback.swift`：gate closed 时不读取植物缺水/叶子发黄信号。
- `Ohana/Features/Home/Views/VerticalSolidHomeView+TodayFocus.swift`：植物 quest/negative tap 保留未来逻辑，gate closed 时上游无植物卡；防御性打开也必须 no-op。
- `Ohana/Features/TodayFocus/Views/TodayFocusCard+Runtime.swift` 与 `TodayFocusCard+ContentCards.swift`：植物 quest 渲染能力保留，gate closed 时 snapshot 不含植物输入。
- `Ohana/Features/Economy/TodayFocusEconomyService.swift`：gate closed 时不 fetch plants、植物 quest 不参与可见完成/奖励判断。

### Plants Module Body

- `Ohana/Features/Plants/PlantRouteContainer.swift`
- `Ohana/Features/Plants/Views/PlantDashboardView.swift`
- `Ohana/Features/Plants/Views/AddPlantView.swift`
- `Ohana/Features/Plants/Views/PlantDetailView.swift`
- `Ohana/Features/Plants/PlantCommands.swift`

这些文件保留。首发只保证没有生产入口到达它们；服务层不硬 gate，以免破坏未来迁移、备份恢复、单元测试和数据修复能力。

### Onboarding And Demo Surfaces

- `Ohana/Features/Onboarding/Views/OnboardingView.swift`
- `Ohana/Features/Members/RequiredHumanProfileView.swift`

首发不展示显式“植物 / Plants”或 leaf badge 文案，改为“提醒 / reminders”这类已上线能力。“家庭=生命组合”的产品愿景仍在宪法保留，但首发体验不预告不可用的植物功能。

- `Ohana/Features/GrowthUnlock/Views/GrowthUnlockFlowTestView.swift`
- `Ohana/Features/Settings/DesignLab/VerticalGlassHomeLabView.swift`

若这些开发/设置演示在正式包中可达，gate closed 时也不得展示可点击植物入口。

### Data Safety And Future Sync Surfaces

- `Ohana/Domain/Services/RecycleBinService.swift` 与 `Ohana/Features/Settings/Views/RecycleBinView.swift`：保留已有植物数据的恢复/清理能力，属于 D16 数据安全面，不作为植物功能入口。
- `Ohana/Domain/Services/DataBackupManager*.swift` 与 `DataBackupDTOs.swift`：备份/恢复继续包含植物数据，避免未来解锁或用户旧数据丢失。
- `Ohana/Domain/Services/CloudSyncEntityRegistry.swift` 与 serializer：Plant/PlantCareLog registry 保留；首发不启用 CloudKit。
- `Ohana/Domain/Services/CareLedger*.swift` 与 `Ohana/Features/CareLedger/*.swift`：历史 plantCare 数据可保留，但 gate closed 时不应作为首发可见植物体验的来源。
- `Ohana/Features/Notifications/NotificationDeliveryPolicy.swift` 与日历事件分类保留未来分类能力；首发无植物创建/植物提醒入口。

## Future Unlock

未来打开植物模块时，最小路径是：

1. 修改 `PlantFeatureGate` 内部判定，不改各入口散落条件。
2. 确认 O8 的产品形态：免费更新、付费解锁、或与联机/家庭套餐组合。
3. 若需要等级节奏，继续让 `GrowthUnlockPolicy` 决定可见等级；若不需要等级节奏，gate 打开后直接显示植物入口。
4. 解锁前重跑入口、quest、mood、备份恢复、回收站和通知回归，确认历史植物数据不会造成重复任务或重复派生。

No call site may decide plant availability from `GrowthUnlockPolicy.isOutOfScope`, `EntityType.isAvailable` hard-coded booleans, build flags, demo mode, existing plant count, backup contents, CloudKit state, or entitlement strings directly.
