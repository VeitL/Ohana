//
//  VerticalSolidHomeModels.swift
//  Ohana
//
//  Value snapshots and commands for the rebuilt home surface.
//

import Foundation
import SwiftData
import SwiftUI

enum VerticalSolidHomeTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case calendar
    case oasis
    case plants

    static var visibleTabs: [VerticalSolidHomeTab] {
        AppFeatureRouteGuard.visibleHomeTabs
    }

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .home: 0
        case .calendar: 1
        case .oasis: 2
        case .plants: 3
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .calendar: "checklist"
        case .oasis: "tree.fill"
        case .plants: "leaf.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .home: l.tr(zh: "首页", en: "Home", de: "Home")
        case .calendar: l.tr(zh: "待办", en: "Tasks", de: "Aufgaben")
        case .oasis: l.tr(zh: "Oasis", en: "Oasis", de: "Oasis")
        case .plants: l.tr(zh: "植物", en: "Plants", de: "Pflanzen")
        }
    }
}

nonisolated struct VerticalSolidHomePlantSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let name: String
    let subtitle: String
    let emoji: String
    let themeHex: String
    let roomName: String
    let avatarImageSignature: String
    let avatarImageAssetName: String?
    let needsCare: Bool
    let hasDueWatering: Bool
    let hasDueFertilizing: Bool
    let dueCareTypes: [PlantCareType]
    let overdueCareTypes: [PlantCareType]
    let dueCareCount: Int
    let overdueCareCount: Int
    let careDifficultyText: String
    let attentionText: String
    let todoText: String
}

nonisolated struct VerticalSolidHomeFirstPetEmptyState: Equatable, Sendable {
    let eyebrow: String
    let title: String
    let subtitle: String
    let progressText: String
    let primaryActionTitle: String
}

nonisolated struct VerticalSolidHomeSnapshot: @unchecked Sendable {
    var isReady = false
    var greeting = ""
    var activeName = ""
    var coconutText = "0"
    var todayFocus = TodayFocusSnapshot.empty
    var cards: [FocusCard] = []
    var firstPetEmptyState: VerticalSolidHomeFirstPetEmptyState?
    var plants: [VerticalSolidHomePlantSnapshot] = []
    var heroPreparationRevision = ""

    static let empty = VerticalSolidHomeSnapshot()
}
