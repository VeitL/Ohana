//
//  SharedCareSessionMaintenance.swift
//  Ohana
//
//  Keeps shared session facts consistent when legacy child logs are edited or removed.
//

import Foundation
import SwiftData

struct SharedCareSessionDeleteResult: Equatable {
    let sessionID: UUID
    let careLogIDs: [UUID]
    let pottyLogIDs: [UUID]
    let hygieneLogIDs: [UUID]
    let expenseLogIDs: [UUID]
    let walkLogIDs: [UUID]
    let ledgerEventIDs: [UUID]

    var deletedChildCount: Int {
        careLogIDs.count + pottyLogIDs.count + hygieneLogIDs.count + expenseLogIDs.count + walkLogIDs.count
    }
}

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

enum SharedCareSessionMaintenanceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                return L10n().tr(
                    zh: "保存共同照护记录失败：\(reason)",
                    en: "Failed to save shared care records: \(reason)",
                    de: "Gemeinsame Pflegeeinträge konnten nicht gespeichert werden: \(reason)"
                )
            }
            return L10n().tr(
                zh: "保存共同照护记录失败，请重试。",
                en: "Failed to save shared care records. Please try again.",
                de: "Gemeinsame Pflegeeinträge konnten nicht gespeichert werden. Bitte erneut versuchen."
            )
        }
    }
}

