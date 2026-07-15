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
        ExpenseActorAttribution(
            executorId: HumanActionAttributionPolicy.activeHumanID(executorId, context: context),
            recordedByHumanId: HumanActionAttributionPolicy.activeHumanID(recordedByHumanId, context: context)
        )
    }
}
