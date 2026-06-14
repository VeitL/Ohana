//
//  PhysicalDeletionService+SharedCareScrubbing.swift
//  Ohana
//
//  Keeps retained shared-care child facts consistent when a human executor is
//  physically deleted.
//

import Foundation
import SwiftData

extension PhysicalDeletionService {
    private nonisolated struct RetainedPetFactKey: Hashable {
        var modelName: String
        var modelId: String
    }

    @discardableResult
    nonisolated static func scrubSharedCareChildrenReferencingSession(
        _ session: SharedCareSession,
        deletedHumanId: String,
        remainingExecutorIds: [String],
        clearsSessionLink: Bool,
        context: ModelContext,
        modifiedAt: Date
    ) -> Int {
        let sessionID = session.id.uuidString
        let replacementExecutorId = remainingExecutorIds.first
        var changedCareLogs: [PetCareLog] = []
        var changedPottyLogs: [PetPottyLog] = []
        var changedHygieneLogs: [PetHygieneLog] = []
        var changedExpenseLogs: [PetExpenseLog] = []
        var changedWalkLogs: [PetWalkLog] = []

        for log in SharedCareSessionMaintenance.fetchCareLogs(sessionID: sessionID, context: context) {
            var changed = clearSharedSessionIdIfNeeded(log.sharedSessionId, clearsSessionLink: clearsSessionLink) {
                log.sharedSessionId = $0
            }
            if let scrubbedExecutorId = executorIdAfterRemovingHuman(
                log.executorId,
                deletedHumanId: deletedHumanId,
                replacementExecutorId: replacementExecutorId
            ) {
                log.executorId = scrubbedExecutorId
                changed = true
            }
            if changed {
                changedCareLogs.append(log)
            }
        }

        for log in SharedCareSessionMaintenance.fetchPottyLogs(sessionID: sessionID, context: context) {
            var changed = clearSharedSessionIdIfNeeded(log.sharedSessionId, clearsSessionLink: clearsSessionLink) {
                log.sharedSessionId = $0
            }
            if let scrubbedExecutorId = executorIdAfterRemovingHuman(
                log.executorId,
                deletedHumanId: deletedHumanId,
                replacementExecutorId: replacementExecutorId
            ) {
                log.executorId = scrubbedExecutorId
                changed = true
            }
            if changed {
                changedPottyLogs.append(log)
            }
        }

        for log in SharedCareSessionMaintenance.fetchHygieneLogs(session: session, context: context) {
            var changed = clearSharedSessionIdIfNeeded(log.sharedSessionId, clearsSessionLink: clearsSessionLink) {
                log.sharedSessionId = $0
            }
            if let scrubbedExecutorId = executorIdAfterRemovingHuman(
                log.executorId,
                deletedHumanId: deletedHumanId,
                replacementExecutorId: replacementExecutorId
            ) {
                log.executorId = scrubbedExecutorId
                changed = true
            }
            if changed {
                changedHygieneLogs.append(log)
            }
        }

        for log in SharedCareSessionMaintenance.fetchExpenseLogs(sessionID: sessionID, context: context) {
            var changed = clearSharedSessionIdIfNeeded(log.sharedSessionId, clearsSessionLink: clearsSessionLink) {
                log.sharedSessionId = $0
            }
            if let scrubbedExecutorId = executorIdAfterRemovingHuman(
                log.executorId,
                deletedHumanId: deletedHumanId,
                replacementExecutorId: replacementExecutorId
            ) {
                log.executorId = scrubbedExecutorId
                changed = true
            }
            if changed {
                changedExpenseLogs.append(log)
            }
        }

        for log in SharedCareSessionMaintenance.fetchWalkLogs(sessionID: sessionID, context: context) {
            var changed = clearSharedSessionIdIfNeeded(log.sharedSessionId, clearsSessionLink: clearsSessionLink) {
                log.sharedSessionId = $0
            }
            if walkExecutorIdsContain(log, humanId: deletedHumanId) {
                if remainingExecutorIds.isEmpty {
                    log.executorId = nil
                    log.executorIdsRaw = ""
                } else {
                    log.setExecutorIds(remainingExecutorIds, primaryExecutorId: replacementExecutorId)
                }
                changed = true
            }
            if changed {
                changedWalkLogs.append(log)
            }
        }

        CloudSyncMutationRecorder.markModified(changedCareLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedPottyLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedHygieneLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedExpenseLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedWalkLogs, context: context, modifiedAt: modifiedAt)

        return changedCareLogs.count +
            changedPottyLogs.count +
            changedHygieneLogs.count +
            changedExpenseLogs.count +
            changedWalkLogs.count
    }

