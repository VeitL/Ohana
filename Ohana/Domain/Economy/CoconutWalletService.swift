//
//  CoconutWalletService.swift
//  Ohana
//
//  SwiftData-backed coconut wallet write service and legacy bootstrap.
//

import Foundation
import SwiftData

enum CoconutWalletError: LocalizedError {
    case insufficientBalance(accountName: String, missing: Int)
    case duplicateTransaction(String)
    case walletFrozen(accountName: String)

    var errorDescription: String? {
        switch self {
        case let .insufficientBalance(accountName, missing):
            "\(accountName) needs \(missing) more coconuts."
        case let .duplicateTransaction(key):
            "Duplicate coconut wallet transaction: \(key)."
        case let .walletFrozen(accountName):
            "\(accountName)'s coconut wallet is frozen."
        }
    }
}

nonisolated enum CoconutWalletPersistence {
    private enum PersistenceError: LocalizedError {
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case let .saveFailed(message):
                String(
                    localized: "coconut.wallet.persistence.failed",
                    defaultValue: "Unable to save coconut wallet changes: \(message)"
                )
            }
        }
    }

    static func save(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw PersistenceError.saveFailed(saveResult.errorDescription ?? "Unknown save failure")
        }
    }

    static func saveIfNeeded(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }
}

extension CoconutWalletService {
    @MainActor
    static func restoreCachedHumanBalances(_ balances: [UUID: Int], context: ModelContext) {
        guard !balances.isEmpty else { return }
        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? []
        for human in humans {
            if let balance = balances[human.id] {
                human.coconutBalance = balance
            }
        }
    }

    /// Restores in-memory wallet projections after an uncommitted transaction
    /// is rolled back. Persisted balances still roll back through ModelContext;
    /// this keeps the current render pass from observing transient values.
    @MainActor
    static func restoreUncommittedBalances(
        humans: [(model: Human, balance: Int)],
        accounts: [(model: CoconutAccount, balance: Int, updatedAt: Date)]
    ) {
        for snapshot in humans {
            snapshot.model.coconutBalance = snapshot.balance
        }
        for snapshot in accounts {
            snapshot.model.balance = snapshot.balance
            snapshot.model.updatedAt = snapshot.updatedAt
        }
    }
}

struct CoconutWalletReconciliationSummary: Equatable {
    let correctedAccountCount: Int
    let createdAccountCount: Int

    nonisolated var didChange: Bool {
        correctedAccountCount > 0 || createdAccountCount > 0
    }
}

nonisolated enum CoconutWalletAccountLifecycleMetadata {
    private static let deletedOwnerKey = "deletedOwner"

    static func isDeletedOwner(_ account: CoconutAccount) -> Bool {
        boolValue(named: deletedOwnerKey, in: account.metadataJSON) == true
    }

    static func markDeletedOwner(_ account: CoconutAccount, deletedAt: Date) {
        var object = jsonObject(from: account.metadataJSON)
        object[deletedOwnerKey] = true
        object["deletedOwnerAt"] = deletedAt.timeIntervalSince1970
        object["deletedOwnerKind"] = account.ownerKindRaw
        object["deletedOwnerId"] = account.ownerId
        account.metadataJSON = encode(object)
    }

    private static func boolValue(named key: String, in json: String) -> Bool? {
        guard let value = jsonObject(from: json)[key] else { return nil }
        if let bool = value as? Bool { return bool }
        if let string = value as? String { return NSString(string: string).boolValue }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private static func jsonObject(from json: String) -> [String: Any] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func encode(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"deletedOwner":true}"#
        }
        return string
    }
}

struct CoconutWalletDelta {
    var accountKey: String
    var ownerKind: CoconutWalletOwnerKind
    var ownerId: String
    var ownerName: String
    var cachedBalance: Int
    var delta: Int
    var entryKind: CoconutWalletEntryKind
    var source: CoconutWalletSource
    var title: String
    var emoji: String
    var actorId: String?
    var actorName: String?
    var subjectKind: CareLedgerSubjectKind
    var subjectId: String?
    var sourceModelName: String
    var sourceModelId: String
    var careLedgerEventId: String?
    var metadataJSON: String
    var occurredAt: Date
    var transactionKey: String
    var affectsBalance: Bool
    var human: Human?
    var pet: Pet?

