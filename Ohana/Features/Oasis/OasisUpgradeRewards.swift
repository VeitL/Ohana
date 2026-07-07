//
//  OasisUpgradeRewards.swift
//  Ohana
//
//  Persistent reward layer for Life Tree upgrade coconuts and rare
//  electronic pet milestones.
//

import Foundation
import SwiftData

@MainActor
enum OasisUpgradeRewardService {
    static let maxCritterLevel = 12
    static let maxCritterAppearanceStage = 5
    static let critterXPPerLevel = 300

    static let lifecycleDay: TimeInterval = 86400
    static let lifecycleCareTick: TimeInterval = 21600
    static let needsCareThreshold = 45
    static let atRiskThreshold = 20
    static let sickHealthThreshold = 45
    static let elderWarningDays = 180
    static let oldAgeDeathDays = 210
    static let riskToCriticalHours = 72
    static let criticalToDeathHours = 72

    static func saveRewardChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw OasisRewardPersistenceError.saveFailed(saveResult.errorDescription ?? "Unknown save failure")
        }
    }

    static func saveRewardChangesIfNeeded(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }

    enum OasisRewardPersistenceError: LocalizedError {
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case let .saveFailed(message):
                String(
                    localized: "oasis.reward.persistence.failed",
                    defaultValue: "Unable to save Oasis reward changes: \(message)"
                )
            }
        }
    }
}
