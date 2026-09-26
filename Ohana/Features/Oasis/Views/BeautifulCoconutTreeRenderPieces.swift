//
//  BeautifulCoconutTreeRenderPieces.swift
//  Ohana
//
//  Reusable render pieces for the interactive coconut tree.
//

import SwiftUI

struct TrunkShape: Shape {
    var trunkWidth: Double
    var trunkHeight: Double
    var bend: Double

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(trunkWidth, AnimatablePair(trunkHeight, bend)) }
        set {
            trunkWidth = newValue.first
            trunkHeight = newValue.second.first
            bend = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let by = rect.maxY
        let w = trunkWidth
        let h = trunkHeight
        let b = bend

        path.move(to: CGPoint(x: cx - w / 2, y: by))
        path.addQuadCurve(
            to: CGPoint(x: cx + b, y: by - h),
            control: CGPoint(x: cx + b / 2, y: by - h / 2)
        )
        path.addLine(to: CGPoint(x: cx + b + w * 0.4, y: by - h))
        path.addQuadCurve(
            to: CGPoint(x: cx + w / 2, y: by),
            control: CGPoint(x: cx + b / 2 + w, y: by - h / 2)
        )
        path.closeSubpath()
        return path
    }
}

struct VineShape: Shape {
    var trunkWidth: Double
    var trunkHeight: Double
    var bend: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let by = rect.maxY
        let w = trunkWidth
        let h = trunkHeight
        let b = bend

        path.move(to: CGPoint(x: cx - w / 2, y: by))
        path.addQuadCurve(
            to: CGPoint(x: cx + b - 10, y: by - h * 0.6),
            control: CGPoint(x: cx + b, y: by - h * 0.3)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx + b + 10, y: by - h * 0.9),
            control: CGPoint(x: cx + b - 20, y: by - h * 0.75)
        )
        return path
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100.0
        let sy = rect.height / 60.0
        let ox = rect.minX
        let oy = rect.midY

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * sx, y: oy + y * sy)
        }

        var path = Path()
        path.move(to: pt(0, 0))
        path.addCurve(to: pt(100, 20), control1: pt(30, -40), control2: pt(80, -20))
        path.addCurve(to: pt(0, 0), control1: pt(60, 0), control2: pt(30, -10))
        path.closeSubpath()
        return path
    }
}

/// Keeps the native refraction passes for a mature crown in one compositor
/// group. The illustration still falls back to the same tinted leaf artwork
/// when visual effects or Reduce Transparency disable Liquid Glass.
struct OasisLeafGlassContainer<Content: View>: View {
    let isEnabled: Bool
    private let content: Content

    init(isEnabled: Bool, @ViewBuilder content: () -> Content) {
        self.isEnabled = isEnabled
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *), isEnabled {
            GlassEffectContainer(spacing: 10) {
                content
            }
        } else {
            content
        }
    }
}

/// The original curved palm leaf with a restrained native Liquid Glass lens.
/// The glass layer is decorative, so it never competes with the stage CTA.
struct OasisPalmLeaf: View {
    let tint: Color
    let width: CGFloat
    let height: CGFloat
    var isBackLayer = false
    var usesLiquidGlass = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if #available(iOS 26.0, *), usesLiquidGlass, !reduceTransparency {
            leafArtwork
                .shadow(color: Color.white.opacity(isBackLayer ? 0.06 : 0.16), radius: 3, x: -1, y: -1) // ui-v4: allow leaf specular edge
                .glassEffect(
                    .regular
                        .tint(tint.opacity(isBackLayer ? 0.14 : 0.24))
                        .interactive(false),
                    in: LeafShape()
                )
        } else {
            leafArtwork
        }
    }

    private var leafArtwork: some View {
        LeafShape()
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(isBackLayer ? 0.62 : 0.96),
                        tint.opacity(isBackLayer ? 0.42 : 0.76)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                LeafShape()
                    .stroke(
                        Color.white.opacity(isBackLayer ? 0.05 : 0.14), // ui-v4: allow leaf illustration specular edge
                        lineWidth: isBackLayer ? 0.6 : 0.9
                    )
            }
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

enum OasisTreeWindPhase: CaseIterable {
    case resting
    case catchesWind
    case rebounds
    case settles

    var angle: Double {
        switch self {
        case .resting: 0
        case .catchesWind: 3.8
        case .rebounds: -2.1
        case .settles: 0
        }
    }

    var xOffset: CGFloat {
        switch self {
        case .resting: 0
        case .catchesWind: 4
        case .rebounds: -2
        case .settles: 0
        }
    }

