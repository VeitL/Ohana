# Ohana iOS App 项目文档

> 最后更新: 2026-04-26（全家庭周报 / 账本分析 / 成长档案深化 / 提醒健康面板）| Build: ✅ | Tests: ✅ `OhanaTests` | Schema: ArkSchemaV37
>
> **当前默认首页**：GO UI（`FocusStackHomeTestView`）。仅保留 GO UI + 经典 `OverviewView`；Material UI 已于 2026-04-24 移除。通过 `@AppStorage("appUIStyle")` 切换。

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
- **语言入口**：`AppLanguage.supported` 是设置页、SwiftUI `Locale`、`DateFormatter` / `NumberFormatter` 的唯一语言清单；新增语言时追加 `Option` 并创建对应 `<lang>.lproj/Localizable.strings`。
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
│   ├── Pet.swift / PetWeightLog.swift / PetCareLog.swift
│   ├── PetMedication.swift / PetInsurance.swift / InsuranceClaim.swift
│   ├── PetPhotoLog.swift / SymptomLog.swift / HeatCycleLog.swift
│   ├── Human.swift / HumanWeightLog.swift / Plant.swift / PlantCareLog.swift
│   ├── Event.swift / Reminder.swift / PetExpenseLog.swift
│   ├── SharedModelContainer.swift   # Schema 迁移链，当前 ArkSchemaV37
│   ├── CareLedgerEvent.swift        # 统一照护事件账本
│   ├── CareLedgerService.swift / CareLedgerBackfillService.swift
│   ├── ReminderSchedulingService.swift # 提醒调度、去重、补偿
│   ├── PrivacyService.swift         # 人类隐私权限统一入口
│   ├── QuestManager.swift           # 椰子奖励系统
│   └── OasisTreeManager.swift       # 生命之树等级
├── Views/
│   ├── OverviewView.swift           # 首页主视图（经典 UI）
│   ├── CalendarView.swift
│   ├── OhanaDesignSystem.swift      # CoconutBalanceCapsule + OhanaFont + goTranslucentCard 等
│   ├── ArkBackgroundView.swift      # AppBackgroundStyle 全局背景
│   ├── Home/
│   │   ├── FocusStackHomeTestView.swift # GO UI 默认首页：Wallet 卡片堆 + Today Focus + 家庭协作 + FAB
│   │   ├── FocusMoodQuestStrip.swift    # 旧 GO UI 心情 + 任务白卡组件，部分路径仍可复用
│   │   ├── EmptyStateWelcomeCard.swift  # GO UI 空态欢迎卡
│   │   ├── FunctionMenuSheet.swift      # GO UI 全部功能 sheet
│   │   ├── PetWalletStack.swift     # 经典首页宠物钱包卡转盘
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
| V34 | `HumanMedicationLog`（人类吃药打卡记录） |
| V35 | `Human.mbti` |
| V36 | `Pet.foodReminderEnabled` / `Pet.foodReminderAdvanceDays`（粮仓断粮提醒偏好） |
| V37 | `CareLedgerEvent`（统一照护事件账本，additive schema） |

### 关键模型字段
**Pet**：`species`、`themeColorHex`、`personalityTagsRaw`、`currentStreak`、`foodTrackingMode`
**PetInsurance**：`annualPremium`、`paymentFrequency`、`paymentDayOfMonth`、`showInCalendar`、`otherFeeAmount`
**PetWeightLog**：`weight`、`weightUnit`（"kg"/"g"）、`weightInKg`（计算属性）、`bcsScore`
**PetWalkLog**：`distanceMeters`、`coconutsEarned`、`mapSnapshotData`、`routeLocationsData`、`behaviorNotes`（可选文字备注）、`moodRating`（0=未评 / 1-5星）
**Event**：`relatedEntityType`（`EntityKind.rawValue`）、`relatedEntityId`、`assigneeId`（任务指派）  
**Reminder**：`scheduledAt`、`status`、`completedAt`、`completedBy`、`notificationId`  
**CareLedgerEvent**：`actorKind/actorId`、`subjectKind/subjectId`、`eventKind/actionType`、`source/sourceId`、`occurredAt`、`metadataJSON`，用于统一记录喂食/喂水/吃药/运动/花费/提醒/椰子奖励等行为。

---

## 三·A、统一照护事件账本与提醒产品化

### 统一照护事件账本（ArkSchemaV37）

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

入口：`FunctionMenuSheet` → “家庭岛屿” → **照护账本分析**。

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

**`ContentView.swift`** 读 `@AppStorage("appUIStyle")` 决定首页：

| 值 | 首页 | 状态 |
|---|---|---|
| `"go"`（默认） | `FocusStackHomeTestView` | **当前主路径**，详见第二十三·B 节 |
| `""` 或其它 | `OverviewView` | 经典 UI，详情如下；大量组件仍在 GO UI 外被复用 |

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

