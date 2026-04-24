# Ohana App 完整代码参考文档

> **版本**: v8.0.0 | **平台**: iOS 17+ | **框架**: SwiftUI + SwiftData + Swift Charts
> **语言**: Swift 6 | **模拟器**: iPhone 17 Pro (iOS 26.2) | **编译状态**: ✅ Build Succeeded
> **原名**: Ark | **品牌名**: Ohana（代码中部分标识符保留 Ark 前缀）
> **最后更新**: 2026-04-16（Phase 57+，Schema V34）

---

## 一、项目结构

```
Ohana/
├── OhanaApp.swift              # @main 入口，ModelContainer 初始化
├── ContentView.swift           # NavigationStack + 全局覆盖层
├── Models/                     # 34个数据模型 + 13个管理器/服务
├── Views/
│   ├── RootView.swift          # Onboarding 路由守卫
│   ├── ArkBackgroundView.swift # 全局深色渐变背景
│   ├── OhanaDesignSystem.swift # 设计系统（颜色/组件/修饰符）
│   ├── OverviewView.swift      # 首页（主要入口）
│   ├── CalendarView.swift      # 日历视图
│   ├── OnboardingView.swift    # 新手引导
│   ├── SettingsView.swift      # 设置页
│   ├── MaterialDashboardView.swift # 宠物仪表盘（AI Studio 同款）
│   ├── Details/                # 50+ 个详情页/卡片
│   ├── Components/             # 40+ 个全局组件
│   ├── Forms/                  # 9个表单/向导
│   └── Home/                   # 16个首页子模块
├── ViewModels/                 # 2个 @Observable ViewModel
└── Utilities/                  # ColorExtensions + ModelContextExtensions + 4个工具类
```

---

## 二、技术栈与架构

### 核心框架
- **SwiftUI** — 全 declarative UI，无 UIKit ViewController
- **SwiftData** — 持久化（`@Model`, `@Query`, `ModelContext`），版本化 Schema（V1→V34）
- **Swift Charts** — BarMark / LineMark / SectorMark 图表（`import Charts`）
- **CoreLocation** — GPS 轨迹追踪（遛狗功能）
- **MapKit** — 地图快照生成
- **HealthKit** — 人类运动数据读取（`HumanWorkoutLog.sourceHealthKit`）
- **Vision** — iOS 17 原生抠像（`VNGenerateForegroundInstanceMaskRequest`）
- **UserNotifications** — 本地推送（用药提醒、事件提醒）

### 状态管理
- **@Observable** — `QuestManager`, `AchievementManager`, `PetWalkingManager`, `LocationManager`, `OasisTreeManager`, `StreakRewardManager`（单例）
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
- **UserDefaults**：`QuestManager` 椰子余额/日志、`AppStorage` UI 状态、`OasisTreeManager` 能量注入量
- **外部存储**（`@Attribute(.externalStorage)`）：`avatarImageData`、`mapSnapshotData`、`routeLocationsData`、`PetPhotoLog.imageData`

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
| `casualDurationDays` | Int | 佛系模式：预估能吃天数 |
| `coconutBalance` | Int | 该宠物的椰子余额（V11） |
| `passedAwayDate` | Date? | 离世日期（V14，Rainbow Bridge） |
| `personalityTagsRaw` | String | 性格标签 id 列表，逗号分隔（V26） |
| `cardStyleRaw` | String | 卡片背面风格（V19） |
| `weeklyWalkGoalKm` | Double | 每周遛狗目标公里数（V23） |

**Relationships**（全部 `.cascade`）：
`expenseLogs`, `foodRecords`, `pottyLogs`, `walkLogs`, `hygieneLogs`, `milestones`, `weightLogs`, `documents`, `healthLogs`, `careLogs`, `medications`, `insurances`, `photoLogs`, `symptomLogs`, `heatCycleLogs`

**关键计算属性**：
- `themeColor: PetThemeColor` — 从 `themeColorHex` 解析
- `daysTogether: Int` — 距接回家天数
- `ageText: String` — "X岁Y月" 格式
- `humanEquivalentAge: Int` — 人类等效年龄
- `remainingFoodGrams: Double` — 余粮克数（精准模式）
- `remainingFoodDays: Int` — 估算剩余天数
- `genderSymbol: String` — ♂/♀/⚧
- `speciesEmoji: String` — 🐕/🐈/🐇/🐾
- `hasPassedAway: Bool` — 是否已离世
- `personalityTagIdList: [String]` — 从 `personalityTagsRaw` 解析的标签列表

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
| `avatarImageData` | Data? | 头像图片（externalStorage） |
| `role` | String | "owner"/"editor"/"viewer" |
| `appleUserIdentifier` | String | Apple ID（预留） |
| `notes` | String | 备注 |
| `createdAt` | Date | 创建时间 |
| `nationality` | String | 国籍（V13） |
| `city` | String | 城市（V13） |
| `coconutBalance` | Int | 椰子余额（V11） |
| `shouldShowOnHome` | Bool | 是否在首页卡堆显示（V13） |
| `themeColorHex` | String | 主题色正式字段（V15，迁移自 notes hack） |
| `privateFieldsRaw` | String | 隐私控制字段列表，逗号分隔（V16） |
| `heightCm` | Double | 身高（V16） |

**Relationships**: `weightLogs: [HumanWeightLog]`（cascade）, `workoutLogs: [HumanWorkoutLog]`（cascade）

**重要变更（V15 起）**: `themeColorHex` 已成为正式字段，不再使用 `notes` 中的 `"themeColor:XXXXXX"` hack。`HumanExtensions.swift` 中的 `themeColor` 计算属性仍提供兼容访问。

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
| `avatarImageData` | Data? | 头像图片（externalStorage，V27） |
| `wateringIntervalDays` | Int | 浇水间隔（天） |
| `fertilizingIntervalDays` | Int | 施肥间隔（天） |
| `lastWateredDate` | Date? | 上次浇水日 |
| `lastFertilizedDate` | Date? | 上次施肥日 |
| `notes` | String | 备注 |
| `createdAt` | Date | 创建时间 |
| `themeColorHex` | String | 主题色（V27） |

**Relationships**: `careLogs: [PlantCareLog]`（cascade，V27）

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
| `assigneeId` | String? | 被分配人 Human.id（V12） |
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
| `behaviorNotes` | String | 行为备注（V33） |
| `moodRating` | Int | 心情评分（V33，1-5） |
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
| `weightUnit` | String | 单位（"kg"/"lbs"，V23） |
| `bcsScore` | Int | BCS 体况评分 1-9（V24，0 表示未记录） |
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
| `expirationDate` | Date? | 有效期（疫苗/驱虫类型，V5） |
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
| `cost` | Double | 办理费用（V6） |
| `attachmentData` | Data? | 附件数据（externalStorage，V6） |
| `attachmentFilename` | String | 附件文件名（V6） |
| `pet` | Pet? | 关联宠物 |

**Relationships**: `attachments: [PetDocumentAttachment]`（cascade，V20）

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
| `photoData` | Data? | 配图（externalStorage，V17） |
| `location` | String | 地点记录（V18） |
| `pet` | Pet? | 关联宠物 |

---

### 3.16 PetCareLog（喂食/喂水/铲屎/换水追踪）
**文件**: `Ohana/Models/PetCareLog.swift`（V7新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间（有 `#Index`） |
| `type` | String | CareType.rawValue（喂食/喂水/铲屎/换水） |
| `amountGrams` | Double | 喂食克数（feeding用） |
| `amountMl` | Double | 喂水毫升（watering用） |
| `note` | String | 备注 |
| `executorId` | String? | 执行人（V11） |
| `pet` | Pet? | 关联宠物 |

---

### 3.17 PetRelationship（宠物家庭关系）
**文件**: `Ohana/Models/PetRelationship.swift`（V4新增）

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

---

### 3.19 HumanWeightLog（人类体重日志）
**文件**: `Ohana/Models/HumanWeightLog.swift`（V8新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `weight` | Double | 体重（kg） |
| `human` | Human? | 关联人类 |

---

### 3.20 HumanWorkoutLog（人类运动日志）
**文件**: `Ohana/Models/HumanWorkoutLog.swift`（V9新增）

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

