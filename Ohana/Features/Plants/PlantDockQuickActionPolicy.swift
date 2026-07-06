//
//  PlantDockQuickActionPolicy.swift
//  Ohana
//
//  Shared default action grammar for plant wallet-card docks.
//

import SwiftUI

nonisolated enum PlantQuickCareFeedbackKey {
    static func key(plantID: UUID, careType: PlantCareType) -> String {
        "\(plantID.uuidString)|\(careType.rawValue)"
    }
}

extension PlantCareCategory {
    @MainActor var tint: Color {
        switch self {
        case .hydration:
            Color.goTeal
        case .nutrition:
            Color.goPrimary
        case .maintenance:
            Color.goYellow
        case .health:
            Color.goOrange
        case .growth:
            Color.goPurple
        }
    }
}

struct PlantDockQuickActionCategorySection: Identifiable, Sendable {
    let category: PlantCareCategory
    let actions: [PlantDockQuickAction]

    var id: String { category.rawValue }
}

nonisolated enum PlantDockQuickAction: String, CaseIterable, Identifiable, Sendable {
    case water
    case fertilize
    case photo
    case mist
    case prune
    case cleanLeaves
    case pestCheck
    case rotate
    case repot
    case newLeaf
    case yellowLeaf
    case pestFound
    case note
    case detail

    static let maxVisibleItems = 8

    static var defaultItems: [PlantDockQuickAction] {
        [.water, .fertilize, .photo, .detail]
    }

    static var editableItems: [PlantDockQuickAction] {
        editableSections.flatMap(\.actions) + [.detail]
    }

    static var editableSections: [PlantDockQuickActionCategorySection] {
        [
            PlantDockQuickActionCategorySection(category: .hydration, actions: [.water, .mist]),
            PlantDockQuickActionCategorySection(category: .nutrition, actions: [.fertilize, .repot]),
            PlantDockQuickActionCategorySection(category: .maintenance, actions: [.prune, .cleanLeaves, .rotate]),
            PlantDockQuickActionCategorySection(category: .health, actions: [.pestCheck, .yellowLeaf, .pestFound]),
            PlantDockQuickActionCategorySection(category: .growth, actions: [.photo, .newLeaf, .note])
        ]
    }

    var id: String { rawValue }

    init?(actionType: String) {
        if let action = Self.allCases.first(where: { $0.actionType == actionType }) {
            self = action
            return
        }
        self.init(rawValue: actionType)
    }

    func title(l: L10n) -> String {
        switch self {
        case .water:
            l.tr(zh: "浇水", en: "Water", de: "Gießen")
        case .fertilize:
            l.tr(zh: "施肥", en: "Fertilize", de: "Düngen")
        case .photo:
            l.tr(zh: "拍照", en: "Photo", de: "Foto")
        case .mist:
            l.tr(zh: "喷雾", en: "Mist", de: "Besprühen")
        case .prune:
            l.tr(zh: "修剪", en: "Prune", de: "Schneiden")
        case .cleanLeaves:
            l.tr(zh: "擦叶", en: "Clean", de: "Reinigen")
        case .pestCheck:
            l.tr(zh: "查虫", en: "Pests", de: "Schädlinge")
        case .rotate:
            l.tr(zh: "转盆", en: "Rotate", de: "Drehen")
        case .repot:
            l.tr(zh: "换盆", en: "Repot", de: "Umtopfen")
        case .newLeaf:
            l.tr(zh: "新叶", en: "New leaf", de: "Neues Blatt")
        case .yellowLeaf:
            l.tr(zh: "黄叶", en: "Yellow leaf", de: "Gelbes Blatt")
        case .pestFound:
            l.tr(zh: "虫害", en: "Pest found", de: "Befall")
        case .note:
            l.tr(zh: "备注", en: "Note", de: "Notiz")
        case .detail:
            l.tr(zh: "详情", en: "Detail", de: "Detail")
        }
    }

    var icon: String {
        switch self {
        case .water:
            "drop.fill"
        case .fertilize:
            "leaf.fill"
        case .photo:
            "camera.fill"
        case .mist:
            "cloud.drizzle.fill"
        case .prune:
            "scissors"
        case .cleanLeaves:
            "sparkle.magnifyingglass"
        case .pestCheck:
            "ladybug.fill"
        case .rotate:
            "arrow.triangle.2.circlepath"
        case .repot:
            "shippingbox.fill"
        case .newLeaf:
            "leaf.arrow.triangle.circlepath"
        case .yellowLeaf:
            "leaf.fill"
        case .pestFound:
            "exclamationmark.triangle.fill"
        case .note:
            "note.text"
        case .detail:
            "info.circle.fill"
        }
    }

    var actionType: String {
        switch self {
        case .water:
            "plantWater"
        case .fertilize:
            "fertilizePlant"
        case .photo:
            "moment"
        case .mist:
            "plantMisting"
        case .prune:
            "plantPruning"
        case .cleanLeaves:
            "plantLeafCleaning"
        case .pestCheck:
            "plantPestCheck"
        case .rotate:
            "plantRotating"
        case .repot:
            "plantRepotting"
        case .newLeaf:
            "plantNewLeaf"
        case .yellowLeaf:
            "plantYellowLeaf"
        case .pestFound:
            "plantPestFound"
        case .note:
            "plantNote"
        case .detail:
            "plantDetail"
        }
    }

    var careType: PlantCareType? {
        switch self {
        case .water:
            .watering
        case .fertilize:
            .fertilizing
        case .photo:
            .photo
        case .mist:
            .misting
        case .prune:
            .pruning
        case .cleanLeaves:
            .leafCleaning
        case .pestCheck:
            .pestCheck
        case .rotate:
            .rotating
        case .repot:
            .repotting
        case .newLeaf:
            .newLeaf
        case .yellowLeaf:
            .yellowLeaf
        case .pestFound:
            .pestFound
        case .note:
            .customNote
        case .detail:
            nil
        }
    }

    var careCategory: PlantCareCategory? {
        careType?.careCategory
    }

    var detailFeatureDestination: PlantCareFeatureDestination? {
        guard let careType else { return nil }
        return PlantCareFeatureDestination.categoryDestination(for: careType)
    }

    @MainActor var tint: Color {
        careCategory?.tint ?? Color.goTeal
    }

    var primaryIcon: String {
        switch self {
        case .water, .fertilize, .mist, .prune, .cleanLeaves, .pestCheck, .rotate, .repot, .newLeaf, .yellowLeaf, .pestFound, .note:
            "checkmark"
        case .photo:
            "camera.fill"
        case .detail:
            "arrow.right"
        }
    }

    var detailIcon: String {
        switch self {
        case .water, .fertilize, .mist, .prune, .cleanLeaves, .pestCheck, .rotate, .repot, .newLeaf, .yellowLeaf, .pestFound, .note:
            "info.circle.fill"
        case .photo:
            "photo.stack.fill"
        case .detail:
            "info.circle.fill"
        }
    }

    static func quickActionItems(
        for plantID: UUID,
        localization l: L10n,
        actions: [PlantDockQuickAction]
    ) -> [QuickActionItem] {
        actions.map { action in
            QuickActionItem(
                id: "plant-\(plantID.uuidString)-\(action.actionType)",
                label: action.title(l: l),
                icon: action.icon,
                colorHex: action.colorHex,
                actionType: action.actionType,
                entityId: plantID,
                entityKind: .plant
            )
        }
    }

    private var colorHex: String {
        switch careCategory {
        case .hydration:
            "00D4AA"
        case .nutrition:
            "C8FF00"
        case .maintenance:
            "FFDD44"
        case .health:
            "F97316"
        case .growth:
            "A78BFA"
        case nil:
            "00D4AA"
        }
    }
}
