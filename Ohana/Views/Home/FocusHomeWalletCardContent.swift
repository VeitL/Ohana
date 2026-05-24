//
//  FocusHomeWalletCardContent.swift
//  Ohana
//
//  Rendered content and lightweight effects for one GO Focus wallet card.
//

import SwiftUI

struct FocusHomeWalletCardContent: View {
    let card: FocusCard
    let namespace: Namespace.ID
    let heroNamespace: Namespace.ID
    let expandedId: UUID?
    let isHeroExpanded: Bool
    let heroProgress: CGFloat
    let avatarCacheRevision: Int
    let walkTrackingPet: Pet?
    var usesMatchedGeometry: Bool = true

    var body: some View {
        ZStack {
            FocusWalletCardView(
                card: card,
                namespace: namespace,
                heroNS: heroNamespace,
                expandedId: expandedId,
                isHeroExpanded: isHeroExpanded,
                heroProgress: heroProgress,
                avatarCacheRevision: avatarCacheRevision,
                usesMatchedGeometry: usesMatchedGeometry
            )
            .opacity(walkTrackingPet == nil ? 1 : 0)

            if let walkTrackingPet {
                WalkTrackingCard(pet: walkTrackingPet)
                    .padding(10)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .center).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(HeroAnim.walletSpring, value: walkTrackingPet?.id)
    }

    static func walkTrackingPet(for card: FocusCard, isHero: Bool, pets: [Pet]) -> Pet? {
        guard isHero,
              !card.isHuman,
              PetWalkingManager.shared.currentPet?.id == card.id
        else { return nil }

        switch PetWalkingManager.shared.phase {
        case .running, .paused, .finished:
            return pets.first(where: { $0.id == card.id && !$0.hasPassedAway })
        case .idle:
            return nil
        }
    }
}

struct FocusHomeExpandedActionPulseOverlay: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            RoundedRectangle(cornerRadius: HeroAnim.stackCardCorner, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.88), lineWidth: 2)
                .shadow(color: Color.goPrimary.opacity(0.45), radius: 18, y: 0) // ui-v4: allow quick-action success pulse
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 1.015)))
        }
    }
}

struct FocusHomeWalkTransformBurstOverlay: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            WalkLaunchBurst()
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}
