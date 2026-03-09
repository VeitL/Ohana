# Ohana App 完整代码参考文档

> **版本**: v7.6.0 | **平台**: iOS 17+ | **框架**: SwiftUI + SwiftData + Swift Charts
> **语言**: Swift 6 | **模拟器**: iPhone 17 Pro (iOS 26.2) | **编译状态**: ✅ Build Succeeded
> **原名**: Ark | **品牌名**: Ohana（代码中部分标识符保留 Ark 前缀）
> **最后更新**: 2026-03-05（Phase 57）

---

## 一、项目结构

```
Ohana/
├── OhanaApp.swift              # @main 入口，ModelContainer 初始化
├── ContentView.swift           # NavigationStack + 全局覆盖层
├── Models/                     # 20个数据模型 + 6个管理器
├── Views/
│   ├── RootView.swift          # Onboarding 路由守卫
│   ├── ArkBackgroundView.swift # 全局深色渐变背景
│   ├── OhanaDesignSystem.swift # 设计系统（颜色/组件/修饰符）
│   ├── OverviewView.swift      # 首页（主要入口）
│   ├── CalendarView.swift      # 日历视图
│   ├── OnboardingView.swift    # 新手引导
│   ├── SettingsView.swift      # 设置页
│   ├── Details/                # 29个详情页/卡片
│   ├── Components/             # 15个全局组件
│   ├── Forms/                  # 7个表单/向导
│   └── Home/                   # 6个首页子模块
├── ViewModels/                 # 2个 @Observable ViewModel
└── Utilities/                  # ColorExtensions + ModelContextExtensions
```

---

## 二、技术栈与架构

### 核心框架
- **SwiftUI** — 全 declarative UI，无 UIKit ViewController
- **SwiftData** — 持久化（`@Model`, `@Query`, `ModelContext`），版本化 Schema（V1→V11）
- **Swift Charts** — BarMark / LineMark 图表（`import Charts`）
- **CoreLocation** — GPS 轨迹追踪（遛狗功能）
- **MapKit** — 地图快照生成
- **HealthKit** — 人类运动数据读取（`HumanWorkoutLog.sourceHealthKit`）

### 状态管理
- **@Observable** — `QuestManager`, `AchievementManager`, `PetWalkingManager`, `LocationManager`（单例）
- **@Query** — SwiftData 查询，View 层直接使用
- **@AppStorage** — UserDefaults 持久化（onboarding、quickActions、主题等）
- **@Environment(\.modelContext)** — SwiftData context 注入

### App 入口链路
```
OhanaApp (@main)
  └─ RootView
       ├─ OnboardingView（首次启动）
       └─ ContentView
            ├─ OverviewView（首页）
            ├─ PetDetailView（宠物详情，NavigationDestination）
            ├─ HumanDetailView（人类详情）
            ├─ PlantDetailView（植物详情）
            ├─ GlobalCoconutButtonOverlay（全局悬浮椰子按钮）
            └─ GlobalWalkBanner（全局遛狗悬浮横幅）
```

### 数据持久化
- **SwiftData 本地存储**（无 CloudKit，`cloudKitDatabase: .none`）
- **UserDefaults**：`QuestManager` 椰子余额/日志、`AppStorage` UI 状态
- **外部存储**（`@Attribute(.externalStorage)`）：`avatarImageData`、`mapSnapshotData`、`routeLocationsData`

---

## 三、数据模型（@Model）

### 3.1 Pet（宠物）
**文件**: `Ohana/Models/Pet.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `name` | String | 宠物名字 |
| `species` | String | 物种（狗/猫/兔子等） |
| `breed` | String | 品种 |
| `birthday` | Date? | 生日 |
| `gender` | String | "male"/"female"/"unknown" |
| `isNeutered` | Bool | 是否绝育 |
| `avatarEmoji` | String | 头像 Emoji |
| `avatarImageData` | Data? | 头像图片（externalStorage） |
| `microchipID` | String | 芯片号 |
| `vetContact` | String | 兽医联系方式 |
| `allergies` | String | 过敏信息 |
| `passportNumber` | String | 护照号 |
| `passportExpiryDate` | Date? | 护照过期日 |
| `formerName` | String | 曾用名 |
| `lineageInfo` | String | 血统信息 |
| `themeColorHex` | String | 主题色（存 enum rawValue，如 "coral"） |
| `homeDate` | Date? | 接回家日期 |
| `birthCountry` | String | 出生国家 |
| `birthCity` | String | 出生城市 |
| `foodBrand` | String | 粮食品牌 |
| `restockDate` | Date? | 上次进粮日期（精准模式） |
| `restockWeight` | Double | 进粮重量 kg（精准模式） |
| `dailyPortionGrams` | Double | 每日饲喂量 g |
| `foodPrice` | Double | 粮食单价 |
| `isShared` | Bool | 是否多宠共享粮食 |
| `ckRecordName` | String | CloudKit 记录名（预留，未启用） |
| `createdAt` | Date | 创建时间 |
| `notes` | String | 备注 |
| `coatColor` | String | 毛色 |
| `eyeColor` | String | 眼色 |
| `currentStreak` | Int | 当前连续打卡天数（羁绊值） |
| `lastCheckInDate` | Date? | 最后打卡日期 |
| `foodTrackingModeRaw` | String | "casual"/"precise" |
| `casualOpenDate` | Date? | 佛系模式：开包日期 |
| `casualDurationDays` | Int | 佛系模式：预估能吃天数（30/60/90/180） |
| `coconutBalance` | Int | 该宠物的椰子余额（ArkSchemaV11） |

**Relationships**（全部 `.cascade`）：
`expenseLogs`, `foodRecords`, `pottyLogs`, `walkLogs`, `hygieneLogs`, `milestones`, `weightLogs`, `documents`, `healthLogs`, `careLogs`

**关键计算属性**：
- `themeColor: PetThemeColor` — 从 `themeColorHex` 解析
- `daysTogether: Int` — 距接回家天数
- `ageText: String` — "X岁Y月" 格式
- `humanEquivalentAge: Int` — 人类等效年龄（狗：1→15岁，2→24岁，之后每年+5）
- `remainingFoodGrams: Double` — 余粮克数（精准模式）
- `remainingFoodDays: Int` — 估算剩余天数
- `casualEstimatedRunOutDate: Date?` — 佛系模式耗尽日期
- `genderSymbol: String` — ♂/♀/⚧
- `speciesEmoji: String` — 🐕/🐈/🐇/🐾

---

### 3.2 Human（人类成员）
**文件**: `Ohana/Models/Human.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `name` | String | 姓名 |
| `birthday` | Date? | 生日 |
| `bloodType` | String | 血型 |
| `avatarEmoji` | String | 头像 Emoji |
| `avatarImageData` | Data? | 头像图片 |
| `role` | String | "owner"/"editor"/"viewer" |
| `appleUserIdentifier` | String | Apple ID（预留） |
| `notes` | String | 备注（`themeColor:XXXXXX` 格式存储主题色） |
| `createdAt` | Date | 创建时间 |
| `nationality` | String | 国籍（U13） |
| `city` | String | 城市（U13） |
| `coconutBalance` | Int | 椰子余额（ArkSchemaV11） |

