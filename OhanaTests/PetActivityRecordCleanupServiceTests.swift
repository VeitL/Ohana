import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct PetActivityRecordCleanupServiceTests {
    @Test func cleanupPhysicallyDeletesPetActivityFactsAndWritesSyncTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        pet.currentStreak = 5
        pet.lastCheckInDate = Date(timeIntervalSince1970: 1_800_000_000)
        let otherPet = Pet(name: "Nana", species: "猫")
        let careLog = PetCareLog(type: .feeding, pet: pet)
        let pottyLog = PetPottyLog(type: .perfectPoop, pet: pet)
        let walkLog = PetWalkLog(pet: pet)
        walkLog.distanceMeters = 1200
        let weightLog = PetWeightLog(weight: 8.2, pet: pet)
        let document = PetDocument(title: "Passport", category: .passport, pet: pet)
        let insurance = PetInsurance(companyName: "Care Co", policyNumber: "P-1", pet: pet)
        let otherCareLog = PetCareLog(type: .watering, pet: otherPet)
        let event = Event(
            title: "Momo reminder",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSince1970: 1_800_000_100))
        reminder.notificationId = "notification-momo"
        let otherEvent = Event(
            title: "Nana reminder",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: otherPet.id.uuidString
        )

        context.insert(pet)
        context.insert(otherPet)
        context.insert(careLog)
        context.insert(pottyLog)
        context.insert(walkLog)
        context.insert(weightLog)
        context.insert(document)
        context.insert(insurance)
        context.insert(otherCareLog)
        context.insert(event)
        context.insert(reminder)
        context.insert(otherEvent)
        try context.save()

        let notifications = FakeReminderNotificationScheduler()
        let result = PetActivityRecordCleanupService(notifications: notifications)
            .clearActivityRecords(for: pet, context: context)
        try context.save()

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let pottyLogs = try context.fetch(FetchDescriptor<PetPottyLog>())
        let walkLogs = try context.fetch(FetchDescriptor<PetWalkLog>())
        let weightLogs = try context.fetch(FetchDescriptor<PetWeightLog>())
        let documents = try context.fetch(FetchDescriptor<PetDocument>())
        let insurances = try context.fetch(FetchDescriptor<PetInsurance>())
        let events = try context.fetch(FetchDescriptor<Event>())
        let reminders = try context.fetch(FetchDescriptor<Reminder>())

        #expect(result.petID == pet.id)
        #expect(result.deletedActivityRecordCount == 4)
        #expect(result.deletedEventCount == 1)
        #expect(result.cancelledNotificationIDs == ["notification-momo"])
        #expect(result.didResetStreak)
        #expect(notifications.cancelledIDs == ["notification-momo"])
        #expect(pet.currentStreak == 0)
        #expect(pet.lastCheckInDate == nil)
        #expect(Set(careLogs.map(\.id)) == Set([otherCareLog.id]))
        #expect(pottyLogs.isEmpty)
        #expect(walkLogs.isEmpty)
        #expect(weightLogs.isEmpty)
        #expect(documents.map { $0.pet?.id } == [pet.id])
        #expect(insurances.map { $0.pet?.id } == [pet.id])
        #expect(Set(events.map(\.relatedEntityId)) == Set([otherPet.id.uuidString]))
        #expect(reminders.isEmpty)
        #expect(deletionTombstone(PetCareLog.self, id: careLog.id, context: context) != nil)
        #expect(deletionTombstone(PetPottyLog.self, id: pottyLog.id, context: context) != nil)
        #expect(deletionTombstone(PetWalkLog.self, id: walkLog.id, context: context) != nil)
        #expect(deletionTombstone(PetWeightLog.self, id: weightLog.id, context: context) != nil)
        #expect(deletionTombstone(Event.self, id: event.id, context: context) != nil)
        #expect(deletionTombstone(Reminder.self, id: reminder.id, context: context) != nil)
    }

    @Test func cleanupNoOpsForPassedAwayPet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        pet.passedAwayDate = Date(timeIntervalSince1970: 1_800_000_000)
        pet.currentStreak = 5
        let careLog = PetCareLog(type: .feeding, pet: pet)
        let event = Event(
            title: "Momo reminder",
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(careLog)
        context.insert(event)
        try context.save()

        let notifications = FakeReminderNotificationScheduler()
        let result = PetActivityRecordCleanupService(notifications: notifications)
            .clearActivityRecords(for: pet, context: context)
        try context.save()

        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(result.deletedActivityRecordCount == 0)
        #expect(result.deletedEventCount == 0)
        #expect(!result.didResetStreak)
        #expect(notifications.cancelledIDs.isEmpty)
        #expect(pet.currentStreak == 5)
        #expect(careLogs.map(\.id) == [careLog.id])
        #expect(events.map(\.id) == [event.id])
        #expect(deletionTombstone(PetCareLog.self, id: careLog.id, context: context) == nil)
        #expect(deletionTombstone(Event.self, id: event.id, context: context) == nil)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func deletionTombstone<T>(
        _: T.Type,
        id: UUID,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        let key = CloudSyncRecordState.recordKey(entityName: String(describing: T.self), localRecordId: id)
        return (try? context.fetch(FetchDescriptor<CloudSyncRecordState>()))?
            .first { $0.recordKey == key && $0.isDeletionTombstone }
    }
}

private final class FakeReminderNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
    private(set) var cancelledIDs: [String] = []

    func schedule(reminder _: Reminder) {}
    func schedule(
        reminder _: Reminder,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.scheduled)
    }

    func schedule(
        reminder _: Reminder,
        deliveryDate _: Date?,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.scheduled)
    }

    func pendingNotificationIds() async -> Set<String> { [] }
    func scheduleRollingWindow(reminders _: [Reminder]) {}
    func refillWindowIfNeeded(allReminders _: [Reminder]) {}
    func cancel(notificationId: String) { cancelledIDs.append(notificationId) }
    func cancelAll(for _: Pet, reminders _: [Reminder]) {}
    func compensate(reminders _: [Reminder]) {}
}
