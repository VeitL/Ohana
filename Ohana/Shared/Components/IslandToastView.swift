//
//  IslandToastView.swift
//  Ohana
//
//  岛屿连击 Toast：完成委托后从底部浮出的奖励提示。
//

import SwiftUI

struct IslandToastView: View {
    let message: String
    var isShowing: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.ohanaCardSurface, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 16, y: 4) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
        .opacity(isShowing ? 1 : 0)
        .offset(y: isShowing ? 0 : 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isShowing) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
    }
}

// MARK: - ViewModifier 方便挂载
struct IslandToastModifier: ViewModifier {
    var manager: IslandToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            IslandToastView(message: manager.message, isShowing: manager.isShowing)
                .padding(.bottom, 90)
                .allowsHitTesting(false)
        }
    }
}

struct IslandToastEnvironmentModifier: ViewModifier {
    @Environment(AppServices.self) private var appServices

    func body(content: Content) -> some View {
        content.modifier(IslandToastModifier(manager: appServices.islandToasts))
    }
}

extension View {
    func islandToastOverlay() -> some View {
        modifier(IslandToastEnvironmentModifier())
    }
}