    var animation: Animation {
        switch self {
        case .resting: GoMotion.quick
        case .catchesWind: GoMotion.heroExpand
        case .rebounds: GoMotion.page
        case .settles: GoMotion.heroCollapse
        }
    }
}

enum OasisTreeChargePhase: CaseIterable {
    case resting
    case gathers
    case surges
    case settles

    var scale: CGFloat {
        switch self {
        case .resting: 1
        case .gathers: 0.985
        case .surges: 1.052
        case .settles: 1
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .resting: 0
        case .gathers: 2
        case .surges: -5
        case .settles: 0
        }
    }

    var brightness: Double {
        switch self {
        case .resting: 0
        case .gathers: 0.05
        case .surges: 0.22
        case .settles: 0
        }
    }

    var glowOpacity: Double {
        switch self {
        case .resting: 0
        case .gathers: 0.22
        case .surges: 0.58
        case .settles: 0
        }
    }

    var animation: Animation {
        switch self {
        case .resting: GoMotion.quick
        case .gathers: GoMotion.quick
        case .surges: GoMotion.zenCardColorReveal
        case .settles: GoMotion.stateChange
        }
    }
}

private enum OasisEnergyPulsePhase: CaseIterable {
    case resting
    case gathers
    case travels
    case settles

    var flarePosition: CGFloat {
        switch self {
        case .resting, .gathers: 0.04
        case .travels: 0.92
        case .settles: 1
        }
    }

    var flareOpacity: Double {
        switch self {
        case .resting: 0
        case .gathers: 0.76
        case .travels: 1
        case .settles: 0
        }
    }

    var glowOpacity: Double {
        switch self {
        case .resting: 0.12
        case .gathers: 0.52
        case .travels: 0.82
        case .settles: 0.18
        }
    }

    var animation: Animation {
        switch self {
        case .resting: GoMotion.quick
        case .gathers: GoMotion.quick
        case .travels: GoMotion.zenCardColorReveal
        case .settles: GoMotion.stateChange
        }
    }
}

/// Shared by the live and snapshot-only Oasis stages so energy gain reads as
/// one clear, smooth event instead of a tiny width jump.
struct OasisEnergyProgressBar: View {
    let progress: Double
    let pulseToken: Int
    let allowsMotion: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var safeProgress: CGFloat {
        CGFloat(min(max(progress.isFinite ? progress : 0, 0), 1))
    }

    @ViewBuilder
    var body: some View {
        if allowsMotion, !reduceMotion {
            rail(phase: .resting)
                .phaseAnimator(OasisEnergyPulsePhase.allCases, trigger: pulseToken) { _, phase in
                    rail(phase: phase)
                } animation: { phase in
                    phase.animation
                }
        } else {
            rail(phase: .resting)
                .animation(GoMotion.reduced, value: safeProgress)
        }
    }

    private func rail(phase: OasisEnergyPulsePhase) -> some View {
        GeometryReader { proxy in
            let trackWidth = max(0, proxy.size.width)
            let rawFillWidth = trackWidth * safeProgress
            let fillWidth = safeProgress > 0 ? min(trackWidth, max(12, rawFillWidth)) : 0
            let flareTravel = max(0, fillWidth - 18)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.ohanaControlFill.opacity(colorScheme == .dark ? 0.92 : 0.72))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.ohanaGlassStroke.opacity(0.26), lineWidth: 0.7)
                    }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.goPrimary, Color.goTeal, Color(hex: "5EEAD4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.38 : 0.52)) // ui-v4: allow energy rail specular highlight
                            .frame(height: 3)
                            .padding(.horizontal, 3)
                            .padding(.top, 1.5)
                    }
                    .shadow( // ui-v4: allow finite, interaction-triggered Oasis energy glow
                        color: Color.goTeal.opacity(phase.glowOpacity),
                        radius: phase == .travels ? 9 : 5,
                        x: 0,
                        y: 0
                    )
                    .animation(GoMotion.heroExpand, value: safeProgress)

                Circle()
                    .fill(Color.white) // ui-v4: allow transient energy flare core
                    .frame(width: 18, height: 18) // a11y: allow decorative transient energy flare
                    .blur(radius: 2.2)
                    .blendMode(.screen)
                    .offset(x: flareTravel * phase.flarePosition)
                    .opacity(fillWidth > 0 ? phase.flareOpacity : 0)
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

private enum OasisEnergySurgePhase: CaseIterable {
    case resting
    case gathers
    case rises
    case dissolves

    var height: CGFloat {
        switch self {
        case .resting: 34
        case .gathers: 72
        case .rises: 206
        case .dissolves: 242
        }
    }

    var width: CGFloat {
        switch self {
        case .resting: 3
        case .gathers: 8
        case .rises: 12
        case .dissolves: 5
        }
    }

