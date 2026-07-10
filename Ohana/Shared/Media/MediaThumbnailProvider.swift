//
//  MediaThumbnailProvider.swift
//  Ohana
//
//  Shared downsampled thumbnail cache for user-imported media.
//

import Foundation
import UIKit

struct MediaThumbnailKey: Hashable, Sendable {
    let id: String
    let sourceSignature: String
    let maxPixel: Int

    init(id: String, sourceSignature: String, maxPixel: CGFloat) {
        self.id = id
        self.sourceSignature = sourceSignature
        self.maxPixel = max(1, Int(maxPixel.rounded(.up)))
    }
}

enum MediaPayloadSignature {
    nonisolated static func signature(for data: Data) -> String {
        let head = data.prefix(12).map { String(format: "%02x", $0) }.joined()
        let tail = data.suffix(12).map { String(format: "%02x", $0) }.joined()
        return "\(data.count)-\(head)-\(tail)"
    }
}

@MainActor
enum MediaThumbnailProvider {
    struct Result {
        let image: UIImage
        let isTransparent: Bool
    }

    private struct InFlightImageDecode {
        let id: UUID
        let task: Task<UIImage?, Never>
    }

    private struct InFlightTransparencyScan {
        let id: UUID
        let task: Task<Bool?, Never>
    }

    private static var images: [MediaThumbnailKey: UIImage] = [:]
    private static var transparencyFlags: [MediaThumbnailKey: Bool] = [:]
    /// Each handle is the task that performs the actual off-main work. This is
    /// deliberately not a parent wrapper around a detached decode, so route
    /// cancellation and memory pressure reach the decoder itself.
    private static var inFlight: [MediaThumbnailKey: InFlightImageDecode] = [:]
    private static var transparencyInFlight: [MediaThumbnailKey: InFlightTransparencyScan] = [:]
    private static var accessTicks: [MediaThumbnailKey: UInt64] = [:]
    private static var nextAccessTick: UInt64 = 0
    private static var evictionGeneration = 0

    nonisolated static func signature(for data: Data) -> String {
        MediaPayloadSignature.signature(for: data)
    }

    static func cachedImage(for key: MediaThumbnailKey) -> UIImage? {
        ensureMemoryWarningEvictionRegistered()
        guard !key.sourceSignature.isEmpty else { return nil }
        guard let image = images[key] else { return nil }
        recordAccess(for: key)
        return image
    }

    static func image(
        for key: MediaThumbnailKey,
        dataProvider: @escaping @MainActor () -> Data?
    ) async -> UIImage? {
        await image(for: key, asyncDataProvider: {
            await MainActor.run {
                dataProvider()
            }
        })
    }

    static func image(
        for key: MediaThumbnailKey,
        asyncDataProvider: @escaping @Sendable () async -> Data?
    ) async -> UIImage? {
        ensureMemoryWarningEvictionRegistered()
        guard !key.sourceSignature.isEmpty else { return nil }
        if let cached = images[key] {
            recordAccess(for: key)
            return cached
        }
        if let inFlightDecode = inFlight[key] {
            return await withTaskCancellationHandler(operation: {
                await inFlightDecode.task.value
            }, onCancel: {
                inFlightDecode.task.cancel()
            })
        }

        let generation = evictionGeneration
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "media_thumbnail_decode",
            requestedItemCount: 1
        )
        guard budget.hasWorkCapacity else { return nil }
        let priority: TaskPriority = budget.allowsExpensiveWork ? .utility : .background
        let startedAt = Date()
        let task = Task.detached(priority: priority) { () -> UIImage? in // smoothness: bounded shared thumbnail worker; the retained task performs both loading and decode off-main.
            guard !Task.isCancelled else { return nil }
            guard let data = await asyncDataProvider() else {
                return nil
            }
            guard !Task.isCancelled, budget.hasTimeRemaining(since: startedAt) else { return nil }
            let image = AttachmentImageDecoder.image(from: data, maxPixel: CGFloat(key.maxPixel))
            guard !Task.isCancelled else { return nil }
            return image
        }
        let inFlightDecode = InFlightImageDecode(id: UUID(), task: task)
        inFlight[key] = inFlightDecode