### 3.21 WishlistItem（椰子心愿单）
**文件**: `Ohana/Models/WishlistItem.swift`（V12新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `title` | String | 心愿标题 |
| `cost` | Int | 所需椰子数 |
| `creatorId` | String | 创建者 Human.id.uuidString |
| `isRedeemed` | Bool | 是否已兑换 |
| `redeemedById` | String? | 兑换人 ID |
| `createdAt` | Date | 创建时间 |

---

### 3.22 HumanMedication（人类药物提醒）
**文件**: `Ohana/Models/HumanMedication.swift`（V21新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `humanId` | String | 所属 Human.id.uuidString |
| `name` | String | 药品名称 |
| `dosage` | String | 剂量描述（如 "1 片"、"5mg"） |
| `frequencyRaw` | String | MedicationFrequency.rawValue |
| `customFrequencyNote` | String | 自定义频率说明 |
| `firstDoseTime` | Date | 第一次服药时间（定每日时刻） |
| `startDate` | Date | 开始日期 |
| `endDate` | Date? | 结束日期（nil=长期） |
| `colorHex` | String | 颜色标签（hex） |
| `notes` | String | 备注 |
| `isActive` | Bool | 是否激活提醒 |
| `createdAt` | Date | 创建时间 |

**计算属性**: `frequency: MedicationFrequency`, `isActiveToday: Bool`, `daysRemaining: Int?`

---

### 3.23 HumanMedicationLog（人类服药记录）
**文件**: `Ohana/Models/HumanMedicationLog.swift`（V34新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `humanId` | String | 所属 Human ID |
| `medicationId` | String | 对应 HumanMedication.id.uuidString |
| `scheduledTime` | Date | 计划服药时间 |
| `recordedTime` | Date? | 实际操作时间 |
| `statusRaw` | String | HumanMedicationStatus.rawValue |
| `createdAt` | Date | 创建时间 |

**计算属性**: `status: HumanMedicationStatus`

---

### 3.24 HumanHealthReport（人类身体检测报告）
**文件**: `Ohana/Models/HumanHealthReport.swift`（V22新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `humanId` | String | 所属 Human ID |
| `reportTypeRaw` | String | HealthReportType.rawValue |
| `conclusionRaw` | String | ReportConclusion.rawValue |
| `hospitalName` | String | 医院名称 |
| `doctorName` | String | 医生名称 |
| `reportDate` | Date | 报告日期 |
| `nextCheckDate` | Date? | 下次复查日期 |
| `summary` | String | 报告摘要 |
| `notes` | String | 备注 |
| `colorHex` | String | 颜色标签（hex） |
| `createdAt` | Date | 创建时间 |

**计算属性**: `reportType: HealthReportType`, `conclusion: ReportConclusion`, `daysUntilNextCheck: Int?`

---

### 3.25 PetMedication（宠物用药计划）
**文件**: `Ohana/Models/PetMedication.swift`（V24新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `name` | String | 药品名称 |
| `dosage` | String | 剂量（如 "1 片"、"5ml"） |
| `frequencyRaw` | String | PetMedicationFrequency.rawValue |
| `customFrequencyNote` | String | 自定义频率说明 |
| `startDate` | Date | 开始日期 |
| `endDate` | Date? | 结束日期（nil=长期） |
| `colorHex` | String | 卡片颜色标签 |
| `notes` | String | 备注 |
| `isActive` | Bool | 是否激活 |
| `createdAt` | Date | 创建时间 |
| `pet` | Pet? | 关联宠物 |

**计算属性**: `frequency: PetMedicationFrequency`, `isActiveToday: Bool`, `daysRemaining: Int?`, `statusLabel: String`

---

### 3.26 PetInsurance（宠物保险）
**文件**: `Ohana/Models/PetInsurance.swift`（V25新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `companyName` | String | 保险公司 |
| `policyNumber` | String | 保单号 |
| `productName` | String | 产品名称 |
| `annualPremium` | Double | 年费（元） |
| `coverageAmount` | Double | 保额（元） |
| `startDate` | Date | 生效日期 |
| `renewalDate` | Date | 续期日期 |
| `notes` | String | 备注（承保范围、排除项等） |
| `isActive` | Bool | 是否有效 |
| `createdAt` | Date | 创建时间 |
| `paymentFrequencyRaw` | String | InsurancePaymentFrequency.rawValue（V30） |
| `paymentDayOfMonth` | Int | 每月扣款日（V31，默认 1） |
| `showInCalendar` | Bool | 是否在日历显示（V31） |
| `otherFeeAmount` | Double | 其他费用（V31） |
| `otherFeeNote` | String | 其他费用说明（V31） |
| `firstPremiumPaymentDate` | Date? | 首期保费缴费日（V32） |
| `pet` | Pet? | 关联宠物 |
| `claims` | [InsuranceClaim] | 报销记录（cascade，V30） |

**计算属性**: `paymentFrequency`, `premiumPerPeriod`, `totalPerPeriod`, `totalApprovedReimbursement`, `daysUntilRenewal`, `renewalStatusLabel`, `renewalStatusColor`

---

### 3.27 InsuranceClaim（保险报销记录）
**文件**: `Ohana/Models/InsuranceClaim.swift`（V30新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `claimDate` | Date | 提交申请日期 |
| `incidentDate` | Date | 就诊/事故日期 |
| `totalExpense` | Double | 本次总花费（元） |
| `claimedAmount` | Double | 申请报销金额（元） |
| `approvedAmount` | Double | 实际到账金额（0=待处理） |
| `statusRaw` | String | ClaimStatus.rawValue |
| `note` | String | 备注 |
| `relatedExpenseLogId` | String? | PetExpenseLog.id（可选关联） |
| `approvedAt` | Date? | 审批完成日期 |
| `createdAt` | Date | 创建时间 |
| `insurance` | PetInsurance? | 关联保险 |

**计算属性**: `claimStatus: ClaimStatus`, `reimbursementRate: Double`

---

### 3.28 HeatCycleLog（发情周期日志）
**文件**: `Ohana/Models/HeatCycleLog.swift`（V29新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `startDate` | Date | 开始日期 |
| `endDate` | Date? | 结束日期 |
| `statusRaw` | String | HeatCycleStatus.rawValue |
| `note` | String | 备注 |
| `isMated` | Bool | 是否已交配 |
| `expectedDeliveryDate` | Date? | 预产期 |
| `pet` | Pet? | 关联宠物 |

**计算属性**: `status: HeatCycleStatus`

---

### 3.29 SymptomLog（症状记录）
**文件**: `Ohana/Models/SymptomLog.swift`（V29新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `categoryRaw` | String | SymptomCategory.rawValue |
| `symptomName` | String | 症状名称 |
| `severityRaw` | Int | SymptomSeverity.rawValue（1-4） |
| `note` | String | 备注 |
| `photoData` | Data? | 附图 |
| `pet` | Pet? | 关联宠物 |

**计算属性**: `category: SymptomCategory`, `severity: SymptomSeverity`

---

### 3.30 PetPhotoLog（照片日志）
**文件**: `Ohana/Models/PetPhotoLog.swift`（V25新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `imageData` | Data | 原图（externalStorage） |
| `date` | Date | 拍摄时间 |
| `note` | String | 备注（最多140字） |
| `createdAt` | Date | 创建时间 |
| `locationLatitude` | Double | 地理纬度（V28，0=未记录） |
| `locationLongitude` | Double | 地理经度（V28） |
| `locationPlacename` | String | 地点名称（V28） |
| `pet` | Pet? | 关联宠物 |

---

### 3.31 PlantCareLog（植物护理日志）
**文件**: `Ohana/Models/PlantCareLog.swift`（V27新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识 |
| `date` | Date | 记录时间 |
| `careTypeRaw` | String | PlantCareType.rawValue（watering/fertilizing） |
| `note` | String | 备注 |
| `executorId` | String? | 执行人 Human.id |
| `plant` | Plant? | 关联植物 |

**计算属性**: `careType: PlantCareType`

---

### 3.32 PetDocumentAttachment（多附件支持）
**文件**: `Ohana/Models/PetDocumentAttachment.swift`（V20新增）

多附件关联到 `PetDocument`，支持图片/PDF 附件存储。

---

## 四、枚举类型完整列表

