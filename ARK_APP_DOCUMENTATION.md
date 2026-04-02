# Ohana (欧哈纳) iOS App 完整技术文档

> 最后更新: 2026-03-28 | Schema: ArkSchemaV22 | Phase 1-79 + 第二十章～第四十七章 | 编译: iPhone 17 Pro Simulator, iOS 26.2

---

## 一、概览

**Ohana（欧哈纳）**是一款家庭宠物综合管理 iOS App。

- **核心理念**："Ohana means family. Nobody gets left behind or forgotten."
- **技术栈**：SwiftUI + SwiftData + Swift Charts, iOS 17+, Swift 6
- **本地优先**：无需账号，数据存储在设备 SwiftData（SQLite + App Group）
- **设计风格**：Ohana Design System (基于 Go UI 进化) — 支持 Light/Dark 模式，Bento Box 布局，现代毛玻璃卡片，热带岛屿养成氛围
- **App Group**：`group.com.guanchen.li.Ark`

### 项目结构

```
Ohana/
├── OhanaApp.swift              # @main 入口
├── ContentView.swift           # NavigationStack 主路由
├── Info.plist
├── Ohana.entitlements
├── Assets.xcassets/
├── Models/                     # 33 个文件（SwiftData 模型 + 管理器）
├── Views/                      # 48 个文件
│   ├── RootView.swift          # Onboarding 判断 → Overview
│   ├── OverviewView.swift      # 首页主视图
│   ├── OnboardingView.swift    # 3 步引导
│   ├── CalendarView.swift      # 日历/列表双视图
│   ├── SettingsView.swift      # 设置页
│   ├── ArkBackgroundView.swift # 多风格动态背景系统（4种可选）
│   ├── OhanaDesignSystem.swift # Go UI 修饰器/组件库
│   ├── Components/             # 25 个可复用组件（新增 ImageCutoutPreviewSheet / GenericWeightEntrySheet）
│   ├── Details/                # 35 个详情/子页面
│   ├── Forms/                  # 7 个表单/向导
│   └── Home/                   # 6 个首页子组件
├── Utilities/                  # 3 个工具文件
│   ├── ColorExtensions.swift   # Go UI 18 色色板 + toHex()
│   ├── ImageCutoutService.swift # iOS 17 Vision 前景抠像单例
│   └── ModelContextExtensions.swift
└── ViewModels/                 # 2 个 ViewModel
    ├── IslandUnifiedStatsViewModel.swift
    └── IslandWealthViewModel2.swift
```

---

## 二、设计系统（Go UI）

### 2.1 颜色色板

定义于 `Utilities/ColorExtensions.swift`，18 色 `Color` 扩展：

| Token | Hex | 用途 |
|-------|-----|------|
| `goPrimary` | #4338FF | 品牌蓝 |
| `goLime` | #C8FF00 | **主强调色**（按钮/选中/进度） |
| `goMint` | #00FFD1 | 薄荷辅助色 |
| `goYellow` | #FFD600 | 警告/里程碑 |
| `goOrange` | #FF8A00 | 逾期/紧急 |
| `goRed` | #FF3B30 | 危险/删除 |
| `goTeal` | #00BFA5 | 宠物标签 |
| `goCardCyan` | #00E5FF | 卡片装饰 |
| `arkInk` | #1A1A2E | 深色文字（亮色背景用） |
| `goDarkBlue` | #0D1B3E | 深色卡片背景 |
| `goDeepNavy` | #060E24 | 最深背景 |

> **规则**：foregroundStyle 中必须写 `Color.goLime` 而非 `.goLime`

### 2.2 字体

- **全局**：SF Pro Rounded（`.rounded` design）
- **大数字**：`.system(size: 48~64, weight: .heavy, design: .rounded)`
- **标题**：`.title2.bold()` 或 `.title3.weight(.semibold)`
- **正文**：`.body` / `.callout`
- **标签**：`.caption` / `.caption2`

### 2.3 圆角规范

| 场景 | 圆角 |
|------|------|
| 全屏卡片 | 32pt |
| 大型毛玻璃卡 | 24pt |
| 标准卡片 | 20pt |
| 小型卡片/胶囊 | 16pt |
| 按钮/Badge | 12pt |
| Chip/Tag | `Capsule()` (Style C - 带圆点) |

### 2.4 核心布局与风格规则

*   **卡片容器**：统一使用 `ohanaStandardCard` (自动适配：Dark 模式下为深蓝渐变 + frosted glass, Light 模式下为纯白 + 阴影)
*   **页面布局**：主要数据流页面（如 Overview, 详情页）采用 **Bento Box (组合方块)** 布局，打破横向堆叠的单调感。
*   **列表布局**：设置页等重列表页面采用 **Floating Groups**，将分组内容置于单一容器内，使用 `OhanaDashedDivider` 分隔。
*   **Quick Access (QA)**：采用 **Glass (毛玻璃)** 紧凑小卡片风格，突出核心指标。
*   **按钮/标签**：统一使用 Style B (无边框 Icon 按钮), Style D (Toast Alert), Style C (圆点标签)。

### 2.5 通用修饰器组件 (`OhanaDesignSystem.swift`)

```swift
.ohanaStandardCard()                   // 核心：自动适配亮暗模式的卡片背景
OhanaIconButton(icon:color:action:)    // 核心：Style B 按钮组件
OhanaAlertBanner(text:icon:style:)     // 核心：Style D 提示横幅
OhanaQACard(item:...)                  // 核心：Glass 风格 QA 卡片
```

*(注意：旧有的 `.goTranslucentCard`, `.goCard`, `.neoWhiteCard` 正在被逐步替换为 `.ohanaStandardCard`)*

### 2.5 通用组件

```swift
FloatingDockNav(selectedTab:onHome:onStats:onCrew:onOasis:)  // 底部悬浮4tab导航（i18n本地化标签）
GoDashedDivider()                   // 虚线分割
OhanaSheetWrapper { }               // 标准 Sheet 容器
CoconutBalanceCapsule(...)          // 椰子余额胶囊按钮
CoconutRewardModifier               // 全局椰子弹跳动效
L10n(appLanguage)                   // 多语言本地化助手（中/英，"ohana"不翻译）
```

### 2.6 Material UI 2.0（第四十五章）

#### 首页吸顶三按钮 (`matStickyHeader`)
`MaterialDashboardView` 在 `homeTab` 的 ZStack 最上层 overlay 一个独立 sticky header，不参与 ScrollView：
- **左**：Settings 灰色圆形按钮（`gear` 图标）
- **中**：添加成员橙色圆形 FAB（`plus` 图标，`showAddEntity = true`）
- **右**：椰子数胶囊（`circle.hexagongrid.fill` + 数字，点击 `showCoconutDetail`）
- 背景：`bg.opacity(0.92) + .ultraThinMaterial`，`.ignoresSafeArea(.top)`
- `GeometryReader` 捕获椰子按钮中心 → `coconutBtnOrigin: CGPoint`（粒子目标点）

#### 日历吸顶三按钮 (`calStickyHeader`)
`CalendarView` 同款 sticky header overlay（`ZStack(alignment: .top)`），与首页完全一致：
- 添加日程（`calendar.badge.plus`）+ 视图切换胶囊（`calendar` / `list.bullet`）+ Spacer + 椰子数药丸
- `onAppear` + `NotificationCenter("coconutCountChanged")` 实时同步椰子数

#### 宠物卡片旋转窗口 (`visibleStackPets`)
```swift
private var visibleStackPets: [(stackPos: Int, pet: Pet)] {
    guard !pets.isEmpty else { return [] }
    return (0..<min(3, pets.count)).map { slot in
        (slot, pets[(activePetIndex + slot) % pets.count])
    }
}
```
- 解决 `prefix(3)` 固定窗口导致第4+只宠物不可见的 bug
- `.onChange(of: pets.count)` 自动跳转至最新宠物（`activePetIndex = newCount - 1`）

#### 卡片展开动画
所有 Bento 卡添加 `matchedGeometryEffect(id: type.rawValue, in: cardExpandNS)`；  
VStack 动画参数改为 `.spring(response: 0.55, dampingFraction: 0.88)` — 更平滑的布局推挤效果。

#### 粒子起点追踪 (`cardOrigins`)
```swift
@State private var cardOrigins: [MatCardType: CGPoint] = [:]
// 每张卡附加：
.onGeometryChange(for: CGPoint.self) { g in
    let f = g.frame(in: .global); return CGPoint(x: f.midX, y: f.midY)
} action: { cardOrigins[.feeding] = $0 }
```
`launchCoconutParticles(from: CGPoint?)` 接受可选起始点；`triggerFeedingAnim/WaterAnim/LitterAnim` 全部传 `cardOrigins[type]`。

#### 分层 Avatar 引擎 (`LayeredAvatarView.swift`)
```swift
LayeredAvatarView(imageData: Data?, petName: String, species: String,
                  furHex: Binding<String>, eyeHex: Binding<String>,
                  allowCustomize: Bool = true)
```
- **有头像**：点击上 1/3 弹眼色选择器，点击下 2/3 弹毛色选择器
- **无头像**：`PetSilhouetteIcon`（系统符号 dog/cat/hare/bird/pawprint）+ `RadialGradient` 毛色圆底 + 双瞳眼睛层（含瞳孔+高光圆点）
- `ColorPickerPopup`：`.presentationDetents([.height(340)])` bottom sheet；眼色9种/毛色10种；选中后 spring 放大+0.25s dismiss

#### Material UI 测试页 (`MaterialDesignTestView.swift`)
设置页 > 偏好设置 > `NavigationLink` 入口，展示：色彩系统、5级排版、Standard/Accent Card、FAB/Secondary/Pill 按钮、Toggle/Slider、Tags/Badges、Area+Stacked Bar 图表、6条 Motion 参数。

#### AddEntityView Material 化
`isMaterial`（`@AppStorage("appUIStyle") == "material"`）：
- **背景**：`matBg`（#F5F5F7 / #0A0A0C）替代 `ArkBackgroundView`
- **选择卡**：RR28 + white surface + shadow（Material）/ 半透明玻璃 + 描边（Classic）
- 统一 `ScaleButtonStyle` + 弹簧动画跳转

### 2.7 全局固定前置层（R6: globalFixedHeader）

`OverviewView` 的 `body` ZStack 顶层覆盖一个无背景 header overlay，覆盖所有 4 个 tab：
- **左侧**：根据 `selectedDockTab` 动态显示标题（首页问候语 / 日历 / Ohana 图鉴 / 绿洲）
- **右侧按 tab 定制**：
  - **首页(0)**：椰子余额 + 头像菜单（添加成员/管理主页/设置）
  - **日历(1)**：视图切换（月/列表，`@AppStorage("calendar_viewMode")` 共享）+ 添加日程 + 椰子余额
  - **图鉴(2)**：搜索按钮 + 添加岛民 + 椰子余额
  - **绿洲(3)**：椰子规则 + 百宝箱 + 椰子余额
- **无背景**：移除了旧的 `.ultraThinMaterial` 毛玻璃背景
- **触发机制**：子视图接受 `hideToolbar: Bool` + `xxxTrigger: Bool` 参数，header 按钮通过 `.toggle()` 触发子视图 `.onChange` 执行对应操作
- 子视图（CalendarView / CrewRosterOverlay / OasisRewardView / mainScrollView）各自添加 `Spacer().frame(height: 70)` 占位
- 子视图隐藏原生 `.toolbar(.hidden, for: .navigationBar)`

### 2.7 多语言支持（i18n 基础设施）

`Localization.swift` 新建 `L10n` struct：
- `init(_ lang: String)` 读取 `@AppStorage("appLanguage")` 值（"zh" / "en"）
- 100+ 翻译 key：tab / greeting / settings / pet detail / human detail / calendar / common
- 规则：`"ohana"` 一词不翻译
- 使用方式：视图中声明 `@AppStorage("appLanguage") private var appLanguage = "zh"` + `private var l: L10n { L10n(appLanguage) }`
- 已接入：OverviewView globalFixedHeader、FloatingDockNav tab 标签

---

## 三、SwiftData 数据模型

### 3.1 Schema 版本

**当前最新：`ArkSchemaV22`**（`Schema.Version(22, 0, 0)`），包含 23 个模型。

| 版本 | 变更 |
|------|------|
| V1–V13 | 模型逐步添加（宠物/人类/日志/椰子经济/协作等）|
| V14 | Pet 新增 `passedAwayDate`（Rainbow Bridge）|
| V15 | Human 新增 `themeColorHex`（正式主题色字段，自定义迁移）|
| V16 | Human 新增 `privateFieldsRaw`/`heightCm`（lightweight）|
| V17 | PetMilestone 新增 `photoData: Data?`（lightweight）|
| V18 | PetMilestone 新增 `location: String`（lightweight，默认 ""）|
| V19 | Pet 新增 `cardStyleRaw: String`（lightweight，默认 "classic"）|
| V20 | PetDocument 修改：支持 `attachments` (关系) & 多附件迁移（custom）|
| **V21** | **新增 `HumanMedication` 模型（人类吃药提醒）**|
| **V22** | **新增 `HumanHealthReport` 模型（身体检测报告）**|

**迁移链**：V1→…→V14 全部 `lightweight`；V14→V15 `custom`；V15→V22 全部 `lightweight`。

**下次 Model 变更**：新建 `ArkSchemaV23`，在 `stages` 追加迁移。

### 3.2 核心模型

#### Pet（宠物）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | String | 名字 |
| species | String | 物种（dog/cat/rabbit/hamster/bird） |
| breed | String | 品种 |
| gender | String | 性别（male/female/unknown） |
| birthday | Date? | 生日 |
| adoptionDate | Date? | 到家日 |
| avatarData | Data? | 头像照片 `@Attribute(.externalStorage)` |
| avatarEmoji | String | 头像 Emoji 备用 |
| themeColorHex | String | 主题色 hex |
| isNeutered | Bool | 是否绝育 |
| coatColor | String | 毛色 |
| eyeColor | String | 瞳色 |
| notes | String | 备注 |
| currentStreak | Int | 当前连胜天数（V2） |
| lastCheckInDate | Date? | 上次打卡日期（V2） |
| coconutBalance | Int | 椰子余额（V11） |
| foodTrackingModeRaw | String | 粮食追踪模式 "casual"/"precise"（V10） |
| casualOpenDate | Date? | 佛系模式开包日（V10） |
| casualDurationDays | Int | 佛系模式预估天数（V10） |
| passedAwayDate | Date? | 离世日期，nil=在世（V14）|
| **cardStyleRaw** | **String** | **卡片风格 "classic"/"minimal"（V19，默认 "classic"）**|
| **关系** | | |
| pottyLogs | [PetPottyLog] | `.cascade` |
| walkLogs | [PetWalkLog] | `.cascade` |
| hygieneLogs | [PetHygieneLog] | `.cascade` |
| weightLogs | [PetWeightLog] | `.cascade` |
| healthLogs | [PetHealthLog] | `.cascade` |
| documents | [PetDocument] | `.cascade` |
| expenseLogs | [PetExpenseLog] | `.cascade` |
| foodRecords | [PetFoodRecord] | `.cascade` |
| milestones | [PetMilestone] | `.cascade` |
| waterLogs | [WaterLog] | `.cascade` |
| careLogs | [PetCareLog] | `.cascade` |

**计算属性**：`daysTogether`、`ageText`、`genderSymbol`、`humanEquivalentAge`、`hasPassedAway`、`foodTrackingMode`、`casualEstimatedRunOutDate`、`casualRemainingDays`、`remainingFoodGrams`

#### Human（人类成员）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | String | 姓名 |
| avatarEmoji | String | 头像 Emoji |
| birthday | Date? | 生日 |
| bloodType | String | 血型 |
| role | String | 角色（owner/family/friend） |
| notes | String | 备注（V15 起不再存储颜色）|
| nationality | String | 国籍（V8）|
| city | String | 城市（V8）|
| coconutBalance | Int | 椰子余额（V11）|
| avatarImageData | Data? | 头像照片 `@Attribute(.externalStorage)` |
| shouldShowOnHome | Bool | 是否在首页卡堆显示（V13，默认 false）|
| **themeColorHex** | **String** | **主题色 hex（V15，默认 "4338FF"）**|
| **关系** | | |
| weightLogs | [HumanWeightLog] | `.cascade` |
| workoutLogs | [HumanWorkoutLog] | `.cascade` |


#### Event（事件）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| title | String | 标题 |
| eventTypeRaw | String | 类型 raw（daily/vaccine/birthday/anniversary/task/custom...） |
| startDate / endDate | Date | 起止时间 |
| isAllDay | Bool | 全天事件 |
| isCompleted | Bool | 是否完成 |
| relatedEntityId | UUID? | 关联实体 ID |
| relatedEntityType | String | 关联实体类型 |
| recurrenceRuleRaw | String | 循环规则 |
| assigneeId | String? | 指派人 ID（V12） |
| **关系** | | |
| reminders | [Reminder] | `.cascade` |

**计算属性**：`isActionableTask`（区分生日/纪念日信息事件与行动任务）

#### Reminder（提醒）

| 字段 | 类型 | 说明 |
|------|------|------|
| id / title / scheduledDate | — | 基础字段 |
| statusRaw | String | pending/completed/skipped/snoozed |
| completedAt | Date? | 完成时间 |
| **关系** | | |
| event | Event? | 反向关联 |

#### 其他日志模型

| 模型 | 文件 | 关键字段 |
|------|------|----------|
| PetPottyLog | `PetPottyLog.swift` | date, type(pee/poo/both), consistency, executorId |
| PetWalkLog | `PetWalkLog.swift` | date, duration, distanceMeters, routeLocationsData(`@externalStorage`), mapSnapshotData, poopCount, coconutsEarned, executorId |
| PetHygieneLog | `PetHygieneLog.swift` | date, typeRaw(bath/teeth/nails/grooming/earCleaning) |
| PetWeightLog | `PetWeightLog.swift` | date, weight(Double) |
| PetHealthLog | `PetHealthLog.swift` | date, typeRaw(vaccine/deworming/dewormingInternal/dewormingExternal/checkup/medication/surgery/emergency), note, vetName, expirationDate, cost |
| PetDocument | `PetDocument.swift` | name, documentTypeRaw, expirationDate, cost, attachments(关系), syncToPet(Bool) |
| PetDocumentAttachment | `PetDocumentAttachment.swift` | id, filename, fileType(image/file), data(@externalStorage) |
| PetExpenseLog | `PetExpenseLog.swift` | date, amount, category, note, executorId |
| PetFoodRecord | `PetFoodRecord.swift` | date, amountGrams, mealTypeRaw, executorId |
| PetMilestone | `PetMilestone.swift` | date, title, notes, photoData(`Data?`) |
| WaterLog | `WaterLog.swift` | date, amountMl |
| PetCareLog | `PetCareLog.swift` | date, careTypeRaw(feeding/watering/litterBox), executorId |
| HumanWeightLog | `HumanWeightLog.swift` | date, weight, human(关系) |
| HumanWorkoutLog | `HumanWorkoutLog.swift` | date, typeRaw(8种 WorkoutType), durationMinutes, distanceKm, calories, steps, sourceHealthKit, human(关系) |
| PetRelationship | `PetRelationship.swift` | fromPetId, toPetId, relationshipTypeRaw(parent/child/sibling/halfSibling/mate/other) |
| WishlistItem | `WishlistItem.swift` | title, cost(Int), creatorId, isRedeemed, redeemedById |
| **HumanMedication** | **`HumanMedication.swift`** | **humanId, name, dosage, frequencyRaw(每天/每天两次/每天三次/每周/按需/自定义), customFrequencyNote, firstDoseTime, startDate, endDate?, colorHex, notes, isActive, createdAt** |
| **HumanHealthReport** | **`HumanHealthReport.swift`** | **humanId, reportTypeRaw(血液检测/尿液检测/全身体检/视力检查/口腔检查/心脏检查/影像检查/过敏检测/其他), conclusionRaw(正常/注意/异常/危急), hospitalName, doctorName, reportDate, nextCheckDate?, summary, notes, colorHex, createdAt** |

