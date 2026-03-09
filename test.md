# Ohana App Bug 追踪

> 最后更新: 2026-03-03

## 已修复 Bug（Phase 11）

### UI 交互类

| ID | 描述 | 根因 | 修复方案 | 文件 |
|----|------|------|----------|------|
| C1 | 毛色/瞳色自定义颜色器点击无反应 | `ColorPicker` 以 `opacity(0.015)` 覆盖，系统触摸事件无法传递 | 改为 `Button` 触发 `.sheet` 展示 `GoColorPickerSheet`，内置系统 `ColorPicker` 全交互 | `AddPetWizardView.swift` |
| C2 | 头像裁剪区域与实际显示不一致 | `performCrop()` 错误使用 `UIScreen.main.bounds.size` 作为图片坐标系基准，忽略 `scaledToFill` 的 fillScale | 重写为：`fillScale = max(screenW/imgW, screenH/imgH)`，再乘以用户缩放系数转回原始像素坐标 | `AddPetWizardView.swift` |

### 动画类

| ID | 描述 | 根因 | 修复方案 | 文件 |
|----|------|------|----------|------|
| C3 | 卡片滑出后不回到底部，循环中断 | `withAnimation` 在数据 mutate 时机不对，导致新顶牌位移跳变可见 | 飞出 spring(0.28/0.75)→0.22s后`withAnimation(.none)`瞬间完成数据洗牌→0.3s后解锁 isBusy | `CritterDeckCarousel.swift` |

### 编译错误（已修复）

| 错误 | 原因 | 修复 | 文件 |
|------|------|------|------|
| `Reminder has no member 'title'` | `Reminder` 模型无 `title` 字段，需通过 `event?.title` 获取 | 改为 `topReminder.event?.title ?? "今日提醒"` | `SmartTodayCard.swift` |
| `cannot convert String to ExpenseCategory` | `PetExpenseLog.init` 的 `category` 参数类型为枚举而非 String | 改为传 `newCategory`（枚举值）而非 `.rawValue` | `ExpenseHistoryView.swift` |

## 已修复 Bug（Phase 12）

### UI 交互类

| ID | 描述 | 根因 | 修复方案 | 文件 |
|----|------|------|----------|------|
| R1 | 头像裁剪 zoom out — 裁剪结果范围偏大/偏移 | `performCrop()` 使用 `UIScreen.main.bounds.size` 而非 GeometryReader 实际容器尺寸，导致 safe area 差异使坐标偏移 | 新增 `@State containerSize`，在 `.onAppear` / `.onChange(of: geo.size)` 记录真实容器尺寸，`performCrop()` 改用 `containerSize` 为基准 | `AddPetWizardView.swift` |
| R5 | 打卡格长按无响应 | `Button` 阻断了 `onLongPressGesture` 事件链 | 将每格改为独立 `View`，用 `.onTapGesture` + `.onLongPressGesture` 组合替换 `Button` | `ArkCrewIDCardView.swift` |
| R9 | 日历未默认列表，事件行无滑动操作 | `viewMode` 初始值为 `.month`；事件行无手势实现 | `viewMode` 初始值改为 `.list`；新建 `SwipeableEventRow`（DragGesture 左滑完成/右滑删除）；删除弹窗支持"删除此条"和"删除系列" | `CalendarView.swift`、`SwipeableEventRow.swift` |

### 颜色对比度类

| ID | 描述 | 根因 | 修复方案 | 文件 |
|----|------|------|----------|------|
| R6 | SmartTodayCard 深色背景（goCardCyan）下仍用 arkInk（深色）文字导致不可见 | 文字颜色硬编码为 `Color.arkInk`，不区分背景亮暗 | 新增 `textColor` 计算属性：`goLime`/`goYellow` 背景→`arkInk`，其余→白色 | `SmartTodayCard.swift` |

### 白色背景 Sheet 类

| ID | 描述 | 修复方案 | 文件 |
|----|------|----------|------|
| R7 | 体重添加 sheet 黑底白字，不符合截图风格 | 重写为白底+深色文字+`systemGray6` 输入框+`goTeal` 按钮；`presentationDragIndicator(.hidden)` | `WeightHistoryView.swift` |
| R7 | 花费添加 sheet 黑底白字，不符合截图风格 | 重写为白底+深色文字+`systemGray6` 输入框+`goYellow` 按钮；分类 chip 用 `systemGray5`/`goYellow` 选中 | `ExpenseHistoryView.swift` |

## 已修复 Bug（Phase 13）

### 编译错误（已修复）

| 错误 | 原因 | 修复 | 文件 |
|------|------|------|------|
| `cannot find 'CapsuleTag' in scope` (x3) | 组件定义缺失 | 用内联 `.background(in: Capsule())` 替代 | `PlantDetailView.swift`, `HumanDetailView.swift`, `AddHumanWizardView.swift` |

