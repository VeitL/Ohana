# Ohana UI 规范

`ui规范.selection.json` 是 Ohana UI 的唯一机器可读规范源头。本文档是同一选择的人类可读说明，用来解释规则、约束和使用场景；如本文档与 `ui规范.selection.json` 不一致，以 `ui规范.selection.json` 为准，并更新本文档。

`设置 > 开发者工具 > UI/UX 规范查看` 中的 V4 交互式设计控制台只是编辑、预览和导出工具。控制台里的 AppStorage 状态不自动成为正式规范；只有导出的 V4 JSON 同步到 `ui规范.selection.json` 后，才算新的设计源头。

## 0. 规范分层

- `ui规范.selection.json`：唯一机器源头，保存 token、选项值、规则 ID 和当前正式选择。
- `ui规范.md`：解释同一选择的意图、适用场景、例外和人工检查方式；不另起 token。
- `docs/ui-v4-new-page-template.md`：新页面和重构页面的代码起点，只演示最小可执行结构。
- `AGENTS.md`：代理工作流提示，只保留源头、验证命令和高风险提醒。
- `docs/ui-ux-pro-max-ohana-adaptation.md`：外部 UI/UX 建议如何翻译进 Ohana；不得覆盖 V4 token。

更新规范时，先改 `ui规范.selection.json`，再同步本文档。只有需要试验或导出新组合时才进入 V4 控制台；实现页面时不要把控制台 AppStorage 状态当作正式规范。

## 0.1 V4 设计控制台使用规则

- 入口：`设置 > 开发者工具 > UI/UX 规范查看`。
- 控制台只使用 fixture 假数据，不读取真实 SwiftData，不修改全 app 主题。
- 设计选择按 `背景 → 卡片 → 按钮 → 输入 → 控件 → 文字 → 导航 → 弹窗 → 图表 → 反馈 → 动效` 的积木顺序调整。
- 预览画布采用“全元素总览”：同一画布内覆盖导航、卡片、按钮、输入、开关、chip、列表、角标、进度、图表、toast/banner、状态矩阵和 FAB。
- 预览画布应模拟一个固定高度的 iPhone 视口，内部内容可独立上下滑动；不要把长预览裁切成不可滚动的海报。
- 弹窗不再作为单独页面切换，而是从全元素画布内打开覆盖层，用来观察 sheet 透明度、关闭按钮、底部 CTA、删除确认等效果。
- Chip 指“小型选择标签”，例如时间范围、筛选项、快捷克数、干粮/湿粮切换；它不是独立页面控件，应在控件区和真实业务卡片中同时预览。
- 卡片和输入框必须提供 `纯色无边框 / Flat Block` 选项：纯色块、无描边、无阴影，适合极简表单和密集工具页。
- 所有可见状态切换都必须有顺滑过渡：按钮按压、chip/segment 选中、toggle 滑动、卡片展开、sheet 出入场、toast/banner、列表更新、图表数据变化、日历切换都不能硬切。
- 每次确定设计方向后，复制 V4 JSON/Markdown，并同步到 `ui规范.selection.json` 与本文档。
- 新建页面或大改页面时，从 `docs/ui-v4-new-page-template.md` 开始；完成前运行 `scripts/audit-ui-v4.sh --changed` 或指定文件扫描。
- 后续正式规范调整应检查 V4 控制台中的设计检查面板：文字对比、44pt 触控区域、玻璃可读性、动效强度、状态可见性、深浅色安全。

## 0.2 当前正式设计选择

以 `ui规范.selection.json` 为准，当前已确认的 V4 token：

