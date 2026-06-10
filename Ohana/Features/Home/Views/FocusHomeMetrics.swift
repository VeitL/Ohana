//
//  FocusHomeMetrics.swift
//  Ohana
//
//  Shared layout metrics and lightweight route models for GO Focus home.
//

import SwiftUI

enum K {
    static let bg = Color(hex: "F8D8DF")
    static let ink = Color(hex: "23181A")
    static let muted = Color(hex: "8B6E74")

    static let hPad: CGFloat = 20
    static let cardMargin: CGFloat = 7
    /// 标准信用卡比例 85.6x53.98mm ≈ 1.586:1（宽/高），随屏幕宽度动态计算
    static var cardH: CGFloat { (ScreenCompat.width - cardMargin * 2) / 1.586 }
    static let expandedCardH: CGFloat = 360
    static let cardTitleH: CGFloat = 49
    static let collapsedStackPeekH: CGFloat = cardTitleH * 0.9
    static let stackPeekH: CGFloat = collapsedStackPeekH
    static var expandedInactiveStackPeekH: CGFloat { collapsedStackPeekH / 5 }
    static let expandedInactiveFrontPeekH: CGFloat = 18
    static let collapsedStackBottomGap: CGFloat = 22
    static let expandedStackBottomGap: CGFloat = 12
    static let expandedCardGlobalTopOffset: CGFloat = 76
    static let expandedQuickModuleGap: CGFloat = 22
    static let expandedQuickModuleH: CGFloat = 112
    static let expandedQuickModuleEditH: CGFloat = 206
    static var stackSpacing: CGFloat { -(cardH - collapsedStackPeekH) }

    static let heroMargin: CGFloat = 16
    static let focusCardPadding: CGFloat = heroMargin / 3
}

enum HeroAnim {
    static let stackCardCorner: CGFloat = 24
    static var transitionSpring: Animation { GoMotion.page }
    static var walletSpring: Animation { GoMotion.heroExpand }
    static var walletCollapseSpring: Animation { GoMotion.heroCollapse }
    static var walletContentSpring: Animation {
        .interactiveSpring(response: 0.34, dampingFraction: 0.9, blendDuration: 0.12)
    }
    static var walletReduced: Animation { .easeOut(duration: 0.22) }
    static var fabSpring: Animation { GoMotion.fab }
    static var buttonSpring: Animation { GoMotion.feedback }
    static let compactPeek: CGFloat = 14
}

struct HeroShellID: Hashable { let cardId: UUID }
struct HeroArtID: Hashable { let cardId: UUID }

enum HeroTransitionPhase: Equatable {
    case collapsed
    case expanding
    case expanded
    case collapsing
}

struct HomeHeroTransitionProgress: Equatable {
    var value: CGFloat

    var clamped: CGFloat {
        min(max(value, 0), 1)
    }

    var phase: HeroTransitionPhase {
        if clamped <= 0.001 { return .collapsed }
        if clamped >= 0.999 { return .expanded }
        return .expanding
    }
}

enum OhanaHeroGeometry {
    static func lerp(_ start: CGFloat, _ end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * min(max(progress, 0), 1)
    }
}

typealias HomeWalletHeroTimeline = WalletHeroTimeline

struct HomeHeroQuickModuleRevealModifier: AnimatableModifier {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let reveal = WalletHeroTimeline.quickReveal(progress: progress)
        content
            .opacity(reveal > 0.015 ? 1 : 0)
            .clipShape(HomeHeroTopRevealShape(reveal: reveal))
            .allowsHitTesting(reveal > 0.98)
    }
}

private struct HomeHeroTopRevealShape: Shape {
    var reveal: CGFloat

    var animatableData: CGFloat {
        get { reveal }
        set { reveal = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let visibleHeight = rect.height * min(max(reveal, 0), 1)
        return Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: visibleHeight))
    }
}
