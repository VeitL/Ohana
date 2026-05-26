//
//  OasisRewardRoutes.swift
//  Ohana
//
//  Typed presentation routes for the Oasis module.
//

import Foundation

enum OasisSheetRoute: Identifiable, Equatable {
    case coconutRules
    case achievements
    case inventory
    case coconutShop(ShopItem.ShopCategory)
    case gacha
    case checkInDetail
    case critterCodex

    var id: String {
        switch self {
        case .coconutRules:
            return "coconut-rules"
        case .achievements:
            return "achievements"
        case .inventory:
            return "inventory"
        case let .coconutShop(category):
            return "coconut-shop-\(category.rawValue)"
        case .gacha:
            return "gacha"
        case .checkInDetail:
            return "check-in-detail"
        case .critterCodex:
            return "critter-codex"
        }
    }
}

enum OasisFullScreenRoute: Identifiable, Equatable {
    case coconutLog

    var id: String {
        switch self {
        case .coconutLog:
            return "coconut-log"
        }
    }
}

enum OasisOverlayRoute: Identifiable, Equatable {
    case upgradeReward(routeID: UUID = UUID(), reward: OasisOpenedUpgradeReward)

    var id: UUID {
        switch self {
        case let .upgradeReward(routeID, _):
            return routeID
        }
    }

    var upgradeReward: OasisOpenedUpgradeReward? {
        switch self {
        case let .upgradeReward(_, reward):
            return reward
        }
    }
}

enum OasisConfirmationRoute: Identifiable, Equatable {
    case makeup(date: String)

    var id: String {
        switch self {
        case let .makeup(date):
            return "makeup-\(date)"
        }
    }

    var makeupDate: String? {
        switch self {
        case let .makeup(date):
            return date
        }
    }
}
