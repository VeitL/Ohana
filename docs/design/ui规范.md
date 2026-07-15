# Ohana UI 规范

`ui规范.selection.json` 是 Ohana UI 的唯一机器可读规范源头。本文档是同一选择的人类可读说明，用来解释规则、约束和使用场景；如本文档与 `ui规范.selection.json` 不一致，以 `ui规范.selection.json` 为准，并更新本文档。

`设置 > 开发者工具 > UI/UX 规范查看` 中的 V4 交互式设计控制台只是编辑、预览和导出工具。控制台里的 AppStorage 状态不自动成为正式规范；只有导出的 V4 JSON 同步到 `ui规范.selection.json` 后，才算新的设计源头。

## 0. 规范分层

- `ui规范.selection.json`：唯一机器源头，保存 token、选项值、规则 ID 和当前正式选择。
- `docs/design/ui规范.md`：解释同一选择的意图、适用场景、例外和人工检查方式；不另起 token。
- `docs/ui-v4-new-page-template.md`：新页面和重构页面的代码起点，只演示最小可执行结构。
- `AGENTS.md`：代理工作流提示，只保留源头、验证命令和高风险提醒。
更新规范时，先改 `ui规范.selection.json`，再同步本文档。只有需要试验或导出新组合时才进入 V4 控制台；实现页面时不要把控制台 AppStorage 状态当作正式规范。

## 0.1 V4 设计控制台使用规则

- 入口：`设置 > 开发者工具 > UI/UX 规范查看`。
- 控制台只使用 fixture 假数据，不读取真实 SwiftData，不修改全 app 主题。
- 设计选择按 `背景 → 卡片 → 按钮 → 输入 → 控件 → 文字 → 导航 → 弹窗 → 图表 → 反馈 → 动效` 的积木顺序调整。
- 预览画布采用“全元素总览”：同一画布内覆盖导航、卡片、按钮、输入、开关、chip、列表、角标、进度、图表、toast/banner、状态矩阵和 FAB。
- 预览画布应模拟一个固定高度的 iPhone 视口，内部内容可独立上下滑动；不要把长预览裁切成不可滚动的海报。
- 弹窗预览必须使用真实 SwiftUI `Sheet`、`Alert`、`confirmationDialog` 或 `Menu`，用来观察系统 chrome、原生 toolbar、表单分组与确认行为；不在预览画布内伪造覆盖层。
- Chip 指“小型选择标签”，例如时间范围、筛选项、快捷克数、干粮/湿粮切换；它不是独立页面控件，应在控件区和真实业务卡片中同时预览。
- 卡片和输入框必须提供 `纯色无边框 / Flat Block` 选项：纯色块、无描边、无阴影，适合极简表单和密集工具页。
- 自定义内容状态切换必须顺滑；`TabView`、`NavigationStack`、Sheet、Alert、Menu 与表单控件的过渡交给系统，不覆盖原生动画。
- 每次确定设计方向后，复制 V4 JSON/Markdown，并同步到 `ui规范.selection.json` 与本文档。
- 新建页面或大改页面时，从 `docs/ui-v4-new-page-template.md` 开始；完成前运行 `scripts/audit-ui-v4.sh --changed` 或指定文件扫描。
- 后续正式规范调整应检查 V4 控制台中的设计检查面板：文字对比、44pt 触控区域、玻璃可读性、动效强度、状态可见性、深浅色安全。

## 0.2 当前正式设计选择

以 `ui规范.selection.json` 为准，当前已确认的 V4 token：