    init(
        accountKey: String,
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        ownerName: String,
        cachedBalance: Int = 0,
        delta: Int,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        title: String,
        emoji: String = "🥥",
        actorId: String? = nil,
        actorName: String? = nil,
        subjectKind: CareLedgerSubjectKind = .system,
        subjectId: String? = nil,
        sourceModelName: String = "",
        sourceModelId: String = "",
        careLedgerEventId: String? = nil,
        metadataJSON: String = "",
        occurredAt: Date = Date(),
        transactionKey: String? = nil,
        affectsBalance: Bool = true,
        human: Human? = nil,
        pet: Pet? = nil
    ) {
        self.accountKey = accountKey
        self.ownerKind = ownerKind
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.cachedBalance = cachedBalance
        self.delta = delta
        self.entryKind = entryKind
        self.source = source
        self.title = title
        self.emoji = emoji
        self.actorId = actorId
        self.actorName = actorName
        self.subjectKind = subjectKind
        self.subjectId = subjectId
        self.sourceModelName = sourceModelName
        self.sourceModelId = sourceModelId
        self.careLedgerEventId = careLedgerEventId
        self.metadataJSON = metadataJSON
        self.occurredAt = occurredAt
        self.transactionKey = transactionKey ?? Self.makeTransactionKey(
            source: source,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            accountKey: accountKey,
            occurredAt: occurredAt,
            delta: delta
        )
        self.affectsBalance = affectsBalance
        self.human = human
        self.pet = pet
    }

    static func human(
        _ human: Human,
        delta: Int,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        title: String,
        emoji: String = "🥥",
        actorId: String? = nil,
        actorName: String? = nil,
        subjectKind: CareLedgerSubjectKind = .human,
        subjectId: String? = nil,
        sourceModelName: String = "",
        sourceModelId: String = "",
        careLedgerEventId: String? = nil,
        metadataJSON: String = "",
        occurredAt: Date = Date(),
        transactionKey: String? = nil
    ) -> CoconutWalletDelta {
        CoconutWalletDelta(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            ownerName: human.name,
            cachedBalance: human.coconutBalance,
            delta: delta,
            entryKind: entryKind,
            source: source,
            title: title,
            emoji: emoji,
            actorId: actorId ?? human.id.uuidString,
            actorName: actorName ?? human.name,
            subjectKind: subjectKind,
            subjectId: subjectId ?? human.id.uuidString,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            careLedgerEventId: careLedgerEventId,
            metadataJSON: metadataJSON,
            occurredAt: occurredAt,
            transactionKey: transactionKey,
            human: human
        )
    }

    static func pet(
        _ pet: Pet,
        delta: Int,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        title: String,
        emoji: String = "🥥",
        actorId: String? = nil,
        actorName: String? = nil,
        subjectKind: CareLedgerSubjectKind = .pet,
        subjectId: String? = nil,
        sourceModelName: String = "",
        sourceModelId: String = "",
        careLedgerEventId: String? = nil,
        metadataJSON: String = "",
        occurredAt: Date = Date(),
        transactionKey: String? = nil
    ) -> CoconutWalletDelta {
        CoconutWalletDelta(
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            ownerName: pet.name,
            cachedBalance: pet.coconutBalance,
            delta: delta,
            entryKind: entryKind,
            source: source,
            title: title,
            emoji: emoji,
            actorId: actorId ?? pet.id.uuidString,
            actorName: actorName ?? pet.name,
            subjectKind: subjectKind,
            subjectId: subjectId ?? pet.id.uuidString,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            careLedgerEventId: careLedgerEventId,
            metadataJSON: metadataJSON,
            occurredAt: occurredAt,
            transactionKey: transactionKey,
            pet: pet
        )
    }

