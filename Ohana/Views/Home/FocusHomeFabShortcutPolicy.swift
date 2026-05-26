//
//  FocusHomeFabShortcutPolicy.swift
//  Ohana
//
//  Pure shortcut lists for the expanded-card FAB.
//

import Foundation

enum FocusHomeFabShortcutPolicy {
    static func humanShortcuts(
        for human: Human,
        displayedItems: [QuickActionItem],
        localization l: L10n
    ) -> [ExpandedCardFabShortcut] {
        let displayedActionTypes = Set(
            displayedItems
                .prefix(QuickActionLimit.maxItemsPerEntity)
                .map(\.actionType)
        )
        let hiddenQuickItems = ExpandedQuickActionDefaults
            .humanItems(for: human, localization: l)
            .filter { !displayedActionTypes.contains($0.actionType) }
            .map(humanShortcut(from:))

        return hiddenQuickItems + [
            allHumanFeaturesShortcut(localization: l),
        ]
    }

    static func humanShortcuts(localization l: L10n) -> [ExpandedCardFabShortcut] {
        [
            ExpandedCardFabShortcut(label: l.homeQAWeight, icon: "scalemass.fill", action: .humanQuick("humanWeight")),
            ExpandedCardFabShortcut(label: l.expense, icon: "creditcard.fill", action: .humanQuick("humanExpense")),
            ExpandedCardFabShortcut(label: l.homeQAMeds, icon: "pill.fill", action: .humanQuick("humanMedication")),
            ExpandedCardFabShortcut(label: l.homeQASport, icon: "figure.run", action: .humanQuick("humanWorkout")),
            ExpandedCardFabShortcut(label: l.homeQANote, icon: "note.text", action: .humanQuick("humanNote")),
            allHumanFeaturesShortcut(localization: l),
        ]
    }

    static func humanShortcut(from item: QuickActionItem) -> ExpandedCardFabShortcut {
        ExpandedCardFabShortcut(label: item.label, icon: item.icon, action: .humanQuick(item.actionType))
    }

    static func petShortcut(from option: QuickActionPickerCatalog.Option) -> ExpandedCardFabShortcut {
        switch option.id {
        case "health":
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .detail(.health))
        case "expense":
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .detail(.expense))
        case "weight":
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .detail(.weight))
        default:
            return ExpandedCardFabShortcut(label: option.label, icon: option.icon, action: .quick(option.id))
        }
    }

    static func petShortcuts(
        for pet: Pet,
        displayedItems: [QuickActionItem],
        localization l: L10n
    ) -> [ExpandedCardFabShortcut] {
        let displayedActionTypes = Set(
            displayedItems
                .prefix(QuickActionLimit.maxItemsPerEntity)
                .map(\.actionType)
        )
        let hiddenQuickItems = QuickActionPickerCatalog
            .available(for: pet, existingActionTypes: displayedActionTypes)
            .map { petShortcut(from: $0) }

        return hiddenQuickItems + [
            ExpandedCardFabShortcut(
                label: l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen"),
                icon: "ellipsis.circle.fill",
                action: .allFeatures
            ),
        ]
    }

    private static func allHumanFeaturesShortcut(localization l: L10n) -> ExpandedCardFabShortcut {
        ExpandedCardFabShortcut(
            label: l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen"),
            icon: "ellipsis.circle.fill",
            action: .humanAllFeatures
        )
    }
}
