# Ohana iOS App 项目文档

> **Planning / Reference only**：本文档顶部快照可帮助理解历史决策，但不是当前规则源；下方长章节包含旧计划和旧事实。任何冲突都以 `AGENTS.md`、`ui规范.selection.json`、`docs/governance/manifests/`、当前治理文档和源码为准。

> 最后更新: 2026-06-07（成熟度工程强化：MetricKit 可观测性 / 后台 @ModelActor / 通知调度依赖注入接缝 / 持久化模型拆分 / 历史 fetch 安全上限）| Build: ✅ `scripts/build-debug-fast.sh`（默认 iPhone 17 / Xcode installed default iOS 26.5 simulator runtime；在 iCloud 同步目录构建时用 `DERIVED_DATA_PATH=/tmp/OhanaDD` 绕过 CodeSign detritus 失败）| Schema: ArkSchemaV56
>
> **当前事实优先级**：本文件顶部“当前快照”代表 2026-05-25 的实现状态；下方早期长章节保留为历史实现记录，若与当前快照、`AGENTS.md`、`ui规范.selection.json` 或 `docs/app-architecture-governance.md` 冲突，以后四者为准。
>
> **当前默认首页**：竖版实色首页（`FocusHomeV3View(sceneStyle: .verticalSolid)` / `FocusHomeVerticalSolidView`）。Wallet V3 / Wallet V2 仍可在设置里选择作为对照；旧 `FocusStackHomeTestView` 仅保留为兼容/回归代码，不再作为默认路径。首页是唯一高频工作台，只回答“今天谁需要照顾 / 现在最该做什么 / 点一下怎么完成”；卡片展开页把快捷操作嵌入卡片底部，底部导航承载首页 / 日历 / Oasis / 植物与中央添加入口。

---

## 当前快照（2026-05-25）

### 1. 设计系统与 UI 源头

- **唯一机器可读 UI 源头**：根目录 `ui规范.selection.json`。
- **人类可读 companion**：`docs/design/ui规范.md`。若 Markdown 与 JSON 冲突，JSON token 胜出。
- **毛绒 Icon 样张源头**：`docs/plush-icon-sample-care-prompts.md` 记录 Feed / Water / Walk 三个照护快捷入口的 3D 毛绒 icon 生成规范、统一负面 prompt、命名与导入建议；`docs/plush-icon-samples/` 保存对应 SVG 构图预览稿。
- **开发者 UI 控制台**：设置 > 开发者工具 > UI/UX 规范查看，只是编辑、预览、导出界面；只有导出的 V4 JSON 写回 `ui规范.selection.json` 后才成为正式规范。
- **全局主色**：`goPrimary` 自适应，深色 = `goLime`，浅色 = `goBlue`。成员主题色、宠物主题色、领域专有色不得复用 `goLime/goBlue` 或 primary alias。
- **卡片规则**：只有可点击、可编辑、可展开、可导航的 grouped surface 才使用 flat card；纯信息摘要使用 unframed metrics / inline summary。
- **短弹窗规范**：短记录、确认、补粮、轻管理弹窗必须是当前页面内 `inlineOverlay`，底部靠近安全区、6pt 水平边距、52pt 连续圆角、单层 `nativeRegular` glass、`liftedAlert` 阴影、内容自适应高度、顶部 handle 才能下滑关闭。
- **普通 sheet/page 规范**：总览、历史、长列表、复杂编辑可使用普通页面或系统 sheet，但页面 chrome、关闭按钮、背景、chart、按钮仍遵守 V4。
- **数字输入**：高频数字输入优先使用页面内迷你数字键盘、Stepper 或快捷 chip，避免弹系统键盘。
- **动效**：全局使用克制高级动效：短按 spring、selection soft glide、数字 `contentTransition(.numericText())`、FAB/menu stagger、popup bottomSpringScaleFade、奖励/成功反馈短粒子。常驻循环必须接入 `AppWorkloadPolicy`。

### 2. 架构、能耗与合规边界

- **工程治理源头**：`docs/app-architecture-governance.md`。
- **运行时策略唯一入口**：`Ohana/Utilities/AppRuntimePolicy.swift` 中的 `AppWorkloadPolicy`。不要在单个 View 里新建平行低功耗、Reduce Motion、scene phase 或后台策略。
- **定位合规**：只有 running 遛狗可以持续定位和后台定位；paused、finished、无遛狗进程、普通浏览、首页、记录、喂食、协作、商店都必须停止持续定位。
- **后台/锁屏**：running 遛狗继续记录路线，但 UI timer、地图重绘、装饰动画停止或降频；时长用 elapsed-time 计算，不依赖后台每秒 timer。
- **重复动画/Timer**：新增 `Timer.publish`、`TimelineView(.animation)`、`repeatForever`、Canvas/粒子循环、Map live update 必须通过 `scripts/audit-runtime-guardrails.sh`。
- **构建快速入口**：`scripts/build-debug-fast.sh` 默认使用 `platform=iOS Simulator,name=iPhone 17`，不写 `OS=`；让 Xcode 选择本机已安装的默认 iOS 26.5 simulator runtime，避免为旧 runtime 触发下载/解析。

### 2A. 合规、安全、性能与功耗 Audit 待实施计划（2026-05-25）

> 本节是未来实施计划，不表示下列风险已经修复。实施时仍以 `docs/app-architecture-governance.md`、`AGENTS.md`、`ui规范.selection.json` 和实际代码为准。

- **本轮验证状态**：已基于当前工作树完成静态审计，并运行 `scripts/audit-runtime-guardrails.sh`、`scripts/audit-ui-v4.sh --changed`、`scripts/build-debug-fast.sh`；最终 Debug build 在默认 iPhone 17 / iOS 26.5 simulator runtime 通过。首次增量构建曾在 `QuickFeedDetailSheet.swift` 出现瞬时 type-check / 作用域异常，复跑通过，但仍作为大 SwiftUI 文件性能债务跟踪。
- **P0 隐私清单**：✅ 已完成（见 2C）。新增 `Ohana/PrivacyInfo.xcprivacy`，声明 `UserDefaults` required-reason API（`CA92.1`）；已复核未使用文件时间戳 / 磁盘卷容量 / 系统启动时间类受限 API。
- **P0 权限声明一致性**：✅ 已完成（见 2C）。移除纯 mock 的 HealthKit 权限键与重复的 Camera/Photo/Location `INFOPLIST_KEY_*`，以 `Info.plist` + 三语 `InfoPlist.strings` 为唯一来源。
- **P1 备份安全**：✅ 已完成文件保护 / atomic write / 临时文件清理（见 2C）。仍待办：用户密码加密、导出敏感提示。
- **P1 备份性能**：✅ 导出全表 fetch + encode 已迁到后台 `@ModelActor DataBackupActor`（见 2C）。
- **P1 导入去重**：备份恢复 UI 写“自动去重”，但部分日志类当前直接插入，可能污染统计、提醒和账本。后续按 UUID 对全模型 upsert/skip，并给导入前加 schema、大小和来源预检。
- **P1 后台任务与定位透明度**：`BGAppRefreshTask` 需要 expiration/cancel/failure 路径，避免后台任务超时仍占资源。后台定位总体集中在 `LocationManager` / `PetWalkingManager` 是正确方向，但 running walk 进入后台时应加强用户透明度，优先显示系统后台定位指示，并做真机锁屏路线验证。
- **P2 包体与资源策略**：Debug app 包体约 432 MB，`Resources/Avatars/PetAvatarAssets` 约 197 MB 作为 folder resource 整包复制，并在 App Bundle 中保持 `PetAvatarAssets` 目录名。发布前压缩/重采样头像，评估 asset catalog、按需资源或下载型资源，并做 Release archive size audit。
- **P2 SwiftUI 热点拆分**：进行中。`MemberCardCreationView.swift` 已 4002 → 1734 行（见 2C）。剩余最大文件为 `AddPetWizardView.swift`（3122）、`PetHealthDetailView.swift`（2949）等，可同法继续拆分 presenter / data loader / 子视图。
- **P3 发布完整性**：设置里的隐私政策、联系开发者等入口需要真实 action；通知 action/title 需要三语本地化；App Group entitlement 若没有真实共享容器使用，应移除或补齐用途说明。
- **实施顺序**：先修 `PrivacyInfo.xcprivacy` 和权限声明一致性；再修备份安全与导入去重；随后修后台任务和定位透明度；最后处理包体优化与大 SwiftUI 文件拆分。

### 2B. 生产可观测性与依赖注入接缝（2026-06-07）

- **MetricKit 可观测性**：`Ohana/Utilities/MetricKitObserver.swift` 是生产遥测的统一入口，`OhanaApp.init` 在 MainActor 任务里 `MetricKitObserver.shared.start()` 注册为 `MXMetricManagerSubscriber`。
  - 聚合每日 `MXMetricPayload`：首帧/恢复耗时、应用 Hang 平均时长、内存峰值、后台异常退出计数（直方图按桶中点加权平均换算成毫秒，见 `averageDurationMS(_:)`）。
  - 聚合 `MXDiagnosticPayload`：崩溃（termination reason / signal / exception）、Hang 时长、CPU 异常、磁盘写异常。
  - 崩溃诊断由系统在**下次启动**才送达，因此诊断摘要持久化到 `MetricDiagnosticsStore`（`UserDefaults` 键 `ohana_metrickit_pending_diagnostics`，JSON 环形缓冲，上限 20 条，`NSLock` 保护），启动时 `drainUnreported()` 回放进 `AppPerformanceMonitor`，直接显示在设置「性能诊断面板」（`PerformanceDiagnosticsView`）。
  - 全部对 `AppPerformanceMonitor`（MainActor）的写入都通过 `Task { @MainActor in ... }` 派发；MetricKit 回调在后台队列触发。`#if canImport(MetricKit)` 下编译实现，否则提供 no-op stub。
- **后台 `@ModelActor` SwiftData 读写**：`CareLedgerBackfillActor`（定义在 `Ohana/Models/CareLedgerBackfillService.swift`）是 `@ModelActor`，拥有专属后台 `modelContext`，其 `run()` 调用 `CareLedgerBackfillService.backfill(context:)`。
  - 用途：一次性、全表无界的 CareLedger 回填（fetch 全部 `PetCareLog/PetPottyLog/PetWalkLog/PetExpenseLog/HumanWeightLog/HumanWorkoutLog/PlantCareLog/Reminder`）从主线程移到后台 context，幂等、只写持久数据、无 UI 活动模型依赖。
  - `StartupMaintenanceCoordinator.runCareLedgerBackfillIfNeeded` 改为 `async`，用 `CareLedgerBackfillActor(modelContainer: context.container)` + `await actor.run()`，启动维护步骤 `care_ledger_backfill` 已 `await`。
  - `CareLedgerService.record` 与 `CareLedgerBackfillService.backfill` 去掉非必要的 `@MainActor`（函数体仅做 `ModelContext` 写入，隔离无关），所有现有 MainActor 调用方与 `OhanaTests` 直接调用均兼容。
  - **重要约束**：首页高频读模型（`HomeReadModelStore` / `HomeReadModelFetches`）**仍在 MainActor 主上下文**读取，因为 `VerticalSolidHomeView` 与 `TodayFocusSnapshot` 直接消费活动 `Pet/Human/Plant/FamilyCollaborationTask` 模型对象（非纯值类型）；把它整体迁到后台 `@ModelActor` 需要先把整条 home 渲染管线重写为纯值类型，属高风险大改，暂不做。后台 `@ModelActor` 能力优先用于一次性维护 / 导出 / 统计等值类型/隔离路径。
- **通知调度依赖注入接缝**：`Ohana/Utilities/ReminderNotificationScheduling.swift`。
  - `ReminderNotificationScheduling`（`Sendable` 协议）声明域服务依赖的通知操作子集；`NotificationManager` 直接 conform。
  - `OhanaNotifications.current`（`nonisolated(unsafe) static var`）是可注入提供者，默认 = `NotificationManager.shared`（live），`useLive()` 用于测试 teardown 恢复；**生产行为不变**。
  - 域/模型层（`CareEventService`、`ReminderCompletionService`、`ReminderSchedulingService`、`FamilyTaskService`、`FeedManagementSupport`、`Pet`、`RainbowBridgeService`）的 `schedule` / `cancel` / `pendingNotificationIds` 调用统一改走 `OhanaNotifications.current`，单测可替换为内存假实现以测试 reminder/care 写路径。视图层的 `requestPermission()`（不在协议内）保持直接调用 `NotificationManager.shared`。

### 2C. 合规、备份安全与大文件拆分（2026-06-08）

- **隐私清单**：`Ohana/PrivacyInfo.xcprivacy`（随 `PBXFileSystemSynchronizedRootGroup` 自动打包，构建时 `CpResource` 进 `.app`）。声明唯一实际使用的 required-reason API：`NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`。`NSPrivacyTracking=false`，`NSPrivacyTrackingDomains` 与 `NSPrivacyCollectedDataTypes` 为空（数据全本地，不联网收集/不做跟踪）。
  - 复核结论：代码仅用 `URLResourceValues.fileSizeKey` / `.contentTypeKey` / `FileManager.attributesOfItem[.size]`，均**不属于**文件时间戳（C617.x）、磁盘卷容量（E174.x）或系统启动时间（35F9.x）受限类别，故不需额外声明。
- **权限声明唯一来源**：权限文案以 `Ohana/Info.plist` + `en.lproj` / `de.lproj` 的 `InfoPlist.strings` 三语为准。已从 `project.pbxproj`（Debug+Release 两处）移除：
  - `INFOPLIST_KEY_NSHealthShareUsageDescription` / `INFOPLIST_KEY_NSHealthUpdateUsageDescription`——HealthKit 全是 mock（`HumanHealthKitManager`，无 `import HealthKit`、无 entitlement），声明属未使用权限。
  - 重复的 `INFOPLIST_KEY_NSCamera/PhotoLibrary/Location*`——这些键与 `Info.plist` 文件重复且文案不同，`GENERATE_INFOPLIST_FILE` 注入会覆盖本地化 `InfoPlist.strings`，导致英/德用户看到中文文案。移除后三语本地化生效。
  - 实际用到的权限：相机（`UIImagePickerController` 拍摄，`QuickHumanNoteSheet`）、相册（`PhotosUI.PhotosPicker`，out-of-process）、定位（遛狗路线 `LocationManager`/`PetWalkingManager`），均由 `Info.plist` 保留。
- **备份导出安全（`DataBackupManager`）**：
  - `exportJSON(container:)` 用 `try data.write(to:options:[.atomic, .completeFileProtection])`——原子写入 + 锁屏静止加密。导出含健康/用药/保险/证件/照片/定位明文 JSON，必须加密落盘。
  - `purgeStaleExports()` 在每次导出前清理临时目录里 `ohana_backup_*.json` 历史文件，避免敏感明文残留。
- **备份导出后台化**：
  - 新增 `@ModelActor DataBackupActor`（文件末尾）：拥有专属后台 `modelContext`，`exportData() throws -> Data` 调用 `DataBackupManager.shared.buildBackup` + `.encode`，全表 fetch + JSON encode 在后台执行，仅把 Sendable `Data` 跨回主线程。
  - `DataBackupManager` 去类级 `@MainActor`，改为 `final class ... : @unchecked Sendable`（其逻辑只做 `ModelContext` 读写 + 纯值映射，隔离无关）。`buildBackup` 去 `private`、新增 `encode(_:)`，供 actor 调用。
  - **import 仍走主上下文**：`importJSON(from:context:)` 单独标 `@MainActor`，保留主 context 写入，使恢复后 `@Query` 驱动的 UI 立即刷新（不引入跨 context 合并的刷新延迟）。
  - `SettingsView` 导出按钮改传 `modelContext.container`；`ModelContainer` 是 `Sendable`，跨隔离安全。
- **超大视图文件拆分**：`MemberCardCreationView.swift` 4002 → 1734 行（同 target，`PBXFileSystemSynchronizedRootGroup` 自动纳入，无需改 pbxproj，行为不变）：
  - `MemberCardCreationSupport.swift`（997 行）：`MemberCreationKind` / `MemberCreationDraft` / `MemberCreationMediaRecoverySnapshot` / `MemberCardRenderSnapshot` / `MemberCreationStep` / `Avatar2DCandidateProvider` / `MemberCreationService` / `MemberAvatarMediaCoordinator` / `MemberAvatarImageProcessor` 等数据、服务、头像媒体层。
  - `MemberCardCreationComponents.swift`（1303 行）：输入控件、日期/MBTI/城市选择器、`MemberPortraitDraftCardSurface`、`MemberCameraCaptureView`、`MemberPortraitCropView` 等可复用 UI 子视图。
  - 跨文件可见性：原 `private` 的 `MemberCreationMediaRecoverySnapshot` 与 `MemberCreationJoinHandoff*` 改为 internal（仍被主 View 引用）。
