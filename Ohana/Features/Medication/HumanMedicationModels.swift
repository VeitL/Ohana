//
//  HumanMedicationModels.swift
//  Ohana
//
//  Render support values for HumanMedicationContentView.
//

import Foundation

struct DailyDoseItem: Identifiable, Hashable {
    let medication: HumanMedication
    let scheduledTime: Date
    let doseIndex: Int
    var log: HumanMedicationLog?

    var id: String {
        let minuteKey = Int(scheduledTime.timeIntervalSince1970 / 60)
        return "\(medication.id.uuidString)-\(minuteKey)-\(doseIndex)"
    }
}

struct MedicationAdherenceDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayLabel: String
    let planned: Int
    let taken: Int

    var completion: Double {
        guard planned > 0 else { return 0 }
        return min(1, Double(taken) / Double(planned))
    }
}
