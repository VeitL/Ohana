//
//  FocusHomeSnapshotController.swift
//  Ohana
//
//  Keeps home card snapshots and first-screen avatar loading out of the main home view.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class FocusHomeSnapshotController: ObservableObject {
    @Published private(set) var snapshot: [FocusCard] = []
    @Published private(set) var snapshotInitialized = false
    @Published private(set) var avatarDataById: [UUID: Data] = [:]
    @Published private(set) var popoutDataById: [UUID: Data] = [:]
    @Published private(set) var avatarCacheRevision = 0

    private var avatarLoadTask: Task<Void, Never>?

    deinit {
        avatarLoadTask?.cancel()
    }

    func cards(fallback: @autoclosure () -> [FocusCard]) -> [FocusCard] {
        snapshotInitialized ? snapshot : fallback()
    }

    func refresh(
        snapshot newSnapshot: [FocusCard],
        pets: [Pet],
        humans: [Human],
        equipFxPopoutCard: Bool,
        isExpanded: Bool,
        walletTransitionCardId: UUID?
    ) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            snapshot = newSnapshot
            snapshotInitialized = true
            seedVisibleAvatarData(
                from: newSnapshot,
                pets: pets,
                humans: humans,
                equipFxPopoutCard: equipFxPopoutCard
            )
        }
        AppPerformanceMonitor.shared.record("home.firstSnapshotReady", valueMS: 0)
        scheduleVisibleAvatarDataLoad(
            from: newSnapshot,
            pets: pets,
            humans: humans,
            equipFxPopoutCard: equipFxPopoutCard,
            isExpanded: isExpanded,
            walletTransitionCardId: walletTransitionCardId
        )
    }

    func cancelAvatarLoad() {
        avatarLoadTask?.cancel()
        avatarLoadTask = nil
    }

    func scheduleVisibleAvatarDataLoad(
        from source: [FocusCard]? = nil,
        pets: [Pet],
        humans: [Human],
        equipFxPopoutCard: Bool,
        isExpanded: Bool,
        walletTransitionCardId: UUID?
    ) {
        cancelAvatarLoad()
        guard !isExpanded, walletTransitionCardId == nil else { return }

        let sourceCards = source ?? cards(fallback: [])
        let targetCards = Array(sourceCards.prefix(FocusHomeCardDataSource.maxCardsPerPage))
        let targetIds = targetCards.map(\.id)
        let targetIdSet = Set(targetIds)
        if !targetIdSet.isEmpty {
            avatarDataById = avatarDataById.filter { targetIdSet.contains($0.key) }
            popoutDataById = popoutDataById.filter { targetIdSet.contains($0.key) }
        }

        avatarLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }

            var payloads: [FocusWalletAvatarCache.Payload] = []
            var popoutPayloads: [FocusWalletAvatarCache.Payload] = []
            for card in targetCards {
                guard !Task.isCancelled else { return }
                if let data = card.avatarImageData, !data.isEmpty {
                    if avatarDataById[card.id] != data {
                        avatarDataById[card.id] = data
                    }
                    payloads.append(FocusWalletAvatarCache.Payload(id: card.id, data: data))
                }

                if equipFxPopoutCard,
                   let popout = card.cardPopoutImageData,
                   !popout.isEmpty {
                    popoutDataById[card.id] = popout
                    popoutPayloads.append(FocusWalletAvatarCache.Payload(id: card.id, data: popout))
                }
                await Task.yield()
            }
            guard !payloads.isEmpty || !popoutPayloads.isEmpty else { return }

            let avatarDidRefresh = await FocusWalletAvatarCache.preload(payloads: payloads)
            guard !Task.isCancelled else { return }
            let popoutDidRefresh = await FocusPopoutImageCache.preload(payloads: popoutPayloads)
            guard !Task.isCancelled else { return }
            if avatarDidRefresh || popoutDidRefresh {
                avatarCacheRevision &+= 1
                AppPerformanceMonitor.shared.record(
                    "home.avatarFinalReady",
                    valueMS: 0,
                    note: "\(payloads.count) avatars, \(popoutPayloads.count) popouts"
                )
            }
        }
    }

    func visibleCards(
        from cards: [FocusCard],
        rosterPreviewCard: FocusCard?,
        isExpanded: Bool,
        activeCardId: UUID?
    ) -> [FocusCard] {
        FocusHomeCardDataSource.visibleCards(
            from: cards,
            rosterPreviewCard: rosterPreviewCard,
            isExpanded: isExpanded,
            activeCardId: activeCardId,
            avatarData: avatarDataById,
            popoutData: popoutDataById
        )
    }

    func visibleIdsSignature(cards: [FocusCard], rosterPreviewCard: FocusCard?) -> String {
        FocusHomeCardDataSource.visibleIdsSignature(cards: cards, rosterPreviewCard: rosterPreviewCard)
    }

    func withLoadedAvatarData(_ cards: [FocusCard]) -> [FocusCard] {
        FocusHomeCardDataSource.withLoadedAvatarData(
            cards,
            avatarData: avatarDataById,
            popoutData: popoutDataById
        )
    }

    func avatarData(for id: UUID) -> Data? {
        avatarDataById[id]
    }

    func seedAvatarData(cardId: UUID, data: Data?) {
        guard let data, !data.isEmpty else {
            avatarDataById.removeValue(forKey: cardId)
            Task { @MainActor in
                let didRefresh = await FocusWalletAvatarCache.preload(payloads: [
                    FocusWalletAvatarCache.Payload(id: cardId, data: nil)
                ])
                if didRefresh {
                    avatarCacheRevision &+= 1
                }
            }
            return
        }
        avatarDataById[cardId] = data
        Task { @MainActor in
            let didRefresh = await FocusWalletAvatarCache.preload(payloads: [
                FocusWalletAvatarCache.Payload(id: cardId, data: data)
            ])
            if didRefresh {
                avatarCacheRevision &+= 1
            }
        }
    }

    func seedPopoutData(cardId: UUID, data: Data?) {
        if let data, !data.isEmpty {
            popoutDataById[cardId] = data
        } else {
            popoutDataById.removeValue(forKey: cardId)
        }
        Task { @MainActor in
            let didRefresh = await FocusPopoutImageCache.preload(payloads: [
                FocusWalletAvatarCache.Payload(id: cardId, data: data)
            ])
            if didRefresh {
                avatarCacheRevision &+= 1
            }
        }
    }

    func invalidateMemberAppearance(cardId: UUID?) {
        cancelAvatarLoad()
        if let cardId {
            avatarDataById.removeValue(forKey: cardId)
            popoutDataById.removeValue(forKey: cardId)
            avatarCacheRevision &+= 1
        } else {
            avatarDataById.removeAll()
            popoutDataById.removeAll()
            avatarCacheRevision &+= 1
        }
    }

    private func seedVisibleAvatarData(
        from source: [FocusCard],
        pets: [Pet],
        humans: [Human],
        equipFxPopoutCard: Bool
    ) {
        let seeded = FocusHomeCardDataSource.seedAvatarData(
            from: source,
            pets: pets,
            humans: humans,
            equipFxPopoutCard: equipFxPopoutCard,
            currentAvatarData: avatarDataById,
            currentPopoutData: popoutDataById
        )
        avatarDataById = seeded.avatarData
        popoutDataById = seeded.popoutData
        let visibleCount = min(source.count, FocusHomeCardDataSource.maxCardsPerPage)
        AppPerformanceMonitor.shared.record("home.avatarPreviewReady", valueMS: 0, note: "\(visibleCount) visible")
    }
}
