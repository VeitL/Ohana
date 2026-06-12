//
//  QuickPottyUnknownClaimStore.swift
//  Ohana
//

import Foundation
import SwiftData

enum QuickPottyUnknownClaimStore {
    @MainActor
    static func items(for pet: Pet, context: ModelContext) -> [PoopLogItem] {
        let petID = pet.id.uuidString
        let unknownKind = SharedCareActionKind.pottyUnknown.rawValue
        let sessions = fetchOrLog(FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.actionKindRaw == unknownKind
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ), context: context, operation: "fetch unknown potty sessions")
        let targetSessions = sessions.filter { $0.targetPetIds.contains(petID) }
        guard !targetSessions.isEmpty else { return [] }

        let targetCounts = Dictionary(uniqueKeysWithValues: targetSessions.map { ($0.id.uuidString, max(1, $0.targetPetIds.count)) })
        let logs = targetCounts.keys.flatMap { sessionID in
            fetchOrLog(FetchDescriptor<PetPottyLog>(
                predicate: #Predicate<PetPottyLog> { log in
                    log.sharedSessionId == sessionID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ), context: context, operation: "fetch unknown potty logs")
        }

        return logs
            .filter { $0.pet == nil }
            .sorted { $0.date > $1.date }
            .map { .unknownPotty($0, targetCount: targetCounts[$0.sharedSessionId] ?? 1) }
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
                "QuickPottyUnknownClaimStore failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }
}
