//
//  SharedCareLegacyNoteBatchWorker.swift
//  Ohana
//
//  Bounded cursor-based startup cleanup for legacy shared-care note metadata.
//

import Foundation
import SwiftData

nonisolated struct SharedCareLegacyNoteCleanupResult: Equatable {
    let sessionIDs: [UUID]
    let careLogIDs: [UUID]
    let hygieneLogIDs: [UUID]
    let expenseLogIDs: [UUID]
    let walkLogIDs: [UUID]
    let ledgerEventIDs: [UUID]
    let missingSessionIDs: [UUID]
    let skippedOrphanCareLogIDs: [UUID]
    let skippedOrphanExpenseLogIDs: [UUID]
    let skippedOrphanWalkLogIDs: [UUID]
    let skippedOrphanLedgerEventIDs: [UUID]
    /// `false` means the caller's mutations were rolled back and a durable
    /// version marker must not be advanced.
    var didPersist: Bool = true

    static let empty = SharedCareLegacyNoteCleanupResult(
        sessionIDs: [],
        careLogIDs: [],
        hygieneLogIDs: [],
        expenseLogIDs: [],
        walkLogIDs: [],
        ledgerEventIDs: [],
        missingSessionIDs: [],
        skippedOrphanCareLogIDs: [],
        skippedOrphanExpenseLogIDs: [],
        skippedOrphanWalkLogIDs: [],
        skippedOrphanLedgerEventIDs: []
    )

    var cleanedCount: Int {
        sessionIDs.count + careLogIDs.count + hygieneLogIDs.count + expenseLogIDs.count + walkLogIDs.count + ledgerEventIDs.count
    }

    var skippedOrphanCount: Int {
        skippedOrphanCareLogIDs.count + skippedOrphanExpenseLogIDs.count + skippedOrphanWalkLogIDs.count + skippedOrphanLedgerEventIDs.count
    }
}

nonisolated struct SharedCareLegacyNoteMaintenanceResult: Equatable {
    let didRun: Bool
    let cleanup: SharedCareLegacyNoteCleanupResult
}

/// The startup migration walks stable source tables rather than repeatedly
/// materializing every legacy note. A source/offset cursor stays valid because
/// this cleanup only changes note and relationship fields, never the sort keys.
nonisolated enum SharedCareLegacyNoteCleanupSource: String, Codable, Equatable, Sendable {
    case session
    case careLog
    case expenseLog
    case walkLog
    case ledgerEvent
    case complete
}

nonisolated struct SharedCareLegacyNoteCleanupCursor: Codable, Equatable, Sendable {
    var source: SharedCareLegacyNoteCleanupSource
    var offset: Int

    static let initial = SharedCareLegacyNoteCleanupCursor(source: .session, offset: 0)

    var isComplete: Bool {
        source == .complete
    }

    func normalized() -> SharedCareLegacyNoteCleanupCursor {
        guard source != .complete else {
            return SharedCareLegacyNoteCleanupCursor(source: .complete, offset: 0)
        }
        return SharedCareLegacyNoteCleanupCursor(source: source, offset: max(0, offset))
    }
}

nonisolated struct SharedCareLegacyNoteCleanupBatchResult: Equatable, Sendable {
    let nextCursor: SharedCareLegacyNoteCleanupCursor
    let scannedRecordCount: Int
    let cleanedRecordCount: Int
    let skippedOrphanCount: Int
    let didComplete: Bool
}

private nonisolated struct SharedCareLegacyNoteCleanupPersistenceFailure: LocalizedError {
    let errorDescription: String?
}
enum SharedCareLegacyNoteMaintenanceService {
    static let currentVersion = 1
    static let completedVersionKey = "ohana_shared_care_legacy_note_cleanup_version"

    @discardableResult
    @MainActor
    static func runIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        cleanedAt: Date = Date()
    ) -> SharedCareLegacyNoteMaintenanceResult {
        guard defaults.integer(forKey: completedVersionKey) < currentVersion else {
            return SharedCareLegacyNoteMaintenanceResult(didRun: false, cleanup: .empty)
        }

        let cleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
            context: context,
            cleanedAt: cleanedAt
        )
        guard cleanup.didPersist else {
            return SharedCareLegacyNoteMaintenanceResult(didRun: false, cleanup: cleanup)
        }
        defaults.set(currentVersion, forKey: completedVersionKey)
        return SharedCareLegacyNoteMaintenanceResult(didRun: true, cleanup: cleanup)
    }
}

