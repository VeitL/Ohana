# Ohana App 开发进度

> 最后更新: 2026-03-09 | Schema: ArkSchemaV19 | Phase 1-76 + TASK 1-7 + FIX 1-8 + UIUX 1-6 + BUG FIX 11项 + 深度修复 P1-P10 全部完成

## App 定位

**Ohana（欧哈纳）** — 家庭生命体综合管理 iOS App
- 核心理念："Ohana means family. Nobody gets left behind or forgotten."
- 宠物、人类成员、植物统称为"家人（Critters）"
- 热带岛屿氛围的养成游戏化体验，多巴胺式正向反馈
- 本地优先，无需账号，SwiftData 存储
- 技术栈：SwiftUI + SwiftData + Swift Charts, iOS 17+, Swift 6
- 模拟器：iPhone 17 Pro (iOS 26.2)

---

## 整体进度概览

| 模块 | 状态 | 说明 |
|------|------|------|
| 核心架构 | ✅ 完成 | ArkSchemaV15（V15新增Human.themeColorHex），21模型，V1→V15完整迁移链 |
| 宠物模块 | ✅ 完成 | 健康/遛狗/饮食/护理/证件/花费/里程碑/成就/关系 |
| 人类成员模块 | ✅ 完成 | 体重/国籍城市/运动卡/HealthKit/心愿单 |
| 植物模块 | ✅ 基础 | 浇水/施肥追踪（无高级功能） |
| 首页系统 | ✅ 完成 | Wallet 堆叠卡牌/Quick Access/Island Stats/天气粒子/记忆碎片 |
| 日历/提醒 | ✅ 完成 | 月视图+列表/滑动操作/循环事件/本地通知 |
| 椰子经济 | ✅ 完成 | QuestManager/暴击引擎/双边分润/成员筛选/财富中心 |
| 绿洲系统 | 🔄 骨架 | 生命树 + 被动收益，功能待深化 |
| 设计系统 | ✅ 完成 | Go UI 18 色/毛玻璃卡片/FloatingDockNav |
| 全岛仪表盘 | ✅ 完成 | 体重/花费/探索/财富 4 个沉浸式 Dashboard |
| Widget | ⬜ 待做 | 基础设施就绪，缺 Widget Target |
| CloudKit | ⬜ 待做 | 需付费开发者账号 |

---

## 已完成 Phase 总览

共完成 **70 个 Phase**，以下按功能域归类：

### 基础架构 & 数据模型（Phase 1, 16, 19-20, 48-49）

| Phase | 日期 | 内容 |
|-------|------|------|
| 1 | — | SwiftData 模型（Pet/Human/Plant/Event/Reminder + 10 种日志）、SharedModelContainer、设计系统、App 入口 |
| 16 | 03-04 | VersionedSchema V1 + ArkMigrationPlan；PetDetailView 5 个子卡片拆分为独立文件 |
| 19 | 03-04 | 游戏化粘性：IslandProsperityManager + StreakManager + DailyQuestsCard；ArkSchemaV2（Pet.currentStreak） |
| 20 | 03-04 | Island EXP（ArkSchemaV3 Household.totalProsperity）；记忆碎片 MemoryDropCard；植物生态联动；成就实体贴纸 |
| 48 | 03-05 | 双轨制粮食管理（ArkSchemaV10 Pet 佛系/精准模式字段） |
| 49 | 03-05 | 家庭协作（ArkSchemaV11 coconutBalance + executorId）；设备身份绑定；SynergyEngine |

### 核心 UI（Phase 2-5, 6-14）

| Phase | 日期 | 内容 |
|-------|------|------|
| 2 | — | OnboardingView / OverviewView / CritterDeckCarousel / ArkCrewIDCardView / PetDetailView / HumanDetailView |
| 3 | — | CalendarView / SettingsView / 7 个表单向导 / CrewRosterOverlay |
| 4 | — | NotificationManager / LocationManager / PetWalkingManager / WalkTrackingCard |
| 5 | — | IslandMoodWeatherView / CatCareStationCard / WeeklyReportCard / PottyOverviewView / WalkSummarySheet |
| 6 | 03-03 | Go UI 风格全面重构（18 色色板 + 8 个核心文件重写） |
| 7 | — | 卡片叠堆动画 / 深度视差 / 拖拽倾斜 / 植物一键浇水 / 体重折线图 |
| 8 | — | 宠物功能全面完善（喂食卡/免疫卡/健康打卡/体重卡/里程碑/ID 卡背面） |
| 9 | — | 品种数据库 / AddPetWizardView 12 步重写 / FloatingDockNav / BentoStatCard |
| 10-14 | — | 5 轮 UI/UX 精修（头像裁剪/Quick Access/Island Stats/SmartTodayCard/SwipeableEventRow 等） |

### 产品体验（Phase 15, 17-18, 26-32）

| Phase | 日期 | 内容 |
|-------|------|------|
| 15 | 03-04 | 成就体系 7 枚徽章 + 打卡爽感 + celebrate 粒子 |
| 17 | 03-04 | IslandMood 补充 celebrate 触发；3 枚即时型成就；SitterCardPreviewSheet；空状态引导 |
| 18 | 03-04 | WalkTrackingCard 状态合并（单一数据源 PetWalkingManager） |
| 26 | 03-04 | PetDetailView HUD 瀑布流仪表盘重构（8 层结构 + UnifiedTimeline） |
| 27 | 03-04 | T1-T12 UI 重构（ArkSchemaV7 PetCareLog + PetCareTrackingCard） |
| 28 | 03-04 | 遛狗气泡可拖动 + 结束翻转卡 + PetChartDashboard + PetFoodManagementView |
| 29 | 03-04 | 路由重构（绿洲 Tab）+ SmartTodayCard 里程碑金色闪卡 |
| 30 | 03-04 | B1-B8 修复（气泡拖动/翻转/免疫卡/护理卡/Island Stats/粮食入口/椰子记录/里程碑识别） |
| 31 | 03-04 | C 系列改进（竖向穿透/HeroRow 加高/品种感知 HUD/护理打卡/气泡圆形/Streak 自动刷新） |
| 32 | 03-04 | 新手任务系统（QuestManager + WelcomeQuestBentoView + 暴击结算动画） |

### QA Sprint & Bug 修复（Phase 33-34, 37, 40, 42-46, 51, 56-57）

