import Foundation
import ImageIO
import UIKit

@MainActor
enum FocusWalletAvatarCache {
    struct Entry {
        let image: UIImage?
        let isTransparent: Bool
        let signature: String
        let isFinal: Bool
    }

    nonisolated struct Payload: Sendable {
        let id: UUID
        let data: Data?
    }

    private typealias PreviewDecodeResult = [(UUID, Entry)]
    private typealias FullDecodeResult = [(UUID, UIImage?, Bool, String, Bool, Data?, String)]

    private static var entries: [UUID: Entry] = [:]
    private static var inFlightKeys: Set<String> = []
    /// These are the actual detached workers, rather than bookkeeping-only
    /// keys. Memory pressure and the owning route can therefore cancel decode
    /// and alpha/preview generation before more images are processed.
    private static var previewDecodeTasks: [UUID: Task<PreviewDecodeResult, Never>] = [:]
    private static var fullDecodeTasks: [UUID: Task<FullDecodeResult, Never>] = [:]
    private static var accessTicks: [UUID: UInt64] = [:]
    private static var nextAccessTick: UInt64 = 0
    private static var evictionGeneration = 0

    @discardableResult
    static func seedPreviewEntries(payloads: [Payload]) async -> Bool {
        ensureMemoryWarningEvictionRegistered()
        var didChange = false
        var previewRequests: [(UUID, String)] = []
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "avatar_preview_decode",
            requestedItemCount: payloads.count
        )
        guard budget.hasWorkCapacity else { return false }

        for payload in payloads.prefix(budget.maximumItemCount) {
            guard let data = payload.data else {
                if entries.removeValue(forKey: payload.id) != nil {
                    didChange = true
                }
                accessTicks.removeValue(forKey: payload.id)
                continue
            }

            let signature = signature(for: data)
            if let cached = entries[payload.id],
               cached.signature == signature,
               cached.image != nil {
                recordAccess(for: payload.id)
                continue
            }

            previewRequests.append((payload.id, signature))
        }

        guard !previewRequests.isEmpty else { return didChange }
        let generation = evictionGeneration
        let startedAt = Date()
        let priority: TaskPriority = budget.allowsExpensiveWork ? .utility : .background
        let taskID = UUID()
        let task = Task.detached(priority: priority) { () -> PreviewDecodeResult in // smoothness: retained bounded cache-hit disk IO, image decode, and alpha scan stay off the main actor.
            var resolved: [(UUID, Entry)] = []
            for (id, signature) in previewRequests {
                guard !Task.isCancelled, budget.hasTimeRemaining(since: startedAt) else { break }
                if let entry = previewEntry(for: id, signature: signature) {
                    guard !Task.isCancelled else { break }
                    resolved.append((id, entry))
                }
            }
            return resolved
        }
        previewDecodeTasks[taskID] = task
        let previews = await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
        previewDecodeTasks.removeValue(forKey: taskID)

        guard !Task.isCancelled, generation == evictionGeneration else { return didChange }

        for (id, preview) in previews {
            if let cached = entries[id] {
                guard cached.signature == preview.signature else { continue }
                if cached.isFinal { continue }
            }
            entries[id] = preview
            recordAccess(for: id)
            didChange = true
        }
        trimToCapacity()