- **导出版本**：Ohana UI 规范选择 V4，Generated `2026-06-16T00:00:00Z`。
- **颜色与背景**：深色预览使用 `deep` 背景；主色为 adaptive primary，深色解析为 `goLime`，浅色解析为清爽蓝 `goBlue`。全局背景必须以“浅色/深色成对”的官方背景包选择，一次选择同时决定两种模式；浅色背景必须比浅色卡片更深一档，让白色/浅色卡片保持层次。大面积背景以中性雾灰、冷灰为主，只保留少量岛屿蓝氛围，不再整屏铺满高饱和蓝。当前官方背景对为 `goIsland`、`cleanBlueGray`、`paperCream`、`forestGlade`、`deepAmbient`；自定义照片使用同一张图片叠加深/浅色可读性遮罩。
- **主操作颜色纪律**：`goPrimary` / `adaptivePrimary` 是唯一全局“可点击/可确认/可选中”的主操作颜色。主 CTA、确认、关键入口、功能 icon、焦点和系统级选中态使用它；喂食、提醒、危险、成功、奖励和图表只在表达业务语义时使用各自语义色，不能为每个功能另造一套漂亮主色。
- **食物语义色**：喂食页只保留三种喂食模式色和干/湿粮食物色。干粮全局使用 `foodDry` 琥珀色，湿粮全局使用 `foodWet` rose；余粮、库存、零食在喂食模块内统一使用 `goPrimary`，低余粮/异常只在局部状态上使用 `goYellow/goRed`。
- **卡片与输入**：卡片使用 `solidFlat`，输入框使用 `flat`。业务卡片默认是实色 token surface 或实色语义色块，不使用低透明度磨砂/半透明填充；整体密度使用 `compact`。
- **表面节奏与阴影预算**：默认靠背景层级、间距、分组标题和轻 hairline 建立结构，而不是不断增加边框、玻璃、阴影或卡片套卡片。普通卡片、按钮、文字、chip、列表行和弹窗内容不使用装饰阴影；系统呈现自行管理 elevation，自定义阴影只留给 toast、关键浮层、重要角色/头像/产品视觉和明确 allowlist 的预览。
- **控件**：有语义化系统控件时必须使用原生 SwiftUI：`Button`、`Toggle`、`Picker`、`Menu`、`List`、`Form`、`DisclosureGroup`、`searchable`、`Sheet`、`Alert`、`confirmationDialog` 与 SF Symbols。品牌 token 只负责 tint、排版、间距与自定义内容表面，不重画系统控件。
- **实色控件**：高频按钮、chip、快捷金额/克数、内嵌数字键盘优先使用实色填充，减少低透明度和磨砂表面。选中态使用实色 `goPrimary` / 业务 tint + `Color.arkInk` 文本；未选态使用实色 elevated surface，不使用低透明度 tint。
- **按钮语法**：一个页面只保留一个主 pill；次级操作视觉降噪；危险操作使用语义红并二次确认；icon-only 控件必须有 44pt 实际触控区和本地化 accessibility label。
- **功能 Icon**：全局功能 icon 使用 `monochromePrimary`。导航、按钮、设置行、快捷操作、列表和状态入口里的 icon 必须是 SF Symbol 或 template vector，统一使用 `goPrimary`，不使用彩色仿真 icon、emoji、多色插画或拟物图标。
- **导航与设置行**：根导航使用原生 `TabView`，底部 tab 只显示 SF Symbol，可见文字隐藏但保留本地化 accessibility label；层级导航使用 `NavigationStack`。首页 FAB 使用原生圆形 `borderedProminent` Button 并贴右下安全区，应用只负责位置与快捷菜单；系统负责 tab bar、navigation bar、返回按钮、标题、toolbar 和按钮状态。设置项左 icon 使用 `plainGlyph`，不加彩色底块。
- **弹窗**：记录与编辑使用原生 `.sheet`，确认与破坏性操作使用 `Alert` / `confirmationDialog`，短选项使用 `Menu`。尺寸、圆角、拖拽关闭、键盘避让、过渡和无障碍均由系统呈现容器负责；内容内部继续使用 Ohana 品牌 token。
- **图表与日历**：图表使用 `area` 趋势 + `quiet` 坐标；日历使用 `agendaHybrid`、`minimalNumber` 日期格、`dots` 事件标记、`timeRail` 日程列表。
- **反馈与动效**：toast 使用 `icon`，banner 使用 `inline`，触感 `soft`；自定义内容可使用克制的 shared motion，系统导航、呈现和控件保持原生动画，奖励视觉可保留 `bouncy`。
- **第一帧反馈**：手指触发的第一帧只做本地视觉反馈，例如轻 scale、opacity/brightness 和 soft haptic。SwiftData 读写、奖励同步、提醒同步、路由重活和跨模块刷新必须在视觉 handoff 之后进行。
- **双模式省电**：省电模式默认关闭。普通模式与省电模式都必须保持当前可见核心交互动效顺滑；省电模式只减少后台刷新、动态背景、粒子、彩虹流动、环境光等装饰/重复工作。
- **已接受的风险约束**：`compact` 密度仍必须保留 44pt 实际触控区；`clear` 玻璃必须有足够遮罩和描边，避免文字浮在复杂背景上。

## 0.3 页面生成质量硬规则

这些规则是之后生成或重构页面前的硬性门槛，用来避免内容显示不全、颜色错误、排版怪异、按钮互相覆盖等低级问题。

