# Ohana (欧哈纳) — 完整技术与产品文档

> 版本：v4.5.0 | 平台：iOS 17+ | 框架：SwiftUI + SwiftData | 语言：Swift 6
> 原名：Ark | 品牌名已更新为 Ohana
> 文档目的：供 AI 工具进行代码审查、产品分析和优化建议
> 最后更新：2026-03（Phase 15：产品体检 + 多巴胺/架构优化）
>
> **开发实现状态（2026-03）**：Phase 1-15 全部完成并编译通过 (iPhone 17 Pro, iOS 26.2)。
>
> **Phase 15 新增（产品体检 + 多巴胺/架构优化 V4.5）**：
> - **P0-1 架构隐患修复** — `PetWalkLog.swift`：`routeLocationsData` 加 `@Attribute(.externalStorage)`，与 `mapSnapshotData` 保持一致，防止 GPS 坐标 JSON 数组内联膨胀 SwiftData 主 SQLite 文件（长期高频使用后可能造成 40MB+ 数据膨胀拖慢主线程查询）
> - **P1-1 成就体系扩充** — 新建 `AchievementManager.swift`（`@Observable` 单例，7枚成就纯计算无副作用，`async evaluate(for:)` 异步不阻塞主线程）+ 新建 `AchievementWallView.swift`（徽章网格：已解锁发光+颜色/未解锁灰度+说明文字）；`PetDetailView.swift` 概览 Tab 新增 `achievementBannerCard` 入口（进度胶囊 + 成就墙 Sheet）
> - **P1-2 打卡完成爽感升级** — `SwipeableEventRow.swift`：`triggerComplete()` 升级为双重触觉反馈（`.heavy` 重击 + 0.08s 延迟后 `.success` 通知音）+ 6 个 emoji 粒子飞散动画（`CelebrationParticle` 结构体，⭐️✨💛🎉🐾，0.7s 后自动清除）
> - **P1-4 IslandMood .celebrate 状态** — `IslandMoodWeatherView.swift`：`IslandMood` 枚举新增 `.celebrate`；`IslandMoodCalculator.calculate()` 新增触发条件：今日所有宠物遛狗总距离 ≥5km 或 `daysTogether` 命中里程碑节点（100/365/500/730/1000/1095）；粒子组：🎉🌟✨🎊⭐️💫
>
> **Phase 14 新增（UI/UX 精修第四轮）**：
> - **N1 Quick Action 完全自定义** — `OverviewView.swift`：`QuickActionItem` 加 `actionType` 字段+`Codable/Hashable`，`@AppStorage("quickActionItems_v2")` JSON 持久化；新增 `AddQuickActionSheet`（两步 wizard：Step1 选宠物行列表→Step2 该宠物可用功能 3列网格，8种功能含物种过滤）；`GoQuickActionCard` 加 `onDelete` 回调+`LongPressGesture`+`confirmationDialog` 删除确认；虚线"+"新增格常驻末尾
> - **N2 遛狗地图详情页** — 新建 `WalkDetailView.swift`：`Map` 视图+`MapPolyline` 路径折线（goLime色）+起点/终点 `Annotation`；点击"在 Apple Maps 中查看"通过 `MKMapItem.openMaps` 跳转步行导航；底部统计4格（距离/时长/日期/出发时间）；`WalkTrackingCard.swift` 地图预览区改为 `Button`，idle 时点击 → `WalkDetailView`，右下角 `arrow.up.forward.circle.fill` 提示；`WalkSummarySheet.swift` 历史记录行改为 `Button` → `WalkDetailView`
> - **N3 日历滑动层重叠修复** — `CalendarView.swift`：删除 `goEventRow` 内手写的 ZStack 左/右滑背景层（与 `SwipeableEventRow` 内部背景重叠导致动画异常），直接返回 `SwipeableEventRow`
> - **N4 宠物卡片背景层次+头像圆形光晕** — `ArkCrewIDCardView.swift`：重写 `cardFrontView` 背景为 5 层叠加（①深色打底 mix(.black,0.25)②斜向3色渐变③右上角椭圆光斑 RadialGradient④左下暗角⑤巨字装饰 opacity 0.06）；头像从方形圆角改为：外发光光晕圈(blur12)+内圆背景+圆形裁剪照片/emoji+边缘细圆圈+右下角物种emoji浮标(.ultraThinMaterial 毛玻璃背景)
>
> **Phase 13 新增（UI/UX 精修第三轮）**：
> - **T1 Flashcard 弧线动画** — `CritterDeckCarousel.swift`：两段动画：第一段顶牌弧线飞出+旋转28°+渐隐；第二段重排数组后新牌从底部弹入。新增 `flyingCardOffset/Rotation/Opacity` 状态驱动顶牌独立变换
> - **T2 Island Stats 去边框+虚线分割** — `IslandStatComponents.swift`：移除 `strokeBorder`；`OverviewView.swift`：新增 `islandStatDivider` 计算属性（虚线 `Path`），卡片间 spacing 改为 0
> - **T3 Quick Access 先选宠物再跳转** — `OverviewView.swift`：多宠物时弹 `PetPickerSheet`，单宠物直接跳；新建 `PetPickerSheet.swift` 组件（白底、头像+名字+物种/品种行）
> - **T4 日历滑动渐显文字** — `SwipeableEventRow.swift`：全面重写为 progress-based 渐变效果；左滑显示绿色"完成"+图标，右滑显示红色"删除"+图标，`progress` 控制 opacity/scale，超阈值触发震动+操作
> - **T6 主题色预览黑色修复** — `Pet.swift`：`PetThemeColor` 新增 `hexValue` 属性；`AddPetWizardView.swift`：选择器改用 `tc.hexValue`（hex字符串）存入 `themeColorHex`，修复原来存入 `rawValue`（英文名）导致 `Color(hex:)` 返回黑色的问题
> - **T7 遛狗卡片 Go UI 主题化** — `WalkTrackingCard.swift`：`ohanaGlassStyle` 改为 `goTranslucentCard`；开始/结束按钮改 `goLime`+黑字；暂停按钮 `goYellow`；停止按钮 `goRed`；恢复按钮 `goTeal`；计时器秒数改 `goLime`；空地图占位改深色风格
> - **T8 体重历史记录白底黑字** — `WeightHistoryView.swift`：`recordListLayer` 背景改 `Color.white`，标题/文字改黑色，记录行背景改 `systemGray6`
> - **T9 花费历史记录白底黑字** — `ExpenseHistoryView.swift`：同上，`recordListLayer` 白色背景+黑字+`systemGray6` 行背景
> - **T10 长按打卡格黑色空弹窗修复** — `ArkCrewIDCardView.swift`：引入 `IdentifiableAction`，`.sheet(isPresented:)+if let` 改为 `.sheet(item:)`，确保 `longPressedAction` 非 nil 才展示内容
> - **CapsuleTag 编译错误修复** — `PlantDetailView.swift`、`HumanDetailView.swift`、`AddHumanWizardView.swift`：用内联 `.background(in: Capsule())` 替代未定义的 `CapsuleTag` 组件
>
> **Phase 12 新增（UI/UX 精修第二轮）**：
> - **R1 头像裁剪 zoom out 修复** — `AddPetWizardView.swift`：`PetImageCropView` 新增 `@State containerSize`，在 GeometryReader `.onAppear`/`.onChange` 记录真实容器尺寸；`performCrop()` 改用 `containerSize` 而非 `UIScreen.main.bounds`，消除 safe area 差异引发的坐标偏移和 zoom out 效果
> - **R2 卡片切换动画 Figma 重写** — `CritterDeckCarousel.swift`：参考 Figma FlashCards.tsx 重写 ghost card 动画；顶牌释放后立即数据洗牌，旧牌作为 ghost card 从拖拽位置 spring 动画回底部，新顶牌从 depth-1 位置弹入
> - **R3 Island Stats 透明等高** — `IslandStatComponents.swift`：`IslandStatCard` 背景完全透明，固定高度 160pt 保证一致性，描边改为 `white.opacity(0.08)` 细线
> - **R4 Quick Access 加号→物种选择** — `OverviewView.swift`：Quick Access `handleAction("add")` 改为弹出 `AddEntityView`（物种选择页面）而非直接跳转添加宠物
> - **R5 打卡格长按→添加待办** — `ArkCrewIDCardView.swift`：新增 `AddReminderFromCheckInSheet`（白色底/全天开关/开始结束时间 DatePicker/7档重复频率横滚 chip/保存到 Event+Reminder）；`SpeciesCheckInGrid` 每格改用 `.onTapGesture`（单击打卡）+ `.onLongPressGesture(0.5s)`（长按弹出添加待办 sheet），触觉反馈 `.heavy`
> - **R6 SmartTodayCard 对比度修复** — `SmartTodayCard.swift`：新增 `textColor` 计算属性，`goLime`/`goYellow` 背景→`arkInk` 深色文字，其余深色背景→`.white`，避免深底深字不可见
> - **R7 体重/花费添加 Sheet 白色背景** — `WeightHistoryView.swift`、`ExpenseHistoryView.swift`：重写 addWeightSheet/addExpenseSheet 为白色背景（`Color.white`），大字输入框（56pt）+`systemGray6` 圆角卡底，日期行右对齐 DatePicker，彩色保存按钮（goTeal/goYellow），`presentationDragIndicator(.hidden)`
> - **R8 返回首页卡片显示正面** — `CritterDeckCarousel.swift` + `OverviewView.swift`：`resetFlip: Binding<Bool>` 参数控制翻转状态重置，`OverviewView` 在 `.onAppear` 时触发重置
> - **R9 日历默认列表+滑动操作** — `CalendarView.swift`：`viewMode` 默认值改为 `.list`；新建 `SwipeableEventRow.swift`：DragGesture 实现左滑完成（触发 `isCompleted.toggle()`）/右滑删除（弹 alert），alert 支持"删除此条"和"删除此条及之后所有重复"（按 title 匹配系列）
>
> **Phase 11 新增（UI/UX 精修 + 功能增强）**：
> - C1 自定义颜色器修复 / C2 头像裁剪坐标系 / C3 Tinder 洗牌循环 / C4 Island Stats 横向图表卡 / C5 智能待办卡 / C7 植物开发中标记 / C8a-d 记录详情页 / C9 卡片背面可点击（详见 project_plan.md Phase 11）
>
> **Phase 10 新增（UI精修 + Bug修复）**：
> - B1 头像白屏修复 / B2 毛色瞳色扩展 / B3 Quick Access+ManageSheet / B4 barcode / B5 Island Stats 虚线行 / B6 Tinder洗牌动画（详见 project_plan.md Phase 10）
>
> 待实现：R10 继续完善页面（护理详情/文件管理）、Widget、Siri、CloudKit、数据导出。详见 project_plan.md。

