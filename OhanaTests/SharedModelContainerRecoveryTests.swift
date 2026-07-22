import SQLite3
import SwiftData
import XCTest
@testable import Ohana

final class SharedModelContainerRecoveryTests: XCTestCase {
    func testEveryAutomaticOpenAttemptUsesOneWritablePrimaryIdentity() {
        XCTAssertEqual(
            SharedModelContainerOpenPolicy.orderedAttempts,
            [.primaryWithMigrationPlan, .primaryWithoutMigrationPlan]
        )
        XCTAssertEqual(
            Set(SharedModelContainerOpenPolicy.orderedAttempts.map(\.identity)),
            [.primary]
        )
        XCTAssertEqual(SharedModelContainerOpenPolicy.writableStoreIdentities, [.primary])
    }

    func testMigrationFailureRetriesTheSamePrimaryIdentity() throws {
        var attemptedStoreKinds: [SharedModelContainerStoreKind] = []

        let openedIdentity = try SharedModelContainerOpenPolicy.open { storeKind -> SharedModelContainerStoreIdentity in
            attemptedStoreKinds.append(storeKind)
            if storeKind == .primaryWithMigrationPlan {
                throw StoreOpenTestError.migrationPlanRejected
            }
            return storeKind.identity
        }

        XCTAssertEqual(openedIdentity, .primary)
        XCTAssertEqual(
            attemptedStoreKinds,
            [.primaryWithMigrationPlan, .primaryWithoutMigrationPlan]
        )
    }

    func testBothPrimaryOpenModesFailClosedBeforeAnyDiskOrMemoryFallbackWrite() {
        var attemptedStoreKinds: [SharedModelContainerStoreKind] = []

        XCTAssertThrowsError(try SharedModelContainerOpenPolicy.open { storeKind -> String in
            attemptedStoreKinds.append(storeKind)
            throw StoreOpenTestError.primaryUnavailable
        }) { error in
            XCTAssertEqual(
                error as? SharedModelContainerOpenFailure,
                SharedModelContainerOpenFailure(
                    attemptedStoreKinds: [.primaryWithMigrationPlan, .primaryWithoutMigrationPlan]
                )
            )
        }

        XCTAssertEqual(
            attemptedStoreKinds,
            [.primaryWithMigrationPlan, .primaryWithoutMigrationPlan]
        )
        XCTAssertEqual(Set(attemptedStoreKinds.map(\.identity)), [.primary])
    }

    func testDiskFullFailureCanRecoverAndRepeatOnlyOnThePrimaryIdentity() throws {
        var diskIsFull = true
        var attemptedStoreKinds: [SharedModelContainerStoreKind] = []

        XCTAssertThrowsError(try SharedModelContainerOpenPolicy.open { storeKind -> SharedModelContainerStoreIdentity in
            attemptedStoreKinds.append(storeKind)
            if diskIsFull {
                throw StoreOpenTestError.diskFull
            }
            return storeKind.identity
        })

        diskIsFull = false
        let recoveredIdentities = try (0 ..< 3).map { _ in
            try SharedModelContainerOpenPolicy.open { storeKind -> SharedModelContainerStoreIdentity in
                attemptedStoreKinds.append(storeKind)
                return storeKind.identity
            }
        }

        XCTAssertEqual(recoveredIdentities, [.primary, .primary, .primary])
        XCTAssertEqual(
            Array(attemptedStoreKinds.prefix(2)),
            [.primaryWithMigrationPlan, .primaryWithoutMigrationPlan]
        )
        XCTAssertTrue(attemptedStoreKinds.allSatisfy { $0.identity == .primary })
    }

    @MainActor
    func testSamePrimaryStorePreservesFallbackWriteAcrossRelaunch() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaStoreIdentityTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let petID = UUID()
        let schema = Schema(ArkSchemaV94.models)

        do {
            let container = try SharedModelContainerOpenPolicy.open { storeKind -> ModelContainer in
                if storeKind == .primaryWithMigrationPlan {
                    throw StoreOpenTestError.migrationPlanRejected
                }
                let configuration = ModelConfiguration(
                    "OhanaPrimary",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: schema, configurations: [configuration])
            }
            let pet = Pet(name: "Miso", species: "Cat", breed: "Domestic")
            pet.id = petID
            container.mainContext.insert(pet)
            try container.mainContext.save()
        }

