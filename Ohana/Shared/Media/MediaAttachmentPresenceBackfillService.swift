//
//  MediaAttachmentPresenceBackfillService.swift
//  Ohana
//
//  One-time upgrade repair for attachment presence flags added after legacy blobs existed.
//

import Foundation
import SwiftData

nonisolated struct MediaAttachmentPresenceBackfillResult: Equatable, Sendable {
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

    mutating func merge(_ other: MediaAttachmentPresenceBackfillResult) {
        petAvatarChanges += other.petAvatarChanges
        petCardPopoutChanges += other.petCardPopoutChanges
        humanAvatarChanges += other.humanAvatarChanges
        plantAvatarChanges += other.plantAvatarChanges
        plantCarePhotoChanges += other.plantCarePhotoChanges
        petMilestonePhotoChanges += other.petMilestonePhotoChanges
        petPhotoLogChanges += other.petPhotoLogChanges
        documentLegacyChanges += other.documentLegacyChanges
        documentAttachmentChanges += other.documentAttachmentChanges
    }
}

/// Each source has an independent, stable model-table cursor. Backfill changes
/// attachment columns only; it never inserts or removes source rows, so an
/// offset remains valid while a finite page is repaired and saved.
nonisolated enum MediaAttachmentPresenceBackfillSource: String, Codable, Equatable, Sendable, CaseIterable {
    case pet
    case human
    case plant
    case plantCareLog
    case petMilestone
    case petPhotoLog
    case documentLegacy
    case documentAttachment
    case complete

    var next: MediaAttachmentPresenceBackfillSource {
        switch self {
        case .pet: .human
        case .human: .plant
        case .plant: .plantCareLog
        case .plantCareLog: .petMilestone
        case .petMilestone: .petPhotoLog
        case .petPhotoLog: .documentLegacy
        case .documentLegacy: .documentAttachment
        case .documentAttachment, .complete: .complete
        }
    }
}

nonisolated struct MediaAttachmentPresenceBackfillCursor: Codable, Equatable, Sendable {
    var source: MediaAttachmentPresenceBackfillSource
    var offset: Int

    static let initial = MediaAttachmentPresenceBackfillCursor(source: .pet, offset: 0)

    var isComplete: Bool {
        source == .complete
    }

    func normalized() -> MediaAttachmentPresenceBackfillCursor {
        guard !isComplete else {
            return MediaAttachmentPresenceBackfillCursor(source: .complete, offset: 0)
        }
        return MediaAttachmentPresenceBackfillCursor(source: source, offset: max(0, offset))
    }
}

nonisolated struct MediaAttachmentPresenceBackfillBatchResult: Equatable, Sendable {
    let backfillResult: MediaAttachmentPresenceBackfillResult
    let nextCursor: MediaAttachmentPresenceBackfillCursor
    let scannedRecordCount: Int
    let didComplete: Bool
}

private nonisolated struct MediaAttachmentPresenceBackfillPersistenceFailure: LocalizedError {
    let errorDescription: String?
}

private nonisolated struct MediaAttachmentPresenceBackfillSourceProgress: Sendable {
    let result: MediaAttachmentPresenceBackfillResult
    let fetchedRecordCount: Int
    let processedRecordCount: Int
}

