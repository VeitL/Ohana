# Ohana App 开发进度

> 最后更新: 2026-03-19 | Schema: ArkSchemaV22 | Phase 1-79 + 第二十章～第四十五章完成

## 第四十七章 首页全面重设计（2026-03-28）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| HM47-BG | 背景图资产 | `Assets.xcassets` | 新增 `bg_dog.imageset`（Golden_retriever.png）和 `bg_cat.imageset`（Devon_rex.png），从 "Background Pictures" 文件夹复制 |
| HM47-HERO | Pet Hero 区 | `MaterialDashboardView.swift` | 全新 `petHeroSection(pet:)`：圆形头像 96pt + 白色 3pt 描边 + 宠物名字 40pt black rounded + 物种胶囊 + Happy&Active 状态胶囊 + 指示点（多宠物）+ 左右滑动切换手势；占屏幕高度约 42% |
| HM47-BG-SWITCH | 背景切换逻辑 | `MaterialDashboardView.swift` | `activePetBgImageName`：species 含"猫"/cat → bg_cat，否则 → bg_dog；切换动画 `.easeInOut(duration: 0.7)` |
| HM47-GLASS | 磨砂玻璃面板 | `MaterialDashboardView.swift` | 下 ~58% 区域用 `.ultraThinMaterial` + `UnevenRoundedRectangle(topRadius:32)` 磨砂玻璃面板，内含拖动手柄 + activityGrid + lifeTreeWidget + globalOverviewSection |
| HM47-REMOVE | 移除旧模块 | `MaterialDashboardView.swift` | 从 homeTab 移除 `stackedPetCards`（宠物堆叠卡片）和 `matGreeting`（问候语），信息整合进 petHeroSection |
| HM47-HEADER | Sticky header 透明化 | `MaterialDashboardView.swift` | Home tab 下 sticky header 背景改为 `.ultraThinMaterial.opacity(0.85)`，不再遮挡背景图 |

## 第四十六章 性能深度优化（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| PERF46-TIMELINE | 消灭 30fps TimelineView | `SwipeableEventRow.swift` | 将 `TimelineView(.animation(minimumInterval: 1/30))` 替换为原生 SwiftUI `@State overdueBreath: Bool` + `@State overdueFloat: CGFloat`；在 `.onAppear` 中用 `.easeInOut(duration:0.55).repeatForever(autoreverses:true)` 和 `.easeInOut(duration:0.83).repeatForever` 触发；彻底消除每帧轮询主线程的开销 |
| PERF46-COLORS | Color 静态缓存 | `MaterialDashboardView.swift` | 将 `bg/surface/surf2/textSec` 计算属性改为 `private static let` 预先解析的 Color 常量（bgLight/bgDark/surf1D/surf2L/surf2D/textSecL/textSecD）；实例计算属性只做一次 ternary 返回，彻底消除每次 render 的 `Scanner` hex 解析 |
| PERF46-WALKTIMER | Walk Timer 隔离 | `MaterialDashboardView.swift` | 彻底移除 `@State walkTime: Int` + `@State walkTimer: Timer`（每秒 `walkTime+=1` 触发 2000+行父视图全量重渲染）；改为 `@State walkStartDate: Date?` + `@State walkPausedElapsed: Int`；走步卡内部用 `TimelineView(.periodic(from:.now, by:1))` 计算显示 elapsed，父视图 body 每秒不再触发 |

## 第四十五章 Material UI 体验全面升级（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT45-STICKY | 首页吸顶三按钮 | `MaterialDashboardView.swift` | `matStickyHeader` 横排：Settings 圆形 + 添加 FAB（橙色圆形 +号）+ Spacer + 椰子数胶囊（最右）；ZStack overlay + `.background(.ultraThinMaterial).ignoresSafeArea(.top)` 常驻顶部，不随 ScrollView 滚动；`GeometryReader` 捕获 `coconutBtnOrigin` 供粒子动画定位 |
| MAT45-CARD-ANIM | 卡片展开 Layout 动画 | `MaterialDashboardView.swift` | 所有 Bento 卡增加 `matchedGeometryEffect(id:in:cardExpandNS)`；activityGrid VStack 动画从 `.spring(0.45,0.75)` 改为 `.spring(response:0.55,dampingFraction:0.88)` 使展开更平滑推挤 |
| MAT45-PARTICLE-SRC | 粒子从卡片起飞 | `MaterialDashboardView.swift` | 新增 `@State cardOrigins:[MatCardType:CGPoint]`；每张 bento 卡附加 `.onGeometryChange(for:CGPoint.self)` 实时追踪屏幕坐标（含滚动更新）；`launchCoconutParticles(from:)` 新增 origin 参数；`triggerFeedingAnim/triggerWaterAnim/triggerLitterAnim` 全部传 `cardOrigins[.type]` |
| MAT45-PET-APPEAR | 新宠物立即可见 | `MaterialDashboardView.swift` | `stackedPetCards` 改为旋转窗口：`visibleStackPets` 基于 `activePetIndex` 动态取 min(3,n) 只宠物（从任意索引旋转）；`.onChange(of:pets.count)` 自动跳转至 `newCount-1`（最新宠物）并触发 `triggerCardStagger()`；解决原来 `prefix(3)` 固定只展示前3只的 bug |
| MAT45-CAL-HDR | 日历吸顶三按钮 | `CalendarView.swift` | `calStickyHeader` 横排：添加日程（calendar.badge.plus 橙色圆形 FAB）+ 视图切换胶囊（calendar/list.bullet）+ Spacer + 椰子数药丸；与首页按钮位置/样式完全一致；`onAppear`+`NotificationCenter("coconutCountChanged")` 同步椰子数；移除旧 toolbar HStack |
| MAT45-MAT-TEST | Material UI 测试页 | `MaterialDesignTestView.swift`（新建） | 完整展示设计系统：色彩系统 6色板、排版5级字阶、Cards(Standard+Accent)、Buttons(FAB/Secondary/Pill)、Toggles+Slider、Tags/Badges、Area+Stacked Bar 图表、6条 Motion 参数；Settings > 偏好设置 `NavigationLink` 入口 |
| MAT45-ADD-ENT | AddEntityView Material 化 | `AddEntityView.swift` | `isMaterial` 检测：背景切换 `matBg`；entity 选择器改为独立 `entityCard()` 函数；Material 模式：白色 RR28 卡片 + shadow；Classic 模式：半透明玻璃卡 + 描边；统一 `ScaleButtonStyle`；标题/副标题更新 |
| MAT45-AVATAR | 分层 Avatar 引擎 | `LayeredAvatarView.swift`（新建） | `LayeredAvatarView`：有头像→图片分区点击（上1/3=眼区，下2/3=身体区）；无头像→矢量剪影 `PetSilhouetteIcon`（dog/cat/hare/bird/pawprint）+ 毛色 RadialGradient 圆底 + 眼睛层（双瞳+光斑）；点击触发 `.sheet(ColorPickerPopup)` Phase 1+2 完成 |
| MAT45-COLOR-PKR | ColorPickerPopup | `LayeredAvatarView.swift` | 眼色9种（琥珀/深棕/浅棕/蓝灰/绿色/冰蓝/灰色/榛色/黑色）；毛色10种（象牙白/奶油/金黄/姜橙/焦糖/巧克力/银灰/炭黑/三花/虎纹）；`.presentationDetents([.height(340)])`；选中即动画更新绑定值 + 0.25s 后自动 dismiss；`ScaleButtonStyle` + spring 选中放大效果 |

## 第四十四章 Global Overview Carousel + 智能日程流（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT44-CAROUSEL | Global Overview 横向 Carousel | `MaterialDashboardView.swift` | `globalOverviewSection` 重写为横向 ScrollView + `.scrollTargetBehavior(.viewAligned)`；3 张卡宽 85vw、高 220pt、圆角 32pt；`.scrollClipDisabled()` 露出下张卡边缘暗示可滑动 |
| MAT44-WALK-CARD | Card 1: Walk & Activity | `MaterialDashboardView.swift` | 7日真实走步距离（activePet.walkLogs，无数据时 Mock 回退）；橙色 CatmullRom Area Chart（LinearGradient 填充 #FF5A00→clear）+ LineMark + PointMark；Y 轴隐藏，X 轴极简星期标签；大数 "{总km} km" + "Walk & Activity" 胶囊 |
| MAT44-EXP-CARD | Card 2: Island Expenses | `MaterialDashboardView.swift` | 本月 activePet 花费汇总（无数据用 Mock 620+380+180+100）；水平堆叠条形图（4色 Capsule）+ 3色图例 chip + "X 占本月总开销的 Y%" 底部洞察文字；金额 numericText 动画 |
| MAT44-COCO-CARD | Card 3: Coconut Wealth 榜 | `MaterialDashboardView.swift` | 全岛椰子总量（`QuestManager.shared.coconutCount`）+ 前3名横向条形图（emoji+名字+进度条+余额）；Human+Pet 合并排序；条形动画 spring(0.6,0.8) |
| MAT44-OVERDUE | 逾期引力动画 | `SwipeableEventRow.swift` | 移除描边框；逾期图标圆底变 #FF5A00；`TimelineView(.animation(minimumInterval:1/30))` 驱动：`sin(t×1.8)×0.025+1.0` 呼吸缩放 + `sin(t×1.2)×2.0` 垂直浮动；仅对 `rowState == .overdue` 生效 |
| MAT44-SWIPE-MORPH | 滑动完成形变 | `SwipeableEventRow.swift` | 左滑时卡片 `scaleEffect(x: 1-p×0.04, y: 1+p×0.02, anchor: .trailing)` 挤压；图标节点背景随 `leftProgress` 从原色插值到 #FF5A00；p>0.4 时 emoji 淡出→checkmark 淡入+缩放；信息文字 `opacity(1-p×0.8)` 淡出；逾期 p>0.3 即开始 morph；`animation(.spring(response:0.2,dampingFraction:0.7))` |

