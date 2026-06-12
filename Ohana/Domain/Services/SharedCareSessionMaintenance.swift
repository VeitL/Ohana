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
    let expenseLogIDs: [UUID]
    let walkLogIDs: [UUID]
    let ledgerEventIDs: [UUID]

    var deletedChildCount: Int {
        careLogIDs.count + pottyLogIDs.count + expenseLogIDs.count + walkLogIDs.count
    }
}

struct SharedCareLegacyNoteCleanupResult: Equatable {
    let sessionIDs: [UUID]
    let careLogIDs: [UUID]
    let expenseLogIDs: [UUID]
    let walkLogIDs: [UUID]
    let ledgerEventIDs: [UUID]
    let missingSessionIDs: [UUID]
    let skippedOrphanCareLogIDs: [UUID]
    let skippedOrphanExpenseLogIDs: [UUID]
    let skippedOrphanWalkLogIDs: [UUID]
    let skippedOrphanLedgerEventIDs: [UUID]

    static let empty = SharedCareLegacyNoteCleanupResult(
        sessionIDs: [],
        careLogIDs: [],
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
        sessionIDs.count + careLogIDs.count + expenseLogIDs.count + walkLogIDs.count + ledgerEventIDs.count
    }

    var skippedOrphanCount: Int {
        skippedOrphanCareLogIDs.count + skippedOrphanExpenseLogIDs.count + skippedOrphanWalkLogIDs.count + skippedOrphanLedgerEventIDs.count
    }
}

struct SharedCareLegacyNoteMaintenanceResult: Equatable {
    let didRun: Bool
    let cleanup: SharedCareLegacyNoteCleanupResult
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
        defaults.set(currentVersion, forKey: completedVersionKey)
        return SharedCareLegacyNoteMaintenanceResult(didRun: true, cleanup: cleanup)
    }
}

