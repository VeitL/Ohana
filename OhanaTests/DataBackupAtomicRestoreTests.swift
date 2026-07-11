import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct DataBackupAtomicRestoreTests {
    private struct InjectedRestoreFailure: Error {}

    @Test func everyRestorePhaseFailureLeavesStoreDefaultsAndNotificationsUnchanged() throws {
        let source = try makeBackup()

        for phase in DataBackupRestorePhase.allCases {
            let fixture = try makeTarget(petID: source.petID)
            defer { fixture.removeDefaults() }

            do {
                try fixture.manager.applyBackup(
                    source.backup,
                    context: fixture.container.mainContext,
                    projectionManager: nil,
                    schedulePlantNotifications: true,
                    plantNotifications: fixture.notifications,
                    restoreFaultInjector: { currentPhase in
                        if currentPhase == phase {
                            throw InjectedRestoreFailure()
                        }
                    }
                )
                Issue.record("Expected restore phase \(phase.rawValue) to fail")
            } catch is InjectedRestoreFailure {
                // Expected.
            }

            try assertOriginalState(fixture, petID: source.petID)
        }
    }

    @Test func transactionSaveFailureRollsBackPreparedChanges() throws {
        let source = try makeBackup()
        let fixture = try makeTarget(petID: source.petID)
        defer { fixture.removeDefaults() }

        do {
            try fixture.manager.applyBackup(
                source.backup,
                context: fixture.container.mainContext,
                projectionManager: nil,
                plantNotifications: fixture.notifications,
                restoreTransaction: { _, changes in
                    try changes()
                    throw InjectedRestoreFailure()
                }
            )
            Issue.record("Expected the injected transaction save failure")
        } catch is DataBackupRestorePersistenceError {
            // Expected: the restore reached the commit boundary, then failed.
        }

        try assertOriginalState(fixture, petID: source.petID)
    }

    @Test func cancellationBeforeCommitLeavesOriginalStateUnchanged() async throws {
        let source = try makeBackup()
        let fixture = try makeTarget(petID: source.petID)
        defer { fixture.removeDefaults() }

        let restoreTask = Task { @MainActor in
            await Task.yield()
            try fixture.manager.applyBackup(
                source.backup,
                context: fixture.container.mainContext,
                projectionManager: nil,
                plantNotifications: fixture.notifications
            )
        }
        restoreTask.cancel()

        do {
            try await restoreTask.value
            Issue.record("Expected restore cancellation")
        } catch is CancellationError {
            // Expected.
        }

        try assertOriginalState(fixture, petID: source.petID)
    }

    @Test func malformedRequiredValuesFailBeforeAnyLiveMutation() throws {
        let source = try makeBackup()

        var invalidIdentity = source.backup
        invalidIdentity.pets[0].id = "not-a-uuid"
        try assertPreflightFailure(
            invalidIdentity,
            expected: .identity,
            petID: source.petID
        )

        var invalidDate = source.backup
        invalidDate.pets[0].createdAt = "not-a-date"
        try assertPreflightFailure(
            invalidDate,
            expected: .date,
            petID: source.petID
        )

        var duplicateIdentity = source.backup
        duplicateIdentity.pets.append(duplicateIdentity.pets[0])
        try assertPreflightFailure(
            duplicateIdentity,
            expected: .duplicateIdentity,
            petID: source.petID
        )

        var brokenRelationship = source.backup
        brokenRelationship.petRelationships = [
            PetRelationshipBackup(
                id: UUID().uuidString,
                fromPetId: source.petID.uuidString,
                toPetId: UUID().uuidString,
                relationshipTypeRaw: PetRelationshipType.sibling.rawValue,
                note: "",
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
        try assertPreflightFailure(
            brokenRelationship,
            expected: .relationship,
            petID: source.petID
        )

        var unsafeMedia = source.backup
        unsafeMedia.pets[0].avatarImageRef = BackupMediaReference(
            path: "../outside.bin",
            byteCount: 1
        )
        try assertPreflightFailure(
            unsafeMedia,
            expected: .media,
            petID: source.petID
        )
    }

    @Test func invalidExpenseAmountsFailAtomicallyAndValidReimbursementRestoresOnce() throws {
        let source = try makeBackup()
        let timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_400))

        let invalidAmounts: [Double] = [0, -1, .nan, .infinity, -Double.infinity]
        for amount in invalidAmounts {
            var invalid = source.backup
            invalid.petExpenseLogs = [
                PetExpenseLogBackup(
                    id: UUID().uuidString,
                    date: timestamp,
                    amount: amount,
                    category: ExpenseCategory.medical.rawValue,
                    note: "invalid",
                    petId: source.petID.uuidString,
                    executorId: nil,
                    sharedSessionId: nil
                )
            ]
            for _ in 0 ..< 2 {
                try assertPreflightFailure(
                    invalid,
                    expected: .businessValue,
                    petID: source.petID
                )
            }
        }

        var invalidSharedExpense = source.backup
        invalidSharedExpense.sharedCareSessions = [
            SharedCareSessionBackup(
                id: UUID().uuidString,
                date: timestamp,
                actionKindRaw: SharedCareActionKind.expense.rawValue,
                executorId: nil,
                executorIdsRaw: nil,
                sourcePetId: source.petID.uuidString,
                targetPetIdsRaw: source.petID.uuidString,
                speciesRaw: "cat",
                totalAmountGrams: 0,
                totalAmountMl: 0,
                totalExpenseAmount: nil,
                expenseCategoryRaw: ExpenseCategory.other.rawValue,
                currencyCode: AppCurrency.code,
                allocationModeRaw: SharedCareAllocationMode.equal.rawValue,
                foodKindRaw: FeedFoodKind.dry.rawValue,
                stockOwnerPetId: "",
                primaryLegacyModelName: nil,
                primaryLegacyModelId: nil,
                note: "invalid shared expense",
                createdAt: timestamp
            )
        ]
        for _ in 0 ..< 2 {
            try assertPreflightFailure(
                invalidSharedExpense,
                expected: .businessValue,
                petID: source.petID
            )
        }

        var valid = source.backup
        valid.petExpenseLogs = [
            PetExpenseLogBackup(
                id: UUID().uuidString,
                date: timestamp,
                amount: -80,
                category: ExpenseCategory.insurancePremium.rawValue,
                note: "\(ExpenseAmountPolicy.insuranceReimbursementNotePrefix)clinic",
                petId: source.petID.uuidString,
                executorId: nil,
                sharedSessionId: nil
            )
        ]
        let fixture = try makeTarget(petID: source.petID)
        defer { fixture.removeDefaults() }

        for _ in 0 ..< 2 {
            try fixture.manager.applyBackup(
                valid,
                context: fixture.container.mainContext,
                projectionManager: nil,
                schedulePlantNotifications: false,
                plantNotifications: fixture.notifications
            )
        }
        let restoredExpenses = try fixture.container.mainContext.fetch(FetchDescriptor<PetExpenseLog>())
        #expect(restoredExpenses.count == 1)
        #expect(restoredExpenses.first?.amount == -80)
    }

    @Test func restoreLimitsAndMediaReaderRejectOversizeOrTampering() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataBackupAtomicRestoreTests.\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let oversizedManifest = root.appendingPathComponent("oversized.json")
        #expect(FileManager.default.createFile(atPath: oversizedManifest.path, contents: nil))
        let handle = try FileHandle(forWritingTo: oversizedManifest)
        try handle.truncate(atOffset: UInt64(DataBackupRestoreLimits.maximumManifestBytes + 1))
        try handle.close()
        do {
            try DataBackupPreflightValidator.validateManifestSize(at: oversizedManifest)
            Issue.record("Expected oversized manifest rejection")
        } catch let BackupError.invalidRestoreData(category) {
            #expect(category == .sizeLimit)
        }

        let mediaDirectory = root.appendingPathComponent(DataBackupPackageFormat.mediaDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let mediaURL = mediaDirectory.appendingPathComponent("tampered.bin")
        try Data([1, 2]).write(to: mediaURL)
        let reader = DataBackupMediaPackageReader(packageURL: root, password: nil)
        do {
            _ = try reader.data(for: BackupMediaReference(path: "media/tampered.bin", byteCount: 3))
            Issue.record("Expected media byte-count mismatch rejection")
        } catch let BackupError.invalidRestoreData(category) {
            #expect(category == .media)
        }
    }

    @Test func successfulRepeatedRestoreIsIdempotentAndCommitsDefaults() throws {
        let source = try makeBackup()
        let fixture = try makeTarget(petID: source.petID)
        defer { fixture.removeDefaults() }

        try fixture.manager.applyBackup(
            source.backup,
            context: fixture.container.mainContext,
            projectionManager: nil,
            schedulePlantNotifications: false,
            plantNotifications: fixture.notifications
        )
        let firstCounts = try recordCounts(in: fixture.container.mainContext)

        try fixture.manager.applyBackup(
            source.backup,
            context: fixture.container.mainContext,
            projectionManager: nil,
            schedulePlantNotifications: false,
            plantNotifications: fixture.notifications
        )
        let secondCounts = try recordCounts(in: fixture.container.mainContext)
        let restoredPet = try #require(try fixture.container.mainContext.fetch(FetchDescriptor<Pet>()).first)

        #expect(firstCounts == secondCounts)
        #expect(restoredPet.name == "Restored Pet")
        #expect(fixture.defaults.string(forKey: "bountyTasks") == "after-restore")
        #expect(!fixture.container.mainContext.hasChanges)
    }

    // MARK: - Fixtures

    private struct BackupFixture {
        let backup: OhanaBackup
        let petID: UUID
    }

    private struct TargetFixture {
        let container: ModelContainer
        let defaults: UserDefaults
        let defaultsSuiteName: String
        let manager: DataBackupManager
        let notifications: NotificationSpy

        func removeDefaults() {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
    }

    private struct RecordCounts: Equatable {
        let pets: Int
        let humans: Int
        let plants: Int
        let careLogs: Int
        let events: Int
        let reminders: Int
        let accounts: Int
    }

    private func makeBackup() throws -> BackupFixture {
        let suiteName = "DataBackupAtomicRestoreTests.Source.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("after-restore", forKey: "bountyTasks")

        let container = try makeContainer()
        let context = container.mainContext
        let petID = try #require(UUID(uuidString: "AAAAAAA1-AAAA-4AAA-8AAA-AAAAAAAAAAA1"))
        let pet = Pet(name: "Restored Pet", species: "cat")
        pet.id = petID
        pet.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let human = Human(name: "Restored Human")
        human.createdAt = Date(timeIntervalSince1970: 1_700_000_100)
        let plant = Plant(name: "Restored Plant", wateringIntervalDays: 7, fertilizingIntervalDays: 30)
        plant.createdAt = Date(timeIntervalSince1970: 1_700_000_200)
        plant.remindersEnabled = false
        let careLog = PetCareLog(
            date: Date(timeIntervalSince1970: 1_700_000_300),
            type: .feeding,
            amountGrams: 25,
            pet: pet,
            executorId: human.id.uuidString
        )
        context.insert(pet)
        context.insert(human)
        context.insert(plant)
        context.insert(careLog)
        try context.save()

        let manager = DataBackupManager(defaults: defaults)
        return BackupFixture(backup: try manager.buildBackup(context: context), petID: petID)
    }

    private func makeTarget(petID: UUID) throws -> TargetFixture {
        let suiteName = "DataBackupAtomicRestoreTests.Target.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set("before-restore", forKey: "bountyTasks")
        let container = try makeContainer()
        let pet = Pet(name: "Original Pet", species: "cat")
        pet.id = petID
        pet.createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        container.mainContext.insert(pet)
        try container.mainContext.save()
        return TargetFixture(
            container: container,
            defaults: defaults,
            defaultsSuiteName: suiteName,
            manager: DataBackupManager(defaults: defaults),
            notifications: NotificationSpy()
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: ArkMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func assertPreflightFailure(
        _ backup: OhanaBackup,
        expected: BackupRestoreValidationCategory,
        petID: UUID
    ) throws {
        let fixture = try makeTarget(petID: petID)
        defer { fixture.removeDefaults() }

        do {
            try fixture.manager.applyBackup(
                backup,
                context: fixture.container.mainContext,
                projectionManager: nil,
                plantNotifications: fixture.notifications
            )
            Issue.record("Expected strict preflight failure: \(expected.rawValue)")
        } catch let BackupError.invalidRestoreData(category) {
            #expect(category == expected)
        }

        try assertOriginalState(fixture, petID: petID)
    }

    private func assertOriginalState(_ fixture: TargetFixture, petID: UUID) throws {
        let context = fixture.container.mainContext
        let pets = try context.fetch(FetchDescriptor<Pet>())
        #expect(pets.count == 1)
        #expect(pets.first?.id == petID)
        #expect(pets.first?.name == "Original Pet")
        #expect(try context.fetch(FetchDescriptor<Human>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Plant>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(fixture.defaults.string(forKey: "bountyTasks") == "before-restore")
        #expect(fixture.notifications.scheduledReminderIDs.isEmpty)
        #expect(fixture.notifications.cancelledNotificationIDs.isEmpty)
        #expect(!context.hasChanges)
    }

    private func recordCounts(in context: ModelContext) throws -> RecordCounts {
        RecordCounts(
            pets: try context.fetchCount(FetchDescriptor<Pet>()),
            humans: try context.fetchCount(FetchDescriptor<Human>()),
            plants: try context.fetchCount(FetchDescriptor<Plant>()),
            careLogs: try context.fetchCount(FetchDescriptor<PetCareLog>()),
            events: try context.fetchCount(FetchDescriptor<Event>()),
            reminders: try context.fetchCount(FetchDescriptor<Reminder>()),
            accounts: try context.fetchCount(FetchDescriptor<CoconutAccount>())
        )
    }

    private final class NotificationSpy: ReminderNotificationScheduling, @unchecked Sendable {
        private(set) var scheduledReminderIDs: [UUID] = []
        private(set) var cancelledNotificationIDs: [String] = []

        func schedule(reminder: Reminder) {
            scheduledReminderIDs.append(reminder.id)
        }

        func schedule(
            reminder: Reminder,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledReminderIDs.append(reminder.id)
            completion?(.scheduled)
        }

        func schedule(
            reminder: Reminder,
            deliveryDate _: Date?,
            existingNotificationIds _: Set<String>?,
            completion: ((ReminderNotificationScheduleResult) -> Void)?
        ) {
            scheduledReminderIDs.append(reminder.id)
            completion?(.scheduled)
        }

        func pendingNotificationIds() async -> Set<String> { [] }
        func scheduleRollingWindow(reminders _: [Reminder]) {}
        func refillWindowIfNeeded(allReminders _: [Reminder]) {}

        func cancel(notificationId: String) {
            cancelledNotificationIDs.append(notificationId)
        }

        func cancelAll(for _: Pet, reminders _: [Reminder]) {}
        func compensate(reminders _: [Reminder]) {}
    }
}
