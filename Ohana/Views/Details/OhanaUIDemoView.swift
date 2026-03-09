//
//  OhanaUIDemoView.swift
//  Ohana
//
//  UI 规范测试页 — 用于统一 Light / Dark 模式下所有 UI 元素的视觉规范。
//  入口：设置 → 开发者工具 → UI 规范测试
//

import SwiftUI

struct OhanaUIDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDarkMode = true
    @State private var sampleText = ""
    @State private var sampleToggle = true
    @State private var sampleSlider: Double = 0.6
    @State private var sampleSegment = 0
    @State private var sampleStepper = 3
    @State private var sampleDate = Date()
    @State private var samplePicker = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // ─── Mode Toggle ───
                    modeToggleSection

                    // ─── Typography ───
                    sectionLabel("排版 · Typography")
                    typographySection

                    // ─── Color Palette ───
                    sectionLabel("色板 · Color Palette")
                    colorPaletteSection

                    // ─── Buttons ───
                    sectionLabel("按钮 · Buttons")
                    buttonsSection

                    // ─── Cards ───
                    sectionLabel("卡片 · Cards")
                    cardsSection

                    // ─── Inputs ───
                    sectionLabel("输入 · Inputs")
                    inputsSection

                    // ─── Alerts ───
                    sectionLabel("提示横幅 · Alert Banners")
                    alertsSection

                    // ─── Tags & Chips ───
                    sectionLabel("标签 · Tags & Chips")
                    tagsSection

                    // ─── Dividers ───
                    sectionLabel("分割线 · Dividers")
                    dividersSection

                    // ─── Progress & Metrics ───
                    sectionLabel("进度 & 大字 · Progress & Metrics")
                    progressSection

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background {
                if isDarkMode {
                    ArkBackgroundView()
                } else {
                    Color(hex: "F4F5F9").ignoresSafeArea()
                }
            }
            .navigationTitle("UI 规范")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }

    // MARK: - Mode Toggle
    private var modeToggleSection: some View {
        HStack(spacing: 14) {
            Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(isDarkMode ? Color.goYellow : Color.goOrange)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text(isDarkMode ? "深色模式 Dark" : "浅色模式 Light")
                    .font(OhanaFont.headline())
                    .foregroundStyle(isDarkMode ? .white : Color.arkInk)
                Text("切换后查看所有元素在不同模式下的表现")
                    .font(OhanaFont.caption())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isDarkMode)
                .labelsHidden()
                .tint(Color.goLime)
        }
        .padding(16)
        .background {
            if isDarkMode {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.goDarkBlue.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.13), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
        }
    }

    // MARK: - Section Label
    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isDarkMode ? .white.opacity(0.4) : Color.arkInk.opacity(0.4))
                .tracking(1.5)
            Spacer()
        }
        .padding(.leading, 4)
        .padding(.top, 4)
    }

    // MARK: - Typography
    private var typographySection: some View {
        demoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("LargeTitle 34pt Black")
                    .font(OhanaFont.largeTitle())
                    .foregroundStyle(textPrimary)
                Text("Title 24pt Bold")
                    .font(OhanaFont.title())
                    .foregroundStyle(textPrimary)
                Text("Title2 20pt Bold")
                    .font(OhanaFont.title2())
                    .foregroundStyle(textPrimary)
                Text("Title3 17pt Semibold")
                    .font(OhanaFont.title3())
                    .foregroundStyle(textPrimary)
                Text("Headline 16pt Bold")
                    .font(OhanaFont.headline())
                    .foregroundStyle(textPrimary)
                Text("Body 15pt Medium — 正文示例文字，用于段落和描述性内容。")
                    .font(OhanaFont.body())
                    .foregroundStyle(textSecondary)
                Text("Callout 14pt Medium — 辅助说明文字")
                    .font(OhanaFont.callout())
                    .foregroundStyle(textSecondary)
                Text("Footnote 12pt · Caption 11pt · Caption2 10pt")
                    .font(OhanaFont.footnote())
                    .foregroundStyle(textTertiary)
            }
        }
    }

    // MARK: - Color Palette
    private var colorPaletteSection: some View {
        demoCard {
            VStack(spacing: 10) {
                paletteRow("goPrimary", Color.goPrimary)
                paletteRow("goLime", Color.goLime)
                paletteRow("goMint", Color.goMint)
                paletteRow("goYellow", Color.goYellow)
                paletteRow("goOrange", Color.goOrange)
                paletteRow("goRed", Color.goRed)
                paletteRow("goTeal", Color.goTeal)
                paletteRow("goCardCyan", Color.goCardCyan)
                paletteRow("arkInk", Color.arkInk)
                paletteRow("goDarkBlue", Color.goDarkBlue)
                paletteRow("goDeepNavy", Color.goDeepNavy)
            }
        }
    }

    private func paletteRow(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 32, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.2), lineWidth: 1))
            Text(name)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(textPrimary)
            Spacer()
        }
    }

    // MARK: - Buttons
    private var buttonsSection: some View {
        demoCard {
            VStack(spacing: 14) {
                // Primary (goLime)
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .black))
                        Text("主按钮 Primary").font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color.goLime, Color(hex: "A8E44A")],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .shadow(color: Color.goLime.opacity(0.35), radius: 10, y: 4)
                }

                // Secondary (white outline, dark mode) / (dark outline, light mode)
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("次按钮 Secondary").font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(isDarkMode ? .white : Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isDarkMode ? .white.opacity(0.2) : Color.arkInk.opacity(0.15), lineWidth: 1.5)
                    )
                }

                // Destructive
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash").font(.system(size: 14, weight: .bold))
                        Text("危险按钮 Destructive").font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goRed, in: RoundedRectangle(cornerRadius: 16))
                }

                // Capsule pill
                HStack(spacing: 10) {
                    Button {} label: {
                        Text("胶囊 Pill").neonCapsuleButton()
                    }
                    Button {} label: {
                        Text("深色胶囊").capsuleButtonDark()
                    }
                }

                // Small icon buttons
                HStack(spacing: 10) {
                    smallIconButton("heart.fill", Color.goRed)
                    smallIconButton("star.fill", Color.goYellow)
                    smallIconButton("mappin.circle.fill", Color.goTeal)
                    smallIconButton("bell.fill", Color.goOrange)
                    Spacer()
                    // Disabled
                    Button {} label: {
                        Text("Disabled")
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.tokenButtonDisabledText)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.tokenButtonDisabledBg, in: Capsule())
                    }
                    .disabled(true)
                }
            }
        }
    }

    private func smallIconButton(_ icon: String, _ color: Color) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Cards
    private var cardsSection: some View {
        VStack(spacing: 14) {
            // Translucent card (dark only)
            VStack(alignment: .leading, spacing: 10) {
                Text("goTranslucentCard 毛玻璃卡片").font(OhanaFont.headline()).foregroundStyle(.white)
                Text("深蓝渐变 + ultraThinMaterial + 白色描边。适用于深色模式下所有主要内容区块。")
                    .font(OhanaFont.callout()).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 10) {
                    demoInputField("输入占位符", text: .constant(""), dark: true)
                }
            }
            .padding(16)
            .goTranslucentCard(cornerRadius: 20)

            // White card (light mode)
            VStack(alignment: .leading, spacing: 10) {
                Text("neoWhiteCard 白色卡片").font(OhanaFont.headline()).foregroundStyle(Color.arkInk)
                Text("纯白背景 + 投影。适用于浅色模式或高对比区块。")
                    .font(OhanaFont.callout()).foregroundStyle(Color.arkInk.opacity(0.5))
                demoInputField("浅色输入框", text: .constant(""), dark: false)
            }
            .padding(16)
            .neoWhiteCard(cornerRadius: 20)

            // Glass card
            VStack(alignment: .leading, spacing: 10) {
                Text("ohanaGlassStyle 毛玻璃").font(OhanaFont.headline()).foregroundStyle(isDarkMode ? .white : Color.arkInk)
                Text("半透明材质 + 白色渐变填充 + 白色描边。")
                    .font(OhanaFont.callout()).foregroundStyle(.secondary)
            }
            .padding(16)
            .ohanaGlassStyle(cornerRadius: 20)

            // Blue gradient card
            VStack(alignment: .leading, spacing: 10) {
                Text("goBlueCard 蓝色渐变").font(OhanaFont.headline()).foregroundStyle(.white)
                Text("品牌色渐变，用于强调性区域。")
                    .font(OhanaFont.callout()).foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .goBlueCard(cornerRadius: 20)
        }
    }

    // MARK: - Inputs
    private var inputsSection: some View {
        demoCard {
            VStack(spacing: 16) {
                // Text Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("文本输入 TextField")
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(textTertiary)
                    demoInputField("请输入内容…", text: $sampleText, dark: isDarkMode)
                }

                // Toggle
                HStack {
                    Text("开关 Toggle")
                        .font(OhanaFont.body())
                        .foregroundStyle(textPrimary)
                    Spacer()
                    Toggle("", isOn: $sampleToggle)
                        .labelsHidden()
                        .tint(Color.goLime)
                }

                // Slider
                VStack(alignment: .leading, spacing: 6) {
                    Text("滑块 Slider：\(Int(sampleSlider * 100))%")
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(textTertiary)
                    Slider(value: $sampleSlider, in: 0...1)
                        .tint(Color.goLime)
                }

                // Segmented Control
                VStack(alignment: .leading, spacing: 6) {
                    Text("分段控件 Segmented")
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(textTertiary)
                    Picker("", selection: $sampleSegment) {
                        Text("日").tag(0)
                        Text("周").tag(1)
                        Text("月").tag(2)
                        Text("年").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                // Stepper
                HStack {
                    Text("步进器 Stepper")
                        .font(OhanaFont.body())
                        .foregroundStyle(textPrimary)
                    Spacer()
                    Stepper("\(sampleStepper)", value: $sampleStepper, in: 0...10)
                        .font(OhanaFont.body(.bold))
                        .fixedSize()
                }

                // DatePicker
                VStack(alignment: .leading, spacing: 6) {
                    Text("日期选择 DatePicker")
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(textTertiary)
                    DatePicker("", selection: $sampleDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(Color.goLime)
                }

                // Picker (menu)
                HStack {
                    Text("菜单选择 Picker")
                        .font(OhanaFont.body())
                        .foregroundStyle(textPrimary)
                    Spacer()
                    Picker("", selection: $samplePicker) {
                        Text("选项 A").tag(0)
                        Text("选项 B").tag(1)
                        Text("选项 C").tag(2)
                    }
                    .pickerStyle(.menu)
                    .tint(Color.goLime)
                }
            }
        }
    }

    // MARK: - Alerts
    private var alertsSection: some View {
        demoCard {
            VStack(spacing: 12) {
                AlertBanner(style: .success, message: "操作成功！建议配合震动反馈。", title: "成功 Success")
                AlertBanner(style: .warning, message: "证件即将到期，请注意续费。", title: "警告 Warning")
                AlertBanner(style: .error,   message: "数据保存失败，请重试。",     title: "错误 Error")
                AlertBanner(style: .info,    message: "新版本可用，前往更新。",     title: "信息 Info")
            }
        }
    }

    // MARK: - Tags & Chips
    private var tagsSection: some View {
        demoCard {
            VStack(alignment: .leading, spacing: 12) {
                // Capsule chips
                Text("胶囊标签 Capsule Chips")
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(textTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipView("🐕 狗狗", Color.goLime, selected: true)
                        chipView("🐈 猫咪", Color.goTeal, selected: false)
                        chipView("🐰 兔子", Color.goYellow, selected: false)
                        chipView("⚖️ 体重", Color.goOrange, selected: false)
                        chipView("💸 花费", Color.goRed, selected: false)
                    }
                }

                GoDashedDivider(color: isDarkMode ? .white.opacity(0.1) : .black.opacity(0.08))
                    .padding(.vertical, 4)

                // Status badges
                Text("状态徽章 Status Badges")
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(textTertiary)
                HStack(spacing: 8) {
                    badgeView("已完成", Color.goLime)
                    badgeView("进行中", Color.goYellow)
                    badgeView("已过期", Color.goRed)
                    badgeView("待处理", Color.goTeal)
                }
            }
        }
    }

    private func chipView(_ label: String, _ color: Color, selected: Bool) -> some View {
        Text(label)
            .font(OhanaFont.callout(.bold))
            .foregroundStyle(selected ? Color.arkInk : (isDarkMode ? .white : Color.arkInk))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? color : color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(selected ? 0 : 0.3), lineWidth: 1))
    }

    private func badgeView(_ label: String, _ color: Color) -> some View {
        Text(label)
            .font(OhanaFont.caption2(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Dividers
    private var dividersSection: some View {
        demoCard {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GoDashedDivider 虚线").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    GoDashedDivider(color: isDarkMode ? .white.opacity(0.2) : .black.opacity(0.12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("实线 Solid").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    Divider().overlay(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("OhanaDashedDivider 虚线 2").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    OhanaDashedDivider(color: isDarkMode ? .white.opacity(0.25) : .black.opacity(0.15))
                }
            }
        }
    }

    // MARK: - Progress & Metrics
    private var progressSection: some View {
        demoCard {
            VStack(spacing: 16) {
                // Big metric number
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("128")
                        .font(OhanaFont.metric(size: 56))
                        .foregroundStyle(Color.goLime)
                    Text("天")
                        .font(OhanaFont.title2())
                        .foregroundStyle(textSecondary)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    Text("进度条 ProgressView").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: [Color.goLime, Color(hex: "A8E44A")],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * sampleSlider)
                        }
                    }
                    .frame(height: 10)
                }

                // Circular progress
                HStack(spacing: 24) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 6)
                            Circle().trim(from: 0, to: 0.72)
                                .stroke(Color.goLime, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("72%").font(OhanaFont.callout(.black)).foregroundStyle(textPrimary)
                        }
                        .frame(width: 64, height: 64)
                        Text("环形").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    }
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 6)
                            Circle().trim(from: 0, to: 0.45)
                                .stroke(Color.goOrange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("45%").font(OhanaFont.callout(.black)).foregroundStyle(textPrimary)
                        }
                        .frame(width: 64, height: 64)
                        Text("环形").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    }
                    Spacer()
                }

                // System ProgressView
                VStack(alignment: .leading, spacing: 6) {
                    Text("系统 ProgressView").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    ProgressView().tint(Color.goLime)
                }
            }
        }
    }

    // MARK: - Helpers

    private var textPrimary: Color {
        isDarkMode ? .white : Color.arkInk
    }
    private var textSecondary: Color {
        isDarkMode ? .white.opacity(0.55) : Color.arkInk.opacity(0.55)
    }
    private var textTertiary: Color {
        isDarkMode ? .white.opacity(0.35) : Color.arkInk.opacity(0.35)
    }

    /// Adaptive demo card container
    @ViewBuilder
    private func demoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background {
            if isDarkMode {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.goDarkBlue.opacity(0.82), Color.goDeepNavy.opacity(0.92)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.13), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
        }
    }

    /// Adaptive input field
    private func demoInputField(_ placeholder: String, text: Binding<String>, dark: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(dark ? Color.goYellow : Color.goPrimary)
            TextField(placeholder, text: text)
                .font(OhanaFont.body())
                .foregroundStyle(dark ? .white : Color.arkInk)
                .tint(Color.goLime)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            dark ? Color.white.opacity(0.08) : Color.tokenFormInputBg,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(dark ? .white.opacity(0.12) : Color.tokenFormInputBorder, lineWidth: 1)
        )
    }
}

#Preview {
    OhanaUIDemoView()
}
