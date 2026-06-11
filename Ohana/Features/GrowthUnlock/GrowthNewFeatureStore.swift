//
//  GrowthNewFeatureStore.swift
//  Ohana
//
//  Lightweight persistence for newly unlocked growth-stage entry badges.
//

import Foundation
import SwiftUI

enum GrowthNewFeatureStore {
    static let revisionKey = "ohanaGrowthNewFeatureRevisionV1"

    private static let pendingStagesKey = "ohanaGrowthPendingFeatureStagesV1"
    private static let defaults = UserDefaults.standard

    static func markPending(_ steps: [GrowthUnlockStep]) {
        guard !steps.isEmpty else { return }
        var ids = pendingStageIDs()
        let before = ids.count
        ids.formUnion(steps.map(\.id.rawValue))
        guard ids.count != before else { return }
        store(ids)
    }

    static func markVisited(_ destination: FMDest?) {
        guard let destination else { return }
        markVisited(stageID: GrowthUnlockPolicy.stageID(for: destination))
    }

    static func markVisited(_ oasisRoute: OasisSheetRoute) {
        switch oasisRoute {
        case .achievements:
            markVisited(feature: .achievements)
        case .coconutShop:
            markVisited(stageID: GrowthUnlockPolicy.stageID(for: FMDest.coconutShop))
        case .gacha:
            markVisited(stageID: GrowthUnlockPolicy.stageID(for: FMDest.gacha))
        case .critterCodex:
            markVisited(stageID: .mastery)
        case .coconutRules, .growthRoadmap, .inventory, .checkInDetail:
            break
        }
    }

    static func markVisited(feature: PetFeature) {
        markVisited(stageID: GrowthUnlockPolicy.stageID(for: feature))
    }

    static func markVisited(quickActionType: String) {
        guard let feature = quickActionFeature(quickActionType) else { return }
        markVisited(feature: feature)
    }

    static func markVisited(group: FeatureGroup) {
        markVisited(stageID: GrowthUnlockPolicy.stageID(for: group))
    }

    static func hasPending(_ destination: FMDest?) -> Bool {
        guard let destination else { return hasAnyPending }
        return hasPending(stageID: GrowthUnlockPolicy.stageID(for: destination))
    }

    static func hasPending(feature: PetFeature) -> Bool {
        hasPending(stageID: GrowthUnlockPolicy.stageID(for: feature))
    }

    static func hasPending(group: FeatureGroup) -> Bool {
        hasPending(stageID: GrowthUnlockPolicy.stageID(for: group))
    }

    static func hasPending(oasisFeature: OasisBentoFeature) -> Bool {
        switch oasisFeature {
        case .shop:
            hasPending(FMDest.coconutShop)
        case .achievements:
            hasPending(feature: .achievements)
        case .critters:
            hasPending(stageID: .mastery)
        case .gacha:
            hasPending(FMDest.gacha)
        }
    }

    static func hasPending(homeShortcut: HomeFabFunctionShortcut) -> Bool {
        hasPending(homeShortcut.destination)
    }

    static func hasPending(expandedShortcut: ExpandedCardFabShortcut) -> Bool {
        switch expandedShortcut.action {
        case let .detail(feature):
            return hasPending(feature: feature)
        case let .quick(actionType):
            if let feature = quickActionFeature(actionType) {
                return hasPending(feature: feature)
            }
            return false
        case .allFeatures, .humanAllFeatures:
            return hasAnyPending
        case .humanQuick:
            return false
        }
    }

    static var hasAnyPending: Bool {
        !pendingStageIDs().isEmpty
    }

    private static func markVisited(stageID: GrowthUnlockStageID) {
        var ids = pendingStageIDs()
        guard ids.remove(stageID.rawValue) != nil else { return }
        store(ids)
    }

    private static func hasPending(stageID: GrowthUnlockStageID) -> Bool {
        pendingStageIDs().contains(stageID.rawValue)
    }

    private static func pendingStageIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: pendingStagesKey) ?? [])
    }

    private static func quickActionFeature(_ actionType: String) -> PetFeature? {
        switch actionType {
        case "feed":
            .food
        case "water", "waterChange", "filterClean":
            .food
        case "potty", "litter":
            .potty
        case "walk":
            .walks
        case "play":
            .moments
        case "health":
            .health
        case "medication":
            .medications
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange":
            .hygiene
        case "weight":
            .weight
        case "expense":
            .expense
        case "moment":
            .moments
        default:
            nil
        }
    }

    private static func store(_ ids: Set<String>) {
        defaults.set(Array(ids).sorted(), forKey: pendingStagesKey)
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
    }
}

struct GrowthNewFeatureDot: View {
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(Color.goRed)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(Color.ohanaPrimaryActionText.opacity(0.92), lineWidth: max(1, size * 0.18))
            }
            .shadow(color: Color.goRed.opacity(0.36), radius: 4, y: 1) // ui-v4: allow tiny notification dot lift
            .accessibilityHidden(true)
    }
}