- **先定固定区域，再排内容**：页面必须先扣除状态栏、Dynamic Island、固定顶部栏、底部导航、sheet chrome 和安全区，再在剩余区域内布局内容。嵌入式页面不能从 `y=0` 开始画主要内容，必须由宿主提供或自身定义 top/bottom inset。
- **主内容必须完整可见**：hero、生命树、卡片、头像、chart、底部 CTA、关闭按钮和快捷操作不能被裁切。固定高度模块必须有明确 `min/max/aspectRatio`；如果真实数据放不下，应该让内容区域有意图地滚动，而不是被父容器裁掉。
- **禁止无意双背景**：一个卡片只能有一个主背景。除非要表达真实堆叠卡片，否则不能出现“外面一个圆角背景，里面又一个圆角卡片”的双层框。
- **ZStack 层级要可解释**：背景、光晕、遮罩、地图、chart 等装饰层必须 `.allowsHitTesting(false)`；关闭按钮、顶部按钮、快捷操作和主 CTA 必须有明确 zIndex 和 44pt 触控区。
- **深浅色一起验收**：任何玻璃、弹窗、卡片和图表都必须同时检查深色和浅色。玻璃要保留折射感，但文字、按钮和图标必须清晰；不能为了可读性把玻璃盖成纯色，也不能为了透明让内容糊在背景里。
- **真实数据优先于 fixture**：布局必须能承受长名字、德语文案、大数字、空数据、缺失头像、2.5D 全身头像、照片头像和多宠/多成员真实数据。不要只按一组短中文 fixture 调整。
- **完成前的目测清单**：交付 UI 前至少检查一次：有没有裁切、有没有重叠、有没有双关闭按钮、有没有双背景、有没有点不到的按钮、有没有突然跳动、有没有颜色语义冲突、有没有 chart/数字和文案不一致。

## 1. 设计原则

- **信息密度优先**：Ohana 是家庭宠物管理工具，优先清晰、可扫描、可重复操作，不做营销式大 hero。
- **圆润但克制**：使用圆体、胶囊按钮和柔和卡片，但不要卡片套卡片，不要堆过多装饰。
- **状态可读**：任何状态都必须靠文字、icon、颜色共同表达，不能只靠颜色；状态背景、badge、文字可以使用语义色，但功能 icon glyph 本身保持全局 `goPrimary` 单色。
- **状态优先于说明**：高频页面只展示当前状态和下一步动作，避免常驻“点击/长按/拖动/如何使用”式教程文案。
- **一个主色贯穿到底**：主操作、确认、关键入口、功能 icon、焦点和系统级选中态统一使用 `goPrimary`。业务色只表达业务含义，不承担全局“点我”的职责。
- **表面节奏优先于 chrome**：需要分区时，先调整背景层级、间距、标题、轻分隔线和内容密度；不要先加新的外框、玻璃、阴影或第二层卡片。
- **卡片只给可操作表面**：卡片 UI 只用于可点击、可进入、可展开或可操作的区域；纯信息总览、静态指标和标题说明使用无框布局、行内数字或轻量分隔，不为了分组而套卡片背景。
- **阴影有预算**：普通业务卡片、按钮、chip、文本和列表行默认无阴影。阴影是“浮在内容之上”或“重要视觉对象有重量”的信号，只给 sheet、popup、toast、关键浮层、角色/头像/奖励等少数对象。
- **深浅色同步**：页面切换浅色/深色时，背景、卡片、描边、文字、图表和控件都必须同步变化。
- **顺滑过渡，不硬切**：所有用户能看到的 UI 状态变化都要用项目动效 token 过渡。即使是轻量变化，也应有短促的 fade/scale/slide/spring，让界面像“滑过去、浮出来、收回去”，而不是突然换帧。
- **核心交互满质量，装饰动效按预算降级**：按钮、FAB、弹窗、卡片展开、奖励反馈、数字和图表切换属于 interaction motion，省电模式不应让它们变钝；背景呼吸、粒子、常驻发光、彩虹流动、环境循环属于 ambient motion，省电模式应静态化或停止。
- **性能稳定**：规范页和设置入口不要使用高风险重型 glass API。大页面使用 `ScrollView + LazyVStack`。

## 2. Foundations

### 字体

中文统一使用 `cnFont(size:weight:)` 风格：优先寒蝉全圆体，缺失时回退系统 `.rounded`。

- Metric 36：大数字，如体重、完成率、资产。
- Large Title 30：页面主标题，一屏最多一个。
- Title 24：卡片大标题。
- Headline 17：列表主标题、设置项标题。
- Body 15：正文与详情说明。
- Callout 13：副标题、辅助描述。
- Caption 11：时间戳、字段标签、说明文字。

