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
    func petAvatarImageData(id: UUID) -> Data? {
        guard let pet = pet(id: id) else { return nil }
        return petAvatarImageData(pet)
    }

    func petAvatarImageData(modelID: PersistentIdentifier) -> Data? {
        guard let pet = modelContext.model(for: modelID) as? Pet else { return nil }
        return petAvatarImageData(pet)
    }

    func humanAvatarImageData(id: UUID) -> Data? {
        guard let human = human(id: id) else { return nil }
        return humanAvatarImageData(human)
    }

    func humanAvatarImageData(modelID: PersistentIdentifier) -> Data? {
        guard let human = modelContext.model(for: modelID) as? Human else { return nil }
        return humanAvatarImageData(human)
    }

    func petCardPopoutImageData(id: UUID) -> Data? {
        guard let pet = pet(id: id) else { return nil }
        return petCardPopoutImageData(pet)
    }

    func petCardPopoutImageData(modelID: PersistentIdentifier) -> Data? {
        guard let pet = modelContext.model(for: modelID) as? Pet else { return nil }
        return petCardPopoutImageData(pet)
    }

    private func petAvatarImageData(_ pet: Pet) -> Data? {
        guard pet.canAttemptAvatarImageAttachmentLoad else { return nil }
        let data = pet.avatarImageData
        persistRepairIfNeeded(pet.repairAvatarMediaIndexesIfNeeded())
        return data
    }

    private func humanAvatarImageData(_ human: Human) -> Data? {
        guard human.canAttemptAvatarImageAttachmentLoad else { return nil }
        let data = human.avatarImageData
        persistRepairIfNeeded(human.repairAvatarAttachmentIndexIfNeeded())
        return data
    }

    private func petCardPopoutImageData(_ pet: Pet) -> Data? {
        guard pet.cardStyleRaw == "popout",
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

    private func pet(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    private func human(id: UUID) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    private func persistRepairIfNeeded(_ didRepair: Bool) {
        guard didRepair else { return }
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        if !saveResult.didSave {
            modelContext.rollback()
        }
    }
}