### Pet 相关
```swift
// PetThemeColor — 宠物主题色
enum PetThemeColor: String, Codable, CaseIterable {
    case coral, ocean, lavender, mint, sunset, berry, sky, sage, peach, slate
}

// FoodTrackingMode
enum FoodTrackingMode: String, Codable, CaseIterable {
    case casual   // 佛系估算
    case precise  // 精准倒数
}

// HygieneType（cycleDays: 护理周期天数）
enum HygieneType: String, Codable, CaseIterable {
    case teeth, nails, ears, brushing, bath
}

// HealthLogType
enum HealthLogType: String, Codable, CaseIterable, Identifiable {
    case general, vaccine, medication, dewormingInternal, dewormingExternal
    case surgery, dental, checkup, emergency, other
}

// DocumentCategory
enum DocumentCategory: String, Codable, CaseIterable {
    case passport, vaccine, insurance, medical, registration, other
}

// PottyType
enum PottyType: String, Codable, CaseIterable {
    case perfectPoop, softPoop, liquidPoop, pee
}

// ExpenseCategory
enum ExpenseCategory: String, Codable, CaseIterable {
    case food, treats, medical, grooming, toys, other
}

// PetRelationshipType
enum PetRelationshipType: String, CaseIterable, Codable {
    case parent, child, sibling, halfSibling, mate, other
}

// CareType — 日常护理（PetCareLog用）
enum CareType: String, CaseIterable, Codable {
    case feeding   // 喂食，🍽️
    case watering  // 喂水，💧
    case litter    // 铲屎，🧹
    case waterChange // 换水（鱼缸等），🔄
}

// HeatCycleStatus — 发情周期状态
enum HeatCycleStatus: String, Codable, CaseIterable {
    case proestrus  // 发情前期
    case estrus     // 发情期
    case diestrus   // 发情后期
    case anestrus   // 休情期
    case pregnant   // 孕期
    case nursing    // 哺乳期
}

// SymptomSeverity — 症状严重程度（Int rawValue: 1-4）
enum SymptomSeverity: Int, Codable, CaseIterable {
    case mild = 1, moderate = 2, severe = 3, critical = 4
}

// SymptomCategory — 症状分类
enum SymptomCategory: String, Codable, CaseIterable {
    case digestive, respiratory, mobility, appetite, skin, behavior, other
}
```

### 宠物用药相关
```swift
// PetMedicationFrequency
enum PetMedicationFrequency: String, Codable, CaseIterable, Identifiable {
    case daily          // 每天
    case twiceDaily     // 每天两次
    case threeTimesDaily // 每天三次
    case everyOtherDay  // 隔天
    case weekly         // 每周
    case asNeeded       // 按需
    case custom         // 自定义
}
```

### 人类相关
```swift
// WorkoutType — 运动类型
enum WorkoutType: String, Codable, CaseIterable {
    case running, walking, cycling, swimming, gym, yoga, hiking, other
}

// MedicationFrequency — 人类服药频率
enum MedicationFrequency: String, Codable, CaseIterable, Identifiable {
    case daily        // 每天
    case twiceDaily   // 每天两次
    case threeTimesDaily // 每天三次
    case weekly       // 每周
    case asNeeded     // 按需
    case custom       // 自定义
}

// HumanMedicationStatus — 服药状态
enum HumanMedicationStatus: String, Codable {
    case pending, taken, skipped
}

// HealthReportType — 报告类型
enum HealthReportType: String, Codable, CaseIterable, Identifiable {
    case bloodTest, urineTest, physical, vision, dental, cardiac, imaging, allergy, other
}

// ReportConclusion — 报告结论等级
enum ReportConclusion: String, Codable, CaseIterable, Identifiable {
    case normal    // 正常 ✅
    case attention // 注意 ⚠️
    case abnormal  // 异常 🔶
    case critical  // 危急 🔴
}
```

### 保险相关
```swift
// InsurancePaymentFrequency — 缴费频次
enum InsurancePaymentFrequency: String, Codable, CaseIterable {
    case monthly   // 按月
    case quarterly // 按季
    case annual    // 按年
    case once      // 一次性
}

// ClaimStatus — 报销状态
enum ClaimStatus: String, Codable, CaseIterable {
    case submitted   // 已提交
    case processing  // 处理中
    case approved    // 已报销
    case rejected    // 已拒绝
}
```

### 事件/任务相关
```swift
// EventType — 日历事件类型（含新增类型）
enum EventType: String, Codable, CaseIterable {
    case birthday, anniversary, daily, health, task
    case shoppingList, chore
    case vaccine, externalDeworming, internalDeworming
    case grooming, vetVisit, foodChange, litterBox
    case watering, fertilizing
    case insurancePremium  // 保险缴费（V31）
    case petMedicationDose // 宠物服药打卡（PetMedicationDoseLogging 用）
}

// ReminderStatus
enum ReminderStatus: String, Codable {
    case pending, completed, skipped, snoozed, failed
}
```

