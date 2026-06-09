//
//  QuickCareCommands.swift
//  Ohana
//
//  Feature-local command definitions bridged to the legacy central pipeline.
//

import Foundation

protocol FeatureDomainCommand: Hashable {
    var domainCommand: DomainCommand { get }
}

enum QuickCareCommand: FeatureDomainCommand {
    case action(petID: UUID, action: String)
    case plannedFeed(petID: UUID, reminderID: UUID)
    case potty(petID: UUID, type: String)
    case grooming(petID: UUID, type: String)
    case health(petID: UUID, type: String)
    case medicationDose(petID: UUID, medicationID: UUID)

    var domainCommand: DomainCommand {
        switch self {
        case let .action(petID, action):
            return .quickCare(entityID: petID, action: action)
        case let .plannedFeed(petID, _):
            return .quickCare(entityID: petID, action: "plannedFeed")
        case let .potty(petID, type):
            return .quickCare(entityID: petID, action: "potty:\(type)")
        case let .grooming(petID, type):
            return .quickCare(entityID: petID, action: "groom:\(type)")
        case let .health(petID, type):
            return .quickCare(entityID: petID, action: "health:\(type)")
        case let .medicationDose(petID, medicationID):
            return .medicationDose(petID: petID, medicationID: medicationID)
        }
    }

    var affectedEntityIDs: Set<UUID> {
        switch self {
        case let .action(petID, _),
             let .potty(petID, _),
             let .grooming(petID, _),
             let .health(petID, _):
            return [petID]
        case let .plannedFeed(petID, reminderID):
            return [petID, reminderID]
        case let .medicationDose(petID, medicationID):
            return [petID, medicationID]
        }
    }

    var revisionNote: String {
        switch self {
        case .action:
            return "home.quickCare"
        case .plannedFeed:
            return "home.plannedFeed"
        case .potty:
            return "home.potty"
        case .grooming:
            return "home.groom"
        case .health:
            return "home.health"
        case .medicationDose:
            return "home.medicationDose"
        }
    }
}
