//
//  FamilyTaskCommands.swift
//  Ohana
//
//  Feature-local family task command keys bridged to the legacy revision bus.
//

import Foundation

enum FamilyTaskCommand: FeatureDomainCommand {
    case migrateLegacyBounties
    case assignReminder(taskID: UUID, reminderID: UUID)
    case create(taskID: UUID)
    case update(taskID: UUID)
    case delete(taskID: UUID)
    case claim(taskID: UUID, humanID: UUID)
    case complete(taskID: UUID, humanID: UUID?)
    case confirm(taskID: UUID, reviewerID: UUID?)
    case reject(taskID: UUID, reviewerID: UUID?)

    var domainCommand: DomainCommand {
        switch self {
        case .migrateLegacyBounties:
            .unknown(action: "familyTask:migrateLegacyBounties")
        case let .assignReminder(taskID, _):
            .legacyBounty(taskID: taskID, action: "assignReminder")
        case let .create(taskID):
            .legacyBounty(taskID: taskID, action: "create")
        case let .update(taskID):
            .legacyBounty(taskID: taskID, action: "update")
        case let .delete(taskID):
            .legacyBounty(taskID: taskID, action: "delete")
        case let .claim(taskID, _):
            .legacyBounty(taskID: taskID, action: "claim")
        case let .complete(taskID, _):
            .legacyBounty(taskID: taskID, action: "complete")
        case let .confirm(taskID, _):
            .legacyBounty(taskID: taskID, action: "confirm")
        case let .reject(taskID, _):
            .legacyBounty(taskID: taskID, action: "reject")
        }
    }

    var affectedEntityIDs: Set<UUID> {
        switch self {
        case .migrateLegacyBounties:
            return []
        case let .assignReminder(taskID, reminderID):
            return [taskID, reminderID]
        case let .create(taskID),
             let .update(taskID),
             let .delete(taskID):
            return [taskID]
        case let .claim(taskID, humanID):
            return [taskID, humanID]
        case let .complete(taskID, humanID),
             let .confirm(taskID, humanID),
             let .reject(taskID, humanID):
            var affected: Set<UUID> = [taskID]
            if let humanID {
                affected.insert(humanID)
            }
            return affected
        }
    }

    var revisionNote: String {
        "familyTask.\(actionName)"
    }

    private var actionName: String {
        switch self {
        case .migrateLegacyBounties:
            "migrateLegacyBounties"
        case .assignReminder:
            "assignReminder"
        case .create:
            "create"
        case .update:
            "update"
        case .delete:
            "delete"
        case .claim:
            "claim"
        case .complete:
            "complete"
        case .confirm:
            "confirm"
        case .reject:
            "reject"
        }
    }
}