- **新增单测**（`OhanaTests`，Swift Testing，in-memory `ModelContainer(for: Schema(ArkSchemaV56.models))`）：
  - `CareLedgerBackfillActorTests`：后台 `CareLedgerBackfillActor` 把 `PetCareLog` 回填为 `CareLedgerEvent` 且重复运行幂等（跨 context：主 context 写入 → actor 后台读写 → 新 context 校验）。
  - `OhanaNotificationsSchedulingTests`：注入 `FakeScheduler` 验证 `ReminderCompletionService.skip` 经 `OhanaNotifications.current` 取消通知；并验证默认 `current` 是 live `NotificationManager`。
  - 修正 `OhanaTests.backupRestoresHumanFieldsAndLogRelationships` 预存在缺陷：原断言把保留品牌主色 `C8FF00`（`OhanaThemeColorPolicy.reservedMemberThemeHexes`，导入 `normalizedMemberThemeHex` 必拒）当作可备份往返，改用非保留色 `FF8800`，使其正确验证 `themeColorHex` 往返。

### 2D. 工程治理基建：CI 门禁、Lint、无障碍与治理文档（2026-06-08）

> 目标：把规则从"散文 + 自觉"升级为机械门禁，并补齐成熟团队常备的治理面。规则越能自动执行，越不依赖执行者记忆。

- **CI 门禁**：`.github/workflows/ci.yml`（push/PR 触发）三 job：
  - `audits`：UI V4 + 无障碍审计按 **PR 改动文件**严格执行（新代码门禁，不淹没 18 万行遗留基线）；runtime guardrails / 本地化覆盖 / 发布数据安全 / git 体积全量。
  - `lint`：SwiftLint（真门禁，非 `--strict`）+ SwiftFormat（先 report-only / `continue-on-error`）。
  - `build-test`：固定 iPhone 17 模拟器 `xcodebuild test`，产出 `.xcresult`。**前提**：runner 的 Xcode 需带 iOS 26 SDK + iPhone 17 模拟器（GitHub 托管镜像可能滞后，必要时自建 runner / `macos-26` 镜像）。
  - 分支保护在仓库设置里配置（要求 `audits`/`lint`/`build-test` 通过）。
- **Lint/Format 配置（棘轮策略）**：
  - `.swiftlint.yml`：宽松基线（禁用过噪规则、放大阈值、排除资源/生成目录）+ 高价值 opt-in 规则 + 三条自定义规则（`no_ark_app_group` error；`no_print_in_app` / `no_language_ternary` warning）。CI 不带 `--strict`，仅 error 级阻断；基线清理后再收紧。
  - `.swiftformat`：4 空格缩进等对齐 `AGENTS.md` 风格；禁用会产生大 diff 的规则；先 report-only，跑一次 `swiftformat .` 建基线后再强制。
- **无障碍治理**：
  - `docs/accessibility-governance.md`：VoiceOver 标签/hint、Dynamic Type（禁 `.system(size:)` 固定值）、44×44pt 点击区、WCAG AA 对比度、颜色非唯一信号、traits、组合朗读、三语 a11y 文案。
  - `scripts/audit-accessibility.sh`：镜像 `audit-ui-v4.sh` 风格的启发式 grep 审计，`// a11y: allow <reason>` 白名单，已接入 CI 与 `AGENTS.md` UI 完成门禁。
- **新增治理文档**（已接入 `AGENTS.md` 治理清单，共 12 份 doc）：
  - `docs/os-support-matrix.md`：标注 `IPHONEOS_DEPLOYMENT_TARGET = 26.2` 安装基数过窄风险；定义 N-1~N-2 支持策略；降级是需可用性守卫审计的独立迁移，不在无关改动里擅自降。
  - `docs/reliability-slo.md`：crash-free ≥ 99.5% / hang ≤ 0.5% / 冷启 ≤ 1500ms p90 等数值目标 + MetricKit/App Store Connect 度量来源 + 违反处理流程。
  - `docs/privacy-compliance.md`：App Store 隐私清单/营养标签/加密出口合规；GDPR 数据导出（复用 `DataBackupManager.exportJSON`）与"删除我的数据"完整路径、数据最小化、无静默收集。
  - `docs/dependency-governance.md`：第三方依赖默认拒绝；新增需理由 + license（MIT/Apache/BSD）+ 供应链 + 版本锁定（提交 `Package.resolved`）；禁分析/广告/外泄 PII 的 SDK。
  - `docs/concurrency-and-error-policy.md`：MainActor vs 后台 `@ModelActor` 边界、`ModelContext` 非 Sendable 不得跨隔离、`@unchecked Sendable` / `nonisolated(unsafe)` 使用约束、错误建模与用户可见失败、`OSLog` 取代 `print` 的隐私安全日志。
- **`AGENTS.md` 接入**：治理文档清单补全；新增「Continuous Integration & Automated Gates」章节；UI 完成门禁追加无障碍审计要求。

### 3. 当前 SwiftData Schema

当前 schema 链到 **ArkSchemaV56**，`SharedModelContainer` 使用 `Schema(ArkSchemaV56.models)`。

近期关键迁移：

| Schema | 当前用途 |
|---|---|
| V39 | 喂食干/湿粮、零食类型、喂食计划结构化字段 |
| V40 | Human PIN：`pinHash/pinSalt/failedAttempts/lockedUntil` |
| V41 | 宠物当前主粮类型，用于打卡和计划默认值 |
| V42 | 余粮 purchase/open date、手动修正余量 |
| V43 | 人类纪念模式生命周期字段 |
| V44 | 人类离世/纪念只读边界扩展 |
| V45 | `FamilyCollaborationTask` 统一家庭任务/事项模型 |
| V46 | `CoconutExchangeRequest` 家庭内部线下兑换记录 |
| V47 | Oasis 升级椰子、电子宠物、碎片、解锁模型 |
| V48 | `OasisCritterActionLog` 电子宠物互动/升星日志 |
| V49 | 电子宠物展示/状态扩展字段 |
| V50 | 遛狗便便地图标记：`PetPottyLog` 坐标 + `walkLogId` |
| V51 | 宠物 3D 破框卡片专用主体图：`cardPopoutImageData/cardPopoutSourceRaw` |
| V52 | `SharedCareSession`：同物种多宠共同照护记录 |
| V53 | `GachaOwnedItem` / `GachaDrawLog`：系列盲盒扭蛋收藏与抽取记录 |
| V54 | 扭蛋非收藏结果与即时奖励记录扩展 |
| V55 | Oasis 电子宠物低压力生命状态扩展 |
| V56 | `HumanHealthMetricLog`：人类体检指标单项数值时间序列 |

备份/恢复已覆盖家庭协作任务、兑换请求、Oasis 电子宠物、喂食结构化字段、余粮字段、破框图等新数据；PIN hash/salt 不应进入备份。

### 4. 首页与快捷操作

- **默认首页**：`FocusHomeV3View(sceneStyle: .verticalSolid)`，由 `FocusHomeVerticalSolidView` 作为默认样式入口。顶部五按钮与底部导航固定，中间区域在首页 / 日历 / Oasis / 植物间横向切换。
- **卡片区**：竖版实色卡片使用真实 `Pet/Human/Plant` 数据、真实头像/2.5D、主题色、椰子数与状态 badge；卡片展开后快捷操作嵌入卡片底部。
- **顶部按钮**：顶部不再保留独立日历按钮。任何界面点击椰子数都打开椰子历史；卡片放大页按当前宠物/人类过滤，其他页面默认显示当前用户（人类）数据。
- **底部导航**：四个 tab：首页、日历、Oasis、植物（待开发）；中央 `+` 集成原首页 FAB 能力，不另放悬浮 FAB。
- **快捷操作**：不再依赖隐藏长按。点击快捷操作时，在按钮下方出现类似 FAB 的两个极简图标按钮：`+ / checkmark` 快速打卡/快记/完成，`chart/list` 详情/管理/历史；无快速动作的入口只显示打开/管理按钮。
- **默认快捷操作**：按物种区分。狗：喂食/喂水/遛狗/陪玩/体重/记录/花费；猫：喂食/喂水/铲屎/陪玩/体重/记录/花费。其它低频操作进入 FAB/全部功能。
- **局部打卡反馈**：打卡成功后当前卡片/快捷 icon 必须播放轻量反馈，数字跳变；椰子正向增加由全局 `CoconutRewardFeedbackCenter` 播放 `+x🥥`。

### 5. Today Focus

- Today Focus 是“今日任务盘”，在竖版首页顶部以一张张任务卡呈现；卡片区域上下滑动切换，不使用 ScrollView，不显示额外上下按钮。
- 任务盘可以最小化为页面边缘胶囊，显示任务数 / 紧急提醒；展开时卡片区下移缩小，最小化后卡片区上移放大，两者不能重叠。
- Today Focus 展示当前最值得处理的任务/警告/协作/兑换确认/Oasis 建设任务。
- 顶部 `x/x` 状态跟随当前卡片类型和滑动位置，不再固定显示全局总数。
- 点击任务卡进入相关任务页或总览页；添加记录应使用弹窗，不直接跳系统 sheet。
- 警告卡用户看过一次后应可关闭，不应每天重复打扰。
- 分配给当前人类的 `FamilyCollaborationTask` 立即进入 Today Focus；照护快捷打卡完成后，相关 reminder/task 同步消失。
- 首个人类建档填写初始体重后会写入体重记录，并抑制当天“记录体重”任务。
- Oasis 建设/生命树升级任务也可进入 Today Focus，以 token/槽位呈现。

### 5A. 全局计划逾期未打卡规则

- **统一入口**：`CarePlanOverdueStatusCalculator` 是宠物、人类、未来植物计划逾期状态的统一计算入口。
- **宠物覆盖**：喂食、喂水、换水、滤芯、铲屎、陪玩、护理、用药、健康、保险、清笼、放飞、保湿、换垫等，只要对应计划 reminder 处于 pending 且已过时，或被标记 failed，就进入逾期状态。自动猫粮机规则不进入日历/逾期警告。
- **水族周期覆盖**：换水、滤芯清洗 / 更换等周期型状态即使没有显式 reminder，也会通过同一逾期状态进入首页卡片状态与快捷操作提示。
- **人类覆盖**：人类计划事件、指派给该人类的任务、人类用药计划未打卡都会进入逾期状态。人类卡片右上角状态按钮和用药快捷操作显示 `逾期 / 逾期x天`。
- **植物预留**：植物浇水、施肥和植物关联事件已接入同一计算器；未来植物正式进入首页 / Today Focus 后直接复用，不再写一套单独规则。
- **打卡后恢复**：相关记录完成后，对应 reminder/task 应同步 completed，首页状态、快捷操作、Today Focus、家庭协作里的逾期提示应随 snapshot signature 刷新消失。

### 6. 喂食、水、便便/铲屎

- **喂食**：三模式互斥：手动、提醒计划、自动猫粮机。顶部模式切换直接决定喂食卡 UI；计划/自动若已有 active plan，点击直接切换，否则进入设置。
- **喂食卡**：显示当前主粮类型（干粮/湿粮）并在两个粮食显示区域直接 highlight；手动模式的设置按钮改为历史/设置管理语义，记录喂食弹窗确认参数时不应误触发打卡。
- **喂食总览**：聚合三种模式的数据；单一模式详情进入对应历史/日历页。Chart 极简，数据语义正确，有加载/切换动画。
- **余粮**：补粮区分购买日期与开袋日期；只有开袋日起的同类型主粮记录扣减。余粮管理支持查看、修改、删除、提醒、手动修正。余粮色默认 `goPrimary`，低余粮只在局部状态用警告色。
- **零食**：Chart 主语义是频率，按每日记录次数统计，未填写克数也计入；支持零食类型 filter，并能看到某类型上次喂食时间。
- **喂水**：参考喂食，保留手动/提醒计划；已有计划时切换不再反复弹新建计划。水量可选，不填则只记录次数。逾期未打卡时首页卡片状态、快捷操作和喂水/换水/滤芯页面必须明显警告，完成后恢复普通态。
- **便便/铲屎/猫砂**：猫显示便便/铲屎/猫砂；非猫物种需要调整为更通用便便管理，不显示猫砂/铲屎误导入口。点击卡片进 overview，按钮做记录/管理。铲屎/换砂计划逾期也走全局逾期规则。

### 7. 健康、人类、体重、花费、记录

- **宠物健康**：三核心卡：预防护理、用药、异常/就诊。用药任务可在 Today Focus 直接打卡，不强制跳转用药页。
- **人类模块**：默认快捷操作为体重、花费、用药、运动、备注、全部功能；本人可见私密数据并提示“仅自己可见”，非本人显示锁定占位。人类用药计划逾期时，人类卡片状态按钮和用药快捷操作必须即时提示。
- **人类 PIN**：设置 > 设备身份 > 切换人类账户 > 人类卡片锁按钮设置/公开/隐私；切换到有 PIN 成员时必须验证。
- **体重/花费统一页**：宠物/人类从全部功能和快捷操作进入同一套页面。快记使用 V4 inline popup + 内嵌数字键盘；详情页有 chart + 历史，避免重复相似页面。
- **记录中心**：短按“记录”打开快速记录弹窗，支持文字、拍照、相册、文件、提醒等；长路径进入记录中心。时光页显示用户主动记录和重要成长事件，不混入大量工具流水账。
- **证件保障**：只保留证件与保险。疫苗完全属于健康模块 / 疫苗本，不在证件保障中展示或新增。新增/编辑证件、保险走 inline popup；添加证件类型不含保险。

### 8. 家庭协作与任务/事项

- **入口**：首页顶部 Ohana 成员按钮默认进入家庭协作；协作页右上“成员”按钮进入成员页。
- **任务统一模型**：`FamilyCollaborationTask` 是协作、普通家庭任务、悬赏、宠物照护待办、Today Focus 展示的统一任务层。
- **服务**：`FamilyTaskService` 负责创建、分配、接手、提交完成、发布人确认、拒绝、取消、删除，并同步 `Reminder` 与椰子账本。
- **宠物地图**：协作默认是宠物地图。点击宠物节点，底部抽屉显示该宠物待办；每条待办有明显分配按钮，可指定除自己外的家庭成员并可选悬赏。
- **悬赏**：可发布任意家庭任务，设置椰子奖励。接受者完成后先进入待确认，发布人确认后才从发布人扣椰子并转给完成人；发布人也可拒绝并重新发布/编辑。
- **Today Focus**：发给当前人的任务立即出现；快捷打卡成功后，同宠物同类型最近 pending/failed reminder/task 同步完成。

### 9. Oasis、商店、椰子经济

- **人类椰子**：可消费钱包，用于商店、悬赏、货币兑换、电子宠物升星/互动等。
- **宠物椰子**：宠物成长资产，用于宠物专属装饰、名字铭牌、相册故事样式、Oasis 小窝装饰、纪念相框；不能换钱、不能付悬赏、不能买 App Icon。
- **Oasis 第一屏**：生命椰子树舞台 + 注入能量按钮 + 升级椰子 + Lv5/Lv10 电子宠物目标。注入能量后树形、进度、椰子/叶片/光效应即时变化。
- **升级椰子**：每次生命树升级生成可敲开的升级椰子；普通等级给资源/碎片/装饰，Lv5 保底 `芽芽 / Sprout Mochi`，Lv10 保底 `极光灵 / Aurora Luma`。
- **电子宠物**：轻养成 + 收藏，图鉴/详情/互动/升星/碎片/日志/备份均已建模。真实照护行为应给生命树能量并给当前展示电子宠物轻量 bond/xp/mood 反馈。
- **商店**：分类包含 App Icon、2.5D 头像、货币兑换、外观特效、称号、加成道具。购买装饰必须提供实际应用预览；无法直接预览的商品用动画预览。
- **外观特效**：彩虹轨迹、彩虹便便购买后有开关；实时遛狗、总结地图、历史快照都要一致展示。星辰落雨等效果购买后也应在实际页面可见。
- **3D 破框卡片**：购买后选择宠物，可用相册抠图或 2.5D 头像作为破框主体；主要在卡片放大页实现主体跳出卡片边界的 3D 效果，普通头像不被覆盖。
- **椰子入口**：点击椰子数默认进入椰子历史记录；历史页右上 pie chart 进入 Ohana 财富页。财富页只做分析，不重复展示流水历史。

### 10. 创建流程

- **首次安装本人档案**：语言/国家后直接进入 `AddHumanWizardView`，不再有“添加家人”二次选择页。首次流程保持深色模式和全局背景。
- **添加人类**：5 步轻 RPG 角色创建：身份卡、形象、权限、身体档案、加入 Ohana。第 1 步合并姓名/性别/生日/血型/MBTI；性别无“不透露”；性别选择使用一排 2.5D 头像按钮。
- **添加宠物**：5 步：认识伙伴、外貌、形象、性格、加入 Ohana。首个宠物默认免费 2.5D；后续成员提示商店解锁。
- **顶部预览卡**：人类/宠物创建时始终显示实时角色卡，字段变化用克制动画，不硬切。
- **主题色**：成员主题色使用专属 palette，不包含 goLime/goBlue；最后一步色盘应极简、高级、顺滑。