#### 辅助模型

| 模型 | 文件 | 说明 |
|------|------|------|
| Plant | `Plant.swift` | 植物（name/species/location/lastWateredDate/lastFertilizedDate） |
| Household | `Household.swift` | 家庭（name/totalProsperity: Int, V3 新增） |

---

## 四、管理器 & ViewModel

### 4.1 QuestManager（椰子经济系统）

**文件**：`Models/QuestManager.swift`（`@Observable` 单例，UserDefaults 持久化）

```swift
// 核心方法（Phase 55，推荐所有打卡调用使用）
@discardableResult
func awardAction(type: OhanaActionType, pet: Pet?, context: ModelContext) -> (humanGot: Int, petGot: Int)
// 自动从 UserDefaults["currentActiveHumanId"] 读取当前绑定人类

### 5.6 PetDetailView — `Views/Details/PetDetailView.swift`

**HUD 瀑布流仪表盘**（Phase 26 重构，无 Tab 结构）：

| 层 | 组件 | 功能 |
|----|------|------|
| L1 | PetHeroRow | 头像（无图时 PetSilhouetteView fallback）+ 名字 + Tags + daysTogether/年龄，高度 152，圆角 24 |
| L1.5 | PetHUDVitalSection | goLime 霓虹环形图（遛狗进度/铲屎+喂食）；**@Query 实时查询**当日 walkLogs/pottyLogs/careLogs，打卡后数字立即刷新 |
| L2 | PetAlertScrollSection | 断粮/证件到期/疫苗预警横滚卡 |
| L3 | PetHealthHubCard | 健康快动作 4 按钮 + 疫苗本入口 |
| — | PetImmunityCard / PetHygieneCard | 免疫状态 / 护理追踪 |
| L4 | PetChartDashboard | 横向 ScrollView 图表卡（体重/花费/遛狗/噗噗/余粮） |
| L5-6 | PetDocumentsCard / PetMilestonesCard | 证件 / 里程碑 |
| L7 | PetUnifiedTimeline | 岁月史书（5 类日志合并降序） |

**内嵌工具栏**（petToolbar）：编辑（goLime）/ 日历（goCardCyan）/ 寄养卡（goYellow）+ 椰子余额胶囊，glassEffect Capsule 样式

**参数**：`openHealthOnAppear: Bool` — 自动 push PetHealthDetailView

### 5.7 CalendarView — `Views/CalendarView.swift`

- 月视图 + 列表视图切换（默认列表）
- Pet Chip 筛选器：经典模式 goLime 选中，**Material 模式橙色选中 + 白字**
- `SwipeableEventRow`：左滑完成/右滑删除，三种视觉状态(pending/completed/overdue)
- 点击行 → EventDetailSheet——F2F0F5 底板
- 等差光纤纵向时间轴
- **Material 模式差异**：`@AppStorage("appUIStyle")` 自动切换背景 `#F5F5F7`/`#0A0A0C`；`iconModeBtn` 选中橙色；`ambientLightBlobs` 隐藏；月历和周预览选中日橙色背景 + 白字

### 5.8 SettingsView — `Views/SettingsView.swift`

- Profile 卡（经典：goLime 头像；Material：橙色 accent）
- 设备身份选择器（`@AppStorage("currentActiveHumanId")`）
- 偏好：语言（`@AppStorage("appLanguage")`）
- **UI 风格切换**：支持 "经典 (Classic)" 和 "Material" 两种界面风格（`@AppStorage("appUIStyle")`）
- 通知 / 关于 / 版本号
- 宠物管理：每只宠物独立「重置」（清空日志）+「删除」按钮
- **Material 模式差异**：`glassCard` 改白色 RR24+shadow；`settingsSection` 标题改白色胶囊 pill；`accentColor` 切 `#FF5A00`；toolbar 改自定义 xmark 圆按钮 + "Settings" 左标题

### 5.9 HumanDetailView — `Views/Details/HumanDetailView.swift`

1. **Hero 渐变卡**（themeColor→goDarkBlue 渐变 + 装饰光球，圆角 28；头像 100px ultraThinMaterial 底+emoji fallback；姓名 34pt black rounded；Chip 横滚行：角色/年龄/血型/国籍/城市/身高）
2. **Stats Bento**（4 个 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))` 迷你卡横排：体重 goLime / 用药 goRed / 待办 goOrange / 椰子 goYellow，每卡含 SF Symbol 图标）
3. **所有功能卡片**（吃药提醒/身体检测报告/体重记录/椰子资产/账单花费/首页卡堆显示/隐私占位/待办提醒/备注）均使用 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))` 作为背景，与首页 BentoStatCard 风格一致
3. **Badges Card**（动态称号横滚）
4. **Section Header**（goLime 竖线 + 大写 tracking 标题，分隔"健康&身体"/"活动&记录"/"财务"/"提醒&备注"区域）
5. 体重卡 → **HumanWeightHistoryView（Phase 73：改为 .sheet）**
6. HumanWorkoutCard（运动记录） / CoHealthDashboard（共健）
7. 花费卡 / 椰子资产卡
8. **吃药提醒卡**（→ HumanMedicationView）：显示当前激活药物数量+药物名称预览，进入后可添加/编辑/停药，含摘要 Bento（当前用药/今日到期/长期用药）
9. **身体检测报告卡**（→ HumanHealthReportView）：显示报告总数+异常项数，进入后可添加/编辑报告（9种类型：血液/尿液/全身体检/视力/口腔/心脏/影像/过敏/其他；4级结论：正常/注意/异常/危急），含复查日期提醒
10. 提醒区域 / 备注 / 删除
11. Toolbar 铅笔 → EditHumanSheet + 椰子余额胶囊

### 5.9 MaterialDashboardView — `Views/MaterialDashboardView.swift`

**Material Dashboard（第三十七～四十三章，对齐 `Ai_Studio_New_UI/PetDashboard.tsx` 参考实现）**

#### 页面结构（从上至下）

1. **Header**（`HStack(alignment: .top)`）：
   - 左侧：Greeting（`"Hi [ownerName],"` + `"Welcome\nHome!"`，size 38 rounded）
   - 右侧垂直3项：① Settings 齿轮圆形 ② 橙色 `plus` 圆形（`showAddEntity = true`） ③ 椰子余额胶囊（`circle.hexagongrid.fill` 橙色图标 + 数字 `.contentTransition(.numericText())`，点击跳转 Oasis tab）
2. **3D 堆叠宠物卡**（前3只），顶层点击循环切换 + `triggerCardStagger()`
3. **`"{pet.name}'s Actions"`** 小标题胶囊
4. **Activity Grid（5-card Bento + 全宽 Walk）**：
   - `cardSize = (screenWidth−32−14)/2`（≈174pt）
   - 正常态：行1（Feeding + WaterChange）、行2（Litter + Expenses）、行3（Weight + Color.clear 占位）
   - 展开态：选中卡片全宽（spring 动画），其余4张 `opacity(0.4)+scale(0.97)` 排2×2行
   - 全局 Tap Dismiss：`homeTab` 是 ZStack，`expandedCard != nil` 时叠 `Color.clear` 覆盖层捕获点击
   - 每张卡 `onTapGesture` 只扩张（`guard expandedCard != .xxx else { return }`），X 按钮主动关闭
   - Walk 卡：紧凑 cardSize / 活跃 300pt（含实时 MapKit 地图）/ 展开 340pt（历史列表）
5. **Life Tree Widget（全宽横条卡）**：左：Emoji 树图标（随 TreeLevel lv1🌱→lv10✨）；中：等级名 + Lv 标签 + 能量/下级文字；右：进度环（accent 色）+ bolt.fill 注入 FAB（消耗10椰子，调 `OasisTreeManager.shared.injectEnergy(cost:10)`）
6. **Global Overview** 区：Swift Charts 双折线面积图

#### 卡片详情（第四十三章更新）

| 卡片 | 高度 | 展开内容 | 快捷操作 |
|------|------|----------|----------|
| **Feeding** | cardSize / 280pt | 喂食记录列表 + Mark as Fed 按钮 | pet 图标行 + 逐条打勾 |
| **WaterChange** | cardSize / 300pt | 滤芯倒计时条 + 日常换水/深度清洗双按钮 | 折叠态 + 按钮 |
| **Litter** | cardSize / 310pt | Bristol 便便类型 5 按钮 + 全盆更换记录 | 折叠态 + 按钮 |
| **Expenses** | cardSize / 360pt | 本月总额 + 4类横向进度条 + 金额输入+记账 | + 按钮 → `AddExpenseSheet(preselectedPayerId:)` |
| **Weight** | cardSize / 320pt | 大号体重 + Charts 折线面积图 + 记录按钮 | + 按钮 → `QuickWeightSheet` |
| **Walk** | cardSize/300pt/340pt | 前面：Start；活跃背面：MapKit Map + pause/💩计数/结束；展开：历史列表 | `walkPoopCount[pet.id]` 便便计数（numericText） |

#### 椰子粒子吸收动画（Suck-in Effect）
- `MatCoinParticle` 结构体 + `MatCoinParticleView`（橙色 14pt 圆 + hexagongrid 图标 + 发光阴影）
- `launchCoconutParticles()`：Feeding/Water/Litter 打卡及 Life Tree 注入时触发
- 粒子从屏幕卡片区中心飞向右上角 Header pill（spring 0.6s），Light Haptic on launch，Heavy Haptic 0.65s 后
- `coinParticles: [MatCoinParticle]` 覆盖在 `homeTab` ZStack 顶层，1.2s 后自动清理

#### 底部导航（matBottomNav）
- Tab 0：house.fill（首页）| Tab 1：calendar（日历）| 中间 FAB：plus（`showAddEntity`）| Tab 2：pawprint.fill（CrewRoster）| Tab 3：leaf.fill（OasisReward）

#### Global Overview Carousel（第四十四章更新）
- `globalOverviewSection`：Section Header（"Global Overview" + "Details >"）+ 横向 ScrollView + `.scrollTargetBehavior(.viewAligned)` + `.scrollClipDisabled()`
- 卡片规格：宽 85vw，高 220pt，圆角 32pt，surface 背景，shadow(0.03 opacity, radius 20)
- **Card 1 Walk & Activity**：7日走路距离（真实 activePet.walkLogs 或 Mock 回退）；橙色 CatmullRom Area Chart（LinearGradient #FF5A00→clear）+ LineMark + PointMark；大数 km；"Walk & Activity" 胶囊
- **Card 2 Island Expenses**：本月 activePet 花费按 ExpenseCategory 分组（无数据用 Mock）；水平堆叠条形图（Capsule，4色）+ 图例 chip + 洞察文字；金额 `.contentTransition(.numericText())`
- **Card 3 Coconut Wealth**：全岛椰子总量 + 前3名 Human+Pet 合并横向进度条榜单；条形动画 spring(0.6,0.8)

#### AddExpenseSheet（`Components/AddExpenseSheet.swift`）
- 新增 `var preselectedPayerId: String? = nil`
- `onAppear`：优先 `preselectedPayerId` → UserDefaults `currentActiveHumanId` → `humans.first`

#### 辅助类型（同文件）
- **`MatTopRoundedRect`** / **`MatBottomRoundedRect`**：仅上/下两角圆角 Shape
- **`MatWaveView`** / **`MatWaveShape`**：可动画双层波形（`animatableData = phase`）
- **`FoodParticleView`** / **`WaterParticleView`** / **`PoopParticleView`**：落下停留不弹回
- **`MatCoinParticle`** + **`MatCoinParticleView`**：椰子飞行粒子（Chapter 43 新增）
- **`ScaleButtonStyle`**：按下 `scaleEffect(0.92)`

#### State 关键变量
- `expandedCard: MatCardType?`：unified 展开状态（feeding/waterChange/litter/expenses/weight/walk）
- `cardVisible: [Bool]`（6个）：Staggered Cascade
- `walkPoopCount: [UUID: Int]`：遛狗便便计数（per pet）
- `coinParticles: [MatCoinParticle]`：飞行粒子列表
- `treeInjectPressing: Bool`：生命树注入按钮按压缩放状态
- `showAddWeight` / `showAddExpense` / `showAddEntity`：sheet 控制

#### 颜色 Tokens
- bg `#F5F5F7` / surface `.white` / surf2 `#F0F2F5`（Light）
- bg `#0A0A0C` / surface `#1C1C1E` / surf2 `#2C2C2E`（Dark）
- accent `#FF5A00`，textSec `#8E8E93`（Light）/ `#64748B`（Dark）


### 5.10 OasisRewardView（绿洲）— `Views/Home/OasisRewardView.swift`

- 生命之树 SF Symbol（动态 leaf→tree.circle→tree 切换）
- 注入能量按钮（扣 10🥥 + 粒子特效 + 升级弹出）
- 每日被动收益 3🥥（茂盛级以上）
- **Phase 73 新增**：右上角 `info.circle` 按钮 → `CoconutRulesSheet`（椰子获取指南，含收入来源/消耗用途/双账本三区）
- Bento Grid（Phase 71 更新）：
  - 行1：**椰子商店**（→ CoconutShopView）/ 成就解锁（→ AchievementWallView）
  - 行2：**欧气扭蛋机**（→ GachaView）/ **家庭悬赏榜**（→ BountyBoardView）
  - 行3：今日能量 / 植物管理（占位）
- 打卡日历入口已迁移到首页 `DailyStreakDetailView`，绿洲页不再承载月历和补签入口
- **Material 模式差异**：`@AppStorage("appUIStyle")` 背景切 `#F5F5F7`/`#0A0A0C`；`bentoMiniCard` 改白色底+`#E5E5EA` 描边+shadow；`injectEnergyButton` 可用态橙色背景+橙阴影，不可用态白底+橙描边

### 5.14 P1 新增功能（Phase 71）

#### MilestoneCelebrationOverlay — `Views/Details/MilestoneCelebrationOverlay.swift`

- `MilestoneConfig`：定义4个里程碑（100/365/500/1000天），含 emoji/title/accentColor
- `MilestoneCelebrationOverlay`：全屏动画，粒子雨 + 春弹卡片 + 双震动反馈
- `MilestoneCheckModifier`：ViewModifier，`@AppStorage("celebratedMilestoneDays")` 防重复，挂载到 OverviewView 的 `.milestoneCheck(pets:)`

#### CoconutShopView — `Views/Details/CoconutShopView.swift`

- 10件商品（特效4/称号3/加成3），`@AppStorage("purchasedShopItems")` 持久化
- 分类 Chip 筛选，余额实时显示，兑换时写入 CoconutLogEntry
- 无法负数购买（不足时 disabled + 视觉降噪）

#### GachaView — `Views/Details/GachaView.swift`

- 消耗 30🥥/次，4档稀有度：普通(55%) / 稀有(30%) / 史诗(12%) / 传说(3%)
- 14种奖品池，加权随机抽取
- 旋转动画 + 光晕特效 + 历史记录（最多24条，`@AppStorage("gachaHistory")`）
- 传说奖品触发双重震动

#### BountyBoardView — `Views/Details/BountyBoardView.swift`

- `BountyTask: Codable`，JSON 存储于 `@AppStorage("bountyTasks")`
- 发布任务：`AddBountyTaskSheet`（emoji/标题/描述/奖励选择），发布人身份来自 `currentActiveHumanId`
- 接单完成：触发椰子奖励转移，记录接单人姓名和完成时间
- 发布人可撤销任务；进行中/已完成双 Tab 切换

### 5.11 其他重要页面

| 页面 | 文件 | 功能 |
|------|------|------|
| DailyStreakDetailView | `Home/DailyStreakDetailView.swift` | 首页“打卡连击”弹层：我的连击卡 + 月历打卡 + 补签 + 连续打卡里程碑奖励 |
| PetBasicInfoDetailView | `Details/PetBasicInfoDetailView.swift` | 宠物完整信息页（Hero 卡 info 入口） |
| PetHealthDetailView | `Details/PetHealthDetailView.swift` | 免疫健康详情（环形进度 + 时间轴） |
| PetHygieneDetailView | `Details/PetHygieneDetailView.swift` | 护理详情（5 图标 + 7 日 mini bar） |
| PetFoodManagementView | `Details/PetFoodManagementView.swift` | 双轨制粮食管理（佛系/精准） |
| PottyOverviewView | `Details/PottyOverviewView.swift` | 噗噗电台（今日次数 + 7 日柱状图） |
| WalkDetailView | `Details/WalkDetailView.swift` | 交互式 Map + MapPolyline + Apple Maps 跳转 |
| WalkSummarySheet | `Details/WalkSummarySheet.swift` | 遛狗历史列表 + 地图快照 |
| WeightHistoryView | `Details/WeightHistoryView.swift` | 体重折线图 + 记录列表 |
| ExpenseHistoryView | `Details/ExpenseHistoryView.swift` | 花费柱状图 + 分类记录 |
| AchievementWallView | `Details/AchievementWallView.swift` | 成就墙 2 列网格 |
| SitterCardPreviewSheet | `Details/SitterCardPreviewSheet.swift` | 寄养名片 + ImageRenderer 截图分享 |
| VaccinePassportView | `Details/VaccinePassportView.swift` | 疫苗本详情 |
| DocumentsListView | `Details/DocumentsListView.swift` | 证件列表（点击跳转 `DocumentDetailSheet`） |
| DocumentDetailSheet | `Details/DocumentDetailSheet.swift` | 证件完整详情（多附件展示/下载/预览） |
| DogActivityCard | `Home/DogActivityCard.swift` | 狗狗运动卡（遛狗/陪玩记录显示） |
| PlantDetailView | `Details/PlantDetailView.swift` | 植物详情（浇水/施肥） |
| CatCareStationCard | `Details/CatCareStationCard.swift` | 猫咪护理站 |
| CoHealthDashboardView | `Details/CoHealthDashboardView.swift` | 协同健康仪表盘 |
| HumanWishlistView | `Details/HumanWishlistView.swift` | 心愿单 |
| WeeklyReportCard | `Details/WeeklyReportCard.swift` | 本周小报海报 |

### 5.12 全岛数据仪表盘

| 仪表盘 | 文件 | 功能 |
|--------|------|------|
| IslandWeightDashboard | `Details/IslandWeightDashboard.swift` | 全岛体重看板（Catmull-Rom 平滑曲线 + 面积层 + 左到右 reveal 动画 + 干饭王/自律王 Bento + 个体清单下钻） |
| IslandExpenseDashboard | `Details/IslandExpenseDashboard.swift` | 全岛花费（总支出 + 吞金兽 Bento + 条形图 + 环形饼图 + 谁在买单）；无数据时 pie chart 仍显示灰色空心环 + "暂无数据" + 右侧引导文案 |
| IslandExplorationDashboard | `Details/IslandExplorationDashboard.swift` | 全岛探索（总里程 + Bento + 堆叠柱状图 + 贡献榜） |
| IslandWealthDashboard2 | `Details/IslandWealthDashboard2.swift` | 椰子财富中心（堆叠柱状图 + 贡献排行榜） |

### 5.16 Phase 78 & 79 (UI Polish, Inventory & Theme Toggles)

**UI 标准化与动效**：
- `IslandStatComponents` 图表增加了载入动画，且使用 `pet.themeColor` 区分各宠物的曲线。
- 日历 Bug 修复，支持正确的跨天显示和序列删除逻辑。
- 引入了系统的 `appThemePreference`（系统/浅色/深色），对 `ohanaStandardCard` 等组件做了全适配。

