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

enum SharedCareSessionMaintenance {
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
    static func reconcileAfterDeletingChild(sharedSessionId: String, context: ModelContext) {
        guard let sessionID = UUID(uuidString: sharedSessionId),
              let session = fetchSession(id: sessionID, context: context) else {
            return
        }
        reconcile(session, context: context)
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
        return (try? context.fetch(descriptor)) ?? []
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

        let targetIds = orderedTargetIds(careLogs: careLogs, pottyLogs: pottyLogs, expenseLogs: expenseLogs, walkLogs: walkLogs)
        if !targetIds.isEmpty {
            session.targetPetIdsRaw = targetIds.joined(separator: "|")
        }

        if !careLogs.isEmpty {
            session.totalAmountGrams = careLogs.reduce(0) { $0 + max(0, $1.amountGrams) }
            session.totalAmountMl = careLogs.reduce(0) { $0 + max(0, $1.amountMl) }
        }
        if !expenseLogs.isEmpty {
            session.totalExpenseAmount = expenseLogs.reduce(0) { $0 + $1.amount }
            if let category = expenseLogs.first?.expenseCategory {
                session.expenseCategoryRaw = category.rawValue
            }
        }

        refreshStockOwnerMetadata(session: session, careLogs: careLogs)
        refreshSharedCareMetadata(session: session, careLogs: careLogs)
        refreshExpenseMetadata(session: session, expenseLogs: expenseLogs)
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

        let ownerLog = feedingLogs.first { $0.pet?.id.uuidString == session.stockOwnerPetId }
            ?? feedingLogs.first { $0.pet?.id.uuidString == session.sourcePetId }
            ?? feedingLogs[0]
        session.stockOwnerPetId = ownerLog.pet?.id.uuidString ?? ""

        let prefix = SharedCareMetadata.prefix(for: session.actionKind)
        for log in feedingLogs {
            log.note = SharedCareMetadata.note(
                prefix: prefix,
                sessionId: session.id,
                targetCount: feedingLogs.count,
                visibleNote: SharedCareMetadata.visibleNote(log.note)
            )
        }
    }

    @MainActor
    private static func refreshSharedCareMetadata(session: SharedCareSession, careLogs: [PetCareLog]) {
        let prefix = SharedCareMetadata.prefix(for: session.actionKind)
        for log in careLogs where log.careType != .feeding {
            log.note = SharedCareMetadata.note(
                prefix: prefix,
                sessionId: session.id,
                targetCount: careLogs.count,
                visibleNote: SharedCareMetadata.visibleNote(log.note)
            )
        }
    }

    @MainActor
    private static func refreshExpenseMetadata(session: SharedCareSession, expenseLogs: [PetExpenseLog]) {
        for log in expenseLogs {
            log.note = SharedCareMetadata.note(
                prefix: SharedCareMetadata.expenseNotePrefix,
                sessionId: session.id,
                targetCount: expenseLogs.count,
                visibleNote: SharedCareMetadata.visibleNote(log.note)
            )
        }
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
    private static func fetchSession(id: UUID, context: ModelContext) -> SharedCareSession? {
        var descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @MainActor
    private static func fetchCareLogs(sessionID: String, context: ModelContext) -> [PetCareLog] {
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchPottyLogs(sessionID: String, context: ModelContext) -> [PetPottyLog] {
        let descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchExpenseLogs(sessionID: String, context: ModelContext) -> [PetExpenseLog] {
        let descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchWalkLogs(sessionID: String, context: ModelContext) -> [PetWalkLog] {
        let descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
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
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == modelName
            }
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { event in
            ids.contains(event.legacyModelId ?? "")
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
