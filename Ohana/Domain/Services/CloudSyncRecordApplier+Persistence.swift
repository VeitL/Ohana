//
//  CloudSyncRecordApplier+Persistence.swift
//  Ohana
//
//  Split helpers for applying CloudKit records into SwiftData.
//

import CloudKit
import Foundation
import SwiftData

extension CloudSyncRecordApplier {
    nonisolated static func saveCloudSyncApplyChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw CloudSyncRecordApplyPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
    }

    @discardableResult
    nonisolated static func saveCloudSyncDeletionChanges(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }
}