    var opacity: Double {
        switch self {
        case .resting: 0
        case .gathers: 0.68
        case .rises: 0.96
        case .dissolves: 0
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .resting: -20
        case .gathers: -34
        case .rises: -112
        case .dissolves: -152
        }
    }

    var animation: Animation {
        switch self {
        case .resting: GoMotion.quick
        case .gathers: GoMotion.quick
        case .rises: GoMotion.zenCardColorReveal
        case .dissolves: GoMotion.stateChange
        }
    }
}

struct OasisTreeEnergySurgeView: View {
    let pulseToken: Int
    let color: Color
    let allowsMotion: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if allowsMotion, !reduceMotion {
            surge(phase: .resting)
                .phaseAnimator(OasisEnergySurgePhase.allCases, trigger: pulseToken) { _, phase in
                    surge(phase: phase)
                } animation: { phase in
                    phase.animation
                }
        }
    }

    private func surge(phase: OasisEnergySurgePhase) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0), color.opacity(0.94), Color.goTeal.opacity(0.24)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: phase.width, height: phase.height)
                    .blur(radius: phase == .rises ? 4 : 7)

                Circle()
                    .fill(Color.white.opacity(0.92)) // ui-v4: allow transient energy beam core
                    .frame(width: 18, height: 18) // a11y: allow decorative transient energy flare
                    .blur(radius: 3)
                    .offset(y: -max(0, phase.height - 18))
            }
            .opacity(phase.opacity)
            .offset(y: phase.yOffset)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

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
                        Color.arkInk.frame(height: h / 2)
                    }
                )
                .opacity(0.8)

            let eyeColor = isMax ? Color(hex: "B45309") : Color(hex: "3E1F07")
            Circle().fill(eyeColor).frame(width: 3, height: 3).offset(x: -3, y: -5) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
            Circle().fill(eyeColor).frame(width: 3, height: 3).offset(x: 3, y: -5) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
            Circle().fill(eyeColor).frame(width: 3, height: 3).offset(x: 0, y: -1) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.

            if isMax {
                Circle()
                    .fill(Color(hex: "FEF3C7"))
                    .frame(width: 6, height: 6) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .blur(radius: 1)
                    .opacity(0.6)
                    .offset(x: -4, y: -6)
            }
        }
    }
}

struct SunbeamsView: View {
    var allowsAmbientMotion: Bool = true
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
            updateMotion()
        }
        .onChange(of: allowsAmbientMotion) { _, _ in
            updateMotion()
        }
    }

    private func updateMotion() {
        if allowsAmbientMotion {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { // ui-v4: allow AppWorkloadPolicy-gated sunbeams; runtime-guardrail: allow AppWorkloadPolicy-gated sunbeams // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                breathe = true
            }
        } else {
            breathe = false
        }
    }
}

struct DivineHaloView: View {
    var isSwaying: Bool
    var tier: Int = 1
    var size: CGFloat = 240
    var allowsAmbientMotion: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [Color(hex: "00FFD1"), Color(hex: "84CC16"), Color(hex: "00FFD1")],
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
        .animation(
            allowsAmbientMotion
                ? .linear(duration: 25).repeatForever(autoreverses: false) // runtime-guardrail: allow AppWorkloadPolicy-gated halo // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                : nil,
            value: isSwaying
        )
        .opacity(0.72 + min(Double(tier), 4) * 0.06)
        .allowsHitTesting(false)
    }
}

struct RunesView: View {
    var isSwaying: Bool
    var allowsAmbientMotion: Bool = true
    private let runes = ["✧", "✦", "✺", "✵", "❂", "❀"]

    var body: some View {
        ZStack {
            ForEach(0 ..< runes.count, id: \.self) { i in
                let angle = Double(i) * (360.0 / Double(runes.count))
                Text(runes[i])
                    .font(OhanaFont.adaptive(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "84CC16"))
                    .shadow(color: Color(hex: "00FFD1"), radius: 4) // ui-v4: allow max-level rune glow
                    .offset(y: -130)
                    .rotationEffect(.degrees(angle))
            }
        }
        .rotationEffect(.degrees(isSwaying ? -360 : 0))
        .animation(
            allowsAmbientMotion
                ? .linear(duration: 30).repeatForever(autoreverses: false) // runtime-guardrail: allow AppWorkloadPolicy-gated runes // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                : nil,
            value: isSwaying
        )
        .opacity(0.9)
        .allowsHitTesting(false)
    }
}

