# PlantFeatureGate Logic

## Purpose

`PlantFeatureGate` 是 D19 / GAP-12 的产品/构建支持判定点；`PlantUnlockPolicy` 是用户可见性判定点。首发版本定位为“家中所有生命”，但基础植物照护不在 Lv.1 立即暴露，而在 Lv.4「家庭树冠」作为成长解锁出现。

植物门与 `OnlineFeatureGate` 互不耦合：联机关闭不代表植物关闭，植物关闭也不代表联机关闭。基础植物照护永久免费、无限数量、本地可用，只受椰子树成长节奏控制，不作为付费墙；未来 Care+ 可在不改变基础免费边界的前提下增加 AI 识别、病虫害智能诊断、天气联动和季节计划。

## Growth Unlock Semantics

- `PlantFeatureGate.allows(.plants)` 在当前 build 恒为开启，表示 app 支持植物数据、服务、备份、恢复和本地提醒。
- 用户是否看到基础植物模块由 `PlantUnlockPolicy` 决定：椰子树 Lv.4「家庭树冠」解锁；若本机已经存在植物数据，则 grandfather，低于 Lv.4 也可继续进入植物列表和详情。
- Lv.1–3 不显示植物 tab、不显示添加植物入口、不生成植物 quest、不展示植物负反馈信号；植物 route / FunctionMenu 入口必须 redirect 到 Growth Roadmap。
- Lv.4 后开放添加植物、植物 Dashboard、详情、护理计划、日志、照片、资料库、本地提醒和 Today Focus 植物任务。
- Lv.5 不是基础植物管理前置，只用于植物与绿洲/岛屿氛围、装饰或收益反馈的后续联动。
- Lv.8+ / Care+ 才承载植物 AI 识别、病虫害智能诊断、天气/季节计划和高级趋势洞察。
- `Plant`、`PlantCareLog`、Plants 模块源码、备份/恢复、物理删除边界、CloudSync mutation metadata 保留；首发不启用 CloudKit。
- gate 不依赖 `OnlineFeatureGate`、CloudKit、iCloud、家庭人数、build configuration 或订阅 product id。Grandfather 状态只由 `PlantUnlockPolicy` 管理，调用点不得自己读植物数量决定可见性。
- 无 AI/天气供应商配置时，识别和诊断入口必须诚实降级：手动搜索添加、空候选、不确定性提示，不得伪造识别结果或置信度。

## Collected Surfaces

### Single Decision Point

- `Ohana/Domain/Services/PlantFeatureGate.swift`：产品支持判定点和 `PlantUnlockPolicy` 的唯一持久化 grandfather 标记。
- `Ohana/App/AppFeatureRouteGuard.swift`：路由、FunctionMenu、Home tab、AddEntity 和 read-model 加载统一委托到 `PlantFeatureGate` + `PlantUnlockPolicy`。
- `Ohana/Features/GrowthUnlock/GrowthUnlockPolicy.swift`：`.plants`、`.plantsDashboard`、`.plantDetail` 属于 `.household`，即 Lv.4。
- `Ohana/Features/Members/Views/AddEntityRoute.swift`：`EntityType.plant.isAvailable` 委托到 `PlantUnlockPolicy`，不再硬编码 false 或直接读产品 gate。

### Home And App Routes

- `Ohana/App/ContentView.swift`：`onOpenPlant` 打开 typed plant profile route。
- `Ohana/App/AppRouteCoordinator.swift`：`openPlant` 和 `.plantProfile` Lv.4 后 push 进入植物详情；Lv.4 前 redirect 到 Growth Roadmap，已有植物数据 grandfather。
- `Ohana/App/RouteContainers/AppRouteDestinationContainers.swift`：`.plantProfile` destination 挂载 `AppPlantRouteContainer`。
- `Ohana/Features/Home/HomeRouteCoordinator.swift`：`openAddEntity(.plant)` Lv.4 后打开添加植物页；Lv.4 前 redirect 到 Growth Roadmap。
- `Ohana/Features/Home/VerticalSolidHomeModels.swift`：`.plants` tab 仅在 Lv.4 或已有植物数据时进入可见 tab 集。
- `Ohana/Features/Home/HomeReadModelStore.swift` 和 snapshot builder：产品 gate 开启时可加载植物 read model 以发现已有数据；渲染 snapshot 只使用 `PlantUnlockPolicy` 可见植物。

### Function Menu