    static func island(
        delta: Int,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        title: String,
        emoji: String = "🥥",
        subjectKind: CareLedgerSubjectKind = .household,
        subjectId: String? = nil,
        sourceModelName: String = "",
        sourceModelId: String = "",
        careLedgerEventId: String? = nil,
        metadataJSON: String = "",
        occurredAt: Date = Date(),
        transactionKey: String? = nil,
        affectsBalance: Bool = true
    ) -> CoconutWalletDelta {
        CoconutWalletDelta(
            accountKey: CoconutAccountKey.islandReserve,
            ownerKind: .system,
            ownerId: "island",
            ownerName: "Ohana Island",
            delta: delta,
            entryKind: entryKind,
            source: source,
            title: title,
            emoji: emoji,
            actorId: "system",
            actorName: "Ohana",
            subjectKind: subjectKind,
            subjectId: subjectId,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            careLedgerEventId: careLedgerEventId,
            metadataJSON: metadataJSON,
            occurredAt: occurredAt,
            transactionKey: transactionKey,
            affectsBalance: affectsBalance
        )
    }

    static func system(
        delta: Int,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        title: String,
        emoji: String = "🥥",
        actorId: String? = "system",
        actorName: String? = "System",
        sourceModelName: String = "",
        sourceModelId: String = "",
        metadataJSON: String = "",
        occurredAt: Date = Date(),
        transactionKey: String? = nil,
        affectsBalance: Bool = true
    ) -> CoconutWalletDelta {
        CoconutWalletDelta(
            accountKey: CoconutAccountKey.legacySystem,
            ownerKind: .system,
            ownerId: "",
            ownerName: actorName ?? "System",
            cachedBalance: 0,
            delta: delta,
            entryKind: entryKind,
            source: source,
            title: title,
            emoji: emoji,
            actorId: actorId,
            actorName: actorName,
            sourceModelName: sourceModelName,
            sourceModelId: sourceModelId,
            metadataJSON: metadataJSON,
            occurredAt: occurredAt,
            transactionKey: transactionKey,
            affectsBalance: affectsBalance
        )
    }

    private static func makeTransactionKey(
        source: CoconutWalletSource,
        sourceModelName: String,
        sourceModelId: String,
        accountKey: String,
        occurredAt: Date,
        delta: Int
    ) -> String {
        if !sourceModelName.isEmpty || !sourceModelId.isEmpty {
            return "\(source.rawValue):\(sourceModelName):\(sourceModelId):\(accountKey):\(delta)"
        }
        return "\(source.rawValue):\(accountKey):\(occurredAt.timeIntervalSince1970):\(UUID().uuidString)"
    }
}