### 颜色

- `goPrimary`：全局主操作、品牌强调、系统级选中状态；深色模式解析为 `goLime`，浅色模式解析为清爽蓝 `goBlue`。
- `goPrimary` 适用范围：主 CTA、确认、关键入口、导航/设置/快捷操作功能 icon、焦点环、选中态和 feeding stock/treat 的既定业务入口。
- `goLime` / `goBlue`：保留主色，只能作为 `goPrimary` 的深/浅色解析或系统级强调；宠物/人类主题色、业务模式色、图表系列色、计划等专有色不能直接复用这两个颜色。喂食模块中的余粮/库存/零食按业务决策使用 `goPrimary`。
- `goTeal`：完成、健康、成功。
- `goYellow`：进行中、注意、隐私。
- `goRed`：错误、危险、删除、异常。
- `goBlue`：浅色模式主色，不再作为普通信息色或业务专有色使用。
- 成员主题色：只用于宠物/人类身份、图表系列、头像底色；从成员主题色库选择，必须避开 `goLime`、`goBlue` 及它们的明暗变体。旧数据若命中保留色，启动时自动归一到成员 fallback 色。
- 粮食语义色：手动模式用 `goOrange`，计划模式用 `goPurple`，自动模式用 `goTeal`；干粮用 amber，湿粮用 rose；余粮/库存/零食统一使用 `goPrimary`，但低余粮、异常、删除等局部状态仍使用 `goYellow/goRed`。

### 动效

统一使用 `GoMotion`：

- `GoMotion.page`：页面级转场、详情层展开/收起。
- `GoMotion.hero`：首页卡片、头像主体、待办系统旅程 / 奖励卡片切换。
- `GoMotion.fab`：FAB 菜单、奖励弹出、较强反馈。
- `GoMotion.feedback`：按钮、色块、segment、轻量状态切换。
- `GoMotion.tap`：所有按钮/可点击块的短按反馈，轻微缩放、轻微变暗，不做夸张弹跳。
- `GoMotion.selection`：chip、segment、tab、模式切换、干湿粮切换等选中态移动/扩散。
- `GoMotion.stateChange`：卡片状态、任务状态、完成/待办、空/有数据之间的稳定过渡。
- `GoMotion.sheet`：仅供没有系统语义等价物的自定义空间视觉；不得用于替代 SwiftUI Sheet 的进出场。
- `GoMotion.quick` / `GoMotion.reduced`：短淡出、低功耗/减弱动态模式。

默认实现规则：

- 自定义内容 motion 默认采用 **Capsule** 体系，数字、进度和品牌视觉反馈走克制轻弹；系统控件、TabView、NavigationStack、Sheet、Alert 与 Menu 使用平台动画。**Chart 是例外**，采用 **Flow** 体系，线条用约 `0.72s` 的 `trim` 慢慢延长，面积只轻淡入，点位轻显，不做点位弹跳主导。
- 点击：语义动作使用原生 `Button` 与系统 button style；只有没有系统控件等价物的品牌视觉交互才可使用 `ScaleButtonStyle()`，并保持短促、无阴影、不夸张 bounce。
- 选中：原生 Picker、Toggle、TabView 与列表选择保持系统动画；自定义可视化选择才使用 shared selection motion 或 matched transition。
- 数字：余额、次数、克数、完成率、排行榜数字使用 `contentTransition(.numericText())` 或 `ohanaNumericMotion`。
- 列表/菜单：功能入口、FAB 子菜单、添加菜单使用 35ms 左右的 stagger 入场，上限约 240ms，保证高级但不拖沓。
- 反馈：奖励、完成、错误、需要注意才使用 pop / ping / shine / shake；高频页面避免常驻循环装饰。

全局过渡规则：

