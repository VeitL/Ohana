//
//  CoconutGachaRevealGrandBundle.swift
//  Ohana
//
//  Grand coconut bundle reveal surface.
//

import SwiftUI

struct GachaCoconutGrandBundlePrizeView: View {
    let phase: CoconutGachaRevealPhase
    let trigger: Int
    let coconutDelta: Int
    let shouldAnimate: Bool
    let l: L10n

    private var isSettled: Bool { phase == .settled }
    private var giftYOffset: CGFloat { isSettled ? -6 : -42 }
    private var giftScale: CGFloat { isSettled ? 0.94 : 1.10 }

    var body: some View {
        ZStack {
            grandGlow
            fallingCoconuts

            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: "shippingbox.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 64, weight: .black))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.goYellow)
                        .frame(width: 104, height: 104)
                        .background(Color.goYellow.opacity(0.20), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(Color.goCardWhite.opacity(0.70), lineWidth: 2)
                        }
                        .shadow(color: Color.goYellow.opacity(shouldAnimate ? 0.48 : 0.18), radius: 24, x: 0, y: 12) // ui-v4: allow one-shot jackpot bundle depth

                    Text("🥥")
                        .font(OhanaFont.adaptive(size: 34))
                        .offset(x: 30, y: 26)
                        .shadow(color: Color.arkInk.opacity(0.22), radius: 5, y: 2) // ui-v4: allow jackpot coconut readability
                }
                .offset(y: giftYOffset)
                .scaleEffect(giftScale)
                .rotationEffect(.degrees(phase == .reveal && shouldAnimate ? -7 : 0))
                .ohanaPhasePop(trigger: trigger, enabled: shouldAnimate)
                .ohanaPing(trigger: trigger, accent: Color.goYellow, isEnabled: shouldAnimate && phase == .reveal)
                .ohanaShake(trigger: phase, amount: 7, isEnabled: shouldAnimate && phase == .reveal)

                VStack(spacing: 2) {
                    Text("+\(coconutDelta)🥥")
                        .font(OhanaFont.adaptive(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                        .contentTransition(.numericText())
                        .shadow(color: Color.goYellow.opacity(0.30), radius: 12, x: 0, y: 5) // ui-v4: allow jackpot numeric glow

                    Text(l.tr(zh: "椰子大礼包", en: "Coconut Grand Bundle", de: "Großes Kokospaket"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.ohanaCardSurface.opacity(0.86), in: Capsule())
                .ohanaShine(trigger: trigger, cornerRadius: OhanaRadius.cardSoft, isEnabled: shouldAnimate && phase == .reveal)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var grandGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.goYellow.opacity(shouldAnimate ? 0.56 : 0.28),
                            Color.goPrimary.opacity(0.22),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 136
                    )
                )
                .frame(width: 258, height: 258)

            ForEach(0 ..< 14, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "plus")
                    .font(.system(size: index.isMultiple(of: 3) ? 17 : 9, weight: .black))
                    .foregroundStyle(index.isMultiple(of: 2) ? Color.goYellow : Color.goCardWhite)
                    .offset(x: glowOffsets[index].x, y: glowOffsets[index].y)
                    .opacity(phase == .reveal ? 0.95 : 0.32)
                    .scaleEffect(phase == .reveal ? 1.18 : 0.82)
            }
        }
        .scaleEffect(phase == .reveal ? 1.05 : 0.95)
        .allowsHitTesting(false)
    }

    private var fallingCoconuts: some View {
        ForEach(0 ..< 8, id: \.self) { index in
            Text("🥥")
                .font(.system(size: index.isMultiple(of: 2) ? 20 : 16))
                .offset(
                    x: coconutOffsets[index].x,
                    y: phase == .reveal ? coconutOffsets[index].y : coconutOffsets[index].y - 72
                )
                .opacity(phase == .reveal ? 0.95 : 0.20)
                .scaleEffect(phase == .reveal ? 1 : 0.72)
                .allowsHitTesting(false)
        }
    }

    private let glowOffsets: [(x: CGFloat, y: CGFloat)] = [
        (-92, -58), (-68, 28), (-42, -88), (-18, 64), (10, -74), (38, 42), (72, -36),
        (94, 16), (-104, 8), (-76, 76), (-6, -112), (52, -92), (86, 78), (18, 98)
    ]

    private let coconutOffsets: [(x: CGFloat, y: CGFloat)] = [
        (-78, -74), (-50, -20), (-22, -92), (6, -34), (34, -78), (64, -18), (88, -58), (18, -112)
    ]
}