## 十·A、家庭周报升级

**`FamilyWeeklyReportDashboardView.swift`** 是全家庭多宠周报入口，替代单宠周报作为 GO 首页家庭协作卡的主周报页面。

入口：
- `FocusStackHomeTestView.familyCollaborationCard` → “周报”
- `FunctionMenuSheet` → “家庭岛屿” → **家庭周报**

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

## 二十三 · B. GO UI 首页（2026-04-26，**当前默认主页**）

`FocusStackHomeTestView` 是 `@AppStorage("appUIStyle") == "go"`（默认值）时的主界面。当前版本以 Apple Wallet 式宠物/家人卡片堆为核心：折叠态显示底部完整前卡，点选态将 active card 上移到顶部按钮下方，其它卡片压缩到底部，同时在 active card 下方显示快捷模块。

### 页面结构（自上而下）

```
ZStack
├── ArkBackgroundView()                         // 跟随 Settings 背景设置
├── stackLayer                                  // 未展开时：header + 任务白卡 + 卡片堆/空态
│   ├── goFocusHeader(safeT: safeAreaTop)
│   ├── TodayFocusCard                          // 今天谁需要照顾 / 什么最紧急 / 一点完成
│   ├── firstSuccessCheckInCard                 // 新用户首次快捷打卡闭环（按需）
│   ├── familyCollaborationCard                 // 家庭协作：谁做了什么 / 指派待办 / 催办 / 周报
│   └── walletCardStack(cards:)                 // 仅 collapsed 显示，底部锚定
├── expandedWalletLayer(cards:geo:)             // isExpanded == true 时根层绝对定位
│   ├── active FocusWalletCardView              // safeAreaTop + 76pt
│   ├── expandedQuickModules                    // active card 下方
│   └── inactive cards                          // 底部压缩，只露出顶部文字条
└── FAB / scrim                                 // 仅 collapsed 显示
```

### Header — `goFocusHeader`

顶部按钮统一为和 `CoconutBalanceCapsule` 一致的绿色胶囊样式（`Color.goPrimary`、26pt 高、黑色文字/图标）。

- **中间**：`🔥 + headerStreak` 胶囊 + `CoconutBalanceCapsule(onTap:)`
  - `headerStreak = pets.map { $0.currentStreak }.max() ?? 0`
  - 注意：这不是 `oasis_checkedIn_dates` 的每日打开 App 连胜，而是所有宠物护理 streak 的最大值。
  - 椰子胶囊点击 → `IslandWealthDashboardView`
- **右侧**：`...` 胶囊 Menu
  - 添加成员 → `AddEntityView()`
  - OHANA 成员 → `CrewRosterOverlay`
  - 设置 → `SettingsView`
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
- 展开态隐藏 `FocusMoodQuestStrip`、隐藏原卡堆、隐藏 FAB，改由根 ZStack 渲染 `expandedWalletLayer`，避免受 VStack 布局影响。
- 点击 inactive card 时切换 `activeCardId`，不会立即收起。
- 所有 wallet 状态动画使用 `HeroAnim.walletSpring = .spring(response: 0.4, dampingFraction: 0.85)`。

### 布局常量 — `K`

| 常量 | 当前值 | 含义 |
|---|---:|---|
| `hPad` | 20 | header 水平 padding |
| `cardMargin` | 7 | 卡片到屏幕边缘的间距 |
| `cardH` | 200 | 折叠态卡片高度 |
| `expandedCardH` | 360 | 点选态 active card 高度（竖向放大） |
| `stackPeekH` | 38 | 折叠/压缩态每张卡露出的顶部文字条高度 |
| `cardTitleH` | 76 | 折叠卡底部标题条高度 |
| `stackBottomGap` | 220 | 折叠态前卡底部到 GeometryReader 底部的可见间距 |
| `expandedStackBottomGap` | 12 | 展开态底部压缩卡堆到安全区底部的间距 |
| `expandedCardGlobalTopOffset` | 76 | active card 顶部 = safeAreaTop + 76，保持在顶部按钮下方 |
| `expandedQuickModuleH` | 112 | active card 下方快捷模块高度 |
| `expandedQuickModuleEditH` | 206 | 展开态快捷模块编辑模式高度（含添加入口） |
| `HeroAnim.stackCardCorner` | 24 | 卡片圆角 |

### 卡片数据 — `FocusCard`

`FocusCard` 从 `Pet` / `Human` 组装，用同一个结构喂给卡片堆、展开卡、快捷模块。

- `FocusCard.from(Pet)`：
  - 狗：FEED / WALK / WATER / POTTY
  - 猫：FEED / WATER / LITTER / PLAY
  - 鱼：FEED / WATER / FILTER
  - 其它：FEED / WATER / PLAY
  - 额外携带：`daysTogetherText`、`ageText`、`zodiacText`、`genderText`、`avatarImageData`、`petSpecies`、`coatColor`、`eyeColor`、`patternName`、`themeColorHex`、`breed`