### UI/UX 修复

| ID | 描述 | 修复方案 | 文件 |
|----|------|----------|------|
| T1 | Flashcard 动画：划走的牌直接消失而非绕弧线插回 | 两段动画：第一段顶牌弧线飞出+旋转+渐隐，第二段重排数组后新牌从底部弹入 | `CritterDeckCarousel.swift` |
| T2 | Island Stats 卡片有边框 | 移除 `strokeBorder`，卡片间改用虚线 `Path` 分割 | `IslandStatComponents.swift`, `OverviewView.swift` |
| T3 | Quick Access 点击直接跳宠物，未先选宠物 | 多宠物时弹 `PetPickerSheet` 先选，单宠物直接跳 | `OverviewView.swift`, `PetPickerSheet.swift`(新建) |
| T4 | 日历左/右滑无渐显文字效果 | 重写 `SwipeableEventRow`：滑动时背景色+图标+文字根据 `progress` 渐变，超阈值触发操作 | `SwipeableEventRow.swift` |
| T6 | 主题色预览黑色 | `PetThemeColor.rawValue` 是英文名非 hex；添加 `hexValue` 属性，选择器改用 `tc.hexValue` | `Pet.swift`, `AddPetWizardView.swift` |
| T8 | 体重历史记录行深色背景 | 改为白色卡片背景 + 黑色文字 + `systemGray6` 行背景 | `WeightHistoryView.swift` |
| T9 | 花费历史记录行深色背景 | 改为白色卡片背景 + 黑色文字 + `systemGray6` 行背景 | `ExpenseHistoryView.swift` |
| T10 | 长按打卡格弹出黑色空弹窗 | `.sheet(isPresented:)+if let` 竞态导致内容为空；改用 `.sheet(item:)` 配合 `IdentifiableAction` | `ArkCrewIDCardView.swift` |

## 已修复 Bug（Phase 14）

### UI/UX 修复

| ID | 描述 | 修复方案 | 文件 |
|----|------|----------|------|
| N1 | Quick Action 无法自定义宠物+功能组合 | `QuickActionItem` 加 `actionType+Codable`，`@AppStorage` JSON 持久化；新建 `AddQuickActionSheet` 两步 wizard（选宠物→选功能）；`GoQuickActionCard` 长按 confirmationDialog 删除 | `OverviewView.swift` |
| N2 | 遛狗卡片无地图交互，无详情页 | 新建 `WalkDetailView.swift`：交互式 Map+MapPolyline 路径折线+起终点 Annotation；点击"Apple Maps"跳转步行导航；`WalkTrackingCard` 地图预览添加点击→详情；`WalkSummarySheet` 历史行可点击 | `WalkDetailView.swift`, `WalkTrackingCard.swift`, `WalkSummarySheet.swift` |
| N3 | 日历事项行有两层滑动背景（ZStack+SwipeableEventRow 重叠）| 删除 `goEventRow` 内自实现的 ZStack 左/右滑背景层，直接返回 `SwipeableEventRow` | `CalendarView.swift` |
| N4 | 宠物卡片背景单调（纯色渐变），头像方形死板 | 重写 `cardFrontView`：5层背景（深色打底+斜向3色渐变+右上角光斑椭圆+左下暗角+巨字装饰）；头像改为圆形+外发光 RadialGradient 光晕+边缘细圆圈+右下角物种 emoji 浮标 | `ArkCrewIDCardView.swift` |

## 已修复 Bug（Phase 15）

### 架构隐患修复

| ID | 描述 | 修复方案 | 文件 |
|----|------|----------|------|
| P0-1 | `routeLocationsData` 未用 externalStorage，GPS 坐标 JSON 内联膨胀 SQLite 主文件 | 添加 `@Attribute(.externalStorage)`，与 `mapSnapshotData` 保持一致 | `PetWalkLog.swift` |

### 功能增强（无 Bug，主动优化）

| ID | 描述 | 实现方案 | 文件 |
|----|------|----------|------|
| P1-1 | 成就体系仅有 1 枚徽章 | 新建 `AchievementManager.swift`（7枚成就纯计算）+ `AchievementWallView.swift`（徽章墙）+ `PetDetailView` 成就入口 banner | `AchievementManager.swift`, `AchievementWallView.swift`, `PetDetailView.swift` |
| P1-2 | 打卡完成无爽感反馈（静默完成） | `triggerComplete()` 改为双重触觉（`.heavy` 重击 + `.success` 通知音），并发射 6 个 emoji 粒子飞散动画（`CelebrationParticle`） | `SwipeableEventRow.swift` |
| P1-4 | `IslandMoodWeatherView` 无正向激励状态 | 新增 `.celebrate` 枚举，今日遛狗 ≥5km 或 `daysTogether` 命中里程碑节点（100/365/500/730/1000/1095）时触发金色礼花粒子（🎉🌟✨🎊⭐️💫） | `IslandMoodWeatherView.swift` |