---

## 一、项目概述

### 1.1 产品定位

**Ohana（欧哈纳）** 是一款家庭生命体综合管理 iOS App，核心理念源自夏威夷语：
> *"Ohana means family. Family means nobody gets left behind or forgotten."*

它将宠物、人类家庭成员、植物统称为"家人（Critters）"，打造为一座充满热带氛围的"欧哈纳岛屿"。不同于冰冷的"管理工具"，App 设计强调情感连接和多巴胺式的交互体验。



### 1.2 技术栈

| 层次 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 数据持久化 | SwiftData（App Group 共享，Widget 可读） |
| 数据版本管理 | VersionedSchema（V1 → V2 → V3），轻量迁移 |
| 云同步 | CloudKit（当前 `.none`，预留 `.automatic`） |
| 认证 | Sign in with Apple（ASAuthorizationController） |
| 位置服务 | CoreLocation（GPS 遛狗轨迹） |
| 通知 | UserNotifications（本地推送 + 锁屏操作按钮） |
| 实时活动 | ActivityKit（Live Activity，遛狗动态岛） |
| 健康数据 | HealthKit（步数读取，可选） |
| Siri / 快捷指令 | AppIntents（4 个 Intent，AppShortcutsProvider） |
| 小组件 | WidgetKit（ArkWidget，待完善） |
| PDF 导出 | UIGraphicsPDFRenderer（宠物健康档案 PDF） |
| 地图快照 | MapKit（MKMapSnapshotter，遛狗路线截图） |
| 日志 | os.log / ArkLogger（Release 自动静默） |

### 1.3 核心设计语言

**"Go UI"（v4.0.0 全面重构）** — 灵感来自 GO Club 设计系统：



1. Color System (色彩系统)
Base Background (全局背景渐变)
这三色构成了 App 最具识别度的“电光蓝”深色环境。

color-bg-gradient-top: #5B52FF (goPrimaryLight)

color-bg-gradient-mid: #4338FF (goPrimary)

color-bg-gradient-btm: #3028CC (goPrimaryDark)

Accent / Dopamine Colors (多巴胺强调色)
用于极高对比度的视觉焦点，如打卡按钮、高亮 CTA 卡片（如截图中的黄绿卡片）、Tab 选中状态。

color-accent-primary: #C8FF00 (goLime) —— 绝对核心的灵魂高光色

color-accent-light: #E8FFB0 (goLimeLight)

color-accent-mint: #B8FFD0 (goMint)

color-accent-yellow: #FFF44F (goYellow)

Surface Colors (容器与卡片底色)
用于承载数据的面板。

color-surface-solid: #FFFFFF (goCardWhite) —— 用于亮色实心卡片

color-surface-blue: #5B6AFF (goCardBlue) —— 用于部分强调的微渐变蓝卡

color-surface-dark: #1A0E4B (goDarkBlue) / #0D0638 (goDeepNavy) —— 用于悬浮导航底座或深色对比卡片

color-surface-glass: rgba(255, 255, 255, 0.12) (goTranslucentCard) —— 半透明毛玻璃底色

Semantic / Functional (语义功能色)
用于成功、警告、错误或特定的图表状态。

color-semantic-success: #00D4AA (goTeal) —— 进度条拉满或健康状态

color-semantic-warning: #FF8C42 (goOrange) —— 粮仓预警或即将逾期

color-semantic-danger: #FF4757 (goRed) —— 紧急状态或严重逾期

Typography Colors (文本颜色)

color-text-on-dark-primary: #FFFFFF (纯白) —— 深色/渐变背景上的主标题与大数字

color-text-on-dark-secondary: rgba(255, 255, 255, 0.4) 到 0.7 —— 辅助说明文字、单位

color-text-on-light-primary: Color.arkInk (深墨色/纯黑) —— 用于青柠色 (goLime) 或白色卡片上的文字，形成极致对比

🔤 2. Typography System (字体系统)
Go UI 强调运动感和亲和力，抛弃了锋利的系统默认字体，全面转向圆润且极具重量感的无衬线字体。

Font Family: SF Pro Rounded (Apple 系统圆体，极具亲和力与现代感)

Hero / Metric (巨型数据):

font-size: 56pt 到 80pt

font-weight: .black (极其粗壮)

用途：打卡天数、体重读数、巨幅时间显示

Header (标题):

font-size: 36pt (大卡片标题) / 24pt (分段标题)

font-weight: .black

Body (正文与标签):

font-size: 16pt / 14pt

font-weight: .bold (设计规范中标签均使用 bold 以在深色背景下保持清晰)

design: .rounded

🔲 3. Shape & Surface (形状与质感系统)
Go UI 的高级感来源于极致的圆角和克制的边框。

Corner Radius (圆角):

radius-card-large: 24pt —— 所有主层级卡片（如体重监测、今日目标卡）

radius-card-base: 20pt —— 次级 Bento 小卡片

radius-pill: 999px (Capsule Shape) —— 按钮、悬浮导航栏、标签

Borders (边界):

border-glass: rgba(255, 255, 255, 0.15) 到 0.18, width: 1px —— 用于勾勒毛玻璃卡片的边缘，增加精致的“高光边缘”感。

border-divider: rgba(255, 255, 255, 0.25) 虚线 (dash [4,4]) —— GoDashedDivider 极简风格的分割线。

Textures (纹理):

texture-noise: opacity: 0.015, blendMode: .overlay —— 全局背景叠加，消除渐变的数字塑料感，增加高级磨砂颗粒感。
- **首页 ID 卡**：正面鲜蓝渐变 (`goCardBlue → goPrimary`)，巨字 daysTogether + 条形码 + 胶囊标签；背面深蓝渐变 (`goDarkBlue → goDeepNavy`)，彩色 icon bento 网格
- **字体**：`SF Pro Rounded`，`.black` 权重，大数字（36-56pt），标签用 `.bold` + `design: .rounded`
- **文字颜色**：深色背景统一 `.white` / `.white.opacity(0.4-0.7)`；亮色卡片使用 `Color.arkInk`
- **强调色**：`goLime #C8FF00` 作为主强调（按钮、Tab 选中、FAB），替代旧紫蓝渐变
- **分割线**：`GoDashedDivider` 虚线分割 (dash [4,4])
- **导航**：右下角 `OrbFAB`（青柠色 + 深色图标）；Capsule 形 Tab 选择器（选中为青柠底 + 深色字）
- **动画**：`spring(response: 0.6, dampingFraction: 0.78)` 卡片翻转；`spring(response: 0.35)` 一般交互



---

## 二、数据模型层（SwiftData Models）

### 2.1 数据库配置

- **App Group ID**：`group.com.guanchen.li.Ark`
- **SharedModelContainer**：主 App 和 Widget 共享同一 SQLite 文件
- **Schema 版本**：
  - `ArkSchemaV1`（1.0.0）：基础模型
  - `ArkSchemaV2`（2.0.0）：Pet 证件字段、PetDocument.category、Human.avatarImageData
  - `ArkSchemaV3`（3.0.0）：Pet/Human avatarImageData 改为 `@Attribute(.externalStorage)`