- **ZStack Motion Scene**：关键动效必须采用稳定 `ZStack` 场景：动画开始前冻结业务快照，动画期间视觉层保持挂载，只用单一 `progress` 驱动位置、尺寸、圆角、阴影、遮挡、mask、opacity、zIndex 和 hit-testing。动画过程中不要插入/删除复杂 View，不做头像解码，不扫 SwiftData，不用多个 `DispatchQueue` 延迟拼动画。
- **适用范围**：首页卡片 hero、自定义空间 reveal、奖励反馈、扭蛋/Oasis 奖励、添加人类/宠物角色卡、图表范围切换和其他没有系统语义等价物的空间过渡。Sheet、Alert、Menu、TabView、NavigationStack、长表单和设置列表不使用自定义 motion scene。
- **遮挡优先于淡入淡出**：Apple Wallet 式过渡应让元素“被移开的主物体自然露出”，优先用 transform/mask/reveal，不要让目标模块在主动画结束后再单独 fade in。
- **状态冻结与解冻**：开始动画前把卡片、头像、快捷操作和关键数字冻结成 snapshot；动画结束后再同步真实业务状态，避免内容在运动中途跳变。
- **空间卡片几何唯一真相**：可展开卡片堆必须由一个 motion scene 同时拥有折叠态 frame、展开态 frame、内部 alignment、padding、头像 source、快捷操作边界、zIndex、hit-testing 和浮动。先验收 collapsed / expanded 两个稳定端点，再调 spring 或 progress。
- **层级与冻结分离**：卡片收回接近卡片堆时，selected zIndex / hit-testing 应先回到折叠堆层级；frozen card/avatar source 多保留一帧，等普通折叠卡稳定接管后再清掉；这段时间不要恢复 ambient floating。
- **禁止散点修偏**：卡片偏左/偏右时，不要先随机改 `x`、padding 或 offset。必须同时检查外层 `CGRect.midX`、内部 alignment、leading/trailing padding、overlay/quick action 视觉边界、头像裁切透明区和 frozen/live source 是否一致。
- **控件切换**：segment、tab、filter、picker 与 Toggle 优先使用原生控件及系统动画；只有没有语义等价物的自定义可视化才使用 shared motion。
- **Toggle**：始终使用 SwiftUI `Toggle`，不定义轨道、圆钮、位移或 bounce。
- **卡片与列表**：展开/收起、插入/删除、排序变化应使用 `GoMotion.page` 或 `GoMotion.feedback`，配合 opacity/scale/offset，避免列表瞬间重排。
- **Sheet / 弹窗**：出入场、背景遮罩、材质、drag indicator 与交互关闭全部由 SwiftUI 系统呈现管理。
- **图表 / 日历**：数据范围、日期、选中点变化要 animate value；空状态和有数据状态之间使用 crossfade。图表主线采用 Flow slow line draw：线条从左到右慢慢延长，面积轻淡入，点位随后轻显；不要把 chart 做成 Capsule 弹跳或奖励 pop。
- **深浅色切换**：颜色 token 变化也应使用短过渡，避免整屏闪一下。
- **减弱动态模式**：可以降低位移和弹性，但仍使用短 fade/ease 过渡，不做硬切。

不要在高频页面随手写新的 `.spring(response:)` 参数；除非该动画是独立特效，并且不会影响首页、表单输入或头像裁剪性能。

禁止在普通卡片、文本、描边中硬编码 `.white` / `.black`。使用：

- `primaryText`
- `secondaryText`
- `tertiaryText`
- `cardSurface`
- `sectionCardFill`
- `sectionCardStroke`

### 背景和卡片

- 页面背景必须随深浅色变化。
- 浅色页面背景不能接近纯白；默认使用稍深的中性雾灰 / 冷灰渐变，确保 `ohanaCardSurface`、白色卡片和输入块能从背景中分离，同时减少蓝色背景的面积感。
- 官方背景和自定义照片背景都必须经过深浅色可读性遮罩。自定义照片只保存一张原图，渲染时按当前模式叠加雾灰 / 深色遮罩与轻模糊。
- 背景选择是全局页面底，不等同于卡片、弹窗或玻璃 token；省电模式只能降低动画，不能覆盖用户选择的背景。
- 纯信息显示区域不使用卡片背景；只有可点击、可导航、可展开、可编辑的区域才使用卡片样式。
- 业务卡片必须使用实色填充：优先 `Color.ohanaCardSurface`、`Color.ohanaCardSurfaceElevated` 或明确的实色语义色。避免 `tint.opacity(...)`、厚磨砂、低透明 material 作为主卡片背景。唯一长期内容层例外是宠物/人类/植物身份主卡：一层非交互 `nativeRegular` 玻璃承托半透明主题光场；Reduce Transparency / reduced-effects 回退为不透明五段渐变。
- 分区优先级：先用页面背景与卡片 surface 的明度差，再用空白、标题和轻 hairline；只有内容本身需要可点击、可进入、可展开或可编辑时才增加卡片 surface。
- 大面积内容使用 `sectionCard`，但仍保持实色 surface，不做半透明磨砂卡片。
- 卡片内子区域使用 `cardSurface`。
- 原生 `.glassEffect()` 只用于系统拥有语义的 TabView、顶部 toolbar、返回/关闭和浮动系统控件，以及上文身份主卡例外；Sheet、Alert、Menu 与原生控件的材质由系统负责。禁止用单纯降低透明度冒充玻璃。
- 普通页面和业务详情页不要新增长驻 `.glassEffect()` 卡片。不得为 Sheet 或 popup 内容再画一层玻璃外壳、遮罩、圆角或 drag handle。
- `Toggle` 必须委托原生 `.switch`；`Slider`、`.segmented` Picker 和 `DatePicker` 保持 SwiftUI 系统组件，由系统负责静止、按下、拖动、选中、禁用、折射与 Reduce Motion。Figma 记录状态和 Smart Animate 时长，不用自绘低透明胶囊替代运行时行为。
- 状态提示使用 `tint.opacity(0.10)` 背景 + `tint.opacity(0.25-0.30)` 描边。
- 卡片圆角默认 22；内嵌格圆角 12-14；列表行圆角 14。
- 普通卡片和弹窗内容不加 decorative shadow；如果需要自定义阴影，必须属于 toast、关键浮层、重要角色视觉，或用 `// ui-v4: allow <reason>` 明确说明。