## Phase 34 — 用户反馈 Bug/Feature（2026-03-04）

| ID | 类型 | 描述 | 状态 |
|----|------|------|------|
| U1 | Bug | 宠物卡片区域向上滑无反应（CritterDeckCarousel 手势穿透） | 待修复 |
| U2 | Feature | 今日岛屿委托全完成后缩小卡片，只显示完成字样+椰子壳图标 | 待实现 |
| U3 | Feature | 删除首页顶部"1天 好的开始！"部分 | 待实现 |
| U4 | Feature | 首页右上角显示椰子数量+点击展开2级菜单（添加成员/设置/管理主页） | 待实现 |
| U5 | Feature | 每天第一次打开app弹出椰子收集卡片，椰子飞到右上角 | 待实现 |
| U7 | Bug | 全局椰子数量不联动（添加宠物+50但绿洲显示12） | 待修复 |
| U8 | Feature | 把首页椰子任务栏移到绿洲页面 | 待实现 |
| U9 | Bug/Feature | 记忆碎片不显示奖励宠物信息+允许滑动移出主页 | 待修复 |
| U10 | Feature | 卡片背面调整：猫无巡岛信息+增加余量；长按二级菜单；3秒撤回打卡；喂食+200g动画+余量联动 | 待实现 |
| U11 | Bug | Island Stats 体重只显示一只宠物信息 | 待修复 |
| U12 | Feature | Quick Access 补全所有功能 | 待实现 |
| U13 | Feature | 人类添加体重记录卡片+添加人类时国籍/居住地要有国家城市列表 | 待实现 |
| U14 | Feature | 人类运动卡片+同步Apple Health+结合遛狗数据 | 待实现 |
| U15 | Bug | 疫苗健康卡弹出无添加按钮 | 待修复 |
| U16 | Feature | 护理打卡弹出详情页+按钮放一行+动画反馈+3秒撤回 | 待实现 |
| U17 | Feature | 宠物详情页体重等无背景表格移到免疫健康之上 | 待实现 |
| U18 | Feature | 日常照料卡片弹出详情页（饮食/水/便便详情+添加按钮+3秒撤回） | 待实现 |
| U19 | Bug | 巡岛悬浮窗背面关闭按钮跳到苹果地图而非关闭 | 待修复 |

## 已知问题

暂无未解决的 bug。

## 编译警告

| 警告 | 文件 | 说明 |
|------|------|------|
| Metadata extraction skipped | AppIntents | 尚未添加 AppIntents.framework 依赖，非阻塞 |
| `UIScreen.main` deprecated (iOS 26) | 多处 | fallback 路径，不影响运行时 |

## 测试记录

- 2026-03-01: 首次完整编译通过 (iPhone 17 Pro Simulator, iOS 26.2)
- 2026-03-03: Phase 11 UI/UX 精修全部完成，Build Succeeded
- 2026-03-04: Phase 12 修复完成，Build Succeeded (iPhone 17 Pro Simulator, iOS 26.2)
- 2026-03-04: Phase 13 T1/T2/T3/T4/T6/T8/T9/T10 修复 + CapsuleTag 错误修复，Build Succeeded
- 2026-03-04: Phase 14 N1/N2/N3/N4 完成，Build Succeeded
- 2026-03-04: Phase 15 P0-1/P1-1/P1-2/P1-4 完成，Build Succeeded (iPhone 17 Pro Simulator, iOS 26.2)
- 2026-03-04: Phase 16 架构重构+功能补全，Build Succeeded (iPhone 16 Pro Simulator, SDK iphonesimulator)

## Phase 16 — 架构重构 + 功能补全

### 修复/实现项