### 岛屿/经济相关
```swift
// IslandLevel — 岛屿等级
enum IslandLevel: Int, CaseIterable {
    case seedling = 1, blooming = 2, paradise = 3
}

// TreeLevel — 椰子树等级（10级）
enum TreeLevel: Int, CaseIterable, Comparable {
    case lv1 = 1   // 希望之种  0–49
    case lv2 = 2   // 破土嫩芽 50–149
    case lv3 = 3   // 茁壮成长 150–299
    case lv4 = 4   // 初现树形 300–499
    case lv5 = 5   // 椰影婆娑 500–799
    case lv6 = 6   // 果实初挂 800–1199
    case lv7 = 7   // 硕果累累 1200–1799
    case lv8 = 8   // 参天古木 1800–2599
    case lv9 = 9   // 灵树觉醒 2600–3599
    case lv10 = 10 // 生命之树 3600+
    // levelUpReward: 升级获得椰子（5/10/15/25/35/50/75/100/200）
    // passiveIncomeAmount: Lv5=3, Lv7=5, Lv9=8, Lv10=15 (每日被动收益)
}

// BatchActionType — 一键全家批量打卡
enum BatchActionType: String, CaseIterable, Codable {
    case feed, water, potty, litter, play
}

// EntityKind — 统一实体类型
enum EntityKind: String, Codable, CaseIterable, Identifiable {
    case pet = "Pet"
    case human = "Human"
    case plant = "Plant"
}

// PlantCareType — 植物护理类型
enum PlantCareType: String, Codable, CaseIterable, Identifiable {
    case watering      // 浇水 💧
    case fertilizing   // 施肥 🌿
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
- `isPetWizardCompleted`, `isFirstMealRecorded`, `isThemeColorSet`

**核心方法**：
```swift
func awardAction(type: OhanaActionType, pet: Pet?, context: ModelContext) -> (humanGot: Int, petGot: Int)
func batchAward(type: OhanaActionType, pets: [Pet], context: ModelContext)
func addCoconuts(_ amount: Int, emoji: String, title: String, ...)
func recordFirstMeal()
func recordThemeColorSet()
func recordDailyStepGoal(steps:)
func recordBondedWalk(humanDistanceKm:, petWalkDistanceKm:)
```

**OhanaActionType 奖励规则**：

| 类型 | 人类奖励 | 宠物奖励 |
|------|---------|---------|
| `.walk(distanceMeters)` | max(1, d/100) | max(1, d/100) |
| `.potty(isLitter: true)` | +5 | 0 |
| `.potty(isLitter: false)` | +2 | +5 |
| `.feed` | +2 | +2 |
| `.water` | +1 | +1 |
| `.care(.bath)` | +15 | +10 |
| `.care(其他)` | +5 | +2 |
| `.health` | +20 | +20 |
| `.expense` | +10 | 0 |
| `.milestone` | +50 | +50 |
| `.general(humanReward:petReward:)` | 自定义 | 自定义 |

**暴击引擎**（rollCrit）：
- 1-89：×1（无暴击）
- 90-98：×2 🎉
- 99-100：×5 👑（双震动）

---

### 5.2 AchievementManager（成就系统）
**文件**: `Ohana/Models/AchievementManager.swift`
**模式**: `@Observable` 单例（`AchievementManager.shared`）

10个核心成就（`iron_gut`, `iron_paw`, `walk_streak`, `health_hero`, `nutritionist`, `happy_birthday`, `hundred_days`, `first_record`, `day_one_checkin`, `old_friend`）+ 跨维度成就。

---

### 5.3 PetWalkingManager（遛狗管理器）
**文件**: `Ohana/Models/PetWalkingManager.swift`
**模式**: `@Observable` 单例（`PetWalkingManager.shared`）

**状态机（WalkPhase）**: `.idle` → `.running` → `.paused` → `.finished(elapsed, poopCount)`

---

### 5.4 LocationManager（GPS 追踪）
**文件**: `Ohana/Models/LocationManager.swift`
**模式**: `@Observable` 单例（`LocationManager.shared`），实现 `CLLocationManagerDelegate`

---

### 5.5 StreakManager（连续打卡）
**文件**: `Ohana/Models/StreakManager.swift`
**模式**: 静态方法 struct

- `refreshStreak(for pet:, context:)` — 检查更新 `pet.currentStreak`
- `topStreakPet(pets:)` — 返回最高连续打卡宠物

---

### 5.6 IslandProsperityManager & IslandProsperityEXP（岛屿繁荣度）
**文件**: `Ohana/Models/IslandProsperityManager.swift` + `Ohana/Models/IslandProsperityEXP.swift`

---

### 5.7 OasisTreeManager（椰子树/生命之树管理）
**文件**: `Ohana/Models/OasisTreeManager.swift`
**模式**: `@Observable` 单例（`OasisTreeManager.shared`）

**核心属性**：
- `islandEnergy: Int` — 基础繁荣度（来自数据库活动量）
- `injectedEnergy: Int` — 额外注入经验（消耗椰子所得，UserDefaults 持久化）
- `totalEnergy: Int` — 合计能量（islandEnergy + injectedEnergy）
- `treeLevel: TreeLevel` — 当前树等级（1-10）
- `progressToNextLevel: Double` — 当前级别进度（0.0-1.0）
- `passiveIncomeAmount: Int` — 每日被动收益（Lv5+ 生效）
- `canHarvestToday: Bool` — 今日是否可领取被动收益

**核心方法**：
```swift
func refreshEnergy(modelContext:, pets:, humans:, plants:)
func checkAndRewardLevelUp() -> TreeLevel?   // 检查升级并发放奖励
func injectEnergy(cost: Int = 10) -> Bool    // 消耗椰子注入能量
func harvestDailyPassiveIncome() -> Bool     // 领取每日被动收益
```

---

### 5.8 StreakRewardManager（连续打卡里程碑奖励）
**文件**: `Ohana/Models/StreakRewardManager.swift`
**模式**: `@Observable` 单例（`StreakRewardManager.shared`）

**里程碑配置**（防重复领取）：

| 连续天数 | 奖励椰子 |
|---------|---------|
| 7 天 | 20 |
| 30 天 | 100 |
| 100 天 | 500 |
| 365 天 | 2000 |

**核心方法**：
```swift
func checkAndAward(pet: Pet)                                        // 每次打卡后调用
func nextMilestone(currentStreak:) -> (days:, reward:, remaining:)? // UI 提示下一里程碑
```

---

### 5.9 NotificationManager（本地通知管理）
**文件**: `Ohana/Models/NotificationManager.swift`
**模式**: `final class`，实现 `UNUserNotificationCenterDelegate`（单例 `NotificationManager.shared`）

**功能**：
- `requestPermission() async -> Bool` — 请求通知权限
- `schedule(reminder:)` — 调度单条提醒
- `scheduleRollingWindow(reminders:)` — 滚动窗口调度（14天内）
- `refillWindowIfNeeded(allReminders:)` — App 启动时补充窗口
- `cancel(notificationId:)` — 取消单条通知
- `cancelAll(for petId:, reminders:)` — 取消某宠物所有通知
- `compensate(reminders:)` — 补偿过期 pending 提醒

**通知分类 ID**: `"OHANA_REMINDER"`（含完成/跳过/明天再说三个 action）

---

### 5.10 MedicationReminderService（用药提醒服务）
**文件**: `Ohana/Models/MedicationReminderService.swift`
**模式**: 单例（`MedicationReminderService.shared`）

**功能**：
- `scheduleMedicationReminders(for pet:)` — 调度宠物用药通知（覆盖替换，14天窗口）
- `scheduleHumanMedicationReminders(for human:, meds:)` — 调度人类用药通知
- `cancelMedicationReminders(for petId:)` — 取消宠物用药通知
- `cancelHumanMedicationReminders(for humanId:)` — 取消人类用药通知
- `dosesTakenToday(for medicationId:) -> Int` — 今日已服次数（static）
- `recordDose(for medicationId:)` — 记录服药（static）
- `undoDose(for medicationId:)` — 撤销服药（static）

---

### 5.11 RainbowBridgeService（宠物离世生命周期）
**文件**: `Ohana/Models/RainbowBridgeService.swift`
**模式**: `@MainActor` struct，静态方法

```swift
static func markPassedAway(pet:, date:, context:)   // 标记离世，删除未来提醒/事件
static func undoPassedAway(pet:, context:)           // 撤销离世（误操作恢复）
```

---

### 5.12 PetHealthAlertEngine（健康异常检测引擎）
**文件**: `Ohana/Models/PetHealthAlertEngine.swift`
**模式**: 单例（`PetHealthAlertEngine.shared`）

```swift
func scanAlerts(pets: [Pet]) -> [HealthAlert]  // 扫描所有宠物，返回排序警报列表
```

**检测类型（AlertType）**：`vaccineExpired`, `vaccineExpiringSoon`, `dewormingDue`, `weightGainAlert`, `weightLossAlert`, `noCheckIn`, `noPotty`, `noWalk`, `checkupOverdue`, `documentExpiringSoon`, `activeSymptom`（新增）, `heatCycleAlert`（新增）, `pregnancyCountdown`（新增）, `drinkingWeightAlert`（新增）, `lowActivityAlert`（新增）

---

### 5.13 DataBackupManager（JSON 全量备份/恢复）
**文件**: `Ohana/Models/DataBackupManager.swift`
**模式**: `@MainActor` 单例（`DataBackupManager.shared`）

- 备份格式版本：`schemaVersion: 14`，覆盖21个 SwiftData 模型 + appState
- `exportJSON(context:) async throws -> URL`
- `importJSON(from url:, context:) async throws`

---

### 5.14 DataExportService（本地冷备份）
**文件**: `Ohana/Models/DataExportService.swift`
**模式**: `@MainActor` 单例（`DataExportService.shared`）

- `exportZip() async -> URL?` — 打包 SQLite + 外部图片，写入 tmp 目录
- `estimatedBackupSizeText() -> String`

---

## 六、辅助工具类（Utilities/）

### 6.1 AntiRepeatCareManager（防重复打卡）
**文件**: `Ohana/Utilities/AntiRepeatCareManager.swift`

```swift
@MainActor
static func checkRecentCareLog(
    for pet: Pet, type: CareType,
    thresholdMinutes: Int = 120,
    currentUserId: String?, in humans: [Human]
) -> (executorName: String, minutesAgo: Int)?
```
家庭协作保护：在指定时间窗口内已有打卡记录时返回告警（谁、多久前操作过）。

### 6.2 CarePlanCalendarSync（护理计划日历同步）
**文件**: `Ohana/Utilities/CarePlanCalendarSync.swift`

将间隔类护理计划（换水/换砂/铲屎）同步为 SwiftData `Event`，在应用内日历可见：
- `syncWaterChangePlan(pet:, context:, intervalDays:, enabled:, cycleAnchor:)`
- `syncLitterFullChangePlan(pet:, context:, intervalDays:, enabled:, cycleAnchor:)`
- `syncScoopPlan(pet:, context:, intervalDays:, enabled:, anchor:)`
- `removeCalendarPlan(kind:, petKey:, context:)`

### 6.3 ImageCutoutService（iOS 17 原生抠像）
**文件**: `Ohana/Utilities/ImageCutoutService.swift`

```swift
@MainActor
func removeBackground(from image: UIImage) async throws -> UIImage?
static func isTransparentPNG(_ data: Data) -> Bool
```
使用 `VNGenerateForegroundInstanceMaskRequest` 提取主体前景，背景替换为透明。

### 6.4 PetMedicationDoseLogging（宠物服药打卡写入 Event）
**文件**: `Ohana/Utilities/PetMedicationDoseLogging.swift`

```swift
static func requiredDoses(on date:, for med:) -> Int     // 某日应服次数
static func todayDoseCount(events:, medicationId:) -> Int
@MainActor
static func recordDose(medication:, pet:, modelContext:, decrementRemaining:)
```

### 6.5 ColorExtensions
**文件**: `Ohana/Utilities/ColorExtensions.swift`

Go UI 主色板、Figma 设计令牌、`Color(hex:)`、`Color(light:, dark:)`、`color.toHex()`。

### 6.6 ModelContextExtensions
**文件**: `Ohana/Utilities/ModelContextExtensions.swift`

```swift
extension ModelContext {
    func safeSave()  // 全项目统一安全保存（catch 后 print，不 crash）
}
```

---

## 七、ViewModels

### 7.1 IslandWealthViewModel（财富仪表盘 ViewModel）
**文件**: `Ohana/ViewModels/IslandWealthViewModel2.swift`
**模式**: `@Observable`

- `leaderboard: [WealthLeaderRow]` — 直接读个人 `coconutBalance`
- `chartBars: [WealthBarData]` — 按时间桶聚合
- `color(for entityId:) -> Color`

### 7.2 IslandUnifiedStatsViewModel（全岛统计 ViewModel）
**文件**: `Ohana/ViewModels/IslandUnifiedStatsViewModel.swift`
**模式**: `@Observable`

体重变动%趋势 + 近7天探索里程 + 月度排行。

---

## 八、Views 结构与功能

### 8.1 应用入口

| 文件 | 说明 |
|------|------|
| `OhanaApp.swift` | `@main`，初始化 `SharedModelContainer.make()`（单例），注入 `modelContainer` |
| `RootView.swift` | `@AppStorage("ohana_has_onboarded")` 控制路由；数据库降级警告 |
| `ContentView.swift` | `NavigationStack` + `OverviewView`；全局 `navigationDestination`；`GlobalCoconutButtonOverlay`；`GlobalWalkBanner` |

---

### 8.2 首页 OverviewView
**文件**: `Ohana/Views/OverviewView.swift`

**主要功能**：
- 问候语 + 岛屿背景 + 天气粒子特效（`IslandMoodWeatherView`）
- 宠物/人类/植物为空时的引导页
- 动态内容区域（sectionOrder 可自定义）：`petCards`, `todayTasks`, `islandStats`, `quickAccess`
- 一键全家批量打卡（`BatchAction`）
- 植物仪表盘（`PlantDashboardView`）
- 岛屿日报弹窗（`IslandDailyReportSheet`，每日首次打开）
- 首日椰子奖励、记忆碎片卡片（`MemoryDropCard`）

---

### 8.3 宠物详情 PetDetailView
**文件**: `Ohana/Views/Details/PetDetailView.swift`

布局结构（ScrollView 垂直排列）：PetHeroRow → PetHUDVitalSection → PetAlertScrollSection → PetChartDashboard → PetHealthHubCard → PetHygieneCard → DietCardWithQuickActions → 三卡横排 → PetUnifiedTimeline → deleteDangerZone

---

### 8.4 详情页列表（Details/）

| 文件 | 进入方式 | 功能 |
|------|---------|------|
| `PetDetailView.swift` | NavigationDestination | 宠物详情主页 |
| `PetHealthDetailView.swift` | navigationDestination | 健康详情：免疫/趋势图/时间轴 |
| `PetHygieneDetailView.swift` | NavigationLink | 护理详情：5项护理总览 + 打卡 |
| `PetFoodManagementView.swift` | sheet | 饮食管理：双轨制粮食追踪 |
| `PetChartDashboard.swift` | 内嵌 | 图表仪表盘（体重/遛狗/便便/花费/余粮） |
| `PetBasicInfoDetailView.swift` | navigationDestination | 宠物基本信息编辑 |
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
| `HumanMedicationView.swift` | sheet/link | 人类用药管理（新增） |
| `HumanExpenseDetailView.swift` | sheet/link | 人类消费详情（新增） |
| `HumanWishlistView.swift` | sheet/link | 人类心愿单（新增） |
| `HumanHealthReportView.swift` | sheet/link | 人类健康报告（新增） |
| `CoHealthDashboardView.swift` | sheet/link | 人宠共健仪表盘（新增）|
| `CoHealthDashboardFullView.swift` | sheet | 人宠共健全屏视图（新增）|
| `PlantDetailView.swift` | navigationDestination | 植物详情 |
| `IslandWealthDashboard2.swift` | NavigationLink | 财富仪表盘 |
| `IslandUnifiedDashboardView.swift` | sheet/link | 全岛统计仪表盘 |
| `IslandExpenseDashboard.swift` | sheet/link | 全岛花费详情（新增，Bento Box 毛玻璃主题）|
| `IslandExplorationDashboard.swift` | sheet/link | 全岛探索仪表盘（新增）|
| `IslandWeightDashboard.swift` | sheet/link | 全岛体重仪表盘（新增）|
| `PetInsuranceView.swift` | sheet/link | 宠物保险管理（新增）|
| `PetMedicationView.swift` | sheet/link | 宠物用药管理（新增）|
| `PetMedicationDetailSheet.swift` | sheet | 宠物用药详情（新增）|
| `PetMomentsHubView.swift` | sheet/link | 岁月史书+相册综合页（新增）|
| `PetPhotoAlbumView.swift` | 内嵌/sheet | 宠物照片相册（新增）|
| `PetUnifiedTimelineSheet.swift` | sheet | 宠物统一时间轴 Sheet（新增）|
| `PetTimelineModels.swift` | — | 时间轴数据模型（UnifiedLogItem 等）|
| `PetMilestoneListView.swift` | sheet/link | 里程碑列表（新增）|
| `MilestoneCelebrationOverlay.swift` | overlay | 里程碑庆祝动画（新增）|
| `InventoryView.swift` | sheet | 道具背包（补打卡券等，新增）|
| `DogActivityCard.swift` | 内嵌 | 狗狗活动卡片（新增）|
| `BackdateCheckInSheet.swift` | sheet | 补打卡 Sheet（新增，使用补打卡券）|
| `InsurancePolicyDetailSheet.swift` | sheet | 保险保单详情（新增）|
| `DocumentDetailSheet.swift` | sheet | 证件详情（新增）|
| `PetVetSummaryPDFView.swift` | sheet | 宠物兽医摘要 PDF 视图（新增）|
| `CoconutShopView.swift` | sheet | 椰子兑换商店（新增，消耗椰子换道具/称号）|
| `GachaView.swift` | sheet | 欧气扭蛋机（新增，30🥥/次）|
| `BountyBoardView.swift` | sheet | 家庭悬赏榜（新增，发布/接取任务）|
| `WeeklyReportCard.swift` | 内嵌 | 周报卡片 |
| `OhanaGlassUIDemoView.swift` | — | UltimateGlassCard UI 演示（仅调试/演示）|
| `ios26UITestView.swift` | — | iOS 26 glassEffect() API 测试页（仅调试/演示）|

---

### 8.5 椰子商店 / 扭蛋 / 悬赏榜

**CoconutShopView**（`Views/Details/CoconutShopView.swift`）：
- 商品分三类：特效（effect）、称号（title_）、加成（boost）
- `isConsumable: Bool` — 消耗品立即激活；永久/称号标记已购（`purchasedShopItems` AppStorage）
- 购买后触发 Confetti 动画

**GachaView**（`Views/Details/GachaView.swift`）：
- 每次消耗 30 🥥
- 奖品稀有度权重：普通55 / 稀有30 / 史诗12 / 传说3
- 传说奖品含补打卡券（`isBackdatePass`）

**BountyBoardView**（`Views/Details/BountyBoardView.swift`）：
- `BountyTask` 存于 `@AppStorage("bountyTasks")`（JSON）
- 发布任务（创建者设定椰子奖励）→ 接单 → 完成 → 椰子从创建者转移到完成者

---

### 8.6 全局组件（Components/）

| 文件 | 说明 |
|------|------|
| `GlobalCoconutButtonOverlay.swift` | 全局悬浮椰子按钮（右上角）→ CoconutLogView |
| `GlobalWalkBanner.swift` | 全局遛狗悬浮横幅（底部）|
| `ArkCrewIDCardView.swift` | 成员 ID 卡片（正面/背面渐变）|
| `DailyQuestsCard.swift` | 每日任务卡片 |
| `SmartTodayCard.swift` | 智能今日卡片 |
| `IslandStatComponents.swift` | 全岛统计组件（MiniBarChart 等）|
| `MemoryDropCard.swift` | 记忆碎片卡（可滑动消失）|
| `SwipeableEventRow.swift` | 可滑动事件行（完成/删除）|
| `StreakBadgeView.swift` | 连续打卡徽章 |
| `WelcomeQuestBentoView.swift` | 欢迎任务 Bento 格局 |
| `QuickPottySheet.swift` | 快速便便打卡 Sheet |
| `QuickWeightSheet.swift` | 快速体重记录 Sheet |
| `PetPickerSheet.swift` | 宠物选择器 Sheet |
| `AddExpenseSheet.swift` | 快速记账 Sheet |
| `AddHealthRecordSheet.swift` | 添加健康记录 Sheet |
| `UltimateGlassCard.swift` | **新** iOS 26 级 Liquid Glass 卡片容器（8层折射系统）|
| `LiquidGlassButton.swift` | **新** Liquid Droplet 玻璃按钮（6层渐变）|
| `QuickHumanNoteSheet.swift` | **新** 快速记录家庭成员备注 |
| `IslandQuestCarousel.swift` | **新** 岛屿委托任务横滑 Carousel |
| `IslandEnergyBar.swift` | **新** 岛屿/树能量进度条 |
| `LayeredAvatarView.swift` | **新** 多层头像叠加视图 |
| `IslandToastView.swift` | **新** 岛屿风格 Toast 通知 |
| `EquipPopoutCardSheet.swift` | **新** 装备弹出卡片 Sheet |
| `ExpenseSplitterCard.swift` | **新** 费用分摊卡片 |
| `DutyNudgeComponents.swift` | **新** 家庭任务提醒 Nudge 组件 |
| `ConfettiModifier.swift` | **新** 彩纸动画修饰符 |
| `OverviewHelperViews.swift` | **新** OverviewView 辅助视图子组件 |
| `OverviewQuickActions.swift` | **新** OverviewView 快捷操作区 |
| `AddInsuranceClaimSheet.swift` | **新** 添加保险报销记录 |
| `AddPetMedicationSheet.swift` | **新** 添加宠物用药计划 |
| `GenericWeightEntrySheet.swift` | **新** 通用体重录入 Sheet |
| `ImageCutoutPreviewSheet.swift` | **新** 抠图预览 Sheet（iOS 17 Vision）|
| `PetSilhouetteView.swift` | **新** 宠物剪影视图（根据物种/品种/毛色渲染）|
| `ProTipSection.swift` | **新** 品种护理贴士展示区 |
| `QuickFeedDetailSheet.swift` | **新** 快速喂食详情 |
| `QuickLitterDetailSheet.swift` | **新** 快速铲砂详情 |
| `QuickMomentSheet.swift` | **新** 快速记录重要时刻 |
| `QuickPlayDetailSheet.swift` | **新** 快速陪玩详情 |
| `QuickPottyDetailSheet.swift` | **新** 快速便便详情 |
| `QuickWaterChangeDetailSheet.swift` | **新** 快速换水详情 |
| `QuickWaterDetailSheet.swift` | **新** 快速喂水详情 |

---

### 8.7 表单/向导（Forms/）

| 文件 | 说明 |
|------|------|
| `AddPetWizardView.swift` | 添加宠物向导（多步骤，含性格标签选择） |
| `AddHumanWizardView.swift` | 添加人类成员向导 |
| `EditPetSheet.swift` | 编辑宠物信息 Sheet |
| `AddEventView.swift` | 添加日历事件 |
| `AddEntityView.swift` | 添加实体（选择类型入口）|
| `AddDocumentSheet.swift` | 添加证件（含多附件上传）|
| `AddPlantView.swift` | 添加植物 |
| `AddHeatCycleSheet.swift` | **新** 添加发情/孕期周期记录 |
| `AddSymptomSheet.swift` | **新** 添加症状记录（分类+严重度+照片）|

---

### 8.8 首页子模块（Home/）

| 文件 | 说明 |
|------|------|
| `CritterDeckCarousel.swift` | 宠物卡片轮播（顶部翻转效果，含 HumanIDCardView）|
| `CrewRosterOverlay.swift` | 全岛成员花名册（宠物+人类+植物管理）|
| `OasisRewardView.swift` | 绿洲奖励视图 |
| `CoconutLogView.swift` | 椰子收支明细日志 |
| `IslandMoodWeatherView.swift` | 岛屿心情/天气粒子特效 |
| `WalkTrackingCard.swift` | 遛狗追踪实时卡片 |
| `PetWalletStack.swift` | **新** iOS Wallet 堆叠动效宠物卡（matchedTransitionSource + zoom 英雄过渡）|
| `BeautifulCoconutTree.swift` | **新** 精确 SwiftUI 椰子树（固定9个椰子坐标 + 采摘交互 + 升级冲击波）|
| `HomeBentoBoxes.swift` | **新** 首页 Bento 统计格（椰子余额 + 打卡连击）|
| `HomeHighlightDeck.swift` | **新** 首页横滑高亮甲板（宠物状态/连击/委托/等级，160pt，含页码指示器）|
| `IslandDailyReportSheet.swift` | **新** 岛屿日报启动弹窗（每日首次打开）|
| `PetCardBackSettingsSheet.swift` | **新** 宠物卡片背面设置菜单（编辑/彩虹桥/删除）|
| `PetWellnessCard.swift` | **新** 宠物健康状态一览卡（当日喂食/喂水/遛狗/便便）|
| `PlantDashboardView.swift` | **新** 植物 Tab 主面板（网格 + 快捷浇水/施肥）|
| `WalletPetCardBack.swift` | **新** 宠物卡片背面（分组功能枢纽，覆盖全部宠物功能入口）|
| `DailyStreakDetailView.swift` | **新** 打卡连击详情页（打卡日历 + 连击排行 + 补打卡）|

---

### 8.9 iOS 26 Liquid Glass 组件

**UltimateGlassCard**（`Views/Components/UltimateGlassCard.swift`）：

Ohana UI V2 设计规范核心容器，实现**8层 Liquid Glass 折射系统**：
- `L1` `.ultraThinMaterial` 磨砂基底
- `L2` 白色透明叠加（0.05）
- `L3` 顶/底线性渐变折射（边缘高光）
- `L4` 径向渐变（中心散焦，blendMode .multiply）
- `L5` 白色 0.5pt 细描边
- `L6` 蓝色/红色双色调描边（色散模拟）
- `L7` 顶部高光胶囊线（specular highlight）
- `L8` 左上角椭圆反光斑（radial glow）

亮色模式：强制 `UIBlurEffect(.light)` + 白色渐变折射（`VisualEffectBlur` UIViewRepresentable）

辅助类型：`InnerPillConfig`（内部组件配色），`InnerGlassTag`（玻璃标签）

**LiquidGlassButton**（`Views/Components/LiquidGlassButton.swift`）：

高光 Liquid Droplet 效果按钮，6层：
1. `.ultraThinMaterial` 基底
2. 颜色着色层（isDone/tintColor 时启用）
3. 左上内阴影（白色高光 strokeBorder + blur + offset）
4. 右下内阴影（暗色 strokeBorder + blur）
5. 表面光泽线性渐变
6. 外边框描边

按压时 `scaleEffect(0.90)`，spring 弹簧动画。

**GoTranslucentCardModifier**（`Views/OhanaDesignSystem.swift`）：

现已使用 iOS 26 原生 `.glassEffect(.regular, in: RoundedRectangle(...))` 实现。

**MaterialDashboardView**（`Views/MaterialDashboardView.swift`）：

AI Studio 同款 PetDashboard，MatUrgentPulseModifier 紧急闪烁动画，支持喂食/换水/猫砂/花费/体重/遛狗六类卡片。

---

### 8.10 PetPersonalityTag（宠物性格标签系统）

**文件**: `Ohana/Models/PetPersonalityTag.swift`（非 @Model，存于 Pet.personalityTagsRaw）

- 内置 39 个预设标签（`PetPersonalityTag.allTags`）
- 支持用户自定义标签（`CustomPersonalityTagRecord`，存于 `UserDefaults "ohana_custom_personality_tags_v1"`，id 前缀 `u.`）
- `PetTagGreeting.homeSubtitleHint(pet:, hour:, l:)` — 基于标签和时间生成稳定的首页副标题文案（同一天不闪烁）

---

### 8.11 PetBreedDatabase（品种数据库）

**文件**: `Ohana/Models/PetBreedDatabase.swift`

静态数据库，包含：
- `dogBreeds: [BreedInfo]`（26个品种）
- `catBreeds: [BreedInfo]`（19个品种）
- `rabbitBreeds`（6个品种）
- `hamsterBreeds`（5个品种）
- `birdBreeds`（8个品种）
- `otherBreeds`（8个其他宠物）
- `breedCareTips: [String: [String]]` — 20+品种护理贴士（模糊匹配）
- `countries: [String]` — 44个国家
- `citiesByCountry: [String: [String]]` — 9个国家的城市列表

---

## 九、设计系统

### 9.1 颜色系统（ColorExtensions.swift）

**Go UI 主色板**：
```swift
Color.goPrimary      // #4338FF（深紫蓝，主品牌色）
Color.goPrimaryLight // #5B52FF
Color.goPrimaryDark  // #3028CC
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
Color.arkCoral, Color.arkInk, Color.arkCardDark, Color.arkMint
```

**颜色工具方法**：
```swift
Color(hex: "RRGGBB")
Color(light:, dark:)     // 亮/暗模式自适应
color.toHex() -> String?
```

---

### 9.2 组件与修饰符（OhanaDesignSystem.swift）

**卡片修饰符**：
```swift
.goCard(color: .white, cornerRadius: 24)         // 纯色卡片
.goBlueCard(cornerRadius: 24)                    // 蓝色渐变卡片（goCardBlue→goPrimary）
.goTranslucentCard(cornerRadius: 20)             // 原生 .glassEffect()（iOS 26）
.goGlassBackground(_ shape: InsettableShape)     // 任意形状 glassEffect
.ohanaGlassStyle(cornerRadius:)                  // 经典毛玻璃（ultraThinMaterial + 渐变）
.neoWhiteCard(cornerRadius: 32)                  // 白色阴影卡片
.neoDarkCard()                                   // 深色卡片（arkCardDark）
```

**按钮修饰符**：
```swift
.capsuleButton()       // 白色胶囊按钮
.neonCapsuleButton()   // 霓虹黄绿胶囊按钮
.capsuleButtonDark()   // 深色胶囊按钮
```

**字体系统（OhanaFont）**：
全部使用 `.system(design: .rounded)`：
```swift
OhanaFont.largeTitle(_ weight: Font.Weight = .black) → size 34
OhanaFont.title(_ weight:)                           → size 24 bold
OhanaFont.headline(_ weight:)                        → size 16 bold
OhanaFont.body(_ weight:)                            → size 15 medium
OhanaFont.callout(_ weight:)                         → size 14
OhanaFont.caption(_ weight:)                         → size 12
OhanaFont.caption2(_ weight:)                        → size 10
OhanaFont.metric(size: CGFloat, _ weight:)           → 任意大小（数字专用）
```

**修饰符便捷方法**：
```swift
.heroTitleStyle()              // .lowercase + .heavy
.giantMetricStyle(size: 60)    // OhanaFont.metric .heavy
.arkMetric(size: 80)           // font(OhanaFont.metric(size:, .heavy))
.arkMetricSM(size: 40)
```

**其他组件**：
```swift
GoDashedDivider             // 虚线分割线
OhanaDashedDivider          // 另一版本虚线分割（dash: [6,4]）
GoBottomTabBar              // 底部 Tab 栏（选中项展开+胶囊背景）
AlertBanner                 // 设计令牌警告横幅（success/warning/error/info）
CoconutBalanceCapsule       // 椰子余额胶囊（工具栏用），接受 onTap 回调
CoconutRewardModifier       // 椰子奖励弹跳动画（.coconutRewardOverlay(trigger:, amount:)）
OhanaSheetWrapper           // Sheet 包装容器（统一标题栏 + 关闭按钮）
NoiseTextureView            // 噪点纹理叠加层
IslandEXPBadgeView          // 岛屿 EXP 徽章 + 进度条
ScreenCompat                // 屏幕尺寸兼容（优先 UIWindowScene，避免 UIScreen.main）
```

---

## 十、数据流与关键逻辑

### 10.1 椰子经济数据一致性
```
全岛总库 QuestManager.coconutCount
    = Σ pet.coconutBalance + Σ human.coconutBalance
