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
    .init(level: 0, name: "沉睡种子", scale: 1.24, leafCount: 0, coconutCount: 0, flowerCount: 0, trunkHeight: 28, trunkWidth: 9, leafWidth: 34, leafHeight: 24, crownOffset: 0, auraTier: 0, rootCount: 0),
    .init(level: 1, name: "破土新芽", scale: 1.28, leafCount: 2, coconutCount: 0, flowerCount: 0, trunkHeight: 92, trunkWidth: 13, leafWidth: 50, leafHeight: 34, crownOffset: 0, auraTier: 0, rootCount: 0),
    .init(level: 2, name: "稚嫩幼苗", scale: 1.20, leafCount: 4, coconutCount: 0, flowerCount: 0, trunkHeight: 112, trunkWidth: 16, leafWidth: 64, leafHeight: 40, crownOffset: -1, auraTier: 0, rootCount: 1),
    .init(level: 3, name: "茁壮小树", scale: 1.14, leafCount: 6, coconutCount: 0, flowerCount: 3, trunkHeight: 130, trunkWidth: 20, leafWidth: 76, leafHeight: 48, crownOffset: -2, auraTier: 0, rootCount: 2),
    .init(level: 4, name: "青葱树冠", scale: 1.11, leafCount: 8, coconutCount: 0, flowerCount: 5, trunkHeight: 144, trunkWidth: 23, leafWidth: 88, leafHeight: 54, crownOffset: -3, auraTier: 0, rootCount: 3),
    .init(level: 5, name: "初结硕果", scale: 1.09, leafCount: 10, coconutCount: 1, flowerCount: 6, trunkHeight: 158, trunkWidth: 27, leafWidth: 98, leafHeight: 60, crownOffset: -4, auraTier: 0, rootCount: 4),
    .init(level: 6, name: "丰收之树", scale: 1.08, leafCount: 13, coconutCount: 3, flowerCount: 8, trunkHeight: 170, trunkWidth: 31, leafWidth: 108, leafHeight: 66, crownOffset: -5, auraTier: 1, rootCount: 5),
    .init(level: 7, name: "绿洲明珠", scale: 1.07, leafCount: 16, coconutCount: 5, flowerCount: 10, trunkHeight: 182, trunkWidth: 35, leafWidth: 118, leafHeight: 72, crownOffset: -6, auraTier: 1, rootCount: 6),
    .init(level: 8, name: "繁星树冠", scale: 1.06, leafCount: 19, coconutCount: 7, flowerCount: 12, trunkHeight: 192, trunkWidth: 39, leafWidth: 128, leafHeight: 78, crownOffset: -8, auraTier: 2, rootCount: 7),
    .init(level: 9, name: "生命之源", scale: 1.055, leafCount: 21, coconutCount: 10, flowerCount: 15, trunkHeight: 200, trunkWidth: 43, leafWidth: 138, leafHeight: 84, crownOffset: -10, auraTier: 3, rootCount: 8),
    .init(level: 10, name: "永恒神树", scale: 1.05, leafCount: 22, coconutCount: 12, flowerCount: 18, trunkHeight: 208, trunkWidth: 47, leafWidth: 148, leafHeight: 90, crownOffset: -12, auraTier: 4, rootCount: 9)
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

private func treeLeafColor(index i: Int, isMax: Bool, level: Int) -> Color {
    if isMax { return i % 2 == 0 ? Color(hex: "00FFD1") : Color(hex: "0284C7") }
    if level >= 7 { return i % 2 == 0 ? Color(hex: "22C55E") : Color(hex: "15803D") }
    return i % 2 == 0 ? Color(hex: "84CC16") : Color(hex: "4D7C0F")
}

// MARK: - BeautifulCoconutTree

struct BeautifulCoconutTree: View {
    var level: Int // 0-10
    var isInjecting: Bool // 注入能量脉冲
    var growthProgress: Double = 0
    var injectionPulseToken: Int = 0
    var pendingUpgradeCoconutCount: Int = 0
    var dailyCoconutCount: Int?
    var allowsAmbientMotion: Bool = true
    var allowsInteractionMotion: Bool = true
    var usesLiquidGlassLeaves: Bool = true
    var harvestedCoconuts: Set<Int> = [] // 已采摘的椰子索引
    var onHarvest: ((Int) -> Void)? // 采摘回调

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var windPulseToken = 0
    @State private var entranceWindTask: Task<Void, Never>?
    @State private var isLiquidGlassPrepared = false
    @State private var liquidGlassPreparationTask: Task<Void, Never>?
    @State private var burstKey = 0 // 升级冲击波触发器
    @State private var shockwaveScale: CGFloat = 0
    @State private var shockwaveOpacity: Double = 0
    @State private var vineProgress: CGFloat = 0

