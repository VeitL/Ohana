# Ohana (欧哈纳) iOS App 完整技术文档

> 最后更新: 2026-03-09 | Schema: ArkSchemaV19 | Phase 1-76 + TASK A-E + FIX 1-8 + 深度修复 P1-P10 完成 | 编译: iPhone 17 Pro Simulator, iOS 26.2

---

## 一、概览

**Ohana（欧哈纳）**是一款家庭宠物综合管理 iOS App。

- **核心理念**："Ohana means family. Nobody gets left behind or forgotten."
- **技术栈**：SwiftUI + SwiftData + Swift Charts, iOS 17+, Swift 6
- **本地优先**：无需账号，数据存储在设备 SwiftData（SQLite + App Group）
- **设计风格**：Go UI — 青柠主色调，深蓝渐变背景，毛玻璃卡片，热带岛屿养成氛围
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
│   ├── ArkBackgroundView.swift # 深蓝渐变背景
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
| Chip/Tag | `Capsule()` |

### 2.4 ViewModifier（`OhanaDesignSystem.swift`）

```swift
.goTranslucentCard(cornerRadius: 20)   // 毛玻璃卡片（最常用）
.goCard(cornerRadius: 20)              // 白色卡片
.goBlueCard(cornerRadius: 20)          // 蓝色卡片
.ohanaGlassStyle(cornerRadius: 24)     // 旧版毛玻璃（部分页面保留）
.neoWhiteCard(cornerRadius: 32)        // 新白色卡
.coconutRewardOverlay()                // 椰子弹跳动效
```

### 2.5 通用组件

```swift
FloatingDockNav(selectedTab:onHome:onStats:onCrew:onOasis:)  // 底部悬浮4tab导航
GoDashedDivider()                   // 虚线分割
OhanaSheetWrapper { }               // 标准 Sheet 容器
CoconutBalanceCapsule(...)          // 椰子余额胶囊按钮
CoconutRewardModifier               // 全局椰子弹跳动效
```

---

## 三、SwiftData 数据模型

### 3.1 Schema 版本

**当前最新：`ArkSchemaV19`**（`Schema.Version(19, 0, 0)`），包含 21 个模型。

| 版本 | 变更 |
|------|------|
| V1–V13 | 模型逐步添加（宠物/人类/日志/椰子经济/协作等）|
| V14 | Pet 新增 `passedAwayDate`（Rainbow Bridge）|
| V15 | Human 新增 `themeColorHex`（正式主题色字段，自定义迁移）|
| V16 | Human 新增 `privateFieldsRaw`/`heightCm`（lightweight）|
| V17 | PetMilestone 新增 `photoData: Data?`（lightweight）|
| **V18** | **PetMilestone 新增 `location: String`**（lightweight，默认 ""）|
| **V19** | **Pet 新增 `cardStyleRaw: String`**（lightweight，默认 "classic"）|

**迁移链**：V1→…→V14 全部 `lightweight`；V14→V15 `custom`；V15→V19 全部 `lightweight`。

