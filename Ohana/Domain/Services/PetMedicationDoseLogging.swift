//
//  PetMedicationDoseLogging.swift
//  Ohana
//
//  宠物用药打卡写入 Event，避免改动 PetMedication Schema。
//

import Foundation
import SwiftData

nonisolated enum PetMedicationDoseLogging {
    static let relatedEntityTypeMedication = MedicationEventLink.petMedicationDose

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
            ev.eventType == EventType.petMedicationDose.rawValue
                && ev.relatedEntityType == relatedEntityTypeMedication
                && ev.relatedEntityId == medicationId.uuidString
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
        questManager: QuestManager,
        activeHumanSelection: ActiveHumanSelecting = UserDefaultsActiveHumanSelection(),
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil
    ) -> Event {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let medicationReminders = providedMedicationReminders ?? SharedMedicationReminderManager()
        let event = Event(
            title: "💊 \(pet.name) 服用 \(medication.name)",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: relatedEntityTypeMedication,
            relatedEntityId: medication.id.uuidString
        )
        if let hid = activeHumanSelection.currentHumanId {
            event.assigneeId = hid
        }
        modelContext.insert(event)

        do {
            var coconutDelta = 0
            if awardCoconut {
                let reward = questManager.awardAction(
                    type: .general(humanReward: 1, petReward: 0, emoji: "💊", title: "记录喂药 +1🥥"),
                    pet: pet,
                    context: modelContext,
                    executorId: event.assigneeId
                )
                coconutDelta = reward.humanGot + reward.petGot
            }
            careLedger.record(
                occurredAt: event.startDate,
                actorKind: event.assigneeId == nil ? .unknown : .human,
                actorId: event.assigneeId,
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
            try modelContext.save()
        } catch {
            modelContext.rollback()
            questManager.wallet.refreshQuestProjection(context: modelContext, manager: questManager)
            #if DEBUG
                OhanaLog.error("[PetMedicationDoseLogging] dose save failed: \(error.localizedDescription)", category: "Economy")
            #endif
        }

        return event
    }
}
