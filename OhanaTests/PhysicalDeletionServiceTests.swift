import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct PhysicalDeletionServiceTests {
    @Test func deleteDocumentPhysicallyDeletesAttachmentsAndWritesTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo")
        let document = PetDocument(title: "Passport", category: .passport, pet: pet)
        let attachment = PetDocumentAttachment(data: Data([1, 2, 3]), filename: "scan.jpg", isImage: true)
        document.attachments = [attachment]

        context.insert(pet)
        context.insert(document)
        context.insert(attachment)
        try context.save()

        PhysicalDeletionService.deleteDocument(document, pet: pet, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PetDocument>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetDocumentAttachment>()).isEmpty)
        #expect(deletionTombstone(PetDocument.self, id: document.id, context: context) != nil)
        #expect(deletionTombstone(PetDocumentAttachment.self, id: attachment.id, context: context) != nil)
    }

    @Test func deletePetPhysicallyDeletesCareFactsAndWritesTombstones() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo")
        let careLog = PetCareLog(type: .feeding, pet: pet)
        let walkLog = PetWalkLog(pet: pet)

        context.insert(pet)
        context.insert(careLog)
        context.insert(walkLog)
        try context.save()

        PhysicalDeletionService.deletePet(pet, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PetWalkLog>()).isEmpty)
        #expect(deletionTombstone(Pet.self, id: pet.id, context: context) != nil)
        #expect(deletionTombstone(PetCareLog.self, id: careLog.id, context: context) != nil)
        #expect(deletionTombstone(PetWalkLog.self, id: walkLog.id, context: context) != nil)
    }

    @Test func deletePetRemovesWalletLedgerAndSharedSessionReferences() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let deletedPet = Pet(name: "Milo", species: "猫")
        let survivor = Pet(name: "Luna", species: "猫")
        let session = SharedCareSession(
            date: Date(timeIntervalSinceReferenceDate: 10),
            actionKind: .feeding,
            sourcePetId: deletedPet.id.uuidString,
            targetPetIds: [deletedPet.id.uuidString, survivor.id.uuidString],
            species: "猫",
            totalAmountGrams: 120,
            stockOwnerPetId: deletedPet.id.uuidString
        )
        let deletedLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 60,
            sharedSessionId: session.id.uuidString,
            pet: deletedPet
        )
        let survivorLog = PetCareLog(
            date: session.date,
            type: .feeding,
            amountGrams: 60,
            sharedSessionId: session.id.uuidString,
            pet: survivor
        )
        let account = CoconutAccount(
            accountKey: CoconutAccountKey.pet(deletedPet.id),
            ownerKind: .pet,
            ownerId: deletedPet.id.uuidString,
            displayName: deletedPet.name,
            balance: 12
        )
        let walletEntry = CoconutLedgerEntry(
            transactionKey: "delete-pet-wallet-entry",
            accountKey: CoconutAccountKey.pet(deletedPet.id),
            ownerKind: .pet,
            ownerId: deletedPet.id.uuidString,
            ownerName: deletedPet.name,
            delta: 12,
            balanceBefore: 0,
            balanceAfter: 12,
            entryKind: .reward,
            source: .careEvent,
            title: "Reward",
            emoji: "coconut"
        )
        let careLedger = CareLedgerEvent(
            occurredAt: session.date,
            actorKind: .unknown,
            subjectKind: .pet,
            subjectId: deletedPet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: deletedLog.id.uuidString
        )
        context.insert(deletedPet)
        context.insert(survivor)
        context.insert(session)
        context.insert(deletedLog)
        context.insert(survivorLog)
        context.insert(account)
        context.insert(walletEntry)
        context.insert(careLedger)
        try context.save()

        PhysicalDeletionService.deletePet(deletedPet, context: context)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<SharedCareSession>())
        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let careLedgers = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let careLogs = try context.fetch(FetchDescriptor<PetCareLog>())

        #expect(accounts.allSatisfy { $0.ownerId != deletedPet.id.uuidString })
        #expect(walletEntries.allSatisfy { $0.ownerId != deletedPet.id.uuidString && $0.subjectId != deletedPet.id.uuidString })
        #expect(careLedgers.allSatisfy { $0.subjectId != deletedPet.id.uuidString && $0.legacyModelId != deletedLog.id.uuidString })
        #expect(careLogs.allSatisfy { $0.pet?.id != deletedPet.id })
        #expect(careLogs.contains { $0.pet?.id == survivor.id })
        #expect(sessions.allSatisfy { session in
            !session.targetPetIds.contains(deletedPet.id.uuidString)
                && session.sourcePetId != deletedPet.id.uuidString
                && session.stockOwnerPetId != deletedPet.id.uuidString
        })
        #expect(sessions.first?.targetPetIds == [survivor.id.uuidString])
        #expect(sessions.first?.sourcePetId.isEmpty == true)
        #expect(sessions.first?.stockOwnerPetId.isEmpty == true)
        #expect(sessions.first?.totalAmountGrams == survivorLog.amountGrams)
        #expect(CoconutWalletService.totalBalance(context: context) == 0)
        #expect(deletionTombstone(CoconutLedgerEntry.self, id: walletEntry.id, context: context) != nil)
        #expect(deletionTombstone(CareLedgerEvent.self, id: careLedger.id, context: context) != nil)
    }

    @Test func careLedgerRecordEnqueuesCloudSyncDirtyState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = CareLedgerService.record(
            occurredAt: Date(timeIntervalSinceReferenceDate: 20),
            subjectKind: .pet,
            subjectId: UUID().uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            context: context
        )

        let state = try #require(try CloudSyncMetadataService.state(
            entityName: String(describing: CareLedgerEvent.self),
            localRecordId: event.id,
            context: context
        ))
        #expect(state.hasPendingLocalChanges)
        #expect(!state.isDeletionTombstone)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV72.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func deletionTombstone<T>(
        _: T.Type,
        id: UUID,
        context: ModelContext
    ) -> CloudSyncRecordState? {
        let key = CloudSyncRecordState.recordKey(entityName: String(describing: T.self), localRecordId: id)
        return (try? context.fetch(FetchDescriptor<CloudSyncRecordState>()))?
            .first { $0.recordKey == key && $0.isDeletionTombstone }
    }
}