## 第四十三章 Dashboard Bug Fixes + UX 强化（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT43-TAPFIX | Card onTapGesture 修复 | `MaterialDashboardView.swift` | 全部5张 Bento 卡（feeding/water/litter/expenses/weight）`.onTapGesture` 改为只展开（`guard expandedCard != .xxx else { return }`），不再在展开态拦截内部按钮点击 |
| MAT43-DISMISS | 全局 Tap Dismiss | `MaterialDashboardView.swift` | `homeTab` 改为 `ZStack`，`expandedCard != nil` 时在 ScrollView 上方叠加 `Color.clear + contentShape + onTapGesture { expandedCard = nil }` 透明覆盖层 |
| MAT43-BENTO5 | Weight 并入 Bento 网格 | `MaterialDashboardView.swift` | `bentoTypes` 扩展至 5 项（+weight）；正常态 Grid 增加第3行（weight + Color.clear 占位）；展开态剩余4张卡排成2行×2列；`bentoCardView` 增加 `.weight` case；移除独立全宽 weight 行 |
| MAT43-WALK-MAP | Walk 卡实时地图 | `MaterialDashboardView.swift` | `import MapKit`；`walkBackFace` 顶部 Map 视图（`Map(interactionModes:[]) { UserAnnotation() }.mapStyle(.standard)`）替换山脉装饰图；活跃时卡片高度 300pt；紧凑控件行：pause(40×32) + 💩计数器(numericText) + 结束按钮；新增 `@State walkPoopCount: [UUID:Int]` |
| MAT43-ADDPET | 添加宠物入口 | `MaterialDashboardView.swift` | Header 右侧新增橙色圆形 + 按钮（`showAddEntity = true`）；Dock 中间 FAB 从 leaf.fill → plus（调用 `showAddEntity`）；tab 2→CrewRoster，tab 3→OasisReward |
| MAT43-COCONUT | Header 椰子极简药丸 | `MaterialDashboardView.swift` | 椰子余额改用 `circle.hexagongrid.fill` 橙色图标 + surf2 胶囊；数字加 `.contentTransition(.numericText()).animation(.spring(response:0.4), value: coconutCount)` |
| MAT43-PARTICLE | 打卡椰子粒子吸收 | `MaterialDashboardView.swift` | 新增 `MatCoinParticle` 结构体 + `MatCoinParticleView`（飞向右上角 header pill）；`launchCoconutParticles()` 在 feeding/water/litter 打卡时触发；Light Haptic on launch，Heavy Haptic 0.65s 后模拟"吸收"；`coinParticles` overlay 在 homeTab ZStack 顶层 |
| MAT43-TREE | 生命之树 Bento Widget | `MaterialDashboardView.swift` | `lifeTreeWidget`：Activity Grid 下方全宽横条卡；左：Emoji 树图标（随 TreeLevel 变化，lv1🌱→lv10✨）+ glowColor 光晕圆；中：`displayName` + Lv 标签 + 能量进度文字；右：`progressToNextLevel` 环形进度条（accent 色）+ `bolt.fill` 注入 FAB（消耗10椰子调 `injectEnergy(cost:10)`）|
| MAT43-EXPENSE-PAY | Expense 默认支付者 | `AddExpenseSheet.swift` | 新增 `var preselectedPayerId: String? = nil`；`onAppear` 优先使用 `preselectedPayerId`，其次读 UserDefaults `currentActiveHumanId`，最后 fallback `humans.first`；Dashboard 开启 sheet 时传 `humans.first?.id.uuidString` |

## 第四十二章 Dashboard 卡片进阶 + AddPet Bento 重构（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT42-ENUM | MatCardType enum | `MaterialDashboardView.swift` | 新增 `private enum MatCardType: String, Equatable`（feeding/waterChange/litter/expenses/weight/walk）；`@State private var expandedCard: MatCardType? = nil` 统一管理所有卡片展开状态，替换旧 `feedingExpanded[UUID:Bool]` 字典 |
| MAT42-INLINE | Inline Expansion 挤压展开 | `MaterialDashboardView.swift` | `activityGrid` 重写：展开态时选中卡片弹至全宽 + Spring 动画，剩余3张以 opacity(0.4)+scale(0.97) 缩退到下方两行；收起态恢复 2×2 Bento 网格；`.animation(.spring(response:0.45,damping:0.75),value:expandedCard)` |
| MAT42-FOCUS | Focus State 视觉聚焦 | `MaterialDashboardView.swift` | 非选中卡片 `focusOpacity()` → 0.4，`focusScale()` → 0.97；全部卡片 helper 统一读取 `expandedCard` |
| MAT42-WATERCHANGE | Water Change 卡 | `MaterialDashboardView.swift` | 替换旧 waterCard：Collapsed = 波浪背景+换水天数；Expanded = 滤芯倒计时进度条(30天周期，<7天变红) + 双按钮（日常换水/深度清洗）；新增 `lastWaterChangeDates`/`lastDeepCleanDates` per-pet 字典 |
| MAT42-LITTER | Litter 展开态 | `MaterialDashboardView.swift` | 展开态：Bristol 便便类型 5-按钮快速记录 + "上次全盆更换 N天前" + "记录更换"按钮 |
| MAT42-EXPENSES | Expenses 展开态 | `MaterialDashboardView.swift` | 展开态：本月总额 + 4类花销占比横向进度条(食物/医疗/美容/用品) + 内嵌金额输入框+"记账"按钮；新增 `@State private var quickExpenseAmount` |
| MAT42-WEIGHT | Weight 展开态 | `MaterialDashboardView.swift` | 展开态：大号当前体重 + 最近6次 Charts 折线+面积图 + "记录体重"按钮；历史 <2 条时显示引导文案 |
| MAT42-WALK | Walk 展开整合 | `MaterialDashboardView.swift` | `walkExpanded` → `expandedCard == .walk`；Walk History 的 X 关闭按钮改为 `expandedCard = nil`；Start Walk 同步 reset expandedCard |
| MAT42-STAGGER | Staggered reset | `MaterialDashboardView.swift` | `triggerCardStagger()` 首行追加 `expandedCard = nil` 确保宠物切换时折叠所有卡片 |
| MAT42-BENTO-WIZARD | AddPetWizard 单页 Bento | `AddPetWizardView.swift` | 移除10步多页 navButtons 导航；新 body = 单页 ScrollView + 4模块：① LiveIDCard（实时预览头像/名字/物种/年龄换算）② MagicScanSection（抠图头像区 + 名字输入 + 剪贴板/相册/拍照3按钮）③ BioGrid（物种胶囊选择器 + 性别药丸 + 绝育 Toggle + 生日 DatePicker + 主题色8色格）④ DigitalTwin（毛色+瞳色色板）；FloatingFAB 橙色圆形 Checkmark 一键保存 |

## 第四十一章 Material Dashboard UI 细化（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT41-HEADER | Header 重构 | `MaterialDashboardView.swift` | Greeting 并入 Header 左侧（size 38 rounded 两行）；右侧改为垂直排列两个按钮：Settings 圆形 + 椰子数胶囊（`🥥 N`，点击跳转 OasisRewardView）；`HStack(alignment: .top)`顶部对齐；顶部空隙从 60→24pt |
| MAT41-CARDSIZE | 卡片统一正方形高度 | `MaterialDashboardView.swift` | 新增 `cardSize = (screenWidth - 32 - 14) / 2`（约 174pt）；feeding/water/litter/expenses/weight/walk 全部使用 `cardSize` 高度替代原来各自 hardcode 的 164/162/80/130 |
| MAT41-SEAMLESS | Feeding/Litter 无缝 | `MaterialDashboardView.swift` | 两张分割卡的 `VStack(spacing: 2)` → `VStack(spacing: 0)`；内部上下两半均改 `frame(maxHeight: .infinity)` 自适应分配，不再 hardcode 80/82/72/90 |
| MAT41-PARTICLES | 粒子不弹回 | `MaterialDashboardView.swift` | `FoodParticleView` / `WaterParticleView` / `PoopParticleView` 新增独立 `@State yOff`；落下动画只改 yOff 不复位；淡出动画只改 opacity，yOff 停在落地位置（不弹回） |
| MAT41-ADDBTNS | Weight/Expenses 添加按钮 | `MaterialDashboardView.swift` | Weight 卡改为竖版布局（图标+add按钮在顶，文字在底），右上角 `+` 圆形按钮（`showAddWeight` sheet）；Expenses 卡顶右也加 `+` 按钮（`showAddExpense` sheet） |
| MAT41-STAGGER | Staggered Cascade 动画 | `MaterialDashboardView.swift` | 新增 `@State cardVisible[6]`；`triggerCardStagger()` 禁止动画瞬间置 false + 每张卡 i×0.05s 延迟 spring 回 true；每张卡添加 `.opacity/.scaleEffect(0.85)` 响应；stacked card 点击切换同时调用 `triggerCardStagger()` |

## 第四十章 Material UI 全页面统一（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT40-SETTINGS | SettingsView Material 化 | `SettingsView.swift` | `isMaterial` 开关：背景 `#F5F5F7`/`#0A0A0C`；`glassCard` 改白色 RR24+shadow；`settingsSection` 标题改白色胶囊 pill；`accentColor` → `#FF5A00`；toolbar 改自定义 xmark 圆按钮 + "Settings" 左侧大标题 |
| MAT40-CALENDAR | CalendarView Material 化 | `CalendarView.swift` | `chipAccent`=橙色；背景切换；chip 选中橙色+白字；`iconModeBtn` 选中橙色；月历/周预览选中日橙色背景白字；时间轴今日点橙色；`ambientLightBlobs` material 模式下隐藏 |
| MAT40-CREW | CrewRosterOverlay Material 化 | `Home/CrewRosterOverlay.swift` | Material 模式关闭 `IslandMoodWeatherView`；搜索栏改白色 RR16+shadow；`dexSectionLabel` 改白色胶囊 pill（橙色计数）；`addNewLifeButton` 橙色 accent + 白色实线边框 |
| MAT40-OASIS | OasisRewardView Material 化 | `Home/OasisRewardView.swift` | 背景切换；`bentoMiniCard` 改白色底+淡灰描边+shadow；`injectEnergyButton` 可用态橙色+阴影，不可用态白底+橙描边 |

## 第三十九章 Material Dashboard 对齐 React 参考 UI（2026-03-19）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT39-HEADER | Header 改为3按钮布局 | `MaterialDashboardView.swift` | 左：Settings 齿轮；右：Plus(橙色) + Bell；移除日期/问候文字显示位置 |
| MAT39-GREETING | Greeting 大标题 | `MaterialDashboardView.swift` | 新增 `greetingSection`：两行大字 "Hi [ownerName]," + "Welcome\nHome!"（size 38, rounded） |
| MAT39-STACKED | 恢复3D堆叠宠物卡 | `MaterialDashboardView.swift` | 替换横向头像选择器；前3只宠物以 scale(0.06×offset)、y(30×offset)、rotation(±4°) 堆叠；点击最顶层卡循环切换；宠物照片全填充+暗色渐变遮罩；名字50pt黑体 |
| MAT39-SECTION | Actions 区标签 | `MaterialDashboardView.swift` | 新增 `actionsSectionHeader`："{pet.name}'s Actions" 白色圆角胶囊标签 |
| MAT39-FEED | Feeding/Litter 卡视觉修正 | `MaterialDashboardView.swift` | 容器改为透明；上半 `MatTopRoundedRect`+下半 `MatBottomRoundedRect` 分别为白色；中间 2pt 缝隙；Litter 上半以 bottomTrailing 锚点旋转 |
| MAT39-WEIGHT | 恢复 Weight 全宽卡 | `MaterialDashboardView.swift` | 全宽水平卡(80pt)：scalemass 图标 + 实际体重日志最新值 + 箭头 |
| MAT39-WALK | Walk 卡 3D flip + History | `MaterialDashboardView.swift` | 紧凑态：前面(橙色+Start)↔背面(天空山脉场景+计时器+进度条+Pause/Stop)；展开态：步行历史列表 |
| MAT39-OVERVIEW | 恢复 Global Overview | `MaterialDashboardView.swift` | 图表区含 Section 标签 + 白色 RR32 卡片 + Swift Charts 双折线/面积图(Expenses orange + Activity blue) |
| MAT39-SHAPES | 新增自定义 Shape | `MaterialDashboardView.swift` | `MatTopRoundedRect`、`MatBottomRoundedRect`(仅两个对角圆角)、`MatTriangle`(山脉装饰) |