**Relationships**: `weightLogs: [HumanWeightLog]`, `workoutLogs: [HumanWorkoutLog]`

**注意**: Human 没有 `themeColorHex` 字段，主题色存储于 `notes` 字段，格式为 `"themeColor:XXXXXX"`。

---

### 3.3 Household（家庭/岛屿）
**文件**: `Ohana/Models/Household.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `name` | String | 家庭名称（默认"我的家庭"） |
| `createdAt` | Date | 创建时间 |
| `ckShareRecordName` | String | CloudKit 分享记录名（预留） |
| `totalProsperity` | Int | 岛屿繁荣度 EXP（只增不减） |

---

### 3.4 Plant（植物）
**文件**: `Ohana/Models/Plant.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `name` | String | 植物名称 |
| `species` | String | 物种 |
| `location` | String | 放置位置 |
| `avatarEmoji` | String | 头像 Emoji |
| `wateringIntervalDays` | Int | 浇水间隔（天） |
| `fertilizingIntervalDays` | Int | 施肥间隔（天） |
| `lastWateredDate` | Date? | 上次浇水日 |
| `lastFertilizedDate` | Date? | 上次施肥日 |
| `notes` | String | 备注 |
| `createdAt` | Date | 创建时间 |

**计算属性**: `daysSinceWatered`, `daysSinceFertilized`, `needsWatering: Bool`, `needsFertilizing: Bool`

---

### 3.5 Event（日历事件）
**文件**: `Ohana/Models/Event.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `title` | String | 标题 |
| `startDate` | Date | 开始时间 |
| `endDate` | Date? | 结束时间 |
| `isAllDay` | Bool | 是否全天 |
| `eventType` | String | EventType.rawValue |
| `relatedEntityType` | String | "pet"/"human"/"plant"/"" |
| `relatedEntityId` | String | 关联实体的 UUID 字符串 |
| `recurrenceDays` | Int | 重复间隔天数（0=不重复） |
| `recurrenceEndDate` | Date? | 重复截止日 |
| `isCompleted` | Bool | 是否完成 |
| `completedOccurrences` | [String] | 已完成的日期字符串列表 |
| `createdAt` | Date | 创建时间 |
| `reminders` | [Reminder] | 关联提醒（cascade） |

---

### 3.6 Reminder（提醒）
**文件**: `Ohana/Models/Reminder.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `event` | Event? | 关联事件 |
| `scheduledAt` | Date | 预定时间 |
| `status` | String | ReminderStatus.rawValue |
| `completedAt` | Date? | 完成时间 |
| `completedBy` | String | 完成人 ID |
| `notificationId` | String | 本地通知 ID |
| `createdAt` | Date | 创建时间 |

---

### 3.7 PetPottyLog（便便日志）
**文件**: `Ohana/Models/PetPottyLog.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 时间（有 `#Index`） |
| `type` | String | PottyType.rawValue |
| `executorId` | String? | 执行人 Human.id.uuidString（V11） |
| `pet` | Pet? | 关联宠物 |

---

### 3.8 PetWalkLog（遛狗日志）
**文件**: `Ohana/Models/PetWalkLog.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `startDate` | Date | 开始时间 |
| `endDate` | Date? | 结束时间 |
| `distanceMeters` | Double | 距离（米） |
| `coconutsEarned` | Int | 本次获得椰子数 |
| `executorId` | String? | 执行人（V11） |
| `mapSnapshotData` | Data? | 地图快照（externalStorage） |
| `routeLocationsData` | Data? | 路径坐标 JSON（externalStorage） |
| `pet` | Pet? | 关联宠物 |

**静态方法**: `coconuts(for distanceMeters: Double) -> Int`（每 500m +1，最少 1）

---

### 3.9 PetHygieneLog（护理日志）
**文件**: `Ohana/Models/PetHygieneLog.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 时间（有 `#Index`） |
| `type` | String | HygieneType.rawValue |
| `pet` | Pet? | 关联宠物 |

---

### 3.10 PetWeightLog（体重日志）
**文件**: `Ohana/Models/PetWeightLog.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `weight` | Double | 体重（kg） |
| `pet` | Pet? | 关联宠物 |

---

### 3.11 PetHealthLog（健康日志）
**文件**: `Ohana/Models/PetHealthLog.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `type` | String | HealthLogType.rawValue |
| `note` | String | 备注 |
| `vetName` | String | 兽医名 |
| `cost` | Double | 花费（元） |
| `expirationDate` | Date? | 有效期（疫苗/驱虫类型，V5新增） |
| `nextCheckupDate` | Date? | 下次体检日期 |
| `pet` | Pet? | 关联宠物 |

---

### 3.12 PetDocument（证件文档）
**文件**: `Ohana/Models/PetDocument.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `title` | String | 证件标题 |
| `category` | String | DocumentCategory.rawValue |
| `issueDate` | Date? | 签发日期 |
| `expiryDate` | Date? | 过期日期 |
| `issuingAuthority` | String | 签发机构 |
| `notes` | String | 备注 |
| `reminderDate` | Date? | 提醒日期 |
| `cost` | Double | 办理费用（V6新增） |
| `attachmentData` | Data? | 附件数据（externalStorage，V6新增） |
| `attachmentFilename` | String | 附件文件名（V6新增） |
| `pet` | Pet? | 关联宠物 |

**计算属性**: `isExpired: Bool`, `isExpiringSoon: Bool`（30天内到期）

---

### 3.13 PetExpenseLog（花费日志）
**文件**: `Ohana/Models/PetExpenseLog.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `amount` | Double | 金额（元） |
| `category` | String | ExpenseCategory.rawValue |
| `note` | String | 备注 |
| `executorId` | String? | 执行人（V11） |
| `pet` | Pet? | 关联宠物 |

