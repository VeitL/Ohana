# iOS App 设计规范完全指南

### 基于 iOS 26 · Liquid Glass · Apple HIG 2025
> 自 iOS 7 以来最大的界面重设计 · 适用版本：iOS 26 · Swift 6 · SwiftUI · Xcode 26

> **版本说明：** Apple 于 WWDC 2025（2025年6月9日）发布 iOS 26，同时将命名规范改为与年份对齐（原 iOS 19 → iOS 26）。  
> iOS 26 于 2025年9月正式发布，核心变化是引入 **Liquid Glass** 设计语言，跨越 iOS / iPadOS / macOS Tahoe / watchOS / tvOS 全平台统一。

---

## 目录

1. [设计哲学与核心原则](#一设计哲学与核心原则)
2. [Liquid Glass — iOS 26 核心材质](#二liquid-glass--ios-26-核心材质)
3. [排版系统 Typography](#三排版系统-typography)
4. [颜色系统 Color System](#四颜色系统-color-system)
5. [间距与布局 Spacing & Layout](#五间距与布局-spacing--layout)
6. [核心组件规范 Components](#六核心组件规范-components)
7. [Light / Dark Mode](#七light--dark-mode)
8. [触控与手势规范](#八触控与手势规范)
9. [动画规范 Animation](#九动画规范-animation)
10. [图标与图片 Icons & Images](#十图标与图片-icons--images)
11. [无障碍设计 Accessibility](#十一无障碍设计-accessibility)
12. [性能设计准则 Performance](#十二性能设计准则-performance)
13. [发布前设计检查清单](#十三发布前设计检查清单)

---

## 一、设计哲学与核心原则

iOS 设计哲学历经三个时代：

| 时代 | 风格 | 代表版本 |
|---|---|---|
| 拟物化 Pre-iOS 7 | 模仿现实材质，厚重纹理 | iOS 6 及以前 |
| 扁平化 Flat | 去除装饰，清晰直白 | iOS 7 — iOS 15 |
| 玻璃化 Glassmorphism | 半透明、层次、光线 | iOS 15 — 25 |
| **液态玻璃 Liquid Glass** | **物理折射、动态自适应、流体交互** | **iOS 26 →** |

### Apple HIG 三大原则（iOS 26 诠释）

**清晰 Clarity** — 文字永远可读，图标精准传达含义。Liquid Glass 带来的新挑战：玻璃背景下对比度更难保证，需要额外测试。

**顺从 Deference** — UI 服务于内容。iOS 26 的 Tab Bar 在滚动时自动收缩让位于内容，展现了顺从的极致。

**深度 Depth** — 通过折射、反光、层叠传递空间层级。Liquid Glass 将"深度"从视觉比喻变成了物理现实 —— 真实的光线弯曲与镜面反射。

### iOS 26 新增原则

**层级即深度 Hierarchy Through Depth** — 界面重要性通过透明度、折射率、视觉重量来传达，而非仅靠颜色对比或尺寸差异。

**动态自适应 Dynamic Adaptation** — 控件根据背景内容、光线环境、用户行为自动调整透明度与效果强度。

**真实材质 Honest Materiality** — 玻璃效果必须服务于功能目的，而非纯粹装饰。每一个 Liquid Glass 元素都应回答：它的透明性帮助用户做了什么？

---

## 二、Liquid Glass — iOS 26 核心材质

### 2.1 什么是 Liquid Glass

Liquid Glass 是 Apple 为 iOS 26 创造的新材质，具备真实玻璃的物理属性：

- **折射 Lensing** — 实时弯曲并聚焦背景光线（有别于传统模糊只是散射光线）
- **镜面反射 Specular Highlights** — 随设备运动产生高光，响应陀螺仪
- **自适应阴影 Adaptive Shadows** — 阴影随背景内容动态变化
- **流体形变 Fluid Morphing** — 形状和尺寸变化时产生液体流动感
- **物质化 Materialization** — 元素出现时通过逐渐调节光线弯曲度来呈现

### 2.2 原生 API（iOS 26）

```swift
// ─── 基础用法 ───────────────────────────────────────────────
// 最简单：系统自动处理折射、反光、Dark/Light 适配
myView.glassEffect()

// 指定强度
.glassEffect(.regular)        // 标准（最常用）
.glassEffect(.clear)          // 更透明，折射更强

// ─── 指定形状 ───────────────────────────────────────────────
.glassEffect(.regular, in: .capsule)
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

// ─── 着色（Tint） ───────────────────────────────────────────
// 系统在玻璃效果上叠加品牌色调，而非直接染色
.glassEffect(.regular.tint(.blue))
.glassEffect(.regular.tint(Color.accentColor.opacity(0.3)))

// ─── 交互效果 ───────────────────────────────────────────────
// 点击时产生按压/弹跳/闪光反馈
.glassEffect(.regular.interactive())

// ─── 按钮样式（iOS 26 新增）────────────────────────────────
Button("次要操作") { }.buttonStyle(.glass)           // 标准玻璃按钮
Button("主要操作") { }.buttonStyle(.glassProminent)  // 更显眼的玻璃按钮
```

### 2.3 GlassEffectContainer — 多元素协同

> ⚠️ **关键限制：** Liquid Glass 无法采样其他 Liquid Glass（玻璃不能透过玻璃看玻璃）。多个玻璃元素必须放在同一个 `GlassEffectContainer` 内统一渲染，否则产生白色遮罩。

```swift
// 正确：多个 Glass 元素放入 Container
GlassEffectContainer(spacing: 8) {
    Button("步骤") { }.glassEffect(.regular, in: .capsule)
    Button("计划") { }.glassEffect(.regular, in: .capsule)
    Button("档案") { }.glassEffect(.regular, in: .capsule)
}

// 错误：独立嵌套
VStack {
    view1.glassEffect()  // ❌ 无法透视下方的 view2.glassEffect()
    view2.glassEffect()
}
```

### 2.4 Morphing 形变动画

```swift
// 用 glassEffectID 连接同一 namespace 的两个状态
// 系统自动在形状/尺寸之间做流体液态插值
@Namespace var namespace

// 状态 A（收起）
pillView
    .glassEffect(.regular, in: .capsule)
    .glassEffectID("nav", in: namespace)

// 状态 B（展开）
expandedView
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    .glassEffectID("nav", in: namespace)

// withAnimation 触发，系统接管形变过程
withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
    isExpanded.toggle()
}
```

### 2.5 向下兼容（iOS 17+）

```swift
// 统一封装，自动降级
@ViewBuilder
func adaptiveGlass<S: Shape>(in shape: S) -> some View {
    if #available(iOS 26, *) {
        self.glassEffect(.regular.interactive(), in: shape)
    } else {
        self
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
}
```

### 2.6 何时用 Liquid Glass，何时用 Material

| 场景 | 推荐方式 | 理由 |
|---|---|---|
| 浮动导航、Toolbar 按钮 | `.glassEffect()` | 系统原生，自动折射背景 |
| 自定义胶囊/Badge | `.glassEffect(.regular, in: .capsule)` | 轻量，符合系统风格 |
| 大型内容卡片 | `.ultraThinMaterial` | 需要更多控制，Liquid Glass 对大面积效果过强 |
| 设置列表组 | `.ultraThinMaterial` | 信息密度高，玻璃效果会干扰阅读 |
| Alert / 警告横幅 | 纯实色背景 | 需要强对比度保证可读性，玻璃无法保证 |
| 系统控件（Tab Bar 等）| 重新编译即自动获得 | 无需任何代码修改 |

### 2.7 系统控件自动升级

用 **Xcode 26** 重新编译，以下控件自动获得 Liquid Glass，无需修改代码：

```swift
NavigationStack { }        // ✅ 导航栏自动 Liquid Glass
TabView { }                // ✅ Tab Bar 自动收缩/展开
.sheet(isPresented:) { }  // ✅ Sheet 背景自动 Liquid Glass
ToolbarItem { }            // ✅ Toolbar 按钮自动升级
Toggle / Slider            // ✅ 系统控件外观自动更新
.searchable(text:)         // ✅ 搜索栏自动 Liquid Glass
```

> ⚠️ 升级后检查：之前给 Sheet 手动设置 `.background` 的代码需移除，否则会遮蔽 Liquid Glass 效果。

---

## 三、排版系统 Typography

### 3.1 系统字体

iOS 26 继续使用 **SF Rounded**，中文使用 **PingFang SC**。始终通过语义 TextStyle 引用，不得硬编码字号，以支持 Dynamic Type。

> **iOS 26 新要求：** Liquid Glass 背景下文字对比度更难保证，建议对玻璃上的重要文字额外测试，并优先使用 `.primary` 语义色而非固定颜色。

### 3.2 Dynamic Type 类型比例表

| 样式 | 字号 | 字重 | iOS Token | 用途 |
|---|---|---|---|---|
| Large Title | 34pt | Regular | `.largeTitle` | 页面主标题 |
| Title 1 | 28pt | Regular | `.title` | 导航标题 |
| Title 2 | 22pt | Regular | `.title2` | 区块标题 |
| Title 3 | 20pt | Semibold | `.title3` | 卡片标题 |
| Headline | 17pt | Semibold | `.headline` | 列表头部 |
| Body | 17pt | Regular | `.body` | 正文（默认）|
| Callout | 16pt | Regular | `.callout` | 副标题/说明 |
| Subheadline | 15pt | Regular | `.subheadline` | 次要信息 |
| Footnote | 13pt | Regular | `.footnote` | 注脚/标签 |
| Caption 1 | 12pt | Regular | `.caption` | 图注/辅助文字 |
| Caption 2 | 11pt | Regular | `.caption2` | 最小标签 |

### 3.3 排版规范

- **行高** — 正文行高 = 字号 × 1.4～1.6，中文建议 × 1.6
- **行宽** — 单行最大 60～70 个字符（约 320pt 宽）
- **对齐** — 正文左对齐；避免两端对齐（justified）
- **玻璃背景下** — 优先使用 `.primary` / `.secondary` 语义色，系统会自动调整对比度
- **Dynamic Type** — 必须响应用户字号设置，测试 AX5 最大字号

```swift
Text("标题").font(.title2).fontWeight(.semibold)
Text("正文").font(.body).foregroundStyle(.primary)
Text("次要").font(.footnote).foregroundStyle(.secondary)
```

---

## 四、颜色系统 Color System

### 4.1 动态颜色（Adaptive Colors）

**始终使用语义 token，系统自动处理 Light/Dark 切换。不得硬编码十六进制颜色。**

iOS 26 中语义颜色的重要性更加突出 —— Liquid Glass 背景是动态变化的，硬编码颜色在某些背景下可能失去对比度。

### 4.2 系统颜色对照表

| Token | Hex | 角色 |
|---|---|---|
| `goLime` | `#C8FF00` | **主强调色** — CTA 按钮、进度条、选中态 |
| `goPrimary` | `#4338FF` | 品牌蓝 — 链接、导航、信息类 |
| `goMint` | `#00FFD1` | 薄荷辅助 — 完成状态、健康数据 |
| `goYellow` | `#FFD600` | 警告/里程碑 |
| `goOrange` | `#FF8A00` | 逾期/紧急 |
| `goRed` | `#FF3B30` | 危险/删除 |
| `goTeal` | `#00BFA5` | 宠物标签、激活状态 |
| `goCardCyan` | `#00E5FF` | 卡片装饰 |
| `goBlue` | `#0A84FF` | iOS 系统蓝（Blob 用）|
| `goPurple` | `#BF5AF2` | Blob 紫（背景装饰）|
| `arkInk` | `#1A1A2E` | 亮色背景上的黑色文字 |
| `goDarkBlue` | `#0D1B3E` | 深色卡片背景 |
| `goDeepNavy` | `#060E24` | 最深背景层 |

> **规则**：`foregroundStyle` 中必须写 `Color.goLime`，不得省略 `Color.`

### 4.3 自定义颜色的适配

```swift
// 在 Assets.xcassets 创建 Color Set，自动适配 Light/Dark
Color("BrandPrimary")

// 代码中手动适配
@Environment(\.colorScheme) var colorScheme
var isDark: Bool { colorScheme == .dark }
let textColor = isDark ? Color.white : Color.black
```

### 4.4 对比度要求（WCAG AA + iOS 26 玻璃背景）

| 内容类型 | 标准对比度要求 | Liquid Glass 上建议 |
|---|---|---|
| 普通文字（< 18pt）| ≥ 4.5:1 | ≥ 5.5:1（玻璃背景动态，留冗余）|
| 大号文字（≥ 18pt Bold）| ≥ 3:1 | ≥ 4.0:1 |
| UI 组件边框 | ≥ 3:1 | ≥ 3:1 |
| 浮动在纯色背景 | 标准即可 | 标准即可 |

> 💡 Liquid Glass 背景是实时变化的，建议用 **Accessibility Inspector** 在多种壁纸下测试，不要只测静态截图。

### 4.5 Tint Color 规范

```swift
// App 根视图设置全局强调色
.tint(Color("AppTint"))

// iOS 26 的 Liquid Glass tint（玻璃上的品牌着色）
.glassEffect(.regular.tint(Color("AppTint").opacity(0.25)))
```

---

## 五、间距与布局 Spacing & Layout

### 5.1 基础间距单位（8pt Grid）

iOS 26 继承 8pt 网格系统，所有间距值为 4pt 的倍数。

| 名称 | 数值 | 倍率 | 典型用途 |
|---|---|---|---|
| xxSmall | 2pt | ×0.125 | 图标内部间距 |
| xSmall | 4pt | ×0.25 | 图标与标签最小间距 |
| Small | 8pt | ×0.5 | 行内元素间距 |
| Medium | 12pt | ×0.75 | 列表项 padding |
| **Base** | **16pt** | **×1** | **标准内边距（最常用）** |
| Large | 20pt | ×1.25 | 卡片内 padding |
| xLarge | 24pt | ×1.5 | 区块间距 |
| xxLarge | 32pt | ×2 | Section 间距 |
| xxxLarge | 48pt | ×3 | 屏幕顶部大间距 |

### 5.2 Safe Area 规范

| 区域 | iPhone 16 Pro | iPhone SE | 处理方式 |
|---|---|---|---|
| Status Bar | 59pt | 20pt | `safeAreaInsets.top` |
| Home Indicator | 34pt | 0pt | `safeAreaInsets.bottom` |
| Dynamic Island | 含在 top 内 | — | 内容勿覆盖 |
| 侧边（横屏）| 59pt | — | `safeAreaInsets.leading/trailing` |

```swift
// 背景延伸全屏（仅背景层）
backgroundView.ignoresSafeArea()

// 内容尊重安全区（默认行为，无需额外代码）
ScrollView { content }

// 手动添加底部间距（有浮动 Tab Bar 时）
.safeAreaInset(edge: .bottom) {
    Color.clear.frame(height: 80)  // Tab Bar 高度
}
```

### 5.3 iOS 26 Tab Bar 新行为

Tab Bar 在 iOS 26 会随滚动自动收缩/展开，不再固定在底部：

```swift
// 使用 TabView，系统自动处理收缩行为
TabView(selection: $tab) {
    ContentView()
        .tabItem { Label("首页", systemImage: "house") }
        .tag(0)
}
// 无需任何额外配置，Xcode 26 编译后自动获得

// 内容底部留出足够间距（Tab Bar 收缩后内容可见）
.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
```

### 5.4 内容边距规范

- **全宽内容**（图片、横幅）：延伸至屏幕边缘
- **文字内容**：水平边距 ≥ 16pt
- **卡片内容**：内部 padding 16pt，卡片间距 12pt
- **Section 间距**：32～48pt

### 5.5 自适应布局

```swift
// 自适应网格（推荐）
LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))]) { ... }

// iPad 多栏
NavigationSplitView {
    SidebarView()
} detail: {
    DetailView()
}
```

---

## 六、核心组件规范 Components

### 6.1 导航栏 Navigation Bar

iOS 26 导航栏自动应用 Liquid Glass，用 Xcode 26 重新编译即可。

```swift
.navigationTitle("探索")
.navigationBarTitleDisplayMode(.large)

// iOS 26：Large Title 在滚动时自动过渡到 Standard + Liquid Glass
// 无需额外代码
```

**规范：**
- 标题长度 ≤ 20 字符
- Large Title 用于 Tab 根页面，Standard Title 用于子页面
- 右侧按钮 ≤ 3 个，优先 SF Symbols
- **iOS 26 新**：背景自动 Liquid Glass，不得手动覆盖 `.toolbarBackground`（除非有特殊需求）

### 6.2 标签栏 Tab Bar

**iOS 26 重大变化：** Tab Bar 自动收缩（滚动时变成小胶囊），展开时恢复完整。

```swift
// 系统 TabView 自动处理，无需修改
TabView { ... }

// 自定义 Tab Bar（需同步 iOS 26 行为）
// 使用 GlassEffectContainer + glassEffectID 实现 morphing
GlassEffectContainer {
    HStack {
        ForEach(tabs) { tab in
            TabButton(tab)
                .glassEffect(selected == tab ? .regular.tint(.accentColor) : .regular,
                             in: Capsule())
                .glassEffectID(tab.id, in: namespace)
        }
    }
}
```

**规范：**
- Tab 数量 3～5 个
- 图标：SF Symbols，选中 fill，未选中 outline
- 每个 Tab 独立导航栈，切换不清除历史
- Badge 数字超出显示 "99+"

### 6.3 按钮 Button

```swift
// 主要按钮（每屏仅一个）
Button("确认") { }
    .buttonStyle(.borderedProminent)  // 系统实色主按钮
    .controlSize(.large)

// iOS 26 玻璃按钮（次要操作）
Button("分享") { }
    .buttonStyle(.glass)              // Liquid Glass 次要按钮
Button("更多") { }
    .buttonStyle(.glassProminent)     // 更醒目的玻璃按钮

// 危险操作
Button("删除", role: .destructive) { }
// ⚠️ 危险按钮必须搭配 confirmationDialog 二次确认
```

### 6.4 列表 List

```swift
List {
    Section("区块标题") {
        ForEach(items) { item in
            ItemRow(item: item)
        }
        .onDelete(perform: delete)
    }
}
.listStyle(.insetGrouped)
```

**规范：**
- 可点击行：chevron 图标 + 高亮反馈
- 左滑操作 ≤ 4 个，最右侧为主操作
- 空状态：占位图 + 说明 + 引导操作
- 行高 ≥ 44pt（推荐 52pt）

### 6.5 文本输入 TextField

```swift
TextField("邮箱地址", text: $email)
    .keyboardType(.emailAddress)
    .textContentType(.emailAddress)
    .autocorrectionDisabled()

// 错误状态
if hasError {
    Text("请输入有效邮箱").font(.caption).foregroundStyle(.red)
}
```

**规范：**
- 输入框高度 ≥ 44pt
- 使用对应 `keyboardType` 和 `textContentType`
- 焦点时自动滚动保证可见
- 错误：红色边框 + 错误提示文字

### 6.6 弹层与模态

```swift
// Sheet（iOS 26 自动 Liquid Glass 背景）
.sheet(isPresented: $show) {
    SheetContent()
        .presentationDetents([.medium, .large])  // 多档位
        .presentationDragIndicator(.visible)
}

// FullScreenCover（沉浸式）
.fullScreenCover(isPresented: $show) { MediaPlayer() }

// iOS 26 Sheet Morphing（从按钮位置展开）
Button("添加") { show = true }
    .matchedTransitionSource(id: "add", in: ns)

.sheet(isPresented: $show) {
    AddView().navigationTransition(.zoom(sourceID: "add", in: ns))
}
```

---

## 七、Light / Dark Mode

### 7.1 实现原则

- **颜色** — 使用系统语义颜色或 Asset Catalog Adaptive Color
- **图标** — SF Symbols 自动适配；自定义图标提供 Light/Dark 两套
- **图片** — Asset Catalog 添加 Dark Appearance 变体
- **Liquid Glass** — 自动适配，无需额外处理

### 7.2 层级背景色

| 层级 | Light | Dark | SwiftUI |
|---|---|---|---|
| 1 级（主背景）| #FFFFFF | #000000 | `.background` |
| 2 级（卡片/分组）| #F2F2F7 | #1C1C1E | `.secondarySystemBackground` |
| 3 级（嵌套卡片）| #FFFFFF | #2C2C2E | `.tertiarySystemBackground` |
| 分隔线 | #3C3C43 30% | #545458 60% | `.separator` |

### 7.3 代码实现

```swift
@Environment(\.colorScheme) var colorScheme

// 自定义品牌色（推荐：在 Assets.xcassets 创建 Color Set）
Color("BrandPrimary")  // 系统自动切换

// 手动适配（仅在必要时）
var isDark: Bool { colorScheme == .dark }
Color(isDark ? "SurfaceDark" : "SurfaceLight")
```

### 7.4 Dark Mode 检查清单

- [ ] 所有颜色使用语义 token，无硬编码 `#000000` / `#FFFFFF`
- [ ] Liquid Glass 元素在两种模式下视觉效果均已验证
- [ ] 阴影在 Dark Mode 下减弱（opacity ×0.5）或改为描边
- [ ] 图片在深色背景下清晰可见
- [ ] 设备上实测（不只在模拟器），尤其是玻璃效果

> ⚠️ **iOS 26 特别注意：** Liquid Glass 在 Light Mode 下折射率更高、高光更强，在暗色背景下更透明。必须两种模式都测试，某些文字组合在某模式下可能失去对比度。

### 7.5 强制覆盖

```swift
.preferredColorScheme(.dark)   // 强制该视图树为深色（如媒体播放）
.preferredColorScheme(.light)  // 强制浅色（如证件展示）
```

---

## 八、触控与手势规范

### 8.1 触控目标尺寸

| 元素 | 最小尺寸 | 推荐尺寸 | 备注 |
|---|---|---|---|
| 普通按钮 | 44×44pt | 50×50pt | Apple HIG 最低标准 |
| Tab Bar 图标区 | 44×44pt | 44×44pt | 整体区域含标签 |
| 列表行 | 44pt 高 | 52pt 高 | 左右 padding ≥ 16pt |
| 导航栏按钮 | 44×44pt | 44×44pt | 可视区域可更小 |
| 文本输入框 | 44pt 高 | 48pt 高 | — |
| 开关 Switch | 系统固定 | 51×31pt | 勿自定义 |

### 8.2 手势规范

- **Tap** — 单次轻触执行主要操作
- **Long Press** — 触发 `contextMenu` 或 Peek 预览
- **Swipe** — 水平滑动删除/操作，垂直滑动滚动
- **Pinch** — 缩放，必须提供双击替代方式
- **系统手势优先** — 不得拦截下拉通知栏、右滑返回、上滑 Home

### 8.3 触觉反馈 Haptics

```swift
// 轻触反馈
UIImpactFeedbackGenerator(style: .light).impactOccurred()

// 中等按压（重要操作）
UIImpactFeedbackGenerator(style: .medium).impactOccurred()

// 操作成功
UINotificationFeedbackGenerator().notificationOccurred(.success)

// 操作失败
UINotificationFeedbackGenerator().notificationOccurred(.error)

// 选择变化（如 Picker 滚动）
UISelectionFeedbackGenerator().selectionChanged()
```

> 💡 每次用户主动操作最多一次触觉反馈，后台操作不触发。Liquid Glass 的 `.interactive()` 内置了触觉反馈，不要重复添加。

---

## 九、动画规范 Animation

### 9.1 标准动画参数

| 场景 | 时长 | 参数 | SwiftUI |
|---|---|---|---|
| Liquid Glass Morphing | 系统控制 | — | `glassEffectID` 自动处理 |
| Sheet 弹出 | 0.45s | spring(0.75) | `.spring(response: 0.45, dampingFraction: 0.75)` |
| 视图出现/消失 | 0.35s | easeInOut | `.easeInOut(duration: 0.35)` |
| 按钮点击 | 0.12s | easeOut | `.scaleEffect(0.96)` |
| 列表项出现 | staggered | — | 每项 delay +0.05s |
| 错误抖动 | 0.4s | keyframe | ±8pt 水平抖动 × 3次 |
| Loading | 1.0s 循环 | linear | `.linear.repeatForever` |

### 9.2 iOS 26 Sheet Morphing

```swift
// 按钮 → Sheet 的流体展开动画
@Namespace var ns

Button("新建") { isPresented = true }
    .matchedTransitionSource(id: "btn", in: ns)

.sheet(isPresented: $isPresented) {
    NewItemView()
        .navigationTransition(.zoom(sourceID: "btn", in: ns))
}
```

### 9.3 减少动效适配（必须实现）

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// 按钮点击
.scaleEffect(isPressed ? 0.96 : 1.0)
.animation(reduceMotion ? .none : .easeOut(duration: 0.12), value: isPressed)

// 转场动画
.transition(reduceMotion
    ? .opacity
    : .scale(scale: 0.92).combined(with: .opacity))
```

### 9.4 动画原则

- 动画服务于功能，帮助理解界面变化，不是展示技巧
- 遵循 iOS 弹性动画风格（spring），避免线性匀速
- Liquid Glass 的流体动画由系统控制，开发者不应试图覆盖
- 复杂动画使用 `withAnimation` 包裹状态变化，不要直接操作视图

---

## 十、图标与图片 Icons & Images

### 10.1 SF Symbols 7（iOS 26）

SF Symbols 7 随 iOS 26 发布，提供 6000+ 图标。

```swift
// 渲染模式
Image(systemName: "heart.fill")
    .symbolRenderingMode(.hierarchical)    // 多层彩色（推荐）
    .symbolRenderingMode(.multicolor)      // 系统多色
    .symbolRenderingMode(.palette)         // 自定义多色

// 动画（iOS 17+）
Image(systemName: "wifi")
    .symbolEffect(.variableColor.iterative)  // 循环动画

// iOS 26 新增：玻璃效果 SF Symbol
Image(systemName: "star.fill")
    .glassEffect(.regular, in: Circle())     // Symbol 也可加玻璃
```

### 10.2 App Icon — iOS 26 四套规范

> **iOS 26 新增 Clear（透明）变体**，共需四套图标。

| 变体 | Assets 路径 | 外观 | 设计要求 |
|---|---|---|---|
| Standard | `AppIcon` | 正常 | 现有图标 1024×1024pt |
| **Dark** | `AppIcon → Dark` | 深色主题 | 深色背景，高亮主体 |
| **Tinted** | `AppIcon → Tinted` | 系统着色 | 单色调，系统根据壁纸着色 |
| **Clear** *(新)* | `AppIcon → Clear` | 透明玻璃 | Liquid Glass 材质，Icon Composer 工具制作 |

**Icon Composer 工具（Xcode 26 新增）：**

```
使用 Icon Composer 可将单个设计文件自动导出为全部四套变体。
工具路径：Xcode → Open Developer Tool → Icon Composer
输入：前景层 + 背景层（分离的 PNG）
输出：自动生成 Standard / Dark / Tinted / Clear 全套
```

**图标设计规范：**

- 主图标：1024×1024px PNG，无圆角（系统自动裁切）
- 背景不透明，关键内容避开边角（系统圆角会裁切）
- Dark 版：背景明显加深，主体元素保持清晰
- Tinted 版：降低颜色复杂度，确保单色时仍可辨认
- Clear 版：强调形状轮廓，折射背景时仍能识别品牌

### 10.3 图片加载规范

```swift
AsyncImage(url: imageURL) { phase in
    switch phase {
    case .empty:
        ProgressView()
            .frame(width: 60, height: 60)
    case .success(let image):
        image
            .resizable()
            .scaledToFill()
    case .failure:
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
            .frame(width: 60, height: 60)
    @unknown default:
        EmptyView()
    }
}
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
```

---

## 十一、无障碍设计 Accessibility

> **iOS 26 特别提示：** Liquid Glass 带来了新的无障碍挑战。Apple 已更新 HIG 中关于透明背景的无障碍指南，开发者需额外关注玻璃背景下的文字可读性。

### 11.1 VoiceOver

```swift
// 图标按钮必须有标签
Image(systemName: "heart.fill")
    .accessibilityLabel("已收藏")
    .accessibilityHint("双击取消收藏")

// 装饰性元素隐藏
decorativeView.accessibilityHidden(true)

// Liquid Glass 控件
Button("确认") { }
    .buttonStyle(.glass)
    .accessibilityLabel("确认操作")   // .glass 样式需手动添加标签
```

### 11.2 Reduce Transparency（iOS 26 更重要）

iOS 26 的 Liquid Glass 效果比以往的毛玻璃更激进，关闭透明时必须提供清晰降级方案：

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var body: some View {
    if reduceTransparency {
        // 降级：纯色不透明背景，确保可读性
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    } else {
        // 正常：Liquid Glass
        content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}
```

### 11.3 Dynamic Type

```swift
// 图标随字号缩放
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24

// 测试最大字号（AX5）
// Xcode → Simulator → Settings → Accessibility → Larger Text
```

### 11.4 颜色无障碍

```swift
@Environment(\.accessibilityDifferentiateWithoutColor) var diffColor

// 仅用颜色区分时，增加形状/图标补充
if diffColor {
    Image(systemName: "checkmark.circle.fill")  // 添加形状区分
}
```

### 11.5 对比度增强

```swift
@Environment(\.accessibilityIncreaseContrast) var highContrast

// Liquid Glass 在高对比度模式下应更不透明
.glassEffect(highContrast ? .regular : .clear)
```

---

## 十二、性能设计准则 Performance

### 12.1 Liquid Glass 性能注意

Liquid Glass 的折射效果比传统 blur 计算量更大，需要注意：

- **大面积慎用** — 全屏 Liquid Glass 会持续占用 GPU，优先用于小型控件
- **静止时优化** — 静止状态下系统会自动降低采样率，不要手动禁用
- **嵌套限制** — 避免 Glass 嵌套（用 `GlassEffectContainer` 解决）
- **列表中慎用** — 滚动时每帧都需重新渲染折射，性能敏感

```swift
// 大面积内容区域使用 Material 而非 Liquid Glass
.background(.ultraThinMaterial)  // ✅ 低成本模糊

// 小型控件才使用 Liquid Glass
button.glassEffect(.regular, in: .capsule)  // ✅ 面积小，可接受
```

### 12.2 渲染性能

- 列表避免视图层级超过 5 层
- `Equatable` 协议减少不必要的重渲染
- 使用 Instruments → Core Animation 验证帧率（目标 60fps / 120fps ProMotion）
- 异步解码图片，不在主线程处理

### 12.3 启动优化

- Cold Start 目标 **< 400ms**，Warm Start **< 200ms**
- LaunchScreen 使用静态 Storyboard，不得有动画
- 非首屏服务（Analytics、第三方 SDK）延迟初始化

### 12.4 内存管理

- 列表缩略图使用 thumbnail，不加载全尺寸图
- `@StateObject` 管理生命周期
- 响应 `didReceiveMemoryWarning`

---

## 十三、发布前设计检查清单

### ✅ Liquid Glass 合规

- [ ] 使用 Xcode 26 重新编译，系统控件自动升级已验证
- [ ] 多个 Glass 元素使用 `GlassEffectContainer` 包裹
- [ ] Glass 背景上的文字对比度 ≥ 4.5:1（多种壁纸下测试）
- [ ] Alert / 警告类 Banner 使用纯实色背景，不使用 Glass
- [ ] 关闭透明效果（Reduce Transparency）时有清晰降级方案
- [ ] Sheet 不手动设置背景（让 Liquid Glass 自然呈现）

### ✅ 图标 Icons

- [ ] App Icon 提供 **四套**：Standard / Dark / Tinted / Clear
- [ ] 使用 Icon Composer 工具生成，或手动提供所有变体
- [ ] SF Symbols 版本验证（iOS 26 使用 SF Symbols 7）

### ✅ 视觉 Visual

- [ ] 所有颜色使用语义 token，Light/Dark 均已验证
- [ ] 对比度满足 WCAG AA（玻璃背景下留冗余余量）
- [ ] 所有图片提供 @2x / @3x

### ✅ 布局 Layout

- [ ] Safe Area 适配，Dynamic Island / Home Indicator 不遮挡
- [ ] 横屏布局测试
- [ ] iPad 布局测试（若声明支持）
- [ ] Dynamic Type AX5 最大字号不溢出

### ✅ 交互 Interaction

- [ ] 所有可点击元素 ≥ 44×44pt
- [ ] Loading / 空状态 / 错误状态均已设计
- [ ] 关键操作有 Haptics 反馈
- [ ] `accessibilityReduceMotion` 适配，动画可降级
- [ ] `accessibilityReduceTransparency` 适配，Glass 可降级

### ✅ 无障碍 Accessibility

- [ ] VoiceOver 逐页测试，所有操作可完成
- [ ] 图标按钮有 `accessibilityLabel`
- [ ] Liquid Glass 控件有无障碍标签
- [ ] 颜色非唯一信息传递手段

### ✅ 性能 Performance

- [ ] Instruments 无内存泄漏
- [ ] 滚动帧率 ≥ 60fps（ProMotion 设备 120fps）
- [ ] Cold Start < 400ms
- [ ] 大面积 Liquid Glass 已改为 `.ultraThinMaterial`

---

## 十四、Ohana 背景口号系统（Shorthand System）

> 在描述 UI 需求时使用以下口号，确保 AI 和开发者对背景样式达成一致理解。

### 14.1 口号对照表

| 口号 | 含义 | 代码实现 | 使用场景 | 参考组件 |
|------|------|----------|----------|----------|
| **卡片标准背景** | 8 层 Liquid Glass 折射系统，自适应透明度 | `glassCard { content }` 或 `UltimateGlassCard { content }` | 大面积内容卡片、设置组、表单容器 | Typography 卡片、生命之树卡片、设置页 section |
| **玻璃背景** | iOS 26 原生 `.glassEffect()` 单层磨砂折射 | `.glassEffect(.regular, in: shape)` | 浮动按钮、导航栏、Dock、小型交互控件 | Dock 栏、详情页右上角椰子+编辑按钮、胶囊按钮 |
| **内嵌背景** | 卡片内部的次级区域背景 | `.background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))` | 卡片内的 Bento 格、输入框、标签区 | statsBento 内的 mini 格子、体重/卡路里格子 |
| **纯色背景** | 不透明实色，用于需要强对比度的场景 | `.background(Color.goLime, in: Capsule())` | CTA 按钮、Alert Banner、危险操作 | 主要按钮、成功/失败提示条 |

### 14.2 「卡片标准背景」详细参数

```swift
// glassCard — 自适应透明度容器（推荐使用）
// Dark Mode: .glassEffect(.regular, in: RoundedRectangle(24))
// Light Mode: .ultraThinMaterial.opacity(0.3) + RoundedRectangle(24)
// 无障碍降级: Color(.systemBackground).opacity(0.95) + RoundedRectangle(24)

@ViewBuilder
private func glassCard<C: View>(@ViewBuilder content: () -> C) -> some View {
    if reduceTransparency {
        // 无障碍降级：纯色不透明背景
        content()
            .background(Color(.systemBackground).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    } else {
        // 浅色模式下更透明
        if colorScheme == .light {
            content()
                .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

// 使用示例
glassCard {
    VStack(spacing: 14) {
        sectionTitle("Typography System")
        // ... 内容
    }
    .padding(16)
}
```

```swift
// UltimateGlassCard — 8 层 Liquid Glass 折射系统（传统实现）
// Dark Mode 层级：
//   L1: .ultraThinMaterial（系统毛玻璃基底）
//   L2: Color.white.opacity(0.05)（微亮层）
//   L3: LinearGradient 顶底白边（折射模拟）
//   L4: RadialGradient 暗角（multiply 混合）
//   L5: strokeBorder white 0.12（内描边）
//   L6: 蓝色 + 红色极细描边（色散模拟）
//   L7: 顶部高光胶囊条（0.5pt）
//   L8: 左上角椭圆光斑（blur 8）
// 圆角: 24pt continuous
// 阴影: black 0.20 radius 20 y10 + white 0.06 radius 30 y20

UltimateGlassCard {
    VStack { /* 内容 */ }
        .padding(16)
}
```

### 14.3 「玻璃背景」详细参数

```swift
// iOS 26 原生 Liquid Glass — 系统自动处理折射、反光、Dark/Light 适配
// 圆角由 shape 参数决定

// Dock 样式（标准实现）
HStack(spacing: 16) {
    ForEach(["house.fill", "calendar", "pawprint.fill", "leaf.fill"], id: \.self) { icon in
        Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(secondaryText)
    }
}
.padding(.horizontal, 20).padding(.vertical, 12)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

// 胶囊按钮
HStack(spacing: 6) {
    Text("🥥").font(.system(size: 14))
    Text("128").font(OhanaFont.caption(.bold)).foregroundStyle(primaryText)
}
.padding(.horizontal, 12).padding(.vertical, 8)
.glassEffect(.regular, in: Capsule())

// 圆形按钮
Image(systemName: "pencil")
    .font(.system(size: 14, weight: .semibold))
    .foregroundStyle(secondaryText)
    .frame(width: 36, height: 36)
    .glassEffect(.regular, in: Circle())

// 带品牌着色（可选）
content
    .glassEffect(.regular.tint(Color.goLime.opacity(0.2)), in: Circle())
```

### 14.4 自适应文字颜色系统

```swift
// 根据颜色方案自动调整文字颜色，避免在浅色模式下使用过亮颜色
@Environment(\.colorScheme) private var colorScheme

private var primaryText: Color {
    colorScheme == .dark ? .white : .black
}

private var secondaryText: Color {
    colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
}

private var tertiaryText: Color {
    colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4)
}

// 强调色（避免 goLime/goYellow/goMint/white）
private var accentColor: Color {
    colorScheme == .dark ? Color.goTeal : Color.goBlue
}

// 使用示例
Text("标题")
    .font(OhanaFont.headline(.bold))
    .foregroundStyle(primaryText)

Text("副标题")
    .font(OhanaFont.caption2())
    .foregroundStyle(secondaryText)

Text("说明文字")
    .font(OhanaFont.caption2())
    .foregroundStyle(tertiaryText)
```

### 14.5 「内嵌背景」详细参数

```swift
// 卡片内部子区域，低对比度半透明
// 实际示例：体重/卡路里 Bento 格子
ForEach([("scalemass.fill", "24.5", "kg", Color.goTeal),
         ("flame.fill", "1240", "kcal", Color.goOrange)], id: \.0) { item in
    VStack(alignment: .leading, spacing: 4) {
        Image(systemName: item.0).font(.system(size: 16, weight: .bold)).foregroundStyle(item.3)
        Spacer()
        Text(item.1).font(OhanaFont.metric(size: 16)).foregroundStyle(primaryText)
        Text(item.2).font(OhanaFont.caption2()).foregroundStyle(tertiaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .frame(height: 80)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
}
```

### 14.6 「纯色背景」详细参数

```swift
// 不透明实色，用于需要强对比度的场景
// 实际示例：主要按钮 + 危险操作按钮
HStack(spacing: 10) {
    Text("主要按钮")
        .font(OhanaFont.callout(.bold))
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.goLime, in: Capsule())
    
    Text("危险操作")
        .font(OhanaFont.callout(.bold))
        .foregroundStyle(Color.goRed)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.goRed.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
}
```

### 14.7 使用决策树

```
需要背景？
├─ 大面积内容卡片（表单/详情/数据面板）
│   └─ 「卡片标准背景」glassCard { content }
│       ├─ Dark Mode: .glassEffect(.regular, in: RoundedRectangle(24))
│       └─ Light Mode: .ultraThinMaterial.opacity(0.3) + RoundedRectangle(24)
├─ 浮动小型控件（按钮/Dock/胶囊/Badge）
│   └─ 「玻璃背景」.glassEffect(.regular, in: shape)
│       ├─ Dock: RoundedRectangle(cornerRadius: 22)
│       ├─ 胶囊: Capsule()
│       └─ 圆形: Circle()
├─ 卡片内部的分区/格子
│   └─ 「内嵌背景」.white.opacity(0.08) + RoundedRectangle(16)
└─ 强对比度（CTA/Alert/危险）
    └─ 「纯色背景」实色填充
        ├─ 主要操作: Color.goLime
        └─ 危险操作: Color.goRed.opacity(0.12) + strokeBorder
```

### 14.8 实际应用示例

```swift
// iOS 26 UI 测试页中的完整实现
private var cardBackgroundComparison: some View {
    VStack(alignment: .leading, spacing: 14) {
        sectionTitle("背景口号系统 · Shorthand")
        thinDivider

        // 1. 卡片标准背景 — 使用 glassCard 容器
        glassCard {
            HStack(spacing: 12) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("生命之树卡片")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(primaryText)
                    Text("大面积内容卡片 · 设置组 · 表单")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(secondaryText)
                }
                Spacer()
            }
            .padding(16)
        }

        // 2. 玻璃背景 — 直接使用 .glassEffect()
        HStack(spacing: 12) {
            // Dock 样式
            HStack(spacing: 16) {
                ForEach(["house.fill", "calendar", "pawprint.fill", "leaf.fill"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(secondaryText)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
    .padding(16)
}
```

---

## 快速参考

```
设计语言    iOS 26 Liquid Glass — 自 iOS 7 以来最大重设计
核心 API    .glassEffect() · GlassEffectContainer · glassEffectID
字体        SF Pro / SF Rounded · 语义 TextStyle · 禁止硬编码字号
颜色        语义 token · 禁止硬编码 HEX · Asset Catalog Adaptive Color
圆角        .continuous style · 大卡片 24pt · 标准 20pt · 格子 16pt
间距        8pt 网格 · Base=16pt 最常用 · Section 间距 32pt
对比度      普通文字 ≥ 4.5:1 · 玻璃背景建议 ≥ 5.5:1
触控目标    最小 44×44pt · 列表行 52pt 高
动画        spring(0.45, 0.75) · Morphing 用 glassEffectID
Tab Bar     iOS 26 自动收缩 · 重新编译即可 · 无需修改代码
App Icon    四套：Standard / Dark / Tinted / Clear · Icon Composer
降级        #available(iOS 26, *) + .ultraThinMaterial 降级
```

---

*参考资料：[Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) · [Apple Newsroom — iOS 26 Design](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/) · developer.apple.com/design*  
*基于 iOS 26 · Xcode 26 · SF Symbols 7 · 2026-03*
