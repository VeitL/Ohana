import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Ohana

struct CloudSyncMetadataServiceTests {
    @MainActor
    @Test func markModifiedUpsertsDirtyState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let petId = UUID()
        let householdId = UUID()
        let firstDate = Date(timeIntervalSinceReferenceDate: 100)
        let secondDate = Date(timeIntervalSinceReferenceDate: 200)

        let first = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            modifiedAt: firstDate,
            context: context
        )
        let second = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            modifiedAt: secondDate,
            metadataJSON: #"{"field":"name"}"#,
            context: context
        )

        #expect(first.id == second.id)
        #expect(second.hasPendingLocalChanges)
        #expect(!second.isDeleted)
        #expect(second.lastModifiedAt == secondDate)
        #expect(second.conflictPolicy == .lastWriterWins)
        #expect(second.householdId == householdId.uuidString.lowercased())
        #expect(second.metadataJSON.contains(#""field":"name""#))
        #expect(try context.fetch(FetchDescriptor<CloudSyncRecordState>()).count == 1)
    }

    @MainActor
    @Test func markDeletedKeepsTombstoneDirtyUntilSynced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let recordId = UUID()
        let humanId = UUID()
        let deletionDate = Date(timeIntervalSinceReferenceDate: 300)

        let tombstone = try CloudSyncMetadataService.markDeleted(
            entityName: String(describing: PetCareLog.self),
            localRecordId: recordId,
            deletedAt: deletionDate,
            deletedByHumanId: humanId,
            context: context
        )

        #expect(tombstone.isDeleted)
        #expect(tombstone.deletedAt == deletionDate)
        #expect(tombstone.deletedByHumanId == humanId.uuidString.lowercased())
        #expect(tombstone.hasPendingLocalChanges)
        #expect(tombstone.conflictPolicy == .appendOnly)

        CloudSyncMetadataService.markSynced(
            tombstone,
            ckRecordName: tombstone.recordKey,
            ckChangeTag: "server-change-tag",
            ckZoneName: "household-zone",
            syncedAt: Date(timeIntervalSinceReferenceDate: 400)
        )

        #expect(!tombstone.hasPendingLocalChanges)
        #expect(tombstone.isDeleted)
        #expect(tombstone.ckChangeTag == "server-change-tag")
        #expect(try CloudSyncMetadataService.dirtyStates(context: context).isEmpty)
    }

    @MainActor
    @Test func mergePolicyCallsOutCountersAndLedgerProjections() {
        #expect(
            CloudSyncMergePolicy.conflictPolicy(
                entityName: String(describing: Household.self),
                fieldName: "totalProsperity"
            ) == .maxValue
        )
        #expect(
            CloudSyncMergePolicy.conflictPolicy(
                entityName: String(describing: Human.self),
                fieldName: "coconutBalance"
            ) == .ledgerProjection
        )
        #expect(
            CloudSyncMergePolicy.defaultConflictPolicy(for: String(describing: CoconutLedgerEntry.self)) == .appendOnly
        )
    }

    @MainActor
    @Test func entityRegistryCoversCurrentSwiftDataSchema() {
        let schemaNames = Set(ArkSchemaV64.models.map { String(describing: $0) })
        let descriptorNames = Set(CloudSyncEntityRegistry.descriptors.map(\.entityName))

        #expect(descriptorNames == schemaNames)
        #expect(CloudSyncEntityRegistry.descriptors.count == descriptorNames.count)
    }

    @MainActor
    @Test func entityRegistryKeepsLocalSecurityFieldsOutOfCloudPayloads() throws {
        let human = try #require(CloudSyncEntityRegistry.descriptor(for: Human.self))
        #expect(!human.shouldUploadField("appleUserIdentifier"))
        #expect(!human.shouldUploadField("pinHash"))
        #expect(!human.shouldUploadField("pinSalt"))
        #expect(!human.shouldUploadField("pinFailedAttempts"))
        #expect(!human.shouldUploadField("pinLockedUntil"))
        #expect(!human.shouldUploadField("coconutBalance"))

        let reminder = try #require(CloudSyncEntityRegistry.descriptor(for: Reminder.self))
        #expect(!reminder.shouldUploadField("notificationId"))

        let household = try #require(CloudSyncEntityRegistry.descriptor(for: Household.self))
        #expect(!household.shouldUploadField("ckShareRecordName"))

        let pet = try #require(CloudSyncEntityRegistry.descriptor(for: Pet.self))
        #expect(!pet.shouldUploadField("ckRecordName"))
        #expect(!pet.shouldUploadField("coconutBalance"))
    }

    @MainActor
    @Test func entityRegistryDoesNotUploadDerivedOrLocalMetadataRecords() throws {
        let account = try #require(CloudSyncEntityRegistry.descriptor(for: CoconutAccount.self))
        #expect(!account.uploadsToCloudKit)
        #expect(account.role == .derivedProjection)
        #expect(account.conflictPolicy(for: "balance") == .ledgerProjection)

        let syncState = try #require(CloudSyncEntityRegistry.descriptor(for: CloudSyncRecordState.self))
        #expect(!syncState.uploadsToCloudKit)
        #expect(syncState.role == .localSyncMetadata)
    }

    @MainActor
    @Test func recordSerializerBuildsDeterministicHouseholdRecord() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("11111111-1111-4111-8111-111111111111")
        household.createdAt = Date(timeIntervalSinceReferenceDate: 10)
        household.ckShareRecordName = "private-share-cache"
        household.totalProsperity = 42

        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Household.self),
            localRecordId: household.id,
            householdId: household.id,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 20),
            context: context
        )
        let payload = try CloudSyncRecordSerializer.payload(for: household, state: state)

        #expect(payload.recordType == "Household")
        #expect(payload.recordName == "Household_11111111-1111-4111-8111-111111111111")
        #expect(payload.zoneName == "household-11111111-1111-4111-8111-111111111111")
        #expect(payload.fields["name"]?.stringValue == "Shared Home")
        #expect(payload.fields["totalProsperity"]?.intValue == 42)
        #expect(payload.fields["ckShareRecordName"] == nil)
        #expect(payload.fields[CloudSyncRecordFieldKey.isDeleted]?.boolValue == false)
        #expect(payload.fields[CloudSyncRecordFieldKey.localRecordId]?.stringValue == normalized(household.id))

        let record = try payload.makeCKRecord()
        #expect(record.recordID.recordName == payload.recordName)
        #expect(record.recordID.zoneID.zoneName == payload.zoneName)
        #expect(record["name"] as? String == "Shared Home")
    }

    @MainActor
    @Test func recordSerializerFiltersSecurityAndLedgerProjectionFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Avery")
        human.id = uuid("22222222-2222-4222-8222-222222222222")
        human.appleUserIdentifier = "apple-user-private"
        human.pinHash = "hash"
        human.pinSalt = "salt"
        human.pinFailedAttempts = 3
        human.pinLockedUntil = Date(timeIntervalSinceReferenceDate: 30)
        human.coconutBalance = 999

        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Human.self),
            localRecordId: human.id,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            context: context
        )
        let payload = try CloudSyncRecordSerializer.payload(for: human, state: state)

        #expect(payload.fields["name"]?.stringValue == "Avery")
        #expect(payload.fields["appleUserIdentifier"] == nil)
        #expect(payload.fields["pinHash"] == nil)
        #expect(payload.fields["pinSalt"] == nil)
        #expect(payload.fields["pinFailedAttempts"] == nil)
        #expect(payload.fields["pinLockedUntil"] == nil)
        #expect(payload.fields["coconutBalance"] == nil)
    }

    @MainActor
    @Test func recordSerializerKeepsAppendOnlyLogReferencesLightweight() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let pet = Pet(name: "Momo")
        pet.id = uuid("33333333-3333-4333-8333-333333333333")
        let executorId = normalized(uuid("44444444-4444-4444-8444-444444444444"))
        let log = PetCareLog(
            date: Date(timeIntervalSinceReferenceDate: 40),
            type: .feeding,
            amountGrams: 25,
            note: "breakfast",
            pet: pet,
            executorId: executorId
        )
        log.id = uuid("55555555-5555-4555-8555-555555555555")

        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: PetCareLog.self),
            localRecordId: log.id,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            context: context
        )
        let payload = try CloudSyncRecordSerializer.payload(for: log, state: state)

        #expect(payload.fields["petId"]?.stringValue == normalized(pet.id))
        #expect(payload.fields["executorId"]?.stringValue == executorId)
        #expect(payload.fields["amountGrams"] == .double(25))
        #expect(payload.fields[CloudSyncRecordFieldKey.conflictPolicy]?.stringValue == CloudSyncConflictPolicy.appendOnly.rawValue)
    }

    @MainActor
    @Test func recordSerializerKeepsLedgerEntriesAsImmutableFacts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = CoconutLedgerEntry(
            id: uuid("66666666-6666-4666-8666-666666666666"),
            transactionKey: "tx-1",
            accountKey: CoconutAccountKey.human("owner-1"),
            ownerKind: .human,
            ownerId: "owner-1",
            ownerName: "Avery",
            delta: 7,
            balanceBefore: 10,
            balanceAfter: 17,
            entryKind: .reward,
            source: .careEvent,
            title: "Fed Momo",
            emoji: "coconut",
            occurredAt: Date(timeIntervalSinceReferenceDate: 60),
            createdAt: Date(timeIntervalSinceReferenceDate: 61)
        )

        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: CoconutLedgerEntry.self),
            localRecordId: entry.id,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            context: context
        )
        let payload = try CloudSyncRecordSerializer.payload(for: entry, state: state)

        #expect(payload.fields["transactionKey"]?.stringValue == "tx-1")
        #expect(payload.fields["delta"]?.intValue == 7)
        #expect(payload.fields["balanceAfter"]?.intValue == 17)
        #expect(payload.fields[CloudSyncRecordFieldKey.conflictPolicy]?.stringValue == CloudSyncConflictPolicy.appendOnly.rawValue)
    }

    @MainActor
    @Test func tombstonePayloadDoesNotRequireDeletedLocalModel() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let localRecordId = uuid("77777777-7777-4777-8777-777777777777")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let deletedByHumanId = uuid("88888888-8888-4888-8888-888888888888")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 70)

        let state = try CloudSyncMetadataService.markDeleted(
            entityName: String(describing: Pet.self),
            localRecordId: localRecordId,
            householdId: householdId,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            context: context
        )
        let payload = try CloudSyncRecordSerializer.tombstonePayload(for: state)

        #expect(payload.isDeleted)
        #expect(payload.recordName == "Pet_77777777-7777-4777-8777-777777777777")
        #expect(payload.fields["name"] == nil)
        #expect(payload.fields[CloudSyncRecordFieldKey.isDeleted]?.boolValue == true)
        #expect(payload.fields[CloudSyncRecordFieldKey.deletedAt]?.dateValue == deletedAt)
        #expect(payload.fields[CloudSyncRecordFieldKey.deletedByHumanId]?.stringValue == normalized(deletedByHumanId))
    }

    @MainActor
    @Test func recordSerializerRejectsDerivedLocalRecords() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = CoconutAccount(
            id: uuid("99999999-9999-4999-8999-999999999999"),
            accountKey: CoconutAccountKey.system(),
            ownerKind: .system,
            ownerId: "legacy",
            displayName: "Legacy",
            balance: 99
        )
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: CoconutAccount.self),
            localRecordId: account.id,
            context: context
        )

        do {
            _ = try CloudSyncRecordSerializer.payload(for: account, state: state)
            Issue.record("Expected derived CoconutAccount to be rejected by CloudKit serializer")
        } catch let CloudSyncRecordSerializationError.notUploadable(entityName) {
            #expect(entityName == String(describing: CoconutAccount.self))
        } catch {
            Issue.record("Expected notUploadable, got \(error)")
        }
    }

    @MainActor
    @Test func uploadBatchBuilderBuildsDirtyPayloadsInModifiedOrder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let pet = Pet(name: "Momo")
        pet.id = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        context.insert(household)
        context.insert(pet)

        _ = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: pet.id,
            householdId: household.id,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 200),
            context: context
        )
        _ = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Household.self),
            localRecordId: household.id,
            householdId: household.id,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 100),
            context: context
        )

        let payloads = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)

        #expect(payloads.map(\.entityName) == ["Household", "Pet"])
        #expect(payloads.map(\.recordName) == [
            "Household_aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            "Pet_bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        ])
    }

    @MainActor
    @Test func uploadBatchBuilderDoesNotFetchLocalModelForTombstone() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let deletedPetId = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")

        _ = try CloudSyncMetadataService.markDeleted(
            entityName: String(describing: Pet.self),
            localRecordId: deletedPetId,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            deletedAt: Date(timeIntervalSinceReferenceDate: 300),
            context: context
        )

        let payloads = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)

        #expect(payloads.count == 1)
        #expect(payloads.first?.recordName == "Pet_cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        #expect(payloads.first?.isDeleted == true)
    }

    @MainActor
    @Test func uploadBatchBuilderFailsWhenDirtyModelIsMissing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let missingPetId = uuid("dddddddd-dddd-4ddd-8ddd-dddddddddddd")

        _ = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: missingPetId,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            context: context
        )

        do {
            _ = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)
            Issue.record("Expected missing dirty model to fail upload batch building")
        } catch let CloudSyncUploadBatchError.missingLocalModel(entityName, localRecordId) {
            #expect(entityName == String(describing: Pet.self))
            #expect(localRecordId == normalized(missingPetId))
        } catch {
            Issue.record("Expected missingLocalModel, got \(error)")
        }
    }

    @MainActor
    @Test func engineBatchBuilderCreatesCKSyncEngineSaveBatch() throws {
        let payload = makeRecordPayload(
            localRecordId: uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["name": .string("Shared Home")]
        )

        let batch = try #require(try CloudSyncEngineBatchBuilder.recordZoneChangeBatch(
            for: [payload],
            atomicByZone: true
        ))

        #expect(batch.recordsToSave.count == 1)
        #expect(batch.recordIDsToDelete.isEmpty)
        #expect(batch.atomicByZone)

        let record = try #require(batch.recordsToSave.first)
        #expect(record.recordID.recordName == payload.recordName)
        #expect(record.recordID.zoneID.zoneName == payload.zoneName)
        #expect(record["name"] as? String == "Shared Home")

        let pendingChanges = CloudSyncEngineBatchBuilder.pendingSaveChanges(for: [payload])
        #expect(pendingChanges.count == 1)
        guard case let .saveRecord(recordID) = pendingChanges[0] else {
            Issue.record("Expected soft-delete sync payloads to be saved as CloudKit records")
            return
        }
        #expect(recordID.recordName == payload.recordName)
        #expect(recordID.zoneID.zoneName == payload.zoneName)
    }

    @MainActor
    @Test func engineBatchBuilderHonorsSendScope() throws {
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let firstPayload = makeRecordPayload(
            localRecordId: uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"),
            householdId: householdId,
            fields: ["name": .string("First")]
        )
        let secondPayload = makeRecordPayload(
            localRecordId: uuid("ffffffff-ffff-4fff-8fff-ffffffffffff"),
            householdId: householdId,
            fields: ["name": .string("Second")]
        )
        let secondRecordID = CloudSyncEngineBatchBuilder.recordID(for: secondPayload)

        let scopedBatch = try #require(try CloudSyncEngineBatchBuilder.recordZoneChangeBatch(
            for: [firstPayload, secondPayload],
            sendScope: .recordIDs([secondRecordID])
        ))

        #expect(scopedBatch.recordsToSave.count == 1)
        #expect(scopedBatch.recordsToSave.first?.recordID.recordName == secondPayload.recordName)

        let emptyBatch = try CloudSyncEngineBatchBuilder.recordZoneChangeBatch(
            for: [firstPayload],
            sendScope: .recordIDs([secondRecordID])
        )
        #expect(emptyBatch == nil)
    }

    @MainActor
    @Test func engineBatchBuilderSavesTombstonesInsteadOfDeletingRecords() throws {
        let payload = makeRecordPayload(
            entityName: String(describing: Pet.self),
            recordType: String(describing: Pet.self),
            localRecordId: uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            isDeleted: true,
            fields: [CloudSyncRecordFieldKey.isDeleted: .bool(true)]
        )

        let batch = try #require(try CloudSyncEngineBatchBuilder.recordZoneChangeBatch(for: [payload]))

        #expect(batch.recordsToSave.count == 1)
        #expect(batch.recordIDsToDelete.isEmpty)
        #expect(batch.recordsToSave.first?[CloudSyncRecordFieldKey.isDeleted] as? Bool == true)
        guard case .saveRecord = CloudSyncEngineBatchBuilder.pendingSaveChanges(for: [payload]).first else {
            Issue.record("Expected tombstone payload to stay on the save path")
            return
        }
    }

    @MainActor
    @Test func engineBatchBuilderRequiresAssetFileProvider() throws {
        let payload = makeRecordPayload(
            entityName: String(describing: Pet.self),
            recordType: String(describing: Pet.self),
            localRecordId: uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["avatarImageData": .assetData(Data([1, 2, 3]))]
        )

        do {
            _ = try CloudSyncEngineBatchBuilder.recordZoneChangeBatch(for: [payload])
            Issue.record("Expected asset payloads to require a CKAsset file provider")
        } catch let CloudSyncRecordSerializationError.missingAssetFileURL(fieldName) {
            #expect(fieldName == "avatarImageData")
        } catch {
            Issue.record("Expected missingAssetFileURL, got \(error)")
        }
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeRecordPayload(
        entityName: String = String(describing: Household.self),
        recordType: String = String(describing: Household.self),
        localRecordId: UUID,
        householdId: UUID,
        isDeleted: Bool = false,
        fields: [String: CloudSyncRecordFieldValue] = [:]
    ) -> CloudSyncRecordPayload {
        let localRecordId = normalized(localRecordId)
        let householdId = normalized(householdId)
        return CloudSyncRecordPayload(
            entityName: entityName,
            recordType: recordType,
            recordName: CloudSyncZoneNaming.recordName(entityName: entityName, localRecordId: localRecordId),
            zoneName: CloudSyncZoneNaming.zoneName(forHouseholdId: householdId),
            localRecordId: localRecordId,
            householdId: householdId,
            isDeleted: isDeleted,
            fields: fields
        )
    }

    private func uuid(_ rawValue: String) -> UUID {
        guard let value = UUID(uuidString: rawValue) else {
            Issue.record("Invalid test UUID: \(rawValue)")
            return UUID()
        }
        return value
    }

    private func normalized(_ id: UUID) -> String {
        CloudSyncRecordState.normalizedRecordId(id)
    }
}
