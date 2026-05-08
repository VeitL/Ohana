//
//  BeautifulCoconutTree.swift
//  Ohana
//
//  SwiftUI 精确翻译 React/Framer Motion 版椰子树
//  - 固定椰子坐标 + 呼吸发光 + 采摘交互
//  - 藤蔓 trim 生长动画（Lv5+）
//  - 升级冲击波特效
//  - 每级改变树干、树冠、花果和光效层级
//

import SwiftUI

// MARK: - 等级配置

struct TreeLevelConfig {
    let level: Int
    let name: String
    let scale: Double
    let leafCount: Int
    let coconutCount: Int
    let flowerCount: Int
    let trunkHeight: CGFloat
    let trunkWidth: CGFloat
    let leafWidth: CGFloat
    let leafHeight: CGFloat
    let crownOffset: CGFloat
    let auraTier: Int
    let rootCount: Int
}

private let treeLevelConfigs: [TreeLevelConfig] = [
    .init(level: 1,  name: "破土新芽", scale: 0.54, leafCount: 2,  coconutCount: 0,  flowerCount: 0,  trunkHeight: 54,  trunkWidth: 14, leafWidth: 50,  leafHeight: 34, crownOffset: 7,  auraTier: 0, rootCount: 0),
    .init(level: 2,  name: "稚嫩幼苗", scale: 0.60, leafCount: 4,  coconutCount: 0,  flowerCount: 0,  trunkHeight: 86,  trunkWidth: 16, leafWidth: 64,  leafHeight: 40, crownOffset: 5,  auraTier: 0, rootCount: 1),
    .init(level: 3,  name: "茁壮小树", scale: 0.68, leafCount: 6,  coconutCount: 0,  flowerCount: 3,  trunkHeight: 114, trunkWidth: 20, leafWidth: 76,  leafHeight: 48, crownOffset: 2,  auraTier: 0, rootCount: 2),
    .init(level: 4,  name: "青葱树冠", scale: 0.76, leafCount: 8,  coconutCount: 0,  flowerCount: 5,  trunkHeight: 136, trunkWidth: 23, leafWidth: 88,  leafHeight: 54, crownOffset: 0,  auraTier: 0, rootCount: 3),
    .init(level: 5,  name: "初结硕果", scale: 0.84, leafCount: 10, coconutCount: 1,  flowerCount: 6,  trunkHeight: 154, trunkWidth: 27, leafWidth: 98,  leafHeight: 60, crownOffset: -2, auraTier: 0, rootCount: 4),
    .init(level: 6,  name: "丰收之树", scale: 0.92, leafCount: 13, coconutCount: 3,  flowerCount: 8,  trunkHeight: 168, trunkWidth: 31, leafWidth: 108, leafHeight: 66, crownOffset: -4, auraTier: 1, rootCount: 5),
    .init(level: 7,  name: "绿洲明珠", scale: 1.00, leafCount: 16, coconutCount: 5,  flowerCount: 10, trunkHeight: 180, trunkWidth: 35, leafWidth: 118, leafHeight: 72, crownOffset: -6, auraTier: 1, rootCount: 6),
    .init(level: 8,  name: "繁星树冠", scale: 1.07, leafCount: 19, coconutCount: 7,  flowerCount: 12, trunkHeight: 190, trunkWidth: 39, leafWidth: 128, leafHeight: 78, crownOffset: -8, auraTier: 2, rootCount: 7),
    .init(level: 9,  name: "生命之源", scale: 1.14, leafCount: 21, coconutCount: 10, flowerCount: 15, trunkHeight: 198, trunkWidth: 43, leafWidth: 138, leafHeight: 84, crownOffset: -10, auraTier: 3, rootCount: 8),
    .init(level: 10, name: "永恒神树", scale: 1.20, leafCount: 22, coconutCount: 12, flowerCount: 18, trunkHeight: 206, trunkWidth: 47, leafWidth: 148, leafHeight: 90, crownOffset: -12, auraTier: 4, rootCount: 9),
]

// 椰子固定坐标（相对树冠中心）
private let cocoPositions: [(x: CGFloat, y: CGFloat)] = [
    (-25, 15), (25, 10), (0, 30),
    (-45, -5), (40, -15), (-15, 45),
    (15, 45), (-35, 25), (35, 25),
    (-58, 14), (58, 2), (0, -8)
]