struct SharedCareLegacyOrphanNoteDiagnostic: Equatable {
    let sourceModelName: String
    let recordID: UUID
    let missingSessionID: UUID?
    let targetCount: Int?
    let stockTotalGrams: Double?
    let isStockOwner: Bool
    let legacyModelName: String?
    let legacyModelId: String?
    let visibleNoteCharacterCount: Int
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

nonisolated enum SharedCareSessionMaintenance {
    /// Live models remain inside the maintenance actor. This small carrier is
    /// intentionally not Sendable and is used only to attach one legacy source
    /// row whose `sharedSessionId` has not yet been restored.
    struct LegacyNoteCleanupSupplement {
        var careLogs: [PetCareLog] = []
        var expenseLogs: [PetExpenseLog] = []
        var walkLogs: [PetWalkLog] = []
        var ledgerEvents: [CareLedgerEvent] = []
    }

    struct LegacyMetadataScan {
        let sessionIDs: [UUID]
        let missingSessionIDs: [UUID]
        let careLogsBySessionID: [UUID: [PetCareLog]]
        let expenseLogsBySessionID: [UUID: [PetExpenseLog]]
        let walkLogsBySessionID: [UUID: [PetWalkLog]]
        let ledgerEventsBySessionID: [UUID: [CareLedgerEvent]]
        let skippedOrphanCareLogs: [PetCareLog]
        let skippedOrphanExpenseLogs: [PetExpenseLog]
        let skippedOrphanWalkLogs: [PetWalkLog]
        let skippedOrphanLedgerEvents: [CareLedgerEvent]

        var skippedOrphanCareLogIDs: [UUID] {
            skippedOrphanCareLogs.map(\.id)
        }

        var skippedOrphanExpenseLogIDs: [UUID] {
            skippedOrphanExpenseLogs.map(\.id)
        }

        var skippedOrphanWalkLogIDs: [UUID] {
            skippedOrphanWalkLogs.map(\.id)
        }

        var skippedOrphanLedgerEventIDs: [UUID] {
            skippedOrphanLedgerEvents.map(\.id)
        }
    }

    @discardableResult
    static func deleteCascade(
        _ session: SharedCareSession,
        context: ModelContext,
        deletedByHumanId: String? = nil,
        deletedAt: Date = Date()
    ) throws -> SharedCareSessionDeleteResult {
        let sessionUUID = session.id
        let sessionID = session.id.uuidString
        let careLogs = fetchCareLogs(sessionID: sessionID, context: context)
        let pottyLogs = fetchPottyLogs(sessionID: sessionID, context: context)
        let hygieneLogs = fetchHygieneLogs(session: session, context: context)
        let expenseLogs = fetchExpenseLogs(sessionID: sessionID, context: context)
        let walkLogs = fetchWalkLogs(sessionID: sessionID, context: context)
        let stockReminderPets = feedingStockReminderPets(affectedBy: careLogs)
        let ledgerEvents = ledgerEvents(
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs,
            context: context
        )

        CloudSyncMutationRecorder.markDeleted(session, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        for event in ledgerEvents {
            CloudSyncMutationRecorder.markDeleted(event, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(event)
        }
        for log in careLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        }
        for log in pottyLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        }
        for log in hygieneLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        }
        for log in expenseLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        }
        for log in walkLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        }
        context.delete(session)
        markDeletedSharedSessionState(sessionID: sessionUUID, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        try saveSharedCareChanges(context: context)
        FeedingPlanWriter.rebuildFoodStockReminders(pets: stockReminderPets, context: context, now: deletedAt)

        return SharedCareSessionDeleteResult(
            sessionID: sessionUUID,
            careLogIDs: careLogs.map(\.id),
            pottyLogIDs: pottyLogs.map(\.id),
            hygieneLogIDs: hygieneLogs.map(\.id),
            expenseLogIDs: expenseLogs.map(\.id),
            walkLogIDs: walkLogs.map(\.id),
            ledgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    static func reconcileAfterDeletingChild(
        sharedSessionId: String,
        context: ModelContext,
        reconciledAt: Date = Date()
    ) {
        guard let sessionID = UUID(uuidString: sharedSessionId),
              let session = fetchSession(id: sessionID, context: context) else {
            return
        }
        reconcile(session, context: context, reconciledAt: reconciledAt)
    }

    @MainActor
    static func reconcileAfterClaimingPotty(_ log: PetPottyLog, pet: Pet, context: ModelContext) {
        guard let sessionID = UUID(uuidString: log.sharedSessionId),
              let session = fetchSession(id: sessionID, context: context) else {
            return
        }
        session.sourcePetId = pet.id.uuidString
        session.speciesRaw = pet.species
        reconcile(session, context: context)
    }

    @MainActor
    static func reconcileAfterDeletingHygieneChild(
        logID: UUID,
        ledgerEvents: [CareLedgerEvent],
        context: ModelContext,
        reconciledAt: Date = Date()
    ) {
        let sessionIDs = sessionIDsReferencingHygieneLog(
            logID: logID,
            ledgerEvents: ledgerEvents,
            context: context
        )
        for sessionID in sessionIDs {
            guard let session = fetchSession(id: sessionID, context: context) else { continue }
            reconcile(session, context: context, reconciledAt: reconciledAt)
        }
    }

    @MainActor
    static func sessionsReferencingPet(id petID: UUID, context: ModelContext) -> [SharedCareSession] {
        let petIDString = petID.uuidString
        let descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.sourcePetId == petIDString ||
                    session.stockOwnerPetId == petIDString ||
                    session.targetPetIdsRaw.contains(petIDString)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch sessions referencing pet")
    }

    @MainActor
    static func legacyOrphanNoteDiagnostics(context: ModelContext) -> [SharedCareLegacyOrphanNoteDiagnostic] {
        let scan = legacyMetadataScan(context: context)
        let diagnostics =
            scan.skippedOrphanCareLogs.map {
                orphanDiagnostic(
                    sourceModelName: String(describing: PetCareLog.self),
                    recordID: $0.id,
                    legacyNote: $0.note
                )
            } +
            scan.skippedOrphanExpenseLogs.map {
                orphanDiagnostic(
                    sourceModelName: String(describing: PetExpenseLog.self),
                    recordID: $0.id,
                    legacyNote: $0.note
                )
            } +
            scan.skippedOrphanWalkLogs.map {
                orphanDiagnostic(
                    sourceModelName: String(describing: PetWalkLog.self),
                    recordID: $0.id,
                    legacyNote: $0.behaviorNotes ?? ""
                )
            } +
            scan.skippedOrphanLedgerEvents.map {
                orphanDiagnostic(
                    sourceModelName: String(describing: CareLedgerEvent.self),
                    recordID: $0.id,
                    legacyNote: $0.note,
                    legacyModelName: $0.legacyModelName,
                    legacyModelId: $0.legacyModelId
                )
            }
        return diagnostics.sorted {
            if $0.sourceModelName == $1.sourceModelName {
                return $0.recordID.uuidString < $1.recordID.uuidString
            }
            return $0.sourceModelName < $1.sourceModelName
        }
    }

    @discardableResult
    @MainActor
    static func cleanLegacyNoteMetadata(
        context: ModelContext,
        cleanedAt: Date = Date()
    ) -> SharedCareLegacyNoteCleanupResult {
        let scan = legacyMetadataScan(context: context)
        var changedSessions: [SharedCareSession] = []
        var changedCareLogs: [PetCareLog] = []
        var changedHygieneLogs: [PetHygieneLog] = []
        var changedExpenseLogs: [PetExpenseLog] = []
        var changedWalkLogs: [PetWalkLog] = []
        var changedLedgerEvents: [CareLedgerEvent] = []

        for sessionID in scan.sessionIDs {
            guard let session = fetchSession(id: sessionID, context: context) else { continue }
            let sessionIDString = session.id.uuidString
            let careLogs = uniqueByID(
                fetchCareLogs(sessionID: sessionIDString, context: context) + (scan.careLogsBySessionID[sessionID] ?? []),
                id: { $0.id }
            )
            let pottyLogs = fetchPottyLogs(sessionID: sessionIDString, context: context)
            let hygieneLogs = fetchHygieneLogs(session: session, context: context)
            let expenseLogs = uniqueByID(
                fetchExpenseLogs(sessionID: sessionIDString, context: context) + (scan.expenseLogsBySessionID[sessionID] ?? []),
                id: { $0.id }
            )
            let walkLogs = uniqueByID(
                fetchWalkLogs(sessionID: sessionIDString, context: context) + (scan.walkLogsBySessionID[sessionID] ?? []),
                id: { $0.id }
            )
            let ledgerEvents = uniqueByID(
                ledgerEvents(
                    careLogs: careLogs,
                    pottyLogs: pottyLogs,
                    hygieneLogs: hygieneLogs,
                    expenseLogs: expenseLogs,
                    walkLogs: walkLogs,
                    context: context
                ) + (scan.ledgerEventsBySessionID[sessionID] ?? []),
                id: { $0.id }
            )

            var sessionChanged = recoverStructuredMetadata(
                session: session,
                careLogs: careLogs,
                pottyLogs: pottyLogs,
                hygieneLogs: hygieneLogs,
                expenseLogs: expenseLogs,
                walkLogs: walkLogs
            )
            if cleanNoteIfSafe(&session.note, session: session) {
                sessionChanged = true
            }
            if sessionChanged {
                changedSessions.append(session)
            }

            for log in careLogs {
                var logChanged = restoreSharedSessionIdIfNeeded(
                    &log.sharedSessionId,
                    note: log.note,
                    sessionID: session.id
                )
                if cleanNoteIfSafe(&log.note, session: session) {
                    logChanged = true
                }
                if logChanged {
                    changedCareLogs.append(log)
                }
            }
            for log in hygieneLogs where log.sharedSessionId != sessionIDString {
                log.sharedSessionId = sessionIDString
                changedHygieneLogs.append(log)
            }
            for log in expenseLogs {
                var logChanged = restoreSharedSessionIdIfNeeded(
                    &log.sharedSessionId,
                    note: log.note,
                    sessionID: session.id
                )
                if cleanNoteIfSafe(&log.note, session: session) {
                    logChanged = true
                }
                if logChanged {
                    changedExpenseLogs.append(log)
                }
            }
            for log in walkLogs {
                var logChanged = restoreSharedSessionIdIfNeeded(
                    &log.sharedSessionId,
                    note: log.behaviorNotes ?? "",
                    sessionID: session.id
                )
                if let notes = log.behaviorNotes,
                   SharedCareMetadata.hasLegacyMetadata(notes),
                   canStripLegacyMetadata(notes, session: session) {
                    let cleaned = SharedCareMetadata.userNoteForStorage(notes)
                    log.behaviorNotes = cleaned.isEmpty ? nil : cleaned
                    if cleaned != notes {
                        logChanged = true
                    }
                }
                if logChanged {
                    changedWalkLogs.append(log)
                }
            }
            for event in ledgerEvents where cleanNoteIfSafe(&event.note, session: session) {
                changedLedgerEvents.append(event)
            }
        }

        for session in changedSessions {
            CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: cleanedAt)
        }
        CloudSyncMutationRecorder.markModified(changedCareLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedHygieneLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedExpenseLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedWalkLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedLedgerEvents, context: context, modifiedAt: cleanedAt)
        let didChange = !changedSessions.isEmpty ||
            !changedCareLogs.isEmpty ||
            !changedHygieneLogs.isEmpty ||
            !changedExpenseLogs.isEmpty ||
            !changedWalkLogs.isEmpty ||
            !changedLedgerEvents.isEmpty
        let didPersist = !didChange || saveSharedCareMaintenanceChanges(context: context)

        return SharedCareLegacyNoteCleanupResult(
            sessionIDs: changedSessions.map(\.id),
            careLogIDs: changedCareLogs.map(\.id),
            hygieneLogIDs: changedHygieneLogs.map(\.id),
            expenseLogIDs: changedExpenseLogs.map(\.id),
            walkLogIDs: changedWalkLogs.map(\.id),
            ledgerEventIDs: changedLedgerEvents.map(\.id),
            missingSessionIDs: scan.missingSessionIDs,
            skippedOrphanCareLogIDs: scan.skippedOrphanCareLogIDs,
            skippedOrphanExpenseLogIDs: scan.skippedOrphanExpenseLogIDs,
            skippedOrphanWalkLogIDs: scan.skippedOrphanWalkLogIDs,
            skippedOrphanLedgerEventIDs: scan.skippedOrphanLedgerEventIDs,
            didPersist: didPersist
        )
    }

    /// Cleans one known shared-care session without doing the legacy full-table
    /// discovery scan. Startup calls this from a bounded source-page actor and
    /// saves the whole page once; the original public one-shot API above keeps
    /// its existing compatibility behavior for manual repair/restore paths.
    static func cleanLegacyNoteMetadata(
        sessionID: UUID,
        supplement: LegacyNoteCleanupSupplement = .init(),
        context: ModelContext,
        cleanedAt: Date = Date(),
        persistChanges: Bool
    ) -> SharedCareLegacyNoteCleanupResult {
        guard let session = fetchSession(id: sessionID, context: context) else {
            return SharedCareLegacyNoteCleanupResult(
                sessionIDs: [],
                careLogIDs: [],
                hygieneLogIDs: [],
                expenseLogIDs: [],
                walkLogIDs: [],
                ledgerEventIDs: [],
                missingSessionIDs: [sessionID],
                skippedOrphanCareLogIDs: [],
                skippedOrphanExpenseLogIDs: [],
                skippedOrphanWalkLogIDs: [],
                skippedOrphanLedgerEventIDs: []
            )
        }

        let sessionIDString = session.id.uuidString
        let careLogs = uniqueByID(
            fetchCareLogs(sessionID: sessionIDString, context: context) + supplement.careLogs,
            id: { $0.id }
        )
        let pottyLogs = fetchPottyLogs(sessionID: sessionIDString, context: context)
        let hygieneLogs = fetchHygieneLogs(session: session, context: context)
        let expenseLogs = uniqueByID(
            fetchExpenseLogs(sessionID: sessionIDString, context: context) + supplement.expenseLogs,
            id: { $0.id }
        )
        let walkLogs = uniqueByID(
            fetchWalkLogs(sessionID: sessionIDString, context: context) + supplement.walkLogs,
            id: { $0.id }
        )
        let ledgerEvents = uniqueByID(
            ledgerEvents(
                careLogs: careLogs,
                pottyLogs: pottyLogs,
                hygieneLogs: hygieneLogs,
                expenseLogs: expenseLogs,
                walkLogs: walkLogs,
                context: context
            ) + supplement.ledgerEvents,
            id: { $0.id }
        )

        var changedSessions: [SharedCareSession] = []
        var changedCareLogs: [PetCareLog] = []
        var changedHygieneLogs: [PetHygieneLog] = []
        var changedExpenseLogs: [PetExpenseLog] = []
        var changedWalkLogs: [PetWalkLog] = []
        var changedLedgerEvents: [CareLedgerEvent] = []

        var sessionChanged = recoverStructuredMetadata(
            session: session,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        )
        if cleanNoteIfSafe(&session.note, session: session) {
            sessionChanged = true
        }
        if sessionChanged {
            changedSessions.append(session)
        }

        for log in careLogs {
            var logChanged = restoreSharedSessionIdIfNeeded(
                &log.sharedSessionId,
                note: log.note,
                sessionID: session.id
            )
            if cleanNoteIfSafe(&log.note, session: session) {
                logChanged = true
            }
            if logChanged {
                changedCareLogs.append(log)
            }
        }
        for log in hygieneLogs where log.sharedSessionId != sessionIDString {
            log.sharedSessionId = sessionIDString
            changedHygieneLogs.append(log)
        }
        for log in expenseLogs {
            var logChanged = restoreSharedSessionIdIfNeeded(
                &log.sharedSessionId,
                note: log.note,
                sessionID: session.id
            )
            if cleanNoteIfSafe(&log.note, session: session) {
                logChanged = true
            }
            if logChanged {
                changedExpenseLogs.append(log)
            }
        }
        for log in walkLogs {
            var logChanged = restoreSharedSessionIdIfNeeded(
                &log.sharedSessionId,
                note: log.behaviorNotes ?? "",
                sessionID: session.id
            )
            if let notes = log.behaviorNotes,
               SharedCareMetadata.hasLegacyMetadata(notes),
               canStripLegacyMetadata(notes, session: session) {
                let cleaned = SharedCareMetadata.userNoteForStorage(notes)
                log.behaviorNotes = cleaned.isEmpty ? nil : cleaned
                if cleaned != notes {
                    logChanged = true
                }
            }
            if logChanged {
                changedWalkLogs.append(log)
            }
        }
        for event in ledgerEvents where cleanNoteIfSafe(&event.note, session: session) {
            changedLedgerEvents.append(event)
        }

        for changedSession in changedSessions {
            CloudSyncMutationRecorder.markModified(changedSession, context: context, modifiedAt: cleanedAt)
        }
        CloudSyncMutationRecorder.markModified(changedCareLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedHygieneLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedExpenseLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedWalkLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedLedgerEvents, context: context, modifiedAt: cleanedAt)

        let didChange = !changedSessions.isEmpty ||
            !changedCareLogs.isEmpty ||
            !changedHygieneLogs.isEmpty ||
            !changedExpenseLogs.isEmpty ||
            !changedWalkLogs.isEmpty ||
            !changedLedgerEvents.isEmpty
        let didPersist = !persistChanges || !didChange || saveSharedCareMaintenanceChanges(context: context)

        return SharedCareLegacyNoteCleanupResult(
            sessionIDs: changedSessions.map(\.id),
            careLogIDs: changedCareLogs.map(\.id),
            hygieneLogIDs: changedHygieneLogs.map(\.id),
            expenseLogIDs: changedExpenseLogs.map(\.id),
            walkLogIDs: changedWalkLogs.map(\.id),
            ledgerEventIDs: changedLedgerEvents.map(\.id),
            missingSessionIDs: [],
            skippedOrphanCareLogIDs: [],
            skippedOrphanExpenseLogIDs: [],
            skippedOrphanWalkLogIDs: [],
            skippedOrphanLedgerEventIDs: [],
            didPersist: didPersist
        )
    }

    @discardableResult
    private static func saveSharedCareChanges(context: ModelContext) throws -> ModelContextSaveResult {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw SharedCareSessionMaintenanceError.persistenceFailed(saveResult.errorDescription)
        }
        return saveResult
    }

    @discardableResult
    private static func saveSharedCareMaintenanceChanges(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }

    static func reconcile(_ session: SharedCareSession, context: ModelContext, reconciledAt: Date = Date()) {
        let sessionID = session.id.uuidString
        let careLogs = fetchCareLogs(sessionID: sessionID, context: context)
        let pottyLogs = fetchPottyLogs(sessionID: sessionID, context: context)
        let hygieneLogs = fetchHygieneLogs(session: session, context: context)
        let expenseLogs = fetchExpenseLogs(sessionID: sessionID, context: context)
        let walkLogs = fetchWalkLogs(sessionID: sessionID, context: context)

        guard !careLogs.isEmpty || !pottyLogs.isEmpty || !hygieneLogs.isEmpty || !expenseLogs.isEmpty || !walkLogs.isEmpty else {
            CloudSyncMutationRecorder.markDeleted(session, context: context, deletedAt: reconciledAt)
            context.delete(session)
            return
        }

        _ = recoverStructuredMetadata(
            session: session,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        )
        for log in hygieneLogs where log.sharedSessionId != sessionID {
            log.sharedSessionId = sessionID
        }

        session.note = SharedCareMetadata.userNoteForStorage(session.note)
        refreshStockOwnerMetadata(session: session, careLogs: careLogs)
        refreshSharedCareMetadata(session: session, careLogs: careLogs)
        refreshExpenseMetadata(session: session, expenseLogs: expenseLogs)
        refreshWalkMetadata(session: session, walkLogs: walkLogs)
        refreshPrimaryLegacyModel(
            session: session,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        )
        markReconciledFactsModified(
            session: session,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs,
            context: context,
            modifiedAt: reconciledAt
        )
    }

    private static func refreshStockOwnerMetadata(session: SharedCareSession, careLogs: [PetCareLog]) {
        let feedingLogs = careLogs.filter { $0.careType == .feeding }
        guard !feedingLogs.isEmpty else { return }

        let ownerLog = feedingLogs.first { SharedCareMetadata.isStockOwner($0.note) }
            ?? feedingLogs.first { $0.pet?.id.uuidString == session.stockOwnerPetId }
            ?? feedingLogs.first { $0.pet?.id.uuidString == session.sourcePetId }
            ?? feedingLogs[0]
        session.stockOwnerPetId = ownerLog.pet?.id.uuidString ?? ""

        for log in feedingLogs {
            log.note = SharedCareMetadata.userNoteForStorage(log.note)
        }
    }

    private static func refreshSharedCareMetadata(session _: SharedCareSession, careLogs: [PetCareLog]) {
        for log in careLogs where log.careType != .feeding {
            log.note = SharedCareMetadata.userNoteForStorage(log.note)
        }
    }

    private static func refreshExpenseMetadata(session _: SharedCareSession, expenseLogs: [PetExpenseLog]) {
        for log in expenseLogs {
            log.note = SharedCareMetadata.userNoteForStorage(log.note)
        }
    }

    private static func refreshWalkMetadata(session _: SharedCareSession, walkLogs: [PetWalkLog]) {
        for log in walkLogs {
            guard let notes = log.behaviorNotes else { continue }
            let cleaned = SharedCareMetadata.userNoteForStorage(notes)
            log.behaviorNotes = cleaned.isEmpty ? nil : cleaned
        }
    }

    private static func feedingStockReminderPets(affectedBy careLogs: [PetCareLog]) -> [Pet] {
        var seen = Set<UUID>()
        var pets: [Pet] = []
        for log in careLogs where log.careType == .feeding {
            guard let pet = log.pet, seen.insert(pet.id).inserted else { continue }
            pets.append(pet)
        }
        return pets
    }

    private static func recoverStructuredMetadata(
        session: SharedCareSession,
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        hygieneLogs: [PetHygieneLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) -> Bool {
        var changed = false
        let targetIds = orderedTargetIds(
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        )
        if !targetIds.isEmpty {
            changed = assign(targetIds.joined(separator: "|"), to: \.targetPetIdsRaw, on: session) || changed
        }

        if !careLogs.isEmpty {
            changed = assign(careLogs.reduce(0) { $0 + max(0, $1.amountGrams) }, to: \.totalAmountGrams, on: session) || changed
            changed = assign(careLogs.reduce(0) { $0 + max(0, $1.amountMl) }, to: \.totalAmountMl, on: session) || changed
        }
        if !expenseLogs.isEmpty {
            changed = assign(expenseLogs.reduce(0) { $0 + $1.amount }, to: \.totalExpenseAmount, on: session) || changed
            if let category = expenseLogs.first?.expenseCategory {
                changed = assign(category.rawValue, to: \.expenseCategoryRaw, on: session) || changed
            }
        }
        changed = recoverStockOwner(session: session, careLogs: careLogs) || changed
        changed = recoverPrimaryLegacyModel(
            session: session,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            hygieneLogs: hygieneLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        ) || changed
        return changed
    }

    private static func recoverStockOwner(session: SharedCareSession, careLogs: [PetCareLog]) -> Bool {
        let feedingLogs = careLogs.filter { $0.careType == .feeding }
        guard !feedingLogs.isEmpty else { return false }
        let ownerLog = feedingLogs.first { SharedCareMetadata.isStockOwner($0.note) }
            ?? feedingLogs.first { $0.pet?.id.uuidString == session.stockOwnerPetId }
            ?? feedingLogs.first { $0.pet?.id.uuidString == session.sourcePetId }
            ?? feedingLogs[0]
        return assign(ownerLog.pet?.id.uuidString ?? "", to: \.stockOwnerPetId, on: session)
    }

    private static func recoverPrimaryLegacyModel(
        session: SharedCareSession,
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        hygieneLogs: [PetHygieneLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) -> Bool {
        let primary: (name: String, id: String)? = if let log = careLogs.first {
            ("PetCareLog", log.id.uuidString)
        } else if let log = pottyLogs.first {
            ("PetPottyLog", log.id.uuidString)
        } else if let log = hygieneLogs.first {
            ("PetHygieneLog", log.id.uuidString)
        } else if let log = expenseLogs.first {
            ("PetExpenseLog", log.id.uuidString)
        } else if let log = walkLogs.first {
            ("PetWalkLog", log.id.uuidString)
        } else {
            nil
        }
        guard let primary else { return false }
        let changedName = assign(primary.name, to: \.primaryLegacyModelName, on: session)
        let changedId = assign(primary.id, to: \.primaryLegacyModelId, on: session)
        return changedName || changedId
    }

    private static func cleanNoteIfSafe(_ note: inout String, session: SharedCareSession) -> Bool {
        guard SharedCareMetadata.hasLegacyMetadata(note),
              canStripLegacyMetadata(note, session: session) else {
            return false
        }
        let cleaned = SharedCareMetadata.userNoteForStorage(note)
        guard cleaned != note else { return false }
        note = cleaned
        return true
    }

    private static func restoreSharedSessionIdIfNeeded(_ raw: inout String, note: String, sessionID: UUID) -> Bool {
        guard raw != sessionID.uuidString,
              SharedCareMetadata.legacySessionId(from: note) == sessionID else {
            return false
        }
        raw = sessionID.uuidString
        return true
    }

    private static func canStripLegacyMetadata(_ note: String, session: SharedCareSession) -> Bool {
        guard SharedCareMetadata.hasLegacyMetadata(note) else { return false }
        let needsTargetCount = SharedCareMetadata.targetCount(from: note) != nil
        let needsStockFields = SharedCareMetadata.stockDeductionGrams(from: note) != nil || SharedCareMetadata.isStockOwner(note)
        let hasTargets = !session.targetPetIds.isEmpty
        let hasStockFacts = session.totalAmountGrams > 0 && !session.stockOwnerPetId.isEmpty
        return (!needsTargetCount || hasTargets) && (!needsStockFields || hasStockFacts)
    }

    private static func assign<T: Equatable>(
        _ value: T,
        to keyPath: ReferenceWritableKeyPath<SharedCareSession, T>,
        on session: SharedCareSession
    ) -> Bool {
        guard session[keyPath: keyPath] != value else { return false }
        session[keyPath: keyPath] = value
        return true
    }

    private static func refreshPrimaryLegacyModel(
        session: SharedCareSession,
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        hygieneLogs: [PetHygieneLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) {
        if let log = careLogs.first {
            session.primaryLegacyModelName = "PetCareLog"
            session.primaryLegacyModelId = log.id.uuidString
        } else if let log = pottyLogs.first {
            session.primaryLegacyModelName = "PetPottyLog"
            session.primaryLegacyModelId = log.id.uuidString
        } else if let log = hygieneLogs.first {
            session.primaryLegacyModelName = "PetHygieneLog"
            session.primaryLegacyModelId = log.id.uuidString
        } else if let log = expenseLogs.first {
            session.primaryLegacyModelName = "PetExpenseLog"
            session.primaryLegacyModelId = log.id.uuidString
        } else if let log = walkLogs.first {
            session.primaryLegacyModelName = "PetWalkLog"
            session.primaryLegacyModelId = log.id.uuidString
        }
    }

    private static func orderedTargetIds(
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        hygieneLogs: [PetHygieneLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for pet in careLogs.compactMap(\.pet) + pottyLogs.compactMap(\.pet) + hygieneLogs.compactMap(\.pet) + expenseLogs.compactMap(\.pet) + walkLogs.compactMap(\.pet) {
            let id = pet.id.uuidString
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    private static func markReconciledFactsModified(
        session: SharedCareSession,
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        hygieneLogs: [PetHygieneLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog],
        context: ModelContext,
        modifiedAt: Date
    ) {
        CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(careLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(pottyLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(hygieneLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(expenseLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(walkLogs, context: context, modifiedAt: modifiedAt)
    }
}