---

### 3.14 PetFoodRecord（喂食记录）
**文件**: `Ohana/Models/PetFoodRecord.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `brand` | String | 粮食品牌 |
| `dailyGrams` | Double | 每日克数 |
| `startDate` | Date | 开始日期 |
| `notes` | String | 备注 |
| `executorId` | String? | 执行人（V11） |
| `pet` | Pet? | 关联宠物 |

---

### 3.15 PetMilestone（里程碑）
**文件**: `Ohana/Models/PetMilestone.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 里程碑日期 |
| `title` | String | 标题 |
| `emoji` | String | 表情符号 |
| `notes` | String | 备注 |
| `pet` | Pet? | 关联宠物 |

---

### 3.16 PetCareLog（喂食/喂水/铲屎追踪）
**文件**: `Ohana/Models/PetCareLog.swift`（ArkSchemaV7新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间（有 `#Index`） |
| `type` | String | CareType.rawValue（喂食/喂水/铲屎） |
| `amountGrams` | Double | 喂食克数（feeding用） |
| `amountMl` | Double | 喂水毫升（watering用） |
| `note` | String | 备注 |
| `executorId` | String? | 执行人（V11） |
| `pet` | Pet? | 关联宠物 |

---

### 3.17 PetRelationship（宠物家庭关系）
**文件**: `Ohana/Models/PetRelationship.swift`（ArkSchemaV4新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `fromPetId` | UUID | 关系发起方宠物 ID |
| `toPetId` | UUID | 目标宠物 ID |
| `relationshipTypeRaw` | String | PetRelationshipType.rawValue |
| `note` | String | 备注 |
| `createdAt` | Date | 创建时间 |

---

### 3.18 WaterLog（喝水日志）
**文件**: `Ohana/Models/WaterLog.swift`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `amountMl` | Double | 饮水量（毫升） |
| `note` | String | 备注 |

*注：WaterLog 不关联到 Pet/Human，是全局日志（目前用途有限）*

---

### 3.19 HumanWeightLog（人类体重日志）
**文件**: `Ohana/Models/HumanWeightLog.swift`（ArkSchemaV8新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `weight` | Double | 体重（kg） |
| `human` | Human? | 关联人类 |

---

### 3.20 HumanWorkoutLog（人类运动日志）
**文件**: `Ohana/Models/HumanWorkoutLog.swift`（ArkSchemaV9新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `typeRaw` | String | WorkoutType.rawValue |
| `durationMinutes` | Int | 时长（分钟） |
| `distanceKm` | Double | 距离（公里） |
| `calories` | Int | 卡路里 |
| `steps` | Int | 步数 |
| `notes` | String | 备注 |
| `sourceHealthKit` | Bool | 是否来自 HealthKit |
| `human` | Human? | 关联人类 |

---

## 四、枚举类型完整列表

### Pet 相关
```swift
// PetThemeColor — 宠物主题色
enum PetThemeColor: String, Codable, CaseIterable {
    case coral    // #FF6B6B
    case ocean    // #4ECDC4
    case lavender // #B8A9C9
    case mint     // #95E1D3
    case sunset   // #F38181
    case berry    // #AA96DA
    case sky      // #8EC5FC
    case sage     // #A8E6CF
    case peach    // #FFD3B6
    case slate    // #95ADBE
}
// 获取颜色：pet.themeColor.color → Color
// 深色：pet.themeColor.deepColor → Color

// FoodTrackingMode — 粮食追踪模式
enum FoodTrackingMode: String, Codable, CaseIterable {
    case casual  // 佛系估算
    case precise // 精准倒数
}

// HygieneType — 护理类型（cycleDays: 周期天数）
enum HygieneType: String, Codable, CaseIterable {
    case teeth    // 刷牙，emoji: 🦷，周期: 1天
    case nails    // 剪甲，emoji: ✂️，周期: 14天
    case ears     // 清耳，emoji: 👂，周期: 7天
    case brushing // 梳毛，emoji: 🪮，周期: 3天
    case bath     // 洗澡，emoji: 🛁，周期: 14天
}

// HealthLogType — 健康记录类型
enum HealthLogType: String, Codable, CaseIterable, Identifiable {
    case general          // 常规，📋
    case vaccine          // 疫苗，💉
    case medication       // 用药（旧值兼容），💊
    case dewormingInternal // 体内驱虫，🪱
    case dewormingExternal // 体外驱虫，🐛
    case surgery          // 手术，🏥
    case dental           // 牙科，🦷
    case checkup          // 体检，🩺
    case emergency        // 急诊，🚨
    case other            // 其他，📝
}
// needsExpiration: Bool — vaccine/dewormingInternal/dewormingExternal/medication 为 true

// DocumentCategory — 证件类别
enum DocumentCategory: String, Codable, CaseIterable {
    case passport     // 护照，🛂
    case vaccine      // 疫苗本，💉
    case insurance    // 保险，🛡️
    case medical      // 病历，📋
    case registration // 登记证，📄
    case other        // 其他，📎
}

// PottyType — 便便类型
enum PottyType: String, Codable, CaseIterable {
    case perfectPoop // 完美便便，💩
    case softPoop    // 软便，💦
    case liquidPoop  // 水便，🌊
    case pee         // 尿尿，💧
}

// ExpenseCategory — 花费类别
enum ExpenseCategory: String, Codable, CaseIterable {
    case food     // 食物，🍖
    case treats   // 零食，🦴
    case medical  // 医疗，🏥
    case grooming // 美容，✂️
    case toys     // 玩具，🧸
    case other    // 其他，📦
}

// PetRelationshipType — 宠物关系类型
enum PetRelationshipType: String, CaseIterable, Codable {
    case parent, child, sibling, halfSibling, mate, other
}

// CareType — 日常护理类型（PetCareLog用）
enum CareType: String, CaseIterable, Codable {
    case feeding  // 喂食，🍽️，颜色: #FF8C00
    case watering // 喂水，💧，颜色: #00D4AA
    case litter   // 铲屎，🧹，颜色: #FFF44F
}
```

### 事件/任务相关
```swift
// EventType — 日历事件类型
enum EventType: String, Codable, CaseIterable {
    case birthday, anniversary, daily, health, task
    case shoppingList, chore
    case vaccine, externalDeworming, internalDeworming
    case grooming, vetVisit, foodChange, litterBox
    case watering, fertilizing
}

// ReminderStatus — 提醒状态
enum ReminderStatus: String, Codable {
    case pending, completed, skipped, snoozed
}
```

