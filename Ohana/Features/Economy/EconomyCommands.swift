//
//  EconomyCommands.swift
//  Ohana
//
//  Economy command definitions that keep wallet/reward revision keys local.
//

import Foundation

enum EconomyCommand: FeatureDomainCommand {
    case coconutExchange(requestID: UUID)
    case shopPurchase(humanID: UUID?, itemID: String)
    case achievementReward(entityID: UUID, kind: String, badgeIDs: [String])

    var domainCommand: DomainCommand {
        switch self {
        case let .coconutExchange(requestID):
            return .coconutExchange(requestID: requestID)
        case let .shopPurchase(humanID, itemID):
            return .shopPurchase(humanID: humanID, itemID: itemID)
        case let .achievementReward(entityID, kind, badgeIDs):
            return .achievementReward(entityID: entityID, kind: kind, badgeIDs: badgeIDs)
        }
    }

    var affectedEntityIDs: Set<UUID> {
        switch self {
        case let .coconutExchange(requestID):
            return [requestID]
        case let .shopPurchase(humanID, _):
            return Set(humanID.map { [$0] } ?? [])
        case let .achievementReward(entityID, _, _):
            return [entityID]
        }
    }
}
