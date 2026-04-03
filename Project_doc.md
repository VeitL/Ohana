# Ohana iOS App 项目文档

> 最后更新: 2026-04-03 | Build: ✅ | Schema: ArkSchemaV31

---

## 一、项目概览

**Ohana（欧哈纳）** — 家庭宠物 + 植物综合管理 iOS App

- **理念**："Ohana means family. Nobody gets left behind or forgotten."
- **技术栈**：SwiftUI + SwiftData + Swift Charts, iOS 26+, Swift 6
- **本地优先**：无账号，SwiftData（App Group `group.com.guanchen.li.Ohana`）
- **全局主色**：`Color.goPrimary` — 浅色 `#FF7600` / 深色 `#C8FF00`，`OhanaApp` 根视图 `.tint(Color.goPrimary)`
- **UI 规范**：见 `UIRules.md`，所有新页面必须符合规范

---

## 二、项目结构

```
Ohana/
├── Models/
│   ├── Pet.swift / PetWeightLog.swift / PetCareLog.swift
│   ├── PetMedication.swift / PetInsurance.swift / InsuranceClaim.swift
│   ├── PetPhotoLog.swift / SymptomLog.swift / HeatCycleLog.swift
│   ├── Human.swift / HumanWeightLog.swift / Plant.swift / PlantCareLog.swift
│   ├── Event.swift / Reminder.swift / PetExpenseLog.swift
│   ├── SharedModelContainer.swift   # Schema 迁移链，当前 ArkSchemaV31
│   ├── QuestManager.swift           # 椰子奖励系统
│   └── OasisTreeManager.swift       # 生命之树等级
├── Views/
│   ├── OverviewView.swift           # 首页主视图（经典 UI）
│   ├── MaterialDashboardView.swift  # Material UI 主视图
│   ├── CalendarView.swift
│   ├── OhanaDesignSystem.swift      # CoconutBalanceCapsule + OhanaFont + goTranslucentCard 等
│   ├── ArkBackgroundView.swift      # AppBackgroundStyle 全局背景
│   ├── Home/
│   │   ├── PetWalletStack.swift     # 首页宠物钱包卡转盘
│   │   ├── HomeHighlightDeck.swift  # 宠物卡下方横滑甲板（130pt）
│   │   ├── CritterDeckCarousel.swift
│   │   └── DailyStreakDetailView.swift
│   ├── Details/
│   │   ├── IslandWeightDashboard.swift   # 全岛体重（按 UUID seriesID 分线）
│   │   ├── IslandExpenseDashboard.swift
│   │   ├── IslandExplorationDashboard.swift
│   │   ├── PetHealthDetailView.swift
│   │   ├── PetInsuranceView.swift        # 保单列表 + AddPetInsuranceSheet
│   │   └── iOS26UITestView.swift         # iOS 26 UI 规范测试页
│   ├── Components/
│   │   ├── QuickFeedDetailSheet.swift    # 喂食详情（手动/计划模式）
│   │   ├── QuickWaterDetailSheet.swift   # 喂水/换水
│   │   ├── QuickLitterDetailSheet.swift  # 铲屎/换砂
│   │   ├── QuickPottyDetailSheet.swift   # 便便记录
│   │   ├── QuickPlayDetailSheet.swift    # 逗玩
│   │   ├── QuickMomentSheet.swift        # 记录时刻（相册+定位）
│   │   ├── AddExpenseSheet.swift         # 花费记账
│   │   ├── GenericWeightEntrySheet.swift # 统一体重输入
│   │   └── OverviewQuickActions.swift    # 首页快捷操作网格
│   └── Forms/
│       ├── AddEntityView.swift
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

### 关键模型字段
**Pet**：`species`、`themeColorHex`、`personalityTagsRaw`、`currentStreak`、`foodTrackingMode`  
**PetInsurance**：`annualPremium`、`paymentFrequency`、`paymentDayOfMonth`、`showInCalendar`、`otherFeeAmount`  
**PetWeightLog**：`weight`、`weightUnit`（"kg"/"g"）、`weightInKg`（计算属性）、`bcsScore`  
**Event**：`relatedEntityType`（`EntityKind.rawValue`）、`relatedEntityId`  

---

## 四、首页（OverviewView）架构

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
| `memoryDrop` | 记忆碎片 | 随机浮现历史温馨时刻；需有记录数据；左右滑消失 |
| `islandStats` | 岛屿统计 | 体重/步数/花费/粮仓 Bento 横滑 |

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
- **打卡连击**：`oasis_checkedIn_dates` UserDefaults，首页顶栏与 `DeckCheckInStreakCard` 同步

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

## 十三、背景系统（AppBackgroundStyle）

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