**下次 Model 变更**：新建 `ArkSchemaV20`，在 `stages` 追加迁移。

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
| PetDocument | `PetDocument.swift` | name, documentTypeRaw, expirationDate, cost, attachmentData(`@externalStorage`), attachmentFilename |
| PetExpenseLog | `PetExpenseLog.swift` | date, amount, category, note, executorId |
| PetFoodRecord | `PetFoodRecord.swift` | date, amountGrams, mealTypeRaw, executorId |
| PetMilestone | `PetMilestone.swift` | date, title, notes, photoData(`Data?`) |
| WaterLog | `WaterLog.swift` | date, amountMl |
| PetCareLog | `PetCareLog.swift` | date, careTypeRaw(feeding/watering/litterBox), executorId |
| HumanWeightLog | `HumanWeightLog.swift` | date, weight, human(关系) |
| HumanWorkoutLog | `HumanWorkoutLog.swift` | date, typeRaw(8种 WorkoutType), durationMinutes, distanceKm, calories, steps, sourceHealthKit, human(关系) |
| PetRelationship | `PetRelationship.swift` | fromPetId, toPetId, relationshipTypeRaw(parent/child/sibling/halfSibling/mate/other) |
| WishlistItem | `WishlistItem.swift` | title, cost(Int), creatorId, isRedeemed, redeemedById |

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
| L1 | PetHeroRow | 头像 + 名字 + Tags + daysTogether/年龄 |
| L1.5 | PetHUDVitalSection | goLime 霓虹环形图（遛狗进度/铲屎+喂食）；**@Query 实时查询**当日 walkLogs/pottyLogs/careLogs，打卡后数字立即刷新 |
| L2 | PetAlertScrollSection | 断粮/证件到期/疫苗预警横滚卡 |
| L3 | PetHealthHubCard | 健康快动作 4 按钮 + 疫苗本入口 |
| — | PetImmunityCard / PetHygieneCard | 免疫状态 / 护理追踪 |
| L4 | PetChartDashboard | 横向 ScrollView 图表卡（体重/花费/遛狗/噗噗/余粮） |
| L5-6 | PetDocumentsCard / PetMilestonesCard | 证件 / 里程碑 |
| L7 | PetUnifiedTimeline | 岁月史书（5 类日志合并降序） |

**Toolbar**：分享 → 日历 → 椰子余额

**参数**：`openHealthOnAppear: Bool` — 自动 push PetHealthDetailView

### 5.7 CalendarView — `Views/CalendarView.swift`

- 月视图 + 列表视图切换（默认列表）
- Pet Chip 筛选器（goLime 选中态）
- `SwipeableEventRow`：左滑完成/右滑删除，三种视觉状态(pending/completed/overdue)
- 点击行 → EventDetailSheet（F2F0F5 底板）
- 发光光纤纵向时间轴

### 5.8 SettingsView — `Views/SettingsView.swift`

- Profile 卡（goLime 头像 + 昵称）
- 设备身份选择器（`@AppStorage("currentActiveHumanId")`）
- 偏好：语言（`@AppStorage("appLanguage")`）
- 通知 / 关于 / 版本号
- 宠物管理：每只宠物独立「重置」（清空日志）+「删除」按钮

### 5.9 HumanDetailView — `Views/Details/HumanDetailView.swift`

1. Hero 卡（头像 + 姓名 + Chip 行：角色/年龄/血型/国籍/城市）
2. 体重卡 → **HumanWeightHistoryView（Phase 73：改为 .sheet，修复 NavigationLink 死锁）**
3. HumanWorkoutCard（HealthKit 统计 + 运动记录）
4. 提醒区域 / 备注 / 删除
5. Toolbar 铅笔 → EditHumanSheet

### 5.10 OasisRewardView（绿洲）— `Views/Home/OasisRewardView.swift`

- 生命之树 SF Symbol（动态 leaf→tree.circle→tree 切换）
- 注入能量按钮（扣 10🥥 + 粒子特效 + 升级弹出）
- 每日被动收益 3🥥（茂盛级以上）
- **Phase 73 新增**：右上角 `info.circle` 按钮 → `CoconutRulesSheet`（椰子获取指南，含收入来源/消耗用途/双账本三区）
- Bento Grid（Phase 71 更新）：
  - 行1：**椰子商店**（→ CoconutShopView）/ 成就解锁（→ AchievementWallView）
  - 行2：**欧气扭蛋机**（→ GachaView）/ **家庭悬赏榜**（→ BountyBoardView）
  - 行3：今日能量 / 植物管理（占位）

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
| DocumentsListView | `Details/DocumentsListView.swift` | 证件列表 |
| PlantDetailView | `Details/PlantDetailView.swift` | 植物详情（浇水/施肥） |
| CatCareStationCard | `Details/CatCareStationCard.swift` | 猫咪护理站 |
| CoHealthDashboardView | `Details/CoHealthDashboardView.swift` | 协同健康仪表盘 |
| HumanWishlistView | `Details/HumanWishlistView.swift` | 心愿单 |
| WeeklyReportCard | `Details/WeeklyReportCard.swift` | 本周小报海报 |

