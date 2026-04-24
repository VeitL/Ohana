# Ohana iOS App 项目文档

> 最后更新: 2026-04-16（英文本地化：en.lproj + 生成脚本）| Build: ✅ | Schema: ArkSchemaV33

---

## 一、项目概览

**Ohana（欧哈纳）** — 家庭宠物 + 植物综合管理 iOS App

- **理念**："Ohana means family. Nobody gets left behind or forgotten."
- **技术栈**：SwiftUI + SwiftData + Swift Charts, iOS 26+, Swift 6
- **本地优先**：无账号，SwiftData（App Group `group.com.guanchen.li.Ohana`）
- **全局主色**：`Color.goPrimary` — 浅色 `#FF7600` / 深色 `#C8FF00`，`OhanaApp` 根视图 `.tint(Color.goPrimary)`
- **UI 规范**：见 `UIRules.md`，所有新页面必须符合规范

### 本地化（简体中文 / English）

- **策略**：Swift 源码中的用户可见**中文整句**作为 `LocalizedStringKey`；`Ohana/en.lproj/Localizable.strings` 以相同中文为 key、英文为 value。系统语言为 **English** 时使用英文，为 **简体中文** 时显示源码中文（无需 `zh-Hans` 副本）。
- **隐私文案**：`Ohana/en.lproj/InfoPlist.strings` 覆盖相机/定位说明；`Info.plist` 内保留中文作开发默认值。
- **工程**：`CFBundleLocalizations` = `en` + `zh-Hans`；Xcode `knownRegions` 含 `zh-Hans`。
- **批量生成**：`scripts/generate_en_localizable.py`（依赖 `deep-translator`，建议使用仓库内 `.venv-l10n`）扫描含汉字的字符串字面量并机翻；进度缓存在 `scripts/.l10n_en_cache.json`（已 `.gitignore`），中断后可续跑。
- **注意**：带 `\(variable)` 的**插值字符串**、部分 `String(format:)` 与通知正文等可能不会出现在字面量扫描结果中，需后续改为 `String(localized:)` / `LocalizedStringResource` 等并补条目；机翻建议按模块在 Xcode 或 diff 中人工润色。

---

## 二、项目结构

```
Ohana/
├── en.lproj/
│   ├── Localizable.strings   # 英文 UI（key = 源码中的中文）
│   └── InfoPlist.strings     # 英文隐私描述
├── Models/
│   ├── Pet.swift / PetWeightLog.swift / PetCareLog.swift
│   ├── PetMedication.swift / PetInsurance.swift / InsuranceClaim.swift
│   ├── PetPhotoLog.swift / SymptomLog.swift / HeatCycleLog.swift
│   ├── Human.swift / HumanWeightLog.swift / Plant.swift / PlantCareLog.swift
│   ├── Event.swift / Reminder.swift / PetExpenseLog.swift
│   ├── SharedModelContainer.swift   # Schema 迁移链，当前 ArkSchemaV33
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
| V32 | `PetInsurance.firstPremiumPaymentDate`（按年/一次性首期缴费日） |
| V33 | `PetWalkLog.behaviorNotes`（可选备注）/ `PetWalkLog.moodRating`（默认 0） |

### 关键模型字段
**Pet**：`species`、`themeColorHex`、`personalityTagsRaw`、`currentStreak`、`foodTrackingMode`
**PetInsurance**：`annualPremium`、`paymentFrequency`、`paymentDayOfMonth`、`showInCalendar`、`otherFeeAmount`
**PetWeightLog**：`weight`、`weightUnit`（"kg"/"g"）、`weightInKg`（计算属性）、`bcsScore`
**PetWalkLog**：`distanceMeters`、`coconutsEarned`、`mapSnapshotData`、`routeLocationsData`、`behaviorNotes`（可选文字备注）、`moodRating`（0=未评 / 1-5星）
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

### 成就系统（AchievementManager，15枚）
`static func compute(for pet: Pet) -> [Achievement]` 纯计算，无副作用

| 序号 | ID | 触发条件 |
|------|----|---------|
| 1 | `iron_gut` | 连续7天每天有 perfectPoop 记录 |
| 2 | `iron_paw` | 累计遛狗 ≥ 100km |
| 3 | `walk_streak` | 连续7天有遛狗记录 |
| 4 | `health_hero` | 30天内无紧急就医/手术 |
| 5 | `nutritionist` | 喂食记录跨度 ≥ 14天 |
| 6 | `happy_birthday` | 今天是宠物生日 |
| 7 | `hundred_days` | `pet.daysTogether >= 100` |
| 8 | `first_record` | 至少一条任意记录 |
| 9 | `day_one_checkin` | 今天完成至少一次打卡 |
| 10 | `old_friend` | App 使用 ≥ 7天 |
| 11 | `long_runner` | 单次遛狗 ≥ 5km |
| 12 | `medication_complete` | 完成至少一个完整用药疗程 |
| 13 | `photo_enthusiast` | 照片数 ≥ 20张 |
| 14 | `expense_tracker` | 花费记录 ≥ 10条 |
| 15 | `weight_manager` | 体重记录 ≥ 7条 |

另有2枚人宠联动成就（需 HealthKit）：`bonded_walk` / `step_champion`，通过 `computeBonded(for:humanDistanceKm:)` 计算。

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

**文件**：`Ohana/Models/PetHygieneLog.swift`

- `HygieneType` 新增：`defaultCycleDays`（硬编码默认值）、`effectiveCycleDays(for petId: UUID)`（读自定义，否则用默认）
- 自定义存储键：`hygiene_cycle_<petUUID>_<typeRawValue>`（UserDefaults）
- 静态工具：`customCycleDays(for:petId:)` / `setCustomCycleDays(_:for:petId:)`
- `PetHygieneDetailView` 每张类型卡底部新增「调整周期」按钮 → Sheet（`cycleDaysEditorSheet`）
  - Stepper 范围 1-90 天，保存后立即生效于超期判断和状态色

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
