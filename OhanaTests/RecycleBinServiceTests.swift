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
        let scheduler = FakeRecycleBinNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }

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
        #expect(scheduler.cancelledIDs == [reminder.notificationId])
        #expect(try cloudSyncState(for: reminder, context: context)?.hasPendingLocalChanges == true)

        let item = try #require(RecycleBinService.listItems(context: context).first { $0.kind == .human && $0.sourceID == human.id })
        let restore = RecycleBinService.restoreItem(item, context: context)
        try context.save()

        #expect(restore.restoredSourceCount == 3)
        #expect(human.trashedAt == nil)
        #expect(event.trashedAt == nil)
        #expect(reminder.statusEnum == .pending)
        #expect(reminder.completedBy.isEmpty)
        #expect(scheduler.scheduledIDs == [reminder.notificationId])
    }

    @Test func restoreExpiredItemPurgesInsteadOfReactivating() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let deletedByHumanId = UUID()
        let deletedAt = Date().addingTimeInterval(TimeInterval(-(RecycleBinService.retentionDays + 1) * 24 * 60 * 60))
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        RecycleBinService.moveToRecycleBin(
            pet,
            now: deletedAt,
            trashedByHumanId: deletedByHumanId.uuidString,
            context: context
        )
        try context.save()

        let item = try #require(RecycleBinService.listItems(context: context).first { $0.kind == .pet && $0.sourceID == pet.id })
        let restore = RecycleBinService.restoreItem(item, context: context)
        try context.save()

        #expect(!restore.didChange)
        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        let tombstone = try #require(try cloudSyncState(for: pet, context: context))
        #expect(tombstone.isDeletionTombstone)
        #expect(tombstone.deletedByHumanId == deletedByHumanId.uuidString.lowercased())
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

    @Test func petPurgeWritesTombstonesForCascadeDeletedChildren() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deletedByHumanId = UUID()
        let pet = Pet(name: "Momo", species: "狗")
        let careLog = PetCareLog(date: now, type: .feeding, pet: pet)
        let expenseLog = PetExpenseLog(date: now, amount: 42, category: .medical, note: "Vet", pet: pet)
        let foodRecord = PetFoodRecord(brand: "Kibble", dailyGrams: 120, totalGrams: 1000, startDate: now, pet: pet)
        context.insert(pet)
        context.insert(careLog)
        context.insert(expenseLog)
        context.insert(foodRecord)
        try context.save()

        RecycleBinService.moveToRecycleBin(
            pet,
            now: now,
            trashedByHumanId: deletedByHumanId.uuidString,
            context: context
        )
        try context.save()

        _ = RecycleBinService.purgeExpired(
            context: context,
            now: now.addingTimeInterval(TimeInterval((RecycleBinService.retentionDays + 1) * 24 * 60 * 60))
        )
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetFoodRecord>()).isEmpty)
        #expect(try cloudSyncState(entityName: String(describing: PetCareLog.self), id: careLog.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: PetExpenseLog.self), id: expenseLog.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: PetFoodRecord.self), id: foodRecord.id, context: context)?.isDeletionTombstone == true)
    }

    @Test func directDeleteCommandsWriteCloudSyncTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let human = Human(name: "Ava")
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(human)
        context.insert(pet)
        try context.save()

        let metric = try #require(HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: "heartRate",
            unitCode: "bpm",
            value: 72,
            date: now,
            notes: "",
            context: context
        )?.log)
        _ = HumanHealthMetricCommandService.deleteMetricLog(metric, human: human, context: context)

        let workout = WorkoutCommandService.recordHumanWorkout(
            human: human,
            type: .walking,
            durationMinutes: 30,
            date: now,
            context: context
        )
        let workoutLog = try #require(try context.fetch(FetchDescriptor<HumanWorkoutLog>()).first { $0.id == workout.logID })
        _ = WorkoutCommandService.deleteHumanWorkout(workoutLog, human: human, context: context)

        let medication = PetMedication(name: "Meds", dosage: "1 pill", pet: pet)
        let event = Event(
            title: "Meds",
            startDate: now.addingTimeInterval(3600),
            eventType: EventType.medication.rawValue,
            relatedEntityType: MedicationEventLink.petMedicationPlan,
            relatedEntityId: medication.id.uuidString
        )
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        context.insert(medication)
        context.insert(event)
        context.insert(reminder)
        try context.save()
        _ = PetMedicationPlanCommandService.deletePlan(
            pet: pet,
            medication: medication,
            context: context,
            scheduleReminders: false
        )

        let insurance = PetInsurance(companyName: "Care", policyNumber: "P-1", pet: pet)
        let claim = InsuranceClaim(claimDate: now, totalExpense: 100, claimedAmount: 80, insurance: insurance)
        context.insert(insurance)
        context.insert(claim)
        try context.save()
        _ = InsurancePolicyCommandService.deleteClaim(claim, insurance: insurance, pet: pet, context: context)

        _ = try HumanWishlistCommandService.createItem(
            input: HumanWishlistCommandInput(title: "Trip", cost: 10, createdAt: now),
            for: human,
            context: context
        )
        let wish = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        _ = try HumanWishlistCommandService.deleteItem(wish, for: human, context: context)
        try context.save()

        #expect(try cloudSyncState(entityName: String(describing: HumanHealthMetricLog.self), id: metric.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: HumanWorkoutLog.self), id: workout.logID, context: context)?.isDeletionTombstone == true)
        if let ledgerEventID = workout.ledgerEventID {
            #expect(try cloudSyncState(entityName: String(describing: CareLedgerEvent.self), id: ledgerEventID, context: context)?.isDeletionTombstone == true)
        }
        #expect(try cloudSyncState(entityName: String(describing: PetMedication.self), id: medication.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Event.self), id: event.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: Reminder.self), id: reminder.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: InsuranceClaim.self), id: claim.id, context: context)?.isDeletionTombstone == true)
        #expect(try cloudSyncState(entityName: String(describing: WishlistItem.self), id: wish.id, context: context)?.isDeletionTombstone == true)
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
        let schema = Schema(ArkSchemaV71.models)
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
    private(set) var scheduledIDs: [String] = []
    private(set) var cancelledIDs: [String] = []

    func schedule(reminder: Reminder) {
        scheduledIDs.append(reminder.notificationId)
    }

    func schedule(
        reminder: Reminder,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        scheduledIDs.append(reminder.notificationId)
        completion?(.scheduled)
    }

    func schedule(
        reminder: Reminder,
        deliveryDate _: Date?,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        scheduledIDs.append(reminder.notificationId)
        completion?(.scheduled)
    }

    func pendingNotificationIds() async -> Set<String> { [] }
    func scheduleRollingWindow(reminders _: [Reminder]) {}
    func refillWindowIfNeeded(allReminders _: [Reminder]) {}
    func cancel(notificationId: String) {
        cancelledIDs.append(notificationId)
    }

    func cancelAll(for _: String, reminders _: [Reminder]) {}
    func compensate(reminders _: [Reminder]) {}
}
