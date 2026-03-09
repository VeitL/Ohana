//
//  OhanaUIDemoView.swift
//  Ohana
//
//  UI 规范测试页 — 已确认风格 + 布局示例 (Phase 60)
//

import SwiftUI
import Charts

struct OhanaUIDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDarkMode = true
    @State private var sampleText = ""
    @State private var sampleToggle = true
    @State private var sampleSlider: Double = 0.65
    @State private var sampleDate = Date()
    @State private var sampleStepper = 3
    @State private var sampleSegment = 0
    @State private var samplePicker = 0
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var barHeights: [CGFloat] = [0.4, 0.7, 0.55, 0.9, 0.3, 0.8, 0.6]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // ─── Mode Toggle ───
                modeToggleSection

                // ─── PART 1: CHOSEN PRIMARY STYLES ───
                Group {
                    sectionLabel("✅ 基础风格 · Standard Elements")
                    
                    VStack(spacing: 16) {
                        // Typography
                        typographySection
                        
                        // Colors
                        colorPaletteSection
                        
                        // Inputs
                        inputsSection
                        
                        // Standard Card Showcase
                        VStack(alignment: .leading, spacing: 10) {
                            Text("统一卡片 (ohanaStandardCard)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("深色模式: 深蓝渐变 + 磨砂描边\n浅色模式: 纯白 + 柔和投影").font(OhanaFont.callout()).foregroundStyle(textSecondary)
                        }
                        .padding(16)
                        .ohanaStandardCard(isDarkMode: isDarkMode)
                        
                        // Chosen Alert Style D
                        VStack(spacing: 10) {
                            Text("提示横幅 (OhanaAlertBanner)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                            OhanaAlertBanner(icon: "checkmark.circle.fill", message: "操作成功完成！", bg: Color.goLime, fg: Color.arkInk)
                            OhanaAlertBanner(icon: "exclamationmark.triangle.fill", message: "证件即将到期。", bg: Color.goYellow, fg: Color.arkInk)
                            OhanaAlertBanner(icon: "xmark.circle.fill", message: "保存失败请重试。", bg: Color.goRed, fg: .white)
                            OhanaAlertBanner(icon: "info.circle.fill", message: "新版本可用。", bg: Color.goPrimary, fg: .white)
                        }
                        .padding(16)
                        .ohanaStandardCard(isDarkMode: isDarkMode)
                        
                        // Chosen Button Style B
                        VStack(spacing: 10) {
                            Text("图标按钮 (OhanaIconButton)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 12) {
                                OhanaIconButton(icon: "heart.fill", color: Color.goRed) {}
                                OhanaIconButton(icon: "star.fill", color: Color.goYellow) {}
                                OhanaIconButton(icon: "mappin.circle.fill", color: Color.goTeal) {}
                                OhanaIconButton(icon: "bell.fill", color: Color.goOrange) {}
                                Spacer()
                            }
                            
                            Text("主操作按钮 (Primary)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                            Button {} label: {
                                Text("保存设置")
                                    .font(OhanaFont.headline(.bold))
                                    .foregroundStyle(Color.arkInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(LinearGradient(colors: [Color.goLime, Color(hex: "A8E44A")], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
                            }
                        }
                        .padding(16)
                        .ohanaStandardCard(isDarkMode: isDarkMode)
                        
                        // Chosen Tag Style C
                        VStack(spacing: 10) {
                            Text("标签 (OhanaChip)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    OhanaChip(label: "🐕 狗狗", color: Color.goLime, selected: true, isDarkMode: isDarkMode)
                                    OhanaChip(label: "🐈 猫咪", color: Color.goTeal, selected: false, isDarkMode: isDarkMode)
                                    OhanaChip(label: "🐰 兔子", color: Color.goYellow, selected: false, isDarkMode: isDarkMode)
                                    OhanaChip(label: "⚖️ 体重", color: Color.goOrange, selected: false, isDarkMode: isDarkMode)
                                }
                            }
                        }
                        .padding(16)
                        .ohanaStandardCard(isDarkMode: isDarkMode)
                    }
                }

                // ─── PART 2: LAYOUT EXPLORATIONS (Standardized) ───
                Group {
                    sectionLabel("🧩 布局规范 · Layout Conventions")
                    Text("不要使用单一的横条卡片堆叠，使用这些组合进行布局。").font(OhanaFont.callout()).foregroundStyle(textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                    
                    // Style A: Bento Box
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. 组合方块 (Bento Box)").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                        Text("用于仪表盘和详情页头部").font(OhanaFont.caption()).foregroundStyle(textSecondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "dog.fill").font(.system(size: 32)).foregroundStyle(Color.goLime)
                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("萌宠档案").font(OhanaFont.title3(.bold)).foregroundStyle(textPrimary)
                                    Text("基本概览").font(OhanaFont.caption()).foregroundStyle(textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .ohanaStandardCard(isDarkMode: isDarkMode)
                            
                            VStack(spacing: 12) {
                                layoutSmallCard(icon: "calendar", title: "日程", color: Color.goTeal)
                                layoutSmallCard(icon: "chart.bar.fill", title: "健康", color: Color.goOrange)
                            }
                            .frame(width: 100)
                        }
                        .frame(height: 140)
                    }

                    // Style B: Split Cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. 对称切片 (Split Cards)").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                        Text("用于并列两项重要指标").font(OhanaFont.caption()).foregroundStyle(textSecondary)
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "pawprint.fill").foregroundStyle(Color.goLime)
                                Text("遛狗").font(OhanaFont.callout(.bold))
                                Spacer()
                                Text("1.2k").font(OhanaFont.footnote(.bold)).foregroundStyle(textSecondary)
                            }
                            .padding(14).ohanaStandardCard(isDarkMode: isDarkMode)
                            
                            HStack {
                                Image(systemName: "drop.fill").foregroundStyle(Color.goTeal)
                                Text("喝水").font(OhanaFont.callout(.bold))
                                Spacer()
                                Text("600ml").font(OhanaFont.footnote(.bold)).foregroundStyle(textSecondary)
                            }
                            .padding(14).ohanaStandardCard(isDarkMode: isDarkMode)
                        }
                    }

                    // Style C: Floating Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. 悬浮群组 (Floating Groups)").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                        Text("用于设置页和列表，代替各自独立的行卡片").font(OhanaFont.caption()).foregroundStyle(textSecondary)
                        VStack(spacing: 0) {
                            groupItem(icon: "gearshape.fill", title: "系统设置", color: Color.goPrimary)
                            OhanaDashedDivider(color: isDarkMode ? .white.opacity(0.1) : .black.opacity(0.05)).padding(.leading, 50)
                            groupItem(icon: "lock.fill", title: "隐私与安全", color: Color.goTeal)
                            OhanaDashedDivider(color: isDarkMode ? .white.opacity(0.1) : .black.opacity(0.05)).padding(.leading, 50)
                            groupItem(icon: "person.2.fill", title: "家庭管理", color: Color.goOrange)
                        }
                        .ohanaStandardCard(isDarkMode: isDarkMode)
                    }
                }

                // ─── PART 3: QUICK ACCESS (QA) ───
                Group {
                    sectionLabel("⚡️ 快捷操作卡片 · Quick Access")
                    Text("OhanaQACard (玻璃质感，小巧紧凑)").font(OhanaFont.callout()).foregroundStyle(textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            OhanaQACard(title: "今日运动", value: "45分", icon: "figure.walk", color: Color.goLime, isDarkMode: isDarkMode)
                            OhanaQACard(title: "体重", value: "6.2kg", icon: "scalemass.fill", color: Color.goTeal, isDarkMode: isDarkMode)
                            OhanaQACard(title: "收益余额", value: "248 🥥", icon: "leaf.circle.fill", color: Color.goYellow, isDarkMode: isDarkMode)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                }

                // ─── PART 4: CHARTS & ANIMATIONS ───
                Group {
                    sectionLabel("📊 数据可视化 · Charts & Metrics")
                    VStack(spacing: 16) {
                        chartsSection
                        progressSection
                        animationsSection
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background {
            if isDarkMode { ArkBackgroundView() }
            else { Color(hex: "F4F5F9").ignoresSafeArea() }
        }
        .navigationTitle("Ohana UI 规范")
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

    // MARK: - Components

    private var modeToggleSection: some View {
        HStack(spacing: 14) {
            Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isDarkMode ? Color.goYellow : Color.goOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(isDarkMode ? "深色模式 Dark" : "浅色模式 Light").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                Text("实时预览所有标准组件").font(OhanaFont.caption()).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isDarkMode).labelsHidden().tint(Color.goLime)
        }
        .padding(16).ohanaStandardCard(isDarkMode: isDarkMode)
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased()).font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(isDarkMode ? .white.opacity(0.4) : Color.arkInk.opacity(0.4)).tracking(1.2)
            Spacer()
        }
        .padding(.leading, 4).padding(.top, 8)
    }

    // MARK: Typography
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("排版 (OhanaFont)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text("Hero / Metric").font(OhanaFont.metric(size: 40)).foregroundStyle(textPrimary)
                Text("LargeTitle").font(OhanaFont.largeTitle()).foregroundStyle(textPrimary)
                Text("Title").font(OhanaFont.title()).foregroundStyle(textPrimary)
                Text("Title3").font(OhanaFont.title3()).foregroundStyle(textPrimary)
                Text("Headline").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                Text("Body 说明正文").font(OhanaFont.body()).foregroundStyle(textSecondary)
                Text("Caption / Footnote 辅助信息").font(OhanaFont.caption()).foregroundStyle(textTertiary)
            }
        }
        .padding(16)
        .ohanaStandardCard(isDarkMode: isDarkMode)
    }

    // MARK: Colors
    private var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("品牌色板").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                paletteChip("goLime", Color.goLime)
                paletteChip("goYellow", Color.goYellow)
                paletteChip("goOrange", Color.goOrange)
                paletteChip("goRed", Color.goRed)
                paletteChip("goTeal", Color.goTeal)
                paletteChip("goMint", Color.goMint)
            }
        }
        .padding(16)
        .ohanaStandardCard(isDarkMode: isDarkMode)
    }

    private func paletteChip(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6).fill(color).frame(width: 24, height: 24)
            Text(name).font(OhanaFont.caption2(.bold)).foregroundStyle(textPrimary).lineLimit(1)
            Spacer()
        }
    }

    // MARK: Inputs
    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("表单输入 (Inputs)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
            
            // TextField
            HStack {
                Image(systemName: "pencil").foregroundStyle(textTertiary)
                TextField("输入些什么...", text: $sampleText)
                    .foregroundStyle(textPrimary)
            }
            .padding(12)
            .background(isDarkMode ? .white.opacity(0.05) : .black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            
            // Segment
            Picker("", selection: $sampleSegment) {
                Text("选项 1").tag(0); Text("选项 2").tag(1); Text("选项 3").tag(2)
            }
            .pickerStyle(.segmented)
            
            HStack {
                Text("Stepper").font(OhanaFont.body()).foregroundStyle(textPrimary)
                Spacer()
                Stepper("\(sampleStepper)", value: $sampleStepper, in: 0...10)
                    .font(OhanaFont.body(.bold)).fixedSize()
            }
        }
        .padding(16)
        .ohanaStandardCard(isDarkMode: isDarkMode)
    }

    // MARK: Layout Explorations Components
    private func layoutSmallCard(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(title).font(OhanaFont.caption(.bold)).foregroundStyle(textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .ohanaStandardCard(isDarkMode: isDarkMode)
    }

    private func groupItem(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(title).font(OhanaFont.body(.semibold)).foregroundStyle(textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(textTertiary)
        }
        .padding(14)
        .background(isDarkMode ? .white.opacity(0.01) : .clear)
    }

    // MARK: Charts & Progress
    private var chartsSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("图表 (Charts)").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                Chart {
                    ForEach(Array(zip(weekDays, weekValues).enumerated()), id: \.offset) { i, pair in
                        LineMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.goLime)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        AreaMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color.goLime.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(height: 100)
            }
            .padding(16).ohanaStandardCard(isDarkMode: isDarkMode)
        }
    }

    private var progressSection: some View {
        HStack(spacing: 12) {
            Text("128").font(OhanaFont.metric(size: 44)).foregroundStyle(Color.goLime)
            Text("天").font(OhanaFont.callout()).foregroundStyle(textSecondary)
            Spacer()
            Circle().trim(from: 0, to: 0.75).stroke(Color.goLime, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 40, height: 40)
        }
        .padding(16).ohanaStandardCard(isDarkMode: isDarkMode)
    }

    private var animationsSection: some View {
        HStack(spacing: 16) {
            Circle().fill(Color.goLime.opacity(0.15)).frame(width: 40, height: 40)
                .scaleEffect(pulseScale)
                .overlay(Image(systemName: "heart.fill").foregroundStyle(Color.goLime))
            Text("活跃状态脉冲 (Animations)").font(OhanaFont.callout(.bold)).foregroundStyle(textPrimary)
            Spacer()
        }
        .padding(14).ohanaStandardCard(isDarkMode: isDarkMode)
    }

    // MARK: Helpers
    private var textPrimary: Color { isDarkMode ? .white : Color.arkInk }
    private var textSecondary: Color { isDarkMode ? .white.opacity(0.5) : Color.arkInk.opacity(0.5) }
    private var textTertiary: Color { isDarkMode ? .white.opacity(0.3) : Color.arkInk.opacity(0.3) }

    private let weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private let weekValues: [Double] = [3, 5, 2, 7, 4, 8, 6]

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulseScale = 1.15 }
    }
}

#Preview {
    OhanaUIDemoView()
}