### 11. 离世/纪念模式

- 宠物/人类标记离世后进入黑白纪念只读模式；日常照护、未来提醒、Today Focus 任务、日历未来事项不应继续出现。
- 当前产品决策：离世不可撤回。
- 离世宠物仍可保留在首页卡片堆，是否显示由“首页显示”按钮决定；成员页历史宠物卡片也应黑白化。
- 允许查看历史、档案、照片、记录中心、证件/保障、纪念相关内容。

### 12. 常用验证命令

```bash
scripts/build-debug-fast.sh
scripts/audit-ui-v4.sh --changed
scripts/audit-runtime-guardrails.sh --changed
```

触碰定位、后台、Timer、常驻动画、Map live update 时必须跑：

```bash
scripts/audit-runtime-guardrails.sh
```

触碰新页面/大 UI 重构时至少跑路径级：

```bash
scripts/audit-ui-v4.sh <changed paths>
```

---

## 一、项目概览

**Ohana（欧哈纳）** — 家庭宠物 + 植物综合管理 iOS App

- **理念**："Ohana means family. Nobody gets left behind or forgotten."
- **技术栈**：SwiftUI + SwiftData + Swift Charts, iOS 26+, Swift 6
- **本地优先**：无账号，SwiftData（App Group `group.com.guanchen.li.Ohana`）
- **全局主色**：`Color.goPrimary` — 深色模式解析为 `goLime`，浅色模式解析为 `goBlue`，仅用于全局品牌/系统主操作
- **UI 规范**：`ui规范.selection.json` 是唯一机器可读源头；`docs/design/ui规范.md` 是人类可读 companion；所有新页面必须符合 V4 规范

### 本地化（简体中文 / English / Deutsch）

- **策略**：用户可见动态文案、插值文案、按钮、弹窗、formatter 标签优先通过 `L10n(appLanguage).tr(zh:en:de:)`、`L10n.current` 或 `AppLocalizedText(zh:en:de:)`。
- **语言入口**：`AppLanguage.supported` 是设置页、SwiftUI `Locale`、`DateFormatter` / `NumberFormatter` 的唯一语言清单；新增语言时追加 `Option` 并创建对应 `<lang>.lproj/Localizable.strings`。
- **当前语言**：设置页支持中文 / English / Deutsch；新增 Go Focus 功能的可见文案必须同时提供中文、英文、德文，德文未完成时用清晰英文 fallback，不能泄露中文。
- **禁止模式**：不要新增 `appLanguage == "zh" ? ... : ...` 或 `AppLanguage.isEnglish ? ... : ...` 这类视图内语言三元判断。
- **隐私文案**：`Ohana/en.lproj/InfoPlist.strings` 覆盖相机/定位说明；`Info.plist` 内保留中文作开发默认值。
- **工程**：`CFBundleLocalizations` = `en` + `zh-Hans`；Xcode `knownRegions` 含 `zh-Hans`。
- **批量生成**：`scripts/generate_en_localizable.py --target en --lproj en`（依赖 `deep-translator`，建议使用仓库内 `.venv-l10n`）扫描含汉字的字符串字面量并机翻；新增语言可改 `--target ja --lproj ja` 等参数；进度缓存在 `scripts/.l10n_<target>_cache.json`（已 `.gitignore`），中断后可续跑。
- **注意**：带 `\(variable)` 的**插值字符串**、部分 `String(format:)` 与通知正文等可能不会出现在字面量扫描结果中，需后续改为 `String(localized:)` / `LocalizedStringResource` 等并补条目；机翻建议按模块在 Xcode 或 diff 中人工润色。

---

## 二、项目结构

```
Ohana/
├── en.lproj/
│   ├── Localizable.strings   # 英文 UI（key = 源码中的中文）
│   └── InfoPlist.strings     # 英文隐私描述
├── Models/
│   ├── Pet.swift / PetWeightLog.swift / PetCareLog.swift # 宠物资料、体重、照护记录；含喂食结构化字段
│   ├── PetMedication.swift / PetInsurance.swift / InsuranceClaim.swift
│   ├── PetPhotoLog.swift / SymptomLog.swift / HeatCycleLog.swift
│   ├── Human.swift / HumanWeightLog.swift / Plant.swift / PlantCareLog.swift
│   ├── Event.swift / Reminder.swift / PetExpenseLog.swift
│   ├── SharedModelContainer.swift   # Schema 迁移链，当前 ArkSchemaV51
│   ├── CareLedgerEvent.swift        # 统一照护事件账本
│   ├── CareLedgerService.swift / CareLedgerBackfillService.swift
│   ├── ReminderSchedulingService.swift # 提醒调度、去重、补偿
│   ├── PrivacyService.swift         # 人类隐私权限统一入口
│   ├── QuestManager.swift           # 椰子奖励系统
│   ├── FamilyTaskService.swift      # 家庭协作任务/悬赏/Today Focus 同步
│   └── OasisUpgradeRewards.swift    # 生命树升级椰子、电子宠物、碎片、互动
├── Views/
│   ├── OverviewView.swift           # 首页主视图（经典 UI）
│   ├── CalendarView.swift
│   ├── OnboardingView.swift         # 首次启动引导：App Store 截图式功能介绍 + 建档流程
│   ├── OhanaDesignSystem.swift      # CoconutBalanceCapsule + OhanaFont + goTranslucentCard 等
│   ├── ArkBackgroundView.swift      # AppBackgroundStyle / OhanaAppBackground 全局背景
│   ├── Home/
│   │   ├── FocusStackHomeTestView.swift # GO Focus V4 默认首页：卡片堆 + Today Focus + 快捷操作 + FAB
│   │   ├── FocusMoodQuestStrip.swift    # 旧 GO UI 心情 + 任务白卡组件，部分路径仍可复用
│   │   ├── EmptyStateWelcomeCard.swift  # GO UI 空态欢迎卡
│   │   ├── FunctionMenuSheet.swift      # GO UI 功能分类 sheet + FMDest / FeatureGroup / PetFeature
│   │   ├── FeatureGroupDashboardView.swift # FAB 分类二级页：分段详情 + 左右滑动子功能
│   │   ├── PetWalletStack.swift     # 经典首页钱包卡堆（遗留/复用视觉组件）
│   │   ├── HomeHighlightDeck.swift  # 宠物卡下方横滑甲板（130pt）
│   │   ├── CritterDeckCarousel.swift
│   │   └── DailyStreakDetailView.swift
│   ├── Details/
│   │   ├── PetRetentionHubView.swift     # 长期留存：成长档案总览
│   │   ├── FamilyWeeklyReportDashboardView.swift # 全家庭多宠周报
│   │   ├── CareLedgerAnalysisView.swift  # 统一照护账本分析页
│   │   ├── ReminderObservabilityView.swift # 提醒健康可观测面板
│   │   ├── IslandWeightDashboard.swift   # 全岛体重（按 UUID seriesID 分线）
│   │   ├── IslandExpenseDashboard.swift
│   │   ├── IslandExplorationDashboard.swift
│   │   ├── PetHealthDetailView.swift
│   │   ├── PetInsuranceView.swift        # 保单列表 + AddPetInsuranceSheet
│   │   └── iOS26UITestView.swift         # iOS 26 UI 规范测试页
│   ├── Components/
│   │   ├── FamilyActivityStripView.swift # 今日谁做了什么
│   │   ├── DutyNudgeComponents.swift     # 指派成员 chip + 催办按钮
│   │   ├── QuickFeedDetailSheet.swift    # Go Focus 喂食管理：三模式、余粮、零食、overview/history
│   │   ├── QuickWaterDetailSheet.swift   # 喂水/换水
│   │   ├── QuickLitterDetailSheet.swift  # 铲屎/换砂
│   │   ├── QuickPottyDetailSheet.swift   # 便便记录
│   │   ├── QuickPlayDetailSheet.swift    # 逗玩
│   │   ├── QuickMomentSheet.swift        # 记录时刻（相册+定位）
│   │   ├── AddExpenseSheet.swift         # 花费记账
│   │   ├── GenericWeightEntrySheet.swift # 统一体重输入
│   │   └── OverviewQuickActions.swift    # 首页快捷操作网格
│   └── Forms/
│       ├── AddEntityRoute.swift
│       ├── AddPetWizardView.swift
│       └── AddHumanWizardView.swift
├── ViewModels/
│   └── IslandUnifiedStatsViewModel.swift  # 全岛体重/探索数据聚合
└── Utilities/
    ├── ColorExtensions.swift
    └── CarePlanCalendarSync.swift
```

---

## 三、数据模型（SwiftData）

### Schema 版本历史
> 说明：完整当前版本为 ArkSchemaV51；V39 之后的关键迁移见下表。早期 V1-V38 保留历史记录。

| Schema | 新增内容 |
|--------|---------|
| V23 | `PetWeightLog.weightUnit` / `Pet.weeklyWalkGoalKm` |
| V24 | `PetMedication` / `Pet.vetClinicName/vetDoctorName/vetAddress` / `PetWeightLog.bcsScore` |
| V25 | `PetInsurance` / `PetPhotoLog` |
| V26 | `Pet.personalityTagsRaw` |
| V27 | `PlantCareLog` |
| V28 | `PetPhotoLog.locationLatitude/Longitude/Placename` |
| V29 | `SymptomLog` / `HeatCycleLog` |
| V30 | `InsuranceClaim` / `PetInsurance.paymentFrequencyRaw` |
| V31 | `PetInsurance.paymentDayOfMonth/showInCalendar/otherFeeAmount/otherFeeNote` |
| V32 | `PetInsurance.firstPremiumPaymentDate`（按年/一次性首期缴费日） |
| V33 | `PetWalkLog.behaviorNotes`（可选备注）/ `PetWalkLog.moodRating`（默认 0） |
| V34 | `HumanMedicationLog`（人类吃药打卡记录） |
| V35 | `Human.mbti` |
| V36 | `Pet.foodReminderEnabled` / `Pet.foodReminderAdvanceDays`（粮仓断粮提醒偏好） |
| V37 | `CareLedgerEvent`（统一照护事件账本，additive schema） |
| V38 | `PetWeightLog.executorId` / `PetHealthLog.executorId` / `PetHygieneLog.executorId` / `HumanWeightLog.executorId`（快捷记录执行者绑定） |
| V39 | 喂食结构化：`foodKindRaw` / `treatKindRaw` / `feedRuleKindRaw` / `feedAmountGrams` 等 |
| V40 | 人类本地 PIN：`pinHash` / `pinSalt` / 失败次数 / 冷却时间 |
| V41 | `Pet.currentFoodKindRaw`（当前主粮类型） |
| V42 | 余粮购买日期、开袋日期语义、手动修正余量/时间 |
| V43 | 人类生命周期/纪念模式字段 |
| V44 | 人类离世只读与纪念状态扩展 |
| V45 | `FamilyCollaborationTask`（统一家庭任务/事项/悬赏） |
| V46 | `CoconutExchangeRequest`（家庭内部线下货币兑换确认） |
| V47 | Oasis 升级椰子、电子宠物、碎片、解锁模型 |
| V48 | `OasisCritterActionLog`（电子宠物互动/升星日志） |
| V49 | 电子宠物展示与状态扩展字段 |
| V50 | 遛狗便便地图标记：`PetPottyLog` 坐标与 `walkLogId` |
| V51 | 宠物 3D 破框卡片专用图：`cardPopoutImageData` / `cardPopoutSourceRaw` |
| V52 | `SharedCareSession`：同物种多宠共同照护记录 |
| V53 | `GachaOwnedItem` / `GachaDrawLog`：系列盲盒扭蛋收藏与抽取记录 |
| V54 | 扭蛋非收藏结果与即时奖励记录扩展 |
| V55 | Oasis 电子宠物低压力生命状态扩展 |

### 关键模型字段
**Pet**：`species`、`themeColorHex`、`personalityTagsRaw`、`currentStreak`、`foodTrackingMode`
**PetInsurance**：`annualPremium`、`paymentFrequency`、`paymentDayOfMonth`、`showInCalendar`、`otherFeeAmount`
**PetWeightLog**：`weight`、`weightUnit`（"kg"/"g"）、`weightInKg`（计算属性）、`bcsScore`
**HumanWeightLog**：`weight`、`executorId`（当前手机使用者 / 执行者）
**PetWalkLog**：`distanceMeters`、`coconutsEarned`、`mapSnapshotData`、`routeLocationsData`、`behaviorNotes`（可选文字备注）、`moodRating`（0=未评 / 1-5星）
**Event**：`relatedEntityType`（`EntityKind.rawValue`）、`relatedEntityId`、`assigneeId`（任务指派）  
**Reminder**：`scheduledAt`、`status`、`completedAt`、`completedBy`、`notificationId`  
**CareLedgerEvent**：`actorKind/actorId`、`subjectKind/subjectId`、`eventKind/actionType`、`source/sourceId`、`occurredAt`、`metadataJSON`，用于统一记录喂食/喂水/吃药/运动/花费/提醒/椰子奖励等行为。

**FeedTodayState**（纯计算 helper，无 SwiftData 迁移）：统一计算宠物今日喂食状态，输入 `Pet`、`allEvents`、每日手动目标餐数，输出今日计划提醒、手动/计划记录、完成进度、下一餐/逾期、今日已喂克数。`QuickFeedDetailSheet`、GO 首页展开态快捷模块、`GoDashboardView` 共用，避免首页与喂食页完成态不一致。

---

## 三·A、统一照护事件账本与提醒产品化

### 统一照护事件账本（ArkSchemaV37+）

当前采用**增量双写**策略：保留既有 `PetCareLog` / `PetWalkLog` / `PetExpenseLog` / `Reminder` / 椰子日志等模型，同时将关键行为写入 `CareLedgerEvent`，为后续统计、同步、撤销、权限与审计提供统一事件层。

关键文件：
- `CareLedgerEvent.swift`：统一账本 SwiftData 模型与 `CareLedgerActorKind` / `CareLedgerSubjectKind` / `CareLedgerEventKind` / `CareLedgerSource`
- `CareLedgerService.swift`：统一记录入口
- `CareLedgerBackfillService.swift`：历史数据幂等回填服务
- `CareEventService.swift` / `CoconutEconomyService` 相关路径：逐步集中写逻辑，减少 View 直接改模型
- `DataBackupManager.swift`：已补充账本、提醒、食粮记录、expense executor 等导出/导入字段

已接入范围：
- 宠物照护：喂食、喂水、换水、便便、遛狗、护理、健康、体重、花费
- 人类照护：体重、运动、吃药、备注/健康相关入口
- 植物照护：浇水、施肥等 `PlantCareLog`
- 提醒生命周期：调度、重复跳过、补注册、失败、过期补偿、完成、snooze、reopen
- 椰子奖励与消费：用于后续账本审计和财富面板

### 提醒系统产品化

`ReminderSchedulingService.swift` 是新的提醒调度门面：
- `scheduleIfNeeded` / `scheduleManyIfNeeded`：调度前处理缺事件 / 过期提醒，随后读取 pending notification IDs，抑制重复通知
- `deduplicate`：按 `eventId + scheduledAt minute` 合并重复 `Reminder`
- `refillMissingPendingNotifications`：App 启动 / BGTask 时补注册未来窗口内缺失通知
- `compensate`：过期未完成提醒自动标记 `failed` / `skipped`，取消通知并写账本
- `cancelAndReschedule`：用于 snooze / reopen 后的统一重排

`NotificationManager.schedule` 已返回 `ReminderNotificationScheduleResult`，成功、失败、跳过、重复等结果都会进入 `CareLedgerEvent`。

**`ReminderObservabilityView.swift`** 是用户可见的提醒健康面板：
- 通知权限状态：`UNUserNotificationCenter.notificationSettings()`
- 系统待发队列：`NotificationManager.pendingNotificationIds()`
- App 内提醒状态：未来待办 / 已过期 / 失败 / 本周完成 / 总提醒
- 调度账本：从 `CareLedgerEvent.eventKind == .reminder` 汇总 `schedule/refill/dedupe/compensate` 类 action
- 风险列表：集中展示过期与失败提醒，便于后续补做重试 / 重新调度入口

---

## 三·B、统一账本分析

**`CareLedgerAnalysisView.swift`** 是 `CareLedgerEvent` 的第一版分析入口，定位为“谁、给谁、做了什么”的可视化审计页。

入口：GO 首页 FAB / `FunctionMenuSheet` → **花费账本** → **照护分析** 分段。

能力：
- 时间范围筛选：本周 / 本月 / 全部
- 事件类型筛选：照护、便便、遛狗、护理、健康、体重、吃药、运动、花费、提醒、植物、椰子、里程碑等
- 汇总卡：事件数、奖励椰子数、事件类型数
- 类型分布：按 `CareLedgerEventKind` 统计
- 成员排行：按 `actorId + actorKind` 聚合
- 最近流水：展示事件类型、actionType、actor → subject、发生时间

