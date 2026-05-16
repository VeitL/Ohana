//
//  FamilyCollaborationTask.swift
//  Ohana
//
//  Unified family task layer for collaboration, bounty, and Today Focus.
//

import Foundation
import SwiftData

enum FamilyCollaborationTaskKind: String, Codable, CaseIterable, Identifiable {
    case careReminder
    case householdTask
    case bounty

    var id: String { rawValue }
}

enum FamilyCollaborationTaskStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case claimed
    case pendingReview
    case completed
    case cancelled

    var id: String { rawValue }
}

@Model
final class FamilyCollaborationTask {
    #Index<FamilyCollaborationTask>([\.statusRaw], [\.assignedToId], [\.relatedReminderId], [\.dueAt])

    var id: UUID
    var title: String
    var note: String
    var kindRaw: String
    var statusRaw: String

    var relatedPetId: String?
    var relatedEventId: String?
    var relatedReminderId: String?

    var createdById: String
    var createdByName: String
    var assignedToId: String?
    var assignedToName: String?
    var claimedById: String?
    var claimedByName: String?
    var completedById: String?
    var completedByName: String?

    var rewardCoconuts: Int
    var dueAt: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var emoji: String

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        kind: FamilyCollaborationTaskKind,
        status: FamilyCollaborationTaskStatus = .active,
        relatedPetId: String? = nil,
        relatedEventId: String? = nil,
        relatedReminderId: String? = nil,
        createdById: String,
        createdByName: String,
        assignedToId: String? = nil,
        assignedToName: String? = nil,
        rewardCoconuts: Int = 0,
        dueAt: Date? = nil,
        emoji: String = "🎯",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.kindRaw = kind.rawValue
        self.statusRaw = status.rawValue
        self.relatedPetId = relatedPetId
        self.relatedEventId = relatedEventId
        self.relatedReminderId = relatedReminderId
        self.createdById = createdById
        self.createdByName = createdByName
        self.assignedToId = assignedToId
        self.assignedToName = assignedToName
        self.claimedById = nil
        self.claimedByName = nil
        self.completedById = nil
        self.completedByName = nil
        self.rewardCoconuts = rewardCoconuts
        self.dueAt = dueAt
        self.completedAt = nil
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.emoji = emoji
    }

    var kind: FamilyCollaborationTaskKind {
        get { FamilyCollaborationTaskKind(rawValue: kindRaw) ?? .householdTask }
        set { kindRaw = newValue.rawValue }
    }

    var status: FamilyCollaborationTaskStatus {
        get { FamilyCollaborationTaskStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var isOpen: Bool {
        status == .active && assignedToId == nil && claimedById == nil
    }

    var isFinished: Bool {
        status == .completed || status == .cancelled
    }

    var isPendingReview: Bool {
        status == .pendingReview
    }

    var hasReward: Bool {
        rewardCoconuts > 0 || kind == .bounty
    }

    func touch() {
        updatedAt = Date()
    }
}
