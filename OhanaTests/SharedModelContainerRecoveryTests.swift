import SQLite3
import SwiftData
import XCTest
@testable import Ohana

final class SharedModelContainerRecoveryTests: XCTestCase {
    func testBackupExclusionFailureStopsBeforeAnyPersistentStoreOpenAttempt() {
        var attemptedStoreKinds: [SharedModelContainerStoreKind] = []

        XCTAssertThrowsError(try SharedModelContainerCreationPolicy.open(
            preparingLocalPersistence: {
                throw StoreOpenTestError.backupExclusionRejected
            },
            using: { storeKind -> String in
                attemptedStoreKinds.append(storeKind)
                return storeKind.rawValue
            }
        )) { error in
            let failure = error as? SharedModelContainerPrivacyPreparationFailure
            XCTAssertNotNil(failure)
            XCTAssertTrue(failure?.underlyingDescription.isEmpty == false)
        }

        XCTAssertTrue(attemptedStoreKinds.isEmpty)
    }

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
        XCTAssertEqual(ObjectIdentifier(ArkMigrationPlan.schemas.last!), ObjectIdentifier(ArkSchemaV99.self))
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
    func testRealV90HealthRowsBinaryStoreMigratesToV99WithoutLosingLegacyValues() throws {
        let fixtureURL = try v90HealthRowsFixtureStoreURL()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaRealV90HealthRowsToV99MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("default.store")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)

        XCTAssertEqual(
            try sqliteScalar(at: storeURL, sql: "SELECT COUNT(*) FROM ZHUMANHEALTHREPORT"),
            1
        )
        XCTAssertEqual(
            try sqliteScalar(at: storeURL, sql: "SELECT COUNT(*) FROM ZHUMANHEALTHMETRICLOG"),
            1
        )
        XCTAssertEqual(
            try sqliteScalar(
                at: storeURL,
                sql: "SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'HumanHealthReport'"
            ),
            1
        )
        XCTAssertEqual(
            try sqliteScalar(
                at: storeURL,
                sql: "SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'HumanHealthMetricLog'"
            ),
            1
        )
        XCTAssertEqual(
            try sqliteScalar(
                at: storeURL,
                sql: "SELECT COUNT(*) FROM pragma_table_info('ZHUMANHEALTHREPORT') "
                    + "WHERE name IN ('ZRECORDEDBYHUMANID', 'ZCAPTURESOURCERAW')"
            ),
            0
        )
        XCTAssertEqual(
            try sqliteScalar(
                at: storeURL,
                sql: "SELECT COUNT(*) FROM pragma_table_info('ZHUMANHEALTHMETRICLOG') "
                    + "WHERE name IN ('ZRECORDEDBYHUMANID', 'ZSOURCEREPORTID', 'ZSOURCELABEL', "
                    + "'ZREFERENCELOW', 'ZREFERENCEHIGH', 'ZREFERENCERANGETEXT', 'ZREPORTEDFLAGRAW')"
            ),
            0
        )

        let scanReportID = UUID()
        let scanMetricID = UUID()
        let recordedAt = Date(timeIntervalSince1970: 1_901_000_000)
        let schema = Schema(ArkSchemaV99.models)

