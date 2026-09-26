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
    case declined
    case pendingReview
    case completed
    case cancelled

    var id: String { rawValue }
}

nonisolated enum FamilyCollaborationTaskSubjectKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case household
    case human
    case pet
    case plant

    var id: String { rawValue }
}

@Model
final class FamilyCollaborationTask {
    #Index<FamilyCollaborationTask>(
        [\.statusRaw],
        [\.assignedToId],
        [\.relatedReminderId],
        [\.dueAt],
        [\.planId, \.nominalAt]
    )

    var id: UUID
    var title: String
    var note: String
    var kindRaw: String
    var statusRaw: String

    /// V87 canonical subject link. `relatedPetId` remains for V86 compatibility.
    var subjectKindRaw: String = ""
    var subjectId: String?
    var relatedPetId: String?
    var relatedEventId: String?
    var relatedReminderId: String?
    /// V95 recurrence-plan provenance. Legacy one-off rows remain `nil` / version zero.
    var planId: String?
    @Attribute(.unique) var occurrenceKey: String?
    var nominalAt: Date?
    var scheduleVersion: Int = 0

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
        subjectKind: FamilyCollaborationTaskSubjectKind? = nil,
        subjectId: String? = nil,
        relatedPetId: String? = nil,
        relatedEventId: String? = nil,
        relatedReminderId: String? = nil,
        planId: String? = nil,
        occurrenceKey: String? = nil,
        nominalAt: Date? = nil,
        scheduleVersion: Int = 0,
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
        let inferredSubjectKind = subjectKind
            ?? (Self.nonempty(relatedPetId) == nil ? .household : .pet)
        self.subjectKindRaw = inferredSubjectKind.rawValue
        let inferredSubjectId = Self.canonicalSubjectId(
            subjectId ?? (inferredSubjectKind == .pet ? relatedPetId : nil)
        )
        self.subjectId = inferredSubjectKind == .household ? nil : inferredSubjectId
        self.relatedPetId = inferredSubjectKind == .pet
            ? (inferredSubjectId ?? Self.nonempty(relatedPetId))
            : nil
        self.relatedEventId = relatedEventId
        self.relatedReminderId = relatedReminderId
        self.planId = planId
        self.occurrenceKey = occurrenceKey
        self.nominalAt = nominalAt
        self.scheduleVersion = max(0, scheduleVersion)
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

    /// Legacy V86 rows have an empty `subjectKindRaw`; their pet link remains authoritative.
    var subjectKind: FamilyCollaborationTaskSubjectKind {
        if let explicitKind = FamilyCollaborationTaskSubjectKind(rawValue: subjectKindRaw) {
            return explicitKind
        }
        return Self.nonempty(relatedPetId) == nil ? .household : .pet
    }

    var resolvedSubjectId: String? {
        switch subjectKind {
        case .household:
            nil
        case .human, .plant:
            Self.canonicalSubjectId(subjectId)
        case .pet:
            Self.canonicalSubjectId(subjectId) ?? Self.canonicalSubjectId(relatedPetId)
        }
    }

    func setSubject(kind: FamilyCollaborationTaskSubjectKind, id: String?) {
        subjectKindRaw = kind.rawValue
        switch kind {
        case .household:
            subjectId = nil
            relatedPetId = nil
        case .human, .plant:
            subjectId = Self.canonicalSubjectId(id)
            relatedPetId = nil
        case .pet:
            let normalizedId = Self.canonicalSubjectId(id)
            subjectId = normalizedId
            relatedPetId = normalizedId
        }
    }

    var isOpen: Bool {
        status == .active && assignedToId == nil && claimedById == nil
    }

    var isFinished: Bool {
        status == .declined || status == .completed || status == .cancelled
    }

    var isPendingReview: Bool {
        status == .pendingReview
    }

    var hasReward: Bool {
        rewardCoconuts > 0
    }

    func touch() {
        updatedAt = Date()
    }

    private static func canonicalSubjectId(_ raw: String?) -> String? {
        guard let raw = nonempty(raw) else { return nil }
        let firstComponent = raw.split(separator: ":", maxSplits: 1).first.map(String.init) ?? raw
        return UUID(uuidString: firstComponent)?.uuidString
    }

    private static func nonempty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