| Phase | 日期 | 内容 |
|-------|------|------|
| 33 | 03-04 | 架构审计 F1-F10（10 项关键修复） |
| 34 | 03-04 | U 系列 16 项 Bug 修复/功能增强 |
| 35 | 03-04 | U13/U14 人类体重+国籍+运动卡+HealthKit（ArkSchemaV8/V9） |
| 36 | 03-04 | ARCH4 人宠数据联动（步数达标/同甘共苦奖励 + 2 枚跨维度成就） |
| 37 | 03-04 | P0 修复 + UI 重构（PetHealthDetailView/CareTrackingDetailSheet/HygieneDetailSheet GO Club 风格） |
| 38 | 03-05 | cardBackView Bento Box 重构（BackBentoDashboard + 单击/长按分离 + 椰子浮字） |
| 39 | 03-05 | 全岛数据中枢 + 绿洲重构（OasisTreeManager）+ 日历 EventDetailSheet |
| 40 | 03-05 | QA Sprint 2（14 项：打卡双倍/遛狗状态/生命树死锁/Cross-Pet/防重复闭环） |
| 42 | 03-05 | QA Sprint 3（13 项修复） |
| 43 | 03-05 | UI 改进（PetDetailView 椰子胶囊 + AllPetsFoodOverviewSheet + 噗噗迁移） |
| 44 | 03-05 | task31 Quick Access Reminder 联动 + task10 喂食提醒选择器 + task34 噗噗沉浸式重构 |
| 45 | 03-05 | Sprint 4（长按防误删/级联清理/语义化文案/路由串线修复） |
| 46 | 03-05 | Sprint 4 收尾（miniHygieneChip 修复/遛狗椰子/Quick Access 残留清理/待办卡/QuickFeedSheet） |
| 51 | 03-05 | v6.7.0 重构后遗症全歼（11 项 Bug Fix） |
| 56 | 03-06 | 6 项修复（铲屎双倍/支付人选择器/体重小数点/护理弹窗/主题色互斥） |
| 57 | 03-07 | 9 项修复（循环事件/体重卡死/健康路由/猫咪平衡/背卡图表/体重下钻/荣誉榜排重） |

### 椰子经济 & 仪表盘（Phase 47, 50, 52-55）

| Phase | 日期 | 内容 |
|-------|------|------|
| 47 | 03-05 | IA 重构（BackBentoDashboard 生命体征/activeCritterId/固定人体工学布局） |
| 50 | 03-05 | 暴击引擎 + 生命树被动收益 |
| 52 | 03-05 | N1-N10 + 4 Hotfix（OnboardingView/GlobalCoconutButton/HealthKit Mock/成员筛选） |
| 53 | 03-05 | 全局椰子胶囊 + 快速打卡重构 + IslandWealthDashboard |
| 54 | 03-05 | 6 项增强（引导卡/Chart 修复/财富卡 UI/遛狗奖励/快速打卡导航/默认卡） |
| 55 | 03-05 | 椰子经济引擎重构（OhanaActionType + 双边分润 + 暴击引擎 + 全调用点替换） |

### 视觉 & 交互（Phase 58-70）

| Phase | 日期 | 内容 |
|-------|------|------|
| 58 | 03-07 | **宠物卡片杂志封面 + Apple Wallet 堆叠**（Editorial Cutout Design + WalletLayout） |
| 59 | 03-05 | 代码重构（LocationManager 后台定位 + QuestManager 原子化 + OverviewView 2968→1333 行拆分） |
| 60 | 03-05 | PetHealthDetailView 散点时间轴 + PetHygieneDetailView 轻量化 |
| 61 | 03-05 | 4 个全岛仪表盘（AddQuickActionSheet/IslandWealth/IslandWeight/IslandExpense） |
| 62 | 03-05 | 5 项修复（Stats 路由/navBar/图表/背面重构/成就贴纸） |
| 63 | 03-05 | 7 项（背面 Sparkline/QuickWeight DatePicker/财富聚合/图表颜色/椰子日志/花费动画） |
| 64 | 03-05 | 6 项（3D 层叠精调/智能副标题/双边日志拆分/财富 ViewModel） |
| 65 | 03-06 | 5 项（LocationManager 崩溃修复/Quick Access 完整重构 QACardType/护理弹窗/健康花费体重卡/glanceSubtitle） |
| 66 | 03-06 | 3 项（宠物复制防双击/Quick Access 接入/SpeciesCheckInGrid 回调冒泡） |
| 67 | 03-06 | 5 项（默认空卡片/防重复/护理 confirmationDialog/花费卡/正面升级） |
| 68 | 03-07 | 全局椰子按钮布局重构（废弃 GlobalCoconutButtonOverlay → 各页面原生注入） |
| 69 | 03-07 | 卡片背面 Read-Only Dashboard 重构（三区结构 + Sparkline + 待办 Banner） |
| 70 | 03-07 | Event.isActionableTask + IslandExplorationDashboard + toolbar 椰子按钮独立化 |
| 71 | 03-07 | **信用卡比例卡片 + Apple Wallet 3张 + P1功能4项**（详见下方） |
| 72 | 03-07 | **体验优化与 Bug 修复 6项**（详见下方） |
| 73 | 03-07 | **UX 重构 9 模块 + 经济系统扩展**（详见下方） |
| 74 | 03-07 | **终极体验打磨 6 项 + iOS 17 Vision 抜像集成**（详见下方） |
| 75 | 03-08 | **终极体验打磨 Phase 2 — 9 模块数据+UI+架构全面升级**（详见下方） |

#### Phase 71 详情

- **卡片改为信用卡比例**：`ArkCrewIDCardView` / `HumanIDCardView` 高度改为 `(width-48)/1.586`（85.6×53.98mm≈1.586:1），`WalletLayout.cardHeight(for:)` 动态计算；正面/背面内容字号全部压缩适配
- **Apple Wallet 首页最多3张**：`WalletLayout.maxVisible=3`，`peekOffset=32`；超出3张时底部显示「全部 N 张」胶囊按钮
- **AllCardsSheet**：全部成员列表，支持置顶（promoteCard）和跳转详情
- **里程碑全屏庆典**：`MilestoneCelebrationOverlay` + `MilestoneCheckModifier`，命中 100/365/500/1000 天时弹出全屏动画；`@AppStorage("celebratedMilestoneDays")` 防重复；挂载于 `OverviewView.milestoneCheck(pets:)`
- **椰子兑换商店**：`CoconutShopView`，10 件商品（特效/称号/加成），消耗椰子兑换，已兑换持久化（`@AppStorage("purchasedShopItems")`）
- **欧气扭蛋机**：`GachaView`，消耗 30🥥/次，4 档稀有度（普通55%/稀有30%/史诗12%/传说3%），历史记录最多24条
- **家庭悬赏榜**：`BountyBoardView` + `AddBountyTaskSheet`，JSON 存储于 `@AppStorage("bountyTasks")`，完成任务触发椰子转移
- 绿洲 Bento Grid 接入椰子商店/扭蛋机/悬赏榜三个真实入口

