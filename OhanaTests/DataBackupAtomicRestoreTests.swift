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

        let timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_500))
        let restoredHumanID = try #require(source.backup.humans.first?.id)
        let missingRecorderID = UUID().uuidString

        var brokenMetricRecorder = source.backup
        brokenMetricRecorder.humanHealthMetricLogs = [
            HumanHealthMetricLogBackup(
                id: UUID().uuidString,
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: 10,
                date: timestamp,
                notes: "",
                humanId: restoredHumanID,
                recordedByHumanId: missingRecorderID,
                createdAt: timestamp
            )
        ]

        var brokenReportRecorder = source.backup
        brokenReportRecorder.humanHealthReports = [
            HumanHealthReportBackup(
                id: UUID().uuidString,
                humanId: restoredHumanID,
                reportTypeRaw: "checkup",
                conclusionRaw: "normal",
                hospitalName: "",
                doctorName: "",
                reportDate: timestamp,
                nextCheckDate: nil,
                summary: "",
                notes: "",
                recordedByHumanId: missingRecorderID,
                colorHex: "",
                createdAt: timestamp
            )
        ]

        var brokenSymptomRecorder = source.backup
        brokenSymptomRecorder.symptomLogs = [
            SymptomLogBackup(
                id: UUID().uuidString,
                date: timestamp,
                categoryRaw: "other",
                symptomName: "test",
                severityRaw: 1,
                note: "",
                photoBase64: nil,
                photoRef: nil,
                petId: source.petID.uuidString,
                recordedByHumanId: missingRecorderID
            )
        ]

        var brokenHeatCycleRecorder = source.backup
        brokenHeatCycleRecorder.heatCycleLogs = [
            HeatCycleLogBackup(
                id: UUID().uuidString,
                startDate: timestamp,
                endDate: nil,
                statusRaw: "active",
                note: "",
                isMated: false,
                expectedDeliveryDate: nil,
                petId: source.petID.uuidString,
                recordedByHumanId: missingRecorderID
            )
        ]

        for backup in [
            brokenMetricRecorder,
            brokenReportRecorder,
            brokenSymptomRecorder,
            brokenHeatCycleRecorder
        ] {
            try assertPreflightFailure(
                backup,
                expected: .relationship,
                petID: source.petID
            )
        }

        var brokenMetricSourceReport = source.backup
        brokenMetricSourceReport.humanHealthMetricLogs = [
            HumanHealthMetricLogBackup(
                id: UUID().uuidString,
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: 2.1,
                date: timestamp,
                notes: "",
                humanId: restoredHumanID,
                sourceReportID: UUID().uuidString,
                createdAt: timestamp
            )
        ]
        try assertPreflightFailure(
            brokenMetricSourceReport,
            expected: .relationship,
            petID: source.petID
        )

        for (metricKey, unitCode, value) in [
            ("unknown_metric", "mIU_L", 2.1),
            ("tsh", "wrong_unit", 2.1),
            ("tsh", "mIU_L", -1)
        ] {
            var invalidMetric = source.backup
            invalidMetric.humanHealthMetricLogs = [
                HumanHealthMetricLogBackup(
                    id: UUID().uuidString,
                    metricKey: metricKey,
                    unitCode: unitCode,
                    value: value,
                    date: timestamp,
                    notes: "",
                    humanId: restoredHumanID,
                    createdAt: timestamp
                )
            ]
            try assertPreflightFailure(
                invalidMetric,
                expected: .businessValue,
                petID: source.petID
            )
        }

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

    @Test func restoreAppliesMultiPayerPetExpenseAndReadsExactShares() throws {
        let source = try makeBackup()
        let primaryPayerRaw = try #require(source.backup.humans.first?.id)
        let primaryPayerID = try #require(UUID(uuidString: primaryPayerRaw))
        let coPayerID = UUID()
        let expenseID = UUID()
        let timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_450))
        let contributions = [
            ExpensePayerContribution(humanID: primaryPayerID, minorUnits: 6000),
            ExpensePayerContribution(humanID: coPayerID, minorUnits: 4000)
        ]
        var backup = source.backup
        var coPayer = try #require(backup.humans.first)
        coPayer.id = coPayerID.uuidString
        coPayer.name = "Co-payer"
        backup.humans.append(coPayer)
        backup.petExpenseLogs = [
            PetExpenseLogBackup(
                id: expenseID.uuidString,
                date: timestamp,
                amount: 100,
                category: ExpenseCategory.medical.rawValue,
                note: "Shared clinic bill",
                petId: source.petID.uuidString,
                executorId: primaryPayerID.uuidString,
                recordedByHumanId: coPayerID.uuidString,
                sharedSessionId: nil,
                payerContributionsJSON: ExpensePayerContributionPolicy.encode(contributions)
            )
        ]
        let fixture = try makeTarget(petID: source.petID)
        defer { fixture.removeDefaults() }

        try fixture.manager.applyBackup(
            backup,
            context: fixture.container.mainContext,
            projectionManager: nil,
            schedulePlantNotifications: false,
            plantNotifications: fixture.notifications
        )

        let expense = try #require(
            try fixture.container.mainContext.fetch(FetchDescriptor<PetExpenseLog>()).first {
                $0.id == expenseID
            }
        )
        #expect(expense.pet?.id == source.petID)
        #expect(expense.executorId == primaryPayerID.uuidString)
        #expect(expense.recordedByHumanId == coPayerID.uuidString)
        #expect(expense.payerContributions == contributions)
        #expect(ExpenseSummaryBuilder.amountPaid(by: primaryPayerID, for: expense) == 60)
        #expect(ExpenseSummaryBuilder.amountPaid(by: coPayerID, for: expense) == 40)
    }

    @Test func restoreLimitsAndMediaReaderRejectOversizeOrTampering() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataBackupAtomicRestoreTests.\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let oversizedManifest = root.appendingPathComponent("oversized.json")
        #expect(FileManager.default.createFile(atPath: oversizedManifest.path, contents: nil))
        let handle = try FileHandle(forWritingTo: oversizedManifest)
        try handle.truncate(atOffset: UInt64(DataBackupRestoreLimits.maximumEncryptedManifestBytes + 1))
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

    @Test func encryptedFiftyMiBMediaPackageRoundTripsWithinPlaintextLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataBackupEncryptedMedia.\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let password = "Strong backup password"
        let writer = DataBackupMediaPackageWriter(packageURL: root, encryptMedia: true, password: password)
        try writer.preparePackageDirectory()
        let original = Data(repeating: 0xA5, count: 50 * 1024 * 1024)
        let reference = try #require(try writer.write(original, purpose: .petDocumentAttachmentFile, id: UUID().uuidString))
        let reader = DataBackupMediaPackageReader(packageURL: root, password: password)
        let restored = try #require(try reader.data(for: reference))

        #expect(reference.byteCount == original.count)
        #expect(restored == original)
        #expect(writer.mediaBytes == original.count)
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

    @Test func restrictedRestorePreservesExistingMedicationPrivacyAndLocalMedication() throws {
        let source = try makeBackup(includingHumanMedication: true)
        let humanBackup = try #require(source.backup.humans.first)
        let humanID = try #require(UUID(uuidString: humanBackup.id))
        #expect(humanBackup.bloodType.isEmpty)
        #expect(humanBackup.notes.isEmpty)
        #expect(humanBackup.heightCm == nil)
        #expect(humanBackup.privateFieldsRaw == nil)
        #expect((source.backup.humanMedications ?? []).isEmpty)

        let fixture = try makeTarget(petID: source.petID)
        defer { fixture.removeDefaults() }
        let existingHuman = Human(name: "Existing Human")
        existingHuman.id = humanID
        existingHuman.bloodType = "O-"
        existingHuman.heightCm = 181
        existingHuman.notes = "Existing local health note"
        existingHuman.setPrivate(.medication, true)
        let existingMedication = HumanMedication(
            humanId: humanID.uuidString,
            name: "Local medication"
        )
        fixture.container.mainContext.insert(existingHuman)
        fixture.container.mainContext.insert(existingMedication)
        try fixture.container.mainContext.save()

        try fixture.manager.applyBackup(
            source.backup,
            context: fixture.container.mainContext,
            projectionManager: nil,
            schedulePlantNotifications: false,
            plantNotifications: fixture.notifications
        )

        let restoredHuman = try #require(
            try fixture.container.mainContext.fetch(FetchDescriptor<Human>()).first {
                $0.id == humanID
            }
        )
        let localMedications = try fixture.container.mainContext.fetch(FetchDescriptor<HumanMedication>())
        #expect(restoredHuman.bloodType == "O-")
        #expect(restoredHuman.heightCm == 181)
        #expect(restoredHuman.notes == "Existing local health note")
        #expect(restoredHuman.privateFields.contains(HumanPrivateField.medication.rawValue))
        #expect(localMedications.count == 1)
        #expect(localMedications.first?.id == existingMedication.id)
    }

    @Test func linkedLabReportRestoresBeforeItsConfirmedMetrics() throws {
        let source = try makeBackup()
        let humanID = try #require(source.backup.humans.first?.id)
        let reportID = UUID()
        let logID = UUID()
        let timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_600))
        var backup = source.backup
        backup.humanHealthReports = [
            HumanHealthReportBackup(
                id: reportID.uuidString,
                humanId: humanID,
                reportTypeRaw: HealthReportType.bloodTest.rawValue,
                conclusionRaw: ReportConclusion.attention.rawValue,
                hospitalName: "Local Lab",
                doctorName: "",
                reportDate: timestamp,
                nextCheckDate: nil,
                summary: "",
                notes: "",
                captureSourceRaw: "documentScan",
                colorHex: "",
                createdAt: timestamp
            )
        ]
        backup.humanHealthMetricLogs = [
            HumanHealthMetricLogBackup(
                id: logID.uuidString,
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: 5.2,
                date: timestamp,
                notes: "",
                humanId: humanID,
                sourceReportID: reportID.uuidString,
                sourceLabel: "TSH",
                referenceLow: 0.4,
                referenceHigh: 4,
                referenceRangeText: "0.4–4.0",
                reportedFlagRaw: "high",
                createdAt: timestamp
            )
        ]
        let fixture = try makeTarget(petID: source.petID)
        defer { fixture.removeDefaults() }

        try fixture.manager.applyBackup(
            backup,
            context: fixture.container.mainContext,
            projectionManager: nil,
            schedulePlantNotifications: false,
            plantNotifications: fixture.notifications
        )

        let report = try #require(try fixture.container.mainContext.fetch(FetchDescriptor<HumanHealthReport>()).first)
        let log = try #require(try fixture.container.mainContext.fetch(FetchDescriptor<HumanHealthMetricLog>()).first)
        #expect(report.id == reportID)
        #expect(report.captureSourceRaw == "documentScan")
        #expect(log.id == logID)
        #expect(log.sourceReportID == reportID)
        #expect(log.referenceLow == 0.4)
        #expect(log.referenceHigh == 4)
        #expect(log.reportedFlagRaw == "high")
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

    private func makeBackup(includingHumanMedication: Bool = false) throws -> BackupFixture {
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
        if includingHumanMedication {
            human.bloodType = "AB+"
            human.heightCm = 172
            human.notes = "Source health note"
            human.setPrivate(.medication, true)
        }
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
        if includingHumanMedication {
            context.insert(HumanMedication(
                humanId: human.id.uuidString,
                name: "Source medication"
            ))
        }
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
        let schema = Schema(ArkSchemaV94.models)
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
