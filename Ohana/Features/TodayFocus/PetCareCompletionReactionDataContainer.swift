import Foundation
import SwiftData

@MainActor
enum PetCareCompletionReactionDataContainer {
    static func snapshot(
        for trigger: PetCareCompletionTrigger,
        occurredAt: Date,
        context: ModelContext
    ) -> PetCareCompletionReactionSnapshot? {
        let petID = trigger.petID
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == petID
            }
        )
        descriptor.fetchLimit = 1
        guard let pet = try? context.fetch(descriptor).first, // route-first-frame: allow event-driven single-row lookup after persisted care
              !pet.hasPassedAway else { return nil }

        return PetCareCompletionReactionSnapshot(
            petID: pet.id,
            petName: pet.name,
            primaryTagID: pet.personalityTagIdList.first,
            kind: trigger.kind,
            occurredAt: occurredAt
        )
    }
}