## 第三十八章 Material Dashboard 完整重构（2026-03-18）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MAT-HEADER | Header 重构 | `MaterialDashboardView.swift` | 移除旧 matTopBar + matGreeting；新 matHeader：左侧日期("EEEE, d MMM") + 动态问候("Good Morning/Afternoon/Evening")，右侧齿轮设置按钮 |
| MAT-SELECTOR | 横向 Pet Selector | `MaterialDashboardView.swift` | 替换旧 matStackedCards；新 petSelectorRow：ScrollView(.horizontal) 圆形头像(w:64)，选中态橙色描边(3px) + scale(1.1)，未选态 opacity(0.7)，末尾虚线圆形"+"按钮 |
| MAT-GRID | 2列 Activity Grid | `MaterialDashboardView.swift` | 替换旧 HStack Row 布局；使用 VStack+HStack 实现：第1行 Feeding+Water，第2行 Litter+Expenses，第3行 Walk(全宽)；喂食卡展开时单独占全宽隐藏其他3张 |
| MAT-FEED | Feeding Card 展开 | `MaterialDashboardView.swift` | 1x1↔2x1 展开，紧凑态 Split Lid 动画(上半偏移-12/下半偏移+12)，展开态显示宠物名+食量统计+标记已喂食按钮；FoodParticleView 深棕色圆粒掉落 |
| MAT-WATER | Water Card 波浪 | `MaterialDashboardView.swift` | 新增 MatWaveView + MatWaveShape；两层半透明蓝色波形(4A90E2)持续水平移动，点击触发水位上升+水滴粒子掉落 |
| MAT-LITTER | Litter Card 盖子 | `MaterialDashboardView.swift` | 点击触发盖子(顶部 HStack)以 bottomTrailing 为锚点旋转15°，同时 PoopParticleView 💩粒子掉落 |
| MAT-EXP | Expenses Card 金币 | `MaterialDashboardView.swift` | 点击触发 creditcard 图标弹跳(scale:1.15, y:+5)，FFCC00 金色圆形硬币从图标弹起(-52pt) fade in/out |
| MAT-WALK | Walk Card 3D Flip | `MaterialDashboardView.swift` | 2x1(110pt)→2x2(340pt)展开；点击 Start 触发 rotation3DEffect X轴180° flip：前面(橙色+Start按钮)→背面(天空场景+实时计时器+公里数+Stop按钮)；Stop后翻回并展示 Walk Complete 总结屏 |
| MAT-PARTICLES | 新增粒子类型 | `MaterialDashboardView.swift` | 新增 PoopParticleView(💩)；重构 FoodParticleView/WaterParticleView 使用实例属性(避免 static random 重用) |

## 第三十七章 双 UI 体系：Material Dashboard（2026-03-18）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| MATERIAL-DASH | 新建 Material Dashboard 视图 | `MaterialDashboardView.swift`（新建） | 完整复现 React `Ai_Studio_New_UI` 设计：#F5F5F7 浅灰背景 + 纯白圆角32卡片 + #FF5A00 橙色主题；包含：顶部栏(齿轮/+/铃铛)、问候语、3D 堆叠宠物卡、2×2 Bento 操作格(喂食/喝水/清洁/花销) + 全宽体重卡 + 全宽橙色遛狗卡、全局概览折线图(Swift Charts)、悬浮药丸底部导航(首页/日历/🥥 FAB/图鉴/绿植) |
| MATERIAL-ROUTE | ContentView 双 UI 路由 | `ContentView.swift` | 新增 `@AppStorage("appUIStyle")` 变量；`appUIStyle == "material"` 时渲染 `MaterialDashboardView`，否则渲染原 `OverviewView`；NavigationDestination 保持共享 |
| MATERIAL-SETTING | 设置页 UI 风格切换 | `SettingsView.swift` | 偏好设置 → 外观主题下方新增「UI 风格」区块：两张预览卡（经典 / Material）用 `UIStyleCard` 组件呈现；选中卡高亮对应 accentColor 描边；新增 `UIStyleCard` private struct |

## 第三十六章 首页信息层级重构（2026-03-17）

| ID | 内容 | 修改文件 | 说明 |
|----|------|----------|------|
| HOME-REORDER | 首页模块顺序重组 | `OverviewView.swift` | 新顺序：快捷操作 → 批量打卡 → 今日任务 → 岛屿总览 → 记忆碎片 → 岛屿统计；将 memoryDrop 从硬编码顶部移入 section 系统，沉至底部作情感分割带；islandStats 下沉至最底 |
| HOME-ALERT | 紧急健康警告 Banner | `OverviewView.swift` | 新增 `emergencyAlertBanner`：Wallet Stack 与快捷操作之间，仅当有 `.urgent` 级别警告时显示；Color.goRed 实色背景，.white 粗体字，无 glassEffect，支持 prefix(3) 最多展示 3 条 |
| HOME-MIGRATION | section 迁移逻辑升级 | `OverviewView.swift` | `sectionOrderRaw` 默认值更新；旧用户若无 `memoryDrop` section 则强制重置为新标准顺序；新增 `memoryDrop` 到 allIds |
| HOME-MANAGE-SHEET | 首页管理面板更新 | `OverviewHelperViews.swift` | `HomeSectionEntry.defaults` 新增 memoryDrop 条目（粉色心形图标）；条目顺序与新产品动线对齐 |
| HOME-SPACING | 首页间距调整 | `OverviewView.swift` | VStack spacing 从 24 改为 20；去掉宠物卡片与其他卡片之间的硬编码 Spacer(height:24) |