private let blossomPositions: [(x: CGFloat, y: CGFloat)] = [
    (-48, -34), (48, -38), (-8, -58),
    (-66, -10), (66, -14), (-26, 18),
    (28, 18), (-82, 18), (82, 14),
    (-48, 42), (48, 40), (0, 50),
    (-96, -2), (96, -8), (-14, -80),
    (20, -78), (-72, 46), (74, 42)
]

private let maxLeafSlots = 22

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
    private var glowColor: Color { isMax ? Color(hex: "FBBF24") : Color.goPrimary }
    private var sproutCount: Int { max(1, min(level, 4)) }

    private var trunkH: CGFloat { cfg.trunkHeight }
    private var trunkW: CGFloat { cfg.trunkWidth }
    private var bend: CGFloat { CGFloat(12 + min(level, 9) * 3) }

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
                LevelUpBurstView(
                    progress: shockwaveScale,
                    opacity: shockwaveOpacity,
                    glowColor: glowColor
                )
                    .offset(x: bend + trunkW * 0.4,
                            y: -trunkH + cfg.crownOffset)
                    .allowsHitTesting(false)
            }

            // ── 底部光环与阴影（绿洲神池）
            if level >= 7 {
                Ellipse()
                    .fill(Color(hex: "0EA5E9").opacity(0.6))
                    .frame(width: max(CGFloat(130), trunkW * 6.2), height: trunkW * 2)
                    .blur(radius: 12)
                    .animation(GoMotion.hero, value: level)
            }

            Ellipse()
                .fill(isMax ? Color(hex: "0F172A") : Color(hex: "271A14"))
                .frame(width: max(CGFloat(72), trunkW * 5.2), height: max(CGFloat(18), trunkW * 1.45))
                .animation(GoMotion.hero, value: level)

            if cfg.rootCount > 0 {
                ZStack {
                    ForEach(0..<cfg.rootCount, id: \.self) { i in
                        let direction: CGFloat = i.isMultiple(of: 2) ? -1 : 1
                        Capsule()
                            .fill(isMax ? Color(hex: "334155") : Color(hex: "4A2B16"))
                            .frame(width: CGFloat(38 + i * 8), height: max(CGFloat(3), trunkW * 0.13))
                            .rotationEffect(.degrees(direction * Double(8 + i * 2)))
                            .offset(x: direction * CGFloat(8 + i * 4), y: CGFloat(i % 3) * 2)
                            .opacity(0.88)
                    }
                }
                .offset(x: bend * 0.18, y: 1)
                .allowsHitTesting(false)
            }

            if level <= 4 {
                ForEach(0..<sproutCount, id: \.self) { i in
                    GroundSproutView(color: leafColor(index: i))
                        .scaleEffect(0.58 + CGFloat(i) * 0.14)
                        .offset(
                            x: (CGFloat(i) - CGFloat(sproutCount - 1) / 2) * 36,
                            y: -3
                        )
                        .opacity(0.85)
                        .allowsHitTesting(false)
                }
            }

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
                .animation(GoMotion.hero, value: level)

            // ── 藤蔓（Lv5+，trim 生长动画）
            if level >= 5 {
                VineShape(trunkWidth: Double(trunkW), trunkHeight: Double(trunkH), bend: Double(bend))
                    .trim(from: 0, to: vineProgress)
                    .stroke(
                        Color(hex: "84CC16"),
                        style: StrokeStyle(lineWidth: max(CGFloat(3), trunkW * 0.11), lineCap: .round)
                    )
                    .frame(width: trunkW * 4 + bend + 40, height: trunkH + 10)
                    .shadow(color: Color(hex: "84CC16").opacity(0.6), radius: 4)
                    .opacity(0.8)
                    .animation(.easeOut(duration: 2.0), value: vineProgress)
            }

            // ── 神圣光环 (Divine Halo, Lv6+)
            if level >= 6 {
                DivineHaloView(
                    isSwaying: isSwaying,
                    tier: cfg.auraTier,
                    size: 184 + CGFloat(cfg.auraTier) * 30
                )
                    .offset(x: bend + trunkW * 0.4, y: -trunkH - 8)
            }

            // ── 树冠（树叶 + 椰子，摇摆）
            ZStack {
                // 后层树叶让高等级树冠更饱满
                if level >= 6 {
                    ForEach(0..<maxLeafSlots, id: \.self) { i in
                        let isActive = i < cfg.leafCount && i % 2 == 1
                        let angle: Double = cfg.leafCount > 1
                            ? -168 + Double(i) * (336.0 / Double(max(1, cfg.leafCount - 1)))
                            : -150
                        LeafShape()
                            .fill(leafColor(index: i + 1).opacity(0.72))
                            .frame(width: cfg.leafWidth * 0.72, height: cfg.leafHeight * 0.78)
                            .scaleEffect(isActive ? 1.0 : 0.001, anchor: .topLeading)
                            .rotationEffect(.degrees(angle + 9), anchor: .topLeading)
                            .offset(x: -6, y: 10)
                            .opacity(isActive ? 0.55 : 0)
                            .animation(
                                GoMotion.hero.delay(isActive ? Double(i) * 0.025 : 0),
                                value: cfg.leafCount
                            )
                            .allowsHitTesting(false)
                    }
                }

                // 树叶（扇形，originX/Y=0 对应 React style.origin）
                ForEach(0..<maxLeafSlots, id: \.self) { i in
                    let isActive = i < cfg.leafCount
                    let angle: Double = cfg.leafCount > 1
                        ? -160 + Double(i) * (320.0 / Double(max(1, cfg.leafCount - 1)))
                        : -150
                    LeafShape()
                        .fill(leafColor(index: i))
                        .frame(width: cfg.leafWidth, height: cfg.leafHeight)
                        .scaleEffect(isActive ? (isMax ? 1.08 : 1.0) : 0.001,
                                     anchor: .topLeading)
                        .rotationEffect(.degrees(angle), anchor: .topLeading)
                        .opacity(isActive ? 0.95 : 0)
                        .animation(
                            GoMotion.hero
                                .delay(isActive ? Double(i) * 0.05 : 0),
                            value: cfg.leafCount
                        )
                        .allowsHitTesting(false)
                }

                // 花朵/能量结晶，3 级后开始出现
                ForEach(0..<blossomPositions.count, id: \.self) { i in
                    if i < cfg.flowerCount {
                        let pos = blossomPositions[i]
                        let bloomScale = min(CGFloat(1.18), max(CGFloat(0.62), cfg.leafWidth / 120))
                        BlossomView(index: i, isMax: isMax)
                            .offset(x: pos.x * bloomScale, y: pos.y * bloomScale)
                            .scaleEffect(level >= 8 ? 1.0 : 0.82)
                            .transition(.scale.combined(with: .opacity))
                            .animation(
                                GoMotion.fab.delay(0.25 + Double(i) * 0.035),
                                value: cfg.flowerCount
                            )
                            .allowsHitTesting(false)
                    }
                }

                // 椰子（固定坐标）
                ForEach(0..<cocoPositions.count, id: \.self) { i in
                    if i < cfg.coconutCount {
                        let pos = cocoPositions[i]
                        let isHarvested = harvestedCoconuts.contains(i)
                        let positionScale = min(CGFloat(1.22), max(CGFloat(0.72), cfg.leafWidth / 108))
                        InteractiveCoconut(
                            index: i,
                            isMax: isMax,
                            isHarvested: isHarvested,
                            onTap: { onHarvest?(i) }
                        )
                        .offset(x: pos.x * positionScale, y: pos.y * positionScale)
                        .animation(
                            GoMotion.fab
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
                    y: -trunkH + cfg.crownOffset)
            // 持续摇摆
            .rotationEffect(.degrees(isSwaying ? 2 : -2), anchor: .bottom)
            .animation(
                .easeInOut(duration: 6).repeatForever(autoreverses: true),
                value: isSwaying
            )
            // 注入能量脉冲
            .scaleEffect(isInjecting ? 1.1 : 1.0)
            .animation(GoMotion.feedback, value: isInjecting)
        }
        // 整体 scale 随等级变化（React 源码 animate.scale）
        .scaleEffect(CGFloat(cfg.scale))
        .animation(GoMotion.hero, value: cfg.scale)
        .frame(width: 300, height: 348)
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
        withAnimation(.easeOut(duration: 1.35)) {
            shockwaveScale = 1
            shockwaveOpacity = 0
        }
    }
}

