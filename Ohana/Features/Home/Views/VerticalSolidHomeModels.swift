//
//  VerticalSolidHomeModels.swift
//  Ohana
//
//  Value snapshots and commands for the rebuilt home surface.
//

import Foundation
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
        case .calendar: "calendar"
        case .oasis: "tree.fill"
        case .plants: "leaf.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .home: l.tr(zh: "首页", en: "Home", de: "Home")
        case .calendar: l.tr(zh: "日历", en: "Calendar", de: "Kalender")
        case .oasis: l.tr(zh: "Oasis", en: "Oasis", de: "Oasis")
        case .plants: l.tr(zh: "植物", en: "Plants", de: "Pflanzen")
        }
    }
}

nonisolated struct VerticalSolidHomePlantSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let subtitle: String
    let emoji: String
    let themeHex: String
    let needsCare: Bool
}

nonisolated struct VerticalSolidHomeSnapshot: @unchecked Sendable {
    var isReady = false
    var greeting = ""
    var activeName = ""
    var coconutText = "0"
    var todayFocus = TodayFocusSnapshot.empty
    var cards: [FocusCard] = []
    var plants: [VerticalSolidHomePlantSnapshot] = []
    var heroPreparationRevision = ""

    static let empty = VerticalSolidHomeSnapshot()
}
