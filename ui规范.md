# Ohana UI 规范

本文档以 `Ohana/Views/Details/GoFocusUIView.swift` 为 UI 基础规范页。新增页面、重构页面或修复 UI 时，优先遵循本文档；如页面与规范冲突，应先调整页面，除非有明确产品原因。

## 1. 设计原则

- **信息密度优先**：Ohana 是家庭宠物管理工具，优先清晰、可扫描、可重复操作，不做营销式大 hero。
- **圆润但克制**：使用圆体、胶囊按钮和柔和卡片，但不要卡片套卡片，不要堆过多装饰。
- **状态可读**：任何状态都必须靠文字、icon、颜色共同表达，不能只靠颜色。
- **深浅色同步**：页面切换浅色/深色时，背景、卡片、描边、文字、图表和控件都必须同步变化。
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

- `goPrimary`：主操作、品牌强调、选中状态。
- `goTeal`：完成、健康、成功。
- `goYellow`：进行中、注意、隐私。
- `goRed`：错误、危险、删除、异常。
- `goBlue`：信息、导航、辅助强调。
- 宠物主题色：只用于宠物身份、图表系列、头像底色；避免使用绿色，防止和品牌主色混淆。

禁止在普通卡片、文本、描边中硬编码 `.white` / `.black`。使用：

- `primaryText`
- `secondaryText`
- `tertiaryText`
- `cardSurface`
- `sectionCardFill`
- `sectionCardStroke`

### 背景和卡片

- 页面背景必须随深浅色变化。
- 大面积内容使用 `sectionCard`。
- 卡片内子区域使用 `cardSurface`。
- 普通业务页面使用 `goTranslucentCard`、`goGlassBackground` 或 `goSelectableSurface`；不要直接调用原生 `.glassEffect()`。
- `.glassEffect()` 只允许保留在 `iOS26UITestView` 这类内部 UI 测试页中，避免设置页、首页和详情页真机卡顿。
- 状态提示使用 `tint.opacity(0.10)` 背景 + `tint.opacity(0.25-0.30)` 描边。
- 卡片圆角默认 22；内嵌格圆角 12-14；列表行圆角 14。

## 3. Components

### 按钮

- Primary CTA：实色 `goPrimary` 胶囊，每屏最多一个，文字用 `Color.arkInk`。
- Secondary：`primaryText.opacity(0.08)` 背景，适合取消、稍后、查看详情。
- Destructive：红色文字、浅红背景、红色描边，必须配二次确认。
- Ghost：无背景或轻背景，只用于卡片内轻量动作。
- Quick Action Circle：40x40 圆形 icon 按钮，按功能使用 tint。

### 关闭按钮

- 默认 sheet/弹窗右上角使用纯 icon 关闭按钮。
- 普通关闭：`xmark` + 36x36 圆形浅背景。
- 系统 sheet 可用 `xmark.circle.fill` hierarchical。
- 只有退出长表单或有数据丢失风险时，才用带文字的关闭胶囊。

### 返回按钮

- 优先使用 `NavigationStack` 系统返回。
- 自定义 toolbar 使用 36x36 `chevron.left` 圆形按钮。
- 彩色 hero 上使用实色返回圆按钮。
- 多级详情可使用“返回”文字胶囊，但背景和文字必须有足够对比。

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

## 5. 深浅色规则

页面切换浅色/深色时，至少这些元素必须变化：

- 页面背景
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
- 是否避免硬编码 `.white` / `.black`？
- 深浅色切换时背景、卡片、描边是否一起变化？
- 同一屏是否只有一个主 CTA？
- 关闭按钮是否只用 icon？
- 返回按钮是否优先使用系统返回？
- Toggle 是否只表达布尔状态？
- 私密数据是否对非本人完全隐藏？
- 复杂列表是否使用 `LazyVStack`？
- 是否避免卡片套卡片？

## 7. 代码映射

- 规范展示页：`Ohana/Views/Details/GoFocusUIView.swift`
- 背景和卡片基础：`goFocusBackdrop`、`sectionCard`
- 通用业务表面：`goTranslucentCard`、`goGlassBackground`、`goSelectableSurface`
- 文字颜色：`primaryText`、`secondaryText`、`tertiaryText`
- 表面色：`cardSurface`、`sectionCardFill`、`sectionCardStroke`
- 组件展示：`buttonShowcase`、`annotation`、`statusBadge`、`chip`、`toggleRow`

修改 UI 时，先在 `GoFocusUIView` 中补齐或调整规范，再应用到业务页面。
