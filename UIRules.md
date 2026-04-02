# Ohana UI 设计规范

> 基于 iOS 26 Liquid Glass 原生 API，适用于 Ohana App 所有页面。
> **所有新建/修改页面必须遵循此规范。**

---

## 一、颜色系统

### 全局主色
```swift
Color.goPrimary   // 自适应：浅色 #FF7600（橙）/ 深色 #C8FF00（荧光绿）
Color.arkInk      // 黑色，用于主色按钮上的文字
```

### 品牌色板
```swift
Color.goYellow    // #FFF44F  — 高亮/奖励
Color.goOrange    // #FF8C42  — 次要强调
Color.goRed       // #FF4757  — 错误/危险/删除
Color.goTeal      // #00D4AA  — 成功/健康
Color.goMint      //          — 植物/自然
Color.goBlue      //          — 信息/链接
Color.goPurple    //          — 神秘/设置
```

### 自适应文字色（必须按此使用，禁止硬编码 .white）
```swift
// 在视图中定义：
var primaryText: Color   { colorScheme == .dark ? .white : .black }
var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
var tertiaryText: Color  { colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4) }
var accentColor: Color   { colorScheme == .dark ? Color.goTeal : Color.goBlue }
```

### 宠物主题色（16种非绿高对比度色）
```swift
Color.petThemeCrimson / Vermilion / Orange / Amber / Yellow
Color.petThemeBrown / Rust / Burgundy / Magenta / Pink
Color.petThemePurple / Indigo / Violet / Navy / Blue / SkyBlue
```

---

## 二、背景层次系统（4种）

### 1. 卡片默认背景（推荐）
```swift
// 深色模式
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

// 浅色模式（降级）
.background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

// 无障碍降级（reduceTransparency）
.background(Color(.systemBackground).opacity(0.95))
.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
```
**适用场景**：默认信息卡、面板卡、图表承载卡（首选默认）。

### 2. 导航栏 / Dock 玻璃
```swift
// Dock 圆角矩形
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

// 胶囊（椰子数、标签等）
.glassEffect(.regular, in: Capsule())

// 圆形按钮
.glassEffect(.regular, in: Circle())
```
**适用场景**：顶栏固定控件、浮层操作条、工具条。

### 3. 内嵌背景（卡片内部子区域）
```swift
.background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
```
**适用场景**：Bento 统计格、次级信息容器、轻分组区域（不要在顶层卡使用）。

### 4. 纯色背景（CTA / 危险操作）
```swift
// 主要 CTA
.background(Color.goPrimary, in: Capsule())  // 文字用 Color.arkInk

// 危险操作
.background(Color.goRed.opacity(0.12), in: Capsule())
.overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
// 文字用 Color.goRed
```
**适用场景**：关键 CTA、删除/停用等危险操作、状态强调。

---

## 三、字体系统（OhanaFont）

**必须使用 `OhanaFont` 封装**，禁止直接 `.font(.system(size:weight:))`。

```swift
OhanaFont.largeTitle()          // 大标题
OhanaFont.title()               // 标题
OhanaFont.title2(.bold)         // 二级标题
OhanaFont.title3(.bold)         // 三级标题
OhanaFont.headline(.bold)       // 头部文字 / 按钮
OhanaFont.subheadline(.bold)    // 子标题
OhanaFont.body()                // 正文
OhanaFont.callout(.semibold)    // 辅助说明
OhanaFont.caption(.bold)        // 小标签
OhanaFont.caption2(.bold)       // 最小标签
OhanaFont.metric(size: 36)      // 大数字（体重/步数等指标）
```

---

## 四、按钮规范

### 主要 CTA（全宽胶囊）
```swift
Button { } label: {
    Text("确认")
        .font(OhanaFont.headline(.bold))
        .foregroundStyle(Color.arkInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.goPrimary, in: Capsule())
}
.buttonStyle(.plain)
```

