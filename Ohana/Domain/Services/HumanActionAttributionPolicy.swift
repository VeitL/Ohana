//
//  HumanActionAttributionPolicy.swift
//  Ohana
//
//  Validates draft-scoped Human attribution before user facts are persisted.
//

import Foundation
import SwiftData

nonisolated enum HumanActionAttributionPolicy {
    @MainActor
    static func activeHumanID(_ rawID: String?, context: ModelContext) -> String? {
        guard let rawID,
              let id = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        guard let human = try? context.fetch(descriptor).first,
              human.passedAwayDate == nil else { return nil }
        return human.id.uuidString
    }
}

extension ExpenseActorAttribution {
    @MainActor
    func validated(context: ModelContext) -> ExpenseActorAttribution {
        // Keep an explicitly supplied executor token long enough for the
        // downstream reward resolver to distinguish "missing executor" from
        // "no executor supplied". The write kernel still persists only its
        // resolved live Human (or nil), while an unresolved explicit actor
        // correctly suppresses reward side effects.
        let normalizedExecutorId = EconomyRewardOwnerResolver.normalizedExecutorId(executorId)
        return ExpenseActorAttribution(
            executorId: HumanActionAttributionPolicy.activeHumanID(normalizedExecutorId, context: context)
                ?? normalizedExecutorId,
            recordedByHumanId: HumanActionAttributionPolicy.activeHumanID(recordedByHumanId, context: context)
        )
    }
}