#### Phase 76 详情

- **模块1 剪贴板抠图捷径**：`AddPetWizardView.stepAvatar` 和 `AddHumanWizardView` 头像区域均新增「粘贴已抠主体」黄色胶囊按钮；读取 `UIPasteboard.general.image`，优先保存 PNG（保留透明通道），失败退回 JPEG；附带操作提示文字「相册长按人物 → 拷贝主体 → 回来粘贴」；`AddHumanWizardView` 同步添加 `pastePasteboardImage()` 方法
- **模块2 卡片正面排版修复**：`ArkCrewIDCardView.petFrontView` 右侧 VStack 底部加 `.padding(.bottom, 28)`；翻转提示 `arrow.triangle.2.circlepath` icon 从右下角改为左下角（与条形码同侧），彻底消除文字遮挡
- **模块3 人类卡片视觉统一**：`HumanIDCardView.humanFrontView` 完全重构为「杂志封面 Editorial Cutout」布局——左侧头像底部对齐（支持贴纸白边/emoji fallback），右侧显示相识天数（HStack firstTextBaseline）、大名字、角色胶囊、年龄胶囊、血型胶囊；翻转 icon 移至左下角；`humanThemeColor` 从 `notes` 字段解析；新增 `humanFrontPill/humanFrontPillScalable` helpers；与宠物卡片 100% 相同的圆角/阴影/底部 padding 规范
- **模块4b 猫咪 Quick Access 补全**：`QACardType.available("猫")` 加入 `.potty`（猫咪拉粑粑），完整列表：`.litter/.feed/.water/.potty/.play/.care/.health/.expense/.weight`
- **模块4c 人类专属 Quick Access**：`HumanIDCardView.humanBackView` 全面重构——顶部 QUICK ACCESS 标题+详情按钮，分隔线，`HumanQuickAccessGrid`（4 格：⚖️记录体重/💧喝水打卡/💸记一笔账/📝待办心愿）；底部紧凑 chip 行（年龄/血型/角色）；喝水打卡直接写入 `WaterLog`+`QuestManager`，体重跳 `GenericWeightEntrySheet`，待办跳 `HumanWishlistView`
- **模块5 AllCardsSheet 网格化**：`AllCardsSheet` 从简陋列表重构为 `LazyVGrid` 双列缩略卡；新建 `MiniFlipCard` 支持点击翻面（背面有「进入详情」青柠按钮+「置顶显示」按钮）；正面复刻杂志封面布局（头像大图+名字/品种）；当前顶牌显示「当前」标签；信用卡比例（cardWidth/1.586）；`CritterDeckCarousel.swift` 补加 `import SwiftData`

#### Phase 75 详情

- **模块1 全岛重名防护**：`AddPetWizardView`/`AddHumanWizardView`/`EditPetSheet` 三处加入 `isNameDuplicate` 计算属性（忽略大小写/首尾空格；EditPetSheet 排除自身原名）；`canProceed` 在 basicInfo 步骤阻止继续；保存时弹出 Alert「名字已被占用 🏠」
- **模块2 ImageCutoutPreviewSheet**：新建 `Views/Components/ImageCutoutPreviewSheet.swift`；裁剪后弹出 sheet 展示原图 vs Vision 抠图对比（棋盘格透明背景），用户点选确认；`AddPetWizardView` 和 `AddHumanWizardView` 均使用此 sheet 替代旧自动抠像逻辑
- **模块3a GenericWeightEntrySheet**：新建 `Views/Components/GenericWeightEntrySheet.swift`，支持 `.pet(Pet)` / `.human(Human)` 两种 Target，玻璃深色风格；`WeightHistoryView` 和 `HumanWeightHistoryView` 内嵌 addWeightSheet 全部替换
- **模块3b AddHumanWizard 头像**：Step1 新增 PhotosPicker 相册 + 相机头像选择，经 `ImageCutoutPreviewSheet` 确认后保存 `avatarImageData`
- **模块3c 猫咪 litter**：确认 `QACardType.available("猫")` 首位已为 `.litter`（Phase 73 已完成）
- **模块4a CoconutRulesSheet Bento 重构**：13 条收入 + 4 条支出规则每条为独立 Bento 卡片（emoji + 霓虹微光 RadialGradient + 奖励胶囊）；双列 `LazyVGrid`，stagger 入场动画
- **模块4b ArkCrewIDCardView 情感化排版**：天数行重构为 `HStack(firstTextBaseline)`（「✨已相伴 [28pt] 天」）；`humanAgeLabel(pet:humanAge:)` 新增宠物自然年龄前缀和性别分化称号（少女/少男、独立美女/稳重帅哥等共 8 档）
- **模块5b Human.shouldShowOnHome**：`Human` 新增 `shouldShowOnHome: Bool`（默认 false）；升级至 **ArkSchemaV13**（lightweight migration V12→V13）；`HumanDetailView` 新增「在首页卡堆显示」toggle 卡；`CritterDeckCarousel.allItems` 合并 shouldShowOnHome=true 的 Human（宠物在前）

#### Phase 74 详情

- **模块1 账本安全**：`CoconutLogEntry` 存储于 `QuestManager` 的 `UserDefaults`（非 SwiftData），`modelContext.delete(pet)` 不影响椒子账本；`resetPetLogs` 确认仅清理宝物私有数据（weightLogs/expenseLogs/healthLogs/hygieneLogs/walkLogs/pottyLogs/foodRecords/careLogs/Events），财务账本天然安全
- **模块2 QuickWeightSheet UI 重构**：移除黑色背景，整体背景改为 goDarkBlue + goPrimary 渐变；输入区改为 `.ultraThinMaterial` 玻璃卡片，字体升到 72pt .black.rounded + goLime 的 kg；日期选择器内嵌卡片
- **模块3 卡片正面 Polish**：`humanAgeLabel` 改用 `frontPillScalable`（`.minimumScaleFactor(0.5)` 独占一行）；删除旧翻转提示（HStack），改为绝对右下角 `arrow.triangle.2.circlepath` 图标（opacity 0.35）；将卡片 `.onTapGesture` 改为 `.simultaneousGesture(TapGesture())`，防止与父层 DragGesture 冲突
- **模块4 ImageCutoutService**：创建 `Utilities/ImageCutoutService.swift`，使用 iOS 17 `VNGenerateForegroundInstanceMaskRequest` 提取前景主体，逐像素应用 mask 输出透明底 PNG；集成到 `AddPetWizardView.cropImageItem` sheet 的 `onCrop` 回调，裁剪后异步抠像，成功则存透明 PNG，失败则 fallback 到原图 JPEG
- **模块5 毛色选择器渐变图案**：新增 `PetCoatPattern` 枚举（5 种：三花/銀渐层/珳璃/奶牛色/蓝白双色），每种定义 `AnyShapeStyle` 渐变（AngularGradient/RadialGradient/LinearGradient）；`colorSection` 新增 `patternItems` 参数，渐变圣水跟在纯色圣水后面；毛色开启图案，瞳色 `patternItems: []`
- **CritterDeckCarousel 间距微调**：`wheelSpacing` 从 `cardH*0.72`（押渋）改为固定 45pt；`wheelFrameHeight = cardH + wheelSpacing*2.2`；`wheelScale` max 提到 0.80，系数 0.12；`wheelOpacity` 系数 0.50；`wheelBrightness` 系数 0.22；背后卡片只露出一条细边进行滑动提示

