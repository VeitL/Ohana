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
        DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
    }

    static func applyBackup(snapshot: DomainPetRehydrateSnapshot, context: ModelContext) throws {
        try DomainGeneralRehydrateWriter.upsertPet(
            snapshot: snapshot,
            source: .backupRestore,
            context: context
        )
    }
}