### 人类相关
```swift
// WorkoutType — 运动类型
enum WorkoutType: String, Codable, CaseIterable {
    case running, walking, cycling, swimming, gym, yoga, hiking, other
}
```

### 岛屿/经济相关
```swift
// IslandLevel — 岛屿等级（根据记录总量或繁荣度EXP）
enum IslandLevel: Int, CaseIterable {
    case seedling = 1  // 萌芽岛，0-49条记录
    case blooming = 2  // 繁花岛，50-199条记录
    case paradise = 3  // 极乐岛，200+条记录
}

// ProsperitySource — EXP来源
enum ProsperitySource: String {
    case walk       // 遛狗，+5 EXP
    case milestone  // 里程碑，+5 EXP
    case potty      // 便便打卡，+3 EXP
    case hygiene    // 护理，+3 EXP
    case health     // 健康记录，+3 EXP
    case watering   // 植物浇水，+2 EXP
    case feeding    // 喂食记录，+2 EXP
    case appOpen    // 打开 App，+1 EXP
}

// WealthTimeRange — 财富仪表盘时间范围
enum WealthTimeRange: String, CaseIterable {
    case day, week, month, all
}
```

---

## 五、管理器与单例

### 5.1 QuestManager（椰子经济引擎）
**文件**: `Ohana/Models/QuestManager.swift`
**模式**: `@Observable` 单例（`QuestManager.shared`）

**持久化属性（UserDefaults双写）**：
- `coconutCount: Int` — 全岛椰子总库
- `coconutLogs: [CoconutLogEntry]` — 收支明细（最多200条）
- `isPetWizardCompleted: Bool` — 任务1完成
- `isFirstMealRecorded: Bool` — 任务2完成
- `isThemeColorSet: Bool` — 任务3完成

**核心方法**：
```swift
// 新版（推荐）— 自动双边分润 + 暴击引擎
func awardAction(type: OhanaActionType, pet: Pet?, context: ModelContext) -> (humanGot: Int, petGot: Int)

// 旧版兼容 — 全岛总库only
func awardAction(type: ActionType, amount: Int, pet: Pet?, humanId: String?, allHumans: [Human])

// 全局奖励（无实体关联）
func addCoconuts(_ amount: Int, emoji: String, title: String, ...)

// 特殊奖励（幂等）
func recordFirstMeal()           // +15椰子，只触发一次
func recordThemeColorSet()       // +10椰子，只触发一次
func recordDailyStepGoal(steps:) // ≥8000步 → +10椰子，每天一次
func recordBondedWalk(humanDistanceKm:, petWalkDistanceKm:) // 同行奖励 +5，每天一次
```

**OhanaActionType 奖励规则**：
| 类型 | 人类奖励 | 宠物奖励 |
|------|---------|---------|
| `.walk(distanceMeters)` | max(1, d/100) | max(1, d/100) |
| `.potty(isLitter: true)` 铲砂 | +5 | 0 |
| `.potty(isLitter: false)` 遛狗便便 | +2 | +5 |
| `.feed` | +2 | +2 |
| `.water` | +1 | +1 |
| `.care(.bath)` | +15 | +10 |
| `.care(其他)` | +5 | +2 |
| `.health` | +20 | +20 |
| `.expense` | +10 | 0 |
| `.milestone` | +50 | +50 |

**暴击引擎**（rollCrit）：
- 1-89：无暴击（×1）
- 90-98：幸运暴击 🎉（×2）
- 99-100：奇迹发生 👑（×5，双震动）

**全岛一致性原则**：`coconutCount += pet实际到账 + human实际到账`（严格等于个人余额之和）

---

### 5.2 AchievementManager（成就系统）
**文件**: `Ohana/Models/AchievementManager.swift`
**模式**: `@Observable` 单例（`AchievementManager.shared`）

**10个成就**：
| ID | Emoji | 名称 | 条件 |
|----|-------|------|------|
| `iron_gut` | 💪 | 钢铁肠胃 | 连续7天有完美便便 |
| `iron_paw` | 🏃 | 铁脚板 | 累计遛狗≥100km |
| `walk_streak` | 📅 | 连续巡岛 | 连续7天有遛狗记录 |
| `health_hero` | 💎 | 健康达人 | 30天内无急诊/手术 |
| `nutritionist` | 🍗 | 营养师 | 喂食记录跨度≥14天 |
| `happy_birthday` | 🎂 | 生日快乐 | 当天打开App |
| `hundred_days` | 🗓️ | 相伴百日 | daysTogether≥100 |
| `first_record` | 📝 | 第一步 | 拥有任意一条记录 |
| `day_one_checkin` | ✅ | 今日全勤 | 今天有任意打卡 |
| `old_friend` | 🤝 | 老朋友 | 使用App≥7天 |

**跨维度成就**（需要HealthKit数据）：`bonded_walk`（同甘共苦）、`step_champion`（步数冠军）

---

### 5.3 PetWalkingManager（遛狗管理器）
**文件**: `Ohana/Models/PetWalkingManager.swift`
**模式**: `@Observable` 单例（`PetWalkingManager.shared`）

**状态机（WalkPhase）**: `.idle` → `.running` → `.paused` → `.finished(elapsed, poopCount)`

**主要操作**:
- `start(pet:)` — 开始遛狗，启动 GPS 追踪和计时器
- `pause()` / `resume()` — 暂停/恢复
- `stop(modelContext:, household:)` — 结束，保存 PetWalkLog + PetPottyLog，触发奖励
- `addPoop()` — 记录便便次数（结束后批量保存）
- `reset()` — 重置所有状态

**stop 时触发**：
1. 保存 `PetWalkLog`（距离、路径、地图快照）
2. 保存 N 条 `PetPottyLog`
3. `QuestManager.awardAction(.walk(distanceMeters:))`
4. 每次便便：`QuestManager.awardAction(.potty(isLitter: false))`
5. `IslandProsperityEXP.addEXP`（.walk + 每次 .potty）

---

### 5.4 LocationManager（GPS 追踪）
**文件**: `Ohana/Models/LocationManager.swift`
**模式**: `@Observable` 单例（`LocationManager.shared`），继承 `CLLocationManagerDelegate`