| ID | 类型 | 说明 | 文件 |
|----|------|------|------|
| A1 | 架构 | 引入 ArkSchemaV1 + ArkMigrationPlan，VersionedSchema 保护 | SharedModelContainer.swift |
| A1 | 修复 | ArkSchemaV1 初始编译错误（无 .schema 属性），改用 Schema(models) | SharedModelContainer.swift |
| R1 | 重构 | immunityCard → PetImmunityCard.swift 独立文件 | PetImmunityCard.swift |
| R2 | 重构 | hygieneCard → PetHygieneCard.swift 独立文件 | PetHygieneCard.swift |
| R3 | 重构 | healthLogCard → PetHealthLogCard.swift + HealthLogListView | PetHealthLogCard.swift |
| R4 | 重构 | documentsCard → PetDocumentsCard.swift 独立文件 | PetDocumentsCard.swift |
| R5 | 重构 | milestonesCard → PetMilestonesCard.swift 独立文件 | PetMilestonesCard.swift |
| N1 | 新增 | PetDetailView Hero 卡名字旁 info.circle 按钮 → PetBasicInfoDetailView | PetDetailView.swift |
| N2 | 新增 | PetBasicInfoDetailView — 完整宠物信息展示页（基本/外貌/医疗/证件/血统） | PetBasicInfoDetailView.swift |
| N3 | 新增 | PetHealthLogCard「查看全部」按钮 + HealthLogListView（类型 chip 过滤） | PetHealthLogCard.swift |
| N4 | UI | SettingsView Go UI 化（goTranslucentCard/goLime 图标/GoDashedDivider/版本号修正） | SettingsView.swift |
| N5 | 新增 | WalkDetailView 分享按钮（左上角，ImageRenderer 截图 + UIActivityViewController） | WalkDetailView.swift |

---

## Phase 17 — 产品体验深度优化（2026-03-04）

### 修复/实现项

| ID | 类型 | 说明 | 文件 |
|----|------|------|------|
| P17-1 | 新增 | IslandMoodCalculator 补充3条 celebrate 触发：首次遛狗日/到家周年/今日提醒全勤 | IslandMoodWeatherView.swift |
| P17-2 | 新增 | AchievementManager 新增即时型成就：first_record / day_one_checkin / old_friend（共10枚） | AchievementManager.swift |
| P17-3 | 重构 | deleteDangerZone 从 PetDetailView.recordsTabContent 移至 SettingsView「宠物管理」section | PetDetailView.swift / SettingsView.swift |
| P17-4 | 新增 | SitterCardPreviewSheet — 寄养名片（宠物一页纸 + ImageRenderer 截图分享） | SitterCardPreviewSheet.swift |
| P17-5 | 新增 | PetDetailView Toolbar 添加寄养名片入口（rectangle.portrait.on.rectangle.portrait 图标） | PetDetailView.swift |
| P17-6 | UX | OverviewView 空状态升级：岛屿 Emoji 主视觉 + 三步引导卡 + 开始建岛按钮 | OverviewView.swift |
| P17-FIX | 修复 | SettingsView.swift 字符串转义问题（嵌套引号导致 unterminated string literal） | SettingsView.swift |

---

## Phase 18 — WalkTrackingCard 状态合并重构（2026-03-04）

### 根本问题（已修复）

WalkTrackingCard 拥有独立的 7 个本地 @State（walkPhase/elapsedSeconds/poopCount/timer/startTime 等），
与 PetWalkingManager.shared 完全脱节，导致：
1. 计时器重复运行（两套 Timer）
2. WalkTrackingCard.stopWalk() 无路线数据、无地图快照
3. 便便记录只在 Card 里写入，Manager 的 poopCount 永远不同步

### 修复/实现项

| ID | 类型 | 说明 | 文件 |
|----|------|------|------|
| P18-1 | 架构 | PetWalkingManager 引入 pausedElapsed+resumeTime 双变量，修复暂停后计时不准问题 | PetWalkingManager.swift |
| P18-2 | 功能 | PetWalkingManager.stop() 补充便便记录写入（poopCount 次 PetPottyLog） | PetWalkingManager.swift |
| P18-3 | 新增 | PetWalkingManager 新增 showSummary: Bool，stop() 后置 true，Card onChange 弹出 WalkSummarySheet | PetWalkingManager.swift |
| P18-4 | 重构 | WalkTrackingCard 删除全部本地状态/timer/Actions 方法（约 80 行），改为纯 UI 层 | WalkTrackingCard.swift |
| P18-5 | 重构 | WalkTrackingCard 所有按钮操作改为调用 mgr.start/pause/resume/stop/reset/addPoop | WalkTrackingCard.swift |
| P18-6 | 新增 | WalkTrackingCard isActivePet 计算属性（多宠物场景隔离，避免串台） | WalkTrackingCard.swift |

---

## Phase 19 — 游戏化粘性系统（Duolingo-style）（2026-03-04）

### 新增文件

| 文件 | 说明 |
|------|------|
| `Models/IslandProsperityManager.swift` | IslandLevel 枚举（seedling/blooming/paradise）+ 全局 Log 计数算法 |
| `Models/StreakManager.swift` | 连续打卡天数更新逻辑（pottyLog/walkLog/foodRecord 三路触发） |
| `Views/Components/DailyQuestsCard.swift` | 今日岛屿委托卡（IslandQuestEngine + 3任务 + CoconutDropSheet 盲盒） |
| `Views/Components/StreakBadgeView.swift` | 🔥 羁绊值徽章（连续天数 + 火焰脉冲动画） |

