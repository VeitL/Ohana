//
//  AvatarAssetMaintenanceService.swift
//  Ohana
//
//  Keeps stored profile images near their largest display size so SwiftData
//  startup queries do not repeatedly load oversized camera assets.
//

import Foundation
import SwiftData
import UIKit

/// Durable position for the one-time avatar compaction. The offset is scoped
/// to one source table; compaction changes blobs but never inserts or removes
/// Pet/Human rows, so advancing it cannot skip a row because of this work.
nonisolated enum AvatarAssetCompactionSource: String, Codable, Equatable, Sendable {
    case pet
    case human
    case complete
}

nonisolated struct AvatarAssetCompactionCursor: Codable, Equatable, Sendable {
    var source: AvatarAssetCompactionSource
    var offset: Int

    static let initial = AvatarAssetCompactionCursor(source: .pet, offset: 0)

    var isComplete: Bool {
        source == .complete
    }

    func normalized() -> AvatarAssetCompactionCursor {
        guard source != .complete else {
            return AvatarAssetCompactionCursor(source: .complete, offset: 0)
        }
        return AvatarAssetCompactionCursor(source: source, offset: max(0, offset))
    }
}

nonisolated struct AvatarAssetCompactionBatchResult: Equatable, Sendable {
    let nextCursor: AvatarAssetCompactionCursor
    let scannedRecordCount: Int
    let compactedRecordCount: Int
    let didComplete: Bool
}

private nonisolated struct AvatarAssetCompactionPersistenceFailure: LocalizedError {
    let errorDescription: String?
}

enum AvatarAssetMaintenanceService {
    private nonisolated static let maxStoredPixel: CGFloat = 900
    private nonisolated static let largeAssetThreshold = 700_000

    private nonisolated struct AvatarPayload: Sendable {
        let id: UUID
        let data: Data?
    }

    private nonisolated struct AvatarUpdate: Sendable {
        let id: UUID
        let originalData: Data
        let compactedData: Data
    }

    private nonisolated struct AvatarCompactionWorkerResult: Sendable {
        let processedRecordCount: Int
        let updates: [AvatarUpdate]
    }