        do {
            let configuration = ModelConfiguration(
                "RealV90HealthRowsToV99Migration",
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
            let human = try assertMigratedV90HealthRows(context: context)

            let report = HumanHealthReport(
                id: scanReportID,
                humanId: human.id.uuidString,
                reportType: .bloodTest,
                conclusion: .attention,
                reportDate: recordedAt,
                recordedByHumanId: human.id.uuidString,
                captureSource: .documentScan
            )
            let metric = HumanHealthMetricLog(
                id: scanMetricID,
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: 4.8,
                date: recordedAt,
                recordedByHumanId: human.id.uuidString,
                sourceReportID: scanReportID,
                sourceLabel: "TSH",
                referenceLow: 0.4,
                referenceHigh: 4.0,
                referenceRangeText: "0.4–4.0",
                reportedFlag: .high,
                human: human
            )
            context.insert(report)
            context.insert(metric)
            try context.save()
        }

        do {
            let configuration = ModelConfiguration(
                "RealV90HealthRowsToV99Migration",
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
            let human = try assertMigratedV90HealthRows(context: context)
            var reportDescriptor = FetchDescriptor<HumanHealthReport>(
                predicate: #Predicate<HumanHealthReport> { $0.id == scanReportID }
            )
            reportDescriptor.fetchLimit = 1
            var metricDescriptor = FetchDescriptor<HumanHealthMetricLog>(
                predicate: #Predicate<HumanHealthMetricLog> { $0.id == scanMetricID }
            )
            metricDescriptor.fetchLimit = 1
            let scanReport = try XCTUnwrap(context.fetch(reportDescriptor).first)
            let scanMetric = try XCTUnwrap(context.fetch(metricDescriptor).first)

            XCTAssertEqual(scanReport.humanId, human.id.uuidString)
            XCTAssertEqual(scanReport.reportType, .bloodTest)
            XCTAssertEqual(scanReport.conclusion, .attention)
            XCTAssertEqual(scanReport.reportDate, recordedAt)
            XCTAssertEqual(scanReport.recordedByHumanId, human.id.uuidString)
            XCTAssertEqual(scanReport.captureSource, .documentScan)
            XCTAssertEqual(scanMetric.human?.id, human.id)
            XCTAssertEqual(scanMetric.value, 4.8)
            XCTAssertEqual(scanMetric.date, recordedAt)
            XCTAssertEqual(scanMetric.recordedByHumanId, human.id.uuidString)
            XCTAssertEqual(scanMetric.sourceReportID, scanReportID)
            XCTAssertEqual(scanMetric.sourceLabel, "TSH")
            XCTAssertEqual(scanMetric.referenceLow, 0.4)
            XCTAssertEqual(scanMetric.referenceHigh, 4.0)
            XCTAssertEqual(scanMetric.reportedFlag, .high)
            XCTAssertEqual(scanMetric.referenceRangeText, "0.4–4.0")
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthReport>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()), 2)
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
    func testCurrentEventModelReopensFromV87LabeledContainerWithEmptyTaskCareKind() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaEventCurrentModelReopenTests-\(UUID().uuidString)", isDirectory: true)
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
            let schema = Schema(ArkSchemaV99.models)
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
    func testCurrentReminderModelReopensFromV88LabeledContainerWithOccurrenceFallback() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaReminderCurrentModelReopenTests-\(UUID().uuidString)", isDirectory: true)
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
            let schema = Schema(ArkSchemaV99.models)
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

    @MainActor
    func testRealV90ExpenseMigratesToV99WithLegacyPayerFallback() throws {
        let fixtureURL = try v90FixtureStoreURL()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaRealV90ExpenseToV99MigrationTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("default.store")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)

        let expenseID = try XCTUnwrap(UUID(uuidString: "E87E9A6B-90B4-4B84-AEF3-000000000090"))
        let payerID = try XCTUnwrap(UUID(uuidString: "58B6F77F-1913-4951-BBBF-C08B56858D97"))
        try sqliteExecute(
            at: storeURL,
            sql: """
            BEGIN IMMEDIATE;
            INSERT INTO ZPETEXPENSELOG (
                Z_PK, Z_ENT, Z_OPT, ZAMOUNT, ZDATE, ZCATEGORY, ZEXECUTORID, ZNOTE,
                ZSHAREDSESSIONID, ZTRASHBATCHID, ZTRASHEDBYHUMANID, ZID
            ) VALUES (
                1, 30, 1, 125.5, 805807800, '医疗', '\(payerID.uuidString)',
                'Legacy split migration proof', '', '', '', X'E87E9A6B90B44B84AEF3000000000090'
            );
            UPDATE Z_PRIMARYKEY SET Z_MAX = 1 WHERE Z_NAME = 'PetExpenseLog';
            COMMIT;
            """
        )

        XCTAssertEqual(
            try sqliteScalar(
                at: storeURL,
                sql: "SELECT COUNT(*) FROM pragma_table_info('ZPETEXPENSELOG') "
                    + "WHERE name = 'ZPAYERCONTRIBUTIONSJSON'"
            ),
            0
        )

        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(
            "RealV90ExpenseToV99Migration",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ArkMigrationPlan.self,
            configurations: [configuration]
        )
        var descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { $0.id == expenseID }
        )
        descriptor.fetchLimit = 1
        let migrated = try XCTUnwrap(container.mainContext.fetch(descriptor).first)

        XCTAssertEqual(migrated.amount, 125.5, accuracy: 0.000_001)
        XCTAssertEqual(migrated.executorId, payerID.uuidString)
        XCTAssertNil(migrated.recordedByHumanId)
        XCTAssertEqual(migrated.payerContributionsJSON, "")
        XCTAssertEqual(
            migrated.payerContributions,
            [ExpensePayerContribution(humanID: payerID, minorUnits: 12550)]
        )
        XCTAssertEqual(migrated.amountPaid(by: payerID.uuidString), 125.5, accuracy: 0.000_001)
    }
}

private extension SharedModelContainerRecoveryTests {
    func v90FixtureStoreURL() throws -> URL {
        try migrationFixtureStoreURL(
            directoryName: "ArkSchemaV90",
            expectedHealthReportCount: 0
        )
    }

    func v90HealthRowsFixtureStoreURL() throws -> URL {
        try migrationFixtureStoreURL(
            directoryName: "ArkSchemaV90HealthRows",
            storeFileName: "ark-schema-v90-health-rows.store",
            expectedHealthReportCount: 1
        )
    }

