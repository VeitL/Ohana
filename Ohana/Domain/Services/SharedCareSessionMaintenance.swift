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

struct SharedCareLegacyNoteCleanupResult: Equatable {
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
        let hygieneLogs = fetchHygieneLogs(session: session, context: context)
        let expenseLogs = fetchExpenseLogs(sessionID: sessionID, context: context)
        let walkLogs = fetchWalkLogs(sessionID: sessionID, context: context)
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
        context.safeSave()
        markDeletedSharedSessionState(sessionID: sessionUUID, context: context, deletedAt: deletedAt, deletedByHumanId: deletedByHumanId)
        context.safeSave()

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
        if !changedSessions.isEmpty ||
            !changedCareLogs.isEmpty ||
            !changedHygieneLogs.isEmpty ||
            !changedExpenseLogs.isEmpty ||
            !changedWalkLogs.isEmpty ||
            !changedLedgerEvents.isEmpty {
            context.safeSave()
        }

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
            skippedOrphanLedgerEventIDs: scan.skippedOrphanLedgerEventIDs
        )
    }

    @MainActor
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

    @MainActor
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