**Inventory & Effects (背包与特效装备)**：
- `InventoryView`: 从 Oasis 进入，分为 Titles / Effects / Consumables 三页，数据通过 `@AppStorage` 保存。
- **特效支持**：
  - `fx_lime_glow`: 装备后在首页 ID Card 签到时会有绿色闪光 (`ArkCrewIDCardView.swift`)
  - `fx_rainbow`: 装备后 `WalkDetailView` 的轨迹线条呈彩虹渐变
  - `fx_stars`: 装备后完成 `DailyQuestsCard` 的任务掉落星星粒子
  - `fx_firework`: 装备后 `MilestoneCelebrationOverlay` 庆典掉落烟花粒子
- **称号支持**：
  - `title_guardian` (守护神): 展示在 `ArkCrewIDCardView` 封面名字前
  - `title_pioneer` (先锋): 在 `IslandExplorationDashboard` 为劳模铲屎官头衔加 Rocket badge
  - `title_chef` (厨神): 在 `QuestManager.swift` 发生喂食 (`.feed`) 判定时，Human 额外 +1 椰子奖励

### 5.17 PetWalletStack（第三十四章重构，替换 CritterDeckCarousel）

**位置**：`Views/Home/PetWalletStack.swift`

- **iOS Wallet 堆叠 + App Store Today 展开**：
  - 首页卡片从横向 `TabView` 分页改为 **ZStack Wallet 堆叠**布局
  - **下边的卡片在最前面**（zIndex最高，active卡片在底部全尺寸可交互），上边在最后面（behind卡片仅露出顶部56pt条纹）
  - behind卡片 `scaleEffect(1-depth*0.02, anchor: .bottom)` + `brightness(-depth*0.05)` 衰减
  - 顶牌上下拖拽切换（`highPriorityGesture` + `contentShape(Rectangle())` 不与页面 ScrollView 冲突）
  - **上/下滑均把当前前卡移到堆末尾**（`activeIndex = (activeIndex + 1) % count`），不再循环回堆顶
  - 底部自定义分页胶囊指示器（当前页 24×7 goLime，其余 7×7 白色半透）
  - 最多显示 4 张卡片（`maxVisible = 4`）
- **App Store Today 英雄过渡**：
  - 使用 iOS 18+ `matchedTransitionSource(id: pet.id, in: heroNS)` 标记卡片为过渡源
  - ContentView 的 `navigationDestination` 添加 `.navigationTransition(.zoom(sourceID: pet.id, in: heroNS))`
  - `@Namespace` 从 `ContentView` → `OverviewView` → `PetWalletStack` 层层传递
  - 点击宠物卡片 → 原生 zoom 过渡到 `PetDetailView`（完整详情页，零内容复制）
- **WalletPetCardFront**（GO UI 蓝橙配色）：蓝色渐变底(`#233BFF` → `#141FAE`) + 橙色(`#FF5A3D`)超大背景名字**锚定卡片顶部**（堆叠时漏出的peeking区域可见）+ 左侧头像层（透明抠图/普通照片羽化/剪影三方案）+ 右侧信息列（连续打卡徽章、daysTogether主数字、footnote、条码）+ 彩虹桥覆盖
- **WalletHumanCardFront**：同蓝底 + teal 配色 + 顶部大字 + 岛民信息 + 条码
- **PetDetailView 顶部卡片统一**：`PetHeroRow` 替换为 `WalletPetCardFront`，与首页 Wallet 卡片同款视觉，zoom 过渡自然衔接
- **PetDetailView 布局（第三十五章更新）**：
  - `petToolbar`（编辑/日历/即养卡）移到 Hero 卡上方（ScrollView 内顶部，椰子数左边）
  - `PetChartDashboard` 无背景直接渲染（去掉外层背景包裹）
  - `PetHygieneCard` 移除内部 `UltimateGlassCard`，由外层 glassEffect 提供背景
  - `compactDocumentsCard` / `compactMemoriesCard` / `compactAchievementsCard` cornerRadius = 16
  - **"里程碑"改名为"回忆录"**：右上角新增 goLime + 快捷添加按钮，直接 NavigationLink 进 `PetMilestoneListView`
  - `PetUnifiedTimeline`（岁月史书）改用 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))`
  - 所有卡片统一标准背景：`.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))`
- `DeckItem` enum 和 `HumanIDCardView` 仍保留在 `CritterDeckCarousel.swift`（供 AllCardsSheet 等使用）

### 5.13 首页组件

| 组件 | 文件 | 功能 |
|------|------|------|
| IslandStatComponents | `Components/IslandStatComponents.swift` | Island Stats 卡片 + SynergyFlashCard + CoconutWealthRankingCard（Button+onTap 回调，标题"Ohana财富"）；`MultiPetLineChart` / `MiniLineChart` / `MiniBarChart` / `MultiPetExpenseBar` / `MiniRingChart` 均支持首帧和数据变化重播动画；`playAnimation()` 统一使用轻量 `easeOut(duration:0.28~0.3)` 避免卡顿 |
| PetSilhouetteView | `Components/PetSilhouetteView.swift` | 互动宠物剪影（猫/狗/通用），Path 绘制耳嵌头部/五官下移/眼距正确；支持 `onTapCoat`/`onTapEye` 闭包；`AddPetWizardView.stepAppearance` 点击眼睛→瞳色 sheet，点击身体→毛色 sheet（`ColorPickerSheet` 5列圆形色格）；`resolvedCoatColor`/`resolvedEyeColor` 将颜色名映射为 Color |
| SmartTodayCard | `Components/SmartTodayCard.swift` | 智能待办（SmartTaskEngine 优先级决策 + GoldenRewardRow 里程碑） |
| DailyQuestsCard | `Components/DailyQuestsCard.swift` | 今日 3 委托 + 进度条 + **Quest Toast**（领取盲盒后顶部青柠胶囊 + 成功震动，2.2s 消失） |
| MemoryDropCard | `Components/MemoryDropCard.swift` | 岁月记忆碎片 |
| WelcomeQuestBentoView | `Components/WelcomeQuestBentoView.swift` | 新手 3 任务面板 |
| GlobalWalkBanner | `Components/GlobalWalkBanner.swift` | 遛狗悬浮条（可拖动气泡 + 结束翻转详情卡） |
| SwipeableEventRow | `Components/SwipeableEventRow.swift` | 日历事件滑动行 |
| OverviewQuickActions | `Components/OverviewQuickActions.swift` | GoQuickActionCard + GroomMenuSheet |
| OverviewHelperViews | `Components/OverviewHelperViews.swift` | 首页辅助视图 |
| StreakBadgeView | `Components/StreakBadgeView.swift` | 🔥 连胜徽章 |
| ConfettiModifier | `Components/ConfettiModifier.swift` | 庆典粒子特效 |
| DutyNudgeComponents | `Components/DutyNudgeComponents.swift` | 打卡提醒组件 |
| ExpenseSplitterCard | `Components/ExpenseSplitterCard.swift` | 费用分摊卡 |

### 5.15 QACardType 全物种 Quick Access（Phase 73）

**位置**：`ArkCrewIDCardView.swift` — `SpeciesCheckInGrid` + `QACardType` enum

**QACardType 完整 16 cases**：

| Case | 物种 | 打卡类型 | 椰子奖励(人/宠) |
|------|------|----------|----------------|
| `.feed` | 通用 | CareType.feeding | 2 / 3 |
| `.water` | 通用 | CareType.watering | 2 / 3 |
| `.potty` | 通用 | PetPottyLog | 2~5 / 5~8 |
| `.litter` | 猫 | CareType.litter | 5 / 8 |
| `.walk` | 狗 | PetWalkingManager | 按里程 |
| `.care` | 通用 | HygieneLog menu | 5~15 差异化 |
| `.health` | 通用 | → HealthDetail | 20 / 20 |
| `.weight` | 通用 | WeightSheet | - |
| `.expense` | 通用 | ExpenseSheet | 10 / 0 |
| `.play` | 猫/兔鼠 | CareType.play | 10 / 12 via .general |
| `.waterChange` | 鱼 | CareType.waterChange | 15 / 20 via .general |
| `.filterClean` | 鱼 | CareType.filterClean | 25 / 40 via .general |
| `.cageCleaning` | 鸟/兔鼠 | CareType.cageCleaning | 15 / 20 via .general |
| `.freeFlight` | 鸟 | CareType.freeFlight | 10 / 12 via .general |
| `.misting` | 爬宠 | CareType.misting | 8 / 10 via .general |
| `.substrateChange` | 爬宠 | CareType.substrateChange | 20 / 30 via .general |

**available(for:) 物种分配**：
- 狗：walk / feed / water / potty / care / play / health / expense / weight
- 猫：litter / feed / water / **potty** / play / care / health / expense / weight（Phase 76 加入 potty）
- 鱼：feed / waterChange / filterClean / health / expense / weight
- 鸟：feed / water / cageCleaning / freeFlight / care / health / expense / weight
- 兔鼠：feed / water / litter / play / cageCleaning / care / health / expense
- 爬宠：feed / water / misting / substrateChange / health / expense / weight
- 默认：feed / water / potty / care / health / expense / weight

**打卡辅助方法**：
- `performCareCheckIn(type:)` — 通用 CareLog + awardAction(.feed/.water)
- `performPottyCheckIn()` — PottyLog + awardAction(.potty)
- `performLitterCheckIn()` — CareLog(litter) + awardAction(.potty(isLitter:true))
- `performSpecialCareCheckIn(type:emoji:title:humanReward:petReward:)` — 新物种动作 + awardAction(.general)

---

## 六、表单与向导

| 文件 | 功能 |
|------|------|
| `AddPetWizardView.swift` | 宠物添加向导（10步：basicInfo→breed→avatar→dates→gender→birthplace→identity→**appearance**→familyRelation→confirm），含头像裁剪/品种选择/主题色互斥/自动创建事件；**Phase 76 新增「粘贴已抠主体」剪贴板按钮**；**F11 新增**：appearance 步骤顶部展示 `PetSilhouetteView` 互动剪影，根据 species 渲染猫/狗/通用形态，毛色/瞳色选择实时映射到剪影颜色（`resolvedCoatColor`/`resolvedEyeColor` 计算属性），支持预设色+图案色+自定义色 |
| `AddHumanWizardView.swift` | 成员添加向导（5 步）；**Phase 76 新增「粘贴已抠主体」剪贴板按钮**（同 `pastePasteboardImage()` 方法） |
| `AddPlantView.swift` | 添加植物（轻量表单） |
| `EditPetSheet.swift` | 编辑宠物全字段 |
| `AddEventView.swift` | 添加日历事件（含循环规则，180 天批量 Reminder 生成，365 天 hardCap） |
| `AddDocumentSheet.swift` | 添加宠物证件（含拍照/相册/文件多附件） |
| `AddEntityView.swift` | 选择添加类型入口（植物标记为"开发中"） |

---

## 七、核心交互流程

### 7.1 遛狗完整流程

```
PetDetailView / Quick Access / 卡片背面
→ PetWalkingManager.start(pet:)
  → LocationManager.startTracking()
  → 计时器开始，每 10 个 GPS 点刷新地图快照
→ GlobalWalkBanner 展开（可拖动/最小化气泡）
→ "停止" → LocationManager.stopTracking()
  → generateMapSnapshot() → 生成路线图
  → PetWalkLog 写入 SwiftData（routeLocationsData @externalStorage）
  → awardAction(.walk) + poopCount × awardAction(.potty)
  → WalkSummarySheet 自动弹出
→ WalkDetailView（交互地图 + Apple Maps 跳转）
```

### 7.2 提醒完整流程

```
AddEventView → 创建 Event + Reminder(s)
  → 循环事件按步长生成 180 天内所有 Reminder
→ NotificationManager.schedule(reminder)
  → UNCalendarNotificationTrigger
→ 通知触发（锁屏/Banner）
  → 用户操作：完成/跳过/明天再说
  → .completed / .skipped / .snoozed
  → .snoozed：创建次日新 Reminder + 调度通知
```

### 7.3 打卡奖励流程

```
任何打卡入口（Quick Access / 卡片背面 / 详情页）
→ QuestManager.shared.awardAction(type:pet:context:)
  → 读取 UserDefaults["currentActiveHumanId"] 找 Human
  → 计算基础奖励 → 暴击引擎 roll
  → pet.coconutBalance += finalPet
  → human.coconutBalance += finalHuman
  → coconutCount += (finalPet + finalHuman)
  → 写入 CoconutLogEntry（含 actorId/actorName）
→ UI 反馈：震动 + 椰子浮字特效
```

---

## 八、UserDefaults Key 索引

| Key | 类型 | 用途 |
|-----|------|------|
| `ohana_has_onboarded` | Bool | 是否完成引导 |
| `currentActiveHumanId` | String | 当前设备绑定的 Human UUID |
| `overview_activeCritterId` | String | 首页当前顶牌宠物 UUID |
| `appLanguage` | String | 语言偏好（zh/en） |
| `userNickname` | String | 用户昵称 |
| `coconutCount` | Int | 全局椰子总数 |
| `coconutLogs` | Data(JSON) | 椰子收支日志 |
| `isPetWizardCompleted` | Bool | 新手任务：添加宠物 |
| `isFirstMealRecorded` | Bool | 新手任务：首次喂食 |
| `isThemeColorSet` | Bool | 新手任务：设置主题色 |
| `quickActionItems_v2` | String(JSON) | Quick Access 持久化 |
| `home_section_order` | String | 首页 section 顺序（已废弃，Phase 47 改为固定布局） |
| `lastTreeHarvestDate` | String | 生命树上次领取日期 |
| `celebratedMilestoneDays` | String | 已庆典里程碑记录（"petId-days,..."） |
| `purchasedShopItems` | String | 已兑换商店商品 ID 列表（","分隔） |
| `gachaHistory` | String | 扭蛋历史奖品 ID 列表（最多24条） |
| `bountyTasks` | String(JSON) | 家庭悬赏榜任务列表 |

---

## 九、数据安全与隐私

- **本地优先**：所有数据存储在设备 SwiftData（SQLite + App Group）
- **iCloud**：`cloudKitDatabase: .none`，数据不同步
- **照片权限**：用户主动选择头像时请求
- **位置权限**：遛狗时请求 "When In Use"
- **通知权限**：创建第一个提醒时请求
- **HealthKit**：只读步数/卡路里/距离/Workout（模拟器 Mock 化）
- **Release 日志**：`#if DEBUG` 条件编译

---

## 十、已知限制与 Bug

| ID | 描述 | 优先级 | 状态 |
|----|------|--------|------|
| BUG-2 | `UIScreen.main` deprecated（iOS 16+），多处使用 | 低 | ⬜ 待修 |
| LIMIT-1 | Sign in with Apple 未实现 | 中 | ⬜ |
| LIMIT-2 | CloudKit 同步未实现（需付费开发者账号） | 中 | ⬜ |
| LIMIT-3 | Widget Target 不存在 | 高 | ⬜ |
| LIMIT-4 | 多语言 Localizable.strings 未建立，中文硬编码 | 中 | ⬜ |
| LIMIT-5 | HealthKit 模拟器 Mock 化，真机未完整测试 | 低 | ⬜ |

---

## 十一、Backlog

### P0 — 高优先级

| 任务 | 说明 | 预估 |
|------|------|------|
| **Widget** | 今日提醒 + 喂食打卡，App Group 基础设施已就绪 | 2-3 天 |

### P1 — 中优先级

| 任务 | 说明 | 状态 |
|------|------|------|
| ~~椰子兑换商店~~ | ~~绿洲 Bento 入口~~ | ✅ Phase 71 |
| ~~里程碑全屏庆典~~ | ~~100/365/500/1000 天~~ | ✅ Phase 71 |
| ~~欧气扭蛋机~~ | ~~消耗 30🥥/次~~ | ✅ Phase 71 |
| ~~家庭悬赏榜~~ | ~~发布/接单/椰子转移~~ | ✅ Phase 71 |
| **HealthKit 写入** | 将运动记录写回 HealthKit | ⬜ |
| **NFC 魔法贴** | Shortcuts + `ark://` 深度链接 | ⬜ |

### P2 — 低优先级

| 任务 | 说明 |
|------|------|
| Sign in with Apple | AuthManager |
| CloudKit 同步 | 需付费开发者账号 |
| Siri 快捷指令 | AppIntents |
| Live Activity | 遛狗动态岛 |
| PDF 导出 | 宠物健康档案 |
| ~~数据导出 JSON/CSV~~ | ✅ **已完成** — DataBackupManager（见第十三节）|
| 多语言 | Localizable.strings（zh/en） |
| 分享海报 | 遛狗总结/里程碑 |
| 交互式桌面组件 | 桌面直接投喂 |

---

---

## 十二、工具服务层（Utilities / Services）

### 12.1 ImageCutoutService

**文件**：`Utilities/ImageCutoutService.swift`（Phase 74 新建）

**功能**：使用 iOS 17 `Vision.VNGenerateForegroundInstanceMaskRequest` 将宫物头像背景替换为透明

```swift
@MainActor
final class ImageCutoutService {
    static let shared = ImageCutoutService()
    func removeBackground(from image: UIImage) async throws -> UIImage?
}
```

**核心流程**：
1. `UIImage` 方向修正（`fixedOrientation()`）→ `CGImage`
2. `VNImageRequestHandler` 执行 `VNGenerateForegroundInstanceMaskRequest`
3. `result.generateScaledMaskForImage(forInstances:from:)` 获取前景 mask（CVPixelBuffer）
4. 逐像素应用：mask 白色保留，黑色变透明（alpha = 0）
5. 输出 `UIImage` PNG（透明底）

**集成点**：`AddPetWizardView.cropImageItem` sheet `onCrop` 回调中异步调用，成功就存透明 PNG、失败 fallback 到 JPEG

**效果**：`PetCardFrontView` 贴纸白边加持宪物轮廓，而非方形框

### 12.2 PetCoatPattern（毛色渐变图案）

**位置**：`AddPetWizardView.swift` 尾部定义（Phase 74）

| Case | 显示名 | 渐变类型 |
|------|---------|----------|
| `.calico` | 三花 | AngularGradient（白/黑/橙/白） |
| `.silverChinchilla` | 銀渐层 | RadialGradient（白→浅灰） |
| `.tortoiseshell` | 珳璃 | AngularGradient（深棕+橙+黑） |
| `.cowPattern` | 奶牛色 | LinearGradient（白/黑角锄角） |
| `.bicolor` | 蓝白双色 | LinearGradient（石蓝→白） |

`colorSection(title:items:patternItems:...)` 渐变圣水排列在纯色圣水后面；毛色开启 `PetCoatPattern.allCases`，瞳色 `patternItems: []`

---

---

## 十三、TASK 1-7 新增功能（2026-03-08）

### 13.1 DataBackupManager（JSON 全量备份/恢复）

**文件**：`Models/DataBackupManager.swift`

**功能**：将全部 21 个 SwiftData 模型 + 关键 UserDefaults 状态导出为单个 JSON 文件，并支持从 JSON 文件恢复（UUID 去重，不清除现有数据）。

```swift
@MainActor
final class DataBackupManager {
    static let shared = DataBackupManager()
    func exportJSON(context: ModelContext) async throws -> URL  // 返回 temp 目录 JSON 文件 URL
    func importJSON(from url: URL, context: ModelContext) async throws
}
```

**备份结构**（`OhanaBackup`）：
- `schemaVersion: Int`（14）
- `exportedAt: String`
- 21 个模型数组：pets / humans / plants / households / events / reminders / careLogs / pottyLogs / walkLogs / weightLogs / expenseLogs / healthLogs / hygieneLogs / foodRecords / milestones / documents / petRelationships / humanWeightLogs / humanWorkoutLogs / waterLogs / wishlistItems
- `appState: AppStateBackup`（coconutCount / coconutLogs / bountyTasks / purchasedShopItems / gachaHistory / celebratedMilestoneDays）

**文件命名**：`ohana_backup_yyyyMMdd_HHmmss.json`