#### Phase 73 详情

- **模块1 PetCardFrontView 重构**：移除悬浮动画（`isHovering` state + `.easeInOut repeatForever`）；天数标签合并为单行 `"✨ 已相伴 N 天"`；品种+性别+物种 emoji 合并为单个 frontPill；新增 `humanAgeLabel(_:)` 情感化文案（7段年龄区间，0岁婴儿~70+长者）；有照片时用多层白色 `.shadow(color:.white)` 叠出贴纸描边效果
- **模块2 CritterDeckCarousel 3D 滚轮**：新增 `activeIndex` state 替代旧堆叠模型；引入 `wheelDiff/wheelScale/wheelOpacity/wheelBrightness` 数学 helpers；ZStack 居中排列所有卡片，按 diff 偏移 `wheelSpacing(cardH*0.72)`，缩放最大1.0/最小0.78，透明度随距离衰减；`advanceToNext/retreatToPrev` 改为直接更新 `activeIndex`，`jumpToCard(at:)` 直跳任意卡片
- **模块3 PetCardBackView 删除图表**：移除 `backSparklines` 调用，后卡页面仅保留核心数据摘要+待办 Banner
- **模块4 全物种 Quick Access**：`CareType` 新增 `.waterChange/.filterClean/.cageCleaning/.freeFlight/.misting/.substrateChange/.play` 7 个类型；`QACardType` 对应扩展 16 个 case；`available(for:)` 按物种精准分配（狗/猫/鱼/鸟/兔鼠/爬宠/默认）；`handleTap` 处理新 case，`performLitterCheckIn/performSpecialCareCheckIn` 新打卡方法；`todayCount/glanceSubtitle` 全覆盖
- **模块5 椰子规则说明**：`OasisRewardView` 右上角添加 `info.circle` 按钮；`CoconutRulesSheet` 独立视图（收入来源/消耗用途/双账本系统三区，每项附说明）
- **模块6 体重导航修复**：`HumanDetailView.showWeightHistory` 从 `.navigationDestination` 改为 `.sheet`，根治 NavigationLink 死锁
- **模块7 猫咪 litter**：`QACardType.available("猫")` 列表首位改为 `.litter`，确保猫咪必有铲屎快捷
- **模块8 Quest 领取 Toast**：`DailyQuestsCard` 盲盒 sheet `onDismiss` 后触发 `UINotificationFeedbackGenerator(.success)` + 顶部青柠胶囊 Toast，2.2s 后自动消失
- **模块9 经济系统扩展**：`QuestManager.OhanaActionType.care(type:)` 的 `baseRewards/emoji/title` 全面差异化（洗澡15/10，刷牙8/5，剪甲8/5，梳毛5/4，清耳6/5）；新物种动作通过 `.general(humanReward:petReward:emoji:title:)` 传入奖励

#### Phase 72 详情

- **Task1 级联删除 Event**：`PetDetailView.clearPetLogs()` + `SettingsView.resetPetLogs()` 补充 `FetchDescriptor<Event>` 查询并删除 `relatedEntityId == petIdStr` 的 Event；删除宠物路径已在 Phase 71 覆盖
- **Task2 铲屎卡今日次数**：`OverviewView.countTextForAction()` 新增 `case "litter"` 过滤 `CareType.litter`，`case "potty"` 过滤 `pottyLogs`，与喂食/喂水逻辑一致
- **Task3 花费 Sheet 高度**：Quick Access `quickExpensePet` sheet 加 `.presentationDetents([.height(460), .medium])` + `.presentationDragIndicator(.visible)`
- **Task4 ImageCropper 缩放重构**：`PetImageCropView` 新增 `minScale` 计算属性（让图片短边填满 280pt 裁剪框）；初始化时自动设为 `minScale`；`MagnificationGesture` 改为 `onChanged` 实时 clamp `[minScale, 5.0]`，`onEnded` 同步 `lastScale`，移除旧 `@GestureState pinchScale`
- **Task5 第一顿美餐成就**：在所有喂食打卡点（`ArkCrewIDCardView.performCareCheckIn`、`OverviewView.applyAction("feed")`、`PetDetailView` 喂食按钮）`awardAction` 之前调用 `QuestManager.shared.recordFirstMeal()`
- **Task6 垂直切牌手势**：`CritterDeckCarousel` 重构——移除旧 `promotingIndex/Scale/Offset`，新增 `dragOffsetY` + `isDragging`；ZStack 挂 `DragGesture(minimumDistance:8)`，上滑 `advanceToNext()`（顶牌飞出→末尾），下滑 `retreatToPrev()`（末张飞入→顶），阻尼 0.45/0.35；`cardOffsetY/cardScale` 含联动动效

---

## 编译状态

✅ **最新编译通过** — iPhone 17 Pro Simulator, iOS 26.2（FIX 1-8 + 椰子树升级 + UI优化5项全部完成）

**Schema**: ArkSchemaV17（新增 PetMilestone.photoData）

---

## Backlog（未来待做）

