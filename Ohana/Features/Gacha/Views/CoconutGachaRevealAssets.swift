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

struct CoconutRevealParticles: View {
    let phase: CoconutGachaRevealPhase
    let accent: Color
    var isCollectible: Bool = false

    private var isBursting: Bool {
        phase == .reveal || phase == .settled
    }

    var body: some View {
        ZStack {
            ForEach(0 ..< 10, id: \.self) { index in
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
            Color.ohanaSecondaryText
        case .rare:
            Color.goTeal
        case .superRare:
            Color.goPurple
        case .hidden:
            Color.goYellow
        }
    }
}
