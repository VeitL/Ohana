//
//  QuickFeedOverlayHost.swift
//  Ohana
//
//  Typed overlay presenter for feeding toast and treat celebration states.
//

import SwiftUI

struct QuickFeedOverlayHost: View {
    let route: QuickFeedOverlayRoute?

    var body: some View {
        ZStack {
            if let route {
                switch route {
                case let .toast(_, message, tint):
                    toastView(message: message, tint: tint)
                        .zIndex(10)
                case let .treatCelebration(_, tint):
                    TreatCelebrationOverlay(tint: tint)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                        .zIndex(20)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func toastView(message: String, tint: Color) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(message)
                    .font(.system(size: 14, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(tint, in: Capsule())
            .padding(.bottom, 34)
        }
    }
}