- `desiredAccuracy: kCLLocationAccuracyBest`，`distanceFilter: 5m`
- 背景追踪：`allowsBackgroundLocationUpdates = false`
- 防止无界增长：超过5000个点时降采样（保留每隔一个）
- `totalDistance: Double` — 累计距离（米）

---

### 5.5 StreakManager（连续打卡）
**文件**: `Ohana/Models/StreakManager.swift`
**模式**: 静态方法 struct

- `refreshStreak(for pet:, context:)` — 检查更新 `pet.currentStreak`
- 打卡条件：当天有 pottyLog / walkLog / foodRecord 任意一条
- `topStreakPet(pets:)` — 返回最高连续打卡宠物

---

### 5.6 IslandProsperityManager & IslandProsperityEXP（岛屿繁荣度）
**文件**: `Ohana/Models/IslandProsperityManager.swift` + `Ohana/Models/IslandProsperityEXP.swift`

**IslandProsperityManager**（根据记录总量估算，用于无 Household 场景）：
- `level(pets:) -> IslandLevel`
- `totalLogCount(pets:) -> Int`（walkLogs + pottyLogs + hygieneLogs + healthLogs + weightLogs + foodRecords + milestones）

**IslandProsperityEXP**（基于 `Household.totalProsperity`，主要使用）：
- `addEXP(source:, household:, context:)` — 增加 EXP（只增不减）
- `tryAddDailyOpenEXP(household:, context:)` — 每日首次打开 +1 EXP（幂等）
- `level(from prosperity:) -> IslandLevel`

**视图组件**: `IslandEXPBadgeView` — 等级徽章 + 进度条

---

## 六、ViewModels

### 6.1 IslandWealthViewModel（财富仪表盘 ViewModel）
**文件**: `Ohana/ViewModels/IslandWealthViewModel2.swift`
**模式**: `@Observable`

**关键属性**：
- `timeRange: WealthTimeRange` — 时间范围筛选
- `pets: [Pet]`, `humans: [Human]` — 由 View 注入
- `petColorMap: [String: Color]` — 宠物 id → 主题色，由 View 注入
- `totalAssets: Int` — `QuestManager.shared.coconutCount`

**计算属性**：
- `leaderboard: [WealthLeaderRow]` — 直接读个人 `coconutBalance`，按余额排序
- `chartBars: [WealthBarData]` — 按时间桶聚合 log，用于趋势图
- `color(for entityId: String) -> Color` — 优先 petColorMap，否则调色板

**颜色调色板**：`[#C8FF00, #FFF44F, #00D4AA, #FF8C42, #FF4757, #80FFEA]`

---

### 6.2 IslandUnifiedStatsViewModel（全岛统计 ViewModel）
**文件**: `Ohana/ViewModels/IslandUnifiedStatsViewModel.swift`
**模式**: `@Observable`

**功能**：体重变动%趋势 + 近7天探索里程 + 月度排行（干饭王/自律王）

**数据结构**：
- `WeightDeltaPoint` — 相对基准的体重变动百分比
- `ExplorationPoint` — 按天聚合的探索里程
- `FameRanking` — 月度变动排名

**辅助属性**：`weightDeltasBySeries`、`last7Days`、`explorationByDayAndEntity`

---

## 七、Views 结构与功能

### 7.1 应用入口

| 文件 | 说明 |
|------|------|
| `OhanaApp.swift` | `@main`，初始化 `SharedModelContainer`，注入 `modelContainer` |
| `RootView.swift` | `@AppStorage("ohana_has_onboarded")` 控制 Onboarding/ContentView 路由；数据库降级警告 |
| `ContentView.swift` | `NavigationStack` + `OverviewView`；全局 `navigationDestination`（Pet/Human/Plant）；`GlobalCoconutButtonOverlay`；`GlobalWalkBanner` |

---

### 7.2 首页 OverviewView
**文件**: `Ohana/Views/OverviewView.swift`（约3000行）

**主要功能**：
- 问候语（Good morning/afternoon/evening/night）
- 岛屿背景（`ArkBackgroundView(level: islandLevel)`）
- 天气粒子特效（`IslandMoodWeatherView`）
- 宠物/人类/植物为空时的引导页
- 动态内容区域（sectionOrder 可自定义）：
  - `petCards`：宠物卡片轮播（`CritterDeckCarousel`）
  - `todayTasks`：今日任务（`SmartTodayCard` / `DailyQuestsCard`）
  - `islandStats`：全岛统计
  - `quickAccess`：快速打卡区域
- QuickAction 快捷打卡（可自定义，存于 `quickActionItems_v2` UserDefaults）
- 日历入口、设置入口、成员管理（`CrewRosterOverlay`）
- 首日椰子奖励、记忆碎片卡片（`MemoryDropCard`）

---

### 7.3 宠物详情 PetDetailView
**文件**: `Ohana/Views/Details/PetDetailView.swift`（约1375行）

**布局结构**（ScrollView 垂直排列）：
1. `PetHeroRow` — Hero 横排卡（头像+基本信息）
2. `PetHUDVitalSection` — 发光环 + 活力大字
3. `PetAlertScrollSection` — 智能预警横滚区（有警告时出现）
4. `PetChartDashboard` — 图表仪表盘（体重/遛狗/便便/花费/余粮）
5. `PetHealthHubCard` — 免疫健康中枢卡
6. `PetHygieneCard` — 护理卡（点击进入 `PetHygieneDetailView`）
7. `DietCardWithQuickActions` — 饮食排泄快速打卡卡
8. **三卡横排（HStack）**：
   - `compactDocumentsCard` → `DocumentsListView`
   - `compactMilestonesCard`（内联）
   - `compactAchievementsCard` → `AchievementWallView`
9. `PetUnifiedTimeline` — 统一时间轴（岁月史书）
10. `deleteDangerZone` — 危险操作区

**全局状态**：所有 `@State` 变量控制 sheet/navigationDestination 的显示

**Tab 枚举**（向下兼容）：`PetDetailTab { overview, health, records }`

---

### 7.4 详情页列表（Details/）