- **导出版本**：Ohana UI 规范选择 V4，Generated `2026-05-13T00:00:00Z`。
- **颜色与背景**：深色预览使用 `deep` 背景；主色为 adaptive primary，深色解析为 `goLime`，浅色解析为清爽蓝 `goBlue`。全局背景必须以“浅色/深色成对”的官方背景包选择，一次选择同时决定两种模式；浅色背景必须比浅色卡片更深一档，让白色/浅色卡片保持层次。当前官方背景对为 `goIsland`、`cleanBlueGray`、`paperCream`、`forestGlade`、`deepAmbient`；自定义照片使用同一张图片叠加深/浅色可读性遮罩。
- **食物语义色**：喂食页只保留三种喂食模式色和干/湿粮食物色。干粮全局使用 `foodDry` 琥珀色，湿粮全局使用 `foodWet` rose；余粮、库存、零食在喂食模块内统一使用 `goPrimary`，低余粮/异常只在局部状态上使用 `goYellow/goRed`。
- **卡片与输入**：卡片使用 `solidFlat`，输入框使用 `flat`。业务卡片默认是实色 token surface 或实色语义色块，不使用低透明度磨砂/半透明填充；整体密度使用 `compact`。
- **控件**：按钮 `pill`，chip `pill`，segment `capsule`，toggle `pill`，进度条 `bar`，列表行 `filled`，角标 `solid`。
- **实色控件**：高频按钮、chip、快捷金额/克数、内嵌数字键盘优先使用实色填充，减少低透明度和磨砂表面。选中态使用实色 `goPrimary` / 业务 tint + `Color.arkInk` 文本；未选态使用实色 elevated surface，不使用低透明度 tint。
- **功能 Icon**：全局功能 icon 使用 `monochromePrimary`。导航、按钮、设置行、快捷操作、列表和状态入口里的 icon 必须是 SF Symbol 或 template vector，统一使用 `goPrimary`，不使用彩色仿真 icon、emoji、多色插画或拟物图标。
- **导航与设置行**：设置项左 icon 使用 `plainGlyph`，不加彩色底块；非弹窗页面返回使用 `floatingCircle`；非弹窗页面关闭使用 `iconOnly`；弹窗关闭继续使用独立 `sheetChrome=iconOnly`。
- **弹窗**：sheet 使用独立 token，当前为 `compact` 布局、`nativeRegular` 背景、`flat` 卡片、`flat` 输入框、`pill` 按钮、`iconOnly` 关闭。短记录/确认弹窗使用 `inlineOverlay`，底部贴近安全区、左右 `6pt`、连续圆角 `52pt`、自适应内容高度、`liftedAlert` 阴影、`scrimGradient` 背后遮罩、`bottomSpringScaleFade` 出入场；长表单底部 CTA 固定可见；下滑关闭只允许从顶部 drag handle 触发。弹窗 token 不跟随普通卡片/输入/按钮选择变化。
- **图表与日历**：图表使用 `area` 趋势 + `quiet` 坐标；日历使用 `agendaHybrid`、`minimalNumber` 日期格、`dots` 事件标记、`timeRail` 日程列表。
- **反馈与动效**：toast 使用 `icon`，banner 使用 `inline`，触感 `soft`，主运动 `spring`，FAB `rotate`，转场 `scale`，奖励 `bouncy`。
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
- **卡片只给可操作表面**：卡片 UI 只用于可点击、可进入、可展开或可操作的区域；纯信息总览、静态指标和标题说明使用无框布局、行内数字或轻量分隔，不为了分组而套卡片背景。
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
- `GoMotion.hero`：首页卡片、头像主体、Today Focus 卡片切换。
- `GoMotion.fab`：FAB 菜单、奖励弹出、较强反馈。
- `GoMotion.feedback`：按钮、色块、segment、轻量状态切换。
- `GoMotion.tap`：所有按钮/可点击块的短按反馈，轻微缩放、轻微变暗，不做夸张弹跳。
- `GoMotion.selection`：chip、segment、tab、模式切换、干湿粮切换等选中态移动/扩散。
- `GoMotion.stateChange`：卡片状态、任务状态、完成/待办、空/有数据之间的稳定过渡。
- `GoMotion.sheet`：普通 sheet 或 inline popup 的出入场节奏。
- `GoMotion.quick` / `GoMotion.reduced`：短淡出、低功耗/减弱动态模式。

默认实现规则：

- 点击：使用 `ScaleButtonStyle()`，只做 `0.965` 左右的短促按压、轻微暗化和 soft haptic；不要给普通按钮加夸张 bounce。
- 选中：使用共享 selection motion 或 matched transition，选中块应“滑过去/长出来”，不要瞬移。
- 数字：余额、次数、克数、完成率、排行榜数字使用 `contentTransition(.numericText())` 或 `ohanaNumericMotion`。
- 列表/菜单：功能入口、FAB 子菜单、添加菜单使用 35ms 左右的 stagger 入场，上限约 240ms，保证高级但不拖沓。
- 反馈：奖励、完成、错误、需要注意才使用 pop / ping / shine / shake；高频页面避免常驻循环装饰。

