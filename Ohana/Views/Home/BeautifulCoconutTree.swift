//
//  BeautifulCoconutTree.swift
//  Ohana
//
//  SwiftUI 精确翻译 React/Framer Motion 版椰子树
//  - 固定椰子坐标（9个）+ 呼吸发光 + 采摘交互
//  - 藤蔓 trim 生长动画（Lv5+）
//  - 升级冲击波特效
//  - 整体 scale 随等级变化
//

import SwiftUI

// MARK: - 等级配置

struct TreeLevelConfig {
    let level: Int
    let name: String
    let scale: Double
    let leafCount: Int
    let coconutCount: Int
}

private let treeLevelConfigs: [TreeLevelConfig] = [
    .init(level: 1,  name: "破土新芽", scale: 0.4, leafCount: 2,  coconutCount: 0),
    .init(level: 2,  name: "稚嫩幼苗", scale: 0.5, leafCount: 4,  coconutCount: 0),
    .init(level: 3,  name: "茁壮小树", scale: 0.6, leafCount: 6,  coconutCount: 0),
    .init(level: 4,  name: "青葱树冠", scale: 0.7, leafCount: 8,  coconutCount: 0),
    .init(level: 5,  name: "初结硕果", scale: 0.8, leafCount: 10, coconutCount: 1),
    .init(level: 6,  name: "丰收之树", scale: 0.9, leafCount: 12, coconutCount: 3),
    .init(level: 7,  name: "绿洲明珠", scale: 1.0, leafCount: 14, coconutCount: 5),
    .init(level: 8,  name: "繁星树冠", scale: 1.1, leafCount: 16, coconutCount: 7),
    .init(level: 9,  name: "生命之源", scale: 1.2, leafCount: 16, coconutCount: 9),
    .init(level: 10, name: "永恒神树", scale: 1.3, leafCount: 16, coconutCount: 9),
]

// 9 个椰子固定坐标（相对树冠中心，对应 React 源码）
private let cocoPositions: [(x: CGFloat, y: CGFloat)] = [
    (-25, 15), (25, 10), (0, 30),
    (-45, -5), (40, -15), (-15, 45),
    (15, 45), (-35, 25), (35, 25)
]

// MARK: - BeautifulCoconutTree

struct BeautifulCoconutTree: View {
    var level: Int           // 1-10
    var isInjecting: Bool    // 注入能量脉冲
    var harvestedCoconuts: Set<Int> = []        // 已采摘的椰子索引
    var onHarvest: ((Int) -> Void)? = nil       // 采摘回调

    @State private var isSwaying = false
    @State private var burstKey  = 0            // 升级冲击波触发器
    @State private var shockwaveScale: CGFloat = 0
    @State private var shockwaveOpacity: Double = 0
    @State private var vineProgress: CGFloat = 0

    private var cfg: TreeLevelConfig {
        treeLevelConfigs[max(0, min(level - 1, 9))]
    }
    private var isMax: Bool { level >= 10 }
    private var glowColor: Color { isMax ? Color(hex: "FBBF24") : Color.goLime }

    // React 源码固定参数
    private let trunkH: CGFloat = 180
    private var trunkW: CGFloat { CGFloat(24 + level * 2) }
    private let bend:   CGFloat = 30

    private func leafColor(index i: Int) -> Color {
        if isMax { return i % 2 == 0 ? Color(hex: "00FFD1") : Color(hex: "0284C7") }
        if level >= 7 { return i % 2 == 0 ? Color(hex: "22C55E") : Color(hex: "15803D") }
        return i % 2 == 0 ? Color(hex: "84CC16") : Color(hex: "4D7C0F")
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── 背景光效（Sunbeams, Lv9+)
            if level >= 9 {
                SunbeamsView()
                    .offset(y: -100)
            }

            // ── 升级冲击波（在树冠中心位置）
            if burstKey > 0 {
                Circle()
                    .stroke(glowColor, lineWidth: 4)
                    .frame(width: 20, height: 20)
                    .scaleEffect(shockwaveScale)
                    .opacity(shockwaveOpacity)
                    .offset(x: bend + trunkW * 0.4,
                            y: -(trunkH * CGFloat(cfg.scale)))
                    .allowsHitTesting(false)
            }

            // ── 底部光环与阴影（绿洲神池）
            if level >= 7 {
                Ellipse()
                    .fill(Color(hex: "0EA5E9").opacity(0.6))
                    .frame(width: trunkW * 6, height: trunkW * 2)
                    .blur(radius: 12)
                    .animation(.spring(response: 1.5), value: level)
            }