## 3. Components

### 按钮

- Primary CTA：实色 `goPrimary` 胶囊，每屏最多一个，文字用 `Color.ohanaPrimaryActionText`。
- 底部导航、顶部工具栏的返回/关闭按钮使用原生 `.glass`；浮动主操作使用 `.glassProminent`。Reduce Transparency 时回退为 `ohanaCardSurfaceElevated` 实色，不保留伪磨砂。
- Secondary：`primaryText.opacity(0.08)` 背景，适合取消、稍后、查看详情。
- Destructive：红色文字、浅红背景、红色描边，必须配二次确认。
- Ghost：无背景或轻背景，只用于卡片内轻量动作。
- Quick Action Circle：40x40 圆形 icon 按钮，功能 icon 统一使用 `goPrimary` 单色；通过按钮背景、badge 或文字表达业务状态。
- 高频选择按钮：选中态必须是实色主色/业务色，未选态必须是实色 surface；避免 `tint.opacity(0.10-0.20)` 作为可点击按钮主体。
- 内嵌数字键盘：数字、删除、小数点键统一使用实色 elevated surface；不要用半透明磨砂键帽。
- 按钮层级固定：主 pill 表示“现在做”；secondary 表示“稍后/替代路径”；ghost 只用于轻量辅助；icon-only 只用于关闭、返回、工具和导航类动作。
- 按压反馈固定：所有按钮默认走 `ScaleButtonStyle()` 的轻反馈；需要额外阴影深度时必须显式 opt in，而不是把阴影做成普通按钮默认行为。

### 关闭按钮

- 弹窗关闭使用系统 toolbar 的 `.cancellationAction`；层级页面优先使用系统返回按钮。
- 非弹窗页面确需关闭时使用原生 toolbar `Button`，图标用 SF Symbol 并提供本地化 accessibility label。
- 不手绘关闭圆片、胶囊或固定像素视觉框；触控、布局、玻璃和状态反馈由系统按钮负责。
- 只有图片预览、强视觉 hero 或背景对比不足时，才使用浅色圆形底。
- 只有退出长表单或有数据丢失风险时，才使用带文字的原生 toolbar 取消动作，并配合确认提示。

### 返回按钮

- 返回行为由 `NavigationStack` 与系统 navigation bar 管理，不创建自绘 floating circle。
- 系统 push 页面优先使用 `NavigationStack` 系统返回。
- 自定义 toolbar 使用 34-36 视觉框的 `chevron.left` 圆形按钮，并保留 44pt 实际触控区。
- 彩色 hero 上使用实色返回圆按钮。
- 多级详情可使用“返回”文字胶囊，但背景和文字必须有足够对比。

### 全局功能 Icon

- 功能 icon 由 `icon` 控制，当前为 `monochromePrimary`。
- 适用范围：导航、按钮、设置行、快捷操作、列表行、状态入口、toast/banner 中的功能符号。
- 默认结构：SF Symbol 或 template-rendered vector，20-22pt 视觉尺寸，`goPrimary` 前景，保留至少 44pt 触控区。
- 禁止：彩色仿真 icon、拟物 icon、emoji 作为 UI 功能 icon、多色图标、照片/插画裁成按钮图标。
- 例外：宠物/人类头像、2.5D 角色、商品预览、照片、电子宠物形象、App Icon、业务插画不是功能 icon，可继续使用彩色视觉资产。
- 状态表达不要靠 icon 变色完成；使用 badge、背景、文字、进度条或状态行补充。

