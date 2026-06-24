//
//  FocusHomeCardDataSource.swift
//  Ohana
//
//  Lightweight card snapshot and avatar data helpers for the GO Focus home.
//

import Foundation

nonisolated enum FocusHomeCardDataSource {
    nonisolated static let maxCardsPerPage = 6

    static func buildSnapshot(
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool
    ) -> [FocusCard] {
        let real = (
            pets
                .filter { !$0.hasPassedAway && HomeCardVisibility.isPetVisible($0, raw: hiddenPetIDsRaw) }
                .map { FocusCard.from($0, includeAvatarData: false, includeWalkDistance: false) }
                + humans
                .filter { $0.shouldShowOnHome && !$0.hasPassedAway }
                .map { FocusCard.from($0, includeAvatarData: false) }
                + electronicPets
                .filter { !$0.isArchived && $0.lifeState != .dead && $0.isFeaturedOnOasis }
                .map { FocusCard.from($0) }
        )
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
        let targetIds = Array(source.prefix(maxCardsPerPage)).map(\.id)
        let targetIdSet = Set(targetIds)
        var avatarData = currentAvatarData
        var popoutData = currentPopoutData

        if !targetIdSet.isEmpty {
            avatarData = avatarData.filter { targetIdSet.contains($0.key) }
            popoutData = popoutData.filter { targetIdSet.contains($0.key) }
        }

        for id in targetIds {
            if let data = avatarDataForHomeCard(id: id, pets: pets, humans: humans), !data.isEmpty {
                avatarData[id] = data
            } else {
                avatarData.removeValue(forKey: id)
            }
            if let popout = popoutDataForHomeCard(id: id, pets: pets, equipFxPopoutCard: equipFxPopoutCard), !popout.isEmpty {
                popoutData[id] = popout
            } else {
                popoutData.removeValue(forKey: id)
            }
        }

        return (avatarData, popoutData)
    }

    static func avatarDataForHomeCard(id: UUID, pets: [Pet], humans: [Human]) -> Data? {
        if let pet = pets.first(where: { $0.id == id }) {
            return pet.avatarImageData
        }
        if let human = humans.first(where: { $0.id == id }) {
            return human.avatarImageData
        }
        return nil
    }

    static func popoutDataForHomeCard(id: UUID, pets: [Pet], equipFxPopoutCard: Bool) -> Data? {
        guard equipFxPopoutCard,
              let pet = pets.first(where: { $0.id == id }),
              pet.cardStyleRaw == "popout" else { return nil }
        return pet.cardPopoutImageData ?? pet.avatarImageData
    }

    static func visibleCards(
        from cards: [FocusCard],
        rosterPreviewCard: FocusCard?,
        isExpanded: Bool,
        activeCardId: UUID?,
        avatarData: [UUID: Data],
        popoutData: [UUID: Data]
    ) -> [FocusCard] {
        var visible = Array(cards.prefix(maxCardsPerPage))
        if let rosterPreviewCard,
           isExpanded || activeCardId == rosterPreviewCard.id,
           !visible.contains(where: { $0.id == rosterPreviewCard.id }) {
            visible.append(rosterPreviewCard)
        }
        return withLoadedAvatarData(visible, avatarData: avatarData, popoutData: popoutData)
    }

    static func visibleIdsSignature(cards: [FocusCard], rosterPreviewCard: FocusCard?) -> String {
        var ids = Array(cards.prefix(maxCardsPerPage)).map(\.id)
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
            copy.avatarImageSignature = copy.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
            copy.cardPopoutImageData = popoutData[card.id] ?? copy.cardPopoutImageData
            copy.cardPopoutImageSignature = copy.cardPopoutImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
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
