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
            return GoMotion.heroExpand
        case .sheet:
            return GoMotion.sheetEnter
        case .menu:
            return GoMotion.fab
        case .reward:
            return GoMotion.rewardPop
        case .chart:
            return GoMotion.stateChange
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

struct OhanaSceneRevealShape: Shape {
    enum Edge {
        case top
        case bottom
        case leading
        case trailing
    }

    var progress: CGFloat
    var edge: Edge = .top

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let p = min(max(progress, 0), 1)
        switch edge {
        case .top:
            return Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * p))
        case .bottom:
            return Path(CGRect(x: rect.minX, y: rect.maxY - rect.height * p, width: rect.width, height: rect.height * p))
        case .leading:
            return Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * p, height: rect.height))
        case .trailing:
            return Path(CGRect(x: rect.maxX - rect.width * p, y: rect.minY, width: rect.width * p, height: rect.height))
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

