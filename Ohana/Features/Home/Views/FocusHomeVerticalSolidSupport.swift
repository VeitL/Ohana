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
    @State private var hitTestOverflow: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            content
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
        }
            .frame(width: width, alignment: .top)
            .frame(height: height + hitTestOverflow, alignment: .top)
            .contentShape(Rectangle())
            .clipShape(WalletHeroRevealShape(reveal: reveal))
            .contentShape(Rectangle())
            .opacity(Double(reveal))
            .allowsHitTesting(isReady)
            .accessibilityHidden(!isReady)
            // The card scene aligns this layer to its bottom edge. Offset the
            // added menu space back down so the dock stays put while the
            // parent hit-test and reveal bounds grow around an open submenu.
            .offset(y: hitTestOverflow)
            .onPreferenceChange(VerticalHomeEmbeddedQuickActionHitOverflowPreferenceKey.self) { newValue in
                guard hitTestOverflow != newValue else { return }
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    hitTestOverflow = newValue
                }
            }
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