// MARK: - Upgrade / Growth Details

private struct LevelUpBurstView: View {
    let progress: CGFloat
    let opacity: Double
    let glowColor: Color

    private let sparkAngles: [Double] = [0, 24, 52, 82, 116, 148, 180, 214, 246, 278, 310, 336]

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        glowColor.opacity(0.82 - Double(i) * 0.18),
                        lineWidth: CGFloat(4 - i)
                    )
                    .frame(width: CGFloat(30 + i * 18), height: CGFloat(30 + i * 18))
                    .scaleEffect(1 + progress * CGFloat(5 + i * 3))
                    .opacity(opacity)
            }

            ForEach(0..<sparkAngles.count, id: \.self) { i in
                let radians = sparkAngles[i] * .pi / 180
                let distance = CGFloat(28 + (i % 4) * 7) + progress * CGFloat(96 + (i % 3) * 18)
                Capsule()
                    .fill(i.isMultiple(of: 2) ? glowColor : Color.goYellow)
                    .frame(width: 3, height: CGFloat(12 + (i % 3) * 5))
                    .rotationEffect(.degrees(sparkAngles[i] + 90))
                    .offset(
                        x: CGFloat(cos(radians)) * distance,
                        y: CGFloat(sin(radians)) * distance
                    )
                    .opacity(opacity)
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

private struct GroundSproutView: View {
    let color: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color(hex: "4A2B16"))
                .frame(width: 5, height: 24)
            LeafShape()
                .fill(color)
                .frame(width: 34, height: 20)
                .rotationEffect(.degrees(-34), anchor: .topLeading)
                .offset(x: -6, y: -13)
            LeafShape()
                .fill(color.opacity(0.82))
                .frame(width: 30, height: 18)
                .rotationEffect(.degrees(146), anchor: .topLeading)
                .offset(x: 8, y: -12)
        }
        .frame(width: 42, height: 34)
    }
}