- `FocusCard.from(Human)`：
  - WEIGHT / WORKOUT / NOTE
  - `isHuman = true`
- `FocusCard.dummies` 仅在 `@AppStorage("debugShowDummyCards") == true` 且真实数据为空时显示。

### 卡片渲染 — `FocusWalletCardView`

`FocusWalletCardView` 复用 `WalletPetCardFront` 的视觉语言，并在展开态切换到更接近身份卡的竖向布局；折叠卡片左下角不再重复显示名字，识别信息集中在顶部身份条。

- 背景：真实实体使用 `WalletPetCardTheme.meshColors(for:)` 的 3×3 `MeshGradient`；dummy 使用 `card.color` 派生渐变。
- 宠物图像：
  - 非透明照片：全幅 `scaledToFill` + 右侧可读性遮罩。
  - 透明 PNG：白色轮廓影 + 原图 popout。
  - 无头像：`PetSilhouetteView` Kawaii 剪影。
- 展开态：
  - 宠物名大号显示在顶部，物种字幕在其下。
  - 左侧显示宠物剪影/照片。
  - 右下显示 Days Together、年龄/品种/物种脚注、`O H A N A   P E T` 条码。
  - 紧凑态顶部显示 `topIdentityBar`，保证卡片被压缩时仍可识别名字和属性。

### 展开态快捷模块 — `expandedQuickModules`

active 宠物 / 人类卡下方复用经典 UI 的 `GoQuickActionCard` 网格样式，读取同一份 `@AppStorage("quickActionItems_v2")`。宠物若没有自定义项，则按物种生成默认前 4 项；人类默认项为体重 / 运动 / 用药 / 备注。短按执行快捷打卡 / 打开快速 sheet；长按进入对应详情。护理、健康、便便复用经典 UI 的 Popover 分流；dummy 卡继续使用原轻量入口。

编辑模式：标题行右侧铅笔进入编辑；编辑态同样最多显示 4 个快捷项，少于 4 个时显示“添加”占位格；支持抖动、减号删除、拖拽排序；点击完成后写回 `quickActionItems_v2`，与经典 UI / 宠物详情共享同一份配置。

椰子增长动画：`CoconutBalanceCapsule` 监听 `QuestManager.shared.coconutCount`，只在数值增加时触发轻微 pulse、`+N` 浮标和 haptic；减少椰子时只更新数字，不播放奖励动画。

默认项：
- 狗：喂食 / 喂水 / 遛狗 / 便便
- 猫：喂食 / 喂水 / 铲屎 / 便便
- 鱼：喂食 / 换水 / 清滤材 / 体重
- 其它：喂食 / 喂水 / 护理 / 体重

### Today Focus 与家庭协作入口

GO UI 折叠态首屏已收敛为 Today Focus：优先回答“今天谁需要照顾、什么最紧急、我点一下能完成什么”。展开卡片时隐藏，避免与 active card 下方快捷模块争抢空间。

**`TodayFocusCard`**：
- 数据来自 `IslandQuestEngine.todayQuests(pets:reminders:plants:events:)`
- 传入 `activePet: todayFocusActivePet`
- 完成回调走 `completeQuestInFocusStack(_:)`，继续发放椰子奖励并写入现有照护日志/账本路径
- 右侧绿洲入口 `onTapOasis` 打开 `OasisRewardView`

**新用户 3 分钟成功体验**：
- `OnboardingView.finishOnboarding()` 设置 `ohana_show_first_success_card = true`
- 首页显示 `firstSuccessCheckInCard(pet:)`，引导完成第一次“喂食 +🥥”
- 成功后写入喂食记录、触发椰子奖励动画，并设置 `ohana_first_quick_checkin_completed = true`

**家庭协作卡**：
- `familyCollaborationCard(pet:)` 显示在 Today Focus 下方
- `FamilyActivityStripView(style: .compact)`：今日谁照顾了当前宠物
- `assignedPendingReminders(for:)`：读取当前宠物今日内已指派 `Event.assigneeId` 的 pending reminders
- `AssigneeChip` + `NudgeButton`：展示负责人并提供本地催办反馈
- 周报入口打开 `WeeklyReportCard(pet:)`

**任务完成处理**（`completeQuestInFocusStack`）：
- `q_feed_*` → `.feeding` PetCareLog（`dailyPortionGrams` + `manualFeedNoteMarker`）
- `q_water_*`（非植物）→ `.waterChange` PetCareLog
- `q_walk` → `PetWalkingManager.shared.start(pet:)`
- `q_potty` → `.perfectPoop` PetPottyLog
- `q_water_plant` / `q_fertilize_plant` → 更新植物日期 + `PlantCareLog`
- `q_reminder` → `showingCalendar = true`
- 用药任务 → `PetMedicationDoseLogging.recordDose`
- 除 `q_walk` 外，完成后均 `QuestManager.shared.addCoconuts(amt, title: "岛屿任务")`

