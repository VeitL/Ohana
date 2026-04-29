//
//  GoFocusUIView.swift
//  Ohana
//
//  Go Focus UI 规范页 — App 设计系统单页参考
//
//  设计原则：
//  · 中文字体：寒蝉全圆体（带系统圆体回退）
//  · 背景：本页内置浅色 / 深色预览背景
//  · 文字：自适应深色 / 浅色模式（primaryText / secondaryText / tertiaryText）
//  · 控件：每个变体都有「适用场景」备注，AI / 设计师据此选用正确变体
//
//  架构注意：
//  · 所有 card 使用 LazyVStack 按需构建，避免 push 转场期间一次性渲染主线程阻塞
//  · 不使用 GlassEffectContainer / .buttonStyle(.glass) 等重型 iOS 26 API（这些是 iOS26UITestView 的演示职责），
//    保证本规范页可以稳定打开。
//

import SwiftUI
import Charts
import UIKit

struct GoFocusUIView: View {
    private static let resolvedCNFontName: String? = {
        ["ChillHuanQuanYuan-Regular", "HanChanQuanYuan-Regular", "ChillRoundSC-Regular"]
            .first { UIFont(name: $0, size: 12) != nil }
    }()

    @State private var previewColorScheme: ColorScheme = .dark

    // 控件状态
    @State private var toggleNotification = true
    @State private var togglePrivacy = false
    @State private var toggleAirplane = false
    @State private var toggleFavorite = true
    @State private var sliderValue: Double = 0.6
    @State private var stepperValue: Int = 5
    @State private var segment: Int = 0
    @State private var sampleText: String = ""
    @State private var showToast: Bool = false

    // ==== Sample 数据（Charts / Timeline 用）====
    private let weekDays   = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private let weekValues: [Double] = [3, 5, 2, 7, 4, 8, 6]
    private let barValues:  [Double] = [4, 6, 3, 8, 5, 9, 7]

    // ==== 自适应文字色 ====
    private var effectiveColorScheme: ColorScheme { previewColorScheme }
    private var isDarkPreview: Bool { effectiveColorScheme == .dark }
    private var primaryText:   Color { isDarkPreview ? .white : .black }
    private var secondaryText: Color { isDarkPreview ? .white.opacity(0.72) : .black.opacity(0.62) }
    private var tertiaryText:  Color { isDarkPreview ? .white.opacity(0.46) : .black.opacity(0.42) }
    private var cardSurface:   Color { isDarkPreview ? .white.opacity(0.06) : .black.opacity(0.055) }
    private var sectionCardFill: Color { isDarkPreview ? .white.opacity(0.07) : .white.opacity(0.88) }
    private var sectionCardStroke: Color { isDarkPreview ? .white.opacity(0.08) : .black.opacity(0.08) }

