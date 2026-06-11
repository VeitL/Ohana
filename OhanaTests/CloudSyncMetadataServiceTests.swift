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
    @Test func mutationRecorderCreatesDefaultHouseholdZoneForNewPet() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let pet = Pet(name: "Momo")
        pet.id = uuid("99999999-9999-4999-8999-999999999999")
        let modifiedAt = Date(timeIntervalSinceReferenceDate: 90)
        context.insert(pet)

        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: modifiedAt)

        let household = try #require(try context.fetch(FetchDescriptor<Household>()).first)
        let petState = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            localRecordId: pet.id,
            context: context
        ))
        let householdState = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Household.self),
            localRecordId: household.id,
            context: context
        ))

        #expect(petState.householdId == normalized(household.id))
        #expect(petState.hasPendingLocalChanges)
        #expect(householdState.householdId == normalized(household.id))
        #expect(householdState.hasPendingLocalChanges)
    }

    @MainActor
    @Test func careEventServiceMarksPetCareLogDirty() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let pet = Pet(name: "Momo")
        pet.id = uuid("99999999-9999-4999-8999-999999999999")
        let recordedAt = Date(timeIntervalSinceReferenceDate: 91)
        context.insert(household)
        context.insert(pet)

        let log = CareEventService.recordTreatFeed(
            pet: pet,
            amountGrams: 6,
            context: context,
            executorId: nil,
            date: recordedAt
        )

        let state = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: PetCareLog.self),
            localRecordId: log.id,
            context: context
        ))
        #expect(state.householdId == normalized(household.id))
        #expect(state.conflictPolicy == .appendOnly)
        #expect(state.lastModifiedAt == recordedAt)
        #expect(state.hasPendingLocalChanges)
    }

    @MainActor
    @Test func coconutWalletServiceMarksLedgerEntriesDirty() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let human = Human(name: "Avery")
        human.id = uuid("22222222-2222-4222-8222-222222222222")
        context.insert(household)
        context.insert(human)
        let occurredAt = Date(timeIntervalSinceReferenceDate: 92)

        let entries = try CoconutWalletService.apply(
            deltas: [
                .human(
                    human,
                    delta: 7,
                    entryKind: .reward,
                    source: .service,
                    title: "Sync test reward",
                    occurredAt: occurredAt,
                    transactionKey: "cloud-sync:test:ledger"
                )
            ],
            context: context,
            save: true,
            postsRewardFeedback: false,
            updatesProjection: false
        )
        let entry = try #require(entries.first)
        let state = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: CoconutLedgerEntry.self),
            localRecordId: entry.id,
            context: context
        ))

        #expect(state.householdId == normalized(household.id))
        #expect(state.conflictPolicy == .appendOnly)
        #expect(state.lastModifiedAt == occurredAt)
        #expect(state.hasPendingLocalChanges)
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
    @Test func recordSerializerBuildsPetScopedCareLogPayloads() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let pet = Pet(name: "Momo")
        pet.id = uuid("33333333-3333-4333-8333-333333333333")
        let executorId = normalized(uuid("44444444-4444-4444-8444-444444444444"))

        let pottyLog = PetPottyLog(
            date: Date(timeIntervalSinceReferenceDate: 80),
            type: .pee,
            pet: pet,
            executorId: executorId,
            latitude: 1.25,
            longitude: 2.5,
            locationAccuracyMeters: 3,
            walkLogId: "walk-1",
            sharedSessionId: "session-1"
        )
        pottyLog.id = uuid("55555555-5555-4555-8555-555555555555")
        let pottyState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: PetPottyLog.self),
            localRecordId: pottyLog.id,
            householdId: householdId,
            context: context
        )
        let pottyPayload = try CloudSyncRecordSerializer.payload(for: pottyLog, state: pottyState)

        #expect(pottyPayload.entityName == "PetPottyLog")
        #expect(pottyPayload.fields["petId"]?.stringValue == normalized(pet.id))
        #expect(pottyPayload.fields["executorId"]?.stringValue == executorId)
        #expect(pottyPayload.fields["latitude"] == .double(1.25))
        #expect(pottyPayload.fields["sharedSessionId"]?.stringValue == "session-1")

        let walkLog = PetWalkLog(
            startDate: Date(timeIntervalSinceReferenceDate: 90),
            pet: pet,
            executorId: executorId,
            sharedSessionId: "session-2"
        )
        walkLog.id = uuid("66666666-6666-4666-8666-666666666666")
        walkLog.endDate = Date(timeIntervalSinceReferenceDate: 120)
        walkLog.distanceMeters = 123.4
        walkLog.coconutsEarned = 9
        walkLog.behaviorNotes = "calm walk"
        walkLog.moodRating = 4
        walkLog.routeLocationsData = Data([1, 2, 3])
        let walkState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: PetWalkLog.self),
            localRecordId: walkLog.id,
            householdId: householdId,
            context: context
        )
        let walkPayload = try CloudSyncRecordSerializer.payload(for: walkLog, state: walkState)

        #expect(walkPayload.entityName == "PetWalkLog")
        #expect(walkPayload.fields["distanceMeters"] == .double(123.4))
        #expect(walkPayload.fields["coconutsEarned"]?.intValue == 9)
        #expect(walkPayload.fields["behaviorNotes"]?.stringValue == "calm walk")
        #expect(walkPayload.fields["routeLocationsData"] == .assetData(Data([1, 2, 3])))
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
    @Test func assetFileStoreWritesUploadDataToTemporaryFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaCloudSyncAssetFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = CloudSyncAssetFileStore(directoryURL: directoryURL)
        let data = Data([9, 8, 7])

        let fileURL = try store.assetFileURLProvider()("avatar image", data)

        #expect(fileURL.deletingLastPathComponent() == directoryURL)
        #expect(fileURL.lastPathComponent.hasPrefix("avatar-image-"))
        #expect(try Data(contentsOf: fileURL) == data)
    }

    @MainActor
    @Test func engineBatchBuilderUsesAssetFileProviderForCKAssets() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaCloudSyncAssetBatchTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = CloudSyncAssetFileStore(directoryURL: directoryURL)
        let data = Data([1, 2, 3])
        let payload = makeRecordPayload(
            entityName: String(describing: Pet.self),
            recordType: String(describing: Pet.self),
            localRecordId: uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["avatarImageData": .assetData(data)]
        )

        let batch = try #require(try CloudSyncEngineBatchBuilder.recordZoneChangeBatch(
            for: [payload],
            assetFileURLProvider: store.assetFileURLProvider()
        ))
        let record = try #require(batch.recordsToSave.first)
        let asset = try #require(record["avatarImageData"] as? CKAsset)
        let fileURL = try #require(asset.fileURL)

        #expect(try Data(contentsOf: fileURL) == data)
    }

    @MainActor
    @Test func assetFileStorePrunesOldFilesOnly() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaCloudSyncAssetPruneTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = CloudSyncAssetFileStore(directoryURL: directoryURL)
        let oldURL = try store.fileURL(fieldName: "old", data: Data([1]))
        let recentURL = try store.fileURL(fieldName: "recent", data: Data([2]))
        let oldDate = Date(timeIntervalSinceReferenceDate: 10)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldURL.path)

        store.pruneFiles(olderThan: Date(timeIntervalSinceReferenceDate: 20))

        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
        #expect(FileManager.default.fileExists(atPath: recentURL.path))
    }

    @MainActor
    @Test func householdShareServicePreparesZoneWideShare() {
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let service = CloudSyncHouseholdShareService()

        let preparation = service.prepareZoneWideShare(
            householdId: householdId,
            householdName: "Shared Home"
        )

        #expect(preparation.zoneID.zoneName == "household-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        #expect(preparation.shareRecordID.recordName == CKRecordNameZoneWideShare)
        #expect(preparation.shareRecordID.zoneID.zoneName == preparation.zoneID.zoneName)
        #expect(preparation.title == "Shared Home")
        #expect(preparation.shareType == CloudSyncShareRuntime.shareType)
    }

    @MainActor
    @Test func householdShareServiceUsesFallbackTitleForBlankName() {
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let service = CloudSyncHouseholdShareService()

        let preparation = service.prepareZoneWideShare(
            householdId: householdId,
            householdName: "   "
        )

        #expect(preparation.title == CloudSyncShareRuntime.fallbackTitle)
    }

    @MainActor
    @Test func householdShareStateUpdaterStoresZoneWideShareName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let household = Household(name: "Shared Home")
        household.id = householdId
        context.insert(household)
        let shareRecordName = CloudSyncHouseholdShareService()
            .prepareZoneWideShare(householdId: householdId, householdName: household.name)
            .shareRecordID
            .recordName

        let didUpdate = try CloudSyncHouseholdShareStateUpdater.markSharePrepared(
            householdId: householdId,
            shareRecordName: shareRecordName,
            context: context
        )

        #expect(didUpdate)
        #expect(household.ckShareRecordName == CKRecordNameZoneWideShare)
    }

    @MainActor
    @Test func pendingChangeBuilderCreatesOneZoneSavePerDirtyZone() {
        let householdZonePayload = makeRecordPayload(
            localRecordId: uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["name": .string("Home")]
        )
        let petPayload = makeRecordPayload(
            entityName: String(describing: Pet.self),
            recordType: String(describing: Pet.self),
            localRecordId: uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["name": .string("Momo")]
        )
        let secondHouseholdPayload = makeRecordPayload(
            localRecordId: uuid("ffffffff-ffff-4fff-8fff-ffffffffffff"),
            householdId: uuid("dddddddd-dddd-4ddd-8ddd-dddddddddddd"),
            fields: ["name": .string("Second Home")]
        )

        let changes = CloudSyncEnginePendingChangeBuilder.pendingDatabaseChanges(
            for: [householdZonePayload, petPayload, secondHouseholdPayload]
        )

        #expect(changes.count == 2)
        guard case let .saveZone(firstZone) = changes[0],
              case let .saveZone(secondZone) = changes[1] else {
            Issue.record("Expected custom CloudKit zones to be registered before record uploads")
            return
        }
        #expect(firstZone.zoneID.zoneName == "household-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        #expect(secondZone.zoneID.zoneName == "household-dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    }

    @MainActor
    @Test func engineDelegateAdapterBuildsBatchThroughUploadProvider() async throws {
        let firstPayload = makeRecordPayload(
            localRecordId: uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["name": .string("First")]
        )
        let secondPayload = makeRecordPayload(
            localRecordId: uuid("ffffffff-ffff-4fff-8fff-ffffffffffff"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["name": .string("Second")]
        )
        let runtime = CloudSyncEngineDelegateAdapter(
            uploadPayloadProvider: StaticCloudSyncUploadPayloadProvider(payloads: [firstPayload, secondPayload])
        )

        let batch = try #require(await runtime.recordZoneChangeBatch(
            sendScope: .recordIDs([CloudSyncEngineBatchBuilder.recordID(for: secondPayload)])
        ))

        #expect(batch.recordsToSave.count == 1)
        #expect(batch.recordsToSave.first?.recordID.recordName == secondPayload.recordName)
        #expect(batch.recordIDsToDelete.isEmpty)
    }

    @MainActor
    @Test func localStoreActorBuildsDirtyPayloadsFromSwiftData() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        context.insert(household)
        _ = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Household.self),
            localRecordId: household.id,
            householdId: household.id,
            context: context
        )
        try context.save()

        let actor = CloudSyncLocalStoreActor(modelContainer: container)
        let payloads = try await actor.uploadPayloads()

        #expect(payloads.count == 1)
        #expect(payloads.first?.recordName == "Household_aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        #expect(payloads.first?.fields["name"]?.stringValue == "Shared Home")
    }

    @MainActor
    @Test func sentRecordStateUpdaterMarksSavedRecordSynced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        context.insert(household)

        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Household.self),
            localRecordId: household.id,
            householdId: household.id,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 10),
            context: context
        )
        let payload = try CloudSyncRecordSerializer.payload(for: household, state: state)
        let record = try payload.makeCKRecord()
        let syncedAt = Date(timeIntervalSinceReferenceDate: 20)

        let updatedCount = try CloudSyncSentRecordStateUpdater.markSavedRecords(
            [record],
            syncedAt: syncedAt,
            context: context
        )

        #expect(updatedCount == 1)
        #expect(!state.hasPendingLocalChanges)
        #expect(state.ckRecordName == payload.recordName)
        #expect(state.ckZoneName == payload.zoneName)
        #expect(state.ckChangeTag.isEmpty)
        #expect(state.lastSyncedAt == syncedAt)
    }

    @MainActor
    @Test func sentRecordStateUpdaterIgnoresRecordsWithoutLocalSyncState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let zoneID = CKRecordZone.ID(zoneName: "household-unknown", ownerName: CKCurrentUserDefaultName)
        let unknownRecord = CKRecord(
            recordType: String(describing: Household.self),
            recordID: CKRecord.ID(recordName: "Household_unknown", zoneID: zoneID)
        )
        unknownRecord[CloudSyncRecordFieldKey.recordKey] = "Household:unknown" as CKRecordValue

        let updatedCount = try CloudSyncSentRecordStateUpdater.markSavedRecords(
            [unknownRecord],
            context: context
        )

        #expect(updatedCount == 0)
    }

    @MainActor
    @Test func localStoreActorMarksSavedRecordSynced() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        context.insert(household)

        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Household.self),
            localRecordId: household.id,
            householdId: household.id,
            context: context
        )
        let payload = try CloudSyncRecordSerializer.payload(for: household, state: state)
        let record = try payload.makeCKRecord()
        try context.save()

        let actor = CloudSyncLocalStoreActor(modelContainer: container)
        try await actor.markSavedRecords([record])

        let verificationContext = ModelContext(container)
        let savedState = try #require(try CloudSyncMetadataService.state(
            recordKey: state.recordKey,
            context: verificationContext
        ))
        #expect(!savedState.hasPendingLocalChanges)
        #expect(savedState.ckRecordName == payload.recordName)
        #expect(savedState.ckZoneName == payload.zoneName)
    }

    @MainActor
    @Test func recordApplierInsertsRemoteHouseholdAndMarksSynced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let remoteModifiedAt = Date(timeIntervalSinceReferenceDate: 1000)
        let record = try makeRecordPayload(
            localRecordId: householdId,
            householdId: householdId,
            lastModifiedAt: remoteModifiedAt,
            fields: [
                "name": .string("Remote Home"),
                "createdAt": .date(Date(timeIntervalSinceReferenceDate: 900)),
                "totalProsperity": .int(12)
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .inserted(entityName: "Household", localRecordId: normalized(householdId)))
        let household = try #require(try fetchHousehold(id: householdId, context: context))
        #expect(household.name == "Remote Home")
        #expect(household.totalProsperity == 12)

        let state = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Household.self),
            localRecordId: householdId,
            context: context
        ))
        #expect(!state.hasPendingLocalChanges)
        #expect(state.lastModifiedAt == remoteModifiedAt)
        #expect(state.ckRecordName == "Household_aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    }

    @MainActor
    @Test func recordApplierMergesProsperityCounterWithMax() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let household = Household(name: "Local Home")
        household.id = householdId
        household.totalProsperity = 20
        context.insert(household)

        let record = try makeRecordPayload(
            localRecordId: householdId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 2000),
            fields: [
                "name": .string("Remote Home"),
                "totalProsperity": .int(4)
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .updated(entityName: "Household", localRecordId: normalized(householdId)))
        #expect(household.name == "Remote Home")
        #expect(household.totalProsperity == 20)
    }

    @MainActor
    @Test func recordApplierInsertsRemotePetScopedCareFacts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let petId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let pet = Pet(name: "Momo")
        pet.id = petId
        context.insert(pet)

        let pottyId = uuid("11111111-1111-4111-8111-111111111111")
        let pottyDate = Date(timeIntervalSinceReferenceDate: 2100)
        let pottyRecord = try makeRecordPayload(
            entityName: String(describing: PetPottyLog.self),
            recordType: String(describing: PetPottyLog.self),
            localRecordId: pottyId,
            householdId: householdId,
            fields: [
                "date": .date(pottyDate),
                "type": .string(PottyType.pee.rawValue),
                "petId": .string(normalized(petId)),
                "executorId": .string("executor-1"),
                "latitude": .double(1.25),
                "longitude": .double(2.5),
                "walkLogId": .string("walk-1")
            ]
        ).makeCKRecord()

        let pottyResult = try CloudSyncRecordApplier.apply(pottyRecord, context: context)

        #expect(pottyResult == .inserted(entityName: "PetPottyLog", localRecordId: normalized(pottyId)))
        let pottyLog = try #require(try fetchPetPottyLog(id: pottyId, context: context))
        #expect(pottyLog.pet?.id == petId)
        #expect(pottyLog.type == PottyType.pee.rawValue)
        #expect(pottyLog.latitude == 1.25)
        #expect(pottyLog.walkLogId == "walk-1")

        let walkId = uuid("22222222-2222-4222-8222-222222222222")
        let walkRecord = try makeRecordPayload(
            entityName: String(describing: PetWalkLog.self),
            recordType: String(describing: PetWalkLog.self),
            localRecordId: walkId,
            householdId: householdId,
            fields: [
                "startDate": .date(Date(timeIntervalSinceReferenceDate: 2200)),
                "endDate": .date(Date(timeIntervalSinceReferenceDate: 2300)),
                "distanceMeters": .double(456.7),
                "coconutsEarned": .int(11),
                "petId": .string(normalized(petId)),
                "executorId": .string("executor-2"),
                "sharedSessionId": .string("session-2"),
                "behaviorNotes": .string("happy"),
                "moodRating": .int(5)
            ]
        ).makeCKRecord()

        let walkResult = try CloudSyncRecordApplier.apply(walkRecord, context: context)

        #expect(walkResult == .inserted(entityName: "PetWalkLog", localRecordId: normalized(walkId)))
        let walkLog = try #require(try fetchPetWalkLog(id: walkId, context: context))
        #expect(walkLog.pet?.id == petId)
        #expect(walkLog.distanceMeters == 456.7)
        #expect(walkLog.coconutsEarned == 11)
        #expect(walkLog.sharedSessionId == "session-2")
        #expect(walkLog.behaviorNotes == "happy")
        #expect(walkLog.moodRating == 5)
    }

    @MainActor
    @Test func recordApplierSkipsStaleRemoteMutableRecord() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let petId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let pet = Pet(name: "Local Momo")
        pet.id = petId
        context.insert(pet)
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 3000),
            context: context
        )
        let record = try makeRecordPayload(
            entityName: String(describing: Pet.self),
            recordType: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 2000),
            fields: ["name": .string("Remote Momo")]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .skippedStale(entityName: "Pet", localRecordId: normalized(petId)))
        #expect(pet.name == "Local Momo")
        #expect(state.hasPendingLocalChanges)
    }

    @MainActor
    @Test func recordApplierDoesNotApplyLedgerProjectionBalanceFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let humanId = uuid("22222222-2222-4222-8222-222222222222")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let human = Human(name: "Local Avery")
        human.id = humanId
        human.coconutBalance = 99
        context.insert(human)
        let record = try makeRecordPayload(
            entityName: String(describing: Human.self),
            recordType: String(describing: Human.self),
            localRecordId: humanId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 2000),
            fields: [
                "name": .string("Remote Avery"),
                "coconutBalance": .int(1)
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .updated(entityName: "Human", localRecordId: normalized(humanId)))
        #expect(human.name == "Remote Avery")
        #expect(human.coconutBalance == 99)
    }

    @MainActor
    @Test func recordApplierAppliesRemoteTombstoneAndKeepsSyncState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let petId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4000)
        let pet = Pet(name: "Momo")
        pet.id = petId
        context.insert(pet)
        let record = try makeRecordPayload(
            entityName: String(describing: Pet.self),
            recordType: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [
                CloudSyncRecordFieldKey.deletedAt: .date(deletedAt),
                CloudSyncRecordFieldKey.deletedByHumanId: .string(normalized(uuid("33333333-3333-4333-8333-333333333333")))
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "Pet", localRecordId: normalized(petId)))
        #expect(try fetchPet(id: petId, context: context) == nil)
        let state = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            context: context
        ))
        #expect(state.isDeleted)
        #expect(!state.hasPendingLocalChanges)
        #expect(state.deletedAt == deletedAt)
    }

    @MainActor
    @Test func localStoreActorAppliesFetchedRecordsThroughRecordApplier() async throws {
        let container = try makeContainer()
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let record = try makeRecordPayload(
            localRecordId: householdId,
            householdId: householdId,
            fields: ["name": .string("Actor Home")]
        ).makeCKRecord()

        let actor = CloudSyncLocalStoreActor(modelContainer: container)
        let summary = try await actor.applyFetchedRecords([record])

        #expect(summary.inserted == 1)
        let verificationContext = ModelContext(container)
        let household = try #require(try fetchHousehold(id: householdId, context: verificationContext))
        #expect(household.name == "Actor Home")
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
        lastModifiedAt: Date = Date(timeIntervalSinceReferenceDate: 500),
        fields: [String: CloudSyncRecordFieldValue] = [:]
    ) -> CloudSyncRecordPayload {
        let localRecordId = normalized(localRecordId)
        let householdId = normalized(householdId)
        let normalizedEntityName = CloudSyncRecordState.normalizedEntityName(entityName)
        var fields = fields
        fields[CloudSyncRecordFieldKey.recordKey] = .string(
            CloudSyncRecordState.recordKey(entityName: normalizedEntityName, localRecordId: localRecordId)
        )
        fields[CloudSyncRecordFieldKey.entityName] = .string(normalizedEntityName)
        fields[CloudSyncRecordFieldKey.localRecordId] = .string(localRecordId)
        fields[CloudSyncRecordFieldKey.householdId] = .string(householdId)
        fields[CloudSyncRecordFieldKey.isDeleted] = .bool(isDeleted)
        fields[CloudSyncRecordFieldKey.lastModifiedAt] = .date(lastModifiedAt)
        fields[CloudSyncRecordFieldKey.conflictPolicy] = .string(
            CloudSyncMergePolicy.defaultConflictPolicy(for: normalizedEntityName).rawValue
        )
        return CloudSyncRecordPayload(
            entityName: normalizedEntityName,
            recordType: recordType,
            recordName: CloudSyncZoneNaming.recordName(entityName: normalizedEntityName, localRecordId: localRecordId),
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

    private func fetchHousehold(id: UUID, context: ModelContext) throws -> Household? {
        var descriptor = FetchDescriptor<Household>(
            predicate: #Predicate<Household> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPetPottyLog(id: UUID, context: ModelContext) throws -> PetPottyLog? {
        var descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPetWalkLog(id: UUID, context: ModelContext) throws -> PetWalkLog? {
        var descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

private struct StaticCloudSyncUploadPayloadProvider: CloudSyncEngineUploadPayloadProviding {
    let payloads: [CloudSyncRecordPayload]

    func uploadPayloads() async throws -> [CloudSyncRecordPayload] {
        payloads
    }
}
