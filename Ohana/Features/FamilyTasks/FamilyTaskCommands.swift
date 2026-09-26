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
    case createPlan(planID: UUID)
    case update(taskID: UUID)
    case delete(taskID: UUID)
    case claim(taskID: UUID, humanID: UUID)
    case complete(taskID: UUID, humanID: UUID?)
    case decline(taskID: UUID, humanID: UUID)
    case postpone(taskID: UUID, humanID: UUID)
    case comment(taskID: UUID, humanID: UUID)
    case cancel(taskID: UUID, creatorID: UUID)
    case confirm(taskID: UUID, reviewerID: UUID?)
    case returnForRedo(taskID: UUID, reviewerID: UUID?)

    var domainCommand: DomainCommand {
        switch self {
        case .migrateLegacyBounties:
            .unknown(action: "familyTask:migrateLegacyBounties")
        case let .assignReminder(taskID, _):
            .legacyBounty(taskID: taskID, action: "assignReminder")
        case let .create(taskID):
            .legacyBounty(taskID: taskID, action: "create")
        case let .createPlan(planID):
            .command("familyTasks", "createPlan", ["planID": planID.uuidString])
        case let .update(taskID):
            .legacyBounty(taskID: taskID, action: "update")
        case let .delete(taskID):
            .legacyBounty(taskID: taskID, action: "delete")
        case let .claim(taskID, _):
            .legacyBounty(taskID: taskID, action: "claim")
        case let .complete(taskID, _):
            .legacyBounty(taskID: taskID, action: "complete")
        case let .decline(taskID, _):
            .legacyBounty(taskID: taskID, action: "declineAssignment")
        case let .postpone(taskID, _):
            .legacyBounty(taskID: taskID, action: "postponeOccurrence")
        case let .comment(taskID, _):
            .legacyBounty(taskID: taskID, action: "comment")
        case let .cancel(taskID, _):
            .legacyBounty(taskID: taskID, action: "cancel")
        case let .confirm(taskID, _):
            .legacyBounty(taskID: taskID, action: "confirm")
        case let .returnForRedo(taskID, _):
            .legacyBounty(taskID: taskID, action: "returnForRedo")
        }
    }

    var affectedEntityIDs: Set<UUID> {
        switch self {
        case .migrateLegacyBounties:
            return []
        case let .assignReminder(taskID, reminderID):
            return [taskID, reminderID]
        case let .create(taskID),
             let .createPlan(taskID),
             let .update(taskID),
             let .delete(taskID):
            return [taskID]
        case let .claim(taskID, humanID):
            return [taskID, humanID]
        case let .complete(taskID, humanID),
             let .confirm(taskID, humanID),
             let .returnForRedo(taskID, humanID):
            var affected: Set<UUID> = [taskID]
            if let humanID {
                affected.insert(humanID)
            }
            return affected
        case let .decline(taskID, humanID),
             let .postpone(taskID, humanID),
             let .comment(taskID, humanID),
             let .cancel(taskID, humanID):
            return [taskID, humanID]
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
        case .createPlan:
            "createPlan"
        case .update:
            "update"
        case .delete:
            "delete"
        case .claim:
            "claim"
        case .complete:
            "complete"
        case .decline:
            "declineAssignment"
        case .postpone:
            "postponeOccurrence"
        case .comment:
            "comment"
        case .cancel:
            "cancel"
        case .confirm:
            "confirm"
        case .returnForRedo:
            "returnForRedo"
        }
    }
}