**UI 集成**：`SettingsView` 「数据备份」Section：
- 导出行：生成备份 → ShareLink 分享
- 导入行：`.fileImporter(allowedContentTypes: [.json])` 选择文件
- 恢复成功/失败 Alert

### 13.2 ArkSchemaV15 — Human.themeColorHex

**变更**：`Human` 模型新增 `var themeColorHex: String`（默认 `"4338FF"`）

**迁移**：V14→V15 使用 `MigrationStage.custom` 的 `didMigrate`，从 `human.notes` 中提取 `"themeColor:XXXXXX"` 写入 `themeColorHex`，并从 `notes` 清除该段。

**读取**：统一使用 `human.themeColor`（`HumanExtensions.swift` 计算属性，返回 `themeColorHex`，为空时 fallback `"4338FF"`）。

**写入**（新建时）：`human.themeColorHex = selectedColor`，不再写 `notes`。

**替换范围**（6 处）：
- `OnboardingView` — 创建 Human 时写入
- `OverviewView` — 头像色读取
- `CritterDeckCarousel` — 轮播卡主题色（2处）
- `AddExpenseSheet` — 付款人颜色
- `ExpenseSplitterCard` — 分摊颜色
- `IslandExpenseDashboard` — 仪表盘颜色

### 13.3 GPS 后台权限完善

**Info.plist 新增**：
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

**LocationManager 新增**：
- `var isAlwaysAuthorized: Bool` — 计算属性
- `func upgradeToAlways()` — 主动请求 Always 权限

**WalkTrackingCard 新增**：Always 权限升级横幅，仅在 `authorizationStatus == .authorizedWhenInUse` 时显示，点击「升级」调用 `upgradeToAlways()`，点击 ✕ 关闭。

### 13.4 Sliding Window Reminder + BGAppRefreshTask

**BGTask ID**：`com.guanchen.li.Ark.reminderRefill`

**Info.plist**：`BGTaskSchedulerPermittedIdentifiers` 数组注册该 ID。

**OhanaApp 变更**：
- `init()` 中调用 `registerBGTasks()`
- `UIApplication.didEnterBackgroundNotification` 时调用 `scheduleReminderRefill()`（earliestBeginDate = now + 6h）
- `handleReminderRefill` 创建新 `ModelContext`，调用 `NotificationManager.refillWindowIfNeeded` + `compensate`，完成后 `setTaskCompleted(success: true)`

**现有 NotificationManager 方法**（`scheduleRollingWindow` / `refillWindowIfNeeded` / `compensate`）已就位，BGTask 触发时调用。

### 13.5 PetHealthAlertEngine — 健康异常检测

**文件**：`Models/PetHealthAlertEngine.swift`

**主入口**：
```swift
final class PetHealthAlertEngine {
    static let shared = PetHealthAlertEngine()
    func scanAlerts(pets: [Pet]) -> [HealthAlert]  // 按严重程度排序
}
```

**检测规则**（8 类）：
| 类型 | 触发条件 |
|------|---------|
| 疫苗已过期 | expirationDate < now |
| 疫苗即将到期 | 距到期 ≤ 30 天 |
| 驱虫即将到期 | 距到期 ≤ 14 天 |
| 体重异常增加 | 相邻两条记录 ≥ +10% |
| 体重异常减轻 | 相邻两条记录 ≤ -10% |
| 久未打卡 | 距上次喂食/喂水 ≥ 2 天 |
| 长时间未便便 | 距上次便便 ≥ 36h（仅狗/非猫兔鼠） |
| 未遛狗 | 距上次遛狗 ≥ 3 天（仅物种="狗"） |
| 年检逾期 | 距上次体检 ≥ 365 天 |
| 证件到期 | 距到期 ≤ 30 天或已过期 |

**严重程度**：`.urgent` > `.warning` > `.info`

**UI 集成**：`PetHealthDetailView` 顶部 `alertsSection`，`onAppear` 时调用 `scanAlerts`，最多展示 5 条，每条显示 emoji + 标题 + 说明 + 严重程度徽章。

---

*文档生成时间：2026-03-09 | Schema: ArkSchemaV17 | Phase 1-76 + TASK 1-7 + FIX 1-8 | 核查方式：逐文件代码验证*

---

## 十四、FIX Sprint 变更汇总（2026-03-09）

| Fix | 文件 | 变更说明 |
|-----|------|----------|
| FIX 1 | `AddHumanWizardView.swift`, `Human.swift`, `SharedModelContainer.swift` | Human 新增 `privateFieldsRaw: String` + `heightCm: Double`（ArkSchemaV16）；向导从 7 步扩展到 9 步（体重/隐私）；`EditHumanSheet` 同步加载和保存隐私字段 |
| FIX 2 | `AddPetWizardView.swift` | `stepAvatar` 重构：粘贴抠图黄色胶囊主推荐 + 操作提示 + 可折叠引导说明卡 + 相册/拍照次级按钮 |
| FIX 3 | `CritterDeckCarousel.swift` | `miniCardFront` 透明 PNG 用 `scaledToFit`（不裁切），普通图用 `scaledToFill+clipped`；pet/human 无头像时显示 emoji 或首字母 |
| FIX 4 | `PetDetailView.swift` | `DietCardWithQuickActions` 新增便便/铲砂快捷打卡按钮；`isCatLike` 控制：猫写 `PetCareLog(.litter)` + `QuestManager.potty(isLitter:true)`，非猫写 `PetPottyLog` + `potty(isLitter:false)`；`dietActionCell` 辅助函数统一按钮样式 |
| FIX 5 | `PetFoodManagementView.swift` | A: `showOverdoseToast(isSuccess:)` 参数语义修正（true=达标绿/false=超量橙）；B: `saveStock()` 后清空 `stockKgInput/dailyGramsInput`；C: `onAppear` 从 `pet.restockWeight/dailyPortionGrams` 预填输入框 |
| FIX 6 | `PetDetailView.swift` | `PetHUDVitalSection` 改为独立 struct，内置 `@Query`（按 `pet.id + todayStart/weekStart` 过滤），打卡后顶部 3 个数字实时更新，无需等待 SwiftData relationship 刷新 |
| FIX 7 | `PetMilestone.swift`, `SharedModelContainer.swift`, `PetMilestoneListView.swift` | 模型新增 `photoData: Data?`（ArkSchemaV17）；列表页添加 `PhotosPicker` 照片选择、160pt 高照片展示、保存时写入 `photoData`；sheet 改为 `.presentationDetents([.large])` |
| FIX 8 | `CritterDeckCarousel.swift` | 小卡片普通图片（非透明 PNG）底部叠加 `LinearGradient(colors:[.clear,.clear,goDarkBlue.opacity(0.5),goDarkBlue.opacity(0.85)])` overlay，使头像底部自然融入卡片渐变背景 |
| **P11** | **DocumentsListView.swift / DocumentDetailSheet.swift** | **证件详情重构**：点击证件不再直接进入编辑，而是通过 `DocumentDetailSheet` 展示全字段 + 多附件预览（支持图片/文件）；Edit/Delete 移至详情页 Toolbar； contextMenu 增加查看详情入口 |
| **P12** | **OasisRewardView.swift** | **椰子点击交互**：`BeautifulCoconutTree` 启用 `onHarvest` 回调；`harvestedCoconutIndices` 追踪当日采摘；点击椰果触发 `QuestManager.shared.addCoconuts(1)` + 飞入动画 |
| **P13** | **PetMilestoneListView.swift** | **地图选址 + 自动化**：地址 TextField 替换为 `MapLocationPickerSheet`（`MKLocalSearch`）；新增 `autoCreateMilestones()`：进入页面时自动补全生日、到家日、最高体重记录里程碑（存入 `location` 字段） |
| **P14** | **AddDocumentSheet.swift / Pet.swift** | **信息同步**：添加证件时可勾选「同步到宠物基本信息」；自动读写 `pet.passportNumber` |
| **P15** | **DogActivityCard.swift** | **狗狗专项**：为物种="狗"的宠物在详情页增加「遛狗与陪玩」专属统计卡片 |

---

## 十五、绿洲系统（椰子树全面升级，2026-03-09）

### 15.1 OasisTreeManager — `Models/OasisTreeManager.swift`

**TreeLevel 10 级系统**（`enum TreeLevel: Int, CaseIterable, Comparable`，rawValue 1-10）：

| 等级 | 名称 | 能量范围 | 升级奖励椰子 |
|------|------|----------|------------|
| Lv1 | 希望之种 | 0–49 | — |
| Lv2 | 破土嫩芽 | 50–149 | 5🥥 |
| Lv3 | 茁壮成长 | 150–299 | 10🥥 |
| Lv4 | 初现树形 | 300–499 | 15🥥 |
| Lv5 | 椰影婆娑 | 500–799 | 25🥥 |
| Lv6 | 果实初挂 | 800–1199 | 35🥥 |
| Lv7 | 硕果累累 | 1200–1799 | 50🥥 |
| Lv8 | 参天古木 | 1800–2599 | 75🥥 |
| Lv9 | 灵树觉醒 | 2600–3599 | 100🥥 |
| Lv10 | 生命之树 | 3600+ | 200🥥 |

**关键属性**：
- `islandEnergy`：来自数据库活动（careLogs/walkLogs/hygieneLogs/pottyLogs/workoutLogs 计数）
- `injectedEnergy`：消耗椰子注入，持久化到 `UserDefaults["oasis_injectedEnergy"]`
- `totalEnergy = islandEnergy + injectedEnergy`
- `progressToNextLevel`：当前级别内进度 0.0~1.0

**升级奖励**：`checkAndRewardLevelUp()` 在 `refreshEnergy` / `injectEnergy` 后调用，用 `lastRewardedLevel`（UserDefaults）防止重复奖励。

**被动收益**（Lv5+）：每日可领取 3-15 椰子，`canHarvestToday` 检测 `lastTreeHarvestDate`。

### 15.2 BeautifulCoconutTree — `Views/Home/BeautifulCoconutTree.swift`（新建）

SwiftUI `Path` 驱动的动态生长椰子树，接收 `level: Int`（1-10）和 `isInjecting: Bool`。

**核心 Shape**：
- `TrunkShape`：`AnimatablePair<Double, AnimatablePair<Double, Double>>` 驱动弯曲树干，`trunkHeight/trunkWidth/bend` 随等级线性增长
- `LeafShape`：贝塞尔曲线弯曲叶片，16 片上限按等级展示，颜色随等级变化（黄绿→青绿→青蓝→青蓝 Lv10）
- `CoconutShape`：椭圆椰果，Lv5+ 出现，最多 6 颗

**动画**：
- 微风摇曳：`.easeInOut(duration:3.0).repeatForever(autoreverses:true)` 控制 `swayAngle`（-2.5~2.5°）
- 光晕脉冲：底部 `RadialGradient` 椭圆随 `glowPulse` 缩放
- 注入脉冲：`isInjecting` 为 true 时树冠 `scaleEffect(1.12)`
- 升级动画：`TrunkShape.animatableData` 确保树干平滑过渡
- Lv10 粒子：`Timer` 每 2s 生成 12 个 `sparkle` 图标，淡出上浮

### 15.3 CoconutShopView — `Views/Details/CoconutShopView.swift`

**ShopItem 新增 `isConsumable: Bool`**（默认 false）：

| 道具 | id | 类型 | 效果 |
|------|-----|------|------|
| 青柠光晕 | `fx_lime_glow` | 永久特效 | 购买后标记已购 |
| 彩虹轨迹 | `fx_rainbow` | 永久特效 | 购买后标记已购 |
| 守护者/先行者/首席厨师 | `title_*` | 永久称号 | 购买后标记已购 |
| 双倍椰子券 | `boost_double` | 消耗品 | 设置 `shop_boostDoubleActive=true`，下次 `addCoconuts` 时自动×2消耗 |
| 连胜护盾 | `boost_streak` | 消耗品 | 设置 `shop_streakShieldExpiry`（+24h），漏打不断 Streak |
| 生命树加速 | `boost_tree` | 消耗品 | 立即注入 30 点 `injectedEnergy`，触发升级检测 |

**消耗品不标记 `purchasedSet`，可重复购买**。

### 15.4 QuestManager.addCoconuts 双倍券接入

正向奖励（amount > 0）时：检测 `UserDefaults["shop_boostDoubleActive"]`，激活则 `finalAmount *= 2`，日志标题前缀"⚡️双倍券激活！"，消耗标记（`removeObject`）。

---

## 十六、UI 优化与业务逻辑拓展（2026-03-09）

### 16.1 生命之树风车布局 + 风动特效 — `BeautifulCoconutTree.swift`

**重构树冠树叶为风车状布局**：
- 每片 `LeafShape` 使用 `360.0 / leafCount * i` 均匀散开，`.rotationEffect(.degrees(spokeAngle), anchor: .leading)` 使叶片从中心向外辐射
- 新增 `@State private var isSwaying: Bool = false`，`onAppear` 时设为 `true`
- 树冠整体 `.rotationEffect(.degrees(isSwaying ? 3.0 : -3.0), anchor: .bottom)` + `.animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isSwaying)` 实现微风摇曳
- 删除旧的 `startSway()` 方法（原依赖 `swayAngle` @State 驱动）

### 16.2 测试资金注入 — `OhanaApp.swift`

`init()` 中添加（TODO 标记，测试完毕后移除）：
```swift
// TODO: 测试完毕后移除
UserDefaults.standard.set(10000, forKey: "coconutCount")
```

### 16.3 宠物卡片破框显示 + 精简信息 — `CritterDeckCarousel.swift`

**透明 PNG 破框**：
- 提取 `isTransparent` 变量，将卡片结构改为外层 `ZStack`
- 内层 `ZStack + .clipShape(RoundedRectangle)` 包含卡片背景、普通图头像、文字信息
- 透明 PNG 图层放在 `.clipShape` 之外叠加，`frame(height: cardHeight * 1.25)` + `frame(height: cardHeight, alignment: .bottom)` 实现底部对齐、向上溢出杂志封面效果

**精简信息**：删除品种/性别 `Text(pet.breed)` 胶囊，右侧 `VStack` 仅保留名字。

### 16.4 Quick Access 全物种补全 `.play` — `ArkCrewIDCardView.swift`

`QACardType.available(for:)` 更新：
- 鸟类 (`鸟/鹦鹉/文鸟/鸽子`)：新增 `.play`
- 爬宠 (`蜥蜴/蛇/龟/变色龙/壁虎`)：新增 `.play`
- `default`：新增 `.play`
- 猫咪已有 `.potty` + `.play`，狗已有 `.play`，无需修改

`.play` 点击触发 `performSpecialCareCheckIn(.play)` → `QuestManager.awardAction(.general(humanReward:10, petReward:12))` 写 `PetCareLog(.play)`。

### 16.5 一键全家自定义数据源 + 编辑 Sheet

**新建 `BatchAction.swift`（`Models/`）**：
- `BatchActionType` 枚举：`feed / water / potty / litter / play`，含 `label / emoji / colorHex`
- `BatchAction` 结构体（`Identifiable, Codable`）：`targetPets(from:)` 按物种过滤，`perform(pets:context:)` 调用 `QuestManager.batchAward`
  - `litter` → `batchAward(.general(humanReward:5, petReward:8, emoji:"🧹", title:"铲砂打卡"))`
  - `play`   → `batchAward(.general(humanReward:10, petReward:12, emoji:"🎾", title:"陪玩打卡"))`
- `BatchActionEditSheet`：网格多选，选中高亮，"完成"按钮 goLime 色
- `static var defaults`: `[feed, water, potty, litter]`

**`OverviewView.swift` 重构**：
- 新增 `@AppStorage("customBatchActions") private var customBatchActionsJSON: String`
- `customBatchActions` 计算属性：JSON 解码，空值回退到 `BatchAction.defaults`
- `batchCheckInBar` 改为 `ScrollView(.horizontal) + ForEach(customBatchActions)`，末尾 ⚙️ 编辑按钮弹出 `BatchActionEditSheet`

**`QuestManager.batchAward`** 新增 `case .general` 中 `含"铲砂/铲屎"` → `careTypeEnum = .litter`，`含"陪玩/逗玩"` → `careTypeEnum = .play`。

---

## 第十七章：UI/UX 深度修复与视觉升级（2026-03-09）

### 17.1 头像裁剪框错位根本修复（AddPetWizardView）

**根本原因**：旧版 `PetImageCropView` 用 `GeometryReader + .ignoresSafeArea()` 让图片层包含 safe area，但 `ZStack` 内的覆盖层（取景框）受 safe area 约束，造成坐标系偏移。

**修复方案（`AddPetWizardView.swift` 底部 `PetImageCropView`）**：
- 废弃 `GeometryReader + .ignoresSafeArea()`，改为外层 `GeometryReader` 只读尺寸
- 内层 `ZStack` 统一使用 `.scaledToFit` + `.frame(width:height:)` —— 图片层、遮罩层、取景框描边全在同一 ZStack，坐标系完全一致
- `performCrop(in:)` 接收 `geo.size`，基于 `scaledToFit` 数学精准反算裁剪区域
- 取景框描边改为 `goLime` 颜色

**粘贴优先高亮**：
- `hasPasteboardImage` 改用 `UIPasteboard.general.hasImages`
- 剪贴板有图时：粘贴按钮背景 `Color.goLime`（黑字），无图时：灰色半透明（弱化）
- 三种入口（相册/拍照/粘贴）全部 → `cropImageItem = IdentifiableCropImage(image:)` → 进取景框，sheet 改为内嵌 `PetImageCropView` 的 `NavigationStack`

### 17.2 宠物卡片正面头像融合（CritterDeckCarousel）

**普通图（非透明 PNG）**：
- 改用 `.mask(LinearGradient(...))` 从左到右羽化：`clear(0) → black(0.12) → black(1.0) → black(0.72) → clear(1.0)`
- 宽度从 `cardWidth * 0.55` 扩至 `0.62`，移除旧的底部 overlay 渐变

**透明 PNG 破框层**：保持 `clipShape` 外叠加，无 border/stroke，真正杂志封面效果

### 17.3 Quick Access 修复（已验证完整）

`QACardType.available(for:)` 中：
- 猫咪：`[.litter, .feed, .water, .potty, .play, ...]` — `.potty` 和 `.litter` 并存
- 所有物种均包含 `.play`（鸟类、爬宠、default 均已添加）

### 17.4 一键全家 Bento 网格 Premium 升级（OverviewView）

旧版 `HStack + ScrollView pill` 改为完整 Bento 风格：
- **容器**：`.ultraThinMaterial` 毛玻璃 + `LinearGradient strokeBorder` 光边框 + `goPrimary` 外阴影
- **标题行**：`bolt.fill`（goLime）+ "一键全家" + 右侧"自定义"胶囊按钮
- **网格**：`LazyVGrid` 最多4列，每格圆形图标 + 动作名
- **按下效果**：`batchPressedId` 状态跟踪，按下时圆形背景加深 + `shadow(radius: 8)` 发光 + `scaleEffect(0.94)` 弹性缩放
- 保留 `BatchActionEditSheet` 自定义配置入口

### 17.5 测试资金 & 扭蛋机（OhanaApp / GachaView）

- `OhanaApp.init()` 已写入 `UserDefaults.standard.set(10000, forKey: "coconutCount")`
- `GachaView.swift` 已完整实现：扣除椰子 → 旋转动画（1.2s）→ `GachaPrize.roll()` 权重随机（普通55/稀有30/史诗12/传说3）→ 写入 `@AppStorage("gachaHistory")` → 展示结果卡 + 历史网格

### 17.6 椰子树形状精确还原（BeautifulCoconutTree）

**`TrunkShape`**：精确还原 SVG Q 曲线，`control` 点 x 坐标改为 `startX + bend`（垂直二阶贝塞尔，与 React 版一致）

