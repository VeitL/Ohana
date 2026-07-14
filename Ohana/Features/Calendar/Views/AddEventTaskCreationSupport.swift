//
//  AddEventTaskCreationSupport.swift
//  Ohana
//
//  Pure task-prefill policy and event-editor initial state.
//

import Foundation

struct AddEventTaskCreationState: Equatable {
    let title: String
    let eventType: EventType
    let relatedEntityType: String
    let relatedEntityId: String
    let taskCareKindRaw: String

    init(preset: TaskCreationPreset, subjectName: String?, l: L10n) {
        let careTitle = preset.careKind.localizedTitle(l: l)
        let cleanSubjectName = subjectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        title = cleanSubjectName.isEmpty ? careTitle : "\(careTitle) · \(cleanSubjectName)"
        eventType = preset.careKind.eventType
        relatedEntityType = switch preset.subjectKind {
        case .pet: EntityKind.pet.rawValue
        case .plant: EntityKind.plant.rawValue
        }
        relatedEntityId = preset.subjectID.uuidString
        taskCareKindRaw = preset.careKind.rawValue
    }
}

enum AddEventCollaborationPolicy {
    static func showsControls(activeHumanCount: Int) -> Bool {
        activeHumanCount > 1
    }

    static func normalizedReward(
        _ requestedReward: Int,
        activeHumanCount: Int,
        creatorHumanID: UUID?,
        assigneeHumanID: UUID?
    ) -> Int {
        guard showsControls(activeHumanCount: activeHumanCount),
              let creatorHumanID,
              let assigneeHumanID,
              creatorHumanID != assigneeHumanID else {
            return 0
        }
        return FamilyTaskRewardPolicy.capped(requestedReward)
    }
}

extension AddEventContentView {
    struct InitialState {
        let title: String
        let eventType: EventType
        let startDate: Date
        let isAllDay: Bool
        let relatedEntityType: String
        let relatedEntityId: String
        let recurrenceOption: RecurrenceOption
        let recurrenceDays: Int
        let recurrenceEndDate: Date
        let reminderLeadOption: ReminderLeadOption
        let hasReminder: Bool
        let assigneeId: String?
    }

    static func subjectName(
        for preset: TaskCreationPreset,
        pets: [Pet],
        plants: [Plant]
    ) -> String? {
        switch preset.subjectKind {
        case .pet:
            pets.first(where: { $0.id == preset.subjectID })?.name
        case .plant:
            plants.first(where: { $0.id == preset.subjectID })?.name
        }
    }

    static func initialState(for event: Event?, occurrenceDate: Date?) -> InitialState {
        let defaultStartDate = defaultNewEventStartDate()
        let fallbackRecurrenceEnd = Calendar.current.date(byAdding: .month, value: 1, to: defaultStartDate) ?? defaultStartDate
        guard let event else {
            return InitialState(
                title: "",
                eventType: .daily,
                startDate: defaultStartDate,
                isAllDay: false,
                relatedEntityType: "",
                relatedEntityId: "",
                recurrenceOption: .none,
                recurrenceDays: 2,
                recurrenceEndDate: fallbackRecurrenceEnd,
                reminderLeadOption: .atTime,
                hasReminder: true,
                assigneeId: nil
            )
        }

        let startDate = displayStartDate(for: event, occurrenceDate: occurrenceDate)
        let recurrenceOption = recurrenceOption(for: event.recurrenceDays)
        let reminderLead = reminderLeadOption(for: event, displayStartDate: startDate)
        return InitialState(
            title: event.title,
            eventType: EventType(rawValue: event.eventType) ?? .daily,
            startDate: startDate,
            isAllDay: event.isAllDay,
            relatedEntityType: event.relatedEntityType,
            relatedEntityId: event.relatedEntityId,
            recurrenceOption: recurrenceOption,
            recurrenceDays: max(2, event.recurrenceDays),
            recurrenceEndDate: event.recurrenceEndDate ?? fallbackRecurrenceEnd,
            reminderLeadOption: reminderLead ?? .atTime,
            hasReminder: reminderLead != nil,
            assigneeId: event.assigneeId
        )
    }

    nonisolated static func defaultNewEventStartDate(now: Date = Date()) -> Date {
        let minimumFutureDate = now.addingTimeInterval(5 * 60)
        let fiveMinuteQuantum: TimeInterval = 5 * 60
        let roundedInterval = ceil(minimumFutureDate.timeIntervalSinceReferenceDate / fiveMinuteQuantum) * fiveMinuteQuantum
        return Date(timeIntervalSinceReferenceDate: roundedInterval)
    }

    private static func displayStartDate(for event: Event, occurrenceDate: Date?) -> Date {
        guard event.recurrenceDays > 0,
              let occurrenceDate else {
            return event.startDate
        }
        return event.isAllDay
            ? Calendar.current.startOfDay(for: occurrenceDate)
            : Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
    }

    private static func recurrenceOption(for days: Int) -> RecurrenceOption {
        switch days {
        case 0:
            .none
        case 1:
            .daily
        case 7:
            .weekly
        case 30:
            .monthly
        default:
            .custom
        }
    }

    private static func reminderLeadOption(for event: Event, displayStartDate: Date) -> ReminderLeadOption? {
        guard let reminder = event.reminders.sorted(by: { $0.scheduledAt < $1.scheduledAt }).first else {
            return nil
        }
        let minutes = Int(round(displayStartDate.timeIntervalSince(reminder.scheduledAt) / 60))
        return ReminderLeadOption(rawValue: max(0, minutes))
    }
}
