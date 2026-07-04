//
//  PlantMediaAttachmentIndexRepair.swift
//  Ohana
//
//  Deferred compatibility repair for lightweight plant media indexes.
//

import SwiftData

@MainActor
enum PlantMediaAttachmentIndexRepair {
    @discardableResult
    static func repair(
        plants: [Plant],
        modelContext: ModelContext,
        maxBlobReads: Int = 24
    ) -> Bool {
        var changed = false
        var blobReads = 0

        for plant in plants {
            guard blobReads < maxBlobReads else { break }

            if plant.needsAvatarAttachmentIndexRepair {
                changed = plant.repairAvatarAttachmentIndexIfNeeded() || changed
                blobReads += 1
            }

            for log in plant.careLogs where log.needsPhotoAttachmentIndexRepair {
                guard blobReads < maxBlobReads else { break }
                changed = log.repairPhotoAttachmentIndexIfNeeded() || changed
                blobReads += 1
            }
        }

        guard changed else { return false }
        try? modelContext.save()
        return true
    }
}
