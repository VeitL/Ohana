//
//  CoconutEconomyBootstrapService.swift
//  Ohana
//
//  Imports the legacy coconut projection into the SwiftData wallet once.
//

import Foundation
import SwiftData

@MainActor
enum CoconutEconomyBootstrapService {
    private struct BootstrapPreparation {
        var memberTotal = 0
        var backfilledOpeningEntries: [CoconutLedgerEntry] = []
        var deltas: [CoconutWalletDelta] = []
    }

    static func bootstrapIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        projectionManager: CoconutProjectionManaging? = nil,
        saveChanges: Bool = true,
        updatesProjection: Bool = true
    ) throws {
        try bootstrapIfNeeded(
            context: context,
            legacyIslandCount: defaults.integer(forKey: "quest_coconutCount"),
            legacyLogs: decodeLegacyLogs(defaults: defaults),
            projectionManager: projectionManager,
            saveChanges: saveChanges,
            updatesProjection: updatesProjection
        )
    }

    static func bootstrapIfNeeded(
        context: ModelContext,
        legacyIslandCount: Int,
        legacyLogsJSON: String,
        projectionManager: CoconutProjectionManaging? = nil,
        saveChanges: Bool = true,
        updatesProjection: Bool = true
    ) throws {
        try bootstrapIfNeeded(
            context: context,
            legacyIslandCount: legacyIslandCount,
            legacyLogs: decodeLegacyLogs(json: legacyLogsJSON),
            projectionManager: projectionManager,
            saveChanges: saveChanges,
            updatesProjection: updatesProjection
        )
    }

    private static func bootstrapIfNeeded(
        context: ModelContext,
        legacyIslandCount: Int,
        legacyLogs: [CoconutLogEntry],
        projectionManager: CoconutProjectionManaging?,
        saveChanges: Bool,
        updatesProjection: Bool
    ) throws {
        let legacyAccountKey = CoconutAccountKey.legacySystem
        var legacyDescriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == legacyAccountKey }
        )
        legacyDescriptor.fetchLimit = 1
        if try !context.fetch(legacyDescriptor).isEmpty {
            if updatesProjection {
                CoconutWalletService.refreshQuestProjection(context: context, manager: projectionManager)
            }
            return
        }

        let humans = try context.fetch(FetchDescriptor<Human>()) // smoothness: allow legacy bootstrap lookup
        let pets = try context.fetch(FetchDescriptor<Pet>()) // smoothness: allow legacy bootstrap lookup
        let existingAccounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let existingAccountByKey = Dictionary(
            existingAccounts.map { ($0.accountKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let existingLedgerEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let existingTransactionKeys = Set(existingLedgerEntries.map(\.transactionKey))
        let existingDeltaByAccountKey = Dictionary(
            grouping: existingLedgerEntries.filter(\.affectsBalance),
            by: \.accountKey
        ).mapValues { entries in
            entries.reduce(0) { $0 + $1.delta }
        }
        var preparation = BootstrapPreparation()
        prepareHumanBalances(
            humans,
            existingAccountByKey: existingAccountByKey,
            existingDeltaByAccountKey: existingDeltaByAccountKey,
            existingTransactionKeys: existingTransactionKeys,
            legacyIslandCount: legacyIslandCount,
            preparation: &preparation
        )
        preparePetBalances(
            pets,
            existingAccountByKey: existingAccountByKey,
            existingDeltaByAccountKey: existingDeltaByAccountKey,
            existingTransactionKeys: existingTransactionKeys,
            legacyIslandCount: legacyIslandCount,
            preparation: &preparation
        )

        let systemBalance = max(0, legacyIslandCount - preparation.memberTotal)
        let mismatch = legacyIslandCount < preparation.memberTotal
        preparation.deltas.append(.system(
            delta: systemBalance,
            entryKind: .openingBalance,
            source: .legacyUserDefaults,
            title: "Imported island coconut balance",
            emoji: "🥥",
            metadataJSON: "{\"legacyIslandCount\":\(legacyIslandCount),\"memberTotal\":\(preparation.memberTotal),\"mismatch\":\(mismatch)}",
            transactionKey: "bootstrap:v58:opening:\(CoconutAccountKey.legacySystem)"
        ))

        try CoconutWalletService.apply(
            deltas: preparation.deltas,
            context: context,
            save: false,
            postsRewardFeedback: false,
            updatesProjection: false
        )
        for entry in preparation.backfilledOpeningEntries {
            context.insert(entry)
        }
        CloudSyncMutationRecorder.markModified(preparation.backfilledOpeningEntries, context: context)

        try importLegacyHistory(legacyLogs, humans: humans, pets: pets, context: context)
        if saveChanges {
            try CoconutWalletPersistence.save(context: context)
        }
        if updatesProjection {
            CoconutWalletService.refreshQuestProjection(context: context, manager: projectionManager)
        }
    }

    private static func prepareHumanBalances(
        _ humans: [Human],
        existingAccountByKey: [String: CoconutAccount],
        existingDeltaByAccountKey: [String: Int],
        existingTransactionKeys: Set<String>,
        legacyIslandCount: Int,
        preparation: inout BootstrapPreparation
    ) {
        for human in humans {
            let accountKey = CoconutAccountKey.human(human.id)
            if let existingAccount = existingAccountByKey[accountKey] {
                // A command may legitimately create this wallet before the
                // deferred compatibility bootstrap runs. The model field is
                // then a projection of that account, not an opening balance.
                let legacyBaseline = max(
                    0,
                    existingAccount.balance - (existingDeltaByAccountKey[accountKey] ?? 0)
                )
                preparation.memberTotal += max(0, legacyBaseline)
                backfillOpeningEntryIfNeeded(
                    account: existingAccount,
                    ownerKind: .human,
                    ownerId: human.id.uuidString,
                    ownerName: human.name,
                    legacyBalance: legacyBaseline,
                    legacyIslandCount: legacyIslandCount,
                    occurredAt: human.createdAt,
                    existingTransactionKeys: existingTransactionKeys,
                    preparedEntries: &preparation.backfilledOpeningEntries
                )
                continue
            }
            let originalBalance = human.coconutBalance
            let balance = max(0, originalBalance)
            preparation.memberTotal += balance
            preparation.deltas.append(.human(
                human,
                delta: balance,
                entryKind: .openingBalance,
                source: .legacyUserDefaults,
                title: "Imported coconut balance",
                emoji: "🥥",
                metadataJSON: metadata(originalBalance: originalBalance, legacyIslandCount: legacyIslandCount),
                occurredAt: human.createdAt,
                transactionKey: "bootstrap:v58:opening:\(CoconutAccountKey.human(human.id))"
            ))
            if originalBalance < 0 {
                preparation.deltas.append(negativeAdjustment(
                    ownerKey: CoconutAccountKey.human(human.id),
                    ownerKind: .human,
                    ownerId: human.id.uuidString,
                    ownerName: human.name,
                    originalBalance: originalBalance
                ))
            }
        }
    }

    private static func preparePetBalances(
        _ pets: [Pet],
        existingAccountByKey: [String: CoconutAccount],
        existingDeltaByAccountKey: [String: Int],
        existingTransactionKeys: Set<String>,
        legacyIslandCount: Int,
        preparation: inout BootstrapPreparation
    ) {
        for pet in pets {
            let accountKey = CoconutAccountKey.pet(pet.id)
            if let existingAccount = existingAccountByKey[accountKey] {
                let legacyBaseline = max(
                    0,
                    existingAccount.balance - (existingDeltaByAccountKey[accountKey] ?? 0)
                )
                preparation.memberTotal += max(0, legacyBaseline)
                backfillOpeningEntryIfNeeded(
                    account: existingAccount,
                    ownerKind: .pet,
                    ownerId: pet.id.uuidString,
                    ownerName: pet.name,
                    legacyBalance: legacyBaseline,
                    legacyIslandCount: legacyIslandCount,
                    occurredAt: pet.createdAt,
                    existingTransactionKeys: existingTransactionKeys,
                    preparedEntries: &preparation.backfilledOpeningEntries
                )
                continue
            }
            let originalBalance = pet.coconutBalance
            let balance = max(0, originalBalance)
            preparation.memberTotal += balance
            preparation.deltas.append(.pet(
                pet,
                delta: balance,
                entryKind: .openingBalance,
                source: .legacyUserDefaults,
                title: "Imported coconut balance",
                emoji: "🥥",
                metadataJSON: metadata(originalBalance: originalBalance, legacyIslandCount: legacyIslandCount),
                occurredAt: pet.createdAt,
                transactionKey: "bootstrap:v58:opening:\(CoconutAccountKey.pet(pet.id))"
            ))
            if originalBalance < 0 {
                preparation.deltas.append(negativeAdjustment(
                    ownerKey: CoconutAccountKey.pet(pet.id),
                    ownerKind: .pet,
                    ownerId: pet.id.uuidString,
                    ownerName: pet.name,
                    originalBalance: originalBalance
                ))
            }
        }
    }

    private static func backfillOpeningEntryIfNeeded(
        account: CoconutAccount,
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        ownerName: String,
        legacyBalance: Int,
        legacyIslandCount: Int,
        occurredAt: Date,
        existingTransactionKeys: Set<String>,
        preparedEntries: inout [CoconutLedgerEntry]
    ) {
        guard legacyBalance > 0 else { return }
        let transactionKey = "bootstrap:v58:opening:\(account.accountKey)"
        guard !existingTransactionKeys.contains(transactionKey) else { return }

        let entry = CoconutLedgerEntry(
            transactionKey: transactionKey,
            accountKey: account.accountKey,
            ownerKind: ownerKind,
            ownerId: ownerId,
            ownerName: ownerName,
            delta: legacyBalance,
            balanceBefore: 0,
            balanceAfter: legacyBalance,
            entryKind: .openingBalance,
            source: .legacyUserDefaults,
            title: "Imported coconut balance",
            emoji: "🥥",
            metadataJSON: metadata(
                originalBalance: legacyBalance,
                legacyIslandCount: legacyIslandCount
            ),
            occurredAt: occurredAt
        )
        preparedEntries.append(entry)
    }

    private static func importLegacyHistory(
        _ legacyLogs: [CoconutLogEntry],
        humans: [Human],
        pets: [Pet],
        context: ModelContext
    ) throws {
        let humanById = Dictionary(uniqueKeysWithValues: humans.map { ($0.id.uuidString, $0) })
        let petById = Dictionary(uniqueKeysWithValues: pets.map { ($0.id.uuidString, $0) })
        let accountByKey = Dictionary(uniqueKeysWithValues: fetchOrLog(
            FetchDescriptor<CoconutAccount>(),
            context: context,
            operation: "fetch coconut accounts for legacy history import"
        ).map { ($0.accountKey, $0) })
        var importedEntries: [CoconutLedgerEntry] = []

        for log in legacyLogs.prefix(200) {
            let delta: CoconutWalletDelta = if let actorId = log.actorId, let human = humanById[actorId] {
                .human(
                    human,
                    delta: log.amount,
                    entryKind: .legacyHistory,
                    source: .legacyUserDefaults,
                    title: log.title,
                    emoji: log.emoji,
                    actorId: log.actorId,
                    actorName: log.actorName,
                    metadataJSON: legacyMetadata(log),
                    occurredAt: log.date,
                    transactionKey: "bootstrap:v58:legacyHistory:\(log.id.uuidString)"
                ).nonBalanceAffecting()
            } else if let actorId = log.actorId, let pet = petById[actorId] {
                .pet(
                    pet,
                    delta: log.amount,
                    entryKind: .legacyHistory,
                    source: .legacyUserDefaults,
                    title: log.title,
                    emoji: log.emoji,
                    actorId: log.actorId,
                    actorName: log.actorName,
                    metadataJSON: legacyMetadata(log),
                    occurredAt: log.date,
                    transactionKey: "bootstrap:v58:legacyHistory:\(log.id.uuidString)"
                ).nonBalanceAffecting()
            } else {
                .system(
                    delta: log.amount,
                    entryKind: .legacyHistory,
                    source: .legacyUserDefaults,
                    title: log.title,
                    emoji: log.emoji,
                    actorId: log.actorId,
                    actorName: log.actorName,
                    metadataJSON: legacyMetadata(log),
                    occurredAt: log.date,
                    transactionKey: "bootstrap:v58:legacyHistory:\(log.id.uuidString)",
                    affectsBalance: false
                )
            }
            let account = accountByKey[delta.accountKey]
            let entry = CoconutLedgerEntry(
                transactionKey: delta.transactionKey,
                accountKey: delta.accountKey,
                ownerKind: delta.ownerKind,
                ownerId: delta.ownerId,
                ownerName: delta.ownerName,
                delta: delta.delta,
                balanceBefore: account?.balance ?? 0,
                balanceAfter: account?.balance ?? 0,
                affectsBalance: false,
                entryKind: .legacyHistory,
                source: .legacyUserDefaults,
                title: delta.title,
                emoji: delta.emoji,
                actorId: delta.actorId,
                actorName: delta.actorName,
                metadataJSON: delta.metadataJSON,
                occurredAt: delta.occurredAt
            )
            context.insert(entry)
            importedEntries.append(entry)
        }
        CloudSyncMutationRecorder.markModified(importedEntries, context: context)
    }

    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "CoconutEconomyBootstrapService failed to \(operation): \(error.localizedDescription)",
                category: "Economy"
            )
            return []
        }
    }

    private static func decodeLegacyLogs(defaults: UserDefaults) -> [CoconutLogEntry] {
        if let data = defaults.data(forKey: "quest_coconutLogs"),
           let logs = try? JSONDecoder().decode([CoconutLogEntry].self, from: data) {
            return logs
        }
        if let string = defaults.string(forKey: "coconutLogs"),
           let data = string.data(using: .utf8),
           let logs = try? JSONDecoder().decode([CoconutLogEntry].self, from: data) {
            return logs
        }
        return []
    }

    private static func decodeLegacyLogs(json: String) -> [CoconutLogEntry] {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let logs = try? JSONDecoder().decode([CoconutLogEntry].self, from: data) else {
            return []
        }
        return logs
    }

    private static func metadata(originalBalance: Int, legacyIslandCount: Int) -> String {
        "{\"originalBalance\":\(originalBalance),\"legacyIslandCount\":\(legacyIslandCount)}"
    }

    private static func legacyMetadata(_ log: CoconutLogEntry) -> String {
        "{\"legacyLogId\":\"\(log.id.uuidString)\",\"growthXP\":\(log.growthXP ?? 0)}"
    }

    private static func negativeAdjustment(
        ownerKey: String,
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        ownerName: String,
        originalBalance: Int
    ) -> CoconutWalletDelta {
        CoconutWalletDelta(
            accountKey: ownerKey,
            ownerKind: ownerKind,
            ownerId: ownerId,
            ownerName: ownerName,
            delta: abs(originalBalance),
            entryKind: .adjustment,
            source: .legacyUserDefaults,
            title: "Negative coconut balance normalized",
            metadataJSON: "{\"originalBalance\":\(originalBalance)}",
            transactionKey: "bootstrap:v58:negativeAdjustment:\(ownerKey)",
            affectsBalance: false
        )
    }
}

private extension CoconutWalletDelta {
    func nonBalanceAffecting() -> CoconutWalletDelta {
        var copy = self
        copy.affectsBalance = false
        return copy
    }
}