@MainActor
enum CoconutWalletService {
    @discardableResult
    static func apply(
        deltas: [CoconutWalletDelta],
        context: ModelContext,
        save: Bool = false,
        postsRewardFeedback: Bool = true,
        updatesProjection: Bool = true,
        projectionManager: CoconutProjectionManaging? = nil
    ) throws -> [CoconutLedgerEntry] {
        let meaningfulDeltas = deltas.filter { $0.delta != 0 || $0.entryKind == .openingBalance || $0.entryKind == .legacyHistory }
        guard !meaningfulDeltas.isEmpty else { return [] }

        let transactionKeys = meaningfulDeltas.map(\.transactionKey).filter { !$0.isEmpty }
        let uniqueTransactionKeys = Set(transactionKeys)
        if uniqueTransactionKeys.count != transactionKeys.count, let duplicateKey = firstDuplicate(in: transactionKeys) {
            throw CoconutWalletError.duplicateTransaction(duplicateKey)
        }

        let duplicateEntries = try existingEntries(for: transactionKeys, context: context)
        if !duplicateEntries.isEmpty {
            let duplicateKeys = Set(duplicateEntries.map(\.transactionKey))
            if duplicateKeys == uniqueTransactionKeys {
                return duplicateEntries
            }
            throw CoconutWalletError.duplicateTransaction(duplicateKeys.sorted().first ?? "")
        }

        var accountsByKey: [String: CoconutAccount] = [:]
        var stagedBalances: [String: Int] = [:]

        for delta in meaningfulDeltas {
            if try isFrozenWrite(delta, context: context) {
                throw CoconutWalletError.walletFrozen(accountName: delta.ownerName)
            }
            let account = try existingAccount(for: delta, context: context, cache: &accountsByKey)
            let initialBalance = account?.balance ?? initialBalance(for: delta)
            let balanceBefore = stagedBalances[delta.accountKey] ?? initialBalance
            let balanceAfter = delta.affectsBalance ? balanceBefore + delta.delta : balanceBefore
            if delta.affectsBalance, balanceAfter < 0 {
                throw CoconutWalletError.insufficientBalance(
                    accountName: delta.ownerName,
                    missing: abs(balanceAfter)
                )
            }
            stagedBalances[delta.accountKey] = balanceAfter
        }

        var runningBalances: [String: Int] = [:]
        var createdEntries: [CoconutLedgerEntry] = []

        for delta in meaningfulDeltas {
            let account = try account(for: delta, context: context, cache: &accountsByKey)
            let balanceBefore = runningBalances[delta.accountKey] ?? account.balance
            let balanceAfter = delta.affectsBalance ? balanceBefore + delta.delta : balanceBefore

            if delta.affectsBalance {
                account.balance = balanceAfter
                account.updatedAt = Date()
                runningBalances[delta.accountKey] = balanceAfter
                syncCache(for: delta, balance: balanceAfter)
            }

            let entry = CoconutLedgerEntry(
                transactionKey: delta.transactionKey,
                accountKey: delta.accountKey,
                ownerKind: delta.ownerKind,
                ownerId: delta.ownerId,
                ownerName: delta.ownerName,
                delta: delta.delta,
                balanceBefore: balanceBefore,
                balanceAfter: balanceAfter,
                affectsBalance: delta.affectsBalance,
                entryKind: delta.entryKind,
                source: delta.source,
                title: delta.title,
                emoji: delta.emoji,
                actorId: delta.actorId,
                actorName: delta.actorName,
                subjectKind: delta.subjectKind,
                subjectId: delta.subjectId,
                sourceModelName: delta.sourceModelName,
                sourceModelId: delta.sourceModelId,
                careLedgerEventId: delta.careLedgerEventId,
                metadataJSON: delta.metadataJSON,
                occurredAt: delta.occurredAt
            )
            context.insert(entry)
            createdEntries.append(entry)
        }
        CloudSyncMutationRecorder.markModified(createdEntries, context: context)

        if save {
            try CoconutWalletPersistence.save(context: context)
        }
        if updatesProjection {
            projectionManager?.recordWalletProjection(
                entries: createdEntries,
                postsRewardFeedback: postsRewardFeedback
            )
        }
        return createdEntries
    }