### 2.2 核心模型

#### Pet（宠物）
```
字段（精简）：
- id: UUID（唯一）
- name, species（狗/猫/兔子等）, breed（品种）
- birthday, gender(male/female/unknown), isNeutered
- avatarEmoji, avatarImageData（@externalStorage）
- microchipID, vetContact, allergies
- passportNumber, passportExpiryDate（证件）
- formerName, lineageInfo（血统）
- themeColorHex（智能主题色）
- homeDate（到家日）, birthCountry/birthCity
- foodBrand, restockDate/Weight/dailyPortionGrams/foodPrice（余粮系统）
- isShared, ckRecordName（CloudKit 同步）

关联（cascade delete）：
- expenseLogs [PetExpenseLog]     — 宠物账本
- foodRecords [PetFoodRecord]     — 饮食记录
- pottyLogs   [PetPottyLog]       — 排泄日记
- walkLogs    [PetWalkLog]        — 遛狗轨迹
- hygieneLogs [PetHygieneLog]     — 护理记录
- milestones  [PetMilestone]      — 里程碑时间轴
- weightLogs  [PetWeightLog]      — 体重趋势
- documents   [PetDocument]       — 证件管理
- healthLogs  [PetHealthLog]      — 健康日志

计算属性：
- remainingFoodGrams/Days/Percent  — 余粮推算
- estimatedRunOutDate              — 断粮日期
- daysTogether                     — 共处天数
- humanEquivalentAge               — 人类等效年龄（按物种/体型差异化算法）
```

#### Human（家庭成员）
```
字段：
- id: UUID（唯一）
- name, birthday, bloodType
- avatarEmoji, avatarImageData（@externalStorage）
- role: String（owner / editor / viewer）
- appleUserIdentifier（Sign in with Apple 绑定）
- notes
```

#### Plant（植物）
```
字段：
- id, name, species, location
- avatarEmoji
- wateringIntervalDays（浇水周期，默认7天）
- fertilizingIntervalDays（施肥周期）
- lastWateredDate, lastFertilizedDate
- notes
```

#### Household（家庭组织）
```
字段：
- id, name, createdAt
- ckShareRecordName（CloudKit 共享区域）
级联关系：Human、Pet、Plant
```

#### Event（事件）
```
字段：
- id, title, startDate, endDate, isAllDay
- eventType（见 EventTypes 枚举）
- relatedEntityType（"Human"/"Pet"/"Plant"）
- relatedEntityId（弱关联 UUID 字符串）
- recurrenceDays（0=不循环，支持每日/周/月/年）
- recurrenceEndDate（循环终止日期）
- isCompleted, completedOccurrences（多次出现独立完成）
```

**支持的 EventType**：
```
通用：生日、纪念日、日常、健康、任务、购物清单、家务分配
宠物：疫苗、体外驱虫、体内驱虫、洗澡美容、就医、换粮、铲猫砂
植物：浇水、施肥
```

#### Reminder（提醒）
```
字段：
- id, event（关联 Event）
- scheduledAt（触发时间）
- status: String（底层存储，兼容 #Predicate）
  - statusEnum: ReminderStatus（.pending/.completed/.skipped/.snoozed）
- completedAt, completedBy（打卡人昵称）
- notificationId（本地通知 ID）
```

#### 宠物子记录模型
```
PetPottyLog     — 排泄记录（date, type: PottyType）
  PottyType：perfectPoop / softPoop / liquidPoop / pee

PetWalkLog      — 遛狗记录（startDate, endDate, distanceMeters,
                  mapSnapshotData, routeLocationsData）
  计算属性：durationSeconds, distanceText, durationText

PetHygieneLog   — 护理记录（date, type: HygieneType）
  HygieneType：teeth / nails / ears / brushing / bath
  每种类型有推荐周期（cycleDays）

PetWeightLog    — 体重记录（date, weight）

PetHealthLog    — 健康日志（date, type, note, vetName, cost）
  type：general / vaccine / medication / surgery / dental / checkup / emergency / other

PetDocument     — 证件管理（title, category, issueDate, expiryDate,
                  issuingAuthority, notes, reminderDate）
  category：passport / vaccine / insurance / medical / registration / other

PetExpenseLog   — 消费账本（date, amount, category: ExpenseCategory, note）
  ExpenseCategory：food / treats / medical / grooming / toys / other

PetFoodRecord   — 饮食记录（brand, dailyGrams, startDate, notes）

PetMilestone    — 里程碑时间轴（date, title, emoji, notes）
```

#### WaterLog（饮水日志）
```
字段：date, amountMl（毫升）, note
```

---

## 三、应用架构与入口

### 3.1 启动流程

```
ArkApp（@main）
├── ModelContainer 初始化（ArkSchemaV3 + App Group 路径）
│   └── 失败时降级为 in-memory（do-catch，不 try!）
├── .modelContainer(container) 注入全局
├── .tint(Color.arkCoral)
└── RootView
    ├── hasSeenOnboarding == false → OnboardingView
    └── hasSeenOnboarding == true  → ContentView → OverviewView
```

### 3.2 ContentView / OverviewView

`OverviewView` 是主视图，包含：
- 全局背景：`ArkBackgroundView`（紫蓝粉三色渐变 + 噪点纹理）
- 气候层：`IslandMoodWeatherView`（基于宠物状态的粒子特效）
- 主体滚动区域：`mainScrollView`
- 右下角 FAB：`OrbFAB`（日历按钮）+ 右上角工具栏

**主滚动区域三分区结构（v3.4.0 重构）**：

**a 区 — 宠物卡片**
- `IslandAmbientHeader` — 透明仪表盘，视差偏移
- `CritterDeckCarousel` — 3D 卡牌转盘（点击翻转 / 左右无限循环滑动）

**b 区 — Island Stats（多宠物数据对比）**
- 标题：`ISLAND STATS`
- 统一横向 `ScrollView`：`PetWeightCard`（体重趋势）+ `IslandInsightCard`（inlineMode）所有数据卡
- 全部卡片宽度 = `ScreenCompat.bounds.width - 32`，与 PetWeightCard 等宽

**c 区 — 快速入口（用户自定义）**
- `HomeQuickAccessSection`（`Views/Home/HomeQuickAccessSection.swift`）
- 由 `QuickAccessPreferences`（AppStorage JSON）驱动，默认：待办提醒、日常打卡、遛狗追踪、岛屿简报、生日倒计时
- 右上角「⊟」按钮打开 `QuickAccessCustomizeSheet` 自定义
- 菜单入口：用户头像菜单 → "自定义快速入口"
- 已删除：`HibiscusStreakView`（今日打卡/连胜花）

### 3.3 导航结构（v3.4.0 更新）

```
RootView
└── ContentView（NavigationStack）
    └── OverviewView（主页）
        ├── [Sheet] AddEntityView                  — 添加生命体
        ├── [Sheet] SettingsView                   — 设置
        ├── [Sheet] DashboardManageView            — 营地卡片管理（旧系统）
        ├── [Sheet] QuickAccessCustomizeSheet      — 快速入口自定义（v3.4.0 新增）
        ├── [Sheet] CalendarView                   — 全局日历
        ├── [Sheet] CrewRosterOverlay              — 岛民大厅
        ├── [Sheet] CloudSharingView               — 家庭共享（v3.4.0 新增菜单入口）
        └── [Push] .navigationDestination(item:) → PetDetailView / HumanDetailView
            （由 ArkCrewIDCardView 背面右上角 onDetail 回调触发）

右上角菜单（v3.4.0 更新）：
  添加小怪兽/岛民 | 编辑海滩营地 | 自定义快速入口 | 查看全体岛民 | 家庭共享 | 设置
```

---

## 四、页面详细说明

### 4.1 OnboardingView（引导页）

- **结构**：`TabView(.page)` 多页滑动
- **页数**：5 页，每页含大图标、标题（全小写英文）、副标题说明
- **内容**：功能介绍（家人管理、日历、健康追踪、遛狗、数据安全）
- **导航**：Next / Skip 按钮，最后一页变为"Start Island Journey"
- **完成**：写入 `@AppStorage("hasSeenOnboarding")`

### 4.2 OverviewView（主页 / 海滩营地）

**文件**：`Views/OverviewView.swift`

**状态变量（v3.2.0）**：
- `selectedPet: Pet?`：NavigationLink 跳转宠物详情的目标
- `selectedHuman: Human?`：NavigationLink 跳转人类详情的目标
- `showingCrewRoster`, `showingCalendar`：Sheet 展示状态
- `isEditingHome`：首页编辑模式（重排 Dashboard 卡片）
- `searchText`：全局搜索文字
- `scrollOffset: CGFloat`：视差偏移追踪

