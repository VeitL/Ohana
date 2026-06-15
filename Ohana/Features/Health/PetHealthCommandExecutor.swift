//
//  PetHealthCommandExecutor.swift
//  Ohana
//

import Foundation
import SwiftData

@MainActor
struct PetHealthCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    private let derivations: CareDerivationExecutor
    let questManager: QuestManager
    let careLedger: CareLedgerRecording
    let reminderScheduling: ReminderSchedulingManaging
    let oasisRewards: OasisRewardManaging

    init(context: ModelContext) {
        let questManager = QuestManager()
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            questManager: questManager,
            careLedger: CareLedgerService(),
            reminderScheduling: ReminderSchedulingManager(),
            oasisRewards: StaticOasisRewardManager(
                activeHumanSelection: UserDefaultsActiveHumanSelection(),
                wallet: SwiftDataCoconutWalletManager(),
                questManager: questManager
            )
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        let questManager = QuestManager()
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: questManager,
            careLedger: CareLedgerService(),
            reminderScheduling: ReminderSchedulingManager(),
            oasisRewards: StaticOasisRewardManager(
                activeHumanSelection: UserDefaultsActiveHumanSelection(),
                wallet: SwiftDataCoconutWalletManager(),
                questManager: questManager
            )
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            careLedger: services.careLedger,
            reminderScheduling: services.reminderScheduling,
            oasisRewards: services.oasisRewards
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        careLedger: CareLedgerRecording,
        reminderScheduling: ReminderSchedulingManaging,
        oasisRewards: OasisRewardManaging
    ) {
        self.context = context
        self.revisions = revisions
        derivations = CareDerivationExecutor(revisions: revisions)
        self.questManager = questManager
        self.careLedger = careLedger
        self.reminderScheduling = reminderScheduling
        self.oasisRewards = oasisRewards
    }

    @discardableResult
    func recordHealth(
        pet: Pet,
        input: PetHealthRecordCommandInput,
        awardsReward: Bool = true,
        schedulesReminderNotification: Bool = true,
        note: String
    ) -> PetHealthCommandResult? {
        guard let result = PetHealthCommandService.recordHealth(
            pet: pet,
            input: input,
            context: context,
            awardsReward: awardsReward,
            schedulesReminderNotification: schedulesReminderNotification,
            questManager: questManager,
            careLedger: careLedger,
            reminderScheduling: reminderScheduling,
            oasisRewards: oasisRewards
        ) else {
            derivations.derive(
                .noOp(
                    command: .petHealthRecord(petID: pet.id, type: input.type.rawValue),
                    affectedEntityIDs: [pet.id],
                    note: "pet.health.readOnly"
                )
            )
            return nil
        }
        deriveHealthRecord(result, type: input.type.rawValue, factDate: input.date, note: note)
        return result
    }

    @discardableResult
    func recordSymptom(
        pet: Pet,
        input: PetSymptomCommandInput,
        note: String,
        emptyNote: String = "pet.symptom.empty"
    ) -> PetSymptomCommandResult? {
        guard let result = PetSymptomCommandService.recordSymptom(pet: pet, input: input, context: context, careLedger: careLedger) else {
            derivations.derive(
                .noOp(
                    command: .petHealthRecord(petID: pet.id, type: "symptom"),
                    affectedEntityIDs: [pet.id],
                    note: emptyNote
                )
            )
            return nil
        }
        revisions.publishPetSymptom(result, note: note)
        return result
    }

    @discardableResult
    func recordHeatCycle(
        pet: Pet,
        input: PetHeatCycleCommandInput,
        note: String
        ) -> PetHeatCycleCommandResult? {
        guard let result = PetHeatCycleCommandService.recordHeatCycle(pet: pet, input: input, context: context) else {
            derivations.derive(
                .noOp(
                    command: .petHealthRecord(petID: pet.id, type: "heat"),
                    affectedEntityIDs: [pet.id],
                    note: "pet.health.readOnly"
                )
            )
            return nil
        }
        revisions.publishPetHeatCycle(result, note: note)
        return result
    }

    @discardableResult
    func deleteHealthLog(_ log: PetHealthLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteHealthLog(log, pet: pet, context: context)
        if result.didDelete {
            revisions.publishPetHealthDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    func deleteSymptomLog(_ log: SymptomLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteSymptomLog(log, pet: pet, context: context)
        if result.didDelete {
            revisions.publishPetHealthDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    func deleteHeatCycleLog(_ log: HeatCycleLog, pet: Pet, note: String) -> PetHealthDeleteResult {
        let result = PetHealthDeleteCommandService.deleteHeatCycleLog(log, pet: pet, context: context)
        if result.didDelete {
            revisions.publishPetHealthDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    private func deriveHealthRecord(
        _ result: PetHealthCommandResult,
        type: String,
        factDate: Date,
        note: String
    ) -> CareDerivationResult {
        var affected: Set<UUID> = [result.subjectID, result.logID]
        if let expenseLogID = result.expenseLogID {
            affected.insert(expenseLogID)
        }
        if let eventID = result.eventID {
            affected.insert(eventID)
        }
        if let reminderID = result.reminderID {
            affected.insert(reminderID)
        }
        return derivations.derive(
            .active(
                disposition: result.allowsDerivedEffects ? .active : .noOp,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: result.subjectID,
                    logIDs: [result.logID],
                    factDate: factDate,
                    operationDate: factDate
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: .petHealthRecord(petID: result.subjectID, type: type),
                    affectedEntityIDs: affected,
                    note: note
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: result.coconutDelta,
                    petDelta: 0
                ),
                noopNote: note
            )
        )
    }
}
