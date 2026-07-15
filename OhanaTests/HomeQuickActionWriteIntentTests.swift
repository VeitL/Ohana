import Foundation
import Testing
@testable import Ohana

@MainActor
struct HomeQuickActionWriteIntentTests {
    @Test func routeOnlyActionsDoNotClaimAnImmediateFactWrite() {
        let now = Date()
        let dog = Pet(name: "Piper", species: "dog")
        let fish = Pet(name: "Bubbles", species: "fish")

        #expect(!ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .walk,
            pet: dog,
            allEvents: [],
            now: now
        ))
        #expect(!ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .waterChange,
            pet: fish,
            allEvents: [],
            now: now
        ))
        #expect(!ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .water,
            pet: fish,
            allEvents: [],
            now: now
        ))
        #expect(ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .play,
            pet: dog,
            allEvents: [],
            now: now
        ))
    }

    @Test func manualFeedOnlyRequestsAnExecutorWhenAPortionCanBeRecorded() {
        let pet = Pet(name: "Piper", species: "dog")
        let now = Date()

        pet.dailyPortionGrams = 0
        #expect(!ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .feed,
            pet: pet,
            allEvents: [],
            now: now
        ))

        pet.dailyPortionGrams = 45
        #expect(ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .feed,
            pet: pet,
            allEvents: [],
            now: now
        ))
    }

    @Test func medicationOnlyRequestsAnExecutorForARecordableDose() {
        let now = Date()
        let pet = Pet(name: "Piper", species: "dog")
        let medication = PetMedication(
            name: "Tablet",
            frequency: .daily,
            startDate: now.addingTimeInterval(-60),
            pet: pet
        )
        pet.medications = [medication]

        #expect(ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .medication,
            pet: pet,
            allEvents: [],
            now: now
        ))

        let completedDose = Event(
            title: "Dose",
            startDate: now,
            eventType: EventType.petMedicationDose.rawValue,
            relatedEntityType: PetMedicationDoseLogging.relatedEntityTypeMedication,
            relatedEntityId: medication.id.uuidString
        )
        #expect(!ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: .medication,
            pet: pet,
            allEvents: [completedDose],
            now: now
        ))
    }
}