当前不提供编辑 / 撤销，只作为只读分析面板；后续 TODO 是账本浏览器、撤销/更正和旧模型差异审计。

---

## 四、首页架构总览

**`ContentView.swift`** 默认固定进入 GO Focus 首页：

| 条件 | 首页 | 状态 |
|---|---|---|
| 普通用户路径 | `FocusStackHomeTestView` | **当前唯一主路径**，详见第二十三·B 节 |
| `debugEnableClassicHome == true && appUIStyle == "classic"` | `OverviewView` | 内部兼容/回归入口；设置页不再暴露经典 UI 切换 |

> Material UI 已于 2026-04-24 删除（`MaterialDashboardView.swift`、`isMaterial` 分支清理为 `false`、Settings 选项卡移除）。`MaterialDesignTestView.swift` 作为设计系统展示页保留。

两者接收相同的 bindings：`selectedPet` / `selectedHuman` / `selectedPlant` / `selectedPetTab` / `heroNS`；`NavigationStack` + `.navigationDestination(item: $selectedPet)` + `.navigationTransition(.zoom(sourceID:in:))` 在 `ContentView` 层统一管理。

---

## 四·A、经典首页（OverviewView）架构

### 顶栏（globalFixedHeader）
- 右侧行高固定 **32pt**（与 `CoconutBalanceCapsule` 齐平）
- 首页 Tab：`Menu`（添加成员 / 设置）+ 连续打卡天数胶囊 + 椰子胶囊
- 日历 Tab：视图切换玻璃胶囊 + 添加按钮
- 绿洲 Tab：椰子指南 + 百宝箱

### 页面滚动区结构
```
Spacer(height: 70)           // header 占位
PetWalletStack               // 宠物卡片转盘（可翻面）
emergencyAlertBanner         // 紧急健康警告（仅 urgent 级）
ForEach(orderedSections)     // 受 HomeSectionManageSheet 控制（顺序 + 显隐）
  ├── quickActions           // 横滑甲板 + 快捷操作网格 + 遛狗追踪卡（狗专属）
  ├── batchCheckIn           // 一键全家打卡（多宠物）/ 极简开启提示
  ├── memoryDrop             // 记忆碎片（需有历史数据才显示，可左右划消）
  └── islandStats            // 岛屿统计横滑卡
```

### 首页模块管理（HomeSectionManageSheet）
4 个独立模块，支持拖拽排序 + 独立显隐：
| sectionId | 标题 | 内容 |
|-----------|------|------|
| `quickActions` | 快捷操作 | HomeHighlightDeck + 快捷操作网格 + WalkTrackingCard（狗） |
| `batchCheckIn` | 一键打卡 | 多宠物批量喂食/喂水；未开启时显示极简开启提示 |
| `memoryDrop` | 记忆碎片 | 随机浮现历史温馨时刻；无数据时显示引导占位卡；左右滑消失 |
| `islandStats` | 岛屿统计 | 体重/步数/花费/粮仓 Bento 横滑 |

> **记忆碎片空态**：`MemoryEngine.pickFragment()` 返回 nil 时，若有宠物数据则渲染引导占位卡（`memoryDropPlaceholder`），而非直接隐藏模块。

### HomeHighlightDeck（宠物卡下方横滑甲板，160pt）
卡片顺序：`DeckPetStatusCard` → `DeckCheckInStreakCard`（打卡连击，含里程碑进度条）→ 委托卡 → `DeckLevelCard`（岛屿等级）
- 委托内容动态生成（按当日实际待办）：q_feed_\<UUID>、q_water_\<UUID>、q_potty、q_med_\<UUID>、q_reminder（有待办提醒时）
- 委托「去完成」→ 弹确认卡片（QuestConfirmationSheet），不直接打卡
- 每日首次打开 App 自动完成打卡并记录椰子奖励

### 快捷操作网格
- iOS 桌面风格编辑模式（抖动 + 拖排）
- 新建宠物后按物种默认前4项：狗(喂食/喂水/遛狗/便便)、猫(喂食/喂水/铲屎/便便)、鱼(喂食/换水/清滤材/体重)、其他(喂食/喂水/梳毛/体重)
- 长按 → 详情 Sheet；短按 → 直接打卡 / Popover（便便、护理、健康）
- 护理 `GroomPopoverContent`、健康 `HealthPopoverContent`（5选项）、便便 `PottyPopoverContent`

### WalkTrackingCard（遛狗追踪卡，狗专属，160pt）
- 在快捷操作区正下方展示（仅当 deckActivePet 为狗）
- 空闲：显示上次遛狗地图快照（可点击进入 WalkDetailView）/ 无记录则渐变占位
- 遛狗中：深色地图背景 + 实时距离 overlay
- 底部 `.ultraThinMaterial` 玻璃控制条：宠物名 + 计时器 + 开始/暂停/结束按钮

---

## 五、宠物卡片背面（WalletPetCardBack）— 功能枢纽

**3 分组行内布局，每组一行，所有入口通过 `OverviewView` sheet 弹出：**

### 健康管理
| SF Symbol | 标题 | 目标视图 | 物种限制 |
|-----------|------|---------|---------|
| `stethoscope` | 健康档案 | `PetHealthDetailView` | 全部 |
| `scalemass.fill` | 体重记录 | `WeightHistoryView` | 全部 |
| `pills.fill` | 用药管理 | `PetMedicationView` | 非鱼类 |

### 日常生活
| SF Symbol | 标题 | 目标视图 | 物种限制 |
|-----------|------|---------|---------|
| `fork.knife` | 饮食管理 | `PetFoodManagementView`（与长按快捷操作同款） | 全部 |
| `bubbles.and.sparkles.fill` | 清洁护理 | `PetHygieneDetailView` | 全部 |
| `figure.walk` | 遛狗记录 | `WalkSummarySheet` | 狗 |
| `drop.fill` | 便便记录 | `PottyOverviewView` | 全部 |
| `creditcard.fill` | 花费记录 | `ExpenseHistoryView` | 全部 |

### 档案与记忆
| SF Symbol | 标题 | 目标视图 | 物种限制 |
|-----------|------|---------|---------|
| `person.fill` | 基本信息 | `PetBasicInfoDetailView` | 全部 |
| `doc.fill` | 证件保障 | `DocumentsListView` | 全部 |
| `sparkles` | 重要时刻 | `PetMomentsHubView` | 全部 |
| `trophy.fill` | 成就 | `AchievementWallView` | 全部 |

背景为 MeshGradient（与正面主题色一致）
设置齿轮 → `PetCardBackSettingsSheet`（基本信息/寄养卡/彩虹桥/清空/删除）

### PetDetailView（纯数据仪表盘）
移除了工具栏（编辑/日历/寄养卡按钮）和底部三列导航卡（证件/时刻/成就），页面仅保留数据内容：
- `PetAlertScrollSection`（智能预警）
- `PetChartDashboard`（图表，含内部钻取 sheet）
- `PetHealthHubCard` + 用药管理行
- `PetHygieneCard` + `DietCardWithQuickActions`
- `DogActivityCard`（狗专属）
- `rainbowBridgeSection` + `deleteDangerZone`
- 椰子余额胶囊保留在页面顶部右对齐

---

## 六、保险管理

**`PetInsuranceView`**：保单列表（卡片 Menu：编辑/详情/删除）  
**`AddPetInsuranceSheet`**：
- 保单号、保额为 Toggle（关闭时写空字符串/0）
- 付款频次 2×2 等高网格
- 按年/一次性：DatePicker 选首期缴费日
- 新建时可自动批量生成 `PetExpenseLog`（全期付款计划）+ 日历 `Event`

**`InsurancePolicyDetailSheet`**：进度条 + Bento 格 + 报销记录 + 编辑/删除 Menu  
**三条资金流**：保费支出（PetExpenseLog）→ 报销申请（InsuranceClaim）→ 报销到账（负值 ExpenseLog）

---

## 六·A、长期留存：成长档案总览

**`PetRetentionHubView.swift`** 是单宠物长期留存聚合页，目标是把“长期价值”从分散页面收敛为一个清晰入口。

入口：
- `FunctionMenuSheet` → “档案与记忆” → **成长档案**
- `FeatureAggregateView(.retention)` → 选择宠物进入单宠物成长档案
- `PetAllFeaturesSheet` → 单宠物全部功能 → **成长档案**

聚合模块：
- **健康趋势**：最新体重、体重累计变化、近 90 天急诊/手术风险解释、健康记录数量 → `PetHealthDetailView`
- **成长相册**：照片数量、今年新增照片、重要时刻数量、时间线入口 → `PetMomentsHubView`
- **花费统计**：本月支出、本月预测支出、花费记录数量 → `ExpenseHistoryView`
- **保险 / 医疗记录**：医疗/用药/证件/保单摘要、即将到期/已过期保障提醒 → `DocumentsListView`
- **生命树成就**：成就解锁进度、连续打卡摘要、下一枚成就提示 → `AchievementWallView`
- **本周建议**：保障风险 + 近照提醒，用于把长期留存数据转成下一步行动

当前版本不新增底层模型，直接复用已有 `PetWeightLog` / `PetHealthLog` / `PetPhotoLog` / `PetMilestone` / `PetExpenseLog` / `PetDocument` / `PetInsurance` / `PetMedication` / `AchievementManager`，避免迁移风险。

---

## 七、全岛统计

**`IslandUnifiedStatsViewModel`**：
- `WeightAbsolutePoint` 按 `seriesID`（`pet:<UUID>`/`human:<UUID>`）分线，宠物使用 `weightInKg`
- 探索里程（近 7/30 天）+ 干饭王/自律王排行

**`IslandWeightDashboard`**：
- 趋势图按 UUID `seriesID` 分线（`LineMark(series:)` + `AreaMark(series:)`），避免同名合并
- 时间筛选从**今日倒数**：周 = 今天 -7天，月 = 今天 -1个月，年 = 今天 -1年（非日历周期起点）

**`IslandExpenseDashboard`**：饼图含 `insurancePremium` 青色分类  

---

## 八、日历（CalendarView）

- 嵌入 OverviewView：顶栏由 `globalFixedHeader` 控制，宠物筛选条在顶栏下方
- 独立经典模式：`classicCalendarHeader`（月份 + 玻璃切换胶囊 + 添加按钮）
- Material 模式：`calStickyHeader`（吸顶磨砂）
- 宠物筛选持久化：`@AppStorage("calendar_filterPetId")`
- 从宠物卡 / 宠物详情进入时可传 `preselectedPetId`，此时固定筛选当前宠物，不显示顶部宠物筛选条；GO 首页宠物卡展开态 FAB → “日历” 会自动传当前宠物 id。
- 宠物关联判断覆盖：直接宠物事件、粮仓事件、`pet_insurance` 通过保单反查宠物、`PetMedicationDoseLogging.relatedEntityTypeMedication` 通过用药计划反查宠物。
- `EventType.foodChange` 不在日历列表显示（喂食计划仅供提醒）

---

## 九、植物模块

- `PlantDashboardView`：植物卡片网格 + 紧急浇水区
- `PlantCareLog`：`.watering` / `.fertilizing`，写入 `Event` 计生命之树能量
- `IslandQuestEngine`：生成浇水/施肥委托任务

---

## 十、游戏化系统

- **椰子**：`QuestManager.shared.addCoconuts(_:emoji:title:)`，打卡/委托/打卡连续均发放
- **生命之树**：`OasisTreeManager.shared`，lv1-10，能量来自各类 Event
- **岛屿委托**：`IslandQuestEngine.todayQuests(pets:reminders:plants:events:)`，含用药委托 `q_med_<UUID>`
- **打卡连击**：`oasis_checkedIn_dates` UserDefaults 用于 `DailyStreakDetailView` / `OasisRewardView` 的每日打开 App 连胜；GO UI 顶部 `🔥` 当前显示 `pets.map(\.currentStreak).max()`（所有宠物护理 streak 最大值），两者不是同一数据源。

### 成就系统（AchievementManager，15枚）
`static func compute(for pet: Pet) -> [Achievement]` 纯计算，无副作用；`AchievementWallView` 负责展示进度、宠物切换、过滤、详情弹窗与椰子奖励领取。

入口：
- 绿洲页 `OasisRewardView` 的成就入口打开 `AchievementWallView(pet:allPets:)`，支持在全部未离世宠物间切换。
- 宠物详情 / 功能菜单 / retention hub 仍可直达单宠成就页。

奖励：
- 每个宠物的每枚成就可领取一次 `10🥥`，领取记录存储在 `achievement_claimedRewardIDs`，key 为 `<petId>_<achievementId>`。
- 领取时通过 `QuestManager.shared.addCoconuts` 写入椰子流水，标题为 `成就奖励 · <成就名>`。
- 已解锁未领取的成就会在页面 overview 中显示待领取数量，并支持“领取全部”。

| 序号 | ID | 触发条件 |
|------|----|---------|
| 1 | `iron_gut` | 连续7天每天有 perfectPoop 记录 |
| 2 | `iron_paw` | 累计遛狗 ≥ 100km |
| 3 | `walk_streak` | 连续7天有遛狗记录 |
| 4 | `health_hero` | 30天内无紧急就医/手术 |
| 5 | `nutritionist` | 喂食记录或喂食 care log 跨度 ≥ 14天 |
| 6 | `happy_birthday` | 今天是宠物生日 |
| 7 | `hundred_days` | `pet.daysTogether >= 100` |
| 8 | `first_record` | 至少一条健康、便便、遛狗、护理、喂食、花费、体重、照片或里程碑记录 |
| 9 | `day_one_checkin` | 今天完成至少一次健康、清洁、便便、护理、遛狗或体重记录 |
| 10 | `old_friend` | App 使用 ≥ 7天 |
| 11 | `long_runner` | 单次遛狗 ≥ 5km |
| 12 | `medication_complete` | 完成至少一个完整用药疗程 |
| 13 | `photo_enthusiast` | 照片数 ≥ 20张 |
| 14 | `expense_tracker` | 花费记录 ≥ 10条 |
| 15 | `weight_manager` | 体重记录 ≥ 7条 |

另有2枚人宠联动成就（需 HealthKit）：`bonded_walk` / `step_champion`，通过 `computeBonded(for:humanDistanceKm:)` 计算。

---

## 十·A、家庭周报升级

**`FamilyWeeklyReportDashboardView.swift`** 是全家庭多宠周报入口。2026-05-07 起家庭协作不再作为首页折叠态卡片展示，避免首页超载。

入口：
- GO 首页 FAB / `FunctionMenuSheet` → **家庭协作** → **家庭周报** 分段（仅人类成员数 > 1 时显示）

能力：
- 全家庭本周总览：照护次数、参与成员数、椰子奖励数
- 成员贡献排行：按 `executorId` 聚合 `PetCareLog` / `PetPottyLog` / `PetWalkLog` / `PetExpenseLog`
- 宠物照护覆盖：显示每只在世宠物本周记录数和“待关注”状态
- 最近动态：展示最近 8 条家庭照护事件
- 近 4 周趋势：按周统计全家庭照护数量
- 分享：`ShareLink` 输出轻量文本周报

仍保留 `WeeklyReportCard(pet:)` 作为单宠物周报卡，可在其它详情路径继续使用。

---

## 十一、颜色系统

```swift
Color.goPrimary   // 浅色 #FF7600 / 深色 #C8FF00（全局主色）
Color.goYellow    // #FFF44F
Color.goOrange    // #FF8C42
Color.goRed       // #FF4757
Color.goTeal      // #00D4AA
Color.goBlue      // 蓝色系
Color.goPurple    // 紫色系
Color.arkInk      // 黑色（主色按钮文字）

// 16种宠物主题色（非绿）
Color.petThemeCrimson / Vermilion / Orange / Amber / Yellow / Brown / Rust / Burgundy
Color.petThemeMagenta / Pink / Purple / Indigo / Violet / Navy / Blue / SkyBlue
```

---

## 十二、添加宠物向导（AddPetWizardView）

### 步骤结构
`basicInfo → breed → avatar → dates → gender → birthplace → identity → appearance → familyRelation → confirm`

### 头像裁剪（PetImageCropView）
- 取景框尺寸：**300 × 189 pt**（卡片比例 1.586:1，与首页宠物卡片一致）
- 圆角 20pt，左半区有宠物轮廓引导（pawprint + "宠物放这里"）
- 手势：`SimultaneousGesture(MagnifyGesture(), DragGesture())` — 支持捏合缩放 + 平移
- 底部控制栏：`.safeAreaInset(edge: .bottom)` 内嵌「取消」+「确认裁剪」
- 辅助 struct：`CardCropOverlay(cropW:cropH:cornerRadius:)` + `CardCropCorners(width:height:radius:)`

### 卡片样式
- 各步骤内容卡用 `.goTranslucentCard(cornerRadius: 24)`（glassEffect），无阴影，浮于背景之上

