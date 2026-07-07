import Foundation
import SwiftData

enum MemberLifecycleGateGoodCommandService {
    @MainActor
    static func recordCare(pet: Pet, context: ModelContext) {
        let intent = DomainCareFactCreateIntent(
            kind: .care(
                type: .feeding,
                amountGrams: 0,
                amountMl: 0,
                note: "",
                foodKind: .dry,
                treatKind: nil,
                autoFeedDedupKey: "",
                sharedSessionId: ""
            ),
            occurredAt: Date()
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "good.fixture"
        ) else { return }
        _ = DomainCareFactWriter.createCareLog(plan: write, context: context)
    }

    static func petOwnedEvent(_ event: Event, pet: Pet) -> Bool {
        MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: pet.id.uuidString)
    }

    static func publishReminderEffect(event: Event, revisions: DomainRevisionPublishing) {
        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            catalog: DomainSubjectResolutionCatalog()
        )
        revisions.publishDomainMutation(
            .calendarChange,
            affectedEntityIDs: resolution.affectedEntityIDs,
            note: "good.typed.effect.subject"
        )
    }

    @MainActor
    static func publishDerivedMutationWithPlan(pet: Pet, derivations: CareDerivationExecutor, context: ModelContext) {
        guard let plan = DomainEffectWriteAuthorizer.authorizePetEffect(
            pet: pet,
            writeKind: .care,
            context: context,
            logPrefix: "good.fixture.derived"
        ) else { return }
        derivations.derive(
            .derivedMutation(
                command: .quickCare(entityID: pet.id, action: "goodDerivedSubject"),
                effectPlan: plan,
                note: "good.typed.derived.subject"
            )
        )
    }

    @MainActor
    static func recordLedgerWithDispatcher(
        pet: Pet,
        plan: AuthorizedDomainMemberFactWrite,
        careLedger: CareLedgerRecording,
        context: ModelContext
    ) {
        DomainMemberFactEffectsDispatcher.run(plan: plan) { _ in
            careLedger.record(
                occurredAt: Date(),
                actorKind: .unknown,
                actorId: nil,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .care,
                actionType: "goodEffectPlan",
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
    }

    @MainActor
    static func stageRewardWithDispatcher(
        plan: AuthorizedDomainEffectWrite,
        questManager: QuestManager,
        human: Human,
        context: ModelContext
    ) throws {
        var rewardError: Error?
        DomainEffectDispatcher.runEconomy(plan: plan) { _ in
            do {
                try questManager.stageSpecialCoconutReward(
                    amount: 1,
                    emoji: "🎯",
                    title: "Good reward",
                    actorId: human.id.uuidString,
                    actorName: human.name,
                    source: .familyTask,
                    sourceModelName: "GoodFixture",
                    sourceModelId: human.id.uuidString,
                    metadataJSON: nil,
                    transactionKey: "good:\(human.id.uuidString)",
                    context: context
                )
            } catch {
                rewardError = error
            }
        }
        if let rewardError {
            throw rewardError
        }
    }

    static func registryFeatureTaxonomyString() -> String {
        DomainEntityLinkRegistry.petFoodStock
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

    static func deletePetReminder(event: Event, mutation: AuthorizedDomainScheduleMutation, context: ModelContext) {
        let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
        DomainScheduleEffectsDispatcher.dispatch(delete: result)
    }

    static func deletePetReminderWithDeferredEffects(
        event: Event,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) -> [String] {
        let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
        return result.notificationIdsToCancel
    }

    static func completeReminder(
        reminder: Reminder,
        mutation: AuthorizedDomainScheduleMutation,
        context: ModelContext
    ) {
        DomainScheduleWriter.completeReminder(
            reminder,
            mutation: mutation,
            completedBy: nil,
            completedAt: Date(),
            context: context
        )
    }

    static func applyBackup(snapshot: DomainPetRehydrateSnapshot, context: ModelContext) throws {
        try DomainGeneralRehydrateWriter.upsertPet(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )
    }
}