            Ellipse()
                .fill(isMax ? Color(hex: "0F172A") : Color(hex: "271A14"))
                .frame(width: trunkW * 5, height: trunkW * 1.6)
                .animation(.spring(response: 1.5), value: level)

            // ── 树干
            TrunkShape(trunkWidth: Double(trunkW), trunkHeight: Double(trunkH), bend: Double(bend))
                .fill(
                    LinearGradient(
                        colors: isMax
                            ? [Color(hex: "1E293B"), Color(hex: "334155"), Color(hex: "0F172A")]
                            : [Color(hex: "452B17"), Color(hex: "5C3A21"), Color(hex: "3A2413")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: trunkW * 4 + bend + 40, height: trunkH + 10)
                .animation(.spring(response: 1.5, dampingFraction: 0.7), value: level)

            // ── 藤蔓（Lv5+，trim 生长动画）
            if level >= 5 {
                VineShape(trunkWidth: Double(trunkW), trunkHeight: Double(trunkH), bend: Double(bend))
                    .trim(from: 0, to: vineProgress)
                    .stroke(
                        Color(hex: "84CC16"),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: trunkW * 4 + bend + 40, height: trunkH + 10)
                    .shadow(color: Color(hex: "84CC16").opacity(0.6), radius: 4)
                    .opacity(0.8)
                    .animation(.easeOut(duration: 2.0), value: vineProgress)
            }

            // ── 神圣光环 (Divine Halo, Lv6+)
            if level >= 6 {
                DivineHaloView(isSwaying: isSwaying)
                    .offset(x: bend + trunkW * 0.4, y: -(trunkH))
            }

            // ── 树冠（树叶 + 椰子，摇摆）
            ZStack {
                // 树叶（扇形，originX/Y=0 对应 React style.origin）
                ForEach(0..<16, id: \.self) { i in
                    let isActive = i < cfg.leafCount
                    let angle: Double = cfg.leafCount > 1
                        ? -150 + Double(i) * (300.0 / Double(max(1, cfg.leafCount - 1)))
                        : -150
                    LeafShape()
                        .fill(leafColor(index: i))
                        .frame(width: 100, height: 60)
                        .scaleEffect(isActive ? (isMax ? 1.3 : 1.0) : 0.001,
                                     anchor: .topLeading)
                        .rotationEffect(.degrees(angle), anchor: .topLeading)
                        .opacity(isActive ? 0.95 : 0)
                        .animation(
                            .spring(response: 1.5, dampingFraction: 0.6)
                                .delay(isActive ? Double(i) * 0.05 : 0),
                            value: cfg.leafCount
                        )
                        .allowsHitTesting(false)
                }

                // 椰子（固定坐标，9 个槽位）
                ForEach(0..<9, id: \.self) { i in
                    if i < cfg.coconutCount {
                        let pos = cocoPositions[i]
                        let isHarvested = harvestedCoconuts.contains(i)
                        InteractiveCoconut(
                            index: i,
                            isMax: isMax,
                            isHarvested: isHarvested,
                            onTap: { onHarvest?(i) }
                        )
                        .offset(x: pos.x, y: pos.y)
                        .animation(
                            .spring(response: 1.0, dampingFraction: 0.6)
                                .delay(0.5 + Double(i) * 0.1),
                            value: cfg.coconutCount
                        )
                    }
                }

                // ── 符文 (Runes, Lv10)
                if isMax {
                    RunesView(isSwaying: isSwaying)
                }

                // ── 星尘 (Stardust, Lv8+)
                if level >= 8 {
                    StardustView()
                }
            }
            // 树冠对齐树干顶端（对应 React animate.x/y）
            .offset(x: bend + trunkW * 0.4,
                    y: -(trunkH - (level == 1 ? 5 : 0)))
            // 持续摇摆
            .rotationEffect(.degrees(isSwaying ? 2 : -2), anchor: .bottom)
            .animation(
                .easeInOut(duration: 6).repeatForever(autoreverses: true),
                value: isSwaying
            )
            // 注入能量脉冲
            .scaleEffect(isInjecting ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isInjecting)
        }
        // 整体 scale 随等级变化（React 源码 animate.scale）
        .scaleEffect(CGFloat(cfg.scale))
        .animation(.spring(response: 1.5, dampingFraction: 0.7), value: cfg.scale)
        .frame(width: 260, height: 320)
        .onAppear {
            isSwaying = true
            if level >= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    vineProgress = 1.0
                }
            }
        }
        .onChange(of: level) { oldVal, newVal in
            if newVal > oldVal { triggerShockwave() }
            // 新等级达到 5+ 时重新生长藤蔓
            if newVal >= 5 && oldVal < 5 {
                vineProgress = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    vineProgress = 1.0
                }
            }
        }
    }

    // MARK: - 升级冲击波
    private func triggerShockwave() {
        burstKey += 1
        shockwaveScale = 0
        shockwaveOpacity = 1
        withAnimation(.easeOut(duration: 1.5)) {
            shockwaveScale = 25
            shockwaveOpacity = 0
        }
    }
}

