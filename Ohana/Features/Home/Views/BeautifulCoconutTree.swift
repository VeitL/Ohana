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
    var growthProgress: Double = 0
    var injectionPulseToken: Int = 0
    var pendingUpgradeCoconutCount: Int = 0
    var dailyCoconutCount: Int? = nil
    var allowsAmbientMotion: Bool = true
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
    private var displayedCoconutCount: Int {
        min(cfg.coconutCount, max(0, dailyCoconutCount ?? cfg.coconutCount))
    }

    private var trunkH: CGFloat { cfg.trunkHeight }
    private var trunkW: CGFloat { cfg.trunkWidth }
    private var bend: CGFloat { CGFloat(12 + min(level, 9) * 3) }

    static func coconutCapacity(for level: Int) -> Int {
        treeLevelConfigs[max(0, min(level - 1, 9))].coconutCount
    }

    private func leafColor(index i: Int) -> Color {
        if isMax { return i % 2 == 0 ? Color(hex: "00FFD1") : Color(hex: "0284C7") }
        if level >= 7 { return i % 2 == 0 ? Color(hex: "22C55E") : Color(hex: "15803D") }
        return i % 2 == 0 ? Color(hex: "84CC16") : Color(hex: "4D7C0F")
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── 背景光效（Sunbeams, Lv9+)
            if level >= 9 {
                SunbeamsView(allowsAmbientMotion: allowsAmbientMotion)
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

            EnergyRootPulseView(token: injectionPulseToken, color: glowColor, isActive: isInjecting)
                .offset(x: bend * 0.18, y: 2)
                .allowsHitTesting(false)

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
                    .shadow(color: Color(hex: "84CC16").opacity(0.6), radius: 4) // ui-v4: allow tree illustration vine glow
                    .opacity(0.8)
                    .animation(GoMotion.hero, value: vineProgress)
            }

            // ── 神圣光环 (Divine Halo, Lv6+)
            if level >= 6 {
                DivineHaloView(
                    isSwaying: isSwaying,
                    tier: cfg.auraTier,
                    size: 184 + CGFloat(cfg.auraTier) * 30,
                    allowsAmbientMotion: allowsAmbientMotion
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
                    if i < displayedCoconutCount {
                        let pos = cocoPositions[i]
                        let isHarvested = harvestedCoconuts.contains(i)
                        let positionScale = min(CGFloat(1.22), max(CGFloat(0.72), cfg.leafWidth / 108))
                        InteractiveCoconut(
                            index: i,
                            isMax: isMax,
                            isHarvested: isHarvested,
                            allowsAmbientMotion: allowsAmbientMotion,
                            onTap: { onHarvest?(i) }
                        )
                        .offset(x: pos.x * positionScale, y: pos.y * positionScale)
                        .animation(
                            GoMotion.fab
                                .delay(0.5 + Double(i) * 0.1),
                            value: displayedCoconutCount
                        )
                    }
                }

                // ── 符文 (Runes, Lv10)
                if isMax {
                    RunesView(isSwaying: isSwaying, allowsAmbientMotion: allowsAmbientMotion)
                }

                // ── 星尘 (Stardust, Lv8+)
                if level >= 8 {
                    StardustView(allowsAmbientMotion: allowsAmbientMotion)
                }
            }
            // 树冠对齐树干顶端（对应 React animate.x/y）
            .offset(x: bend + trunkW * 0.4,
                    y: -trunkH + cfg.crownOffset)
            // 持续摇摆
            .rotationEffect(.degrees(isSwaying ? 2 : -2), anchor: .bottom)
            .animation(
                allowsAmbientMotion
                    ? .easeInOut(duration: 6).repeatForever(autoreverses: true) // runtime-guardrail: allow AppWorkloadPolicy-gated tree sway // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                    : nil,
                value: isSwaying
            )
        }
        // 整体 scale 随等级变化（React 源码 animate.scale）
        .scaleEffect(CGFloat(cfg.scale))
        .animation(GoMotion.hero, value: cfg.scale)
        .frame(width: 300, height: 348)
        .onAppear {
            isSwaying = true
            if level >= 5 {
                OhanaFrameScheduler.runAfterNextFrame(milliseconds: 300) {
                    vineProgress = 1.0
                }
            }
            isSwaying = allowsAmbientMotion
        }
        .onChange(of: allowsAmbientMotion) { _, shouldAnimate in
            isSwaying = shouldAnimate
        }
        .onChange(of: level) { oldVal, newVal in
            if newVal > oldVal { triggerShockwave() }
            // 新等级达到 5+ 时重新生长藤蔓
            if newVal >= 5 && oldVal < 5 {
                vineProgress = 0
                OhanaFrameScheduler.runAfterNextFrame(milliseconds: 500) {
                    vineProgress = 1.0
                }
            }
        }
        .overlay(alignment: .bottom) {
            if pendingUpgradeCoconutCount > 0 {
                PendingUpgradeCoconutHint(count: pendingUpgradeCoconutCount)
                    .offset(x: -86, y: -18)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 升级冲击波
    private func triggerShockwave() {
        burstKey += 1
        shockwaveScale = 0
        shockwaveOpacity = 1
        withAnimation(GoMotion.hero) {
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

private struct EnergyRootPulseView: View {
    let token: Int
    let color: Color
    let isActive: Bool

    @State private var scale: CGFloat = 0.72
    @State private var opacity: Double = 0.9

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.9), lineWidth: 3)
                .frame(width: 44, height: 44)
                .scaleEffect(scale)
                .opacity(isActive ? opacity : 0)
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 36, height: 36) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                .scaleEffect(scale * 0.84)
                .opacity(isActive ? opacity : 0)
        }
        .blendMode(.screen)
        .onAppear {
            if isActive { run() }
        }
        .onChange(of: token) { _, _ in
            if isActive { run() }
        }
    }

    private func run() {
        scale = 0.72
        opacity = 0.9
        withAnimation(GoMotion.stateChange) {
            scale = 2.4
            opacity = 0
        }
    }
}

