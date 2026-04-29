//
//  iOS26UITestView.swift
//  Ohana
//
//  iOS 26 UI 测试页 — 用原生 .glassEffect() API 重现 UltimateGlassCard Demo 的全部内容
//  参考：iOS26_Design_Guide.md · Section 2 Liquid Glass
//

import SwiftUI
import Charts
import UIKit

// MARK: - Main View

struct iOS26UITestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sampleText = ""
    @State private var sampleToggle = true
    @State private var sampleSlider: Double = 0.6
    @State private var sampleStepper = 5
    @State private var sampleSegment = 0
    @State private var showToast = false
    @State private var chineseFontDemoPick: ChineseFontDemoOption = .alimamaFangYuan

    let weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    let weekValues: [Double] = [3, 5, 2, 7, 4, 8, 6]
    let barValues: [Double] = [4, 6, 3, 8, 5, 9, 7]

    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @Environment(\.colorScheme) private var colorScheme

    private var isLightBackdrop: Bool { colorScheme == .light }
    
    private var themeIcon: String {
        switch appThemePreference {
        case "dark": return "moon.fill"
        case "light": return "sun.max.fill"
        default: return "circle.lefthalf.filled" // system
        }
    }
    
    private var themeColor: Color {
        switch appThemePreference {
        case "dark": return Color.goBlue
        case "light": return Color.goYellow
        default: return Color.goPurple // system
        }
    }
    
    // 浅色模式下的自适应文字颜色
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

    var body: some View {
        ZStack {
            IOS26TestBackdropView(reduceMotion: reduceMotion)

            // ── 内容：关闭从背景层继承的隐式动画，避免整页横向/布局跟着动 ──
            VStack(spacing: 0) {
                headerBar

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        cardLiquidGlassInfo
                        cardGlassCardBackgrounds
                        cardTypography
                        cardPetThemeColors
                        cardColors
                        cardButtons
                        cardFormInputs
                        cardChips
                        cardAlertBanners
                        cardPetCard
                        cardStatsBento
                        cardListRows
                        cardProgressRing
                        cardCharts
                        cardTimeline
                        cardEmptyState
                        cardToast
                        cardAvatarRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
            .transaction { $0.disablesAnimations = true }

            // ── Toast ──
            if showToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text("✨ 操作已完成")
                            .font(OhanaFont.subheadline(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) { showToast = false }
                        } label: {
                            Text("撤回")
                                .font(OhanaFont.subheadline(.black))
                                .foregroundStyle(Color.goYellow)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.black.opacity(0.85), in: Capsule())
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(OhanaFont.headline(.semibold))
                    .foregroundStyle(primaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)

            Spacer()

            VStack(spacing: 2) {
                Text("iOS 26 UI 测试页")
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(primaryText)
                    .tracking(0.5)
                Text("Liquid Glass Native API")
                    .font(OhanaFont.caption2())
                    .foregroundStyle(tertiaryText)
            }

            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    // 循环切换：dark → light → system → dark
                    switch appThemePreference {
                    case "dark":
                        appThemePreference = "light"
                    case "light":
                        appThemePreference = "system"
                    default:
                        appThemePreference = "dark"
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                    Image(systemName: themeIcon)
                        .font(OhanaFont.headline(.semibold))
                        .foregroundStyle(themeColor)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            // Spacer 占位保持标题居中
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Card 1: Liquid Glass Info

    private var cardLiquidGlassInfo: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "sparkles", color: Color.goPrimary,
                           title: "Liquid Glass · iOS 26",
                           subtitle: "原生 .glassEffect() API")
                thinDivider
                Text("• .glassEffect()  ·  GlassEffectContainer\n• .buttonStyle(.glass) / .glassProminent\n• glassEffectID + Namespace → Morphing\n• 系统自动折射 · 镜面反光 · 自适应阴影")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(5)
            }
            .padding(16)
        }
    }

    // MARK: - Card 1.5: Background Comparison (口号系统)

    private var cardBackgroundComparison: some View {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("背景口号系统 · Shorthand")
                thinDivider

                // 1. 卡片标准背景 — UltimateGlassCard
                VStack(alignment: .leading, spacing: 6) {
                    Text("「卡片标准背景」")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(accentColor)
                    Text("UltimateGlassCard · Go Focus surface")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(tertiaryText)
                }
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

                // 2. 玻璃背景 — .glassEffect
                VStack(alignment: .leading, spacing: 6) {
                    Text("「玻璃背景」")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goTeal)
                    Text(".glassEffect(.regular) · 原生折射")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(tertiaryText)
                }
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
                }

                // 3. 内嵌背景
                VStack(alignment: .leading, spacing: 6) {
                    Text("「内嵌背景」")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goOrange)
                    Text(".white.opacity(0.08) · 卡片内子区域")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(tertiaryText)
                }
                HStack(spacing: 10) {
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
                }

                // 4. 纯色背景
                VStack(alignment: .leading, spacing: 6) {
                    Text("「纯色背景」")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.goRed)
                    Text("实色填充 · CTA / Alert / 危险操作")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(tertiaryText)
                }
                HStack(spacing: 10) {
                    Text("主要按钮")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.goPrimary, in: Capsule())
                    Text("危险操作")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.goRed)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.goRed.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(16)
    }

    // MARK: - Card 1.6: Merged Background System
    private var cardGlassCardBackgrounds: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("背景系统（合并）")
            thinDivider
            Text("已合并“卡片背景”与“背景口号系统”，仅保留 4 种：品牌色板同款-24（默认）、导航栏玻璃、内嵌背景、纯色背景。")
                .font(OhanaFont.caption2())
                .foregroundStyle(tertiaryText)

            brandPaletteBackgroundSample
            navBarGlassSample
            embeddedBackgroundSample
            solidBackgroundSample
        }
    }

    // MARK: - Card 2: Typography

    private var cardTypography: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Typography System")
                thinDivider
                VStack(alignment: .leading, spacing: 10) {
                    Text("Metric 36").font(OhanaFont.metric(size: 36)).foregroundStyle(Color.goPrimary)
                    Text("Large Title").font(OhanaFont.largeTitle()).foregroundStyle(primaryText)
                    Text("Title · title2 · title3").font(OhanaFont.title()).foregroundStyle(primaryText)
                    Text("Headline / Callout").font(OhanaFont.headline()).foregroundStyle(primaryText)
                    Text("Body 正文内容 — Body copy text").font(OhanaFont.body()).foregroundStyle(secondaryText)
                    Text("Caption · Footnote · Caption2").font(OhanaFont.caption()).foregroundStyle(tertiaryText)
                }

                thinDivider

                Text("中文字体候选（圆润可爱向）")
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(accentColor)
                Text("点选一行作标记；未嵌入字库时四档使用不同系统近似（圆角 / 标准 / 粗圆 / 衬线）以便区分。将字体加入 Target 并注册 UIAppFonts 后即显示真实字形。")
                    .font(OhanaFont.caption2())
                    .foregroundStyle(tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(ChineseFontDemoOption.allCases) { option in
                        chineseFontOptionRow(option: option, isSelected: chineseFontDemoPick == option)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 3: Colors

    private var cardPetThemeColors: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Pet Theme Colors · 16 种无绿主题色")
                thinDivider
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach([
                        ("Crimson", Color.petThemeCrimson),
                        ("Vermilion", Color.petThemeVermilion),
                        ("Orange", Color.petThemeOrange),
                        ("Amber", Color.petThemeAmber),
                        ("Yellow", Color.petThemeYellow),
                        ("Brown", Color.petThemeBrown),
                        ("Rust", Color.petThemeRust),
                        ("Burgundy", Color.petThemeBurgundy),
                        ("Magenta", Color.petThemeMagenta),
                        ("Pink", Color.petThemePink),
                        ("Purple", Color.petThemePurple),
                        ("Indigo", Color.petThemeIndigo),
                        ("Violet", Color.petThemeViolet),
                        ("Navy", Color.petThemeNavy),
                        ("Blue", Color.petThemeBlue),
                        ("Sky Blue", Color.petThemeSkyBlue)
                    ], id: \.0) { item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.1)
                                .frame(width: 32, height: 32)
                                .shadow(color: item.1.opacity(0.5), radius: 4, y: 2)
                            Text(item.0)
                                .font(OhanaFont.caption(.bold))
                                .foregroundStyle(primaryText)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var cardColors: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Brand Color Palette")
                thinDivider
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach([
                        ("goLime #C8FF00", Color.goPrimary),
                        ("goYellow #FFF44F", Color.goYellow),
                        ("goOrange #FF8C42", Color.goOrange),
                        ("goRed #FF4757", Color.goRed),
                        ("goTeal #00D4AA", Color.goTeal),
                        ("goMint", Color.goMint),
                        ("goBlue", Color.goBlue),
                        ("goPurple", Color.goPurple),
                    ], id: \.0) { item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.1)
                                .frame(width: 32, height: 32)
                                .shadow(color: item.1.opacity(0.5), radius: 4, y: 2)
                            Text(item.0)
                                .font(OhanaFont.caption(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 4: Buttons

    private var cardButtons: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Buttons · iOS 26 Native")
                thinDivider
                VStack(spacing: 10) {
                    // Primary — 实色（Alert/CTA 不用 Glass）
                    Button {} label: {
                        Text("主要按钮 · Primary CTA")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    // iOS 26 Glass 次要按钮
                    Button {} label: {
                        Text("次要按钮 · .glass")
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glass)

                    // iOS 26 Prominent Glass
                    Button {} label: {
                        Text("醒目按钮 · .glassProminent")
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glassProminent)

                    // Destructive
                    Button {} label: {
                        Text("危险操作 · Destructive")
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(Color.goRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goRed.opacity(0.12), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // Quick action circles — GlassEffectContainer 保证多 Glass 共渲染
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            ForEach([
                                ("plus", Color.goPrimary),
                                ("heart.fill", Color.goRed),
                                ("bell.fill", Color.goYellow),
                                ("camera.fill", Color.goTeal),
                            ], id: \.0) { item in
                                Button {} label: {
                                    Image(systemName: item.0)
                                        .font(OhanaFont.headline())
                                        .foregroundStyle(item.1)
                                        .frame(width: 48, height: 48)
                                }
                                .glassEffect(.regular.tint(item.1.opacity(0.2)), in: Circle())
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 5: Form Inputs

    private var cardFormInputs: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Form Inputs")
                thinDivider
                VStack(spacing: 12) {
                    // TextField
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundStyle(.white.opacity(0.3))
                        TextField("Enter text...", text: $sampleText)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Segmented
                    Picker("", selection: $sampleSegment) {
                        Text("总览").tag(0); Text("健康").tag(1); Text("记录").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)

                    // Toggle
                    Toggle("通知提醒", isOn: $sampleToggle)
                        .tint(Color.goPrimary)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(.white)

                    // Slider
                    VStack(alignment: .leading, spacing: 6) {
                        Text("灵敏度 \(Int(sampleSlider * 100))%")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(.white.opacity(0.6))
                        Slider(value: $sampleSlider).tint(Color.goPrimary)
                    }

                    // Stepper
                    HStack {
                        Text("每日上限").font(OhanaFont.body()).foregroundStyle(.white)
                        Spacer()
                        Stepper("\(sampleStepper) 次", value: $sampleStepper, in: 1...20)
                            .font(OhanaFont.body(.bold))
                            .fixedSize()
                            .colorScheme(.dark)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 6: Chips & Tags

    private var cardChips: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Chips & Tags")
                thinDivider
                VStack(alignment: .leading, spacing: 10) {
                    // iOS 26 Chip — glassEffect + tint
                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                chipItem("🐕 狗狗", tint: Color.goPrimary, selected: true)
                                chipItem("🐈 猫咪", tint: Color.goTeal, selected: false)
                                chipItem("🐰 兔子", tint: Color.goYellow, selected: false)
                                chipItem("🐹 仓鼠", tint: Color.goOrange, selected: false)
                            }
                        }
                    }

                    // Tag Pills
                    HStack(spacing: 8) {
                        ForEach(["疫苗已打", "绝育", "芯片已植入"], id: \.self) { tag in
                            Text(tag)
                                .font(OhanaFont.caption(.bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(.white.opacity(0.1), in: Capsule())
                        }
                    }

                    // Status Badges
                    HStack(spacing: 8) {
                        statusBadge("已完成", color: Color.goTeal)
                        statusBadge("进行中", color: Color.goYellow)
                        statusBadge("逾期", color: Color.goRed)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 7: Alert Banners

    private var cardAlertBanners: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Alert Banners")
                thinDivider
                VStack(spacing: 8) {
                    alertRow(icon: "checkmark.circle.fill", color: Color.goPrimary, title: "操作成功完成！")
                    alertRow(icon: "exclamationmark.triangle.fill", color: Color.goYellow, title: "证件即将到期。")
                    alertRow(icon: "xmark.circle.fill", color: Color.goRed, title: "保存失败请重试。")
                    alertRow(icon: "info.circle.fill", color: Color.goPrimary, title: "新版本可用。")
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 8: Pet Card

    private var cardPetCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Pet Card · 宠物档案卡")
                thinDivider
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.goPrimary.opacity(0.2)).frame(width: 64, height: 64)
                        Text("🐶").font(.system(size: 34))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buddy").font(OhanaFont.title2(.bold)).foregroundStyle(.white)
                        Text("金毛寻回犬 · 3 岁").font(OhanaFont.callout()).foregroundStyle(.white.opacity(0.6))
                        HStack(spacing: 6) {
                            statusBadge("健康", color: Color.goTeal)
                            statusBadge("已绝育", color: Color.goBlue)
                        }
                    }
                    Spacer()
                }
                thinDivider
                HStack {
                    statCell(label: "体重", value: "24.5 kg", color: Color.goTeal)
                    Divider().frame(height: 40).opacity(0.3)
                    statCell(label: "连续打卡", value: "12 天", color: Color.goPrimary)
                    Divider().frame(height: 40).opacity(0.3)
                    statCell(label: "剩余粮食", value: "3 天", color: Color.goOrange)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 9: Stats Bento

    private var cardStatsBento: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Bento Stats · 统计格")
                thinDivider
                HStack(spacing: 10) {
                    bentoCell(icon: "figure.walk", label: "今日步数", value: "8,420", color: Color.goBlue, wide: true)
                    VStack(spacing: 10) {
                        bentoCell(icon: "drop.fill", label: "饮水", value: "1.8L", color: Color.goTeal, wide: false)
                        bentoCell(icon: "flame.fill", label: "卡路里", value: "1,240", color: Color.goOrange, wide: false)
                    }
                }
                .frame(height: 130)
            }
            .padding(16)
        }
    }

    // MARK: - Card 10: List Rows

    private var cardListRows: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("List Rows · 列表行")
                thinDivider
                VStack(spacing: 0) {
                    ForEach(Array([
                        ("cart.fill", "购买粮食", "今天 10:00", "-¥128", Color.goOrange),
                        ("syringe.fill", "狂犬疫苗", "昨天 14:00", "提醒", Color.goTeal),
                        ("figure.walk", "傍晚遛狗", "昨天 18:30", "45 min", Color.goBlue),
                    ].enumerated()), id: \.offset) { i, row in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(row.4.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: row.0).font(OhanaFont.body(.semibold)).foregroundStyle(row.4)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.1).font(OhanaFont.callout(.bold)).foregroundStyle(.white)
                                Text(row.2).font(OhanaFont.caption()).foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Text(row.3).font(OhanaFont.callout(.bold)).foregroundStyle(.white)
                        }
                        .padding(.vertical, 10)
                        if i < 2 { thinDivider }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 11: Progress Ring

    private var cardProgressRing: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Progress & Rings · 进度")
                thinDivider
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.08), lineWidth: 10)
                        Circle().trim(from: 0, to: 0.72)
                            .stroke(LinearGradient(colors: [Color.goPrimary, Color.goTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("72%").font(OhanaFont.metric(size: 18)).foregroundStyle(.white)
                            Text("完成").font(OhanaFont.caption2()).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 10) {
                        progressBar("喂食", 0.9, Color.goOrange)
                        progressBar("散步", 0.6, Color.goBlue)
                        progressBar("饮水", 0.45, Color.goTeal)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 12: Charts

    private var cardCharts: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Charts · 数据图表")
                thinDivider
                Chart {
                    ForEach(Array(zip(weekDays, weekValues).enumerated()), id: \.offset) { _, pair in
                        LineMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.goPrimary)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        AreaMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color.goPrimary.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(height: 90)
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.5)) }
                }
                .chartYAxis(.hidden)

                thinDivider

                Chart {
                    ForEach(Array(zip(weekDays, barValues).enumerated()), id: \.offset) { _, pair in
                        BarMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .foregroundStyle(Color.goBlue.gradient)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 80)
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.5)) }
                }
                .chartYAxis(.hidden)
            }
            .padding(16)
        }
    }

    // MARK: - Card 13: Timeline

    private var cardTimeline: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Timeline · 时间轴")
                thinDivider
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array([
                        ("08:00", "早餐", "喂了 80g 狗粮", Color.goOrange),
                        ("11:30", "体检", "体重 24.5kg，一切正常", Color.goTeal),
                        ("18:00", "遛狗", "公园散步 45 分钟", Color.goBlue),
                    ].enumerated()), id: \.offset) { i, item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle().fill(item.3).frame(width: 10, height: 10).padding(.top, 4)
                                if i < 2 {
                                    Rectangle().fill(item.3.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.1).font(OhanaFont.callout(.bold)).foregroundStyle(.white)
                                    Spacer()
                                    Text(item.0).font(OhanaFont.caption()).foregroundStyle(.white.opacity(0.4))
                                }
                                Text(item.2).font(OhanaFont.caption()).foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 14: Empty State

    private var cardEmptyState: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Empty State · 空状态")
                thinDivider
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.goPrimary.opacity(0.15)).frame(width: 72, height: 72)
                        Image(systemName: "tray").font(.system(size: 32)).foregroundStyle(Color.goPrimary)
                    }

                    Text("暂无记录").font(OhanaFont.title3(.bold)).foregroundStyle(.white)
                    Text("点击下方按钮添加第一条健康记录")
                        .font(OhanaFont.callout()).foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Button {} label: {
                        Text("+ 添加记录")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .padding(16)
        }
    }

    // MARK: - Card 15: Toast Demo

    private var cardToast: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Toast / Undo · 操作反馈")
                thinDivider
                Button {
                    withAnimation(.spring(response: 0.3)) { showToast = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.spring(response: 0.3)) { showToast = false }
                    }
                } label: {
                    Text("触发 Toast 通知")
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
            }
            .padding(16)
        }
    }

    // MARK: - Card 16: Avatar Row

    private var cardAvatarRow: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Avatars & Badges · 头像徽标")
                thinDivider

                HStack(spacing: -8) {
                    ForEach(["🐶", "🐱", "🐰", "🐹", "🦜"], id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 32))
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    }
                    Text("+3")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.leading, 8)
                    Spacer()
                }

                thinDivider

                HStack(spacing: 24) {
                    ForEach([
                        ("🥥", "椰子", "×128", Color.goYellow),
                        ("🏆", "成就", "12/20", Color.goOrange),
                        ("⚡", "连击", "7天", Color.goPrimary),
                    ], id: \.0) { item in
                        VStack(spacing: 5) {
                            Text(item.0).font(.system(size: 32))
                            Text(item.2)
                                .font(OhanaFont.caption(.bold))
                                .foregroundStyle(item.3)
                            Text(item.1)
                                .font(OhanaFont.caption2())
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    Spacer()
                }
            }
            .padding(16)
        }
    }

    // MARK: - Reusable Glass Card Container

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

    // MARK: - Helpers

    private var thinDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 1)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.headline(.bold))
            .foregroundStyle(primaryText)
    }

    private func cardHeader(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: icon).font(OhanaFont.headline(.bold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(OhanaFont.title3(.bold)).foregroundStyle(.white)
                Text(subtitle).font(OhanaFont.caption()).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
    }

    private func chipItem(_ label: String, tint: Color, selected: Bool) -> some View {
        Text(label)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(selected ? Color.arkInk : .white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .glassEffect(selected ? .regular.tint(tint.opacity(0.8)) : .regular, in: Capsule())
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(OhanaFont.caption2(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func alertRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.arkInk)
            Text(title)
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.arkInk)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(color, in: Capsule())
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(OhanaFont.metric(size: 18)).foregroundStyle(color)
            Text(label).font(OhanaFont.caption()).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func bentoCell(icon: String, label: String, value: String, color: Color, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(OhanaFont.metric(size: wide ? 22 : 16)).foregroundStyle(.white)
                Text(label).font(OhanaFont.caption()).foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func progressBar(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(OhanaFont.caption(.bold)).foregroundStyle(.white)
                Spacer()
                Text("\(Int(value * 100))%").font(OhanaFont.caption2(.bold)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * value, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func backgroundStyleCard(
        name: String,
        params: String,
        material: Material,
        cornerRadius: CGFloat,
        strokeOpacity: Double,
        shadowOpacity: Double,
        tintOverlayOpacity: Double,
        darkenOverlayOpacity: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(primaryText)
                Text(params)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(tertiaryText)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.28))
                        .frame(width: 30, height: 30)
                        .overlay(Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.goPrimary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sample Card")
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(primaryText)
                        Text("文字 / icon / 分割线")
                            .font(OhanaFont.caption2())
                            .foregroundStyle(secondaryText)
                    }
                    Spacer()
                }

                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Text("Action")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15), in: Capsule())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(secondaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(tintOverlayOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black.opacity(darkenOverlayOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(strokeOpacity), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: 14, x: 0, y: 8)
        }
    }

    private var navBarGlassSample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("导航栏玻璃（参考：背景口号系统·玻璃背景）")
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(primaryText)
            Text("专属名：导航栏玻璃-强折射")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(tertiaryText)

            HStack(spacing: 12) {
                HStack(spacing: 16) {
                    ForEach(["house.fill", "calendar", "pawprint.fill", "leaf.fill"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(secondaryText)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                HStack(spacing: 5) {
                    Text("🥥").font(.system(size: 13))
                    Text("128")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(primaryText)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .glassEffect(.regular, in: Capsule())

                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .light ? Color.goBlue : secondaryText)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: Circle())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            Text("参数：dock=glassEffect(.regular, radius 22)；胶囊=glassEffect(.regular)；圆按钮=glassEffect(.regular)；演示区无额外底色/底条，玻璃叠在测试页动态背景上。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryText)
            Text("应用场景：首页固定导航、浮层顶部操作条、工具条。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(tertiaryText)
        }
    }

    private var brandPaletteBackgroundSample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("品牌色板同款-24（默认）")
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(primaryText)
            Text("与 Brand Color Palette 卡片相同背景：glassEffect(.regular) + 圆角24")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(tertiaryText)

            VStack(alignment: .leading, spacing: 10) {
                Text("Brand Color Palette")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(primaryText)
                HStack(spacing: 8) {
                    ForEach([Color.goPrimary, .goYellow, .goOrange, .goBlue, .goPurple], id: \.self) { c in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(c)
                            .frame(height: 28)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("参数：glassEffect(.regular, RoundedRectangle(cornerRadius: 24))。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryText)
            Text("应用场景：默认信息卡、面板卡、图表承载卡（推荐默认）。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(tertiaryText)
        }
    }

    private var embeddedBackgroundSample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内嵌背景")
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(primaryText)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
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
                        .frame(height: 76)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            Text("参数：Color.white.opacity(0.08) + RoundedRectangle(cornerRadius: 14)。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryText)
            Text("应用场景：卡片内部统计格、次级信息容器、轻分组区域。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(tertiaryText)
        }
    }

    private var solidBackgroundSample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("纯色背景")
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(primaryText)
            HStack(spacing: 10) {
                Text("主要按钮")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.goPrimary, in: Capsule())
                Text("危险操作")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color.goRed)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.goRed.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
            }
            Text("参数：CTA 使用实色填充（如 goLime）；危险操作使用 goRed.opacity(0.12) + 0.3 描边。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryText)
            Text("应用场景：关键 CTA、删除/停用等危险操作、状态强调。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(tertiaryText)
        }
    }

    // MARK: - Chinese font demo (Typography card)

    private enum ChineseFontDemoOption: Int, CaseIterable, Identifiable {
        case alimamaFangYuan
        case resourceHanRounded
        case chillQuanYuan
        case communityRoundCute

        var id: Int { rawValue }

        var letter: String {
            switch self {
            case .alimamaFangYuan: return "A"
            case .resourceHanRounded: return "B"
            case .chillQuanYuan: return "C"
            case .communityRoundCute: return "D"
            }
        }

        var title: String {
            switch self {
            case .alimamaFangYuan: return "阿里妈妈方圆体"
            case .resourceHanRounded: return "资源圆体（思源系）"
            case .chillQuanYuan: return "寒蝉全圆体"
            case .communityRoundCute: return "猫啃 / 站酷圆体类"
            }
        }

        var blurb: String {
            switch self {
            case .alimamaFangYuan: return "现代方圆、气质最接近 SF Pro Rounded"
            case .resourceHanRounded: return "字系统一、多字重、偏耐看"
            case .chillQuanYuan: return "全圆黑体、更软更萌"
            case .communityRoundCute: return "个性更强，务必核对商用授权"
            }
        }

        static let sampleLine = "Ohana 宠物日记 🐾 圆润可爱一二三四"

        /// 按序尝试 PostScript 名；以打包进 App 的字体真实 PostScript 为准（Font Book / 打印日志核对）
        var postScriptCandidates: [String] {
            switch self {
            case .alimamaFangYuan:
                return ["AlimamaFangYuanTi-Regular", "AlimamaFangYuanTi", "Alimama FangYuan Ti"]
            case .resourceHanRounded:
                return [
                    "ResourceHanRoundedSC-Regular",
                    "ResourceHanRoundedCN-Regular",
                    "SourceHanRoundedSC-Regular",
                ]
            case .chillQuanYuan:
                return [
                    "ChillHuanQuanYuan-Regular",
                    "HanChanQuanYuan-Regular",
                    "ChillRoundSC-Regular",
                ]
            case .communityRoundCute:
                return [
                    "MaokenZhuyuan-Regular",
                    "ZCOOLKuaiLe-Regular",
                    "HuangYou-Regular",
                ]
            }
        }

        var primaryPostScriptHint: String {
            postScriptCandidates.first ?? ""
        }

        func isFontEmbedded(in size: CGFloat = 17) -> Bool {
            postScriptCandidates.contains { UIFont(name: $0, size: size) != nil }
        }

        /// 未嵌入字库时用系统字体做**可区分**的近似预览（嵌入后仅用 custom）
        func displayFont(size: CGFloat) -> Font {
            if let name = postScriptCandidates.first(where: { UIFont(name: $0, size: size) != nil }) {
                return Font.custom(name, size: size)
            }
            switch self {
            case .alimamaFangYuan:
                return Font.system(size: size, weight: .medium, design: .rounded)
            case .resourceHanRounded:
                return Font.system(size: size, weight: .regular, design: .default)
            case .chillQuanYuan:
                return Font.system(size: size + 1, weight: .heavy, design: .rounded)
            case .communityRoundCute:
                return Font.system(size: size, weight: .bold, design: .serif)
            }
        }

        var previewTracking: CGFloat {
            switch self {
            case .alimamaFangYuan: return 0
            case .resourceHanRounded: return -0.3
            case .chillQuanYuan: return 0.5
            case .communityRoundCute: return 0.6
            }
        }

        var fallbackPreviewLabel: String {
            switch self {
            case .alimamaFangYuan:
                return "系统近似：圆角体 + 中等字重（对齐 SF Rounded）"
            case .resourceHanRounded:
                return "系统近似：标准体 / 苹方、偏瘦长"
            case .chillQuanYuan:
                return "系统近似：圆角 + 特粗、字号 +1"
            case .communityRoundCute:
                return "系统近似：衬线粗体（与圆体反差大，模拟展示字）"
            }
        }
    }

    @ViewBuilder
    private func chineseFontOptionRow(option: ChineseFontDemoOption, isSelected: Bool) -> some View {
        Button {
            chineseFontDemoPick = option
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.goPrimary.opacity(0.28) : Color.white.opacity(isLightBackdrop ? 0.12 : 0.08))
                        Text(option.letter)
                            .font(OhanaFont.headline(.black))
                            .foregroundStyle(isSelected ? Color.goPrimary : secondaryText)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(option.title)
                                .font(OhanaFont.callout(.bold))
                                .foregroundStyle(primaryText)
                            if option.isFontEmbedded() {
                                Text("已嵌入")
                                    .font(OhanaFont.caption2(.bold))
                                    .foregroundStyle(Color.goTeal)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.goTeal.opacity(0.18), in: Capsule())
                            }
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.goPrimary)
                            }
                        }
                        Text(option.blurb)
                            .font(OhanaFont.caption2())
                            .foregroundStyle(tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(ChineseFontDemoOption.sampleLine)
                    .font(option.displayFont(size: 17))
                    .tracking(option.previewTracking)
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(3)

                if !option.isFontEmbedded() {
                    Text("未嵌入字库：\(option.fallbackPreviewLabel)。首候选 PostScript：\(option.primaryPostScriptHint)")
                        .font(OhanaFont.caption2())
                        .foregroundStyle(tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isLightBackdrop ? 0.04 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.goPrimary.opacity(0.9) : Color.primary.opacity(isLightBackdrop ? 0.08 : 0.12),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Isolated animated backdrop（动画状态仅在此子树，避免带动整页布局）

private struct IOS26TestBackdropView: View {
    var reduceMotion: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var blob1: CGSize = .zero
    @State private var blob2: CGSize = .zero
    @State private var blob3: CGSize = .zero
    @State private var blob4: CGSize = .zero
    @State private var blob5: CGSize = .zero
    @State private var blob6: CGSize = .zero
    @State private var blob7: CGSize = .zero
    @State private var stripeShift: CGFloat = 0
    @State private var refractionSpin: Double = 0
    @State private var blobBreath: CGFloat = 1.0
    @State private var bgHue: Double = 0

    private var isLightBackdrop: Bool { colorScheme == .light }

    var body: some View {
        ZStack {
            Group {
                if isLightBackdrop {
                    LinearGradient(
                        colors: [Color(hex: "EEF2FB"), Color(hex: "D9E3F5"), Color(hex: "E8F0FA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(hex: "0A0A0C")
                }
            }
            .ignoresSafeArea()

            GeometryReader { geo in
                let size = geo.size
                Canvas { context, _ in
                    let step: CGFloat = isLightBackdrop ? 20 : 17
                    let o1 = isLightBackdrop ? 0.09 : 0.16
                    let o2 = isLightBackdrop ? 0.06 : 0.11
                    for i in stride(from: -size.width, through: size.width * 2, by: step) {
                        var p = Path()
                        let x0 = i + stripeShift
                        p.move(to: CGPoint(x: x0, y: 0))
                        p.addLine(to: CGPoint(x: x0 - size.height * 0.42, y: size.height))
                        context.stroke(p, with: .color(Color.black.opacity(o1)), lineWidth: isLightBackdrop ? 1.0 : 1.4)
                    }
                    for j in stride(from: -size.height, through: size.height * 2, by: step * 1.25) {
                        var p = Path()
                        let y0 = j + stripeShift * 0.55
                        p.move(to: CGPoint(x: 0, y: y0))
                        p.addLine(to: CGPoint(x: size.width, y: y0 - size.width * 0.1))
                        context.stroke(p, with: .color((isLightBackdrop ? Color.goBlue : Color.cyan).opacity(o2)), lineWidth: 1.0)
                    }
                    for k in stride(from: 0, through: max(size.width, size.height), by: step * 2.4) {
                        var p = Path()
                        p.move(to: CGPoint(x: k + stripeShift * 0.3, y: 0))
                        p.addLine(to: CGPoint(x: k - size.height * 0.2 + stripeShift * 0.3, y: size.height))
                        context.stroke(p, with: .color(Color.primary.opacity(isLightBackdrop ? 0.035 : 0.07)), lineWidth: 0.8)
                    }
                }
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.goPrimary, .goBlue, .goPurple, .goOrange, .goTeal, .goPrimary],
                        center: .center
                    ),
                    lineWidth: isLightBackdrop ? 36 : 52
                )
                .frame(width: isLightBackdrop ? 400 : 460, height: isLightBackdrop ? 400 : 460)
                .blur(radius: isLightBackdrop ? 32 : 44)
                .rotationEffect(.degrees(refractionSpin))
                .offset(x: isLightBackdrop ? 20 : 55, y: isLightBackdrop ? -150 : -190)
                .opacity(isLightBackdrop ? 0.4 : 0.55)

            Circle()
                .stroke(Color.white.opacity(isLightBackdrop ? 0.35 : 0.12), lineWidth: 2)
                .frame(width: 280 + blobBreath * 40, height: 280 + blobBreath * 40)
                .offset(x: -40 + blob6.width * 0.5, y: 120 + blob7.height * 0.5)
                .blur(radius: 0.5)
                .opacity(isLightBackdrop ? 0.55 : 0.35)

            ZStack {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("LIQUID GLASS")
                            .font(.system(size: 120, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary.opacity(isLightBackdrop ? 0.22 : 0.35))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 100, y: -200)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("REFRACTION")
                            .font(.system(size: 100, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goBlue.opacity(isLightBackdrop ? 0.20 : 0.30))
                            .rotationEffect(.degrees(10))
                            .offset(x: -150, y: 50)
                        Spacer()
                    }
                    VStack {
                        HStack {
                            Text("iOS 26")
                                .font(.system(size: 80, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goPurple.opacity(isLightBackdrop ? 0.18 : 0.28))
                                .rotationEffect(.degrees(-8))
                                .offset(x: 200, y: 100)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                VStack {
                    HStack {
                        Text("🌟")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.goYellow.opacity(isLightBackdrop ? 0.4 : 0.25))
                            .rotationEffect(.degrees(25))
                            .offset(x: -180, y: -120)
                        Spacer()
                        Text("💎")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.goTeal.opacity(isLightBackdrop ? 0.38 : 0.30))
                            .rotationEffect(.degrees(-20))
                            .offset(x: 150, y: -180)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("🔮")
                            .font(.system(size: 70))
                            .foregroundStyle(Color.goOrange.opacity(isLightBackdrop ? 0.36 : 0.25))
                            .rotationEffect(.degrees(15))
                            .offset(x: 120, y: 80)
                        Spacer()
                        Text("✨")
                            .font(.system(size: 45))
                            .foregroundStyle(Color.goPrimary.opacity(isLightBackdrop ? 0.45 : 0.35))
                            .rotationEffect(.degrees(-30))
                            .offset(x: -200, y: 150)
                        Spacer()
                    }
                    VStack {
                        Spacer()
                        HStack {
                            Text("🌈")
                                .font(.system(size: 55))
                                .foregroundStyle(Color.goPurple.opacity(isLightBackdrop ? 0.4 : 0.30))
                                .rotationEffect(.degrees(-10))
                                .offset(x: 180, y: 200)
                            Spacer()
                            Text("🎨")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.goRed.opacity(isLightBackdrop ? 0.32 : 0.25))
                                .rotationEffect(.degrees(20))
                                .offset(x: -160, y: 250)
                            Spacer()
                        }
                    }
                }

                VStack {
                    HStack {
                        Text("GLASS")
                            .font(.system(size: 40, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.goBlue.opacity(isLightBackdrop ? 0.14 : 0.20))
                            .rotationEffect(.degrees(-45))
                            .offset(x: 80, y: 60)
                        Spacer()
                        Text("26")
                            .font(.system(size: 35, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goOrange.opacity(isLightBackdrop ? 0.16 : 0.25))
                            .rotationEffect(.degrees(30))
                            .offset(x: -100, y: -80)
                        Spacer()
                    }
                    Spacer()
                    VStack {
                        HStack {
                            Spacer()
                            Text("iOS")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.goTeal.opacity(isLightBackdrop ? 0.15 : 0.22))
                                .rotationEffect(.degrees(-25))
                                .offset(x: -120, y: -40)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Text("NATIVE")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.goPrimary.opacity(isLightBackdrop ? 0.13 : 0.20))
                                .rotationEffect(.degrees(40))
                                .offset(x: 140, y: -120)
                            Spacer()
                        }
                    }
                }

                VStack {
                    HStack {
                        Text("⌁⌁⌁")
                            .font(.system(size: 44, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.goMint.opacity(isLightBackdrop ? 0.22 : 0.16))
                            .rotationEffect(.degrees(-12))
                            .offset(x: -60, y: 200)
                        Spacer()
                        Text("◆ ◆ ◆")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.goOrange.opacity(isLightBackdrop ? 0.2 : 0.18))
                            .offset(x: 40, y: -40)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("# GAUSS #")
                            .font(.system(size: 26, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.goPurple.opacity(isLightBackdrop ? 0.18 : 0.14))
                            .rotationEffect(.degrees(8))
                            .offset(x: -30, y: -120)
                    }
                }
            }

            Group {
                Circle()
                    .fill(Color.goPrimary.opacity(isLightBackdrop ? 0.42 : 0.85))
                    .frame(width: 320 * blobBreath).blur(radius: 80)
                    .offset(x: -80 + blob1.width, y: -160 + blob1.height)
                Circle()
                    .fill(Color.goBlue.opacity(isLightBackdrop ? 0.35 : 0.75))
                    .frame(width: 380 * blobBreath).blur(radius: 100)
                    .offset(x: 110 + blob2.width, y: 60 + blob2.height)
                Circle()
                    .fill(Color.goPurple.opacity(isLightBackdrop ? 0.4 : 0.85))
                    .frame(width: 280 * blobBreath).blur(radius: 70)
                    .offset(x: -40 + blob3.width, y: 280 + blob3.height)
                Circle()
                    .fill(Color.goOrange.opacity(isLightBackdrop ? 0.32 : 0.65))
                    .frame(width: 240).blur(radius: 60)
                    .offset(x: 160 + blob1.width, y: -120 + blob2.height)
                Circle()
                    .fill(Color.goTeal.opacity(isLightBackdrop ? 0.34 : 0.70))
                    .frame(width: 260).blur(radius: 75)
                    .offset(x: -140 + blob3.width, y: 180 + blob1.height)
                Circle()
                    .fill(Color.goRed.opacity(isLightBackdrop ? 0.22 : 0.42))
                    .frame(width: 200).blur(radius: 60)
                    .offset(x: -170 + blob4.width, y: -40 + blob5.height)
                Circle()
                    .fill(Color.goYellow.opacity(isLightBackdrop ? 0.22 : 0.35))
                    .frame(width: 210).blur(radius: 65)
                    .offset(x: 120 + blob5.width, y: 250 + blob4.height)
                Circle()
                    .fill(Color.goMint.opacity(isLightBackdrop ? 0.26 : 0.45))
                    .frame(width: 190).blur(radius: 58)
                    .offset(x: 30 + blob4.width, y: -260 + blob2.height)
                Circle()
                    .fill(Color.goPurple.opacity(isLightBackdrop ? 0.28 : 0.55))
                    .frame(width: 220 * blobBreath).blur(radius: 68)
                    .offset(x: -20 + blob6.width, y: 40 + blob6.height)
                Circle()
                    .fill(Color.goTeal.opacity(isLightBackdrop ? 0.3 : 0.5))
                    .frame(width: 170).blur(radius: 52)
                    .offset(x: 90 + blob7.width, y: -90 + blob7.height)
            }
        }
        .hueRotation(.degrees(bgHue))
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else {
                blob1 = CGSize(width: 45, height: -38)
                blob2 = CGSize(width: -52, height: 42)
                blob3 = CGSize(width: 32, height: -48)
                blob4 = CGSize(width: -62, height: 28)
                blob5 = CGSize(width: 58, height: -38)
                blob6 = CGSize(width: 28, height: 52)
                blob7 = CGSize(width: -48, height: -22)
                stripeShift = 22
                refractionSpin = 42
                bgHue = 12
                blobBreath = 1.04
                return
            }
            withAnimation(.easeInOut(duration: 6.2).repeatForever(autoreverses: true)) {
                blob1 = CGSize(width: 88, height: -72)
            }
            withAnimation(.easeInOut(duration: 7.8).repeatForever(autoreverses: true)) {
                blob2 = CGSize(width: -92, height: 78)
            }
            withAnimation(.easeInOut(duration: 7.1).repeatForever(autoreverses: true)) {
                blob3 = CGSize(width: 70, height: -88)
            }
            withAnimation(.easeInOut(duration: 9.4).repeatForever(autoreverses: true)) {
                blob4 = CGSize(width: -95, height: 55)
            }
            withAnimation(.easeInOut(duration: 10.5).repeatForever(autoreverses: true)) {
                blob5 = CGSize(width: 85, height: -68)
            }
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                blob6 = CGSize(width: 62, height: 95)
            }
            withAnimation(.easeInOut(duration: 11.2).repeatForever(autoreverses: true)) {
                blob7 = CGSize(width: -78, height: -58)
            }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                stripeShift = 72
            }
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
                refractionSpin = 360
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                blobBreath = 1.14
            }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                bgHue = 42
            }
        }
    }
}

// MARK: - Preview

#Preview {
    iOS26UITestView()
}
