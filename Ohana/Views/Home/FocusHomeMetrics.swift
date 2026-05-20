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
    static var walletSpring: Animation {
        .interactiveSpring(response: 0.58, dampingFraction: 0.9, blendDuration: 0.18)
    }
    static var walletCollapseSpring: Animation {
        .interactiveSpring(response: 0.5, dampingFraction: 0.94, blendDuration: 0.16)
    }
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

struct ExpandedQuickPetRecordRoute: Identifiable {
    let id = UUID()
    let pet: Pet
}

struct ExpandedQuickHumanRecordRoute: Identifiable {
    let id = UUID()
    let human: Human
    let actionType: String

    var actionKey: String {
        "\(human.id.uuidString):\(actionType)"
    }
}

enum ExpandedQuickActionMenuTarget: Identifiable {
    case pet(QuickActionItem, Pet)
    case human(QuickActionItem, Human)

    var id: String {
        switch self {
        case .pet(let item, let pet):
            return "pet:\(pet.id.uuidString):\(item.id)"
        case .human(let item, let human):
            return "human:\(human.id.uuidString):\(item.id)"
        }
    }
}
