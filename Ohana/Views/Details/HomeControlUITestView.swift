//
//  HomeControlUITestView.swift
//  Ohana
//
//  Pet-themed UI/UX specification and showcase page.
//

import SwiftUI
import Charts

struct HomeControlUITestView: View {
    var embeddedInMergedPage: Bool = false
    private enum DemoScheme: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    private struct AccentTheme: Identifiable {
        let id: String
        let name: String
        let primary: Color
        let secondary: Color
        let tertiary: Color
        let quaternary: Color
        let surface: Color
    }

    private struct DailyStat: Identifiable {
        let id: String
        let day: String
        let value: Double
    }

    private struct MotionToken: Identifiable {
        let id: String
        let title: String
        let duration: String
        let curve: String
        let usage: String
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var demoScheme: DemoScheme = .light
    @State private var selectedAccentId = "orange"
    @State private var selectedPet = "Mochi"
    @State private var selectedSegment = "Today"
    @State private var selectedCategory = "Health"
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var notificationsOn = true
    @State private var autoLogOn = true
    @State private var reducedMotionPreview = false
    @State private var treatBurst = false
    @State private var feedProgress: Double = 0.74
    @State private var hydrationProgress: Double = 0.58
    @State private var energyProgress: Double = 0.84
    @State private var selectedMood = 4
    @State private var animateMotion = false

    private let accentThemes: [AccentTheme] = [
        .init(
            id: "orange",
            name: "Orange",
            primary: Color(hex: "FF7600"),
            secondary: Color(hex: "FFAB0F"),
            tertiary: Color(hex: "FFBC00"),
            quaternary: Color(hex: "FFE45A"),
            surface: Color(hex: "FFFEFC")
        ),
        .init(
            id: "frosty",
            name: "Frosty Morning",
            primary: Color(hex: "3C98BF"),
            secondary: Color(hex: "9AC6D3"),
            tertiary: Color(hex: "E6F0F1"),
            quaternary: Color(hex: "CCD6DF"),
            surface: Color(hex: "A7C1CF")
        ),
        .init(
            id: "coolness",
            name: "Coolness",
            primary: Color(hex: "002CCD"),
            secondary: Color(hex: "006CEC"),
            tertiary: Color(hex: "61C2FF"),
            quaternary: Color(hex: "B5E3FF"),
            surface: .white
        ),
        .init(
            id: "dreamy",
            name: "Dreamy Sea",
            primary: Color(hex: "472280"),
            secondary: Color(hex: "661E8A"),
            tertiary: Color(hex: "852D94"),
            quaternary: Color(hex: "AC62A9"),
            surface: Color(hex: "F0DFEC")
        )
    ]

    private let activityData: [DailyStat] = [
        .init(id: "Mon", day: "Mon", value: 38),
        .init(id: "Tue", day: "Tue", value: 52),
        .init(id: "Wed", day: "Wed", value: 64),
        .init(id: "Thu", day: "Thu", value: 48),
        .init(id: "Fri", day: "Fri", value: 70),
        .init(id: "Sat", day: "Sat", value: 82),
        .init(id: "Sun", day: "Sun", value: 58)
    ]

    private let moodData: [DailyStat] = [
        .init(id: "1", day: "Mon", value: 3.4),
        .init(id: "2", day: "Tue", value: 4.1),
        .init(id: "3", day: "Wed", value: 3.8),
        .init(id: "4", day: "Thu", value: 4.6),
        .init(id: "5", day: "Fri", value: 4.8),
        .init(id: "6", day: "Sat", value: 4.2),
        .init(id: "7", day: "Sun", value: 4.5)
    ]

    private let motionTokens: [MotionToken] = [
        .init(id: "entry", title: "Entry", duration: "0.24s", curve: "spring 0.82", usage: "Cards and sheets should lift in fast, then settle."),
        .init(id: "state", title: "State Change", duration: "0.18s", curve: "easeInOut", usage: "Toggles, chips and filters should confirm instantly."),
        .init(id: "reward", title: "Reward", duration: "0.42s", curve: "spring 0.72", usage: "Treat, streak and completion moments can overshoot slightly.")
    ]

    private var selectedTheme: AccentTheme {
        accentThemes.first(where: { $0.id == selectedAccentId }) ?? accentThemes[0]
    }