        do {
            let container = try SharedModelContainerOpenPolicy.open { storeKind -> ModelContainer in
                let configuration = ModelConfiguration(
                    "OhanaPrimary",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
                switch storeKind {
                case .primaryWithMigrationPlan:
                    return try ModelContainer(
                        for: schema,
                        migrationPlan: ArkMigrationPlan.self,
                        configurations: [configuration]
                    )
                case .primaryWithoutMigrationPlan:
                    return try ModelContainer(for: schema, configurations: [configuration])
                }
            }
            var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == petID })
            descriptor.fetchLimit = 1
            let restoredPet = try container.mainContext.fetch(descriptor).first

            XCTAssertEqual(restoredPet?.id, petID)
            XCTAssertEqual(restoredPet?.name, "Miso")
        }
    }

    func testCloudSyncDeletionTombstoneDefaultsMirrorLegacyDeletionFlag() {
        let activeRecord = CloudSyncRecordState(entityName: "Pet", localRecordId: UUID())
        XCTAssertFalse(activeRecord.isDeleted)
        XCTAssertFalse(activeRecord.isDeletionTombstone)

        let deletedRecord = CloudSyncRecordState(
            entityName: "Pet",
            localRecordId: UUID(),
            isDeleted: true
        )
        XCTAssertTrue(deletedRecord.isDeleted)
        XCTAssertTrue(deletedRecord.isDeletionTombstone)
    }

    func testCloudSyncTombstoneDefaultLandsOnLatestLightweightSchema() {
        XCTAssertEqual(ObjectIdentifier(ArkMigrationPlan.schemas.last!), ObjectIdentifier(ArkSchemaV96.self))
        XCTAssertTrue(ArkMigrationPlan.stages.isEmpty)
    }

    func testV91AddsOnlyTheHumanNoteAttributionSidecarToV90ModelRegistration() {
        let v90 = Set(ArkSchemaV90.models.map { String(describing: $0) })
        let v91 = Set(ArkSchemaV91.models.map { String(describing: $0) })

        XCTAssertFalse(v90.contains(String(describing: HumanNoteRecord.self)))
        XCTAssertEqual(v91.subtracting(v90), [String(describing: HumanNoteRecord.self)])
        XCTAssertTrue(v90.subtracting(v91).isEmpty)
    }

    func testV92AddsOnlyTheShopPurchaseAttemptToV91ModelRegistration() {
        let v91 = Set(ArkSchemaV91.models.map { String(describing: $0) })
        let v92 = Set(ArkSchemaV92.models.map { String(describing: $0) })

        XCTAssertFalse(v91.contains(String(describing: ShopPurchaseAttempt.self)))
        XCTAssertEqual(v92.subtracting(v91), [String(describing: ShopPurchaseAttempt.self)])
        XCTAssertTrue(v91.subtracting(v92).isEmpty)
    }

    @MainActor
    func testV91StoreMigratesToV92AndPersistsShopPurchaseAttempt() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaShopAttemptV92MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let humanID = UUID()
        do {
            let schema = Schema(ArkSchemaV91.models)
            let configuration = ModelConfiguration(
                "ShopAttemptV91Source",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV91OnlyMigrationPlan.self,
                configurations: [configuration]
            )
            let human = Human(name: "V91 Shop Buyer")
            human.id = humanID
            container.mainContext.insert(human)
            try container.mainContext.save()
        }

        let attemptID = UUID()
        let ledgerEventID = UUID()
        let createdAt = Date(timeIntervalSinceReferenceDate: 92000)
        do {
            let schema = Schema(ArkSchemaV92.models)
            let configuration = ModelConfiguration(
                "ShopAttemptV92Target",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [configuration]
            )
            XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Human>()).map(\.id), [humanID])
            XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<ShopPurchaseAttempt>()).isEmpty)

            let attempt = ShopPurchaseAttempt(
                id: attemptID,
                transactionKey: "shop:v92:\(attemptID.uuidString)",
                itemId: "boost_double",
                buyerHumanId: humanID.uuidString,
                price: 35,
                state: .fulfilling,
                purchaseLedgerEventId: ledgerEventID,
                fundingContributionsJSON: "{\"version\":1,\"contributions\":[]}",
                fulfillmentPayloadJSON: "{\"version\":1}",
                attemptCount: 1,
                lastError: "interrupted",
                nextRetryAt: createdAt.addingTimeInterval(30),
                createdAt: createdAt
            )
            container.mainContext.insert(attempt)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV92.models)
            let configuration = ModelConfiguration(
                "ShopAttemptV92Target",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [configuration]
            )
            let attempt = try XCTUnwrap(
                try container.mainContext.fetch(FetchDescriptor<ShopPurchaseAttempt>()).first
            )
            XCTAssertEqual(attempt.id, attemptID)
            XCTAssertEqual(attempt.itemId, "boost_double")
            XCTAssertEqual(attempt.buyerHumanId, humanID.uuidString)
            XCTAssertEqual(attempt.price, 35)
            XCTAssertEqual(attempt.state, .fulfilling)
            XCTAssertEqual(attempt.purchaseLedgerEventId, ledgerEventID)
            XCTAssertEqual(attempt.attemptCount, 1)
            XCTAssertEqual(attempt.lastError, "interrupted")
            XCTAssertEqual(attempt.createdAt, createdAt)
        }
    }

    @MainActor
    func testV92StoreMigratesToCurrentV93AndPreservesUnsettledShopPurchaseAttempt() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaShopAttemptV93MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let humanID = UUID()
        let attemptID = UUID()
        let createdAt = Date(timeIntervalSinceReferenceDate: 93000)
        do {
            let schema = Schema(ArkSchemaV92.models)
            let configuration = ModelConfiguration(
                "ShopAttemptV92Source",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV92OnlyMigrationPlan.self,
                configurations: [configuration]
            )
            let human = Human(name: "V92 Pending Shop Buyer")
            human.id = humanID
            let fundingData = try JSONEncoder().encode([
                ShopPurchaseFundingContribution(humanID: humanID, amount: 580)
            ])
            let fundingJSON = try XCTUnwrap(String(data: fundingData, encoding: .utf8))
            let attempt = ShopPurchaseAttempt(
                id: attemptID,
                transactionKey: "shop:v92-current:\(attemptID.uuidString)",
                itemId: "boost_backdate_pack",
                buyerHumanId: humanID.uuidString,
                price: 580,
                state: .refundPending,
                fundingContributionsJSON: fundingJSON,
                createdAt: createdAt
            )
            container.mainContext.insert(human)
            container.mainContext.insert(attempt)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV94.models)
            let configuration = ModelConfiguration(
                "ShopAttemptV93Target",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [configuration]
            )
            let attempt = try XCTUnwrap(
                try container.mainContext.fetch(FetchDescriptor<ShopPurchaseAttempt>()).first
            )
            XCTAssertEqual(attempt.id, attemptID)
            XCTAssertEqual(attempt.buyerHumanId, humanID.uuidString)
            XCTAssertEqual(attempt.itemId, "boost_backdate_pack")
            XCTAssertEqual(attempt.state, .refundPending)
            XCTAssertEqual(attempt.price, 580)
            XCTAssertEqual(attempt.createdAt, createdAt)
        }
    }

    @MainActor
    func testRealV90BinaryStoreMigratesToV91AndPersistsAttributionFacts() throws {
        let fixtureURL = try v90FixtureStoreURL()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaRealV90MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("default.store")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)

        let legacyAttributionTables = [
            "ZPETEXPENSELOG",
            "ZHEATCYCLELOG",
            "ZHUMANHEALTHMETRICLOG",
            "ZHUMANHEALTHREPORT",
            "ZSYMPTOMLOG"
        ]

        XCTAssertEqual(
            try sqliteScalar(
                at: storeURL,
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'ZHUMANNOTERECORD'"
            ),
            0,
            "The checked-in fixture must remain a pre-V91 store without HumanNoteRecord."
        )
        for table in legacyAttributionTables {
            XCTAssertEqual(
                try sqliteScalar(
                    at: storeURL,
                    sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = '\(table)'"
                ),
                1,
                "The V90 fixture should contain the legacy \(table) table."
            )
            XCTAssertEqual(
                try sqliteScalar(
                    at: storeURL,
                    sql: "SELECT COUNT(*) FROM pragma_table_info('\(table)') WHERE name = 'ZRECORDEDBYHUMANID'"
                ),
                0,
                "The checked-in V90 fixture must predate \(table).recordedByHumanId."
            )
        }

        let schema = Schema(ArkSchemaV91.models)
        let petID = UUID()
        let expenseID = UUID()
        let noteRecordID = UUID()
        let recordedAt = Date(timeIntervalSince1970: 1_900_200_000)
        let recorderID: UUID

        do {
            let configuration = ModelConfiguration(
                "RealV90ToV91Migration",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [configuration]
            )
            let context = container.mainContext
            let humans = try context.fetch(FetchDescriptor<Human>())
            let plants = try context.fetch(FetchDescriptor<Plant>())

            XCTAssertEqual(humans.map(\.name), ["FixtureHuman"])
            XCTAssertEqual(plants.map(\.name), ["Codex Pothos Seed-1"])
            XCTAssertTrue(try context.fetch(FetchDescriptor<HumanNoteRecord>()).isEmpty)

            let recorder = try XCTUnwrap(humans.first)
            recorderID = recorder.id
            let pet = Pet(name: "V91 Fixture Pet", species: "Cat", breed: "Domestic")
            pet.id = petID
            let expense = PetExpenseLog(
                date: recordedAt,
                amount: 12.5,
                category: .medical,
                note: "V91 attribution migration proof",
                pet: pet,
                executorId: recorderID.uuidString,
                recordedByHumanId: recorderID.uuidString
            )
            expense.id = expenseID
            let noteRecord = HumanNoteRecord(
                id: noteRecordID,
                humanId: recorderID,
                sequence: 0,
                date: recordedAt,
                rawEntry: "V91 sidecar migration proof",
                recordedByHumanId: recorderID.uuidString
            )

            context.insert(pet)
            context.insert(expense)
            context.insert(noteRecord)
            try context.save()
        }

        do {
            let configuration = ModelConfiguration(
                "RealV90ToV91Migration",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [configuration]
            )
            let context = container.mainContext
            var expenseDescriptor = FetchDescriptor<PetExpenseLog>(
                predicate: #Predicate<PetExpenseLog> { $0.id == expenseID }
            )
            expenseDescriptor.fetchLimit = 1
            var noteDescriptor = FetchDescriptor<HumanNoteRecord>(
                predicate: #Predicate<HumanNoteRecord> { $0.id == noteRecordID }
            )
            noteDescriptor.fetchLimit = 1

            let expense = try XCTUnwrap(context.fetch(expenseDescriptor).first)
            let noteRecord = try XCTUnwrap(context.fetch(noteDescriptor).first)
            XCTAssertEqual(expense.pet?.id, petID)
            XCTAssertEqual(expense.executorId, recorderID.uuidString)
            XCTAssertEqual(expense.recordedByHumanId, recorderID.uuidString)
            XCTAssertEqual(noteRecord.humanId, recorderID)
            XCTAssertEqual(noteRecord.rawEntry, "V91 sidecar migration proof")
            XCTAssertEqual(noteRecord.recordedByHumanId, recorderID.uuidString)
            XCTAssertEqual(try context.fetch(FetchDescriptor<Human>()).map(\.name), ["FixtureHuman"])
            XCTAssertEqual(try context.fetch(FetchDescriptor<Plant>()).map(\.name), ["Codex Pothos Seed-1"])
        }
    }

    @MainActor
    func testV86LegacyPetFamilyTaskOpensOnV87WithCompatibilitySubject() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaFamilyTaskV87MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let creatorID = UUID()
        let petID = UUID()
        let taskID = UUID()
        do {
            let schema = Schema(ArkSchemaV86.models)
            let config = ModelConfiguration("FamilyTaskV86Source", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV86OnlyMigrationPlan.self,
                configurations: [config]
            )
            let creator = Human(name: "Publisher")
            creator.id = creatorID
            let pet = Pet(name: "Momo", species: "cat")
            pet.id = petID
            let task = FamilyCollaborationTask(
                id: taskID,
                title: "Feed Momo",
                kind: .careReminder,
                relatedPetId: petID.uuidString,
                createdById: creatorID.uuidString,
                createdByName: creator.name
            )
            // Reproduce a V86 row before the canonical subject columns existed.
            task.subjectKindRaw = ""
            task.subjectId = nil
            container.mainContext.insert(creator)
            container.mainContext.insert(pet)
            container.mainContext.insert(task)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV87.models)
            let config = ModelConfiguration("FamilyTaskV87Target", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            var descriptor = FetchDescriptor<FamilyCollaborationTask>(
                predicate: #Predicate<FamilyCollaborationTask> { $0.id == taskID }
            )
            descriptor.fetchLimit = 1
            let task = try XCTUnwrap(container.mainContext.fetch(descriptor).first)

            XCTAssertEqual(task.subjectKind, .pet)
            XCTAssertEqual(task.resolvedSubjectId, petID.uuidString)
            XCTAssertEqual(task.relatedPetId, petID.uuidString)
        }
    }

    @MainActor
    func testV87EventOpensThroughLatestWithEmptyTaskCareKindDefault() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaEventV88MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let eventID = UUID()
        do {
            let schema = Schema(ArkSchemaV87.models)
            let config = ModelConfiguration("EventV87Source", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV87OnlyMigrationPlan.self,
                configurations: [config]
            )
            let event = Event(
                title: "Legacy task",
                startDate: Date(timeIntervalSince1970: 1_900_000_000),
                eventType: EventType.task.rawValue
            )
            event.id = eventID
            event.taskCareKindRaw = ""
            container.mainContext.insert(event)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV94.models)
            let config = ModelConfiguration("EventLatestTarget", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            var descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == eventID })
            descriptor.fetchLimit = 1
            let event = try XCTUnwrap(container.mainContext.fetch(descriptor).first)

            XCTAssertEqual(event.title, "Legacy task")
            XCTAssertEqual(event.taskCareKindRaw, "")
        }
    }

    @MainActor
    func testV88ReminderOpensThroughLatestWithLegacyOccurrenceFallback() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaReminderV89MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let reminderID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_900_100_000)
        do {
            let schema = Schema(ArkSchemaV88.models)
            let config = ModelConfiguration("ReminderV88Source", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV88OnlyMigrationPlan.self,
                configurations: [config]
            )
            let event = Event(title: "Legacy care", startDate: scheduledAt)
            let reminder = Reminder(event: event, scheduledAt: scheduledAt)
            reminder.id = reminderID
            container.mainContext.insert(event)
            container.mainContext.insert(reminder)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV94.models)
            let config = ModelConfiguration("ReminderLatestTarget", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate<Reminder> { $0.id == reminderID })
            descriptor.fetchLimit = 1
            let reminder = try XCTUnwrap(container.mainContext.fetch(descriptor).first)

            XCTAssertNil(reminder.occurrenceAt)
            XCTAssertEqual(reminder.resolvedOccurrenceAt, scheduledAt)
        }
    }

    @MainActor
    func testV89StoreOpensThroughLatestWithSharedCareFactsAndNoSyntheticUndoReceipt() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaUndoReceiptV90MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let sessionID = UUID()
        let sourcePetID = UUID()
        do {
            let schema = Schema(ArkSchemaV89.models)
            let config = ModelConfiguration(
                "UndoReceiptV89Source",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV89OnlyMigrationPlan.self,
                configurations: [config]
            )
            let session = SharedCareSession(
                actionKind: .litterScoop,
                sourcePetId: sourcePetID.uuidString,
                targetPetIds: [sourcePetID.uuidString],
                species: "cat"
            )
            session.id = sessionID
            container.mainContext.insert(session)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV94.models)
            let config = ModelConfiguration(
                "UndoReceiptV90Target",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            let sessions = try container.mainContext.fetch(FetchDescriptor<SharedCareSession>())
            let receipts = try container.mainContext.fetch(FetchDescriptor<SharedCareUndoReceipt>())

            XCTAssertEqual(sessions.map(\.id), [sessionID])
            XCTAssertEqual(sessions.first?.sourcePetId, sourcePetID.uuidString)
            XCTAssertTrue(receipts.isEmpty)
        }
    }

    @MainActor
    func testLatestUndoReceiptPersistsAcrossContainerRelaunch() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaUndoReceiptPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let receiptID = UUID()
        let sessionID = UUID()
        let sourcePetID = UUID()
        let targetPetID = UUID()
        let reminderID = UUID()
        let occurredAt = Date(timeIntervalSinceReferenceDate: 10000)
        let undoDeadline = occurredAt.addingTimeInterval(6)

        do {
            let schema = Schema(ArkSchemaV94.models)
            let config = ModelConfiguration(
                "UndoReceiptPersistenceSource",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            let receipt = SharedCareUndoReceipt(
                id: receiptID,
                sharedSessionId: sessionID,
                sourcePetId: sourcePetID,
                targetPetIds: [sourcePetID, targetPetID, sourcePetID],
                executorId: "member-1",
                actionKind: .litterScoop,
                occurredAt: occurredAt,
                createdAt: occurredAt,
                undoDeadline: undoDeadline,
                state: .externalEffectsPending,
                reminderOccurrences: [
                    SharedCareUndoReminderOccurrence(
                        targetPetId: targetPetID,
                        reminderId: reminderID,
                        occurrenceAt: occurredAt
                    )
                ],
                corePayloadJSON: "{\"version\":1}",
                externalEffectsPayloadJSON: "{\"version\":1}",
                completedExternalEffects: [.userDefaults, .notifications],
                attemptCount: 2,
                lastError: "retryable",
                nextRetryAt: undoDeadline.addingTimeInterval(5)
            )
            container.mainContext.insert(receipt)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV94.models)
            let config = ModelConfiguration(
                "UndoReceiptPersistenceTarget",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            let receipt = try XCTUnwrap(
                try container.mainContext.fetch(FetchDescriptor<SharedCareUndoReceipt>()).first
            )

            XCTAssertEqual(receipt.id, receiptID)
            XCTAssertEqual(receipt.sharedSessionId, sessionID)
            XCTAssertEqual(receipt.sourcePetId, sourcePetID)
            XCTAssertEqual(receipt.targetPetIds, [sourcePetID, targetPetID])
            XCTAssertEqual(receipt.executorId, "member-1")
            XCTAssertEqual(receipt.actionKind, .litterScoop)
            XCTAssertEqual(receipt.state, .externalEffectsPending)
            XCTAssertEqual(receipt.undoDeadline, undoDeadline)
            XCTAssertEqual(
                receipt.reminderOccurrences,
                [
                    SharedCareUndoReminderOccurrence(
                        targetPetId: targetPetID,
                        reminderId: reminderID,
                        occurrenceAt: occurredAt
                    )
                ]
            )
            XCTAssertEqual(receipt.completedExternalEffects, [.userDefaults, .notifications])
            XCTAssertEqual(receipt.attemptCount, 2)
            XCTAssertEqual(receipt.lastError, "retryable")
        }
    }

    @MainActor
    func testV67StoreOpensThroughLatestLightweightMigrationWithoutLosingCloudSyncRecord() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaModelsMigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let recordId = UUID()
        let expectedRecordKey = CloudSyncRecordState.recordKey(entityName: "Pet", localRecordId: recordId)
        do {
            let schema = Schema(ArkSchemaV67.models)
            let config = ModelConfiguration("ModelsMigrationSource", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV67OnlyMigrationPlan.self,
                configurations: [config]
            )
            let context = container.mainContext
            context.insert(CloudSyncRecordState(entityName: "Pet", localRecordId: recordId))
            try context.save()
        }

        do {
            let schema = Schema(ArkSchemaV94.models)
            let config = ModelConfiguration("ModelsMigrationTarget", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            let records = try container.mainContext.fetch(FetchDescriptor<CloudSyncRecordState>())

            XCTAssertEqual(records.map(\.recordKey), [expectedRecordKey])
            XCTAssertFalse(records[0].isDeleted)
            XCTAssertFalse(records[0].isDeletionTombstone)
        }
    }

    @MainActor
    func testV67StoreOpensThroughLatestLightweightMigrationWithCoreUserData() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaCoreUserDataMigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let petID = UUID()
        let humanID = UUID()
        let plantID = UUID()
        let accountKey = "pet:\(petID.uuidString)"
        let eventStart = Date(timeIntervalSince1970: 1_785_000_000)
        let reminderTime = eventStart.addingTimeInterval(3600)

        do {
            let schema = Schema(ArkSchemaV67.models)
            let config = ModelConfiguration("CoreUserDataMigrationSource", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkSchemaV67OnlyMigrationPlan.self,
                configurations: [config]
            )
            let context = container.mainContext

            let pet = Pet(name: "Miso", species: "Cat", breed: "Domestic")
            pet.id = petID
            pet.foodBrand = "Ohana Kibble"
            pet.coconutBalance = 12

            let human = Human(name: "Alex", role: "owner", genderIdentityRaw: "nonbinary")
            human.id = humanID
            human.coconutBalance = 7

            let plant = Plant(name: "Pothos", species: "Epipremnum", location: "Living room", wateringIntervalDays: 5)
            plant.id = plantID
            plant.lastWateredDate = eventStart.addingTimeInterval(-86400 * 4)

            let event = Event(
                title: "Water Pothos",
                startDate: eventStart,
                isAllDay: true,
                eventType: EventType.watering.rawValue,
                relatedEntityType: EntityKind.plant.rawValue,
                relatedEntityId: plantID.uuidString
            )
            event.recurrenceDays = 5

            let reminder = Reminder(event: event, scheduledAt: reminderTime)
            let careLog = PetCareLog(
                date: eventStart,
                type: .feeding,
                amountGrams: 32,
                note: "legacy feed",
                pet: pet,
                executorId: humanID.uuidString
            )
            let plantLog = PlantCareLog(
                date: eventStart,
                careType: .watering,
                note: "legacy plant water",
                executorId: humanID.uuidString,
                careTransactionId: ""
            )
            plantLog.plant = plant
            let careLedger = CareLedgerEvent(
                occurredAt: eventStart,
                actorKind: .human,
                actorId: humanID.uuidString,
                subjectKind: .pet,
                subjectId: petID.uuidString,
                eventKind: .care,
                actionType: CareType.feeding.rawValue,
                amountValue: 32,
                amountUnit: "g",
                note: "legacy feed",
                source: .service,
                legacyModelName: "PetCareLog",
                legacyModelId: careLog.id.uuidString,
                coconutDelta: 1
            )
            let walletAccount = CoconutAccount(
                accountKey: accountKey,
                ownerKind: .pet,
                ownerId: petID.uuidString,
                displayName: pet.name,
                balance: 12
            )
            let walletEntry = CoconutLedgerEntry(
                transactionKey: "legacy-feed-\(careLog.id.uuidString)",
                accountKey: accountKey,
                ownerKind: .pet,
                ownerId: petID.uuidString,
                ownerName: pet.name,
                delta: 1,
                balanceBefore: 11,
                balanceAfter: 12,
                entryKind: .reward,
                source: .careEvent,
                title: "Legacy feed",
                emoji: "coconut",
                actorId: humanID.uuidString,
                actorName: human.name,
                subjectKind: .pet,
                subjectId: petID.uuidString,
                sourceModelName: "PetCareLog",
                sourceModelId: careLog.id.uuidString,
                careLedgerEventId: careLedger.id.uuidString
            )

            context.insert(human)
            context.insert(pet)
            context.insert(plant)
            context.insert(event)
            context.insert(reminder)
            context.insert(careLog)
            context.insert(plantLog)
            context.insert(careLedger)
            context.insert(walletAccount)
            context.insert(walletEntry)
            try context.save()
        }

        do {
            let schema = Schema(ArkSchemaV94.models)
            let config = ModelConfiguration("CoreUserDataMigrationTarget", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [config]
            )
            let context = container.mainContext

            let pets = try context.fetch(FetchDescriptor<Pet>())
            let humans = try context.fetch(FetchDescriptor<Human>())
            let plants = try context.fetch(FetchDescriptor<Plant>())
            let events = try context.fetch(FetchDescriptor<Event>())
            let reminders = try context.fetch(FetchDescriptor<Reminder>())
            let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
            let plantLogs = try context.fetch(FetchDescriptor<PlantCareLog>())
            let careLedgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
            let walletAccounts = try context.fetch(FetchDescriptor<CoconutAccount>())
            let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())

            XCTAssertEqual(pets.map(\.name), ["Miso"])
            XCTAssertEqual(humans.map(\.name), ["Alex"])
            XCTAssertEqual(plants.map(\.name), ["Pothos"])
            XCTAssertEqual(events.map(\.title), ["Water Pothos"])
            XCTAssertEqual(events.map(\.taskCareKindRaw), [""])
            XCTAssertEqual(reminders.map(\.scheduledAt), [reminderTime])
            XCTAssertEqual(careLogs.map(\.note), ["legacy feed"])
            XCTAssertEqual(plantLogs.map(\.note), ["legacy plant water"])
            XCTAssertEqual(plantLogs.map(\.careTransactionId), [""])
            XCTAssertEqual(careLedgerEvents.map(\.actionType), [CareType.feeding.rawValue])
            XCTAssertEqual(walletAccounts.map(\.balance), [12])
            XCTAssertEqual(walletEntries.map(\.delta), [1])

            let migratedPet = try XCTUnwrap(pets.first)
            let migratedPlant = try XCTUnwrap(plants.first)
            XCTAssertEqual(migratedPet.cardPopoutAttachmentState, .absent)
            XCTAssertEqual(migratedPet.avatarTransparencyState, .absent)
            XCTAssertNil(migratedPlant.archivedAt)
            XCTAssertEqual(migratedPlant.avatarAttachmentState, .absent)
        }
    }
}

