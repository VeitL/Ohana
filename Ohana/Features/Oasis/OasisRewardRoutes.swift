//
//  OasisRewardRoutes.swift
//  Ohana
//
//  Typed presentation routes for the Oasis module.
//

import Foundation

enum OasisSheetRoute: Identifiable, Equatable {
    case coconutRules
    case growthRoadmap
    case achievements
    case inventory
    case coconutShop(ShopItem.ShopCategory)
    case gacha
    case checkInDetail
    case critterCodex

    var id: String {
        switch self {
        case .coconutRules:
            "coconut-rules"
        case .growthRoadmap:
            "growth-roadmap"
        case .achievements:
            "achievements"
        case .inventory:
            "inventory"
        case let .coconutShop(category):
            "coconut-shop-\(category.rawValue)"
        case .gacha:
            "gacha"
        case .checkInDetail:
            "check-in-detail"
        case .critterCodex:
            "critter-codex"
        }
    }
}

enum OasisFullScreenRoute: Identifiable, Equatable {
    case coconutLog

    var id: String {
        switch self {
        case .coconutLog:
            "coconut-log"
        }
    }
}

enum OasisOverlayRoute: Identifiable, Equatable {
    case upgradeReward(routeID: UUID = UUID(), reward: OasisOpenedUpgradeReward)

    var id: UUID {
        switch self {
        case let .upgradeReward(routeID, _):
            routeID
        }
    }

    var upgradeReward: OasisOpenedUpgradeReward? {
        switch self {
        case let .upgradeReward(_, reward):
            reward
        }
    }
}

enum OasisConfirmationRoute: Identifiable, Equatable {
    case makeup(date: String)

    var id: String {
        switch self {
        case let .makeup(date):
            "makeup-\(date)"
        }
    }

    var makeupDate: String? {
        switch self {
        case let .makeup(date):
            date
        }
    }
}
