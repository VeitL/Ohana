//
//  PetMedicationDoseLogging.swift
//  Ohana
//
//  宠物用药打卡写入 Event，避免改动 PetMedication Schema。
//

import Foundation
import SwiftData

enum PetMedicationDoseLogging {
    static let relatedEntityTypeMedication = "pet_medication"

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

    static func todayDoseCount(events: [Event], medicationId: UUID) -> Int {
        let cal = Calendar.current
        return events.count(where: { ev in
            ev.eventType == EventType.petMedicationDose.rawValue
                && ev.relatedEntityType == relatedEntityTypeMedication
                && ev.relatedEntityId == medicationId.uuidString
                && cal.isDateInToday(ev.startDate)
        })
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
        modelContext.safeSave()
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
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "{\"medicationId\":\"\(medication.id.uuidString)\"}",
            context: modelContext,
            save: true
        )

        if decrementRemaining {
            PetMedicationPlanStorageKeys.decrementRemainingAmount(medicationID: medication.id)
        }

        medicationReminders.recordDose(for: medication.id)

        if awardCoconut {
            questManager.addCoconuts(1, emoji: "💊", title: "记录喂药 +1🥥")
            _ = careLedger.recordCoconut(
                delta: 1,
                title: "记录喂药",
                actorId: event.assigneeId,
                actorName: nil,
                source: .economy,
                context: modelContext
            )
        }

        return event
    }
}
