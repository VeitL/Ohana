//
//  PhysicalDeletionService+UndoReceipts.swift
//  Ohana
//
//  Local-only shared-care undo receipt cleanup during physical deletion.
//

import Foundation
import SwiftData

// SharedCareUndoReceipt is explicitly local-only recovery state in
// CloudSyncEntityRegistry, so physical cleanup has no CloudKit tombstone or
// sync metadata to publish.
extension PhysicalDeletionService {
    @discardableResult
    nonisolated static func deleteSharedCareUndoReceiptsReferencingPet(
        petId: String,
        context: ModelContext
    ) -> Int {
        let receipts = fetchAll(SharedCareUndoReceipt.self, context: context).filter { receipt in
            idsMatch(receipt.sourcePetId.uuidString, petId) ||
                receipt.targetPetIds.contains { idsMatch($0.uuidString, petId) }
        }
        for receipt in receipts {
            context.delete(receipt)
        }
        return receipts.count
    }

    @discardableResult
    nonisolated static func deleteSharedCareUndoReceiptsReferencingHuman(
        humanId: String,
        context: ModelContext
    ) -> Int {
        let receipts = fetchAll(SharedCareUndoReceipt.self, context: context).filter {
            idsMatch($0.executorId, humanId)
        }
        for receipt in receipts {
            context.delete(receipt)
        }
        return receipts.count
    }

    @discardableResult
    nonisolated static func deleteOrphanedSharedCareUndoReceipts(
        context: ModelContext
    ) -> Int {
        let sessionIDs = Set(fetchAll(SharedCareSession.self, context: context).map(\.id))
        let receipts = fetchAll(SharedCareUndoReceipt.self, context: context).filter {
            switch $0.state {
            case .pendingUndo, .finalizingCore, .externalEffectsPending:
                !sessionIDs.contains($0.sharedSessionId)
            case .finalized, .undone:
                // Terminal receipts may intentionally outlive their session long
                // enough to make repeated finish/undo requests idempotent.
                false
            }
        }
        for receipt in receipts {
            context.delete(receipt)
        }
        return receipts.count
    }
}
