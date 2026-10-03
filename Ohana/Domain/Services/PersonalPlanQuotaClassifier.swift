//
//  PersonalPlanQuotaClassifier.swift
//  Ohana
//

import Foundation

/// Maps structured event facts to the commercial quota class. Never infer a
/// safety exemption from user-entered titles.
enum PersonalPlanQuotaClassifier {
    nonisolated static func quotaClass(for eventType: EventType) -> PersonalPlanQuotaClass {
        switch eventType {
        case .health,
             .vaccine,
             .externalDeworming,
             .internalDeworming,
             .vetVisit,
             .medication,
             .petMedication,
             .petMedicationDose:
            .healthCritical
        case .birthday,
             .anniversary,
             .daily,
             .task,
             .shoppingList,
             .chore,
             .grooming,
             .foodChange,
             .litterBox,
             .watering,
             .fertilizing,
             .plantRepotting,
             .plantPruning,
             .plantMisting,
             .plantRotation,
             .plantLeafCleaning,
             .plantPestCheck,
             .plantHealthCheck,
             .insurancePremium:
            .ordinary
        }
    }
}
