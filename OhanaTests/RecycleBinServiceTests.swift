import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct RecycleBinServiceTests {
    @Test func memberDeletionSoftDeletesPetAndRelatedEventsThenRestoresOriginalIds() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let event = Event(
            title: "Vet",
            eventType: EventType.vetVisit.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        context.insert(pet)
        context.insert(event)
        try context.save()

        let result = MemberDeletionCommandService.deletePet(pet, context: context, userDefaults: isolatedDefaults())
        try context.save()

        #expect(result.removedRelatedEventIDs == [event.id])
        #expect(pet.trashedAt != nil)
        #expect(event.trashedAt != nil)
        #expect(try context.fetch(FetchDescriptor<Pet>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Pet>()).activeRecycleBinItems.isEmpty)

        let item = try #require(RecycleBinService.listItems(context: context).first { $0.kind == .pet && $0.sourceID == pet.id })
        let restore = RecycleBinService.restoreItem(item, context: context)
        try context.save()

        #expect(restore.restoredSourceCount == 2)
        #expect(pet.trashedAt == nil)
        #expect(event.trashedAt == nil)
        #expect(try context.fetch(FetchDescriptor<Pet>()).activeRecycleBinItems.map(\.id) == [pet.id])
    }

    @Test func memberDeletionSuppressesRelatedRemindersAndRestoreReactivatesThem() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        let event = Event(
            title: "Ava birthday",
            startDate: Date().addingTimeInterval(86400),
            eventType: EventType.birthday.rawValue,
            relatedEntityType: EntityKind.human.rawValue,
            relatedEntityId: human.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(human)
        context.insert(event)
        context.insert(reminder)
        try context.save()

        _ = MemberDeletionCommandService.deleteHuman(
            human,
            activeHumanID: human.id.uuidString,
            context: context
        )
        try context.save()

        #expect(human.trashedAt != nil)
        #expect(event.trashedAt != nil)
        #expect(reminder.statusEnum == .skipped)
        #expect(reminder.completedBy.hasPrefix("system:recycle:"))
        #expect(try cloudSyncState(for: reminder, context: context)?.hasPendingLocalChanges == true)

        let item = try #require(RecycleBinService.listItems(context: context).first { $0.kind == .human && $0.sourceID == human.id })
        let restore = RecycleBinService.restoreItem(item, context: context)
        try context.save()

        #expect(restore.restoredSourceCount == 3)
        #expect(human.trashedAt == nil)
        #expect(event.trashedAt == nil)
        #expect(reminder.statusEnum == .pending)
        #expect(reminder.completedBy.isEmpty)
    }

    @Test func expiredHumanPurgeDeletesHumanScopedStringRecordsWithTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let human = Human(name: "Ava")
        let medication = HumanMedication(humanId: human.id.uuidString, name: "Vitamin")
        let medicationLog = HumanMedicationLog(
            humanId: human.id.uuidString,
            medicationId: medication.id.uuidString,
            scheduledTime: now,
            status: .taken,
            recordedTime: now
        )
        let report = HumanHealthReport(humanId: human.id.uuidString, hospitalName: "Clinic")
        let wish = WishlistItem(title: "Trip", cost: 200, creatorId: human.id.uuidString)
        let directExpense = PetExpenseLog(date: now, amount: 42, category: .medical, note: "Self", pet: nil, executorId: human.id.uuidString)
        context.insert(human)
        context.insert(medication)
        context.insert(medicationLog)
        context.insert(report)
        context.insert(wish)
        context.insert(directExpense)
        try context.save()

        RecycleBinService.moveToRecycleBin(
            human,
            now: now,
            trashedByHumanId: human.id.uuidString,
            context: context
        )
        try context.save()

        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).count == 1)

        _ = RecycleBinService.purgeExpired(
            context: context,
            now: now.addingTimeInterval(TimeInterval((RecycleBinService.retentionDays + 1) * 24 * 60 * 60))
        )
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Human>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedication>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanMedicationLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: HumanMedication.self), id: medication.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: HumanMedicationLog.self), id: medicationLog.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: HumanHealthReport.self), id: report.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: WishlistItem.self), id: wish.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: PetExpenseLog.self), id: directExpense.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func preciousArchiveDeletesStayRecoverableWithSourcePayloads() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let photo = PetPhotoLog(imageData: Data([1, 2, 3]), date: Date(), pet: pet)
        photo.note = "beach"
        let document = PetDocument(title: "Passport", category: .passport, pet: pet)
        document.attachmentData = Data([7, 8, 9])
        let milestone = PetMilestone(date: Date(), title: "Home", emoji: "H", pet: pet)
        let policy = PetInsurance(companyName: "Care", policyNumber: "P-1", pet: pet)
        let claim = InsuranceClaim(claimDate: Date(), totalExpense: 100, claimedAmount: 80, insurance: policy)
        context.insert(pet)
        context.insert(photo)
        context.insert(document)
        context.insert(milestone)
        context.insert(policy)
        context.insert(claim)
        try context.save()

        PetPhotoAlbumCommandService.deletePhoto(photo, pet: pet, context: context)
        PetDocumentCommandService.deleteDocument(document, pet: pet, context: context)
        PetMilestoneCommandService.deleteMilestone(milestone, pet: pet, context: context)
        InsurancePolicyCommandService.deletePolicy(policy, pet: pet, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PetPhotoLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetDocument>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetMilestone>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PetInsurance>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<InsuranceClaim>()).count == 1)
        #expect(photo.trashedAt != nil)
        #expect(document.trashedAt != nil)
        #expect(milestone.trashedAt != nil)
        #expect(policy.trashedAt != nil)

        for item in RecycleBinService.listItems(context: context) {
            _ = RecycleBinService.restoreItem(item, context: context)
        }
        try context.save()

        #expect(photo.trashedAt == nil)
        #expect(photo.imageData == Data([1, 2, 3]))
        #expect(document.trashedAt == nil)
        #expect(document.attachmentData == Data([7, 8, 9]))
        #expect(milestone.trashedAt == nil)
        #expect(policy.trashedAt == nil)
        #expect(policy.claims.map(\.id) == [claim.id])
    }

    @Test func purgeExpiredWritesCloudSyncTombstoneOnlyAtFinalPurge() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deletedByHumanId = UUID()
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        RecycleBinService.moveToRecycleBin(pet, now: now, trashedByHumanId: deletedByHumanId.uuidString, context: context)
        try context.save()
        let modifiedState = try #require(try cloudSyncState(for: pet, context: context))
        #expect(modifiedState.entityName == String(describing: Pet.self))
        #expect(modifiedState.localRecordId == pet.id.uuidString.lowercased())
        #expect(modifiedState.isDeletionTombstone == false)

        _ = RecycleBinService.purgeExpired(
            context: context,
            now: now.addingTimeInterval(TimeInterval((RecycleBinService.retentionDays + 1) * 24 * 60 * 60))
        )
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        let tombstone = try #require(try cloudSyncState(for: pet, context: context))
        #expect(tombstone.isDeletionTombstone)
        #expect(tombstone.deletedAt != nil)
        #expect(tombstone.deletedByHumanId == deletedByHumanId.uuidString.lowercased())
    }

    @Test func backupPreservesTrashStatesAndRecycleBatches() throws {
        let sourceContainer = try makeContainer()
        let source = sourceContainer.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let log = PetCareLog(type: .feeding, pet: pet)
        source.insert(pet)
        source.insert(log)
        try source.save()

        let clearResult = PetActivityRecordCleanupService(notifications: FakeRecycleBinNotificationScheduler())
            .clearActivityRecords(for: pet, context: source, now: Date(timeIntervalSince1970: 1_800_000_000))
        try source.save()
        _ = try #require(clearResult.recycleBatchID)

        let backup = try DataBackupManager(defaults: isolatedDefaults()).buildBackup(context: source)
        #expect(backup.trashStates?.isEmpty == false)
        #expect(backup.recycleBinBatches?.count == 1)

        let targetContainer = try makeContainer()
        let target = targetContainer.mainContext
        try DataBackupManager(defaults: isolatedDefaults()).applyBackup(backup, context: target, projectionManager: nil)

        let importedLogs = try target.fetch(FetchDescriptor<PetCareLog>())
        let importedBatches = try target.fetch(FetchDescriptor<RecycleBinBatch>())
        #expect(importedLogs.count == 1)
        #expect(importedLogs.first?.trashedAt != nil)
        #expect(importedBatches.count == 1)
        #expect(RecycleBinService.listItems(context: target).contains { $0.kind == .petActivityClearBatch })
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV69.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "RecycleBinServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func cloudSyncState(for pet: Pet, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == String(describing: Pet.self)
                && $0.localRecordId == pet.id.uuidString.lowercased()
        }
    }

    private func cloudSyncState(for reminder: Reminder, context: ModelContext) throws -> CloudSyncRecordState? {
        try cloudSyncState(entityName: String(describing: Reminder.self), id: reminder.id, context: context)
    }

    private func cloudSyncState(entityName: String, id: UUID, context: ModelContext) throws -> CloudSyncRecordState? {
        try context.fetch(FetchDescriptor<CloudSyncRecordState>()).first {
            $0.entityName == entityName
                && $0.localRecordId == id.uuidString.lowercased()
        }
    }
}

private final class FakeRecycleBinNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
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
    func cancel(notificationId _: String) {}
    func cancelAll(for _: String, reminders _: [Reminder]) {}
    func compensate(reminders _: [Reminder]) {}
}
