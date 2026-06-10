//
//  QuickPottySheetRoutes.swift
//  Ohana
//
//  Focus and sheet route metadata for QuickPottyDetailSheet.
//

import SwiftUI

enum QuickPottyFocus: String, CaseIterable, Identifiable {
    case potty
    case scoop
    case litter

    var id: String { rawValue }
    func title(_ l: L10n) -> String {
        switch self {
        case .potty: l.tr(zh: "噗噗", en: "Poop", de: "Häufchen")
        case .scoop: l.tr(zh: "铲砂", en: "Scoop", de: "Schaufeln")
        case .litter: l.tr(zh: "猫砂", en: "Litter", de: "Streu")
        }
    }

    var icon: String {
        switch self {
        case .potty: "seal.fill"
        case .scoop: "trash.fill"
        case .litter: "tray.full.fill"
        }
    }
}

enum QuickPottyActiveSheet: String, Identifiable {
    case pottyType
    case scoopCheckIn
    case litterChangeCheckIn
    case scoopSettings
    case litterSettings
    case pottyOverview
    case scoopOverview
    case litterOverview
    case pottyHistory
    case scoopHistory
    case litterHistory
    case history

    var id: String { rawValue }

    var usesInlineOverlay: Bool {
        switch self {
        case .pottyType, .scoopCheckIn, .litterChangeCheckIn, .scoopSettings, .litterSettings:
            true
        case .pottyOverview, .scoopOverview, .litterOverview, .pottyHistory, .scoopHistory, .litterHistory, .history:
            false
        }
    }

    var inlineHeight: CGFloat {
        switch self {
        case .pottyType:
            430
        case .scoopCheckIn, .litterChangeCheckIn:
            390
        case .scoopSettings, .litterSettings:
            560
        case .pottyOverview, .scoopOverview, .litterOverview, .pottyHistory, .scoopHistory, .litterHistory, .history:
            720
        }
    }
}
