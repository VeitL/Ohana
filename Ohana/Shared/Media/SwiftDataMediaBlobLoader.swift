//
//  SwiftDataMediaBlobLoader.swift
//  Ohana
//
//  Background SwiftData blob reads for visible media thumbnails.
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataMediaBlobLoader {
    func petAvatarImageData(modelID: PersistentIdentifier) -> Data? {
        guard let pet = modelContext.model(for: modelID) as? Pet,
              pet.canAttemptAvatarImageAttachmentLoad else {
            return nil
        }
        let data = pet.avatarImageData
        persistRepairIfNeeded(pet.repairAvatarMediaIndexesIfNeeded())
        return data
    }

    func humanAvatarImageData(modelID: PersistentIdentifier) -> Data? {
        guard let human = modelContext.model(for: modelID) as? Human,
              human.canAttemptAvatarImageAttachmentLoad else {
            return nil
        }
        let data = human.avatarImageData
        persistRepairIfNeeded(human.repairAvatarAttachmentIndexIfNeeded())
        return data
    }

    func petCardPopoutImageData(modelID: PersistentIdentifier) -> Data? {
        guard let pet = modelContext.model(for: modelID) as? Pet,
              pet.cardStyleRaw == "popout",
              pet.canAttemptCardPopoutImageAttachmentLoad else {
            return nil
        }
        let data = pet.cardPopoutImageData
        persistRepairIfNeeded(pet.repairCardPopoutAttachmentIndexIfNeeded())
        return data
    }

    func petPhotoLogImageData(modelID: PersistentIdentifier) -> Data? {
        guard let log = modelContext.model(for: modelID) as? PetPhotoLog,
              log.canAttemptImageAttachmentLoad else {
            return nil
        }
        let data = log.imageData
        persistRepairIfNeeded(log.repairImageAttachmentIndexIfNeeded())
        return data
    }

    func petMilestonePhotoData(modelID: PersistentIdentifier) -> Data? {
        guard let milestone = modelContext.model(for: modelID) as? PetMilestone,
              milestone.canAttemptPhotoAttachmentLoad else {
            return nil
        }
        let data = milestone.photoData
        persistRepairIfNeeded(milestone.repairPhotoAttachmentIndexIfNeeded())
        return data
    }

    func plantAvatarImageData(modelID: PersistentIdentifier) -> Data? {
        guard let plant = modelContext.model(for: modelID) as? Plant,
              plant.canAttemptAvatarImageAttachmentLoad else {
            return nil
        }
        let data = plant.avatarImageData
        persistRepairIfNeeded(plant.repairAvatarAttachmentIndexIfNeeded())
        return data
    }

    func plantCareLogPhotoData(modelID: PersistentIdentifier) -> Data? {
        guard let log = modelContext.model(for: modelID) as? PlantCareLog,
              log.canAttemptPhotoAttachmentLoad else {
            return nil
        }
        let data = log.photoData
        persistRepairIfNeeded(log.repairPhotoAttachmentIndexIfNeeded())
        return data
    }

    private func persistRepairIfNeeded(_ didRepair: Bool) {
        guard didRepair else { return }
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        if !saveResult.didSave {
            modelContext.rollback()
        }
    }
}