**@Query 数据源**：
- `humans`（按 `createdAt` 排序）
- `pets`（按 `createdAt` 排序）
- `plants`
- `households`
- `pendingReminders`（只取 status == "pending"，按 `scheduledAt` 排序）

**搜索功能**：
- 同时搜索 `Human.name`、`Pet.name`、`Reminder.event.title`
- 结果实时过滤（`isSearching` = searchText 非空）
- 搜索时整体切换为 `searchResultsView`

**顶部工具栏**：
- 左：设置按钮（齿轮图标）
- 右：卡片管理按钮 + 添加生命体按钮
- 编辑模式时左侧出现"完成"按钮

**FAB 系统**：
- `OrbFAB`（右下角悬浮）：跳转日历 / 岛民大厅 / 添加生命体
- 搜索或编辑模式时 FAB 自动隐藏

### 4.3 CritterDeckCarousel（3D 卡牌转盘）

**文件**：`Views/Home/CritterDeckCarousel.swift`

- **功能**：展示所有宠物和人类的 ID 卡片，支持左右滑动切换
- **卡片类型**：`ArkCrewIDCardView`（宠物）/ `HumanIDCardView`（人类）
- **堆叠布局**：后方卡片缩小 6%/层 + 倾斜 5°/层 + 向下偏移 10pt/层（渲染 relIdx -1 ~ +2 共4张）
- **拖拽切换（v3.5.0）**：
  - 手势挂载在 `ZStack` 外层，不受子视图 `allowsHitTesting` 影响
  - 卡片翻转到背面时仍可左右滑动切换
  - **无限循环**：`wrappedIndex(_ idx:)` 取模，可循环滑动（A→B→C→A…）
  - 超过 60pt 阈值才切换，`spring(response:0.55, dampingFraction:0.78)` 弹回
- **扑克牌堆叠动画（v3.5.0 修复）**：
  - 后方卡片叠在正中心后方，只有层深（`yOff = depth × 8`）和缩放差异，不向左右展开
  - 当前卡完整跟随拖拽偏移；后方卡 `dragFollow = 0`，保持静止堆叠
  - 切换时只有当前卡被"抽走"，下一张从原位弹出，视觉上如同一摞牌被逐一取走
  - `relIdx = -1`（前一张）深度视为 0，不额外偏移
- **触觉反馈**：切换时 `.light` UIImpactFeedback
- **陀螺仪保护**：拖动期间 `gyroscopeLocked=true` 暂停视差

**交互逻辑（v3.4.0）**：
```
拖拽手势（外层 ZStack）
  → 无论正面/背面，均可左右切换
  → activeIndex = wrappedIndex(activeIndex ± 1)（无限循环）

点击宠物卡片正面
  → ArkCrewIDCardView.onTap
  → 3D Y 轴 180° 翻转到背面
  → 背面右上角 [↗] → onDetail → selectedPet → PetDetailView
```

**底部指示器**：胶囊形分页点（当前页宽 20pt，其余 6pt）

---

### 4.3.2 HomeQuickAccessSection（快速入口 — v3.4.0 新增）

**文件**：`Views/Home/HomeQuickAccessSection.swift`

**功能**：首页 c 区，用户可自定义放置的快捷卡片集合

**卡片类型（`QuickAccessCardType`）**：

| rawValue | 标题 | 说明 |
|---|---|---|
| `walk_tracking` | 遛狗追踪 | WalkTrackingCard，实时地图 |
| `check_in` | 日常打卡 | UnifiedCheckInGrid，首只宠物 |
| `reminders` | 今日待办 | TodayReminderRibbon |
| `weight_tracker` | 体重追踪 | PetWeightCard |
| `food_inventory` | 粮仓管理 | 余粮进度条（自绘） |
| `expense` | 本月花费 | 月度花费汇总 |
| `briefing` | 岛屿简报 | ArkBriefingCard |
| `anniversaries` | 生日倒计时 | AnniversariesCard |

**持久化**：`QuickAccessPreferences`（`ObservableObject`），AppStorage key `home_quick_access_cards`，JSON 编解码

**自定义 Sheet**：`QuickAccessCustomizeSheet`，全屏毛玻璃风格，已启用/可添加分区，点击 ±/− 切换

---

### 4.X CatCareStationCard（猫咪护理站 — v3.4.0 新增）

**文件**：`Views/Details/CatCareStationCard.swift`

**触发条件**：`PetCardType.catCareStation`，仅 `pet.species == "猫"` 时显示（`PetDetailView.neoCardSection`）

**护理动作（`CatCareAction`）**：

| case | emoji | 标签 |
|---|---|---|
| `litter` | 🧹 | 铲猫砂 |
| `feed` | 🥩 | 喂食 |
| `water` | 💧 | 喂水 |

**功能**：
- 点击按钮：创建 `Event`（含 emoji 标题，关联 Pet.id），litter 同时写入 `PetHygieneLog`
- 4 秒撤回：同步删除 Event + HygieneLog
- 长按按钮（0.5s）：弹出 `CatCareTodoSheet` — 创建 Event + Reminder + 本地通知
- 点击标题行：进入 `CatCareHistorySheet` — 按日期分组展示所有护理 Event
- 今日统计行：实时显示当日各项打卡次数

---

### 4.3.1 ArkCrewIDCardView（岛民身份证卡）

**文件**：`Views/Components/ArkCrewIDCardView.swift`

**卡片尺寸**：`(屏宽 - 48) × 520pt`，圆角 32pt

**正面（CardFrontView）**：
- 底层：宠物主题色渐变背景（`PetThemeColor.deepColor → .color`）+ 弥散阴影
- 巨字名字装饰（120pt，white opacity 0.08，后层）
- 中层：`CritterParallaxAvatarView`（破框悬浮头像，CoreMotion 视差）
- 底部信息层：名字（52pt .heavy）+ 胶囊标签（年龄/性别/国家/品种）+ 条形码 + ChipID
- 顶部标签：`OHANA PALS` + 物种

**背面（CardBackView）**：
- 背景：主题深色渐变 + `ultraThinMaterial` 半透明叠层
- 顶栏：`IDENTITY / 岛民凭证` 标题 + 编辑按钮（`square.grid.2x2`）+ **详情入口**（`arrow.up.right.circle.fill`）
- 虚线分割线
- `UnifiedCheckInGrid`：万能打卡板（今日数据快捷打卡）
- Bento 网格（`LazyVGrid` 双列）：
  - 6 个组件：体重/粮仓/捣蛋/巡岛/证件/芯片
  - 每组件支持 Small（1列）/ Wide（2列）切换
  - 可拖拽排序（`onDrag` / `onDrop`）
  - 编辑模式：左上角 `−` 删除按钮 + 底部添加菜单
  - 布局通过 `UserDefaults` 持久化（key: `bento_layout_{petId}`）

**CoreMotion 视差**：
- `MotionManager.shared` 单例（15fps 节流）
- 最大偏移 ±10pt（parallaxX/Y）
- 低电量模式自动跳过
- 拖动期间锁定（`gyroscopeLocked`）

---

### 4.4 CritterDeckCarousel Island Stats 卡（v3.5.0 透明化）

**文件**：`Views/Home/CritterDeckCarousel.swift`，`insightSlide` 容器 + 各 `*Content` 数据视图

**外观（v3.5.0 修改）**：
- 去掉各卡片的彩色背景，改为 `.ultraThinMaterial.opacity(0.45)` + 白色 1pt 描边
- 所有文字改为白色（`.white` / `.white.opacity(N)`），进度条轨道改为 `.white.opacity(0.2)`
- 卡片文字/图表悬浮在首页渐变背景上，与 IslandAmbientHeader「今日任务全清」区域风格一致

**卡片列表（横向 ScrollView，`insightSlide` 容器）**：
1. **体重监测**（绿色进度条）：各宠物最新体重 + bar 对比
2. **本月花费**（橙色进度条）：各宠物本月消费合计 + bar 对比
3. **巡岛记录**：各宠物最后遛狗时间 + 总次数
4. **卫生打卡**：各宠物最后护理时间 + 总次数
5. **能量代谢**：今日卡路里消耗 / DER（橙→黄渐变进度条）
6. **粮仓预警**（条件显示）：余粮天数，≤7天显示红色警告
7. **健康趋势**：本周 vs 上周遛狗趋势分析
8. **消费透视**：本月合计 + 环比趋势 + 分类 Top N

---

### 4.4.1 HomeSectionPreferences（首页模块管理 — v3.5.0 新增）

**文件**：`Views/Home/HomeSectionPreferences.swift`

**功能**：允许用户对首页三大模块进行排序和显隐控制

**模块定义（`HomeSection` enum）**：

| case | 标题 | 说明 |
|---|---|---|
| `petCards` | 宠物卡片 | CritterDeckCarousel |
| `islandStats` | Island Stats | 体重/花费/遛狗等数据卡横向滚动 |
| `quickAccess` | 快速入口 | 待办/打卡/自定义快捷入口 |

