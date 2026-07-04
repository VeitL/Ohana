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

    private static var images: [MediaThumbnailKey: UIImage] = [:]
    private static var transparencyFlags: [MediaThumbnailKey: Bool] = [:]
    private static var inFlight: [MediaThumbnailKey: Task<UIImage?, Never>] = [:]
    private static var evictionGeneration = 0

    nonisolated static func signature(for data: Data) -> String {
        MediaPayloadSignature.signature(for: data)
    }

    static func cachedImage(for key: MediaThumbnailKey) -> UIImage? {
        ensureMemoryWarningEvictionRegistered()
        guard !key.sourceSignature.isEmpty else { return nil }
        return images[key]
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
            return cached
        }
        if let task = inFlight[key] {
            return await task.value
        }

        let generation = evictionGeneration
        let task = Task(priority: .utility) { () -> UIImage? in // smoothness: allow shared thumbnail worker; data loading chooses its actor, decode stays off-main.
            guard let data = await asyncDataProvider() else {
                return nil
            }
            return await Task.detached(priority: .utility) { () -> UIImage? in
                AttachmentImageDecoder.image(from: data, maxPixel: CGFloat(key.maxPixel))
            }.value
        }
        inFlight[key] = task

        let decoded = await task.value
        inFlight.removeValue(forKey: key)
        guard !Task.isCancelled,
              generation == evictionGeneration else {
            return nil
        }
        guard let decoded else {
            images.removeValue(forKey: key)
            return nil
        }
        images[key] = decoded
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
            return Result(image: image, isTransparent: cachedTransparency)
        }

        let generation = evictionGeneration
        let isTransparent = await Task.detached(priority: .utility) { // smoothness: allow shared off-main thumbnail alpha scan; keyed cache evicts on memory pressure.
            ImageCutoutService.imageHasTransparentPixels(image)
        }.value
        guard !Task.isCancelled,
              generation == evictionGeneration else {
            return Result(image: image, isTransparent: isTransparent)
        }
        transparencyFlags[key] = isTransparent
        return Result(image: image, isTransparent: isTransparent)
    }

    private static func ensureMemoryWarningEvictionRegistered() {
        MemoryWarningEvictionRegistry.register(ownerID: "media-thumbnail-provider") {
            evictDecodedCacheForMemoryWarning()
        }
    }

    private static func evictDecodedCacheForMemoryWarning() {
        guard !images.isEmpty || !transparencyFlags.isEmpty || !inFlight.isEmpty else { return }
        images.removeAll(keepingCapacity: false)
        transparencyFlags.removeAll(keepingCapacity: false)
        for task in inFlight.values {
            task.cancel()
        }
        inFlight.removeAll(keepingCapacity: false)
        evictionGeneration &+= 1
    }

    #if DEBUG
        static func resetForTesting() {
            images.removeAll(keepingCapacity: false)
            transparencyFlags.removeAll(keepingCapacity: false)
            for task in inFlight.values {
                task.cancel()
            }
            inFlight.removeAll(keepingCapacity: false)
            evictionGeneration &+= 1
        }
    #endif
}