### 修复/实现项

| ID | 类型 | 说明 | 文件 |
|----|------|------|------|
| P19-1 | 新增 | WeeklyReportCard 海报化：闪烁 Share 按钮 + ImageRenderer 3x + weeklyPoster 独立视图 | WeeklyReportCard.swift |
| P19-2 | 新增 | IslandProsperityManager：seedling(<50)/blooming(50-199)/paradise(200+) 三级，驱动背景进化 | IslandProsperityManager.swift |
| P19-3 | 升级 | ArkBackgroundView 接受 level 参数，Level2 加繁花光晕，Level3 加极光叠加层 | ArkBackgroundView.swift |
| P19-4 | 新增 | OverviewView Header 繁荣度徽章 + StreakBadgeView | OverviewView.swift |
| P19-5 | 新增 | DailyQuestsCard：遛狗/便便/探访3任务 + 进度条 + 全完成解锁椰子盲盒 | DailyQuestsCard.swift |
| P19-6 | 新增 | PetDetailView.onAppear 写入「探访」任务完成标记（UserDefaults，今日 key） | PetDetailView.swift |
| P19-7 | 新增 | StreakManager：每日打卡检测 + streak 断链归零逻辑；OverviewView.onAppear 全量刷新 | StreakManager.swift |
| **P19-8** | **迁移** | **ArkSchemaV2**：Pet 新增 currentStreak(Int=0) + lastCheckInDate(Date?=nil)，lightweight 迁移 | SharedModelContainer.swift / Pet.swift |
| P19-FIX | 修复 | StreakManager PetFoodRecord 字段名 date → startDate | StreakManager.swift |

---

## Phase 20 — 动森模式养成系统（Animal Crossing style）（2026-03-04）

### 新增文件

| 文件 | 说明 |
|------|------|
| `Models/IslandProsperityEXP.swift` | ProsperitySource(7种) + IslandProsperityEXP 管理器 + IslandEXPBadgeView |
| `Views/Components/MemoryDropCard.swift` | MemoryFragment 模型 + MemoryEngine + MemoryDropCard 视图 |

### 修复/实现项

| ID | 类型 | 说明 | 文件 |
|----|------|------|------|
| P20-1 | 迁移 | **ArkSchemaV3**：Household.totalProsperity(Int=0)，V2→V3 lightweight 迁移 | SharedModelContainer.swift / Household.swift |
| P20-2 | 新增 | IslandProsperityEXP：walk(+5)/milestone(+5)/potty(+3)/hygiene(+3)/health(+3)/watering(+2)/appOpen(+1) | IslandProsperityEXP.swift |
| P20-3 | 新增 | IslandEXPBadgeView：等级 + 动画进度条 + 欧哈纳星光文字 | IslandProsperityEXP.swift |
| P20-4 | 升级 | OverviewView islandLevel 优先读 Household.totalProsperity（降级回 log 计数）| OverviewView.swift |
| P20-5 | 新增 | EXP 挂载点：WalkTrackingCard / PetHygieneCard / PottyOverviewView / PlantDetailView | 各文件 |
| P20-6 | 新增 | MemoryEngine：5类历史回忆（去年遛狗/里程碑/到家周年/健康初诊/植物纪念日），今日固定种子 | MemoryDropCard.swift |
| P20-7 | 新增 | MemoryDropCard：毛玻璃卡片 + 地图截图（有则显示）+ 闪光今日回忆标签 | MemoryDropCard.swift |
| P20-8 | 新增 | IslandMood.plantBreeze：🍃🌿🌱花瓣粒子，今日浇水触发 | IslandMoodWeatherView.swift |
| P20-9 | 升级 | IslandMoodCalculator 新增 plants 参数（默认值[]），植物浇水 → .plantBreeze | IslandMoodWeatherView.swift |
| P20-10 | 接入 | **IslandMoodWeatherView 正式接入 OverviewView**（全局粒子层，allowsHitTesting=false）| OverviewView.swift |
| P20-11 | 新增 | ArkCrewIDCardView 背面 achievementStickerWall（5列 10 枚贴纸，解锁 emoji / 未解锁🔒）| ArkCrewIDCardView.swift |
| P20-FIX | 修复 | MemoryDropCard 引用 HealthLogType.displayName → 改用 rawValue | MemoryDropCard.swift |

## Phase 24 — Bug修复 6项（2026-03-04）

