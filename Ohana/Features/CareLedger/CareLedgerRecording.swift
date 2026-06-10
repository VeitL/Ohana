import Foundation
import SwiftData

@MainActor
protocol CareLedgerRecording {
    @discardableResult
    func record(
        occurredAt: Date,
        actorKind: CareLedgerActorKind,
        actorId: String?,
        subjectKind: CareLedgerSubjectKind,
        subjectId: String?,
        eventKind: CareLedgerEventKind,
        actionType: String,
        amountValue: Double,
        amountUnit: String,
        note: String,
        source: CareLedgerSource,
        sourceEventId: String?,
        sourceReminderId: String?,
        legacyModelName: String?,
        legacyModelId: String?,
        coconutDelta: Int,
        rewardLogId: String?,
        privacyFieldRaw: String?,
        metadataJSON: String,
        context: ModelContext,
        save: Bool
    ) -> CareLedgerEvent

    func recordReminderState(
        reminder: Reminder,
        actionType: String,
        actorId: String?,
        source: CareLedgerSource,
        context: ModelContext,
        save: Bool
    )

    func recordPetCare(
        log: PetCareLog,
        pet: Pet,
        source: CareLedgerSource,
        sourceEventId: String?,
        sourceReminderId: String?,
        coconutDelta: Int,
        metadataJSON: String,
        context: ModelContext,
        save: Bool
    )

    func recordPetPotty(
        log: PetPottyLog,
        pet: Pet,
        source: CareLedgerSource,
        coconutDelta: Int,
        metadataJSON: String,
        context: ModelContext,
        save: Bool
    )

    func rewardDelta(_ reward: (humanGot: Int, petGot: Int)?) -> Int
    func rewardMetadata(_ reward: (humanGot: Int, petGot: Int)?, questManager: QuestManager) -> String
    func syncOasisTreeEnergyIfNeeded(metadataJSON: String, context: ModelContext)

    @discardableResult
    func recordEventCompletionReward(
        event: Event,
        occurrenceDate: Date,
        actorId: String?,
        coconutDelta: Int,
        occurredAt: Date,
        context: ModelContext
    ) -> CareLedgerEvent

    @discardableResult
    func recordCoconut(
        delta: Int,
        title: String,
        actorId: String?,
        actorName: String?,
        source: CareLedgerSource,
        context: ModelContext
    ) -> CareLedgerEvent
}

@MainActor
extension CareLedgerService: CareLedgerRecording {
    func record(
        occurredAt: Date,
        actorKind: CareLedgerActorKind,
        actorId: String?,
        subjectKind: CareLedgerSubjectKind,
        subjectId: String?,
        eventKind: CareLedgerEventKind,
        actionType: String,
        amountValue: Double,
        amountUnit: String,
        note: String,
        source: CareLedgerSource,
        sourceEventId: String?,
        sourceReminderId: String?,
        legacyModelName: String?,
        legacyModelId: String?,
        coconutDelta: Int,
        rewardLogId: String?,
        privacyFieldRaw: String?,
        metadataJSON: String,
        context: ModelContext,
        save: Bool
    ) -> CareLedgerEvent {
        CareLedgerService.record(
            occurredAt: occurredAt,
            actorKind: actorKind,
            actorId: actorId,
            subjectKind: subjectKind,
            subjectId: subjectId,
            eventKind: eventKind,
            actionType: actionType,
            amountValue: amountValue,
            amountUnit: amountUnit,
            note: note,
            source: source,
            sourceEventId: sourceEventId,
            sourceReminderId: sourceReminderId,
            legacyModelName: legacyModelName,
            legacyModelId: legacyModelId,
            coconutDelta: coconutDelta,
            rewardLogId: rewardLogId,
            privacyFieldRaw: privacyFieldRaw,
            metadataJSON: metadataJSON,
            context: context,
            save: save
        )
    }

    func recordReminderState(
        reminder: Reminder,
        actionType: String,
        actorId: String?,
        source: CareLedgerSource,
        context: ModelContext,
        save: Bool
    ) {
        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: actionType,
            actorId: actorId,
            source: source,
            context: context,
            save: save
        )
    }

    func recordPetCare(
        log: PetCareLog,
        pet: Pet,
        source: CareLedgerSource,
        sourceEventId: String?,
        sourceReminderId: String?,
        coconutDelta: Int,
        metadataJSON: String,
        context: ModelContext,
        save: Bool
    ) {
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: source,
            sourceEventId: sourceEventId,
            sourceReminderId: sourceReminderId,
            coconutDelta: coconutDelta,
            metadataJSON: metadataJSON,
            context: context
        )
    }

    func recordPetPotty(
        log: PetPottyLog,
        pet: Pet,
        source: CareLedgerSource,
        coconutDelta: Int,
        metadataJSON: String,
        context: ModelContext,
        save: Bool
    ) {
        CareLedgerService.recordPetPotty(
            log: log,
            pet: pet,
            source: source,
            coconutDelta: coconutDelta,
            metadataJSON: metadataJSON,
            context: context
        )
    }

    func rewardDelta(_ reward: (humanGot: Int, petGot: Int)?) -> Int {
        guard let reward else { return 0 }
        return max(0, reward.humanGot) + max(0, reward.petGot)
    }

    func rewardMetadata(_ reward: (humanGot: Int, petGot: Int)?, questManager: QuestManager) -> String {
        guard let reward else { return "" }
        if let result = questManager.lastEconomyRewardResult,
           result.humanCoconuts == max(0, reward.humanGot),
           result.petCoconuts == max(0, reward.petGot) {
            return result.metadataJSON
        }
        return ""
    }

    func syncOasisTreeEnergyIfNeeded(metadataJSON: String, context: ModelContext) {
        guard CoconutEconomyPolicyV2.metadataValue(named: "growthXP", in: metadataJSON) > 0 else { return }
        OasisTreeManagerRegistry.current.refreshLedgerEnergy(modelContext: context)
    }

    func recordEventCompletionReward(
        event: Event,
        occurrenceDate: Date,
        actorId: String?,
        coconutDelta: Int,
        occurredAt: Date,
        context: ModelContext
    ) -> CareLedgerEvent {
        CareLedgerService.record(
            occurredAt: occurredAt,
            actorKind: actorId == nil ? .unknown : .human,
            actorId: actorId,
            subjectKind: subjectKind(for: event),
            subjectId: event.relatedEntityId.isEmpty ? nil : event.relatedEntityId,
            eventKind: .coconut,
            actionType: "eventCompletionReward",
            note: event.title,
            source: .calendar,
            sourceEventId: event.id.uuidString,
            coconutDelta: coconutDelta,
            metadataJSON: "{\"occurrence\":\"\(Event.occurrenceStorageKey(for: occurrenceDate))\"}",
            context: context
        )
    }

    func recordCoconut(
        delta: Int,
        title: String,
        actorId: String?,
        actorName: String?,
        source: CareLedgerSource,
        context: ModelContext
    ) -> CareLedgerEvent {
        CareLedgerService.record(
            actorKind: actorId == nil ? .system : .human,
            actorId: actorId,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "coconutDelta",
            note: actorName.map { "\($0) · \(title)" } ?? title,
            source: source,
            coconutDelta: delta,
            context: context
        )
    }

    private func subjectKind(for event: Event) -> CareLedgerSubjectKind {
        switch event.relatedEntityType {
        case EntityKind.pet.rawValue, "pet":
            return .pet
        case EntityKind.human.rawValue, "human":
            return .human
        case EntityKind.plant.rawValue, "plant":
            return .plant
        default:
            return event.relatedEntityId.isEmpty ? .system : .unknown
        }
    }
}
