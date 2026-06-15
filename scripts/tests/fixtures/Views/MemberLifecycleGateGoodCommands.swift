import SwiftData

enum MemberLifecycleGateGoodCommandService {
    @MainActor
    static func recordCare(pet: Pet, context: ModelContext) {
        let disposition = MemberLifecycleGate.disposition(pet: pet, writeKind: .care)
        guard disposition.allowsCareFactWrite else { return }
        context.insert(PetCareLog(type: .feeding, pet: pet))
    }

    static func petOwnedEvent(_ event: Event, pet: Pet) -> Bool {
        MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: pet.id.uuidString)
    }

    @MainActor
    static func createPetReminder(pet: Pet, context: ModelContext) {
        let intent = DomainScheduleCreateIntent(
            title: "Vet",
            startDate: Date(),
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString,
            writeKind: .care
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
            return
        }
        _ = DomainScheduleWriter.createEvent(plan: plan, context: context)
    }

    static func applyBackup(snapshot: DomainPetRehydrateSnapshot, context: ModelContext) throws {
        try DomainGeneralRehydrateWriter.upsertPet(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )
    }
}
