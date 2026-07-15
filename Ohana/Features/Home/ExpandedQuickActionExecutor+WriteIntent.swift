//
//  ExpandedQuickActionExecutor+WriteIntent.swift
//  Ohana
//
//  Predicts whether a Home quick action will write a care fact immediately, so
//  route-only taps do not ask the user to confirm an executor first.
//

import Foundation

extension ExpandedQuickActionExecutor {
    static func willImmediatelyWriteFact(
        action: HomePetQuickActionKind,
        pet: Pet,
        allEvents: [Event],
        now: Date
    ) -> Bool {
        switch action {
        case .feed:
            let dashboard = ExpandedQuickActionLogic.feedDashboard(for: pet, allEvents: allEvents, now: now)
            return (dashboard.operatingMode == .manual && pet.dailyPortionGrams > 0) ||
                (dashboard.operatingMode == .manualReminder && dashboard.nextManualReminder != nil)
        case .water:
            guard !WaterQuickActionPolicy.isAquatic(species: pet.species) else { return false }
            let state = ExpandedQuickActionLogic.waterRuleState(for: pet, allEvents: allEvents, now: now)
            return state.operatingMode != .reminder || state.nextPendingReminder != nil
        case .medication:
            return quickActionMedicationTarget(pet: pet, allEvents: allEvents, now: now) != nil
        case .walk, .waterChange, .filterClean:
            return false
        case .litter, .play, .cageCleaning, .freeFlight, .misting, .substrateChange:
            return true
        }
    }

    static func quickActionMedicationTarget(
        pet: Pet,
        allEvents: [Event],
        now: Date
    ) -> PetMedication? {
        let activeMedications = pet.medications.filter { $0.isActive(on: now) }
        return activeMedications.first { medication in
            let required = PetMedicationDoseLogging.requiredDoses(on: now, for: medication)
            guard required > 0 else { return false }
            let completed = PetMedicationDoseLogging.doseCount(
                on: now,
                events: allEvents,
                medicationId: medication.id
            )
            return completed < required
        } ?? activeMedications.first {
            PetMedicationDoseLogging.requiredDoses(on: now, for: $0) == 0
        }
    }
}