- `Ohana/Features/FunctionMenu/FunctionMenuModels.swift`：`.plants`、`.plantsDashboard`、`.plantDetail` 保留为未来 route 值。
- `Ohana/Features/FunctionMenu/Views/FunctionMenuRootView.swift`：候选功能组可包含 `.plants`，visible filter 必须经 `AppFeatureRouteGuard`。
- `Ohana/Features/FunctionMenu/Views/FunctionMenuSheet.swift`：direct landing 初始目的地必须先经 `visibleFunctionDestination`。
- `Ohana/Features/FunctionMenu/Views/FunctionMenuDestinationRouter.swift`：Plants destination 挂载植物 Dashboard / Detail。

### Today Focus, Quest, And Mood

- `Ohana/Features/TodayFocus/IslandQuestEngine.swift`：Lv.4 或已有植物数据时才产生 `q_water_plant*` / `q_fertilize_plant*`。
- `Ohana/Features/Home/Views/FocusHomeAuxiliaryViews.swift`：Today Focus snapshot 只在 `PlantUnlockPolicy` 允许时保留植物快照、植物 quest 和植物 negative signal。
- `Ohana/Shared/Components/IslandNegativeFeedback.swift`：可读取植物缺水/黄叶等负反馈信号。
- `Ohana/Features/Economy/TodayFocusEconomyService.swift`：可 fetch plants，植物 quest 参与可见完成/奖励判断。

### Plants Module Body

- `Ohana/Features/Plants/PlantRouteContainer.swift`
- `Ohana/Features/Plants/Views/PlantDashboardView.swift`
- `Ohana/Features/Plants/Views/AddPlantView.swift`
- `Ohana/Features/Plants/Views/PlantDetailView.swift`
- `Ohana/Features/Plants/PlantCommands.swift`

这些文件是生产入口。服务层继续不硬 gate，以便备份恢复、单元测试、数据修复、grandfather 和未来同步元数据复用。

### Onboarding And Demo Surfaces

- `Ohana/Features/Onboarding/Views/OnboardingView.swift`
- `Ohana/Features/Members/RequiredHumanProfileView.swift`

首发 onboarding 可以采集植物偏好：城市/地区、通知意向、宠物/儿童安全偏好、植物经验和主要护理场景。未授权定位或通知时仍可继续使用；但采集偏好不代表 Lv.1 立即显示植物入口。

- `Ohana/Features/GrowthUnlock/Views/GrowthUnlockFlowTestView.swift`
- `Ohana/Features/Settings/DesignLab/VerticalGlassHomeLabView.swift`

若这些开发/设置演示在正式包中可达，必须与首发植物可达状态保持一致。

### Data Safety And Future Sync Surfaces

- `Ohana/Domain/Services/PhysicalDeletionService.swift`：植物删除必须写不可见 sync tombstone 后物理删除；没有用户可见恢复/清理入口。
- `Ohana/Domain/Services/DataBackupManager*.swift` 与 `DataBackupDTOs.swift`：备份/恢复继续包含植物数据，避免未来解锁或用户旧数据丢失。
- `Ohana/Domain/Services/CloudSyncEntityRegistry.swift` 与 serializer：Plant/PlantCareLog registry 保留；首发不启用 CloudKit。
- `Ohana/Domain/Services/CareLedger*.swift` 与 `Ohana/Features/CareLedger/*.swift`：plantCare 数据可作为 Lv.4 可见植物照护事实来源。
- `Ohana/Features/Notifications/NotificationDeliveryPolicy.swift` 与日历事件分类包含 `.plantCare`；Lv.4 后允许基础植物提醒与单株提醒关闭。

## Future Unlock

未来扩展植物模块时，最小路径是：

1. 保持 `PlantFeatureGate` 作为单一判定点，不在入口散落条件。
2. 保持 `PlantUnlockPolicy` 作为唯一用户可见性判定点；Lv.4 前入口 redirect 到 Growth Roadmap，已有植物数据 grandfather。
3. 基础植物继续免费；AI 识别、智能诊断、天气联动和高级计划走 Care+ 或后续供应商能力。
4. 扩展前重跑入口、quest、mood、备份恢复、物理删除和通知回归，确认历史植物数据不会造成重复任务或重复派生。

No call site may decide plant availability from `GrowthUnlockPolicy.isOutOfScope`, `EntityType.isAvailable` hard-coded booleans, build flags, demo mode, existing plant count, backup contents, CloudKit state, or entitlement strings directly. Use `PlantFeatureGate` for product/build support and `PlantUnlockPolicy` for user-visible access.