| 文件 | 进入方式 | 功能 |
|------|---------|------|
| `PetHealthDetailView.swift` | navigationDestination | 健康详情：免疫状态总览（4项环形进度）+ 12个月趋势图 + 时间轴列表 |
| `PetHygieneDetailView.swift` | NavigationLink（PetHygieneCard头部） | 护理详情：5项护理环形总览 + 每类7天柱状图 + 打卡按钮 |
| `PetFoodManagementView.swift` | sheet | 饮食管理：双轨制（佛系/精准）+ 喂食打卡 + 历史图表 |
| `PetChartDashboard.swift` | 内嵌在 PetDetailView | 体重/遛狗/便便/花费/余粮图表仪表盘 |
| `PetHealthLogCard.swift` | 内嵌 | 健康日志卡片 |
| `PetHygieneCard.swift` | 内嵌 | 护理状态卡片 |
| `PetImmunityCard.swift` | 内嵌 | 免疫状态卡片 |
| `PetDocumentsCard.swift` | 内嵌 | 证件状态摘要卡 |
| `PetMilestonesCard.swift` | 内嵌 | 里程碑摘要卡 |
| `CatCareStationCard.swift` | 内嵌 | 猫咪护理站 |
| `PetCareTrackingCard.swift` | 内嵌 | 喂食/喂水/铲屎打卡追踪 |
| `PetBasicInfoDetailView.swift` | navigationDestination | 宠物基本信息详情编辑 |
| `WeightHistoryView.swift` | navigationDestination | 宠物体重历史 + 折线图 |
| `ExpenseHistoryView.swift` | navigationDestination | 花费历史 + 分类图表 |
| `DocumentsListView.swift` | NavigationLink | 证件列表 |
| `VaccinePassportView.swift` | sheet | 疫苗护照 |
| `AchievementWallView.swift` | sheet | 成就墙 |
| `PottyOverviewView.swift` | sheet | 便便概览 |
| `WalkSummarySheet.swift` | sheet | 遛狗总结 |
| `WalkDetailView.swift` | 内嵌 | 遛狗详情（地图+路线） |
| `SitterCardPreviewSheet.swift` | sheet | 保姆卡预览 |
| `HumanDetailView.swift` | navigationDestination | 人类成员详情 |
| `HumanWeightHistoryView.swift` | 内嵌 | 人类体重历史 |
| `HumanWorkoutCard.swift` | 内嵌 | 人类运动卡片（HealthKit集成） |
| `PlantDetailView.swift` | navigationDestination | 植物详情 |
| `IslandWealthDashboard2.swift` | NavigationLink | 财富仪表盘 |
| `IslandUnifiedDashboardView.swift` | sheet/link | 全岛统计仪表盘 |
| `WeeklyReportCard.swift` | 内嵌 | 周报卡片 |

---

### 7.5 财富仪表盘 IslandWealthDashboardView
**文件**: `Ohana/Views/Details/IslandWealthDashboard2.swift`

**布局**（ZStack三层）：
- L0：`ArkBackgroundView().ignoresSafeArea()`
- L1：图表区（`chartArea`，上半屏，padding top 80）
- L2：底部卡片（`bottomCard`，`.ignoresSafeArea(edges: .bottom)`，无边距）

**图表**：按实体分组的堆叠柱状图（`BarMark`），每条 bar 用 `vm.color(for: bar.entityId)` 着宠物主题色

**底部卡片内容**：
- 全岛总资产大数字（`vm.totalAssets`，数字跳动动画）
- 时间范围选择器（日/周/月/全部）
- 财富排行榜（直接读个人 `coconutBalance`，而非聚合日志）
- 排名徽章：第1 goLime，第2 goYellow，第3 goTeal

---

### 7.6 全局组件（Components/）

| 文件 | 说明 |
|------|------|
| `GlobalCoconutButtonOverlay.swift` | 全局悬浮椰子按钮（右上角）→ CoconutLogView |
| `GlobalWalkBanner.swift` | 全局遛狗悬浮横幅（底部）|
| `ArkCrewIDCardView.swift` | 成员 ID 卡片（正面鲜蓝渐变 + 背面深蓝 bento）|
| `DailyQuestsCard.swift` | 每日任务卡片 |
| `SmartTodayCard.swift` | 智能今日卡片 |
| `IslandStatComponents.swift` | 全岛统计组件（MiniBarChart, PetStatCard 等）|
| `MemoryDropCard.swift` | 记忆碎片卡（可滑动消失）|
| `SwipeableEventRow.swift` | 可滑动事件行（完成/删除） |
| `StreakBadgeView.swift` | 连续打卡徽章 |
| `WelcomeQuestBentoView.swift` | 欢迎任务 Bento 格局 |
| `QuickPottySheet.swift` | 快速便便打卡 Sheet（`.height(320)`）|
| `QuickWeightSheet.swift` | 快速体重记录 Sheet |
| `PetPickerSheet.swift` | 宠物选择器 Sheet |
| `AddExpenseSheet.swift` | 快速记账 Sheet |
| `AddHealthRecordSheet.swift` | 添加健康记录 Sheet |

---

### 7.7 表单/向导（Forms/）

| 文件 | 说明 |
|------|------|
| `AddPetWizardView.swift` | 添加宠物向导（约63KB，多步骤） |
| `AddHumanWizardView.swift` | 添加人类成员向导 |
| `EditPetSheet.swift` | 编辑宠物信息 Sheet |
| `AddEventView.swift` | 添加日历事件 |
| `AddEntityView.swift` | 添加实体（选择类型入口） |
| `AddDocumentSheet.swift` | 添加证件（含附件上传） |
| `AddPlantView.swift` | 添加植物 |

---

### 7.8 首页子模块（Home/）

| 文件 | 说明 |
|------|------|
| `CritterDeckCarousel.swift` | 宠物卡片轮播（顶部翻转效果，含 HumanIDCardView）|
| `CrewRosterOverlay.swift` | 全岛成员花名册（宠物+人类+植物管理）|
| `OasisRewardView.swift` | 绿洲奖励视图 |
| `CoconutLogView.swift` | 椰子收支明细日志 |
| `IslandMoodWeatherView.swift` | 岛屿心情/天气粒子特效 |
| `WalkTrackingCard.swift` | 遛狗追踪实时卡片 |

---

### 7.9 其他关键视图

| 文件 | 说明 |
|------|------|
| `ArkBackgroundView.swift` | 深蓝渐变全屏背景，接受 `level: IslandLevel` 参数改变渐变色 |
| `CalendarView.swift` | 日历视图，Go风格 chip 筛选器，青柠选中日期 |
| `OnboardingView.swift` | 新手引导（3步骤），`@AppStorage("ohana_has_onboarded")` |
| `SettingsView.swift` | 设置页（主题/通知/数据管理等） |

