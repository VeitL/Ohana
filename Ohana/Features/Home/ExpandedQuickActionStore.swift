//
//  ExpandedQuickActionStore.swift
//  Ohana
//
//  Persistence helpers for expanded-card quick action ordering.
//

import Foundation

nonisolated enum ExpandedQuickActionStore {
    static func petItems(
        raw: String,
        pet: Pet,
        localization l: L10n,
        waterLabel: String,
        managementLabel: String
    ) -> [QuickActionItem] {
        petItems(
            raw: raw,
            pet: pet,
            defaultItems: ExpandedQuickActionDefaults.items(
                for: pet,
                localization: l,
                waterManagementLabel: managementLabel
            ),
            waterLabel: waterLabel,
            managementLabel: managementLabel
        )
    }

    static func petItems(
        raw: String,
        pet: Pet,
        defaultItems: [QuickActionItem],
        waterLabel: String,
        managementLabel: String
    ) -> [QuickActionItem] {
        let stored = decode(raw).filter { $0.petId == pet.id && $0.entityKind != .human }
        let items = (stored.isEmpty ? defaultItems : stored)
            .filter { $0.actionType != "litterChange" }
        return WaterQuickActionPolicy.normalizedItems(
            items,
            for: pet,
            waterLabel: waterLabel,
            managementLabel: managementLabel
        )
    }

    static func humanItems(raw: String, human: Human, localization l: L10n) -> [QuickActionItem] {
        humanItems(
            raw: raw,
            human: human,
            defaultItems: ExpandedQuickActionDefaults.humanItems(for: human, localization: l)
        )
    }

    static func humanItems(raw: String, human: Human, defaultItems: [QuickActionItem]) -> [QuickActionItem] {
        let stored = decode(raw).filter {
            $0.entityId == human.id &&
                $0.entityKind == .human &&
                $0.actionType != "humanAllFeatures"
        }
        return stored.isEmpty ? defaultItems : stored
    }

    static func plantItems(raw: String, plantID: UUID, localization l: L10n) -> [QuickActionItem] {
        let stored = decode(raw).filter {
            $0.entityId == plantID &&
                $0.entityKind == .plant &&
                PlantDockQuickAction(actionType: $0.actionType) != nil
        }
        let defaults = PlantDockQuickAction.quickActionItems(
            for: plantID,
            localization: l,
            actions: PlantDockQuickAction.defaultItems
        )
        return Array((stored.isEmpty ? defaults : stored).prefix(PlantDockQuickAction.maxVisibleItems))
    }

    static func plantCandidateItems(plantID: UUID, localization l: L10n) -> [QuickActionItem] {
        PlantDockQuickAction.quickActionItems(
            for: plantID,
            localization: l,
            actions: PlantDockQuickAction.editableItems
        )
    }

    static func savingPetItems(
        _ edited: [QuickActionItem],
        pet: Pet,
        raw: String,
        localization l: L10n,
        waterLabel: String,
        managementLabel: String
    ) -> String {
        savingPetItems(
            edited,
            pet: pet,
            currentItems: petItems(
                raw: raw,
                pet: pet,
                localization: l,
                waterLabel: waterLabel,
                managementLabel: managementLabel
            ),
            raw: raw
        )
    }

    static func savingPetItems(
        _ edited: [QuickActionItem],
        pet: Pet,
        currentItems: [QuickActionItem],
        raw: String
    ) -> String {
        savingPetItems(
            edited,
            petID: pet.id,
            currentItems: currentItems,
            raw: raw
        )
    }

    static func savingPetItems(
        _ edited: [QuickActionItem],
        petID: UUID,
        currentItems: [QuickActionItem],
        raw: String
    ) -> String {
        var saved = decode(raw)
        let currentPetItemIds = Set(currentItems.map(\.id))
        let insertionIdx = saved.firstIndex(where: { currentPetItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { ($0.petId == petID || $0.entityId == petID) && $0.entityKind != .human }
        let cleaned = edited.filter { $0.actionType != "litterChange" }
        saved.insert(contentsOf: Array(cleaned.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        return encode(saved) ?? raw
    }

    static func savingHumanItems(
        _ edited: [QuickActionItem],
        human: Human,
        raw: String,
        localization l: L10n
    ) -> String {
        savingHumanItems(
            edited,
            human: human,
            currentItems: humanItems(raw: raw, human: human, localization: l),
            raw: raw
        )
    }

    static func savingHumanItems(
        _ edited: [QuickActionItem],
        human: Human,
        currentItems: [QuickActionItem],
        raw: String
    ) -> String {
        savingHumanItems(
            edited,
            humanID: human.id,
            currentItems: currentItems,
            raw: raw
        )
    }

    static func savingHumanItems(
        _ edited: [QuickActionItem],
        humanID: UUID,
        currentItems: [QuickActionItem],
        raw: String
    ) -> String {
        var saved = decode(raw)
        let currentItemIds = Set(currentItems.map(\.id))
        let insertionIdx = saved.firstIndex(where: { currentItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { $0.entityId == humanID && $0.entityKind == .human }
        let cleaned = edited.filter { $0.actionType != "humanAllFeatures" }
        saved.insert(contentsOf: Array(cleaned.prefix(QuickActionLimit.maxItemsPerEntity)), at: min(insertionIdx, saved.count))
        return encode(saved) ?? raw
    }

    static func savingPlantItems(
        _ edited: [QuickActionItem],
        plantID: UUID,
        currentItems: [QuickActionItem],
        raw: String
    ) -> String {
        var saved = decode(raw)
        let currentItemIds = Set(currentItems.map(\.id))
        let insertionIdx = saved.firstIndex(where: { currentItemIds.contains($0.id) }) ?? saved.count
        saved.removeAll { $0.entityId == plantID && $0.entityKind == .plant }
        let cleaned = edited
            .filter { item in
                item.entityId == plantID &&
                    item.entityKind == .plant &&
                    PlantDockQuickAction(actionType: item.actionType) != nil
            }
        saved.insert(contentsOf: Array(cleaned.prefix(PlantDockQuickAction.maxVisibleItems)), at: min(insertionIdx, saved.count))
        return encode(saved) ?? raw
    }

    private static func decode(_ raw: String) -> [QuickActionItem] {
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let items = try? JSONDecoder().decode([QuickActionItem].self, from: data)
        else { return [] }
        return items
    }

    private static func encode(_ items: [QuickActionItem]) -> String? {
        guard let data = try? JSONEncoder().encode(items) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
