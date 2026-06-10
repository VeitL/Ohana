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
            .coconutExchange(requestID: requestID)
        case let .shopPurchase(humanID, itemID):
            .shopPurchase(humanID: humanID, itemID: itemID)
        case let .achievementReward(entityID, kind, badgeIDs):
            .achievementReward(entityID: entityID, kind: kind, badgeIDs: badgeIDs)
        }
    }

    var affectedEntityIDs: Set<UUID> {
        switch self {
        case let .coconutExchange(requestID):
            [requestID]
        case let .shopPurchase(humanID, _):
            Set(humanID.map { [$0] } ?? [])
        case let .achievementReward(entityID, _, _):
            [entityID]
        }
    }
}