（awardAction 严格保证这个等式）
```

### 10.2 打卡 → 奖励 → 树能量链路
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
IslandProsperityEXP.addEXP(source: .xxx, household:, context:)
  ↓ household.totalProsperity += expValue
  ↓
OasisTreeManager.refreshEnergy(...)   // 同步树能量
  ↓ treeLevel 更新
  ↓ checkAndRewardLevelUp()           // 升级时发放椰子奖励
  ↓
StreakRewardManager.checkAndAward(pet:) // 连续打卡里程碑检测
```

### 10.3 SwiftData 注意事项
```swift
// 安全保存（全项目统一使用）
modelContext.safeSave()

// @Attribute(.externalStorage) 字段不参与正常 SwiftData query
// 如 avatarImageData, mapSnapshotData, PetPhotoLog.imageData

// 删除宠物时需手动删除关联 Events（relatedEntityId 匹配，不在 cascade 范围）

// RainbowBridgeService.markPassedAway 会自动清理未来事件/提醒
```

### 10.4 Swift Charts 注意事项
```swift
// ✅ 正确：unit 参数只支持具体值，不能动态传 Calendar.Component
BarMark(x: .value("时间", date, unit: .day), ...)

// ❌ 错误（会 fatal error）
let component: Calendar.Component = ...
BarMark(x: .value("时间", date, unit: component), ...)
```