    // ==== 寒蝉全圆体（带系统 .rounded 回退）====
    private func cnFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = Self.resolvedCNFontName {
            return Font.custom(name, size: size).weight(weight)
        }
        return Font.system(size: size, weight: weight, design: .rounded)
    }

    var body: some View {
        ZStack {
            goFocusBackdrop

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 18) {
                    cardThemeSwitch          // 本页浅色 / 深色模式开关
                    cardTypography           // 字体（含完整字号阶梯）
                    cardBackgroundSystem     // 三种背景使用场景
                    cardColors               // 品牌色板
                    cardPetThemeColors       // 16 种宠物主题色
                    cardButtons              // 主按钮系列（含快捷圆形按钮）
                    cardCloseButtons         // 关闭按钮（带场景备注）
                    cardBackButtons          // 返回按钮（带场景备注）
                    cardControlToggles       // 开关
                    cardFormInputs           // 表单（含带图标 TextField）
                    cardChips                // Chips & Tags
                    cardAlertBanners         // 横幅
                    cardPetCard              // 宠物档案卡
                    cardStatsBento           // Bento 统计
                    cardListRows             // 列表行
                    cardProgressRing         // 进度环
                    cardCharts               // 图表
                    cardTimeline             // 时间轴
                    cardEmptyState           // 空状态
                    cardToast                // Toast
                    cardAvatarRow            // 头像
                    cardUsagePatterns        // App 真实使用场景
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }

            if showToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text("✨ 操作已完成")
                            .font(cnFont(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) { showToast = false }
                        } label: {
                            Text("撤回")
                                .font(cnFont(size: 14, weight: .black))
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
        .preferredColorScheme(effectiveColorScheme)
        .navigationTitle("Go Focus UI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    togglePreviewColorScheme()
                } label: {
                    Image(systemName: isDarkPreview ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(isDarkPreview ? Color.goBlue : Color.goYellow)
                        .frame(width: 30, height: 30)
                        .background(primaryText.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDarkPreview ? "切换到浅色模式" : "切换到深色模式")
            }
        }
    }

    private func togglePreviewColorScheme() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            previewColorScheme = isDarkPreview ? .light : .dark
        }
    }

    private var goFocusBackdrop: some View {
        ZStack {
            if isDarkPreview {
                LinearGradient(
                    colors: [Color(hex: "07111F"), Color(hex: "10243A"), Color(hex: "07111F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(hex: "F7FAFF"), Color(hex: "EEF4FF"), Color(hex: "FFFFFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            VStack(spacing: 0) {
                Rectangle()
                    .fill((isDarkPreview ? Color.goPrimary : Color.goBlue).opacity(isDarkPreview ? 0.10 : 0.06))
                    .frame(height: 180)
                Spacer()
                Rectangle()
                    .fill((isDarkPreview ? Color.goTeal : Color.goPrimary).opacity(isDarkPreview ? 0.08 : 0.045))
                    .frame(height: 220)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 0. Theme Switch

    private var cardThemeSwitch: some View {
        sectionCard("页面模式 · 浅色 / 深色") {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((isDarkPreview ? Color.goBlue : Color.goYellow).opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: isDarkPreview ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(isDarkPreview ? Color.goBlue : Color.goYellow)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isDarkPreview ? "深色模式" : "浅色模式")
                        .font(cnFont(size: 16, weight: .black))
                        .foregroundStyle(primaryText)
                    Text("切换后本页背景、卡片、文字和控件示例同步变化")
                        .font(cnFont(size: 11, weight: .semibold))
                        .foregroundStyle(tertiaryText)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isDarkPreview },
                    set: { previewColorScheme = $0 ? .dark : .light }
                ))
                .labelsHidden()
                .tint(isDarkPreview ? Color.goBlue : Color.goYellow)
            }
        }
    }

    // MARK: - 1. 字体

    private var cardTypography: some View {
        sectionCard("字体 · 寒蝉全圆体 · 完整字号阶梯") {
            VStack(alignment: .leading, spacing: 10) {
                typeRow("Metric 36",      cnFont(size: 36, weight: .heavy),    role: "数据指标 · 体重 / 步数 / 大数字", color: Color.goPrimary)
                typeRow("Large Title 30", cnFont(size: 30, weight: .black),    role: "页面主标题 · 一屏一个", color: primaryText)
                typeRow("Title 24",       cnFont(size: 24, weight: .bold),     role: "卡片大标题 · sectionCard 标题", color: primaryText)
                typeRow("Headline 17",    cnFont(size: 17, weight: .bold),     role: "列表行主标题 · 设置项标题", color: primaryText)
                typeRow("Body 15",        cnFont(size: 15, weight: .regular),  role: "正文 · 详情段落", color: secondaryText)
                typeRow("Callout 13",     cnFont(size: 13, weight: .semibold), role: "次要文本 · 副标题", color: secondaryText)
                typeRow("Caption 11",     cnFont(size: 11, weight: .regular),  role: "辅助说明 · 时间戳 · 字段标签", color: tertiaryText)

                divider
                Text("Ohana 宠物日记 🐾 圆润可爱一二三四")
                    .font(cnFont(size: 22, weight: .heavy))
                    .foregroundStyle(primaryText)
                Text("中文示例 · 标点符号、英文混排、Emoji")
                    .font(cnFont(size: 13))
                    .foregroundStyle(secondaryText)

                divider
                annotation("规则", "中文必须走 cnFont() —— 自动尝试寒蝉全圆体（ChillHuanQuanYuan），缺字库时回退系统 .rounded（圆体）。粗细映射：标题 heavy/black，主行 bold/semibold，正文 regular。")
            }
        }
    }

    private func typeRow(_ label: String, _ font: Font, role: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(font)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(role)
                .font(cnFont(size: 10))
                .foregroundStyle(tertiaryText)
                .frame(maxWidth: 140, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - 1.5 背景系统

    private var cardBackgroundSystem: some View {
        sectionCard("背景系统 · 三类用途") {
            VStack(alignment: .leading, spacing: 14) {
                // 1. 卡片标准背景
                bgUsageBlock(
                    label: "卡片标准背景",
                    labelColor: Color.goPrimary,
                    desc: ".ultraThinMaterial · sectionCard / 大面积内容 / 设置组 / 表单",
                    demo: AnyView(
                        HStack(spacing: 12) {
                            Image(systemName: "tree.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.goPrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("生命之树卡片").font(cnFont(size: 14, weight: .bold)).foregroundStyle(primaryText)
                                Text("大面积内容卡片 · 设置组 · 表单").font(cnFont(size: 11)).foregroundStyle(secondaryText)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(sectionCardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(sectionCardStroke, lineWidth: 1)
                        )
                    )
                )

                // 2. 内嵌背景
                bgUsageBlock(
                    label: "内嵌背景",
                    labelColor: Color.goOrange,
                    desc: "primaryText.opacity(0.06) · 卡片内子区域 / Bento 格 / 控件容器",
                    demo: AnyView(
                        HStack(spacing: 10) {
                            ForEach([("scalemass.fill", "24.5", "kg", Color.goTeal),
                                     ("flame.fill", "1240", "kcal", Color.goOrange)], id: \.0) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Image(systemName: item.0).font(.system(size: 14, weight: .bold)).foregroundStyle(item.3)
                                    Spacer()
                                    Text(item.1).font(cnFont(size: 16, weight: .heavy)).foregroundStyle(primaryText)
                                    Text(item.2).font(cnFont(size: 10)).foregroundStyle(tertiaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 70)
                                .padding(10)
                                .background(cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    )
                )

                // 3. 强调描边
                bgUsageBlock(
                    label: "强调描边",
                    labelColor: Color.goTeal,
                    desc: "tint.opacity(0.10) bg + tint.opacity(0.30) border · 状态横幅 / 关键提示",
                    demo: AnyView(
                        alertRow(icon: "checkmark.circle.fill", color: .goPrimary, title: "操作成功完成！")
                    )
                )

                divider
                annotation("规则", "卡片背景用 ultraThinMaterial（系统模糊）；内嵌格用 primaryText.opacity 自适应；强调横幅用 tint+描边表达语义。避免直接用 .white 或 .black 实色，会破坏深浅模式。")
            }
        }
    }

    private func bgUsageBlock(label: String, labelColor: Color, desc: String, demo: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(labelColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(labelColor.opacity(0.14), in: Capsule())
                Text(desc)
                    .font(cnFont(size: 10))
                    .foregroundStyle(tertiaryText)
                    .lineLimit(2)
            }
            demo
        }
    }

    // MARK: - 2. 颜色

    private var cardColors: some View {
        sectionCard("颜色 · 自适应") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    swatch(.goPrimary, name: "goPrimary")
                    swatch(.goLime,    name: "goLime")
                    swatch(.goBlue,    name: "goBlue")
                    swatch(.goYellow,  name: "goYellow")
                }
                HStack(spacing: 10) {
                    swatch(.goTeal,   name: "goTeal")
                    swatch(.goPurple, name: "goPurple")
                    swatch(.goRed,    name: "goRed")
                    swatch(.goMint,   name: "goMint")
                }
                divider
                annotation("规则", "primaryText / secondaryText / tertiaryText 跟随系统模式自动反相。彩色用作 accent / 状态 / 类目区分，避免大面积涂色。")
            }
        }
    }

    // MARK: - 2.5 宠物主题色（16 种）

    private var cardPetThemeColors: some View {
        sectionCard("宠物主题色 · 16 种无绿") {
            VStack(alignment: .leading, spacing: 12) {
                annotation("用途", "为不同宠物分配身份色 · 头像底色、卡片 accent、图表系列。无绿色避免与品牌主色 goLime/goPrimary 混淆。")
                let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                LazyVGrid(columns: cols, spacing: 8) {
                    petThemeRow("Crimson",   .petThemeCrimson)
                    petThemeRow("Vermilion", .petThemeVermilion)
                    petThemeRow("Orange",    .petThemeOrange)
                    petThemeRow("Amber",     .petThemeAmber)
                    petThemeRow("Yellow",    .petThemeYellow)
                    petThemeRow("Brown",     .petThemeBrown)
                    petThemeRow("Rust",      .petThemeRust)
                    petThemeRow("Burgundy",  .petThemeBurgundy)
                    petThemeRow("Magenta",   .petThemeMagenta)
                    petThemeRow("Pink",      .petThemePink)
                    petThemeRow("Purple",    .petThemePurple)
                    petThemeRow("Indigo",    .petThemeIndigo)
                    petThemeRow("Violet",    .petThemeViolet)
                    petThemeRow("Navy",      .petThemeNavy)
                    petThemeRow("Blue",      .petThemeBlue)
                    petThemeRow("Sky Blue",  .petThemeSkyBlue)
                }
            }
        }
    }

    private func petThemeRow(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 28, height: 28)
                .shadow(color: color.opacity(0.4), radius: 3, y: 1)
            Text(name)
                .font(cnFont(size: 11, weight: .bold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
            Spacer()
        }
    }

    // MARK: - 3. 主要按钮

    private var cardButtons: some View {
        sectionCard("主要按钮 Buttons") {
            VStack(spacing: 14) {
                // 1. Primary CTA
                buttonShowcase(
                    name: "Primary CTA · 主行动按钮",
                    usage: "页面里最重要的单一行动（保存、确认、添加）。每屏最多一个。"
                ) {
                    Button {} label: {
                        Text("保存")
                            .font(cnFont(size: 16, weight: .bold))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goPrimary, in: Capsule())
                    }.buttonStyle(.plain)
                }

                // 2. Secondary
                buttonShowcase(
                    name: "Secondary · 次要操作",
                    usage: "和主 CTA 并列时使用，权重次之（取消、稍后再说、查看详情）。"
                ) {
                    Button {} label: {
                        Text("取消")
                            .font(cnFont(size: 15, weight: .semibold))
                            .foregroundStyle(primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(primaryText.opacity(0.08), in: Capsule())
                    }.buttonStyle(.plain)
                }

                // 3. Destructive
                buttonShowcase(
                    name: "Destructive · 破坏性操作",
                    usage: "删除 / 注销 / 清除数据。需配 alert 二次确认。"
                ) {
                    Button {} label: {
                        Text("删除")
                            .font(cnFont(size: 15, weight: .semibold))
                            .foregroundStyle(Color.goRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goRed.opacity(0.12), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
                    }.buttonStyle(.plain)
                }

                // 4. Ghost / Tertiary
                buttonShowcase(
                    name: "Ghost · 第三级",
                    usage: "卡片内的轻量动作（「了解更多」、「展开」），不抢主操作。"
                ) {
                    Button {} label: {
                        Text("了解更多")
                            .font(cnFont(size: 14, weight: .semibold))
                            .foregroundStyle(Color.goPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                    }.buttonStyle(.plain)
                }

                // 5. Quick action circles
                buttonShowcase(
                    name: "Quick Action Circle · 快捷圆形",
                    usage: "Toolbar / 卡片角落多动作并列。每个 tint 表达功能类目（添加 / 收藏 / 提醒 / 拍照）。"
                ) {
                    HStack(spacing: 12) {
                        ForEach([
                            ("plus",        Color.goPrimary),
                            ("heart.fill",  Color.goRed),
                            ("bell.fill",   Color.goYellow),
                            ("camera.fill", Color.goTeal),
                        ], id: \.0) { item in
                            Button {} label: {
                                Image(systemName: item.0)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(item.1)
                                    .frame(width: 40, height: 40)
                                    .background(item.1.opacity(0.14), in: Circle())
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 4. 关闭按钮（每个变体带适用场景）

    private var cardCloseButtons: some View {
        sectionCard("关闭按钮 Close · 不同变体的适用场景") {
            VStack(spacing: 14) {
                buttonShowcase(
                    name: "Plain Circle Close · 圆形纯色关闭",
                    usage: "Sheet / 弹窗右上角默认关闭按钮。视觉最轻，不抢内容焦点。背景与卡片表面同色。"
                ) {
                    HStack {
                        Button {} label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(primaryText)
                                .frame(width: 36, height: 36)
                                .background(primaryText.opacity(0.08), in: Circle())
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }

                buttonShowcase(
                    name: "Hierarchical xmark.circle.fill · 系统层级关闭",
                    usage: "原生 SwiftUI sheet / 系统列表场景。SF Symbol hierarchical 渲染，与系统 toolbar 一致。导航栏 trailing 使用。"
                ) {
                    HStack {
                        Button {} label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(secondaryText)
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }

                buttonShowcase(
                    name: "Tinted Capsule Close · 带文字关闭胶囊",
                    usage: "用户需要明确感知「这是关闭」的场景：数据丢失警告、长表单退出、重要弹层。强调动作语义。"
                ) {
                    HStack {
                        Button {} label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                                Text("关闭").font(cnFont(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color.goRed)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.goRed.opacity(0.12), in: Capsule())
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }

                buttonShowcase(
                    name: "Heart Toggle · 收藏切换",
                    usage: "并非「关闭」，而是状态切换。用于收藏 / 喜欢 / 标星。带触感反馈。"
                ) {
                    HStack {
                        Button {
                            toggleFavorite.toggle()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: toggleFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color.goRed)
                                .frame(width: 36, height: 36)
                                .background(Color.goRed.opacity(toggleFavorite ? 0.18 : 0.08), in: Circle())
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 5. 返回按钮（每个变体带适用场景）

    private var cardBackButtons: some View {
        sectionCard("返回按钮 Back · 不同变体的适用场景") {
            VStack(spacing: 14) {
                buttonShowcase(
                    name: "Plain Chevron Circle · 圆形 chevron 返回",
                    usage: "**默认**：自定义 toolbar 隐藏系统返回按钮时使用。视觉与 Plain Close 对称，统一 36×36 圆形。"
                ) {
                    HStack {
                        Button {} label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(primaryText)
                                .frame(width: 36, height: 36)
                                .background(primaryText.opacity(0.08), in: Circle())
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }

                buttonShowcase(
                    name: "Filled Arrow Pill · 实色圆形返回",
                    usage: "彩色背景图 / 渐变 hero 区域上方使用。背景实色保证在彩色内容上仍清晰。常见于宠物详情页 hero。"
                ) {
                    HStack {
                        Button {} label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.goPrimary, in: Circle())
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }

                buttonShowcase(
                    name: "Text + Chevron Pill · 文字带 chevron 胶囊",
                    usage: "面包屑 / 多级深度页（设置三级页、详情子页）。明示「返回到 X」的语义。"
                ) {
                    HStack {
                        Button {} label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                                Text("返回").font(cnFont(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.goPrimary, in: Capsule())
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }

                buttonShowcase(
                    name: "System Native Back · 系统原生返回",
                    usage: "**默认行为，优先选择**：直接用 NavigationStack 系统返回（不要隐藏 backButton）。除非有 hero 视觉需求否则用系统的，无障碍最好。"
                ) {
                    HStack {
                        Text("（在 NavigationStack 中由系统自动渲染）")
                            .font(cnFont(size: 12))
                            .foregroundStyle(tertiaryText)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 6. 开关 Toggle

    private var cardControlToggles: some View {
        sectionCard("开关 Toggle") {
            VStack(spacing: 0) {
                toggleRow(
                    icon: "bell.badge.fill", iconColor: .goPrimary,
                    title: "通知提醒", subtitle: toggleNotification ? "已开启" : "已关闭",
                    isOn: $toggleNotification, tint: .goPrimary
                )
                Divider().padding(.leading, 48)
                toggleRow(
                    icon: togglePrivacy ? "lock.fill" : "lock.open.fill",
                    iconColor: togglePrivacy ? .goYellow : tertiaryText,
                    title: "隐私模式", subtitle: togglePrivacy ? "仅本人可见" : "家人可见",
                    isOn: $togglePrivacy, tint: .goYellow
                )
                Divider().padding(.leading, 48)
                toggleRow(
                    icon: "airplane",
                    iconColor: toggleAirplane ? .goBlue : tertiaryText,
                    title: "飞行模式", subtitle: toggleAirplane ? "已启用" : "已关闭",
                    isOn: $toggleAirplane, tint: .goBlue
                )
            }
            .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(cnFont(size: 15, weight: .semibold))
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .font(cnFont(size: 11))
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(tint)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    // MARK: - 7. 表单

    private var cardFormInputs: some View {
        sectionCard("表单 · TextField / Slider / Stepper / Picker") {
            VStack(alignment: .leading, spacing: 14) {
                // TextField - 标准
                VStack(alignment: .leading, spacing: 6) {
                    Text("标准 TextField").font(cnFont(size: 11, weight: .semibold)).foregroundStyle(tertiaryText)
                    TextField("输入宠物名字…", text: $sampleText)
                        .font(cnFont(size: 15))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // TextField - 带前置图标
                VStack(alignment: .leading, spacing: 6) {
                    Text("带前置图标 · 搜索 / 编辑场景").font(cnFont(size: 11, weight: .semibold)).foregroundStyle(tertiaryText)
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tertiaryText)
                        TextField("搜索宠物 / 记录 / 标签…", text: $sampleText)
                            .font(cnFont(size: 14))
                            .foregroundStyle(primaryText)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(cardSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Slider
                VStack(alignment: .leading, spacing: 6) {
                    Text("亮度 \(Int(sliderValue * 100))%")
                        .font(cnFont(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryText)
                    Slider(value: $sliderValue).tint(Color.goPrimary)
                }

                // Stepper
                Stepper("份量 \(stepperValue)", value: $stepperValue, in: 0...20)
                    .font(cnFont(size: 14, weight: .semibold))
                    .foregroundStyle(primaryText)

                // Segmented Picker
                Picker("视图模式", selection: $segment) {
                    Text("日").tag(0)
                    Text("周").tag(1)
                    Text("月").tag(2)
                }.pickerStyle(.segmented)
            }
        }
    }

    // MARK: - 8. Chips & Tags

    private var cardChips: some View {
        sectionCard("标签 Chips & Tags") {
            VStack(alignment: .leading, spacing: 12) {
                annotation("Chip · 选择类目", "可点击切换的类目过滤器（首页「猫/狗/兔」切换）。selected 状态填充 tint。")
                let cols = [GridItem(.adaptive(minimum: 64), spacing: 8)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                    chip("🐕 狗狗", tint: .goPrimary, selected: true)
                    chip("🐈 猫咪", tint: .goTeal, selected: false)
                    chip("🐰 兔子", tint: .goYellow, selected: false)
                    chip("🐹 仓鼠", tint: .goPurple, selected: false)
                }

                divider
                annotation("Tag Pill · 静态信息", "纯展示，不可点击。例如\"疫苗已打\" \"已绝育\"。")
                HStack(spacing: 8) {
                    ForEach(["疫苗已打", "已绝育", "芯片已植入"], id: \.self) { tag in
                        Text(tag)
                            .font(cnFont(size: 11, weight: .bold))
                            .foregroundStyle(secondaryText)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(primaryText.opacity(0.08), in: Capsule())
                    }
                }

                divider
                annotation("Status Badge · 状态徽标", "用 tint 表达状态：绿 = 完成，黄 = 进行中，红 = 异常。")
                HStack(spacing: 8) {
                    statusBadge("已完成", color: .goTeal)
                    statusBadge("进行中", color: .goYellow)
                    statusBadge("逾期",   color: .goRed)
                }
            }
        }
    }

    // MARK: - 9. Alert Banners

    private var cardAlertBanners: some View {
        sectionCard("横幅 Alert Banner") {
            VStack(spacing: 8) {
                alertRow(icon: "checkmark.circle.fill",      color: .goPrimary, title: "操作成功完成！")
                alertRow(icon: "exclamationmark.triangle.fill", color: .goYellow,  title: "证件即将到期。")
                alertRow(icon: "xmark.circle.fill",          color: .goRed,     title: "保存失败请重试。")
                alertRow(icon: "info.circle.fill",           color: .goBlue,    title: "新版本可用。")
                divider
                annotation("规则", "横幅用 icon + 文字，颜色对应语义：绿=成功，黄=警告，红=错误，蓝=信息。可点击跳转或自动消失。")
            }
        }
    }

    private func alertRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            Text(title).font(cnFont(size: 13, weight: .semibold)).foregroundStyle(primaryText)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(color.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - 10. Pet Card

    private var cardPetCard: some View {
        sectionCard("宠物档案卡 Pet Card") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.goPrimary.opacity(0.2)).frame(width: 60, height: 60)
                        Text("🐶").font(.system(size: 32))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buddy")
                            .font(cnFont(size: 20, weight: .bold))
                            .foregroundStyle(primaryText)
                        Text("金毛寻回犬 · 3 岁")
                            .font(cnFont(size: 12))
                            .foregroundStyle(secondaryText)
                        HStack(spacing: 6) {
                            statusBadge("健康", color: .goTeal)
                            statusBadge("已绝育", color: .goBlue)
                        }
                    }
                    Spacer()
                }
                divider
                HStack {
                    statCell(label: "体重", value: "24.5 kg", color: .goTeal)
                    Divider().frame(height: 36).opacity(0.3)
                    statCell(label: "连续打卡", value: "12 天", color: .goPrimary)
                    Divider().frame(height: 36).opacity(0.3)
                    statCell(label: "剩余粮食", value: "3 天", color: .goOrange)
                }
            }
        }
    }

    // MARK: - 11. Bento Stats

    private var cardStatsBento: some View {
        sectionCard("Bento Stats · 统计格") {
            HStack(spacing: 10) {
                bentoCell(icon: "figure.walk", label: "今日步数", value: "8,420", color: .goBlue, wide: true)
                VStack(spacing: 10) {
                    bentoCell(icon: "drop.fill", label: "饮水",    value: "1.8L",  color: .goTeal,   wide: false)
                    bentoCell(icon: "flame.fill", label: "卡路里", value: "1,240", color: .goOrange, wide: false)
                }
            }
            .frame(height: 130)
        }
    }

    // MARK: - 12. List Rows

    private var cardListRows: some View {
        sectionCard("列表行 List Rows") {
            VStack(spacing: 0) {
                let rows: [(String, String, String, String, Color)] = [
                    ("cart.fill",    "购买粮食", "今天 10:00",  "-¥128", .goOrange),
                    ("syringe.fill", "狂犬疫苗", "昨天 14:00",  "提醒",   .goTeal),
                    ("figure.walk",  "傍晚遛狗", "昨天 18:30",  "45 min", .goBlue),
                ]
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(row.4.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: row.0).font(.system(size: 13, weight: .semibold)).foregroundStyle(row.4)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.1).font(cnFont(size: 14, weight: .bold)).foregroundStyle(primaryText)
                            Text(row.2).font(cnFont(size: 11)).foregroundStyle(tertiaryText)
                        }
                        Spacer()
                        Text(row.3).font(cnFont(size: 13, weight: .bold)).foregroundStyle(primaryText)
                    }
                    .padding(.vertical, 9)
                    if i < rows.count - 1 { divider }
                }
            }
        }
    }

    // MARK: - 13. Progress & Rings

    private var cardProgressRing: some View {
        sectionCard("进度环 & 进度条 Progress") {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(primaryText.opacity(0.08), lineWidth: 9)
                    Circle().trim(from: 0, to: 0.72)
                        .stroke(LinearGradient(colors: [.goPrimary, .goTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("72%").font(cnFont(size: 17, weight: .heavy)).foregroundStyle(primaryText)
                        Text("完成").font(cnFont(size: 10)).foregroundStyle(tertiaryText)
                    }
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 8) {
                    progressBar("喂食", 0.9, .goOrange)
                    progressBar("散步", 0.6, .goBlue)
                    progressBar("饮水", 0.45, .goTeal)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 14. Charts

    private var cardCharts: some View {
        sectionCard("图表 Charts · 数据可视化") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Line + Area · 趋势")
                    .font(cnFont(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryText)
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
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(tertiaryText) }
                }
                .chartYAxis(.hidden)

                divider

                Text("Bar · 对比")
                    .font(cnFont(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryText)
                Chart {
                    ForEach(Array(zip(weekDays, barValues).enumerated()), id: \.offset) { _, pair in
                        BarMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .foregroundStyle(Color.goBlue.gradient)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 80)
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(tertiaryText) }
                }
                .chartYAxis(.hidden)
            }
        }
    }

    // MARK: - 15. Timeline

    private var cardTimeline: some View {
        sectionCard("时间轴 Timeline") {
            VStack(alignment: .leading, spacing: 0) {
                let items: [(String, String, String, Color)] = [
                    ("08:00", "早餐", "喂了 80g 狗粮",      .goOrange),
                    ("11:30", "体检", "体重 24.5kg，一切正常", .goTeal),
                    ("18:00", "遛狗", "公园散步 45 分钟",    .goBlue),
                ]
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(item.3).frame(width: 9, height: 9).padding(.top, 4)
                            if i < items.count - 1 {
                                Rectangle().fill(item.3.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.1).font(cnFont(size: 14, weight: .bold)).foregroundStyle(primaryText)
                                Spacer()
                                Text(item.0).font(cnFont(size: 11)).foregroundStyle(tertiaryText)
                            }
                            Text(item.2).font(cnFont(size: 12)).foregroundStyle(secondaryText)
                        }
                    }
                    .frame(minHeight: 40)
                }
            }
        }
    }

    // MARK: - 16. Empty State

    private var cardEmptyState: some View {
        sectionCard("空状态 Empty State") {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.goPrimary.opacity(0.15)).frame(width: 64, height: 64)
                    Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(Color.goPrimary)
                }
                Text("暂无记录").font(cnFont(size: 17, weight: .bold)).foregroundStyle(primaryText)
                Text("点击下方按钮添加第一条健康记录")
                    .font(cnFont(size: 12)).foregroundStyle(tertiaryText)
                    .multilineTextAlignment(.center)
                Button {} label: {
                    Text("+ 添加记录")
                        .font(cnFont(size: 14, weight: .bold))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Color.goPrimary, in: Capsule())
                }.buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 17. Toast

    private var cardToast: some View {
        sectionCard("Toast · 操作反馈") {
            VStack(alignment: .leading, spacing: 12) {
                annotation("用法", "短暂出现于屏幕底部 2-3 秒。可包含撤回按钮。点击触发下方测试。")
                Button {
                    withAnimation(.spring(response: 0.3)) { showToast = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.spring(response: 0.3)) { showToast = false }
                    }
                } label: {
                    Text("触发 Toast 通知")
                        .font(cnFont(size: 14, weight: .bold))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.goPrimary, in: Capsule())
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - 18. Avatar Row

    private var cardAvatarRow: some View {
        sectionCard("头像 & 徽标 Avatars & Badges") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(["🐶", "🐱", "🐰", "🐹", "🦜"], id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 30))
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    }
                    Text("+3")
                        .font(cnFont(size: 14, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.leading, 8)
                    Spacer()
                }
                divider
                HStack(spacing: 24) {
                    badgeCell("🥥", "椰子", "×128", .goYellow)
                    badgeCell("🏆", "成就", "12/20", .goOrange)
                    badgeCell("⚡", "连击", "7天", .goPrimary)
                }
            }
        }
    }

    // MARK: - 19. Usage Patterns

    private var cardUsagePatterns: some View {
        sectionCard("App 使用场景 · 组合规范") {
            VStack(alignment: .leading, spacing: 10) {
                patternRow(
                    icon: "house.fill",
                    title: "首页 / GO Focus",
                    rule: "信息密度优先：顶部状态、卡片堆、快捷操作、聚合入口。避免营销式大 hero 和装饰卡套卡。",
                    tint: .goPrimary
                )
                patternRow(
                    icon: "person.crop.circle.fill",
                    title: "成员 / 宠物详情页",
                    rule: "先身份卡，再关键指标，再按健康、活动、财务、备注分组。隐私数据必须用锁定占位替代真实内容。",
                    tint: .goBlue
                )
                patternRow(
                    icon: "square.and.pencil",
                    title: "记录详情 / 长按快捷操作",
                    rule: "顶部只放隐私 icon 和关闭 icon；底部主 CTA 固定为实色 goPrimary 胶囊；列表卡片统一 sectionCard 表面。",
                    tint: .goTeal
                )
                patternRow(
                    icon: "slider.horizontal.3",
                    title: "设置 / 表单",
                    rule: "使用稳定行高、左 icon、主副标题、右控件。Toggle 只表达布尔状态，危险操作必须二次确认。",
                    tint: .goYellow
                )
                patternRow(
                    icon: "chart.bar.xaxis",
                    title: "统计 Dashboard",
                    rule: "先 overview 大卡，再 2-4 个 bento 指标，再图表和明细。图表色来自语义色或宠物主题色。",
                    tint: .goOrange
                )
                patternRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "空状态 / 错误 / 提醒",
                    rule: "空状态只给一个明确下一步；错误用红色 banner；警告用黄色；成功用品牌绿。不要用大段说明文字。",
                    tint: .goRed
                )
            }
        }
    }

    // MARK: - Atomic helpers

    private var divider: some View {
        Rectangle().fill(primaryText.opacity(0.08)).frame(height: 1)
    }

    private func sectionCard<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(cnFont(size: 16, weight: .bold))
                .foregroundStyle(primaryText)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(sectionCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(sectionCardStroke, lineWidth: 1)
        )
        .shadow(color: isDarkPreview ? .black.opacity(0.18) : .black.opacity(0.08), radius: 14, y: 8)
    }

    private func annotation(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.goPrimary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.goPrimary.opacity(0.14), in: Capsule())
            Text(text)
                .font(cnFont(size: 11))
                .foregroundStyle(secondaryText)
                .lineSpacing(2)
        }
    }

    /// 按钮变体展示：上方 name + usage 注释，下方实际控件
    private func buttonShowcase<C: View>(name: String, usage: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(cnFont(size: 12, weight: .bold))
                .foregroundStyle(primaryText)
            Text(usage)
                .font(cnFont(size: 11))
                .foregroundStyle(tertiaryText)
                .lineSpacing(2)
            content()
                .padding(.top, 4)
        }
        .padding(12)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func swatch(_ color: Color, name: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(primaryText.opacity(0.18), lineWidth: 0.5)
                )
            Text(name)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ label: String, tint: Color, selected: Bool) -> some View {
        Text(label)
            .font(cnFont(size: 12, weight: .bold))
            .foregroundStyle(selected ? Color.arkInk : primaryText)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(
                Capsule().fill(selected ? tint : primaryText.opacity(0.08))
            )
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(cnFont(size: 10, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 0.5))
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(cnFont(size: 14, weight: .heavy)).foregroundStyle(color)
            Text(label).font(cnFont(size: 10)).foregroundStyle(tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func bentoCell(icon: String, label: String, value: String, color: Color, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Spacer()
            Text(value)
                .font(cnFont(size: wide ? 22 : 16, weight: .heavy))
                .foregroundStyle(primaryText)
            Text(label).font(cnFont(size: 10)).foregroundStyle(tertiaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func progressBar(_ label: String, _ progress: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(cnFont(size: 11, weight: .bold)).foregroundStyle(primaryText)
                Spacer()
                Text("\(Int(progress * 100))%").font(cnFont(size: 10)).foregroundStyle(tertiaryText)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(primaryText.opacity(0.08)).frame(height: 6)
                Capsule().fill(color).frame(width: max(0, CGFloat(progress) * 200), height: 6)
            }
        }
    }

    private func badgeCell(_ emoji: String, _ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 22))
            Text(value).font(cnFont(size: 13, weight: .heavy)).foregroundStyle(color)
            Text(label).font(cnFont(size: 10)).foregroundStyle(tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func patternRow(icon: String, title: String, rule: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(cnFont(size: 13, weight: .black))
                    .foregroundStyle(primaryText)
                Text(rule)
                    .font(cnFont(size: 11, weight: .medium))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        GoFocusUIView()
    }
}