---

## 八、设计系统

### 8.1 颜色系统（ColorExtensions.swift）

**Go UI 主色板**：
```swift
Color.goPrimary      // #4338FF（深紫蓝，主品牌色）
Color.goPrimaryLight // #5B52FF
Color.goPrimaryDark  // #3028CC
Color.goBackground   // #4338FF（同主色）
Color.goLime         // #C8FF00（青柠，主强调色）
Color.goLimeLight    // #E8FFB0
Color.goMint         // #B8FFD0
Color.goYellow       // #FFF44F（黄色，次强调/数字高亮）
Color.goYellowBright // #FFEB3B
Color.goCardWhite    // #FFFFFF
Color.goCardLight    // #F0F0FF
Color.goCardBlue     // #5B6AFF（卡片蓝）
Color.goCardGreen    // #BFFF80
Color.goCardCyan     // #80FFEA（青色，健康/护理）
Color.goTeal         // #00D4AA（青绿）
Color.goOrange       // #FF8C42（橙色）
Color.goRed          // #FF4757（红色，危险/逾期）
Color.goDarkBlue     // #1A0E4B（卡片深色背景）
Color.goDeepNavy     // #0D0638（更深蓝）
```

**Legacy 颜色**（保留兼容）：
```swift
Color.arkCoral       // #FF5E3A（旧主色）
Color.arkInk         // #1A1A2E（深墨色）
Color.arkCardDark    // #2D2D3A
Color.arkMint        // #00D4AA
```

**Figma 设计令牌**（亮/暗模式自适应）：
- `alertSuccessBg/Border/Text/Icon`
- `alertWarningBg/Border/Text/Icon`
- `alertErrorBg/Border/Text/Icon`
- `alertInfoBg/Border/Text/Icon`
- `tokenButtonPrimaryBg/Text`（#4235FF / white）
- `tokenButtonSecondaryBg/Text`（#C8FF00 / black）

**颜色工具方法**：
- `Color(hex: "RRGGBB")` — HEX 初始化
- `Color(light:, dark:)` — 亮/暗模式自适应
- `color.toHex() -> String?` — 转 HEX 字符串

---

### 8.2 组件与修饰符（OhanaDesignSystem.swift）

**卡片修饰符**：
```swift
.goCard(color: .white, cornerRadius: 24)         // 纯色卡片
.goBlueCard(cornerRadius: 24)                    // 蓝色渐变卡片（goCardBlue→goPrimary）
.goTranslucentCard(cornerRadius: 20)             // 半透明深色卡片（goDarkBlue渐变）
.ohanaGlassStyle(cornerRadius: 32)               // 毛玻璃效果
.neoWhiteCard(cornerRadius: 32)                  // 白色阴影卡片
```

**按钮修饰符**：
```swift
.capsuleButton()      // 白色胶囊按钮（arkInk文字）
.neonCapsuleButton()  // 霓虹黄绿胶囊按钮（arkInk文字）
.capsuleButtonDark()  // 深色胶囊按钮（白色文字）
```

**字体系统（OhanaFont）**：
全部使用 `.system(design: .rounded)`：
- `OhanaFont.largeTitle()` → size 34 .black
- `OhanaFont.title()` → size 24 .bold
- `OhanaFont.headline()` → size 16 .bold
- `OhanaFont.body()` → size 15 .medium
- `OhanaFont.metric(size:)` → 任意大小 .black（数字专用）

**其他组件**：
- `GoDashedDivider` — 虚线分割线（默认 `.white.opacity(0.2)`）
- `OhanaDashedDivider` — 另一版本虚线分割（dash: [6,4]）
- `GoBottomTabBar` — 底部 Tab 栏（选中项展开+胶囊背景）
- `AlertBanner` — 设计令牌警告横幅（success/warning/error/info）
- `CoconutBalanceCapsule` — 椰子余额胶囊（工具栏用）
- `CoconutRewardModifier` — 椰子奖励弹跳动画（`.coconutRewardOverlay(trigger:, amount:)`）
- `OhanaSheetWrapper` — Sheet 包装容器（统一标题栏 + 关闭按钮）
- `NoiseTextureView` — 噪点纹理叠加层
- `IslandEXPBadgeView` — 岛屿 EXP 徽章 + 进度条

---

## 九、数据流与关键逻辑

### 9.1 用户数据流向（人类主题色特殊说明）
```
Pet:   pet.themeColorHex → PetThemeColor.allCases.first { $0.rawValue == hex } → .color → Color
Human: human.notes → 检测 "themeColor:XXXXXX" → Color(hex: "XXXXXX")
       （没有 themeColorHex 字段！）
```

### 9.2 椰子经济数据一致性
```
全岛总库 QuestManager.coconutCount
    = Σ pet.coconutBalance（所有宠物）
    + Σ human.coconutBalance（所有人类）
（新版 awardAction 严格保证这个等式）
```

### 9.3 打卡 → 奖励 → EXP 链路
```
用户打卡（喂食/遛狗/护理等）
  ↓
QuestManager.awardAction(type: .xxx, pet: pet, context: context)
  ↓ 自动 fetch Human, 计算暴击
  ↓ pet.coconutBalance += finalPet
  ↓ human.coconutBalance += finalHuman
  ↓ coconutCount += islandDelta
  ↓ appendLog(CoconutLogEntry)
  ↓ context.save()
  ↓
IslandProsperityEXP.addEXP(source: .xxx, household: h, context: context)
  ↓ household.totalProsperity += expValue
  ↓ context.safeSave()
```

### 9.4 遛狗完整流程
```
PetWalkingManager.start(pet:)
  → LocationManager.startTracking()（GPS）
  → Timer 每秒更新 elapsedTime
  → GlobalWalkBanner 实时显示

PetWalkingManager.stop(modelContext:, household:)
  → 生成 PetWalkLog（含地图快照、路径数据）
  → 生成 N 条 PetPottyLog（如有便便）
  → QuestManager.awardAction(.walk + .potty × N)
  → IslandProsperityEXP.addEXP（.walk + .potty × N）
  → modelContext.safeSave()
  → showSummary = true → WalkSummarySheet
```

