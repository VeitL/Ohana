import Foundation
import UIKit

@MainActor
enum FocusPopoutImageCache {
    private struct Entry {
        let signature: String
        let image: UIImage?
    }

    private typealias DecodeResult = [(UUID, String, UIImage?)]

    private static var entries: [UUID: Entry] = [:]
    /// Retains the actual off-main decode work so memory pressure and the
    /// outer route task cancel decoding itself, not only the cache commit.
    private static var decodeTasks: [UUID: Task<DecodeResult, Never>] = [:]
    private static var accessTicks: [UUID: UInt64] = [:]
    private static var nextAccessTick: UInt64 = 0
    private static var evictionGeneration = 0

    static func cachedImage(for id: UUID, signature: String) -> UIImage? {
        ensureMemoryWarningEvictionRegistered()
        guard !signature.isEmpty,
              let cached = entries[id],
              cached.signature == signature else {
            return nil
        }
        recordAccess(for: id)
        return cached.image
    }

    @discardableResult
    static func preload(payloads: [FocusWalletAvatarCache.Payload]) async -> Bool {
        ensureMemoryWarningEvictionRegistered()
        var didChange = false
        let generation = evictionGeneration
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "avatar_popout_decode",
            requestedItemCount: payloads.count
        )
        guard budget.hasWorkCapacity else { return false }
        let decodePayloads: [(UUID, Data, String)] = payloads.prefix(budget.maximumItemCount).compactMap { payload in
            guard let data = payload.data, !data.isEmpty else {
                if entries.removeValue(forKey: payload.id) != nil {
                    didChange = true
                }
                accessTicks.removeValue(forKey: payload.id)
                return nil
            }
            let signature = FocusWalletAvatarCache.signature(for: data)
            if let cached = entries[payload.id], cached.signature == signature {
                recordAccess(for: payload.id)
                return nil
            }
            return (payload.id, data, signature)
        }
        guard !decodePayloads.isEmpty else { return didChange }

        let startedAt = Date()
        let priority: TaskPriority = budget.allowsExpensiveWork ? .utility : .background
        let taskID = UUID()
        let task = Task.detached(priority: priority) { () -> DecodeResult in // smoothness: retained bounded off-main popout decode; cancellation and low-power budget stop long preload batches.
            var resolved: [(UUID, String, UIImage?)] = []
            for (id, data, signature) in decodePayloads {
                guard !Task.isCancelled, budget.hasTimeRemaining(since: startedAt) else { break }
                let image = decodedImage(from: data)
                guard !Task.isCancelled else { break }
                resolved.append((id, signature, image))
            }
            return resolved
        }
        decodeTasks[taskID] = task
        let decoded = await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
        decodeTasks.removeValue(forKey: taskID)

        guard !Task.isCancelled, generation == evictionGeneration else {
            return didChange
        }

        for (id, signature, image) in decoded {
            entries[id] = Entry(signature: signature, image: image)
            recordAccess(for: id)
        }
        trimToCapacity()
        return true
    }

    private static func ensureMemoryWarningEvictionRegistered() {
        MemoryWarningEvictionRegistry.register(ownerID: "focus-popout-image-cache") {
            evictDecodedCacheForMemoryWarning()
        }
    }

    private static func recordAccess(for id: UUID) {
        nextAccessTick &+= 1
        accessTicks[id] = nextAccessTick
    }

    private static func trimToCapacity() {
        let budget = AppWorkloadPolicy.shared.backgroundWorkBudget(
            operation: "avatar_popout_cache",
            requestedItemCount: 16
        )
        let capacity = budget.allowsExpensiveWork ? 16 : 6
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
        guard !entries.isEmpty || !decodeTasks.isEmpty else { return }
        entries.removeAll(keepingCapacity: false)
        accessTicks.removeAll(keepingCapacity: false)
        for task in decodeTasks.values {
            task.cancel()
        }
        decodeTasks.removeAll(keepingCapacity: false)
        evictionGeneration &+= 1
    }

    #if DEBUG
        static func resetForTesting() {
            entries.removeAll(keepingCapacity: false)
            accessTicks.removeAll(keepingCapacity: false)
            for task in decodeTasks.values {
                task.cancel()
            }
            decodeTasks.removeAll(keepingCapacity: false)
            evictionGeneration &+= 1
        }
    #endif

    private nonisolated static func decodedImage(from data: Data) -> UIImage? {
        let raw = UIImage(data: data) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        return raw.flatMap { ImageCutoutService.trimmedTransparentSubjectImage(from: $0) } ?? raw
    }
}