---

## 十一、Schema 版本历史

| 版本 | App 版本 | 新增内容 |
|------|---------|---------|
| V1 | v4.5.0 | 首个版本化 Schema（16个模型）|
| V2 | v4.7.0 | Pet.currentStreak + lastCheckInDate |
| V3 | v4.8.0 | Household.totalProsperity |
| V4 | v4.9.0 | PetRelationship 表 |
| V5 | v5.0.0 | PetHealthLog.expirationDate |
| V6 | v5.1.0 | PetDocument.cost/attachmentData/attachmentFilename |
| V7 | v5.2.0 | PetCareLog 表（喂食/喂水/铲屎）|
| V8 | v5.6.0 | HumanWeightLog + Human.nationality/city |
| V9 | v5.7.0 | HumanWorkoutLog |
| V10 | v6.8.0 | Pet.foodTrackingModeRaw/casualOpenDate/casualDurationDays |
| V11 | v7.0.0 | Pet/Human.coconutBalance；所有 Log.executorId |
| V12 | v8.5.0 | WishlistItem；Event.assigneeId |
| V13 | v9.0.0 | Human.shouldShowOnHome |
| V14 | v9.1.0 | Pet.passedAwayDate（Rainbow Bridge）|
| V15 | — | Human.themeColorHex（迁移自 notes hack）|
| V16 | — | Human.privateFieldsRaw + Human.heightCm |
| V17 | — | PetMilestone.photoData（配图）|
| V18 | — | PetMilestone.location |
| V19 | — | Pet.cardStyleRaw |
| V20 | — | PetDocumentAttachment（多附件支持）|
| V21 | — | HumanMedication（人类吃药提醒）|
| V22 | — | HumanHealthReport（身体检测报告）|
| V23 | — | PetWeightLog.weightUnit + Pet.weeklyWalkGoalKm |
| V24 | — | PetMedication + Pet vet 结构化字段 + PetWeightLog.bcsScore |
| V25 | — | PetInsurance + PetPhotoLog |
| V26 | — | Pet.personalityTagsRaw（性格标签）|
| V27 | — | Plant.themeColorHex/avatarImageData/careLogs + PlantCareLog |
| V28 | — | PetPhotoLog 地理位置字段（latitude/longitude/placename）|
| V29 | — | SymptomLog + HeatCycleLog |
| V30 | — | InsuranceClaim + PetInsurance.paymentFrequencyRaw |
| V31 | — | PetInsurance.paymentDayOfMonth/showInCalendar/otherFeeAmount/otherFeeNote；Event.insurancePremium 类型 |
| V32 | — | PetInsurance.firstPremiumPaymentDate |
| V33 | — | PetWalkLog.behaviorNotes + moodRating |
| V34 | — | HumanMedicationLog（人类吃药打卡记录）|

