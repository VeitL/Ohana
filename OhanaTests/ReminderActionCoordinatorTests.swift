import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct ReminderActionCoordinatorTests {
    @Test func notificationActionUsesNarrowReminderLookup() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let untouched = Reminder()
        let target = Reminder()
        context.insert(untouched)
        context.insert(target)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "SKIP",
                "notificationId": target.notificationId
            ],
            currentActiveHumanId: "human-1",
            context: context
        )

        #expect(result == .skipped)
        #expect(target.statusEnum == .skipped)
        #expect(target.completedBy == "human-1")
        #expect(untouched.statusEnum == .pending)
    }

    @Test func missingReminderDoesNotMutateExistingReminders() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reminder = Reminder()
        context.insert(reminder)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "COMPLETE",
                "reminderId": UUID().uuidString
            ],
            currentActiveHumanId: "human-1",
            context: context
        )

        #expect(result == .missingReminder)
        #expect(reminder.statusEnum == .pending)
        #expect(reminder.completedBy.isEmpty)
    }

    @Test func manualFeedReminderCompletesThroughCareService() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "早餐",
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        let reminder = Reminder(event: event, scheduledAt: Date().addingTimeInterval(60))
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "COMPLETE",
                "reminderId": reminder.id.uuidString
            ],
            currentActiveHumanId: "human-1",
            context: context
        )

        let logs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(result == .completed)
        #expect(reminder.statusEnum == .completed)
        #expect(event.isOccurrenceMarkedComplete(on: reminder.scheduledAt))
        #expect(logs.count == 1)
        #expect(logs.first?.pet?.id == pet.id)
    }

    @Test func humanMedicationNotificationCompleteWritesDoseLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let human = Human(name: "Guan")
        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: "Vitamin D",
            dosage: "1 tablet",
            frequency: .daily
        )
        let scheduledAt = Date(timeIntervalSince1970: 1_780_921_200)
        context.insert(human)
        context.insert(medication)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "COMPLETE",
                "humanMedicationId": medication.id.uuidString,
                "humanId": human.id.uuidString,
                "scheduledAt": scheduledAt.timeIntervalSince1970
            ],
            currentActiveHumanId: human.id.uuidString,
            context: context,
            domainRevisions: revisions
        )

        let logs = try context.fetch(FetchDescriptor<HumanMedicationLog>())
        #expect(result == .completed)
        #expect(logs.count == 1)
        #expect(logs.first?.humanId == human.id.uuidString)
        #expect(logs.first?.medicationId == medication.id.uuidString)
        #expect(logs.first?.status == .taken)
        #expect(logs.first?.scheduledTime == scheduledAt)
        #expect(revisionCenter.lastMutation?.command == .humanMedicationDose(
            humanID: human.id,
            medicationID: medication.id,
            scheduledMinute: Int(scheduledAt.timeIntervalSince1970 / 60),
            status: HumanMedicationStatus.taken.rawValue
        ))
    }

    @Test func petMedicationNotificationCompleteWritesDoseAndDecrementsRemainingAmount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        let medicationReminders = FakeMedicationReminderManager()
        let questManager = QuestManager(
            wallet: SwiftDataCoconutWalletManager(),
            revisions: revisions
        )
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "狗")
        let medication = PetMedication(
            name: "Apoquel",
            dosage: "1 tablet",
            frequency: .daily,
            remainingAmount: 2,
            pet: pet
        )
        context.insert(human)
        context.insert(pet)
        context.insert(medication)
        try context.save()

        let result = ReminderActionCoordinator.handle(
            userInfo: [
                "action": "COMPLETE",
                "medicationId": medication.id.uuidString,
                "petId": pet.id.uuidString,
                "scheduledAt": Date().timeIntervalSince1970
            ],
            currentActiveHumanId: human.id.uuidString,
            context: context,
            questManager: questManager,
            medicationReminders: medicationReminders,
            domainRevisions: revisions
        )

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(result == .completed)
        #expect(events.count == 1)
        #expect(events.first?.eventType == EventType.petMedicationDose.rawValue)
        #expect(events.first?.relatedEntityType == MedicationEventLink.petMedicationDose)
        #expect(events.first?.relatedEntityId == medication.id.uuidString)
        #expect(medication.remainingAmount == 1)
        #expect(medicationReminders.recordedMedicationIDs == [medication.id])
        #expect(medicationReminders.scheduledPetIDs == [pet.id])
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV63.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

@MainActor
private final class FakeMedicationReminderManager: MedicationReminderManaging {
    var recordedMedicationIDs: [UUID] = []
    var scheduledPetIDs: [UUID] = []

    func dosesTakenToday(for _: UUID) -> Int {
        0
    }

    func recordDose(for medicationId: UUID) {
        recordedMedicationIDs.append(medicationId)
    }

    func undoDose(for _: UUID) {}

    func scheduleMedicationReminders(for pet: Pet, context _: ModelContext?) {
        scheduledPetIDs.append(pet.id)
    }

    func scheduleHumanMedicationReminders(for _: Human, meds _: [HumanMedication], context _: ModelContext?) {}
}
