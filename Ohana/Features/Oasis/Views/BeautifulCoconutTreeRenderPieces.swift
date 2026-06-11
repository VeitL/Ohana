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

                    Text("Lv.\(level) · 点击椰子采摘")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))

                    HStack(spacing: 16) {
                        Button("升级") {
                            if level < 10 { level += 1 }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.goPrimary, in: Capsule())
                        .foregroundStyle(Color.arkInk)

                        Button("重置椰子") { harvested = [] }
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
