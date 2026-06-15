//
//  CoconutProjectionManaging.swift
//  Ohana
//

import Foundation

struct CoconutLogEntry: Codable, Identifiable {
    let id: UUID
    let emoji: String
    let title: String
    let amount: Int
    let date: Date
    var actorId: String?
    var actorName: String?
    var growthXP: Int?
    var economyReason: String?
    var budgetStage: String?
    var feedbackMessage: String?

    init(
        id: UUID = UUID(),
        emoji: String,
        title: String,
        amount: Int,
        date: Date = Date(),
        actorId: String? = nil,
        actorName: String? = nil,
        growthXP: Int? = nil,
        economyReason: String? = nil,
        budgetStage: String? = nil,
        feedbackMessage: String? = nil
    ) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.amount = amount
        self.date = date
        self.actorId = actorId
        self.actorName = actorName
        self.growthXP = growthXP
        self.economyReason = economyReason
        self.budgetStage = budgetStage
        self.feedbackMessage = feedbackMessage
    }
}

struct CoconutLedgerAudit: Equatable {
    let islandCount: Int
    let rollingLogDelta: Int
    let petAccountTotal: Int
    let humanAccountTotal: Int
    let rollingLogReconciles: Bool?
    let hasNegativeAccount: Bool

    var isHealthy: Bool {
        islandCount >= 0 && !hasNegativeAccount && (rollingLogReconciles ?? true)
    }

    static func evaluate(
        islandCount: Int,
        logs: [CoconutLogEntry],
        petBalances: [Int],
        humanBalances: [Int],
        maxRollingLogCount: Int = 200
    ) -> CoconutLedgerAudit {
        let logDelta = logs.reduce(0) { $0 + $1.amount }
        let canUseRollingLogs = logs.count < maxRollingLogCount
        return CoconutLedgerAudit(
            islandCount: islandCount,
            rollingLogDelta: logDelta,
            petAccountTotal: petBalances.reduce(0, +),
            humanAccountTotal: humanBalances.reduce(0, +),
            rollingLogReconciles: canUseRollingLogs ? logDelta == islandCount : nil,
            hasNegativeAccount: petBalances.contains(where: { $0 < 0 }) || humanBalances.contains(where: { $0 < 0 })
        )
    }
}

protocol CoconutProjectionManaging: AnyObject {
    func replaceCoconutProjection(count: Int, logs: [CoconutLogEntry])
    func recordWalletProjection(entries: [CoconutLedgerEntry], postsRewardFeedback: Bool)
}