private struct PendingUpgradeCoconutHint: View {
    let count: Int

    var body: some View {
        HStack(spacing: -7) {
            ForEach(0..<min(count, 3), id: \.self) { index in
                Text("🥥")
                    .font(OhanaFont.adaptive(size: 17))
                    .frame(width: 25, height: 25) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .background(Color.goPrimary.opacity(0.16), in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if index == 0 {
                            Circle()
                                .fill(Color.goPrimary)
                                .frame(width: 7, height: 7) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                        }
                    }
            }
            if count > 3 {
                Text("+\(count - 3)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 25, height: 25) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .background(Color.goPrimary, in: Circle())
                    .padding(.leading, 4)
            }
        }
    }
}

private struct GroundSproutView: View {
    let color: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color(hex: "4A2B16"))
                .frame(width: 5, height: 24) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
            LeafShape()
                .fill(color)
                .frame(width: 34, height: 20) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                .rotationEffect(.degrees(-34), anchor: .topLeading)
                .offset(x: -6, y: -13)
            LeafShape()
                .fill(color.opacity(0.82))
                .frame(width: 30, height: 18) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                .rotationEffect(.degrees(146), anchor: .topLeading)
                .offset(x: 8, y: -12)
        }
        .frame(width: 42, height: 34) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
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
                    .frame(width: 5, height: 12) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .offset(y: -5)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(isMax ? Color.goPrimary : Color.goYellow)
                .frame(width: 5, height: 5) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
        }
        .frame(width: 18, height: 18) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
        .shadow(color: petalColor.opacity(isMax ? 0.75 : 0.35), radius: isMax ? 5 : 2) // ui-v4: allow tree blossom glow
    }
}

// MARK: - InteractiveCoconut（含呼吸发光 + 采摘动画）

private struct InteractiveCoconut: View {
    let index: Int
    let isMax: Bool
    let isHarvested: Bool
    let allowsAmbientMotion: Bool
    let onTap: () -> Void

    @State private var breatheScale: CGFloat = 0.8
    @State private var breatheOpacity: Double = 0
    @State private var isLocallyHarvested = false

    private var visuallyHarvested: Bool {
        isHarvested || isLocallyHarvested
    }

    var body: some View {
        ZStack {
            // 呼吸发光
            if !visuallyHarvested {
                Circle()
                    .fill(Color.goPrimary)
                    .frame(width: 32, height: 32) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .scaleEffect(breatheScale)
                    .opacity(breatheOpacity)
                    .blur(radius: 4)
                    .allowsHitTesting(false)
                    .onAppear {
                        updateBreathing()
                    }
                    .onChange(of: allowsAmbientMotion) { _, _ in updateBreathing() }
            }

            // 椰子本体
            CoconutView(isMax: isMax)
                .scaleEffect(visuallyHarvested ? 0.72 : 1.0)
                .offset(y: visuallyHarvested ? -28 : 0)
                .opacity(visuallyHarvested ? 0 : 1)
                .animation(
                    GoMotion.feedback,
                    value: visuallyHarvested
                )
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .allowsHitTesting(!visuallyHarvested)
        .onTapGesture {
            guard !visuallyHarvested else { return }
            withAnimation(GoMotion.feedback) {
                isLocallyHarvested = true
            }
            onTap()
        }
        .onChange(of: isHarvested) { _, isHarvested in
            if !isHarvested {
                isLocallyHarvested = false
            }
        }
    }

    private func updateBreathing() {
        if allowsAmbientMotion {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { // ui-v4: allow AppWorkloadPolicy-gated coconut affordance; runtime-guardrail: allow AppWorkloadPolicy-gated coconut affordance // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                breatheScale = 1.4
                breatheOpacity = 0.5
            }
        } else {
            breatheScale = 1.0
            breatheOpacity = 0.18
        }
    }
}