private extension SharedModelContainerRecoveryTests {
    func v90FixtureStoreURL() throws -> URL {
        let bundle = Bundle(for: SharedModelContainerRecoveryTests.self)
        if let nestedURL = bundle.url(
            forResource: "default",
            withExtension: "store",
            subdirectory: "Fixtures/ArkSchemaV90"
        ) {
            return nestedURL
        }
        if let flatURL = bundle.url(forResource: "default", withExtension: "store") {
            return flatURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: bundle.bundleURL,
            includingPropertiesForKeys: nil
        ) else {
            throw migrationFixtureError("Unable to enumerate the OhanaTests bundle for the V90 fixture.")
        }
        for case let candidate as URL in enumerator where candidate.lastPathComponent == "default.store" {
            return candidate
        }
        throw migrationFixtureError("Missing Fixtures/ArkSchemaV90/default.store in the OhanaTests bundle.")
    }

    func sqliteScalar(at storeURL: URL, sql: String) throws -> Int64 {
        var database: OpaquePointer?
        let immutableStoreURI = storeURL.absoluteString + "?immutable=1"
        let openResult = sqlite3_open_v2(
            immutableStoreURI,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_URI,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite open error"
            if let database {
                sqlite3_close(database)
            }
            throw migrationFixtureError("Unable to open the V90 fixture: \(message)")
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw migrationFixtureError(
                "Unable to prepare a V90 fixture assertion: \(String(cString: sqlite3_errmsg(database)))"
            )
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw migrationFixtureError(
                "V90 fixture assertion returned no row: \(String(cString: sqlite3_errmsg(database)))"
            )
        }
        return sqlite3_column_int64(statement, 0)
    }

    func migrationFixtureError(_ description: String) -> NSError {
        NSError(
            domain: "OhanaTests.ArkSchemaV90Fixture",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}

private enum StoreOpenTestError: Error {
    case migrationPlanRejected
    case primaryUnavailable
    case diskFull
}

private enum ArkSchemaV67OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV67.self] }
    static var stages: [MigrationStage] { [] }
}

private enum ArkSchemaV86OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV86.self] }
    static var stages: [MigrationStage] { [] }
}

private enum ArkSchemaV91OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV91.self] }
    static var stages: [MigrationStage] { [] }
}

private enum ArkSchemaV92OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV92.self] }
    static var stages: [MigrationStage] { [] }
}

private enum ArkSchemaV87OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV87.self] }
    static var stages: [MigrationStage] { [] }
}

private enum ArkSchemaV88OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV88.self] }
    static var stages: [MigrationStage] { [] }
}

private enum ArkSchemaV89OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV89.self] }
    static var stages: [MigrationStage] { [] }
}