        let decoded = await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
        if inFlight[key]?.id == inFlightDecode.id {
            inFlight.removeValue(forKey: key)
        }
        guard !Task.isCancelled,
              generation == evictionGeneration else {
            return nil
        }
        guard let decoded else {
            images.removeValue(forKey: key)
            accessTicks.removeValue(forKey: key)
            return nil
        }
        images[key] = decoded
        recordAccess(for: key)
        trimToCapacity()
        return decoded
    }

    static func imageWithTransparency(
        for key: MediaThumbnailKey,
        dataProvider: @escaping @MainActor () -> Data?
    ) async -> Result? {
        await imageWithTransparency(for: key, asyncDataProvider: {
            await MainActor.run {
                dataProvider()
            }
        })
    }

    static func imageWithTransparency(
        for key: MediaThumbnailKey,
        asyncDataProvider: @escaping @Sendable () async -> Data?
    ) async -> Result? {
        guard let image = await image(for: key, asyncDataProvider: asyncDataProvider) else {
            transparencyFlags.removeValue(forKey: key)
            return nil
        }

        if let cachedTransparency = transparencyFlags[key] {
            recordAccess(for: key)
            return Result(image: image, isTransparent: cachedTransparency)
        }

        let generation = evictionGeneration
        let inFlightScan: InFlightTransparencyScan
        if let existingScan = transparencyInFlight[key] {
            inFlightScan = existingScan
        } else {
            let task = Task.detached(priority: .utility) { () -> Bool? in // smoothness: retained off-main alpha scan is cancelled by route teardown or memory pressure.
                guard !Task.isCancelled else { return nil }
                let isTransparent = ImageCutoutService.imageHasTransparentPixels(image)
                guard !Task.isCancelled else { return nil }
                return isTransparent
            }
            let createdScan = InFlightTransparencyScan(id: UUID(), task: task)
            transparencyInFlight[key] = createdScan
            inFlightScan = createdScan
        }
        let transparencyResult = await withTaskCancellationHandler(operation: {
            await inFlightScan.task.value
        }, onCancel: {
            inFlightScan.task.cancel()
        })
        if transparencyInFlight[key]?.id == inFlightScan.id {
            transparencyInFlight.removeValue(forKey: key)
        }
        guard let isTransparent = transparencyResult else { return nil }
        guard !Task.isCancelled,
              generation == evictionGeneration else {
            return nil
        }
        transparencyFlags[key] = isTransparent
        trimToCapacity()
        return Result(image: image, isTransparent: isTransparent)
    }

    private static func recordAccess(for key: MediaThumbnailKey) {
        nextAccessTick &+= 1
        accessTicks[key] = nextAccessTick
    }

    /// Bounded LRU keeps a long 500-image scroll from retaining every decoded
    /// thumbnail. Low Power / app power-saving mode deliberately retains a
    /// smaller working set and lets off-screen tiles rebuild lazily.
    private static func trimToCapacity() {
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "media_thumbnail_cache",
            requestedItemCount: 48
        )
        let capacity = budget.allowsExpensiveWork ? 48 : 16
        guard images.count > capacity else { return }

        let evictionKeys = accessTicks
            .sorted { $0.value < $1.value }
            .prefix(images.count - capacity)
            .map(\.key)
        for key in evictionKeys {
            images.removeValue(forKey: key)
            transparencyFlags.removeValue(forKey: key)
            accessTicks.removeValue(forKey: key)
        }
    }

    private static func ensureMemoryWarningEvictionRegistered() {
        MemoryWarningEvictionRegistry.register(ownerID: "media-thumbnail-provider") {
            evictDecodedCacheForMemoryWarning()
        }
    }

    private static func evictDecodedCacheForMemoryWarning() {
        guard !images.isEmpty || !transparencyFlags.isEmpty || !inFlight.isEmpty || !transparencyInFlight.isEmpty else { return }
        images.removeAll(keepingCapacity: false)
        transparencyFlags.removeAll(keepingCapacity: false)
        accessTicks.removeAll(keepingCapacity: false)
        for inFlightDecode in inFlight.values {
            inFlightDecode.task.cancel()
        }
        for inFlightScan in transparencyInFlight.values {
            inFlightScan.task.cancel()
        }
        inFlight.removeAll(keepingCapacity: false)
        transparencyInFlight.removeAll(keepingCapacity: false)
        evictionGeneration &+= 1
    }

    #if DEBUG
        static func resetForTesting() {
            images.removeAll(keepingCapacity: false)
            transparencyFlags.removeAll(keepingCapacity: false)
            accessTicks.removeAll(keepingCapacity: false)
            for inFlightDecode in inFlight.values {
                inFlightDecode.task.cancel()
            }
            for inFlightScan in transparencyInFlight.values {
                inFlightScan.task.cancel()
            }
            inFlight.removeAll(keepingCapacity: false)
            transparencyInFlight.removeAll(keepingCapacity: false)
            evictionGeneration &+= 1
        }
    #endif
}