---

## 十三、用药提醒系统（MedicationReminderService）

**文件**：`Ohana/Models/MedicationReminderService.swift`

- 单例 `MedicationReminderService.shared`
- `scheduleMedicationReminders(for pet: Pet)`：先移除该宠物旧通知，再按各药品频次重新注册未来 14 天推送
- 频次 → 每日次数：`PetMedicationFrequency.dosesPerDay`（daily=1 / twiceDaily=2 / threeTimesDaily=3 / everyOtherDay=1 / weekly=1 / asNeeded&custom=0）
- 基准时间 08:00，多次服药按 `24h / dosesPerDay` 间隔递推
- 疗程结束前3天追加提醒推送（`cancelMedicationReminders(for petId:)` 可取消）
- **今日进度追踪**（UserDefaults，键名 `med_doses_YYYY-MM-dd_<UUID>`）：
  - `dosesTakenToday(for:)` / `recordDose(for:)` / `undoDose(for:)`
- `PetMedicationView` 用药卡片新增今日进度条（`dosesTaken / dosesPerDay`）+ 快捷 ＋ 按钮

---

## 十四、清洁护理周期自定义

**文件**：`Ohana/Models/PetHygieneLog.swift`、`Ohana/Views/Details/PetHygieneCard.swift`、`Ohana/Views/Details/PetHygieneDetailView.swift`

- `HygieneType` 新增：`defaultCycleDays`（硬编码默认值）、`effectiveCycleDays(for petId: UUID)`（读自定义，否则用默认）
- 自定义存储键：`hygiene_cycle_<petUUID>_<typeRawValue>`（UserDefaults）
- 静态工具：`customCycleDays(for:petId:)` / `setCustomCycleDays(_:for:petId:)`
- 周期只在“设置护理计划”页维护：`HygieneTodoSheet` 提供 `- / +` 天数步进，保存计划时写入 `Event.recurrenceDays`，并同步更新该宠物该护理项的 `hygiene_cycle_*`。
- 护理计划支持“全天日程”开关；关闭全天后显示时间选择器，`Event.startDate` 和 `Reminder.scheduledAt` 使用用户指定时间。全天日程的提醒默认按当天 09:00 注册。
- `PetHygieneDetailView` 每张类型卡只展示当前周期标签，不再提供单独“调整周期”按钮，避免周期入口分散。
- 顶部 overview 使用“连续打卡 strike”：按各护理项的有效周期判断记录是否连续，而不是要求每天护理。

---

## 十五、遛狗行为备注与心情评价

**模型**：`PetWalkLog.behaviorNotes: String?`（可选文字备注） + `moodRating: Int`（0=未评/1-5星）

**视图**：`WalkSummarySheet`
- 检测「新鲜步行」（10分钟内完成）时，在汇总页顶部显示「本次巡岛心情」卡
- 支持1-5星评分 + 文字备注输入，保存后写入最近一条 `PetWalkLog`
- 历史记录行显示星级（★★★）+ 备注摘要（单行截断）

---

## 十六、品种护理贴士

**数据**：`PetBreedDatabase.breedCareTips: [String: [String]]`（21个常见品种，含狗/猫）
- 查询函数 `careTips(for breed: String) -> [String]?`：先精确匹配，再模糊匹配（contains 双向）

**视图**：`PetBasicInfoDetailView.breedTipsCard(breed:tips:)` — 折叠卡
- 仅在非编辑模式 + 品种字段有值 + 数据库有匹配时渲染
- 默认展开，点击标题栏折叠/展开（带弹性动画）

---

## 十七、家庭悬赏榜历史归档

**文件**：`BountyBoardView.swift`

「已完成」Tab 新增分层显示：
- **近7天完成**：正常透明度显示
- **历史归档**（> 7天前）：折叠在「历史归档 (N)」按钮后，透明度 0.7，可点击展开/收起

**UI 规范对齐（2026-04-16）**：`BountyBoardView` / `AddBountyTaskSheet` 与椰子商店一致：`ArkBackgroundView()`、导航栏 `.toolbarBackground(.ultraThinMaterial)`、`OhanaFont` + `primaryText` / `secondaryText` / `tertiaryText`；统计与周报卡片使用材质 + `Color.primary` 描边；主色胶囊上文案用 `Color.arkInk`。同次迭代中 **`GachaView`（欧气扭蛋机）** 已按同一套背景、导航与语义色刷新。

---

## 十八、通知分类管理（SettingsView）

设置页「通知」区新增4个功能级别开关（UserDefaults bool，默认 `true`）：

| 开关标题 | UserDefaults Key |
|---------|-----------------|
| 用药提醒 | `notif_medication_enabled` |
| 喂食提醒 | `notif_feeding_enabled` |
| 护理提醒 | `notif_hygiene_enabled` |
| 打卡提醒 | `notif_checkin_enabled` |

工具函数：`notificationToggleRow(icon:iconColor:title:key:)` — Toggle 行复用组件

---

## 十九、体重页饮食-体重关联

**文件**：`WeightHistoryView.swift`

- 新增 `feedingInsightBanner(avg:)` 横幅卡，位于折线图与历史记录列表之间
- 显示条件：宠物有精准模式喂食记录（`dailyGrams > 0`），取近7条计算日均
- 内容：日均摄入克数 + 最新体重变化方向箭头 + 近5天摄入 mini 柱状图

---

## 二十、照片分享

**文件**：`PetPhotoAlbumView.swift`

- 照片缩略图 contextMenu 新增「分享」选项（排在「删除」前）
- 调用 `shareImage(_:)` → `UIActivityViewController`，自动找最顶层 presentedViewController 弹出

---

## 二十一、背景系统（AppBackgroundStyle）

| 风格 | `@AppStorage("appBackgroundStyle")` 值 |
|------|---------------------------------------|
| Go 经典 | `classic` |
| 深邃光球 | `deepBlue` |
| 极光 | `aurora` |
| 午夜 | `midnight` |
| 落日熔金 | `sunset` |
| 樱雾 | `sakura` |
| 森谷 | `forest` |
| 暖纸 | `warmPaper` |
| 霓虹格 | `neonGrid` |

---

## 二十二、宠物剪影（PetSilhouetteView）— Kawaii 风格重设计

**文件**：`Ohana/Views/Components/PetSilhouetteView.swift`

全部5种动物剪影替换为 Kawaii 奶头乐风格，使用纯 SwiftUI 几何形状绘制（`Circle`/`Ellipse`/`Capsule`/`Path`），无 SVG 依赖。

| 物种 | struct | 特征 |
|------|--------|------|
| 猫（猫） | `CatSilhouette` | 圆头 + 粉色三角耳内 + 胡须 + 径向渐变毛绒感 + 尾巴 |
| 狗（狗） | `DogSilhouette` | 耷拉长耳 + 面部暗色斑 + 白色口鼻区 + 圆身 |
| 兔子（兔子/兔） | `RabbitSilhouette` | 竖长耳（紫色内耳 `#C9A4D8`）+ 三点腮红 + Y型嘴 |
| 仓鼠（仓鼠） | `HamsterSilhouette` | 橙色帽感头顶 + 白色椭圆脸 + 小圆耳 |
| 鸟（鸟） | `BirdSilhouette` | 泪滴形身体 + 白肚 + 冠羽 + 橙黄喙 |

**共享组件**：`PetEyeView(size:)` — 白色外圈 + 彩色虹膜 + 黑瞳 + 白色高光点

**颜色来源**：`coatColor`（`WalletPetCardTheme.silhouetteCoatColor(for:)`）+ `eyeColor` + 物种固定 accent（粉耳内 `#FFB3C1`、紫耳内 `#C9A4D8`、橙帽 `#E67E22` 等）

**使用场景**：`WalletPetCardFront`（首页卡正面无头像时）+ `WalletPetCardDraftFront`（添加向导预览卡）

---

## 二十二 · A、人类成员剪影（HumanSilhouetteView）与新建成员

**文件**：`Ohana/Views/Home/PetWalletStack.swift`、`Ohana/Views/Forms/AddHumanWizardView.swift`、`Ohana/Models/Human.swift`

人类成员卡片已从 emoji 头像 fallback 改为性别剪影 fallback：
- `HumanSilhouetteView(gender:accent:)` 使用纯 SwiftUI 几何形状绘制男/女剪影，与宠物剪影的卡片语言保持一致。
- 新建人类成员时，原 emoji 头像选择区域已移除，改为男 / 女性别选择。
- 性别当前沿用既有 `Human.notes` 中的 `性别:<value>` 片段保存；`Human.genderRaw` 负责解析，避免为性别单独引入一次 SwiftData schema 迁移。
- 若用户选择相册 / 拍照 / 粘贴图片作为头像，卡片优先显示图片；剪影仅在没有头像图片时显示。
- 新建成员仍会写入兼容用 `avatarEmoji`（男=👨、女=👩、未选=👤），供旧列表和非卡片场景 fallback。

受影响卡片：
- `WalletHumanCardFront`：正式人类钱包卡，无照片时显示剪影。
- `WalletHumanCardDraftFront`：新建成员向导顶部预览卡，无照片时随性别实时切换剪影。
- `FocusWalletCardView`：GO 首页卡堆中的人类卡，无照片时显示剪影。

---

## 二十三、宠物卡片正面（WalletPetCardFront / WalletPetCardDraftFront）

**文件**：`Ohana/Views/Home/PetWalletStack.swift`

### 布局规范
卡片比例 **1.586:1**（横向），卡宽 = `ScreenWidth - 48`，高 = 宽 / 1.586。

| 区域 | 宽度 | 内容 |
|------|------|------|
| 左半（头像区） | `w × 0.52` | 头像照片 / Kawaii 剪影 |
| 右半（信息区） | 其余 | 连续打卡徽章 + Days Together + 脚注 + 条码 |

### 头像照片显示（非抠图）
`avatarLayer` / `draftAvatarLayer` 非透明分支：
- `scaledToFill()` 填充 `w × 0.52` × `h` 的竖向区域
- 右边缘用 `LinearGradient` mask 渐变淡出（0→65%→100% 不透明）
- 上层叠加 `screen` 混合模式的主题色渐变光效

### 头像照片显示（抠图/透明 PNG）
- 双层叠加：白色轮廓影（`colorMultiply(.white)` + 多方向 shadow）+ 原图
- `scaledToFit()` + 底对齐，适合宠物站立姿势的抠图

### WalletPetCardTheme 工具方法
| 方法 | 作用 |
|------|------|
| `gradientPair(for:)` | 从 `themeColorHex` 推导顶/底渐变色 |
| `meshColors(for:)` | 生成 3×3 MeshGradient 色阵 |
| `headlinePointSize(cardWidth:headlineCount:)` | 宠物名字号自适应（≤6字满幅，更长缩小） |
| `silhouetteCoatColor(for:)` | 从 `pet.coatColor` 展示名解析为 `Color` |
| `silhouetteEyeColor(for:)` | 从 `pet.eyeColor` 展示名解析为 `Color` |

### Schema 迁移注意事项
新增 `@Model` 非可选属性时**必须在属性声明处加 `= 默认值`**（仅在 `init()` 中赋值不够），否则 SwiftData 轻量迁移失败，数据库降级到内存库。

---

## 二十三 · A. 首页简化 · 岛屿三层重构（2026-04-16）

解决"信息大爆炸"问题，把原先 11 层首页压缩为 3 层核心 + 1 层可折叠。

### 新结构（自上而下）

| 层级 | 组件 | 高度 | 职能 |
|:-:|:-|:-:|:-|
| 1 | `globalFixedHeader` | 52pt | 问候/Menu/家人/连击 🔥/椰子胶囊 |
| 1.5 | **`IslandMoodHeaderStrip`** | 60pt | 天气+情绪+负反馈+问候，1 行搞定；点击展开 `IslandSummarySheet` |
| 2 | `PetWalletStack` | ~300pt | 宠物卡牌转盘（顶卡微漂浮动画 ±3pt / 6s） |
| 2.5 | **`FamilyActivityStripView.compact`** | 30pt | 家人头像堆叠 + "今天 X 次" 微胶囊，点击弹完整 Sheet |
| 3 | `emergencyAlertBanner` | 按需 | 仅 `.urgent` 健康警告时显示 |
| 4 | **`TodayFocusCard`** | 130pt | 按优先级智能推送 1 件事（委托/负反馈/回忆/庆祝） |
| 5 | `quickActionsSection` | 网格 | 保持原样，4 列 SF Symbols |
| 6 | `batchCheckInOnlySection` | 按需 | 多宠一键全家 |
| 7 | **`HomeMoreSection`** | 折叠 | 「更多 · 岛屿近况 ⌄」默认折叠，展开显示记忆碎片 + 岛屿统计 |

### 新组件

- **`Ohana/Views/Home/IslandMoodHeaderStrip.swift`**
  - Emoji 映射 `IslandMood`：☀️晴朗 / 🌤微风 / ⛅阴天 / ⛈风暴 / 🎉庆祝 / 🌿植物风
  - 消息优先级：紧急负反馈 > 庆祝里程碑 > 连击 ≥ 7 → ≥ 3 > 轻度警告 > 问候
  - 红点：`negativeSignals.count`
  - 轻度动画：两片浮云 `offset` 往返 + 圆圈呼吸

- **`Ohana/Views/Home/IslandSummarySheet.swift`**
  - 顶部天气主图 + 连击卡 + 负反馈列表（红黄双色） + "一切安好"态

- **`Ohana/Views/Home/TodayFocusCard.swift`**
  - `FocusContent` 枚举：`.quest / .negative / .memory / .celebrate / .welcome`
  - 图标呼吸、完成按钮、Reward Chip（椰子数）
  - `IslandQuestEngine.todayQuests().first(unfinished)` → 最高优先级

- **`Ohana/Views/Home/HomeMoreSection.swift`**
  - 通用折叠容器：`AppStorage("home_more_expanded")` 持久记忆状态
  - 标题带"回忆 · 统计"提示，弹簧动画展开

- **`Ohana/Views/Home/StreakFlameParticles.swift`**
  - 连击 ≥ 7 时在连击胶囊右上角喷出 3 颗 ✨🔥✨ 循环粒子

### 修改点

- `OverviewView.mainScrollView` — 完全重构为新 8 层结构，旧 `quickActionsOnlySection`（包含 HighlightDeck）变为死代码保留不删除
- `FamilyActivityStripView` — 新增 `Style` 枚举与 `compact` 模式，胶囊态显示家人头像堆叠 + 总次数
- `PetWalletStack` — 顶卡新增 `idleBreath` 呼吸漂浮（仅 `isActive && !isDragging && !isFlipped` 时触发）
- `HomeSectionManageSheet` — `HomeSectionEntry.defaults` 增加 `islandHeader / familyStripMini / todayFocus` 三个新 ID

### 落地效果

- 首屏可见模块：7+ → 3（岛屿胶囊 + 宠物卡 + 聚焦卡）
- 纵向滚动：2 屏 → 1 屏
- 可爱度：顶卡微漂浮 + 浮云 + 火苗粒子 + 呼吸光晕
- 所有功能入口保留：快捷操作网格保留、宠物卡片背面 8 格功能枢纽不动、记忆/统计收进可折叠区

---

## 二十三 · B. GO UI 首页（2026-04-26，**当前默认主页**）

`FocusStackHomeTestView` 是 `@AppStorage("appUIStyle") == "go"`（默认值）时的主界面。当前版本以 Apple Wallet 式宠物/家人卡片堆为核心：折叠态显示底部完整前卡，点选态将 active card 上移到顶部按钮下方，其它卡片压缩到底部，同时在 active card 下方显示快捷模块。

### 页面结构（自上而下）

```
ZStack
├── ArkBackgroundView()                         // 跟随 Settings 背景设置
├── stackLayer                                  // 未展开时：header + 任务白卡 + 卡片堆/空态
│   ├── goFocusHeader(safeT: safeAreaTop)
│   ├── TodayFocusCard                          // 今天谁需要照顾 / 什么最紧急 / 一点完成；本次再上移 10pt，当前 offset -20pt
│   ├── firstSuccessCheckInCard                 // 新用户首次快捷打卡闭环（按需）
│   └── walletCardStack(cards:)                 // 仅 collapsed 显示，底部锚定
├── expandedWalletLayer(cards:geo:)             // isExpanded == true 时根层绝对定位
│   ├── active FocusWalletCardView              // safeAreaTop + 76pt
│   ├── expandedQuickModules                    // active card 下方
│   └── inactive cards                          // 底部压缩，只露出顶部文字条
└── homeFabOverlay / scrim                      // 常驻右下角；主按钮不卸载，只按状态切换子菜单
```

### Header — `goFocusHeader`

顶部按钮统一为和 `CoconutBalanceCapsule` 一致的绿色胶囊样式（`Color.goPrimary`、26pt 高、黑色文字/图标）。

