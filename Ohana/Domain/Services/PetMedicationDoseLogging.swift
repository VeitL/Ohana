//
//  PetMedicationDoseLogging.swift
//  Ohana
//
//  宠物用药打卡写入 Event，避免改动 PetMedication Schema。
//

import Foundation
import SwiftData

nonisolated enum PetMedicationDoseLogging {
    static let relatedEntityTypeMedication = DomainEntityLinkRegistry.petMedicationDose

    static func doseMedicationId(for event: Event) -> UUID? {
        guard event.eventType == EventType.petMedicationDose.rawValue else { return nil }
        return DomainEntityLinkRegistry.resolvedId(
            for: DomainEntityLink(event: event),
            role: .petMedicationDose
        )
    }

    static func isDoseEvent(_ event: Event, medicationId: UUID) -> Bool {
        doseMedicationId(for: event) == medicationId
    }

    struct RecordDoseResult {
        let event: Event
        let didRecord: Bool
        let coconutDelta: Int
        let allowsDerivedEffects: Bool
        let didPersist: Bool
        let persistenceErrorDescription: String?
    }

    /// 某日该药应喂次数（`asNeeded` 为 0，不产生委托）
    static func requiredDoses(on date: Date, for med: PetMedication) -> Int {
        guard med.isActive else { return 0 }
        let cal = Calendar.current
        let d0 = cal.startOfDay(for: date)
        if d0 < cal.startOfDay(for: med.startDate) { return 0 }
        if let end = med.endDate, d0 > cal.startOfDay(for: end) { return 0 }

        switch med.frequency {
        case .daily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .everyOtherDay:
            let start = cal.startOfDay(for: med.startDate)
            let days = cal.dateComponents([.day], from: start, to: d0).day ?? 0
            return days % 2 == 0 ? 1 : 0
        case .weekly:
            return cal.component(.weekday, from: date) == cal.component(.weekday, from: med.startDate) ? 1 : 0
        case .asNeeded:
            return 0
        case .custom:
            return 1
        }
    }

    static func doseCount(on date: Date, events: [Event], medicationId: UUID, calendar: Calendar = .current) -> Int {
        events.count(where: { ev in
            isDoseEvent(ev, medicationId: medicationId)
                && calendar.isDate(ev.startDate, inSameDayAs: date)
        })
    }

    static func todayDoseCount(events: [Event], medicationId: UUID) -> Int {
        doseCount(on: Date(), events: events, medicationId: medicationId)
    }

    static func doseEventTitle(petName: String, medicationName: String, l: L10n = .current) -> String {
        l.tr(
            zh: "💊 \(petName) 服用 \(medicationName)",
            en: "💊 \(petName) took \(medicationName)",
            de: "💊 \(petName) hat \(medicationName) bekommen"
        )
    }

    static func doseRewardTitle(l: L10n = .current) -> String {
        l.tr(
            zh: "记录喂药 +1🥥",
            en: "Medication dose logged +1🥥",
            de: "Medikamentengabe erfasst +1🥥"
        )
    }

    @discardableResult
    @MainActor
    static func recordDose(
        medication: PetMedication,
        pet: Pet,
        modelContext: ModelContext,
        decrementRemaining: Bool = true,
        awardCoconut: Bool = false,
        economy: CareEventEconomyAwarding,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> Event {
        recordDoseResult(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            decrementRemaining: decrementRemaining,
            awardCoconut: awardCoconut,
            economy: economy,
            activeHumanSelection: activeHumanSelection,
            careLedger: providedCareLedger,
            medicationReminders: providedMedicationReminders
        ).event
    }

    @discardableResult
    @MainActor
    static func recordDoseResult(
        medication: PetMedication,
        pet: Pet,
        modelContext: ModelContext,
        decrementRemaining: Bool = true,
        awardCoconut: Bool = false,
        economy: CareEventEconomyAwarding,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> RecordDoseResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let medicationReminders = providedMedicationReminders ?? DomainServiceDependencyRegistry.medicationReminders(careLedger: careLedger)
        let now = Date()
        let requestedAssigneeId = activeHumanSelection.currentHumanId
        let previewIntent = DomainScheduleCreateIntent(
            title: doseEventTitle(petName: pet.name, medicationName: medication.name),
            startDate: now,
            isAllDay: false,
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: relatedEntityTypeMedication,
            relatedEntityId: medication.id.uuidString,
            assigneeId: requestedAssigneeId,
            writeKind: .care,
            source: .domainService
        )
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: requestedAssigneeId,
            context: modelContext,
            logPrefix: "PetMedicationDoseLogging"
        )
        let writeIntent = DomainScheduleCreateIntent(
            title: previewIntent.title,
            startDate: previewIntent.startDate,
            isAllDay: previewIntent.isAllDay,
            eventType: previewIntent.eventType,
            relatedEntityType: previewIntent.relatedLink.rawType,
            relatedEntityId: previewIntent.relatedLink.rawId,
            assigneeId: actor.effectiveExecutorId,
            writeKind: .care,
            source: .domainService
        )
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: writeIntent,
            context: modelContext
        ) else {
            let event = DomainScheduleWriter.makeUnpersistedEvent(intent: writeIntent)
            return RecordDoseResult(
                event: event,
                didRecord: false,
                coconutDelta: 0,
                allowsDerivedEffects: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }
        let event = DomainScheduleWriter.createEvent(plan: plan, context: modelContext).event
        CloudSyncMutationRecorder.markModified(event, context: modelContext, modifiedAt: now)
        let effectsPlan = DomainEffectWriteAuthorizer.authorizePetEffect(
            pet: pet,
            occurredAt: now,
            writeKind: .care,
            source: .domainService,
            executorId: actor.effectiveExecutorId,
            context: modelContext,
            logPrefix: "PetMedicationDoseLogging",
            actorOverride: actor
        )

        var coconutDelta = 0
        var pendingRemainingAmountWrite = PendingMedicationDoseStorageWrite.none
        if let effectsPlan {
            DomainEffectDispatcher.run(plan: effectsPlan) { actor in
                if awardCoconut, effectsPlan.allowsEconomyDerivation {
                    let reward = economy.awardCareAction(
                        type: .general(
                            humanReward: 1,
                            petReward: 0,
                            emoji: "💊",
                            title: doseRewardTitle()
                        ),
                        pet: pet,
                        context: modelContext,
                        quality: .none,
                        date: now,
                        executorId: actor.rewardExecutorId
                    )
                    coconutDelta = reward.humanGot + reward.petGot
                }

                careLedger.record(
                    occurredAt: event.startDate,
                    actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                    actorId: actor.effectiveExecutorId,
                    subjectKind: .pet,
                    subjectId: pet.id.uuidString,
                    eventKind: .medication,
                    actionType: "petMedicationDose",
                    amountValue: 0,
                    amountUnit: "",
                    note: event.title,
                    source: .detail,
                    sourceEventId: event.id.uuidString,
                    sourceReminderId: nil,
                    legacyModelName: "Event",
                    legacyModelId: event.id.uuidString,
                    coconutDelta: coconutDelta,
                    rewardLogId: nil,
                    privacyFieldRaw: nil,
                    metadataJSON: "{\"medicationId\":\"\(medication.id.uuidString)\"}",
                    context: modelContext,
                    save: false
                )
                if decrementRemaining {
                    pendingRemainingAmountWrite = prepareRemainingAmountDecrement(medication)
                }
            }
        }
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            modelContext.rollback()
            economy.refreshProjectionAfterRollback(context: modelContext)
            return RecordDoseResult(
                event: event,
                didRecord: false,
                coconutDelta: 0,
                allowsDerivedEffects: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        pendingRemainingAmountWrite.commit()
        if effectsPlan != nil {
            medicationReminders.recordDose(for: medication.id)
        }

        return RecordDoseResult(
            event: event,
            didRecord: true,
            coconutDelta: coconutDelta,
            allowsDerivedEffects: effectsPlan?.allowsDerivedEffects == true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @MainActor
    private static func prepareRemainingAmountDecrement(_ medication: PetMedication) -> PendingMedicationDoseStorageWrite {
        let current = PetMedicationPlanStorageKeys.remainingAmountValue(medication: medication)
        guard current > 0 else { return .none }
        let next = max(0, current - 1)
        medication.remainingAmount = next
        return .setDouble(
            key: PetMedicationPlanStorageKeys.remainingAmount(medicationID: medication.id),
            value: next
        )
    }
}

private enum PendingMedicationDoseStorageWrite {
    case none
    case setDouble(key: String, value: Double)

    func commit(defaults: UserDefaults = .standard) {
        switch self {
        case .none:
            break
        case let .setDouble(key, value):
            defaults.set(value, forKey: key)
        }
    }
}