全局过渡规则：

- **ZStack Motion Scene**：关键动效必须采用稳定 `ZStack` 场景：动画开始前冻结业务快照，动画期间视觉层保持挂载，只用单一 `progress` 驱动位置、尺寸、圆角、阴影、遮挡、mask、opacity、zIndex 和 hit-testing。动画过程中不要插入/删除复杂 View，不做头像解码，不扫 SwiftData，不用多个 `DispatchQueue` 延迟拼动画。
- **适用范围**：首页卡片 hero、FAB/菜单 reveal、inline popup、快捷操作菜单、奖励反馈、扭蛋/Oasis 奖励、添加人类/宠物角色卡、图表范围切换和其他空间过渡。长表单、静态设置列表、普通长详情页可继续使用 `VStack/ScrollView/List`，除非其中有空间转场。
- **遮挡优先于淡入淡出**：Apple Wallet 式过渡应让元素“被移开的主物体自然露出”，优先用 transform/mask/reveal，不要让目标模块在主动画结束后再单独 fade in。
- **状态冻结与解冻**：开始动画前把卡片、头像、快捷操作和关键数字冻结成 snapshot；动画结束后再同步真实业务状态，避免内容在运动中途跳变。
- **空间卡片几何唯一真相**：可展开卡片堆必须由一个 motion scene 同时拥有折叠态 frame、展开态 frame、内部 alignment、padding、头像 source、快捷操作边界、zIndex、hit-testing 和浮动。先验收 collapsed / expanded 两个稳定端点，再调 spring 或 progress。
- **层级与冻结分离**：卡片收回接近卡片堆时，selected zIndex / hit-testing 应先回到折叠堆层级；frozen card/avatar source 多保留一帧，等普通折叠卡稳定接管后再清掉；这段时间不要恢复 ambient floating。
- **禁止散点修偏**：卡片偏左/偏右时，不要先随机改 `x`、padding 或 offset。必须同时检查外层 `CGRect.midX`、内部 alignment、leading/trailing padding、overlay/quick action 视觉边界、头像裁切透明区和 frozen/live source 是否一致。
- **控件切换**：chip、segment、tab、filter、picker 行切换应使用 spring 或 matched transition；选中态要滑动/扩散/淡入，不能直接跳到新位置。
- **Toggle**：轨道高度只比内部圆钮略高；圆钮必须滑动到另一侧，icon/文字可同步 crossfade 或 bounce。
- **卡片与列表**：展开/收起、插入/删除、排序变化应使用 `GoMotion.page` 或 `GoMotion.feedback`，配合 opacity/scale/offset，避免列表瞬间重排。
- **Sheet / 弹窗**：出入场使用 slide/scale/fade 组合；背景遮罩和玻璃透明度也要同步动画。
- **图表 / 日历**：数据范围、日期、选中点变化要 animate value；空状态和有数据状态之间使用 crossfade。
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
- 浅色页面背景不能接近纯白；默认使用稍深的清爽蓝灰渐变，确保 `ohanaCardSurface`、白色卡片和输入块能从背景中分离。
- 官方背景和自定义照片背景都必须经过深浅色可读性遮罩。自定义照片只保存一张原图，渲染时按当前模式叠加蓝灰/深蓝遮罩与轻模糊。
- 背景选择是全局页面底，不等同于卡片、弹窗或玻璃 token；省电模式只能降低动画，不能覆盖用户选择的背景。
- 纯信息显示区域不使用卡片背景；只有可点击、可导航、可展开、可编辑的区域才使用卡片样式。
- 业务卡片必须使用实色填充：优先 `Color.ohanaCardSurface`、`Color.ohanaCardSurfaceElevated` 或明确的实色语义色。避免 `tint.opacity(...)`、厚磨砂、低透明 material 作为主卡片背景。
- 大面积内容使用 `sectionCard`，但仍保持实色 surface，不做半透明磨砂卡片。
- 卡片内子区域使用 `cardSurface`。
- 原生 `.glassEffect()` 和自定义磨砂只用于明确的 Liquid Glass 展示、底部导航、系统级 chrome 或弹窗/短 popup 背景；普通业务卡片、成就卡、列表行、快捷操作容器不使用玻璃/磨砂主背景。
- 普通页面和业务详情页不要新增长驻 `.glassEffect()` 卡片。短 popup / sheet 背景允许一层 `nativeRegular` 玻璃，并按 `sheet*` token 加遮罩、描边和可读性承托；内部表单块仍使用 flat 实色 surface。
- 状态提示使用 `tint.opacity(0.10)` 背景 + `tint.opacity(0.25-0.30)` 描边。
- 卡片圆角默认 22；内嵌格圆角 12-14；列表行圆角 14。

