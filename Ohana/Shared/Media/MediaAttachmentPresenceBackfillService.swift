//
//  MediaAttachmentPresenceBackfillService.swift
//  Ohana
//
//  One-time upgrade repair for attachment presence flags added after legacy blobs existed.
//

import Foundation
import SwiftData

struct MediaAttachmentPresenceBackfillResult: Equatable {
    var petAvatarChanges = 0
    var petCardPopoutChanges = 0
    var humanAvatarChanges = 0
    var plantAvatarChanges = 0
    var plantCarePhotoChanges = 0
    var petMilestonePhotoChanges = 0
    var petPhotoLogChanges = 0
    var documentLegacyChanges = 0
    var documentAttachmentChanges = 0

    var changedCount: Int {
        petAvatarChanges
            + petCardPopoutChanges
            + humanAvatarChanges
            + plantAvatarChanges
            + plantCarePhotoChanges
            + petMilestonePhotoChanges
            + petPhotoLogChanges
            + documentLegacyChanges
            + documentAttachmentChanges
    }

    var didChange: Bool {
        changedCount > 0
    }

    var performanceNote: String {
        "changed=\(changedCount) petAvatar=\(petAvatarChanges) petPopout=\(petCardPopoutChanges) human=\(humanAvatarChanges) plant=\(plantAvatarChanges) plantLog=\(plantCarePhotoChanges) milestone=\(petMilestonePhotoChanges) petPhoto=\(petPhotoLogChanges) docLegacy=\(documentLegacyChanges) docAttachment=\(documentAttachmentChanges)"
    }
}

@MainActor
enum MediaAttachmentPresenceBackfillService {
    static func run(context: ModelContext) -> MediaAttachmentPresenceBackfillResult {
        var result = MediaAttachmentPresenceBackfillResult()

        result.petAvatarChanges = backfillPetAvatarPresence(context: context)
        result.petCardPopoutChanges = backfillPetCardPopoutPresence(context: context)
        result.humanAvatarChanges = backfillHumanAvatarPresence(context: context)
        result.plantAvatarChanges = backfillPlantAvatarPresence(context: context)
        result.plantCarePhotoChanges = backfillPlantCarePhotoPresence(context: context)
        result.petMilestonePhotoChanges = backfillPetMilestonePhotoPresence(context: context)
        result.petPhotoLogChanges = backfillPetPhotoLogPresence(context: context)
        result.documentLegacyChanges = backfillDocumentLegacyAttachmentPresence(context: context)
        result.documentAttachmentChanges = backfillDocumentAttachmentPresence(context: context)

        if result.didChange {
            context.safeSave()
        }
        return result
    }

    private static func backfillPetAvatarPresence(context: ModelContext) -> Int {
        var changed = 0
        let presentDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> {
                $0.avatarImageData != nil && $0.avatarAttachmentStateRaw != "present"
            }
        )
        for pet in fetchOrLog(presentDescriptor, context: context, operation: "pet avatar presence present") {
            if pet.backfillAvatarAttachmentPresence(hasData: true) {
                changed += 1
            }
        }

