//
//  SharedCareSessionMaintenance+Queries.swift
//  Ohana
//

import Foundation
import SwiftData

nonisolated extension SharedCareSessionMaintenance {
    static func legacyMetadataScan(context: ModelContext) -> LegacyMetadataScan {
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

    static func orphanDiagnostic(
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

    static func legacySessionID(raw: String, note: String) -> UUID? {
        SharedCareMetadata.legacySessionId(from: note) ?? UUID(uuidString: raw)
    }

    static func appendSessionID(raw: String, legacyNote: String, to ids: inout Set<UUID>) {
        guard let sessionID = legacySessionID(raw: raw, note: legacyNote) else { return }
        ids.insert(sessionID)
    }

    static func sessionIDsReferencingHygieneLog(
        logID: UUID,
        ledgerEvents: [CareLedgerEvent],
        context: ModelContext
    ) -> [UUID] {
        var ids = Set(ledgerEvents.compactMap { sharedSessionID(from: $0.metadataJSON) })
        var hygieneDescriptor = FetchDescriptor<PetHygieneLog>(
            predicate: #Predicate<PetHygieneLog> { log in
                log.id == logID
            }
        )
        hygieneDescriptor.fetchLimit = 1
        if let log = fetchOrLog(hygieneDescriptor, context: context, operation: "fetch shared hygiene child").first,
           let sessionID = UUID(uuidString: log.sharedSessionId) {
            ids.insert(sessionID)
        }
        let idString = logID.uuidString
        let descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.primaryLegacyModelName == "PetHygieneLog" && session.primaryLegacyModelId == idString
            },
            sortBy: [SortDescriptor(\.date)]
        )
        for session in fetchOrLog(descriptor, context: context, operation: "fetch shared hygiene sessions") {
            ids.insert(session.id)
        }
        return ids.sorted { $0.uuidString < $1.uuidString }
    }

    static func sharedSessionID(from metadataJSON: String) -> UUID? {
        guard let data = metadataJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["sharedSessionId"] as? String else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    static func fetchSession(id: UUID, context: ModelContext) -> SharedCareSession? {
        var descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchFirstOrLog(descriptor, context: context, operation: "fetch session")
    }

    static func fetchSessionsWithLegacyMetadata(context: ModelContext) -> [SharedCareSession] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note sessions")
    }

    static func fetchCareLogsWithLegacyMetadata(context: ModelContext) -> [PetCareLog] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note care logs")
    }

    static func fetchExpenseLogsWithLegacyMetadata(context: ModelContext) -> [PetExpenseLog] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { log in
                log.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note expense logs")
    }

    static func fetchSharedWalkLogsWithLegacyMetadata(context: ModelContext) -> [PetWalkLog] {
        let descriptor = FetchDescriptor<PetWalkLog>(
            sortBy: [SortDescriptor(\.startDate)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared walk logs for legacy note cleanup")
            .filter { ($0.behaviorNotes).map(SharedCareMetadata.hasLegacyMetadata) ?? false }
    }

    static func fetchLedgerEventsWithLegacyMetadata(context: ModelContext) -> [CareLedgerEvent] {
        let marker = SharedCareMetadata.legacyMetadataMarker
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.note.contains(marker)
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch legacy shared-care note ledger events")
    }

    static func fetchCareLogs(sessionID: String, context: ModelContext) -> [PetCareLog] {
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared care logs")
    }

    static func fetchPottyLogs(sessionID: String, context: ModelContext) -> [PetPottyLog] {
        let descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared potty logs")
    }

    static func fetchHygieneLogs(session: SharedCareSession, context: ModelContext) -> [PetHygieneLog] {
        let sessionID = session.id.uuidString
        let direct = fetchHygieneLogs(sessionID: sessionID, context: context)
        let ids = hygieneLogIDs(session: session, context: context)
        var logs: [PetHygieneLog] = []
        for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
            var descriptor = FetchDescriptor<PetHygieneLog>(
                predicate: #Predicate<PetHygieneLog> { log in
                    log.id == id
                },
                sortBy: [SortDescriptor(\.date)]
            )
            descriptor.fetchLimit = 1
            logs += fetchOrLog(descriptor, context: context, operation: "fetch shared hygiene log")
        }
        return uniqueByID(direct + logs, id: { $0.id })
    }

    static func fetchHygieneLogs(sessionID: String, context: ModelContext) -> [PetHygieneLog] {
        let descriptor = FetchDescriptor<PetHygieneLog>(
            predicate: #Predicate<PetHygieneLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared hygiene logs")
    }

    static func hygieneLogIDs(session: SharedCareSession, context: ModelContext) -> Set<UUID> {
        var ids = Set<UUID>()
        if session.primaryLegacyModelName == "PetHygieneLog",
           let primaryID = UUID(uuidString: session.primaryLegacyModelId) {
            ids.insert(primaryID)
        }

        let sessionID = session.id
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == "PetHygieneLog"
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        let events = fetchOrLog(descriptor, context: context, operation: "fetch shared hygiene ledger events")
        for event in events where sharedSessionID(from: event.metadataJSON) == sessionID || event.metadataJSON.contains(sessionID.uuidString) {
            if let idString = event.legacyModelId,
               let id = UUID(uuidString: idString) {
                ids.insert(id)
            }
        }
        return ids
    }

    static func fetchExpenseLogs(sessionID: String, context: ModelContext) -> [PetExpenseLog] {
        let descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared expense logs")
    }

    static func fetchWalkLogs(sessionID: String, context: ModelContext) -> [PetWalkLog] {
        let descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { log in
                log.sharedSessionId == sessionID
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch shared walk logs")
    }

    static func ledgerEvents(
        careLogs: [PetCareLog],
        pottyLogs: [PetPottyLog],
        hygieneLogs: [PetHygieneLog],
        expenseLogs: [PetExpenseLog],
        walkLogs: [PetWalkLog],
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let careLogIDs = Set(careLogs.map(\.id.uuidString))
        let pottyLogIDs = Set(pottyLogs.map(\.id.uuidString))
        let hygieneLogIDs = Set(hygieneLogs.map(\.id.uuidString))
        let expenseLogIDs = Set(expenseLogs.map(\.id.uuidString))
        let walkLogIDs = Set(walkLogs.map(\.id.uuidString))
        return ledgerEvents(forLegacyModelName: "PetCareLog", ids: careLogIDs, context: context)
            + ledgerEvents(forLegacyModelName: "PetPottyLog", ids: pottyLogIDs, context: context)
            + ledgerEvents(forLegacyModelName: "PetHygieneLog", ids: hygieneLogIDs, context: context)
            + ledgerEvents(forLegacyModelName: "PetExpenseLog", ids: expenseLogIDs, context: context)
            + ledgerEvents(forLegacyModelName: "PetWalkLog", ids: walkLogIDs, context: context)
    }

    static func ledgerEvents(
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

    static func uniqueByID<T>(_ values: [T], id: (T) -> UUID) -> [T] {
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

    static func fetchFirstOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> T? {
        fetchOrLog(descriptor, context: context, operation: operation).first
    }

    static func fetchOrLog<T: PersistentModel>(
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

    static func markDeletedSharedSessionState(
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