**当前**: `ArkSchemaV34`（`SharedModelContainer.make()` 使用）

**迁移**: `ArkMigrationPlan`，`stages: []`（全部轻量迁移，无 custom stage）

**三级降级策略**：主默认库 → 无 migrationPlan 默认库 → 命名磁盘备用库（`ohana_disk_fallback`）→ 内存库（最后兜底）

---

## 十二、UserDefaults Keys 索引

| Key | 类型 | 说明 | 存储位置 |
|-----|------|------|---------|
| `ohana_has_onboarded` | Bool | 是否已完成引导 | `@AppStorage` |
| `currentActiveHumanId` | String | 当前活跃人类成员 UUID | UserDefaults |
| `quest_coconutCount` | Int | 全岛椰子总数 | QuestManager |
| `quest_coconutLogs` | Data | 椰子收支明细（JSON）| QuestManager |
| `quest_isPetWizardCompleted` | Bool | 任务1完成 | QuestManager |
| `quest_isFirstMealRecorded` | Bool | 任务2完成 | QuestManager |
| `quest_isThemeColorSet` | Bool | 任务3完成 | QuestManager |
| `quest_stepRewardLastDate` | Date | 步数奖励最后领取日 | QuestManager |
| `quest_bondedWalkLastDate` | Date | 人宠联动最后领取日 | QuestManager |
| `prosperity_lastOpenDate` | Date | 今日打开 EXP 最后领取日 | IslandProsperityEXP |
| `ohana_db_fallback_active` | Bool | 数据库降级标记 | SharedModelContainer |
| `ohana_db_fallback_error` | String | 数据库错误描述 | SharedModelContainer |
| `quickActionItems_v2` | String | QuickAction JSON | OverviewView |
| `home_section_order` | String | 首页 section 排序 | OverviewView |
| `home_section_hidden` | String | 首页隐藏 section | OverviewView |
| `overview_activeCritterId` | String | 首页顶牌宠物 ID | OverviewView |
| `oasis_injectedEnergy` | Int | 椰子注入的额外树能量 | OasisTreeManager |
| `oasis_lastRewardedLevel` | Int | 上次发放升级奖励的树等级 | OasisTreeManager |
| `lastTreeHarvestDate` | Date | 上次领取被动收益日期 | OasisTreeManager |
| `streakRewards_claimed` | Dict | 已领取的连续打卡里程碑（petId_days: timestamp）| StreakRewardManager |
| `purchasedShopItems` | String | 已购买商店商品 ID 列表 | CoconutShopView |
| `bountyTasks` | String | 悬赏任务 JSON | BountyBoardView |
| `gachaHistory` | String | 扭蛋历史 JSON | GachaView |
| `celebratedMilestoneDays` | String | 已庆祝里程碑天数 | MilestoneCelebrationOverlay |
| `med_doses_YYYY-MM-dd_<UUID>` | Int | 当日某药已服次数 | MedicationReminderService |
| `medication_remaining_<UUID>` | Double | 某药剩余粒数估算 | PetMedicationDoseLogging |
| `appLanguage` | String | 应用语言（"zh"/"en"）| L10n |
| `ohana_custom_personality_tags_v1` | String | 用户自定义性格标签 JSON | CustomPersonalityTagStore |
| `user_login_streak` | Int | 用户登录连击天数 | DailyStreakDetailView |
| `user_last_login_date` | String | 最后登录日期字符串 | DailyStreakDetailView |
| `user_login_history` | String | 登录历史 JSON | DailyStreakDetailView |
| `oasis_checkedIn_dates` | String | 打卡日期集合 JSON | DailyStreakDetailView/HomeBentoBoxes |
| `checkIn_lastClaimedMilestone` | Int | 最后领取连击里程碑天数 | DailyStreakDetailView |
| `inventory_backdate_1day_count` | Int | 1天补打卡券数量 | InventoryView |
| `lastLitterChangeDate_<petId>` | Double | 某宠物上次换猫砂时间戳 | CarePlanCalendarSync |