## 第三十五章 PetWalletStack 行为修复 & 全页面 iOS 26 glassEffect 统一（2026-03-16）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| STACK-BEHAVIOR | 首页卡片堆滑动行为修正 | `PetWalletStack.swift` | 上/下滑前卡时，改为将当前卡移到堆末尾（activeIndex+1 mod count），而非之前的循环到最前 |
| DETAIL-TOOLBAR | 宠物详情页工具栏位置 | `PetDetailView.swift` | 编辑/日历/即养卡三个按钮 (`petToolbar`) 从 NavigationBar 移到 Hero 卡片上方（ScrollView 内顶部）；同步移除 NavigationBar 里的 CoconutBalanceCapsule（已包含在 petToolbar 中） |
| DETAIL-CHART-BG | Chart 仪表盘去背景 | `PetDetailView.swift` | `PetChartDashboard` 外层去掉 UltimateGlassCard 包裹，直接渲染无背景 |
| DETAIL-HYGIENE | 护理卡片移除内部背景 | `PetHygieneCard.swift` | 移除 `UltimateGlassCard` wrapper，由外层 `PetDetailView` 的 glassEffect 提供背景；同步修复多出的尾部括号 |
| DETAIL-COMPACT | 三列紧凑卡圆角减小 | `PetDetailView.swift` | `compactDocumentsCard`、`compactMemoriesCard`（原里程碑）、`compactAchievementsCard` cornerRadius 由 24 改为 16 |
| DETAIL-MEMORIES | 里程碑改名+快捷添加 | `PetDetailView.swift` | `compactMilestonesCard` 重命名为 `compactMemoriesCard`，标题改为"回忆录"，右上角添加 goLime + 按钮；点击 NavigationLink 直接进入 `PetMilestoneListView` |
| DETAIL-TIMELINE | 岁月史书标准卡片背景 | `PetDetailView.swift` | `PetUnifiedTimeline` 改用 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))` 替代旧背景 |
| WEIGHT-UI | 体重追踪页深/浅色模式 | `WeightHistoryView.swift` | `recordListLayer` 背景改为 `.regularMaterial`；行卡片改用 `.glassEffect(cornerRadius: 16)`；拖动把手由 `.black.opacity(0.12)` 改为 `.primary.opacity(0.15)`；add sheet 添加 `.presentationBackground(.regularMaterial)` |
| POTTY-UI | 噗噗电台深/浅色模式 | `PottyOverviewView.swift` | `recordListLayer` 背景改为 `.regularMaterial`；行卡片改用 `.glassEffect`；把手颜色适配 |
| EXPENSE-UI | 花费记录页 UI + 玻璃 add sheet | `ExpenseHistoryView.swift` | `recordListLayer` 背景 `.regularMaterial`；行卡片 `.glassEffect`；`addExpenseSheet` 金额框/备注框改 `.glassEffect`；sheet 底色 `.presentationBackground(.regularMaterial)`，detents 改为 `.medium, .large` |
| FOOD-UI | 饮食管理页面 glassEffect 统一 | `PetFoodManagementView.swift` | 所有 `.white.opacity(0.04/0.06/0.08)` 卡片背景替换为 `.glassEffect(cornerRadius: 16/20)`；`FoodReminderSheet` 背景改 `.presentationBackground(.regularMaterial)` |
| HEALTH-UI | 免疫健康页面深/浅色适配 | `PetHealthDetailView.swift` | `immunityOverviewRow`、`healthTrendCard`、`healthLogsCard`、`alertsSection` 全部改为 `.glassEffect`；未记录状态颜色由 `.white.opacity(0.3)` 改为 `.primary.opacity(0.3)`；逾期颜色修正为 `Color.goRed` |

## 第三十四章 首页宠物卡片 Wallet 堆叠重构 + 玻璃背景修复（2026-03-16）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| WALLET-STACK | 首页宠物卡片 iOS Wallet 堆叠 | `PetWalletStack.swift`(新), `ContentView.swift`, `OverviewView.swift` | 替换 `CritterDeckCarousel` 横向 TabView 为 ZStack Wallet 堆叠布局：**下边卡片在最前面(zIndex最高)，上边在最后面**；后牌 Y 偏移 56pt + scaleEffect 0.98 + brightness -0.05 衰减；active 卡片在最底部全尺寸可交互；顶牌上下拖拽切换(highPriorityGesture 不与页面 ScrollView 冲突)；分页指示器保留 |
| HERO-ZOOM | App Store Today 英雄展开动画 | `ContentView.swift`, `PetWalletStack.swift` | 使用 iOS 18+ `matchedTransitionSource(id:in:)` + `navigationTransition(.zoom(sourceID:in:))` 实现原生 App Store Today 卡片展开过渡；`@Namespace` 从 ContentView 传递到 OverviewView → PetWalletStack |
| CARD-VISUAL | Wallet 卡片视觉 GO UI 蓝橙配色 | `PetWalletStack.swift` | `WalletPetCardFront`: GO UI 蓝色渐变底(#233BFF→#141FAE) + **橙色(#FF5A3D)**超大背景名字**锚定卡片顶部**(堆叠时漏出的部分可见) + 左侧头像/剪影 + 右侧信息列 + 条码；`WalletHumanCardFront`: 同蓝底 + teal 配色 + 顶部大字 |
| DETAIL-HERO | 详情页顶部卡片统一 | `PetDetailView.swift` | 替换 `PetHeroRow` 为 `WalletPetCardFront`，与首页 Wallet 卡片同款视觉，zoom 过渡自然衔接；点击跳转宠物基本信息页 |
| DETAIL-GLASS | 详情页卡片标准背景统一 | `PetDetailView.swift` | `PetChartDashboard` 横滚图表仪表盘包裹 `UltimateGlassCard` 标准背景；其余卡片(健康/护理/饮食/活动/证件/里程碑/成就/时间轴)已全部使用 `UltimateGlassCard` |
| STREAK-FIX | 首页打卡连击天数修复 | `HomeBentoBoxes.swift`, `DailyStreakDetailView.swift` | 从独立 `loginStreak` AppStorage 改为基于 `oasis_checkedIn_dates` 倒推计算真实连续天数；日期格式统一为 `yyyy-MM-dd` + TimeZone.current |
| GLASS-SETTINGS | 设置页玻璃卡片修复 | `SettingsView.swift` | 修复 `glassCard` 函数作用域错误（从 BackgroundStyleCard 移回 SettingsView 结构体内部）；添加 `reduceTransparency` 无障碍降级 |
| GLASS-BG | GoGlassBackground 新增 | `OhanaDesignSystem.swift` | 新增 `GoGlassBackground` ViewModifier（深蓝渐变 + ultraThinMaterial 叠加 + 白色描边 + 阴影）+ `.goGlassBackground()` View extension；Dock 栏改用 goGlassBackground |

## 第三十三章 UI 规范化系统 & 全岛体重过滤修复（2026-03-15）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| UI-SHORTHAND | iOS 26 设计口号系统 | `iOS26_Design_Guide.md` | 新增第十四章「Ohana 背景口号系统」，定义四种标准背景：卡片标准背景（UltimateGlassCard 8层折射）、玻璃背景（.glassEffect 原生API）、内嵌背景（.white.opacity(0.08)）、纯色背景（实色CTA），附详细参数和使用决策树 |
| UI-TEST-DEMO | iOS 26 UI 测试页背景对比 | `iOS26UITestView.swift` | 新增 `cardBackgroundComparison` 卡片，展示四种背景口号的实际效果：生命之树卡片、Dock栏+胶囊+圆形按钮、内嵌 Bento 格、主要按钮+危险操作 |
| BATCH-GRID-UI | 一键全家改为网格布局 | `OverviewView.swift` | 将 `batchCheckInBar` 从玻璃胶囊条重构为与快捷操作一致的网格布局：标题+管理按钮+LazyVGrid(4列)；`batchGridCell` 匹配 `GoQuickActionCard` 视觉（无背景icon、打卡后goLime、subtitle显示"已完成"/"全家"）；删除死代码 `batchBentoCell` |
| WEIGHT-HUMAN-FILTER | 全岛体重过滤已关闭人类 | `IslandWeightDashboard.swift` | 新增 `visibleHumans` 计算属性过滤 `shouldShowOnHome==false` 的人类；`totalIslandWeightKg`、`buildSparklineEntries()`、`vm.load()` 三处均使用 `visibleHumans` 替代 `humans`，确保隐藏人类不出现在体重统计中 |

## 第三十二章 UI/UX 精修 & Bug 修复（2026-03-15）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| BATCH-GLOW | 一键全家按钮打卡后保持荧光 | `OverviewView.swift` | `batchPillButton` / `batchBentoCell` 新增 `isBatchDoneToday` 判断，打卡完成后 isHighlighted 保持高亮（goLime 背景/黑色文字），不再只在动画期间高亮 |
| FLIP-MIRROR | 修复卡片翻转镜像 bug | `ArkCrewIDCardView.swift`, `CritterDeckCarousel.swift` | 背面卡使用 `scaleEffect(x: -1, y: 1)` 替代 `rotation3DEffect(.degrees(180))`，避免镜像闪烁；延迟 0.18s 切换正反面 opacity |
| COCONUT-BTN | 日历页椰子按钮完整显示 | `OhanaDesignSystem.swift` | `CoconutBalanceCapsule` 添加 `.fixedSize(horizontal: true, vertical: false)` 防止父容器压缩截断 |
| MED-FREEZE | 修复人类详情页吃药提醒卡死 | `HumanMedicationView.swift` | 移除整个视图级别的 `.animation()` 修饰符，toast 动画改由显式 `withAnimation` 控制 |
| HUMAN-UI-GLASS | 人类详情页卡片改为 glassEffect | `HumanDetailView.swift` | 所有 `UltimateGlassCard` 替换为 `.glassEffect(.regular, in: RoundedRectangle(...))` 与首页 BentoStatCard 风格一致；statsBento mini 卡片同步迁移 |
| CREW-CARD-MINI | Ohana Crew 卡片等比缩小 | `CrewRosterOverlay.swift` | `PetSquareCard` 改为首页 `posterFront` 等比缩小版：蓝色渐变底 + 橙红大字 + 左侧头像（透明抠图/普通照片羽化/剪影三种方案）；去掉所有文字；宽高比从 1:1 改为 1.586:1 |
| EXPENSE-EMPTY-PIE | 全岛花费页无数据显示 pie chart | `IslandExpenseDashboard.swift` | `expenseFloatingHeader` 无论有无数据都显示 pie chart 区域；无数据时显示灰色空心环 + "暂无数据" 文字 + 右侧引导文案 |
| BATCH-ICON-ONLY | 批量打卡仅图标变色 | `OverviewView.swift` | `batchBentoCell` 修改为打卡后仅图标和文字变色（goLime），卡片背景保持不变，避免视觉干扰 |
| WALK-LIVE-PANEL | 遛狗中显示实时面板 | `ArkCrewIDCardView.swift` | 卡片背面在 `isActiveWalk` 时显示 `walkLivePanel` 替代普通仪表盘，已应用 `.glassEffect` |
| CARD-FLIP-SPRING | 卡片翻转动画优化 | `ArkCrewIDCardView.swift` | 使用 `spring(response:0.5,dampingFraction:0.82)` 替代 `easeInOut`，延迟 0.22s 切换正反面，提升物理感 |
| ISLAND-STATS-CLEAN | 岛屿统计布局清理 | `OverviewView.swift`, `IslandStatComponents.swift` | 移除财富榜前多余分隔线；财富榜显示从 Top 4 改为 Top 3 |
| PET-SILHOUETTE-HALF | 宠物剪影缩小一半 | `CrewRosterOverlay.swift` | `PetSilhouetteView` 缩放从 0.82 改为 0.42，避免视觉过重 |
| HUMAN-SHOW-RENAME | 人类显示开关重命名 | `HumanDetailView.swift`, `OverviewView.swift` | "在首页卡堆显示" 改为 "在首页显示"；隐藏时从岛屿体重统计头像中排除 |
| WEALTH-SYSTEM-TOGGLE | 财富页系统椰子开关 | `IslandWealthViewModel2.swift`, `IslandWealthDashboard2.swift` | 添加 `showSystemCoconuts` 开关，过滤图表中系统生成的椰子记录 |
| NAN-COREGRAPHICS | NaN 渲染错误修复 | `HumanDetailView.swift`, `CoHealthDashboardView.swift` | 所有权重显示添加 `.isFinite` 检查，防止 NaN 导致 CoreGraphics 崩溃 |
| MEDICATION-CRASH | 吃药提醒导航崩溃修复 | `HumanDetailView.swift` | 将 `navigationDestination` 改为 `.sheet`，避免多导航目标冲突 |

## 第三十一章 Header 重构 & 打卡连击修复 & 身体检测报告（2026-03-15）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| HDR-REFACTOR | 全局 Header 去背景 + 按 tab 定制按钮 | `OverviewView.swift`, `CalendarView.swift`, `CrewRosterOverlay.swift`, `OasisRewardView.swift` | 移除 header 半透背景；首页保留椰子+头像菜单；日历：视图切换+添加日程+椰子；图鉴：搜索+添加岛民+椰子；绿洲：规则+百宝箱+椰子。子视图新增 `hideToolbar`+trigger 参数，@AppStorage 共享 viewMode |
| MAKEUP-COUNT | 补签卡包购买数量 bug | `CoconutShopView.swift` | 购买1个补签包从 +3 改为 +1 |
| MAKEUP-REFRESH | 购买补签卡后立即刷新 | `DailyStreakDetailView.swift` | `.onChange(of: showCoconutShop)` 关闭商店时重载打卡数据 |
| MAKEUP-STATS | 补签后顶部卡片统计不更新 | `DailyStreakDetailView.swift` | 顶部卡片从 `loginStreak` 改为 `currentStreak`（含补签），里程碑进度条同步 |
| MAKEUP-POS | 补签确认框位置太高 | `DailyStreakDetailView.swift` | 从 `.confirmationDialog` 改为 `.alert`，居中显示 |
| STREAK-REWARD | 连胜奖励不消失+金额太少 | `DailyStreakDetailView.swift`, `OasisRewardView.swift` | `@AppStorage("checkIn_lastClaimedMilestone")` 替代 UserDefaults 直接读写，领取后 UI 即时刷新；奖励从 3/5/10/20/50 提升至 10/25/60/150/300 |
| STREAK-COCONUT | 打卡连击页显示椰子按钮 | `DailyStreakDetailView.swift` | toolbar 加入 `CoconutBalanceCapsule` + 椰子日志 sheet |
| HEALTH-REPORT | 身体检测报告功能 | `HumanHealthReport.swift`(新), `HumanHealthReportView.swift`(新), `HumanDetailView.swift`, `SharedModelContainer.swift` | 新增 `HumanHealthReport` SwiftData 模型（9种报告类型 + 4级结论）；`HumanHealthReportView` 列表+添加/编辑；Schema 升级至 ArkSchemaV22 |

### 待做

| ID | 内容 | 优先级 |
|----|------|--------|
| i18n-full | 多语言支持全量接入 | 高 |

## 第三十章 UI/动画优化 & 批量打卡修复 & 卡片布局重构（2026-03-15）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| CHART-PERF | 图表动画去卡顿 | `IslandStatComponents.swift` | MiniBarChart / MultiPetExpenseBar / MiniRingChart 的 `playAnimation()` 从 `spring(response:0.6)` 改为轻量 `easeOut(duration:0.28~0.3)`，减少 GPU 弹性计算开销 |
| CHART-REVEAL | 补完剩余图表 reveal 动画 | `CoHealthDashboardView.swift`, `PetHealthDetailView.swift` | 体重对比 Chart 和健康散点 Chart 新增 `chartRevealProgress` / `scatterRevealProgress` 状态 + 从左到右 mask reveal 动画（easeOut 0.38~0.42s） |
| BATCH-TOAST | 批量打卡 toast 椰子数一致 | `OverviewView.swift` | `performBatchAction` 计算真实 `coconutDelta` 后调 `showBatchToast("全家X +N🥥", emoji:"🥥")`，不再使用静态 `action.toastMessage`；`showBatchToast` 新增 `emoji` 参数 + 防覆盖逻辑 |
| BATCH-ICON | 批量打卡 icon 变色 | `OverviewView.swift` | `batchPillButton` / `batchBentoCell` 高亮时间从 0.35~0.6s 延长到 1.1s，先设 `batchPressedId` 再异步执行 `performBatchAction`，确保用户看到 goLime 变色反馈 |
| CARD-LAYOUT | 首页卡片布局重构 | `ArkCrewIDCardView.swift` | `posterFront` 重写：背景大字移到上半居中，头像 `posterSubjectLayer` 贴左半边缘（透明抠图/普通照片/剪影三种方案均居左），文字信息列右对齐 |
| CARD-FLIP | 翻转动画物理化 | `ArkCrewIDCardView.swift` | `rotation3DEffect` 加 `perspective: 0.4` 透视感，动画从 `spring(response:0.6)` 改为 `easeInOut(duration:0.4)`，模拟真实翻卡 |
| CREW-GRID | Ohana Crew 两列小卡 | `CrewRosterOverlay.swift` | `BentoPetGrid` / `BentoHumanGrid` 改为 `LazyVGrid` 两列；`PetSquareCard` / `HumanSquareCard` 改为紧凑小卡（120pt 头像区 + 名字），单击直接触发 `onSelect` 进详情，长按删除保留 |

## 第二十九章 首页海报卡精修 & Crew 卡片统一（2026-03-15）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| CARD-POSTER-REFINE | 首页海报卡背景字/锚点精修 | `ArkCrewIDCardView.swift` | `posterFront` 的背景大字改为仅显示宠物名，不再叠第二行物种/品种字；底部信息锚点保留条码区，移除右下圆形 seal，使版面更干净 |
| CARD-PHOTO-BLEND | 普通照片与海报卡背景融合优化 | `ArkCrewIDCardView.swift` | 普通照片主体由“独立圆角照片块”改为“模糊氛围底 + 羽化主体图层”双层方案，通过横向渐隐 mask、轻微 screen 高光和主题色混合，让图片更自然融入蓝色海报底 |
| CREW-CARD-UNIFY | Ohana Crew 卡片与首页统一 | `CrewRosterOverlay.swift`, `CritterDeckCarousel.swift`, `ArkCrewIDCardView.swift` | `CrewRosterOverlay` 的宠物/人类区不再维护旧的 square card 视觉分支，直接复用 `ArkCrewIDCardView` / `HumanIDCardView`，从而与首页保持一致的海报卡 UI 和后续演进链路 |

## 第二十八章 宠物卡片 GO 海报化重设计（2026-03-15）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| CARD-POSTER | 宠物卡正面改版为 GO 海报卡 | `ArkCrewIDCardView.swift` | `cardFrontView` 非 minimal 分支统一切到 `posterFront(geo:avatarImage:isTransparent:)`；采用蓝底 + 橙红超大背景字（宠物名/物种）+ 中右主视觉主体 + 左下信息锚点布局；大数字主信息固定为 `daysTogether`，副文案为年龄/品种；底部加入条码区与圆形 seal，整体风格参考 GO 运动卡片 |
| CARD-SUBJECT | 无头像/有头像主视觉统一 | `ArkCrewIDCardView.swift`, `PetSilhouetteView.swift` | 透明 PNG 头像使用贴纸白边主体；普通照片使用右侧倾斜圆角图卡；无头像时改用 `PetSilhouetteView` 作为主角色，不再退化为简单 emoji |
| CARD-PAGE | 首页卡片切换方式重构 | `CritterDeckCarousel.swift` | 从纵向轮盘式卡组改为横向分页 `TabView(.page)` 焦点卡；保留底部分页指示器和“全部成员”入口；`activeIndex` 切换时自动重置翻面状态，并同步 `onTopCardChanged` |
| CARD-UX | 卡片排列策略升级 | `CritterDeckCarousel.swift`, `OverviewView.swift` | 首页采用“单卡聚焦 + 分页点 + 次级全部入口”的层级，不再让上下叠卡分散注意力；更适合宠物大图、海报字和强主视觉展示 |

## 第二十七章 打卡日历完善 & 全局固定前置层 & i18n 基础设施（2026-03-11）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| R6 | 全局固定前置层 | `OverviewView.swift`, `CalendarView.swift`, `CrewRosterOverlay.swift`, `OasisRewardView.swift` | 新增 `globalFixedHeader` glass overlay 覆盖 4 个 tab，动态标题/菜单；子视图隐藏原生 navigationBar，添加顶部占位间距；CalendarView 工具栏移入 body；CrewRosterOverlay 添加按钮移入搜索栏旁；OasisRewardView 去掉冗余 header |
| i18n-base | 多语言基础设施 | `Localization.swift`(新), `OverviewView.swift`, `OverviewHelperViews.swift` | 新建 `L10n` struct，100+ 翻译 key（tab/greeting/settings/pet/human/calendar/common）；OverviewView globalFixedHeader 接入 L10n；FloatingDockNav tab 标签本地化 |
| CK-FIX | 补签包 key 不匹配 bug | `OasisRewardView.swift` | `makeupPackKey` 从 `oasis_makeup_pack_count` 改为 `inventory_backdate_1day_count`（与椰子商店 `CoconutShopView.activateBoost` 统一） |
| CK-CAL | 打卡日历月视图重写 | `OasisRewardView.swift` | 新增 `CalendarCell` 模型 + `monthCalendarCells(for:)` 按星期正确对齐；月份导航（上/下月切换，禁止翻到未来月）；`calendarDayCell` 支持补签视觉区分（黄色 + 回退图标 vs 青柠 + 勾） |
| CK-STATS | 打卡统计面板 | `OasisRewardView.swift` | 新增 `checkInStatsRow`（总打卡/当前连胜/最长连胜/本月打卡率 4 格），各配独立 SF Symbol + 彩色 |
| CK-MILE | 连续打卡里程碑奖励 | `OasisRewardView.swift` | 新增 `checkInMilestoneRow`，5 档里程碑（7天+3🥥 / 14天+5🥥 / 30天+10🥥 / 60天+20🥥 / 100天+50🥥）；可领取时显示 goLime 按钮；`claimMilestone` 发放椰子 |
| CK-MAKEUP | 补签日期独立记录 | `OasisRewardView.swift` | 新增 `makeupDates: Set<String>` + `makeupDatesKey`；`applyMakeup` 同时写入 checkedInDates 和 makeupDates；补签包不足时显示"去商店购买 →"按钮跳转椰子商店 |
| CK-BENTO | 绿洲 Bento 打卡入口 | `OasisRewardView.swift` | `oasisBentoGrid` 新增第三行全宽打卡日历卡（显示连胜/总天数），点击打开打卡日历 sheet |

### 待做

| ID | 内容 | 优先级 |
|----|------|--------|
| i18n-full | 多语言支持全量接入（PetDetailView/HumanDetailView/SettingsView/CalendarView 等） | 高 |

## 第二十六章 详情页 UI 优化 & 背景系统 & ArkBackgroundView 重构（2026-03-11）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| BG | 背景系统重构 | `ArkBackgroundView.swift`, `SettingsView.swift` | 新增 `AppBackgroundStyle` 枚举（goDefault/deepAmbient/aurora/midnight 四种风格）；每种风格独立 View 组件（GoDefaultBackground/DeepAmbientBackground/AuroraBackground/MidnightBackground）；通过 `@AppStorage("appBackgroundStyle")` 持久化切换；设置页新增横滚背景风格预览卡（`BackgroundStyleCard`），goLime 选中高亮 |
| PD-UI | 宠物详情页 Hero 增强 | `PetDetailView.swift` | PetHeroRow 无头像时使用 `PetSilhouetteView` 作为 fallback（根据 pet.coatColor/eyeColor 着色）；头像遮罩优化（130px、0.85渐变边界）；hero 高度 140→152，圆角 20→24；工具栏按钮增加彩色图标区分（编辑 goLime / 日历 goCardCyan / 寄养卡 goYellow） |
| HD-UI | 人类详情页 UI 现代化 | `HumanDetailView.swift` | heroCard 从 UltimateGlassCard 改为渐变卡片（themeColor→goDarkBlue）+ 装饰光球；头像区域改为白色半透明底 + emoji；Stats Bento 从横排单行改为 4 个独立 UltimateGlassCard 迷你卡（带 SF Symbol 图标）；Section Header 增加 goLime 竖线装饰 + 加大 tracking |
| AUR-FIX | AuroraBackground 类型修复 | `ArkBackgroundView.swift` | 修复 CGFloat/Double 歧义：`.degrees()` 参数包裹 `Double()` 显式转换 |

### 待做

| ID | 内容 | 优先级 |
|----|------|--------|
| R6 | 全局固定前置层（透明玻璃背景，4个页面保持不动） | 高 |
| i18n | 多语言支持(中英)：设置切换全局语言，'ohana'不翻译 | 高 |

## 第二十五章 Pet Silhouette 精修 & UI 全面优化（2026-03-11）

| ID | 内容 | 修复文件 | 说明 |
|----|------|----------|------|
| R1 | 交互式颜色选择（点击剪影选色） | `AddPetWizardView.swift` | `stepAppearance` 完全重写：新增 `showCoatSheet`/`showEyeSheet` 状态；`PetSilhouetteView` 新增 `onTapCoat`/`onTapEye` 闭包；点击身体→毛色选择 sheet，点击眼睛→瞳色选择 sheet；新增 `ColorPickerSheet` 内嵌结构体（5列圆形色格 + 颜色名 + 自定义）|
| R2 | PetSilhouetteView 视觉修复 | `PetSilhouetteView.swift` | 猫耳嵌入头部不再分离；五官下移；狗眼间距缩小；添加眨眼/耳朵摇摆/狗舌头动画 |
| R3 | PetBreedDatabase 颜色数据补全 | `PetBreedDatabase.swift` | 全面替换 dogBreeds/catBreeds 颜色数据为精确 hex；genericCoatColors 新增深灰/浅灰/红棕等；genericEyeColors 新增冰蓝/翠绿/红色等；所有品种使用品种专属 `CoatColor`/`EyeColor` 实例（不再用字符串 coats()/eyes() helper） |
| R4 | 快捷操作添加页 icon 去背景 + 页面缩小 | `OverviewQuickActions.swift` | icon 去掉彩色圆角背景，改为纯彩色 icon（28pt）+ 标签；按下时仅有 0.1 透明度背景反馈；`presentationDetents` 改为 `.height(380)` 优先 |
| R5 | 一键打卡 UI 无背景+goLime高亮 | `OverviewView.swift` | `batchPillButton` 重写为 emoji + 文字纵排，默认文字灰色无背景，点击瞬间 goLime 高亮 + 圆角矩形背景，0.6s 后淡出 |
| R6 | 首页 header Liquid Glass | `OverviewView.swift` | `goGreetingHeader` 添加 `.background(.ultraThinMaterial.opacity(0.7))` 圆角毛玻璃背景，与 docker 视觉一致 |
| R7 | 全局椰子数卡片 goLime 背景 | `OhanaDesignSystem.swift` | `CoconutBalanceCapsule` 背景从 `.ultraThinMaterial` + goYellow 边框改为纯 `Color.goLime`，文字黑色 |
| R8 | QA体重卡片/图表确认 | `ArkCrewIDCardView.swift` | 确认体重 sparkline 已使用 `pt.weight` 实际体重曲线；`glanceSubtitle` 已显示最新体重值（`"%.1f kg"`）；无需修改 |
| R9 | 财富页 navBar 与 filter 不重叠 | `IslandWealthDashboard2.swift` | `navBar` 统一使用 VStack + `padding(.top, 56)`；`chartArea` padding(.top) 改为 120 确保 filter 不被遮挡 |
| R10 | 花费页 Bento 卡片去彩色背景 | `IslandExpenseDashboard.swift` | `topPetCard`/`topCategoryCard` 去掉 RadialGradient 彩色背景和彩色边框，改为 `.white.opacity(0.06)` 半透明深色统一风格 |

### 待做

| ID | 内容 | 优先级 |
|----|------|--------|
| R11 | 全局顶部 header（固定位置+切换动效）| 低（复杂架构改动，评估中）|
| F8 | 宠物卡背面信息去掉从上到下动画，直接显示 | 中 |
| F9 | 宠物详情页 UI 按 iOS26_Design_Guide.md 更新 | 中 |

## 第二十四章 Bug Fix & 新功能（2026-03-11）

| ID | 问题 | 修复文件 | 说明 |
|----|------|----------|------|
| F6 | 财富页更名+导航改 fullScreenCover | `IslandWealthDashboard2.swift`, `IslandStatComponents.swift`, `OverviewView.swift` | navBar 标题改为"Ohana财富"；`CoconutWealthRankingCard` 从 `NavigationLink` 改为 `Button + onTap` 回调；OverviewView 新增 `showIslandWealth` 状态 + fullScreenCover 展示；宠物主题色已在之前 session 中通过 `Color(hex:)` 修正 |
| F7 | 快捷操作体重弹窗卡片太小 | `OverviewView.swift` | `QuickWeightSheet` 的 `.presentationDetents` 从 `.height(280)` 改为 `[.medium, .large]`，标题和内容完整显示 |
| F11 | 毛色/瞳色选择页互动宠物剪影 | `PetSilhouetteView.swift`(新), `AddPetWizardView.swift` | 新建 `PetSilhouetteView` 组件，用 SwiftUI Path 绘制猫/狗/通用剪影（身体+耳朵+眼睛+面部细节），支持眨眼/耳朵摇摆/狗舌头伸缩动画；`stepAppearance` 顶部加入实时预览，选毛色/瞳色即时变化颜色；新增 `resolvedCoatColor`/`resolvedEyeColor` 计算属性将颜色名映射为 Color |

### 待做

| ID | 内容 | 优先级 |
|----|------|--------|
| F8 | 一键打卡无椰子动画+UI改为无背景icon+打卡变色+显示已打卡次数 | 中 |
| F9 | 宠物卡背面信息去掉从上到下动画，直接显示 | 中 |
| F10 | 宠物详情页UI按iOS26_Design_Guide.md更新 | 中 |

## 第二十三章 Bug Fix & UX 优化（2026-03-11）

| ID | 问题 | 修复文件 | 说明 |
|----|------|----------|------|
| E1 | 日历左滑即删（未确认就删除） | `SwipeableEventRow.swift` | 右滑改为调 `pendingDelete()`：回弹到原位 + 弹 `confirmationDialog`；确认后才调 `triggerDelete()` 真正删除；重复事件显示"删除此条 / 删除此条及之后" |
| E2 | 快捷操作无法便捷添加 | `OverviewView.swift`, `OverviewQuickActions.swift` | 标题行右上角新增 `+` 圆角按钮（glassEffect），点击弹 `AddQuickActionSheet`；已满8个时 sheet 内显示提示卡（暂无法添加，先移除再添加）；删除旧的 Grid 内"添加/管理"占位按钮 |
| E3 | 体重弹窗标题无宠物名 | — | 确认 `QuickWeightSheet` 顶部已包含 `pet.name`，无需修改 |
| E4 | 宠物卡片详情进健康页 | `OverviewView.swift` | `CritterDeckCarousel` 的 `onSelectPet` 回调改为先重置 `selectedPetTab = .overview` 再设 `selectedPet`，避免残留 `.health` 状态 |
| E5 | Island Stats 体重页无悬浮 chart | `IslandWeightDashboard.swift` | 去掉旧 `weightTrendCard` 卡片容器，新增 `weightFloatingChart`（时间 filter + 悬浮折线图）；新增 `filteredWeightDeltas` / `filteredSeriesByName` 计算属性支持时间筛选 |
| E6 | Island Stats 探索页无悬浮 chart | `IslandExplorationDashboard.swift` | `heroDisplay` 去掉背景卡片改为悬浮样式，在大数字下方内嵌 Chart 堆叠柱状图（和首页一致），时间 filter 在最上方 |
| E7 | Island Stats 花费页 chart 渐变色/有冗余饼图 | `IslandExpenseDashboard.swift`, `IslandStatComponents.swift` | 首页 `MultiPetExpenseBar` 改为纯色填充（去渐变）；花费页新增 `expenseFloatingHeader`（时间filter + 大数字 + 悬浮 pie chart，独立蓝绿橙紫粉灰色系）；删除底部 `categoryDonutCard` |
| E8 | Island Stats 财富页 filter 在底部卡 | `IslandWealthDashboard2.swift` | 时间 filter 从 `bottomCard` 移到 `chartArea` 上方（filter → chart 顺序），chart 颜色已使用宠物主题色（`petColorMap`） |

## 第二十二章 Bug Fix & UX 优化（2026-03-11）

| ID | 问题 | 修复文件 | 说明 |
|----|------|----------|------|
| D1 | 日历列表视图不展开重复事件 | `CalendarView.swift` | 新增 `expandedOccurrences` 计算属性，按 `recurrenceDays` 展开为虚拟出现；列表视图改用此数据源按 `occurrenceDate` 分组，范围：前后各3个月 |
| D2 | 快捷操作已满8个时无法添加/管理 | `OverviewView.swift` | 未满8个显示"添加"按钮，已满8个改为青柠色"管理"按钮（`slider.horizontal.3` 图标）点击弹出 `QAManageSheet` |
| D3 | 体重弹窗背景不够透明 | `QuickWeightSheet.swift` | 改用 `.ultraThinMaterial` + `.presentationBackground(.clear)`，可透过看到后面图表（标题已含宠物名） |
| D4 | 快捷操作健康页关闭后停留在宠物详情页 | `PetHealthDetailView.swift`, `PetDetailView.swift` | 添加 `onFullDismiss` 回调参数；`PetDetailView` 传入 `{ dismiss() }` 使关闭健康页时同时退出详情页 |
| D5 | 宠物详情页 UI/UX 优化 | `PetDetailView.swift` | 1) spacing 32→20，内容更紧凑；2) 新增 `petToolbar`（编辑/日历/寄养卡胶囊按钮横排）内嵌页面而非挤 NavigationBar；3) 证件/里程碑/成就改三列横排；4) NavigationBar 精简为仅显示椰子余额 |

## 第二十一章 Bug Fix（2026-03-11）

| ID | 问题 | 修复文件 | 说明 |
|----|------|----------|------|
| C1 | 护理计划日历重复事件只显示第一天 | `CalendarView.swift` | `eventOccursOnDate` 增加 `recurrenceDays` 展开逻辑，按步长检查 diff % recurrenceDays == 0 |
| C2 | 快速打卡看不到护理卡片 | `OverviewView.swift` | `activeQuickActionItems` 中将旧版 `actionType="care"` 规范化为 `"groom"`，兼容历史存储 |
| C3 | 宠物卡点击详情进健康页需多次返回 | `PetDetailView.swift`, `ArkCrewIDCardView.swift`, `CritterDeckCarousel.swift` | `showingHealthDetail` 从 `navigationDestination`(push) 改为 `.sheet`；carousel 传入 `onShowHealth` 回调弹 modal |
| C4 | 快速打卡进健康页需多次返回 | `PetDetailView.swift` | 同 C3，健康页统一改为 modal sheet 展示 |
| C5（生命之树） | 点击生命之树卡片跳转绿洲页 | `OverviewView.swift` | `onOasisTap` 改为 `selectedDockTab = 3`，等同点击导航栏第四个图标 |
| C5（背景） | 弹出页面背景不够不透明 | `QuickWeightSheet.swift`, `PetHealthDetailView.swift` | 改为 `.background(.regularMaterial)` + `.presentationBackground(.clear)`，与 Dock 风格一致 |

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
| 核心架构 | ✅ 完成 | ArkSchemaV22（V22新增身体检测报告），23模型，V1→V22完整迁移链 |
| 宠物模块 | ✅ 完成 | 健康/遛狗/饮食/护理/证件/花费/里程碑/成就/关系 |
| 人类成员模块 | ✅ 完成 | 体重/国籍城市/运动卡/HealthKit/心愿单/用药记录/身体检测报告 |
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
| 77 | 03-09 | **深度修复与证件/里程碑专修**：多附件证件管理 + 详情页、椰子树采摘交互、地标地图选址、自动里程碑、狗狗运动卡、证件同步宠物信息。 |
| 78 | 03-09 | **UI 标准化重构 Phase 1 & 2**：制定 Ohana Design System，重构 SettingsView (Floating Groups), OverviewView (Bento Box + Glass QA Cards), PetDetailView (Bento widgets) 适配亮暗模式。修复日历跨天显示/删除无二次确认 Bug，完善全岛统计图表动效与专属宠物主题颜色。 |
| 79 | 03-09 | **Inventory, Effects & Theme Toggles**：实现 Backpack (InventoryView)，装备特效 (Lime/Rainbow/Star/Firework)，装备头衔 (守护神/先锋/厨师加成)。并在Settings中加入 Light/Dark/System 主题切换，自动适配全局卡片和 ArkBackgroundView。 |

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

✅ **最新编译通过** — iPhone 17 Pro Simulator, iOS 26.2（FIX 1-8 + P11-P15 全部完成）

**Schema**: ArkSchemaV20（新增 PetDocumentAttachment 关系）

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
| P11：证件详情页 | `DocumentDetailSheet.swift` | 证件点击不再跳转编辑，而是进入详情展示多附件。|
| P12：椰子采摘 | `OasisRewardView.swift` | 椰子树上的椰果现可点击采摘并获得椰子。|
| P13：地图选址 | `PetMilestoneListView.swift` | 里程碑地点支持地图搜索选址。|
| P14：自动里程碑 | `PetMilestoneListView.swift` | 自动根据生日、到家日、体重记录生成里程碑。|
| P15：狗狗运动卡 | `DogActivityCard.swift` | 首页详情新增专门针对狗狗的运动与陪玩卡片。|

**Schema 版本**: ArkSchemaV20（V20 新增 `PetDocument` 与 `PetDocumentAttachment` 的 1:N 关系）
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

---

## 第二十四章：3D 堆叠玻璃卡片演示 + SwiftData 崩溃修复（2026-03-10）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| 3D卡片演示 | `PetDetailStackedDemoView.swift`（新建）, `SettingsView.swift` | ① 创建 `PetDetailStackedDemoView`：3D 层叠磨砂玻璃卡片效果，支持垂直拖拽切换，4 张卡片（Overview/Health/Diet & Care/Records）；② 背景动态 Blob 粒子 + Dark/Light 模式切换；③ 卡片 3D 旋转 + 缩放 + 透明度渐变；④ 在 `SettingsView` 开发者工具区添加入口 |
| SwiftData 崩溃修复 | `SharedModelContainer.swift` | 根因：iOS 26 在解析 `ArkMigrationPlan.stages` 时，若相邻两个 schema 版本的 Core Data hash 完全相同（如 V9 和 V10 的 models 列表一致），直接在 `try?` 捕获范围之前抛出 `NSInvalidArgumentException: model reference cannot be equal`。修复：将 `stages` 清空为 `[]`，依靠 SwiftData 原生自动 lightweight migration（仅新增字段/模型的迁移 SwiftData 完全自动处理，无需显式 stage）；`SharedModelContainer.make()` 改为三级降级策略，防止任何情况下 fatalError |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 第二十五章：终极玻璃卡片 UI 测试页升级（2026-03-10）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| Light Mode 黑卡修复 + 全量 UI 覆盖 | `OhanaGlassUIV2DemoView.swift` | ① **修复根因**：原背景始终为 `Color(hex: "0A0A0C")` 黑色，light mode 切换后 `.thinMaterial` 磨砂出来仍是黑色；改为 `bgBase` 计算属性，dark=`#0A0A0C`，light=`#F0F4FF`，blob 透明度随模式调整；② **整页重构**：抽取 16 个独立 card computed property，每张卡覆盖一类 UI 元素；③ **新增卡片**：Buttons（主/次/危险/圆形）、Chips & Tags、Alert Banners（success/warning/error/info）、Pet Card 宠物档案、Bento Stats 统计格、List Rows 列表行、Progress Ring 进度环、Charts 折线+柱状、Timeline 时间轴、Empty State、Toast/Undo 触发、Avatars & Badges；④ 所有文字颜色随 isDarkMode 切换；⑤ 整体动画 `.spring(response:0.4,dampingFraction:0.82)` 驱动背景过渡 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 第二十六章：UltimateGlassCard Light Mode 根本修复（2026-03-10）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| Material 渲染 Bug 根本修复 | `UltimateGlassCard.swift` | **根因**：`.environment(\.colorScheme)` 对 `Material.fill` 无效，material 始终跟随系统 colorScheme，导致 Demo 页（系统深色）里 light mode 切换时卡片依然深色。**修复**：使用 `UIViewRepresentable` 封装 `UIVisualEffectView`，强制注入 `overrideUserInterfaceStyle` 和 `.light` style，确保 Light Mode 卡片在任何系统设定下都是极其透亮发白的玻璃效果。 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 第二十六·二章：终极玻璃卡片 UI 精修与开发者入口清理（2026-03-10）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| 开发者测试页入口清理 | `SettingsView.swift` | 移除已废弃的“动态玻璃 UI 测试 (V1 旧版)” 和 “3D 堆叠卡片详情页”入口，避免视觉混淆，只保留最新的 UI 规范测试入口。 |
| Alert Banners 荧光实色恢复 | `OhanaGlassUIV2DemoView.swift` | 移除多余的玻璃框与竖条，恢复为与图3完全一致的全实色荧光背景（`goLime`, `goYellow`, `goRed`, `goPrimary`）+ 黑色粗体字的纯色胶囊样式。 |
| Avatars 彻底移除背景 | `OhanaGlassUIV2DemoView.swift` | 删除所有 `Background` 与 `Overlay` 圆环，仅保留纯 Emoji 叠加与极其轻微的防粘连阴影。 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