// MARK: - InteractiveCoconut（含呼吸发光 + 采摘动画）

private struct InteractiveCoconut: View {
    let index: Int
    let isMax: Bool
    let isHarvested: Bool
    let onTap: () -> Void

    @State private var breatheScale: CGFloat = 0.8
    @State private var breatheOpacity: Double = 0

    var body: some View {
        ZStack {
            // 呼吸发光
            if !isHarvested {
                Circle()
                    .fill(Color.goLime)
                    .frame(width: 32, height: 32)
                    .scaleEffect(breatheScale)
                    .opacity(breatheOpacity)
                    .blur(radius: 4)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2).repeatForever(autoreverses: true)
                        ) {
                            breatheScale  = 1.4
                            breatheOpacity = 0.5
                        }
                    }
            }

            // 椰子本体
            CoconutView(isMax: isMax)
                .scaleEffect(isHarvested ? 0.001 : 1.0)
                .opacity(isHarvested ? 0 : 1)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.6),
                    value: isHarvested
                )
        }
        .onTapGesture { if !isHarvested { onTap() } }
    }
}

// MARK: - TrunkShape

struct TrunkShape: Shape {
    var trunkWidth: Double
    var trunkHeight: Double
    var bend: Double

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(trunkWidth, AnimatablePair(trunkHeight, bend)) }
        set {
            trunkWidth  = newValue.first
            trunkHeight = newValue.second.first
            bend        = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // 对应 React: M{-w/2},0 Q{bend/2},{-h/2} {bend},{-h}
        //             L{bend + w*0.4},{-h} Q{bend/2 + w},{-h/2} {w/2},0 Z
        var path = Path()
        let cx = rect.midX
        let by = rect.maxY
        let w  = trunkWidth
        let h  = trunkHeight
        let b  = bend

        path.move(to: CGPoint(x: cx - w/2, y: by))
        path.addQuadCurve(
            to:      CGPoint(x: cx + b,      y: by - h),
            control: CGPoint(x: cx + b/2,    y: by - h/2)
        )
        path.addLine(to: CGPoint(x: cx + b + w * 0.4, y: by - h))
        path.addQuadCurve(
            to:      CGPoint(x: cx + w/2,    y: by),
            control: CGPoint(x: cx + b/2 + w, y: by - h/2)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - VineShape（藤蔓，供 .trim 动画）

struct VineShape: Shape {
    var trunkWidth: Double
    var trunkHeight: Double
    var bend: Double

    func path(in rect: CGRect) -> Path {
        // 对应 React: M{-w/2},0 Q{bend},{-h*0.3} {bend-10},{-h*0.6} T{bend+10},{-h*0.9}
        var path = Path()
        let cx = rect.midX
        let by = rect.maxY
        let w  = trunkWidth
        let h  = trunkHeight
        let b  = bend

        path.move(to: CGPoint(x: cx - w/2, y: by))
        path.addQuadCurve(
            to:      CGPoint(x: cx + b - 10, y: by - h * 0.6),
            control: CGPoint(x: cx + b,      y: by - h * 0.3)
        )
        path.addQuadCurve(
            to:      CGPoint(x: cx + b + 10, y: by - h * 0.9),
            control: CGPoint(x: cx + b - 20, y: by - h * 0.75)
        )
        return path
    }
}

// MARK: - LeafShape

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        // SVG: M0,0 C30,-40 80,-20 100,20 C60,0 30,-10 0,0 Z
        let sx = rect.width  / 100.0
        let sy = rect.height / 60.0
        let ox = rect.minX
        let oy = rect.midY

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * sx, y: oy + y * sy)
        }

        var path = Path()
        path.move(to: pt(0, 0))
        path.addCurve(to: pt(100, 20), control1: pt(30, -40), control2: pt(80, -20))
        path.addCurve(to: pt(0,   0),  control1: pt(60,   0), control2: pt(30, -10))
        path.closeSubpath()
        return path
    }
}