### 次要按钮（Glass）
```swift
Button { } label: {
    Text("取消").font(OhanaFont.callout(.semibold)).foregroundStyle(.primary)
        .frame(maxWidth: .infinity).padding(.vertical, 14)
}
.buttonStyle(.glass)                   // 普通
.buttonStyle(.glassProminent)          // 醒目
```

### 图标圆形按钮
```swift
Button { } label: {
    Image(systemName: "plus")
        .font(OhanaFont.headline())
        .foregroundStyle(Color.goPrimary)
        .frame(width: 48, height: 48)
}
.glassEffect(.regular.tint(Color.goPrimary.opacity(0.2)), in: Circle())
```

### 危险操作按钮
```swift
Button { } label: {
    Text("删除")
        .font(OhanaFont.callout(.semibold))
        .foregroundStyle(Color.goRed)
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.goRed.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
}
.buttonStyle(.plain)
```

---

## 五、组件规范

### 状态徽章（Status Badge）
```swift
func statusBadge(_ label: String, color: Color) -> some View {
    Text(label)
        .font(OhanaFont.caption2(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
}
```

### 分割线
```swift
Rectangle()
    .fill(.white.opacity(0.1))
    .frame(height: 1)
```

### 列表行头图标
```swift
ZStack {
    Circle().fill(color.opacity(0.15)).frame(width: 40, height: 40)
    Image(systemName: iconName)
        .font(OhanaFont.body(.semibold))
        .foregroundStyle(color)
}
```

### 进度条
```swift
GeometryReader { geo in
    ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.08)).frame(height: 6)
        Capsule().fill(color).frame(width: geo.size.width * progress, height: 6)
    }
}.frame(height: 6)
```

### 进度环
```swift
ZStack {
    Circle().stroke(.white.opacity(0.08), lineWidth: 10)
    Circle().trim(from: 0, to: progress)
        .stroke(
            LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
            style: StrokeStyle(lineWidth: 10, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
}
```

### 空状态
```swift
VStack(spacing: 14) {
    ZStack {
        Circle().fill(Color.goPrimary.opacity(0.15)).frame(width: 72, height: 72)
        Image(systemName: iconName).font(.system(size: 32)).foregroundStyle(Color.goPrimary)
    }
    Text("暂无记录").font(OhanaFont.title3(.bold)).foregroundStyle(primaryText)
    Text("说明文字").font(OhanaFont.callout()).foregroundStyle(secondaryText)
        .multilineTextAlignment(.center)
    // 可选：CTA 按钮
}
.frame(maxWidth: .infinity)
```

### Alert Banner
```swift
func alertRow(icon: String, color: Color, title: String) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.arkInk)
        Text(title).font(OhanaFont.headline(.bold)).foregroundStyle(Color.arkInk)
        Spacer()
    }
    .padding(.horizontal, 20).padding(.vertical, 16)
    .background(color, in: Capsule())
}
```

### Chips（横向滑动标签）
```swift
// 选中态
Text(label)
    .font(OhanaFont.caption(.bold)).foregroundStyle(Color.arkInk)
    .padding(.horizontal, 14).padding(.vertical, 8)
    .glassEffect(.regular.tint(tintColor.opacity(0.8)), in: Capsule())

// 未选中态
Text(label)
    .font(OhanaFont.caption(.bold)).foregroundStyle(.white)
    .padding(.horizontal, 14).padding(.vertical, 8)
    .glassEffect(.regular, in: Capsule())
```

---

## 六、布局规范

### 间距
| 区域 | 值 |
|------|----|
| 页面主要内容水平 padding | **24pt** |
| 卡片内部 padding | **16pt** |
| 卡片内嵌 Bento 格 padding | **14pt** |
| 卡片之间间距 | **20pt** |
| 小组件内边距 | **12pt** |

### 圆角
| 元素 | 圆角值 |
|------|--------|
| 主卡片 / Modal | **24pt** |
| 内嵌 Bento 格 | **14pt** |
| Dock / 浮层 | **22pt** |
| 小胶囊 | Capsule |
| 输入框 | **12pt** |