## 第二十六·三章：Ohana Stats (Island Stats) 布局重构 (2026-03-10)

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| UI 规范文档更新 | `OHANA_UI_GUIDELINES.md` | 更新了 Light Mode 的终极玻璃卡片参数，强调完全抛弃 Material 改用纯白渐变；明确规定了 Alert Banners 必须为实色荧光背景无边框胶囊；明确规定 Avatars 必须为纯 Emoji 重叠无背景圆环。 |
| IslandStats 卡片透明化 | `IslandStatComponents.swift` | 移除了 `IslandStatCard` 和 `SynergyFlashCard` 内部的 `UltimateGlassCard` 包装，将其转换为纯透明的 VStack 布局，以便能作为一个大型外层容器的子元素呈现。 |
| 首页数据卡片大一统布局 | `OverviewView.swift` | 将原本各自独立的水平滚动 `IslandStatCard` 统一包裹进了一个全局宽度的 `UltimateGlassCard` 中，使 "Island Stats" 区域成为一张巨大、宽阔的卡片背景，卡片内部的图表则完全透明，并在图表之间使用 `verticalDashDivider`（虚线）作为视觉分隔，彻底符合设计要求的 "charts要无背景（背景透明），chart之间用虚线分割"。 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 第二十七章：OHANA_UI_GUIDELINES 全面更新 + 首页 UI 规范化（2026-03-10）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| UI 规范文档全面重写 | `OHANA_UI_GUIDELINES.md` | 按 `OhanaGlassUIV2DemoView` 最终实现全量补充：① Dark/Light Mode 参数精确值（CSS equivalent + Swift 代码）；② Island Stats Bento 布局规范（单一 UltimateGlassCard + 透明图表 + verticalDashDivider）；③ 两种规范 Divider 的完整代码（水平实线 + 垂直虚线）；④ Section Header 规范；⑤ Alert Banners 完整示例代码；⑥ Avatars/Badges 完整示例代码；⑦ Status Badges / Chips / Inner Pills 规范；⑧ 全套 Button 变体代码；⑨ Typography 表格；⑩ Backgrounds & Blobs 规范；⑪ Charts 规范（透明背景、Y轴隐藏、X轴颜色）。重组为 9 个章节，总长度约 2.5x |
| quickActionsSection 规范化 | `OverviewView.swift` | 用 `UltimateGlassCard` 包裹整个 Quick Access 区块（标题 + 4列网格），标题字体改为 `OhanaFont.title3(.black)` |
| addFirstPetBanner 规范化 | `OverviewView.swift` | 将内部 3 个奖励 bento cell 从 `.goTranslucentCard()` 改为 `.ultraThinMaterial` + `RoundedRectangle(cornerRadius: 16)` + 白色 stroke，符合 UltimateGlassCard inner pill 规范 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第二十八章：暗色卡片 macOS Widget 风格 + Island Stats 浮动图表（2026-03-10）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| Dark Mode 卡片参数升级 | `UltimateGlassCard.swift` | 去掉 `black/40` 纯黑叠色，改为 `#1A2A6C/35% → #0D1B4B/25%` 蓝紫渐变叠在 `systemUltraThinMaterialDark` 上，边框从 `white/10` 升至 `white/18`，阴影从 `black/50 r24 y16` 降至 `black/35 r20 y8`，对齐 macOS widget 极薄透明蓝紫玻璃效果 |
| Demo 页背景动效加强 | `OhanaGlassUIV2DemoView.swift` | 5 blob 双层结构：Layer1（goLime/goPrimary/goPurple，更大 320-360pt，0.65-0.75 opacity）+ Layer2（goTeal/goOrange，慢速漂移 11s），幅度提升，便于验证卡片透视效果 |
| Island Stats 彻底去卡片 | `OverviewView.swift` | 去掉 `islandStatsBento` 外层 `UltimateGlassCard`，图表直接浮于页面动态背景上。Section header 独立为半透明白字浮标（`.white.opacity(0.45)`），无背景框 |
| UI Guidelines 更新 | `OHANA_UI_GUIDELINES.md` | 暗色模式参数更新为 macOS widget 蓝紫叠色规范；Island Stats Bento 规范更新为无卡片浮动图表 |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第三十三章：iOS 26 UI 规范全面升级（2026-03-11）

