//
//  FamilyTaskActivity.swift
//  Ohana
//
//  Durable, recipient-targeted collaboration activity for family tasks.
//

import Foundation
import SwiftData

nonisolated enum FamilyTaskActivityKind: String, Codable, CaseIterable, Sendable {
    case assigned
    case declined
    case completed
    case submittedForReview
    case postponed
    case commented
    case edited
    case cancelled
    case approved
    case rewarded
    case returnedForRedo
    case missedSummary
}

@Model
final class FamilyTaskActivity {
    #Index<FamilyTaskActivity>(
        [\.recipientHumanId, \.readAt, \.createdAt],
        [\.taskId, \.createdAt],
        [\.planId, \.createdAt],
        [\.occurrenceKey]
    )

    var id: UUID
    var planId: String?
    var taskId: String?
    var occurrenceKey: String?
    var kindRaw: String
    var actorHumanId: String
    var actorHumanName: String
    var recipientHumanId: String
    var taskTitleSnapshot: String
    var body: String
    var oldDueAt: Date?
    var newDueAt: Date?
    var countValue: Int
    @Attribute(.unique) var idempotencyKey: String
    var createdAt: Date
    var readAt: Date?

    init(
        id: UUID = UUID(),
        planId: String? = nil,
        taskId: String? = nil,
        occurrenceKey: String? = nil,
        kind: FamilyTaskActivityKind,
        actorHumanId: String,
        actorHumanName: String,
        recipientHumanId: String,
        taskTitleSnapshot: String,
        body: String = "",
        oldDueAt: Date? = nil,
        newDueAt: Date? = nil,
        countValue: Int = 0,
        idempotencyKey: String,
        createdAt: Date = Date(),
        readAt: Date? = nil
    ) {
        self.id = id
        self.planId = planId
        self.taskId = taskId
        self.occurrenceKey = occurrenceKey
        kindRaw = kind.rawValue
        self.actorHumanId = actorHumanId
        self.actorHumanName = actorHumanName
        self.recipientHumanId = recipientHumanId
        self.taskTitleSnapshot = taskTitleSnapshot
        self.body = body
        self.oldDueAt = oldDueAt
        self.newDueAt = newDueAt
        self.countValue = countValue
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.readAt = readAt
    }

    var kind: FamilyTaskActivityKind {
        get { FamilyTaskActivityKind(rawValue: kindRaw) ?? .commented }
        set { kindRaw = newValue.rawValue }
    }

    var isRead: Bool {
        readAt != nil
    }
}
