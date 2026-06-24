//
//  FocusHomeVerticalSolidSupport.swift
//  Ohana
//
//  Shared value/support types for the vertical solid home motion scene.
//

import SwiftUI
import UIKit

struct FocusHomeVerticalSolidQuickActionLayer<Content: View>: View {
    let content: Content
    let width: CGFloat
    let height: CGFloat
    let reveal: CGFloat
    let isReady: Bool

    var body: some View {
        content
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            .frame(width: width, alignment: .top)
            .frame(height: height, alignment: .top)
            .clipShape(WalletHeroRevealShape(reveal: reveal))
            .opacity(Double(reveal))
            .allowsHitTesting(isReady)
            .accessibilityHidden(!isReady)
    }
}

struct FocusHomeFrozenAvatarSource {
    let image: UIImage?
    let isTransparent: Bool

    static let placeholder = FocusHomeFrozenAvatarSource(image: nil, isTransparent: true)

    @MainActor
    static func cached(for card: FocusCard) -> FocusHomeFrozenAvatarSource? {
        guard let entry = FocusWalletAvatarCache.cachedEntry(for: card.id, signature: card.avatarImageSignature),
              entry.image != nil else {
            return nil
        }
        return FocusHomeFrozenAvatarSource(image: entry.image, isTransparent: entry.isTransparent)
    }

    @MainActor
    static func live(for card: FocusCard) -> FocusHomeFrozenAvatarSource {
        cached(for: card) ?? .placeholder
    }
}