    @discardableResult
    static func applyActorDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        context: ModelContext,
        save: Bool,
        postsRewardFeedback: Bool = true,
        projectionManager: CoconutProjectionManaging? = nil
    ) throws -> [CoconutLedgerEntry] {
        let delta = try makeActorDelta(
            amount: amount,
            emoji: emoji,
            title: title,
            actorId: actorId,
            actorName: actorName,
            entryKind: entryKind,
            source: source,
            context: context
        )
        return try apply(
            deltas: [delta],
            context: context,
            save: save,
            postsRewardFeedback: postsRewardFeedback,
            updatesProjection: true,
            projectionManager: projectionManager
        )
    }

    static func totalBalance(context: ModelContext) -> Int {
        fetchOrLog(
            FetchDescriptor<CoconutAccount>(),
            context: context,
            operation: "fetch coconut accounts for total balance"
        )
        .filter { isActiveSpendableAccount($0, context: context) }
        .reduce(0) { $0 + $1.balance }
    }

    static func balance(accountKey: String, context: ModelContext, fallback: Int = 0) -> Int {
        var descriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == accountKey }
        )
        descriptor.fetchLimit = 1
        if let account = fetchFirstOrLog(
            descriptor,
            context: context,
            operation: "fetch coconut account balance"
        ) {
            return max(0, account.balance)
        }
        return max(0, fallback)
    }

    static func balance(for human: Human, context: ModelContext) -> Int {
        balance(
            accountKey: CoconutAccountKey.human(human.id),
            context: context,
            fallback: human.coconutBalance
        )
    }

    static func balance(for pet: Pet, context: ModelContext) -> Int {
        balance(
            accountKey: CoconutAccountKey.pet(pet.id),
            context: context,
            fallback: pet.coconutBalance
        )
    }

    static func legacySystemBalance(context: ModelContext, fallback: Int = 0) -> Int {
        balance(
            accountKey: CoconutAccountKey.legacySystem,
            context: context,
            fallback: fallback
        )
    }

    static func recentLogProjection(context: ModelContext, limit: Int = 200) -> [CoconutLogEntry] {
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            sortBy: [SortDescriptor(\CoconutLedgerEntry.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch recent coconut ledger projection"
        )
        .filter { $0.delta != 0 }
        .map { $0.asCoconutLogEntry() }
    }

    static func refreshQuestProjection(context: ModelContext, manager: CoconutProjectionManaging? = nil) {
        _ = reconcileFormalAccountBalancesWithLedger(context: context)
        manager?.replaceCoconutProjection(
            count: totalBalance(context: context),
            logs: recentLogProjection(context: context)
        )
    }

    @discardableResult
    nonisolated static func reconcileFormalAccountBalancesWithLedger(
        context: ModelContext,
        saveChanges: Bool = true
    ) -> CoconutWalletReconciliationSummary {
        let entries = fetchOrLog(
            FetchDescriptor<CoconutLedgerEntry>(),
            context: context,
            operation: "fetch coconut ledger entries for replay reconciliation"
        )
        var replayedBalances: [String: Int] = [:]
        var replayMetadata: [String: CoconutLedgerEntry] = [:]
        for entry in entries where entry.affectsBalance && isActiveSpendableLedgerEntry(entry, context: context) {
            replayedBalances[entry.accountKey, default: 0] += entry.delta
            replayMetadata[entry.accountKey] = entry
        }

        let accounts = fetchOrLog(
            FetchDescriptor<CoconutAccount>(),
            context: context,
            operation: "fetch coconut accounts for replay reconciliation"
        )
        var accountsByKey: [String: CoconutAccount] = [:]
        for account in accounts where accountsByKey[account.accountKey] == nil {
            accountsByKey[account.accountKey] = account
        }

        var correctedCount = 0
        var createdCount = 0
        let now = Date()

        for (accountKey, replayedBalance) in replayedBalances where accountsByKey[accountKey] == nil {
            guard let entry = replayMetadata[accountKey] else { continue }
            let account = CoconutAccount(
                accountKey: accountKey,
                ownerKind: entry.ownerKind,
                ownerId: entry.ownerId,
                displayName: entry.ownerName,
                balance: max(0, replayedBalance),
                createdAt: now,
                updatedAt: now,
                metadataJSON: "{\"createdBy\":\"ledgerReconciliation\"}"
            )
            context.insert(account)
            accountsByKey[accountKey] = account
            createdCount += 1
            syncMemberCache(for: account, balance: account.balance, context: context)
        }

        for account in accounts where isFormalMemberAccount(account.ownerKind) || isIslandReserveAccount(account) {
            guard isActiveSpendableAccount(account, context: context) else {
                if account.balance != 0 {
                    account.balance = 0
                    account.updatedAt = now
                    correctedCount += 1
                }
                continue
            }
            let replayedBalance = max(0, replayedBalances[account.accountKey] ?? 0)
            if account.balance != replayedBalance {
                account.balance = replayedBalance
                account.updatedAt = now
                correctedCount += 1
            }
            if syncMemberCache(for: account, balance: replayedBalance, context: context) {
                correctedCount += 1
            }
        }

        let summary = CoconutWalletReconciliationSummary(
            correctedAccountCount: correctedCount,
            createdAccountCount: createdCount
        )
        if saveChanges && summary.didChange {
            guard CoconutWalletPersistence.saveIfNeeded(context: context) else {
                return .init(correctedAccountCount: 0, createdAccountCount: 0)
            }
        }
        return summary
    }

    private static func makeActorDelta(
        amount: Int,
        emoji: String,
        title: String,
        actorId: String?,
        actorName: String?,
        entryKind: CoconutWalletEntryKind,
        source: CoconutWalletSource,
        context: ModelContext
    ) throws -> CoconutWalletDelta {
        guard let actorId, actorId != "system", let uuid = UUID(uuidString: actorId) else {
            return .system(
                delta: amount,
                entryKind: entryKind,
                source: source,
                title: title,
                emoji: emoji,
                actorId: actorId ?? "system",
                actorName: actorName ?? "System"
            )
        }

        if let human = try fetchHuman(id: uuid, context: context) {
            return .human(
                human,
                delta: amount,
                entryKind: entryKind,
                source: source,
                title: title,
                emoji: emoji,
                actorId: actorId,
                actorName: actorName ?? human.name
            )
        }
        if let pet = try fetchPet(id: uuid, context: context) {
            return .pet(
                pet,
                delta: amount,
                entryKind: entryKind,
                source: source,
                title: title,
                emoji: emoji,
                actorId: actorId,
                actorName: actorName ?? pet.name
            )
        }
        return .system(
            delta: amount,
            entryKind: entryKind,
            source: source,
            title: title,
            emoji: emoji,
            actorId: actorId,
            actorName: actorName
        )
    }

    private static func existingEntries(for transactionKeys: [String], context: ModelContext) throws -> [CoconutLedgerEntry] {
        var existing: [CoconutLedgerEntry] = []
        for key in Set(transactionKeys) where !key.isEmpty {
            var descriptor = FetchDescriptor<CoconutLedgerEntry>(
                predicate: #Predicate<CoconutLedgerEntry> { $0.transactionKey == key }
            )
            descriptor.fetchLimit = 8
            existing += try context.fetch(descriptor)
        }
        return existing
    }

    private static func firstDuplicate(in transactionKeys: [String]) -> String? {
        var seen: Set<String> = []
        for key in transactionKeys where !seen.insert(key).inserted {
            return key
        }
        return nil
    }

    private static func existingAccount(
        for delta: CoconutWalletDelta,
        context: ModelContext,
        cache: inout [String: CoconutAccount]
    ) throws -> CoconutAccount? {
        if let cached = cache[delta.accountKey] {
            return cached
        }
        let key = delta.accountKey
        var descriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == key }
        )
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else {
            return nil
        }
        cache[key] = existing
        return existing
    }

    private static func account(
        for delta: CoconutWalletDelta,
        context: ModelContext,
        cache: inout [String: CoconutAccount]
    ) throws -> CoconutAccount {
        if let cached = cache[delta.accountKey] {
            return cached
        }
        let key = delta.accountKey
        var descriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            cache[key] = existing
            return existing
        }

        let initialBalance = initialBalance(for: delta)
        let account = CoconutAccount(
            accountKey: delta.accountKey,
            ownerKind: delta.ownerKind,
            ownerId: delta.ownerId,
            displayName: delta.ownerName,
            balance: initialBalance,
            metadataJSON: delta.metadataJSON.isEmpty ? "{\"createdBy\":\"walletService\"}" : delta.metadataJSON
        )
        context.insert(account)
        cache[key] = account
        return account
    }

    private static func initialBalance(for delta: CoconutWalletDelta) -> Int {
        delta.entryKind == .openingBalance ? 0 : max(0, delta.cachedBalance)
    }

    private static func isFrozenWrite(_ delta: CoconutWalletDelta, context: ModelContext) throws -> Bool {
        guard delta.affectsBalance,
              delta.entryKind != .openingBalance,
              delta.entryKind != .legacyHistory else {
            return false
        }
        switch delta.ownerKind {
        case .human:
            if let human = delta.human {
                return !EconomyWalletWritePolicy.canWrite(human)
            }
            guard let id = resolvedOwnerId(for: delta),
                  let human = try fetchHuman(id: id, context: context) else {
                return true
            }
            return !EconomyWalletWritePolicy.canWrite(human)
        case .pet:
            if let pet = delta.pet {
                return !EconomyWalletWritePolicy.canWrite(pet)
            }
            guard let id = resolvedOwnerId(for: delta),
                  let pet = try fetchPet(id: id, context: context) else {
                return true
            }
            return !EconomyWalletWritePolicy.canWrite(pet)
        case .system:
            return false
        }
    }

    private static func resolvedOwnerId(for delta: CoconutWalletDelta) -> UUID? {
        if let id = UUID(uuidString: delta.ownerId.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return id
        }

        let prefix: String
        switch delta.ownerKind {
        case .human:
            prefix = "human:"
        case .pet:
            prefix = "pet:"
        case .system:
            return nil
        }

        guard delta.accountKey.hasPrefix(prefix) else {
            return nil
        }
        return UUID(uuidString: String(delta.accountKey.dropFirst(prefix.count)))
    }

    private static func syncCache(for delta: CoconutWalletDelta, balance: Int) {
        switch delta.ownerKind {
        case .human:
            delta.human?.coconutBalance = balance
        case .pet:
            delta.pet?.coconutBalance = balance
        case .system:
            break
        }
    }

    private nonisolated static func isFormalMemberAccount(_ ownerKind: CoconutWalletOwnerKind) -> Bool {
        switch ownerKind {
        case .human, .pet:
            true
        case .system:
            false
        }
    }

    private nonisolated static func isIslandReserveAccount(_ account: CoconutAccount) -> Bool {
        account.ownerKind == .system && account.accountKey == CoconutAccountKey.islandReserve
    }

    private nonisolated static func isIslandReserveLedgerEntry(_ entry: CoconutLedgerEntry) -> Bool {
        entry.ownerKind == .system && entry.accountKey == CoconutAccountKey.islandReserve
    }

    private nonisolated static func isActiveSpendableAccount(_ account: CoconutAccount, context: ModelContext) -> Bool {
        isIslandReserveAccount(account) || isActiveFormalMemberAccount(account, context: context)
    }

    private nonisolated static func isActiveSpendableLedgerEntry(_ entry: CoconutLedgerEntry, context: ModelContext) -> Bool {
        isIslandReserveLedgerEntry(entry) || isActiveFormalMemberLedgerEntry(entry, context: context)
    }

    private nonisolated static func isActiveFormalMemberAccount(_ account: CoconutAccount, context: ModelContext) -> Bool {
        guard isFormalMemberAccount(account.ownerKind),
              !CoconutWalletAccountLifecycleMetadata.isDeletedOwner(account),
              let id = UUID(uuidString: account.ownerId) else {
            return false
        }
        do {
            switch account.ownerKind {
            case .human:
                return try fetchHuman(id: id, context: context) != nil
            case .pet:
                return try fetchPet(id: id, context: context) != nil
            case .system:
                return false
            }
        } catch {
            OhanaLog.warning(
                "CoconutWalletService failed to verify wallet owner during active-account check: \(error.localizedDescription)",
                category: "Economy"
            )
            return false
        }
    }

    private nonisolated static func isActiveFormalMemberLedgerEntry(_ entry: CoconutLedgerEntry, context: ModelContext) -> Bool {
        guard isFormalMemberAccount(entry.ownerKind),
              let id = UUID(uuidString: entry.ownerId) else {
            return false
        }
        do {
            switch entry.ownerKind {
            case .human:
                return try fetchHuman(id: id, context: context) != nil
            case .pet:
                return try fetchPet(id: id, context: context) != nil
            case .system:
                return false
            }
        } catch {
            OhanaLog.warning(
                "CoconutWalletService failed to verify wallet owner during ledger replay: \(error.localizedDescription)",
                category: "Economy"
            )
            return false
        }
    }

    @discardableResult
    private nonisolated static func syncMemberCache(for account: CoconutAccount, balance: Int, context: ModelContext) -> Bool {
        guard let id = UUID(uuidString: account.ownerId) else { return false }
        do {
            switch account.ownerKind {
            case .human:
                guard let human = try fetchHuman(id: id, context: context), human.coconutBalance != balance else {
                    return false
                }
                human.coconutBalance = balance
                return true
            case .pet:
                guard let pet = try fetchPet(id: id, context: context), pet.coconutBalance != balance else {
                    return false
                }
                pet.coconutBalance = balance
                return true
            case .system:
                return false
            }
        } catch {
            OhanaLog.warning(
                "CoconutWalletService failed to sync member cache during reconciliation: \(error.localizedDescription)",
                category: "Economy"
            )
            return false
        }
    }

    private nonisolated static func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private nonisolated static func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchFirstOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> T? {
        fetchOrLog(descriptor, context: context, operation: operation).first
    }

    private nonisolated static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "CoconutWalletService failed to \(operation): \(error.localizedDescription)",
                category: "Economy"
            )
            return []
        }
    }
}
