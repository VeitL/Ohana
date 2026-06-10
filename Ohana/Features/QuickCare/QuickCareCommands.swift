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
            .quickCare(entityID: petID, action: action)
        case let .plannedFeed(petID, _):
            .quickCare(entityID: petID, action: "plannedFeed")
        case let .potty(petID, type):
            .quickCare(entityID: petID, action: "potty:\(type)")
        case let .grooming(petID, type):
            .quickCare(entityID: petID, action: "groom:\(type)")
        case let .health(petID, type):
            .quickCare(entityID: petID, action: "health:\(type)")
        case let .medicationDose(petID, medicationID):
            .medicationDose(petID: petID, medicationID: medicationID)
        }
    }

    var affectedEntityIDs: Set<UUID> {
        switch self {
        case let .action(petID, _),
             let .potty(petID, _),
             let .grooming(petID, _),
             let .health(petID, _):
            [petID]
        case let .plannedFeed(petID, reminderID):
            [petID, reminderID]
        case let .medicationDose(petID, medicationID):
            [petID, medicationID]
        }
    }

    var revisionNote: String {
        switch self {
        case .action:
            "home.quickCare"
        case .plannedFeed:
            "home.plannedFeed"
        case .potty:
            "home.potty"
        case .grooming:
            "home.groom"
        case .health:
            "home.health"
        case .medicationDose:
            "home.medicationDose"
        }
    }
}