    @discardableResult
    nonisolated static func scrubRetainedPetFactsReferencingHuman(
        humanId: String,
        context: ModelContext,
        modifiedAt: Date
    ) -> Int {
        var changedCareLogs: [PetCareLog] = []
        var changedPottyLogs: [PetPottyLog] = []
        var changedHygieneLogs: [PetHygieneLog] = []
        var changedHealthLogs: [PetHealthLog] = []
        var changedWalkLogs: [PetWalkLog] = []
        var changedWeightLogs: [PetWeightLog] = []
        var changedFoodRecords: [PetFoodRecord] = []
        var changedExpenseLogs: [PetExpenseLog] = []
        var retainedFactKeys: Set<RetainedPetFactKey> = []

        for log in fetchScrubbableRows(PetCareLog.self, context: context) where log.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: log))
            guard sharedCareIdsMatch(log.executorId, humanId) else { continue }
            log.executorId = nil
            changedCareLogs.append(log)
        }
        for log in fetchScrubbableRows(PetPottyLog.self, context: context) where log.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: log))
            guard sharedCareIdsMatch(log.executorId, humanId) else { continue }
            log.executorId = nil
            changedPottyLogs.append(log)
        }
        for log in fetchScrubbableRows(PetHygieneLog.self, context: context) where log.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: log))
            guard sharedCareIdsMatch(log.executorId, humanId) else { continue }
            log.executorId = nil
            changedHygieneLogs.append(log)
        }
        for log in fetchScrubbableRows(PetHealthLog.self, context: context) where log.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: log))
            guard sharedCareIdsMatch(log.executorId, humanId) else { continue }
            log.executorId = nil
            changedHealthLogs.append(log)
        }
        for log in fetchScrubbableRows(PetWalkLog.self, context: context) where log.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: log))
            guard walkExecutorIdsContain(log, humanId: humanId) else { continue }
            let remainingExecutorIds = log.executorIds.filter { !sharedCareIdsMatch($0, humanId) }
            if remainingExecutorIds.isEmpty {
                log.executorId = nil
                log.executorIdsRaw = ""
            } else {
                log.setExecutorIds(remainingExecutorIds, primaryExecutorId: remainingExecutorIds.first)
            }
            changedWalkLogs.append(log)
        }
        for log in fetchScrubbableRows(PetWeightLog.self, context: context) where log.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: log))
            guard sharedCareIdsMatch(log.executorId, humanId) else { continue }
            log.executorId = nil
            changedWeightLogs.append(log)
        }
        for record in fetchScrubbableRows(PetFoodRecord.self, context: context) where record.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: record))
            guard sharedCareIdsMatch(record.executorId, humanId) else { continue }
            record.executorId = nil
            changedFoodRecords.append(record)
        }
        for log in fetchScrubbableRows(PetExpenseLog.self, context: context) where log.pet != nil {
            retainedFactKeys.insert(retainedPetFactKey(for: log))
            guard sharedCareIdsMatch(log.executorId, humanId) else { continue }
            log.executorId = nil
            changedExpenseLogs.append(log)
        }

        let changedCareLedgers = scrubCareLedgerActors(
            humanId: humanId,
            retainedFactKeys: retainedFactKeys,
            context: context
        )
        let changedCoconutLedgers = scrubCoconutLedgerActors(
            humanId: humanId,
            retainedFactKeys: retainedFactKeys,
            context: context
        )

        CloudSyncMutationRecorder.markModified(changedCareLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedPottyLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedHygieneLogs, context: context, modifiedAt: modifiedAt)
        changedHealthLogs.forEach { CloudSyncMutationRecorder.markModified($0, context: context, modifiedAt: modifiedAt) }
        CloudSyncMutationRecorder.markModified(changedWalkLogs, context: context, modifiedAt: modifiedAt)
        changedWeightLogs.forEach { CloudSyncMutationRecorder.markModified($0, context: context, modifiedAt: modifiedAt) }
        changedFoodRecords.forEach { CloudSyncMutationRecorder.markModified($0, context: context, modifiedAt: modifiedAt) }
        CloudSyncMutationRecorder.markModified(changedExpenseLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedCareLedgers, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(changedCoconutLedgers, context: context, modifiedAt: modifiedAt)

        return changedCareLogs.count +
            changedPottyLogs.count +
            changedHygieneLogs.count +
            changedHealthLogs.count +
            changedWalkLogs.count +
            changedWeightLogs.count +
            changedFoodRecords.count +
            changedExpenseLogs.count +
            changedCareLedgers.count +
            changedCoconutLedgers.count
    }

    private nonisolated static func scrubCareLedgerActors(
        humanId: String,
        retainedFactKeys: Set<RetainedPetFactKey>,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        guard !retainedFactKeys.isEmpty else { return [] }
        var changedEvents: [CareLedgerEvent] = []
        for event in fetchScrubbableRows(CareLedgerEvent.self, context: context)
            where sharedCareIdsMatch(event.actorId, humanId) && retainedFactKeys.contains(retainedPetFactKey(for: event)) {
            event.actorKind = CareLedgerActorKind.unknown.rawValue
            event.actorId = nil
            changedEvents.append(event)
        }
        return changedEvents
    }

    private nonisolated static func scrubCoconutLedgerActors(
        humanId: String,
        retainedFactKeys: Set<RetainedPetFactKey>,
        context: ModelContext
    ) -> [CoconutLedgerEntry] {
        guard !retainedFactKeys.isEmpty else { return [] }
        var changedEntries: [CoconutLedgerEntry] = []
        for entry in fetchScrubbableRows(CoconutLedgerEntry.self, context: context) {
            guard sharedCareIdsMatch(entry.actorId, humanId),
                  retainedFactKeys.contains(retainedPetFactKey(for: entry)),
                  !(entry.ownerKind == .human && sharedCareIdsMatch(entry.ownerId, humanId)),
                  !sharedCareIdsMatch(entry.subjectId, humanId) else {
                continue
            }
            entry.actorId = nil
            entry.actorName = nil
            changedEntries.append(entry)
        }
        return changedEntries
    }

    private nonisolated static func clearSharedSessionIdIfNeeded(
        _ sharedSessionId: String,
        clearsSessionLink: Bool,
        update: (String) -> Void
    ) -> Bool {
        guard clearsSessionLink, !sharedSessionId.isEmpty else { return false }
        update("")
        return true
    }

    private nonisolated static func executorIdAfterRemovingHuman(
        _ executorId: String?,
        deletedHumanId: String,
        replacementExecutorId: String?
    ) -> String?? {
        guard sharedCareIdsMatch(executorId, deletedHumanId) else { return nil }
        return .some(replacementExecutorId)
    }

    private nonisolated static func walkExecutorIdsContain(_ log: PetWalkLog, humanId: String) -> Bool {
        sharedCareIdsMatch(log.executorId, humanId) || log.executorIds.contains { sharedCareIdsMatch($0, humanId) }
    }

    private nonisolated static func sharedCareIdsMatch(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        let left = CloudSyncRecordState.normalizedRecordId(lhs)
        let right = CloudSyncRecordState.normalizedRecordId(rhs)
        return !left.isEmpty && left == right
    }

    private nonisolated static func fetchScrubbableRows<T: PersistentModel>(
        _: T.Type,
        context: ModelContext
    ) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private nonisolated static func retainedPetFactKey(for log: PetCareLog) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetCareLog.self), modelId: log.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for log: PetPottyLog) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetPottyLog.self), modelId: log.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for log: PetHygieneLog) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetHygieneLog.self), modelId: log.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for log: PetHealthLog) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetHealthLog.self), modelId: log.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for log: PetWalkLog) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetWalkLog.self), modelId: log.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for log: PetWeightLog) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetWeightLog.self), modelId: log.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for record: PetFoodRecord) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetFoodRecord.self), modelId: record.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for log: PetExpenseLog) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: String(describing: PetExpenseLog.self), modelId: log.id.uuidString)
    }

    private nonisolated static func retainedPetFactKey(for event: CareLedgerEvent) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: event.legacyModelName ?? "", modelId: event.legacyModelId ?? "")
    }

    private nonisolated static func retainedPetFactKey(for entry: CoconutLedgerEntry) -> RetainedPetFactKey {
        RetainedPetFactKey(modelName: entry.sourceModelName, modelId: entry.sourceModelId)
    }
}