**`LeafShape`**：精确还原 SVG `M0,0 C30,-40 80,-20 100,20 C60,0 30,-10 0,0`，用 `sx/sy` 映射至 `rect`，原点在左上角 `(0,0)`；`rotationEffect` anchor 改为 `.topLeading`（从叶根向外辐射）

**`CoconutView`**（替换旧 `CoconutShape`）：含椰子主体 Ellipse + 下半阴影遮罩 + 3个椰眼 Circle + 满级高光 blur；`isMax` 时金色（`#FBBF24`），普通时棕色（`#8B4513`）；主视图中直接 `.offset(x:y:)` 定位，无需 fill

---

## 第十八章：宠物卡片动态视觉策略 + 反农场机制（2026-03-09）

### 18.1 宠物卡片正面动态视觉策略（ArkCrewIDCardView）

**核心逻辑**：`cardFrontView` 当前保留 `minimalFront` 作为极简风格分支；非 minimal 分支统一进入 `posterFront(geo:avatarImage:isTransparent:)`，整体视觉参考 GO 运动海报卡。

**GO 海报卡（`posterFront`）**
- 底色：`#233BFF → #141FAE` 蓝色渐变 + 底部黑色覆膜
- 超大背景字位于卡片**上半部分居中**（`offset(y: -h*0.22)`）
- **左半：头像主体层**（`posterSubjectLayer`），宽度 52%，贴左/上/下边缘，`clipped()` + `frame(alignment: .leading)`
- **右半：文字信息列**（`.trailing` 对齐）：连胜胶囊 → Spacer → `daysTogether` 大数字 → "Days Together" → 年龄品种副文案 → `posterBarcode` 条码区
- `pet.currentStreak > 1` 时，在右上显示 goLime 连胜胶囊

**主体渲染规则**（`posterSubjectLayer`）
- 透明 PNG：贴纸白边效果，`scaledToFit` 填满左半区域底部对齐
- 普通照片：`scaledToFill` 填满左半 52% 宽度全高，右侧 `LinearGradient` mask 羽化渐隐（65% 实色→100% 透明），叠加 screen 高光与主题色混合
- 无头像：`PetSilhouetteView` 居中于左半区域，根据 `pet.coatColor` / `pet.eyeColor` 着色

**翻转动画**：`rotation3DEffect(.degrees(flipped ? 180 : 0), perspective: 0.4)` + `.easeInOut(duration: 0.4)`，模拟物理翻卡效果

**前面板固定元素**
- `posterDetailButton`：右上半透明 capsule 详情按钮
- `flipHint`：左下翻面提示图标
- `rainbowBridgeFrontOverlay`：离世宠物的彩虹桥遮罩仍完整保留

### 18.2 TASK A：打卡冷却机制（QuestManager）

**冷却规则**（`cooldownDuration(for:)`，static）：
- `.feed` / `.water`：4 小时
- `.potty`：2 小时
- `.care`（bath/teeth/nails/brushing/ears）：24 小时
- `.general`：2 小时
- `.walk` / `.health` / `.expense` / `.milestone`：无冷却

**持久化**：`UserDefaults`，key `quest_cooldownLogs`，格式 `[String: Double]`（petId_actionKey → Unix timestamp）

**核心方法**：
- `isOnCooldown(petId:type:) -> Bool`：公开查询
- `cooldownRemaining(petId:type:) -> TimeInterval`：剩余秒数
- `recordCooldown(petId:type:)`：私有，只在 SwiftData 持久化成功后调用
- `awardAction` 入口门卫：冷却期内直接 `return (0, 0)`

### 18.3 TASK B：遛狗 GPS 20m 门槛（PetWalkingManager）

`stop()` 中：距离 `< 20.0m` → `earnedCoconuts = 0`，跳过 `awardAction(.walk)`。日志和地图快照正常保存。

### 18.4 TASK C：Streak 里程碑奖励（StreakRewardManager）

**新建** `Models/StreakRewardManager.swift`（`@Observable` 单例）：

| 里程碑 | 天数 | 奖励 |
|--------|------|------|
| 初级连击 | 7天 | +20🥥 |
| 月度连击 | 30天 | +100🥥 |
| 百日连击 | 100天 | +500🥥 |
| 年度传说 | 365天 | +2000🥥 |

- 防重复：`UserDefaults` key `streakRewards_claimed`，`{petId_days: timestamp}`
- 调用时机：`QuestManager.awardAction` 持久化成功后 `StreakRewardManager.shared.checkAndAward(pet:)`
- `lastMilestone` 属性：View 层可监听，显示 Toast + 震动反馈

**保护盾接入**（`StreakManager.refreshStreak`）：
- 超过1天未打卡时，检查 `shop_streakShieldExpiry`（Date）
- 有效期内：streak +1 而非重置，消耗标记（removeObject）

### 18.5 TASK D：扭蛋机补打卡券（GachaView + BackdateCheckInSheet）

**新奖品**（`GachaPrize.allPrizes`）：
- `r_backdate_1day`（稀有，权重8）：昨日补打卡券
- `e_backdate_3day`（史诗，权重3）：三日补打卡券

**结果卡**：`isBackdatePass == true` 时显示「立即使用补打卡券」按钮，弹出 `BackdateCheckInSheet`

**`BackdateCheckInSheet.swift`**（新建，`Views/Details/`）：
- 选择宠物（`@Query` 获取活体宠物）
- 选择打卡类型（喂食/喂水/便便/散步）
- 选择目标日期（1-N 天前，N = `backdateDays`）
- 提交调用 `QuestManager.shared.awardAction`（仍受冷却规则限制）
- 成功界面显示获得椰子数

### 18.6 TASK E：椰子商店新商品（CoconutShopView）

新增 `.boost` 分类商品：

| 商品 | ID | 价格 | 效果 |
|------|-----|------|------|
| Streak 保护盾 | `boost_streak` | 50🥥 | 写 `shop_streakShieldExpiry`（+24h）|
| 补打卡包 | `boost_backdate_pack` | 120🥥 | `inventory_backdate_1day_count` +3 |
| 冷却重置券 | `boost_cooldown_reset` | 80🥥 | `removeObject(quest_cooldownLogs)` |

### 18.7 宠物添加向导 — 头像步骤 UX 重构（AddPetWizardView Step 2）

**目标**：强力引导用户上传透明抠图（触发破框悬浮卡片效果），优化粘贴体验。

**新增 State 变量**：
- `pasteBreathing: Bool` — 驱动呼吸动画（`onAppear` 启动无限循环）
- `isPasting: Bool` — 控制加载态显示

**`avatarPreviewBadge`**：
- 透明抠图（`isTransparentPNG == true`）时，右上角叠加 `sparkles` 徽标（goLime 图标 + 黑色圆背景）
- 普通图：`scaledToFill + clipShape`
- 无图：首字母 + 主题色

**`proTipBanner`（任务一）**：
- `wand.and.stars` 图标，goLime 圆形背景
- 标题：`✨ 解锁 3D 悬浮卡片效果`（black 字重）
- 正文富文本：`长按宠物主体并拷贝` 高亮为 goLime 色（`.foregroundColor(Color.goLime)`）
- 背景：`goLime.opacity(0.10)` 圆角卡 + `goLime.opacity(0.28)` 描边

**`pastePrimaryButton`（任务二 + 三）**：
- **有图状态**：goLime → `Color(hex:"A8E44A")` 渐变背景；呼吸发光 shadow（`pasteBreathing` 切换 opacity 0.15→0.55, radius 6→18）；文案「立刻粘贴剪贴板图片」；右箭头 `scaleEffect` 随呼吸缩放
- **无图状态**：`white.opacity(0.08)` 弱化背景；文案「从剪贴板粘贴抠图」；白色细描边
- **加载态**（`isPasting == true`）：`ProgressView(.circular)` + 「正在处理…」代替内容
- 按钮完全自定义（`.buttonStyle(.plain)`），不用系统按钮样式

**`secondaryPhotoRow`（任务二）**：
- 相册（`PhotosPicker`）+ 拍照并排，`RoundedRectangle(cornerRadius:14)` 半透明背景
- 字号 13pt / `white.opacity(0.75)`，明显弱于主 CTA

**`pastePasteboardImage()`（任务三）**：
1. `guard UIPasteboard.general.image` — 无图时 error haptic
2. `UIImpactFeedbackGenerator(.medium).impactOccurred()` — 有图时触觉反馈
3. `isPasting = true` — 显示加载 UI
4. `DispatchQueue.main.asyncAfter(0.15s)` → `cropImageItem = IdentifiableCropImage(image:)` — 直达裁剪框
5. `isPasting = false`

---

## 第十九章：Bug Fix & UX 优化批次（2026-03-09 续）

### 19.1 Quick Access 卡片首次加载为空修复（ArkCrewIDCardView）

**根本原因**：`QAConfig.load(for:)` 无存储时返回 `[]`，导致新宠物或未配置宠物的 Quick Access 区域完全空白，`.potty` 和 `.play` 等卡片从未显示。

**修复**（`ArkCrewIDCardView.swift`）：
- `QAConfig.load(for:species:)` 增加 `species: String = ""` 参数
- 无 UserDefaults 数据时：`species.isEmpty ? [] : QACardType.available(for: species)`
- `onAppear` 调用改为 `QAConfig.load(for: pet.id, species: pet.species)`
- 效果：所有新宠物首次打开 Quick Access 直接显示对应物种的完整默认卡片（猫：litter/feed/water/potty/play/care/health/expense/weight）

### 19.2 健康详情页 sheet 死锁修复（PetHealthDetailView）

**根本原因**：`PetHealthDetailView` 从 `OverviewView` 的 `.sheet` 呈现，包在 `NavigationStack` 内，但 toolbar 只有 PDF 导出和新增按钮，无关闭入口。

**修复**（`PetHealthDetailView.swift`）：
- 新增 `@Environment(\.dismiss) private var dismiss`
- `toolbar` 新增 `ToolbarItem(placement: .topBarLeading)`：`xmark.circle.fill` 按钮，`foregroundStyle(.white.opacity(0.5))`

### 19.3 取景框最小缩放比例放宽（AddPetWizardView）

**修复**（`PetImageCropView.minScale`）：
```swift
private var minScale: CGFloat {
    guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return 0.5 }
    let fitMin = max(cropSize / fitDisplaySize.width, cropSize / fitDisplaySize.height)
    return min(fitMin, 0.5)
}
```
- 允许缩到 0.5x，用户可把大图整体缩小到取景框内，而不强制长边覆盖

### 19.4 AddHumanWizardView 确认页主题色选择器

**新增**（`AddHumanWizardView.swift`）：
- `@State private var themeColorHex: String = "667eea"`
- `private let themeColorOptions: [(String, String)]` — 8 种预设色（靛蓝/珊瑚/海洋/青柠/蜜桃/薰衣草/薄荷/晚霞）
- Step 9 确认页：
  - 头像 emoji 右下角叠加 22pt 主题色 `Circle`（`ZStack(alignment: .bottomTrailing)`）
  - 横向 `ScrollView` 展示 8 个色块按钮，选中有 `strokeBorder(.white, lineWidth:2.5)` + `shadow(radius:8)` + `scaleEffect(1.15)`
- `saveHuman()` 中 `human.themeColorHex = themeColorHex` 写入模型

### 19.5 粮食管理价格记账 + 支付人联动（PetFoodManagementView）

**新增状态**：
- `@State private var stockPriceInput: String = ""`
- `@State private var stockPayerId: String = ""`
- `@Query(sort: \Human.createdAt) private var allHumans: [Human]`

**UI**（库存编辑表单末尾，在"每日份量"后）：
- `inputRow(icon: "yensign.circle.fill", label: "购买价格(¥)", color: .goLime)` — 可选填，`.decimalPad`
- 价格有效时展示横向支付人 Picker（胶囊按钮，选中 goLime 底色黑字）

**`saveStock()` 逻辑**：
```swift
if let price = Double(stockPriceInput...), price > 0 {
    let expenseLog = PetExpenseLog(date:, amount: price, category: .food,
                                   note: "购买 \(brandNote)", pet: pet, executorId: payerId)
    modelContext.insert(expenseLog)
}
// 清空 stockPriceInput / stockPayerId
```

### 19.6 一键全家 AppStorage 开关 + 多巴胺 Bento 升级（OverviewView）

**开关**：
- `@AppStorage("showBatchCheckIn") private var showBatchCheckIn: Bool = true`
- 条件渲染：`if showBatchCheckIn && pets.filter({ !$0.hasPassedAway }).count > 1`
- 外部（如设置页）可通过 `UserDefaults.standard.set(false, forKey: "showBatchCheckIn")` 关闭

**`batchBentoCell` 多巴胺升级**：
- 图标容器改为 `48×48 RoundedRectangle(cornerRadius:14)` + `LinearGradient([action.color.opacity(0.75), action.color.mix(.black,0.25)])` 渐变填充
- 按下时 `shadow(radius:12)` + `scaleEffect(1.15)` emoji 跳动
- cell 外层 `scaleEffect(0.93)` 弹性按压

### 19.7 GenericWeightEntrySheet 多巴胺配色升级

**背景**：三色 `LinearGradient(goDarkBlue, accentColor.opacity(0.35), goPrimary.opacity(0.6))`
**装饰圆**：`Circle().fill(accentColor.opacity(0.12)).frame(280).offset(x:100,y:-120).blur(40)`
**标题行**：`scalemass.fill` 图标圆（`accentColor.opacity(0.2)` 背景）+ 文字
**输入卡片**：渐变 `strokeBorder`（有效时 `accentColor.opacity(0.8)→0.1`）+ `shadow(accentColor.opacity(0.25), radius:12)`
**保存按钮**：`LinearGradient([accentColor, accentColor.mix(.white,0.15)])` + `shadow(accentColor.opacity(0.45), radius:14)` + checkmark 图标前缀

### 19.8 OasisRewardView 椰子树环境光晕 + 采摘交互闭环

**新增状态**：
- `@State private var glowBreathing: Bool = false`
- `@State private var flyCoconut: Bool = false`
- `@State private var flyOpacity: Double = 0`

**环境光晕**（`treeSection` 内）：
- `RadialGradient` 圆（`glowBreathing ? 0.28 : 0.08` opacity，`scaleEffect 1.08↔0.92`）`.easeInOut(2.4s).repeatForever`
- `Circle().stroke(Color.goLime.opacity(...))` 外圈发光轮廓，`blur(radius: 6↔2)`
- `BeautifulCoconutTree` 树本体添加 `.shadow(Color.goLime.opacity(0.15↔0.45), radius: 10↔24)`

**采摘气泡升级**：
- 渐变背景 `LinearGradient([goYellow, FFB800])`
- 主文案「点击采摘今日推落」+ 副文案「+N 椰子」+ `arrow.up.circle.fill` 图标
- 呼吸 `scaleEffect(1.06↔1.0)` 脉冲

**椰子飞出动画**：
- 点击后：`flyCoconut = false → true`（offset y: -60 → -280，spring 0.55）
- 同时 `flyOpacity: 1 → 0`（easeOut 0.3s delay 0.6s）
- `UIImpactFeedbackGenerator(style: .heavy).impactOccurred()` 重触觉反馈
- `onAppear` 启动 `glowBreathing` 呼吸循环

---

## 第二十章：深度 Bug 修复 + UI 重构（2026-03-09）

### 20.1 Quick Access 黑名单机制修复（ArkCrewIDCardView）

**根因**：旧版 `QAConfig` 保存的是**激活列表**，新增的 `.potty`/`.play` 不在旧数据中，导致用户升级后永远看不到新卡片。

**修复方案**：改为**黑名单机制**（保存用户主动移除的卡片）：
- `storageKey` → `"qaExcluded_<petId>"`（新键，与旧键不冲突）
- `QAConfig.load(for:species:)` → 返回 `QACardType.available(for: species)` 减去黑名单，确保新卡片自动出现
- `QAConfig.exclude(type:for:)` / `QAConfig.unexclude(type:for:)` 替代旧 `save/remove`
- 迁移逻辑：检测旧激活列表键，首次启动将其差集转化为黑名单，删除旧键
- `SpeciesCheckInGrid.removeCard` → `QAConfig.exclude`；`QAAddPanel` → `QAConfig.unexclude`
- `onAppear` 改为 `QAConfig.load(for: pet.id, species: pet.species)` 带 species 参数

### 20.2 PetHUDVitalSection @Query 数据同步（PetDetailView）

**根因**：`walkLogsQ` predicate 只覆盖今日，但 7 天点阵需要一周数据；`dogHUD` 的点阵仍用 `pet.walkLogs` 非响应式数据。

**修复**：
- `walkLogsQ` predicate 改为 `>= weekStart`（过去7天）
- `todayWalks` 从 `walkLogsQ.filter { Calendar.current.isDateInToday($0.date) }.count`
- `weekWalks = walkLogsQ.count`
- 7天点阵 `active` 全改用 `walkLogsQ`，消除 `pet.walkLogs` 直接引用
- `todayFeed` predicate 改用 `todayStart` 而非二次 `isDateInToday` 过滤

### 20.3 一键全家 Minimalist 化 + 首页模块排序严格绑定

**batchCheckInBar 重构**：
- 从 VStack（标题行 + Bento 网格）重构为 **44pt 高胶囊条**
- 结构：`[⚡全家] | [ScrollView 水平动作胶囊] | [⚙️]`
- `batchPillButton`：emoji + 文字胶囊，按下时背景变实色 + `scaleEffect(0.93)` + spring 动画
- `.background(Capsule().fill(.ultraThinMaterial).overlay(strokeBorder))` + `shadow`

**首页信息层级（产品动线，第三十六章重构后）**：

```
GlobalHeader（固定悬浮）
  └─ PetWalletStack（宠物/家庭成员 Wallet 堆叠）
  └─ ⚠️ emergencyAlertBanner（仅 .urgent 级别时显示，Color.goRed 实色）
  └─ quickAccess（快捷操作网格，高频执行区）
  └─ batchCheckIn（一键全家，多宠时显示）
  └─ todayTasks（今日任务 SmartToday + DailyQuestsCard）
  └─ homeModule（岛屿总览 HomeBentoBoxes：生命之树/打卡连击）
  └─ memoryDrop（记忆碎片 MemoryDropCard，情感分割带，可侧滑关闭）
  └─ islandStats（岛屿统计横向 ScrollView，低频浏览区）
```

**实现机制**：
- `sectionOrderRaw` 默认：`"quickAccess,batchCheckIn,todayTasks,homeModule,memoryDrop,islandStats"`
- `mainScrollView` 使用 `ForEach(orderedSections)` + `switch` case 渲染
- `memoryDrop` 从硬编码顶部迁移为可排序 section，沉至底部
- `emergencyAlertBanner`：`PetHealthAlertEngine.shared.scanAlerts` 扫描当前顶牌宠物，仅过滤 `.urgent`，无 glassEffect，内容 `.white` 粗体
- **旧用户迁移**：`.onAppear` 检测到无 `memoryDrop` 时强制重置为新标准顺序
- `HomeSectionEntry.defaults` 包含 6 个条目，可在 `HomeSectionManageSheet` 拖拽排序/显隐

### 20.4 AddMilestoneSheet + AddDocumentSheet 多巴胺风格统一

**共同设计语言**：
- 深色渐变背景：`LinearGradient([goDarkBlue, 深紫/深蓝, accent.opacity(0.4)])`
- 右上角装饰圆：`Circle().fill(accent.opacity(0.08)).blur(40)`
- 把手：`.white.opacity(0.2)` Capsule
- 输入框：`.white.opacity(0.08)` 背景 + `.white.opacity(0.12)` 边框，激活时改为 accent 色边框
- `DatePicker` 统一 `.colorScheme(.dark)`
- 保存按钮：`LinearGradient` 渐变 + `shadow(accent.opacity(0.4), radius:10)` + checkmark 图标

