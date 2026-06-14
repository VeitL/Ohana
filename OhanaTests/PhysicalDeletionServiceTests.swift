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
