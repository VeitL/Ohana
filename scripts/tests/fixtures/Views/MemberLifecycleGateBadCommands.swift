import SwiftData

enum MemberLifecycleGateBadCommandService {
    @MainActor
    static func recordCare(pet: Pet, context: ModelContext) {
        guard !pet.hasPassedAway else { return }
        context.insert(PetCareLog(type: .feeding, pet: pet))
    }

    static func petOwnedEvent(_ event: Event, pet: Pet) -> Bool {
        event.relatedEntityType == EntityKind.pet.rawValue &&
            event.relatedEntityId == pet.id.uuidString
    }

    @MainActor
    static func createPetReminder(pet: Pet, context: ModelContext) {
        let event = Event(
            title: "Vet",
            startDate: Date(),
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(event)
    }

    static func applyBackup(context: ModelContext) {
        context.insert(Pet(name: "Bypass"))
    }
}