enum SharedCareSessionMaintenance {
    private struct LegacyMetadataScan {
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
    @MainActor
    static func deleteCascade(
        _ session: SharedCareSession,
        context: ModelContext,
        deletedByHumanId: String? = nil,
        deletedAt: Date = Date()
    ) -> SharedCareSessionDeleteResult {
        let sessionUUID = session.id
        let sessionID = session.id.uuidString
        let careLogs = fetchCareLogs(sessionID: sessionID, context: context)
        let pottyLogs = fetchPottyLogs(sessionID: sessionID, context: context)
        let expenseLogs = fetchExpenseLogs(sessionID: sessionID, context: context)
        let walkLogs = fetchWalkLogs(sessionID: sessionID, context: context)
        let ledgerEvents = ledgerEvents(careLogs: careLogs, pottyLogs: pottyLogs, expenseLogs: expenseLogs, walkLogs: walkLogs, context: context)

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
        for log in expenseLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        }
        for log in walkLogs {
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
            context.delete(log)
        }
        context.delete(session)
        context.safeSave()
        markDeletedSharedSessionState(sessionID: sessionUUID, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        context.safeSave()

        return SharedCareSessionDeleteResult(
            sessionID: sessionUUID,
            careLogIDs: careLogs.map(\.id),
            pottyLogIDs: pottyLogs.map(\.id),
            expenseLogIDs: expenseLogs.map(\.id),
            walkLogIDs: walkLogs.map(\.id),
            ledgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
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
        CloudSyncMutationRecorder.markModified(changedExpenseLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedWalkLogs, context: context, modifiedAt: cleanedAt)
        CloudSyncMutationRecorder.markModified(changedLedgerEvents, context: context, modifiedAt: cleanedAt)
        if !changedSessions.isEmpty ||
            !changedCareLogs.isEmpty ||
            !changedExpenseLogs.isEmpty ||
            !changedWalkLogs.isEmpty ||
            !changedLedgerEvents.isEmpty {
            context.safeSave()
        }

        return SharedCareLegacyNoteCleanupResult(
            sessionIDs: changedSessions.map(\.id),
            careLogIDs: changedCareLogs.map(\.id),
            expenseLogIDs: changedExpenseLogs.map(\.id),
            walkLogIDs: changedWalkLogs.map(\.id),
            ledgerEventIDs: changedLedgerEvents.map(\.id),
            missingSessionIDs: scan.missingSessionIDs,
            skippedOrphanCareLogIDs: scan.skippedOrphanCareLogIDs,
            skippedOrphanExpenseLogIDs: scan.skippedOrphanExpenseLogIDs,
            skippedOrphanWalkLogIDs: scan.skippedOrphanWalkLogIDs,
            skippedOrphanLedgerEventIDs: scan.skippedOrphanLedgerEventIDs
        )
    }

    @MainActor
    static func reconcile(_ session: SharedCareSession, context: ModelContext, reconciledAt: Date = Date()) {
        let sessionID = session.id.uuidString
        let careLogs = fetchCareLogs(sessionID: sessionID, context: context)
        let pottyLogs = fetchPottyLogs(sessionID: sessionID, context: context)
        let expenseLogs = fetchExpenseLogs(sessionID: sessionID, context: context)
        let walkLogs = fetchWalkLogs(sessionID: sessionID, context: context)

        guard !careLogs.isEmpty || !pottyLogs.isEmpty || !expenseLogs.isEmpty || !walkLogs.isEmpty else {
            CloudSyncMutationRecorder.markDeleted(session, context: context, deletedAt: reconciledAt)
            context.delete(session)
            return
        }

        _ = recoverStructuredMetadata(
            session: session,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs
        )

        session.note = SharedCareMetadata.userNoteForStorage(session.note)
        refreshStockOwnerMetadata(session: session, careLogs: careLogs)
        refreshSharedCareMetadata(session: session, careLogs: careLogs)
        refreshExpenseMetadata(session: session, expenseLogs: expenseLogs)
        refreshWalkMetadata(session: session, walkLogs: walkLogs)
        refreshPrimaryLegacyModel(session: session, careLogs: careLogs, pottyLogs: pottyLogs, expenseLogs: expenseLogs, walkLogs: walkLogs)
        markReconciledFactsModified(
            session: session,
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            expenseLogs: expenseLogs,
            walkLogs: walkLogs,
            context: context,
            modifiedAt: reconciledAt
        )
    }

    @MainActor
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

    @MainActor
    private static func refreshSharedCareMetadata(session _: SharedCareSession, careLogs: [PetCareLog]) {
        for log in careLogs where log.careType != .feeding {
            log.note = SharedCareMetadata.userNoteForStorage(log.note)
        }
    }

    @MainActor
    private static func refreshExpenseMetadata(session _: SharedCareSession, expenseLogs: [PetExpenseLog]) {
        for log in expenseLogs {
            log.note = SharedCareMetadata.userNoteForStorage(log.note)
        }
    }

    @MainActor
    private static func refreshWalkMetadata(session _: SharedCareSession, walkLogs: [PetWalkLog]) {
        for log in walkLogs {
            guard let notes = log.behaviorNotes else { continue }
            let cleaned = SharedCareMetadata.userNoteForStorage(notes)
            log.behaviorNotes = cleaned.isEmpty ? nil : cleaned
        }
    }

    @MainActor
    private static func recoverStructuredMetadata(
        session: SharedCareSession,
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) -> Bool {
        var changed = false
        let targetIds = orderedTargetIds(careLogs: careLogs, pottyLogs: pottyLogs, expenseLogs: expenseLogs, walkLogs: walkLogs)
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
        changed = recoverPrimaryLegacyModel(session: session, careLogs: careLogs, pottyLogs: pottyLogs, expenseLogs: expenseLogs, walkLogs: walkLogs) || changed
        return changed
    }

    @MainActor
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
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) -> Bool {
        let primary: (name: String, id: String)? = if let log = careLogs.first {
            ("PetCareLog", log.id.uuidString)
        } else if let log = pottyLogs.first {
            ("PetPottyLog", log.id.uuidString)
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

    @MainActor
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
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) {
        if let log = careLogs.first {
            session.primaryLegacyModelName = "PetCareLog"
            session.primaryLegacyModelId = log.id.uuidString
        } else if let log = pottyLogs.first {
            session.primaryLegacyModelName = "PetPottyLog"
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
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog]
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for pet in careLogs.compactMap(\.pet) + pottyLogs.compactMap(\.pet) + expenseLogs.compactMap(\.pet) + walkLogs.compactMap(\.pet) {
            let id = pet.id.uuidString
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    @MainActor
    private static func markReconciledFactsModified(
        session: SharedCareSession,
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog],
        context: ModelContext,
        modifiedAt: Date
    ) {
        CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(careLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(pottyLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(expenseLogs, context: context, modifiedAt: modifiedAt)
        CloudSyncMutationRecorder.markModified(walkLogs, context: context, modifiedAt: modifiedAt)
    }

    @MainActor
    private static func legacyMetadataScan(context: ModelContext) -> LegacyMetadataScan {
        let sessions = fetchSessionsWithLegacyMetadata(context: context)
        let careLogs = fetchCareLogsWithLegacyMetadata(context: context)
        let expenseLogs = fetchExpenseLogsWithLegacyMetadata(context: context)
        let walkLogs = fetchSharedWalkLogsWithLegacyMetadata(context: context)
        let ledgerEvents = fetchLedgerEventsWithLegacyMetadata(context: context)

        var candidateIDs = Set(sessions.map(\.id))
        for log in careLogs {
            appendSessionID(raw: log.sharedSessionId, legacyNote: log.note, to: &candidateIDs)
        }
        for log in expenseLogs {
            appendSessionID(raw: log.sharedSessionId, legacyNote: log.note, to: &candidateIDs)
        }
        for log in walkLogs {
            appendSessionID(raw: log.sharedSessionId, legacyNote: log.behaviorNotes ?? "", to: &candidateIDs)
        }
        for event in ledgerEvents {
            if let sessionID = SharedCareMetadata.legacySessionId(from: event.note) {
                candidateIDs.insert(sessionID)
            }
        }

        let missingSessionIDs = Set(candidateIDs.filter { fetchSession(id: $0, context: context) == nil })
        let existingSessionIDs = candidateIDs.subtracting(missingSessionIDs)
        var careLogsBySessionID: [UUID: [PetCareLog]] = [:]
        var expenseLogsBySessionID: [UUID: [PetExpenseLog]] = [:]
        var walkLogsBySessionID: [UUID: [PetWalkLog]] = [:]
        var ledgerEventsBySessionID: [UUID: [CareLedgerEvent]] = [:]
        var skippedOrphanCareLogs: [PetCareLog] = []
        var skippedOrphanExpenseLogs: [PetExpenseLog] = []
        var skippedOrphanWalkLogs: [PetWalkLog] = []
        var skippedOrphanLedgerEvents: [CareLedgerEvent] = []

        for log in careLogs {
            guard let sessionID = legacySessionID(raw: log.sharedSessionId, note: log.note),
                  existingSessionIDs.contains(sessionID) else {
                skippedOrphanCareLogs.append(log)
                continue
            }
            careLogsBySessionID[sessionID, default: []].append(log)
        }
        for log in expenseLogs {
            guard let sessionID = legacySessionID(raw: log.sharedSessionId, note: log.note),
                  existingSessionIDs.contains(sessionID) else {
                skippedOrphanExpenseLogs.append(log)
                continue
            }
            expenseLogsBySessionID[sessionID, default: []].append(log)
        }
        for log in walkLogs {
            guard let sessionID = legacySessionID(raw: log.sharedSessionId, note: log.behaviorNotes ?? ""),
                  existingSessionIDs.contains(sessionID) else {
                skippedOrphanWalkLogs.append(log)
                continue
            }
            walkLogsBySessionID[sessionID, default: []].append(log)
        }
        for event in ledgerEvents {
            guard let sessionID = SharedCareMetadata.legacySessionId(from: event.note),
                  existingSessionIDs.contains(sessionID) else {
                skippedOrphanLedgerEvents.append(event)
                continue
            }
            ledgerEventsBySessionID[sessionID, default: []].append(event)
        }

        return LegacyMetadataScan(
            sessionIDs: existingSessionIDs.sorted { $0.uuidString < $1.uuidString },
            missingSessionIDs: missingSessionIDs.sorted { $0.uuidString < $1.uuidString },
            careLogsBySessionID: careLogsBySessionID,
            expenseLogsBySessionID: expenseLogsBySessionID,
            walkLogsBySessionID: walkLogsBySessionID,
            ledgerEventsBySessionID: ledgerEventsBySessionID,
            skippedOrphanCareLogs: skippedOrphanCareLogs.sorted { $0.id.uuidString < $1.id.uuidString },
            skippedOrphanExpenseLogs: skippedOrphanExpenseLogs.sorted { $0.id.uuidString < $1.id.uuidString },
            skippedOrphanWalkLogs: skippedOrphanWalkLogs.sorted { $0.id.uuidString < $1.id.uuidString },
            skippedOrphanLedgerEvents: skippedOrphanLedgerEvents.sorted { $0.id.uuidString < $1.id.uuidString }
        )
    }

    private static func orphanDiagnostic(
        sourceModelName: String,
        recordID: UUID,
        legacyNote: String,
        legacyModelName: String? = nil,
        legacyModelId: String? = nil
    ) -> SharedCareLegacyOrphanNoteDiagnostic {
        SharedCareLegacyOrphanNoteDiagnostic(
            sourceModelName: sourceModelName,
            recordID: recordID,
            missingSessionID: SharedCareMetadata.legacySessionId(from: legacyNote),
            targetCount: SharedCareMetadata.targetCount(from: legacyNote),
            stockTotalGrams: SharedCareMetadata.stockTotalGrams(from: legacyNote),
            isStockOwner: SharedCareMetadata.isStockOwner(legacyNote),
            legacyModelName: legacyModelName,
            legacyModelId: legacyModelId,
            visibleNoteCharacterCount: SharedCareMetadata.visibleNote(legacyNote).count
        )
    }

    private static func legacySessionID(raw: String, note: String) -> UUID? {
        SharedCareMetadata.legacySessionId(from: note) ?? UUID(uuidString: raw)
    }

    private static func appendSessionID(raw: String, legacyNote: String, to ids: inout Set<UUID>) {
        guard let sessionID = legacySessionID(raw: raw, note: legacyNote) else { return }
        ids.insert(sessionID)
    }

    @MainActor
    private static func fetchSession(id: UUID, context: ModelContext) -> SharedCareSession? {
        var descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchFirstOrLog(descriptor, context: context, operation: "fetch session")
    }

    @MainActor
    private static func fetchSessionsWithLegacyMetadata(context: ModelContext) -> [SharedCareSession] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note sessions")
    }

    @MainActor
    private static func fetchCareLogsWithLegacyMetadata(context: ModelContext) -> [PetCareLog] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note care logs")
    }

    @MainActor
    private static func fetchExpenseLogsWithLegacyMetadata(context: ModelContext) -> [PetExpenseLog] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { log in
                log.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note expense logs")
    }

    @MainActor
    private static func fetchSharedWalkLogsWithLegacyMetadata(context: ModelContext) -> [PetWalkLog] {
        let descriptor = FetchDescriptor<PetWalkLog>(
            sortBy: [SortDescriptor(\.startDate)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared walk logs for legacy note cleanup")
            .filter { ($0.behaviorNotes).map(SharedCareMetadata.hasLegacyMetadata) ?? false }
    }

    @MainActor
    private static func fetchLedgerEventsWithLegacyMetadata(context: ModelContext) -> [CareLedgerEvent] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note ledger events")
    }

    @MainActor
    private static func fetchCareLogs(sessionID: String, context: ModelContext) -> [PetCareLog] {
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared care logs")
    }

    @MainActor
    private static func fetchPottyLogs(sessionID: String, context: ModelContext) -> [PetPottyLog] {
        let descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared potty logs")
    }

    @MainActor
    private static func fetchExpenseLogs(sessionID: String, context: ModelContext) -> [PetExpenseLog] {
        let descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared expense logs")
    }

    @MainActor
    private static func fetchWalkLogs(sessionID: String, context: ModelContext) -> [PetWalkLog] {
        let descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared walk logs")
    }

    @MainActor
    private static func ledgerEvents(
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog],
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let careLogIDs = Set(careLogs.map(\.id.uuidString))
        let pottyLogIDs = Set(pottyLogs.map(\.id.uuidString))
        let expenseLogIDs = Set(expenseLogs.map(\.id.uuidString))
        let walkLogIDs = Set(walkLogs.map(\.id.uuidString))
        return ledgerEvents(forLegacyModelName: "PetCareLog", ids: careLogIDs, context: context)
            + ledgerEvents(forLegacyModelName: "PetPottyLog", ids: pottyLogIDs, context: context)
            + ledgerEvents(forLegacyModelName: "PetExpenseLog", ids: expenseLogIDs, context: context)
            + ledgerEvents(forLegacyModelName: "PetWalkLog", ids: walkLogIDs, context: context)
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        ids: Set<String>,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        guard !ids.isEmpty else { return [] }
        var events: [CareLedgerEvent] = []
        for id in ids.sorted() {
            let descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.legacyModelName == modelName && event.legacyModelId == id
                }
            )
            events += fetchOrLog(
                descriptor,
                context: context,
                operation: "fetch shared-session ledger events for \(modelName)"
            )
        }
        return events
    }

    private static func uniqueByID<T>(_ values: [T], id: (T) -> UUID) -> [T] {
        var seen = Set<UUID>()
        var result: [T] = []
        for value in values {
            let valueID = id(value)
            guard !seen.contains(valueID) else { continue }
            seen.insert(valueID)
            result.append(value)
        }
        return result
    }

    @MainActor
    private static func fetchFirstOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> T? {
        fetchOrLog(descriptor, context: context, operation: operation).first
    }

    @MainActor
    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "SharedCareSessionMaintenance failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    @MainActor
    private static func markDeletedSharedSessionState(
        sessionID: UUID,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        do {
            try CloudSyncMetadataService.markDeleted(
                entityName: String(describing: SharedCareSession.self),
                localRecordId: sessionID,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId.flatMap(UUID.init(uuidString:)),
                context: context
            )
        } catch {
            OhanaLog.warning(
                "Cloud sync failed to mark deleted SharedCareSession:\(sessionID): \(error)",
                category: "CloudSync"
            )
        }
    }
}
