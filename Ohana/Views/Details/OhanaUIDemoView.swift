//
//  OhanaUIDemoView.swift
//  Ohana
//
//  UI 规范测试页 — 已确认风格 + 布局探索
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
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationDeg: Double = 0
    @State private var barHeights: [CGFloat] = [0.4, 0.7, 0.55, 0.9, 0.3, 0.8, 0.6]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // ─── Mode Toggle ───
                modeToggleSection

                // ─── PART 1: CHOSEN PRIMARY STYLES ───
                Group {
                    sectionLabel("✅ 已确认的基础风格 · Standard Styles")
                    
                    VStack(spacing: 16) {
                        // Chosen Alert Style D (Solid Capsule)
                        VStack(spacing: 10) {
                            Text("横幅风格 (选定: D)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                            alertStyleD("checkmark.circle.fill", "操作成功完成！", Color.goLime, Color.arkInk)
                            alertStyleD("exclamationmark.triangle.fill", "证件即将到期。", Color.goYellow, Color.arkInk)
                        }
                        
                        // Chosen Button Style B (Gradient subtle background)
                        VStack(spacing: 10) {
                            Text("图标按钮 (选定: B)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 12) {
                                iconBtnStyleB("heart.fill", Color.goRed)
                                iconBtnStyleB("star.fill", Color.goYellow)
                                iconBtnStyleB("mappin.circle.fill", Color.goTeal)
                                iconBtnStyleB("bell.fill", Color.goOrange)
                                Spacer()
                            }
                        }
                        
                        // Chosen Tag Style C (Dot + Weighted bg)
                        VStack(spacing: 10) {
                            Text("标签风格 (选定: C)").font(OhanaFont.footnote(.bold)).foregroundStyle(textTertiary).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 8) {
                                chipStyleC("🐕 狗狗", Color.goLime, selected: true)
                                chipStyleC("🐈 猫咪", Color.goTeal, selected: false)
                                chipStyleC("🐰 兔子", Color.goYellow, selected: false)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .standardCard(dark: isDarkMode)
                }

                // ─── PART 2: LAYOUT EXPLORATIONS ───
                Group {
                    sectionLabel("🧩 布局探索 · Layout Variations")
                    Text("打破单一的横条卡片，尝试更多空间组合").font(OhanaFont.callout()).foregroundStyle(textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                    
                    // Style A: Bento Box (Mix of large and small squares)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("风格 1: 组合方块 (Bento Box)").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                        HStack(spacing: 12) {
                            // Large Square
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "dog.fill").font(.system(size: 32)).foregroundStyle(Color.goLime)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("萌宠档案").font(OhanaFont.title3(.bold)).foregroundStyle(textPrimary)
                                    Text("查看基本信息").font(OhanaFont.caption()).foregroundStyle(textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .standardCard(dark: isDarkMode)
                            
                            // Right Column (Two small squares)
                            VStack(spacing: 12) {
                                layoutSmallCard(icon: "calendar", title: "日程", color: Color.goTeal)
                                layoutSmallCard(icon: "chart.bar.fill", title: "健康", color: Color.goOrange)
                            }
                            .frame(width: 100)
                        }
                    }

                    // Style B: Split Cards (Visual balance)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("风格 2: 对称切片 (Split Cards)").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "pawprint.fill").foregroundStyle(Color.goLime)
                                Text("遛狗").font(OhanaFont.callout(.bold))
                                Spacer()
                                Text("1.2k").font(OhanaFont.footnote(.bold)).foregroundStyle(textSecondary)
                            }
                            .padding(14).standardCard(dark: isDarkMode)
                            
                            HStack {
                                Image(systemName: "drop.fill").foregroundStyle(Color.goTeal)
                                Text("喝水").font(OhanaFont.callout(.bold))
                                Spacer()
                                Text("600ml").font(OhanaFont.footnote(.bold)).foregroundStyle(textSecondary)
                            }
                            .padding(14).standardCard(dark: isDarkMode)
                        }
                    }

                    // Style C: Floating Section (Minimalist)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("风格 3: 悬浮群组 (Floating Groups)").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                        VStack(spacing: 1) {
                            groupItem(icon: "gearshape.fill", title: "系统设置", color: Color.goPrimary, isTop: true)
                            Divider().padding(.leading, 50).opacity(0.1)
                            groupItem(icon: "lock.fill", title: "隐私与安全", color: Color.goTeal, isBottom: true)
                        }
                        .standardCard(dark: isDarkMode)
                    }
                }

                // ─── PART 3: QUICK ACCESS (QA) EXPLORATIONS ───
                Group {
                    sectionLabel("⚡️ QA 卡片探索 · Quick Access Styles")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            // Style 1: Modern Glass (Large Icon + Metric)
                            qaGlassCard(title: "今日运动", value: "45分", icon: "figure.walk", color: Color.goLime)
                            
                            // Style 2: Gradient Minimal (Clean)
                            qaGradientCard(title: "体重记录", value: "6.2kg", icon: "scalemass.fill", color: Color.goTeal)
                            
                            // Style 3: Illustration Style (Colorful bg)
                            qaIllustrativeCard(title: "椰子收获", value: "28", icon: "leaf.circle.fill", color: Color.goYellow)
                            
                            // Style 4: Classic Badge
                            qaClassicCard(title: "剩余猫粮", value: "1.5kg", icon: "cart.fill", color: Color.goOrange)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                }

                // ─── PART 4: CHARTS & ANIMATIONS (Retained) ───
                Group {
                    sectionLabel("📊 数据 & 指标 · Metrics")
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
        .navigationTitle("UI 规范探索")
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

    // MARK: - Components & Helpers

    private var modeToggleSection: some View {
        HStack(spacing: 14) {
            Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isDarkMode ? Color.goYellow : Color.goOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(isDarkMode ? "深色模式 Dark" : "浅色模式 Light").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                Text("实时预览选定风格与新布局设计").font(OhanaFont.caption()).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isDarkMode).labelsHidden().tint(Color.goLime)
        }
        .padding(16).standardCard(dark: isDarkMode)
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased()).font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(isDarkMode ? .white.opacity(0.4) : Color.arkInk.opacity(0.4)).tracking(1.2)
            Spacer()
        }
        .padding(.leading, 4).padding(.top, 8)
    }

    // Standard Styles Helpers
    private func alertStyleD(_ icon: String, _ msg: String, _ bg: Color, _ fg: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(fg)
            Text(msg).font(OhanaFont.callout(.bold)).foregroundStyle(fg)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(bg, in: Capsule())
    }

    private func iconBtnStyleB(_ icon: String, _ color: Color) -> some View {
        Button {} label: {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [color.opacity(0.2), color.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
    }

    private func chipStyleC(_ label: String, _ color: Color, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(OhanaFont.callout(.bold)).foregroundStyle(selected ? textPrimary : textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            isDarkMode ? (selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                      : (selected ? color.opacity(0.12) : Color.black.opacity(0.04)),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    // Layout Exploration Helpers
    private func layoutSmallCard(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(title).font(OhanaFont.caption(.bold)).foregroundStyle(textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .standardCard(dark: isDarkMode)
    }

    private func groupItem(icon: String, title: String, color: Color, isTop: Bool = false, isBottom: Bool = false) -> some View {
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

    // Quick Access Card Helpers
    private func qaGlassCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 24, weight: .bold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(OhanaFont.title2(.black)).foregroundStyle(textPrimary)
                Text(title).font(OhanaFont.caption2(.bold)).foregroundStyle(textSecondary)
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding(16)
        .standardCard(dark: isDarkMode)
    }

    private func qaGradientCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(OhanaFont.caption(.bold)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.white)
            }
            Spacer()
            Text(value).font(OhanaFont.title2(.black)).foregroundStyle(.white)
        }
        .frame(width: 130, height: 80)
        .padding(14)
        .background(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }

    private func qaIllustrativeCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(OhanaFont.title3(.bold)).foregroundStyle(textPrimary)
                Text(title).font(OhanaFont.caption2()).foregroundStyle(textSecondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .standardCard(dark: isDarkMode)
    }

    private func qaClassicCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
            Text(value).font(OhanaFont.callout(.bold)).foregroundStyle(textPrimary)
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(textSecondary)
        }
        .frame(width: 80, height: 80)
        .standardCard(dark: isDarkMode)
    }

    // (Existing charts/progress logic retained for reference but cleaned up)
    private var chartsSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("健康趋势折线图").font(OhanaFont.headline()).foregroundStyle(textPrimary)
                Chart {
                    ForEach(Array(zip(weekDays, weekValues).enumerated()), id: \.offset) { i, pair in
                        LineMark(x: .value("Day", pair.0), y: .value("Val", pair.1))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.goLime)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                }
                .frame(height: 100)
            }
            .padding(16).standardCard(dark: isDarkMode)
        }
    }

    private var progressSection: some View {
        HStack(spacing: 12) {
            Text("128").font(OhanaFont.metric(size: 44)).foregroundStyle(Color.goLime)
            Text("天").font(OhanaFont.callout()).foregroundStyle(textSecondary)
            Spacer()
            Circle().trim(from: 0, to: 0.75).stroke(Color.goLime, lineWidth: 4).frame(width: 30, height: 30)
        }
        .padding(16).standardCard(dark: isDarkMode)
    }

    private var animationsSection: some View {
        HStack(spacing: 16) {
            Circle().fill(Color.goLime.opacity(0.15)).frame(width: 40, height: 40)
                .scaleEffect(pulseScale)
                .overlay(Image(systemName: "heart.fill").foregroundStyle(Color.goLime))
            Text("活跃状态脉冲").font(OhanaFont.callout(.bold)).foregroundStyle(textPrimary)
            Spacer()
        }
        .padding(14).standardCard(dark: isDarkMode)
    }

    private var textPrimary: Color { isDarkMode ? .white : Color.arkInk }
    private var textSecondary: Color { isDarkMode ? .white.opacity(0.5) : Color.arkInk.opacity(0.5) }
    private var textTertiary: Color { isDarkMode ? .white.opacity(0.3) : Color.arkInk.opacity(0.3) }

    private let weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private let weekValues: [Double] = [3, 5, 2, 7, 4, 8, 6]

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulseScale = 1.15 }
    }
}

// MARK: - Unified Card Modifier
private extension View {
    func standardCard(dark: Bool) -> some View {
        self.background {
            if dark {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color.goDarkBlue.opacity(0.8), Color.goDeepNavy.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            }
        }
    }
}

#Preview {
    OhanaUIDemoView()
}
