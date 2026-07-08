//
//  AvatarPipeline.swift
//  Ohana
//
//  Unified first-screen avatar preview, decode, cache, and cancellation entry.
//

import Combine
import Foundation
import UIKit

@MainActor
final class AvatarPipeline: ObservableObject {
    @Published private(set) var revision = 0
    private var decodeTasks: [String: Task<Void, Never>] = [:]

    init() {}

    func seedPreviewEntries(
        _ payloads: [FocusWalletAvatarCache.Payload],
        key: String,
        delayMilliseconds: UInt64 = 16
    ) {
        let taskKey = previewTaskKey(for: key)
        decodeTasks[taskKey]?.cancel()
        decodeTasks[taskKey] = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else { return }
            let changed = await FocusWalletAvatarCache.seedPreviewEntries(payloads: payloads)
            guard !Task.isCancelled else { return }
            if changed { advanceRevision() }
            decodeTasks[taskKey] = nil
        }
    }

    func cachedImage(for id: UUID, signature: String) -> UIImage? {
        FocusWalletAvatarCache.cachedEntry(for: id, signature: signature)?.image
    }

    func cachedEntry(for id: UUID, signature: String) -> FocusWalletAvatarCache.Entry? {
        FocusWalletAvatarCache.cachedEntry(for: id, signature: signature)
    }

    func preload(
        payloads: [FocusWalletAvatarCache.Payload],
        popoutPayloads: [FocusWalletAvatarCache.Payload] = [],
        key: String,
        delayMilliseconds: UInt64 = 72
    ) {
        decodeTasks[key]?.cancel()
        decodeTasks[key] = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            let avatarChanged = await FocusWalletAvatarCache.preload(payloads: payloads)
            guard !Task.isCancelled else { return }
            let popoutChanged = await FocusPopoutImageCache.preload(payloads: popoutPayloads)
            guard !Task.isCancelled else { return }
            if avatarChanged || popoutChanged { advanceRevision() }
            AppPerformanceMonitor.shared.record(
                "avatar_pipeline_decode",
                startedAt: startedAt,
                note: "\(payloads.count) avatars, \(popoutPayloads.count) popouts"
            )
            decodeTasks[key] = nil
        }
    }

    func cancel(key: String) {
        decodeTasks[key]?.cancel()
        decodeTasks[key] = nil
        let taskKey = previewTaskKey(for: key)
        decodeTasks[taskKey]?.cancel()
        decodeTasks[taskKey] = nil
    }

    private func advanceRevision() {
        revision &+= 1
    }

    private func previewTaskKey(for key: String) -> String {
        "preview:\(key)"
    }
}

@MainActor
enum AvatarPipelineRegistry {
    private static var currentPipeline = AvatarPipeline()

    static var current: AvatarPipeline {
        get { currentPipeline }
        set { currentPipeline = newValue }
    }
}