- **中间**：`🔥 + headerStreak` 胶囊 + `CoconutBalanceCapsule(onTap:)`
  - `headerStreak = pets.map { $0.currentStreak }.max() ?? 0`
  - 注意：这不是 `oasis_checkedIn_dates` 的每日打开 App 连胜，而是所有宠物护理 streak 的最大值。
  - 椰子胶囊点击 → `OasisRewardView`；绿洲页内的椰子资产胶囊再进入 `IslandWealthDashboardView`
- **右侧**：`person.2.fill` 成员胶囊 + `calendar` 胶囊 + `gearshape.fill` 设置胶囊
  - 成员胶囊 → `CrewRosterOverlay`
  - 日历胶囊 → `CalendarView`；若当前处于宠物卡展开态，会自动传入 active pet id 并只显示该宠物相关日程
  - 设置胶囊 → `SettingsView`
- 高度 = `safeT + 56`；`safeT` 用 UIKit keyWindow safe area，避免 `.ignoresSafeArea(.all)` 下 GeometryReader 返回 0。

### Apple-Wallet 卡片堆状态

当前状态由两个变量驱动：

| 状态 | `isExpanded` | `activeCardId` | 行为 |
|---|---:|---|---|
| 折叠态 | `false` | 可为空/默认第一张 | `walletCardStack` 在剩余空间底部锚定；底部卡 `zIndex` 最高且完整显示；其它卡只露出顶部文字条 |
| 点选态 | `true` | 被点卡片 id | `expandedWalletLayer` 根层绝对定位；active card 顶部移动到顶部胶囊下方；inactive cards 向下压缩到底部 |
| 收起 | `false` | 保留上次 active | 再点 active card 或向下拖拽 > 80pt，使用同一弹簧动画恢复折叠态 |

**关键实现**：
- 折叠态只在 `stackLayer` 中渲染 `walletCardStack`。
- 展开态隐藏 `FocusMoodQuestStrip`、隐藏原卡堆，改由根 ZStack 渲染 `expandedWalletLayer`，避免受 VStack 布局影响。
- FAB 主按钮在 `expandedId == nil` 时保持常驻同一个 overlay，不因 `isExpanded` 切换而卸载/重建；卡片点选后只切换子菜单内容，避免闪烁。
- 点击 inactive card 时切换 `activeCardId`，不会立即收起。
- 所有 wallet 状态动画使用 `HeroAnim.walletSpring = .spring(response: 0.4, dampingFraction: 0.85)`。

### 布局常量 — `K`

| 常量 | 当前值 | 含义 |
|---|---:|---|
| `hPad` | 20 | header 水平 padding |
| `cardMargin` | 7 | 卡片到屏幕边缘的间距 |
| `cardH` | `(ScreenCompat.width - cardMargin * 2) / 1.586` | 折叠态卡片高度，保持信用卡比例 |
| `expandedCardH` | 360 | 点选态 active card 高度（竖向放大） |
| `cardTitleH` / `collapsedStackPeekH` | 49 / 44.1 | 折叠/压缩态每张卡露出的顶部身份条高度；卡片堆露出间隔为原来的 90%，底部锚点不变 |
| `collapsedStackBottomGap` | 22 | 折叠态前卡底部到屏幕安全区的间距 |
| `expandedStackBottomGap` | 12 | 展开态底部压缩卡堆到安全区底部的间距 |
| `expandedCardGlobalTopOffset` | 76 | active card 顶部 = safeAreaTop + 76，保持在顶部按钮下方 |
| `expandedQuickModuleH` | 112 | active card 下方快捷模块高度 |
| `expandedQuickModuleEditH` | 206 | 展开态快捷模块编辑模式高度（含添加入口） |
| `HeroAnim.stackCardCorner` | 24 | 卡片圆角 |

### 卡片数据 — `FocusCard`

`FocusCard` 从 `Pet` / `Human` 组装，用同一个结构喂给卡片堆、展开卡、快捷模块。

- 首页卡片源头先过滤：宠物读取 `HomeCardVisibility.hiddenPetIDsKey`（UserDefaults key: `hiddenHomePetIDs.v1`），人类读取 `Human.shouldShowOnHome`。
- GO 首页只取过滤后的前 7 张。卡片展开页提供“首页显示”开关，若首页已满 7 张，尝试显示新的宠物/人类会提示先隐藏一张。
- `FocusCard.from(Pet)`：
  - 狗：FEED / WALK / WATER / POTTY
  - 猫：FEED / WATER / LITTER / PLAY
  - 鱼：FEED / WATER / FILTER
  - 其它：FEED / WATER / PLAY
  - 额外携带：`daysTogetherText`、`ageText`、`zodiacText`、`genderText`、`avatarImageData`、`petSpecies`、`coatColor`、`eyeColor`、`patternName`、`themeColorHex`、`breed`
- `FocusCard.from(Human)`：
  - WEIGHT / WORKOUT / NOTE
  - `isHuman = true`
  - `humanGender = human.genderRaw`，用于无头像时渲染男/女剪影
- `FocusCard.dummies` 仅在 `@AppStorage("debugShowDummyCards") == true` 且真实数据为空时显示。

### 卡片渲染 — `FocusWalletCardView`

`FocusWalletCardView` 复用 `WalletPetCardFront` 的视觉语言，并在展开态切换到更接近身份卡的竖向布局；折叠卡片的顶部身份条左侧显示名字，名字右侧显示物种/角色，物种使用普通字重。

- 背景：真实实体使用 `WalletPetCardTheme.meshColors(for:)` 的 3×3 `MeshGradient`；dummy 使用 `card.color` 派生渐变。
- 宠物图像：
  - 非透明照片：全幅 `scaledToFill` + 右侧可读性遮罩。
  - 透明 PNG：白色轮廓影 + 原图 popout。
  - 无头像：`PetSilhouetteView` Kawaii 剪影。
- 人类图像：
  - 非透明照片 / 透明 PNG 逻辑同宠物。
  - 无头像：`HumanSilhouetteView`，按 `Human.genderRaw` 显示男/女剪影。
- 展开态：
  - 宠物名大号显示在顶部，物种字幕在其下。
  - 左侧显示宠物剪影/照片。
  - 右下显示 Days Together、年龄/品种/物种脚注、`O H A N A   P E T` 条码。
  - 紧凑态顶部显示 `topIdentityBar`，保证卡片被压缩时仍可识别名字和属性。

### 展开态快捷模块 — `expandedQuickModules`

active 宠物 / 人类卡下方复用经典 UI 的 `GoQuickActionCard` 网格样式，读取同一份 `@AppStorage("quickActionItems_v2")`。宠物若没有自定义项，则按物种生成默认前 4 项；人类默认项为体重 / 运动 / 用药 / 备注。短按执行快捷打卡 / 打开快速 sheet；长按进入对应详情。护理、健康、便便复用经典 UI 的 Popover 分流；dummy 卡继续使用原轻量入口。

执行人绑定：
- 喂食 / 喂水 / 换水 / 铲屎 / 便便 / 逗玩等快速打卡，自动使用 `@AppStorage("currentActiveHumanId")` 作为 `executorId`。
- 添加体重 / 记录 / 护理 / 健康时，同样默认绑定当前手机使用者。
- 快捷操作界面不显示执行人选择栏；大多数打卡在后台自动记录到本机当前使用者，降低用户感知。
- 添加花费时，`AddExpenseSheet` 提供“支付者”选项，默认同当前手机使用者；`ExpenseHistoryView` 会显示支付者/到账来源。

编辑模式：标题行右侧铅笔进入编辑；编辑态同样最多显示 4 个快捷项，少于 4 个时显示“添加”占位格；支持抖动、减号删除、拖拽排序；点击完成后写回 `quickActionItems_v2`，与经典 UI / 宠物详情共享同一份配置。

椰子增长动画：`CoconutBalanceCapsule` 监听 `QuestManager.shared.coconutCount`，只在数值增加时触发轻微 pulse、`+N` 浮标和 haptic；减少椰子时只更新数字，不播放奖励动画。

默认项：
- 狗：喂食 / 喂水 / 换水 / 遛狗 / 护理 / 体重 / 记录
- 猫：喂食 / 喂水 / 换水 / 铲屎 / 陪玩 / 体重 / 记录
- 鱼：喂食 / 换水 / 清滤材 / 体重
- 其它：喂食 / 喂水 / 护理 / 体重

展开态 FAB 会读取当前快捷模块中已经显示的项目，只展示未显示项目和“全部功能”；用户编辑快捷模块后，FAB 子菜单同步变化。铲屎、护理等一天只应完成一次的项目，今天已打卡时会给出提示并阻止重复打卡。

### 喂食管理 — `QuickFeedDetailSheet`

`QuickFeedDetailSheet` 已从长表单重构为 Go Focus 顶部标签页，默认进入“今日”，主路径是 10 秒内完成一次喂食记录。

顶部标签：
- **今日**：默认页。`FeedTodayState` 自动聚合手动喂食与计划喂食；有今日计划时按计划提醒计算完成进度，无今日计划时按每日目标餐数计算。顶部 Focus 卡展示完成数、下一餐/已逾期、今日已喂克数、粮仓断粮风险。
- **计划**：保留 `Event + Reminder` 喂食计划数据；按今天状态显示待完成、已逾期、已完成、未来计划。新增计划保留紧凑表单：时间、克数、保存；删除计划需要二次确认。
- **粮仓**：保留佛系 / 精准两种模式。顶部先显示品牌、剩余天数/断粮日、提醒状态；“补粮/开包”继续写入 `PetFoodRecord`，有价格时写入 `PetExpenseLog(category: .food)`，断粮提醒复用现有 food stock reminder 事件。
- **历史**：展示今日记录、近 7 天喂食柱状图、最近 15 条记录；手动和计划记录用 badge 区分，删除记录后同步刷新粮仓提醒。

记录规则：
- 主 CTA 固定为“记录喂食”。若存在今日待完成或 failed 的计划提醒，优先完成最早一餐；否则写入手动喂食。
- 快捷克数 chip 来源：宠物默认份量、下一餐/今日计划克数、最近常用克数；仍允许手动输入。
- `HomeFeedRecordMode` 保留兼容旧数据，但不再作为喂食页可见主控件；首页完成态与喂食页都改由 `FeedTodayState` 判断。
- 计划喂食写入 `PetCareLog.plannedFeedNotePrefix`，手动喂食写入 `PetCareLog.manualFeedNoteMarker`，用于历史和统计互斥展示。

### Today Focus 与家庭协作入口

GO UI 折叠态首屏已收敛为 Today Focus：优先回答“今天谁需要照顾、什么最紧急、我点一下能完成什么”。当前模块 offset 为 -20pt，展开卡片时隐藏，避免与 active card 下方快捷模块争抢空间。

**`TodayFocusCard`**：
- 数据来自 `IslandQuestEngine.todayQuests(pets:reminders:plants:events:humans:)`
- 传入 `activePet: todayFocusActivePet`
- 多个任务横向分页显示，底部使用自定义页点；卡片按钮为“去完成”，完成后短暂显示“已完成”并划走。
- 完成回调走 `completeQuestInFocusStack(_:)`，继续发放椰子奖励并写入现有照护日志/账本路径。
- 异常趋势 / 医疗风险优先于普通任务：`IslandNegativeFeedback` 聚合疫苗/驱虫/体重/症状/证件风险，以及食欲下降、便便异常、饮水异常等趋势信号。
- 新宠默认护理计划通过 `CarePlanCalendarSync.ensureDefaultPlans(for:context:)` 写入 `Event`；基础信息页保存时也会刷新物种/品种对应计划。Today Focus 只读取今天到期且尚未完成的计划任务。
- 护理任务 subtitle 会显示“上次由谁完成 / 多久前”或“今天还缺什么”，避免多人家庭重复照顾。
- 已遛狗会自动视作今日陪玩已完成，避免每个宠物每天都生成重复陪玩任务；无任务时显示庆祝卡。
- 右侧绿洲入口 `onTapOasis` 打开 `OasisRewardView`

**默认护理计划**：
- 狗：喂食 / 饮水 / 遛狗 / 体外驱虫 / 体内驱虫 / 疫苗复查 / 毛发护理。
- 猫：喂食 / 饮水 / 铲屎 / 陪玩 / 体重 / 毛球与毛发护理。
- 鱼：喂食 / 换水 / 过滤检查 / 水温检查。
- 鸟：喂食 / 饮水 / 清理鸟笼 / 放飞互动 / 体重。
- 兔子：喂食 / 饮水 / 清理厕所 / 毛发护理 / 体重。
- 爬宠：喂食 / 补水保湿 / 温湿度检查 / 环境清洁 / 蜕皮观察。
- 非每日任务从下一周期开始到期，避免新宠加入当天把 Today Focus 塞满；品种/毛发关键词会调整毛发护理间隔，蛇/龟等爬宠会调整喂食间隔。

**新用户 3 分钟成功体验**：
- `OnboardingView.finishOnboarding()` 设置 `ohana_show_first_success_card = true`
- 首页显示 `firstSuccessCheckInCard(pet:)`，引导完成第一次“喂食 +🥥”
- 成功后写入喂食记录、触发椰子奖励动画，并设置 `ohana_first_quick_checkin_completed = true`

**家庭协作路径**：
- 首页折叠态不再显示 `familyCollaborationCard(pet:)`；家庭协作改走 FAB / 周报 / 详情页，保持首页只回答三件事。
- 仅当人类成员数 `humans.count > 1` 时显示家庭协作入口；单人家庭隐藏，避免制造无意义协作噪音。
- `FamilyActivityStripView(style: .compact)`：今日谁照顾了当前宠物
- `assignedPendingReminders(for:)`：读取当前宠物今日内已指派 `Event.assigneeId` 的 pending reminders
- `AssigneeChip` + `NudgeButton`：展示负责人并提供本地催办反馈
- 周报入口打开 `FamilyWeeklyReportDashboardView`（全家庭多宠周报）

**任务完成处理**（`completeQuestInFocusStack`）：
- `q_feed_*` → `.feeding` PetCareLog（`dailyPortionGrams` + `manualFeedNoteMarker`）
- `q_water_*`（非植物）→ `.watering` PetCareLog
- `q_walk` → `PetWalkingManager.shared.start(pet:)`
- `q_potty` → 猫/兔写入 `.litter` PetCareLog；其它宠物写入 `.perfectPoop` PetPottyLog
- `q_water_plant` / `q_fertilize_plant` → 更新植物日期 + `PlantCareLog`
- `q_reminder` → `showingCalendar = true`
- 用药任务 → `PetMedicationDoseLogging.recordDose`
- `q_event_*` → 标记对应 `Event` 当日 occurrence 已完成
- 除 `q_walk` 外，完成后均 `QuestManager.shared.addCoconuts(amt, title: "岛屿任务")`

**就诊卡片**：
- `PetBasicInfoDetailView` 读取态新增“就诊卡片”，汇总疫苗、过敏、当前用药、近期症状、保险、最近体重、芯片号。
- 使用系统 `ShareLink` 生成给兽医看的文本摘要；深数据仍保留在健康、保险、文档详情页。

### FAB（右下角悬浮按钮）— `homeFabOverlay`

主按钮是 56pt 深蓝圆（`#1A2E8A`），在 GO 首页和宠物卡点选态保持同一位置、同一实例挂载；点击卡片不会造成 FAB 闪烁，只切换子菜单内容。

折叠态 / 未点选卡片时，展开后显示首页级常用入口：

1. **饮食** → `FeatureAggregateView(.food)`
2. **清洁** → `FeatureAggregateView(.hygiene)`
3. **健康** → `FeatureAggregateView(.health)`
4. **体重** → `FeatureAggregateView(.weight)`
5. **花费** → `FeatureAggregateView(.expense)`
6. **更多** → `FunctionMenuSheet` 所有功能入口

`OHANA 成员` 已移到首页顶部成员胶囊；`植物` 和 `绿洲奖励` 不再出现在首页 FAB 集合中：植物走成员/植物相关入口，绿洲走顶部椰子数入口；`日历` 保留为顶部独立胶囊。

从 FAB 点击上述功能时，`FunctionMenuSheet(initialDestination:)` 会把对应 `FeatureAggregateView` 作为 sheet 根页面；右上角显示 **关闭**，点击直接 dismiss，不返回“所有功能”列表。

二级集合页采用分段详情页：
- 顶部横向 segment 只展示当前集合内的子功能。
- 内容区域是 `TabView(.page)`，支持左右滑动切换子功能。
- 子功能内容复用原有聚合/详情能力：`FeatureAggregateView(feature:, showsNavigationChrome:false)`、`CareLedgerAnalysisView`、`ReminderObservabilityView`、`BountyBoardView`、`FamilyWeeklyReportDashboardView` 等。

宠物 / 人类卡点选态时，展开后改为当前实体相关子菜单：

1. **全部功能**
   - 宠物：`PetAllFeaturesSheet` / 当前宠物全部功能
   - 人类：`HumanAllFeaturesSheet` 风格的人类功能列表（体重、用药、健康、活动、花费、椰子资产）
