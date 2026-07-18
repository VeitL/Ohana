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
    static let sectionSpacing: CGFloat = 10
    static let minimumSceneHeight: CGFloat = 360
    static let selectedRoomHeaderHeight: CGFloat = 54
    static let selectedRoomHeaderSpacing: CGFloat = 10
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

    static func selectedRoomCardViewportHeight(
        containerHeight: CGFloat,
        bottomChromeHeight: CGFloat
    ) -> CGFloat {
        max(
            minimumSceneHeight,
            cardViewportHeight(
                containerHeight: containerHeight,
                bottomChromeHeight: bottomChromeHeight
            ) - selectedRoomHeaderHeight - selectedRoomHeaderSpacing
        )
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

struct VerticalSolidHomePlantRoomStackTransform: Equatable {
    let xOffset: CGFloat
    let yOffset: CGFloat
    let rotationDegrees: Double
    let scale: CGFloat
}

nonisolated enum VerticalSolidHomePlantRoomStackLayout {
    static let maxVisibleCards = 5
    static let overviewColumnCount = 2
    static let overviewSpacing: CGFloat = 10
    static let overviewHorizontalPadding: CGFloat = 16
    static let overviewTopInset: CGFloat = 72
    static let overviewBottomInset: CGFloat = 24
    static let verticalOverflowAllowance: CGFloat = 26

    static func gridCellWidth(containerWidth: CGFloat) -> CGFloat {
        let totalSpacing = overviewSpacing * CGFloat(overviewColumnCount - 1)
        let availableWidth = max(
            0,
            containerWidth - overviewHorizontalPadding * 2 - totalSpacing
        )
        return availableWidth / CGFloat(overviewColumnCount)
    }

    static func cardWidth(containerWidth: CGFloat) -> CGFloat {
        min(max(containerWidth - 38, 104), 132)
    }

    static func stackHeight(containerWidth: CGFloat) -> CGFloat {
        cardWidth(containerWidth: containerWidth)
            * FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
            + verticalOverflowAllowance
    }

    static func fourStackGridHeight(containerWidth: CGFloat) -> CGFloat {
        stackHeight(containerWidth: gridCellWidth(containerWidth: containerWidth)) * 2
            + overviewSpacing
    }

    static func transform(position: Int) -> VerticalSolidHomePlantRoomStackTransform {
        let transforms = [
            VerticalSolidHomePlantRoomStackTransform(
                xOffset: 0,
                yOffset: 4,
                rotationDegrees: 0,
                scale: 1
            ),
            VerticalSolidHomePlantRoomStackTransform(
                xOffset: -13,
                yOffset: 6,
                rotationDegrees: -9.2,
                scale: 0.985
            ),
            VerticalSolidHomePlantRoomStackTransform(
                xOffset: 13,
                yOffset: 5,
                rotationDegrees: 9.0,
                scale: 0.975
            ),
            VerticalSolidHomePlantRoomStackTransform(
                xOffset: -6,
                yOffset: -8,
                rotationDegrees: -4.8,
                scale: 0.965
            ),
            VerticalSolidHomePlantRoomStackTransform(
                xOffset: 7,
                yOffset: -9,
                rotationDegrees: 5.6,
                scale: 0.955
            )
        ]
        return transforms[min(max(position, 0), transforms.count - 1)]
    }
}

nonisolated enum VerticalSolidHomePlantExpandedGridLayout {
    static let horizontalPadding: CGFloat = 12
    static let columnSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 8
    static let roomSpacing: CGFloat = 18
    static let topInset: CGFloat = 72
    static let bottomInset: CGFloat = 32
    static let minimumReadableRenderWidth: CGFloat = 154

    static func columnCount(containerWidth: CGFloat) -> Int {
        if containerWidth < 350 { return 3 }
        if containerWidth >= 700 { return 7 }
        if containerWidth >= 560 { return 6 }
        if containerWidth >= 430 { return 5 }
        return 4
    }

    static func cardWidth(containerWidth: CGFloat) -> CGFloat {
        let count = columnCount(containerWidth: containerWidth)
        let totalSpacing = columnSpacing * CGFloat(count - 1)
        return max(
            0,
            (containerWidth - horizontalPadding * 2 - totalSpacing) / CGFloat(count)
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

struct VerticalSolidHomePlantRoomGroup: Identifiable {
    let summary: VerticalSolidHomePlantRoomSummary
    let plants: [VerticalSolidHomePlantSnapshot]

    var id: String { summary.id }
}

struct VerticalSolidHomePlantAvatarPreloadRequest: Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let signature: String
}

enum VerticalSolidHomePlantViewStyle: String, CaseIterable, Identifiable {
    case roomStacks = "room-stacks"
    case allExpanded = "all-expanded"

    var id: String { rawValue }

    func toggleTitle(_ l: L10n) -> String {
        switch self {
        case .roomStacks: l.tr(zh: "全部展开", en: "Expand all", de: "Alle öffnen")
        case .allExpanded: l.tr(zh: "收起", en: "Collapse", de: "Schließen")
        }
    }

    var toggleIcon: String {
        switch self {
        case .roomStacks: "square.grid.3x3.square"
        case .allExpanded: "square.stack.3d.up.fill"
        }
    }

    var toggled: Self {
        switch self {
        case .roomStacks: .allExpanded
        case .allExpanded: .roomStacks
        }
    }
}
