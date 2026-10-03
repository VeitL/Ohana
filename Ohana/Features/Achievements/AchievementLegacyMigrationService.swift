//
//  AchievementLegacyMigrationService.swift
//  Ohana
//
//  Idempotent post-open import of legacy defaults and wallet evidence.
//

import Foundation
import SwiftData

nonisolated struct AchievementLegacyMigrationSummary: Equatable, Sendable {
    let insertedUnlockCount: Int
    let insertedReceiptCount: Int
    let didComplete: Bool
}

@MainActor
enum AchievementLegacyMigrationService {
    static let claimedDefaultsKey = "achievement_claimedRewardIDs"
    private static let markerKey = "achievement.legacy-facts-migration.v1"
    private static let fetchLimit = 20000

    @discardableResult
    static func migrateIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) throws -> AchievementLegacyMigrationSummary {
        guard !defaults.bool(forKey: markerKey) else {
            return AchievementLegacyMigrationSummary(
                insertedUnlockCount: 0,
                insertedReceiptCount: 0,
                didComplete: true
            )
        }
        var ledgerDescriptor = FetchDescriptor<CoconutLedgerEntry>()
        ledgerDescriptor.fetchLimit = fetchLimit
        let achievementLedger = try context.fetch(ledgerDescriptor)
            .filter { $0.transactionKey.hasPrefix("achievement:") }
        var evidenceByKey: [String: CoconutLedgerEntry] = [:]
        for entry in achievementLedger.sorted(by: { $0.occurredAt < $1.occurredAt }) {
            let key = String(entry.transactionKey.dropFirst("achievement:".count))
            // Corrupt or hand-restored legacy stores may contain duplicate
            // transaction keys. The earliest durable ledger entry is enough
            // to prove the historical claim without crashing migration.
            if evidenceByKey[key] == nil {
                evidenceByKey[key] = entry
            }
        }
        let defaultsKeys = defaults.string(forKey: claimedDefaultsKey)?
            .split(separator: ",")
            .map(String.init) ?? []
        let keys = Set(defaultsKeys).union(evidenceByKey.keys)

        let existingUnlockKeys = try Set(context.fetch(FetchDescriptor<AchievementUnlock>()).map(\.achievementKey))
        let existingReceiptKeys = try Set(context.fetch(FetchDescriptor<AchievementRewardReceipt>()).map(\.achievementKey))
        let humanIDs = try Set(context.fetch(FetchDescriptor<Human>()).map { $0.id.uuidString.lowercased() })
        let petIDs = try Set(context.fetch(FetchDescriptor<Pet>()).map { $0.id.uuidString.lowercased() })
        var insertedUnlockCount = 0
        var insertedReceiptCount = 0

        for key in keys.sorted() {
            let evidence = evidenceByKey.removeValue(forKey: key)
            let parsed = parseLegacyKey(key, humanIDs: humanIDs, petIDs: petIDs)
            let unlockedAt = evidence?.occurredAt ?? now
            if !existingUnlockKeys.contains(key) {
                context.insert(
                    AchievementUnlock(
                        achievementKey: key,
                        achievementID: parsed.achievementID,
                        scopeKindRaw: parsed.scope.kind.rawValue,
                        scopeIDRaw: parsed.scope.id,
                        unlockedAt: unlockedAt,
                        isLegacyImport: true,
                        createdAt: now
                    )
                )
                insertedUnlockCount += 1
            }
            guard !existingReceiptKeys.contains(key) else { continue }
            let definitionAmount = AchievementDefinitionCatalog.definition(id: parsed.achievementID)?.reward.coconuts ?? 10
            let awardedAmount = evidence.map { max(0, $0.delta) } ?? definitionAmount
            let recipientID = evidence.flatMap { entry in
                UUID(uuidString: entry.ownerId)?.uuidString
            } ?? ""
            context.insert(
                AchievementRewardReceipt(
                    receiptKey: "achievement-reward:\(key)",
                    achievementKey: key,
                    achievementID: parsed.achievementID,
                    scopeKindRaw: parsed.scope.kind.rawValue,
                    scopeIDRaw: parsed.scope.id,
                    recipientHumanIDRaw: recipientID,
                    claimedAt: evidence?.occurredAt ?? now,
                    awardedCoconutAmount: awardedAmount,
                    awardedStardustAmount: 0,
                    walletTransactionKey: evidence?.transactionKey ?? "achievement:\(key)",
                    isLegacyImport: true,
                    createdAt: now
                )
            )
            insertedReceiptCount += 1
        }

        if insertedUnlockCount > 0 || insertedReceiptCount > 0 {
            let save = context.safeSaveResult(publishFailureEvent: true)
            guard save.didSave else {
                context.rollback()
                throw AchievementProgressionError.persistenceFailed(
                    save.errorDescription ?? "Unable to migrate legacy achievement facts."
                )
            }
        }
        defaults.set(true, forKey: markerKey)
        return AchievementLegacyMigrationSummary(
            insertedUnlockCount: insertedUnlockCount,
            insertedReceiptCount: insertedReceiptCount,
            didComplete: true
        )
    }

    private static func parseLegacyKey(
        _ key: String,
        humanIDs: Set<String>,
        petIDs: Set<String>
    ) -> (achievementID: String, scope: AchievementScopeReference) {
        if key.hasPrefix("global::") {
            return (String(key.dropFirst("global::".count)), .island)
        }
        guard key.count > 37 else {
            let definition = AchievementDefinitionCatalog.definition(id: key)
            let scope = AchievementScopeReference(kind: definition?.scope ?? .legacyUnknown)
            return (key, scope)
        }
        let prefix = String(key.prefix(36))
        let separator = key.index(key.startIndex, offsetBy: 36)
        guard key[separator] == "_", UUID(uuidString: prefix) != nil else {
            return (key, AchievementScopeReference(kind: .legacyUnknown))
        }
        let achievementID = String(key[key.index(after: separator)...])
        if AchievementDefinitionCatalog.definition(id: achievementID)?.scope == .island {
            // Legacy UI attached global reward keys to whichever Pet happened
            // to be selected. Preserve that key verbatim, but make the fact an
            // island fact so it is counted and claimed only once.
            return (achievementID, .island)
        }
        let normalizedID = prefix.lowercased()
        let kind: AchievementScopeKind = if humanIDs.contains(normalizedID) {
            .human
        } else if petIDs.contains(normalizedID) {
            .pet
        } else {
            AchievementDefinitionCatalog.definition(id: achievementID)?.scope ?? .legacyUnknown
        }
        return (
            achievementID,
            AchievementScopeReference(kind: kind, id: prefix)
        )
    }
}