### 设置行左侧 Icon

- 设置项左侧 icon 由 `settingIcon` 控制，当前为 `plainGlyph`。
- 默认结构：纯 SF Symbol / template glyph，无彩色 tile 背景，20-22pt 视觉尺寸，`goPrimary` 前景，44pt 实际触控区。
- 设置行可以使用文字、副标题、右侧 toggle/chevron 和状态 badge 建立层级，不再依赖彩色 icon 底块区分功能。
- 设置行 icon 必须和标题、右侧 chevron/toggle 对齐，行高稳定，不能因为 icon 样式切换造成布局跳动。

### Toggle

- Toggle 只表达布尔状态。
- 设置页行结构：左 icon，中间主副标题，右 Toggle。
- 隐私开关使用 lock icon；公开/隐私状态要同步快捷操作状态徽标。

### 表单

- TextField 使用 10-12 垂直内边距，背景为 `cardSurface`。
- 搜索/编辑类输入框应带左侧 SF Symbol。
- Slider、Stepper、Segmented Picker 放在表单卡片内，不单独漂浮。

### Chips / Tags / Badges

- Chip：可点击筛选，选中态填充 tint。
- Tag：静态信息，不可点击。
- Status Badge：完成=绿，进行中=黄，异常/逾期=红。

### Alert / Toast

- Banner：用于页面内长期可见提醒。
- Toast：底部短暂反馈，2-3 秒自动消失，可带撤回。
- 空状态：icon + 标题 + 一句说明 + 一个主操作，不写长段教程。

## 4. App 使用场景

### 首页 / GO Focus

- 首页以当前家庭状态和快捷操作为核心。
- 使用卡片堆、快捷操作、聚合入口和状态条。
- 避免大面积装饰图、营销式标题、卡片套卡片。
- GO Focus 是默认主路径；经典首页只能作为内部兼容/回归入口，不在普通设置中暴露切换。
- 首页不复制行动清单；Event、Reminder、FamilyTask 与系统旅程统一进入待办。
- 待办中的状态词、按钮和奖励反馈必须来自同一任务快照与 command 结果，不在卡片层另造完成状态。

### 宠物详情页

- 顺序：身份卡 → 关键指标 → 健康 → 活动 → 财务/文档 → 时间线。
- 宠物主题色只作为 accent，不做整页主色。
- 健康/护理/用药等数据页应有 overview 大卡。

### 人类详情页

- 顺序：身份卡 → 隐私可见的关键指标 → 健康身体 → 活动记录 → 财务 → 提醒备注。
- 隐私字段必须完全隐藏真实数据，用锁定占位替代。
- 如果全部字段设为隐私，其他用户只能看到整体锁定占位。

### 快捷操作长按详情页

- 顶部：左侧隐私 icon，右侧关闭 icon。
- 底部：主 CTA 固定为 `goPrimary` 胶囊。
- 内容：先 overview，再图表/列表，再明细。
- 体重、运动、吃药、备注页面应保持同一关闭按钮、添加按钮和隐私开关风格。

### 设置页

- 使用稳定行高，左 icon + 主标题 + 副标题 + 右控件。
- 破坏性设置必须二次确认。
- UI 测试页入口只作为内部工具，不应影响正常设置页性能。

### Dashboard / 统计页

- 先展示 overview 大卡。
- 再展示 2-4 个 bento 指标。
- 图表颜色使用语义色或主题色。
- 明细列表必须可扫描，避免一次展示过多解释性文字。

### Sheet / 表单页

- 标题使用系统 navigation title；取消与完成进入原生 toolbar placement。
- 表单区域使用 `Form` / `List` + `Section` 清晰分组，主操作优先放 confirmation toolbar，只有内容语义要求时才使用 `safeAreaInset` CTA。
- 关闭按钮只保留一个系统 action，不绘制页面内关闭控件。
- 普通 overview、历史、长列表与复杂编辑统一使用原生 `.sheet`，内容由 `NavigationStack` + `List` / `Form` 组织，并使用系统导航标题与 `ToolbarItem`。关闭按钮只能有一个。
- 弹窗背景、圆角、拖拽手势、键盘避让和转场由系统容器管理，不在内容层再次绘制整张玻璃、遮罩、drag handle 或自定义弹出动画。
- 记录、补粮与轻量管理使用原生 `.sheet(item:)`；确认使用 `Alert` / `confirmationDialog`；少量即时选项使用 `Menu`。
- 弹窗内部优先使用原生 Form row、TextField、Toggle、Picker、DatePicker 和 Button；自定义卡片只用于没有系统等价物的信息视觉。
- Sheet 高度优先使用系统语义 detent（`.medium` / `.large`）；不要为常规表单测量并硬编码弹窗高度。长表单由 `Form` / `List` 自然滚动，关键操作放入系统 toolbar 或 `safeAreaInset`。
- 表单内分区使用原生 `Section`，避免在 sheet 里继续套厚重或半透明卡片。

