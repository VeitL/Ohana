//
//  FamilyTaskPlan.swift
//  Ohana
//
//  Recurrence authority for materialized family collaboration tasks.
//

import Foundation
import SwiftData

nonisolated enum FamilyTaskPlanStatus: String, Codable, CaseIterable, Sendable {
    case active
    case cancelled
}

@Model
final class FamilyTaskPlan {
    #Index<FamilyTaskPlan>(
        [\.statusRaw, \.assignedToId],
        [\.materializedThroughAt],
        [\.createdAt]
    )

    var id: UUID
    var title: String
    var note: String
    var emoji: String
    var kindRaw: String
    var statusRaw: String

    var subjectKindRaw: String
    var subjectId: String?
    var subjectName: String

    var createdById: String
    var createdByName: String
    var assignedToId: String
    var assignedToName: String
    var rewardCoconuts: Int

    var recurrenceKindRaw: String
    var intervalDays: Int
    var weekdayMask: Int
    var monthDay: Int
    var anchorAt: Date
    var startsAt: Date?
    var endsAt: Date?
    var timeZoneIdentifier: String
    var scheduleVersion: Int

    var isAllDay: Bool
    var reminderLeadMinutes: Int?
    var eventTypeRaw: String
    var taskCareKindRaw: String

    /// Inclusive civil day through which occurrences have been materialized.
    var materializedThroughAt: Date?
    /// Optional legacy/source event used while recurrence ownership is adopted.
    var sourceEventId: String?

    var createdAt: Date
    var updatedAt: Date
    var cancelledAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        emoji: String = "✅",
        kind: FamilyCollaborationTaskKind = .householdTask,
        status: FamilyTaskPlanStatus = .active,
        subjectKind: FamilyCollaborationTaskSubjectKind = .household,
        subjectId: String? = nil,
        subjectName: String = "",
        createdById: String,
        createdByName: String,
        assignedToId: String,
        assignedToName: String,
        rewardCoconuts: Int = 0,
        recurrenceRule: FamilyTaskRecurrenceRule,
        anchorAt: Date,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        scheduleVersion: Int = 1,
        isAllDay: Bool = true,
        reminderLeadMinutes: Int? = nil,
        eventTypeRaw: String = EventType.task.rawValue,
        taskCareKindRaw: String = "",
        materializedThroughAt: Date? = nil,
        sourceEventId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.emoji = emoji
        kindRaw = kind.rawValue
        statusRaw = status.rawValue
        subjectKindRaw = subjectKind.rawValue
        self.subjectId = subjectKind == .household ? nil : Self.nonempty(subjectId)
        self.subjectName = subjectName
        self.createdById = createdById
        self.createdByName = createdByName
        self.assignedToId = assignedToId
        self.assignedToName = assignedToName
        self.rewardCoconuts = max(0, rewardCoconuts)
        recurrenceKindRaw = recurrenceRule.kind.rawValue
        intervalDays = recurrenceRule.intervalDays
        weekdayMask = recurrenceRule.weekdayMask
        monthDay = recurrenceRule.monthDay
        self.anchorAt = anchorAt
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.scheduleVersion = max(1, scheduleVersion)
        self.isAllDay = isAllDay
        self.reminderLeadMinutes = reminderLeadMinutes.map { max(0, $0) }
        self.eventTypeRaw = eventTypeRaw
        self.taskCareKindRaw = taskCareKindRaw
        self.materializedThroughAt = materializedThroughAt
        self.sourceEventId = sourceEventId
        self.createdAt = createdAt
        updatedAt = createdAt
        cancelledAt = nil
    }

    var kind: FamilyCollaborationTaskKind {
        get { FamilyCollaborationTaskKind(rawValue: kindRaw) ?? .householdTask }
        set { kindRaw = newValue.rawValue }
    }

    var status: FamilyTaskPlanStatus {
        get { FamilyTaskPlanStatus(rawValue: statusRaw) ?? .active }
        set {
            statusRaw = newValue.rawValue
            cancelledAt = newValue == .cancelled ? (cancelledAt ?? Date()) : nil
        }
    }

    var subjectKind: FamilyCollaborationTaskSubjectKind {
        get { FamilyCollaborationTaskSubjectKind(rawValue: subjectKindRaw) ?? .household }
        set {
            subjectKindRaw = newValue.rawValue
            if newValue == .household {
                subjectId = nil
            }
        }
    }

    var recurrenceRule: FamilyTaskRecurrenceRule {
        get {
            switch FamilyTaskRecurrenceKind(rawValue: recurrenceKindRaw) ?? .once {
            case .once:
                .once
            case .everyNDays:
                .everyNDays(intervalDays)
            case .weekly:
                .weekly(weekdayMask: weekdayMask)
            case .monthlyDay:
                .monthlyDay(monthDay)
            case .monthlyLastDay:
                .monthlyLastDay
            }
        }
        set {
            recurrenceKindRaw = newValue.kind.rawValue
            intervalDays = newValue.intervalDays
            weekdayMask = newValue.weekdayMask
            monthDay = newValue.monthDay
        }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private static func nonempty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
