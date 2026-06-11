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
        let sessions = (try? context.fetch(FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { session in
                session.actionKindRaw == unknownKind
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
        let targetSessions = sessions.filter { $0.targetPetIds.contains(petID) }
        guard !targetSessions.isEmpty else { return [] }

        let targetCounts = Dictionary(uniqueKeysWithValues: targetSessions.map { ($0.id.uuidString, max(1, $0.targetPetIds.count)) })
        let sessionIDs = Set(targetCounts.keys)
        let logs = (try? context.fetch(FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { log in
                log.sharedSessionId != ""
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []

        return logs
            .filter { $0.pet == nil && sessionIDs.contains($0.sharedSessionId) }
            .map { .unknownPotty($0, targetCount: targetCounts[$0.sharedSessionId] ?? 1) }
    }
}
