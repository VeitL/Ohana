import SwiftData
import SwiftUI

struct RecurringEconomyBoundariesBadView: View {
    let pet: Pet
    let questManager: QuestManager
    let context: ModelContext

    var body: some View {
        Button("Bad") {
            pet.coconutBalance += 1
            _ = questManager.awardAction(type: .feeding, pet: pet, context: context)
            _ = EconomyRewardDiscipline.awardCareAction(
                type: .feeding,
                pet: pet,
                context: context,
                questManager: questManager
            )
            if CoconutExchangeFeatureGate.isEnabled {
                print("UI-only exchange gate")
            }
        }
    }
}

struct RecurringEconomyUnconsumedFactCommand {
    let careEvents: CareEventRecording
    let context: ModelContext

    func record(pet: Pet, executorId: String) {
        let recorded = careEvents.recordCareFact(
            pet: pet,
            type: .feeding,
            amountMl: 0,
            context: context,
            executorId: executorId,
            reward: .feeding,
            quality: .none,
            date: Date(),
            source: .quickAction,
            createsLinkedPottyLog: false
        )
        print(recorded.result.logID)
    }
}

struct RecurringEconomyAllowlistedCareRewardWithoutPolicyCommand {
    let questManager: QuestManager
    let context: ModelContext

    func awardGeneratedCare(pet: Pet) {
        _ = EconomyRewardDiscipline.awardCareAction(
            type: .feeding,
            pet: pet,
            context: context,
            questManager: questManager
        )
    }

    func recordDoseResult(pet: Pet) {
        _ = EconomyRewardDiscipline.awardCareAction(
            type: .medication,
            pet: pet,
            context: context,
            questManager: questManager
        )
    }
}

struct RecurringEconomyMedicationDoseResultUnconsumedCommand {
    let context: ModelContext
    let services: AppServices

    func recordDose(medication: PetMedication, pet: Pet) {
        PetMedicationCommandExecutor(context: context, services: services).recordDose(
            medication: medication,
            pet: pet,
            awardCoconut: true,
            note: "bad.medication.dose"
        )
        services.medicationReminders.scheduleMedicationReminders(for: pet, context: context)
    }
}

enum RecurringEconomyOpenExecutorPolicy {
    static func executorCannotWrite(_ executorId: String?, context: ModelContext) -> Bool {
        guard let executorId,
              let id = UUID(uuidString: executorId) else {
            return true
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        guard let human = try? context.fetch(descriptor).first else { return true }
        return !EconomyWalletWritePolicy.canWrite(human)
    }
}

struct RecurringEconomyCareCommandResultUnconsumedCommand {
    let commandExecutor: QuickFeedCommandExecutor
    let pet: Pet

    func commitManual() {
        let result = commandExecutor.recordManual(
            pet: pet,
            targets: [pet],
            grams: 42,
            foodKind: .dry,
            saveAsDefault: true,
            foodRecords: [],
            allEvents: [],
            executorId: UUID().uuidString
        )
        print(result.grams)
        afterFoodLogSaved()
    }

    func afterFoodLogSaved() {}
}

struct RecurringEconomyQuickPottyResultUnconsumedCommand {
    let pottyCommandExecutor: QuickPottyCommandExecutor
    let pet: Pet
    let targetIDs: Set<UUID>
    let candidates: [Pet]

    func saveSelectionBeforeUnknownSharedPotty() {
        SharedPetSelectionMemory.saveSelection(
            targetIDs,
            sourcePet: pet,
            scope: "quickCare.potty",
            candidates: candidates
        )
        guard pottyCommandExecutor.recordUnknownSharedPotty(
            sourcePetID: pet.id,
            targetIDs: targetIDs,
            type: .perfectPoop,
            executorId: UUID().uuidString,
            date: Date()
        ) != nil else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func ignoreFullChangeResult() {
        _ = pottyCommandExecutor.recordLitterCare(
            sourcePetID: pet.id,
            targetIDs: targetIDs,
            executorId: UUID().uuidString,
            date: Date(),
            isFullChange: true
        )
        LitterCareSettingsStore.markFullChange(
            petKey: pet.id.uuidString,
            changedAt: Date(),
            cycleAnchor: Date()
        )
        showSaveConfirmation()
    }

    func showSaveConfirmation() {}
}

struct RecurringEconomySecondaryExecutorUncheckedCommand {
    let context: ModelContext

    func stop(sharedExecutorIds: [String], executorId: String?) {
        let executorIds = SharedCareParticipantIDs.normalized(sharedExecutorIds, preferredFirst: executorId)
        guard !CareFactWritePolicy.anyExecutorCannotWrite(executorIds, context: context) else {
            return
        }
        print(executorIds)
    }
}

struct RecurringEconomyCareDerivationDirectPublishCommand {
    let careEvents: CareEventRecording
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    func recordCareAndPublishDirectly(pet: Pet, executorId: String) {
        let recorded = careEvents.recordCareFact(
            pet: pet,
            type: .feeding,
            amountMl: 0,
            context: context,
            executorId: executorId,
            reward: .feeding,
            quality: .none,
            date: Date(),
            source: .quickAction,
            createsLinkedPottyLog: false
        )
        guard recorded.result.didWriteFact, recorded.result.allowsDerivedEffects else {
            AppPerformanceMonitor.shared.record("domain_command_noop", valueMS: 0, note: "bad.noop")
            return
        }
        revisions.publishDomainMutation(
            command: .quickCare(entityID: pet.id, action: "feed"),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: true,
            note: "bad.direct.publish"
        )
    }
}
