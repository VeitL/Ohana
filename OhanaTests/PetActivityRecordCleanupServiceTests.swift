import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct PetActivityRecordCleanupServiceTests {
    @Test func cleanupMovesPetActivityFactsToSingleRecycleBatchAndRestoresThem() throws {
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
        let batches = try context.fetch(FetchDescriptor<RecycleBinBatch>())

        #expect(result.petID == pet.id)
        #expect(result.deletedActivityRecordCount == 4)
        #expect(result.deletedEventCount == 1)
        let batchID = try #require(result.recycleBatchID)
        #expect(result.cancelledNotificationIDs == ["notification-momo"])
        #expect(result.didResetStreak)
        #expect(notifications.cancelledIDs == ["notification-momo"])
        #expect(pet.currentStreak == 0)
        #expect(pet.lastCheckInDate == nil)
        #expect(careLogs.count == 2)
        #expect(careLog.trashedAt != nil)
        #expect(careLog.trashBatchId == RecycleBinService.petActivityClearBatchId(batchID))
        #expect(careLogs.activeRecycleBinItems.map { $0.pet?.id } == [otherPet.id])
        #expect(pottyLogs.activeRecycleBinItems.isEmpty)
        #expect(walkLogs.activeRecycleBinItems.isEmpty)
        #expect(weightLogs.activeRecycleBinItems.isEmpty)
        #expect(documents.map { $0.pet?.id } == [pet.id])
        #expect(insurances.map { $0.pet?.id } == [pet.id])
        #expect(events.activeRecycleBinItems.map(\.relatedEntityId) == [otherPet.id.uuidString])
        #expect(reminder.statusEnum == .skipped)
        #expect(reminder.completedBy.hasPrefix("system:recycle:"))
        #expect(batches.map(\.id) == [batchID])

        let recycleItem = try #require(RecycleBinService.listItems(context: context).first {
            $0.kind == .petActivityClearBatch && $0.batchID == batchID
        })
        let restore = RecycleBinService.restoreItem(recycleItem, context: context)
        try context.save()

        #expect(restore.restoredBatchCount == 1)
        #expect(restore.restoredSourceCount == 6)
        #expect(pet.currentStreak == 5)
        #expect(pet.lastCheckInDate == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(try context.fetch(FetchDescriptor<RecycleBinBatch>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).activeRecycleBinItems.count == 2)
        #expect(try context.fetch(FetchDescriptor<Event>()).activeRecycleBinItems.count == 2)
        #expect(reminder.statusEnum == .pending)
        #expect(reminder.completedBy.isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV69.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
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
    func cancelAll(for _: String, reminders _: [Reminder]) {}
    func compensate(reminders _: [Reminder]) {}
}
