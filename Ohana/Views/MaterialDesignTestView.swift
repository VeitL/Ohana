//
//  MaterialDesignTestView.swift
//  Ohana
//
//  Material UI 设计系统测试页 — 展示所有组件与设计规范

import SwiftUI
import Charts

struct MaterialDesignTestView: View {
    var embeddedInMergedPage: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var bg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var surface: Color { colorScheme == .light ? .white              : Color(hex: "1C1C1E") }
    private var surf2:   Color { colorScheme == .light ? Color(hex: "F0F2F5"): Color(hex: "2C2C2E") }
    private let accent   = Color(hex: "FF5A00")
    private var textSec: Color { colorScheme == .light ? Color(hex: "8E8E93") : Color(hex: "64748B") }

    @State private var toggleA = true
    @State private var toggleB = false
    @State private var toggleC = true
    @State private var sliderVal: Double = 0.65

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)
                    colorPaletteSection
                    typographySection
                    cardsSection
                    buttonsSection
                    togglesSection
                    tagsSection
                    chartsSection
                    motionSection
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
            }
        }
                .navigationBarTitleDisplayMode(.inline)
        .toolbar(embeddedInMergedPage ? .hidden : .visible, for: .navigationBar)
        .modifier(MaterialNavTitleModifier(enabled: !embeddedInMergedPage))
    }

    // MARK: - Color Palette
    private var colorPaletteSection: some View {
        sectionCard(title: "2. 色彩系统") {
            VStack(spacing: 12) {
                paletteRow(title: "Primary Orange", hex: "FF5A00", color: Color(hex: "FF5A00"))
                paletteRow(title: "Orange Light",   hex: "FFF0E5", color: Color(hex: "FFF0E5"))
                paletteRow(title: "Surface",        hex: colorScheme == .dark ? "1C1C1E" : "FFFFFF",
                           color: surface)
                paletteRow(title: "Surface 2",      hex: colorScheme == .dark ? "2C2C2E" : "F0F2F5",
                           color: surf2)
                paletteRow(title: "Background",     hex: colorScheme == .dark ? "0A0A0C" : "F5F5F7",
                           color: bg)
                paletteRow(title: "Text Secondary", hex: colorScheme == .dark ? "64748B" : "8E8E93",
                           color: textSec)
            }
        }
    }

    private func paletteRow(title: String, hex: String, color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("#\(hex.uppercased())")
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(textSec)
            }
            Spacer()
        }
    }

    // MARK: - Typography
    private var typographySection: some View {
        sectionCard(title: "3. 排版系统") {
            VStack(alignment: .leading, spacing: 14) {
                typeRow(label: "Hero Data", example: "48", size: 48, weight: .medium)
                typeRow(label: "Page Title", example: "Welcome Home!", size: 30, weight: .medium)
                typeRow(label: "Card Title", example: "Weekly Overview", size: 18, weight: .medium)
                typeRow(label: "Body", example: "标准文字内容示例", size: 14, weight: .regular)
                typeRow(label: "Micro/Meta", example: "次要信息标签", size: 12, weight: .regular)
            }
        }
    }

    private func typeRow(label: String, example: String, size: CGFloat, weight: Font.Weight) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(textSec)
                .frame(width: 72, alignment: .leading)
            Text(example)
                .font(.system(size: size, weight: weight, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    // MARK: - Cards
    private var cardsSection: some View {
        sectionCard(title: "4.1 Cards — Bento Grid") {
            VStack(spacing: 12) {
                // Standard card
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(surface)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.03),
                                radius: 20, x: 0, y: 4)
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color(hex: "FFF0E5")).frame(width: 48, height: 48)
                            Image(systemName: "flame.fill")
                                .foregroundStyle(accent)
                                .font(.system(size: 20))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Standard Card")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("圆角 32pt · 阴影 radius 20")
                                .font(.system(size: 12)).foregroundStyle(textSec)
                        }
                        Spacer()
                    }
                    .padding(20)
                }

                // Elevated card with accent
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(LinearGradient(colors: [accent, Color(hex: "FF8A00")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: accent.opacity(0.3), radius: 16, x: 0, y: 6)
                    HStack(spacing: 14) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 28)).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accent Card")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("橙色渐变 · 彩色阴影")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Buttons
    private var buttonsSection: some View {
        sectionCard(title: "4.2 Buttons & Actions") {
            VStack(spacing: 16) {
                // FAB
                HStack(spacing: 16) {
                    Text("FAB Primary")
                        .font(.system(size: 13)).foregroundStyle(textSec)
                        .frame(width: 90, alignment: .leading)
                    Button { } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(accent, in: Circle())
                            .shadow(color: accent.opacity(0.3), radius: 12, x: 0, y: 4)
                    }.buttonStyle(ScaleButtonStyle())
                }

                // Secondary action
                HStack(spacing: 16) {
                    Text("Secondary")
                        .font(.system(size: 13)).foregroundStyle(textSec)
                        .frame(width: 90, alignment: .leading)
                    HStack(spacing: 10) {
                        ForEach(["bell", "heart", "share"], id: \.self) { icon in
                            Button { } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(textSec)
                                    .frame(width: 40, height: 40)
                                    .background(surface, in: Circle())
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                            }.buttonStyle(ScaleButtonStyle())
                        }
                    }
                }

                // Capsule pill button
                HStack(spacing: 16) {
                    Text("Pill Button")
                        .font(.system(size: 13)).foregroundStyle(textSec)
                        .frame(width: 90, alignment: .leading)
                    Button { } label: {
                        Text("开始记录")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(accent, in: Capsule())
                            .shadow(color: accent.opacity(0.3), radius: 8)
                    }.buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Toggles
    private var togglesSection: some View {
        sectionCard(title: "4.3 Toggles & Switches") {
            VStack(spacing: 14) {
                matToggleRow(label: "已喂食", isOn: $toggleA)
                matToggleRow(label: "已换水", isOn: $toggleB)
                matToggleRow(label: "已清洁", isOn: $toggleC)
                HStack {
                    Text("滑条 Slider")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(String(format: "%.0f%%", sliderVal * 100))
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(surf2).frame(height: 8)
                        Capsule().fill(accent)
                            .frame(width: geo.size.width * sliderVal, height: 8)
                    }
                    .gesture(DragGesture(minimumDistance: 0).onChanged { val in
                        sliderVal = max(0, min(1, val.location.x / geo.size.width))
                    })
                }
                .frame(height: 8)
            }
        }
    }

    private func matToggleRow(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button { withAnimation(.spring(response: 0.3)) { isOn.wrappedValue.toggle() } } label: {
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn.wrappedValue ? accent : surf2)
                        .frame(width: 48, height: 28)
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.12), radius: 3)
                        .padding(3)
                }
            }.buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Tags
    private var tagsSection: some View {
        sectionCard(title: "4.4 Tags & Badges") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    tagView("Active", bg: Color(hex: "34C759").opacity(0.15), fg: Color(hex: "34C759"))
                    tagView("Pending", bg: Color(hex: "FF9500").opacity(0.15), fg: Color(hex: "FF9500"))
                    tagView("Overdue", bg: Color(hex: "FF3B30").opacity(0.15), fg: Color(hex: "FF3B30"))
                }
                HStack(spacing: 8) {
                    tagView("喂食", bg: accent.opacity(0.12), fg: accent)
                    tagView("医疗", bg: Color(hex: "FF3B30").opacity(0.12), fg: Color(hex: "FF3B30"))
                    tagView("美容", bg: Color(hex: "C084FC").opacity(0.12), fg: Color(hex: "C084FC"))
                    tagView("玩具", bg: Color(hex: "30D158").opacity(0.12), fg: Color(hex: "30D158"))
                }
                // Status badge
                HStack(spacing: 8) {
                    Text("v4.5.0")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(hex: "0F172A"), in: Capsule())
                    Text("Material UI")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(accent.opacity(0.1), in: Capsule())
                        .overlay(Capsule().strokeBorder(accent.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }

    private func tagView(_ label: String, bg: Color, fg: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(bg, in: Capsule())
    }

    // MARK: - Charts
    private var chartsSection: some View {
        sectionCard(title: "Area Chart + Bar Chart") {
            VStack(alignment: .leading, spacing: 20) {
                Text("Area Chart (Walk Activity)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(textSec)
                let walkData: [(String, Double)] = [("M",1.2),("T",3.4),("W",0.8),("Th",4.1),("F",2.7),("Sa",5.5),("Su",1.9)]
                Chart {
                    ForEach(walkData, id: \.0) { d in
                        AreaMark(x: .value("Day", d.0), y: .value("km", d.1))
                            .foregroundStyle(
                                LinearGradient(colors: [accent.opacity(0.5), accent.opacity(0.05)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Day", d.0), y: .value("km", d.1))
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks { AxisValueLabel().font(.system(size: 11)).foregroundStyle(textSec) }
                }
                .chartYAxis(.hidden)
                .frame(height: 100)

                Text("Stacked Bar (Expenses)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(textSec)
                let expData: [(String, Double, Color)] = [
                    ("食物", 0.45, accent),
                    ("医疗", 0.25, Color(hex: "FF3B30")),
                    ("美容", 0.18, Color(hex: "C084FC")),
                    ("其他", 0.12, Color(hex: "4A90E2"))
                ]
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        ForEach(expData, id: \.0) { item in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(item.2)
                                .frame(width: geo.size.width * item.1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 16)
                HStack(spacing: 12) {
                    ForEach(expData, id: \.0) { item in
                        HStack(spacing: 4) {
                            Circle().fill(item.2).frame(width: 7, height: 7)
                            Text(item.0).font(.system(size: 10)).foregroundStyle(textSec)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Motion
    private var motionSection: some View {
        sectionCard(title: "6. Motion & Animation") {
            VStack(alignment: .leading, spacing: 12) {
                motionRow(label: "spring(0.3, 0.8)", description: "快速响应，高阻尼 — 按钮按下")
                motionRow(label: "spring(0.45, 0.75)", description: "标准 spring — 卡片展开")
                motionRow(label: "spring(0.55, 0.88)", description: "平滑 spring — bento 布局")
                motionRow(label: "spring(0.6, 0.7)", description: "较慢 spring — 粒子飞行")
                motionRow(label: "easeOut(0.45)", description: "出现动画 — 页面进入")
            }
        }
    }

    private func motionRow(label: String, description: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .bold).monospaced())
                .foregroundStyle(accent)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .frame(width: 156, alignment: .leading)
            Text(description)
                .font(.system(size: 12)).foregroundStyle(textSec)
        }
    }

    // MARK: - Section Card Helper
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(textSec)
                .padding(.horizontal, 4)
            content()
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.03), radius: 20, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack { MaterialDesignTestView() }
}


private struct MaterialNavTitleModifier: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.navigationTitle("Material UI 测试页")
        } else {
            content
        }
    }
}
