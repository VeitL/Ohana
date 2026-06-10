import Foundation
import UIKit

@MainActor
enum FocusPopoutImageCache {
    private struct Entry {
        let signature: String
        let image: UIImage?
    }

    private static var entries: [UUID: Entry] = [:]
    private static var evictionGeneration = 0

    static func cachedImage(for id: UUID, signature: String) -> UIImage? {
        ensureMemoryWarningEvictionRegistered()
        guard !signature.isEmpty,
              let cached = entries[id],
              cached.signature == signature else {
            return nil
        }
        return cached.image
    }

    @discardableResult
    static func preload(payloads: [FocusWalletAvatarCache.Payload]) async -> Bool {
        ensureMemoryWarningEvictionRegistered()
        var didChange = false
        let generation = evictionGeneration
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

        let decoded = await Task.detached(priority: .userInitiated) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            decodePayloads.map { id, data, signature in
                (id, signature, decodedImage(from: data))
            }
        }.value

        guard generation == evictionGeneration else {
            return didChange
        }

        for (id, signature, image) in decoded {
            entries[id] = Entry(signature: signature, image: image)
        }
        return true
    }

    private static func ensureMemoryWarningEvictionRegistered() {
        MemoryWarningEvictionRegistry.register(ownerID: "focus-popout-image-cache") {
            evictDecodedCacheForMemoryWarning()
        }
    }

    private static func evictDecodedCacheForMemoryWarning() {
        guard !entries.isEmpty else { return }
        entries.removeAll(keepingCapacity: false)
        evictionGeneration &+= 1
    }

    #if DEBUG
        static func resetForTesting() {
            entries.removeAll(keepingCapacity: false)
            evictionGeneration &+= 1
        }
    #endif

    private nonisolated static func decodedImage(from data: Data) -> UIImage? {
        let raw = UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        return raw.flatMap { ImageCutoutService.trimmedTransparentSubjectImage(from: $0) } ?? raw
    }
}
