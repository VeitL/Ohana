//
//  VerticalSolidHomePlantsPageModels.swift
//  Ohana
//
//  Policies and lightweight models for the vertical solid plants page.
//

import Foundation
import SwiftData
import SwiftUI

enum VerticalSolidHomePlantWalletScrollPolicy {
    static let maxCardsPerSection = Int.max
    static let sectionSpacing: CGFloat = 18
    static let minimumSceneHeight: CGFloat = 360
    static let topContentInset: CGFloat = 0
    static let bottomContentInset: CGFloat = 28
    static let roomRailVisibleBottomInset: CGFloat = 72
    static let roomRailHiddenBottomInset: CGFloat = 24
    static let roomRailTrailingCenterInset: CGFloat = 31
    static let expandedCardViewportTopInset: CGFloat = 36
    static let expandedCardHeightEstimate: CGFloat = 386 * FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio

    static func cardViewportHeight(
        containerHeight: CGFloat,
        bottomChromeHeight: CGFloat
    ) -> CGFloat {
        max(minimumSceneHeight, containerHeight - bottomChromeHeight)
    }

    static func roomRailCenterY(
        containerHeight: CGFloat,
        topChromeHeight: CGFloat
    ) -> CGFloat {
        let screenCenterYInPage = (containerHeight - topChromeHeight) / 2
        return min(max(44, screenCenterYInPage), max(44, containerHeight - 44))
    }

    static func sectionCount(
        cardCount: Int,
        maxCardsPerSection: Int = Self.maxCardsPerSection
    ) -> Int {
        guard cardCount > 0, maxCardsPerSection > 0 else { return 0 }
        return Int(ceil(Double(cardCount) / Double(maxCardsPerSection)))
    }

    static func sectionHeight(
        cardCount: Int,
        isExpanded: Bool,
        availableHeight: CGFloat
    ) -> CGFloat {
        guard cardCount > 0 else { return 0 }
        _ = isExpanded

        return max(
            minimumSceneHeight,
            availableHeight,
            FocusHomeVerticalSolidCollapsedLayoutPolicy.scrollExtendedMinimumSceneHeight(cardCount: cardCount)
        )
    }

    static func sceneHeight(
        cardCount: Int,
        isExpanded: Bool,
        availableHeight: CGFloat
    ) -> CGFloat {
        guard cardCount > 0 else { return 0 }
        _ = isExpanded

        return max(
            minimumSceneHeight,
            availableHeight,
            FocusHomeVerticalSolidCollapsedLayoutPolicy.scrollExtendedMinimumSceneHeight(cardCount: cardCount)
        )
    }

    static func anchoredExpandedSceneHeight(
        baseHeight: CGFloat,
        isExpanded: Bool,
        scrollOffsetY: CGFloat
    ) -> CGFloat {
        guard isExpanded else { return baseHeight }

        return max(
            baseHeight,
            max(0, scrollOffsetY)
                + expandedCardViewportTopInset
                + expandedCardHeightEstimate
                + bottomContentInset
        )
    }
}

nonisolated enum VerticalSolidHomePlantRoomRailPolicy {
    static func shouldShow(plantCount: Int, selectedCardId: UUID?, heroDirection: Int) -> Bool {
        plantCount > 0 && selectedCardId == nil && heroDirection == 0
    }
}

struct VerticalSolidHomePlantCardSection: Identifiable {
    let id: String
    let cards: [FocusCard]

    init(cards: [FocusCard]) {
        self.cards = cards
        id = cards.map(\.id.uuidString).joined(separator: "|")
    }

    func contains(cardId: UUID?) -> Bool {
        guard let cardId else { return false }
        return cards.contains { $0.id == cardId }
    }
}

struct VerticalSolidHomePlantRoomSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let plantCount: Int
    let dueCount: Int
}

struct VerticalSolidHomePlantAvatarPreloadRequest: Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let signature: String
}

enum VerticalSolidHomePlantViewStyle: String, CaseIterable, Identifiable {
    case deck
    case list

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .deck: l.tr(zh: "卡牌堆", en: "Card stack", de: "Kartenstapel")
        case .list: l.tr(zh: "列表", en: "List", de: "Liste")
        }
    }

    func shortTitle(_ l: L10n) -> String {
        switch self {
        case .deck: l.tr(zh: "卡", en: "Cards", de: "Karten")
        case .list: l.tr(zh: "列", en: "List", de: "Liste")
        }
    }

    var icon: String {
        switch self {
        case .deck: "square.stack.3d.up.fill"
        case .list: "list.bullet"
        }
    }
}