## 3. Components

### 按钮

- Primary CTA：实色 `goPrimary` 胶囊，每屏最多一个，文字用 `Color.arkInk`。
- Secondary：`primaryText.opacity(0.08)` 背景，适合取消、稍后、查看详情。
- Destructive：红色文字、浅红背景、红色描边，必须配二次确认。
- Ghost：无背景或轻背景，只用于卡片内轻量动作。
- Quick Action Circle：40x40 圆形 icon 按钮，功能 icon 统一使用 `goPrimary` 单色；通过按钮背景、badge 或文字表达业务状态。
- 高频选择按钮：选中态必须是实色主色/业务色，未选态必须是实色 surface；避免 `tint.opacity(0.10-0.20)` 作为可点击按钮主体。
- 内嵌数字键盘：数字、删除、小数点键统一使用实色 elevated surface；不要用半透明磨砂键帽。

### 关闭按钮

- 弹窗关闭由 `sheetChrome` 控制，当前为 `iconOnly`。
- 非弹窗页面关闭由 `pageCloseButton` 控制，当前为 `iconOnly`。
- 普通关闭：`xmark` + 32-36 视觉框 + 44pt 实际触控区域，不额外加圆形浅背景。
- 只有图片预览、强视觉 hero 或背景对比不足时，才使用浅色圆形底。
- 系统确认类 sheet 可用 `xmark.circle.fill` hierarchical，但业务详情页优先纯 icon。
- 只有退出长表单或有数据丢失风险时，才用带文字的关闭胶囊。

### 返回按钮

- 返回按钮由 `pageBackButton` 控制，当前为 `floatingCircle`。
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
- Today Focus 中普通任务用“跳过”，当天隐藏、次日恢复；异常/风险警告用“关闭”，用户确认后不应每天重复出现。

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

- 标题明确，右上角关闭。
- 表单区域分组清晰，底部主 CTA 固定。
- 关闭按钮默认只用 icon，不加文字。
- 普通 overview、历史、长列表、复杂编辑这类 sheet 页面参考体重趋势页：系统导航栏隐藏；页面内顶部固定一行标题 + 关闭按钮，始终不跟随内容滚动；内容区在标题下方使用可弹性下拉的垂直 `ScrollView`；关闭按钮只能有一个，不能同时出现系统导航关闭和页面内关闭。
- 弹出卡片默认使用 `nativeRegular` 背景：优先 `.glassEffect(.regular)` / 原生高斯玻璃效果，避免厚重灰色材质和突兀纯白/纯黑大卡。
- 当前 `nativeRegular` 弹窗背景只能有一层原生 `.glassEffect(.regular)`。深色模式允许在同一玻璃面内使用语义化深色承托 tint、细描边和顶部高光，确保内部 flat 输入块/按钮从背景中分离；这不应做成第二层卡片、厚 material、厚描边或独立背景。系统 `.sheet` 的这层玻璃应放在 `.presentationBackground`，不要放在 sheet 内容层的 `.background` 里，否则会被 NavigationStack / presentation 容器采样成更厚的磨砂感。需要对比时可临时使用 `.glassEffect(.clear)`。弹窗内操作、输入、选项切换时不得触发整张弹窗闪动；自适应高度更新应静默完成，避免 detent 动画造成闪烁。
- 记录、确认、补粮、轻量管理这类短弹窗优先使用当前页面内自绘 overlay sheet，直接盖在同一个 `ZStack` 上，让玻璃采样真实页面背景；系统 `.sheet` 只保留给 overview、历史、长列表和复杂编辑页。
- 弹窗内部卡片和输入框默认使用 `flat` 纯色无边框块；只有弹窗背景负责玻璃质感，内部不要再叠厚玻璃卡。
- Sheet 高度使用能完整显示内容的最小 detent；短记录/确认弹窗必须测量内容高度后使用自适应 `.height(...)`，避免 `.medium` 留出大块空白；表单较长时底部主 CTA 必须固定可见，内容区独立滚动；只有历史、长列表、复杂编辑才使用 `.large`。
- 表单内分区用轻量半透明块承载，避免在 sheet 里继续套厚重卡片。

