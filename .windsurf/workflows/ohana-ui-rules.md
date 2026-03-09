---
description: Ohana iOS App 全局 UI 规范 — 新建任何 View 前必读
---

# Ohana Global UI Rules

## 1. 字体系统 — SF Pro Rounded（强制）

**所有文字必须使用 `OhanaFont` 工具函数**，禁止直接写 `.font(.system(size:weight:))`（除非需要传入动态 size 变量）。

```swift
// ✅ 正确
Text("标题").font(OhanaFont.title(.black))
Text("正文").font(OhanaFont.body())
Text("数字").font(OhanaFont.metric(size: 48))

// ❌ 错误
Text("标题").font(.system(size: 24, weight: .bold))
Text("标题").font(.title)
```

| 函数 | size | 默认 weight | 用途 |
|------|------|-------------|------|
| `OhanaFont.largeTitle()` | 34 | .black | 页面主标题 |
| `OhanaFont.title()` | 24 | .bold | Section 标题 |
| `OhanaFont.title2()` | 20 | .bold | 卡片标题 |
| `OhanaFont.title3()` | 17 | .semibold | 子标题 |
| `OhanaFont.headline()` | 16 | .bold | 按钮/重要标签 |
| `OhanaFont.body()` | 15 | .medium | 正文 |
| `OhanaFont.callout()` | 14 | .medium | 辅助正文 |
| `OhanaFont.subheadline()` | 13 | .medium | 说明文字 |
| `OhanaFont.footnote()` | 12 | .medium | 脚注 |
| `OhanaFont.caption()` | 11 | .medium | 小标签 |
| `OhanaFont.caption2()` | 10 | .medium | 最小标签 |
| `OhanaFont.metric(size:)` | 动态 | .black | 大数字/指标 |

---

## 2. 颜色系统 — Go UI Palette + Figma Tokens

### 主色板（Go UI）