**持久化**：`HomeSectionPreferences`（`ObservableObject` 单例），`UserDefaults` key：
- `home_section_order`：JSON 编码的顺序数组
- `home_section_hidden`：JSON 编码的隐藏集合

**管理 Sheet**：`HomeSectionManageSheet`
- 全屏毛玻璃风格，`List` + `.environment(\.editMode, .constant(.active))` 拖拽排序
- 每行右侧眼睛按钮（`eye.fill` / `eye.slash.fill`）切换显隐

**入口**：
- 菜单「管理首页模块」（`square.3.layers.3d`）
- Island Stats 分区标题行右侧小图标

---

### 4.4.2 WalkTrackingCard（遛狗追踪卡）

**文件**：`Views/Home/WalkTrackingCard.swift`

**布局**：左列（头像+计时器+按钮）+ 右列（地图小图 110×130pt）

**左列详情**：
- `headerRow`：宠物头像（36pt 圆形 + 白色描边）+ 名字/状态
- `statusBadge`：运动中（蓝色脉冲点）/ 已暂停（橙色）/ 已完成（绿色）
- `timerArea`：`FlipDigit` 数字翻转组件（`contentTransition(.numericText)`），格式 HH:MM:SS，秒数蓝色
- `buttonRow`（按状态切换）：
  - idle → `开始` 按钮（`.regularMaterial` 胶囊）
  - running → `暂停` + `结束` + `💩便便` 三按钮
  - paused → `继续` + `结束` + `💩便便` 三按钮
  - finished → `重新开始` 单按钮
- `💩便便` 按钮：计数 badge（橙色圆点）+ `FloatingPoopEmoji` 上浮动画

**右列地图（v3.2.0 真实轨迹）**：
- **idle 状态**：显示该宠物最近一次 `PetWalkLog.mapSnapshotData` 截图（无历史则显示地图图标占位）
- **运动中**：监听 `LocationManager.shared.collectedLocations.count`，每新增 10 个坐标点刷新一次
  - 单点：`MKMapSnapshotter` 显示当前位置（span 0.005°）
  - 多点：`buildRouteSnapshot()` 绘制蓝色路径线（起点绿点 5pt，当前蓝点 6pt）
- 定位脉冲动画：扩散圆环（2.5× 放大 + 渐隐）+ 蓝点轻微跳动

**状态机**：`WalkPhase` enum（idle / running / paused / finished(elapsed:poopCount:)）

**注意**：`WalkTrackingCard` 内部状态机独立于 `PetWalkingManager`（详情页的管理器），两者互不影响

---

### 4.5 ExpandableCreaturePanel（已废弃，v3.2.0 移除）

**原功能**：`ExpandablePetPanel` / `ExpandableHumanPanel` 从底部弹出的半屏→全屏面板。

**v3.2.0 变更**：已从 `OverviewView` 主流程中移除。宠物详情改由 `ArkCrewIDCardView` 背面的 `onDetail` 回调 → `NavigationLink` 跳转实现。

文件仍保留在代码库（`ExpandableCreaturePanel.swift`），但不再从 `OverviewView` 触发。

### 4.6 PetDetailView（宠物详情页）

这是 App 最复杂的页面，包含**可拖拽排序的卡片系统**。

**顶部 Hero 卡片**（`petHeroCard`）：
- 头像（照片 / Emoji）
- 名字、品种、性别、绝育状态
- 共处天数、人类等效年龄
- 点击跳转 `PetBasicInfoDetailView`

**可自定义卡片系统**（`PetCardType` 枚举，`AppStorage` 持久化顺序）：
| 卡片类型 | 内容 |
|---------|------|
| `.immunity` | 疫苗/驱虫/体检免疫仪表板 |
| `.hygiene` | 护理状态卡（刷牙/剪甲/清耳/梳毛/洗澡） |
| `.medical` | 就医历史、健康日志列表 |
| `.weight` | 体重趋势折线图 |
| `.food` | 余粮计算（进度条 + 断粮倒计时） |
| `.expense` | 消费账本（本月支出 + 分类图表） |
| `.documents` | 证件管理（护照/疫苗本等，含到期提醒） |
| `.health` | 综合健康日志 |
| `.potty` | 排泄打卡 + 噗噗电台入口 |
| `.milestones` | 里程碑时间轴 |
| `.walking` | 遛狗控制台（开始/暂停/停止 + 历史记录 + 地图截图） |
| `.achievement` | 成就墙（徽章系统） |
| `.reports` | 欧哈纳电台（周报 + PDF 导出） |

**工具栏按钮**：
- 编辑布局（拖拽排序卡片）
- 查看日历（筛选该宠物的事件）
- 更多菜单：编辑信息 / 生成寄养卡 / 导出 PDF

**Sheets**：
- `EditPetSheet`：编辑宠物基本信息
- `CalendarView(preselectedPetId:)`：宠物专属日历
- `PetPottyLogView`：排泄历史
- `SitterCardPreviewSheet`：寄养名片（可分享）
- `WeeklyReportSheet`（欧哈纳电台）：周报卡片
- `WalkSummarySheet`：遛狗结算看板

**删除防呆**：输入宠物名字才能确认删除

### 4.6 PetBasicInfoDetailView（宠物基础信息详情）

- 完整展示宠物所有属性（证件号、过敏原、兽医联系方式等）
- 出生地（国家 + 城市）
- 血统/父母信息
- 备注

### 4.7 HumanDetailView（家庭成员详情）

**顶部 Hero**：头像、姓名、角色、生日、血型

**功能模块**：
- 今日提醒列表（筛选该成员相关 pending Reminder）
- 完成/跳过提醒操作（触觉反馈）
- 添加打卡提醒（循环/单次）
- 健康数据（HealthKit 步数图表，可选）
- 备注
- 删除成员

**Sheets**：
- `ArkCrewIDCardView`：身份证卡（翻面展示）

### 4.8 PlantDetailView（植物详情）

- 名称、品种、位置
- 浇水状态（距上次浇水天数 + 进度条）
- 施肥状态
- 快捷浇水 / 施肥按钮（更新 lastWateredDate）
- 编辑 / 删除

### 4.9 CalendarView（岛屿任务日历）

- **双视图模式**：月视图 + 列表视图（`scheduleView`）
- **宠物过滤**：顶部横向宠物头像选择器，点击过滤该宠物的事件
- **跳转到今天**：支持外部传入 `jumpToToday` 参数
- **事件分组**：按日期分组的事件列表
- **操作**：点击事件查看详情 / 长按删除
- **添加事件**：`AddEventView` Sheet

**AddEventView（添加事件）**：
- 事件标题、类型选择（所有 EventType）
- 时间：`OhanaTimeCard` 组件（DatePicker + 全天开关）
- 有效期提醒：提前 N 天
- 循环规则：天数 + 结束日期
- 关联生命体
- 自动创建 Reminder + 本地通知

### 4.10 CrewRosterOverlay（岛民大厅）

- 所有人类和宠物的 ID 卡片网格
- 搜索功能
- 快速跳转详情页
- 创建新成员入口

### 4.11 SettingsView（设置）

**章节**：
- **账户**：Sign in with Apple 状态、显示名、头像
- **家庭共享**：Household 创建/加入、CloudKit 共享（`CloudSharingView`）
- **昵称**：打卡时显示的名字
- **语言**：中文 / English（`@AppStorage("appLanguage")`）
- **通知权限**：检查并跳转系统设置
- **关于**：版本号、联系开发者、App Store 评分链接（id6742117937）、隐私政策
- **数据**：导出数据（预留）、危险区

### 4.12 DashboardManageView（卡片管理）

- 拖拽排序主页 Dashboard 卡片
- 开关显示/隐藏各卡片
- 预览卡片的 icon + 描述

### 4.13 特色功能页面

#### PottyOverviewView（噗噗电台）
- 渐变背景（深紫色）
- 7 天堆叠条形图（按 PottyType 分类着色）
- 白卡统计：30 天总计 / 分类占比 / 最近记录列表

#### WalkSummarySheet（遛狗结算看板）
- 距离、时长、速度数据
- 地图路线截图（MKMapSnapshotter）
- 起点/终点标记（绿色/红色圆点）
- 路线轨迹折线
- 分享功能

#### WeeklyReportCard（欧哈纳电台周报）
- 本周遛狗次数、总距离
- 本周排泄统计（分类）
- 本周护理完成情况
- 本周花费

#### PetImmunityDashboard（免疫仪表板）
- 下次疫苗日期（环形进度条）
- 下次体外驱虫、体内驱虫
- 下次体检时间
- 添加记录快捷入口

#### PetWeightTrackerView（体重追踪）
- 折线图（按时间维度：1周/1月/3月/全部）
- 最高/最低/平均体重
- 添加体重记录
- BMI 参考（按品种体型）

#### PetExpenseView（消费账本）
- 月度汇总柱状图
- 分类饼图（食物/医疗/美容/玩具等）
- 明细列表（按日期排序）
- 添加/删除记录

