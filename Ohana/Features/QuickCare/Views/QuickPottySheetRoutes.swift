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
        case .potty: return l.tr(zh: "噗噗", en: "Poop", de: "Häufchen")
        case .scoop: return l.tr(zh: "铲砂", en: "Scoop", de: "Schaufeln")
        case .litter: return l.tr(zh: "猫砂", en: "Litter", de: "Streu")
        }
    }
    var icon: String {
        switch self {
        case .potty: return "seal.fill"
        case .scoop: return "trash.fill"
        case .litter: return "tray.full.fill"
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
            return true
        case .pottyOverview, .scoopOverview, .litterOverview, .pottyHistory, .scoopHistory, .litterHistory, .history:
            return false
        }
    }

    var inlineHeight: CGFloat {
        switch self {
        case .pottyType:
            return 430
        case .scoopCheckIn, .litterChangeCheckIn:
            return 390
        case .scoopSettings, .litterSettings:
            return 560
        case .pottyOverview, .scoopOverview, .litterOverview, .pottyHistory, .scoopHistory, .litterHistory, .history:
            return 720
        }
    }
}
