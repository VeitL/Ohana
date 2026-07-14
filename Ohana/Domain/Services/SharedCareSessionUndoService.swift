//
//  SharedCareSessionUndoService.swift
//  Ohana
//
//  Explicit one-shot undo for a real-world shared-care operation.
//

import Foundation
import SwiftData

nonisolated struct SharedCareUndoToken: Equatable, Hashable, Sendable {
    let sessionID: UUID
    let sourcePetID: UUID
    let receiptID: UUID?
    let undoDeadline: Date?

    init(
        sessionID: UUID,
        sourcePetID: UUID,
        receiptID: UUID? = nil,
        undoDeadline: Date? = nil
    ) {
        self.sessionID = sessionID
        self.sourcePetID = sourcePetID
        self.receiptID = receiptID
        self.undoDeadline = undoDeadline
    }
}

nonisolated enum SharedCareUndoDisposition: String, Equatable, Sendable {
    case undone
    case alreadyUndone
    case notFound
}

nonisolated struct SharedCareUndoResult: Equatable, Sendable {
    let token: SharedCareUndoToken
    let disposition: SharedCareUndoDisposition
    let targetPetIDs: [UUID]
    let deletedCareLogIDs: [UUID]
    let deletedLedgerEventIDs: [UUID]
    let reversalWalletEntryIDs: [UUID]
    let deletedBudgetUsageIDs: [UUID]

    var didUndo: Bool { disposition == .undone }
}

enum SharedCareSessionUndoError: LocalizedError, Equatable {
    case invalidUndoToken
    case undoWindowExpired
    case unsupportedActionKind(String)
    case missingRewardTrace
    case walletReversalFailed(String)
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidUndoToken:
            L10n().tr(
                zh: "撤销信息与共同照护记录不匹配。",
                en: "The undo token does not match the shared care record.",
                de: "Die Rückgängig-Information passt nicht zum gemeinsamen Pflegeeintrag."
            )
        case .undoWindowExpired:
            L10n().tr(
                zh: "撤销时间已结束，照顾记录正在结算。",
                en: "The undo window has ended and the care record is being finalized.",
                de: "Das Rückgängig-Fenster ist abgelaufen; der Pflegeeintrag wird abgeschlossen."
            )
        case let .unsupportedActionKind(actionKind):
            L10n().tr(
                zh: "这类共同照护暂不支持安全撤销（\(actionKind)）。",
                en: "This shared care action cannot be safely undone yet (\(actionKind)).",
                de: "Diese gemeinsame Pflegeaktion kann noch nicht sicher rückgängig gemacht werden (\(actionKind))."
            )
        case .missingRewardTrace:
            L10n().tr(
                zh: "这条共同照护记录缺少可安全回滚的奖励信息。",
                en: "This shared care record is missing the reward trace required for a safe undo.",
                de: "Für diesen gemeinsamen Pflegeeintrag fehlen die Belohnungsdaten für ein sicheres Rückgängigmachen."
            )
        case let .walletReversalFailed(reason):
            L10n().tr(
                zh: "奖励回滚失败：\(reason)",
                en: "Failed to reverse the reward: \(reason)",
                de: "Belohnung konnte nicht rückgängig gemacht werden: \(reason)"
            )
        case let .persistenceFailed(reason):
            L10n().tr(
                zh: "撤销保存失败：\(reason)",
                en: "Unable to save the undo: \(reason)",
                de: "Rückgängig konnte nicht gespeichert werden: \(reason)"
            )
        }
    }
}

@MainActor
enum SharedCareSessionUndoService {
    private static let walletSourceModelName = "SharedCareUndo"

    private struct EconomyTrace {
        let walletEntryIDs: [UUID]
        let budgetUsageIDs: [UUID]
        let hasMalformedValues: Bool
    }

    private struct RewardEvidence {
        let coconutDelta: Int
        let growthXP: Int
        let luckyCoconuts: Int
        let actionKey: String

        var requiresWalletTrace: Bool { coconutDelta > 0 }
        var requiresBudgetTrace: Bool { growthXP > 0 || coconutDelta > 0 || luckyCoconuts > 0 }
    }

    private struct UndoPlan {
        let targetPetIDs: [UUID]
        let walletEntries: [CoconutLedgerEntry]
        let budgetUsages: [EconomyBudgetUsageEvent]
        let budgetUsageIDs: [UUID]
        let budgetDefaultsReversals: [EconomyBudgetUsageDefaultsReversal]
    }

