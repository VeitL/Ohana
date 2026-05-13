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

    struct Payload {
        let id: UUID
        let data: Data?
    }

    private static var entries: [UUID: Entry] = [:]
    private static var inFlightKeys: Set<String> = []

    static func entry(for cardId: UUID, data: Data?) -> Entry {
        guard let data else {
            entries.removeValue(forKey: cardId)
            return Entry(image: nil, isTransparent: false, signature: "", isFinal: true)
        }

        let signature = signature(for: data)
        if let cached = entries[cardId], cached.signature == signature {
            return cached
        }

        let preview = quickPreviewImage(from: data)
        let entry = Entry(image: preview, isTransparent: false, signature: signature, isFinal: false)
        entries[cardId] = entry
        return entry
    }

    @discardableResult
    static func preload(payloads: [Payload]) async -> Bool {
        var didChange = false
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
                return (
                    id,
                    entry.image,
                    entry.isTransparent,
                    entry.signature,
                    entry.isFinal,
                    inFlightKey
                )
            }
        }.value

        for (id, image, isTransparent, signature, isFinal, inFlightKey) in decoded {
            inFlightKeys.remove(inFlightKey)
            entries[id] = Entry(image: image, isTransparent: isTransparent, signature: signature, isFinal: isFinal)
        }
        AppPerformanceMonitor.shared.record("首页头像解码", startedAt: decodeStartedAt, note: "\(decoded.count) 张")
        return true
    }

    nonisolated static func signature(for data: Data) -> String {
        let head = data.prefix(12).map { String(format: "%02x", $0) }.joined()
        let tail = data.suffix(12).map { String(format: "%02x", $0) }.joined()
        return "\(data.count)-\(head)-\(tail)"
    }

    nonisolated private static func decodedEntry(from data: Data, signature: String) -> Entry {
        let image = decodedImage(from: data)
        let isTransparent = image.map { ImageCutoutService.imageHasTransparentPixels($0) } ?? false
        let displayImage = isTransparent ? image.flatMap { ImageCutoutService.trimmedTransparentSubjectImage(from: $0) } ?? image : image
        return Entry(image: displayImage, isTransparent: isTransparent, signature: signature, isFinal: true)
    }

    nonisolated private static func quickPreviewImage(from data: Data) -> UIImage? {
        decodedImage(from: data, maxPixel: 320)
    }

    nonisolated private static func decodedImage(from data: Data, maxPixel: CGFloat = 700) -> UIImage? {
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
