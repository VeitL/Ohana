//
//  AchievementFacts.swift
//  Ohana
//
//  Durable, local-first achievement unlock and reward receipt facts.
//

import Foundation
import SwiftData

@Model
final class AchievementUnlock {
    #Index<AchievementUnlock>([\.achievementID], [\.scopeKindRaw], [\.scopeIDRaw], [\.unlockedAt])

    var id: UUID
    @Attribute(.unique) var achievementKey: String
    var achievementID: String
    var scopeKindRaw: String
    var scopeIDRaw: String
    var unlockedAt: Date
    var isLegacyImport: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        achievementKey: String,
        achievementID: String,
        scopeKindRaw: String,
        scopeIDRaw: String,
        unlockedAt: Date,
        isLegacyImport: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.achievementKey = achievementKey
        self.achievementID = achievementID
        self.scopeKindRaw = scopeKindRaw
        self.scopeIDRaw = scopeIDRaw
        self.unlockedAt = unlockedAt
        self.isLegacyImport = isLegacyImport
        self.createdAt = createdAt
    }
}

@Model
final class AchievementRewardReceipt {
    #Index<AchievementRewardReceipt>(
        [\.achievementKey],
        [\.achievementID],
        [\.scopeKindRaw],
        [\.scopeIDRaw],
        [\.claimedAt]
    )

    var id: UUID
    @Attribute(.unique) var receiptKey: String
    var achievementKey: String
    var achievementID: String
    var scopeKindRaw: String
    var scopeIDRaw: String
    var recipientHumanIDRaw: String
    var claimedAt: Date
    var awardedCoconutAmount: Int
    var awardedStardustAmount: Int
    var walletTransactionKey: String
    var isLegacyImport: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        receiptKey: String,
        achievementKey: String,
        achievementID: String,
        scopeKindRaw: String,
        scopeIDRaw: String,
        recipientHumanIDRaw: String = "",
        claimedAt: Date,
        awardedCoconutAmount: Int,
        awardedStardustAmount: Int,
        walletTransactionKey: String,
        isLegacyImport: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.receiptKey = receiptKey
        self.achievementKey = achievementKey
        self.achievementID = achievementID
        self.scopeKindRaw = scopeKindRaw
        self.scopeIDRaw = scopeIDRaw
        self.recipientHumanIDRaw = recipientHumanIDRaw
        self.claimedAt = claimedAt
        self.awardedCoconutAmount = awardedCoconutAmount
        self.awardedStardustAmount = awardedStardustAmount
        self.walletTransactionKey = walletTransactionKey
        self.isLegacyImport = isLegacyImport
        self.createdAt = createdAt
    }
}
