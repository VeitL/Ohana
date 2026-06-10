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

    private static var entries: [UUID: Entry] = [:]
    private static var inFlightKeys: Set<String> = []
    private static var evictionGeneration = 0

    @discardableResult
    static func seedPreviewEntries(payloads: [Payload]) -> Bool {
        ensureMemoryWarningEvictionRegistered()
        var didChange = false

        for payload in payloads {
            guard let data = payload.data else {
                if entries.removeValue(forKey: payload.id) != nil {
                    didChange = true
                }
                continue
            }

            let signature = signature(for: data)
            if let cached = entries[payload.id],
               cached.signature == signature,
               cached.image != nil {
                continue
            }

            guard let preview = previewEntry(for: payload.id, signature: signature) else {
                continue
            }
            entries[payload.id] = preview
            didChange = true
        }

        return didChange
    }

    static func cachedEntry(for cardId: UUID, signature: String) -> Entry? {
        ensureMemoryWarningEvictionRegistered()
        guard !signature.isEmpty,
              let cached = entries[cardId],
              cached.signature == signature else {
            return nil
        }
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
    }

    @discardableResult
    static func preload(payloads: [Payload]) async -> Bool {
        ensureMemoryWarningEvictionRegistered()
        var didChange = false
        let generation = evictionGeneration
        let decodePayloads: [(UUID, Data, String, String)] = payloads.compactMap { payload in
            guard let data = payload.data else {
                if entries.removeValue(forKey: payload.id) != nil {
                    didChange = true
                }
                return nil
            }
            let signature = signature(for: data)
            if let cached = entries[payload.id],
               cached.signature == signature,
               cached.isFinal {
                return nil
            }
            let inFlightKey = "\(payload.id.uuidString):\(signature)"
            guard !inFlightKeys.contains(inFlightKey) else { return nil }
            inFlightKeys.insert(inFlightKey)
            return (payload.id, data, signature, inFlightKey)
        }
        guard !decodePayloads.isEmpty else { return didChange }

        let decodeStartedAt = CFAbsoluteTimeGetCurrent()
        let decoded = await Task.detached(priority: .userInitiated) {
            decodePayloads.map { id, data, signature, inFlightKey in
                let entry = decodedEntry(from: data, signature: signature)
                let previewData = entry.image.flatMap { previewPNGData(from: $0) }
                return (
                    id,
                    entry.image,
                    entry.isTransparent,
                    entry.signature,
                    entry.isFinal,
                    previewData,
                    inFlightKey
                )
            }
        }.value

        guard generation == evictionGeneration else {
            for (_, _, _, inFlightKey) in decodePayloads {
                inFlightKeys.remove(inFlightKey)
            }
            return didChange
        }

        for (id, image, isTransparent, signature, isFinal, previewData, inFlightKey) in decoded {
            inFlightKeys.remove(inFlightKey)
            entries[id] = Entry(image: image, isTransparent: isTransparent, signature: signature, isFinal: isFinal)
            if let previewData {
                writePreviewData(previewData, cardId: id, signature: signature)
            }
        }
        AppPerformanceMonitor.shared.record("首页头像解码", startedAt: decodeStartedAt, note: "\(decoded.count) 张")
        return true
    }

    nonisolated static func signature(for data: Data) -> String {
        let head = data.prefix(12).map { String(format: "%02x", $0) }.joined()
        let tail = data.suffix(12).map { String(format: "%02x", $0) }.joined()
        return "\(data.count)-\(head)-\(tail)"
    }

    private static func ensureMemoryWarningEvictionRegistered() {
        MemoryWarningEvictionRegistry.register(ownerID: "focus-wallet-avatar-cache") {
            evictDecodedCacheForMemoryWarning()
        }
    }

    private static func evictDecodedCacheForMemoryWarning() {
        guard !entries.isEmpty || !inFlightKeys.isEmpty else { return }
        entries.removeAll(keepingCapacity: false)
        inFlightKeys.removeAll(keepingCapacity: false)
        evictionGeneration &+= 1
    }

#if DEBUG
    static func resetForTesting() {
        entries.removeAll(keepingCapacity: false)
        inFlightKeys.removeAll(keepingCapacity: false)
        evictionGeneration &+= 1
    }
#endif

    nonisolated private static func previewEntry(for cardId: UUID, signature: String) -> Entry? {
        let url = previewURL(cardId: cardId, signature: signature)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        let isTransparent = ImageCutoutService.imageHasTransparentPixels(image)
        return Entry(image: image, isTransparent: isTransparent, signature: signature, isFinal: false)
    }

    nonisolated private static func writePreviewData(_ data: Data, cardId: UUID, signature: String) {
        let directory = previewDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: previewURL(cardId: cardId, signature: signature), options: [.atomic])
    }

    nonisolated private static func previewURL(cardId: UUID, signature: String) -> URL {
        previewDirectory()
            .appendingPathComponent("\(cardId.uuidString)-\(signature).png", isDirectory: false)
    }

    nonisolated private static func previewDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Ohana/HomeAvatarPreviewsV2", isDirectory: true)
    }

    nonisolated private static func decodedEntry(from data: Data, signature: String) -> Entry {
        let image = decodedImage(from: data)
        let isTransparent = image.map { ImageCutoutService.imageHasTransparentPixels($0) } ?? false
        let displayImage = isTransparent ? image.flatMap { ImageCutoutService.trimmedTransparentSubjectImage(from: $0) } ?? image : image
        return Entry(image: displayImage, isTransparent: isTransparent, signature: signature, isFinal: true)
    }

    nonisolated private static func previewPNGData(from image: UIImage, maxPixel: CGFloat = 1_600) -> Data? {
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

    nonisolated private static func decodedImage(from data: Data, maxPixel: CGFloat = 2_200) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data)
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
