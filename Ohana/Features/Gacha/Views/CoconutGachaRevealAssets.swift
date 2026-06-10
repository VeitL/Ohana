//
//  CoconutGachaRevealAssets.swift
//  Ohana
//
//  Asset and particle helpers for gacha reveal surfaces.
//

import SwiftUI

struct GachaAssetImage: View {
    let assetName: String
    let fallbackSymbol: String

    var body: some View {
        if assetName.isEmpty {
            Text(fallbackSymbol)
                .font(OhanaFont.adaptive(size: 42))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClosedCoconut: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "B7824A"), // ui-v4: allow coconut asset color
                            Color(hex: "6D4325") // ui-v4: allow coconut asset color
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 146, height: 146)
                .shadow(color: Color.arkInk.opacity(0.24), radius: 16, x: 0, y: 12) // ui-v4: allow 2.5d coconut asset depth

            Circle()
                .fill(Color.ohanaPrimaryText.opacity(0.15))
                .frame(width: 50, height: 34)
                .offset(x: -28, y: -36)
                .blur(radius: 4)

            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(Color(hex: "E6C29A").opacity(0.42)) // ui-v4: allow coconut fiber color
                    .frame(width: 3, height: 23) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .rotationEffect(.degrees(Double(index) * 30))
                    .offset(y: -68)
            }

            CoconutCrackLine()
                .stroke(Color(hex: "4B2D1B").opacity(0.52), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)) // ui-v4: allow coconut crack ink
                .frame(width: 116, height: 38)
                .offset(y: 2)
        }
    }
}

private enum CoconutShellSide {
    case left
    case right
}

private struct CoconutShellHalf: View {
    let side: CoconutShellSide

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "B7824A"), // ui-v4: allow coconut asset color
                            Color(hex: "5A3621") // ui-v4: allow coconut asset color
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 86, height: 126)

            Capsule()
                .fill(Color(hex: "F3E0C7")) // ui-v4: allow coconut flesh color
                .frame(width: 58, height: 96)
                .offset(x: side == .left ? 10 : -10)

            CoconutCrackLine()
                .stroke(Color(hex: "4B2D1B").opacity(0.42), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)) // ui-v4: allow coconut crack ink
                .frame(width: 44, height: 28)
                .rotationEffect(.degrees(side == .left ? -86 : 86))
                .offset(x: side == .left ? 25 : -25, y: -12)
        }
        .shadow(color: Color.arkInk.opacity(0.18), radius: 12, x: 0, y: 10) // ui-v4: allow 2.5d coconut asset depth
    }
}

private struct CoconutCrackLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.midY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.midY + rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.midY - rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.midY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.midY - rect.height * 0.02))
        return path
    }
}

struct CoconutRevealParticles: View {
    let phase: CoconutGachaRevealPhase
    let accent: Color
    var isCollectible: Bool = false

    private var isBursting: Bool {
        phase == .reveal || phase == .settled
    }

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.goYellow : accent)
                    .frame(width: CGFloat(4 + (index % 3)), height: CGFloat(4 + (index % 3)))
                    .offset(
                        x: isBursting ? xOffsets[index] : 0,
                        y: isBursting ? yOffsets[index] + (isCollectible ? -28 : 0) : 24
                    )
                    .opacity(isBursting && phase == .reveal ? 0.82 : 0)
                    .animation(GoMotion.feedback.delay(Double(index) * 0.018), value: phase)
            }
        }
        .allowsHitTesting(false)
    }

    private let xOffsets: [CGFloat] = [-86, -62, -38, -16, 8, 28, 52, 76, -18, 42]
    private let yOffsets: [CGFloat] = [-18, -48, -28, -66, -54, -24, -60, -30, -82, -84]
}

extension GachaRarity {
    var tint: Color {
        switch self {
        case .common:
            return Color.ohanaSecondaryText
        case .rare:
            return Color.goTeal
        case .superRare:
            return Color.goPurple
        case .hidden:
            return Color.goYellow
        }
    }
}

