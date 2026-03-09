//
//  OhanaUIDemoView.swift
//  Ohana
//
//  UI 规范测试页 — Light / Dark 模式全元素展示
//  入口：设置 → 开发者工具 → UI 规范测试
//

import SwiftUI
import Charts

struct OhanaUIDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDarkMode = true
    @State private var sampleText = ""
    @State private var sampleToggle = true
    @State private var sampleSlider: Double = 0.65
    @State private var sampleSegment = 0
    @State private var sampleStepper = 3
    @State private var sampleDate = Date()
    @State private var samplePicker = 0
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationDeg: Double = 0
    @State private var waveOffset: CGFloat = 0
    @State private var barHeights: [CGFloat] = [0.4, 0.7, 0.55, 0.9, 0.3, 0.8, 0.6]

    var body: some View {
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
                sectionLabel("卡片 · Cards (统一风格)")
                cardsSection

                // ─── Inputs ───
                sectionLabel("输入 · Inputs")
                inputsSection

                // ─── Alerts ─── 4 styles side-by-side
                sectionLabel("提示横幅 · Alert Banners — 4种风格")
                alertsSection

                // ─── Tags & Chips ─── 3 styles
                sectionLabel("标签 · Tags & Chips — 3种风格")
                tagsSection

                // ─── Dividers ───
                sectionLabel("分割线 · Dividers")
                dividersSection

                // ─── Progress & Metrics ───
                sectionLabel("进度 & 大字 · Progress & Metrics")
                progressSection

                // ─── Charts ───
                sectionLabel("图表 · Charts")
                chartsSection

                // ─── Animations ───
                sectionLabel("动画 · Animations")
                animationsSection

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background {
            if isDarkMode { ArkBackgroundView() }
            else { Color(hex: "F4F5F9").ignoresSafeArea() }
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
        .onAppear { startAnimations() }
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
                    .foregroundStyle(textPrimary)
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
        .demoCard(dark: isDarkMode)
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
        .padding(.leading, 4).padding(.top, 4)
    }

    // MARK: - Typography
    private var typographySection: some View {
        demoCardView {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    Text("LargeTitle · 34pt Black").font(OhanaFont.largeTitle()).foregroundStyle(textPrimary)
                    Text("Title · 24pt Bold").font(OhanaFont.title()).foregroundStyle(textPrimary)
                    Text("Title2 · 20pt Bold").font(OhanaFont.title2()).foregroundStyle(textPrimary)
                    Text("Title3 · 17pt Semibold").font(OhanaFont.title3()).foregroundStyle(textPrimary)
                    Text("Headline · 16pt Bold").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                }
                Divider().opacity(0.15)
                Group {
                    Text("Body · 正文示例文字，用于段落和描述性内容。").font(OhanaFont.body()).foregroundStyle(textSecondary)
                    Text("Callout · 辅助说明文字，14pt").font(OhanaFont.callout()).foregroundStyle(textSecondary)
                    Text("Footnote · 12pt · Caption · 11pt · Caption2 · 10pt").font(OhanaFont.footnote()).foregroundStyle(textTertiary)
                }
            }
        }
    }

    // MARK: - Color Palette
    private var colorPaletteSection: some View {
        demoCardView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                paletteChip("goPrimary", Color.goPrimary)
                paletteChip("goLime", Color.goLime)
                paletteChip("goMint", Color.goMint)
                paletteChip("goYellow", Color.goYellow)
                paletteChip("goOrange", Color.goOrange)
                paletteChip("goRed", Color.goRed)
                paletteChip("goTeal", Color.goTeal)
                paletteChip("goCardCyan", Color.goCardCyan)
                paletteChip("goDarkBlue", Color.goDarkBlue)
                paletteChip("goDeepNavy", Color.goDeepNavy)
            }
        }
    }

    private func paletteChip(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6).fill(color)
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            Text(name)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
            Spacer()
        }
    }

    // MARK: - Buttons
    private var buttonsSection: some View {
        demoCardView {
            VStack(spacing: 16) {
                // Primary (goLime gradient)
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").fontWeight(.black)
                        Text("主按钮 Primary Button")
                    }
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [Color.goLime, Color(hex: "A8E44A")], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.goLime.opacity(0.35), radius: 10, y: 4)
                }

                // Secondary (outline)
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").fontWeight(.bold)
                        Text("次按钮 Secondary")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isDarkMode ? .white.opacity(0.2) : Color.arkInk.opacity(0.15), lineWidth: 1.5)
                    )
                }

                // Destructive
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash").fontWeight(.bold)
                        Text("危险按钮 Destructive")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goRed, in: RoundedRectangle(cornerRadius: 16))
                }

                // Disabled
                Button {} label: {
                    Text("禁用状态 Disabled")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.tokenButtonDisabledText)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.tokenButtonDisabledBg, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(true)

                Divider().opacity(0.15)

                // ─── Small Icon Buttons: 4 Styles ───
                Text("图标按钮 — 4种风格 (选一种)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)

                // Style A: Solid colored background (no border)
                HStack(spacing: 8) {
                    Text("A").font(OhanaFont.caption(.bold)).foregroundStyle(textTertiary).frame(width: 16)
                    iconBtnStyleA("heart.fill", Color.goRed)
                    iconBtnStyleA("star.fill", Color.goYellow)
                    iconBtnStyleA("mappin.circle.fill", Color.goTeal)
                    iconBtnStyleA("bell.fill", Color.goOrange)
                    Spacer()
                    Text("实色背景").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                }

                // Style B: Gradient background, no border
                HStack(spacing: 8) {
                    Text("B").font(OhanaFont.caption(.bold)).foregroundStyle(textTertiary).frame(width: 16)
                    iconBtnStyleB("heart.fill", Color.goRed)
                    iconBtnStyleB("star.fill", Color.goYellow)
                    iconBtnStyleB("mappin.circle.fill", Color.goTeal)
                    iconBtnStyleB("bell.fill", Color.goOrange)
                    Spacer()
                    Text("渐变背景").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                }

                // Style C: No background, just large colorful icon
                HStack(spacing: 8) {
                    Text("C").font(OhanaFont.caption(.bold)).foregroundStyle(textTertiary).frame(width: 16)
                    iconBtnStyleC("heart.fill", Color.goRed)
                    iconBtnStyleC("star.fill", Color.goYellow)
                    iconBtnStyleC("mappin.circle.fill", Color.goTeal)
                    iconBtnStyleC("bell.fill", Color.goOrange)
                    Spacer()
                    Text("纯图标").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                }

                // Style D: Pill with label below
                HStack(spacing: 4) {
                    Text("D").font(OhanaFont.caption(.bold)).foregroundStyle(textTertiary).frame(width: 16)
                    iconBtnStyleD("heart.fill", "喜欢", Color.goRed)
                    iconBtnStyleD("star.fill", "收藏", Color.goYellow)
                    iconBtnStyleD("mappin.circle.fill", "地点", Color.goTeal)
                    iconBtnStyleD("bell.fill", "提醒", Color.goOrange)
                    Spacer()
                    Text("图标+文字").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                }
            }
        }
    }

    // Icon Button Style A — solid bg, white icon, no border
    private func iconBtnStyleA(_ icon: String, _ color: Color) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // Icon Button Style B — subtle gradient bg, colored icon, no border
    private func iconBtnStyleB(_ icon: String, _ color: Color) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [color.opacity(0.25), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
    }

    // Icon Button Style C — no bg, large icon only
    private func iconBtnStyleC(_ icon: String, _ color: Color) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
        }
    }

    // Icon Button Style D — circle bg + label below
    private func iconBtnStyleD(_ icon: String, _ label: String, _ color: Color) -> some View {
        Button {} label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color, in: Circle())
                Text(label)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(textSecondary)
            }
        }
    }

    // MARK: - Cards (unified per mode)
    private var cardsSection: some View {
        VStack(spacing: 14) {
            // Main content card
            demoCardView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "house.fill").foregroundStyle(Color.goLime)
                        Text(isDarkMode ? "goTranslucentCard (深色统一)" : "neoWhiteCard (浅色统一)")
                            .font(OhanaFont.headline()).foregroundStyle(textPrimary)
                    }
                    Text("这是所有页面的标准卡片风格。深色模式使用深蓝渐变毛玻璃，浅色模式使用纯白带投影。")
                        .font(OhanaFont.callout()).foregroundStyle(textSecondary)
                    demoInputField("卡片内嵌输入框示例…", text: .constant(""))
                }
            }

            // Nested info card style
            demoCardView {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.goLime.opacity(isDarkMode ? 0.15 : 0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.goLime)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("信息行 Info Row").font(OhanaFont.title3()).foregroundStyle(textPrimary)
                        Text("副标题文字 Subtitle · 次要信息").font(OhanaFont.callout()).foregroundStyle(textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(textTertiary)
                }
            }
        }
    }

    // MARK: - Inputs
    private var inputsSection: some View {
        demoCardView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("文本输入 TextField").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    demoInputField("请输入内容…", text: $sampleText)
                }
                HStack {
                    Text("开关 Toggle").font(OhanaFont.body()).foregroundStyle(textPrimary)
                    Spacer()
                    Toggle("", isOn: $sampleToggle).labelsHidden().tint(Color.goLime)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("滑块 Slider：\(Int(sampleSlider * 100))%").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    Slider(value: $sampleSlider, in: 0...1).tint(Color.goLime)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("分段控件 Segmented").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    Picker("", selection: $sampleSegment) {
                        Text("日").tag(0); Text("周").tag(1); Text("月").tag(2); Text("年").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                HStack {
                    Text("步进器 Stepper").font(OhanaFont.body()).foregroundStyle(textPrimary)
                    Spacer()
                    Stepper("\(sampleStepper)", value: $sampleStepper, in: 0...10)
                        .font(OhanaFont.body(.bold)).fixedSize()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("日期选择 DatePicker").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary)
                    DatePicker("", selection: $sampleDate, displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden().tint(Color.goLime)
                }
                HStack {
                    Text("菜单 Picker").font(OhanaFont.body()).foregroundStyle(textPrimary)
                    Spacer()
                    Picker("", selection: $samplePicker) {
                        Text("选项 A").tag(0); Text("选项 B").tag(1); Text("选项 C").tag(2)
                    }
                    .pickerStyle(.menu).tint(Color.goLime)
                }
            }
        }
    }

    // MARK: - Alert Banners — 4 styles
    private var alertsSection: some View {
        VStack(spacing: 16) {
            Text("风格 A — Figma Token 语义色（现用）").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            demoCardView {
                VStack(spacing: 10) {
                    AlertBanner(style: .success, message: "操作成功完成！", title: "成功")
                    AlertBanner(style: .warning, message: "证件即将到期，请注意。", title: "警告")
                    AlertBanner(style: .error,   message: "保存失败，请重试。",   title: "错误")
                    AlertBanner(style: .info,    message: "新版本可用。",         title: "提示")
                }
            }

            Text("风格 B — 深色磨砂胶囊，goLime 强调色").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            demoCardView {
                VStack(spacing: 10) {
                    alertStyleB("checkmark.circle.fill", "操作成功完成！", Color.goLime)
                    alertStyleB("exclamationmark.triangle.fill", "证件即将到期，请注意。", Color.goYellow)
                    alertStyleB("xmark.circle.fill", "保存失败，请重试。", Color.goRed)
                    alertStyleB("info.circle.fill", "新版本可用。", Color.goTeal)
                }
            }

            Text("风格 C — 纯色左色条 + 轻量背景").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            demoCardView {
                VStack(spacing: 10) {
                    alertStyleC("checkmark.circle.fill", "操作成功完成！", Color.goLime)
                    alertStyleC("exclamationmark.triangle.fill", "证件即将到期，请注意。", Color.goYellow)
                    alertStyleC("xmark.circle.fill", "保存失败，请重试。", Color.goRed)
                    alertStyleC("info.circle.fill", "新版本可用。", Color.goTeal)
                }
            }

            Text("风格 D — 纯色背景胶囊（Toast 风格）").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            demoCardView {
                VStack(spacing: 10) {
                    alertStyleD("checkmark.circle.fill", "操作成功完成！", Color.goLime, Color.arkInk)
                    alertStyleD("exclamationmark.triangle.fill", "证件即将到期。", Color.goYellow, Color.arkInk)
                    alertStyleD("xmark.circle.fill", "保存失败，请重试。", Color.goRed, .white)
                    alertStyleD("info.circle.fill", "新版本可用。", Color.goPrimary, .white)
                }
            }
        }
    }

    // Alert Style B
    private func alertStyleB(_ icon: String, _ msg: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(msg)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(isDarkMode ? .white : Color.arkInk)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(isDarkMode ? Color.white.opacity(0.07) : Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    // Alert Style C — left accent bar
    private func alertStyleC(_ icon: String, _ msg: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3)
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            Text(msg).font(OhanaFont.callout(.semibold)).foregroundStyle(isDarkMode ? .white : Color.arkInk)
            Spacer()
        }
        .padding(.trailing, 14).padding(.vertical, 11)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // Alert Style D — solid color capsule/toast
    private func alertStyleD(_ icon: String, _ msg: String, _ bg: Color, _ fg: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(fg)
            Text(msg).font(OhanaFont.callout(.bold)).foregroundStyle(fg)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(bg, in: Capsule())
    }

    // MARK: - Tags & Chips — 3 styles
    private var tagsSection: some View {
        VStack(spacing: 16) {
            Text("风格 A — Filled (选中) + Ghost (未选)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            demoCardView {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipStyleA("🐕 狗狗", Color.goLime, selected: true)
                        chipStyleA("🐈 猫咪", Color.goTeal, selected: false)
                        chipStyleA("🐰 兔子", Color.goYellow, selected: false)
                        chipStyleA("⚖️ 体重", Color.goOrange, selected: false)
                        chipStyleA("💸 花费", Color.goRed, selected: false)
                    }
                }
            }

            Text("风格 B — 统一 goLime 色，纯色填充 vs 描边").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            demoCardView {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipStyleB("🐕 狗狗", selected: true)
                        chipStyleB("🐈 猫咪", selected: false)
                        chipStyleB("🐰 兔子", selected: false)
                        chipStyleB("⚖️ 体重", selected: false)
                        chipStyleB("💸 花费", selected: false)
                    }
                }
            }

            Text("风格 C — 带左侧图标圆点的标签行").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
            demoCardView {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipStyleC("狗狗", Color.goLime, selected: true)
                        chipStyleC("猫咪", Color.goTeal, selected: false)
                        chipStyleC("兔子", Color.goYellow, selected: false)
                        chipStyleC("体重", Color.goOrange, selected: false)
                        chipStyleC("花费", Color.goRed, selected: false)
                    }
                }
                Divider().opacity(0.15).padding(.vertical, 8)
                // Status badges row
                HStack(spacing: 8) {
                    Text("状态 Badge：").font(OhanaFont.caption(.bold)).foregroundStyle(textTertiary)
                    badgeView("已完成", Color.goLime)
                    badgeView("进行中", Color.goYellow)
                    badgeView("已过期", Color.goRed)
                    badgeView("待处理", Color.goTeal)
                }
            }
        }
    }

    private func chipStyleA(_ label: String, _ color: Color, selected: Bool) -> some View {
        Text(label)
            .font(OhanaFont.callout(.bold))
            .foregroundStyle(selected ? Color.arkInk : (isDarkMode ? .white : Color.arkInk))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? color : color.opacity(0.12), in: Capsule())
            .overlay(!selected ? Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1) : nil)
    }

    private func chipStyleB(_ label: String, selected: Bool) -> some View {
        Text(label)
            .font(OhanaFont.callout(.bold))
            .foregroundStyle(selected ? Color.arkInk : Color.goLime)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? Color.goLime : Color.clear, in: Capsule())
            .overlay(!selected ? Capsule().strokeBorder(Color.goLime.opacity(0.5), lineWidth: 1.5) : nil)
    }

    private func chipStyleC(_ label: String, _ color: Color, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(OhanaFont.callout(.bold))
                .foregroundStyle(selected ? textPrimary : textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            isDarkMode ? (selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                      : (selected ? color.opacity(0.12) : Color.black.opacity(0.04)),
            in: RoundedRectangle(cornerRadius: 10)
        )
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
        demoCardView {
            VStack(spacing: 14) {
                labeledRow("GoDashedDivider 虚线") { GoDashedDivider(color: isDarkMode ? .white.opacity(0.2) : .black.opacity(0.1)) }
                labeledRow("OhanaDashedDivider 虚线 2") { OhanaDashedDivider(color: isDarkMode ? .white.opacity(0.25) : .black.opacity(0.12)) }
                labeledRow("系统 Divider") { Divider().overlay(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08)) }
                labeledRow("goLime 强调线") {
                    RoundedRectangle(cornerRadius: 2).fill(Color.goLime).frame(height: 2)
                }
            }
        }
    }

    private func labeledRow<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(OhanaFont.caption(.bold)).foregroundStyle(textTertiary)
            content()
        }
    }

    // MARK: - Progress & Metrics
    private var progressSection: some View {
        demoCardView {
            VStack(spacing: 16) {
                // Big metric
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("128").font(OhanaFont.metric(size: 56)).foregroundStyle(Color.goLime)
                    Text("天").font(OhanaFont.title2()).foregroundStyle(textSecondary)
                    Spacer()
                    Text("🔥 12 天连胜").font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.goOrange)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.goOrange.opacity(0.12), in: Capsule())
                }

                // Bar progress
                labeledRow("条形进度 ProgressBar") {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6).fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: [Color.goLime, Color(hex: "A8E44A")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * sampleSlider)
                        }
                    }
                    .frame(height: 10)
                }

                // Multi rings
                labeledRow("环形进度 Ring") {
                    HStack(spacing: 20) {
                        ringView(0.72, Color.goLime, "喂食")
                        ringView(0.45, Color.goOrange, "运动")
                        ringView(0.88, Color.goTeal, "护理")
                        ringView(0.30, Color.goRed, "椰子")
                        Spacer()
                    }
                }

                // System ProgressView
                HStack {
                    ProgressView().tint(Color.goLime)
                    Text("加载中…").font(OhanaFont.callout()).foregroundStyle(textSecondary)
                }
            }
        }
    }

    private func ringView(_ progress: Double, _ color: Color, _ label: String) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 5)
                Circle().trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%").font(OhanaFont.caption2(.black)).foregroundStyle(textPrimary)
            }
            .frame(width: 56, height: 56)
            Text(label).font(OhanaFont.caption2()).foregroundStyle(textTertiary)
        }
    }

    // MARK: - Charts
    private var chartsSection: some View {
        VStack(spacing: 14) {
            // Bar chart
            demoCardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("柱状图 Bar Chart").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                    Text("本周遛狗距离 (km)").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    Chart {
                        ForEach(Array(zip(weekDays, weekValues).enumerated()), id: \.offset) { i, pair in
                            BarMark(x: .value("Day", pair.0), y: .value("Km", pair.1))
                                .foregroundStyle(
                                    LinearGradient(colors: [Color.goLime, Color(hex: "A8E44A")], startPoint: .bottom, endPoint: .top)
                                )
                                .cornerRadius(6)
                        }
                    }
                    .frame(height: 120)
                    .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisValueLabel().foregroundStyle(textTertiary) } }
                    .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(textTertiary) } }
                }
            }

            // Line chart
            demoCardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("折线图 Line Chart").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                    Text("近7天体重变化 (kg)").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    Chart {
                        ForEach(Array(zip(weekDays, weightValues).enumerated()), id: \.offset) { i, pair in
                            LineMark(x: .value("Day", pair.0), y: .value("Kg", pair.1))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.goTeal)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            AreaMark(x: .value("Day", pair.0), y: .value("Kg", pair.1))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(colors: [Color.goTeal.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            PointMark(x: .value("Day", pair.0), y: .value("Kg", pair.1))
                                .foregroundStyle(Color.goTeal)
                                .symbolSize(36)
                        }
                    }
                    .frame(height: 120)
                    .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisValueLabel().foregroundStyle(textTertiary) } }
                    .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(textTertiary) } }
                }
            }

            // Donut / Pie chart
            demoCardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("环形图 Donut Chart").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                    Text("本月花费分类").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    HStack(spacing: 20) {
                        Chart(spendCategories, id: \.name) { item in
                            SectorMark(angle: .value("Amount", item.amount),
                                       innerRadius: .ratio(0.55),
                                       angularInset: 2)
                            .foregroundStyle(item.color)
                            .cornerRadius(4)
                        }
                        .frame(width: 110, height: 110)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(spendCategories, id: \.name) { cat in
                                HStack(spacing: 7) {
                                    Circle().fill(cat.color).frame(width: 8, height: 8)
                                    Text(cat.name).font(OhanaFont.caption()).foregroundStyle(textSecondary)
                                    Spacer()
                                    Text("¥\(cat.amount)").font(OhanaFont.caption(.bold)).foregroundStyle(textPrimary)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Animations
    private var animationsSection: some View {
        demoCardView {
            VStack(spacing: 20) {
                // Pulse
                HStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Color.goLime.opacity(0.15)).frame(width: 60, height: 60)
                            .scaleEffect(pulseScale).animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseScale)
                        Circle().fill(Color.goLime.opacity(0.08)).frame(width: 76, height: 76)
                            .scaleEffect(pulseScale).animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.3), value: pulseScale)
                        Image(systemName: "heart.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.goLime)
                    }
                    VStack(alignment: .leading) {
                        Text("呼吸脉冲 Pulse").font(OhanaFont.callout(.bold)).foregroundStyle(textPrimary)
                        Text("用于活跃状态提示").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    }
                    Spacer()
                }

                Divider().opacity(0.12)

                // Rotation
                HStack(spacing: 20) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.goLime)
                        .rotationEffect(.degrees(rotationDeg))
                        .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: rotationDeg)
                    VStack(alignment: .leading) {
                        Text("旋转 Rotation").font(OhanaFont.callout(.bold)).foregroundStyle(textPrimary)
                        Text("用于加载或生命树状态").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    }
                    Spacer()
                }

                Divider().opacity(0.12)

                // Animated bar
                HStack(spacing: 20) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(Array(barHeights.enumerated()), id: \.offset) { i, h in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.goLime.opacity(0.5 + h * 0.5))
                                .frame(width: 8, height: h * 36)
                                .animation(.easeInOut(duration: Double.random(in: 0.6...1.2)).repeatForever(autoreverses: true).delay(Double(i) * 0.1), value: barHeights)
                        }
                    }
                    .frame(height: 40)
                    VStack(alignment: .leading) {
                        Text("活跃波形 Waveform").font(OhanaFont.callout(.bold)).foregroundStyle(textPrimary)
                        Text("用于录音、音频可视化").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    }
                    Spacer()
                }

                Divider().opacity(0.12)

                // Count transition
                HStack(spacing: 20) {
                    Text("🥥 \(sampleStepper * 10)")
                        .font(OhanaFont.metric(size: 28))
                        .foregroundStyle(Color.goYellow)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: sampleStepper)
                    VStack(alignment: .leading) {
                        Text("数字过渡 Numeric").font(OhanaFont.callout(.bold)).foregroundStyle(textPrimary)
                        Text("椰子、计数器变化动效（用步进器测试）").font(OhanaFont.caption()).foregroundStyle(textTertiary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private var textPrimary: Color { isDarkMode ? .white : Color.arkInk }
    private var textSecondary: Color { isDarkMode ? .white.opacity(0.55) : Color.arkInk.opacity(0.55) }
    private var textTertiary: Color { isDarkMode ? .white.opacity(0.35) : Color.arkInk.opacity(0.35) }

    private func demoCardView<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .demoCard(dark: isDarkMode)
    }

    private func demoInputField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDarkMode ? Color.goYellow : Color.goPrimary)
            TextField(placeholder, text: text)
                .font(OhanaFont.body())
                .foregroundStyle(textPrimary)
                .tint(Color.goLime)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            isDarkMode ? Color.white.opacity(0.08) : Color.tokenFormInputBg,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isDarkMode ? .white.opacity(0.12) : Color.tokenFormInputBorder, lineWidth: 1)
        )
    }

    // Chart data
    private let weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private let weekValues: [Double] = [1.2, 3.4, 0.8, 4.1, 2.5, 5.0, 3.7]
    private let weightValues: [Double] = [6.1, 6.0, 6.2, 6.15, 6.05, 6.3, 6.2]
    private let spendCategories: [(name: String, amount: Int, color: Color)] = [
        ("食物", 320, Color.goLime),
        ("医疗", 180, Color.goTeal),
        ("美容", 90,  Color.goOrange),
        ("其他", 50,  Color.goPrimary)
    ]

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulseScale = 1.12 }
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { rotationDeg = 360 }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            barHeights = barHeights.map { _ in CGFloat.random(in: 0.2...1.0) }
        }
    }
}

// MARK: - Demo Card View Modifier
private extension View {
    func demoCard(dark: Bool) -> some View {
        self.background {
            if dark {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.goDarkBlue.opacity(0.82), Color.goDeepNavy.opacity(0.92)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.13), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
        }
    }
}

#Preview {
    OhanaUIDemoView()
}
