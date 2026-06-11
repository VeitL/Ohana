//
//  OhanaZStackMotionScene.swift
//  Ohana
//
//  Shared stable-ZStack motion helpers. Key interactions should keep their
//  visual layers mounted and drive transforms, masks, and opacity from one
//  scene state instead of inserting/removing views mid-animation.
//

import SwiftUI

enum OhanaMotionSceneRole {
    case hero
    case sheet
    case menu
    case reward
    case chart

    var animation: Animation {
        switch self {
        case .hero:
            GoMotion.heroExpand
        case .sheet:
            GoMotion.sheetEnter
        case .menu:
            GoMotion.fab
        case .reward:
            GoMotion.rewardPop
        case .chart:
            GoMotion.stateChange
        }
    }

    var reducedAnimation: Animation {
        GoMotion.reduced
    }
}

struct OhanaMotionScene<Content: View>: View {
    var role: OhanaMotionSceneRole
    var alignment: Alignment
    var isActive: Bool
    var reduceMotion: Bool
    @ViewBuilder var content: () -> Content

    init(
        role: OhanaMotionSceneRole,
        alignment: Alignment = .center,
        isActive: Bool = true,
        reduceMotion: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.role = role
        self.alignment = alignment
        self.isActive = isActive
        self.reduceMotion = reduceMotion
        self.content = content
    }

    var body: some View {
        ZStack(alignment: alignment) {
            content()
        }
        .animation(reduceMotion ? role.reducedAnimation : role.animation, value: isActive)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = role.reducedAnimation
            }
        }
    }
}

extension View {
    func ohanaMotionScene(
        role: OhanaMotionSceneRole,
        alignment: Alignment = .center,
        isActive: Bool = true,
        reduceMotion: Bool = false
    ) -> some View {
        OhanaMotionScene(role: role, alignment: alignment, isActive: isActive, reduceMotion: reduceMotion) {
            self
        }
    }

    func ohanaSceneLayer(zIndex: Double, hitTesting: Bool = true) -> some View {
        self
            .zIndex(zIndex)
            .allowsHitTesting(hitTesting)
    }
}
