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
        #expect(!second.isDeletionTombstone)
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

        #expect(tombstone.isDeletionTombstone)
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
        #expect(tombstone.isDeletionTombstone)
        #expect(tombstone.ckChangeTag == "server-change-tag")
        #expect(try CloudSyncMetadataService.dirtyStates(context: context).isEmpty)
    }

    @MainActor
    @Test func metadataServiceFindsStateByCloudKitRecordIdentity() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let recordId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: recordId,
            householdId: householdId,
            context: context
        )
        CloudSyncMetadataService.markSynced(
            state,
            ckRecordName: "legacy-pet-record-name",
            ckChangeTag: "server-change-tag",
            ckZoneName: "household-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )

        let found = try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            ckRecordName: "legacy-pet-record-name",
            ckZoneName: "household-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            context: context
        )

        #expect(found?.recordKey == state.recordKey)
        #expect(try CloudSyncMetadataService.state(
            entityName: String(describing: Human.self),
            ckRecordName: "legacy-pet-record-name",
            ckZoneName: "household-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            context: context
        ) == nil)
    }

    @MainActor
    @Test func metadataServiceDeduplicatesStatesByRecordKey() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let recordId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let older = CloudSyncRecordState(
            entityName: String(describing: Pet.self),
            localRecordId: recordId,
            householdId: householdId,
            ckChangeTag: "old-tag",
            hasPendingLocalChanges: true,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 100),
            lastSyncedAt: Date(timeIntervalSinceReferenceDate: 150),
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            updatedAt: Date(timeIntervalSinceReferenceDate: 150)
        )
        let newer = CloudSyncRecordState(
            entityName: String(describing: Pet.self),
            localRecordId: recordId,
            householdId: householdId,
            ckChangeTag: "new-tag",
            hasPendingLocalChanges: true,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 300),
            lastSyncedAt: Date(timeIntervalSinceReferenceDate: 350),
            createdAt: Date(timeIntervalSinceReferenceDate: 300),
            updatedAt: Date(timeIntervalSinceReferenceDate: 350)
        )
        context.insert(older)
        context.insert(newer)

        let recordKey = older.recordKey
        let found = try CloudSyncMetadataService.state(recordKey: recordKey, context: context)
        try context.save()

        #expect(found?.id == newer.id)
        let remaining = try context.fetch(FetchDescriptor<CloudSyncRecordState>(
            predicate: #Predicate<CloudSyncRecordState> {
                $0.recordKey == recordKey
            }
        ))
        #expect(remaining.map(\.id) == [newer.id])
    }

    @MainActor
    @Test func metadataServiceDeduplicatesStatesByCloudKitRecordIdentity() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let olderRecordId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let newerRecordId = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let recordName = "legacy-pet-record-name"
        let zoneName = "household-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        let older = CloudSyncRecordState(
            entityName: String(describing: Pet.self),
            localRecordId: olderRecordId,
            householdId: householdId,
            ckZoneName: zoneName,
            ckRecordName: recordName,
            ckChangeTag: "old-tag",
            hasPendingLocalChanges: false,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 100),
            lastSyncedAt: Date(timeIntervalSinceReferenceDate: 200),
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            updatedAt: Date(timeIntervalSinceReferenceDate: 200)
        )
        let newer = CloudSyncRecordState(
            entityName: String(describing: Pet.self),
            localRecordId: newerRecordId,
            householdId: householdId,
            ckZoneName: zoneName,
            ckRecordName: recordName,
            ckChangeTag: "new-tag",
            hasPendingLocalChanges: false,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 300),
            lastSyncedAt: Date(timeIntervalSinceReferenceDate: 400),
            createdAt: Date(timeIntervalSinceReferenceDate: 300),
            updatedAt: Date(timeIntervalSinceReferenceDate: 400)
        )
        context.insert(older)
        context.insert(newer)

        let found = try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            ckRecordName: recordName,
            ckZoneName: zoneName,
            context: context
        )
        try context.save()

        #expect(found?.recordKey == newer.recordKey)
        let remaining = try context.fetch(FetchDescriptor<CloudSyncRecordState>(
            predicate: #Predicate<CloudSyncRecordState> {
                $0.entityName == "Pet" &&
                    $0.ckRecordName == recordName &&
                    $0.ckZoneName == zoneName
            }
        ))
        #expect(remaining.map(\.recordKey) == [newer.recordKey])
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
        let schemaNames = Set(ArkSchemaV73.models.map { String(describing: $0) })
            .subtracting(CloudSyncEntityRegistry.localOnlySchemaEntityNames)
        let descriptorNames = Set(CloudSyncEntityRegistry.descriptors.map(\.entityName))

        #expect(descriptorNames == schemaNames)
        #expect(CloudSyncEntityRegistry.descriptors.count == descriptorNames.count)
        #expect(CloudSyncEntityRegistry.localOnlySchemaEntityNames.isDisjoint(with: descriptorNames))
    }

    @MainActor
    @Test func cloudSyncProjectConfigurationKeepsRequiredCloudKitCapabilities() throws {
        let rootURL = repositoryRootURL()
        let entitlements = try propertyListDictionary(
            rootURL.appendingPathComponent("Ohana/Ohana.entitlements")
        )
        let infoPlist = try propertyListDictionary(
            rootURL.appendingPathComponent("Ohana/Info.plist")
        )
        let project = try String(
            contentsOf: rootURL.appendingPathComponent("Ohana.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )

        let containers = try #require(entitlements["com.apple.developer.icloud-container-identifiers"] as? [String])
        let services = try #require(entitlements["com.apple.developer.icloud-services"] as? [String])
        let backgroundModes = try #require(infoPlist["UIBackgroundModes"] as? [String])

        #expect(containers.contains(CloudSyncEngineRuntime.containerIdentifier))
        #expect(services.contains("CloudKit"))
        #expect((entitlements["aps-environment"] as? String)?.isEmpty == false)
        #expect(backgroundModes.contains("remote-notification"))
        #expect(infoPlist["CKSharingSupported"] as? Bool == true)
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = Ohana/Ohana.entitlements;"))
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
    @Test func entityRegistryUploadableDescriptorsMatchImplementedPipeline() {
        let uploadableNames = Set(CloudSyncEntityRegistry.uploadableDescriptors.map(\.entityName))

        #expect(uploadableNames == CloudSyncEntityRegistry.uploadPipelineEntityNames)
        #expect(uploadableNames.contains(String(describing: Pet.self)))
        #expect(uploadableNames.contains(String(describing: SharedCareSession.self)))
        #expect(uploadableNames.contains(String(describing: CoconutLedgerEntry.self)))
        #expect(!uploadableNames.contains(String(describing: Reminder.self)))
        #expect(CloudSyncEntityRegistry.supportsUploadPipeline(for: String(describing: Reminder.self)) == false)
    }

    @MainActor
    @Test func mutationRecorderStagesSharedCareSessionsForUploadPipeline() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = SharedCareSession(date: Date(timeIntervalSinceReferenceDate: 25))
        session.id = uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")
        context.insert(session)

        let entityName = String(describing: SharedCareSession.self)
        let descriptor = try #require(CloudSyncEntityRegistry.descriptor(for: entityName))
        #expect(descriptor.uploadsToCloudKit)
        #expect(CloudSyncEntityRegistry.supportsUploadPipeline(for: entityName))

        let modified = CloudSyncMutationRecorder.markModified(
            session,
            context: context,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 50)
        )
        let state = try #require(try CloudSyncMetadataService.state(
            entityName: entityName,
            localRecordId: session.id,
            context: context
        ))

        #expect(modified?.id == state.id)
        #expect(state.hasPendingLocalChanges)
        #expect(!state.isDeletionTombstone)

        let deleted = CloudSyncMutationRecorder.markDeleted(
            session,
            context: context,
            deletedAt: Date(timeIntervalSinceReferenceDate: 60)
        )
        let tombstone = try #require(try CloudSyncMetadataService.state(
            entityName: entityName,
            localRecordId: session.id,
            context: context
        ))

        #expect(deleted?.id == state.id)
        #expect(tombstone.isDeletionTombstone)
        #expect(tombstone.hasPendingLocalChanges)
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
    @Test func recordSerializerBuildsGachaAndShopPurchasePayloads() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let ownerId = uuid("77777777-7777-4777-8777-777777777777")
        let ownedItem = GachaOwnedItem(
            ownerHumanId: ownerId.uuidString,
            seriesId: GachaSeriesCatalog.defaultSeriesId,
            itemId: "plush_coconut_sleepy",
            rarity: .common,
            ownedCount: 2,
            firstObtainedAt: Date(timeIntervalSinceReferenceDate: 10),
            latestObtainedAt: Date(timeIntervalSinceReferenceDate: 20)
        )
        ownedItem.id = uuid("88888888-8888-4888-8888-888888888888")
        let ownedState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: GachaOwnedItem.self),
            localRecordId: ownedItem.id,
            householdId: householdId,
            context: context
        )
        let ownedPayload = try CloudSyncRecordSerializer.payload(for: ownedItem, state: ownedState)

        #expect(ownedPayload.recordType == "GachaOwnedItem")
        #expect(ownedPayload.fields["ownerHumanId"]?.stringValue == ownerId.uuidString)
        #expect(ownedPayload.fields["ownedCount"] == .int(2))
        #expect(ownedPayload.fields[CloudSyncRecordFieldKey.conflictPolicy]?.stringValue == CloudSyncConflictPolicy.lastWriterWins.rawValue)

        let purchase = ShopPurchaseRecord(
            id: uuid("99999999-9999-4999-8999-999999999999"),
            transactionKey: "shop:fx_lime_glow:\(ownerId.uuidString)",
            itemId: "fx_lime_glow",
            buyerHumanId: ownerId.uuidString,
            purchasedAt: Date(timeIntervalSinceReferenceDate: 30)
        )
        let purchaseState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: ShopPurchaseRecord.self),
            localRecordId: purchase.id,
            householdId: householdId,
            context: context
        )
        let purchasePayload = try CloudSyncRecordSerializer.payload(for: purchase, state: purchaseState)

        #expect(purchasePayload.recordType == "ShopPurchaseRecord")
        #expect(purchasePayload.fields["transactionKey"]?.stringValue == purchase.transactionKey)
        #expect(purchasePayload.fields["itemId"]?.stringValue == "fx_lime_glow")
        #expect(purchasePayload.fields["buyerHumanId"]?.stringValue == ownerId.uuidString)
    }

    @MainActor
    @Test func recordSerializerBuildsFeedingScheduleAndFoodRecordPayloads() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let pet = Pet(name: "Momo")
        pet.id = uuid("33333333-3333-4333-8333-333333333333")
        let event = Event(
            title: "Breakfast",
            startDate: Date(timeIntervalSinceReferenceDate: 45),
            endDate: Date(timeIntervalSinceReferenceDate: 60),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.id = uuid("44444444-4444-4444-8444-444444444444")
        event.recurrenceDays = 1
        event.completedOccurrences = ["100", "200"]
        event.assigneeId = "human-1"
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        event.foodKindRaw = FeedFoodKind.dry.rawValue
        event.feedAmountGrams = 45
        event.feedPlanGroupId = "plan-1"
        let foodRecord = PetFoodRecord(
            brand: "Acme",
            dailyGrams: 45,
            totalGrams: 1200,
            foodKind: .dry,
            purchaseDate: Date(timeIntervalSinceReferenceDate: 35),
            startDate: Date(timeIntervalSinceReferenceDate: 40),
            pet: pet,
            executorId: "human-1",
            expenseId: uuid("55555555-5555-4555-8555-555555555555"),
            calculationMode: .autoFeeder
        )
        foodRecord.id = uuid("66666666-6666-4666-8666-666666666666")
        foodRecord.remainingCorrectionGrams = 900
        foodRecord.remainingCorrectionDate = Date(timeIntervalSinceReferenceDate: 50)
        foodRecord.notes = "structured stock"

        let eventState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Event.self),
            localRecordId: event.id,
            householdId: householdId,
            context: context
        )
        let recordState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: PetFoodRecord.self),
            localRecordId: foodRecord.id,
            householdId: householdId,
            context: context
        )
        let eventPayload = try CloudSyncRecordSerializer.payload(for: event, state: eventState)
        let foodPayload = try CloudSyncRecordSerializer.payload(for: foodRecord, state: recordState)

        #expect(CloudSyncEntityRegistry.supportsUploadPipeline(for: String(describing: Event.self)))
        #expect(CloudSyncEntityRegistry.supportsUploadPipeline(for: String(describing: PetFoodRecord.self)))
        #expect(eventPayload.fields["title"]?.stringValue == "Breakfast")
        #expect(eventPayload.fields["completedOccurrences"]?.stringListValue == ["100", "200"])
        #expect(eventPayload.fields["feedRuleKindRaw"]?.stringValue == FeedRuleKind.manualReminder.rawValue)
        #expect(foodPayload.fields["brand"]?.stringValue == "Acme")
        #expect(foodPayload.fields["petId"]?.stringValue == normalized(pet.id))
        #expect(foodPayload.fields["expenseId"]?.stringValue == "55555555-5555-4555-8555-555555555555")
        #expect(foodPayload.fields["calculationModeRaw"]?.stringValue == FeedStockCalculationMode.autoFeeder.rawValue)
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

        let coExecutorId = "human-2"
        let walkLog = PetWalkLog(
            startDate: Date(timeIntervalSinceReferenceDate: 90),
            pet: pet,
            executorId: executorId,
            executorIds: [executorId, coExecutorId],
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
        #expect(walkPayload.fields["executorIdsRaw"]?.stringValue == "\(executorId)|\(coExecutorId)")
        #expect(walkPayload.fields["behaviorNotes"]?.stringValue == "calm walk")
        #expect(walkPayload.fields["routeLocationsData"] == .assetData(Data([1, 2, 3])))
    }

    @MainActor
    @Test func recordSerializerBuildsSharedCareSessionPayload() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let sourcePetId = normalized(uuid("11111111-1111-4111-8111-111111111111"))
        let targetPetId = normalized(uuid("22222222-2222-4222-8222-222222222222"))
        let executorId = normalized(uuid("33333333-3333-4333-8333-333333333333"))
        let coExecutorId = normalized(uuid("44444444-4444-4444-8444-444444444444"))
        let session = SharedCareSession(
            date: Date(timeIntervalSinceReferenceDate: 95),
            actionKind: .walk,
            executorId: executorId,
            executorIds: [executorId, coExecutorId],
            sourcePetId: sourcePetId,
            targetPetIds: [sourcePetId, targetPetId],
            species: "dog",
            allocationMode: .equal,
            primaryLegacyModelName: String(describing: PetWalkLog.self),
            primaryLegacyModelId: "walk-log-1",
            note: "evening loop"
        )
        session.id = uuid("55555555-5555-4555-8555-555555555555")
        session.createdAt = Date(timeIntervalSinceReferenceDate: 96)

        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: SharedCareSession.self),
            localRecordId: session.id,
            householdId: householdId,
            context: context
        )
        let payload = try CloudSyncRecordSerializer.payload(for: session, state: state)

        #expect(payload.entityName == "SharedCareSession")
        #expect(payload.fields["actionKindRaw"]?.stringValue == SharedCareActionKind.walk.rawValue)
        #expect(payload.fields["executorId"]?.stringValue == executorId)
        #expect(payload.fields["executorIdsRaw"]?.stringValue == "\(executorId)|\(coExecutorId)")
        #expect(payload.fields["targetPetIdsRaw"]?.stringValue == "\(sourcePetId)|\(targetPetId)")
        #expect(payload.fields["speciesRaw"]?.stringValue == "dog")
        #expect(payload.fields["primaryLegacyModelName"]?.stringValue == String(describing: PetWalkLog.self))
        #expect(payload.fields["note"]?.stringValue == "evening loop")
    }

    @MainActor
    @Test func recordSerializerKeepsLedgerEntriesAsImmutableFacts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let event = CareLedgerEvent(
            id: uuid("55555555-5555-4555-8555-555555555555"),
            occurredAt: Date(timeIntervalSinceReferenceDate: 55),
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: "pet-1",
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: 25,
            amountUnit: "g",
            note: "clean dinner",
            source: .quickAction,
            sourceEventId: "event-1",
            sourceReminderId: "reminder-1",
            legacyModelName: String(describing: PetCareLog.self),
            legacyModelId: "care-log-1",
            coconutDelta: 2,
            rewardLogId: "reward-1",
            privacyFieldRaw: "care",
            metadataJSON: #"{"sharedSessionId":"session-1"}"#,
            createdAt: Date(timeIntervalSinceReferenceDate: 56)
        )
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

        let eventState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: CareLedgerEvent.self),
            localRecordId: event.id,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            context: context
        )
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: CoconutLedgerEntry.self),
            localRecordId: entry.id,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            context: context
        )
        let eventPayload = try CloudSyncRecordSerializer.payload(for: event, state: eventState)
        let payload = try CloudSyncRecordSerializer.payload(for: entry, state: state)

        #expect(CloudSyncEntityRegistry.supportsUploadPipeline(for: String(describing: CareLedgerEvent.self)))
        #expect(eventPayload.entityName == "CareLedgerEvent")
        #expect(eventPayload.fields["actorKind"]?.stringValue == CareLedgerActorKind.human.rawValue)
        #expect(eventPayload.fields["subjectKind"]?.stringValue == CareLedgerSubjectKind.pet.rawValue)
        #expect(eventPayload.fields["eventKind"]?.stringValue == CareLedgerEventKind.care.rawValue)
        #expect(eventPayload.fields["actionType"]?.stringValue == CareType.feeding.rawValue)
        #expect(eventPayload.fields["amountValue"] == .double(25))
        #expect(eventPayload.fields["note"]?.stringValue == "clean dinner")
        #expect(eventPayload.fields["legacyModelName"]?.stringValue == String(describing: PetCareLog.self))
        #expect(eventPayload.fields["metadataJSON"]?.stringValue == #"{"sharedSessionId":"session-1"}"#)
        #expect(eventPayload.fields[CloudSyncRecordFieldKey.conflictPolicy]?.stringValue == CloudSyncConflictPolicy.appendOnly.rawValue)
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
        let ledgerEvent = CareLedgerEvent(
            id: uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc"),
            occurredAt: Date(timeIntervalSinceReferenceDate: 150),
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: normalized(pet.id),
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            note: "clean dinner",
            source: .quickAction,
            legacyModelName: String(describing: PetCareLog.self),
            legacyModelId: "care-log-1",
            metadataJSON: "{}",
            createdAt: Date(timeIntervalSinceReferenceDate: 151)
        )
        context.insert(household)
        context.insert(pet)
        context.insert(ledgerEvent)

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
        _ = try CloudSyncMetadataService.markModified(
            entityName: String(describing: CareLedgerEvent.self),
            localRecordId: ledgerEvent.id,
            householdId: household.id,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 150),
            context: context
        )

        let payloads = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)

        #expect(payloads.map(\.entityName) == ["Household", "CareLedgerEvent", "Pet"])
        #expect(payloads.map(\.recordName) == [
            "Household_aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            "CareLedgerEvent_cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            "Pet_bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        ])
        #expect(payloads.first { $0.entityName == "CareLedgerEvent" }?.fields["note"]?.stringValue == "clean dinner")
    }

    @MainActor
    @Test func uploadBatchBuilderBuildsDirtyPayloadsForRegisteredGachaAndShopEntities() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let household = Household(name: "Shared Home")
        household.id = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let ownerId = uuid("77777777-7777-4777-8777-777777777777")
        let ownedItem = GachaOwnedItem(
            ownerHumanId: ownerId.uuidString,
            seriesId: GachaSeriesCatalog.defaultSeriesId,
            itemId: "plush_coconut_sleepy",
            rarity: .common,
            ownedCount: 2,
            firstObtainedAt: Date(timeIntervalSinceReferenceDate: 10),
            latestObtainedAt: Date(timeIntervalSinceReferenceDate: 20)
        )
        ownedItem.id = uuid("88888888-8888-4888-8888-888888888888")
        let drawLog = GachaDrawLog(
            ownerHumanId: ownerId.uuidString,
            ownerName: "Guan",
            seriesId: GachaSeriesCatalog.defaultSeriesId,
            itemId: "plush_coconut_sleepy",
            rarity: .common,
            isNew: true,
            drawDate: Date(timeIntervalSinceReferenceDate: 30)
        )
        drawLog.id = uuid("99999999-9999-4999-8999-999999999999")
        let purchase = ShopPurchaseRecord(
            id: uuid("66666666-6666-4666-8666-666666666666"),
            transactionKey: "shop:fx_lime_glow:\(ownerId.uuidString)",
            itemId: "fx_lime_glow",
            buyerHumanId: ownerId.uuidString,
            purchasedAt: Date(timeIntervalSinceReferenceDate: 40)
        )
        context.insert(household)
        context.insert(ownedItem)
        context.insert(drawLog)
        context.insert(purchase)

        CloudSyncMutationRecorder.markModified(ownedItem, context: context, modifiedAt: Date(timeIntervalSinceReferenceDate: 100))
        CloudSyncMutationRecorder.markModified(drawLog, context: context, modifiedAt: Date(timeIntervalSinceReferenceDate: 110))
        CloudSyncMutationRecorder.markModified(purchase, context: context, modifiedAt: Date(timeIntervalSinceReferenceDate: 120))

        let payloads = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)

        #expect(payloads.map(\.entityName) == ["GachaOwnedItem", "GachaDrawLog", "ShopPurchaseRecord"])
        #expect(payloads.first { $0.entityName == "GachaOwnedItem" }?.fields["ownerHumanId"]?.stringValue == ownerId.uuidString)
        #expect(payloads.first { $0.entityName == "GachaDrawLog" }?.fields["ownerHumanId"]?.stringValue == ownerId.uuidString)
        #expect(payloads.first { $0.entityName == "ShopPurchaseRecord" }?.fields["buyerHumanId"]?.stringValue == ownerId.uuidString)
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
    @Test func uploadBatchBuilderSkipsDirtyStatesOutsideImplementedPipeline() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let reminderId = uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")

        _ = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Reminder.self),
            localRecordId: reminderId,
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            modifiedAt: Date(timeIntervalSinceReferenceDate: 550),
            context: context
        )

        let payloads = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)

        #expect(payloads.isEmpty)
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
    @Test func cloudSyncAccountPreflightMapsCloudKitAccountStatus() async {
        #expect(CloudSyncAccountPreflight.availability(for: .available) == .available)
        #expect(CloudSyncAccountPreflight.availability(for: .noAccount) == .unavailable(.noAccount))
        #expect(CloudSyncAccountPreflight.availability(for: .restricted) == .unavailable(.restricted))
        #expect(CloudSyncAccountPreflight.availability(for: .temporarilyUnavailable) == .unavailable(.temporarilyUnavailable))
        #expect(CloudSyncAccountPreflight.availability(for: .couldNotDetermine) == .unavailable(.couldNotDetermine))

        let failingAvailability = await CloudSyncAccountPreflight.availability(
            provider: FailingCloudSyncAccountStatusProvider()
        )

        #expect(failingAvailability == .unavailable(.couldNotDetermine))
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
    @Test func householdShareStateUpdaterClearsStoppedShareName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let household = Household(name: "Shared Home")
        household.id = householdId
        household.ckShareRecordName = CKRecordNameZoneWideShare
        context.insert(household)

        let didUpdate = try CloudSyncHouseholdShareStateUpdater.markShareStopped(
            householdId: householdId,
            context: context
        )

        #expect(didUpdate)
        #expect(household.ckShareRecordName.isEmpty)
    }

    @MainActor
    @Test func householdShareStopRuntimeRestagesLocalSnapshotForPrivateSync() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = "CloudSyncHouseholdShareStopRuntimeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            ownerName: "private-owner",
            automaticallySync: false
        )
        service.setEnabled(true)
        service.setDatabaseScope(.sharedCloudDatabase, zoneOwnerName: "share-owner")
        defaults.set(Data("shared-state".utf8), forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey)
        defaults.set(true, forKey: CloudSyncEngineRuntime.sharedZoneAccessRevokedDefaultsKey)
        defaults.set(2, forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey)
        defaults.set(
            Date(timeIntervalSinceReferenceDate: 4000).timeIntervalSinceReferenceDate,
            forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey
        )
        defaults.set(CloudSyncRetryOperation.fetch.rawValue, forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey)

        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let household = Household(name: "Shared Home")
        household.id = householdId
        household.ckShareRecordName = CKRecordNameZoneWideShare
        let pet = Pet(name: "Momo")
        pet.id = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        context.insert(household)
        context.insert(pet)
        let petState = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: pet.id,
            householdId: householdId,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 10),
            context: context
        )
        CloudSyncMetadataService.markSynced(
            petState,
            ckRecordName: "Pet_cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            ckChangeTag: "shared-change-tag",
            ckZoneName: CloudSyncZoneNaming.zoneName(forHouseholdId: normalized(householdId)),
            syncedAt: Date(timeIntervalSinceReferenceDate: 20)
        )
        let restagedAt = Date(timeIntervalSinceReferenceDate: 5000)

        let summary = try CloudSyncHouseholdShareStopRuntime.stopSharingLocally(
            householdId: householdId,
            context: context,
            cloudSync: service,
            modifiedAt: restagedAt
        )

        #expect(summary.householdId == householdId)
        #expect(summary.shareRecordWasCleared)
        #expect(summary.stagedRecordCount == 2)
        #expect(summary.restagedSnapshot.mergedHouseholdCount == 0)
        #expect(household.ckShareRecordName.isEmpty)
        #expect(service.databaseScope == .privateCloudDatabase)
        #expect(service.recordZoneOwnerName == "private-owner")
        #expect(!service.hasSharedZoneAccessRevokedNotice)
        #expect(defaults.string(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey) == nil)
        #expect(defaults.data(forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey) == nil)
        #expect(petState.hasPendingLocalChanges)
        #expect(petState.ckChangeTag.isEmpty)
        #expect(petState.lastModifiedAt == restagedAt)
        #expect(petState.metadataJSON.contains("shareStoppedPrivateRestage"))
    }

    @MainActor
    @Test func acceptedShareStateUpdaterCreatesPlaceholderHousehold() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let zoneID = CloudSyncShareRuntime.zoneID(householdId: householdId)
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Joined Home" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = CloudSyncShareRuntime.shareType as CKRecordValue

        let acceptedHouseholdId = try CloudSyncAcceptedShareStateUpdater.markAcceptedShare(
            share,
            context: context
        )

        #expect(acceptedHouseholdId == householdId)
        let household = try #require(try fetchHousehold(id: householdId, context: context))
        #expect(household.name == "Joined Home")
        #expect(household.ckShareRecordName == CKRecordNameZoneWideShare)
    }

    @MainActor
    @Test func acceptedShareStateUpdaterRejectsNonHouseholdShareType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let zoneID = CloudSyncShareRuntime.zoneID(householdId: householdId)
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Not Ohana" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.example.other.share" as CKRecordValue

        let acceptedHouseholdId = try CloudSyncAcceptedShareStateUpdater.markAcceptedShare(
            share,
            context: context
        )

        #expect(acceptedHouseholdId == nil)
        #expect(try fetchHousehold(id: householdId, context: context) == nil)
    }

    @MainActor
    @Test func humanIdentityBinderStoresCurrentCloudKitUserLocally() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Avery")
        human.id = uuid("22222222-2222-4222-8222-222222222222")
        context.insert(human)

        let didBind = try CloudSyncHumanIdentityBinder.bind(
            currentUserRecordName: "_abcdef123456",
            toHumanId: human.id,
            context: context
        )

        #expect(didBind)
        #expect(human.appleUserIdentifier == "_abcdef123456")
        #expect(try CloudSyncMetadataService.state(
            entityName: String(describing: Human.self),
            localRecordId: human.id,
            context: context
        ) == nil)
    }

    @MainActor
    @Test func initialHouseholdMergeStagesSupportedLocalSnapshotIntoSharedZone() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let acceptedHouseholdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let legacyHouseholdId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let stagedAt = Date(timeIntervalSinceReferenceDate: 800)
        let acceptedHousehold = Household(name: "")
        acceptedHousehold.id = acceptedHouseholdId
        acceptedHousehold.totalProsperity = 2
        let legacyHousehold = Household(name: "Local Home")
        legacyHousehold.id = legacyHouseholdId
        legacyHousehold.totalProsperity = 9
        let pet = Pet(name: "Momo")
        pet.id = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let human = Human(name: "Avery")
        human.id = uuid("dddddddd-dddd-4ddd-8ddd-dddddddddddd")
        let careLog = PetCareLog(
            date: Date(timeIntervalSinceReferenceDate: 700),
            type: .feeding,
            amountGrams: 42,
            pet: pet,
            executorId: human.id.uuidString
        )
        careLog.id = uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")
        context.insert(acceptedHousehold)
        context.insert(legacyHousehold)
        context.insert(pet)
        context.insert(human)
        context.insert(careLog)

        let summary = try CloudSyncInitialHouseholdMergeRuntime.stageLocalSnapshotForHouseholdShare(
            householdId: acceptedHouseholdId,
            context: context,
            modifiedAt: stagedAt
        )
        let payloads = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)
        let sharedZoneName = CloudSyncZoneNaming.zoneName(forHouseholdId: normalized(acceptedHouseholdId))

        #expect(summary.snapshotRecordCount == 5)
        #expect(summary.mergedHouseholdCount == 1)
        #expect(summary.stagedRecordCount == 4)
        #expect(summary.stagedByEntityName[String(describing: Household.self)] == 1)
        #expect(summary.stagedByEntityName[String(describing: Pet.self)] == 1)
        #expect(summary.stagedByEntityName[String(describing: Human.self)] == 1)
        #expect(summary.stagedByEntityName[String(describing: PetCareLog.self)] == 1)
        #expect(acceptedHousehold.name == "Local Home")
        #expect(acceptedHousehold.totalProsperity == 9)
        #expect(payloads.count == 4)
        #expect(payloads.allSatisfy { $0.zoneName == sharedZoneName })
        #expect(payloads.contains { $0.entityName == String(describing: PetCareLog.self) })
    }

    @MainActor
    @Test func initialHouseholdMergeRehomesExistingSyncedStateToSharedZone() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let acceptedHouseholdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let oldHouseholdId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let acceptedHousehold = Household(name: "Shared Home")
        acceptedHousehold.id = acceptedHouseholdId
        let pet = Pet(name: "Momo")
        pet.id = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        context.insert(acceptedHousehold)
        context.insert(pet)
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: pet.id,
            householdId: oldHouseholdId,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 10),
            context: context
        )
        CloudSyncMetadataService.markSynced(
            state,
            ckRecordName: "Pet_cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            ckChangeTag: "old-change-tag",
            ckZoneName: CloudSyncZoneNaming.zoneName(forHouseholdId: normalized(oldHouseholdId)),
            syncedAt: Date(timeIntervalSinceReferenceDate: 20)
        )

        _ = try CloudSyncInitialHouseholdMergeRuntime.stageLocalSnapshotForHouseholdShare(
            householdId: acceptedHouseholdId,
            context: context,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 30)
        )

        #expect(state.householdId == normalized(acceptedHouseholdId))
        #expect(state.ckZoneName == CloudSyncZoneNaming.zoneName(forHouseholdId: normalized(acceptedHouseholdId)))
        #expect(state.ckChangeTag.isEmpty)
        #expect(state.hasPendingLocalChanges)
        #expect(state.lastModifiedAt == Date(timeIntervalSinceReferenceDate: 30))
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
    @Test func pendingChangeBuilderSkipsZoneSavesForSharedDatabaseScope() {
        let payload = makeRecordPayload(
            localRecordId: uuid("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"),
            householdId: uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            fields: ["name": .string("Shared Home")]
        )

        let databaseChanges = CloudSyncEnginePendingChangeBuilder.pendingDatabaseChanges(
            for: [payload],
            ownerName: "share-owner",
            databaseScope: .sharedCloudDatabase
        )
        let recordChanges = CloudSyncEngineBatchBuilder.pendingSaveChanges(
            for: [payload],
            ownerName: "share-owner"
        )

        #expect(databaseChanges.isEmpty)
        guard case let .saveRecord(recordID) = recordChanges.first else {
            Issue.record("Expected shared database participants to save records into the shared zone")
            return
        }
        #expect(recordID.zoneID.ownerName == "share-owner")
        #expect(recordID.zoneID.zoneName == "household-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    }

    @MainActor
    @Test func cloudSyncEngineServicePersistsSharedDatabaseScopeAndOwnerName() {
        let suiteName = "CloudSyncEngineServiceScopeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("stale-state".utf8), forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey)

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            ownerName: "private-owner",
            automaticallySync: false
        )

        #expect(service.databaseScope == .privateCloudDatabase)
        #expect(service.recordZoneOwnerName == "private-owner")

        service.setDatabaseScope(.sharedCloudDatabase, zoneOwnerName: " share-owner ")

        #expect(service.databaseScope == .sharedCloudDatabase)
        #expect(service.recordZoneOwnerName == "share-owner")
        #expect(defaults.string(forKey: CloudSyncEngineRuntime.databaseScopeDefaultsKey) == CloudSyncDatabaseScope.sharedCloudDatabase.rawValue)
        #expect(defaults.string(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey) == "share-owner")
        #expect(defaults.data(forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey) == nil)

        let restored = CloudSyncEngineService(
            userDefaults: defaults,
            ownerName: "private-owner",
            automaticallySync: false
        )
        #expect(restored.databaseScope == .sharedCloudDatabase)
        #expect(restored.recordZoneOwnerName == "share-owner")

        restored.setDatabaseScope(.privateCloudDatabase, zoneOwnerName: nil)

        #expect(restored.databaseScope == .privateCloudDatabase)
        #expect(restored.recordZoneOwnerName == "private-owner")
        #expect(defaults.string(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey) == nil)
    }

    @MainActor
    @Test func cloudSyncEngineServiceClearsStaleSharedOwnerWhenSharedScopeHasBlankOwner() {
        let suiteName = "CloudSyncEngineServiceBlankSharedOwnerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("stale-state".utf8), forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey)
        defaults.set("old-share-owner", forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey)
        defaults.set(2, forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey)
        defaults.set(
            Date(timeIntervalSinceReferenceDate: 1000).timeIntervalSinceReferenceDate,
            forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey
        )
        defaults.set(CloudSyncRetryOperation.send.rawValue, forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey)

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            ownerName: "private-owner",
            automaticallySync: false
        )

        service.setDatabaseScope(.sharedCloudDatabase, zoneOwnerName: "   ")

        #expect(service.databaseScope == .sharedCloudDatabase)
        #expect(service.recordZoneOwnerName == "private-owner")
        #expect(defaults.string(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey) == nil)
        #expect(defaults.data(forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey) == nil)
    }

    @MainActor
    @Test func cloudSyncEngineServiceIgnoresRemoteNotificationsWhenDisabled() async throws {
        let container = try makeContainer()
        let suiteName = "CloudSyncEngineServiceRemoteNotificationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            automaticallySync: false
        )

        let result = await service.handleRemoteNotification(modelContainer: container)

        #expect(result == .ignored)
        #expect(!service.isStarted)
        #expect(await service.fetchRemoteChanges() == false)
        #expect(await service.sendPendingLocalChanges() == false)
    }

    @MainActor
    @Test func cloudSyncEngineServiceClearsEngineStateWhenCloudKitAccountBecomesUnavailable() async throws {
        let container = try makeContainer()
        let suiteName = "CloudSyncEngineServiceAccountChangedTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: CloudSyncEngineRuntime.enabledDefaultsKey)
        defaults.set(Data("stale-state".utf8), forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey)
        defaults.set(2, forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey)
        defaults.set(
            Date(timeIntervalSinceReferenceDate: 4000).timeIntervalSinceReferenceDate,
            forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey
        )
        defaults.set(CloudSyncRetryOperation.fetch.rawValue, forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey)

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            automaticallySync: false
        )

        let result = await service.handleAccountChanged(
            availability: .unavailable(.noAccount),
            modelContainer: container
        )

        #expect(result == .paused(.noAccount))
        #expect(service.isEnabled)
        #expect(!service.isStarted)
        #expect(defaults.data(forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey) == nil)
    }

    @MainActor
    @Test func sharedZoneAccessFailureClassifierDetectsRevokedShareErrors() {
        #expect(CloudSyncSharedZoneAccessFailureClassifier.isSharedZoneAccessLoss(CKError(.zoneNotFound)))
        #expect(CloudSyncSharedZoneAccessFailureClassifier.isSharedZoneAccessLoss(CKError(.permissionFailure)))
        #expect(CloudSyncSharedZoneAccessFailureClassifier.isSharedZoneAccessLoss(CKError(.userDeletedZone)))
        #expect(!CloudSyncSharedZoneAccessFailureClassifier.isSharedZoneAccessLoss(CKError(.networkUnavailable)))
    }

    @MainActor
    @Test func sharedZoneAccessFailureClassifierDetectsRevokedShareInsidePartialFailure() {
        let recordID = CKRecord.ID(
            recordName: "revoked-record",
            zoneID: CKRecordZone.ID(zoneName: "household-zone", ownerName: "share-owner")
        )
        let partialFailure = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                CKPartialErrorsByItemIDKey: [
                    recordID: CKError(.permissionFailure)
                ] as [CKRecord.ID: Error]
            ]
        )

        #expect(CloudSyncSharedZoneAccessFailureClassifier.isSharedZoneAccessLoss(partialFailure))
    }

    @MainActor
    @Test func cloudSyncEngineServiceStopsSharedSyncWhenSharedZoneAccessIsLost() {
        let suiteName = "CloudSyncEngineServiceRevokedShareTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("stale-state".utf8), forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey)

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            ownerName: "private-owner",
            automaticallySync: false
        )
        service.setEnabled(true)
        service.setDatabaseScope(.sharedCloudDatabase, zoneOwnerName: "share-owner")

        let didRecover = service.handleSharedZoneAccessLossIfNeeded(CKError(.zoneNotFound))

        #expect(didRecover)
        #expect(!service.isEnabled)
        #expect(service.databaseScope == .privateCloudDatabase)
        #expect(service.recordZoneOwnerName == "private-owner")
        #expect(service.hasSharedZoneAccessRevokedNotice)
        #expect(defaults.string(forKey: CloudSyncEngineRuntime.sharedZoneOwnerNameDefaultsKey) == nil)
        #expect(defaults.data(forKey: UserDefaultsCloudSyncEngineStateStore.defaultKey) == nil)

        service.clearSharedZoneAccessRevokedNotice()

        #expect(!service.hasSharedZoneAccessRevokedNotice)
    }

    @MainActor
    @Test func transientRetryPolicyUsesCloudKitRetryAfterBeforeFallbackBackoff() throws {
        let now = Date(timeIntervalSinceReferenceDate: 2000)
        let rateLimited = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.requestRateLimited.rawValue,
            userInfo: [CKErrorRetryAfterKey: 42.0]
        )

        let systemPlan = try #require(CloudSyncTransientErrorRetryPolicy.plan(
            for: rateLimited,
            operation: .send,
            previousAttempt: 0,
            now: now
        ))
        let fallbackPlan = try #require(CloudSyncTransientErrorRetryPolicy.plan(
            for: CKError(.networkUnavailable),
            operation: .fetch,
            previousAttempt: 2,
            now: now
        ))

        #expect(systemPlan.operation == .send)
        #expect(systemPlan.attempt == 1)
        #expect(systemPlan.delaySeconds == 42)
        #expect(systemPlan.nextRetryAt == now.addingTimeInterval(42))
        #expect(fallbackPlan.operation == .fetch)
        #expect(fallbackPlan.attempt == 3)
        #expect(fallbackPlan.delaySeconds == 20)
        #expect(fallbackPlan.nextRetryAt == now.addingTimeInterval(20))
        #expect(CloudSyncTransientErrorRetryPolicy.plan(
            for: CKError(.permissionFailure),
            operation: .send,
            previousAttempt: 0,
            now: now
        ) == nil)
    }

    @MainActor
    @Test func transientRetryPolicyUsesRetryAfterInsidePartialFailure() throws {
        let now = Date(timeIntervalSinceReferenceDate: 2400)
        let recordID = CKRecord.ID(
            recordName: "rate-limited-record",
            zoneID: CKRecordZone.ID(zoneName: "household-zone", ownerName: CKCurrentUserDefaultName)
        )
        let rateLimited = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.requestRateLimited.rawValue,
            userInfo: [CKErrorRetryAfterKey: 17.0]
        )
        let partialFailure = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                CKPartialErrorsByItemIDKey: [
                    recordID: rateLimited
                ] as [CKRecord.ID: Error]
            ]
        )

        let plan = try #require(CloudSyncTransientErrorRetryPolicy.plan(
            for: partialFailure,
            operation: .send,
            previousAttempt: 1,
            now: now
        ))

        #expect(plan.operation == .send)
        #expect(plan.attempt == 2)
        #expect(plan.delaySeconds == 17)
        #expect(plan.nextRetryAt == now.addingTimeInterval(17))
    }

    @MainActor
    @Test func cloudSyncEngineServiceQueuesTransientRetryWithoutClearingSharedScope() {
        let suiteName = "CloudSyncEngineServiceTransientRetryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            ownerName: "private-owner",
            automaticallySync: false
        )
        service.setEnabled(true)
        service.setDatabaseScope(.sharedCloudDatabase, zoneOwnerName: "share-owner")

        let now = Date(timeIntervalSinceReferenceDate: 3000)
        let didQueueRetry = service.handleTransientSyncFailureIfNeeded(
            CKError(.networkUnavailable),
            operation: .send,
            now: now
        )

        #expect(didQueueRetry)
        #expect(service.isEnabled)
        #expect(service.databaseScope == .sharedCloudDatabase)
        #expect(service.recordZoneOwnerName == "share-owner")
        #expect(!service.hasSharedZoneAccessRevokedNotice)
        #expect(service.hasPendingTransientRetry)
        #expect(service.nextTransientRetryAt == now.addingTimeInterval(5))
        #expect(service.pendingTransientRetryOperation == .send)
        #expect(defaults.integer(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey) == 1)
        #expect(defaults.double(forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey) == now.addingTimeInterval(5).timeIntervalSinceReferenceDate)
        #expect(defaults.string(forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey) == CloudSyncRetryOperation.send.rawValue)

        service.setEnabled(false)

        #expect(!service.hasPendingTransientRetry)
        #expect(service.nextTransientRetryAt == nil)
        #expect(service.pendingTransientRetryOperation == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey) == nil)
        #expect(defaults.object(forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey) == nil)
    }

    @MainActor
    @Test func cloudSyncEngineServiceRestoresPersistedTransientRetryPlan() {
        let suiteName = "CloudSyncEngineServicePersistedTransientRetryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let nextRetryAt = Date(timeIntervalSinceReferenceDate: 4500)
        defaults.set(3, forKey: CloudSyncEngineRuntime.retryAttemptDefaultsKey)
        defaults.set(nextRetryAt.timeIntervalSinceReferenceDate, forKey: CloudSyncEngineRuntime.nextRetryAtDefaultsKey)
        defaults.set(CloudSyncRetryOperation.fetch.rawValue, forKey: CloudSyncEngineRuntime.retryOperationDefaultsKey)

        let service = CloudSyncEngineService(
            userDefaults: defaults,
            automaticallySync: false
        )

        let futurePlan = service.pendingTransientRetryPlan(now: Date(timeIntervalSinceReferenceDate: 4400))
        let duePlan = service.pendingTransientRetryPlan(now: Date(timeIntervalSinceReferenceDate: 4600))

        #expect(service.hasPendingTransientRetry)
        #expect(service.pendingTransientRetryOperation == .fetch)
        #expect(futurePlan?.operation == .fetch)
        #expect(futurePlan?.attempt == 3)
        #expect(futurePlan?.delaySeconds == 100)
        #expect(futurePlan?.nextRetryAt == nextRetryAt)
        #expect(duePlan?.delaySeconds == 0)
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
    @Test func engineDelegateAdapterAppliesServerRecordChangedFailureThroughFetchedApplier() async throws {
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let serverRecord = try makeRecordPayload(
            localRecordId: householdId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 7000),
            fields: ["name": .string("Server Home")]
        ).makeCKRecord()
        let error = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.serverRecordChanged.rawValue,
            userInfo: [CKRecordChangedErrorServerRecordKey: serverRecord]
        )
        let applier = CapturingCloudSyncFetchedRecordApplier()
        let runtime = CloudSyncEngineDelegateAdapter(
            uploadPayloadProvider: StaticCloudSyncUploadPayloadProvider(payloads: []),
            fetchedRecordApplier: applier
        )

        let resolved = await runtime.resolveFailedRecordSaveConflicts([
            CloudSyncFailedRecordSaveContext(
                recordName: serverRecord.recordID.recordName,
                error: error
            ),
            CloudSyncFailedRecordSaveContext(
                recordName: "network-failure",
                error: CKError(.networkUnavailable)
            )
        ])

        #expect(resolved == [serverRecord.recordID.recordName])
        #expect(applier.appliedRecordNames == [serverRecord.recordID.recordName])
    }

    @MainActor
    @Test func engineDelegateAdapterMatchesServerRecordChangedPartialFailureByRecordName() async throws {
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let decoyRecord = try makeRecordPayload(
            localRecordId: uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"),
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 7050),
            fields: ["name": .string("Decoy Home")]
        ).makeCKRecord()
        let targetRecord = try makeRecordPayload(
            localRecordId: householdId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 7060),
            fields: ["name": .string("Target Home")]
        ).makeCKRecord()
        let decoyError = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.serverRecordChanged.rawValue,
            userInfo: [CKRecordChangedErrorServerRecordKey: decoyRecord]
        )
        let targetError = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.serverRecordChanged.rawValue,
            userInfo: [CKRecordChangedErrorServerRecordKey: targetRecord]
        )
        let partialFailure = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                CKPartialErrorsByItemIDKey: [
                    decoyRecord.recordID: decoyError,
                    targetRecord.recordID: targetError
                ] as [CKRecord.ID: Error]
            ]
        )
        let applier = CapturingCloudSyncFetchedRecordApplier()
        let runtime = CloudSyncEngineDelegateAdapter(
            uploadPayloadProvider: StaticCloudSyncUploadPayloadProvider(payloads: []),
            fetchedRecordApplier: applier
        )

        let resolved = await runtime.resolveFailedRecordSaveConflicts([
            CloudSyncFailedRecordSaveContext(
                recordName: targetRecord.recordID.recordName,
                error: partialFailure
            )
        ])

        #expect(resolved == [targetRecord.recordID.recordName])
        #expect(applier.appliedRecordNames == [targetRecord.recordID.recordName])
    }

    @MainActor
    @Test func engineDelegateAdapterKeepsFailedServerRecordConflictUnresolved() async throws {
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let serverRecord = try makeRecordPayload(
            localRecordId: householdId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 7100),
            fields: ["name": .string("Server Home")]
        ).makeCKRecord()
        let error = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.serverRecordChanged.rawValue,
            userInfo: [CKRecordChangedErrorServerRecordKey: serverRecord]
        )
        let runtime = CloudSyncEngineDelegateAdapter(
            uploadPayloadProvider: StaticCloudSyncUploadPayloadProvider(payloads: []),
            fetchedRecordApplier: FailingCloudSyncFetchedRecordApplier()
        )

        let resolved = await runtime.resolveFailedRecordSaveConflicts([
            CloudSyncFailedRecordSaveContext(
                recordName: serverRecord.recordID.recordName,
                error: error
            )
        ])

        #expect(resolved.isEmpty)
    }

    @MainActor
    @Test func engineDelegateAdapterResolvesMixedServerRecordConflictsIndividually() async throws {
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let resolvedRecord = try makeRecordPayload(
            localRecordId: householdId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 7200),
            fields: ["name": .string("Resolved Home")]
        ).makeCKRecord()
        let unresolvedRecord = try makeRecordPayload(
            localRecordId: uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc"),
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 7210),
            fields: ["name": .string("Unresolved Home")]
        ).makeCKRecord()
        let resolvedError = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.serverRecordChanged.rawValue,
            userInfo: [CKRecordChangedErrorServerRecordKey: resolvedRecord]
        )
        let unresolvedError = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.serverRecordChanged.rawValue,
            userInfo: [CKRecordChangedErrorServerRecordKey: unresolvedRecord]
        )
        let applier = SelectiveFailingCloudSyncFetchedRecordApplier(
            failingRecordNames: [unresolvedRecord.recordID.recordName]
        )
        let runtime = CloudSyncEngineDelegateAdapter(
            uploadPayloadProvider: StaticCloudSyncUploadPayloadProvider(payloads: []),
            fetchedRecordApplier: applier
        )

        let resolved = await runtime.resolveFailedRecordSaveConflicts([
            CloudSyncFailedRecordSaveContext(
                recordName: resolvedRecord.recordID.recordName,
                error: resolvedError
            ),
            CloudSyncFailedRecordSaveContext(
                recordName: unresolvedRecord.recordID.recordName,
                error: unresolvedError
            )
        ])

        #expect(resolved == [resolvedRecord.recordID.recordName])
        #expect(applier.appliedRecordNames == [
            resolvedRecord.recordID.recordName,
            unresolvedRecord.recordID.recordName
        ])
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
    @Test func recordApplierInsertsRemoteGachaAndShopPurchaseFacts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let ownerId = uuid("77777777-7777-4777-8777-777777777777")
        let gachaId = uuid("88888888-8888-4888-8888-888888888888")
        let purchaseId = uuid("99999999-9999-4999-8999-999999999999")
        let owner = Human(name: "Guan")
        owner.id = ownerId
        context.insert(owner)

        let gachaRecord = try makeRecordPayload(
            entityName: String(describing: GachaOwnedItem.self),
            recordType: String(describing: GachaOwnedItem.self),
            localRecordId: gachaId,
            householdId: householdId,
            fields: [
                "ownerHumanId": .string(ownerId.uuidString),
                "seriesId": .string(GachaSeriesCatalog.defaultSeriesId),
                "itemId": .string("plush_coconut_sleepy"),
                "rarityRaw": .string(GachaRarity.common.rawValue),
                "isHidden": .bool(false),
                "ownedCount": .int(3),
                "firstObtainedAt": .date(Date(timeIntervalSinceReferenceDate: 10)),
                "latestObtainedAt": .date(Date(timeIntervalSinceReferenceDate: 20)),
                "createdAt": .date(Date(timeIntervalSinceReferenceDate: 10))
            ]
        ).makeCKRecord()
        let purchaseRecord = try makeRecordPayload(
            entityName: String(describing: ShopPurchaseRecord.self),
            recordType: String(describing: ShopPurchaseRecord.self),
            localRecordId: purchaseId,
            householdId: householdId,
            fields: [
                "transactionKey": .string("shop:fx_lime_glow:\(ownerId.uuidString)"),
                "itemId": .string("fx_lime_glow"),
                "buyerHumanId": .string(ownerId.uuidString),
                "purchasedAt": .date(Date(timeIntervalSinceReferenceDate: 30)),
                "sourceRaw": .string("shop"),
                "isLegacyImport": .bool(false),
                "createdAt": .date(Date(timeIntervalSinceReferenceDate: 30))
            ]
        ).makeCKRecord()

        let gachaResult = try CloudSyncRecordApplier.apply(gachaRecord, context: context)
        let purchaseResult = try CloudSyncRecordApplier.apply(purchaseRecord, context: context)

        #expect(gachaResult == .inserted(entityName: "GachaOwnedItem", localRecordId: normalized(gachaId)))
        #expect(purchaseResult == .inserted(entityName: "ShopPurchaseRecord", localRecordId: normalized(purchaseId)))
        let gachaItems = try context.fetch(FetchDescriptor<GachaOwnedItem>())
        let purchases = try context.fetch(FetchDescriptor<ShopPurchaseRecord>())
        #expect(gachaItems.first?.ownedCount == 3)
        #expect(gachaItems.first?.ownerHumanId == ownerId.uuidString)
        #expect(purchases.first?.itemId == "fx_lime_glow")
        #expect(purchases.first?.buyerHumanId == ownerId.uuidString)
    }

    @MainActor
    @Test func recordApplierSkipsMemberScopedFactsWithoutResolvedOwner() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let careLogId = uuid("11111111-1111-4111-8111-111111111111")
        let missingOwnerId = uuid("77777777-7777-4777-8777-777777777777")
        let gachaId = uuid("88888888-8888-4888-8888-888888888888")
        let careRecord = try makeRecordPayload(
            entityName: String(describing: PetCareLog.self),
            recordType: String(describing: PetCareLog.self),
            localRecordId: careLogId,
            householdId: householdId,
            fields: [
                "date": .date(Date(timeIntervalSinceReferenceDate: 2100)),
                "type": .string(CareType.feeding.rawValue),
                "amountGrams": .double(12),
                "foodKindRaw": .string(FeedFoodKind.dry.rawValue)
            ]
        ).makeCKRecord()
        let gachaRecord = try makeRecordPayload(
            entityName: String(describing: GachaOwnedItem.self),
            recordType: String(describing: GachaOwnedItem.self),
            localRecordId: gachaId,
            householdId: householdId,
            fields: [
                "ownerHumanId": .string(missingOwnerId.uuidString),
                "seriesId": .string(GachaSeriesCatalog.defaultSeriesId),
                "itemId": .string("plush_coconut_sleepy"),
                "rarityRaw": .string(GachaRarity.common.rawValue),
                "isHidden": .bool(false),
                "ownedCount": .int(1),
                "firstObtainedAt": .date(Date(timeIntervalSinceReferenceDate: 10)),
                "latestObtainedAt": .date(Date(timeIntervalSinceReferenceDate: 20)),
                "createdAt": .date(Date(timeIntervalSinceReferenceDate: 10))
            ]
        ).makeCKRecord()

        let careResult = try CloudSyncRecordApplier.apply(careRecord, context: context)
        let gachaResult = try CloudSyncRecordApplier.apply(gachaRecord, context: context)

        #expect(careResult == .skippedUnsupported(entityName: "PetCareLog"))
        #expect(gachaResult == .skippedUnsupported(entityName: "GachaOwnedItem"))
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GachaOwnedItem>()).isEmpty)
        #expect(try CloudSyncMetadataService.state(
            entityName: String(describing: PetCareLog.self),
            localRecordId: careLogId,
            context: context
        ) == nil)
        #expect(try CloudSyncMetadataService.state(
            entityName: String(describing: GachaOwnedItem.self),
            localRecordId: gachaId,
            context: context
        ) == nil)
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
                "executorIdsRaw": .string("executor-2|executor-3"),
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
        #expect(walkLog.executorIds == ["executor-2", "executor-3"])
        #expect(walkLog.sharedSessionId == "session-2")
        #expect(walkLog.behaviorNotes == "happy")
        #expect(walkLog.moodRating == 5)
    }

    @MainActor
    @Test func recordApplierInsertsRemoteSharedCareSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let sessionId = uuid("33333333-3333-4333-8333-333333333333")
        let sourcePetUUID = uuid("11111111-1111-4111-8111-111111111111")
        let targetPetUUID = uuid("22222222-2222-4222-8222-222222222222")
        let sourcePetId = normalized(sourcePetUUID)
        let targetPetId = normalized(targetPetUUID)
        let sessionDate = Date(timeIntervalSinceReferenceDate: 2400)
        let createdAt = Date(timeIntervalSinceReferenceDate: 2401)
        let sourcePet = Pet(name: "Momo")
        let targetPet = Pet(name: "Nori")
        sourcePet.id = sourcePetUUID
        targetPet.id = targetPetUUID
        context.insert(sourcePet)
        context.insert(targetPet)
        let record = try makeRecordPayload(
            entityName: String(describing: SharedCareSession.self),
            recordType: String(describing: SharedCareSession.self),
            localRecordId: sessionId,
            householdId: householdId,
            fields: [
                "date": .date(sessionDate),
                "actionKindRaw": .string(SharedCareActionKind.walk.rawValue),
                "executorId": .string("executor-2"),
                "executorIdsRaw": .string("executor-2|executor-3"),
                "sourcePetId": .string(sourcePetId),
                "targetPetIdsRaw": .string("\(sourcePetId)|\(targetPetId)"),
                "speciesRaw": .string("dog"),
                "totalAmountGrams": .double(0),
                "totalAmountMl": .double(0),
                "totalExpenseAmount": .double(0),
                "expenseCategoryRaw": .string(ExpenseCategory.other.rawValue),
                "currencyCode": .string("EUR"),
                "allocationModeRaw": .string(SharedCareAllocationMode.equal.rawValue),
                "foodKindRaw": .string(FeedFoodKind.dry.rawValue),
                "stockOwnerPetId": .string(""),
                "primaryLegacyModelName": .string(String(describing: PetWalkLog.self)),
                "primaryLegacyModelId": .string("walk-2"),
                "note": .string("remote walk"),
                "createdAt": .date(createdAt)
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .inserted(entityName: "SharedCareSession", localRecordId: normalized(sessionId)))
        let session = try #require(try fetchSharedCareSession(id: sessionId, context: context))
        #expect(session.date == sessionDate)
        #expect(session.actionKind == .walk)
        #expect(session.executorId == "executor-2")
        #expect(session.executorIds == ["executor-2", "executor-3"])
        #expect(session.sourcePetId == sourcePetId)
        #expect(session.targetPetIds == [sourcePetId, targetPetId])
        #expect(session.speciesRaw == "dog")
        #expect(session.currencyCode == "EUR")
        #expect(session.primaryLegacyModelName == String(describing: PetWalkLog.self))
        #expect(session.primaryLegacyModelId == "walk-2")
        #expect(session.note == "remote walk")
        #expect(session.createdAt == createdAt)
    }

    @MainActor
    @Test func recordApplierInsertsAndUpdatesRemoteCareLedgerEvent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let eventId = uuid("44444444-4444-4444-8444-444444444444")
        let occurredAt = Date(timeIntervalSinceReferenceDate: 2450)
        let createdAt = Date(timeIntervalSinceReferenceDate: 2451)
        let record = try makeRecordPayload(
            entityName: String(describing: CareLedgerEvent.self),
            recordType: String(describing: CareLedgerEvent.self),
            localRecordId: eventId,
            householdId: householdId,
            fields: [
                "occurredAt": .date(occurredAt),
                "actorKind": .string(CareLedgerActorKind.human.rawValue),
                "actorId": .string("human-1"),
                "subjectKind": .string(CareLedgerSubjectKind.pet.rawValue),
                "subjectId": .string("pet-1"),
                "eventKind": .string(CareLedgerEventKind.care.rawValue),
                "actionType": .string(CareType.feeding.rawValue),
                "amountValue": .double(25),
                "amountUnit": .string("g"),
                "note": .string("remote dinner"),
                "source": .string(CareLedgerSource.quickAction.rawValue),
                "sourceEventId": .string("event-1"),
                "sourceReminderId": .string("reminder-1"),
                "legacyModelName": .string(String(describing: PetCareLog.self)),
                "legacyModelId": .string("care-log-1"),
                "coconutDelta": .int(2),
                "rewardLogId": .string("reward-1"),
                "privacyFieldRaw": .string("care"),
                "metadataJSON": .string(#"{"sharedSessionId":"session-1"}"#),
                "createdAt": .date(createdAt)
            ]
        ).makeCKRecord()

        let insertResult = try CloudSyncRecordApplier.apply(record, context: context)
        let event = try #require(try fetchCareLedgerEvent(id: eventId, context: context))

        #expect(insertResult == .inserted(entityName: "CareLedgerEvent", localRecordId: normalized(eventId)))
        #expect(event.occurredAt == occurredAt)
        #expect(event.actorKind == CareLedgerActorKind.human.rawValue)
        #expect(event.actorId == "human-1")
        #expect(event.subjectKind == CareLedgerSubjectKind.pet.rawValue)
        #expect(event.subjectId == "pet-1")
        #expect(event.eventKind == CareLedgerEventKind.care.rawValue)
        #expect(event.actionType == CareType.feeding.rawValue)
        #expect(event.amountValue == 25)
        #expect(event.amountUnit == "g")
        #expect(event.note == "remote dinner")
        #expect(event.source == CareLedgerSource.quickAction.rawValue)
        #expect(event.legacyModelName == String(describing: PetCareLog.self))
        #expect(event.legacyModelId == "care-log-1")
        #expect(event.metadataJSON == #"{"sharedSessionId":"session-1"}"#)
        #expect(event.createdAt == createdAt)

        let cleanedRecord = try makeRecordPayload(
            entityName: String(describing: CareLedgerEvent.self),
            recordType: String(describing: CareLedgerEvent.self),
            localRecordId: eventId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 2460),
            fields: [
                "note": .string("clean dinner"),
                "metadataJSON": .string(#"{"sharedSessionId":"session-1","cleaned":true}"#)
            ]
        ).makeCKRecord()

        let updateResult = try CloudSyncRecordApplier.apply(cleanedRecord, context: context)

        #expect(updateResult == .updated(entityName: "CareLedgerEvent", localRecordId: normalized(eventId)))
        #expect(event.note == "clean dinner")
        #expect(event.metadataJSON == #"{"sharedSessionId":"session-1","cleaned":true}"#)
    }

    @MainActor
    @Test func recordApplierReplaysRemoteCoconutLedgerIntoWalletProjection() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let humanId = uuid("77777777-7777-4777-8777-777777777777")
        let ledgerId = uuid("88888888-8888-4888-8888-888888888888")
        let human = Human(name: "Guan")
        human.id = humanId
        context.insert(human)

        let record = try makeRecordPayload(
            entityName: String(describing: CoconutLedgerEntry.self),
            recordType: String(describing: CoconutLedgerEntry.self),
            localRecordId: ledgerId,
            householdId: householdId,
            fields: [
                "transactionKey": .string("remote-ledger-reward"),
                "accountKey": .string(CoconutAccountKey.human(humanId)),
                "ownerKindRaw": .string(CoconutWalletOwnerKind.human.rawValue),
                "ownerId": .string(normalized(humanId)),
                "ownerName": .string("Guan"),
                "delta": .int(7),
                "balanceBefore": .int(0),
                "balanceAfter": .int(7),
                "affectsBalance": .bool(true),
                "entryKindRaw": .string(CoconutWalletEntryKind.reward.rawValue),
                "sourceRaw": .string(CoconutWalletSource.careEvent.rawValue),
                "title": .string("Remote care reward"),
                "emoji": .string("coconut"),
                "subjectKindRaw": .string(CareLedgerSubjectKind.human.rawValue),
                "subjectId": .string(normalized(humanId)),
                "occurredAt": .date(Date(timeIntervalSinceReferenceDate: 2500)),
                "createdAt": .date(Date(timeIntervalSinceReferenceDate: 2501))
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)
        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())

        #expect(result == .inserted(entityName: "CoconutLedgerEntry", localRecordId: normalized(ledgerId)))
        #expect(accounts.first { $0.accountKey == CoconutAccountKey.human(humanId) }?.balance == 7)
        #expect(human.coconutBalance == 7)
    }

    @MainActor
    @Test func recordApplierInsertsAndUpdatesRemoteFeedingScheduleAndFoodRecord() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let petId = uuid("33333333-3333-4333-8333-333333333333")
        let eventId = uuid("44444444-4444-4444-8444-444444444444")
        let recordId = uuid("66666666-6666-4666-8666-666666666666")
        let pet = Pet(name: "Momo")
        pet.id = petId
        context.insert(pet)
        let startDate = Date(timeIntervalSinceReferenceDate: 2470)
        let correctionDate = Date(timeIntervalSinceReferenceDate: 2480)

        let eventRecord = try makeRecordPayload(
            entityName: String(describing: Event.self),
            recordType: String(describing: Event.self),
            localRecordId: eventId,
            householdId: householdId,
            fields: [
                "title": .string("Remote breakfast"),
                "startDate": .date(startDate),
                "isAllDay": .bool(false),
                "eventType": .string(EventType.foodChange.rawValue),
                "relatedEntityType": .string(EntityKind.pet.rawValue),
                "relatedEntityId": .string(normalized(petId)),
                "recurrenceDays": .int(1),
                "isCompleted": .bool(false),
                "completedOccurrences": .stringList(["2470"]),
                "createdAt": .date(startDate),
                "feedRuleKindRaw": .string(FeedRuleKind.manualReminder.rawValue),
                "foodKindRaw": .string(FeedFoodKind.dry.rawValue),
                "feedAmountGrams": .double(45),
                "feedPlanGroupId": .string("plan-remote")
            ]
        ).makeCKRecord()
        let foodRecord = try makeRecordPayload(
            entityName: String(describing: PetFoodRecord.self),
            recordType: String(describing: PetFoodRecord.self),
            localRecordId: recordId,
            householdId: householdId,
            fields: [
                "brand": .string("Acme"),
                "dailyGrams": .double(45),
                "totalGrams": .double(1200),
                "foodKindRaw": .string(FeedFoodKind.dry.rawValue),
                "startDate": .date(startDate),
                "remainingCorrectionGrams": .double(900),
                "remainingCorrectionDate": .date(correctionDate),
                "notes": .string("remote stock"),
                "expenseId": .string("55555555-5555-4555-8555-555555555555"),
                "calculationModeRaw": .string(FeedStockCalculationMode.autoFeeder.rawValue),
                "executorId": .string("human-1"),
                "petId": .string(normalized(petId))
            ]
        ).makeCKRecord()

        let eventInsert = try CloudSyncRecordApplier.apply(eventRecord, context: context)
        let foodInsert = try CloudSyncRecordApplier.apply(foodRecord, context: context)
        let event = try #require(try fetchEvent(id: eventId, context: context))
        let stock = try #require(try fetchPetFoodRecord(id: recordId, context: context))

        #expect(eventInsert == .inserted(entityName: "Event", localRecordId: normalized(eventId)))
        #expect(foodInsert == .inserted(entityName: "PetFoodRecord", localRecordId: normalized(recordId)))
        #expect(event.title == "Remote breakfast")
        #expect(event.completedOccurrences == ["2470"])
        #expect(event.feedAmountGrams == 45)
        #expect(stock.brand == "Acme")
        #expect(stock.remainingCorrectionGrams == 900)
        #expect(stock.expenseId == uuid("55555555-5555-4555-8555-555555555555"))
        #expect(stock.pet?.id == petId)

        let updatedEventRecord = try makeRecordPayload(
            entityName: String(describing: Event.self),
            recordType: String(describing: Event.self),
            localRecordId: eventId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 2490),
            fields: [
                "title": .string("Remote dinner"),
                "feedAmountGrams": .double(60),
                "completedOccurrences": .stringList(["2470", "2490"])
            ]
        ).makeCKRecord()
        let updatedFoodRecord = try makeRecordPayload(
            entityName: String(describing: PetFoodRecord.self),
            recordType: String(describing: PetFoodRecord.self),
            localRecordId: recordId,
            householdId: householdId,
            lastModifiedAt: Date(timeIntervalSinceReferenceDate: 2491),
            fields: [
                "brand": .string("Acme Plus"),
                "remainingCorrectionGrams": .double(700),
                "petId": .string(normalized(petId))
            ]
        ).makeCKRecord()

        let eventUpdate = try CloudSyncRecordApplier.apply(updatedEventRecord, context: context)
        let foodUpdate = try CloudSyncRecordApplier.apply(updatedFoodRecord, context: context)

        #expect(eventUpdate == .updated(entityName: "Event", localRecordId: normalized(eventId)))
        #expect(foodUpdate == .updated(entityName: "PetFoodRecord", localRecordId: normalized(recordId)))
        #expect(event.title == "Remote dinner")
        #expect(event.feedAmountGrams == 60)
        #expect(event.completedOccurrences == ["2470", "2490"])
        #expect(stock.brand == "Acme Plus")
        #expect(stock.remainingCorrectionGrams == 700)
    }

    @MainActor
    @Test func recordApplierQuarantinedRemoteEventWithoutLocalRowDoesNotMarkSynced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let eventId = uuid("44444444-4444-4444-8444-444444444444")
        let eventRecord = try makeRecordPayload(
            entityName: String(describing: Event.self),
            recordType: String(describing: Event.self),
            localRecordId: eventId,
            householdId: householdId,
            fields: [
                "title": .string("Unknown remote plan"),
                "startDate": .date(Date(timeIntervalSinceReferenceDate: 2470)),
                "isAllDay": .bool(false),
                "eventType": .string(EventType.task.rawValue),
                "relatedEntityType": .string("new_remote_member_link"),
                "relatedEntityId": .string(UUID().uuidString),
                "recurrenceDays": .int(1),
                "isCompleted": .bool(false),
                "createdAt": .date(Date(timeIntervalSinceReferenceDate: 2470))
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(eventRecord, context: context)

        #expect(result == .skippedUnsupported(entityName: "Event"))
        #expect(try fetchEvent(id: eventId, context: context) == nil)
        #expect(try CloudSyncMetadataService.state(
            entityName: String(describing: Event.self),
            localRecordId: eventId,
            context: context
        ) == nil)
    }

    @MainActor
    @Test func recordApplierQuarantinedRemoteEventNeutralizesExistingScheduleAndCancelsReminder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let eventId = uuid("44444444-4444-4444-8444-555555555555")
        let pet = Pet(name: "Momo", species: "cat")
        let event = Event(
            title: "Local plan",
            startDate: Date(timeIntervalSinceReferenceDate: 2470),
            eventType: EventType.task.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.id = eventId
        event.recurrenceDays = 1
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSinceReferenceDate: 2480))
        reminder.notificationId = "quarantined-remote-reminder"
        event.reminders = [reminder]
        context.insert(pet)
        context.insert(event)
        context.insert(reminder)
        try context.save()
        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }
        let eventRecord = try makeRecordPayload(
            entityName: String(describing: Event.self),
            recordType: String(describing: Event.self),
            localRecordId: eventId,
            householdId: householdId,
            fields: [
                "title": .string("Unknown remote plan"),
                "startDate": .date(Date(timeIntervalSinceReferenceDate: 2470)),
                "isAllDay": .bool(false),
                "eventType": .string(EventType.task.rawValue),
                "relatedEntityType": .string("new_remote_member_link"),
                "relatedEntityId": .string(UUID().uuidString),
                "recurrenceDays": .int(1),
                "isCompleted": .bool(false),
                "createdAt": .date(Date(timeIntervalSinceReferenceDate: 2470))
            ]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(eventRecord, context: context)

        #expect(result == .updated(entityName: "Event", localRecordId: normalized(eventId)))
        #expect(event.relatedEntityType == EntityKind.pet.rawValue)
        #expect(event.relatedEntityId == pet.id.uuidString)
        #expect(event.isCompleted)
        #expect(event.recurrenceDays == 0)
        #expect(reminder.statusEnum == .skipped)
        #expect(scheduler.cancelledNotificationIds == ["quarantined-remote-reminder"])
        #expect(try CloudSyncMetadataService.state(
            entityName: String(describing: Event.self),
            localRecordId: eventId,
            context: context
        ) != nil)
    }

    @MainActor
    @Test func cloudSyncAppliedLegacySharedCareRecordsCleanOnceAndUploadCleanPayloads() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let firstPetId = uuid("11111111-1111-4111-8111-111111111111")
        let secondPetId = uuid("22222222-2222-4222-8222-222222222222")
        let sessionId = uuid("33333333-3333-4333-8333-333333333333")
        let firstLogId = uuid("44444444-4444-4444-8444-444444444444")
        let secondLogId = uuid("55555555-5555-4555-8555-555555555555")
        let ledgerEventId = uuid("66666666-6666-4666-8666-666666666666")
        let cleanupDate = Date(timeIntervalSinceReferenceDate: 2600)

        let records = try [
            makeRecordPayload(
                entityName: String(describing: Pet.self),
                recordType: String(describing: Pet.self),
                localRecordId: firstPetId,
                householdId: householdId,
                fields: [
                    "name": .string("Milo"),
                    "species": .string("cat")
                ]
            ).makeCKRecord(),
            makeRecordPayload(
                entityName: String(describing: Pet.self),
                recordType: String(describing: Pet.self),
                localRecordId: secondPetId,
                householdId: householdId,
                fields: [
                    "name": .string("Luna"),
                    "species": .string("cat")
                ]
            ).makeCKRecord(),
            makeRecordPayload(
                entityName: String(describing: SharedCareSession.self),
                recordType: String(describing: SharedCareSession.self),
                localRecordId: sessionId,
                householdId: householdId,
                fields: [
                    "date": .date(Date(timeIntervalSinceReferenceDate: 2500)),
                    "actionKindRaw": .string(SharedCareActionKind.feeding.rawValue),
                    "executorId": .string("human-1"),
                    "sourcePetId": .string(normalized(firstPetId)),
                    "targetPetIdsRaw": .string(""),
                    "speciesRaw": .string("cat"),
                    "totalAmountGrams": .double(0),
                    "allocationModeRaw": .string(SharedCareAllocationMode.equal.rawValue),
                    "foodKindRaw": .string(FeedFoodKind.dry.rawValue),
                    "stockOwnerPetId": .string(""),
                    "primaryLegacyModelName": .string(""),
                    "primaryLegacyModelId": .string(""),
                    "note": .string(SharedCareMetadata.legacyEncodedNote(
                        prefix: SharedCareMetadata.feedNotePrefix,
                        sessionId: sessionId,
                        targetCount: 2,
                        visibleNote: "Feed session"
                    )),
                    "createdAt": .date(Date(timeIntervalSinceReferenceDate: 2501))
                ]
            ).makeCKRecord(),
            makeRecordPayload(
                entityName: String(describing: PetCareLog.self),
                recordType: String(describing: PetCareLog.self),
                localRecordId: firstLogId,
                householdId: householdId,
                fields: [
                    "date": .date(Date(timeIntervalSinceReferenceDate: 2510)),
                    "petId": .string(normalized(firstPetId)),
                    "type": .string(CareType.feeding.rawValue),
                    "amountGrams": .double(61),
                    "foodKindRaw": .string(FeedFoodKind.dry.rawValue),
                    "sharedSessionId": .string(""),
                    "note": .string(SharedCareMetadata.legacyEncodedNote(
                        prefix: SharedCareMetadata.feedNotePrefix,
                        sessionId: sessionId,
                        stockTotalGrams: 121,
                        targetCount: 2,
                        visibleNote: "Dinner note"
                    ))
                ]
            ).makeCKRecord(),
            makeRecordPayload(
                entityName: String(describing: PetCareLog.self),
                recordType: String(describing: PetCareLog.self),
                localRecordId: secondLogId,
                householdId: householdId,
                fields: [
                    "date": .date(Date(timeIntervalSinceReferenceDate: 2511)),
                    "petId": .string(normalized(secondPetId)),
                    "type": .string(CareType.feeding.rawValue),
                    "amountGrams": .double(60),
                    "foodKindRaw": .string(FeedFoodKind.dry.rawValue),
                    "sharedSessionId": .string(normalized(sessionId)),
                    "note": .string(SharedCareMetadata.legacyEncodedNote(
                        prefix: SharedCareMetadata.feedNotePrefix,
                        sessionId: sessionId,
                        stockTotalGrams: 121,
                        isStockOwner: true,
                        targetCount: 2,
                        visibleNote: "Dinner note"
                    ))
                ]
            ).makeCKRecord(),
            makeRecordPayload(
                entityName: String(describing: CareLedgerEvent.self),
                recordType: String(describing: CareLedgerEvent.self),
                localRecordId: ledgerEventId,
                householdId: householdId,
                fields: [
                    "occurredAt": .date(Date(timeIntervalSinceReferenceDate: 2512)),
                    "actorKind": .string(CareLedgerActorKind.human.rawValue),
                    "actorId": .string("human-1"),
                    "subjectKind": .string(CareLedgerSubjectKind.pet.rawValue),
                    "subjectId": .string(normalized(firstPetId)),
                    "eventKind": .string(CareLedgerEventKind.care.rawValue),
                    "actionType": .string(CareType.feeding.rawValue),
                    "amountValue": .double(61),
                    "amountUnit": .string("g"),
                    "note": .string(SharedCareMetadata.legacyEncodedNote(
                        prefix: SharedCareMetadata.careNotePrefix,
                        sessionId: sessionId,
                        targetCount: 2,
                        visibleNote: "Ledger note"
                    )),
                    "source": .string(CareLedgerSource.quickAction.rawValue),
                    "metadataJSON": .string(#"{"sharedSessionId":"legacy"}"#),
                    "createdAt": .date(Date(timeIntervalSinceReferenceDate: 2513))
                ]
            ).makeCKRecord()
        ]

        for record in records {
            _ = try CloudSyncRecordApplier.apply(record, context: context)
        }
        try context.save()

        #expect(try CloudSyncMetadataService.dirtyStates(context: context).isEmpty)

        let firstCleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
            context: context,
            cleanedAt: cleanupDate
        )
        let secondCleanup = SharedCareSessionMaintenance.cleanLegacyNoteMetadata(
            context: context,
            cleanedAt: Date(timeIntervalSinceReferenceDate: 2610)
        )
        let session = try #require(try fetchSharedCareSession(id: sessionId, context: context))
        let firstLog = try #require(try fetchPetCareLog(id: firstLogId, context: context))
        let secondLog = try #require(try fetchPetCareLog(id: secondLogId, context: context))
        let event = try #require(try fetchCareLedgerEvent(id: ledgerEventId, context: context))
        let sessionState = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: SharedCareSession.self),
            localRecordId: sessionId,
            context: context
        ))

        #expect(firstCleanup.cleanedCount == 4)
        #expect(firstCleanup.skippedOrphanCount == 0)
        #expect(secondCleanup.cleanedCount == 0)
        #expect(secondCleanup.skippedOrphanCount == 0)
        #expect(session.note == "Feed session")
        #expect(Set(session.targetPetIds.map { $0.lowercased() }) == Set([normalized(firstPetId), normalized(secondPetId)]))
        #expect(session.totalAmountGrams == 121)
        #expect(session.stockOwnerPetId.lowercased() == normalized(secondPetId))
        #expect(firstLog.note == "Dinner note")
        #expect(firstLog.sharedSessionId.lowercased() == normalized(sessionId))
        #expect(secondLog.note == "Dinner note")
        #expect(secondLog.sharedSessionId.lowercased() == normalized(sessionId))
        #expect(event.note == "Ledger note")
        #expect(sessionState.hasPendingLocalChanges)
        #expect(sessionState.lastModifiedAt == cleanupDate)

        let payloads = try CloudSyncUploadBatchBuilder.dirtyPayloads(context: context)
        let payloadNotes = payloads.compactMap { $0.fields["note"]?.stringValue }
        let carePayloads = payloads.filter { $0.entityName == String(describing: PetCareLog.self) }
        let sessionPayload = try #require(payloads.first { $0.entityName == String(describing: SharedCareSession.self) })
        let sessionTargets = try #require(sessionPayload.fields["targetPetIdsRaw"]?.stringValue)
            .split(separator: "|")
            .map { String($0).lowercased() }

        #expect(payloads.map(\.entityName).contains(String(describing: SharedCareSession.self)))
        #expect(payloads.map(\.entityName).contains(String(describing: CareLedgerEvent.self)))
        #expect(carePayloads.count == 2)
        #expect(payloadNotes.allSatisfy { !$0.contains(SharedCareMetadata.legacyMetadataMarker) })
        #expect(carePayloads.allSatisfy { $0.fields["sharedSessionId"]?.stringValue?.lowercased() == normalized(sessionId) })
        #expect(Set(sessionTargets) == Set([normalized(firstPetId), normalized(secondPetId)]))
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
        #expect(state.isDeletionTombstone)
        #expect(!state.hasPendingLocalChanges)
        #expect(state.deletedAt == deletedAt)
    }

    @MainActor
    @Test func recordApplierRemotePetTombstoneCascadesDerivedState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let petId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let survivorId = uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4100)
        let pet = Pet(name: "Milo", species: "cat")
        pet.id = petId
        let survivor = Pet(name: "Luna", species: "cat")
        survivor.id = survivorId
        let session = SharedCareSession(
            date: Date(timeIntervalSinceReferenceDate: 100),
            actionKind: .feeding,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString, survivor.id.uuidString],
            species: "cat",
            totalAmountGrams: 120,
            stockOwnerPetId: pet.id.uuidString
        )
        let deletedLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 60,
            sharedSessionId: session.id.uuidString,
            pet: pet
        )
        let survivorLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 60,
            sharedSessionId: session.id.uuidString,
            pet: survivor
        )
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            displayName: pet.name,
            balance: 12
        )
        let walletEntry = CoconutLedgerEntry(
            transactionKey: "remote-delete-pet-wallet-entry",
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            ownerName: pet.name,
            delta: 12,
            balanceBefore: 0,
            balanceAfter: 12,
            entryKind: .reward,
            source: .careEvent,
            title: "Reward",
            emoji: "coconut",
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            sourceModelName: "PetCareLog",
            sourceModelId: deletedLog.id.uuidString
        )
        let careLedger = CareLedgerEvent(
            occurredAt: session.date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: deletedLog.id.uuidString
        )
        context.insert(pet)
        context.insert(survivor)
        context.insert(session)
        context.insert(deletedLog)
        context.insert(survivorLog)
        context.insert(account)
        context.insert(walletEntry)
        context.insert(careLedger)
        try context.save()

        let record = try makeRecordPayload(
            entityName: String(describing: Pet.self),
            recordType: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLedgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())
        #expect(result == .deleted(entityName: "Pet", localRecordId: normalized(petId)))
        #expect(try fetchPet(id: petId, context: context) == nil)
        #expect(accounts.allSatisfy { $0.ownerId != pet.id.uuidString })
        #expect(walletEntries.allSatisfy { $0.ownerId != pet.id.uuidString && $0.subjectId != pet.id.uuidString })
        #expect(careLedgers.allSatisfy { $0.subjectId != pet.id.uuidString && $0.legacyModelId != deletedLog.id.uuidString })
        #expect(careLogs.allSatisfy { $0.pet?.id != pet.id })
        #expect(careLogs.contains { $0.pet?.id == survivor.id })
        #expect(sessions.allSatisfy { session in
            !session.targetPetIds.contains(pet.id.uuidString)
                && session.sourcePetId != pet.id.uuidString
                && session.stockOwnerPetId != pet.id.uuidString
        })
        #expect(CoconutWalletService.totalBalance(context: context) == 0)
    }

    @MainActor
    @Test func recordApplierRemoteLedgerTombstoneReplaysWalletProjection() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let humanId = uuid("22222222-2222-4222-8222-222222222222")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let ledgerId = uuid("dddddddd-dddd-4ddd-8ddd-dddddddddddd")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4200)
        let human = Human(name: "Avery")
        human.id = humanId
        human.coconutBalance = 10
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            displayName: human.name,
            balance: 10
        )
        let entry = CoconutLedgerEntry(
            id: ledgerId,
            transactionKey: "remote-ledger-delete",
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            ownerName: human.name,
            delta: 10,
            balanceBefore: 0,
            balanceAfter: 10,
            entryKind: .reward,
            source: .careEvent,
            title: "Reward",
            emoji: "coconut",
            occurredAt: Date(timeIntervalSinceReferenceDate: 100)
        )
        context.insert(human)
        context.insert(account)
        context.insert(entry)
        try context.save()

        let record = try makeRecordPayload(
            entityName: String(describing: CoconutLedgerEntry.self),
            recordType: String(describing: CoconutLedgerEntry.self),
            localRecordId: ledgerId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "CoconutLedgerEntry", localRecordId: normalized(ledgerId)))
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(account.balance == 0)
        #expect(human.coconutBalance == 0)
    }

    @MainActor
    @Test func recordApplierRemoteEventTombstoneCancelsReminderBoundary() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let eventId = uuid("11111111-1111-4111-8111-111111111111")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4300)
        let event = Event(
            title: "Vet visit",
            startDate: Date(timeIntervalSinceReferenceDate: 100),
            eventType: EventType.vetVisit.rawValue
        )
        event.id = eventId
        let reminder = Reminder(event: event, scheduledAt: Date(timeIntervalSinceReferenceDate: 90))
        reminder.id = uuid("22222222-2222-4222-8222-222222222222")
        reminder.notificationId = "remote-event-reminder"
        event.reminders = [reminder]
        context.insert(event)
        context.insert(reminder)
        try context.save()

        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }
        let record = try makeRecordPayload(
            entityName: String(describing: Event.self),
            recordType: String(describing: Event.self),
            localRecordId: eventId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "Event", localRecordId: normalized(eventId)))
        #expect(try fetchEvent(id: eventId, context: context) == nil)
        #expect(try fetchReminder(id: reminder.id, context: context) == nil)
        #expect(scheduler.cancelledNotificationIds == ["remote-event-reminder"])
    }

    @MainActor
    @Test func recordApplierRemoteSharedCareSessionTombstoneCascadesChildrenAndLedger() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let sessionId = uuid("11111111-1111-4111-8111-111111111111")
        let petId = uuid("22222222-2222-4222-8222-222222222222")
        let careLogId = uuid("33333333-3333-4333-8333-333333333333")
        let expenseLogId = uuid("44444444-4444-4444-8444-444444444444")
        let ledgerId = uuid("55555555-5555-4555-8555-555555555555")
        let stockEventId = uuid("66666666-6666-4666-8666-666666666666")
        let stockReminderId = uuid("77777777-7777-4777-8777-777777777777")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4400)
        let pet = Pet(name: "Momo")
        pet.id = petId
        pet.dailyPortionGrams = 100
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 2
        let session = SharedCareSession(
            date: Date(timeIntervalSinceReferenceDate: 120),
            actionKind: .feeding,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString],
            primaryLegacyModelName: String(describing: PetCareLog.self),
            primaryLegacyModelId: careLogId.uuidString
        )
        session.id = sessionId
        let careLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 40,
            sharedSessionId: session.id.uuidString,
            pet: pet
        )
        careLog.id = careLogId
        let expense = PetExpenseLog(
            date: session.date,
            amount: 12,
            category: .other,
            note: "Shared supplies",
            pet: pet,
            sharedSessionId: session.id.uuidString
        )
        expense.id = expenseLogId
        let ledger = CareLedgerEvent(
            id: ledgerId,
            occurredAt: session.date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: String(describing: PetCareLog.self),
            legacyModelId: careLog.id.uuidString
        )
        let staleEvent = Event(
            title: "Old stock reminder",
            startDate: Date(timeIntervalSinceReferenceDate: 900),
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
            relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
        )
        staleEvent.id = stockEventId
        staleEvent.foodKindRaw = FeedFoodKind.dry.rawValue
        let staleReminder = Reminder(event: staleEvent, scheduledAt: staleEvent.startDate)
        staleReminder.id = stockReminderId
        staleReminder.notificationId = "remote-shared-stock-reminder"
        staleEvent.reminders = [staleReminder]
        context.insert(pet)
        context.insert(session)
        context.insert(careLog)
        context.insert(expense)
        context.insert(ledger)
        context.insert(staleEvent)
        context.insert(staleReminder)
        try context.save()

        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }
        let record = try makeRecordPayload(
            entityName: String(describing: SharedCareSession.self),
            recordType: String(describing: SharedCareSession.self),
            localRecordId: sessionId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "SharedCareSession", localRecordId: normalized(sessionId)))
        #expect(try fetchSharedCareSession(id: sessionId, context: context) == nil)
        #expect(try fetchPetCareLog(id: careLogId, context: context) == nil)
        #expect(try fetchPetExpenseLog(id: expenseLogId, context: context) == nil)
        #expect(try fetchCareLedgerEvent(id: ledgerId, context: context) == nil)
        #expect(try fetchEvent(id: stockEventId, context: context) == nil)
        #expect(try fetchReminder(id: stockReminderId, context: context) == nil)
        #expect(scheduler.cancelledNotificationIds == ["remote-shared-stock-reminder"])
    }

    @MainActor
    @Test func recordApplierRemotePetCareLogTombstoneReconcilesLedgerAndSharedSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let sessionId = uuid("11111111-1111-4111-8111-111111111111")
        let petId = uuid("22222222-2222-4222-8222-222222222222")
        let careLogId = uuid("33333333-3333-4333-8333-333333333333")
        let ledgerId = uuid("44444444-4444-4444-8444-444444444444")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4500)
        let pet = Pet(name: "Momo")
        pet.id = petId
        let session = SharedCareSession(
            date: Date(timeIntervalSinceReferenceDate: 130),
            actionKind: .feeding,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString],
            primaryLegacyModelName: String(describing: PetCareLog.self),
            primaryLegacyModelId: careLogId.uuidString
        )
        session.id = sessionId
        let careLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 40,
            sharedSessionId: session.id.uuidString,
            pet: pet
        )
        careLog.id = careLogId
        let ledger = CareLedgerEvent(
            id: ledgerId,
            occurredAt: session.date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: String(describing: PetCareLog.self),
            legacyModelId: careLog.id.uuidString
        )
        context.insert(pet)
        context.insert(session)
        context.insert(careLog)
        context.insert(ledger)
        try context.save()

        let record = try makeRecordPayload(
            entityName: String(describing: PetCareLog.self),
            recordType: String(describing: PetCareLog.self),
            localRecordId: careLogId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "PetCareLog", localRecordId: normalized(careLogId)))
        #expect(try fetchPetCareLog(id: careLogId, context: context) == nil)
        #expect(try fetchCareLedgerEvent(id: ledgerId, context: context) == nil)
        #expect(try fetchSharedCareSession(id: sessionId, context: context) == nil)
    }

    @MainActor
    @Test func recordApplierRemoteFeedingLogTombstoneRebuildsStockReminder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let petId = uuid("11111111-1111-4111-8111-111111111111")
        let careLogId = uuid("22222222-2222-4222-8222-222222222222")
        let stockEventId = uuid("33333333-3333-4333-8333-333333333333")
        let stockReminderId = uuid("44444444-4444-4444-8444-444444444444")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4550)
        let pet = Pet(name: "Momo")
        pet.id = petId
        pet.dailyPortionGrams = 100
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 2
        let foodRecord = PetFoodRecord(
            brand: "Dry stock",
            dailyGrams: 100,
            totalGrams: 1000,
            foodKind: .dry,
            startDate: Date(timeIntervalSinceReferenceDate: 100),
            pet: pet
        )
        let careLog = PetCareLog(
            date: Date(timeIntervalSinceReferenceDate: 200),
            type: .feeding,
            amountGrams: 40,
            foodKind: .dry,
            pet: pet
        )
        careLog.id = careLogId
        let staleEvent = Event(
            title: "Old stock reminder",
            startDate: Date(timeIntervalSinceReferenceDate: 900),
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
            relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
        )
        staleEvent.id = stockEventId
        staleEvent.foodKindRaw = FeedFoodKind.dry.rawValue
        let staleReminder = Reminder(event: staleEvent, scheduledAt: staleEvent.startDate)
        staleReminder.id = stockReminderId
        staleReminder.notificationId = "remote-feed-stock-reminder"
        staleEvent.reminders = [staleReminder]
        context.insert(pet)
        context.insert(foodRecord)
        context.insert(careLog)
        context.insert(staleEvent)
        context.insert(staleReminder)
        try context.save()

        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }
        let record = try makeRecordPayload(
            entityName: String(describing: PetCareLog.self),
            recordType: String(describing: PetCareLog.self),
            localRecordId: careLogId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "PetCareLog", localRecordId: normalized(careLogId)))
        #expect(try fetchPetCareLog(id: careLogId, context: context) == nil)
        #expect(try fetchEvent(id: stockEventId, context: context) == nil)
        #expect(try fetchReminder(id: stockReminderId, context: context) == nil)
        #expect(scheduler.cancelledNotificationIds == ["remote-feed-stock-reminder"])
    }

    @MainActor
    @Test func recordApplierRemotePetFoodRecordTombstoneRebuildsStockReminder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let petId = uuid("55555555-5555-4555-8555-555555555555")
        let foodRecordId = uuid("66666666-6666-4666-8666-666666666666")
        let stockEventId = uuid("77777777-7777-4777-8777-777777777777")
        let stockReminderId = uuid("88888888-8888-4888-8888-888888888888")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4560)
        let pet = Pet(name: "Momo")
        pet.id = petId
        pet.dailyPortionGrams = 100
        pet.foodReminderEnabled = true
        pet.foodReminderAdvanceDays = 2
        let foodRecord = PetFoodRecord(
            brand: "Dry stock",
            dailyGrams: 100,
            totalGrams: 1000,
            foodKind: .dry,
            startDate: Date(timeIntervalSinceReferenceDate: 100),
            pet: pet
        )
        foodRecord.id = foodRecordId
        let staleEvent = Event(
            title: "Old stock reminder",
            startDate: Date(timeIntervalSinceReferenceDate: 900),
            eventType: EventType.shoppingList.rawValue,
            relatedEntityType: FeedingPlanWriter.stockReminderEntityType,
            relatedEntityId: FeedingPlanWriter.stockReminderEntityId(pet: pet, foodKind: .dry)
        )
        staleEvent.id = stockEventId
        staleEvent.foodKindRaw = FeedFoodKind.dry.rawValue
        let staleReminder = Reminder(event: staleEvent, scheduledAt: staleEvent.startDate)
        staleReminder.id = stockReminderId
        staleReminder.notificationId = "remote-food-stock-reminder"
        staleEvent.reminders = [staleReminder]
        context.insert(pet)
        context.insert(foodRecord)
        context.insert(staleEvent)
        context.insert(staleReminder)
        try context.save()

        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }
        let record = try makeRecordPayload(
            entityName: String(describing: PetFoodRecord.self),
            recordType: String(describing: PetFoodRecord.self),
            localRecordId: foodRecordId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "PetFoodRecord", localRecordId: normalized(foodRecordId)))
        #expect(try fetchPetFoodRecord(id: foodRecordId, context: context) == nil)
        #expect(try fetchEvent(id: stockEventId, context: context) == nil)
        #expect(try fetchReminder(id: stockReminderId, context: context) == nil)
        #expect(scheduler.cancelledNotificationIds == ["remote-food-stock-reminder"])
    }

    @MainActor
    @Test func recordApplierRemotePetHealthLogTombstoneCascadesDerivedRecords() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let petId = uuid("11111111-1111-4111-8111-111111111111")
        let healthLogId = uuid("22222222-2222-4222-8222-222222222222")
        let eventId = uuid("33333333-3333-4333-8333-333333333333")
        let reminderId = uuid("44444444-4444-4444-8444-444444444444")
        let expenseId = uuid("55555555-5555-4555-8555-555555555555")
        let directLedgerId = uuid("66666666-6666-4666-8666-666666666666")
        let expenseLedgerId = uuid("77777777-7777-4777-8777-777777777777")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 4600)
        let date = Date(timeIntervalSinceReferenceDate: 200)
        let expirationDate = Date(timeIntervalSinceReferenceDate: 600)
        let pet = Pet(name: "Momo")
        pet.id = petId
        let health = PetHealthLog(date: date, type: .vaccine, note: "Rabies", pet: pet)
        health.id = healthLogId
        health.cost = 48
        health.expirationDate = expirationDate
        let event = Event(
            title: "Rabies expires",
            startDate: expirationDate,
            eventType: EventType.vaccine.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.id = eventId
        let reminder = Reminder(event: event, scheduledAt: expirationDate.addingTimeInterval(-86400))
        reminder.id = reminderId
        reminder.notificationId = "remote-health-reminder"
        event.reminders = [reminder]
        let expense = PetExpenseLog(
            date: date,
            amount: health.cost,
            category: .medical,
            note: health.note,
            pet: pet
        )
        expense.id = expenseId
        let directLedger = CareLedgerEvent(
            id: directLedgerId,
            occurredAt: date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: HealthLogType.vaccine.rawValue,
            source: .detail,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            legacyModelName: String(describing: PetHealthLog.self),
            legacyModelId: health.id.uuidString
        )
        let expenseLedger = CareLedgerEvent(
            id: expenseLedgerId,
            occurredAt: date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.medical.rawValue,
            source: .detail,
            legacyModelName: String(describing: PetExpenseLog.self),
            legacyModelId: expense.id.uuidString
        )
        context.insert(pet)
        context.insert(health)
        context.insert(event)
        context.insert(reminder)
        context.insert(expense)
        context.insert(directLedger)
        context.insert(expenseLedger)
        try context.save()

        let scheduler = CapturingReminderNotificationScheduler()
        OhanaNotifications.current = scheduler
        defer { OhanaNotifications.useLive() }
        let record = try makeRecordPayload(
            entityName: String(describing: PetHealthLog.self),
            recordType: String(describing: PetHealthLog.self),
            localRecordId: healthLogId,
            householdId: householdId,
            isDeleted: true,
            lastModifiedAt: deletedAt,
            fields: [CloudSyncRecordFieldKey.deletedAt: .date(deletedAt)]
        ).makeCKRecord()

        let result = try CloudSyncRecordApplier.apply(record, context: context)

        #expect(result == .deleted(entityName: "PetHealthLog", localRecordId: normalized(healthLogId)))
        #expect(try fetchPetHealthLog(id: healthLogId, context: context) == nil)
        #expect(try fetchEvent(id: eventId, context: context) == nil)
        #expect(try fetchReminder(id: reminderId, context: context) == nil)
        #expect(try fetchPetExpenseLog(id: expenseId, context: context) == nil)
        #expect(try fetchCareLedgerEvent(id: directLedgerId, context: context) == nil)
        #expect(try fetchCareLedgerEvent(id: expenseLedgerId, context: context) == nil)
        #expect(scheduler.cancelledNotificationIds == ["remote-health-reminder"])
    }

    @MainActor
    @Test func recordApplierAppliesCloudKitHardDeletionAsSyncedTombstone() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let petId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 5000)
        let pet = Pet(name: "Momo")
        pet.id = petId
        context.insert(pet)
        let recordName = CloudSyncZoneNaming.recordName(
            entityName: String(describing: Pet.self),
            localRecordId: normalized(petId)
        )
        let zoneName = CloudSyncZoneNaming.zoneName(forHouseholdId: normalized(householdId))
        let recordID = CKRecord.ID(
            recordName: recordName,
            zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        )
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 1000),
            context: context
        )
        CloudSyncMetadataService.markSynced(
            state,
            ckRecordName: recordID.recordName,
            ckChangeTag: "old-tag",
            ckZoneName: recordID.zoneID.zoneName,
            syncedAt: Date(timeIntervalSinceReferenceDate: 1200)
        )

        let result = try CloudSyncRecordApplier.applyHardDeletedRecord(
            recordID: recordID,
            recordType: String(describing: Pet.self),
            deletedAt: deletedAt,
            context: context
        )

        #expect(result == .deleted(entityName: "Pet", localRecordId: normalized(petId)))
        #expect(try fetchPet(id: petId, context: context) == nil)
        let tombstone = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            context: context
        ))
        #expect(tombstone.isDeleted)
        #expect(tombstone.isDeletionTombstone)
        #expect(!tombstone.hasPendingLocalChanges)
        #expect(tombstone.ckRecordName == recordName)
        #expect(tombstone.ckZoneName == zoneName)
        #expect(tombstone.ckChangeTag.isEmpty)
        #expect(tombstone.deletedAt == deletedAt)
    }

    @MainActor
    @Test func recordApplierAppliesHardDeletionUsingStoredCloudKitRecordIdentity() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let petId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let deletedAt = Date(timeIntervalSinceReferenceDate: 5200)
        let pet = Pet(name: "Momo")
        pet.id = petId
        context.insert(pet)
        let recordName = "legacy-pet-record-name"
        let zoneName = CloudSyncZoneNaming.zoneName(forHouseholdId: normalized(householdId))
        let recordID = CKRecord.ID(
            recordName: recordName,
            zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        )
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            modifiedAt: Date(timeIntervalSinceReferenceDate: 1000),
            context: context
        )
        CloudSyncMetadataService.markSynced(
            state,
            ckRecordName: recordID.recordName,
            ckChangeTag: "old-tag",
            ckZoneName: recordID.zoneID.zoneName,
            syncedAt: Date(timeIntervalSinceReferenceDate: 1200)
        )

        let result = try CloudSyncRecordApplier.applyHardDeletedRecord(
            recordID: recordID,
            recordType: String(describing: Pet.self),
            deletedAt: deletedAt,
            context: context
        )

        #expect(result == .deleted(entityName: "Pet", localRecordId: normalized(petId)))
        #expect(try fetchPet(id: petId, context: context) == nil)
        let tombstone = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            context: context
        ))
        #expect(tombstone.isDeletionTombstone)
        #expect(!tombstone.hasPendingLocalChanges)
        #expect(tombstone.ckRecordName == recordName)
        #expect(tombstone.ckZoneName == zoneName)
        #expect(tombstone.deletedAt == deletedAt)
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
    @Test func localStoreActorAppliesFetchedRecordDeletionsThroughRecordApplier() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let petId = uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let householdId = uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let pet = Pet(name: "Momo")
        pet.id = petId
        context.insert(pet)
        let recordName = CloudSyncZoneNaming.recordName(
            entityName: String(describing: Pet.self),
            localRecordId: normalized(petId)
        )
        let zoneName = CloudSyncZoneNaming.zoneName(forHouseholdId: normalized(householdId))
        let recordID = CKRecord.ID(
            recordName: recordName,
            zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        )
        let state = try CloudSyncMetadataService.markModified(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            householdId: householdId,
            context: context
        )
        CloudSyncMetadataService.markSynced(
            state,
            ckRecordName: recordID.recordName,
            ckChangeTag: "old-tag",
            ckZoneName: recordID.zoneID.zoneName
        )
        try context.save()

        let actor = CloudSyncLocalStoreActor(modelContainer: container)
        let summary = try await actor.applyFetchedRecordDeletions([
            CloudSyncFetchedRecordDeletion(
                recordID: recordID,
                recordType: String(describing: Pet.self)
            )
        ])

        #expect(summary.deleted == 1)
        let verificationContext = ModelContext(container)
        #expect(try fetchPet(id: petId, context: verificationContext) == nil)
        let tombstone = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: Pet.self),
            localRecordId: petId,
            context: verificationContext
        ))
        #expect(tombstone.isDeletionTombstone)
        #expect(!tombstone.hasPendingLocalChanges)
        #expect(tombstone.ckRecordName == recordName)
        #expect(tombstone.ckZoneName == zoneName)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV71.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func propertyListDictionary(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(object as? [String: Any])
    }

    private struct FailingCloudSyncAccountStatusProvider: CloudSyncAccountStatusProviding {
        func accountStatus() async throws -> CKAccountStatus {
            throw CKError(.networkFailure)
        }
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

    private func fetchEvent(id: UUID, context: ModelContext) throws -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchReminder(id: UUID, context: ModelContext) throws -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPetCareLog(id: UUID, context: ModelContext) throws -> PetCareLog? {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { $0.id == id }
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

    private func fetchPetFoodRecord(id: UUID, context: ModelContext) throws -> PetFoodRecord? {
        var descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPetExpenseLog(id: UUID, context: ModelContext) throws -> PetExpenseLog? {
        var descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchPetHealthLog(id: UUID, context: ModelContext) throws -> PetHealthLog? {
        var descriptor = FetchDescriptor<PetHealthLog>(
            predicate: #Predicate<PetHealthLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchSharedCareSession(id: UUID, context: ModelContext) throws -> SharedCareSession? {
        var descriptor = FetchDescriptor<SharedCareSession>(
            predicate: #Predicate<SharedCareSession> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchCareLedgerEvent(id: UUID, context: ModelContext) throws -> CareLedgerEvent? {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

private final class CapturingReminderNotificationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
    private(set) var cancelledNotificationIds: [String] = []

    func schedule(reminder _: Reminder) {}

    func schedule(
        reminder _: Reminder,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.skippedPastDue)
    }

    func schedule(
        reminder _: Reminder,
        deliveryDate _: Date?,
        existingNotificationIds _: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        completion?(.skippedPastDue)
    }

    func pendingNotificationIds() async -> Set<String> { [] }

    func scheduleRollingWindow(reminders _: [Reminder]) {}

    func refillWindowIfNeeded(allReminders _: [Reminder]) {}

    func cancel(notificationId: String) {
        cancelledNotificationIds.append(notificationId)
    }

    func cancelAll(for _: Pet, reminders: [Reminder]) {
        cancelledNotificationIds.append(contentsOf: reminders.map(\.notificationId))
    }

    func compensate(reminders _: [Reminder]) {}
}

private struct StaticCloudSyncUploadPayloadProvider: CloudSyncEngineUploadPayloadProviding {
    let payloads: [CloudSyncRecordPayload]

    func uploadPayloads() async throws -> [CloudSyncRecordPayload] {
        payloads
    }
}

private final class CapturingCloudSyncFetchedRecordApplier: CloudSyncEngineFetchedRecordApplying {
    private(set) var appliedRecordNames: [String] = []

    func applyFetchedRecords(_ records: [CKRecord]) async throws -> CloudSyncRecordApplySummary {
        appliedRecordNames.append(contentsOf: records.map(\.recordID.recordName))
        var summary = CloudSyncRecordApplySummary.empty
        summary.updated = records.count
        return summary
    }
}

private final class SelectiveFailingCloudSyncFetchedRecordApplier: CloudSyncEngineFetchedRecordApplying {
    private let failingRecordNames: Set<String>
    private(set) var appliedRecordNames: [String] = []

    init(failingRecordNames: Set<String>) {
        self.failingRecordNames = failingRecordNames
    }

    func applyFetchedRecords(_ records: [CKRecord]) async throws -> CloudSyncRecordApplySummary {
        appliedRecordNames.append(contentsOf: records.map(\.recordID.recordName))
        var summary = CloudSyncRecordApplySummary.empty
        for record in records {
            if failingRecordNames.contains(record.recordID.recordName) {
                summary.failed += 1
            } else {
                summary.updated += 1
            }
        }
        return summary
    }
}

private struct FailingCloudSyncFetchedRecordApplier: CloudSyncEngineFetchedRecordApplying {
    func applyFetchedRecords(_: [CKRecord]) async throws -> CloudSyncRecordApplySummary {
        var summary = CloudSyncRecordApplySummary.empty
        summary.failed = 1
        return summary
    }
}
