import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct MediaAttachmentUpgradeCompatibilityTests {
    @Test func unknownAttachmentStatesRemainLoadableAfterLightweightMigrationDefaults() throws {
        let avatarData = Data([1, 2, 3, 4])
        let photoData = Data([9, 10, 11, 12, 13, 14, 15, 16, 17])

        let pet = Pet(name: "Momo")
        pet.avatarImageData = avatarData
        pet.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        pet.avatarImageSignature = ""
        pet.cardPopoutImageData = avatarData
        pet.cardPopoutAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        pet.cardPopoutImageSignature = ""

        let human = Human(name: "Nico")
        human.avatarImageData = avatarData
        human.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        human.avatarImageSignature = ""

        let plant = Plant(name: "Fern")
        plant.avatarImageData = avatarData
        plant.avatarAttachmentStateRaw = PlantAvatarAttachmentState.unknown.rawValue
        plant.avatarImageSignature = ""

        let plantLog = PlantCareLog(careType: .photo, photoData: photoData)
        plantLog.photoAttachmentStateRaw = PlantCarePhotoAttachmentState.unknown.rawValue
        plantLog.photoImageSignature = ""

        let photoLog = PetPhotoLog(imageData: photoData)
        photoLog.imageAttachmentStateRaw = PetPhotoAttachmentState.unknown.rawValue
        photoLog.imageSignature = ""

        let document = PetDocument(title: "Passport")
        document.attachmentData = avatarData
        document.legacyAttachmentStateRaw = PetDocumentAttachmentState.unknown.rawValue
        document.legacyAttachmentSignature = ""

        let documentAttachment = PetDocumentAttachment(data: avatarData, filename: "scan.jpg", isImage: true)
        documentAttachment.dataAttachmentStateRaw = PetDocumentAttachmentState.unknown.rawValue
        documentAttachment.dataSignature = ""

        #expect(pet.hasAvatarImageAttachment)
        #expect(pet.avatarThumbnailSignature.hasPrefix("legacy:"))
        #expect(pet.hasCardPopoutImageAttachment)
        #expect(pet.cardPopoutThumbnailSignature.hasPrefix("legacy:"))
        #expect(human.hasAvatarImageAttachment)
        #expect(human.avatarThumbnailSignature.hasPrefix("legacy:"))
        #expect(plant.hasAvatarImageAttachment)
        #expect(plant.avatarThumbnailSignature.hasPrefix("legacy:"))
        #expect(plantLog.hasPhotoAttachment)
        #expect(plantLog.photoThumbnailSignature.hasPrefix("legacy:"))
        #expect(photoLog.canAttemptImageAttachmentLoad)
        #expect(photoLog.imageThumbnailSignature.hasPrefix("legacy:"))
        #expect(document.canAttemptLegacyAttachmentLoad)
        #expect(document.legacyAttachmentThumbnailSignature.hasPrefix("legacy:"))
        #expect(documentAttachment.canAttemptDataAttachmentLoad)
        #expect(documentAttachment.dataThumbnailSignature.hasPrefix("legacy:"))
    }

    @Test func presenceBackfillMarksLegacyBlobsWithoutComputingSignatures() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let data = Data([1, 2, 3, 4])
        let photoData = Data([9, 10, 11, 12, 13, 14, 15, 16, 17])

        let pet = Pet(name: "Momo")
        pet.avatarImageData = data
        pet.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        pet.avatarImageSignature = ""
        pet.cardPopoutImageData = nil
        pet.cardPopoutAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        pet.cardPopoutImageSignature = "stale"

        let human = Human(name: "Nico")
        human.avatarImageData = nil
        human.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        human.avatarImageSignature = "stale"

        let plant = Plant(name: "Fern")
        plant.avatarImageData = data
        plant.avatarAttachmentStateRaw = PlantAvatarAttachmentState.unknown.rawValue
        plant.avatarImageSignature = ""

        let plantLog = PlantCareLog(careType: .photo, photoData: photoData)
        plantLog.photoAttachmentStateRaw = PlantCarePhotoAttachmentState.unknown.rawValue
        plantLog.photoImageSignature = ""

        let emptyPlantLog = PlantCareLog(careType: .photo, photoData: nil)
        emptyPlantLog.photoAttachmentStateRaw = PlantCarePhotoAttachmentState.unknown.rawValue
        emptyPlantLog.photoImageSignature = "stale"

        let milestone = PetMilestone(title: "First day", photoData: data)
        milestone.photoAttachmentStateRaw = PetMilestonePhotoAttachmentState.unknown.rawValue
        milestone.photoImageSignature = ""

        let photoLog = PetPhotoLog(imageData: photoData)
        photoLog.imageAttachmentStateRaw = PetPhotoAttachmentState.unknown.rawValue
        photoLog.imageSignature = ""

        let document = PetDocument(title: "Passport")
        document.attachmentData = data
        document.attachmentFilename = "passport.jpg"
        document.legacyAttachmentStateRaw = PetDocumentAttachmentState.unknown.rawValue
        document.legacyAttachmentSignature = ""

        let emptyDocument = PetDocument(title: "Empty")
        emptyDocument.attachmentData = nil
        emptyDocument.attachmentFilename = "stale.jpg"
        emptyDocument.legacyAttachmentStateRaw = PetDocumentAttachmentState.unknown.rawValue
        emptyDocument.legacyAttachmentSignature = "stale"

        let documentAttachment = PetDocumentAttachment(data: data, filename: "scan.jpg", isImage: true)
        documentAttachment.dataAttachmentStateRaw = PetDocumentAttachmentState.unknown.rawValue
        documentAttachment.dataSignature = ""

        context.insert(pet)
        context.insert(human)
        context.insert(plant)
        context.insert(plantLog)
        context.insert(emptyPlantLog)
        context.insert(milestone)
        context.insert(photoLog)
        context.insert(document)
        context.insert(emptyDocument)
        context.insert(documentAttachment)
        try context.save()

        let result = MediaAttachmentPresenceBackfillService.run(context: context)

        #expect(result.didChange)
        #expect(pet.avatarAttachmentState == .present)
        #expect(pet.avatarImageSignature.isEmpty)
        #expect(pet.cardPopoutAttachmentState == .absent)
        #expect(pet.cardPopoutImageSignature.isEmpty)
        #expect(human.avatarAttachmentState == .absent)
        #expect(human.avatarImageSignature.isEmpty)
        #expect(plant.avatarAttachmentState == .present)
        #expect(plant.avatarImageSignature.isEmpty)
        #expect(plantLog.photoAttachmentState == .present)
        #expect(plantLog.photoImageSignature.isEmpty)
        #expect(emptyPlantLog.photoAttachmentState == .absent)
        #expect(emptyPlantLog.photoImageSignature.isEmpty)
        #expect(milestone.photoAttachmentState == .present)
        #expect(milestone.photoImageSignature.isEmpty)
        #expect(photoLog.imageAttachmentState == .present)
        #expect(photoLog.imageSignature.isEmpty)
        #expect(document.legacyAttachmentState == .present)
        #expect(document.legacyAttachmentSignature.isEmpty)
        #expect(emptyDocument.legacyAttachmentState == .absent)
        #expect(emptyDocument.legacyAttachmentSignature.isEmpty)
        #expect(emptyDocument.attachmentFilename.isEmpty)
        #expect(documentAttachment.dataAttachmentState == .present)
        #expect(documentAttachment.dataSignature.isEmpty)
    }

    @Test func blobLoaderRepairsUnknownAttachmentIndexesAfterSuccessfulLoad() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let avatarData = Data([1, 2, 3, 4])
        let photoData = Data([9, 10, 11, 12, 13, 14, 15, 16, 17])

        let pet = Pet(name: "Momo")
        pet.avatarImageData = avatarData
        pet.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        pet.avatarImageSignature = ""
        pet.avatarTransparencyStateRaw = MemberAvatarTransparencyState.unknown.rawValue

        let human = Human(name: "Nico")
        human.avatarImageData = avatarData
        human.avatarAttachmentStateRaw = MemberAvatarAttachmentState.unknown.rawValue
        human.avatarImageSignature = ""

        let plant = Plant(name: "Fern")
        plant.avatarImageData = avatarData
        plant.avatarAttachmentStateRaw = PlantAvatarAttachmentState.unknown.rawValue
        plant.avatarImageSignature = ""

        let plantLog = PlantCareLog(careType: .photo, photoData: photoData)
        plantLog.photoAttachmentStateRaw = PlantCarePhotoAttachmentState.unknown.rawValue
        plantLog.photoImageSignature = ""

        context.insert(pet)
        context.insert(human)
        context.insert(plant)
        context.insert(plantLog)
        try context.save()

        let loader = SwiftDataMediaBlobLoader(modelContainer: container)
        #expect(await loader.petAvatarImageData(modelID: pet.persistentModelID) == avatarData)
        #expect(await loader.humanAvatarImageData(modelID: human.persistentModelID) == avatarData)
        #expect(await loader.plantAvatarImageData(modelID: plant.persistentModelID) == avatarData)
        #expect(await loader.plantCareLogPhotoData(modelID: plantLog.persistentModelID) == photoData)

        let verificationContext = ModelContext(container)
        let repairedPet = verificationContext.model(for: pet.persistentModelID) as? Pet
        let repairedHuman = verificationContext.model(for: human.persistentModelID) as? Human
        let repairedPlant = verificationContext.model(for: plant.persistentModelID) as? Plant
        let repairedPlantLog = verificationContext.model(for: plantLog.persistentModelID) as? PlantCareLog

        #expect(repairedPet?.avatarAttachmentState == .present)
        #expect(repairedPet?.avatarImageSignature == MediaPayloadSignature.signature(for: avatarData))
        #expect(repairedHuman?.avatarAttachmentState == .present)
        #expect(repairedHuman?.avatarImageSignature == MediaPayloadSignature.signature(for: avatarData))
        #expect(repairedPlant?.avatarAttachmentState == .present)
        #expect(repairedPlant?.avatarImageSignature == MediaPayloadSignature.signature(for: avatarData))
        #expect(repairedPlantLog?.photoAttachmentState == .present)
        #expect(repairedPlantLog?.photoImageSignature == MediaPayloadSignature.signature(for: photoData))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