| 优先级 | 任务 | 说明 |
|--------|------|------|
| **P0** | **Widget 实现** | Widget Target 不存在；今日提醒 + 喂食打卡，App Group 基础设施已就绪 |
| P1 | HealthKit 写入 | 将运动记录写回 HealthKit（目前仅只读） |
| P1 | NFC 魔法贴 | Shortcuts + `ark://`，碰触即打卡 |
| P2 | Sign in with Apple | AuthManager |
| P2 | CloudKit 同步 | 需付费开发者账号 |
| P2 | Siri 快捷指令 | AppIntents |
| P2 | Live Activity | 遛狗动态岛 ActivityKit |
| P2 | PDF 导出 | 宠物健康档案 + 人类运动报告 |
| P2 | 多语言 | Localizable.strings（zh/en），当前全部中文硬编码 |
| ~~P2~~ | ~~数据导出~~ | ✅ **TASK 1 已完成** — DataBackupManager JSON 全量备份/恢复，SettingsView 备份 Section |
| P2 | 分享海报 | 遛狗总结/里程碑一键生成分享图 |
| P2 | 交互式桌面组件 | 桌面直接投喂 |
---
Backlog — 虚拟宠物「岛屿后代」系统
优先级：P2（长线功能，先验证核心体验后再投入）
预估工期：Phase 1 MVP 约 2-3 周，完整版 6-8 周

核心理念
用户通过打卡积累的椰子「孵化」一只虚拟宠物，作为现有真实宠物的后代。虚拟宠物的状态完全由真实宠物的日常打卡行为驱动——照顾真实宠物越用心，虚拟后代越健康快乐。本质是真实照顾行为的可视化情感反馈，而非独立的额外负担。

与现有系统的联动逻辑
现实打卡行为虚拟宠物效果喂食打卡饥饿值维持正常遛狗打卡活力值 + 体力条上升洗澡 / 护理打卡外观「闪亮」buff 状态宠物体重处于健康区间虚拟宠物体型正常连续打卡 Streak虚拟宠物心情值加成长期不打卡虚拟宠物情绪低落、外观暗淡

分阶段实现规划
Phase 1 — MVP（放在绿洲 Oasis 页面）

消耗椰子「孵化」虚拟蛋（建议 100🥥），孵化动画
虚拟宠物继承父母宠物的物种/毛色/名字后缀（如「小豆」的后代叫「豆豆」）
3 个核心属性：心情 / 饥饿 / 活力（0-100，每日自然衰减）
属性完全映射真实打卡数据，无需单独喂养操作
展示形式：emoji / 像素风格静态形象 + 属性条，放置于绿洲 Bento Grid

Phase 2 — 成长系统

成长阶段：蛋 → 幼年 → 少年 → 成年（按累计打卡天数解锁）
性格特征从父母品种继承（活泼 / 慵懒 / 贪吃等）
稀有外观通过扭蛋或里程碑解锁
本地通知：「我饿了！」「陪我玩！」（映射真实宠物未打卡提醒）

Phase 3 — 深度互动（视用户反馈决定是否推进）

真正的 Tamagotchi 式帧动画表情
简单小游戏（消耗椰子，提升属性）
多只虚拟宠物收集 / 繁殖系统
虚拟宠物与真实宠物的「联名里程碑」


技术要点（实现时参考）

新增 VirtualPet SwiftData 模型：id / name / species / parentPetId / moodValue / hungerValue / energyValue / stage / appearanceRaw / bornAt
属性衰减通过 BGAppRefreshTask 后台任务每日更新，不依赖用户打开 App
状态计算完全基于现有打卡日志（PetFoodRecord / PetWalkLog / PetCareLog），无新数据输入需求
入口：绿洲 Oasis 页面 Bento Grid 新增「后代岛」格子
椰子消耗接入现有 AppStateManager（参见 TASK 3）
---

## TASK 完成记录（2026-03-08）

| Task | 完成 | 关键变更 |
|------|------|---------|
| TASK 1 | ✅ | `DataBackupManager.swift` — 21模型 JSON 全量导出/导入；`SettingsView` 备份 Section（导出+分享+文件导入） |
| TASK 2 | ✅ | `ArkSchemaV15`：`Human.themeColorHex` 正式字段；V14→V15 自定义迁移从 `notes` 提取颜色；全局替换 6 处 notes 颜色 hack |
| TASK 3 | ✅(跳过) | DataBackupManager 的 AppStateBackup 已涵盖 UserDefaults 关键状态，无需再迁移 |
| TASK 5 | ✅ | `Info.plist` 加 3 条定位权限描述；`LocationManager.upgradeToAlways()`；`WalkTrackingCard` Always 升级横幅 |
| TASK 6 | ✅ | `OhanaApp.swift` 注册 `BGAppRefreshTask`（ID: `com.guanchen.li.Ark.reminderRefill`）；`Info.plist` 加 `BGTaskSchedulerPermittedIdentifiers`；每 6 小时后台补充通知滑动窗口 |
| TASK 7 | ✅ | `PetHealthAlertEngine.swift` — 检测疫苗/驱虫到期、体重异常、久未打卡/便便/遛狗、年检逾期、证件到期；`PetHealthDetailView` 顶部健康预警 Section |

### 关键技术注记

- `Human.themeColorHex` 现为正式 SwiftData 字段（V15），所有颜色读取统一走 `human.themeColor`（`HumanExtensions`）
- `BGTaskScheduler` 任务 ID 必须在 Info.plist 的 `BGTaskSchedulerPermittedIdentifiers` 中声明
- `CLBackgroundActivitySession` 在 iOS 17+ 替代 `allowsBackgroundLocationUpdates`（WhenInUse 下也可后台追踪）
- `DataBackupManager.shared.exportJSON(context:)` / `importJSON(from:context:)` 均为 `@MainActor async throws`
- `PetHUDVitalSection` 使用 `@Query` 过滤当日 walkLogs/pottyLogs/careLogs，确保打卡后计数实时刷新
- `ImageCutoutService.isTransparentPNG(_:)` 检测透明通道，控制头像 scaledToFit/scaledToFill 显示策略

---

## FIX Sprint 完成记录（2026-03-09）

| Fix | 完成 | 关键变更 |
|-----|------|----------|
| FIX 1 | ✅ | `AddHumanWizardView` 新增身高/体重/步骤9；`Human` 新增 `privateFieldsRaw`/`heightCm`（ArkSchemaV16）；隐私字段 toggle |
| FIX 2 | ✅ | `AddPetWizardView.stepAvatar` 重构：粘贴抠图胶囊主推荐、可折叠说明卡、次级相册/拍照按钮 |
| FIX 3 | ✅ | `CritterDeckCarousel.miniCardFront` 透明 PNG 用 `scaledToFit`，普通图 `scaledToFill+clipped`；pet/human emoji fallback |
| FIX 4 | ✅ | `DietCardWithQuickActions` 新增便便/铲砂快捷打卡；`isCatLike` 区分；`dietActionCell` 辅助函数 |
| FIX 5 | ✅ | `PetFoodManagementView`：超量 Toast 语义修正；保存后清空输入框；`onAppear` 预填 |
| FIX 6 | ✅ | `PetHUDVitalSection` 独立 struct + `@Query` 实时查询当日打卡数 |
| FIX 7 | ✅ | `PetMilestone` 新增 `photoData: Data?`（ArkSchemaV17）；`PetMilestoneListView` 添加 PhotosPicker |
| FIX 8 | ✅ | `CritterDeckCarousel` 普通图底部加 `LinearGradient` overlay 渐变融入卡片背景 |