| ID | 类型 | 描述 | 文件 |
|----|------|------|------|
| B1 | 修复 | PetBreedDatabase.breeds(for:) 的 Lookup 方法缺失，补充后「其他」固定排最后（sorted + others） | PetBreedDatabase.swift |
| B2 | 修复 | 管理页 sheet 从 quickActionsSection 内部提升到 OverviewView body 顶层，避免 section 隐藏后 sheet 失效；默认 sectionOrder 改为 petCards 置顶；两处 AppStorage 默认值统一为 petCards,islandStats,todayTasks,quickAccess | OverviewView.swift |
| B3 | 改进 | 日历/图鉴/设置从 .sheet 改为 .navigationDestination(isPresented:) push 进入 | OverviewView.swift |
| B4 | 修复 | 拍照附件退出bug：改用 pendingCapturedImage + onDismiss 延迟写入，避免 sheet 嵌套冲突；支持多附件数组（attachments: [DocAttachment]）；自动预填名称（autoTitle = 宠物名+证件类型）；PhotosPicker 改为 maxSelectionCount: 10 | AddDocumentSheet.swift |
| B5 | 修复 | GlobalWalkBanner 悬浮条 top padding 从 8 改为 12，避免与状态栏重叠 | GlobalWalkBanner.swift |
| B6 | 改进 | CritterDeckCarousel 卡片切换：飞出改 easeIn(0.22s)+旋转35°+弧线，入场改 spring(response:0.38,dampingFraction:0.68) 高弹跳 | CritterDeckCarousel.swift |

## Phase 23 — 岛民图鉴 & 日历时间轴重构（2026-03-04）

| ID | 类型 | 描述 | 文件 |
|----|------|------|------|
| R1 | 重构 | CrewRosterOverlay 升级为「欧哈纳图鉴」Bento Box：顶部毛玻璃搜索栏、IslandMoodWeatherView 背景、宠物正方形卡（头像+微动状态徽章/粮食告急/遛狗中）、人类横向宽卡（头像+角色goLime标签）、植物竖向长卡（需浇水badge）、虚线「迎接新生命」添加按钮 | CrewRosterOverlay.swift |
| R2 | 重构 | CalendarView 列表视图：模式切换改为 SF Symbol 图标胶囊；goListView 加入环境光斑（RadialGradient opacity 0.08-0.18）+ 时间轴纵线（纵向白色虚线贯穿）+ 日期节点圆点（今天=goLime）+ relativeDate 中文相对日期 | CalendarView.swift |
| R2b | 重构 | SwipeableEventRow eventCard 彻底重构：移除绿色竖线和剪贴板图标；40x40 Color Coding Emoji 节点（排泄=goTeal/喂食=goYellow/遛狗=goLime/医疗=goRed/清洁=紫）；分类 Badge；右侧时间 monospacedDigit；冰膜毛玻璃卡（white.opacity 0.07）| SwipeableEventRow.swift |

## Phase 22 — UI/UX 11项改进（2026-03-05）

| ID | 类型 | 描述 | 文件 |
|----|------|------|------|
| T1 | 确认 | 品种列表「其他」已在末尾，无需改动 | PetBreedDatabase.swift |
| T2 | 新增 | Island Stats 多宠物分系列折线图 MultiPetLineChart，每宠物独立颜色，卡片高 160→200 | IslandStatComponents.swift, OverviewView.swift |
| T3 | 新增 | GlobalWalkBanner.swift：全局遛狗悬浮条，ContentView ZStack 顶层叠加 | GlobalWalkBanner.swift, ContentView.swift |
| T4 | 改进 | ArkCrewIDCardView achievementStickerWall：LazyVGrid→单行横向 ScrollView，只显示已解锁 | ArkCrewIDCardView.swift |
| T5 | 新增 | PetDetailView 支持 initialTab 参数；OverviewView 添加 selectedPetTab Binding；ContentView 传递；applyAction 按动作设置对应 Tab | PetDetailView.swift, OverviewView.swift, ContentView.swift |
| T6 | 新增 | AddDocumentSheet：附件（拍照/相册/文件）+ 保险/病历费用字段，保存同步 PetExpenseLog；PetDocument 新增 cost/attachmentData/attachmentFilename；ArkSchemaV6 lightweight migration | AddDocumentSheet.swift, PetDocument.swift, SharedModelContainer.swift |
| T7 | 修复 | CritterDeckCarousel dragGesture：只响应水平拖拽（abs(x)>abs(y)），竖向手势不消费 | CritterDeckCarousel.swift |
| T8 | 改进 | GoQuickActionCard ZStack alignment 改为 .topTrailing，头像移到右上角 | OverviewView.swift |
| T9 | 改进 | Manage 按钮移到 Header 右上角（goLime 胶囊）；mainScrollView 读取 AppStorage home_section_hidden/order 实际控制 section 显示/隐藏和顺序 | OverviewView.swift |
| T10 | 新增 | AddHealthRecordSheet.swift：健康记录添加页含有效期；healthQuickActions 改为 sheet(item:) 弹出；HealthLogType 实现 Identifiable；PetHealthLog 新增 expirationDate；ArkSchemaV5 lightweight migration | AddHealthRecordSheet.swift, PetHealthLog.swift, PetDetailView.swift, SharedModelContainer.swift |
| T11 | 改进 | petHeroCard 改为紧凑横排（头像64+名字+标签+天数/年龄），整体可点击进入 PetBasicInfoView | PetDetailView.swift |

