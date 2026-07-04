//
//  MemberMediaAttachmentIndexRepair.swift
//  Ohana
//
//  Deferred compatibility repair for lightweight member media indexes.
//

import SwiftData

@MainActor
enum MemberMediaAttachmentIndexRepair {
    @discardableResult
    static func repair(
        modelContext: ModelContext,
        maxBlobReads: Int = 24
    ) -> Bool {
        var changed = false
        var blobReads = 0

        for pet in fetch(Pet.self, modelContext: modelContext) {
            guard blobReads < maxBlobReads else { break }
            if pet.needsAvatarMediaIndexRepair {
                changed = pet.repairAvatarMediaIndexesIfNeeded() || changed
                blobReads += 1
            }
            guard blobReads < maxBlobReads else { break }
            if pet.needsCardPopoutAttachmentIndexRepair {
                changed = pet.repairCardPopoutAttachmentIndexIfNeeded() || changed
                blobReads += 1
            }
        }

        if blobReads < maxBlobReads {
            for human in fetch(Human.self, modelContext: modelContext) {
                guard blobReads < maxBlobReads else { break }
                if human.needsAvatarAttachmentIndexRepair {
                    changed = human.repairAvatarAttachmentIndexIfNeeded() || changed
                    blobReads += 1
                }
            }
        }

        if blobReads < maxBlobReads {
            for photo in fetch(PetPhotoLog.self, modelContext: modelContext) {
                guard blobReads < maxBlobReads else { break }
                if photo.needsImageAttachmentIndexRepair {
                    changed = photo.repairImageAttachmentIndexIfNeeded() || changed
                    blobReads += 1
                }
            }
        }

        if blobReads < maxBlobReads {
            for document in fetch(PetDocument.self, modelContext: modelContext) {
                guard blobReads < maxBlobReads else { break }
                if document.needsLegacyAttachmentIndexRepair {
                    changed = document.repairLegacyAttachmentIndexIfNeeded() || changed
                    blobReads += 1
                }
            }
        }

        if blobReads < maxBlobReads {
            for attachment in fetch(PetDocumentAttachment.self, modelContext: modelContext) {
                guard blobReads < maxBlobReads else { break }
                if attachment.needsDataAttachmentIndexRepair {
                    changed = attachment.repairDataAttachmentIndexIfNeeded() || changed
                    blobReads += 1
                }
            }
        }

        guard changed else { return false }
        try? modelContext.save()
        return true
    }

    private static func fetch<T: PersistentModel>(
        _ modelType: T.Type,
        modelContext: ModelContext
    ) -> [T] {
        (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
    }
}