// MARK: - CoconutView

struct CoconutView: View {
    var isMax: Bool

    private var w: CGFloat { isMax ? 22 : 18 }
    private var h: CGFloat { isMax ? 26 : 22 }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(isMax ? Color(hex: "FBBF24") : Color(hex: "8B4513"))
                .frame(width: w, height: h)

            Ellipse()
                .fill(isMax ? Color(hex: "F59E0B") : Color(hex: "5C2E0B"))
                .frame(width: w, height: h)
                .mask(
                    VStack(spacing: 0) {
                        Color.clear.frame(height: h / 2)
                        Color.black.frame(height: h / 2)
                    }
                )
                .opacity(0.8)

            let eyeColor = isMax ? Color(hex: "B45309") : Color(hex: "3E1F07")
            Circle().fill(eyeColor).frame(width: 3, height: 3).offset(x: -3, y: -5)
            Circle().fill(eyeColor).frame(width: 3, height: 3).offset(x:  3, y: -5)
            Circle().fill(eyeColor).frame(width: 3, height: 3).offset(x:  0, y: -1)

            if isMax {
                Circle()
                    .fill(Color(hex: "FEF3C7"))
                    .frame(width: 6, height: 6)
                    .blur(radius: 1)
                    .opacity(0.6)
                    .offset(x: -4, y: -6)
            }
        }
    }
}

// MARK: - Special Visual Effects (AI Studio Features)

struct SunbeamsView: View {
    @State private var breathe = false
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: -60, y: -200))
            path.addLine(to: CGPoint(x: 60, y: -200))
            path.addLine(to: CGPoint(x: 200, y: 300))
            path.addLine(to: CGPoint(x: -200, y: 300))
            path.closeSubpath()
        }
        .fill(LinearGradient(colors: [.white.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom))
        .opacity(breathe ? 0.8 : 0.3)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

struct DivineHaloView: View {
    var isSwaying: Bool
    var body: some View {
        Circle()
            .strokeBorder(
                AngularGradient(colors: [Color(hex: "00FFD1"), Color(hex: "C8FF00"), Color(hex: "00FFD1")], center: .center),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 10])
            )
            .frame(width: 240, height: 240)
            .rotationEffect(.degrees(isSwaying ? 360 : 0))
            .animation(.linear(duration: 25).repeatForever(autoreverses: false), value: isSwaying)
            .opacity(0.8)
            .allowsHitTesting(false)
    }
}

struct RunesView: View {
    var isSwaying: Bool
    private let runes = ["✧", "✦", "✺", "✵", "❂", "❀"]
    var body: some View {
        ZStack {
            ForEach(0..<runes.count, id: \.self) { i in
                let angle = Double(i) * (360.0 / Double(runes.count))
                Text(runes[i])
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "C8FF00"))
                    .shadow(color: Color(hex: "00FFD1"), radius: 4)
                    .offset(y: -130)
                    .rotationEffect(.degrees(angle))
            }
        }
        .rotationEffect(.degrees(isSwaying ? -360 : 0))
        .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: isSwaying)
        .opacity(0.9)
        .allowsHitTesting(false)
    }
}

struct StardustView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2, height: CGFloat.random(in: 4...12))
                    .opacity(animate ? 0.1 : 0.8)
                    .offset(
                        x: CGFloat.random(in: -100...100),
                        y: animate ? 150 : -100
                    )
                    .animation(
                        .linear(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: false)
                            .delay(Double.random(in: 0...2)),
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var level = 5
        @State private var isInjecting = false
        @State private var harvested: Set<Int> = []

        var body: some View {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()
                VStack(spacing: 24) {
                    BeautifulCoconutTree(
                        level: level,
                        isInjecting: isInjecting,
                        harvestedCoconuts: harvested,
                        onHarvest: { harvested.insert($0) }
                    )
                    .frame(height: 340)

                    Text("Lv.\(level) · 点击椰子采摘")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.6))

                    HStack(spacing: 16) {
                        Button("升级") {
                            if level < 10 { level += 1 }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.goLime, in: Capsule())
                        .foregroundStyle(.black)

                        Button("注入能量") {
                            isInjecting = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isInjecting = false
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.white.opacity(0.15), in: Capsule())
                        .foregroundStyle(.primary)

                        Button("重置椰子") { harvested = [] }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.white.opacity(0.15), in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .padding()
            }
        }
    }
    return PreviewWrapper()
}