#### PetFoodInventoryView（余粮管家）
- 3D 水瓶式余粮可视化
- 剩余克数 + 可吃天数
- 断粮倒计时
- 历史购买记录
- 修改每日喂食量

#### PetDocumentListView（证件管理）
- 证件卡片列表（护照/疫苗本/保险等）
- 到期日期高亮（红色警告 / 橙色预警）
- 提醒设置（自动创建 Reminder）
- 添加/编辑/删除证件

#### PetHealthLogListView（健康日志）
- 按类型筛选
- 按日期排序的时间轴列表
- 花费统计
- 添加/删除

#### HygieneDashboardCard（护理仪表板卡）
- 各护理项目上次时间
- 彩色进度条显示是否超期（绿/黄/红）
- 建议下次护理日期
- 一键创建护理事件（带循环提醒）

#### MilestoneTimelineView（里程碑时间轴）
- 垂直时间轴布局
- 每个里程碑：日期 + Emoji + 标题 + 备注
- 自动生成的纪念日（100天/365天/500天等）
- 添加/删除里程碑

#### AchievementWallView（成就墙）
- 徽章网格（已解锁 / 未解锁灰色）
- 已解锁徽章的解锁条件说明
- 当前实现：
  - "钢铁肠胃"：连续 7 天每天有 perfectPoop 记录
  - （更多徽章预留）

#### PetSitterCardView / SitterCardPreviewSheet（寄养名片）
- 宠物基本信息一页纸
- 联系方式、过敏原、注意事项
- 支持截图分享
- 兽医联系方式一键拨打

#### CoconutDropsView（椰子盲盒）
- 随机生成宠物养育小贴士
- 动画效果：椰子掉落
- 分享功能

#### ArkCrewIDCardView（岛民身份证）
- 正面：头像/Emoji + 基本信息（名字/年龄/品种）
- 背面（翻转动画）：Bento 组件系统
  - 可拖拽排序的 6 个信息组件（体重/饮食/排泄/遛狗/证件/芯片）
  - 每个组件支持 Small / Wide 两种尺寸
  - UserDefaults 持久化布局
- **CoreMotion 视差效果**：陀螺仪驱动的视角倾斜（20fps 节流）

---

## 五、表单与向导

### 5.1 AddPetWizardView（宠物添加向导）

多步骤向导（7 步）：
1. **基本信息**：名字、物种（狗/猫/兔子/其他）
2. **品种选择**：`BreedPickerView`（内置数百品种数据库）
3. **照片/Emoji**：头像选择
4. **生日 & 到家日**：日期选择
5. **性别 & 绝育**
6. **主题色**：颜色选择（`ColorThemeMapper` 自动推荐）
7. **确认页**：汇总所有信息

**自动触发**（完成后）：
- 创建生日事件 + Reminder
- 创建到家纪念日事件 + Reminder
- 创建 100/365/500/730/1000/1095 天里程碑纪念日事件

### 5.2 AddHumanWizardView（成员添加向导）

多步骤向导：
1. 姓名 + Emoji/照片
2. 生日（可选）
3. 血型
4. 角色（主人/编辑/查看）
5. 确认

### 5.3 AddPetView（快速添加宠物）
轻量版表单，适合快速录入基本信息。

### 5.4 EditPetSheet（编辑宠物）
全字段编辑 Sheet，支持所有宠物属性修改。

### 5.5 AddEventView（添加事件）
- 事件标题、类型（Picker）
- 时间（OhanaTimeCard 组件）
- 全天/定时开关
- 有效期提醒（提前 N 天）
- 循环规则
- 关联宠物/成员
- 备注

### 5.6 AddDocumentView（添加证件）
- 证件类型选择
- 标题、颁发机构、证件号
- 颁发日期、到期日期
- 到期提醒开关（自动创建 Reminder）
- 后续跟进备注（创建 follow-up Reminder）

### 5.7 AddWeightView（添加体重）
- 数字键盘输入
- 单位（kg/lb）
- 日期选择
- 历史趋势提示

### 5.8 AddHealthLogView（添加健康日志）
- 类型（8种）
- 日期、备注、兽医名称、花费

---

## 六、系统服务层

### 6.1 PetWalkingManager（遛狗管理器）

`@Observable` 单例，功能：
- 开始/暂停/恢复/停止遛狗
- 实时 GPS 坐标收集（LocationManager 委托）
- 距离计算（CLLocation.distance 累加）
- **Live Activity**：遛狗动态岛（PetWalkingAttributes，ActivityKit）
  - 显示：宠物名、已走距离、时长
  - 暂停/停止按钮（Button Intent）
- 遛狗结束时：
  - 生成路线 MKMapSnapshotter 截图
  - 写入 PetWalkLog
  - 存储 routeLocationsData（CLLocationCoordinate2D 编码）

### 6.2 LocationManager（位置管理器）

`@Observable` 单例，功能：
- `CLLocationManager` 封装
- 请求 "When In Use" 权限
- 暂停/恢复追踪
- 权限未确定时标记 `pendingStart`，授权后自动开始

### 6.3 NotificationManager（通知管理器）

单例，功能：
- 请求通知权限
- 锁屏操作按钮注册：**完成 ✅ / 跳过 ⏭️ / 明天再说 🕐**（3个 UNNotificationAction）
- 调度单条 Reminder 本地通知（日历触发，非重复）
- 取消通知
- 通知响应处理（`userInfo["reminderCreatedAt"]` 查找对应 Reminder）
  - 完成：`statusEnum = .completed`
  - 跳过：`statusEnum = .skipped`
  - 延后：`statusEnum = .snoozed`，创建次日新 Reminder
- `compensate(reminders:)`：App 启动时补偿遗漏的通知

### 6.4 AuthManager（认证管理器）

`@Observable` 单例，功能：
- Sign in with Apple（ASAuthorizationController）
- Keychain 存储：Apple User ID、昵称、邮箱
- App 启动时检查 credential state（已注销/未找到则清除登录状态）
- 提供 `signOut()` 方法

### 6.5 AchievementManager

`ObservableObject`，功能：
- 异步计算成就徽章（不阻塞主线程）
- 当前成就："钢铁肠胃"（连续7天每天 perfectPoop）
- 输入：Pet 数据快照；输出：已解锁徽章数组

### 6.6 HouseholdSyncManager

`@Observable`，CloudKit 同步功能：
- `push(pet:)`：将宠物数据写入 CloudKit 私有数据库
- `pull(modelContext:)`：从 CloudKit 共享数据库拉取宠物数据
- `delete(pet:)`：删除 CloudKit 记录
- `upsert(record:into:)`：合并/更新本地数据
- **当前状态**：`cloudKitDatabase: .none`（需升级付费开发者账号）

### 6.7 HealthKitManager

可选健康数据接入：
- 请求步数读取权限
- 查询 HKQuantityTypeIdentifier.stepCount
- 用于 HumanDetailView 健康数据展示

### 6.8 ArkLogger（日志封装）

- 主 App：`ArkLogger.debug(message, category:)` — Debug 构建打印，Release 自动静默
- 共享 Model 文件（Widget 也编译）：`#if DEBUG print() #endif`
- `os.log` Logger 实例按 category 分类（general/cloudKit/sync/notify/walk/model）

---

## 七、Siri 快捷指令集成

### 7.1 已注册的 App Intents

| Intent | 标题 | 功能 | Siri 唤醒词 |
|--------|------|------|------------|
| `LogPetPottyIntent` | 记录宠物排泄 | 写入 PetPottyLog | "用方舟便便打卡" |
| `CompletePetFeedingIntent` | 喂饭打卡 | 写入喂饭记录 | "用方舟喂饭打卡" |
| `CleanLitterBoxIntent` | 铲猫砂打卡 | 写入 PottyLog | "用方舟铲猫砂" |
| `LogHygieneIntent` | 护理打卡 | 写入 PetHygieneLog | "用方舟护理打卡" |

所有 Intent：
- `openAppWhenRun: false`（后台执行）
- 通过 `SharedModelContainer` 直接读写数据库
- 返回 `ProvidesDialog`（Siri 语音确认）

### 7.2 NFC 触发

`CleanLitterBoxIntent` / `LogHygieneIntent` 设计支持 NFC 贴纸碰触触发（通过 iOS 快捷指令 NFC 标签动作绑定）。

---

## 八、深度链接（Deep Links）

**Scheme**：`ark://`

| URL | 功能 |
|-----|------|
| `ark://log-potty?petId={UUID}` | 快速记录排泄 |
| `ark://log-food?petId={UUID}` | 快速喂食打卡 |

实现：`ArkDeepLinkRouter`（单例），通过 `onOpenURL` 接收并路由。

---

## 九、Widget（ArkWidget）

**当前状态**：框架搭建完成，内容尚为占位符（显示时间和 favoriteEmoji）。