---

## Bug Fix & UX 优化 批次（2026-03-09 续）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| T1：Quick Access 卡片缺失 | `ArkCrewIDCardView.swift` | `QAConfig.load` 增加 `species` 参数；无存储时返回 `QACardType.available(for: species)` 默认配置；`onAppear` 传入 `pet.species` |
| T2A：健康页 sheet 死锁 | `PetHealthDetailView.swift` | 添加 `@Environment(\.dismiss)`；toolbar `.topBarLeading` 插入 `xmark.circle.fill` 关闭按钮 |
| T2B：打卡数字为0 | `PetDetailView.swift` | `PetHUDVitalSection` 已用 `@Query` 实时查询，确认无问题，标记通过 |
| T3A：取景框最小缩放 | `AddPetWizardView.swift` | `minScale` 改为 `min(fitMin, 0.5)` 允许缩到 0.5x |
| T3B：人类向导主题色 | `AddHumanWizardView.swift` | 确认页添加 8 色主题色选择器+头像徽标；`saveHuman` 写入 `themeColorHex` |
| T4：粮食价格记账 | `PetFoodManagementView.swift` | 库存编辑区新增 `购买价格` 输入框 + 支付人横向 Picker；`saveStock` 价格>0 时创建 `PetExpenseLog(category: .food)` |
| T5：一键全家开关 | `OverviewView.swift` | `@AppStorage("showBatchCheckIn")` 开关控制显隐；`batchBentoCell` 升级为多巴胺渐变圆角矩形图标背景 + 彩色 shadow |
| T6：体重表单多巴胺化 | `GenericWeightEntrySheet.swift` | 三色渐变背景+装饰圆+`scalemass.fill` 大图标圆；输入卡片渐变光晕边框；保存按钮渐变+shadow |
| T7：椰子树光晕采摘 | `OasisRewardView.swift` | `glowBreathing` 呼吸光晕（RadialGradient+goLime stroke）；采摘气泡升级（渐变+副标题）；`flyCoconut/flyOpacity` 驱动椰子飞入余额区动画 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第二十章：深度 Bug 修复 + UI 重构（2026-03-09）

| 模块 | 文件 | 变更说明 |
|------|------|----------|
| 模块一：Quick Access 强过滤 Bug | `ArkCrewIDCardView.swift` | `QAConfig` 改为黑名单机制（`qaExcluded_<petId>`），`load` 返回全量 `available` 再减去黑名单；`removeCard/addCard` 改为 `exclude/unexclude`；迁移旧激活列表存储；`QAAddPanel` 也改用 `unexclude` |
| 模块二：PetHUDVitalSection 数据同步 | `PetDetailView.swift` | `walkLogsQ` predicate 改为 `weekStart`；`todayWalks` 从 `walkLogsQ` 二次过滤；7天点阵全用 `walkLogsQ`；`todayFeed` 改用 `todayStart` predicate |
| 模块三：一键全家 Minimalist + 首页排序 | `OverviewView.swift`, `OverviewHelperViews.swift` | `batchCheckIn` 加入 `sectionOrderRaw` 默认值；`mainScrollView` 改为 `ForEach orderedSections + switch` 驱动；`batchCheckInBar` 重构为 44pt 高胶囊条（左标题+竖线+水平滚动按钮+右编辑）；`batchPillButton` 胶囊按钮；`HomeSectionEntry.defaults` 加入 batchCheckIn 条目 |
| 模块四：AddMilestoneSheet/AddDocumentSheet 多巴胺化 | `PetMilestoneListView.swift`, `AddDocumentSheet.swift` | 深色渐变背景（goDarkBlue/goTeal）+ 装饰圆 + 毛玻璃输入框（.white.opacity(0.08)）+ goLime/goTeal 渐变保存按钮 + `.preferredColorScheme(.dark)`；`docField` 辅助函数统一输入行样式 |
| 模块五：MiniFlipCard 破框极简化 | `CritterDeckCarousel.swift` | Pet/Human 正面右侧信息区只保留大字名字（18pt .heavy）；移除 `human.roleText`；名字字号从 15 升至 18 |
| 模块六：绿洲打卡日历 + 补签系统 | `OasisRewardView.swift` | `checkedInDates`/`makeupPackCount` 状态 + UserDefaults 持久化；`checkInCalendarCard` 30天 LazyVGrid 日历（goLime 打卡圆 + 今日高亮边框）；`triggerTodayCheckIn` onAppear 自动打卡奖励1椰子；`applyMakeup` 消耗补签包；`.confirmationDialog` 补签确认；`currentStreak` 连胜天数计算 |
| 模块七：护理详情长按弹计划 Sheet | `PetHygieneDetailView.swift`, `PetHygieneLog.swift` | `HygieneType` 添加 `Identifiable`；`groomingPlanTarget: HygieneType?` 状态；`hygieneTypeCard` 添加 `.onLongPressGesture(0.5s)` + heavy haptic；`.sheet(item: $groomingPlanTarget)` 弹出 `HygieneTodoSheet` |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 头像步骤 UX 重构（2026-03-09）

| 子任务 | 文件 | 变更说明 |
|--------|------|----------|
| Pro Tip Banner | `AddPetWizardView.swift` | `proTipBanner`：`wand.and.stars` 图标 + goLime 描边卡片 + 富文本（长按主体拷贝高亮 goLime）|
| 主 CTA 粘贴按钮 | `AddPetWizardView.swift` | `pastePrimaryButton`：有图→goLime 渐变+呼吸发光+动态文案「立刻粘贴」；无图→弱化灰色；`pasteBreathing`驱动 shadow/箭头缩放 |
| 次级按钮行 | `AddPetWizardView.swift` | `secondaryPhotoRow`：相册+拍照并排，白色半透明圆角矩形，视觉优先级明确低于主 CTA |
| 头像预览 Badge | `AddPetWizardView.swift` | `avatarPreviewBadge`：透明抠图右上角显示 `sparkles` 绿色徽标 |
| 加载态 + 触觉反馈 | `AddPetWizardView.swift` | `isPasting` 驱动 ProgressView；`UIImpactFeedbackGenerator(.medium)` + 0.15s 延迟后直达 `cropImageItem` |

