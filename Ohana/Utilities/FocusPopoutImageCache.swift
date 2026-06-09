import Foundation
import UIKit

@MainActor
enum FocusPopoutImageCache {
    private struct Entry {
        let signature: String
        let image: UIImage?
    }

    private static var entries: [UUID: Entry] = [:]

    static func cachedImage(for id: UUID, signature: String) -> UIImage? {
        guard !signature.isEmpty,
              let cached = entries[id],
              cached.signature == signature else {
            return nil
        }
        return cached.image
    }

    @discardableResult
    static func preload(payloads: [FocusWalletAvatarCache.Payload]) async -> Bool {
        var didChange = false
        let decodePayloads: [(UUID, Data, String)] = payloads.compactMap { payload in
            guard let data = payload.data, !data.isEmpty else {
                if entries.removeValue(forKey: payload.id) != nil {
                    didChange = true
                }
                return nil
            }
            let signature = FocusWalletAvatarCache.signature(for: data)
            if let cached = entries[payload.id], cached.signature == signature {
                return nil
            }
            return (payload.id, data, signature)
        }
        guard !decodePayloads.isEmpty else { return didChange }

        let decoded = await Task.detached(priority: .userInitiated) {
            decodePayloads.map { id, data, signature in
                (id, signature, decodedImage(from: data))
            }
        }.value

        for (id, signature, image) in decoded {
            entries[id] = Entry(signature: signature, image: image)
        }
        return true
    }

    nonisolated private static func decodedImage(from data: Data) -> UIImage? {
        let raw = UIImage(data: data)
        return raw.flatMap { ImageCutoutService.trimmedTransparentSubjectImage(from: $0) } ?? raw
    }
}