| Token | 用途 |
|-------|------|
| `Color.goPrimary` (#4338FF) | 主交互色、选中态 |
| `Color.goLime` (#C8FF00) | 主强调色、CTA 按钮 |
| `Color.goYellow` (#FFF44F) | 椰子/奖励 |
| `Color.goTeal` (#00D4AA) | 成功/体重 |
| `Color.goOrange` (#FF8C42) | 喂食/日常照料 |
| `Color.goRed` (#FF4757) | 错误/警告 |
| `Color.goCardCyan` (#80FFEA) | 护理/数据统计 |
| `Color.goDarkBlue` (#1A0E4B) | 深色卡片背景 |
| `Color.goDeepNavy` (#0D0638) | 最深背景 |

### Alert 语义色（Figma Tokens，自动 Light/Dark 适配）

```swift
// 不要写死颜色，直接使用语义 token
AlertBanner(style: .success, message: "操作成功")
AlertBanner(style: .warning, message: "请注意")
AlertBanner(style: .error,   message: "发生错误")
AlertBanner(style: .info,    message: "提示信息")

// 或手动使用 token 颜色
Color.alertSuccessBg / .alertSuccessBorder / .alertSuccessText / .alertSuccessIcon
Color.alertWarningBg / .alertWarningBorder / .alertWarningText / .alertWarningIcon
Color.alertErrorBg   / .alertErrorBorder   / .alertErrorText   / .alertErrorIcon
Color.alertInfoBg    / .alertInfoBorder    / .alertInfoText    / .alertInfoIcon
```

### 颜色使用原则

- **深色背景（goTranslucentCard / goBlueCard）上**：文字用 `.white` 或 `.white.opacity(0.xx)`
- **亮色背景（goCard 白/青柠/薄荷）上**：文字用 `Color.arkInk`
- **强调数字/指标**：优先 `goLime`, `goYellow`, `goTeal`, `goCardCyan`
- **禁止**：直接写 `Color.red`、`Color.green`、`Color.blue` 等系统色

---

## 3. 卡片系统

### 三种卡片 Modifier

```swift
// 深色半透明卡片（最常用，用于宠物详情页各卡片）
.goTranslucentCard(cornerRadius: 20)

// 蓝色渐变卡片（用于高亮/主卡）
.goBlueCard(cornerRadius: 24)

// 纯色亮色卡片（用于 goLimeLight / goMint 等亮色背景）
.goCard(color: Color.goLimeLight, cornerRadius: 20)
```

### 卡片内布局规范

```swift
VStack(alignment: .leading, spacing: 0) {
    // 标题行
    HStack { ... }
        .padding(.horizontal, 14~16)
        .padding(.top, 12~16)
        .padding(.bottom, 10~12)

    // 分隔线
    GoDashedDivider().padding(.horizontal, 14~16)

    // 内容区
    ...
    .padding(.horizontal, 12~16)
    .padding(.vertical, 10)
}
.goTranslucentCard(cornerRadius: 20)
```

---

## 4. 按钮规范

### 主要按钮（CTA）
```swift
Button { } label: {
    Text("确认")
        .font(OhanaFont.headline())
        .foregroundStyle(Color.arkInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.goLime, in: Capsule())
}
.buttonStyle(.plain)
```

### 次要按钮
```swift
Button { } label: {
    Text("取消")
        .font(OhanaFont.callout(.semibold))
        .foregroundStyle(.white.opacity(0.7))
}
.buttonStyle(.plain)
```

### Quick Action 圆形按钮
```swift
ZStack {
    Circle()
        .fill(Color.goLime.opacity(0.18))
        .frame(width: 44, height: 44)
    Image(systemName: "plus")
        .font(OhanaFont.headline())
        .foregroundStyle(Color.goLime)
}
```

---

## 5. Sheet / 弹出页规范

```swift
.sheet(isPresented: $show) {
    SomeView()
        .presentationDetents([.medium, .large])  // 或 .height(340) 固定高度
        .presentationDragIndicator(.visible)
}
```

- Sheet 内部如有 `NavigationStack`，标题用 `.navigationBarTitleDisplayMode(.inline)`
- 关闭按钮放 `.confirmationAction` 位置，文字为 "完成"

---

## 6. 动画规范

```swift
// 标准弹簧动画
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { ... }

// 快速弹簧（按钮点击反馈）
withAnimation(.spring(response: 0.25)) { ... }

// 出现/消失
.transition(.move(edge: .bottom).combined(with: .opacity))
.transition(.scale.combined(with: .opacity))
```

---

## 7. Toast / Undo 规范

3秒撤回 toast 使用统一结构：

```swift
if showToast {
    HStack(spacing: 8) {
        Text("✨ \(label) 已完成")
            .font(OhanaFont.subheadline(.bold))
            .foregroundStyle(.white)
        Spacer()
        Button {
            // 撤回逻辑
            withAnimation(.spring(response: 0.3)) { showToast = false }
        } label: {
            Text("撤回")
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.goYellow)
        }
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .background(Color.black.opacity(0.8), in: Capsule())
    .padding(.horizontal, 8).padding(.bottom, 4)
    .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

---

## 8. 间距规范

| 用途 | 值 |
|------|----|
| 页面水平边距 | 16pt |
| 卡片内水平边距 | 14~16pt |
| 卡片内垂直边距 | 10~12pt |
| 卡片顶部内边距 | 12~16pt |
| Section 间距 | 16~20pt |
| 图标与文字间距 | 6~8pt |
| 列表行间距 | 0（用 Divider 分割） |

---

## 9. 新建 View Checklist

新建任何 SwiftUI View 时，逐项检查：

- [ ] 所有 `.font()` 使用 `OhanaFont.*`
- [ ] 颜色使用 `Color.go*` 或 `Color.alert*` token，不写死 RGB/hex
- [ ] 卡片使用 `.goTranslucentCard()` / `.goBlueCard()` / `.goCard()`
- [ ] 弹窗使用 `.presentationDetents` + `.presentationDragIndicator(.visible)`
- [ ] 有打卡操作时添加3秒撤回 toast
- [ ] 按钮使用 `.buttonStyle(.plain)` + 自定义样式
- [ ] 动画使用 `.spring(response: 0.3)` 标准值

---

## 10. Alert 组件用法示例

```swift
// 内联 banner
AlertBanner(style: .success, message: "体重已记录")
AlertBanner(style: .warning, title: "余粮不足", message: "预计还剩 2 天")
AlertBanner(style: .error,   message: "保存失败，请重试")
AlertBanner(style: .info,    message: "长按按钮设置提醒")

// 可关闭
AlertBanner(style: .info, message: "提示", onDismiss: { showBanner = false })
```
