//
//  HomeV2Models.swift
//  Ohana
//
//  Value snapshots and commands for the rebuilt home surface.
//

import Foundation
import SwiftUI

enum HomeV2Tab: String, CaseIterable, Identifiable, Hashable {
    case home
    case calendar
    case oasis
    case plants

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

enum HomeV2QuickAction: CaseIterable, Identifiable {
    case feed
    case water
    case potty
    case play

    var id: String { String(describing: self) }

    var icon: String {
        switch self {
        case .feed: return "fork.knife"
        case .water: return "drop.fill"
        case .potty: return "tray.full.fill"
        case .play: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .feed: return Color.goOrange
        case .water: return Color.goTeal
        case .potty: return Color.goBlue
        case .play: return Color.goPrimary
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .feed: return l.tr(zh: "喂食", en: "Feed", de: "Füttern")
        case .water: return l.tr(zh: "喂水", en: "Water", de: "Wasser")
        case .potty: return l.tr(zh: "便便", en: "Potty", de: "Toilette")
        case .play: return l.tr(zh: "玩耍", en: "Play", de: "Spiel")
        }
    }
}

enum HomeV2QuickRoute: Identifiable {
    case feed(UUID, opensManualSheetOnAppear: Bool)
    case water(UUID)
    case potty(UUID)
    case play(UUID)

    var id: String {
        switch self {
        case let .feed(id, opensManualSheetOnAppear):
            return "feed-\(id.uuidString)-\(opensManualSheetOnAppear ? "quick" : "detail")"
        case let .water(id): return "water-\(id.uuidString)"
        case let .potty(id): return "potty-\(id.uuidString)"
        case let .play(id): return "play-\(id.uuidString)"
        }
    }
}

struct HomeV2PlantSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    let subtitle: String
    let emoji: String
    let themeHex: String
    let needsCare: Bool
}

struct HomeV2Snapshot {
    var isReady = false
    var greeting = ""
    var activeName = ""
    var coconutText = "0"
    var todayFocus = TodayFocusSnapshot.empty
    var cards: [FocusCard] = []
    var plants: [HomeV2PlantSnapshot] = []

    static let empty = HomeV2Snapshot()
}
