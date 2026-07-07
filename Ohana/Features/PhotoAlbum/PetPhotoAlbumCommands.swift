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

enum PetPhotoAlbumCommandError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                return "照片保存失败：\(reason)"
            }
            return "照片保存失败，请稍后重试。"
        }
    }
}

enum PetPhotoAlbumCommandService {
    @discardableResult
    @MainActor
    static func createPhotos(
        data payloads: [Data],
        pet: Pet,
        context: ModelContext,
        date: Date = Date()
    ) throws -> PetPhotoAlbumCreateResult {
        guard !payloads.isEmpty else {
            return PetPhotoAlbumCreateResult(petID: pet.id, photoIDs: [])
        }
        var logs: [PetPhotoLog] = []
        for (index, data) in payloads.enumerated() {
            let logDate = date.addingTimeInterval(Double(index) * 0.01)
            let sanitizedData = AttachmentPrivacySanitizer.sanitizedData(
                data,
                filename: "pet-photo-\(index).jpg",
                isImage: true
            )
            guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
                pet: pet,
                occurredAt: logDate,
                writeKind: .memorial,
                context: context,
                logPrefix: "PetPhotoAlbumCommandService.createPhotos"
            ) else { continue }
            let log = DomainMemberFactWriter.createPetPhotoLog(
                plan: write,
                imageData: sanitizedData,
                date: logDate,
                pet: pet,
                context: context
            )
            logs.append(log)
        }
        guard !logs.isEmpty else {
            return PetPhotoAlbumCreateResult(petID: pet.id, photoIDs: [])
        }
        try savePhotoAlbumChanges(context: context)
        return PetPhotoAlbumCreateResult(petID: pet.id, photoIDs: logs.map(\.id))
    }

    @discardableResult
    @MainActor
    static func updateNote(
        _ note: String,
        photo: PetPhotoLog,
        pet: Pet,
        context: ModelContext
    ) throws -> PetPhotoAlbumUpdateResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .memorial).writesContent else {
            return PetPhotoAlbumUpdateResult(petID: pet.id, photoID: photo.id, didChange: false)
        }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let didChange = photo.note != cleanNote
        photo.note = cleanNote
        if didChange {
            try savePhotoAlbumChanges(context: context)
        }
        return PetPhotoAlbumUpdateResult(petID: pet.id, photoID: photo.id, didChange: didChange)
    }

    @discardableResult
    @MainActor
    static func deletePhoto(
        _ photo: PetPhotoLog,
        pet: Pet,
        context: ModelContext
    ) throws -> PetPhotoAlbumDeleteResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .memorial).writesContent else {
            return PetPhotoAlbumDeleteResult(petID: pet.id, photoID: photo.id)
        }
        let photoID = photo.id
        PhysicalDeletionService.deletePetScopedRecord(photo, pet: pet, context: context)
        try savePhotoAlbumChanges(context: context)
        return PetPhotoAlbumDeleteResult(petID: pet.id, photoID: photoID)
    }

    @MainActor
    private static func savePhotoAlbumChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw PetPhotoAlbumCommandError.persistenceFailed(saveResult.errorDescription)
        }
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
    ) throws -> PetPhotoAlbumCreateResult {
        let result = try PetPhotoAlbumCommandService.createPhotos(
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
    ) throws -> PetPhotoAlbumUpdateResult {
        let result = try PetPhotoAlbumCommandService.updateNote(
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
    ) throws -> PetPhotoAlbumDeleteResult {
        let result = try PetPhotoAlbumCommandService.deletePhoto(photo, pet: pet, context: context)
        revisions.publishPetPhotoDelete(result, note: note)
        return result
    }
}
