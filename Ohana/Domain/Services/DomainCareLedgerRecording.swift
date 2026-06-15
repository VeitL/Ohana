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
    func syncLedgerEnergyIfNeeded(metadataJSON: String, context: ModelContext)
    func subjectInfo(from event: Event?, context: ModelContext) -> CareLedgerSubjectInfo

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