## Phase 30 — Bug 修复 8项（2026-03-04）

| ID | 类型 | 描述 | 根因 | 修复文件 |
|----|------|------|------|----------|
| B1 | 修复 | 最小化气泡拖动卡顿/幻影 | `@State` dragOffset 在 SwiftUI 渲染时产生残影；无合批渲染 | `GlobalWalkBanner.swift`：改用 `@GestureState dragDelta` 自动归零 + `.drawingGroup()` 合批渲染 |
| B2 | 修复 | 遛狗结束先消失再出现翻转卡；关闭按钮无反应 | `mgr.stop()` 后 `isActive→false` 导致 summaryCard 所需的 `pet` 为 nil；关闭按钮嵌套 `withAnimation` 外层 | 新增 `isStopped` State 立即遮盖展开卡不消失；关闭按钮改为直接操作 State；`summaryFlipCard` 重构为纯 VStack + `rotation3DEffect(0→180)` |
| B2+ | 新增 | 地图快照点击无反应 | 原为普通 `Image` 无交互 | 包裹为 `Button { UIApplication.shared.open(URL(string:"maps://")) }` + 右下角「在地图中查看」Capsule 角标 |
| B3 | 优化 | 免疫健康卡过高，点击按钮无法添加记录 | 展开了免疫状态3行列表；按钮仅触发 `onViewPassport` 而非 `onRecord` | 移除免疫状态列表；顶栏改为 HStack（标题+记录数+疫苗本胶囊）；4个快动作按钮点击直接调用 `onRecord(type)` |
| B4 | 优化 | 护理状态卡过高 | 每行含14天 mini chart 增加大量高度 | `HygieneRow` 移除14天 chart，改为紧凑单行（emoji + 名称 + 进度条 + 打卡按钮），padding 收紧 |
| B5 | 优化 | 详情页图表卡有背景边框与首页 Island Stats 风格不一致 | `ChartCard` 使用 `.white.opacity(0.04)` 背景 + accent 边框 | 完整重构 `PetChartDashboard` 为横向 ScrollView，每个卡片无背景无边框，统一高度 190pt，垂直虚线分割 |
| B6 | 修复 | 找不到添加粮食/喂食喂水入口 | `foodChartCard` 的 `quickAdd` 回调只触发 `onFood`，但 `onFood` 绑定到 `showingFoodManagement` sheet；Island Stats 风格后更清晰展示「点击管理粮食」提示 | `foodCardContent` 添加「点击添加余粮信息」提示 Capsule；`PetFoodManagementView` sheet 通过 `onFood` 正确触发 |
| B7 | 新增 | 绿洲椰子按钮无交互 | 原为静态显示胶囊 | 改为 `NavigationLink → CoconutLogView`（新建），含余额大字 + 获取记录列表 |
| B8 | 修复 | 日历添加100天纪念日后首页 SmartTodayCard 无金卡 | 里程碑检测在优先级链第2位，被疫苗逾期挡住；且只检测当天而非未来3天 | `SmartTaskEngine` 新增 Step 0（最高优先级）：今日+未来3天里程碑提醒；扩展关键词（百日/百天/满月/周岁）；`isMilestone()` 提取为静态方法供 Engine 和 Card 共用 |

## Phase 21 — Bug 修复 & 功能增强（2026-03-04）

