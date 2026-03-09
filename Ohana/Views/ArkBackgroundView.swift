//
//  ArkBackgroundView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

struct ArkBackgroundView: View {
    var level: IslandLevel = .seedling
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // 基础渐变（随等级进化）
            LinearGradient(
                colors: colorScheme == .dark ? level.backgroundColors : level.backgroundColorsLight,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Level 2+：繁花光晕
            if level.showBlossoms {
                RadialGradient(
                    colors: [Color.goMint.opacity(0.08), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 320
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.goTeal.opacity(0.06), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 280
                )
                .ignoresSafeArea()
            }

            // Level 3：极光层
            if level.showAurora {
                LinearGradient(
                    colors: [
                        Color(hex: "7B4FFF").opacity(0.15),
                        Color(hex: "00D4AA").opacity(0.10),
                        .clear,
                        Color(hex: "4338FF").opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .blendMode(.screen)
            }

            // 微妙噪点纹理保留
            NoiseTextureView()
                .opacity(0.015)
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    ArkBackgroundView()
}