**目标**：根据 `iOS26_Design_Guide.md` 更新首页 UI，遵循原生 Liquid Glass 规范。

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| Island Stats 去卡片 | `OverviewView.swift` | 去掉 `UltimateGlassCard` 包裹，图表直接浮在背景上（无容器）；Section Header 改为 `.padding(.horizontal, 20)` 与页面对齐；指南明确：**大面积内容用 `.ultraThinMaterial`，图表/数据区无需卡片** |
| QuickAccess 升级 | `OverviewView.swift` | `UltimateGlassCard` 替换为 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))` 原生 Liquid Glass |
| BatchCheckIn 条升级 | `OverviewView.swift` | `.regularMaterial + strokeBorder` 替换为 `.glassEffect(.regular, in: Capsule())` |
| FloatingDockNav 升级 | `OverviewHelperViews.swift` | `HStack + .regularMaterial` 全面升级为 `GlassEffectContainer + .glassEffectID(idx, in: namespace)` morphing；选中态用 `.regular.tint(Color.goLime.opacity(0.18))`；加入 `UIImpactFeedbackGenerator(.light)` 触觉反馈 |

**iOS 26 设计准则对应**：
- 大面积数据区（Island Stats）→ 无卡片，直接浮在背景
- 中型容器（QuickAccess）→ `.glassEffect(.regular, in: RoundedRectangle)`
- 胶囊控件（BatchCheckIn、Dock）→ `.glassEffect(.regular, in: Capsule())`
- 多 Glass 元素 → `GlassEffectContainer` 统一渲染

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第三十二章：iOS 26 UI 测试页（2026-03-11）

**目标**：根据 `iOS26_Design_Guide.md` 新建 "iOS 26 UI 测试页"，内容与 `OhanaGlassUIV2DemoView` 完全对应（同 16 个展示卡片），但全部改用 iOS 26 原生 Liquid Glass API。

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| 新建测试页 | `iOS26UITestView.swift` | 用 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))` 替代 `UltimateGlassCard`；多 Glass 元素用 `GlassEffectContainer` 统一渲染；按钮用 `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`；Chip 用 `.glassEffect(.regular.tint(color))` 着色；`accessibilityReduceTransparency` 降级为纯色背景；`accessibilityReduceMotion` 适配脉冲动画 |
| 添加设置入口 | `SettingsView.swift` | 在"终极玻璃卡片 UI 测试"下方追加"iOS 26 UI 测试页"导航行（goLime 图标，wand.and.sparkles SF Symbol） |

