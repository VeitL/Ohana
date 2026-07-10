import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct MediaAttachmentPresenceBackfillBatchTests {
    @Test func batchRepairsOnlyItsFiniteCandidatePageAndResumesWithoutSkippingRows() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        for index in 0 ..< 3 {
            let pet = Pet(name: "Pet \(index)", species: "猫")
            pet.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
            pet.cardPopoutAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
            context.insert(pet)
        }
        try context.save()

        let actor = MediaAttachmentPresenceBackfillActor(modelContainer: container)
        let first = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(first.scannedRecordCount == 2)
        #expect(first.backfillResult.petAvatarChanges == 2)
        #expect(first.backfillResult.petCardPopoutChanges == 2)
        #expect(first.nextCursor.source == .pet)
        #expect(!first.didComplete)

        let second = try await actor.runBatch(
            cursor: first.nextCursor,
            maximumRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(second.scannedRecordCount == 1)
        #expect(second.backfillResult.petAvatarChanges == 1)
        #expect(second.backfillResult.petCardPopoutChanges == 1)
        #expect(second.didComplete)
        #expect(second.nextCursor.source == .complete)

        let verificationContext = ModelContext(container)
        let pets = try verificationContext.fetch(FetchDescriptor<Pet>())
        #expect(pets.count == 3)
        #expect(pets.allSatisfy { $0.avatarAttachmentState == .absent })
        #expect(pets.allSatisfy { $0.cardPopoutAttachmentState == .absent })
    }

    @Test func expiredDeadlineDoesNotAdvanceOrMarkTheBackfillComplete() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        pet.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        context.insert(pet)
        try context.save()

        let actor = MediaAttachmentPresenceBackfillActor(modelContainer: container)
        let result = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 4,
            deadline: Date().addingTimeInterval(-1)
        )

        #expect(result.scannedRecordCount == 0)
        #expect(!result.backfillResult.didChange)
        #expect(result.nextCursor == .initial)
        #expect(!result.didComplete)
    }

    @Test func actorBatchReachesCompletionAfterAnEmptyInitialStore() async throws {
        let container = try makeContainer()
        let actor = MediaAttachmentPresenceBackfillActor(modelContainer: container)

        let result = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 8,
            deadline: .distantFuture
        )

        #expect(result.scannedRecordCount == 0)
        #expect(result.nextCursor.source == .complete)
        #expect(result.didComplete)
    }

    @Test func explicitAbsentPhotoAndDocumentAttachmentStatesAreNotPromotedToPresent() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let photo = PetPhotoLog(imageData: Data([1, 2, 3]))
        photo.imageAttachmentStateRaw = PetPhotoAttachmentState.absent.rawValue
        let attachment = PetDocumentAttachment(data: Data([4, 5, 6]), filename: "empty.jpg", isImage: true)
        attachment.dataAttachmentStateRaw = PetDocumentAttachmentState.absent.rawValue
        context.insert(photo)
        context.insert(attachment)
        try context.save()

        let actor = MediaAttachmentPresenceBackfillActor(modelContainer: container)
        let result = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 16,
            deadline: .distantFuture
        )

        #expect(result.didComplete)
        #expect(result.backfillResult.petPhotoLogChanges == 0)
        #expect(result.backfillResult.documentAttachmentChanges == 0)

        let verificationContext = ModelContext(container)
        let photos = try verificationContext.fetch(FetchDescriptor<PetPhotoLog>())
        let attachments = try verificationContext.fetch(FetchDescriptor<PetDocumentAttachment>())
        #expect(photos.first?.imageAttachmentState == .absent)
        #expect(attachments.first?.dataAttachmentState == .absent)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