---

## 宠物卡片动态视觉策略 + 反农场机制（2026-03-09）

| 子任务 | 文件 | 变更说明 |
|--------|------|----------|
| 卡片正面动态策略 | `ArkCrewIDCardView.swift` | `cardFrontView` 重构为三分支：透明PNG→方案三破框悬浮（clipShape外overlay，图片溢出20pt）；普通照片→方案四高斯模糊（blur40+深色蒙版+左侧渐变消融）；无图→emoji fallback。右侧信息区删除品种/性别，只保留名字、相伴天数、年龄换算。共享 `infoColumn/detailButton/flipHint` 子组件 |
| 透明度检测 | `ImageCutoutService.swift` | `isTransparentPNG(_:)` 已存在，`ArkCrewIDCardView` 直接调用 |
| TASK A 冷却机制 | `QuestManager.swift` | 新增冷却规则（feed/water:4h, potty:2h, care:24h, general:2h）；`isOnCooldown/cooldownRemaining/recordCooldown`；`awardAction` 入口加冷却门卫，持久化成功后才记录时间戳 |
| TASK B GPS 门槛 | `PetWalkingManager.swift` | `stop()` 距离<20m 时跳过椰子奖励，`isTooShortForReward` 局部变量控制 |
| TASK C Streak奖励 | `StreakRewardManager.swift`（新建）| 里程碑（7/30/100/365天）发放椰子，防重复领取，`lastMilestone` 监听触发 Toast；接入 `awardAction` 成功路径 |
| TASK C 保护盾 | `StreakManager.swift` | Streak 断链时检查 `shop_streakShieldExpiry`，保护盾有效则续 Streak 并消耗 |
| TASK D 扭蛋机 | `GachaView.swift` | 新增 `r_backdate_1day`(Rare,8%) / `e_backdate_3day`(Epic,3%) 补打卡券奖品；结果卡显示「立即使用」按钮；弹出 `BackdateCheckInSheet` |
| TASK D 补打卡Sheet | `BackdateCheckInSheet.swift`（新建）| 选宠物+打卡类型+目标日期（1-N天前）；调用 `awardAction`；成功显示获得椰子数 |
| TASK E 商店新品 | `CoconutShopView.swift` | 新增：Streak保护盾(50🥥)、补打卡包(120🥥→+3张昨日券)、冷却重置券(80🥥→清空所有冷却) |

---

## 椰子树全面升级（2026-03-09）

| 子任务 | 文件 | 变更说明 |
|--------|------|----------|
| OasisTreeManager 重构 | `OasisTreeManager.swift` | `TreeLevel` 扩展为 10 级（lv1-lv10）；能量阈值表 `[0,50,150,300,500,800,1200,1800,2600,3600,∞]`；升级奖励椰子（Lv2-10 奖 5-200）；`checkAndRewardLevelUp()` 防重复奖励；Lv5+ 被动收益每日 3-15 椰子 |
| BeautifulCoconutTree | `BeautifulCoconutTree.swift`（新建） | SwiftUI `Path` 动态生长椰子树：`TrunkShape`（Animatable 弯曲树干）+ `LeafShape`（弯曲叶片，随等级扩展）+ `CoconutShape`（椰果，Lv5+）；微风摇曳（`.easeInOut.repeatForever`）+ 光晕脉冲；Lv10 满级粒子特效（Timer + sparkle 图标） |
| OasisRewardView 接入 | `OasisRewardView.swift` | 替换旧 SF Symbol 树形为 `BeautifulCoconutTree(level:isInjecting:)`；新建 `isInjecting` @State；注能按钮点击时设置 0.5s 脉冲；领取气泡显示实际被动收益数量 |
| CoconutShopView 升级 | `CoconutShopView.swift` | `ShopItem` 新增 `isConsumable`；消耗品购买后立即激活而非标记已购；`boost_tree` 直接注入 30 点树能量；`boost_double` 用 `shop_boostDoubleActive` 标记；`boost_streak` 用 `shop_streakShieldExpiry` 标记 24h |
| QuestManager 接入 | `QuestManager.swift` | `addCoconuts` 正向奖励时检测 `shop_boostDoubleActive`，激活则额外×2 并消耗标记，日志显示"⚡️双倍券激活" |

---