    private var resolvedColorScheme: ColorScheme {
        switch demoScheme {
        case .system: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var isDark: Bool { resolvedColorScheme == .dark }

    private var backgroundBase: Color { isDark ? Color(hex: "121316") : Color(hex: "E7E7E7") }
    private var surface: Color { isDark ? Color(hex: "1B1C1F") : .white }
    private var elevatedSurface: Color { isDark ? Color(hex: "25272C") : Color(hex: "F8F8F8") }
    private var softSurface: Color { isDark ? Color(hex: "24262B") : Color(hex: "EFEFEF") }
    private var textPrimary: Color { isDark ? .white : .black }
    private var textSecondary: Color { isDark ? .white.opacity(0.62) : .black.opacity(0.34) }
    private var textTertiary: Color { isDark ? .white.opacity(0.3) : .black.opacity(0.18) }
    private var borderColor: Color { isDark ? .white.opacity(0.08) : .black.opacity(0.05) }
    private var themeHexes: [String] {
        switch selectedTheme.id {
        case "orange":
            return ["#FF7600", "#FFAB0F", "#FFBC00", "#FFE45A", "#FFFEFC"]
        case "frosty":
            return ["#3C98BF", "#9AC6D3", "#E6F0F1", "#CCD6DF", "#A7C1CF"]
        case "coolness":
            return ["#002CCD", "#006CEC", "#61C2FF", "#B5E3FF", "#FFFFFF"]
        case "dreamy":
            return ["#472280", "#661E8A", "#852D94", "#AC62A9", "#F0DFEC"]
        default:
            return ["#FF7600", "#FFAB0F", "#FFBC00", "#FFE45A", "#FFFEFC"]
        }
    }

    private var sectionSpacing: CGFloat { 22 }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: sectionSpacing) {
                    heroSection
                    previewSection
                    colorAndTypographySection
                    buttonAndElementSection
                    chartSection
                    motionSection
                    interactionSection
                    settingsRowsSection
                    bottomBarSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .preferredColorScheme(demoScheme == .system ? nil : resolvedColorScheme)
                .navigationBarTitleDisplayMode(.inline)
        .toolbar(embeddedInMergedPage ? .hidden : .visible, for: .navigationBar)
        .modifier(HomeControlNavTitleModifier(enabled: !embeddedInMergedPage))
        .onAppear {
            if !animateMotion {
                animateMotion = true
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            backgroundBase.ignoresSafeArea()

            Circle()
                .fill(.white.opacity(isDark ? 0.06 : 0.9))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -80, y: -260)

            Circle()
                .fill(.white.opacity(isDark ? 0.04 : 0.45))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 130, y: 250)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                Text("UI DESIGN")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(isDark ? 0.06 : 0.05))
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("宠物产品 UI/UX 规范")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Text("覆盖主题色、字体层级、按钮、组件、图表、动效和交互反馈。用于快速验证宠物场景下的产品视觉与体验一致性。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(DemoScheme.allCases) { scheme in
                        schemePill(scheme)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(accentThemes) { theme in
                            accentThemePill(theme)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                specTag(icon: "paintpalette.fill", title: "Theme", note: selectedTheme.name)
                specTag(icon: "textformat.size", title: "Type", note: "Rounded")
                specTag(icon: "sparkles", title: "Motion", note: reducedMotionPreview ? "Reduced" : "Expressive")
            }
        }
        .padding(22)
        .background(surface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
        .shadow(color: .black.opacity(isDark ? 0.24 : 0.05), radius: 18, x: 0, y: 8)
    }

    private var previewSection: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    petDashboardCard
                    petDetailCard
                }
            } else {
                VStack(spacing: 16) {
                    petDashboardCard
                    petDetailCard
                }
            }
        }
    }

    private var petDashboardCard: some View {
        previewShell {
            VStack(alignment: .leading, spacing: 18) {
                previewTopBar

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi Chen,")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Text("\(selectedPet) is doing great today")
                        .font(.system(size: 28, weight: .regular, design: .rounded))
                        .foregroundStyle(textSecondary)
                }

                HStack(spacing: 12) {
                    statusCapsule("3 alerts", fill: .black, foreground: .white)
                    statusCapsule("Vaccines synced", fill: .white, foreground: textPrimary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(selectedTheme.primary.opacity(0.14))
                                .frame(width: 82, height: 82)
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(selectedTheme.primary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedPet)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(textPrimary)
                            Text("2 yrs • Mini poodle • Indoor / Outdoor")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(textSecondary)
                            HStack(spacing: 8) {
                                smallBadge("Weight 4.2kg")
                                smallBadge("Mood 4.8")
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        miniMetricCard(title: "Feed", value: "74%", note: "On track", tint: selectedTheme.primary)
                        miniMetricCard(title: "Water", value: "58%", note: "Refill soon", tint: selectedTheme.tertiary)
                        miniMetricCard(title: "Play", value: "42m", note: "Daily goal", tint: selectedTheme.secondary)
                    }

                    HStack(spacing: 12) {
                        quickAction(icon: "fork.knife", title: "Feed")
                        quickAction(icon: "cross.case.fill", title: "Health")
                        quickAction(icon: "bell.badge.fill", title: "Alerts")
                        quickAction(icon: "calendar", title: "Plan")
                    }
                }
                .padding(18)
                .background(softSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                HStack(spacing: 12) {
                    infoStripCard(title: "Daily streak", value: "9 days", note: "Reward tone + haptic")
                    infoStripCard(title: "Next care task", value: "7:30 PM", note: "Dinner + vitamin")
                }
            }
        }
    }

    private var petDetailCard: some View {
        previewShell {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    miniCircleButton(systemName: "chevron.left", diameter: 42, fill: surface, foreground: textPrimary)
                    Spacer()
                    miniCircleButton(systemName: "heart.text.square.fill", diameter: 42, fill: surface, foreground: selectedTheme.primary)
                    miniCircleButton(systemName: "bell.badge.fill", diameter: 42, fill: surface, foreground: textPrimary)
                }

                VStack(alignment: .center, spacing: 8) {
                    Text("Mochi Health Hub")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Text("Detail page spec for pet health, care and habits")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    ForEach(["Today", "Week", "Month"], id: \.self) { item in
                        chipButton(item, selected: selectedSegment == item) {
                            selectedSegment = item
                        }
                    }
                }

                HStack(spacing: 12) {
                    ringMetric(title: "Energy", value: energyProgress, tint: selectedTheme.primary)
                    ringMetric(title: "Hydration", value: hydrationProgress, tint: selectedTheme.tertiary)
                    ringMetric(title: "Feed", value: feedProgress, tint: selectedTheme.secondary)
                }

                VStack(spacing: 10) {
                    detailRow(icon: "cross.case.fill", title: "Medication reminders", note: "2 active", tint: selectedTheme.primary)
                    detailRow(icon: "moon.stars.fill", title: "Sleep log", note: "8h 24m", tint: selectedTheme.tertiary)
                    detailRow(icon: "figure.walk", title: "Walk target", note: "4.2 / 5 km", tint: selectedTheme.secondary)
                }

                HStack(spacing: 12) {
                    demoButton(title: "Book Vet", subtitle: "Primary CTA", icon: "stethoscope", style: .primary)
                    demoButton(title: "Share Record", subtitle: "Secondary", icon: "square.and.arrow.up", style: .secondary)
                }
            }
        }
    }

    private var colorAndTypographySection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("主题色 / Theme Tokens")
                    HStack(spacing: 12) {
                        themeSwatch(title: "Primary", hex: themeHexes[0], color: selectedTheme.primary)
                        themeSwatch(title: "Second", hex: themeHexes[1], color: selectedTheme.secondary)
                        themeSwatch(title: "Third", hex: themeHexes[2], color: selectedTheme.tertiary)
                    }
                    HStack(spacing: 12) {
                        themeSwatch(title: "Fourth", hex: themeHexes[3], color: selectedTheme.quaternary)
                        themeSwatch(title: "Fifth", hex: themeHexes[4], color: selectedTheme.surface)
                        themeSwatch(title: "Soft", hex: isDark ? "#24262B" : "#EFEFEF", color: softSurface)
                    }
                    specNote("页面结构保持灰色卡片体系，主题色只用于重点按钮、图表高亮和状态点缀。")
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("字体层级 / Typography")
                    typeSpecRow(name: "Display", sample: "Pet care that feels calm", size: 32, weight: .black)
                    typeSpecRow(name: "Title", sample: "Section and card titles", size: 22, weight: .bold)
                    typeSpecRow(name: "Body", sample: "Readable, low-noise descriptions", size: 15, weight: .medium)
                    typeSpecRow(name: "Caption", sample: "Tiny helper labels and metadata", size: 12, weight: .medium)
                    specNote("统一使用 rounded 字体风格，大标题偏重，数据采用 monospaced digits，避免健康数据抖动。")
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    private var buttonAndElementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("元素与按钮 / Components")

            HStack(spacing: 12) {
                demoButton(title: "Feed Now", subtitle: "Primary", icon: "pawprint.fill", style: .primary)
                demoButton(title: "View Log", subtitle: "Outline", icon: "list.bullet.rectangle.fill", style: .outline)
            }

            HStack(spacing: 12) {
                demoButton(title: "Quick Treat", subtitle: "Ghost", icon: "gift.fill", style: .ghost)
                fabButton
            }

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(["Health", "Habits", "Notes", "Community"], id: \.self) { item in
                        chipButton(item, selected: selectedCategory == item) {
                            selectedCategory = item
                        }
                    }
                }

                HStack(spacing: 12) {
                    searchCard
                    toggleSpecCard(title: "Notifications", subtitle: "High priority care reminders", isOn: $notificationsOn, tint: selectedTheme.primary)
                }

                HStack(spacing: 12) {
                    toggleSpecCard(title: "Auto Logging", subtitle: "Meal and walk completion events", isOn: $autoLogOn, tint: selectedTheme.secondary)
                    toggleSpecCard(title: "Reduced Motion", subtitle: "Preview calmer transitions", isOn: $reducedMotionPreview, tint: selectedTheme.tertiary)
                }

                sliderSpecCard
            }
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("图表规范 / Charts")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly activity")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Chart(activityData) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Minutes", item.value)
                        )
                        .cornerRadius(8)
                        .foregroundStyle(selectedTheme.primary.gradient)
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel()
                                .foregroundStyle(textSecondary)
                        }
                    }
                    .frame(height: 180)
                    specNote("柱状图用于日常行为完成度，颜色单一，避免宠物健康信息被图表本身抢戏。")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Mood trend")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Chart {
                        ForEach(Array(moodData.enumerated()), id: \.offset) { index, item in
                            AreaMark(
                                x: .value("Day", item.day),
                                y: .value("Score", item.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(selectedTheme.tertiary.opacity(0.18))

                            LineMark(
                                x: .value("Day", item.day),
                                y: .value("Score", item.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(selectedTheme.tertiary)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                            PointMark(
                                x: .value("Day", item.day),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(index == selectedMood ? selectedTheme.primary : selectedTheme.tertiary)
                            .symbolSize(index == selectedMood ? 88 : 48)
                        }
                    }
                    .chartYScale(domain: 3...5)
                    .chartYAxis(.hidden)
                    .frame(height: 180)
                    specNote("趋势图适合体重、饮水和情绪变化，控制在 1 到 2 条曲线内，避免监测面板过载。")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            HStack(spacing: 12) {
                chartMetricCard(title: "Health score", value: "92", subtitle: "Stable", tint: selectedTheme.primary)
                chartMetricCard(title: "Hydration", value: "58%", subtitle: "Below target", tint: selectedTheme.tertiary)
                chartMetricCard(title: "Play intensity", value: "High", subtitle: "Weekend peak", tint: selectedTheme.secondary)
            }
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    private var motionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle("动效规范 / Motion")
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) {
                        animateMotion.toggle()
                    }
                } label: {
                    Text("Replay")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedTheme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                ForEach(motionTokens) { token in
                    motionCard(token)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ruleLine("进入动画要短，避免宠物数据首页显得拖沓。")
                ruleLine("状态切换首选 180ms 左右，结合轻量 spring 或 easeInOut。")
                ruleLine("奖励反馈可以更活泼，但只用于完成任务、连续打卡、喂食成功等高价值动作。")
                ruleLine("若开启 Reduced Motion，移除位移动画，保留透明度和颜色反馈。")
            }
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    private var interactionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("交互反馈 / Micro Interactions")

            HStack(spacing: 12) {
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(index.isMultiple(of: 2) ? selectedTheme.primary : selectedTheme.secondary)
                            .frame(width: 10, height: 10)
                            .scaleEffect(treatBurst ? 1 : 0.25)
                            .opacity(treatBurst ? 0 : 0.95)
                            .offset(
                                x: treatBurst ? cos(Double(index) * .pi / 3) * 44 : 0,
                                y: treatBurst ? sin(Double(index) * .pi / 3) * 44 : 0
                            )
                            .animation(reducedMotionPreview ? .easeOut(duration: 0.16) : .spring(response: 0.44, dampingFraction: 0.62).delay(Double(index) * 0.015), value: treatBurst)
                    }

                    Button {
                        triggerTreatBurst()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 22, weight: .semibold))
                            Text("Reward Burst")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 126)
                        .background(selectedTheme.primary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    interactionSpecCard(title: "Pressed state", note: "Buttons scale to 0.97, shadow tightens, color deepens.", icon: "hand.tap.fill")
                    interactionSpecCard(title: "Selection state", note: "Chips invert to filled accent and preserve readable contrast.", icon: "checkmark.circle.fill")
                    interactionSpecCard(title: "Completion state", note: "Use color + icon + subtle motion, not motion alone.", icon: "sparkles")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    private var settingsRowsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("设置与列表 / Settings Rows")

            VStack(spacing: 10) {
                settingsRow(icon: "paintbrush.fill", title: "Appearance Theme", note: selectedTheme.name)
                settingsRow(icon: "bell.badge.fill", title: "Care Notifications", note: notificationsOn ? "Enabled" : "Muted")
                settingsRow(icon: "heart.text.square.fill", title: "Health Records", note: "Synced to iCloud")
                settingsRow(icon: "lock.shield.fill", title: "Privacy", note: "Family sharing")
            }
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    private var bottomBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("导航规范 / Bottom Navigation")

            HStack(spacing: 0) {
                bottomBarItem(index: 0, icon: "house.fill", title: "Home")
                bottomBarItem(index: 1, icon: "cross.case.fill", title: "Care")
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = 2
                    }
                } label: {
                    Circle()
                        .fill(selectedTheme.primary)
                        .frame(width: 62, height: 62)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        )
                }
                .buttonStyle(.plain)
                .offset(y: -18)
                .frame(maxWidth: .infinity)
                bottomBarItem(index: 3, icon: "chart.bar.fill", title: "Stats")
                bottomBarItem(index: 4, icon: "gearshape.fill", title: "Settings")
            }
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(surface, in: Capsule())
            .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1))

            specNote("底部导航保持 4 到 5 个主入口，中间浮动按钮只承担新增记录或快速护理这类高频单一动作。")
        }
    }

    private var previewTopBar: some View {
        HStack {
            Text("Overview")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(textSecondary)
            Spacer()
            HStack(spacing: 10) {
                miniCircleButton(systemName: "magnifyingglass", diameter: 40, fill: surface, foreground: textPrimary)
                miniCircleButton(systemName: "bell.badge.fill", diameter: 40, fill: surface, foreground: textPrimary)
            }
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inputs")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(textSecondary)
                TextField("", text: $searchText, prompt: Text("Search pets, feeding, health"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(borderColor, lineWidth: 1))

            HStack(spacing: 10) {
                smallBadge("Text input")
                smallBadge("Search")
                smallBadge("Filled field")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var sliderSpecCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress and sliders")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)

            VStack(spacing: 10) {
                progressRow(title: "Food portion", value: feedProgress, tint: selectedTheme.primary)
                progressRow(title: "Water intake", value: hydrationProgress, tint: selectedTheme.tertiary)
                progressRow(title: "Energy target", value: energyProgress, tint: selectedTheme.secondary)
            }

            Slider(value: $feedProgress, in: 0...1)
                .tint(selectedTheme.primary)
        }
        .padding(16)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var fabButton: some View {
        Button {
            triggerTreatBurst()
        } label: {
            ZStack {
                Circle()
                    .fill(selectedTheme.primary)
                    .frame(width: 82, height: 82)
                    .overlay(
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .frame(maxWidth: .infinity, minHeight: 126)
            .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    private func schemePill(_ scheme: DemoScheme) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                demoScheme = scheme
            }
        } label: {
            Text(scheme.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(demoScheme == scheme ? .white : textPrimary.opacity(0.72))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(demoScheme == scheme ? selectedTheme.primary : surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: demoScheme == scheme ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func accentThemePill(_ theme: AccentTheme) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selectedAccentId = theme.id
            }
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Circle().fill(theme.primary).frame(width: 10, height: 10)
                    Circle().fill(theme.secondary).frame(width: 10, height: 10)
                    Circle().fill(theme.tertiary).frame(width: 10, height: 10)
                }
                Text(theme.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedAccentId == theme.id ? textPrimary : textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selectedAccentId == theme.id ? elevatedSurface : surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(selectedAccentId == theme.id ? theme.primary : borderColor, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private func specTag(icon: String, title: String, note: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(selectedTheme.primary.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedTheme.primary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Text(note)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statusCapsule(_ title: String, fill: Color, foreground: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fill, in: Capsule())
    }

    private func smallBadge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(textPrimary.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(surface, in: Capsule())
            .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1))
    }

    private func miniMetricCard(title: String, value: String, note: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(Circle().fill(tint).frame(width: 10, height: 10))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textPrimary)
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
            Text(note)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func quickAction(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(surface)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(textPrimary)
                )
                .overlay(Circle().strokeBorder(borderColor, lineWidth: 1))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoStripCard(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
            Text(note)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func chipButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? .white : textPrimary.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(selected ? selectedTheme.primary : surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? Color.clear : borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func ringMetric(title: String, value: Double, tint: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(textTertiary.opacity(0.4), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textPrimary)
            }
            .frame(width: 78, height: 78)

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func detailRow(icon: String, title: String, note: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            miniCircleButton(systemName: icon, diameter: 40, fill: softSurface, foreground: tint)
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
            Spacer()
            Text(note)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    private enum DemoButtonStyleKind {
        case primary
        case secondary
        case outline
        case ghost
    }

    private func demoButton(title: String, subtitle: String, icon: String, style: DemoButtonStyleKind) -> some View {
        let background: Color
        let foreground: Color
        let stroke: Color

        switch style {
        case .primary:
            background = selectedTheme.primary
            foreground = .white
            stroke = .clear
        case .secondary:
            background = selectedTheme.secondary.opacity(0.24)
            foreground = textPrimary
            stroke = .clear
        case .outline:
            background = surface
            foreground = textPrimary
            stroke = borderColor
        case .ghost:
            background = softSurface
            foreground = textPrimary
            stroke = .clear
        }

        return Button {} label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(style == .primary ? .white.opacity(0.18) : softSurface)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(style == .primary ? .white : foreground)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.75)
                }
                .foregroundStyle(foreground)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(stroke, lineWidth: stroke == .clear ? 0 : 1)
            )
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    private func themeSwatch(title: String, hex: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(color)
                .frame(height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
            Text(hex)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func typeSpecRow(name: String, sample: String, size: CGFloat, weight: Font.Weight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text("\(Int(size))pt")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(textSecondary)
            }
            Text(sample)
                .font(.system(size: size, weight: weight, design: .rounded))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 4)
    }

    private func specNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func toggleSpecCard(title: String, subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(tint)
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func progressRow(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(textSecondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(surface)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(24, proxy.size.width * value))
                }
            }
            .frame(height: 12)
        }
    }

    private func chartMetricCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(Circle().fill(tint).frame(width: 10, height: 10))
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func motionCard(_ token: MotionToken) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(token.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Spacer()
                Text(token.duration)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(textSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(surface)
                    Circle()
                        .fill(selectedTheme.primary)
                        .frame(width: 28, height: 28)
                        .offset(x: reducedMotionPreview ? (proxy.size.width - 28) / 2 : (animateMotion ? proxy.size.width - 28 : 0))
                        .animation(reducedMotionPreview ? .easeInOut(duration: 0.18) : .spring(response: 0.44, dampingFraction: 0.74).repeatForever(autoreverses: true), value: animateMotion)
                }
            }
            .frame(height: 30)

            Text(token.curve)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(selectedTheme.primary)

            Text(token.usage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func ruleLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(selectedTheme.primary)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func interactionSpecCard(title: String, note: String, icon: String) -> some View {
        HStack(spacing: 12) {
            miniCircleButton(systemName: icon, diameter: 42, fill: softSurface, foreground: selectedTheme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                Text(note)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func settingsRow(icon: String, title: String, note: String) -> some View {
        HStack(spacing: 12) {
            miniCircleButton(systemName: icon, diameter: 38, fill: softSurface, foreground: selectedTheme.primary)
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
            Spacer()
            Text(note)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func bottomBarItem(index: Int, icon: String, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(selectedTab == index ? softSurface : .clear)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(selectedTab == index ? selectedTheme.primary : textSecondary)
                    )
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedTab == index ? textPrimary : textSecondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundStyle(textPrimary)
    }

    private func previewShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(surface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(isDark ? 0.24 : 0.05), radius: 18, x: 0, y: 8)
    }

    private func miniCircleButton(systemName: String, diameter: CGFloat, fill: Color, foreground: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: diameter, height: diameter)
            .overlay(Circle().strokeBorder(borderColor, lineWidth: 1))
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: diameter * 0.34, weight: .medium))
                    .foregroundStyle(foreground)
            )
    }

    private func triggerTreatBurst() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
            treatBurst = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            treatBurst = false
        }
    }
}

private struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.14), radius: configuration.isPressed ? 6 : 14, x: 0, y: configuration.isPressed ? 2 : 8)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        HomeControlUITestView()
    }
}


private struct HomeControlNavTitleModifier: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.navigationTitle("宠物主题 UI/UX 规范页")
        } else {
            content
        }
    }
}
