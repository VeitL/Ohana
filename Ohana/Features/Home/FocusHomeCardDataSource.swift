//
//  FocusHomeCardDataSource.swift
//  Ohana
//
//  Lightweight card snapshot and avatar data helpers for the GO Focus home.
//

import Foundation

nonisolated enum FocusHomeCardDataSource {
    /// Bounds eager media work for the cards initially visible above the fold.
    /// This is a performance budget, not a member-card capacity limit.
    nonisolated static let firstScreenMediaBudget = 6

    static func buildSnapshot(
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        l: L10n = .current
    ) -> [FocusCard] {
        // Keep consuming the legacy hidden-pet payload for backup compatibility,
        // but the scrollable Home member deck no longer treats it as a visibility rule.
        _ = hiddenPetIDsRaw
        let real = (
            pets
                .filter { !$0.hasPassedAway }
                .map { FocusCard.from($0, includeAvatarData: false, l: l) }
                + humans
                .filter { !$0.hasPassedAway }
                .map { FocusCard.from($0, includeAvatarData: false) }
                + electronicPets
                .filter {
                    !$0.isArchived &&
                        $0.lifeState != .dead &&
                        $0.lifeState != .critical &&
                        $0.lifeState != .sleeping &&
                        $0.isFeaturedOnOasis
                }
                .map { FocusCard.from($0) }
        )
        .map { card in
            var card = card
            card.isShownOnHome = true
            return card
        }
        .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.name < rhs.name
        }

        if !real.isEmpty {
            return orderedByPreference(real, homeCardOrderRaw: homeCardOrderRaw)
        }

        guard showDummyCards else { return [] }
        let usedNames = Set(real.map(\.name))
        let extras = FocusCard.dummies.filter { !usedNames.contains($0.name) }
        return orderedByPreference(real + extras, homeCardOrderRaw: homeCardOrderRaw)
    }

    static func orderedByPreference(_ base: [FocusCard], homeCardOrderRaw: String) -> [FocusCard] {
        let preferredIds = homeCardOrderRaw
            .split(separator: ",")
            .map(String.init)
        guard !preferredIds.isEmpty else { return base }

        var preferredRank: [String: Int] = [:]
        for (index, id) in preferredIds.enumerated() where preferredRank[id] == nil {
            preferredRank[id] = index
        }

        return base.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = preferredRank[lhs.element.id.uuidString] ?? Int.max
                let rhsRank = preferredRank[rhs.element.id.uuidString] ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    static func encodedOrder(for cards: [FocusCard]) -> String {
        cards.map(\.id.uuidString).joined(separator: ",")
    }

    static func promotedOrderRaw(id: UUID, currentRaw: String) -> String {
        var ids = currentRaw
            .split(separator: ",")
            .map(String.init)
        let idString = id.uuidString
        ids.removeAll { $0 == idString }
        ids.insert(idString, at: 0)
        return ids.joined(separator: ",")
    }

    static func selectionReconciliation(
        cards: [FocusCard],
        selectedCardId: UUID?,
        headerContextCardId: UUID?
    ) -> FocusHomeCardSelectionReconciliation {
        let cardIds = Set(cards.map(\.id))
        return FocusHomeCardSelectionReconciliation(
            clearsSelectedCard: selectedCardId.map { !cardIds.contains($0) } ?? false,
            clearsHeaderContext: headerContextCardId.map { !cardIds.contains($0) } ?? false
        )
    }

    static func seedAvatarData(
        from source: [FocusCard],
        pets: [Pet],
        humans: [Human],
        equipFxPopoutCard: Bool,
        currentAvatarData: [UUID: Data],
        currentPopoutData: [UUID: Data]
    ) -> (avatarData: [UUID: Data], popoutData: [UUID: Data]) {
        _ = pets
        _ = humans
        _ = equipFxPopoutCard
        let targetCards = Array(source.prefix(firstScreenMediaBudget))
        let targetIds = targetCards.map(\.id)
        let targetIdSet = Set(targetIds)
        var avatarData = currentAvatarData
        var popoutData = currentPopoutData

        if !targetIdSet.isEmpty {
            avatarData = avatarData.filter { targetIdSet.contains($0.key) }
            popoutData = popoutData.filter { targetIdSet.contains($0.key) }
        }

        for card in targetCards {
            if let data = card.avatarImageData, !data.isEmpty {
                avatarData[card.id] = data
            }
            if let popout = card.cardPopoutImageData, !popout.isEmpty {
                popoutData[card.id] = popout
            }
        }

        return (avatarData, popoutData)
    }

    static func visibleCards(
        from cards: [FocusCard],
        rosterPreviewCard: FocusCard?,
        isExpanded: Bool,
        activeCardId: UUID?,
        avatarData: [UUID: Data],
        popoutData: [UUID: Data]
    ) -> [FocusCard] {
        var visible = cards
        if let rosterPreviewCard,
           isExpanded || activeCardId == rosterPreviewCard.id,
           !visible.contains(where: { $0.id == rosterPreviewCard.id }) {
            visible.append(rosterPreviewCard)
        }
        return withLoadedAvatarData(visible, avatarData: avatarData, popoutData: popoutData)
    }

    static func visibleIdsSignature(cards: [FocusCard], rosterPreviewCard: FocusCard?) -> String {
        var ids = cards.map(\.id)
        if let rosterPreviewCard {
            ids.append(rosterPreviewCard.id)
        }
        return ids.map(\.uuidString).joined(separator: "|")
    }

    static func withLoadedAvatarData(
        _ cards: [FocusCard],
        avatarData: [UUID: Data],
        popoutData: [UUID: Data]
    ) -> [FocusCard] {
        cards.map { card in
            var copy = card
            copy.avatarImageData = avatarData[card.id] ?? card.avatarImageData
            if let avatarData = copy.avatarImageData {
                copy.avatarImageSignature = FocusWalletAvatarCache.signature(for: avatarData)
            }
            copy.cardPopoutImageData = popoutData[card.id] ?? copy.cardPopoutImageData
            if let popoutData = copy.cardPopoutImageData {
                copy.cardPopoutImageSignature = FocusWalletAvatarCache.signature(for: popoutData)
            }
            return copy
        }
    }

    static func displayCards(
        from source: [FocusCard],
        reorderingCards: [FocusCard]?
    ) -> [FocusCard] {
        guard let reorderingCards else { return source }
        let sourceById = Dictionary(uniqueKeysWithValues: source.map { ($0.id, $0) })
        let ordered = reorderingCards.compactMap { sourceById[$0.id] }
        let orderedIds = Set(ordered.map(\.id))
        let remaining = source.filter { !orderedIds.contains($0.id) }
        return ordered + remaining
    }
}

nonisolated struct FocusHomeCardSelectionReconciliation: Equatable {
    let clearsSelectedCard: Bool
    let clearsHeaderContext: Bool
}