### 5.12 全岛数据仪表盘

| 仪表盘 | 文件 | 功能 |
|--------|------|------|
| IslandWeightDashboard | `Details/IslandWeightDashboard.swift` | 全岛体重引力场（百分比 LineMark + 干饭王/自律王 Bento + 个体清单下钻） |
| IslandExpenseDashboard | `Details/IslandExpenseDashboard.swift` | 全岛花费（总支出 + 吞金兽 Bento + 条形图 + 环形饼图 + 谁在买单） |
| IslandExplorationDashboard | `Details/IslandExplorationDashboard.swift` | 全岛探索（总里程 + Bento + 堆叠柱状图 + 贡献榜） |
| IslandWealthDashboard2 | `Details/IslandWealthDashboard2.swift` | 椰子财富中心（堆叠柱状图 + 贡献排行榜） |

> **Charts 注意**：BarMark 的 `unit` 参数只支持 `.day/.hour/.month` 等静态值，不能动态传 `Calendar.Component`（会 fatal error）。

### 5.16 CritterDeckCarousel / HumanIDCardView（Phase 76 更新）

**位置**：`Views/Home/CritterDeckCarousel.swift`

- `DeckItem` enum（`.pet(Pet)` / `.human(Human)`），`HumanIDCardView` 同文件
- **humanFrontView 重构**（Phase 76）：完全复刻 `PetCardFrontView` 杂志封面布局
  - 左侧头像 52% 宽度底部对齐，支持贴纸白边描边效果（透明 PNG）/ emoji fallback
  - 右侧：相识天数（HStack firstTextBaseline）、大名字（28pt heavy）、角色+性别胶囊、年龄胶囊、血型胶囊
  - 翻转 icon 移至左下角（与宠物卡片一致）；右侧 VStack 加 `.padding(.bottom, 28)` 防遮挡
  - `humanThemeColor` 从 `notes` 字段 `themeColor:XXXXXX` 格式解析
- **humanBackView 重构**（Phase 76）：QUICK ACCESS 标题 + `HumanQuickAccessGrid`（⚖️体重/💧喝水/💸花费/📝心愿）+ 底部 chip 行
- **`HumanQuickAccessGrid`**（新增组件）：4 格 LazyVGrid；喝水打卡写 `WaterLog` + `QuestManager.awardAction(.general)`；体重跳 `GenericWeightEntrySheet`；待办跳 `HumanWishlistView`；水打卡有 3s 视觉反馈
- **AllCardsSheet 重构**（Phase 76）：`LazyVGrid` 双列缩略卡，每格为 `MiniFlipCard`（信用卡比例 cardWidth/1.586）；点击翻面显示「进入详情」青柠按钮 + 「置顶显示」按钮；当前顶牌显示「当前」标签；`import SwiftData` 已补加

### 5.13 首页组件

| 组件 | 文件 | 功能 |
|------|------|------|
| IslandStatComponents | `Components/IslandStatComponents.swift` | Island Stats 卡片 + SynergyFlashCard + CoconutWealthRankingCard |
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
| `AddPetWizardView.swift` | 宠物添加向导（多步，含头像裁剪/品种选择/主题色互斥/自动创建事件）；**Phase 76 新增「粘贴已抠主体」剪贴板按钮**（`pastePasteboardImage()`，优先 PNG 保留透明通道） |
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

**核心逻辑**：`cardFrontView` 通过 `ImageCutoutService.isTransparentPNG(_:)` 检测头像是否为透明抠图，自动分支渲染。

