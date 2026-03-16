//
//  iOS26UITestView.swift
//  Ohana
//
//  iOS 26 UI 测试页 — 用原生 .glassEffect() API 重现 UltimateGlassCard Demo 的全部内容
//  参考：iOS26_Design_Guide.md · Section 2 Liquid Glass
//

import SwiftUI
import Charts

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
    @State private var pulseScale: CGFloat = 1.0
    @State private var showToast = false

    let weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    let weekValues: [Double] = [3, 5, 2, 7, 4, 8, 6]
    let barValues: [Double] = [4, 6, 3, 8, 5, 9, 7]

    @State private var blob1: CGSize = .zero
    @State private var blob2: CGSize = .zero
    @State private var blob3: CGSize = .zero
    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @Environment(\.colorScheme) private var colorScheme
    
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
            // ── 背景 ── 设计系统标准三球 Blob
            background

            // ── 内容 ──
            VStack(spacing: 0) {
                headerBar

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        cardLiquidGlassInfo
                        cardBackgroundComparison
                        cardTypography
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
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }

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
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blob1 = CGSize(width: 40, height: -35)
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                blob2 = CGSize(width: -50, height: 40)
            }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                blob3 = CGSize(width: 30, height: -45)
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(hex: "0A0A0C").ignoresSafeArea()
            
            // 背景文字用于测试折射效果
            ZStack {
                // 大文字层
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("LIQUID GLASS")
                            .font(.system(size: 120, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goLime.opacity(0.35))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 100, y: -200)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("REFRACTION")
                            .font(.system(size: 100, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goBlue.opacity(0.30))
                            .rotationEffect(.degrees(10))
                            .offset(x: -150, y: 50)
                        Spacer()
                    }
                    VStack {
                        HStack {
                            Text("iOS 26")
                                .font(.system(size: 80, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goPurple.opacity(0.28))
                                .rotationEffect(.degrees(-8))
                                .offset(x: 200, y: 100)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Emoji 和图标层
                VStack {
                    HStack {
                        Text("🌟")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.goYellow.opacity(0.25))
                            .rotationEffect(.degrees(25))
                            .offset(x: -180, y: -120)
                        Spacer()
                        Text("💎")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.goTeal.opacity(0.30))
                            .rotationEffect(.degrees(-20))
                            .offset(x: 150, y: -180)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("🔮")
                            .font(.system(size: 70))
                            .foregroundStyle(Color.goOrange.opacity(0.25))
                            .rotationEffect(.degrees(15))
                            .offset(x: 120, y: 80)
                        Spacer()
                        Text("✨")
                            .font(.system(size: 45))
                            .foregroundStyle(Color.goLime.opacity(0.35))
                            .rotationEffect(.degrees(-30))
                            .offset(x: -200, y: 150)
                        Spacer()
                    }
                    VStack {
                        Spacer()
                        HStack {
                            Text("🌈")
                            .font(.system(size: 55))
                            .foregroundStyle(Color.goPurple.opacity(0.30))
                            .rotationEffect(.degrees(-10))
                            .offset(x: 180, y: 200)
                            Spacer()
                            Text("🎨")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.goRed.opacity(0.25))
                            .rotationEffect(.degrees(20))
                            .offset(x: -160, y: 250)
                            Spacer()
                        }
                    }
                }
                
                // 小文字和符号层
                VStack {
                    HStack {
                        Text("GLASS")
                            .font(.system(size: 40, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.goBlue.opacity(0.20))
                            .rotationEffect(.degrees(-45))
                            .offset(x: 80, y: 60)
                        Spacer()
                        Text("26")
                            .font(.system(size: 35, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goOrange.opacity(0.25))
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
                                .foregroundStyle(Color.goTeal.opacity(0.22))
                                .rotationEffect(.degrees(-25))
                                .offset(x: -120, y: -40)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Text("NATIVE")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.goLime.opacity(0.20))
                                .rotationEffect(.degrees(40))
                                .offset(x: 140, y: -120)
                            Spacer()
                        }
                    }
                }
            }
            
            Circle()
                .fill(Color.goLime.opacity(0.85))
                .frame(width: 320).blur(radius: 80)
                .offset(x: -80 + blob1.width, y: -160 + blob1.height)
            Circle()
                .fill(Color.goBlue.opacity(0.75))
                .frame(width: 380).blur(radius: 100)
                .offset(x: 110 + blob2.width, y: 60 + blob2.height)
            Circle()
                .fill(Color.goPurple.opacity(0.85))
                .frame(width: 280).blur(radius: 70)
                .offset(x: -40 + blob3.width, y: 280 + blob3.height)
            Circle()
                .fill(Color.goOrange.opacity(0.65))
                .frame(width: 240).blur(radius: 60)
                .offset(x: 160 + blob1.width, y: -120 + blob2.height)
            Circle()
                .fill(Color.goTeal.opacity(0.70))
                .frame(width: 260).blur(radius: 75)
                .offset(x: -140 + blob3.width, y: 180 + blob1.height)
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(OhanaFont.headline(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)

            Spacer()

            VStack(spacing: 2) {
                Text("iOS 26 UI 测试页")
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(.white)
                    .tracking(0.5)
                Text("Liquid Glass Native API")
                    .font(OhanaFont.caption2())
                    .foregroundStyle(.white.opacity(0.5))
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
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Card 1: Liquid Glass Info

    private var cardLiquidGlassInfo: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "sparkles", color: Color.goLime,
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
                    Text("UltimateGlassCard · 8 层折射")
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
                        .background(Color.goLime, in: Capsule())
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

    // MARK: - Card 2: Typography

    private var cardTypography: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Typography System")
                thinDivider
                VStack(alignment: .leading, spacing: 10) {
                    Text("Metric 36").font(OhanaFont.metric(size: 36)).foregroundStyle(Color.goLime)
                    Text("Large Title").font(OhanaFont.largeTitle()).foregroundStyle(.white)
                    Text("Title · title2 · title3").font(OhanaFont.title()).foregroundStyle(.white)
                    Text("Headline / Callout").font(OhanaFont.headline()).foregroundStyle(.white)
                    Text("Body 正文内容 — Body copy text").font(OhanaFont.body()).foregroundStyle(.white.opacity(0.8))
                    Text("Caption · Footnote · Caption2").font(OhanaFont.caption()).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Card 3: Colors

    private var cardColors: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Brand Color Palette")
                thinDivider
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach([
                        ("goLime #C8FF00", Color.goLime),
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
                            .background(Color.goLime, in: Capsule())
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
                                ("plus", Color.goLime),
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
                        .tint(Color.goLime)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(.white)

                    // Slider
                    VStack(alignment: .leading, spacing: 6) {
                        Text("灵敏度 \(Int(sampleSlider * 100))%")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(.white.opacity(0.6))
                        Slider(value: $sampleSlider).tint(Color.goLime)
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
                                chipItem("🐕 狗狗", tint: Color.goLime, selected: true)
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
                    alertRow(icon: "checkmark.circle.fill", color: Color.goLime, title: "操作成功完成！")
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
                        Circle().fill(Color.goLime.opacity(0.2)).frame(width: 64, height: 64)
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
                    statCell(label: "连续打卡", value: "12 天", color: Color.goLime)
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
                            .stroke(LinearGradient(colors: [Color.goLime, Color.goTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
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
                            .foregroundStyle(Color.goLime)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        AreaMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color.goLime.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
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
                        Circle().fill(Color.goLime.opacity(0.15)).frame(width: 72, height: 72)
                        Image(systemName: "tray").font(.system(size: 32)).foregroundStyle(Color.goLime)
                    }
                    .scaleEffect(pulseScale)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseScale)

                    Text("暂无记录").font(OhanaFont.title3(.bold)).foregroundStyle(.white)
                    Text("点击下方按钮添加第一条健康记录")
                        .font(OhanaFont.callout()).foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Button {} label: {
                        Text("+ 添加记录")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Color.goLime, in: Capsule())
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
                        .foregroundStyle(Color.goLime)
                        .padding(.leading, 8)
                    Spacer()
                }

                thinDivider

                HStack(spacing: 24) {
                    ForEach([
                        ("🥥", "椰子", "×128", Color.goYellow),
                        ("🏆", "成就", "12/20", Color.goOrange),
                        ("⚡", "连击", "7天", Color.goLime),
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
}

// MARK: - Preview

#Preview {
    iOS26UITestView()
}