**技术基础**：
- `AppIntentTimelineProvider`
- `AppIntentConfiguration`
- 每小时刷新一次（5条 entries）
- 通过 `SharedModelContainer` 可读取主 App 数据库

**规划功能**：
- 今日提醒 Widget
- 宠物状态 Widget
- 遛狗快捷 Widget

---

## 十、设计系统（OhanaDesignSystem）

**文件**：`Views/OhanaDesignSystem.swift` + `Views/ArkBackgroundView.swift`

### 10.1 全局颜色

```swift
// ArkBackgroundView.swift Color 扩展
Color.arkCoral      // 珊瑚红 #FF5E3A（旧主色，部分组件保留）
Color.arkOrange     // 橙色强调
Color.arkPeachPink  // 桃粉辅助
Color.arkInk        // 深墨色文字
Color.arkCardDark   // 暗色卡片背景
Color.arkHotPink    // 亮粉强调
Color.arkMint       // 薄荷绿
Color.arkCyan       // 亮青

// v3.2.0 新增背景色（直接用 hex string）
"#e0c3fc"  // 薰衣草紫（背景渐变起点）
"#8ec5fc"  // 天空蓝（背景渐变中点）
"#f5d0c5"  // 蜜桃粉（背景渐变终点）
```

### 10.2 全局背景（ArkBackgroundView）

**文件**：`Views/ArkBackgroundView.swift`

v3.2.0 全面重写，三层叠加：
```
层1（底层）：LinearGradient 135°
    紫 #e0c3fc @ 0% → 蓝 #8ec5fc @ 50% → 粉 #f5d0c5 @ 100%

层2（中层）：NoiseTextureView
    200×200 UIImage tile（CGContext 随机噪点预渲染）
    opacity: 0.025 + blendMode: .overlay
    磨砂质感，不抢眼
```

### 10.3 卡片修饰器

```swift
// OhanaDesignSystem.swift ViewModifier
.neoWhiteCard(cornerRadius: 32)  // 纯白大圆角卡片 + 轻阴影
.neoDarkCard()                    // 深色半透明（arkCardDark）
.neoPinkCard()                    // 粉色渐变卡片
.neoOrangeCard()                  // 橙色渐变卡片
.neoBlueCard()                    // 蓝色渐变卡片

// v3.2.0 主力毛玻璃卡片（OhanaGlassModifier）
.ohanaGlassStyle(cornerRadius: 32, fillOpacity: 0.12)
// 实现：
//   层1: .ultraThinMaterial 背景（跟随系统，渗透背景色）
//   层2: LinearGradient 白色内发光（0.20 → 0.04 → 0.10）
//   层3: strokeBorder 白色描边（opacity 0.55, lineWidth 1）
//   阴影: black opacity 0.05, blur 12, y+4
```

### 10.4 按钮修饰器

```swift
.capsuleButton()           // 全宽胶囊主按钮（白色背景，深色文字）
.neonCapsuleButton()       // 荧光黄胶囊按钮（#E0FF00 + 深色文字）
.capsuleButtonDark()       // 深色胶囊按钮
```

### 10.5 字体修饰器

```swift
.heroTitleStyle()          // 大字报标题（全小写，.heavy 极粗）
.giantMetricStyle()        // 巨型数字（60–80pt .heavy）
.arkMetric(size: 80)       // 自定义大小圆润数字（design: .rounded）
.arkMetricSM(size: 40)     // 小号圆润数字
```

### 10.6 通用 UI 组件

```swift
OhanaSheetWrapper          // 标准 Sheet 容器（topBar 圆角 + X 关闭按钮）
OhanaTimeCard              // 时间表单区域容器
OhanaTimeRow               // DatePicker 表单行
OhanaDashedDivider         // 虚线分割线（白色，opacity 0.25）
DashedDivider              // 同上（别名）
CapsuleBarShape            // 圆角柱状图图形（柱子底部圆角保持方形）
```

### 10.7 IslandMoodWeatherView（岛屿气候系统）

根据宠物状态动态生成粒子特效：
- `.calm`：无粒子，停止 Timer（零 CPU）
- `.breezy`：花瓣/星光粒子飘移（✨🌸🌺🌼）
- `.storm`：闪电/雨滴粒子下落（⚡️🌩️💧）

**判断逻辑**（基于宠物状态）：
- 有紧急食物不足 → `.storm`
- 有证件即将到期 → `.storm`
- 今日有已完成提醒 → `.breezy`
- 否则 → `.calm`

---

## 十一、已完成优化

### v3.2.0 变更（最新）

| 变更项 | 文件 | 说明 |
|--------|------|------|
| 毛玻璃透明度提升 | `OhanaDesignSystem.swift` | 白色内发光从 0.45→0.20，减少白色遮蔽，背景色通过 ultraThinMaterial 渗透 |
| 毛玻璃透明度提升 | `WalkTrackingCard.swift` | 同步降低硬编码白色填充（0.45→0.20, 0.25→0.10）|
| 卡片翻转交互 | `CritterDeckCarousel.swift` | `onTap` 改为 `onDetail`，点击卡片不再触发底部弹窗，改为卡片自身 3D 翻转 |
| NavigationLink 跳转 | `OverviewView.swift` | 移除 `ExpandablePetPanel`，改用 `.navigationDestination(item:)` 跳转详情页；`selectedPet/selectedHuman` 驱动导航 |
| 遛狗地图真实轨迹 | `WalkTrackingCard.swift` | idle 时展示最近历史截图（`PetWalkLog.mapSnapshotData`）；运动中每 10 个新 GPS 点重新生成路线快照 |
| 背景全面更新 | `ArkBackgroundView.swift` | 135° 三色渐变（紫/蓝/粉）替换旧珊瑚橘渐变 |
| 详情页卡片适配 | `PetDetailView.swift` | Hero 卡改为 `ohanaGlassStyle`，文字色改为语义色适配浅色背景 |

### v3.1.0 变更

| 优化项 | 说明 |
|--------|------|
| 断粮算法 | `actualDailyConsumptionGrams` 结合最近 7 天 `PetFoodRecord` 趋势动态修正 |
| 体重波动预警 | `IslandMoodWeatherView` 检测 30 天内 >10% 波动，强制 `.storm` + `vetInsightPetNames` |
| 通知补偿 | `compensate()` 标记过期 `.pending` 为 `.missed`，标题写入 `AppStorage("missedReminderTitles")` |
| 容器容错 | SQLite 损坏时：备份旧文件 → 重建干净 Container → 最终降级内存模式（三级策略） |
| 低电量降级 | `MotionManager.start()` 在 `isLowPowerModeEnabled` 时跳过陀螺仪启动 |
| 异步头像 | `AsyncAvatarImage`：后台解码 + NSCache LRU（60 MB / 64 条） |
| 卡片触觉 | `CritterDeckCarousel` 切换时 `.light` 触觉反馈 |
| 品牌重命名 | App 名称从 Ark → **Ohana**（Info.plist 权限描述已更新） |

## 十二、Backlog 待办

### 必须完成（需外部条件）
- **CloudKit 共享**：`cloudKitDatabase: .none` → `.automatic`，需升级付费 Apple 开发者账号，`HouseholdSyncManager` 已完整实现
- **Xcode Target 重命名**：在 Xcode GUI 中将 Display Name 从 "Ark" 改为 "Ohana"（`project.pbxproj` 不宜直接编辑）

### 功能扩展
- **Widget 实现**：当前为占位 UI（时间 + favoriteEmoji），数据基础设施已就绪，需实现今日提醒 / 宠物状态 / 遛狗快捷三种 Widget
- **PetDetailView 延迟 @Query**：按卡片类型延迟加载子记录，减少进入页面时的初始查询压力
- **子记录分页（Pagination）**：应对 expenseLogs / pottyLogs 多年后的超大数据量
- **首页简报 missedReminderTitles**：读取 `AppStorage("missedReminderTitles")` 在 `ArkBriefingCard` 中展示"遗漏提醒"卡片
- **更多成就勋章**：当前仅"钢铁肠胃"，补充遛狗里程碑 / 体重稳定 / 连续打卡系列
- **Dashboard 占位卡片**：`medication` / `hydration` / `quickLog` 已定义枚举，需实现 UI

### 数据安全
- **数据导出 JSON / CSV**：防止 SwiftData 版本迁移失败导致用户数据丢失
- **HealthKit 接入**：步数读取 → HumanDetailView 健康数据卡

### 国际化
- **多语言**：`@AppStorage("appLanguage")` 已存在，需提取 `Localizable.strings`，支持 zh / en

---

## 十二、文件结构总览

