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
        return events.filter { ev in
            ev.eventType == EventType.petMedicationDose.rawValue
                && ev.relatedEntityType == relatedEntityTypeMedication
                && ev.relatedEntityId == medicationId.uuidString
                && cal.isDateInToday(ev.startDate)
        }.count
    }

    @MainActor
    static func recordDose(
        medication: PetMedication,
        pet: Pet,
        modelContext: ModelContext,
        decrementRemaining: Bool = true
    ) {
        let event = Event(
            title: "💊 \(pet.name) 服用 \(medication.name)",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: relatedEntityTypeMedication,
            relatedEntityId: medication.id.uuidString
        )
        if let hid = UserDefaults.standard.string(forKey: "currentActiveHumanId"), !hid.isEmpty {
            event.assigneeId = hid
        }
        modelContext.insert(event)
        modelContext.safeSave()

        if decrementRemaining {
            let key = "medication_remaining_\(medication.id.uuidString)"
            let cur = UserDefaults.standard.double(forKey: key)
            if cur > 0 {
                UserDefaults.standard.set(max(0, cur - 1), forKey: key)
            }
        }
    }
}