**AddDocumentSheet 新增**：
- `docField<Content>` 辅助函数：图标+标签+毛玻璃容器，统一所有输入行样式
- 证件类型选择胶囊：选中态改为 `Color.goTeal`（深色背景下更醒目）
- `.preferredColorScheme(.dark)`

### 20.5 MiniFlipCard 杂志破框极简化（CritterDeckCarousel）

**目标**：AllCardsSheet 内缩略卡只展示名字，无任何数据。

**变更**：
- Pet 卡正面右侧 VStack：移除所有品种/年龄字段，名字字号从 `15pt` 升至 `18pt .heavy`
- Human 卡正面右侧 VStack：移除 `Text(human.roleText)`，名字字号升至 `18pt .heavy`
- 破框设计（透明PNG溢出）保持不变

### 20.6 绿洲打卡日历 + 补签系统（OasisRewardView）

**状态管理**：
```swift
@State private var checkedInDates: Set<String> = []   // "yyyy-MM-dd" 格式
@State private var makeupPackCount: Int = 0            // 补签包数量
@State private var showMakeupConfirm: String? = nil    // 待确认补签日期
@State private var makeupDates: Set<String> = []       // 补签过的日期集合
@State private var calendarDisplayMonth: Date = Date() // 当前显示月份
private let checkedInKey = "oasis_checkedIn_dates"
private let makeupDatesKey = "oasis_makeup_dates"
private let makeupPackKey = "inventory_backdate_1day_count" // 与椰子商店统一 key
```

**打卡日历卡片** (`checkInCalendarCard`)，以 `.medium` sheet 弹出：
1. **标题行**：`calendar.badge.checkmark` + "打卡日历" + 连胜胶囊（🔥 N天连胜，goYellow）
2. **统计面板** (`checkInStatsRow`)：4 格横排迷你卡
   - 总打卡（checkmark.circle.fill / goLime）
   - 当前连胜（flame.fill / goYellow）
   - 最长连胜（trophy.fill / goOrange）
   - 本月打卡率（chart.bar.fill / goCardCyan）
3. **月份导航**：chevron.left / chevron.right 切换月份，不可翻到未来月
4. **星期标题行**：日一二三四五六
5. **月视图网格** (`CalendarCell` 模型 + `monthCalendarCells(for:)`)：
   - 正确按星期对齐（前置空位）
   - 正常打卡 → goLime 实心圆 + checkmark.black
   - 补签 → goYellow.opacity(0.85) 实心圆 + arrow.uturn.backward 图标
   - 今日 → goLime.opacity(0.22) + goLime 边框
   - 未来日期 → 白色极低透明度，禁用
   - 可补签日期（有补签包且未打卡且非未来）→ 可点击触发补签确认
6. **补签包区域**：显示数量；有包时提示"点击灰色日期补签"；无包时"去商店购买 →"按钮跳转椰子商店
7. **里程碑奖励** (`checkInMilestoneRow`)：5 档（7天+3🥥 / 14天+5🥥 / 30天+10🥥 / 60天+20🥥 / 100天+50🥥），可领取时显示 goLime 按钮

**自动打卡逻辑**：
- `onAppear` → `loadCheckInData()` + `triggerTodayCheckIn()`
- `triggerTodayCheckIn()`：首次当天自动记录 + 奖励1椰子
- `currentStreak`：从今日向前遍历连续打卡天数
- `longestStreak`：排序所有打卡日期，找最长连续段
- `monthCheckInRate`：本月已过天数中打卡天数占比

**补签逻辑** (`applyMakeup`)：
- 消耗1个补签包（`inventory_backdate_1day_count` 减1）
- 同时写入 `checkedInDates` 和 `makeupDates`
- `confirmationDialog` 确认后执行

**Bento Grid 入口**：全宽打卡日历卡（📅 + 连胜/总天数），点击打开 sheet

**补签包获取**：椰子商店 `boost_backdate_pack`（120🥥，+3张）→ `inventory_backdate_1day_count`

### 20.7 护理详情长按弹计划 Sheet（PetHygieneDetailView）

**`HygieneType` 添加 `Identifiable`**（`PetHygieneLog.swift`）：
```swift
enum HygieneType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    ...
}
```

**`PetHygieneDetailView` 修改**：
- 新增 `@State private var groomingPlanTarget: HygieneType? = nil`
- `hygieneTypeCard` 卡片末尾添加 `.onLongPressGesture(minimumDuration: 0.5) { UIImpactFeedbackGenerator(.heavy); groomingPlanTarget = type }`
- `.sheet(item: $groomingPlanTarget)` → `HygieneTodoSheet(pet: pet, type: hygieneType)` + `[.medium, .large]` detents

---

## 二十一、深度 Bug 修复 + UI 精修（2026-03-08）

> **编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)

### 21.1 Quick Access 陪玩 / 粑粑缺失（ArkCrewIDCardView）

**根因**：`QAConfig.loadExcluded` 的旧版激活列表迁移逻辑错误——迁移时用 `QACardType.allCases` 作为基准，导致所有新增卡片（`.play`/`.potty` 等旧版数据里不存在的类型）被误加入黑名单。

**修复**：
```swift
// 修复前：
let allKnown = QACardType.allCases
let excluded = allKnown.filter { !legacyCards.contains($0) }

// 修复后：只用该物种的 available 列表作为基准
let available = species.isEmpty ? QACardType.allCases : QACardType.available(for: species)
let excluded = available.filter { !legacyCards.contains($0) }
```
- `loadExcluded` 新增 `species: String = ""` 参数
- `load(for:species:)` 调用 `loadExcluded(for:species:)` 传入 species

### 21.2 首页模块管理优化（OverviewView + OverviewHelperViews）

- `HomeSectionEntry.defaults` 移除 `petCards` 条目（共 4 项）
- `showBatchCheckIn` 默认值改为 `false`
- `sectionOrderRaw` 默认值：`"batchCheckIn,quickAccess,islandStats,todayTasks"`
- `orderedSections` 和 `onAppear` 迁移逻辑均添加 `removeAll { $0 == "petCards" }`

### 21.3 取景框最大放大限制（AddPetWizardView）

新增 `maxScale` 动态计算属性：
```swift
private var maxScale: CGFloat {
    guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return 8.0 }
    let shortSide = min(fitDisplaySize.width, fitDisplaySize.height)
    return shortSide > 0 ? cropSize / shortSide : 8.0
}
```
`MagnificationGesture.onChanged` 由 `min(8.0, ...)` 改为 `min(maxScale, ...)`。

### 21.4 全家打卡 emoji 重复（OverviewView）

`batchPillButton` 中移除单独的 `Text(action.type.emoji)`，因 `action.label` 已定义为 `type.emoji + " " + type.label`。

### 21.5 图鉴卡片两列小卡（CrewRosterOverlay）

**网格布局**：`BentoPetGrid` / `BentoHumanGrid` 使用 `LazyVGrid` 两列（`GridItem(.flexible(), spacing: 12)` × 2）

**小卡片样式**（`PetSquareCard`）：
- 首页 `posterFront` 的等比例缩小版，宽高比 1.586:1，`cornerRadius: 16`
- 蓝色渐变背景（#233BFF → #141FAE）+ 暗色叠加
- 橙红色大字（宠物名 uppercase，字号 `w * 0.28`），居中偏上
- 左半区头像层（与首页完全一致的三种方案：透明抠图贴纸白边/普通照片右侧羽化/PetSilhouetteView 剪影）
- **无任何文字标签**（名字、物种、天数等全部去掉）
- 单击（`Button(action: onTap)`）直接触发 `onSelect` 进详情页
- 长按触发删除确认（输入宠物名确认）
- 长按 0.7s 弹出删除确认 alert（宠物需输入名字确认，人类一步确认）
- 按下缩放反馈 `scaleEffect(0.95)` + `spring(response:0.25)`

### 21.6 AddDocumentSheet UI 重构（AddDocumentSheet）

参考 `HygieneTodoSheet.settingRow` 风格重写：
- 移除多巴胺深色渐变背景，改用系统默认亮色背景
- `docRow` 辅助函数：`HStack(icon + label + Spacer + content)`，`systemGray6` 背景圆角卡片
- 证件类型 Chip 选择器：`goLime` 选中 + `arkInk` 文字（与护理计划频率选择器一致）
- 保存按钮：`goLime` 实色 + `arkInk` 黑字（与护理计划一致）
- 移除 `.preferredColorScheme(.dark)`

### 21.7 护理计划截止日期 bug（PetHygieneCard）

**根因**：`save()` 在 `repeatDays > 0` 时循环写入未来 180 天所有实例，导致日历塞满大量重复事件。

**修复**：改为写单个 `Event`，用 `recurrenceDays` 和 `recurrenceEndDate` 字段表达重复规则：
```swift
event.recurrenceDays = repeatDays
if hasEndDate {
    event.recurrenceEndDate = endDate
} else if repeatDays > 0 {
    event.recurrenceEndDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)
}
```

### 21.8 Island Stats 左滑提示（OverviewView）

`islandStatsBento` 标题行右侧添加弱提示：
```swift
HStack(spacing: 4) {
    Text("左滑查看更多").font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.25))
    Image(systemName: "chevron.left.2").font(.system(size: 9, weight: .bold))
        .foregroundStyle(.white.opacity(0.2))
}
```

### 21.9 绿洲页面布局调整（OasisRewardView）

| 子项 | 变更 |
|------|------|
| Bento 卡片缩小 | 新增 `bentoMiniCard` 函数（HStack 行式，高约 44pt）；替换原 `bentoBigCard` 的 4 个功能入口 |
| 打卡日历入口 | Header 右侧椰子数旁新增日历胶囊按钮（`calendar.badge.checkmark` + 连胜天数），点击弹出 `checkInCalendarCard` sheet |
| 椰子树下移 | `treeSection` padding.top 从 28 改为 60 |
| 日历 section 移除 | ScrollView 内移除独立的 `checkInCalendarCard` 区块，改由 sheet 弹出 |
| 新增状态 | `@State private var showCheckInCalendar = false` |

---

## 二十二、深度 Bug 修复 + 功能完善 P1-P10（2026-03-09）

### 22.1 P2：卡片风格选择（ArkSchemaV19）

**涉及文件**：`Pet.swift`、`SharedModelContainer.swift`、`AddPetWizardView.swift`、`ArkCrewIDCardView.swift`

- `Pet` 新增 `cardStyleRaw: String`，默认 `"classic"`，ArkSchemaV19 lightweight 迁移。
- `AddPetWizardView.confirm` 步骤新增双风格选择器（经典/简约），写入 `pet.cardStyleRaw`。
- `ArkCrewIDCardView.cardFrontView` 新增 `isMinimal` 分支，调用 `minimalFront`：
  - **经典**（默认）：原有三分支（透明抠图/模糊背景/emoji fallback）
  - **简约**：纯主题色渐变底 + 居中圆形头像/emoji + 底部信息条（名字+品种/物种胶囊+性别+相伴天数大字）
- `minimalPill(_ text: String, tc: Color)` 辅助组件。

### 22.2 P4：宠物信息页可编辑（PetBasicInfoDetailView）

**文件**：`Views/Details/PetBasicInfoDetailView.swift`（完全重构）

**结构**：
```
PetBasicInfoDetailView
├── body → avatarSection + readContent / editContent（根据 isEditing 切换）
├── avatarSection：头像圆形 + 名字 + 物种·品种 + "编辑中"胶囊（编辑时显示）
├── readContent：只读各 section（基本/外貌/健康/证件/血统/主题色/备注）
├── editContent：可编辑各 section（TextField/Picker/Toggle/DatePicker/LazyVGrid 主题色）
├── loadEditState()：将 pet 所有字段镜像到 eXxx 状态变量
└── saveChanges()：写回 pet，调用 modelContext.safeSave() + 触觉反馈
```

**Toolbar**：
- 浏览态：右上角 `pencil.circle.fill`（goLime）→ 进入编辑
- 编辑态：右上角「保存」（goLime）+ 左上角「取消」

**可编辑字段**：名字、物种（Picker）、品种、性别（Segmented）、绝育（Toggle）、生日、到家日、毛色、眼色、芯片号、兽医联系、过敏原、护照编号、护照有效期、曾用名、出生国家/城市、血统信息、主题色（10色预设+ColorPicker）、备注（多行）

### 22.3 P9：寄养名片数据同步（SitterCardPreviewSheet）

**文件**：`Views/Details/SitterCardPreviewSheet.swift`

基本信息区新增三行：
- **体重**：最新 `weightLogs` 排序后第一条，显示 `X.X kg · 日期`（`scalemass.fill` + goCardCyan）
- **年龄**：生日行追加 ` · pet.ageText`
- **出生地**：`pet.birthCountry + 城市`（`globe` + goMint），非空时显示

截图渲染时数据与宠物详情页完全一致。

### 22.4 P5/V18：PetMilestone.location 字段

**文件**：`SharedModelContainer.swift`

- `ArkSchemaV18`：`PetMilestone` 新增 `location: String`（默认 ""），V17→V18 lightweight 迁移。
- 里程碑详情页和地图跳转功能基于此字段。

### 22.5 P3：AddPetWizardView 主题色（确认）

`stepAppearance`（步骤8）已包含完整主题色选择器：
- `PetThemeColor.allCases` 预设色格（LazyVGrid 6列）
- 已用色显示 `xmark` 占位并 disabled
- 自定义 `ColorPicker`（clipShape Circle，scaleEffect 1.3）
- 预览行：色块 + `#HEX` 文字

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 二十三、Bug Fix + UI 重构 T1-T4（2026-03-09）

### 23.1 T1：Quick Access .play/.potty 顽固缺失修复

**根因**：旧版 `qaCards_<petId>` 激活列表迁移时，把"该物种 available 里但旧列表没有"的卡片全部加入黑名单，导致 `.play/.potty` 等新增卡片被误加入并永久生效。

**修复**（`ArkCrewIDCardView.swift` → `QAConfig.load`）：
```swift
let cleanedExcluded = excluded.filter { available.contains($0) }
if cleanedExcluded.count != excluded.count {
    saveExcluded(cleanedExcluded, for: petId)
}
return available.filter { !cleanedExcluded.contains($0) }
```
每次加载时自动清洗黑名单中不属于该物种 `available` 的历史脏数据，一次性生效无需手动重置。

### 23.2 T2：PetHealthDetailView 导航冲突与返回死锁

**根因**：`PetHealthDetailView` 被两条路径打开：
- `PetDetailView.navigationDestination` → push（系统返回按钮已存在）
- `ArkCrewIDCardView.sheet(isPresented: $showHealthSheet)` → sheet（需要 xmark 关闭）

原来始终显示 xmark，push 路径产生"双关闭按钮 + dismiss/nav 状态抢占"死锁。

**修复**：
- `PetHealthDetailView` 新增 `var isModal: Bool = false`
- `toolbar` 中 xmark 仅在 `isModal == true` 时显示
- sheet 调用改为 `PetHealthDetailView(pet: pet, isModal: true)`

### 23.3 T3：GenericWeightEntrySheet 风格对齐

移除多巴胺风格（三色渐变背景、装饰 Circle blur、渐变光边框、渐变保存按钮），改为与 `AddExpenseSheet` 完全一致：
- `ArkBackgroundView()` 深色背景
- 大数字 TextField（42pt .black）+ goLime 单位
- 简洁 HStack 行式日期/对象显示（`.white.opacity(0.06)` 背景，同 `docRow`）
- goLime 实色保存按钮（disabled 时 opacity(0.4)）
- 顶部 xmark 关闭按钮（同 AddExpenseSheet 标题栏样式）

### 23.4 T4：破框卡片改为 popout 特权 + 精简向导 + 商店联动

#### 卡片渲染逻辑（`ArkCrewIDCardView.cardFrontView`）
| 条件 | 渲染方案 |
|------|---------|
| `cardStyleRaw == "minimal"` | `minimalFront` |
| `cardStyleRaw == "popout" && isTransparent && avatarImage != nil` | `cutoutFloatFront`（破框悬浮，特权）|
| 有头像（普通照片） | `blurBackgroundFront`（**默认**）|
| 无头像 | `emojiFallbackFront` |

#### 精简 AddPetWizardView
- `stepAvatar` 移除 `proTipBanner` 和 `pastePrimaryButton`，只保留头像预览 + 相册/拍照 + 清除
- `stepConfirm` 移除 P2 添加的 cardStyle 选择器（不再在新建流程选择）

#### 椰子商店新品（`CoconutShopView`）
- 新增 `ShopItem(id: "fx_popout_card", emoji: "🃏", name: "3D 破框卡片", cost: 150, category: .effect)`（永久特效）
- 购买后自动弹出宠物选择器，跳转 `EquipPopoutCardSheet`

#### EquipPopoutCardSheet（新建文件）
**文件**：`Views/Components/EquipPopoutCardSheet.swift`

**UI 结构**：
```
EquipPopoutCardSheet
├── proTipBanner：三步引导（相册长按拷贝 → 返回粘贴）
├── pasteButton：呼吸光晕粘贴按钮（检测剪贴板）
├── 已激活状态行（cardStyleRaw == "popout" 时显示）
└── 恢复默认按钮
```

**激活逻辑**（`pasteAndActivate()`）：
1. 读取 `UIPasteboard.general.image`，无图给 error 震动 + Toast
2. 有图 → `Task.detached` 后台调 `ImageCutoutService.shared.removeBackground(from:)`
3. 降采样到 maxDim 1024，存为 PNG
4. 写入 `pet.avatarImageData` + `pet.cardStyleRaw = "popout"` + `modelContext.safeSave()`
5. heavy haptic + 成功 Toast → 1.8s 后 dismiss

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 二十三（续）、紧急修复 U1-U4（2026-03-09）

### U1：Quick Access 核弹强注入

**修改**（`ArkCrewIDCardView.swift` → `QAConfig.load`）：
```swift
var result = available.filter { !cleanedExcluded.contains($0) }
for card in available {
    if !result.contains(card) { result.append(card) }
}
return result
```
无论 UserDefaults 黑名单多脏，返回值**必然**包含该物种所有 `available` 卡片。猫的 `.potty`/`.play` 永远无法被排除。

### U2：GenericWeightEntrySheet 骨架对齐确认

上一轮（T3）已完成 `ArkBackgroundView` + `VStack(spacing:20)` + 标题 HStack（含 xmark）+ 大字 TextField + 日期行 + 对象行 + goLime 保存按钮骨架，与 `AddExpenseSheet` 100% 一致。本轮确认无需追加修改。

### U3：头像预览拉伸修复

**修改**（`AddPetWizardView.swift` → `avatarPreviewBadge`）：
- 非透明分支：`resizable → scaledToFill → frame(120×120) → clipShape(RoundedRectangle) → clipped()`
- 透明分支：`resizable → scaledToFit → frame(120×120) → clipped()`

两个分支均补 `.clipped()` 防止图片溢出 ZStack 父容器造成视觉拉伸变形。

### U4：宠物卡片花屏彻底修复

**根因**：`blurBackgroundFront` 层5 用 `.mask(LinearGradient)` 做右侧渐变消融。`.mask` 在 SwiftUI 底层调用 CoreGraphics clip 时，图片尺寸与渲染缓冲区字节未对齐会产生条形码花屏（iOS 已知渲染问题）。

**修复**（`ArkCrewIDCardView.swift` → `blurBackgroundFront` 层5）：
```swift
Image(uiImage: uiImage)
    .resizable().scaledToFill()
    .frame(width: geo.size.width * 0.62, height: geo.size.height)
    .clipped()
    .overlay(
        LinearGradient(stops: [...], startPoint: .leading, endPoint: .trailing)
            .blendMode(.destinationOut)
    )
    .compositingGroup()
```
用 `destinationOut` blendMode + `compositingGroup()` 实现等效渐变消融，且无渲染故障。

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 二十四、3D 堆叠玻璃卡片演示（2026-03-10）

