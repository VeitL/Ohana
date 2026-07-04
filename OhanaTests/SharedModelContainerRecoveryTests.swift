import SwiftData
import XCTest
@testable import Ohana

final class SharedModelContainerRecoveryTests: XCTestCase {
    func testDiskAndMemoryFallbackStoresKeepFallbackIndicatorActive() {
        XCTAssertFalse(SharedModelContainer.fallbackIndicatorIsActive(for: .primaryWithMigrationPlan))
        XCTAssertFalse(SharedModelContainer.fallbackIndicatorIsActive(for: .defaultStoreWithoutMigrationPlan))
        XCTAssertTrue(SharedModelContainer.fallbackIndicatorIsActive(for: .diskFallback))
        XCTAssertTrue(SharedModelContainer.fallbackIndicatorIsActive(for: .memoryFallback))
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
        XCTAssertEqual(ObjectIdentifier(ArkMigrationPlan.schemas.last!), ObjectIdentifier(ArkSchemaV82.self))
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
            let schema = Schema(ArkSchemaV82.models)
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
}

private enum ArkSchemaV67OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV67.self] }
    static var stages: [MigrationStage] { [] }
}