```
Ark/
├── ArkApp.swift                    # 应用入口，ModelContainer 初始化
├── ContentView.swift               # 根容器
├── Models/
│   ├── Pet.swift                   # 宠物模型（最复杂，含余粮/人类年龄计算）
│   ├── Human.swift                 # 人类成员模型
│   ├── Plant.swift                 # 植物模型
│   ├── Household.swift             # 家庭模型（CloudKit 根节点）
│   ├── Event.swift                 # 事件模型
│   ├── Reminder.swift              # 提醒模型（含 ReminderStatus 枚举）
│   ├── PetPottyLog.swift           # 排泄记录
│   ├── PetWalkLog.swift            # 遛狗记录
│   ├── PetHygieneLog.swift         # 护理记录
│   ├── PetWeightLog.swift          # 体重记录
│   ├── PetHealthLog.swift          # 健康日志
│   ├── PetDocument.swift           # 证件
│   ├── PetExpenseLog.swift         # 消费账本
│   ├── PetFoodRecord.swift         # 饮食记录
│   ├── PetMilestone.swift          # 里程碑
│   ├── WaterLog.swift              # 饮水日志
│   ├── PetBreeds.swift             # 品种数据库
│   ├── EventTypes.swift            # 事件类型常量
│   ├── DashboardCard.swift         # 首页卡片系统
│   ├── SharedModelContainer.swift  # App Group 共享容器
│   ├── AuthManager.swift           # Apple 登录
│   ├── NotificationManager.swift   # 本地通知
│   ├── LocationManager.swift       # GPS 位置
│   ├── PetWalkingManager.swift     # 遛狗管理
│   ├── PetWalkingAttributes.swift  # Live Activity 属性
│   ├── HouseholdSyncManager.swift  # CloudKit 同步
│   ├── AchievementManager.swift    # 成就系统
│   ├── HealthKitManager.swift      # 健康数据
│   ├── PetPDFExporter.swift        # PDF 导出
│   └── ArkAppIntents.swift         # Siri 快捷指令
├── Views/
│   ├── ArkBackgroundView.swift     # 全局背景 + 卡片修饰器
│   ├── OhanaDesignSystem.swift     # 设计系统组件
│   ├── OverviewView.swift          # 主页（最重要视图）
│   ├── RootView.swift              # 路由根视图
│   ├── OnboardingView.swift        # 引导页
│   ├── SettingsView.swift          # 设置页
│   ├── CalendarView.swift          # 日历视图
│   ├── PetHomeView.swift           # 宠物主页（备用）
│   ├── CloudSharingView.swift      # iCloud 共享
│   ├── ArkEmptyStateView.swift     # 空状态视图
│   ├── Home/
│   │   ├── CritterDeckCarousel.swift   # 3D 卡牌转盘
│   │   ├── ExpandableCreaturePanel.swift # 原地展开面板
│   │   ├── FloatingDock.swift          # 浮动 FAB
│   │   ├── HibiscusStreakView.swift    # 扶桑花连胜
│   │   ├── IslandMoodWeatherView.swift # 岛屿气候粒子
│   │   ├── CrewDashboard.swift         # 成员卡片
│   │   ├── CrewRosterOverlay.swift     # 岛民大厅
│   │   ├── CritterQuickPanel.swift     # 快速底部面板
│   │   ├── BroadcastToast.swift        # 家庭广播 Toast
│   │   ├── CrewAvatarWithEmotion.swift # 头像情绪组件
│   │   └── BridgeSection.swift         # 桥梁分节视图
│   ├── Details/
│   │   ├── PetDetailView.swift         # 宠物详情（核心）
│   │   ├── HumanDetailView.swift       # 成员详情
│   │   ├── PlantDetailView.swift       # 植物详情
│   │   ├── PetBasicInfoDetailView.swift
│   │   ├── PottyOverviewView.swift     # 噗噗电台
│   │   ├── WalkSummarySheet.swift      # 遛狗结算
│   │   ├── WeeklyReportCard.swift      # 欧哈纳电台周报
│   │   ├── PetWeightTrackerView.swift  # 体重追踪
│   │   ├── PetExpenseView.swift        # 消费账本
│   │   ├── PetFoodInventoryView.swift  # 余粮管家
│   │   ├── PetDocumentListView.swift   # 证件管理
│   │   ├── PetHealthLogListView.swift  # 健康日志
│   │   ├── PetImmunityDashboard.swift  # 免疫仪表板
│   │   ├── HygieneDashboardCard.swift  # 护理仪表板
│   │   ├── MilestoneTimelineView.swift # 里程碑时间轴
│   │   ├── AchievementWallView.swift   # 成就墙
│   │   ├── PetSitterCardView.swift     # 寄养名片
│   │   ├── SitterCardPreviewSheet.swift
│   │   ├── PetPottyLogView.swift       # 排泄历史
│   │   ├── EventDetailView.swift       # 事件详情
│   │   └── CoconutDropsView.swift      # 椰子盲盒
│   ├── Forms/
│   │   ├── AddPetWizardView.swift      # 宠物添加向导（7步）
│   │   ├── AddHumanWizardView.swift    # 成员添加向导
│   │   ├── AddPetView.swift            # 快速添加宠物
│   │   ├── AddHumanView.swift          # 快速添加成员
│   │   ├── AddPlantView.swift          # 添加植物
│   │   ├── EditPetSheet.swift          # 编辑宠物
│   │   ├── AddEventView.swift          # 添加事件
│   │   ├── AddDocumentView.swift       # 添加证件
│   │   ├── AddWeightView.swift         # 添加体重
│   │   ├── AddHealthLogView.swift      # 添加健康日志
│   │   ├── AddEntityView.swift         # 选择添加类型
│   │   └── ImagePickerHelpers.swift    # 图片选择工具
│   ├── Dashboard/
│   │   ├── DashboardCardViews.swift    # 所有 Dashboard 卡片实现
│   │   └── DashboardManageView.swift   # 卡片管理页
│   ├── Components/
│   │   ├── ArkCrewIDCardView.swift     # 岛民 ID 卡
│   │   ├── UnifiedCheckInGrid.swift    # 统一打卡网格
│   │   ├── OhanaTimeCard.swift         # 时间表单组件
│   │   └── BirthplacePicker.swift      # 出生地选择器
│   ├── Settings/
│   │   └── (设置相关子视图)
│   └── Auth/
│       └── LoginView.swift             # Apple 登录页
├── Services/
│   └── ArkDeepLinkRouter.swift         # 深度链接路由
└── Utilities/
    ├── ArkLogger.swift                 # 统一日志
    ├── CalendarEventSyncHelper.swift   # 日历同步工具
    ├── ImageCompressor.swift           # 图片压缩
    ├── KeychainHelper.swift            # Keychain 读写
    └── ColorThemeMapper.swift          # 主题色自动映射

ArkWidget/
├── ArkWidget.swift          # Widget 主体（占位）
├── ArkWidgetBundle.swift    # Widget Bundle
├── ArkWidgetControl.swift   # Control Widget
└── AppIntent.swift          # Widget 配置 Intent
```

---

## 十三、核心交互流程

### 13.1 遛狗完整流程

```
PetDetailView → neoWalkCard
→ "开始巡岛" 按钮
→ PetWalkingManager.start(pet:)
  → LocationManager.startTracking()
  → ActivityKit.request(PetWalkingAttributes) → 动态岛
→ 实时距离/时长更新
→ "停止" 按钮
  → LocationManager.stopTracking()
  → MKMapSnapshotter.start() → 截图
  → PetWalkLog 写入 SwiftData
  → Live Activity 结束
→ WalkSummarySheet 自动弹出
```

### 13.2 提醒完整流程

```
AddEventView → 创建 Event
→ 创建 Reminder（status: .pending）
→ NotificationManager.schedule(reminder)
  → UNCalendarNotificationTrigger
→ 通知触发（锁屏）
  → 用户点击"完成/跳过/明天再说"
  → UNUserNotificationCenter delegate
  → reminder.statusEnum = .completed/.skipped/.snoozed
  → 若 .snoozed：创建次日新 Reminder + 调度通知
  → 若循环事件：scheduleNextIfRecurring()
```

### 13.3 Siri 触发流程

```
用户说："用方舟便便打卡"
→ LogPetPottyIntent.perform()
→ SharedModelContainer.make(readOnly: false)
→ 查找匹配宠物
→ PetPottyLog 写入
→ 返回语音确认："已为 xxx 记录完美便便打卡 💩"
```

---

## 十四、数据安全与隐私

- **本地优先**：所有数据存储在设备 SwiftData（SQLite）
- **Apple 认证**：仅使用 Sign in with Apple，不收集密码
- **Keychain**：Apple User ID、姓名、邮箱存储在系统 Keychain
- **iCloud**：当前 `.none`，数据不同步到 iCloud（待付费账号解锁）
- **照片权限**：仅在用户主动选择头像时请求
- **位置权限**：仅在遛狗时请求 "When In Use"
- **通知权限**：在用户创建第一个提醒时请求
- **HealthKit**：可选，仅读取步数
- **Release 日志**：所有 `print()` 在 Release 构建自动禁用

---

*文档生成时间：2026-02 | 代码版本：ArkSchemaV3*