### 新建文件：`PetDetailStackedDemoView.swift`

**功能特性**：
- **3D 层叠效果**：4 张磨砂玻璃卡片垂直堆叠，支持垂直拖拽切换
- **动态背景**：彩色 Blob 粒子动画，营造热带岛屿氛围
- **Dark/Light 模式**：右上角切换按钮，实时切换卡片透明度参数
- **卡片内容**：Overview（宠物基本信息）/Health（疫苗体检）/Diet & Care（卡路里饮食）/Records（运动记录）
- **3D 变换**：每张卡片具有独立的 Y 轴旋转、缩放、透明度，营造深度层次感

**技术实现**：
```swift
// 3D 变换参数
let offsetHeight = CGFloat(relativeIndex) * -60 + (isActive ? dragOffset : 0)
let scale = 1.0 - CGFloat(relativeIndex) * 0.1
let opacity = 1.0 - Double(relativeIndex) * 0.3
let yRotation = CGFloat(relativeIndex) * 15

// 应用变换
.offset(y: offsetHeight)
.scaleEffect(scale)
.opacity(opacity)
.rotation3DEffect(.degrees(Double(yRotation)), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
```

**入口位置**：`SettingsView.swift` → 开发者工具区 → "3D 堆叠卡片详情页"

---

## 二十五、SwiftData 迁移崩溃修复（2026-03-10）

### 崩溃症状

```
NSInvalidArgumentException: The current model reference and the next model reference cannot be equal.
```

在全新模拟器（iPhone 17 Pro Max）和真机首次安装时崩溃，无法被 `try?` 捕获。

### 根本原因

iOS 26 上 SwiftData 在**解析 `SchemaMigrationPlan.stages` 静态属性时**（早于任何 `try?` 执行），若发现相邻两个 schema 版本的 Core Data model hash 完全相同（例如 V9 和 V10 的 `models` 数组内容一致），立即抛出 `NSInvalidArgumentException`，导致 app 崩溃。

### 修复方案（`SharedModelContainer.swift`）

**1. 清空 stages：**
```swift
static var stages: [MigrationStage] { [] }
```
SwiftData 对"仅新增字段/模型"的迁移完全自动处理（Core Data lightweight migration），无需显式 stage。只有需要自定义数据转换时才需要 `.custom` stage。

**2. 三级降级策略：**
```swift
// 1st: 带 migrationPlan（老用户升级）
if let container = try? ModelContainer(for: schema, migrationPlan: ArkMigrationPlan.self, ...) { return container }
// 2nd: 不带 migrationPlan（全新安装 / iOS 26 兼容）
if let container = try? ModelContainer(for: schema, ...) { return container }
// 3rd: 内存模式（极端兜底）
return try ModelContainer(for: schema, isStoredInMemoryOnly: true)
```

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 二十六、终极玻璃卡片 UI 测试页升级（2026-03-10）

### 修改文件：`OhanaGlassUIV2DemoView.swift`

**修复内容**：
- **Light Mode 黑卡根因**：原 `ZStack` 背景始终是 `Color(hex: "0A0A0C")`，light mode 切换后 `.thinMaterial` 磨砂结果仍为黑色。修复：新增 `bgBase` 计算属性，dark=`#0A0A0C`，light=`#F0F4FF`（淡蓝白），blob 透明度随模式自动调整（深色时更高，浅色时降低）

**新增 16 张卡片，全量覆盖 App UI**：

| # | 卡片名 | 内容 |
|---|--------|------|
| 1 | Glass Parameters | 磨砂玻璃参数展示 |
| 2 | Typography System | 全字阶展示（metric→caption2） |
| 3 | Brand Color Palette | 8 色色板（goLime/goYellow/goOrange/goRed/goTeal/goMint/goBlue/goPurple） |
| 4 | Buttons | 主要/次要/危险/圆形快捷按钮 |
| 5 | Form Inputs | TextField/Picker/Toggle/Slider/Stepper |
| 6 | Chips & Tags | 过滤 Chip/InnerGlassTag/状态 Badge |
| 7 | Alert Banners | success/warning/error/info 4种横幅 |
| 8 | Pet Card | 宠物档案卡片（头像+名字+标签+三列统计） |
| 9 | Bento Stats | 大尺寸 Bento 统计格（步数/饮水/卡路里） |
| 10 | List Rows | 图标+标题+副标题+右值列表行 |
| 11 | Progress Ring | 圆环进度 + 多条进度条 |
| 12 | Charts | 折线+面积图 / 柱状图（Swift Charts） |
| 13 | Timeline | 时间轴竖线连接布局 |
| 14 | Empty State | 空状态（图标+脉冲动画+CTA按钮） |
| 15 | Toast / Undo | 3秒自动消失 Toast 触发演示 |
| 16 | Avatars & Badges | 头像叠加组/奖励徽标格子 |

**架构改进**：
- 每张卡片抽为独立 `private var card*: some View` computed property，主体 `body` 只保留布局骨架
- 公共 Helper：`divider`、`sectionTitle()`、`chipView()`、`statusBadge()`、`alertRow()`、`statCell()`、`bentoCell()`、`progressBar()`
- 整体切换动画：`.animation(.spring(response: 0.4, dampingFraction: 0.82), value: isDarkMode)` 驱动背景色平滑过渡

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 二十七、UltimateGlassCard Light Mode Material 根本修复（2026-03-10）

### 修改文件：`UltimateGlassCard.swift`

**根本原因**：`Material.fill` 的深浅由 **渲染树 parent 的 colorScheme** 决定，`.environment(\.colorScheme, .light)` 加在 `Rectangle` 或 `Group` 上对 material 本身无效。当系统在 dark mode 时，所有 `.thinMaterial` / `.ultraThinMaterial` 都渲染成深色，即使 Demo 页内部 `isDarkMode = false`，卡片依然是深色。

**修复方案**：将 light mode 背景路径拆分为独立 `else` 分支，**完全不依赖 material**：

```swift
if actualMode {
    // Dark: ultraThinMaterial + black/40
} else {
    // Light: ultraThinMaterial(.light env) + white/75→white/30 gradient
    // 白色渐变叠在彩色 blob 上，blob 颜色透过渐变产生毛玻璃透视感
}
```

Light mode 效果：
- 彩色 blob（goLime/goBlue/goPurple）透过 `white/75→white/35` 渐变形成彩色透视感
- 顶部高光 1.5px white/90 渐变线（Inset Top Highlight）
- 外阴影 radius 40，y 16，opacity 0.08（大范围柔和扩散）
- border white/40

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 二十八、Glass Card UI V2 + 设计系统规范升级（2026-03-12）

### 修改文件：`UltimateGlassCard.swift`

完整 8 层 Liquid Glass 折射系统实现（Ohana Design System V2）：

**Dark Mode — 8 层折射：**

| 层 | 名称 | 实现 |
|---|---|---|
| L1 | Blur Base | `.ultraThinMaterial`（iOS 系统原生折射引擎） |
| L2 | 微亮叠层 | `white/0.05` 补偿折射暗区 |
| L3 | Lens Rim | 上下渐变 `white/0.07` 8pt 范围，左右不设（单轴） |
| L4 | Edge Darkening | 径向 `black/0.07`，`.multiply` 混合 |
| L5 | 主边框 | `white/0.12`，0.5pt |
| L6 | Chromatic Aberration | 蓝色外沿 r24.5 `blue/0.07` + 红色内沿 r23.5 `red/0.05` |
| L7 | 顶部折射聚光线 | Capsule 0.5pt，中心 `white/0.55` 渐变 |
| L8 | Specular Highlight | 左上椭圆 110×70pt，`white/0.12→0.04→clear` RadialGradient |
| + | Caustics Shadow | `black/0.20 r20 y10` + `white/0.06 r30 y20` |

**Light Mode — 强制 Light Blur + 白色渐变：**

| 层 | 实现 |
|---|---|
| L1 | `ZStack(VisualEffectBlur(.light) + white/0.68→0.28 渐变)`，绕开 Material 的 colorScheme 继承 |
| L3 | Lens Rim：RadialGradient `clear→white/0.18`，`.screen` 混合 |
| L4 | Edge Dark：RadialGradient `clear→black/0.045`，`.multiply` 混合 |
| L5 | 对角渐变边框：`white/0.75→0.25`，TopLeading→BottomTrailing |
| L6 | Chromatic：`blue/0.04` |
| L7 | 顶部聚光线：`white/0.88`，较 Dark 更强 |
| L8 | Specular：`white/0.42→0.14→clear`，130×80pt |
| + | 双层阴影：`black/0.08 r32 y16` + `black/0.04 r6 y3` |

> **注意**：`cardBackground` 拆分为 `darkBackground`/`lightBackground` 及各 layer 独立方法，避免 Swift 编译器类型推导超时。

### 修改文件：`ArkBackgroundView.swift`

重写为设计系统 2.2 标准三球 Blob：
- 底色：`#0A0A0C`（Dark）/ `#F0F4FF`（Light）
- Blob 颜色：`goLime 260pt` / `goBlue 300pt` / `goPurple 220pt`
- 动画：8s/10s/9s `easeInOut` 独立漂移，`.repeatForever(autoreverses: true)`
- Opacity：Dark `0.55/0.45/0.55`，Light `0.35/0.25/0.30`

### 修改文件：`OhanaGlassUIV2DemoView.swift`

- 背景底色改为 `Color(hex: isDarkMode ? "0A0A0C" : "F0F4FF")`（移除独立 `bgBase` 属性）
- 保留双层 5 球 Blob（Layer1 7s / Layer2 11s），opacity 对齐设计系统规范

### 修改文件：`OverviewView.swift`（最新：iOS 26 规范升级）

**Island Stats**（`islandStatsBento`）：
- 去掉 `UltimateGlassCard` 包裹，图表直接浮在 `ArkBackgroundView` 动态背景上
- Section Header padding 改为 `.horizontal, 20` 与页面对齐
- 依据 `iOS26_Design_Guide.md`：大面积数据区/内容卡片不使用 Liquid Glass

**QuickAccess**（`quickActionsSection`）：
- `UltimateGlassCard` → `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))`

**BatchCheckIn 条**（`batchCheckInBar`）：
- `.regularMaterial + strokeBorder` → `.glassEffect(.regular, in: Capsule())`

### 修改文件：`OverviewHelperViews.swift`（最新：FloatingDockNav iOS 26 升级）

- `HStack + .regularMaterial + strokeBorder` 全面重写为 `GlassEffectContainer + .glassEffectID(idx, in: dockNamespace)` morphing
- 选中态：`.regular.tint(Color.goLime.opacity(0.18))`
- 加入 `UIImpactFeedbackGenerator(style: .light)` 触觉反馈
- 选中指示点 `Circle` 加 `.transition(.scale.combined(with: .opacity))`

**iOS 26 设计准则对应关系**：

| 组件 | 规范 | 实现 |
|---|---|---|
| Island Stats（大面积数据）| 不使用 Glass | 无容器，直接浮在背景 |
| QuickAccess（中型容器）| `.glassEffect` RoundedRect | `.glassEffect(.regular, in: RoundedRectangle(r:24))` |
| BatchCheckIn（胶囊条）| `.glassEffect` Capsule | `.glassEffect(.regular, in: Capsule())` |
| FloatingDockNav（多 Glass）| `GlassEffectContainer` | `GlassEffectContainer + glassEffectID morphing` |

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 二十八、人类详情页完善 + 吃药提醒功能（2026-03-10）

### 新增文件

#### `HumanMedication.swift`（Models）
SwiftData `@Model`，存储人类吃药提醒数据：

| 字段 | 类型 | 说明 |
|------|------|------|
| `humanId` | String | 关联 Human.id.uuidString |
| `name` | String | 药品名称 |
| `dosage` | String | 剂量描述（如"1片"） |
| `frequencyRaw` | String | MedicationFrequency.rawValue |
| `customFrequencyNote` | String | 自定义频率说明 |
| `firstDoseTime` | Date | 每天首次服药时刻 |
| `startDate` | Date | 开始日期 |
| `endDate` | Date? | 结束日期（nil=长期） |
| `colorHex` | String | 颜色标签 hex |
| `notes` | String | 备注 |
| `isActive` | Bool | 是否激活 |

`MedicationFrequency` enum：`daily/twiceDaily/threeTimesDaily/weekly/asNeeded/custom`

计算属性：
- `isActiveToday`：判断今天是否在用药周期内
- `daysRemaining`：距结束还有几天（nil=长期）

#### `HumanMedicationView.swift`（Views/Details）
完整吃药提醒 CRUD 页面：
- **HumanMedicationView**：主列表页
  - 顶部汇总 Bento（当前用药数/今日到期≤3天/长期用药数）
  - 药物行：彩色圆图标 + 名称/频率/剂量/服药时间/剩余天数
  - 激活/停药切换按钮（goTeal=活跃，goOrange=停用）+ Toast 反馈
  - 空状态卡片 + goLime FAB
- **AddMedicationSheet**：新增/编辑 Sheet（ArkBackgroundView 全屏）
  - 卡片1：药物信息（名称/剂量）
  - 卡片2：服药时间（频率横向 Chip / 自定义说明 / 首次时刻 / 开始日期 / 可选结束日期）
  - 卡片3：颜色圆点选择器（8色）+ 备注 TextEditor
  - 编辑模式额外显示删除按钮

### 修改文件

#### `Event.swift`
- 新增 `EventType.medication = "吃药"`，emoji 💊

#### `SharedModelContainer.swift`
- 新增 `ArkSchemaV21`，加入 `HumanMedication.self`
- `ArkMigrationPlan.schemas` 追加 `ArkSchemaV21.self`
- `SharedModelContainer.make()` 使用 `ArkSchemaV21.models`

#### `HumanDetailView.swift`（全面重构）
UI 规范对齐 OHANA_UI_GUIDELINES.md（UltimateGlassCard + OhanaFont + `.white` 颜色）：

**新增内容**：
- `statsBento`：4格横排（最新体重 / 当前用药 / 待办提醒 / 椰子余额），`OhanaFont.metric` 数值
- `medicationCard`：进入 `HumanMedicationView`，显示当前活跃药物彩色 Chip 预览 + 红色数字 Badge
- `sectionHeader()`：区块分组标签（健康&身体 / 活动&记录 / 财务 / 提醒&备注）

**重构内容**：
- `heroCard`：主题色（`human.themeColorHex`）头像光晕 + 彩色分类 Chip
- 所有卡片图标圆改为 48×48
- 所有文字 `foregroundStyle` 从 `.primary` 改为 `.white` / `.white.opacity(n)`
- `remindersSection`：统一 UltimateGlassCard + 虚线分割 + 空状态图示
- 导航全部改用 `.navigationDestination(isPresented:)`（告别 `.sheet` 混用）

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 二十九·二、OHANA_UI_GUIDELINES 全面重写 + 首页全规范化（2026-03-10）

### 修改文件：`OHANA_UI_GUIDELINES.md`

按照 `OhanaGlassUIV2DemoView.swift`（终极玻璃卡片 UI 测试）的最终实现，将 Guidelines 从 89 行扩展为完整的 9 章节规范文档：

| 章节 | 新增内容 |
|------|----------|
| 1. Card Styles | Dark/Light Mode 参数完整精确值（Swift + CSS equivalent），`UltimateGlassCard` 用法 |
| 2. Layouts | Bento Box Layout、Floating Groups、**Island Stats Bento 专项规范**（单卡 + 透明图表 + 虚线分割） |
| 3. UI Components | Dividers 完整代码（水平实线 + 垂直虚线）、Section Headers、Alert Banners 示例代码、Avatars/Badges 示例代码、Status Badges、Chips & Tags、Inner Pills |
| 4. Buttons | Primary/Secondary/Destructive/Icon Buttons 完整代码 + Forms |
| 5. Typography | `OhanaFont` token 表格 |
| 6. Colors | 色板说明 + `arkInk` 使用规则 |
| 7. Backgrounds & Blobs | `ArkBackgroundView` 规范 + 3色 Blob 代码 |
| 8. Charts | 透明背景规则、高度、Y轴隐藏、Line/Area/Bar 示例 |
| 9. Refactoring Process | 重构步骤 |

### 修改文件：`OverviewView.swift`

| 区块 | 变更 |
|------|------|
| `quickActionsSection` | 整个 Quick Access 区块（标题 + 4列 `LazyVGrid`）包裹进 `UltimateGlassCard`；标题从 `.system(size:20)` 改为 `OhanaFont.title3(.black)` |
| `addFirstPetBanner` | 3 个奖励 bento cell 从 `.goTranslucentCard(cornerRadius: 16)` 改为 `.ultraThinMaterial` + `RoundedRectangle(cornerRadius: 16)` + `white.opacity(0.15)` stroke，符合 Inner Pills 规范 |

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 三十、macOS Widget 卡片精准对齐 + 宠物卡片正面大升级（2026-03-11）

### 修改文件：`UltimateGlassCard.swift`

暗色背景彻底对齐苹果官方 macOS widget 实现：

| 参数 | 旧值 | 新值 |
|------|------|------|
| 背景 | `VisualEffectBlur(.systemUltraThinMaterialDark)` + 蓝紫渐变叠色 | 直接 `.ultraThinMaterial`（系统在 dark env 自动渲染为蓝紫 vibrancy） |
| 边框 | `white/18, 1pt` | `white/15, 0.5pt` |
| 阴影 | `black/35, r20, y8` | `black/20, r15, y8` |

### 修改文件：`ArkCrewIDCardView.swift`

**`emojiFallbackFront`（无图卡片正面）** 升级为 9 层渲染：
1. 主色深底
2. 对角渐变（左上亮→右下深）
3. 右上角高光椭圆（RadialGradient）
4. 左下暗角椭圆
5. 大装饰圆环 × 2（苹果卡片风格）
6. OHANA 品牌水印（斜向4%透明度）
7. Emoji 主角（60% 高度，浮起阴影）
8. 右侧信息列
9. 底部品种/绝育胶囊标签行

**`infoColumn`（右侧信息列）** 重构：
- 顶部新增品种 + 性别 chip 行（带描边胶囊）
- 相伴天数从 28pt 升至 **36pt 黑体巨字**，附"天 · 一起度过"副标记
- 名字字号调整为 24pt
- 底部新增 🔥 连续打卡 streak 胶囊（goLime 色，仅 streak > 1 时显示）

**`detailButton`** 改为跟随卡片主题色的半透明胶囊（`cardTextColor/15` 背景 + `cardTextColor/20` stroke）

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 二十九·三、暗色卡片 macOS Widget 风格 + Island Stats 浮动图表（2026-03-10）

### 修改文件：`UltimateGlassCard.swift`

暗色模式背景从 `black/40` 纯黑叠色改为 **蓝紫渐变叠色**，对齐 macOS widget 透明感：

| 参数 | 旧值 | 新值 |
|------|------|------|
| 背景叠色 | `Color.black.opacity(0.4)` | `LinearGradient([#1A2A6C/35%, #0D1B4B/25%], topLeading→bottomTrailing)` |
| 边框 | `white.opacity(0.1)` | `white.opacity(0.18)` |
| 阴影 | `black/50, r24, y16` | `black/35, r20, y8` |

效果：卡片极薄，背景 Blob 颜色（goLime/goPrimary/goPurple）明显透出，蓝紫玻璃质感如 macOS widget。

### 修改文件：`OhanaGlassUIV2DemoView.swift`

背景 Blob 升级为**双层 5 球结构**，方便验证透视效果：
- **Layer 1（7s 快速）：** goLime(0.75) 320pt + goPrimary(0.65) 360pt + goPurple(0.70) 280pt
- **Layer 2（11s 慢漂）：** goTeal(0.50) 200pt + goOrange(0.45) 180pt

### 修改文件：`OverviewView.swift`