#### 原生短呈现标准 / Native Short Presentation Standard

当用户说“改为弹窗 UI”或需要记录、确认、补粮、轻量管理这类短弹窗时，默认按以下标准实现：

- **实现方式**：记录与编辑使用 `.sheet(item:)`；确认使用 `.alert` / `.confirmationDialog`；少量选项使用 `Menu`。
- **系统所有权**：位置、宽度、圆角、遮罩、drag indicator、键盘避让与进出动画交给 SwiftUI 系统呈现，不复制这些行为。
- **内部结构**：优先 `NavigationStack` + `Form` / `List`，用 `Section` 建立层级；品牌卡片只用于确有信息可视化价值的内容。
- **选择控件**：二元设置使用 `Toggle`；2–5 个互斥选项使用 `Picker(.segmented)`；更多选项使用 `Picker(.menu)` 或导航到列表选择。
- **操作**：普通动作使用 `Button`；破坏性动作使用 `.destructive` role 并二次确认；标题、取消和完成使用系统 toolbar placement。
- **可访问性**：保留 Dynamic Type、VoiceOver、Reduce Motion、深浅色与 RTL 的系统行为，不用固定像素布局覆盖系统控件。

## 5. 深浅色规则

页面切换浅色/深色时，至少这些元素必须变化：

- 页面背景
- 自定义/官方背景遮罩
- 卡片背景
- 卡片描边
- 主/副/三级文字
- 内嵌格背景
- 图表轴标签
- 列表分隔线
- 非实色按钮背景

实色语义按钮可以保持 tint，但文字必须保持高对比：

- `goPrimary` 背景 → `Color.arkInk`
- `goRed` 背景 → `Color.arkInk` 或白色，取决于对比
- 浅色卡片上不要使用低透明度彩色文字作为正文

## 6. 实现检查清单

新增或修改 UI 前检查：

- 是否使用 `cnFont()` 或项目现有 `OhanaFont`？
- 是否使用 `GoMotion`，而不是临时新增一套弹簧参数？
- 高频页面是否用短状态替代教程说明？
- 是否避免硬编码 `.white` / `.black`？
- 深浅色切换时背景、卡片、描边是否一起变化？
- 同一屏是否只有一个主 CTA？
- 关闭按钮是否只用 icon？
- 返回按钮是否优先使用系统返回？
- Toggle 是否只表达布尔状态？
- 状态切换、选中态、弹窗、列表更新、图表变化是否都有顺滑过渡，避免硬切？
- 私密数据是否对非本人完全隐藏？
- 复杂列表是否使用 `LazyVStack`？
- 是否避免卡片套卡片？

## 7. 代码映射

- 规范展示页：`Ohana/Features/Settings/DesignLab/UIGuidelinesView.swift`
- 规范选择源：`ui规范.selection.json`
- 新页面模板：`docs/ui-v4-new-page-template.md`
- 自动检查脚本：`scripts/audit-ui-v4.sh`
- 规范类型：`DesignSpecSelectionV4`
- 规范选项：`DesignSpecOptionCatalogV4`
- 场景预览：`DesignSpecPreviewCanvasV4`
- 导出器：`DesignSpecExporterV4`
- 背景和卡片基础：`goFocusBackdrop`、`sectionCard`
- 通用业务表面：`goSolidCardSurface`、`goIslandModuleCard`、`goSelectableSurface`
- 旧名兼容：`goTranslucentCard` 当前实现为实色 surface，不是半透明卡；新代码优先使用 `goSolidCardSurface`
- 文字颜色：`primaryText`、`secondaryText`、`tertiaryText`
- 表面色：`cardSurface`、`sectionCardFill`、`sectionCardStroke`
- V4 控制台组件：背景、卡片、按钮、输入、控件、文字、导航、弹窗、图表、反馈、动效

新建页面或大幅重构时，按需阅读 `ui规范.selection.json` 与本文档；图标、文案、间距、颜色和单个控件等局部修改直接复用现有组件与相关 token，不需要加载或重新验证整套规范。只有调整正式设计选择时，才在 V4 控制台中试验、导出并同步回来。
