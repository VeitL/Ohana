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
        case .home: return 0
        case .calendar: return 1
        case .oasis: return 2
        case .plants: return 3
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .calendar: return "calendar"
        case .oasis: return "tree.fill"
        case .plants: return "leaf.fill"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .home: return l.tr(zh: "首页", en: "Home", de: "Home")
        case .calendar: return l.tr(zh: "日历", en: "Calendar", de: "Kalender")
        case .oasis: return l.tr(zh: "Oasis", en: "Oasis", de: "Oasis")
        case .plants: return l.tr(zh: "植物", en: "Plants", de: "Pflanzen")
        }
    }
}

struct VerticalSolidHomePlantSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    let subtitle: String
    let emoji: String
    let themeHex: String
    let needsCare: Bool
}

struct VerticalSolidHomeSnapshot {
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