2. **顶部日历胶囊**
   - 宠物展开态：`CalendarView(preselectedPetId: card.id.uuidString)`，自动筛选当前宠物相关日程
   - 人类 / 未展开态：打开全局 `CalendarView`

细节：
- 展开时有 `Color.black.opacity(0.25)` scrim，点击 scrim 收回。
- 子项 stagger 动画：展开 55ms × 反向 idx，收起 40ms × idx。

### 空状态 — `EmptyStateWelcomeCard.swift`

`pets.allSatisfy { $0.hasPassedAway } && humans.isEmpty && !showDummyCards` 时渲染，替代卡片堆。按钮：
- 添加宠物 → `showingAddEntity = true`
- 添加家人 → `showingAddEntity = true`

### 长按 contextMenu — `cardContextMenu(card:)`

真实宠物卡长按弹出：
- 喂食 `<name>`（写入 `.feeding` PetCareLog）
- 换水（写入 `.waterChange` PetCareLog）
- 便便记录（写入 `.perfectPoop` PetPottyLog）
- 查看详情 → `selectedPet = pet`

### Bloom 展开层（遗留 dummy / demo 路径）

`expandedLayer(card:geo:outerCornerRadius:windowSize:)` 仍保留，用于 `expandedId` 的旧 bloom 展开路径：
- 全屏放大 `RoundedRectangle(cornerRadius: outerCornerRadius)`
- Hero 卡占顶部区域，`matchedGeometryEffect` 双 ID（Shell + Art）同步过渡
- Footer 140ms 后淡入（`detailFooterVisible`）
- 左上角向下 chevron 关闭；垂直下滑 > 80pt 关闭
- `expandedId` 进入时 `stackLayer` 透明并禁用 hit testing

### 导航架构（两条路径）

**Path 1 — 首页 FAB → 分类分段详情 → 单宠物**

```
FAB 分类项
  └── FunctionMenuSheet(initialDestination: .featureGroup(...))
        └── FeatureGroupDashboardView（sheet 根页面，右上角“关闭”直接 dismiss）
              ├── 顶部 segment：当前集合子功能
              └── 横向分页：FeatureAggregateView / 家庭协作 / 账本分析 / 提醒健康
```

- `FunctionMenuSheet.swift` —— `FeatureGroup` / `FMDest` / `PetFeature` 路由定义；非直达时仍可显示“所有功能”的分类列表。
- `FeatureGroupDashboardView.swift` —— 二级分类分段页；每个集合只展示自己的子功能，避免混入植物/绿洲/其它无关布局。
- `FeatureAggregateView.swift` —— `.weight` 走 `IslandWeightDashboard`，`.expense` 走 `IslandExpenseDashboard`，`.walks` 走 `IslandExplorationDashboard`，其它走单宠物汇总列表；支持 `showsNavigationChrome:false` 被分段页嵌入。

**Path 2 — 宠物详情 → 单宠物全部功能**

```
PetDetailView
  └── [全部] 胶囊 → PetAllFeaturesSheet（sheet, large，独立 NavigationStack）
        └── 功能行 → 单宠物视图（直接，不经聚合）
```

`FMDest.featureAggregate` / `.humanWeight` / `.humanExpense` 在 `PetAllFeaturesSheet` 场景下是死路径：switch 分支走 `assertionFailure`（debug 崩溃，release `EmptyView` fallback）。

**共享类型**（均在 `FunctionMenuSheet.swift`）：
- `FeatureGroup` 枚举：dailyCare / healthBody / archiveMemory / financeLedger / familyCollab / oasisRewards / plants（当前 GO 首页 FAB 只暴露前 4 个；familyCollab 多人时暴露；oasisRewards / plants 保留为内部兼容，不作为首页 FAB 集合）
- `FMDest` 枚举：`.featureGroup(FeatureGroup)` / `.featureAggregate(PetFeature)` / `.petHealth` / `.petMedications` / `.petFood` / `.petHygiene` / `.petWalks` / `.petPotty` / `.petBasicInfo` / `.petDocuments` / `.petMoments` / `.petAchievements` / `.petRetention` / `.petWeight` / `.petExpense` / `.familyWeeklyReport` / `.careLedgerAnalysis` / `.reminderObservability`
- `PetFeature` 枚举：health / medications / food / hygiene / walks / potty / retention / basicInfo / documents / moments / achievements / weight / expense
- `FMPetAvatar` —— 共享小型宠物头像 chip

---

### 宠物详情页（PetDetailView，GO UI 版）

Zoom 目标页。背景 = 宠物主题渐变（与卡片正面无缝转场）。

**同心圆角布局**：
- `bgCardRadius = 32`（背景卡，仅顶部圆角，底部延伸至屏幕边缘）
- `innerMargin = 12`
- `petCardRadius = bgCardRadius − innerMargin = 20`（宠物卡，对齐 Dynamic Island 安全区）

**内容**（有意简化，去掉仪表盘）：
1. 宠物卡（`WalletPetCardFront`）—— 点击 → `PetBasicInfoDetailView`
2. 名字 + 物种（居中）+ `全部` 胶囊（尾随）→ `PetAllFeaturesSheet`
3. 快捷操作网格（4 列，按物种过滤，**可编辑**）

**快捷操作编辑态**（与 `GoDashboardView` 共用机制）：
- 共享持久化：`@AppStorage("quickActionItems_v2")`（JSON `[QuickActionItem]`）
- 切换：`快捷操作` 标题栏的铅笔 ↔ 对勾按钮
- 抖动：`rotationEffect(±2.5°) .easeInOut.repeatForever`，按 `idx % 4 * 0.015` 错峰
- 拖动重排：`QADropDelegate`（源自 OverviewView）
- 删除：`.topLeading` 的减号圆
- 新增：`+` 格 → `QAQuickAddPopoverContent`（复用 GoDashboard popover）
- 退出编辑：将编辑过的项合并回完整存储数组，保留其它宠物/家人的项

**安全区**：`(UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.top ?? 44` —— 不用 GeometryReader（`.ignoresSafeArea(.all)` 下返回 0）。

---

### 财富 dashboard（IslandWealthDashboard2）

入口：GO 首页 header 的 `CoconutBalanceCapsule` 点击先进入 `OasisRewardView`；绿洲页内椰子资产入口再打开 `IslandWealthDashboardView`。

**布局**（2026-04-24 从 ZStack 两区重构为整页可滚动）：
```
  navBar（顶部 overlay，不随滚动）
  timePicker（日/周/月/全部 —— WealthTimeRange）
  incomeVsSpendingRow（两格：本期收入 / 本期花费）
  chartSection（收入按实体堆叠柱 + 花费单色红柱叠加）
  leaderboardSection（按 coconutBalance 降序，无高度限制）
```

**ViewModel 关键属性**（`IslandWealthViewModel2.swift`）：
- `totalAssets` = `QuestManager.shared.coconutCount`（唯一真相源）
- `leaderboard` —— 直接读 `pet.coconutBalance` / `human.coconutBalance`（不是从 log 聚合）
- `filteredByTimeRange` / `filteredIncome` / `filteredSpending` —— 按符号拆分
- `chartBars` —— 收入，按 actor（宠物/家人/system）分桶堆叠
- `spendingBars` —— 花费，单"花费"系列，按时间分桶
- `periodIncome` / `periodSpending` —— 汇总格数字
- `chartEntityNames` / `chartEntityColors` —— `.chartForegroundStyleScale(domain:range:)` 成对；`petColorMap` 由 View 注入

**分桶粒度**：`.day → .hour`，`.week / .month → .day`，`.all → .month`。

**空状态**：`periodSpending == 0` 时右格显示"本期无花费"灰字；无收入时图表空态。

### 椰子商店与百宝箱

入口：`OasisRewardView`、`DailyStreakDetailView`、打卡补签包入口、`FunctionMenuSheet` 均可打开 `CoconutShopView`；已购外观/称号/App Icon 在 `InventoryView` 管理。补签包入口会自动跳到加成道具分类。

- 商店商品统一来自 `ShopCatalog`，避免商店和百宝箱维护两份清单。当前分类为 `App Icon`、`2.5D 头像`、`外观特效`、`称号`、`加成道具`。
- App Icon 采用买断制：默认 Ohana 免费恢复，Lime Night / Clean Blue / Coconut / Paw Duo / Minimal O 预置在 `Assets.xcassets`，通过 `CFBundleAlternateIcons` + `AppIconService` 调用 `UIApplication.setAlternateIconName` 切换。切换失败不扣椰子。
- 永久外观/称号购买后立即生效：青柠光晕、彩虹轨迹、星尘落雨、烟花庆典自动启用；守护者/先行者/首席厨师自动装备为当前称号。
- 商店已购卡片可再次点击切换启用状态或装备称号；3D 破框卡片点击后直接选择宠物并打开 `EquipPopoutCardSheet`。
- 百宝箱同样支持装备/卸下称号、启停外观、绑定 3D 破框卡片。
- 当前消费 key：`purchasedShopItems`、`shop_selected_app_icon`、`shop_equipped_title`、`shop_equip_fx_lime_glow`、`shop_equip_fx_rainbow`、`shop_equip_fx_stars`、`shop_equip_fx_firework`。
- 加成类：`boost_double` 通过 `shop_boostDoubleActive` 在下次椰子奖励中消耗；`boost_streak` 写入 `shop_streakShieldExpiry`；`boost_tree` 注入 `OasisTreeManager.injectedEnergy`；`boost_backdate_pack` 增加 `inventory_backdate_1day_count`；`boost_cooldown_reset` 清空 `quest_cooldownLogs`。
- 椰子记录已合并到 `IslandWealthDashboard2`：财富榜下方展示椰子流水，椰子指南按钮与“我的百宝箱”并列。

---

### GO UI 关键文件清单

| 文件 | 角色 |
|---|---|
| `Views/Home/FocusStackHomeTestView.swift` | GO 首页：Wallet 卡片堆 / Today Focus 一键任务 / 展开态快捷模块 / header / FAB / 空状态 / 显式排序模式 |
| `Views/OnboardingView.swift` | 首次启动引导：App Store 截图式功能介绍 / 人类建档 / 首宠添加选择 |
| `Views/Home/FocusMoodQuestStrip.swift` | 心情 + 任务 TabView pager 白卡 |
| `Views/Home/EmptyStateWelcomeCard.swift` | 冷启动欢迎卡 |
| `Views/Home/FunctionMenuSheet.swift` | 功能分类 sheet + `FeatureGroup` / `FMDest` / `PetFeature` / `FMPetAvatar` |
| `Views/Home/FeatureGroupDashboardView.swift` | 首页 FAB 分类二级页：分段详情 + 左右滑动子功能 |
| `Views/Home/FeatureAggregateView.swift` | 按功能聚合页 + 宠物 chip；可嵌入分类分段页 |
| `Views/Home/PetAllFeaturesSheet.swift` | 单宠物全部功能 sheet（从 PetDetailView） |
| `Views/Details/PetRetentionHubView.swift` | 单宠物长期留存成长档案总览 + 洞察建议 |
| `Views/Details/FamilyWeeklyReportDashboardView.swift` | 全家庭多宠周报、成员贡献排行、分享文本 |
| `Views/Details/CareLedgerAnalysisView.swift` | 统一照护账本分析、事件/成员/时间筛选 |
| `Views/Details/ReminderObservabilityView.swift` | 提醒健康面板、权限/待发/失败/过期诊断 |
| `Views/Details/IslandWealthDashboard2.swift` | 财富 dashboard（可滚动 + 收支分离） |
| `ViewModels/IslandWealthViewModel2.swift` | 财富 VM（`@Observable`，注入 `pets`/`humans`/`petColorMap`） |

---

## 二十三 · C、首次启动引导页（OnboardingView）

`OnboardingView` 负责新用户首次进入的产品介绍、建立人类成员档案，以及可选添加首个宠物。当前版本采用 App Store 截图介绍式卡片，不再在介绍卡底部直接显示“建立我的档案”。

### 流程

```
introFlow（最多 5 张功能介绍卡）
  └── 最后一张点击“继续”
        └── humanOnboardingWizard（AddHumanWizardView）
              └── petChoiceFlow（可选添加第一个宠物 / 先进入首页）
```

### Intro Cards

当前 5 张介绍卡：
1. **首页**：宠物、家人、植物统一管理；Apple Wallet 式卡片堆。
2. **快速记录**：喂食 / 喂水 / 换水 / 铲屎 / 便便 / 逗玩等几秒记录，执行者自动绑定当前手机使用者。
3. **日历提醒**：疫苗、用药、生日、粮仓、护理计划，支持按宠物过滤。
4. **家庭协作**：多人家庭显示协作模块；花费可记录支付者；减少“谁做了/谁付了”的沟通成本。
5. **绿洲奖励**：椰子奖励、连续打卡、绿洲成长。

### UI 细节

- 每张介绍卡包含：功能标签、标题、说明、产品截图式 mock UI、3 条关键价值点。
- mock 截图区域已精简顶部装饰（去掉窗口点/占位条），保证主体内容在 iPhone 竖屏中完整可见。
- 底部主按钮：非最后一张为“下一张”，最后一张为“继续”；进入建档流程后才显示完整的人类成员创建向导。
- “跳过介绍”仍可直接进入建档流程。

---

## 二十四、产品迭代待办（Product Roadmap）

> 由 PM 诊断整理，按优先级执行。**当前焦点：P0 增长/留存 + P0 家庭协作**。

### P0 · 增长 / 留存机制（游戏化服务真实养宠）

目标：让椰子/生命之树/岛屿与现实养宠质量**强耦合**，形成正反馈 + 适度副作用。

- [x] **椰子奖励按质量加成**（2026-04-16 落地）
  - `QuestManager.QualityBonus` 枚举定义 7 种组合（精准 / 备注 / 照片及交叉），倍率 1.0~1.5
  - `compose(precise: hasNote: hasPhoto:)` 智能聚合，`awardAction(quality:)` 统一入参 + 日志标签
  - 接入点：`QuickFeedDetailSheet.commitManualFeed`（克数输入 → `.precise`）、`completeScheduledFeed` 直接 `.precise`、`PetFoodManagementView.quickFeed`（速喂 `.precise`）
  - 椰子日志标题自动拼接质量徽章（"精准 +20%"/"记录 +20%"/"精细带图 +50%"），用户可见加成理由
- [x] **岛屿负反馈系统（适度焦虑）**（2026-04-16 落地)
  - 新增 `IslandMood.cloudy` 阴天态，`IslandMoodWeatherView` 对应粒子 (🌥️/☁️/🌫/💭)
  - `IslandNegativeFeedback.signals(pets:plants:)`：连击断裂、用药晚 22 点未打卡、喂食超 72h、植物超 7 天未浇水
  - 新组件 `IslandNegativeFeedbackBanner`（`Ohana/Views/Components/IslandNegativeFeedbackBanner.swift`）：胶囊横幅 + 多信号翻页 + 当日可关闭 (`AppStorage` 持久)
  - 接入点：`OverviewView` 家庭活动条与紧急警告条之间，优先级低于紧急但高于常规提示
  - 严重度：`.critical`（红）/ `.warning`（黄）双色，自动按严重度排序
- [x] **椰子余额可预期化**（2026-04-16 落地）
  - `CoconutBalanceCapsule` 新增 `onShopTap` / `showPredictionHint` 参数
  - 长按胶囊 → `contextMenu`：椰子明细 / 椰子商店 双入口
  - 胶囊下方显示"距 🍖 再 18🥥"微提示（`CoconutPredictionHelper.nextHint` 自动找到最便宜买不起的商品）
  - 接入点：`OverviewView.globalFixedHeader`，仅在首页 Tab 上显示提示
- [x] **首日承诺（D0 留存钩子）**（2026-04-16 落地）
  - 新文件 `Ohana/Views/Forms/Day0PromiseSheet.swift`：向导保存成功后弹出
  - 承诺菜单按物种差异化（狗 +散步、猫 +梳毛）+ 通用（拍照/陪玩/记录/称重）
  - 勾选 → 自动转成 `BountyTask` 插入 `AppStorage("bountyTasks")`，由当前 activeHuman 作为发布人，任何家人可接
  - 接入点：`AddPetWizardView.savePet()` 替换原 `onComplete` 时机，经 AHA → Day0 → `onComplete`
- [x] **AHA 破壳动画**（2026-04-16 落地）
  - `AddPetWizardView.AhaHatchOverlay`：3 秒分阶段动画（光晕 → 蛋壳震动淡出 → 宠物 emoji 破壳跳出 → 标题"{name} 加入 Ohana"）
  - 8 方向星芒持续旋转、辐射光晕由主题色 → 椰子黄
  - 保存后立即触发，3 秒自动收起 → 推出 Day0 承诺 Sheet