---

## 十三、待实现 Backlog

以下功能在代码中有预留/引用，但尚未完整实现：

- **CloudKit 同步**：`ckRecordName`、`ckShareRecordName` 字段预留，`cloudKitDatabase: .none`
- **Apple 家庭分享**：`Human.appleUserIdentifier` 字段预留
- **HealthKit 完整集成**：HumanWorkoutLog 支持 `sourceHealthKit`，但实际 HealthKit 读取需进一步完善
- **WaterLog 完整集成**：模型存在但 UI 集成有限（独立于宠物/人类的全局日志）
- **HumanMedicationLog 完整 UI**：`HumanMedicationLog` 模型已在 V34 加入，服药打卡流程已支持，但历史日志翻页浏览 UI 待补全
- **Pet.weeklyWalkGoalKm 进度显示**：字段已存在（V23），但首页/详情页进度条尚未实现
- **InsurancePaymentFrequency 日历自动事件生成**：`PetInsurance.showInCalendar` 已支持，但自动续期日历生成逻辑待完善
- **CoconutShopView 加成类商品效果**：购买后的实际加成逻辑（如椰子收益加成）待接入 QuestManager
- **BountyBoardView 资产转移验证**：任务完成后椰子从创建者转移逻辑待加强（防刷机制）

---

## 十四、代码规范与约定

### 14.1 颜色使用
```swift
// ✅ 正确（必须写 Color. 前缀）
.foregroundStyle(Color.goLime)
.background(Color.goTeal)

// ❌ 错误（在 foregroundStyle/background 中不能直接用 .goLime）
.foregroundStyle(.goLime)
```

### 14.2 ViewModel 模式
```swift
// ✅ 使用 @Observable（不用 ObservableObject/Combine）
@Observable
final class MyViewModel { var someState = ... }

// 在 View 中
@State private var vm = MyViewModel()
```

### 14.3 模型写入
```swift
// ✅ 统一使用 safeSave
modelContext.safeSave()

// ✅ SwiftData 模型写入必须在 MainActor 上
DispatchQueue.main.async {
    walkLog.mapSnapshotData = jpegData
}
```

### 14.4 宠物主题色获取
```swift
// ✅ 从宠物获取主题色
let color: Color = pet.themeColor.color
let deepColor: Color = pet.themeColor.deepColor
let hexString: String = pet.themeColor.hexValue

// ✅ 人类主题色（V15 起直接读字段）
let humanColor = Color(hex: human.themeColorHex)
```

### 14.5 打卡奖励调用
```swift
// ✅ 推荐：新版（自动双边分润）
QuestManager.shared.awardAction(
    type: .care(type: .bath), pet: pet, context: modelContext
)

// ✅ 批量打卡
QuestManager.shared.batchAward(type: .feed, pets: allPets, context: modelContext)

// ✅ 全局奖励（无实体关联）
QuestManager.shared.addCoconuts(10, emoji: "🎉", title: "奖励")
```

### 14.6 UltimateGlassCard 使用
```swift
// ✅ 使用 UltimateGlassCard 作为深色毛玻璃卡片容器
UltimateGlassCard(isDarkMode: true) {
    Text("内容")
}

// ✅ 自适应模式（跟随系统 colorScheme）
UltimateGlassCard {
    Text("内容")
}

// ✅ 内部组件使用 InnerGlassTag
InnerGlassTag(text: "标签文字", isDark: true)
```

---

*本文档完整覆盖项目所有主要 Swift 文件（截至 2026-04-16，Schema V34，Phase 57+）*

**最后更新**: 2026-04-16