    private var visualLevel: Int {
        max(0, min(level, 10))
    }

    private var cfg: TreeLevelConfig {
        treeLevelConfigs[visualLevel]
    }

    private var isMax: Bool { visualLevel >= 10 }
    private var glowColor: Color { isMax ? Color(hex: "FBBF24") : Color.goPrimary }
    private var sproutCount: Int { max(1, min(visualLevel, 4)) }
    private var displayedCoconutCount: Int {
        min(cfg.coconutCount, max(0, dailyCoconutCount ?? cfg.coconutCount))
    }

    private var trunkH: CGFloat { cfg.trunkHeight }
    private var trunkW: CGFloat { cfg.trunkWidth }
    private var bend: CGFloat { CGFloat(12 + min(visualLevel, 9) * 3) }
    private var canPlayWindMotion: Bool { allowsAmbientMotion && !reduceMotion }
    private var canPlayInteractionMotion: Bool { allowsInteractionMotion && !reduceMotion }
    private var rendersLiquidGlassLeaves: Bool { usesLiquidGlassLeaves && isLiquidGlassPrepared }

    static func coconutCapacity(for level: Int) -> Int {
        treeLevelConfigs[max(0, min(level, 10))].coconutCount
    }

    private func leafColor(index i: Int) -> Color {
        treeLeafColor(index: i, isMax: isMax, level: visualLevel)
    }