struct StardustView: View {
    var allowsAmbientMotion: Bool = true
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
            ForEach(0 ..< dust.count, id: \.self) { i in
                let item = dust[i]
                Capsule()
                    .fill(Color.ohanaPrimaryActionText)
                    .frame(width: 2, height: item.h)
                    .opacity(animate ? 0.1 : 0.8)
                    .offset(
                        x: item.x,
                        y: animate ? item.endY : item.startY
                    )
                    .animation(
                        allowsAmbientMotion
                            ? .linear(duration: item.duration)
                            .repeatForever(autoreverses: false) // runtime-guardrail: allow AppWorkloadPolicy-gated stardust // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                            .delay(item.delay)
                            : nil,
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = allowsAmbientMotion }
        .onChange(of: allowsAmbientMotion) { _, shouldAnimate in
            animate = shouldAnimate
        }
    }
}

/// Ground plane shared by the frozen and live Oasis tree stages. Keeping the
/// island in the same local scene as the tree prevents the young tree from
/// appearing to float above an unrelated decorative ellipse.
struct OasisTreeIslandBase: View {
    let level: Int
    let progress: Double

    @Environment(\.colorScheme) private var colorScheme

    private var safeLevel: Int { min(max(level, 0), 10) }
    private var safeProgress: CGFloat { CGFloat(min(max(progress, 0), 1)) }
    private var islandWidth: CGFloat {
        min(262, 164 + CGFloat(safeLevel) * 8 + safeProgress * 10)
    }
    private var islandHeight: CGFloat {
        min(58, 42 + CGFloat(safeLevel) * 1.4)
    }
    private var grassOpacity: Double {
        safeLevel == 0 ? 0.24 : min(0.94, 0.54 + Double(safeLevel) * 0.045)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.arkInk.opacity(colorScheme == .light ? 0.12 : 0.34))
                .frame(width: islandWidth * 0.86, height: islandHeight * 0.42)
                .blur(radius: 5)
                .offset(y: 8)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .light
                            ? [Color(hex: "C99B62"), Color(hex: "9A6740"), Color(hex: "74472F")]
                            : [Color(hex: "A96835"), Color(hex: "704226"), Color(hex: "42291D")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: islandWidth, height: islandHeight)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.goPrimary.opacity(grassOpacity), Color.goTeal.opacity(grassOpacity * 0.72)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: islandWidth * 0.91, height: islandHeight * 0.42)
                .offset(y: -islandHeight * 0.25)

            Ellipse()
                .fill(Color(hex: "24150F").opacity(colorScheme == .light ? 0.26 : 0.58))
                .frame(width: max(54, islandWidth * 0.30), height: 10)
                .offset(y: -islandHeight * 0.27)

            if safeLevel >= 3 {
                HStack(spacing: max(22, islandWidth * 0.18)) {
                    OasisIslandGrassTuft(tint: Color.goTeal, mirrors: false)
                    OasisIslandGrassTuft(tint: Color.goPrimary, mirrors: true)
                }
                .offset(y: -islandHeight * 0.40)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 280, height: 68, alignment: .bottom)
        .animation(GoMotion.hero, value: safeLevel)
        .animation(GoMotion.page, value: safeProgress)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct OasisIslandGrassTuft: View {
    let tint: Color
    let mirrors: Bool

    var body: some View {
        HStack(spacing: -5) {
            Capsule()
                .fill(tint.opacity(0.86))
                .frame(width: 6, height: 20) // a11y: allow decorative island grass; non-interactive and hidden with its parent illustration
                .rotationEffect(.degrees(-28))
            Capsule()
                .fill(tint)
                .frame(width: 7, height: 25) // a11y: allow decorative island grass; non-interactive and hidden with its parent illustration
            Capsule()
                .fill(tint.opacity(0.72))
                .frame(width: 6, height: 18) // a11y: allow decorative island grass; non-interactive and hidden with its parent illustration
                .rotationEffect(.degrees(30))
        }
        .scaleEffect(x: mirrors ? -1 : 1, y: 1)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var level = 5
        @State private var harvested: Set<Int> = []

        var body: some View {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()
                VStack(spacing: 24) {
                    BeautifulCoconutTree(
                        level: level,
                        isInjecting: false,
                        harvestedCoconuts: harvested,
                        onHarvest: { harvested.insert($0) }
                    )
                    .frame(height: 340)

                    Text("Lv.\(level) · Tap coconuts to harvest")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))

                    HStack(spacing: 16) {
                        Button("Level up") {
                            if level < 10 { level += 1 }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.goPrimary, in: Capsule())
                        .foregroundStyle(Color.arkInk)

                        Button("Reset coconuts") { harvested = [] }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.ohanaControlFill, in: Capsule())
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                }
                .padding()
            }
        }
    }
    return PreviewWrapper()
}
