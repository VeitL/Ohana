//
//  HomeToolbarQuickRecordPolicy.swift
//  Ohana
//
//  Lightweight targets and record categories for the standard-mode toolbar quick log.
//

import Foundation

struct HomeToolbarQuickRecordTarget: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case human
        case pet
        case plant

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .human: "person.fill"
            case .pet: "pawprint.fill"
            case .plant: "leaf.fill"
            }
        }
    }

    let entityID: UUID
    let name: String
    let kind: Kind
    let quickActions: [QuickActionItem]

    var id: String {
        "\(kind.rawValue)-\(entityID.uuidString)"
    }

    var accessibilityIdentifier: String {
        "home-quick-record-\(kind.rawValue)-\(entityID.uuidString)"
    }
}

enum HomeToolbarQuickRecordPolicy {
    private static let humanRecordActionTypes: Set<String> = [
        "humanWeight",
        "humanWorkout",
        "humanMedication",
        "humanNote"
    ]
    private static let petRecordActionTypes: Set<String> = [
        "walk",
        "feed",
        "water",
        "potty",
        "litter",
        "waterChange",
        "filterClean",
        "groom",
        "health",
        "medication",
        "expense",
        "weight",
        "play",
        "moment",
        "cageCleaning",
        "freeFlight",
        "misting",
        "substrateChange"
    ]

    static func isVisible(for tab: VerticalSolidHomeTab) -> Bool {
        tab == .home || tab == .plants
    }

    static func usesPetPrimaryAction(
        for action: QuickActionItem,
        state: HomeQuickActionRenderSnapshot
    ) -> Bool {
        guard state.menuPolicy.showsQuickButton else { return false }
        let isCompletedSingleUseAction = ExpandedQuickActionLogic.singleUseLabel(
            for: action.actionType
        ) != nil && state.isCompleted
        return !isCompletedSingleUseAction
    }

    static func targets(
        for tab: VerticalSolidHomeTab,
        cards: [FocusCard],
        plants: [VerticalSolidHomePlantSnapshot],
        quickActionsByCardID: [UUID: [QuickActionItem]] = [:],
        localization l: L10n = .current
    ) -> [HomeToolbarQuickRecordTarget] {
        switch tab {
        case .home:
            cards.compactMap { card in
                guard card.isReal,
                      !card.isDummy,
                      !card.isElectronicPet,
                      !card.isPlant,
                      !card.hasPassedAway else {
                    return nil
                }
                return HomeToolbarQuickRecordTarget(
                    entityID: card.id,
                    name: card.name,
                    kind: card.isHuman ? .human : .pet,
                    quickActions: memberQuickActions(
                        for: card,
                        configured: quickActionsByCardID[card.id] ?? [],
                        localization: l
                    )
                )
            }
        case .plants:
            plants.compactMap { plant in
                guard !plant.isArchived else { return nil }
                return HomeToolbarQuickRecordTarget(
                    entityID: plant.id,
                    name: plant.name,
                    kind: .plant,
                    quickActions: []
                )
            }
        case .calendar, .oasis:
            []
        }
    }

    private static func memberQuickActions(
        for card: FocusCard,
        configured: [QuickActionItem],
        localization l: L10n
    ) -> [QuickActionItem] {
        let allowedActionTypes = card.isHuman ? humanRecordActionTypes : petRecordActionTypes
        var actions = configured.reduce(into: [QuickActionItem]()) { result, action in
            guard allowedActionTypes.contains(action.actionType),
                  !result.contains(where: { $0.actionType == action.actionType }) else { return }
            result.append(action)
        }

        if card.isHuman,
           !actions.contains(where: { $0.actionType == "humanMetrics" }) {
            let metrics = QuickActionItem(
                id: "human-\(card.id.uuidString)-humanMetrics",
                label: l.tr(
                    zh: "健康数据",
                    en: "Health data",
                    de: "Gesundheitsdaten",
                    es: "Datos de salud",
                    pt: "Dados de saúde",
                    fr: "Données de santé",
                    ja: "健康データ",
                    ko: "건강 데이터",
                    it: "Dati sanitari"
                ),
                icon: "waveform.path.ecg.rectangle.fill",
                colorHex: "14B8A6",
                actionType: "humanMetrics",
                entityId: card.id,
                entityKind: .human
            )
            let insertionIndex = actions.firstIndex { $0.actionType == "humanWeight" }
                .map { actions.index(after: $0) } ?? actions.startIndex
            actions.insert(metrics, at: insertionIndex)
        }
        return actions
    }
}