- [x] **新用户 3 分钟成功体验闭环**（2026-04-26 落地）
  - `OnboardingView.finishOnboarding()` 完成后打开首页首次成功卡
  - `FocusStackHomeTestView.firstSuccessCheckInCard` 引导完成第一次“喂食 +🥥”
  - 完成后写入喂食记录、播放椰子奖励动画、隐藏成功卡
- [x] **新用户引导页 App Store 化**（2026-04-27 落地）
  - `OnboardingView.introCards` 扩展为 5 张功能介绍卡：首页 / 快速记录 / 日历提醒 / 家庭协作 / 绿洲奖励
  - 去掉介绍卡底部“建立我的档案”文案；用户看完介绍后点击“继续”进入 `AddHumanWizardView`
  - mock 截图区域精简顶部装饰，提升 iPhone 竖屏可读性
- [x] **长期留存成长档案总览**（2026-04-26 落地）
  - 新增 `PetRetentionHubView`
  - 聚合健康趋势 / 成长相册 / 花费统计 / 保险医疗 / 生命树成就
  - 已接入 `FunctionMenuSheet`、`FeatureAggregateView`、`PetAllFeaturesSheet`
- [x] **成长档案深度化**（2026-04-26 落地）
  - `PetRetentionHubView` 增加健康解释、本月花费预测、今年相册计数、下一成就提示
  - 新增本周建议条：保障风险、近照提醒等长期留存 action
  - 保持复用已有模型，不引入新的 SwiftData 迁移

### P0 · 家庭协作（差异点显性化）

目标：让「这是共养软件」成为用户一眼可见的事实，促成家庭行为。

- [x] **宠物卡下方「今日谁做了什么」活动条**（2026-04-16 落地）
  - 组件 `FamilyActivityStripView`（`Ohana/Views/Components/FamilyActivityStripView.swift`）
  - 数据源：`PetCareLog` / `PetPottyLog` / `PetWalkLog` / `PetExpenseLog` 当日记录
  - 去重规则：同一 `(humanId, 动作类别)` 取最新一条，最多 8 条
  - 每条 chip：家庭成员头像圆 + 右下角动作徽章（SF Symbol + 类型主色），底下 11pt 姓名
  - 空态自动隐藏（当日无记录 → `EmptyView`），避免首页冗余
  - 接入点：`OverviewView.swift` 第二层卡转盘与紧急警告条之间，仅顶牌为宠物时渲染
- [x] **打卡 Sheet 默认执行人 + 一键切换**（2026-04-16 落地）
  - 共用组件 `ExecutorPickerBar`（`Ohana/Views/Components/ExecutorPickerBar.swift`）
  - 胶囊：`.ultraThinMaterial` + 主题色描边 + 头像 + 姓名 + 上下箭头，点击弹 `Menu` 切换家庭成员
  - 读写 `@AppStorage("currentActiveHumanId")`，切换立即生效并持久化
  - Menu 末尾支持「不指定执行人」（清空 activeHumanId）
  - 已接入：QuickFeedDetailSheet / QuickWaterDetailSheet / QuickWaterChangeDetailSheet / QuickPottyDetailSheet / QuickPottySheet / QuickLitterDetailSheet / QuickPlayDetailSheet / OverviewQuickActions（喂食/喂水快捷 Popover）
  - AddExpenseSheet 已有自建支付人选择器，保持原状（已读取同一个 `currentActiveHumanId` 作为默认）
- [x] **家庭周报**（悬赏榜升级）（2026-04-16 落地）
  - `BountyBoardView` 新增第 3 个 Tab「周报」：柱图展示本周每位家人的打卡次数（🍖 喂食 / 🦮 遛 / 💩 厕所 / 💰 花费）
  - `HumanWeekStat` 聚合周起点到今日的所有 `careLogs/pottyLogs/walkLogs/expenseLogs`
  - 周报头部：本周总打卡 + 「本周最勤快」徽章
  - 新服务 `FamilyWeeklyReportService`（`Ohana/Models/FamilyWeeklyReportService.swift`）：周日 20:00 `UNCalendarNotificationTrigger` 本地推送「📊 本周 Ohana 家庭周报」，OhanaApp.init 注册幂等调度
- [x] **多人打卡温馨卡**（2026-04-16 落地）
  - `MemoryEngine.detectMultiPersonDay`：扫描当日 4 种日志，若 `executorId` 去重数 ≥ 2，优先生成「全家都在爱 {petName}」碎片
  - 在 `MemoryEngine.pickFragment` 最前置，压过其他候选，确保家庭协作优先可见
  - 涉及文件：`Ohana/Views/Components/MemoryDropCard.swift`
- [x] **家庭悬赏榜 → 任务指派**（2026-04-16 落地）
  - `BountyTask` 新增 `assignedToId/Name/Emoji` 三可选字段（向前兼容老数据解码）
  - `AddBountyTaskSheet` 插入「指派给」横向滚动选择器：所有人可接 / 每位家人
  - `BountyBoardView.taskCard` 显示 `@Name` 徽章，指派给当前用户时高亮；完成权限：无指派→非创建者均可，有指派→仅被指派者
  - `OasisRewardView.bountyAssignedBadge`：首页「家庭悬赏榜」右上角红圆点显示 `@我 X 个待完成`
  - 辅助方法 `BountyTask.loadAll()` / `pendingAssignedCount(for:)`
- [x] **日历任务指派 + 首页协作卡**（2026-04-26 落地）
  - `AddEventView` 新增 `AssigneePickerRow`，保存时写入 `Event.assigneeId`
  - `FocusStackHomeTestView.familyCollaborationCard` 曾用于 GO 首页家庭协作摘要；2026-05-07 后首页折叠态不再展示，家庭协作改走 FAB / 周报 / 详情页
  - 已指派、今日内的 pending reminders 展示负责人 `AssigneeChip`
  - `NudgeButton` 提供本地催办反馈；周报入口打开 `FamilyWeeklyReportDashboardView`
- [x] **家庭周报系统化升级**（2026-04-26 落地）
  - 新增 `FamilyWeeklyReportDashboardView`
  - 全家庭多宠总览、成员贡献排行、宠物照护覆盖、最近动态、近 4 周趋势
  - 支持 `ShareLink` 分享轻量文本周报
- [x] **统一账本分析页**（2026-04-26 落地）
  - 新增 `CareLedgerAnalysisView`
  - 按本周 / 本月 / 全部、事件类型筛选 `CareLedgerEvent`
  - 展示事件分布、成员排行、最近流水
- [x] **提醒系统可观测面板**（2026-04-26 落地）
  - 新增 `ReminderObservabilityView`
  - 展示通知权限、系统待发数量、App 内 pending / overdue / failed / completed 统计
  - 汇总提醒调度账本，并列出高风险提醒
- [x] **GO 首页家庭协作显示条件与执行人/支付者绑定**（2026-04-27 落地）
  - 家庭协作模块仅在人类成员数 > 1 时显示；2026-05-07 起不再塞入首页折叠态
  - 快速打卡、体重、护理、健康等记录默认绑定当前手机使用者为执行人
  - 添加花费新增“支付者”选项，花费详情页显示支付者/保险到账来源
- [x] **GO 首页 FAB 稳定化与宠物日历筛选**（2026-04-27 落地）
  - `homeFabOverlay(activeCard:)` 常驻右下角；卡片点选态只切换子菜单，不卸载主 FAB
  - 宠物卡展开时 FAB → 日历 自动传入当前宠物 id，`CalendarView` 只显示该宠物相关日程
- [x] **GO 首页 FAB 分类直达与分段详情页**（2026-04-27 落地）
  - 默认 FAB 只保留照护相关集合：日常照护 / 健康身体 / 档案记忆 / 花费账本；多人家庭额外显示家庭协作
  - 植物、绿洲奖励、日历不再作为 FAB 集合项；绿洲走顶部椰子入口，日历走顶部日历胶囊
  - 从 FAB 直达分类页时，右上角“关闭”直接 dismiss sheet，不返回“所有功能”
  - 分类二级页采用 segment + 横向分页切换子功能，且每个集合只展示自己的子功能
- [x] **GO 首页 7 张卡片、成员入口与展开态筛选**（2026-05-05 落地）
  - 首页卡片堆上限为 7 张；“首页显示”开关移到宠物/人类卡片展开页，满 7 张时阻止继续添加并提示用户先隐藏一张
  - OHANA 成员入口移到首页顶部成员胶囊；点击成员卡统一进入 GO 首页卡片展开逻辑，旧宠物专页删除
  - 首页顶部日历胶囊在宠物卡展开时自动筛选当前宠物日程，未展开或人类卡时显示全局日历
- [x] **Today Focus 横向任务与快捷项联动**（2026-05-05 落地）
  - Today Focus 多任务横向分页，按钮文案为“去完成 / 已完成”，完成后卡片划走
  - 已遛狗自动视作今日陪玩完成，减少重复陪玩任务；无任务时显示庆祝提示
  - 展开卡 FAB 按当前快捷模块反向生成未显示项目 + “全部功能”，快捷模块编辑后同步更新
- [x] **GO 首页密度与自定义颜色体验微调**（2026-05-07 落地）
  - Today Focus 在折叠态首页继续上移 10pt，当前整体 offset 为 -20pt
  - 首页卡片堆露出间隔调整为原来的 90%，底部位置保持不变，因此卡片堆顶端随总高度下移
  - 毛色 / 瞳色 / 主题色的“自定义”入口改为直接打开带确认按钮的 GO 色块矩阵，不再二次点击系统圆形 ColorPicker
  - 首页卡片头像缓存首屏同步下采样，启动稳定期短暂禁用排序手势，避免首屏头像延迟和首次点击被排序手势吞掉
- [x] **GO Focus 主路径、状态文案与动画层级统一**（2026-05-07 落地）
  - 普通用户首页固定为 GO Focus；经典 `OverviewView` 仅保留 `debugEnableClassicHome` 内部兼容入口
  - 设置页移除经典 / GO 双卡切换，改为 GO Focus 当前状态卡
  - 添加宠物与裁剪页减少教程式长文案，改成“可用 / 未检测到图片 / 卡片取景”等短状态
  - 新增 `GoMotion`：页面转场、卡片 hero、FAB、轻反馈统一动画 token，首页卡片、Today Focus、颜色选择与设置卡片开始复用
- [x] **首页核心工作台、性能诊断与头像链路稳定化**（2026-05-07 落地）
  - 首页折叠态只保留 Today Focus 一键任务与首成功引导，家庭协作摘要不再塞进首页；家庭协作走 FAB / 详情页
  - 设置页开发者工具新增“性能诊断面板”，记录 App init、启动到首页首帧、首页头像解码、卡片点击延迟、粘贴/相册/拍照到裁剪页耗时
  - 添加宠物、添加人类、基础信息页头像来源统一先做轻量预处理：限制到 1600px、修正方向、保留透明 PNG，再进入裁剪页
  - 首页卡片排序改为显式模式：普通状态点击永远优先展开；长按只进入排序状态，进入后再拖动排序
- [x] **物种护理计划、异常趋势与就诊卡片**（2026-05-07 落地）
  - 添加宠物后按物种/品种自动写入默认护理计划 Event；Today Focus 从今天到期的计划中生成可一键完成任务
  - Today Focus 优先展示异常趋势与医疗风险，再展示普通护理任务
  - 护理任务显示上次执行人和时间，降低家庭重复照顾概率
  - 宠物基础信息页新增就诊卡片和给兽医分享摘要
- [x] **喂食管理页 Go Focus Refine**（2026-05-08 落地）
  - `QuickFeedDetailSheet` 改为顶部 4 标签：今日 / 计划 / 粮仓 / 历史，默认进入“今日”
  - `FeedTodayState` 统一计算今日计划、手动记录、完成进度、下一餐、今日克数；喂食页与 GO 首页共用
  - 首页喂食快捷操作：有待完成/failed 计划时优先完成最早计划，否则写入手动喂食
  - 粮仓页先展示品牌、剩余天数/断粮日、提醒状态；补粮/开包继续写 `PetFoodRecord`，有价格时写 `PetExpenseLog(category: .food)`
  - 历史页展示今日记录、近 7 天柱状图、最近 15 条，并用 badge 区分手动/计划记录
- [x] **护理计划与护理详情统一**（2026-05-05 落地）
  - 护理计划支持全天日程 / 指定时间；非全天时写入用户选择的 time
  - 护理周期只在设置计划页通过天数加减维护，保存后同步 `Event.recurrenceDays` 与 `hygiene_cycle_*`
  - 护理页 overview 改为今日进度 + 连续打卡 strike，移除独立“调整周期”按钮

### 当前未完成 TODO（按最新状态补充）

- [ ] **家庭协作云同步 / 多设备一致性**
  - 当前家庭协作仍是本地优先；真正多人家庭共享需要 CloudKit / iCloud 共享或自建同步方案
  - 需要设计冲突处理、成员身份、离线写入合并与设备间提醒归属
- [ ] **跨设备 nudges**
  - 当前 `NudgeButton` 是本地反馈与 alert；尚未发送给对方设备
  - 后续应接入本地家庭成员通知、CloudKit push 或共享提醒队列
- [ ] **角色权限模型**
  - `PrivacyService` 已集中隐私判断，但还没有完整角色体系
  - TODO：本人 / 管理员 / 普通成员 / 访客，覆盖体重、用药、花费、医疗记录等敏感数据
- [ ] **家庭周报历史归档 / 海报化分享**
  - 当前已有全家庭多宠周报与文本分享；尚未持久化每周快照
  - TODO：周报历史列表、海报图片导出、跨设备共享
- [ ] **账本更正与差异审计**
  - 当前 `CareLedgerAnalysisView` 是只读分析页
  - TODO：撤销/更正入口、账本与旧模型差异审计、异常流水修复建议
- [ ] **成长档案年度回顾**
  - 当前已完成成长档案洞察深化
  - TODO：相册标签、年度回顾、保险推荐对比、成就与生命树联动视觉化
- [ ] **提醒失败重试闭环**
  - 当前已有提醒健康面板、去重、补偿、调度结果写账本
  - TODO：失败通知一键重试、权限异常引导、重新授权后的自动补注册

---

### P1 · 专业深度（宠物行业信任感）

- [ ] **疫苗对照表 & 一键批量添加**
  - 按物种 × 年龄推荐标准方案（幼犬 6/9/12 周 DHPP + 狂犬等）
  - `AddHealthRecordSheet` 新增「按标准方案一键生成」入口
- [ ] **粮量计算器**
  - 输入：物种/体重/活动量/是否绝育 → 输出推荐 g/天
  - 嵌入 `PetFoodManagementView` 顶部卡
- [ ] **换粮过渡计划**
  - 选择新粮 → 自动生成 7/14 天梯度换粮日历 `Event`
- [ ] **症状百科 + 就医阈值提示**
  - `SymptomLog` 选择症状时展开「出现以下情况立即就医」短指引
  - 建立 `SymptomKnowledgeBase.swift` 静态库
- [ ] **BCS 5/9 分对照图**
  - `WeightHistoryView` / 体重录入 Sheet 增加可视化对照
- [ ] **驱虫季节性预警**
  - 雨季/出游期自动发提醒推送（复用 `MedicationReminderService`）

### P1 · 信息架构精简

- [ ] **入口审计表**：汇总所有 sheet 可达路径，每个目标保留 1 主入口 + ≤ 1 浅入口
- [ ] **快捷操作网格上限 6 个**，超过强制进入编辑模式
- [ ] **卡背面降到 8 格**（合并花费/体重到仪表盘钻取）
- [ ] **首页默认只开 2 个 section**（快捷操作 + 一键打卡），其余引导发现
- [ ] **情绪化头图**
  - 宠物生日当天卡片飘金粉
  - 到家纪念日加横幅
  - 涉及文件：`WalletPetCardFront.swift`

### P2 · 数据安全与云

- [ ] **iCloud Drive 自动备份**（无账号即可启用，零成本落地）
- [ ] **UserDefaults → SwiftData 迁移**
  - 用药今日进度（`med_doses_*`）
  - 清洁护理自定义周期（`hygiene_cycle_*`）
  - 打卡连击（`oasis_checkedIn_dates`）
  - 防抖记录（`AntiRepeatCareManager`）
- [ ] **数据导出版本号校验**：`DataBackupManager` 写入 Schema 版本，导入时兼容处理

### P2 · 商业化预埋

- [ ] **PDF 兽医病历导出**：前 3 次免费，后续订阅触发点
- [ ] **保险推荐静态对比**：`PetInsuranceView` 新增「找一家适合 TA 的保险」入口（静态表，未来接联盟 API）
- [ ] **椰子商城**：打通椰子 → 实物优惠券（粮/用品/体检）

### P3 · 细节体验

- [ ] **毛色照片自动取色**：上传照片 → 采样主色写入 `coatColor`
- [ ] **性格标签精简到 20 个 + 自定义**
- [ ] **头像裁剪 30s 说明动图**：首次进入 Step 2 时展示「为什么要抠图」
- [ ] **暗色模式全页回归**：全局截图比对一遍