### FAB（右下角悬浮按钮）— `fabOverlay`

主按钮是 56pt 深蓝圆（`#1A2E8A`），展开后向上堆出 4 项：

1. **全部功能** → `FunctionMenuSheet`
2. **日历** → `CalendarView`
3. **绿洲** → `OasisRewardView`（`fullScreenCover`，右上角有关闭按钮）
4. **植物** → 淡化占位，标记“待开发”，点击只给 light haptic，不打开功能

细节：
- 展开时有 `Color.black.opacity(0.25)` scrim，点击 scrim 收回。
- `expandedId == nil && !isExpanded` 才显示；卡片展开态隐藏 FAB，避免遮挡 active card 和快捷模块。
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

**Path 1 — 首页 → 聚合页 → 单宠物**

```
FAB "全部功能"
  └── FunctionMenuSheet（sheet, large，5 分组）
        └── 功能行 → FeatureAggregateView(feature:, parentPath:)
              ├── 顶部宠物横滑 chip → 单宠物视图
              └── 汇总列表行       → 单宠物视图
```

- `FunctionMenuSheet.swift` —— 5 分区：健康管理 / 日常生活 / 植物与绿洲 / 档案与记忆 / 家庭岛屿
- “家庭岛屿”分区已接入 **家庭周报** / **照护账本分析** / **提醒健康**
- `FeatureAggregateView.swift` —— `.weight` 走 `IslandWeightDashboard`，`.expense` 走 `IslandExpenseDashboard`，其它走单宠物汇总列表

**Path 2 — 宠物详情 → 单宠物全部功能**

```
PetDetailView
  └── [全部] 胶囊 → PetAllFeaturesSheet（sheet, large，独立 NavigationStack）
        └── 功能行 → 单宠物视图（直接，不经聚合）
```

`FMDest.featureAggregate` / `.humanWeight` / `.humanExpense` 在 `PetAllFeaturesSheet` 场景下是死路径：switch 分支走 `assertionFailure`（debug 崩溃，release `EmptyView` fallback）。

**共享类型**（均在 `FunctionMenuSheet.swift`）：
- `FMDest` 枚举：`.featureAggregate(PetFeature)` / `.petHealth` / `.petMedications` / `.petFood` / `.petHygiene` / `.petWalks` / `.petPotty` / `.petBasicInfo` / `.petDocuments` / `.petMoments` / `.petAchievements` / `.petRetention` / `.petWeight` / `.petExpense` / `.familyWeeklyReport` / `.careLedgerAnalysis` / `.reminderObservability`
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

入口：首页 header 的 `CoconutBalanceCapsule` 点击 → `fullScreenCover` 打开 `IslandWealthDashboardView`。

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

---

### GO UI 关键文件清单

| 文件 | 角色 |
|---|---|
| `Views/Home/FocusStackHomeTestView.swift` | GO 首页：Wallet 卡片堆 / Today Focus / 家庭协作卡 / 展开态快捷模块 / header / FAB / 空状态 / 遗留 bloom 路径 |
| `Views/Home/FocusMoodQuestStrip.swift` | 心情 + 任务 TabView pager 白卡 |
| `Views/Home/EmptyStateWelcomeCard.swift` | 冷启动欢迎卡 |
| `Views/Home/FunctionMenuSheet.swift` | 全部功能 sheet + `FMDest` / `PetFeature` / `FMPetAvatar` |
| `Views/Home/FeatureAggregateView.swift` | 按功能聚合页 + 宠物 chip |
| `Views/Home/PetAllFeaturesSheet.swift` | 单宠物全部功能 sheet（从 PetDetailView） |
| `Views/Details/PetRetentionHubView.swift` | 单宠物长期留存成长档案总览 + 洞察建议 |
| `Views/Details/FamilyWeeklyReportDashboardView.swift` | 全家庭多宠周报、成员贡献排行、分享文本 |
| `Views/Details/CareLedgerAnalysisView.swift` | 统一照护账本分析、事件/成员/时间筛选 |
| `Views/Details/ReminderObservabilityView.swift` | 提醒健康面板、权限/待发/失败/过期诊断 |
| `Views/Details/IslandWealthDashboard2.swift` | 财富 dashboard（可滚动 + 收支分离） |
| `ViewModels/IslandWealthViewModel2.swift` | 财富 VM（`@Observable`，注入 `pets`/`humans`/`petColorMap`） |

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
  - `FocusStackHomeTestView.familyCollaborationCard` 在 GO 首页展示家庭协作摘要
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