private struct BlossomView: View {
    let index: Int
    let isMax: Bool

    private var petalColor: Color {
        if isMax { return index.isMultiple(of: 2) ? Color(hex: "FDE68A") : Color(hex: "67E8F9") }
        return index.isMultiple(of: 2) ? Color(hex: "F9A8D4") : Color(hex: "FDE68A")
    }

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(petalColor)
                    .frame(width: 5, height: 12)
                    .offset(y: -5)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(isMax ? Color.goPrimary : Color.goYellow)
                .frame(width: 5, height: 5)
        }
        .frame(width: 18, height: 18)
        .shadow(color: petalColor.opacity(isMax ? 0.75 : 0.35), radius: isMax ? 5 : 2)
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
                    .fill(Color.goPrimary)
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
    var tier: Int = 1
    var size: CGFloat = 240

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [Color(hex: "00FFD1"), Color(hex: "C8FF00"), Color(hex: "00FFD1")],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.5 + CGFloat(tier) * 0.25, dash: [6, 10])
                )
                .frame(width: size, height: size)

            if tier >= 2 {
                Circle()
                    .stroke(Color.goPrimary.opacity(0.32), lineWidth: 1)
                    .frame(width: size * 0.72, height: size * 0.72)
            }

            if tier >= 3 {
                Circle()
                    .stroke(Color.goYellow.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [2, 8]))
                    .frame(width: size * 1.18, height: size * 1.18)
            }

            if tier >= 4 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.goPrimary.opacity(0.18), Color.goYellow.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 8,
                            endRadius: size * 0.72
                        )
                    )
                    .frame(width: size * 1.28, height: size * 1.28)
            }
        }
        .rotationEffect(.degrees(isSwaying ? 360 : 0))
        .animation(.linear(duration: 25).repeatForever(autoreverses: false), value: isSwaying)
        .opacity(0.72 + min(Double(tier), 4) * 0.06)
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

    private let dust: [(x: CGFloat, h: CGFloat, startY: CGFloat, endY: CGFloat, duration: Double, delay: Double)] = [
        (-96, 8, -112, 138, 2.5, 0.0),
        (-70, 12, -96, 148, 3.4, 0.6),
        (-44, 6, -120, 132, 2.8, 1.2),
        (-18, 10, -88, 152, 3.8, 0.3),
        (8, 7, -132, 142, 2.6, 1.5),
        (32, 11, -104, 156, 3.2, 0.9),
        (58, 5, -118, 136, 2.7, 1.8),
        (82, 9, -92, 150, 3.7, 0.4),
        (104, 12, -126, 140, 3.0, 1.1),
        (-112, 7, -86, 154, 3.5, 1.6),
        (0, 13, -140, 126, 2.9, 0.8),
        (116, 6, -110, 146, 3.3, 2.0)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<dust.count, id: \.self) { i in
                let item = dust[i]
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2, height: item.h)
                    .opacity(animate ? 0.1 : 0.8)
                    .offset(
                        x: item.x,
                        y: animate ? item.endY : item.startY
                    )
                    .animation(
                        .linear(duration: item.duration)
                            .repeatForever(autoreverses: false)
                            .delay(item.delay),
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
                        .background(Color.goPrimary, in: Capsule())
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