| ID | 类型 | 描述 | 文件 |
|----|------|------|------|
| P21-BUG-1 | 崩溃修复 | 相机权限缺失导致崩溃：pbxproj Debug+Release 两个 config 加入 NSCameraUsageDescription / NSPhotoLibraryUsageDescription / NSLocationWhenInUseUsageDescription | project.pbxproj |
| P21-BUG-2 | 修复 | 头像裁剪坐标偏移：PetImageCropView.performCrop 先 normalizeImage 将 UIImage orientation→.up，再做 cgImage.cropping，消除相机拍照旋转不一致 | AddPetWizardView.swift |
| P21-BUG-3 | 修复 | 品种选"其他"无反应：改用独立 customBreedText，选中时高亮并 ScrollViewReader.scrollTo("customBreedField")；savePet 用 isCustomBreed ? customBreedText : breed | AddPetWizardView.swift |
| P21-BUG-4 | 修复 | 到家日可早于出生日：DatePicker in: hasBirthday ? birthday...Date() : .distantPast...Date()，birthday 变化时自动修正 homeDate | AddPetWizardView.swift |
| P21-FEAT-5 | 新增 | 宠物家庭关系：ArkSchemaV4（新增 PetRelationship 表，V3→V4 lightweight）+ WizardStep.familyRelation + PetRelationshipType（6种，按性别自动缩小描述）| PetRelationship.swift / AddPetWizardView.swift / SharedModelContainer.swift |
| P21-FEAT-6 | 调整 | 卡片正面：去掉右上角物种 chip，改为"详情→"胶囊按钮（白底深色字）；背面：去掉详情箭头，顶部紧凑，整体 VStack spacing 8→8 | ArkCrewIDCardView.swift |
| P21-FEAT-7 | 新增 | 遛狗卡片联动：卡片背面检测 PetWalkingManager 状态，正在遛该宠物时背景变深绿显示 walkLivePanel（TimelineView 计时器/距离/便便数/暂停继续/结束按钮）| ArkCrewIDCardView.swift |
| P21-FEAT-8 | 增强 | Quick Access 动作路由：walk→直接 mgr.start(pet:)+翻转卡片背面；weight→QuickWeightSheet 小弹窗；health/potty/hygiene→跳宠物详情 | OverviewView.swift / QuickWeightSheet.swift |
| P21-NEW | 新增 | QuickWeightSheet：独立底部弹窗（presentationDetents .height(280)），大字体体重输入，保存后自动关闭 | QuickWeightSheet.swift |

## Phase 34 — U系列 Bug修复 & 功能增强（2026-03-04）

| ID | 类型 | 描述 | 根因/方案 | 修复文件 |
|----|------|------|----------|----------|
| U1 | 修复 | 宠物卡片区域向上滑无反应 | minimumDistance 30 + abs(x)>1.8*abs(y) 水平判定 | CritterDeckCarousel.swift |
| U2 | 功能 | 今日委托全完成后缩小卡片 | collapsedCompletedCard 紧凑卡片 | DailyQuestsCard.swift |
| U3 | 功能 | 删除首页顶部 StreakBadgeView | 移除组件引用 | OverviewView.swift |
| U4 | 功能 | 首页右上角椰子数量 + 展开菜单 | Menu 包裹椰子胶囊，含添加成员/设置/管理 | OverviewView.swift |
| U5 | 功能 | 每天首次打开 app 弹出椰子收集卡 + 飞入动画 | @AppStorage 记录日期，overlay + offset 动画 | OverviewView.swift |
| U7 | 修复 | 全局椰子数量不联动 | OasisRewardView/CoconutLogView 改读 QuestManager.shared.coconutCount | OasisRewardView.swift |
| U8 | 功能 | 首页椰子任务栏移到绿洲页面 | WelcomeQuestBentoView 从首页移至 OasisView | OverviewView.swift, OasisView.swift |
| U9 | 功能 | 记忆碎片：宠物奖励信息 + 滑动移出 | MemoryFragment 新增 rewardCoconuts/petName；DragGesture >120pt 移出 | MemoryDropCard.swift, OverviewView.swift |
| U10 | 功能 | 卡片背面猫种改进 | 猫不显示巡岛改显铲屎次数；食物余量条；打卡 3 秒撤回 toast；喂食 +g 浮现动画 | ArkCrewIDCardView.swift |
| U11 | 修复 | Island Stats 体重只显示一只宠物 | compactMap 所有宠物最新体重，多宠物显示 count·各名字 | OverviewView.swift |
| U12 | 功能 | Quick Access 补全 feed/potty/bath | applyAction 新增直接打卡逻辑 + toast | OverviewView.swift |
| U15 | 确认 | 疫苗健康卡添加按钮 | PetHealthHubCard 快动作按钮已实现，无需修改 | PetDetailView.swift |
| U16 | 功能 | 护理打卡详情页 + 3秒撤回 | Header 点击弹 HygieneDetailSheet；HygieneCheckButton onUndo 回调 | PetHygieneCard.swift |
| U17 | 功能 | 体重图表移到免疫健康之上 | PetChartDashboard 与 PetHealthHubCard 位置互换 | PetDetailView.swift |
| U18 | 功能 | 日常照料详情页 + 添加 + 3秒撤回 | Header 点击弹 CareTrackingDetailSheet；CareTypeRow onUndo 回调 | PetCareTrackingCard.swift |
| U19 | 修复 | 巡岛悬浮窗关闭按钮跳苹果地图 | .clipped() + .contentShape 约束气泡触摸区域 | GlobalWalkBanner.swift |
