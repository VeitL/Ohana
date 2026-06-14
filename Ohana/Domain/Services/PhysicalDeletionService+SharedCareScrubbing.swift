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
}
