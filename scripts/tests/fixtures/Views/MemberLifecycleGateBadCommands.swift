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

    static func publishReminderEffect(event: Event, revisions: DomainRevisionPublishing) {
        if event.relatedEntityType == EntityKind.pet.rawValue,
           let petId = UUID(uuidString: event.relatedEntityId) {
            revisions.publishDomainMutation(
                .calendarChange,
                affectedEntityIDs: [petId],
                note: "bad.raw.effect.subject"
            )
        }
    }

    static func rawFeatureTaxonomyString() -> String {
        "pet_food_stock"
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

    static func restoreSchedules(backup: OhanaBackup) {
        let existingEventIds: Set<String> = []
        for dto in backup.events where !existingEventIds.contains(dto.id) {
            _ = dto
        }
    }

    static func markSkippedCloudApplySynced(result: CloudSyncRecordApplyResult, state: CloudSyncRecordState) {
        if result == .skippedUnsupported(entityName: "Event") {
            CloudSyncMetadataService.markSynced(state, ckRecordName: "bad", ckChangeTag: "bad", ckZoneName: "bad")
        }
    }

    static func neutralizeExistingReminderRowOnly(existing: Reminder, plan: AuthorizedDomainRehydratePlan) {
        makeReminderHistoryOnly(existing, plan: plan)
    }
}

enum DomainRehydrateDispositionBadFixture {
    case normalized
    case legacyHistoryOnly
    case quarantined(unregisteredType: String)

    var allowsPersistence: Bool {
        switch self {
        case .normalized, .legacyHistoryOnly, .quarantined:
            true
        }
    }

    var requiresHistoryOnlySchedule: Bool {
        switch self {
        case .legacyHistoryOnly:
            true
        case .normalized, .quarantined:
            false
        }
    }
}