    var body: some View {
        GeometryReader { proxy in
            let fitScale = min(
                max(0, proxy.size.width) / 320,
                max(0, proxy.size.height) / 300
            )

            ZStack(alignment: .bottom) {

            // ── 背景光效（Sunbeams, Lv9+)
            if visualLevel >= 9 {
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
            if visualLevel >= 7 {
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

            if visualLevel == 0 {
                AwakeningSeedView(
                    glowColor: glowColor,
                    isInjecting: isInjecting
                )
            }

            TreeRootClusterView(
                rootCount: cfg.rootCount,
                trunkWidth: trunkW,
                bend: bend,
                isMax: isMax
            )

            EnergyRootPulseView(token: injectionPulseToken, color: glowColor, isActive: isInjecting)
                .offset(x: bend * 0.18, y: 2)
                .allowsHitTesting(false)

            if visualLevel >= 3, visualLevel <= 4 {
                ForEach(0 ..< sproutCount, id: \.self) { i in
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
                .opacity(visualLevel == 0 ? 0 : 1)
                .animation(GoMotion.hero, value: level)

            // ── 藤蔓（Lv5+，trim 生长动画）
            if visualLevel >= 5 {
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
            if visualLevel >= 6 {
                DivineHaloView(
                    isSwaying: false,
                    tier: cfg.auraTier,
                    size: 184 + CGFloat(cfg.auraTier) * 30,
                    allowsAmbientMotion: allowsAmbientMotion
                )
                .offset(x: bend + trunkW * 0.4, y: -trunkH - 8)
            }

            // ── 树冠（树叶 + 椰子，摇摆）
            OasisLeafGlassContainer(isEnabled: rendersLiquidGlassLeaves) {
                ZStack {
                // 后层整叶让高等级树冠更饱满，同时保持原来的扇形轮廓。
                if visualLevel >= 6 {
                    ForEach(0 ..< maxLeafSlots, id: \.self) { i in
                        let isActive = i < cfg.leafCount && i % 2 == 1
                        let angle: Double = cfg.leafCount > 1
                            ? -168 + Double(i) * (336.0 / Double(max(1, cfg.leafCount - 1)))
                            : -150
                        OasisPalmLeaf(
                            tint: leafColor(index: i + 1),
                            width: cfg.leafWidth * 0.72,
                            height: cfg.leafHeight * 0.78,
                            isBackLayer: true,
                            usesLiquidGlass: rendersLiquidGlassLeaves
                        )
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

                // 前层恢复原有的弧形整叶扇冠。
                ForEach(0 ..< maxLeafSlots, id: \.self) { i in
                    let isActive = i < cfg.leafCount
                    let angle: Double = cfg.leafCount > 1
                        ? -160 + Double(i) * (320.0 / Double(max(1, cfg.leafCount - 1)))
                        : -140
                    OasisPalmLeaf(
                        tint: leafColor(index: i),
                        width: cfg.leafWidth,
                        height: cfg.leafHeight,
                        usesLiquidGlass: rendersLiquidGlassLeaves
                    )
                    .scaleEffect(isActive ? (isMax ? 1.08 : 1.0) : 0.001, anchor: .topLeading)
                    .rotationEffect(.degrees(angle), anchor: .topLeading)
                    .opacity(isActive ? 0.95 : 0)
                    .animation(
                        GoMotion.hero.delay(isActive ? Double(i) * 0.05 : 0),
                        value: cfg.leafCount
                    )
                    .allowsHitTesting(false)
                }

                // 花朵/能量结晶，3 级后开始出现
                ForEach(0 ..< blossomPositions.count, id: \.self) { i in
                    if i < cfg.flowerCount {
                        let pos = blossomPositions[i]
                        let bloomScale = min(CGFloat(1.18), max(CGFloat(0.62), cfg.leafWidth / 120))
                        BlossomView(index: i, isMax: isMax)
                            .offset(x: pos.x * bloomScale, y: pos.y * bloomScale)
                            .scaleEffect(visualLevel >= 8 ? 1.0 : 0.82)
                            .transition(.scale.combined(with: .opacity))
                            .animation(
                                GoMotion.fab.delay(0.25 + Double(i) * 0.035),
                                value: cfg.flowerCount
                            )
                            .allowsHitTesting(false)
                    }
                }

                // 椰子（固定坐标）
                ForEach(0 ..< cocoPositions.count, id: \.self) { i in
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
                    RunesView(isSwaying: false, allowsAmbientMotion: allowsAmbientMotion)
                }

                // ── 星尘 (Stardust, Lv8+)
                if visualLevel >= 8 {
                    StardustView(allowsAmbientMotion: allowsAmbientMotion)
                }
                }
            }
            // 树冠对齐树干顶端（对应 React animate.x/y）
            .offset(x: bend + trunkW * 0.4,
                    y: -trunkH + cfg.crownOffset)
            // A finite gust runs when Oasis becomes visible or energy arrives.
            // This avoids keeping a repeating animation alive while the tab sits open.
            .phaseAnimator(OasisTreeWindPhase.allCases, trigger: windPulseToken) { crown, phase in
                crown
                    .rotationEffect(.degrees(canPlayWindMotion || canPlayInteractionMotion ? phase.angle : 0), anchor: .bottom)
                    .offset(x: canPlayWindMotion || canPlayInteractionMotion ? phase.xOffset : 0)
            } animation: { phase in
                phase.animation
            }
            }
            .frame(width: 320, height: 300)
            .scaleEffect(fitScale * CGFloat(cfg.scale), anchor: .bottom)
            .phaseAnimator(OasisTreeChargePhase.allCases, trigger: injectionPulseToken) { tree, phase in
                tree
                    .scaleEffect(canPlayInteractionMotion ? phase.scale : 1, anchor: .bottom)
                    .offset(y: canPlayInteractionMotion ? phase.yOffset : 0)
                    .brightness(phase.brightness)
                    .shadow( // ui-v4: allow finite, interaction-triggered Oasis tree charge glow
                        color: glowColor.opacity(phase.glowOpacity),
                        radius: phase == .surges ? 18 : 8,
                        x: 0,
                        y: 0
                    )
            } animation: { phase in
                canPlayInteractionMotion ? phase.animation : GoMotion.reduced
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .animation(GoMotion.hero, value: cfg.scale)
        .onAppear {
            scheduleLiquidGlassPreparation()
            scheduleEntranceWind()
            if visualLevel >= 5 {
                if canPlayWindMotion {
                    OhanaFrameScheduler.runAfterNextFrame(milliseconds: 300) {
                        vineProgress = 1.0
                    }
                } else {
                    vineProgress = 1.0
                }
            }
        }
        .onChange(of: allowsAmbientMotion) { _, shouldAnimate in
            if shouldAnimate {
                scheduleEntranceWind()
            } else {
                entranceWindTask?.cancel()
                entranceWindTask = nil
            }
            if !canPlayWindMotion, visualLevel >= 5 {
                vineProgress = 1.0
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            if shouldReduceMotion {
                entranceWindTask?.cancel()
                entranceWindTask = nil
            } else {
                scheduleEntranceWind()
            }
        }
        .onChange(of: usesLiquidGlassLeaves) { _, shouldUseGlass in
            if shouldUseGlass {
                scheduleLiquidGlassPreparation()
            } else {
                liquidGlassPreparationTask?.cancel()
                liquidGlassPreparationTask = nil
                isLiquidGlassPrepared = false
            }
        }
        .onChange(of: injectionPulseToken) { oldToken, newToken in
            guard newToken != oldToken, canPlayInteractionMotion else { return }
            windPulseToken &+= 1
        }
        .onChange(of: level) { oldVal, newVal in
            if newVal > oldVal { triggerShockwave() }
            // 新等级达到 5+ 时重新生长藤蔓
            if newVal >= 5, oldVal < 5 {
                if canPlayWindMotion {
                    vineProgress = 0
                    OhanaFrameScheduler.runAfterNextFrame(milliseconds: 500) {
                        vineProgress = 1.0
                    }
                } else {
                    vineProgress = 1.0
                }
            }
        }
        .onDisappear {
            entranceWindTask?.cancel()
            entranceWindTask = nil
            liquidGlassPreparationTask?.cancel()
            liquidGlassPreparationTask = nil
            isLiquidGlassPrepared = false
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

    private func scheduleEntranceWind() {
        guard canPlayWindMotion else { return }
        entranceWindTask?.cancel()
        entranceWindTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
            windPulseToken &+= 1
            entranceWindTask = nil
        }
    }

    private func scheduleLiquidGlassPreparation() {
        guard usesLiquidGlassLeaves, !isLiquidGlassPrepared else { return }
        liquidGlassPreparationTask?.cancel()
        liquidGlassPreparationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            isLiquidGlassPrepared = true
            liquidGlassPreparationTask = nil
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

    private static let sparkSpecs: [LevelUpSparkSpec] = [
        .init(index: 0, angle: 0),
        .init(index: 1, angle: 24),
        .init(index: 2, angle: 52),
        .init(index: 3, angle: 82),
        .init(index: 4, angle: 116),
        .init(index: 5, angle: 148),
        .init(index: 6, angle: 180),
        .init(index: 7, angle: 214),
        .init(index: 8, angle: 246),
        .init(index: 9, angle: 278),
        .init(index: 10, angle: 310),
        .init(index: 11, angle: 336)
    ]

    var body: some View {
        ZStack {
            ForEach(0 ..< 3, id: \.self) { i in
                LevelUpBurstRing(
                    index: i,
                    progress: progress,
                    opacity: opacity,
                    glowColor: glowColor
                )
            }

            ForEach(Self.sparkSpecs) { spec in
                LevelUpSparkView(
                    spec: spec,
                    progress: progress,
                    opacity: opacity,
                    glowColor: glowColor
                )
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

private struct TreeRootClusterView: View {
    let rootCount: Int
    let trunkWidth: CGFloat
    let bend: CGFloat
    let isMax: Bool

    var body: some View {
        if rootCount > 0 {
            ZStack {
                ForEach(0 ..< rootCount, id: \.self) { index in
                    TreeRootSegment(index: index, trunkWidth: trunkWidth, isMax: isMax)
                }
            }
            .offset(x: bend * 0.18, y: 1)
            .allowsHitTesting(false)
        }
    }
}

private struct TreeRootSegment: View {
    let index: Int
    let trunkWidth: CGFloat
    let isMax: Bool

    private var direction: CGFloat {
        index.isMultiple(of: 2) ? -1 : 1
    }

    private var fill: Color {
        isMax ? Color(hex: "334155") : Color(hex: "4A2B16")
    }

    private var segmentWidth: CGFloat {
        CGFloat(38 + index * 8)
    }

    private var segmentHeight: CGFloat {
        max(CGFloat(3), trunkWidth * 0.13)
    }

    private var rotation: Angle {
        .degrees(direction * Double(8 + index * 2))
    }

    private var segmentOffset: CGSize {
        CGSize(
            width: direction * CGFloat(8 + index * 4),
            height: CGFloat(index % 3) * 2
        )
    }

    var body: some View {
        Capsule()
            .fill(fill)
            .frame(width: segmentWidth, height: segmentHeight)
            .rotationEffect(rotation)
            .offset(segmentOffset)
            .opacity(0.88)
    }
}

private struct LevelUpSparkSpec: Identifiable {
    let id: Int
    let angle: Double
    let radians: CGFloat
    let baseDistance: CGFloat
    let progressDistance: CGFloat
    let height: CGFloat
    let usesGlowColor: Bool

    init(index: Int, angle: Double) {
        self.id = index
        self.angle = angle
        self.radians = CGFloat(angle * .pi / 180)
        self.baseDistance = CGFloat(28 + (index % 4) * 7)
        self.progressDistance = CGFloat(96 + (index % 3) * 18)
        self.height = CGFloat(12 + (index % 3) * 5)
        self.usesGlowColor = index.isMultiple(of: 2)
    }
}

private struct LevelUpBurstRing: View {
    let index: Int
    let progress: CGFloat
    let opacity: Double
    let glowColor: Color

    private var diameter: CGFloat {
        CGFloat(30 + index * 18)
    }

    private var lineWidth: CGFloat {
        CGFloat(4 - index)
    }

    private var ringOpacity: Double {
        0.82 - Double(index) * 0.18
    }

    private var scale: CGFloat {
        1 + progress * CGFloat(5 + index * 3)
    }

    var body: some View {
        Circle()
            .stroke(glowColor.opacity(ringOpacity), lineWidth: lineWidth)
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

private struct LevelUpSparkView: View {
    let spec: LevelUpSparkSpec
    let progress: CGFloat
    let opacity: Double
    let glowColor: Color

    private var distance: CGFloat {
        spec.baseDistance + progress * spec.progressDistance
    }

    private var sparkColor: Color {
        spec.usesGlowColor ? glowColor : Color.goYellow
    }

    private var sparkOffset: CGSize {
        CGSize(
            width: cos(spec.radians) * distance,
            height: sin(spec.radians) * distance
        )
    }

    var body: some View {
        Capsule()
            .fill(sparkColor)
            .frame(width: 3, height: spec.height)
            .rotationEffect(.degrees(spec.angle + 90))
            .offset(sparkOffset)
            .opacity(opacity)
    }
}

private struct EnergyRootPulseView: View {
    let token: Int
    let color: Color
    let isActive: Bool

    @State private var scale: CGFloat = 0.64
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.94), lineWidth: 3)
                .frame(width: 54, height: 54)
                .scaleEffect(scale)
                .opacity(opacity)
            Circle()
                .stroke(Color.goTeal.opacity(0.72), lineWidth: 1.4)
                .frame(width: 38, height: 38) // a11y: allow decorative transient root pulse ring
                .scaleEffect(scale * 0.92)
                .opacity(opacity * 0.86)
            Circle()
                .fill(color.opacity(0.24))
                .frame(width: 32, height: 32) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                .scaleEffect(scale * 0.84)
                .opacity(opacity)
        }
        .blendMode(.screen)
        .onAppear {
            if isActive { run() }
        }
        .onChange(of: token) { _, _ in
            run()
        }
    }

    private func run() {
        scale = 0.64
        opacity = 1
        withAnimation(GoMotion.zenCardColorReveal) {
            scale = 3.0
            opacity = 0
        }
    }
}

private struct PendingUpgradeCoconutHint: View {
    let count: Int

    var body: some View {
        HStack(spacing: -7) {
            ForEach(0 ..< min(count, 3), id: \.self) { index in
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

private struct AwakeningSeedView: View {
    let glowColor: Color
    let isInjecting: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(glowColor.opacity(isInjecting ? 0.26 : 0.10))
                .frame(width: 72, height: 72)
                .blur(radius: 12)
                .offset(y: -8)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "A76B35"), Color(hex: "6B3D20"), Color(hex: "3D2416")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 52)
                .rotationEffect(.degrees(9))
                .offset(y: -7)
                .overlay {
                    SeedCrackShape()
                        .stroke(Color(hex: "E7BE79").opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 17, height: 24) // a11y: allow decorative seed crack; non-interactive and hidden with its parent illustration
                        .rotationEffect(.degrees(9))
                        .offset(x: 2, y: -10)
                }

            Capsule()
                .fill(Color(hex: "2A160F").opacity(0.72))
                .frame(width: 58, height: 11)
        }
        .frame(width: 86, height: 74)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SeedCrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.22, y: rect.height * 0.34))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.08, y: rect.maxY))
        return path
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
            ForEach(0 ..< 5, id: \.self) { i in
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