**16 个展示卡片（与 OhanaGlassUIV2DemoView 一一对应）：**
1. Liquid Glass Info（原生 API 说明）
2. Typography System
3. Brand Color Palette
4. Buttons（含 .glass / .glassProminent / GlassEffectContainer 圆形快捷按钮）
5. Form Inputs
6. Chips & Tags（GlassEffectContainer + .tint）
7. Alert Banners（实色，不用 Glass）
8. Pet Card
9. Bento Stats
10. List Rows
11. Progress & Rings
12. Charts
13. Timeline
14. Empty State
15. Toast / Undo
16. Avatars & Badges

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第三十一章：Glass Card UI V2 + 设计系统规范升级（2026-03-12）

**目标**：根据 `Ohana_Design_System__2_.md` 更新"终极玻璃卡片UI测试"页和 app 首页（`OverviewView`），实现完整 8 层 Liquid Glass 折射系统。

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| 8 层折射升级 | `UltimateGlassCard.swift` | Dark Mode：8 层（ultraThinMaterial + L2白色叠层/L3 Lens Rim渐变/L4 Edge Darkening径向暗晕/L5主边框white/12@0.5pt/L6 Chromatic Aberration蓝红双色散/L7顶部聚光线/L8 Specular椭圆 + Caustics阴影）；Light Mode：ZStack(VisualEffectBlur.light + white/68→28渐变) + L3 RadialGradient screen混合/L4/L5对角渐变边框/L6 Chromatic/L7聚光线/L8 Specular（更强）；将 `cardBackground` 拆分为独立子方法避免编译器类型推导超时 |
| 背景规范化 | `ArkBackgroundView.swift` | 重写为设计系统 2.2 标准三球 Blob：底色 `#0A0A0C`/`#F0F4FF`；goLime/goBlue/goPurple 三球；8s/10s/9s easeInOut 漂移动画；移除旧的 5 球实现 |
| Demo 页背景升级 | `OhanaGlassUIV2DemoView.swift` | 背景底色改为 `#0A0A0C`/`#F0F4FF`，移除独立 `bgBase` 计算属性；Blob opacity 对齐设计系统双层规范（Layer1 快速7s/Layer2 慢漂11s） |
| Island Stats 卡片化 | `OverviewView.swift` | `islandStatsBento` 整体包裹进 `UltimateGlassCard`（设计系统 7.3）；Section Header 改用 `OhanaFont.caption2(.bold)` + 正确颜色规范（dark: white/0.45, light: black/0.4） |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第三十章：浅色/深色模式切换修复（2026-03-11）

