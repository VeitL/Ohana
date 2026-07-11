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
        let schema = Schema(ArkSchemaV85.models)

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
        XCTAssertEqual(ObjectIdentifier(ArkMigrationPlan.schemas.last!), ObjectIdentifier(ArkSchemaV85.self))
        XCTAssertTrue(ArkMigrationPlan.stages.isEmpty)
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
            let schema = Schema(ArkSchemaV85.models)
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
                executorId: humanID.uuidString
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
            let schema = Schema(ArkSchemaV85.models)
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
            XCTAssertEqual(reminders.map(\.scheduledAt), [reminderTime])
            XCTAssertEqual(careLogs.map(\.note), ["legacy feed"])
            XCTAssertEqual(plantLogs.map(\.note), ["legacy plant water"])
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

private enum StoreOpenTestError: Error {
    case migrationPlanRejected
    case primaryUnavailable
    case diskFull
}

private enum ArkSchemaV67OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV67.self] }
    static var stages: [MigrationStage] { [] }
}