---

## 七、表单输入规范

```swift
// 文本输入框
HStack {
    Image(systemName: "pencil").foregroundStyle(.white.opacity(0.3))
    TextField("占位符...", text: $value).foregroundStyle(.white)
}
.padding(12)
.background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

// Toggle
Toggle("标签", isOn: $flag)
    .tint(Color.goPrimary)
    .font(OhanaFont.callout(.bold))

// Slider
Slider(value: $val).tint(Color.goPrimary)

// Segmented Picker
Picker("", selection: $seg) { ... }
    .pickerStyle(.segmented)
```

---

## 八、Sheet / 弹窗规范

```swift
// 标准 Sheet 设置
.presentationDetents([.medium, .large])
.presentationDragIndicator(.visible)
.presentationBackground(.bar)           // 或 .clear + ArkBackgroundView

// 输入类 Sheet（如记账、体重输入）
.presentationDetents([.fraction(0.56), .large])
.presentationBackground(.bar)

// 全屏详情页（如健康详情、保险详情）
.presentationDetents([.large])
```

### Sheet 顶部导航栏
```swift
NavigationStack {
    // 内容
    .navigationTitle("标题")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button { dismiss() } label: { Image(systemName: "xmark") }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存") { save() }
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.goPrimary)
        }
    }
    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
}
```

---

## 九、图标使用规范

- **优先使用 SF Symbols**，禁止 Emoji 作为功能图标（Emoji 仅用于装饰性内容）
- 图标颜色应跟随语境：功能性图标 → 宠物主题色 / `goPrimary`，状态图标 → 语义色（成功用 goTeal，危险用 goRed）
- 图标 + 文字的 `Label`：`Image(systemName:)` + `Text()`，间距 4~8pt

---

## 十、无障碍

```swift
// 减少透明度降级
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

if reduceTransparency {
    content.background(Color(.systemBackground).opacity(0.95))
           .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
} else {
    content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
}

// 减少动画
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// 动画中使用 guard !reduceMotion else { /* 静态终态 */ }
```

---

## 十一、图表规范（Swift Charts）

```swift
// 折线图
LineMark(x: .value("日期", date), y: .value("值", value))
    .interpolationMethod(.catmullRom)
    .foregroundStyle(Color.goPrimary)
    .lineStyle(StrokeStyle(lineWidth: 2.5))
AreaMark(x: .value("日期", date), y: .value("值", value))
    .interpolationMethod(.catmullRom)
    .foregroundStyle(LinearGradient(colors: [Color.goPrimary.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))

// 坐标轴标签颜色
AxisMarks { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.5)) }

// 多系列图（全岛体重）：按 UUID seriesID 分线，宠物权重使用 weightInKg
```

---

## 十二、动画规范

- 交互反馈用 `spring(response: 0.3~0.4, dampingFraction: 0.82)`
- 列表入场用 staggered `delay`（每项 +0.05s）
- 关键操作用 `UIImpactFeedbackGenerator`（`.medium`）或 `UINotificationFeedbackGenerator`（`.success`）
- 动画状态变量隔离到独立子 View，避免带动父视图重渲染
- 父视图 `ScrollView`/内容区：`.transaction { $0.disablesAnimations = true }` 防止被子 View 动画带动

---

## 十三、禁止事项

- ❌ 禁止在整个 App 中使用 `UIScreen.main.bounds`（iOS 26 已弃用）
- ❌ 禁止硬编码 `.white` 作为通用文字颜色（改用 `primaryText`/`secondaryText`）
- ❌ 禁止使用 Emoji 作为功能性图标（改用 SF Symbols）
- ❌ 禁止 `repeatForever` 持续动画（性能消耗大，降低功耗）
- ❌ 禁止直接 `.font(.system(size:weight:))`（改用 `OhanaFont`）
- ❌ 禁止 `Color.goLime` 直接用于双色模式场景（改用 `Color.goPrimary`）