    /// Compatibility helper for explicit manual maintenance. Startup must call
    /// the cursor-backed `compactStoredAvatarsBatch` API through the actor.
    static func compactStoredAvatars(context: ModelContext) async {
        var cursor = AvatarAssetCompactionCursor.initial

        while !cursor.isComplete {
            guard !Task.isCancelled else { return }
            do {
                let result = try await compactStoredAvatarsBatch(
                    context: context,
                    cursor: cursor,
                    maximumRecordCount: 64,
                    deadline: .distantFuture
                )
                cursor = result.nextCursor
                await Task.yield()
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "AvatarAssetMaintenanceService compatibility compaction failed: \(error.localizedDescription)",
                    category: "Care"
                )
                return
            }
        }
    }

    /// Compacts one finite page. Only value payloads cross to the image worker;
    /// the background SwiftData actor retains all persistent models locally.
    static func compactStoredAvatarsBatch(
        context: ModelContext,
        cursor: AvatarAssetCompactionCursor,
        maximumRecordCount: Int,
        deadline: Date
    ) async throws -> AvatarAssetCompactionBatchResult {
        var nextCursor = cursor.normalized()
        var remainingRecordCount = max(1, maximumRecordCount)
        var scannedRecordCount = 0
        var compactedRecordCount = 0
        var didChange = false

        do {
            maintenanceLoop: while remainingRecordCount > 0,
                                   !nextCursor.isComplete,
                                   Date() < deadline {
                try Task.checkCancellation()

                switch nextCursor.source {
                case .pet:
                    let payloads = try petPayloads(
                        context: context,
                        offset: nextCursor.offset,
                        limit: remainingRecordCount
                    )
                    let processed = try await compactPayloads(payloads, deadline: deadline)
                    try Task.checkCancellation()

                    let applied = try applyPetUpdates(processed.updates, context: context)
                    didChange = didChange || applied > 0
                    compactedRecordCount += applied
                    scannedRecordCount += processed.processedRecordCount
                    remainingRecordCount -= processed.processedRecordCount
                    nextCursor.offset += processed.processedRecordCount

                    guard processed.processedRecordCount == payloads.count else {
                        break maintenanceLoop
                    }
                    if payloads.count < max(1, remainingRecordCount + processed.processedRecordCount) {
                        nextCursor = AvatarAssetCompactionCursor(source: .human, offset: 0)
                    }

                case .human:
                    let payloads = try humanPayloads(
                        context: context,
                        offset: nextCursor.offset,
                        limit: remainingRecordCount
                    )
                    let processed = try await compactPayloads(payloads, deadline: deadline)
                    try Task.checkCancellation()

                    let applied = try applyHumanUpdates(processed.updates, context: context)
                    didChange = didChange || applied > 0
                    compactedRecordCount += applied
                    scannedRecordCount += processed.processedRecordCount
                    remainingRecordCount -= processed.processedRecordCount
                    nextCursor.offset += processed.processedRecordCount

                    guard processed.processedRecordCount == payloads.count else {
                        break maintenanceLoop
                    }
                    if payloads.count < max(1, remainingRecordCount + processed.processedRecordCount) {
                        nextCursor = AvatarAssetCompactionCursor(source: .complete, offset: 0)
                    }

                case .complete:
                    break
                }
            }

            try Task.checkCancellation()
            if didChange {
                let saveResult = context.safeSaveResult(publishFailureEvent: true)
                guard saveResult.didSave else {
                    context.rollback()
                    throw AvatarAssetCompactionPersistenceFailure(errorDescription: saveResult.errorDescription)
                }
            }

            return AvatarAssetCompactionBatchResult(
                nextCursor: nextCursor,
                scannedRecordCount: scannedRecordCount,
                compactedRecordCount: compactedRecordCount,
                didComplete: nextCursor.isComplete
            )
        } catch {
            if didChange {
                context.rollback()
            }
            throw error
        }
    }

    private static func petPayloads(
        context: ModelContext,
        offset: Int,
        limit: Int
    ) throws -> [AvatarPayload] {
        var descriptor = FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(1, limit)
        do {
            return try context.fetch(descriptor).map { pet in
                AvatarPayload(id: pet.id, data: pet.avatarImageData)
            }
        } catch {
            OhanaLog.warning(
                "AvatarAssetMaintenanceService failed to fetch pets before avatar compaction: \(error.localizedDescription)",
                category: "Care"
            )
            throw error
        }
    }

    private static func humanPayloads(
        context: ModelContext,
        offset: Int,
        limit: Int
    ) throws -> [AvatarPayload] {
        var descriptor = FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(1, limit)
        do {
            return try context.fetch(descriptor).map { human in
                AvatarPayload(id: human.id, data: human.avatarImageData)
            }
        } catch {
            OhanaLog.warning(
                "AvatarAssetMaintenanceService failed to fetch humans before avatar compaction: \(error.localizedDescription)",
                category: "Care"
            )
            throw error
        }
    }

    /// A structured child task inherits cancellation from the maintenance actor.
    /// This deliberately replaces `Task.detached`, whose cancellation state is
    /// independent from the startup task.
    private nonisolated static func compactPayloads(
        _ payloads: [AvatarPayload],
        deadline: Date
    ) async throws -> AvatarCompactionWorkerResult {
        try await withThrowingTaskGroup(
            of: AvatarCompactionWorkerResult.self,
            returning: AvatarCompactionWorkerResult.self
        ) { group in
            group.addTask(priority: .utility) {
                try compactPayloadsOnWorker(payloads, deadline: deadline)
            }
            guard let result = try await group.next() else {
                return AvatarCompactionWorkerResult(processedRecordCount: 0, updates: [])
            }
            return result
        }
    }

    private nonisolated static func compactPayloadsOnWorker(
        _ payloads: [AvatarPayload],
        deadline: Date
    ) throws -> AvatarCompactionWorkerResult {
        var processedRecordCount = 0
        var updates: [AvatarUpdate] = []

        for payload in payloads {
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            defer { processedRecordCount += 1 }

            guard let data = payload.data,
                  let compacted = compactedAvatarData(from: data)
            else {
                continue
            }
            updates.append(
                AvatarUpdate(
                    id: payload.id,
                    originalData: data,
                    compactedData: compacted
                )
            )
        }

        return AvatarCompactionWorkerResult(
            processedRecordCount: processedRecordCount,
            updates: updates
        )
    }

    private static func applyPetUpdates(
        _ updates: [AvatarUpdate],
        context: ModelContext
    ) throws -> Int {
        var appliedCount = 0
        for update in updates {
            try Task.checkCancellation()
            let id = update.id
            var descriptor = FetchDescriptor<Pet>(
                predicate: #Predicate<Pet> { pet in
                    pet.id == id
                }
            )
            descriptor.fetchLimit = 1
            guard let pet = try context.fetch(descriptor).first,
                  pet.avatarImageData == update.originalData
            else { continue }
            pet.updateAvatarImageData(update.compactedData)
            appliedCount += 1
        }
        return appliedCount
    }

    private static func applyHumanUpdates(
        _ updates: [AvatarUpdate],
        context: ModelContext
    ) throws -> Int {
        var appliedCount = 0
        for update in updates {
            try Task.checkCancellation()
            let id = update.id
            var descriptor = FetchDescriptor<Human>(
                predicate: #Predicate<Human> { human in
                    human.id == id
                }
            )
            descriptor.fetchLimit = 1
            guard let human = try context.fetch(descriptor).first,
                  human.avatarImageData == update.originalData
            else { continue }
            human.updateAvatarImageData(update.compactedData)
            appliedCount += 1
        }
        return appliedCount
    }

    private nonisolated static func compactedAvatarData(from data: Data) -> Data? {
        guard data.count > largeAssetThreshold, let image = UIImage(data: data) else { return nil } // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline

        let preservesAlpha = ImageCutoutService.isTransparentPNG(data)
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxStoredPixel || data.count > largeAssetThreshold else { return nil }

        let targetImage: UIImage
        if longest > maxStoredPixel {
            let scale = maxStoredPixel / longest
            let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = !preservesAlpha
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            targetImage = image
        }

        let encoded = preservesAlpha
            ? targetImage.pngData()
            : targetImage.jpegData(compressionQuality: 0.88)
        guard let encoded, encoded.count < data.count else { return nil }
        return encoded
    }
}

/// Avatar compaction scans persistent blobs on an isolated SwiftData context;
/// only compressed `Data` values leave the structured image worker.
@ModelActor
actor AvatarAssetMaintenanceActor {
    func runBatch(
        cursor: AvatarAssetCompactionCursor,
        maximumRecordCount: Int,
        deadline: Date
    ) async throws -> AvatarAssetCompactionBatchResult {
        try await AvatarAssetMaintenanceService.compactStoredAvatarsBatch(
            context: modelContext,
            cursor: cursor,
            maximumRecordCount: maximumRecordCount,
            deadline: deadline
        )
    }

    /// Compatibility helper for deterministic tests and explicit manual work.
    /// Startup uses `runBatch` so each launch consumes one budgeted page.
    func compactStoredAvatars() async {
        await AvatarAssetMaintenanceService.compactStoredAvatars(context: modelContext)
    }
}