        let absentDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> {
                $0.avatarImageData == nil
            }
        )
        for pet in fetchOrLog(absentDescriptor, context: context, operation: "pet avatar presence absent") {
            if pet.backfillAvatarAttachmentPresence(hasData: false) {
                changed += 1
            }
        }
        return changed
    }

    private static func backfillPetCardPopoutPresence(context: ModelContext) -> Int {
        var changed = 0
        let presentDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> {
                $0.cardPopoutImageData != nil && $0.cardPopoutAttachmentStateRaw != "present"
            }
        )
        for pet in fetchOrLog(presentDescriptor, context: context, operation: "pet popout presence present") {
            if pet.backfillCardPopoutAttachmentPresence(hasData: true) {
                changed += 1
            }
        }

        let absentDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> {
                $0.cardPopoutImageData == nil
            }
        )
        for pet in fetchOrLog(absentDescriptor, context: context, operation: "pet popout presence absent") {
            if pet.backfillCardPopoutAttachmentPresence(hasData: false) {
                changed += 1
            }
        }
        return changed
    }

    private static func backfillHumanAvatarPresence(context: ModelContext) -> Int {
        var changed = 0
        let presentDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> {
                $0.avatarImageData != nil && $0.avatarAttachmentStateRaw != "present"
            }
        )
        for human in fetchOrLog(presentDescriptor, context: context, operation: "human avatar presence present") {
            if human.backfillAvatarAttachmentPresence(hasData: true) {
                changed += 1
            }
        }

        let absentDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> {
                $0.avatarImageData == nil
            }
        )
        for human in fetchOrLog(absentDescriptor, context: context, operation: "human avatar presence absent") {
            if human.backfillAvatarAttachmentPresence(hasData: false) {
                changed += 1
            }
        }
        return changed
    }

    private static func backfillPlantAvatarPresence(context: ModelContext) -> Int {
        var changed = 0
        let presentDescriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> {
                $0.avatarImageData != nil && $0.avatarAttachmentStateRaw != "present"
            }
        )
        for plant in fetchOrLog(presentDescriptor, context: context, operation: "plant avatar presence present") {
            if plant.backfillAvatarAttachmentPresence(hasData: true) {
                changed += 1
            }
        }

        let absentDescriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> {
                $0.avatarImageData == nil
            }
        )
        for plant in fetchOrLog(absentDescriptor, context: context, operation: "plant avatar presence absent") {
            if plant.backfillAvatarAttachmentPresence(hasData: false) {
                changed += 1
            }
        }
        return changed
    }

    private static func backfillPlantCarePhotoPresence(context: ModelContext) -> Int {
        var changed = 0
        let presentDescriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> {
                $0.photoData != nil && $0.photoAttachmentStateRaw != "present" // smoothness: allow startup maintenance storage-level nil predicate, not a render blob read.
            }
        )
        for log in fetchOrLog(presentDescriptor, context: context, operation: "plant log photo presence present") {
            if log.backfillPhotoAttachmentPresence(hasData: true) {
                changed += 1
            }
        }

        let absentDescriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> {
                $0.photoData == nil // smoothness: allow startup maintenance storage-level nil predicate, not a render blob read.
            }
        )
        for log in fetchOrLog(absentDescriptor, context: context, operation: "plant log photo presence absent") {
            if log.backfillPhotoAttachmentPresence(hasData: false) {
                changed += 1
            }
        }
        return changed
    }

    private static func backfillPetMilestonePhotoPresence(context: ModelContext) -> Int {
        var changed = 0
        let presentDescriptor = FetchDescriptor<PetMilestone>(
            predicate: #Predicate<PetMilestone> {
                $0.photoData != nil && $0.photoAttachmentStateRaw != "present" // smoothness: allow startup maintenance storage-level nil predicate, not a render blob read.
            }
        )
        for milestone in fetchOrLog(presentDescriptor, context: context, operation: "milestone photo presence present") {
            if milestone.backfillPhotoAttachmentPresence(hasData: true) {
                changed += 1
            }
        }

        let absentDescriptor = FetchDescriptor<PetMilestone>(
            predicate: #Predicate<PetMilestone> {
                $0.photoData == nil // smoothness: allow startup maintenance storage-level nil predicate, not a render blob read.
            }
        )
        for milestone in fetchOrLog(absentDescriptor, context: context, operation: "milestone photo presence absent") {
            if milestone.backfillPhotoAttachmentPresence(hasData: false) {
                changed += 1
            }
        }
        return changed
    }

    private static func backfillPetPhotoLogPresence(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<PetPhotoLog>(
            predicate: #Predicate<PetPhotoLog> {
                $0.imageAttachmentStateRaw == "unknown"
            }
        )
        return fetchOrLog(descriptor, context: context, operation: "pet photo log presence")
            .reduce(0) { count, log in
                count + (log.backfillImageAttachmentPresenceAssumingPayload() ? 1 : 0)
            }
    }

    private static func backfillDocumentLegacyAttachmentPresence(context: ModelContext) -> Int {
        var changed = 0
        let presentDescriptor = FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> {
                $0.attachmentData != nil && $0.legacyAttachmentStateRaw != "present" // smoothness: allow startup maintenance storage-level nil predicate, not a render blob read.
            }
        )
        for document in fetchOrLog(presentDescriptor, context: context, operation: "document legacy presence present") {
            if document.backfillLegacyAttachmentPresence(hasData: true) {
                changed += 1
            }
        }

        let absentDescriptor = FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> {
                $0.attachmentData == nil // smoothness: allow startup maintenance storage-level nil predicate, not a render blob read.
            }
        )
        for document in fetchOrLog(absentDescriptor, context: context, operation: "document legacy presence absent") {
            if document.backfillLegacyAttachmentPresence(hasData: false) {
                changed += 1
            }
        }
        return changed
    }

    private static func backfillDocumentAttachmentPresence(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<PetDocumentAttachment>(
            predicate: #Predicate<PetDocumentAttachment> {
                $0.dataAttachmentStateRaw == "unknown"
            }
        )
        return fetchOrLog(descriptor, context: context, operation: "document attachment presence")
            .reduce(0) { count, attachment in
                count + (attachment.backfillDataAttachmentPresenceAssumingPayload() ? 1 : 0)
            }
    }

    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
                OhanaLog.error("Media attachment presence backfill failed during \(operation): \(error)", category: "StartupMaintenance")
            #endif
            return []
        }
    }
}