    func migrationFixtureStoreURL(
        directoryName: String,
        storeFileName: String = "default.store",
        expectedHealthReportCount: Int64
    ) throws -> URL {
        let bundle = Bundle(for: SharedModelContainerRecoveryTests.self)
        let resourceURL = URL(fileURLWithPath: storeFileName)
        if let nestedURL = bundle.url(
            forResource: resourceURL.deletingPathExtension().lastPathComponent,
            withExtension: resourceURL.pathExtension,
            subdirectory: "Fixtures/\(directoryName)"
        ) {
            return nestedURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: bundle.bundleURL,
            includingPropertiesForKeys: nil
        ) else {
            throw migrationFixtureError("Unable to enumerate the OhanaTests bundle for the \(directoryName) fixture.")
        }
        var storeCandidates: [URL] = []
        for case let candidate as URL in enumerator where candidate.lastPathComponent == storeFileName {
            if candidate.deletingLastPathComponent().lastPathComponent == directoryName {
                return candidate
            }
            storeCandidates.append(candidate)
        }
        for candidate in storeCandidates {
            let healthReportCount = try? sqliteScalar(
                at: candidate,
                sql: "SELECT COUNT(*) FROM ZHUMANHEALTHREPORT"
            )
            if healthReportCount == expectedHealthReportCount {
                return candidate
            }
        }
        throw migrationFixtureError("Missing Fixtures/\(directoryName)/\(storeFileName) in the OhanaTests bundle.")
    }

    @MainActor
    func assertMigratedV90HealthRows(context: ModelContext) throws -> Human {
        let humanID = try XCTUnwrap(UUID(uuidString: "58B6F77F-1913-4951-BBBF-C08B56858D97"))
        let reportID = try XCTUnwrap(UUID(uuidString: "977E9A6B-90B4-4B84-AEF3-000000000090"))
        let metricID = try XCTUnwrap(UUID(uuidString: "987E9A6B-90B4-4B84-AEF3-000000000090"))
        var humanDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.id == humanID }
        )
        humanDescriptor.fetchLimit = 1
        var reportDescriptor = FetchDescriptor<HumanHealthReport>(
            predicate: #Predicate<HumanHealthReport> { $0.id == reportID }
        )
        reportDescriptor.fetchLimit = 1
        var metricDescriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { $0.id == metricID }
        )
        metricDescriptor.fetchLimit = 1

        let human = try XCTUnwrap(context.fetch(humanDescriptor).first)
        let report = try XCTUnwrap(context.fetch(reportDescriptor).first)
        let metric = try XCTUnwrap(context.fetch(metricDescriptor).first)

        XCTAssertEqual(human.name, "FixtureHuman")
        XCTAssertEqual(report.humanId, human.id.uuidString)
        XCTAssertEqual(report.reportType, .bloodTest)
        XCTAssertEqual(report.conclusion, .attention)
        XCTAssertEqual(report.hospitalName, "Legacy General Hospital")
        XCTAssertEqual(report.doctorName, "Dr. Ada Legacy")
        XCTAssertEqual(report.reportDate.timeIntervalSinceReferenceDate, 805_807_800, accuracy: 0.001)
        XCTAssertEqual(
            try XCTUnwrap(report.nextCheckDate).timeIntervalSinceReferenceDate,
            806_412_600,
            accuracy: 0.001
        )
        XCTAssertEqual(report.summary, "Legacy thyroid follow-up")
        XCTAssertEqual(report.notes, "V90 report row must survive migration.")
        XCTAssertEqual(report.colorHex, "123ABC")
        XCTAssertEqual(report.createdAt.timeIntervalSinceReferenceDate, 805_807_820, accuracy: 0.001)
        XCTAssertNil(report.recordedByHumanId)
        XCTAssertEqual(report.captureSourceRaw, HumanHealthReportCaptureSource.manual.rawValue)
        XCTAssertEqual(report.captureSource, .manual)

        XCTAssertEqual(metric.human?.id, human.id)
        XCTAssertEqual(metric.metricKey, "tsh")
        XCTAssertEqual(metric.unitCode, "mIU_L")
        XCTAssertEqual(metric.value, 3.75, accuracy: 0.000_001)
        XCTAssertEqual(metric.date.timeIntervalSinceReferenceDate, 805_807_800, accuracy: 0.001)
        XCTAssertEqual(metric.notes, "V90 metric row must survive migration.")
        XCTAssertEqual(metric.createdAt.timeIntervalSinceReferenceDate, 805_807_830, accuracy: 0.001)
        XCTAssertNil(metric.recordedByHumanId)
        XCTAssertNil(metric.sourceReportID)
        XCTAssertEqual(metric.sourceLabel, "")
        XCTAssertNil(metric.referenceLow)
        XCTAssertNil(metric.referenceHigh)
        XCTAssertEqual(metric.referenceRangeText, "")
        XCTAssertEqual(metric.reportedFlagRaw, HumanHealthMetricReportedFlag.unknown.rawValue)
        XCTAssertEqual(metric.reportedFlag, .unknown)
        return human
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

    func sqliteExecute(at storeURL: URL, sql: String) throws {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite open error"
            if let database {
                sqlite3_close(database)
            }
            throw migrationFixtureError("Unable to open a writable V90 fixture copy: \(message)")
        }
        defer { sqlite3_close(database) }

        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) }
                ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw migrationFixtureError("Unable to seed the V90 fixture copy: \(message)")
        }
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
    case backupExclusionRejected
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