    static func undo(
        _ token: SharedCareUndoToken,
        context: ModelContext,
        undoneByHumanId: String? = nil,
        undoneAt: Date = Date()
    ) throws -> SharedCareUndoResult {
        if token.receiptID != nil {
            return try undoPending(
                token,
                context: context,
                undoneAt: undoneAt
            )
        }
        guard let session = try fetchSession(id: token.sessionID, context: context) else {
            return try completedResultIfPresent(token: token, context: context)
        }
        let plan = try makePlan(token: token, session: session, context: context)
        let reversals = try reverseWallet(plan.walletEntries, token: token, occurredAt: undoneAt, context: context)
        stageBudgetUsageDeletion(
            plan.budgetUsages,
            deletedByHumanId: undoneByHumanId,
            deletedAt: undoneAt,
            context: context
        )
        let deletion = try SharedCareSessionMaintenance.deleteCascade(
            session,
            context: context,
            deletedByHumanId: undoneByHumanId,
            deletedAt: undoneAt
        )
        EconomyDailyBudgetStore.reverseDefaults(plan.budgetDefaultsReversals)
        return result(
            token: token,
            plan: plan,
            deletion: deletion,
            reversalEntryIDs: reversals.map(\.id)
        )
    }

    private static func undoPending(
        _ token: SharedCareUndoToken,
        context: ModelContext,
        undoneAt: Date
    ) throws -> SharedCareUndoResult {
        guard let receiptID = token.receiptID,
              let receipt = try fetchReceipt(id: receiptID, context: context) else {
            return SharedCareUndoResult(
                token: token,
                disposition: .notFound,
                targetPetIDs: [],
                deletedCareLogIDs: [],
                deletedLedgerEventIDs: [],
                reversalWalletEntryIDs: [],
                deletedBudgetUsageIDs: []
            )
        }
        if receipt.state == .undone {
            return SharedCareUndoResult(
                token: token,
                disposition: .alreadyUndone,
                targetPetIDs: receipt.targetPetIds,
                deletedCareLogIDs: [],
                deletedLedgerEventIDs: [],
                reversalWalletEntryIDs: [],
                deletedBudgetUsageIDs: []
            )
        }
        guard receipt.state == .pendingUndo,
              undoneAt < receipt.undoDeadline else {
            throw SharedCareSessionUndoError.undoWindowExpired
        }
        guard receipt.sharedSessionId == token.sessionID,
              receipt.sourcePetId == token.sourcePetID,
              receipt.actionKind == .litterScoop else {
            throw SharedCareSessionUndoError.invalidUndoToken
        }

        let careLogs = SharedCareSessionMaintenance.fetchCareLogs(
            sessionID: token.sessionID.uuidString,
            context: context
        )
        let session = try fetchSession(id: token.sessionID, context: context)
        careLogs.forEach { context.delete($0) }
        if let session { context.delete(session) }
        receipt.state = .undone
        receipt.undoneAt = undoneAt
        receipt.lastError = nil
        receipt.nextRetryAt = nil
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw SharedCareSessionUndoError.persistenceFailed(
                saveResult.errorDescription ?? "Unknown persistence error"
            )
        }
        return SharedCareUndoResult(
            token: token,
            disposition: .undone,
            targetPetIDs: receipt.targetPetIds,
            deletedCareLogIDs: careLogs.map(\.id),
            deletedLedgerEventIDs: [],
            reversalWalletEntryIDs: [],
            deletedBudgetUsageIDs: []
        )
    }

    private static func makePlan(
        token: SharedCareUndoToken,
        session: SharedCareSession,
        context: ModelContext
    ) throws -> UndoPlan {
        guard session.actionKind == .litterScoop else {
            throw SharedCareSessionUndoError.unsupportedActionKind(session.actionKindRaw)
        }
        let targetPetIDs = session.targetPetIds.compactMap(UUID.init(uuidString:))
        guard session.sourcePetId == token.sourcePetID.uuidString || targetPetIDs.contains(token.sourcePetID) else {
            throw SharedCareSessionUndoError.invalidUndoToken
        }
        let ledgers = ledgers(session: session, context: context)
        let trace = economyTrace(ledgers: ledgers)
        let rewardEvidence = try rewardEvidence(session: session, ledgers: ledgers, trace: trace)
        let walletEntries = try fetchWalletEntries(ids: trace.walletEntryIDs, context: context)
        let budgetUsages = try fetchBudgetUsageEvents(ids: trace.budgetUsageIDs, context: context)
        try validateExactTrace(
            rewardEvidence,
            trace: trace,
            walletEntries: walletEntries,
            budgetUsages: budgetUsages
        )
        return UndoPlan(
            targetPetIDs: targetPetIDs,
            walletEntries: walletEntries,
            budgetUsages: budgetUsages,
            budgetUsageIDs: budgetUsages.map(\.id),
            budgetDefaultsReversals: budgetUsages.map(EconomyBudgetUsageDefaultsReversal.init)
        )
    }

    private static func ledgers(session: SharedCareSession, context: ModelContext) -> [CareLedgerEvent] {
        let sessionID = session.id.uuidString
        return SharedCareSessionMaintenance.ledgerEvents(
            careLogs: SharedCareSessionMaintenance.fetchCareLogs(sessionID: sessionID, context: context),
            pottyLogs: SharedCareSessionMaintenance.fetchPottyLogs(sessionID: sessionID, context: context),
            hygieneLogs: SharedCareSessionMaintenance.fetchHygieneLogs(session: session, context: context),
            expenseLogs: SharedCareSessionMaintenance.fetchExpenseLogs(sessionID: sessionID, context: context),
            walkLogs: SharedCareSessionMaintenance.fetchWalkLogs(sessionID: sessionID, context: context),
            context: context
        )
    }

    private static func reverseWallet(
        _ entries: [CoconutLedgerEntry],
        token: SharedCareUndoToken,
        occurredAt: Date,
        context: ModelContext
    ) throws -> [CoconutLedgerEntry] {
        do {
            return try CoconutWalletService.apply(
                deltas: entries.map { undoWalletDelta(original: $0, token: token, occurredAt: occurredAt, context: context) },
                context: context,
                save: false,
                postsRewardFeedback: false,
                updatesProjection: false
            )
        } catch {
            context.rollback()
            throw SharedCareSessionUndoError.walletReversalFailed(error.localizedDescription)
        }
    }

    private static func stageBudgetUsageDeletion(
        _ usages: [EconomyBudgetUsageEvent],
        deletedByHumanId: String?,
        deletedAt: Date,
        context: ModelContext
    ) {
        for usage in usages {
            CloudSyncMutationRecorder.markDeleted(
                usage,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
            context.delete(usage)
        }
    }

    private static func result(
        token: SharedCareUndoToken,
        plan: UndoPlan,
        deletion: SharedCareSessionDeleteResult,
        reversalEntryIDs: [UUID]
    ) -> SharedCareUndoResult {
        SharedCareUndoResult(
            token: token,
            disposition: .undone,
            targetPetIDs: plan.targetPetIDs,
            deletedCareLogIDs: deletion.careLogIDs,
            deletedLedgerEventIDs: deletion.ledgerEventIDs,
            reversalWalletEntryIDs: reversalEntryIDs,
            deletedBudgetUsageIDs: plan.budgetUsageIDs
        )
    }

    private static func completedResultIfPresent(
        token: SharedCareUndoToken,
        context: ModelContext
    ) throws -> SharedCareUndoResult {
        let reversals = try undoWalletEntries(sessionID: token.sessionID, context: context)
        let state = try CloudSyncMetadataService.state(
            entityName: String(describing: SharedCareSession.self),
            localRecordId: token.sessionID,
            context: context
        )
        let disposition: SharedCareUndoDisposition = reversals.isEmpty && state?.isDeletionTombstone != true
            ? .notFound
            : .alreadyUndone
        return SharedCareUndoResult(
            token: token,
            disposition: disposition,
            targetPetIDs: [],
            deletedCareLogIDs: [],
            deletedLedgerEventIDs: [],
            reversalWalletEntryIDs: reversals.map(\.id),
            deletedBudgetUsageIDs: []
        )
    }

    private static func economyTrace(ledgers: [CareLedgerEvent]) -> EconomyTrace {
        var walletEntryIDs = Set<UUID>()
        var budgetUsageIDs = Set<UUID>()
        var hasMalformedValues = false
        for ledger in ledgers {
            let walletIDs = uuidArray(named: "walletEntryIds", in: ledger.metadataJSON)
            let budgetIDs = uuidArray(named: "budgetUsageIds", in: ledger.metadataJSON)
            walletEntryIDs.formUnion(walletIDs.ids)
            budgetUsageIDs.formUnion(budgetIDs.ids)
            hasMalformedValues = hasMalformedValues || walletIDs.isMalformed || budgetIDs.isMalformed
        }
        return EconomyTrace(
            walletEntryIDs: walletEntryIDs.sorted { $0.uuidString < $1.uuidString },
            budgetUsageIDs: budgetUsageIDs.sorted { $0.uuidString < $1.uuidString },
            hasMalformedValues: hasMalformedValues
        )
    }

    private static func rewardEvidence(
        session _: SharedCareSession,
        ledgers: [CareLedgerEvent],
        trace: EconomyTrace
    ) throws -> RewardEvidence {
        let rewardObjects = ledgers.compactMap { ledger -> [String: Any]? in
            guard let object = jsonObject(in: ledger.metadataJSON), isRewardMetadata(object) else { return nil }
            return object
        }
        // A litter-scoop session is written through a reward-bearing command. Without its one
        // canonical reward projection, an older or damaged row cannot be safely reversed.
        guard rewardObjects.count == 1, !trace.hasMalformedValues,
              !ledgers.contains(where: { nonEmpty($0.rewardLogId) != nil }) else {
            throw SharedCareSessionUndoError.missingRewardTrace
        }
        let object = rewardObjects[0]
        let metadataCoconuts = max(0, intValue(named: "humanCoconuts", in: object))
            + max(0, intValue(named: "petCoconuts", in: object))
        let ledgerCoconuts = ledgers.reduce(0) { $0 + max(0, $1.coconutDelta) }
        guard metadataCoconuts == 0 || ledgerCoconuts == 0 || metadataCoconuts == ledgerCoconuts else {
            throw SharedCareSessionUndoError.missingRewardTrace
        }
        return RewardEvidence(
            coconutDelta: max(metadataCoconuts, ledgerCoconuts),
            growthXP: max(0, intValue(named: "growthXP", in: object)),
            luckyCoconuts: max(0, intValue(named: "luckyCoconuts", in: object)),
            actionKey: stringValue(named: "actionKey", in: object)
        )
    }

    private static func validateExactTrace(
        _ evidence: RewardEvidence,
        trace: EconomyTrace,
        walletEntries: [CoconutLedgerEntry],
        budgetUsages: [EconomyBudgetUsageEvent]
    ) throws {
        guard walletEntries.count == trace.walletEntryIDs.count,
              budgetUsages.count == trace.budgetUsageIDs.count,
              evidence.requiresWalletTrace == !walletEntries.isEmpty,
              evidence.requiresBudgetTrace == !budgetUsages.isEmpty else {
            throw SharedCareSessionUndoError.missingRewardTrace
        }
        if evidence.requiresWalletTrace {
            guard walletEntries.allSatisfy({ entry in
                entry.affectsBalance && entry.delta > 0 && entry.entryKind == .reward && entry.source == .careEvent
            }), walletEntries.reduce(0, { $0 + $1.delta }) == evidence.coconutDelta else {
                throw SharedCareSessionUndoError.missingRewardTrace
            }
        }
        guard validateBudgetUsages(budgetUsages, evidence: evidence) else {
            throw SharedCareSessionUndoError.missingRewardTrace
        }
    }

    private static func validateBudgetUsages(
        _ usages: [EconomyBudgetUsageEvent],
        evidence: RewardEvidence
    ) -> Bool {
        guard evidence.requiresBudgetTrace else { return usages.isEmpty }
        guard usages.allSatisfy({ usage in
            usage.source == "economyReward"
                && (evidence.actionKey.isEmpty || usage.actionKey == evidence.actionKey)
        }) else { return false }
        let household = usages.filter { $0.scope == .household }
        let member = usages.filter { $0.scope == .member }
        let careObjects = usages.filter { $0.scope == .careObject }
        return household.count == 1
            && member.count == 1
            && sum(household, \.growthXPUsed) == evidence.growthXP
            && sum(household, \.coconutUsed) == evidence.coconutDelta
            && sum(household, \.luckyCoconutUsed) == evidence.luckyCoconuts
            && sum(member, \.growthXPUsed) == evidence.growthXP
            && sum(member, \.coconutUsed) == evidence.coconutDelta
            && sum(careObjects, \.growthXPUsed) == evidence.growthXP
            && sum(careObjects, \.coconutUsed) == evidence.coconutDelta
    }

    private static func sum(
        _ usages: [EconomyBudgetUsageEvent],
        _ keyPath: KeyPath<EconomyBudgetUsageEvent, Int>
    ) -> Int {
        usages.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    private struct ParsedUUIDArray {
        let ids: [UUID]
        let isMalformed: Bool
    }

    private static func uuidArray(named key: String, in json: String) -> ParsedUUIDArray {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParsedUUIDArray(ids: [], isMalformed: false)
        }
        guard let rawValue = object[key] else {
            return ParsedUUIDArray(ids: [], isMalformed: false)
        }
        guard let values = rawValue as? [String] else {
            return ParsedUUIDArray(ids: [], isMalformed: true)
        }
        let ids = values.compactMap(UUID.init(uuidString:))
        return ParsedUUIDArray(ids: ids, isMalformed: ids.count != values.count || Set(ids).count != ids.count)
    }

    private static func jsonObject(in json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func isRewardMetadata(_ object: [String: Any]) -> Bool {
        object["economyVersion"] != nil
            || object["growthXP"] != nil
            || object["humanCoconuts"] != nil
            || object["petCoconuts"] != nil
    }

    private static func intValue(named key: String, in object: [String: Any]) -> Int {
        if let value = object[key] as? Int { return value }
        if let value = object[key] as? Double { return Int(value) }
        if let value = object[key] as? String { return Int(value) ?? 0 }
        return 0
    }

    private static func stringValue(named key: String, in object: [String: Any]) -> String {
        (object[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func fetchSession(id: UUID, context: ModelContext) throws -> SharedCareSession? {
        var descriptor = FetchDescriptor<SharedCareSession>(predicate: #Predicate<SharedCareSession> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchReceipt(id: UUID, context: ModelContext) throws -> SharedCareUndoReceipt? {
        var descriptor = FetchDescriptor<SharedCareUndoReceipt>(
            predicate: #Predicate<SharedCareUndoReceipt> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchWalletEntries(ids: [UUID], context: ModelContext) throws -> [CoconutLedgerEntry] {
        try ids.compactMap { id in
            var descriptor = FetchDescriptor<CoconutLedgerEntry>(predicate: #Predicate<CoconutLedgerEntry> { $0.id == id })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        }
    }

    private static func fetchBudgetUsageEvents(ids: [UUID], context: ModelContext) throws -> [EconomyBudgetUsageEvent] {
        try ids.compactMap { id in
            var descriptor = FetchDescriptor<EconomyBudgetUsageEvent>(predicate: #Predicate<EconomyBudgetUsageEvent> { $0.id == id })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        }
    }

    private static func undoWalletEntries(sessionID: UUID, context: ModelContext) throws -> [CoconutLedgerEntry] {
        let sourceName = walletSourceModelName
        let sourceID = sessionID.uuidString
        var descriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate<CoconutLedgerEntry> {
                $0.sourceModelName == sourceName && $0.sourceModelId == sourceID
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        descriptor.fetchLimit = 128
        return try context.fetch(descriptor)
    }

    private static func undoWalletDelta(
        original: CoconutLedgerEntry,
        token: SharedCareUndoToken,
        occurredAt: Date,
        context: ModelContext
    ) -> CoconutWalletDelta {
        let ownerKind = original.ownerKind
        return CoconutWalletDelta(
            accountKey: original.accountKey,
            ownerKind: ownerKind,
            ownerId: original.ownerId,
            ownerName: original.ownerName,
            cachedBalance: original.balanceAfter,
            delta: -original.delta,
            entryKind: .adjustment,
            source: .careEvent,
            title: undoRewardTitle(original.title),
            emoji: "↩️",
            actorId: original.actorId,
            actorName: original.actorName,
            subjectKind: CareLedgerSubjectKind(rawValue: original.subjectKindRaw) ?? .unknown,
            subjectId: original.subjectId,
            sourceModelName: walletSourceModelName,
            sourceModelId: token.sessionID.uuidString,
            metadataJSON: undoRewardMetadata(original: original, sessionID: token.sessionID),
            occurredAt: occurredAt,
            transactionKey: "sharedCareUndo:\(token.sessionID.uuidString):\(original.id.uuidString)",
            human: ownerKind == .human ? fetchHuman(id: original.ownerId, context: context) : nil,
            pet: ownerKind == .pet ? fetchPet(id: original.ownerId, context: context) : nil
        )
    }

    private static func undoRewardTitle(_ originalTitle: String) -> String {
        L10n.current.tr(
            zh: "撤销 \(originalTitle)",
            en: "Undo \(originalTitle)",
            de: "\(originalTitle) rückgängig"
        )
    }

    private static func undoRewardMetadata(original: CoconutLedgerEntry, sessionID: UUID) -> String {
        let object: [String: Any] = [
            "generatedBy": walletSourceModelName,
            "reason": "sharedCareUndo",
            "sharedSessionId": sessionID.uuidString,
            "reversesWalletEntryId": original.id.uuidString,
            "reversesTransactionKey": original.transactionKey
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"reversesWalletEntryId\":\"\(original.id.uuidString)\"}"
        }
        return json
    }

    private static func fetchHuman(id idString: String, context: ModelContext) -> Human? {
        guard let id = UUID(uuidString: idString) else { return nil }
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static func fetchPet(id idString: String, context: ModelContext) -> Pet? {
        guard let id = UUID(uuidString: idString) else { return nil }
        var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