**方案三：破框悬浮（`cutoutFloatFront`）**
- 触发条件：`avatarImageData` 存在 + `isTransparentPNG == true`
- 背景：主题色深底 + 斜向渐变覆膜 + 右上高光光斑 + OHANA 水印
- 破框实现：先 `.clipShape(RoundedRectangle)` 裁剪背景和文字，然后 `.overlay(alignment: .bottomLeading)` 在 clipShape 外叠加宠物图片，`offset(y: -20)` 使图片头部超出卡片上边缘
- 贴纸白边：6 层白色 `.shadow` 叠出实心描边
- 图片尺寸：`width * 0.52, height * 1.05`（高于卡片，产生溢出）
- 底部地面光晕：`RadialGradient` Ellipse + `.blur(radius:10)`

**方案四：高斯模糊背景（`blurBackgroundFront`）**
- 触发条件：`avatarImageData` 存在 + `isTransparentPNG == false`
- 层1：原图 `scaledToFill + blur(radius:40)` 充满整卡，Apple Music 风格动态底色
- 层2：`LinearGradient` 深色蒙版（black 28%-55%）保证文字可读
- 层3：`.ultraThinMaterial.opacity(0.35)` 进一步柔化
- 层5：原图左侧显示（width*0.62），右边缘用 `mask(LinearGradient)` 从左向右渐变消融（stops: 0→0.45实体，0.70→1.0消隐）
- 文字颜色固定 `.white`（不用 `cardTextColor`）

**fallback（`emojiFallbackFront`）**：无图时纯色渐变背景 + 大 emoji

**共享组件**（三分支统一使用）：
- `infoColumn(geo:textColor:)`：右侧信息列，只含 **名字 + 相伴天数 + 年龄换算**，已删除品种/性别
- `detailButton`：右上角详情按钮（`.overlay(alignment: .topTrailing)`）
- `flipHint`：左下角翻转提示图标
- `frontPillScalable(_:textColor:)` / `frontPill(_:textColor:)`：新增 `textColor` 参数，默认 `cardTextColor`

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

**首页模块排序严格绑定**：
- `sectionOrderRaw` 默认值加入 `"batchCheckIn"`
- `mainScrollView` 下半段改为 `ForEach(orderedSections)` + `switch` case 渲染，彻底消除硬编码 if 块
- `HomeSectionEntry.defaults` 新增 `batchCheckIn` 条目（icon: `bolt.circle.fill`, color: `#FFD60A`）

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

**新增状态**：
```swift
@State private var checkedInDates: Set<String> = []  // "yyyy-MM-dd"
@State private var makeupPackCount: Int = 0
@State private var showMakeupConfirm: String? = nil
private let checkedInKey = "oasis_checkedIn_dates"
private let makeupPackKey = "oasis_makeup_pack_count"
```

**打卡日历卡片** (`checkInCalendarCard`)：
- 标题行：`calendar.badge.checkmark` + 连胜天数（🔥 N天连胜）+ 补签包数量（📦×N）
- 30天 `LazyVGrid(columns: 7)`：已打卡 → `goLime` 实心圆 + `checkmark.black`；今日 → `goLime.opacity(0.22)` + goLime 边框；未打卡且有补签包 → 可点击触发补签确认
- `.confirmationDialog` 确认补签，消耗1个补签包

**自动打卡逻辑**：
- `onAppear` 调用 `triggerTodayCheckIn()` → 首次打卡当天自动记录 + 奖励1椰子
- `currentStreak` 计算：从今日向前遍历连续打卡天数

**补签包获取**：在椰子商店购买（已有基础架构，`makeupPackKey` UserDefaults 持久化）

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

### 21.5 图鉴卡片只显示名字（CrewRosterOverlay）

`PetSquareCard` 底部信息层：
- 移除 `petStatusBadge`
- 移除 `Text("\(pet.species) · \(pet.breed)")`
- 只保留 `Text(pet.name)` (17pt .black)

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
改用 `.overlay + .blendMode(.destinationOut) + .compositingGroup()` 实现等效渐变消融，彻底绕开 `.mask` 字节对齐问题，消除花屏。

**编译状态**：BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)