#### 短弹窗标准 / Inline Popup Standard

当用户说“改为弹窗 UI”或需要记录、确认、补粮、轻量管理这类短弹窗时，默认按以下标准实现：

- **实现方式**：使用当前页面内自绘 `inlineOverlay`，直接盖在同一个 `ZStack` 上；不要用系统 `.sheet`，除非内容是 overview、历史、长列表或复杂编辑。
- **位置**：底部对齐，距离屏幕底部安全区约 `8pt`；键盘弹出时只抬起弹窗本身，不抬起背景页面。
- **宽度与边距**：左右屏幕边距 `6pt`，视觉上接近屏幕边缘，但仍保留一点呼吸感。
- **圆角**：使用 `RoundedRectangle(cornerRadius: 52, style: .continuous)`；目标是接近 iPhone 屏幕圆角的同心圆感觉。
- **高度**：内容自适应，只比最底部 CTA 多留少量 padding；不要留 `.medium` 那种大块空白。短弹窗建议最小约 `260pt`，最大不超过当前页面高度的 `94%`；键盘出现时最大不超过约 `68%`。表单内容超过可用高度时，底部 CTA 固定在弹窗底部，滚动区域不遮住 CTA。
- **背景**：弹窗玻璃面只保留一层 `nativeRegular` / `.glassEffect(.regular)`；深色模式使用同一玻璃面的深色承托 tint、细边缘光和高光来提高内容分离度。补粮等对比场景可使用 `clear`。不要在玻璃面上再叠厚 material、纯色大底、第二层玻璃或重描边。
- **阴影**：允许在弹窗外层增加 `liftedAlert` 背后托举阴影，参考当前粮食记录弹窗：一层较强的上方 lift shadow + 一层柔和 grounding shadow。阴影要随弹出淡入，不要出现硬切的黑块。
- **背后遮罩**：使用 `scrimGradient`，包含轻微全屏 scrim 和底部渐变，用来托出玻璃层级；遮罩随弹窗一起平滑淡入淡出。
- **弹出动画**：使用 `bottomSpringScaleFade`：从底部向上滑入，同时轻微 scale 和 fade；退出反向。动画使用 `GoMotion.page`，拖拽偏移使用 `GoMotion.feedback`，不能硬切。
- **关闭方式**：右上角 `iconOnly` 关闭按钮；点击外部关闭或先收键盘；弹窗顶部必须有小型 drag handle。实现时统一使用 `OhanaPopupCloseButton` 和 `OhanaPopupDragHandle`，视觉参数为：纯 `xmark`、无圆形底、约 `44pt` 触控区；handle 宽约 `48pt`、高 `5pt`、距离弹窗顶部约 `4pt`。下滑关闭手势只能绑定在顶部 drag handle 上，内容区域的上下滑动只滚动内容，绝不能关闭弹窗，也不能把背后的详情页一起关闭。
- **内部结构**：弹窗内表单块、输入框、分区使用 `flat` 纯色无边框块；不要卡片套卡片。像“当前主粮”这种二选一模块只显示两个胶囊按钮，不要额外加外层卡片背景。
- **选择动画**：干粮/湿粮、segment、chip 等选中态必须用 matched geometry 或 spring 滑块/淡入过渡；不能直接换背景色硬切。
- **底部 CTA**：一个主操作，使用 `pill` 胶囊按钮；短内容可跟随内容底部，长表单必须固定在弹窗底部。弹窗底边只比 CTA 低一小段 padding。

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

- 规范展示页：`Ohana/Views/Details/UIGuidelinesView.swift`
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

修改 UI 时，先读 `ui规范.selection.json` 与本文档；只有需要调整正式设计选择时，才在 V4 控制台中试验、导出并同步回来。
