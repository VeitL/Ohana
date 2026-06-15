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
            title: "💊 \(pet.name) 服用 \(medication.name)",
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
                allowsDerivedEffects: false
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
        do {
            if let effectsPlan {
                DomainEffectDispatcher.run(plan: effectsPlan) { actor in
                    if awardCoconut, effectsPlan.allowsEconomyDerivation {
                        let reward = economy.awardCareAction(
                            type: .general(humanReward: 1, petReward: 0, emoji: "💊", title: "记录喂药 +1🥥"),
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
                        PetMedicationPlanStorageKeys.decrementRemainingAmount(medication: medication)
                    }
                    medicationReminders.recordDose(for: medication.id)
                }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            economy.refreshProjectionAfterRollback(context: modelContext)
            #if DEBUG
                OhanaLog.error("[PetMedicationDoseLogging] dose save failed: \(error.localizedDescription)", category: "Economy")
            #endif
        }

        return RecordDoseResult(
            event: event,
            didRecord: true,
            coconutDelta: coconutDelta,
            allowsDerivedEffects: effectsPlan?.allowsDerivedEffects == true
        )
    }
}