/// Startup-only bounded replacement for the historical one-shot cleanup. It
/// pages immutable sort keys from each legacy source and keeps all live models
/// inside the caller's SwiftData actor until one atomic save succeeds.
nonisolated enum SharedCareLegacyNoteStartupMaintenanceService {
    static func runBatch(
        context: ModelContext,
        cursor: SharedCareLegacyNoteCleanupCursor,
        maximumRecordCount: Int,
        deadline: Date,
        cleanedAt: Date
    ) throws -> SharedCareLegacyNoteCleanupBatchResult {
        var nextCursor = cursor.normalized()
        var remainingRecordCount = max(1, maximumRecordCount)
        var scannedRecordCount = 0
        var cleanedRecordCount = 0
        var skippedOrphanCount = 0

        do {
            maintenanceLoop: while remainingRecordCount > 0,
                                   !nextCursor.isComplete,
                                   Date() < deadline {
                try Task.checkCancellation()
                let batchLimit = remainingRecordCount

                switch nextCursor.source {
                case .session:
                    var descriptor = FetchDescriptor<SharedCareSession>(sortBy: [SortDescriptor(\.date)])
                    descriptor.fetchOffset = nextCursor.offset
                    descriptor.fetchLimit = batchLimit
                    let sessions = try context.fetch(descriptor)
                    guard !sessions.isEmpty else {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .careLog, offset: 0)
                        continue
                    }
                    for session in sessions {
                        try Task.checkCancellation()
                        guard Date() < deadline else { break maintenanceLoop }
                        if SharedCareMetadata.hasLegacyMetadata(session.note) {
                            let cleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
                                sessionID: session.id,
                                context: context,
                                cleanedAt: cleanedAt,
                                persistChanges: false
                            )
                            cleanedRecordCount += cleanup.cleanedCount
                            skippedOrphanCount += cleanup.missingSessionIDs.count
                        }
                        scannedRecordCount += 1
                        remainingRecordCount -= 1
                        nextCursor.offset += 1
                    }
                    if sessions.count < batchLimit {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .careLog, offset: 0)
                    }

                case .careLog:
                    var descriptor = FetchDescriptor<PetCareLog>(sortBy: [SortDescriptor(\.date)])
                    descriptor.fetchOffset = nextCursor.offset
                    descriptor.fetchLimit = batchLimit
                    let logs = try context.fetch(descriptor)
                    guard !logs.isEmpty else {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .expenseLog, offset: 0)
                        continue
                    }
                    for log in logs {
                        try Task.checkCancellation()
                        guard Date() < deadline else { break maintenanceLoop }
                        if SharedCareMetadata.hasLegacyMetadata(log.note) {
                            guard let sessionID = SharedCareSessionMaintenance.legacySessionID(raw: log.sharedSessionId, note: log.note) else {
                                skippedOrphanCount += 1
                                scannedRecordCount += 1
                                remainingRecordCount -= 1
                                nextCursor.offset += 1
                                continue
                            }
                            let cleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
                                sessionID: sessionID,
                                supplement: .init(careLogs: [log]),
                                context: context,
                                cleanedAt: cleanedAt,
                                persistChanges: false
                            )
                            cleanedRecordCount += cleanup.cleanedCount
                            skippedOrphanCount += cleanup.missingSessionIDs.count
                        }
                        scannedRecordCount += 1
                        remainingRecordCount -= 1
                        nextCursor.offset += 1
                    }
                    if logs.count < batchLimit {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .expenseLog, offset: 0)
                    }

                case .expenseLog:
                    var descriptor = FetchDescriptor<PetExpenseLog>(sortBy: [SortDescriptor(\.date)])
                    descriptor.fetchOffset = nextCursor.offset
                    descriptor.fetchLimit = batchLimit
                    let logs = try context.fetch(descriptor)
                    guard !logs.isEmpty else {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .walkLog, offset: 0)
                        continue
                    }
                    for log in logs {
                        try Task.checkCancellation()
                        guard Date() < deadline else { break maintenanceLoop }
                        if SharedCareMetadata.hasLegacyMetadata(log.note) {
                            guard let sessionID = SharedCareSessionMaintenance.legacySessionID(raw: log.sharedSessionId, note: log.note) else {
                                skippedOrphanCount += 1
                                scannedRecordCount += 1
                                remainingRecordCount -= 1
                                nextCursor.offset += 1
                                continue
                            }
                            let cleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
                                sessionID: sessionID,
                                supplement: .init(expenseLogs: [log]),
                                context: context,
                                cleanedAt: cleanedAt,
                                persistChanges: false
                            )
                            cleanedRecordCount += cleanup.cleanedCount
                            skippedOrphanCount += cleanup.missingSessionIDs.count
                        }
                        scannedRecordCount += 1
                        remainingRecordCount -= 1
                        nextCursor.offset += 1
                    }
                    if logs.count < batchLimit {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .walkLog, offset: 0)
                    }

                case .walkLog:
                    var descriptor = FetchDescriptor<PetWalkLog>(sortBy: [SortDescriptor(\.startDate)])
                    descriptor.fetchOffset = nextCursor.offset
                    descriptor.fetchLimit = batchLimit
                    let logs = try context.fetch(descriptor)
                    guard !logs.isEmpty else {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .ledgerEvent, offset: 0)
                        continue
                    }
                    for log in logs {
                        try Task.checkCancellation()
                        guard Date() < deadline else { break maintenanceLoop }
                        let note = log.behaviorNotes ?? ""
                        if SharedCareMetadata.hasLegacyMetadata(note) {
                            guard let sessionID = SharedCareSessionMaintenance.legacySessionID(raw: log.sharedSessionId, note: note) else {
                                skippedOrphanCount += 1
                                scannedRecordCount += 1
                                remainingRecordCount -= 1
                                nextCursor.offset += 1
                                continue
                            }
                            let cleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
                                sessionID: sessionID,
                                supplement: .init(walkLogs: [log]),
                                context: context,
                                cleanedAt: cleanedAt,
                                persistChanges: false
                            )
                            cleanedRecordCount += cleanup.cleanedCount
                            skippedOrphanCount += cleanup.missingSessionIDs.count
                        }
                        scannedRecordCount += 1
                        remainingRecordCount -= 1
                        nextCursor.offset += 1
                    }
                    if logs.count < batchLimit {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .ledgerEvent, offset: 0)
                    }

                case .ledgerEvent:
                    var descriptor = FetchDescriptor<CareLedgerEvent>(sortBy: [SortDescriptor(\.occurredAt)])
                    descriptor.fetchOffset = nextCursor.offset
                    descriptor.fetchLimit = batchLimit
                    let events = try context.fetch(descriptor)
                    guard !events.isEmpty else {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .complete, offset: 0)
                        continue
                    }
                    for event in events {
                        try Task.checkCancellation()
                        guard Date() < deadline else { break maintenanceLoop }
                        if SharedCareMetadata.hasLegacyMetadata(event.note) {
                            guard let sessionID = SharedCareMetadata.legacySessionId(from: event.note) else {
                                skippedOrphanCount += 1
                                scannedRecordCount += 1
                                remainingRecordCount -= 1
                                nextCursor.offset += 1
                                continue
                            }
                            let cleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
                                sessionID: sessionID,
                                supplement: .init(ledgerEvents: [event]),
                                context: context,
                                cleanedAt: cleanedAt,
                                persistChanges: false
                            )
                            cleanedRecordCount += cleanup.cleanedCount
                            skippedOrphanCount += cleanup.missingSessionIDs.count
                        }
                        scannedRecordCount += 1
                        remainingRecordCount -= 1
                        nextCursor.offset += 1
                    }
                    if events.count < batchLimit {
                        nextCursor = SharedCareLegacyNoteCleanupCursor(source: .complete, offset: 0)
                    }

                case .complete:
                    break maintenanceLoop
                }
            }

            try Task.checkCancellation()
            if cleanedRecordCount > 0 {
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    throw SharedCareLegacyNoteCleanupPersistenceFailure(errorDescription: saveResult.errorDescription)
                }
            }

            return SharedCareLegacyNoteCleanupBatchResult(
                nextCursor: nextCursor,
                scannedRecordCount: scannedRecordCount,
                cleanedRecordCount: cleanedRecordCount,
                skippedOrphanCount: skippedOrphanCount,
                didComplete: nextCursor.isComplete
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}

/// The actor performs all scan, recovery, and persistence work off the visible
/// startup coordinator, then returns only a Sendable cursor/result summary.
@ModelActor
actor SharedCareLegacyNoteMaintenanceActor {
    func runBatch(
        cursor: SharedCareLegacyNoteCleanupCursor,
        maximumRecordCount: Int,
        deadline: Date,
        cleanedAt: Date
    ) throws -> SharedCareLegacyNoteCleanupBatchResult {
        try SharedCareLegacyNoteStartupMaintenanceService.runBatch(
            context: modelContext,
            cursor: cursor,
            maximumRecordCount: maximumRecordCount,
            deadline: deadline,
            cleanedAt: cleanedAt
        )
    }
}
