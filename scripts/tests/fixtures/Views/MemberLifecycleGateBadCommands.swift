import Foundation
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

    @MainActor
    static func publishDerivedMutationWithRawSubject(pet: Pet, derivations: CareDerivationExecutor) {
        derivations.derive(
            .derivedMutation(
                command: .quickCare(entityID: pet.id, action: "badRawDerivedSubject"),
                affectedEntityIDs: [pet.id],
                note: "bad.raw.derived.subject"
            )
        )
    }

    @MainActor
    static func recordLedgerWithoutDispatcher(pet: Pet, careLedger: CareLedgerRecording, context: ModelContext) {
        careLedger.record(
            occurredAt: Date(),
            actorKind: .unknown,
            actorId: nil,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: "badEffectBypass",
            amountValue: 0,
            amountUnit: "",
            note: "",
            source: .service,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: nil,
            context: context,
            save: false
        )
    }

    @MainActor
    static func stageRewardWithoutDispatcher(questManager: QuestManager, human: Human, context: ModelContext) throws {
        try questManager.stageSpecialCoconutReward(
            amount: 1,
            emoji: "🎯",
            title: "Bad reward",
            actorId: human.id.uuidString,
            actorName: human.name,
            source: .familyTask,
            sourceModelName: "BadFixture",
            sourceModelId: human.id.uuidString,
            metadataJSON: nil,
            transactionKey: "bad:\(human.id.uuidString)",
            context: context
        )
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

    static func deletePetReminderBypass(event: Event, context: ModelContext) {
        context.delete(event)
    }

    static func deletePetReminderWithoutEffects(
        event: Event,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) {
        DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
    }

    static func deleteRenamedScheduleValueBypass(
        obsoleteSchedule: Event,
        context: ModelContext
    ) {
        context.delete(obsoleteSchedule)
    }

    static func scheduleDeleteResultCommentBypass(
        event: Event,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) {
        let orphanedDeletion = DomainScheduleWriter.deleteEvent(
            event,
            mutation: mutation,
            context: context
        )
        // DomainScheduleEffectsDispatcher.dispatch(delete: orphanedDeletion)
        // return orphanedDeletion.notificationIdsToCancel
        _ = orphanedDeletion.didDelete
    }

    static func scheduleDeleteResultStringBypass(
        event: Event,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) {
        let stringOnlyDeletion = DomainScheduleWriter.deleteEvent(
            event,
            mutation: mutation,
            context: context
        )
        let fakeSink = "DomainScheduleEffectsDispatcher.dispatch(delete: stringOnlyDeletion)"
        _ = fakeSink
        _ = stringOnlyDeletion.didDelete
    }

    static func scheduleDeleteResultWrongBindingBypass(
        firstEvent: Event,
        secondEvent: Event,
        firstMutation: AuthorizedDomainScheduleMutation,
        secondMutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) {
        let abandonedDeletion = DomainScheduleWriter.deleteEvent(
            firstEvent,
            mutation: firstMutation,
            context: context
        )
        let handledDeletion = DomainScheduleWriter.deleteEvent(
            secondEvent,
            mutation: secondMutation,
            context: context
        )
        DomainScheduleEffectsDispatcher.dispatch(delete: handledDeletion)
        _ = abandonedDeletion.didDelete
    }

    static func scheduleDeleteResultUnrelatedIDsBypass(
        event: Event,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) {
        let discardedDeletion = DomainScheduleWriter.deleteEvent(
            event,
            mutation: mutation,
            context: context
        )
        let notificationIdsToCancel: [String] = []
        _ = notificationIdsToCancel
        _ = discardedDeletion.didDelete
    }

    static func completeReminderBypass(reminder: Reminder) {
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        reminder.completedBy = "bad"
        reminder.event?.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
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
    case rejected(reason: String)

    var allowsPersistence: Bool {
        switch self {
        case .normalized, .legacyHistoryOnly, .quarantined, .rejected:
            true
        }
    }

    var requiresHistoryOnlySchedule: Bool {
        switch self {
        case .legacyHistoryOnly:
            true
        case .normalized, .quarantined, .rejected:
            false
        }
    }
}