### 9.5 Swift Charts 使用注意事项
```swift
// ✅ 正确：unit 参数只支持具体值
BarMark(x: .value("时间", date, unit: .day), ...)
BarMark(x: .value("时间", date, unit: .month), ...)

// ❌ 错误：不能动态传 Calendar.Component（会 fatal error）
let component: Calendar.Component = ...
BarMark(x: .value("时间", date, unit: component), ...)  // CRASH!

// 正确做法：用 switch 返回 computed property
private var chartUnit: Calendar.Component {
    switch timeRange {
    case .day: return .hour
    case .week, .month: return .day
    case .all: return .month
    }
}
// 然后在 BarMark 中使用 chartUnit（虽然看起来一样，但类型检查在编译时通过）
```

### 9.6 SwiftData 注意事项
```swift
// 安全保存（全项目统一使用）
modelContext.safeSave()  // 来自 ModelContextExtensions.swift

// 永远不要直接用（除 QuestManager 内部）
try? context.save()

// @Attribute(.externalStorage) 的字段不参与正常 SwiftData query
// 如 avatarImageData, mapSnapshotData

// 删除宠物时需手动删除关联 Events
// （Event.relatedEntityId == pet.id.uuidString 的事件不在 cascade 范围内）
```

---

## 十、Schema 版本历史

| 版本 | App 版本 | 新增内容 |
|------|---------|---------|
| V1 | v4.5.0 | 首个版本化 Schema |
| V2 | v4.7.0 | Pet.currentStreak + lastCheckInDate |
| V3 | v4.8.0 | Household.totalProsperity |
| V4 | v4.9.0 | PetRelationship 表 |
| V5 | v5.0.0 | PetHealthLog.expirationDate |
| V6 | v5.1.0 | PetDocument.cost + attachmentData + attachmentFilename |
| V7 | v5.2.0 | PetCareLog 表（喂食/喂水/铲屎追踪） |
| V8 | v5.6.0 | HumanWeightLog + Human.nationality/city |
| V9 | v5.7.0 | HumanWorkoutLog |
| V10 | v6.8.0 | Pet.foodTrackingModeRaw/casualOpenDate/casualDurationDays |
| V11 | v7.0.0 | Pet/Human.coconutBalance；所有 Log.executorId |

**当前**: `ArkSchemaV11`（`SharedModelContainer.make()` 使用）

**迁移**: 全部使用 `MigrationStage.lightweight`（轻量迁移）

---

## 十一、UserDefaults Keys 索引

| Key | 类型 | 说明 | 存储位置 |
|-----|------|------|---------|
| `ohana_has_onboarded` | Bool | 是否已完成引导 | `@AppStorage` |
| `currentActiveHumanId` | String | 当前活跃人类成员 UUID | UserDefaults |
| `quest_coconutCount` | Int | 全岛椰子总数 | QuestManager |
| `quest_coconutLogs` | Data | 椰子收支明细（JSON） | QuestManager |
| `quest_isPetWizardCompleted` | Bool | 任务1完成 | QuestManager |
| `quest_isFirstMealRecorded` | Bool | 任务2完成 | QuestManager |
| `quest_isThemeColorSet` | Bool | 任务3完成 | QuestManager |
| `quest_stepRewardLastDate` | Date | 步数奖励最后领取日 | QuestManager |
| `quest_bondedWalkLastDate` | Date | 人宠联动最后领取日 | QuestManager |
| `prosperity_lastOpenDate` | Date | 今日打开EXP最后领取日 | IslandProsperityEXP |
| `ohana_db_fallback_active` | Bool | 数据库降级标记 | SharedModelContainer |
| `ohana_db_fallback_error` | String | 数据库错误描述 | SharedModelContainer |
| `quickActionItems_v2` | String | QuickAction JSON | OverviewView |
| `home_section_order` | String | 首页 section 排序 | OverviewView |
| `home_section_hidden` | String | 首页隐藏 section | OverviewView |
| `overview_activeCritterId` | String | 首页顶牌宠物 ID | OverviewView |

---

## 十二、待实现 Backlog

以下功能在代码中有预留/引用，但尚未完整实现：

- **CloudKit 同步**：`ckRecordName`、`ckShareRecordName` 字段预留，`cloudKitDatabase: .none`
- **Apple 家庭分享**：`Human.appleUserIdentifier` 字段预留
- **本地通知**：`Reminder.notificationId` 预留，通知调度逻辑未完整实现
- **HealthKit 完整集成**：HumanWorkoutLog 支持 `sourceHealthKit`，但实际 HealthKit 读取需进一步完善
- **PlantDetailView 完整功能**：浇水/施肥打卡记录扩展
- **WaterLog 完整集成**：模型存在但 UI 集成有限

---

## 十三、代码规范与约定

### 13.1 颜色使用
```swift
// ✅ 正确（必须写 Color. 前缀）
.foregroundStyle(Color.goLime)
.background(Color.goTeal)

// ❌ 错误（在 foregroundStyle/background 中不能直接用 .goLime）
.foregroundStyle(.goLime)
```

### 13.2 ViewModel 模式
```swift
// ✅ 使用 @Observable（不用 ObservableObject/Combine）
@Observable
final class MyViewModel {
    var someState = ...
}

// 在 View 中
@State private var vm = MyViewModel()
```

### 13.3 模型写入
```swift
// ✅ 统一使用 safeSave
modelContext.safeSave()

// ✅ SwiftData 模型写入必须在 MainActor 上
DispatchQueue.main.async {
    walkLog.mapSnapshotData = jpegData
}
```

### 13.4 宠物主题色获取
```swift
// ✅ 从宠物获取主题色
let color: Color = pet.themeColor.color
let deepColor: Color = pet.themeColor.deepColor
let hexString: String = pet.themeColor.hexValue

// ✅ 财富图表中构建 petColorMap 注入 ViewModel
let petColorMap: [String: Color] = Dictionary(
    uniqueKeysWithValues: pets.map { ($0.id.uuidString, $0.themeColor.color) }
)
```

### 13.5 打卡奖励调用
```swift
// ✅ 推荐：新版（自动双边分润）
QuestManager.shared.awardAction(
    type: .care(type: .bath),
    pet: pet,
    context: modelContext
)

// ✅ 旧版（仅全岛总库，无实体分润）
QuestManager.shared.addCoconuts(10, emoji: "🎉", title: "奖励")

// ❌ 已废弃但仍兼容
QuestManager.shared.awardAction(type: .walk, amount: 5, pet: pet, humanId: "...", allHumans: [...])
```

---

*本文档由代码自动分析生成，完整覆盖项目所有 Swift 文件（截至 Phase 57，2026-03-05）*