`islandStatsBento` 彻底去卡片：
- 移除外层 `UltimateGlassCard` 包裹
- `IslandStatCard` 透明内容直接浮在页面动态背景 Blob 之上
- Section Header 改为浮动白字 `.white.opacity(0.45)`，无背景框
- 图表间保留 `verticalDashDivider` 虚线分割

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 二十九、Ohana Stats (Island Stats) 布局重构 (2026-03-10)

### UI 规范文档更新 (`OHANA_UI_GUIDELINES.md`)
- **Light Mode 终极玻璃卡片**：完全抛弃 Material，改为纯白渐变 `white/70 → white/30` 叠加 `UIVisualEffectView(effect: UIBlurEffect(style: .light))` 强制实现极致透亮发白的玻璃效果，无视系统 Dark Mode 设置。
- **Alert Banners (提示横幅)**：必须为纯实色荧光背景（`goLime`, `goYellow` 等），不再使用半透明或边框，内部为黑色粗体字和图标。
- **Avatars (头像)**：必须为纯 Emoji 重叠组合，绝对禁用任何半透明圆形背景或边框叠加。

### 首页卡片透明化大一统 (`OverviewView.swift` / `IslandStatComponents.swift`)
- **透明化组件**：去除了 `IslandStatCard` 和 `SynergyFlashCard`、`CoconutWealthRankingCard` 内部自带的 `UltimateGlassCard` 外壳，将它们变成无背景的纯布局 VStack。
- **统一背景**：在首页的 `islandStatsBento` 区域，将外层横向 `ScrollView` 整体包裹进一个统一的巨大的 `UltimateGlassCard` 中。
- **虚线分割**：图表之间（`IslandStatCard` 之间）统一使用 `verticalDashDivider`（1px，4x4 dash，0.15 透明度）进行视觉切分，彻底满足了 "charts要无背景（背景透明），chart之间用虚线分割" 的大一统设计要求。

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 三十、Overview UI & Features 全面更新（2026-03-11）

### HomeBentoBoxes (`Views/Home/HomeBentoBoxes.swift`)
- 标题中文化："Oasis Tree"→**"生命之树"**，"Daily Strike"→**"打卡连击"**；单位"Days"→"天"
- 新增 `onOasisTap`/`onStreakTap` 闭包参数；点击触发轻触觉反馈

### DailyStreakDetailView（新建 `Views/Home/DailyStreakDetailView.swift`）
- **连击排行榜**：按 `currentStreak` 降序，宠物头像 + 主题色圆 + 大字 streak + 上次打卡日期
- **月历视图**：打卡日橙色圆高亮；今日 goLime 边框；月份左右切换；`.glassEffect(.regular)` 背景

### OverviewView (`Views/OverviewView.swift`)
- 新增 `showOasisReward`/`showStreakDetail` @State；连接 HomeBentoBoxes 回调
- `fullScreenCover` → `OasisRewardView()`；`sheet` → `DailyStreakDetailView(pets:)`
- Quick Access 标题改"**快捷操作**"，移除 EDIT 胶囊按钮；网格末尾加虚线"添加"占位按钮

### GoQuickActionCard (`Views/Components/OverviewQuickActions.swift`)
- 去掉 `premiumShape` fill/strokeBorder 卡片背景；icon 26pt 直接无背景显示
- 保留 `contextMenu` 长按菜单（删除/详情/完成待办）

### ArkCrewIDCardView (`Views/Components/ArkCrewIDCardView.swift`)
- `infoColumn`：去掉品种/性别 chip；daysTogether 改"一起度过了 XX 天"（10pt + 38pt + 12pt）
- `emojiFallbackFront`：删除底部品种/绝育 chip 标签层
- `minimalFront`：品种/性别 chip 行注释隐藏
- shadow 由单层 `opacity(0.5) r24` 柔化为双层：`opacity(0.28) r40` + `opacity(0.10) r80`

### CalendarView (`Views/CalendarView.swift`)
- 导航标题 "Calendar"→"**日历**"；chip "All"→"**全部**"；空状态→"**暂无事件**"

### SwipeableEventRow (`Views/Components/SwipeableEventRow.swift`)
- `eventCard` 背景改为 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))`
- **逾期引力动画（Chapter 44）**：移除描边框；逾期状态图标圆底色变 `#FF5A00`；`TimelineView(.animation(minimumInterval:1/30))` 驱动物理引擎：呼吸 `sin(t×1.8)×0.025+1.0`（scale 1.0→1.05）+ 浮动 `sin(t×1.2)×2.0`（offsetY -2→+2）
- **滑动完成形变（Chapter 44）**：`scaleEffect(x: 1-p×0.04, y: 1+p×0.02, anchor: .trailing)` Squish；图标节点背景 `leftProgress` 驱动从原色过渡到 `#FF5A00`；p>0.4（逾期 p>0.3）时 emoji 淡出，checkmark 淡入+放大；文字 `opacity(1-p×0.8)` 同步淡出；`animation(.spring(response:0.2,dampingFraction:0.7))`

### SettingsView (`Views/SettingsView.swift`)
- 新增 `preferredScheme` 计算属性；`.preferredColorScheme(preferredScheme)` 挂载在 NavigationStack，主题切换页内立即生效

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)

---

## 三十一、UI/UX 全面修订 Round 2（第二十一章）

### OasisRewardView (`Views/Home/OasisRewardView.swift`)
- `@Environment(\.dismiss)` 添加；顶部 Header 右侧新增 `xmark.circle.fill` 关闭按钮
- 标题子标由 "欧哈纳" 改为 "Ohana"
- 移除 `calendar.badge.checkmark` 日历入口按钮及胶囊视图

### ArkCrewIDCardView (`Views/Components/ArkCrewIDCardView.swift`)
- **正面阴影**：三层增强 shadow（主题色 r24 y8 + 黑 r40 y16 + 黑淡 r80 y32），营造卡片浮感
- **背面底层**：手动深蓝渐变 → `.glassEffect(.regular, in: RoundedRectangle(32))`
- **背面文字**：`.white` → `.primary`，适配 Light/Dark mode
- **详情按钮背景**：`.white.opacity(0.08)` → `.glassEffect(.regular, in: Capsule())`
- **待办 Banner 背景**：`.white.opacity(0.06)` → `.glassEffect(.regular, in: RoundedRectangle(14))`
- **`metricDivider`**：`.white.opacity(0.08)` → `.primary.opacity(0.1)`
- **`floatingMetric` 文字**：`.white` → `.primary`

### OverviewHelperViews (`Views/Components/OverviewHelperViews.swift`)
- **FloatingDockNav**：`GlassEffectContainer` 4 个独立 glassEffect capsule → 单张 `.glassEffect(.regular, in: RoundedRectangle(28))` 卡片
- 图标：`chart.bar.fill` → `calendar`，`figure.walk.circle.fill` → `house.fill`
- **BentoStatCard**：`UltimateGlassCard` → `.glassEffect(.regular, in: RoundedRectangle(24))`；文字 `.white` → `.primary`

### HomeBentoBoxes (`Views/Home/HomeBentoBoxes.swift`)
- 打卡连击数据源由 `pets.max(by:).currentStreak` 改为 `@AppStorage("user_login_streak")`
- `@AppStorage("user_last_login_date")` 记录最后登录日期
- `onAppear` 调用 `refreshLoginStreak()`：昨天连续登录则 +1，否则重置为 1

### DailyQuestsCard (`Views/Components/DailyQuestsCard.swift`)
- `expandedCard` 背景：手动 `.ultraThinMaterial` + overlay → `.glassEffect(.regular, in: RoundedRectangle(24))`
- 标题：`"DAILY QUESTS"` → `"今日任务"`

### CrewRosterOverlay (`Views/Home/CrewRosterOverlay.swift`)
- 顶部保留搜索和新增入口，宠物/人类区当前直接复用首页 `ArkCrewIDCardView` / `HumanIDCardView`
- 因此 `Ohana Crew` 与首页共用同一套海报卡视觉语言、详情入口和后续样式演进链路
- **Material 模式差异**：背景切 `#F5F5F7`/`#0A0A0C`，关闭 `IslandMoodWeatherView`；搜索栏改白色 RR16+shadow；`dexSectionLabel` 改白色胶囊 pill（橙色计数）；`addNewLifeButton` 橙色 accent + 白色实线边框 + shadow

### OverviewView (`Views/OverviewView.swift`)
- Header（`goGreetingHeader`）底部加 `.ultraThinMaterial.opacity(0.6)` + mask LinearGradient fade，柔化与内容区的分界

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)
## 第二十二章：UI/UX 优化 Round 2 续（2026-03-11）

### ArkCrewIDCardView (`Views/Components/ArkCrewIDCardView.swift`)
- `cardFrontView`：ZStack 内层加 `.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))`，GeometryReader 外层再加同一 clipShape，防止内容溢出导致阴影呈方形矩形

### DailyStreakDetailView (`Views/Home/DailyStreakDetailView.swift`)
- 删除宠物打卡排行榜，改为「我的连击」人类登录连击卡片
- 卡片内容：当前活跃 Human 头像 + 名字 + `loginStreak` 大字 + 里程碑进度条（3/7/14/30/60/100 天）
- 月历日历格改为读取 `user_login_history`（JSON 数组）标记已登录日期
- `@Query` 引入 `humans` 获取 Human 头像

### HomeBentoBoxes (`Views/Home/HomeBentoBoxes.swift`)
- `refreshLoginStreak()` 新增调用 `appendLoginHistory(todayStr:fmt:)`
- `appendLoginHistory`：解码 `user_login_history` JSON → 追加当日 ISO8601 字符串 → 保留最近 365 条 → 重新编码写回
- 新增 `@AppStorage("user_login_history")` 字段

### OverviewView (`Views/OverviewView.swift`)
- `goGreetingHeader`：删除底部 `LinearGradient + .ultraThinMaterial.opacity(0.6)` 背景块，Header 完全透明无背景

### Quick Access 流程简化（`OverviewView.swift` + `OverviewQuickActions.swift`）
- `+` 按钮改为触发 `showingAddQuickAction`，直接弹出 `AddQuickActionSheet`（不再经过 `QAManageSheet` 中间页）
- `AddQuickActionSheet` 宠物选择行改用 `.glassEffect(RoundedRectangle(18))`
- 动作网格改用 `.glassEffect(RoundedRectangle(20))` + `ScrollView` 包裹，间距 12pt

### PetThemeColor（`Models/Pet.swift`）
- 10 个 case 全部替换为 Go UI 色板：
  - `lime` #C8FF00 / `orange` #FF8C42 / `primary` #4338FF / `teal` #00D4AA / `yellow` #FFF44F
  - `red` #FF4757 / `purple` #A78BFA / `blue` #5B6AFF / `mint` #80FFEA / `pink` #FF6B9D
- fallback 由 `.coral`（已删除）改为 `.orange`

### PetBreedDatabase（`Models/PetBreedDatabase.swift`）
- `genericCoatColors` hex 精准化：黑 1C1C1C / 白 F5F5F0 / 灰 A0A0A0 / 棕 7B4F2E / 金黄 D4A017 / 奶油 F5E6C8 / 红 B5451B / 橙 C8622A / 杏 E8C49A / 蓝灰 7A9AAF / 银 C0C0C0 / 巧克力 4A2C1A / 三花 D4B896 / 虎斑 7A5C3A / 花斑 C8B4A0
- `genericEyeColors` hex 精准化：棕 6B3A2A / 琥珀 C68B1A / 金 D4A017 / 黄 C8A800 / 绿 4A7A3A / 蓝绿 2A7A6A / 蓝 2A5C9A / 浅蓝 5A9ACA / 铜 A05A1A / 橙 C06010 / 榛 7A5A2A / 黑 1C1C1C / 异瞳 7A3A7A

### QuickWeightSheet (`Views/Components/QuickWeightSheet.swift`)
- 顶部宠物 header：头像圆（themeColor 背景）+ 名字（black weight）+ "记录体重" 副标题
- 主输入区：`.glassEffect(RoundedRectangle(28))`，64pt 数字，居中对齐，kg 标签用 `themeColor`
- 上次体重提示：读取 `pet.weightLogs` 最新一条，显示 "上次记录：X.X kg"
- 日期选择行：`.glassEffect(RoundedRectangle(18))`，`tint` 跟随 `themeColor`
- 保存按钮：背景色跟随 `themeColor`，已保存状态变 `goTeal`

### AddExpenseSheet (`Views/Components/AddExpenseSheet.swift`)
- 顶部宠物 header：头像圆（petThemeColor 背景，44pt）+ 名字（black weight）+ "快速记账" 副标题
- 金额输入大卡：`¥` 符号用 `petThemeColor`，52pt 数字；下方分类 chips 选中时背景为 `petThemeColor`，整体 `.glassEffect(RoundedRectangle(24))`
- 支付人：独立 `.glassEffect(RoundedRectangle(20))` 卡，头像升至 44pt，选中圈 2.5pt white stroke
- 日期 + 备注：合并为 `.glassEffect(RoundedRectangle(20))` 卡，中间 `GoDashedDivider` 分隔
- 记录按钮：背景跟随 `petThemeColor`，图标 `yensign.circle.fill`

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)

## 第三十二章：UI/UX 精修 & Bug 修复（2026-03-15）

### 批量打卡视觉优化 (`OverviewView.swift`)
- **batchBentoCell**：打卡完成后仅图标和文字变色（goLime），卡片背景保持不变，避免视觉干扰
- 保持 `isHighlighted` 状态，但仅影响前景色，背景始终为 `Color.white.opacity(0.04)`

### 遛狗实时面板 (`ArkCrewIDCardView.swift`)
- **cardBackView**：在 `isActiveWalk` 时显示 `walkLivePanel` 替代普通仪表盘
- 已应用 `.glassEffect(.regular, in: RoundedRectangle(32))` 保持视觉一致性

### 卡片翻转动画优化 (`ArkCrewIDCardView.swift`)
- 使用 `spring(response: 0.5, dampingFraction: 0.82)` 替代 `easeInOut`，提升物理感
- 延迟 0.22s 切换正反面，匹配 spring 动画中点时间
- 增加 `perspective: 0.5` 增强立体感

### 岛屿统计布局清理 (`OverviewView.swift`, `IslandStatComponents.swift`)
- **OverviewView**：移除 `CoconutWealthRankingCard` 前的 `verticalDashDivider`
- **CoconutWealthRankingCard**：排行榜显示从 Top 4 改为 Top 3（`prefix(3)`）

### 宠物剪影尺寸调整 (`CrewRosterOverlay.swift`)
- **miniSubjectLayer**：`PetSilhouetteView` 缩放从 0.82 改为 0.42
- 避免视觉过重，保持卡片平衡

### 人类显示开关重命名 (`HumanDetailView.swift`, `OverviewView.swift`)
- **showOnHomeCard**：标题从"在首页卡堆显示"改为"在首页显示"
- 副标题更新：隐藏时明确说明"不在首页卡堆与岛屿体重中显示"
- **OverviewView**：岛屿体重统计头像过滤 `humans.filter { $0.shouldShowOnHome }`

### 财富页系统椰子开关 (`IslandWealthViewModel2.swift`, `IslandWealthDashboard2.swift`)
- **IslandWealthViewModel2**：新增 `showSystemCoconuts: Bool` 属性
- **chartBars**：过滤 `eid == "system"` 的记录（当 toggle 关闭时）
- **IslandWealthDashboard2**：导航栏添加齿轮图标按钮，点击切换显示状态

### NaN CoreGraphics 崩溃修复 (`HumanDetailView.swift`, `CoHealthDashboardView.swift`)
- **HumanDetailView.statsBento**：体重显示添加 `latest.weight.isFinite` 检查
- **HumanDetailView.heroCard**：身高显示添加 `human.heightCm.isFinite` 检查
- **CoHealthDashboardView**：`humanWeightPoints` 和 `petWeightPoints` 过滤非有限值
- **statsRow**：体重显示使用 `flatMap` + `isFinite` 双重保护

### 吃药提醒导航崩溃修复 (`HumanDetailView.swift`)
- 将 `navigationDestination(isPresented: $showingMedication)` 改为 `.sheet`
- 避免多个 navigationDestination 修饰符导致的 SwiftUI 竞态条件
- 保持与其他详情页一致的 sheet 呈现模式

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)

## 第三十三章：UI 规范化系统 & 全岛体重过滤修复（2026-03-15）

### iOS 26 设计口号系统 (`iOS26_Design_Guide.md`)
- **新增第十四章「Ohana 背景口号系统」**：建立标准化背景命名体系，确保 AI 和开发者对 UI 需求达成一致理解
- **四种标准背景口号**：
  - **卡片标准背景**：`UltimateGlassCard { content }`，8 层 Liquid Glass 折射系统（.ultraThinMaterial + 7层叠加效果），用于大面积内容卡片、设置组、表单容器
  - **玻璃背景**：`.glassEffect(.regular, in: shape)`，iOS 26 原生单层磨砂折射，用于浮动按钮、导航栏、Dock、小型交互控件
  - **内嵌背景**：`.background(.white.opacity(0.08), in: RoundedRectangle(...))`，卡片内部次级区域背景，用于 Bento 格、输入框、标签区
  - **纯色背景**：`.background(Color.goLime, in: Capsule())`，不透明实色，用于 CTA 按钮、Alert Banner、危险操作
- **详细参数文档**：每种背景附带完整代码示例、使用场景、参考组件
- **使用决策树**：根据组件类型快速选择合适的背景样式

### iOS 26 UI 测试页背景对比 (`iOS26UITestView.swift`)
- **cardBackgroundComparison**：新增背景口号系统演示卡片，展示四种背景的实际效果
- **卡片标准背景示例**：生命之树卡片（UltimateGlassCard + tree.fill icon + 说明文字）
- **玻璃背景示例**：Dock 栏样式（4个 tab icon）+ 胶囊按钮（🥥128）+ 圆形按钮（pencil icon）
- **内嵌背景示例**：两个 Bento 格（体重 24.5kg + 卡路里 1240kcal）
- **纯色背景示例**：主要按钮（goLime 背景）+ 危险操作（goRed 描边）
- 整体使用 `.glassEffect(.regular, in: RoundedRectangle(24))` 作为容器

### 一键全家 UI 重构为网格布局 (`OverviewView.swift`)
- **batchCheckInBar**：从玻璃胶囊条（Capsule + 横向滚动）重构为与快捷操作一致的网格布局
- **新布局结构**：
  - 标题行：`Text("一键全家")` + `Spacer()` + 管理按钮（slider.horizontal.3 icon，`.glassEffect(.regular, in: Circle())`）
  - 网格：`LazyVGrid(columns: 4列, spacing: 10)`
- **batchGridCell**：匹配 `GoQuickActionCard` 视觉风格
  - 无背景 icon（26pt semibold）
  - 打卡后 icon 变 `Color.goLime`，未打卡为 `.primary.opacity(0.75)`
  - Subtitle 显示"已完成"或"全家"
  - 按压缩放动画：`.scaleEffect(isPressed ? 0.88 : 1.0)`
- **删除死代码**：移除 `batchBentoCell`（多巴胺渐变图标背景版本，已不再使用）

### 全岛体重过滤已关闭人类 (`IslandWeightDashboard.swift`)
- **visibleHumans**：新增计算属性 `humans.filter { $0.shouldShowOnHome }`
- **三处过滤应用**：
  - **totalIslandWeightKg**：使用 `visibleHumans` 计算人类体重总和
  - **buildSparklineEntries()**：遍历 `visibleHumans` 而非 `humans`
  - **vm.load() 调用**：`.onAppear`、`.onChange(of: pets.count)`、`.onChange(of: humans.count)` 均传入 `visibleHumans`
- **效果**：确保在人类详情页关闭"在首页显示"开关后，该人类的体重数据不再出现在全岛体重统计、趋势图、排行榜、个体清单中

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)