**根本原因**：`OhanaApp.swift` 原先写死了 `.preferredColorScheme(.dark)`，同时 `ArkBackgroundView` 底色硬编码为 `Color.goDeepNavy`，导致切换无效。

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| 解除深色模式锁定 | `OhanaApp.swift` | 将 `.preferredColorScheme(.dark)` 改为 `.preferredColorScheme(preferredScheme)`，`preferredScheme` 读取 `@AppStorage("appThemePreference")` 动态返回 `.light` / `.dark` / `nil`（跟随系统） |
| 背景自适应 | `ArkBackgroundView.swift` | 添加 `@Environment(\.colorScheme)`；底色从写死 `Color.goDeepNavy` 改为 `isDark ? Color.goDeepNavy : Color(hex: "F0F4FF")`；5个 Blob 的 opacity 也按深/浅分别设值 |
| 浮标题自适应 | `OverviewView.swift` | Island Stats section header 的写死 `.white.opacity()` 改为 `colorScheme == .dark ? .white.opacity(0.45) : Color.primary.opacity(0.5)` |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

## 第二十九章：macOS Widget 卡片精准对齐 + 宠物卡片正面大升级（2026-03-11）

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| Dark Mode 卡片精准对齐 | `UltimateGlassCard.swift` | 彻底对齐苹果官方 macOS widget 实现：暗色背景改为直接 `.ultraThinMaterial`（系统原生深色环境渲染，内置蓝紫 vibrancy），去掉手动蓝紫渐变叠色；边框 `white/15` lineWidth `0.5pt`；阴影 `black/20 r15 y8` |
| 宠物卡片 emoji fallback 正面大升级 | `ArkCrewIDCardView.swift` | `emojiFallbackFront` 升级为 9 层：主色深底+对角渐变+右上高光椭圆+左下暗角+装饰大圆环×2+OHANA水印+emoji主角浮起阴影+右侧信息列+底部品种胶囊标签行 |
| 右侧信息列重构 | `ArkCrewIDCardView.swift` | `infoColumn` 新增：顶部品种+性别 chip 行；相伴天数升级为 36pt 黑体巨字+"天·一起度过"副标记；底部新增 🔥 连续打卡 streak 胶囊（goLime色，streak>1时显示） |
| 详情按钮重设计 | `ArkCrewIDCardView.swift` | `detailButton` 改为跟随卡片主题色的半透明胶囊（`cardTextColor/15` 背景 + `cardTextColor/20` stroke） |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro, iOS 26.2)

---

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| HumanMedication 模型 | `HumanMedication.swift`（新建）| SwiftData @Model：name/dosage/frequencyRaw/firstDoseTime/startDate/endDate/colorHex/notes/isActive；MedicationFrequency enum（6种）；isActiveToday/daysRemaining 计算属性 |
| EventType 扩展 | `Event.swift` | 新增 `.medication = "吃药"` case + 💊 emoji |
| Schema V21 | `SharedModelContainer.swift` | ArkSchemaV21 新增 HumanMedication.self；ArkMigrationPlan.schemas 追加 V21 |
| 吃药提醒页面 | `HumanMedicationView.swift`（新建）| ① 汇总 Bento（当前用药/今日到期/长期用药）；② 药物列表行（颜色圆+频率+剩余天数）；③ 激活/停药 Toggle + Toast；④ AddMedicationSheet：药物信息/服药时间/颜色&备注三张 UltimateGlassCard；频率 Chip 横选；编辑/删除 |
| HumanDetailView 全面重构 | `HumanDetailView.swift` | ① 全部文字 OhanaFont + `.white`；② heroCard 主题色光晕头像；③ statsBento 4格（体重/用药/提醒/椰子）；④ medicationCard 新入口（彩色药丸预览+Badge）；⑤ sectionHeader 区块分组；⑥ remindersSection 统一 UltimateGlassCard；⑦ 导航统一 `.navigationDestination` |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.2)

---

## 第二十章：Overview UI & Features 全面更新（2026-03-11）

**目标**：对首页 Bento 卡片、宠物卡、Quick Access、日历、设置页进行全面 UI 升级。

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| T1: Bento 卡片中文化 + 跳转 | `HomeBentoBoxes.swift` | "Oasis Tree"→"生命之树"，"Daily Strike"→"打卡连击"；添加 `onOasisTap`/`onStreakTap` 闭包回调；触发轻触觉反馈 |
| T1: 绿洲/打卡跳转连接 | `OverviewView.swift` | 新增 `showOasisReward`/`showStreakDetail` State；fullScreenCover → `OasisRewardView`；sheet → `DailyStreakDetailView` |
| T1: 打卡连击详情页 | `DailyStreakDetailView.swift`（新建）| 排行榜（宠物头像/streak大字/上次打卡日期）+ 月历视图（打卡日橙色高亮/今日goLime/月份左右切换）|
| T2: Quick Access EDIT 按钮移除 | `OverviewView.swift` | 去掉 EDIT 胶囊按钮；标题改"快捷操作"；LazyVGrid 末尾保留虚线"添加"占位按钮（未满8个时显示） |
| T2: 卡片去背景 | `OverviewQuickActions.swift` | `GoQuickActionCard` 去掉 premiumShape fill/strokeBorder；仅保留 icon + 文字，无卡片容器背景 |
| T3: 宠物卡正面文案 | `ArkCrewIDCardView.swift` | `infoColumn` 去掉品种/性别 chip 行；daysTogether 改为"一起度过了 XX 天"（小字+大字+小字组合） |
| T3: 去掉左下角品种标签 | `ArkCrewIDCardView.swift` | `emojiFallbackFront` 底部品种/绝育标签层删除；`minimalFront` 底部品种性别 chip 行注释隐藏 |
| T4: 卡片眩光柔化 | `ArkCrewIDCardView.swift` | shadow 从单层 `opacity(0.5) r24` 拆为双层：`opacity(0.28) r40 y12` + `opacity(0.10) r80 y20` |
| T5: Header 固定 | `OverviewView.swift` | `goGreetingHeader` 移出 ScrollView，固定在 VStack 顶部（上版本已完成，本次验证） |
| T6: 日历 UI 中文化 | `CalendarView.swift` | 导航标题 "Calendar"→"日历"；筛选 chip "All"→"全部"；空状态 "No events"→"暂无事件" |
| T6: 事件卡片 glassEffect | `SwipeableEventRow.swift` | `eventCard` 背景从手动深蓝 background 改为 `.glassEffect(.regular)` |
| T7: 设置页主题实时切换 | `SettingsView.swift` | 添加 `preferredScheme` 计算属性；NavigationStack 末尾加 `.preferredColorScheme(preferredScheme)` |

**新建文件**:
- `Ohana/Views/Home/DailyStreakDetailView.swift`

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)

---

## 第二十一章：UI/UX 全面修订 Round 2（2026-03-11）

**目标**：实现 11 项新 UI/UX 改进，涵盖绿洲页返回、Quick Access、宠物卡、Dock、打卡逻辑、卡片背景一致化、图鉴名称、宠物卡背面。

| 任务 | 文件 | 变更说明 |
|------|------|----------|
| F1: 绿洲页返回按钮 | `OasisRewardView.swift` | 添加 `@Environment(\.dismiss)`；顶部右侧添加 `xmark.circle.fill` 关闭按钮；标题子标改 "Ohana" |
| F2: Quick Access + 直接弹 sheet | `OverviewView.swift` | + 按钮点击触发 `showingQAManageSheet`（已有逻辑，确认生效） |
| F3: 宠物卡浮感增强 | `ArkCrewIDCardView.swift` | 三层 shadow：主题色 r24 y8 + 黑 r40 y16 + 黑淡 r80 y32 |
| F4: Header 背景柔化 | `OverviewView.swift` | `.background` 叠加 `.ultraThinMaterial.opacity(0.6)` + mask 底部 LinearGradient fade |
| F5: Dock 合并单卡 | `OverviewHelperViews.swift` | `GlassEffectContainer` → 单张 `.glassEffect(.regular, in: RoundedRectangle(28))`；`chart.bar.fill` → `calendar`；`figure.walk.circle.fill` → `house.fill` |
| F6: 打卡改为人类每日登录打卡 | `HomeBentoBoxes.swift` | `@AppStorage("user_login_streak")` + `@AppStorage("user_last_login_date")`；`onAppear` 调用 `refreshLoginStreak()`；不再使用 `Pet.currentStreak` |
| F7: BentoStatCard 背景一致 | `OverviewHelperViews.swift` | `UltimateGlassCard` 替换为 `.glassEffect(.regular, in: RoundedRectangle(24))`；文字改 `.primary` |
| F8: DailyQuestsCard 背景+中文 | `DailyQuestsCard.swift` | `expandedCard` 背景改 `.glassEffect`；标题 "DAILY QUESTS" → "今日任务" |
| F9: Ohana 图鉴 | `CrewRosterOverlay.swift` | `navigationTitle` "欧哈纳图鉴" → "Ohana 图鉴"；注释同步更新 |
| F10: 移除绿洲日历入口 | `OasisRewardView.swift` | 删除 `calendar.badge.checkmark` 按钮及连带胶囊视图 |
| F11: 宠物卡背面 iOS26 规范 | `ArkCrewIDCardView.swift` | 背景改 `.glassEffect`；文字 `.white` → `.primary`；详情按钮背景改 `.glassEffect`；待办 Banner 背景改 `.glassEffect`；`metricDivider` 改 `.primary.opacity(0.1)` |

**编译状态**: BUILD SUCCEEDED (iPhone 17 Pro Simulator, iOS 26.2)


---

## 第二十二章：UI/UX 优化 Round 2 续（2026-03-11）

| ID | 任务 | 文件 | 关键实现 |
|----|------|------|---------|
| G1 | 宠物卡方形阴影去除 | `ArkCrewIDCardView.swift` | `cardFrontView` 内 ZStack 加 `.clipShape(RoundedRectangle(32))`，GeometryReader 外层再加一次 `.clipShape` |
| G2 | 打卡连击页改为人类登录 | `DailyStreakDetailView.swift` + `HomeBentoBoxes.swift` | 删除宠物排行榜；改为「我的连击」卡片（头像+名字+streak大字+里程碑进度条）；日历格读 `user_login_history` JSON；`refreshLoginStreak` 同步写入登录历史 |
| G3 | Header 去掉 material 背景 | `OverviewView.swift` | 删除 `goGreetingHeader` 底部 `LinearGradient + .ultraThinMaterial.opacity(0.6)` 背景块 |
| G4 | QA + 按钮直接弹出选择半卡 | `OverviewView.swift` + `OverviewQuickActions.swift` | `+` 按钮改触发 `showingAddQuickAction`；直接弹出 `AddQuickActionSh
---

## 第二十二章：UI/UX 优化 Round 2 续（2026-03-11）

|??#???| ID | 任务 | 文件 | 关键实现 |
|----|------|------| `|----|------|------|---------|
| G1 | ?? G1 | 宠物卡方形阴影?y| G2 | 打卡连击页改为人类登录 | `DailyStreakDetailView.swift` + `HomeBentoBoxes.swift` | 删除宠物排行榜；改为「我的连击」卡片（头像+名字+streak大??| G3 | Header 去掉 material 背景 | `OverviewView.swift` | 删除 `goGreetingHeader` 底部 `LinearGradient + .ultraThinMaterial.opacity(0.6)` 背景块 |
| G4 | QA + 按钮直接弹出选择半卡 | `OverviewView.swift` + `OverviewQuickActions.swift` | `+` 按钮改触发 `showingAddQuickAc`u| G4 | QA + 按钮直接弹出选择半卡 | `OverviewView.swift` + `OverviewQuickActions.swift` | `+` 按钮改触发 `s17 Pro Simulator, iOS 26.2)
