//
//  PetPhotoAlbumCommands.swift
//  Ohana
//
//  Pet photo album write boundary and revision publishing.
//

import Foundation
import SwiftData

struct PetPhotoAlbumCreateResult: Equatable {
    let petID: UUID
    let photoIDs: [UUID]
}

struct PetPhotoAlbumUpdateResult: Equatable {
    let petID: UUID
    let photoID: UUID
    let didChange: Bool
}

struct PetPhotoAlbumDeleteResult: Equatable {
    let petID: UUID
    let photoID: UUID
}

enum PetPhotoAlbumCommandService {
    @discardableResult
    @MainActor
    static func createPhotos(
        data payloads: [Data],
        pet: Pet,
        context: ModelContext,
        date: Date = Date()
    ) -> PetPhotoAlbumCreateResult {
        guard !payloads.isEmpty else {
            return PetPhotoAlbumCreateResult(petID: pet.id, photoIDs: [])
        }

        var logs: [PetPhotoLog] = []
        for (index, data) in payloads.enumerated() {
            let log = PetPhotoLog(
                imageData: data,
                date: date.addingTimeInterval(Double(index) * 0.01),
                pet: pet
            )
            context.insert(log)
            logs.append(log)
        }
        context.safeSave()
        return PetPhotoAlbumCreateResult(petID: pet.id, photoIDs: logs.map(\.id))
    }

    @discardableResult
    @MainActor
    static func updateNote(
        _ note: String,
        photo: PetPhotoLog,
        pet: Pet,
        context: ModelContext
    ) -> PetPhotoAlbumUpdateResult {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let didChange = photo.note != cleanNote
        photo.note = cleanNote
        if didChange {
            context.safeSave()
        }
        return PetPhotoAlbumUpdateResult(petID: pet.id, photoID: photo.id, didChange: didChange)
    }

    @discardableResult
    @MainActor
    static func deletePhoto(
        _ photo: PetPhotoLog,
        pet: Pet,
        context: ModelContext
    ) -> PetPhotoAlbumDeleteResult {
        let photoID = photo.id
        PhysicalDeletionService.deletePetScopedRecord(photo, pet: pet, context: context)
        context.safeSave()
        return PetPhotoAlbumDeleteResult(petID: pet.id, photoID: photoID)
    }
}

@MainActor
struct PetPhotoAlbumCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
    }

    @discardableResult
    func createPhotos(
        data payloads: [Data],
        pet: Pet,
        date: Date = Date(),
        note: String
    ) -> PetPhotoAlbumCreateResult {
        let result = PetPhotoAlbumCommandService.createPhotos(
            data: payloads,
            pet: pet,
            context: context,
            date: date
        )
        revisions.publishPetPhotoCreate(result, note: note)
        return result
    }

    @discardableResult
    func updateNote(
        _ noteText: String,
        photo: PetPhotoLog,
        pet: Pet,
        note: String
    ) -> PetPhotoAlbumUpdateResult {
        let result = PetPhotoAlbumCommandService.updateNote(
            noteText,
            photo: photo,
            pet: pet,
            context: context
        )
        revisions.publishPetPhotoUpdate(result, note: note)
        return result
    }

    @discardableResult
    func deletePhoto(
        _ photo: PetPhotoLog,
        pet: Pet,
        note: String
    ) -> PetPhotoAlbumDeleteResult {
        let result = PetPhotoAlbumCommandService.deletePhoto(photo, pet: pet, context: context)
        revisions.publishPetPhotoDelete(result, note: note)
        return result
    }
}