## 第二十一章：深度 Bug 修复 + UI 精修（2026-03-08）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| T1：Quick Access 陪玩/粑粑缺失 | `ArkCrewIDCardView.swift` | `QAConfig.loadExcluded` 迁移旧激活列表时，改为只排除"物种 available 里、旧版未激活"的卡片；新增卡片（play/potty 等）不再被误加入黑名单；`load` 传 species 给 `loadExcluded` |
| T2：首页模块管理优化 | `OverviewView.swift`, `OverviewHelperViews.swift` | 移除 `petCards` 模块管理条目；`showBatchCheckIn` 默认 false；默认排序 `batchCheckIn,quickAccess,islandStats,todayTasks`；`orderedSections` 排除 petCards |
| T3：取景框最大放大限制 | `AddPetWizardView.swift` | 新增 `maxScale` 计算属性（短边/cropSize）；`MagnificationGesture.onChanged` 改用动态 `maxScale` 上限（不再硬编码 8.0） |
| T4：全家打卡 emoji 重复 | `OverviewView.swift` | `batchPillButton` 移除单独的 `Text(action.type.emoji)`；`action.label` 已含 emoji |
| T5：图鉴卡片只显名字 | `CrewRosterOverlay.swift` | `PetSquareCard` 底部信息区只保留宠物名字（17pt .black）；移除品种行和状态 badge |
| T6：AddDocumentSheet UI 重构 | `AddDocumentSheet.swift` | 参考护理计划 `settingRow` 风格：系统浅色背景、横向行布局（`docRow` 辅助函数）；证件类型改为 goLime chip 选择器；保存按钮改为 goLime 实色 |
| T7：护理计划截止日期 bug | `PetHygieneCard.swift` | `save()` 改为写单个 `Event`（设 `recurrenceDays` 字段），不再手动展开 180 天实例；截止日期写 `recurrenceEndDate`；无截止日期时默认一年后 |
| T8：Island Stats 左滑提示 | `OverviewView.swift` | `islandStatsBento` 标题行右侧加"左滑查看更多 + chevron.left.2"弱提示 |
| T9：绿洲页面 Bento 缩小 + 布局调整 | `OasisRewardView.swift` | Bento 大卡改为紧凑行（`bentoMiniCard`，高约44pt）；打卡日历入口胶囊按钮移到椰子数旁；椰子树 padding.top 28→60 整体下移；打卡日历改由 sheet 弹出 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第二十二章：深度 Bug 修复 + 功能完善 P1-P10（2026-03-09）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| P1：取景框卡顿 | `AddPetWizardView.swift` | 选图后异步压缩再进裁剪页，减少主线程阻塞（前一 session 完成）|
| P2：卡片风格选择 | `Pet.swift`, `SharedModelContainer.swift`, `AddPetWizardView.swift`, `ArkCrewIDCardView.swift` | Pet 新增 `cardStyleRaw`（ArkSchemaV19，V18→V19 lightweight 迁移）；confirm 步骤添加经典/简约双风格选择器；`ArkCrewIDCardView` 新增 `minimalFront`：纯色底+居中圆形头像+底部信息条，根据 `cardStyleRaw` 动态切换 |
| P3：确认页主题色 | `AddPetWizardView.swift` | 已在 `stepAppearance` 步骤实现完整主题色选择器（含预设色格+自定义 ColorPicker+预览）|
| P4：宠物信息页可编辑 | `PetBasicInfoDetailView.swift` | 完全重构：toolbar 编辑/保存/取消按钮；`readContent` 展示所有字段；`editContent` 内联编辑（Picker/Toggle/DatePicker/TextField/ColorPicker）；`loadEditState`/`saveChanges` 读写全部字段含主题色；头像区显示"编辑中"胶囊提示 |
| P5：里程碑 location 字段 | `SharedModelContainer.swift` | ArkSchemaV18 新增 `PetMilestone.location`（空字符串），V17→V18 lightweight 迁移（前一 session 完成）|
| P6：里程碑地图跳转 | `PetMilestoneListView.swift` | 地址行可点击跳转苹果地图（前一 session 完成）|
| P7：证件管理可编辑 | `DocumentsListView.swift` | 点击证件进详情页，支持编辑/删除（前一 session 完成）|
| P8：喂食超量弱化拦截 | `PetFoodManagementView.swift` | 移除超量拦截逻辑（前一 session 完成）|
| P9：寄养名片数据同步 | `SitterCardPreviewSheet.swift` | 基本信息区补充体重（最新体重+日期）、年龄（`ageText`）、出生地字段，与宠物详情页数据保持一致 |
| P10：图鉴卡片一致性 | `CrewRosterOverlay.swift` | 移除 ScreenCompat 依赖，改用 GeometryReader 计算卡片宽度（前一 session 完成）|

**Schema 版本**: ArkSchemaV19（V18 新增 `PetMilestone.location`，V19 新增 `Pet.cardStyleRaw`）
**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第二十三章（续）：紧急修复 U1-U4（2026-03-09）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| U1：Quick Access 核弹强注入 | `ArkCrewIDCardView.swift` → `QAConfig.load` | 在清洗黑名单后再遍历一次 `available`，凡不在 `result` 中的卡片强行 `append`。无论旧 UserDefaults 多脏，函数返回值必然包含该物种所有 available 卡片。猫的 `.potty`/`.play` 彻底无法被排除 |
| U2：GenericWeightEntrySheet 100% 对齐 | `GenericWeightEntrySheet.swift` | 上次已完成 ArkBackgroundView + HStack 骨架对齐；本次确认与 AddExpenseSheet 结构一致，无需额外修改 |
| U3：头像预览拉伸修复 | `AddPetWizardView.swift` → `avatarPreviewBadge` | 非透明分支：`resizable → scaledToFill → frame(120×120) → clipShape → clipped`（补 `.clipped()` 防止 fill 溢出 ZStack 造成拉伸视觉）；透明分支：`resizable → scaledToFit → frame(120×120) → clipped` |
| U4：宠物卡片花屏修复 | `ArkCrewIDCardView.swift` → `blurBackgroundFront` | 层5 渐变消融由 `.mask(LinearGradient)` 改为 `.overlay(LinearGradient.blendMode(.destinationOut)) + .compositingGroup()`。根因：`.mask` 在 SwiftUI iOS 上会触发 CoreGraphics 合成层字节未对齐，产生条形码花屏；改用 `destinationOut` blendMode + `compositingGroup` 实现等效消融且无渲染故障 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第二十三章：Bug Fix + UI 重构 T1-T4（2026-03-09）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| T1：Quick Access .play/.potty 缺失 | `ArkCrewIDCardView.swift` | `QAConfig.load` 增加黑名单安全校验：`cleanedExcluded = excluded.filter { available.contains($0) }`，自动清洗历史脏数据，防止 `.play/.potty` 被旧版迁移误加黑名单后永久消失 |
| T2：PetHealthDetailView 导航冲突 | `PetHealthDetailView.swift`, `ArkCrewIDCardView.swift` | `PetHealthDetailView` 新增 `isModal: Bool = false` 参数；仅 sheet 路径（`isModal: true`）显示 `xmark` ToolbarItem；`navigationDestination` push 路径默认 `false`，不显示多余关闭按钮，消除闪烁死锁 |
| T3：GenericWeightEntrySheet 风格对齐 | `GenericWeightEntrySheet.swift` | 移除多巴胺渐变背景/装饰圆/渐变光边框/渐变保存按钮；改用 `ArkBackgroundView` + 简洁 HStack 输入行 + goLime 实色保存按钮，与 `AddExpenseSheet` 视觉完全一致 |
| T4：卡片破框改为 popout 特权 + 精简向导 + 商店联动 | `ArkCrewIDCardView.swift`, `AddPetWizardView.swift`, `CoconutShopView.swift`, `EquipPopoutCardSheet.swift`（新建） | ① `cardFrontView` 将破框触发条件改为 `cardStyleRaw == "popout" && isTransparent`，默认始终 blur；② `stepAvatar` 移除 `proTipBanner` 和 `pastePrimaryButton`，只保留相册/拍照；③ `stepConfirm` 移除 cardStyle 选择器；④ `CoconutShopView` 新增 `fx_popout_card`（150🥥，永久特效），购买后触发宠物选择 → `EquipPopoutCardSheet`；⑤ 新建 `EquipPopoutCardSheet`：抠图引导 Banner + 粘贴激活按钮（读取剪贴板图片 → 调 `ImageCutoutService.removeBackground` → 写入 `pet.avatarImageData` + `pet.cardStyleRaw = "popout"`） |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)