        return didChange
    }

    static func cachedEntry(for cardId: UUID, signature: String) -> Entry? {
        ensureMemoryWarningEvictionRegistered()
        guard !signature.isEmpty,
              let cached = entries[cardId],
              cached.signature == signature else {
            return nil
        }
        recordAccess(for: cardId)
        return cached
    }

    static func storeDecodedImage(cardId: UUID, data: Data?, image: UIImage?, isTransparent: Bool) {
        ensureMemoryWarningEvictionRegistered()
        guard let data, let image else { return }
        let signature = signature(for: data)
        entries[cardId] = Entry(
            image: image,
            isTransparent: isTransparent,
            signature: signature,
            isFinal: true
        )
        recordAccess(for: cardId)
        trimToCapacity()
    }

    @discardableResult
    static func preload(payloads: [Payload]) async -> Bool {
        ensureMemoryWarningEvictionRegistered()
        var didChange = false
        let generation = evictionGeneration
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "avatar_full_decode",
            requestedItemCount: payloads.count
        )
        guard budget.hasWorkCapacity else { return false }
        let decodePayloads: [(UUID, Data, String, String)] = payloads.prefix(budget.maximumItemCount).compactMap { payload in
            guard let data = payload.data else {
                if entries.removeValue(forKey: payload.id) != nil {
                    didChange = true
                }
                accessTicks.removeValue(forKey: payload.id)
                return nil
            }
            let signature = signature(for: data)
            if let cached = entries[payload.id],
               cached.signature == signature,
               cached.isFinal {
                recordAccess(for: payload.id)
                return nil
            }
            let inFlightKey = "\(payload.id.uuidString):\(signature)"
            guard !inFlightKeys.contains(inFlightKey) else { return nil }
            inFlightKeys.insert(inFlightKey)
            return (payload.id, data, signature, inFlightKey)
        }
        guard !decodePayloads.isEmpty else { return didChange }

        let decodeStartedAt = CFAbsoluteTimeGetCurrent()
        let startedAt = Date()
        let priority: TaskPriority = budget.allowsExpensiveWork ? .utility : .background
        let taskID = UUID()
        let task = Task.detached(priority: priority) { () -> FullDecodeResult in // smoothness: retained bounded off-main media/compute worker; cancellation and runtime budget stop long preload batches.
            var resolved: [(UUID, UIImage?, Bool, String, Bool, Data?, String)] = []
            for (id, data, signature, inFlightKey) in decodePayloads {
                guard !Task.isCancelled, budget.hasTimeRemaining(since: startedAt) else { break }
                let entry = decodedEntry(from: data, signature: signature)
                guard !Task.isCancelled, budget.hasTimeRemaining(since: startedAt) else { break }
                let previewData = entry.image.flatMap { previewPNGData(from: $0) }
                guard !Task.isCancelled else { break }
                resolved.append((
                    id,
                    entry.image,
                    entry.isTransparent,
                    entry.signature,
                    entry.isFinal,
                    previewData,
                    inFlightKey
                ))
            }
            return resolved
        }
        fullDecodeTasks[taskID] = task
        let decoded = await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
        fullDecodeTasks.removeValue(forKey: taskID)

        guard !Task.isCancelled, generation == evictionGeneration else {
            for (_, _, _, inFlightKey) in decodePayloads {
                inFlightKeys.remove(inFlightKey)
            }
            return didChange
        }

        let completedInFlightKeys = Set(decoded.map(\.6))
        for (_, _, _, inFlightKey) in decodePayloads where !completedInFlightKeys.contains(inFlightKey) {
            inFlightKeys.remove(inFlightKey)
        }

        for (id, image, isTransparent, signature, isFinal, previewData, inFlightKey) in decoded {
            inFlightKeys.remove(inFlightKey)
            entries[id] = Entry(image: image, isTransparent: isTransparent, signature: signature, isFinal: isFinal)
            recordAccess(for: id)
            if let previewData {
                writePreviewData(previewData, cardId: id, signature: signature)
            }
        }
        trimToCapacity()
        AppPerformanceMonitor.shared.record("首页头像解码", startedAt: decodeStartedAt, note: "\(decoded.count) 张")
        return true
    }

    nonisolated static func signature(for data: Data) -> String {
        MediaPayloadSignature.signature(for: data)
    }

    private static func ensureMemoryWarningEvictionRegistered() {
        MemoryWarningEvictionRegistry.register(ownerID: "focus-wallet-avatar-cache") {
            evictDecodedCacheForMemoryWarning()
        }
    }

    private static func recordAccess(for id: UUID) {
        nextAccessTick &+= 1
        accessTicks[id] = nextAccessTick
    }

    private static func trimToCapacity() {
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "avatar_cache",
            requestedItemCount: 24
        )
        let capacity = budget.allowsExpensiveWork ? 24 : 8
        guard entries.count > capacity else { return }
        let evictionIDs = accessTicks
            .sorted { $0.value < $1.value }
            .prefix(entries.count - capacity)
            .map(\.key)
        for id in evictionIDs {
            entries.removeValue(forKey: id)
            accessTicks.removeValue(forKey: id)
        }
    }

    private static func evictDecodedCacheForMemoryWarning() {
        guard !entries.isEmpty || !inFlightKeys.isEmpty || !previewDecodeTasks.isEmpty || !fullDecodeTasks.isEmpty else { return }
        entries.removeAll(keepingCapacity: false)
        inFlightKeys.removeAll(keepingCapacity: false)
        accessTicks.removeAll(keepingCapacity: false)
        for task in previewDecodeTasks.values {
            task.cancel()
        }
        for task in fullDecodeTasks.values {
            task.cancel()
        }
        previewDecodeTasks.removeAll(keepingCapacity: false)
        fullDecodeTasks.removeAll(keepingCapacity: false)
        evictionGeneration &+= 1
    }

    #if DEBUG
        static func resetForTesting() {
            entries.removeAll(keepingCapacity: false)
            inFlightKeys.removeAll(keepingCapacity: false)
            accessTicks.removeAll(keepingCapacity: false)
            for task in previewDecodeTasks.values {
                task.cancel()
            }
            for task in fullDecodeTasks.values {
                task.cancel()
            }
            previewDecodeTasks.removeAll(keepingCapacity: false)
            fullDecodeTasks.removeAll(keepingCapacity: false)
            evictionGeneration &+= 1
        }
    #endif

    private nonisolated static func previewEntry(for cardId: UUID, signature: String) -> Entry? {
        let url = previewURL(cardId: cardId, signature: signature)
        guard let data = try? Data(contentsOf: url), // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
              let image = UIImage(data: data) else { return nil } // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        let isTransparent = ImageCutoutService.imageHasTransparentPixels(image)
        return Entry(image: image, isTransparent: isTransparent, signature: signature, isFinal: false)
    }

    private nonisolated static func writePreviewData(_ data: Data, cardId: UUID, signature: String) {
        let directory = previewDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: previewURL(cardId: cardId, signature: signature), options: [.atomic])
    }

    private nonisolated static func previewURL(cardId: UUID, signature: String) -> URL {
        previewDirectory()
            .appendingPathComponent("\(cardId.uuidString)-\(signature).png", isDirectory: false)
    }

    private nonisolated static func previewDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Ohana/HomeAvatarPreviewsV2", isDirectory: true)
    }

    private nonisolated static func decodedEntry(from data: Data, signature: String) -> Entry {
        let image = decodedImage(from: data)
        let isTransparent = image.map { ImageCutoutService.imageHasTransparentPixels($0) } ?? false
        let displayImage = isTransparent ? image.flatMap { ImageCutoutService.trimmedTransparentSubjectImage(from: $0) } ?? image : image
        return Entry(image: displayImage, isTransparent: isTransparent, signature: signature, isFinal: true)
    }

    private nonisolated static func previewPNGData(from image: UIImage, maxPixel: CGFloat = 1600) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return image.pngData() }
        let scale = min(1, maxPixel / longest)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let preview = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return preview.pngData()
    }

    private nonisolated static func decodedImage(from data: Data, maxPixel: CGFloat = 2200) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }
        return UIImage(cgImage: cgImage)
    }
}
