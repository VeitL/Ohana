//
//  AchievementFactRehydrateWriter.swift
//  Ohana
//
//  Fact-only backup restore. This writer never invokes reward commands.
//

import Foundation
import SwiftData

nonisolated enum AchievementFactRehydrateWriter {
    static func upsertUnlock(
        _ dto: AchievementUnlockBackup,
        context: ModelContext,
        iso: ISO8601DateFormatter
    ) throws {
        guard let unlockedAt = iso.date(from: dto.unlockedAt),
              let createdAt = iso.date(from: dto.createdAt) else {
            throw BackupError.invalidRestoreData(.date)
        }
        let key = dto.achievementKey
        var descriptor = FetchDescriptor<AchievementUnlock>(
            predicate: #Predicate { $0.achievementKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.unlockedAt = min(existing.unlockedAt, unlockedAt)
            existing.isLegacyImport = existing.isLegacyImport || dto.isLegacyImport
            return
        }
        context.insert(
            AchievementUnlock(
                id: UUID(uuidString: dto.id) ?? UUID(),
                achievementKey: key,
                achievementID: dto.achievementID,
                scopeKindRaw: dto.scopeKindRaw,
                scopeIDRaw: dto.scopeIDRaw,
                unlockedAt: unlockedAt,
                isLegacyImport: dto.isLegacyImport,
                createdAt: createdAt
            )
        )
    }

    static func upsertReceipt(
        _ dto: AchievementRewardReceiptBackup,
        context: ModelContext,
        iso: ISO8601DateFormatter
    ) throws {
        guard let claimedAt = iso.date(from: dto.claimedAt),
              let createdAt = iso.date(from: dto.createdAt) else {
            throw BackupError.invalidRestoreData(.date)
        }
        let key = dto.achievementKey
        let receiptKey = dto.receiptKey
        var descriptor = FetchDescriptor<AchievementRewardReceipt>(
            predicate: #Predicate { receipt in
                receipt.receiptKey == receiptKey || receipt.achievementKey == key
            }
        )
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }
        context.insert(
            AchievementRewardReceipt(
                id: UUID(uuidString: dto.id) ?? UUID(),
                receiptKey: receiptKey,
                achievementKey: key,
                achievementID: dto.achievementID,
                scopeKindRaw: dto.scopeKindRaw,
                scopeIDRaw: dto.scopeIDRaw,
                recipientHumanIDRaw: dto.recipientHumanIDRaw,
                claimedAt: claimedAt,
                awardedCoconutAmount: max(0, dto.awardedCoconutAmount),
                awardedStardustAmount: max(0, dto.awardedStardustAmount),
                walletTransactionKey: dto.walletTransactionKey,
                isLegacyImport: dto.isLegacyImport,
                createdAt: createdAt
            )
        )
    }
}