nonisolated enum MediaAttachmentPresenceBackfillService {
    /// Compatibility helper for explicit/manual repair and old callers. Startup
    /// must use the actor's cursor-backed `runBatch` API instead.
    static func run(context: ModelContext) -> MediaAttachmentPresenceBackfillResult {
        var cursor = MediaAttachmentPresenceBackfillCursor.initial
        var aggregate = MediaAttachmentPresenceBackfillResult()

        while !cursor.isComplete {
            guard !Task.isCancelled else { return aggregate }
            do {
                let batch = try runBatch(
                    context: context,
                    cursor: cursor,
                    maximumRecordCount: 64,
                    deadline: .distantFuture
                )
                aggregate.merge(batch.backfillResult)
                guard batch.nextCursor != cursor || batch.didComplete || batch.scannedRecordCount > 0 else {
                    return aggregate
                }
                cursor = batch.nextCursor
            } catch is CancellationError {
                return aggregate
            } catch {
                OhanaLog.error(
                    "Media attachment presence compatibility backfill failed: \(error)",
                    category: "StartupMaintenance"
                )
                return aggregate
            }
        }

        return aggregate
    }

    /// Repairs a bounded number of source records and returns the precise
    /// continuation phase. The caller owns durable cursor persistence only
    /// after this method returns successfully.
    static func runBatch(
        context: ModelContext,
        cursor: MediaAttachmentPresenceBackfillCursor,
        maximumRecordCount: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillBatchResult {
        var nextCursor = cursor.normalized()
        var remainingRecordCount = max(1, maximumRecordCount)
        var aggregate = MediaAttachmentPresenceBackfillResult()
        var scannedRecordCount = 0
        var didChange = false

        do {
            maintenanceLoop: while remainingRecordCount > 0,
                                   !nextCursor.isComplete,
                                   Date() < deadline {
                try Task.checkCancellation()

                let requestedRecordCount = remainingRecordCount
                let progress = try process(
                    source: nextCursor.source,
                    context: context,
                    offset: nextCursor.offset,
                    limit: remainingRecordCount,
                    deadline: deadline
                )
                aggregate.merge(progress.result)
                didChange = didChange || progress.result.didChange
                scannedRecordCount += progress.processedRecordCount
                remainingRecordCount -= progress.processedRecordCount
                nextCursor.offset += progress.processedRecordCount

                guard progress.processedRecordCount == progress.fetchedRecordCount else {
                    break maintenanceLoop
                }

                if progress.fetchedRecordCount < requestedRecordCount {
                    nextCursor = MediaAttachmentPresenceBackfillCursor(
                        source: nextCursor.source.next,
                        offset: 0
                    )
                }
            }

            try Task.checkCancellation()
            if didChange {
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    throw MediaAttachmentPresenceBackfillPersistenceFailure(errorDescription: saveResult.errorDescription)
                }
            }

            return MediaAttachmentPresenceBackfillBatchResult(
                backfillResult: aggregate,
                nextCursor: nextCursor,
                scannedRecordCount: scannedRecordCount,
                didComplete: nextCursor.isComplete
            )
        } catch {
            if didChange {
                context.rollback()
            }
            throw error
        }
    }

    private static func process(
        source: MediaAttachmentPresenceBackfillSource,
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        switch source {
        case .pet:
            try processPets(context: context, offset: offset, limit: limit, deadline: deadline)
        case .human:
            try processHumans(context: context, offset: offset, limit: limit, deadline: deadline)
        case .plant:
            try processPlants(context: context, offset: offset, limit: limit, deadline: deadline)
        case .plantCareLog:
            try processPlantCareLogs(context: context, offset: offset, limit: limit, deadline: deadline)
        case .petMilestone:
            try processPetMilestones(context: context, offset: offset, limit: limit, deadline: deadline)
        case .petPhotoLog:
            try processPetPhotoLogs(context: context, offset: offset, limit: limit, deadline: deadline)
        case .documentLegacy:
            try processDocuments(context: context, offset: offset, limit: limit, deadline: deadline)
        case .documentAttachment:
            try processDocumentAttachments(context: context, offset: offset, limit: limit, deadline: deadline)
        case .complete:
            MediaAttachmentPresenceBackfillSourceProgress(
                result: MediaAttachmentPresenceBackfillResult(),
                fetchedRecordCount: 0,
                processedRecordCount: 0
            )
        }
    }

    private static func processPets(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)])
        let pets = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "pet attachment presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for pet in pets {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if pet.backfillAvatarAttachmentPresence(hasData: pet.avatarImageData != nil) {
                result.petAvatarChanges += 1
            }
            if pet.backfillCardPopoutAttachmentPresence(hasData: pet.cardPopoutImageData != nil) {
                result.petCardPopoutChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: pets.count,
            processedRecordCount: processed
        )
    }

    private static func processHumans(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)])
        let humans = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "human attachment presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for human in humans {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if human.backfillAvatarAttachmentPresence(hasData: human.avatarImageData != nil) {
                result.humanAvatarChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: humans.count,
            processedRecordCount: processed
        )
    }

    private static func processPlants(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)])
        let plants = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "plant attachment presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for plant in plants {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if plant.backfillAvatarAttachmentPresence(hasData: plant.avatarImageData != nil) {
                result.plantAvatarChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: plants.count,
            processedRecordCount: processed
        )
    }

    private static func processPlantCareLogs(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<PlantCareLog>(sortBy: [SortDescriptor(\.date)])
        let logs = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "plant care photo presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for log in logs {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if log.backfillPhotoAttachmentPresence(hasData: log.photoData != nil) { // smoothness: allow background migration actor reads the storage nil bit once to repair the lightweight presence index; never called from a render path.
                result.plantCarePhotoChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: logs.count,
            processedRecordCount: processed
        )
    }

    private static func processPetMilestones(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<PetMilestone>(sortBy: [SortDescriptor(\.date)])
        let milestones = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "milestone photo presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for milestone in milestones {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if milestone.backfillPhotoAttachmentPresence(hasData: milestone.photoData != nil) { // smoothness: allow background migration actor reads the storage nil bit once to repair the lightweight presence index; never called from a render path.
                result.petMilestonePhotoChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: milestones.count,
            processedRecordCount: processed
        )
    }

    private static func processPetPhotoLogs(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<PetPhotoLog>(sortBy: [SortDescriptor(\.createdAt)])
        let logs = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "pet photo log presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for log in logs {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if log.imageAttachmentStateRaw == "unknown",
               log.backfillImageAttachmentPresenceAssumingPayload() {
                result.petPhotoLogChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: logs.count,
            processedRecordCount: processed
        )
    }

    private static func processDocuments(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<PetDocument>(sortBy: [SortDescriptor(\.title)])
        let documents = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "document legacy attachment presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for document in documents {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if document.backfillLegacyAttachmentPresence(hasData: document.attachmentData != nil) { // smoothness: allow background migration actor reads the storage nil bit once to repair the lightweight attachment index; never called from a render path.
                result.documentLegacyChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: documents.count,
            processedRecordCount: processed
        )
    }

    private static func processDocumentAttachments(
        context: ModelContext,
        offset: Int,
        limit: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillSourceProgress {
        let descriptor = FetchDescriptor<PetDocumentAttachment>(sortBy: [SortDescriptor(\.filename)])
        let attachments = try fetch(
            descriptor,
            offset: offset,
            limit: limit,
            context: context,
            operation: "document attachment presence"
        )
        var result = MediaAttachmentPresenceBackfillResult()
        var processed = 0

        for attachment in attachments {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processed += 1 }
            if attachment.dataAttachmentStateRaw == "unknown",
               attachment.backfillDataAttachmentPresenceAssumingPayload() {
                result.documentAttachmentChanges += 1
            }
        }

        return MediaAttachmentPresenceBackfillSourceProgress(
            result: result,
            fetchedRecordCount: attachments.count,
            processedRecordCount: processed
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        offset: Int,
        limit: Int,
        context: ModelContext,
        operation: String
    ) throws -> [T] {
        var descriptor = descriptor
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(1, limit)
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.error(
                "Media attachment presence backfill failed during \(operation): \(error)",
                category: "StartupMaintenance"
            )
            throw error
        }
    }
}

/// Keeps the legacy attachment-state migration off the visible startup actor.
/// The actor returns value-only progress; live SwiftData models never cross the
/// boundary, and callers persist the cursor only after a successful batch.
@ModelActor
actor MediaAttachmentPresenceBackfillActor {
    func runBatch(
        cursor: MediaAttachmentPresenceBackfillCursor,
        maximumRecordCount: Int,
        deadline: Date
    ) throws -> MediaAttachmentPresenceBackfillBatchResult {
        try MediaAttachmentPresenceBackfillService.runBatch(
            context: modelContext,
            cursor: cursor,
            maximumRecordCount: maximumRecordCount,
            deadline: deadline
        )
    }

    /// Compatibility helper for deterministic tests and explicit/manual work.
    /// Startup uses `runBatch` so it never performs an unbounded repair.
    func run() -> MediaAttachmentPresenceBackfillResult {
        MediaAttachmentPresenceBackfillService.run(context: modelContext)
    }
}
