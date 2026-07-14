//
//  TaskCenterModels.swift
//  Ohana
//
//  Value snapshots for the global actionable-task center.
//

import Foundation

nonisolated enum TaskCenterSurface: String, CaseIterable, Identifiable, Sendable {
    case tasks
    case calendar

    var id: String { rawValue }
}

nonisolated enum TaskCenterUrgency: String, Equatable, Sendable {
    case standard
    case overdue
    case critical
}

nonisolated struct TaskCenterItemSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let eventID: UUID
    let title: String
    let subjectName: String?
    let eventType: EventType?
    let symbol: String
    let themeColorHex: String?
    let occurrenceDate: Date
    let scheduledAt: Date
    let isAllDay: Bool
    let isRecurring: Bool
    let urgency: TaskCenterUrgency
}

nonisolated struct TaskCenterSnapshot: Equatable, Sendable {
    let overdue: [TaskCenterItemSnapshot]
    let today: [TaskCenterItemSnapshot]
    let upcoming: [TaskCenterItemSnapshot]
    let todayCompletedCount: Int
    let todayTotalCount: Int

    static let empty = TaskCenterSnapshot(
        overdue: [],
        today: [],
        upcoming: [],
        todayCompletedCount: 0,
        todayTotalCount: 0
    )

    var pendingCount: Int {
        overdue.count + today.count + upcoming.count
    }

    var overdueCount: Int {
        overdue.count
    }

    var criticalCount: Int {
        overdue.count { $0.urgency == .critical }
    }

    var todayPendingCount: Int {
        max(0, todayTotalCount - todayCompletedCount)
    }

    var todayCompletionFraction: Double {
        guard todayTotalCount > 0 else { return pendingCount == 0 ? 1 : 0 }
        return min(1, max(0, Double(todayCompletedCount) / Double(todayTotalCount)))
    }
}

nonisolated struct TaskCenterBadgeSnapshot: Equatable, Sendable {
    let overdueCount: Int
    let criticalCount: Int

    static let empty = TaskCenterBadgeSnapshot(overdueCount: 0, criticalCount: 0)

    init(overdueCount: Int, criticalCount: Int) {
        self.overdueCount = max(0, overdueCount)
        self.criticalCount = max(0, criticalCount)
    }

    init(snapshot: TaskCenterSnapshot) {
        self.init(overdueCount: snapshot.overdueCount, criticalCount: snapshot.criticalCount)
    }
}

nonisolated enum TaskCenterSnapshotBuilder {
    /// Repeating schedules expose one current actionable occurrence in the center.
    /// Older occurrences remain available in Calendar; this keeps the high-frequency
    /// task surface bounded while preserving the existing completion semantics.
    private static let recurringOverdueLookbackDays = 14

    static func make(
        events: [Event],
        allEvents: [Event],
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        insurances: [PetInsurance] = [],
        petMedications: [PetMedication] = [],
        humanMedications: [HumanMedication] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskCenterSnapshot {
        let timeline = CalendarSnapshotBuilder.buildTimeline(
            events: events,
            allEvents: allEvents,
            pets: pets,
            now: now,
            calendar: calendar
        )
        let today = calendar.startOfDay(for: now)
        let recurringCutoff = calendar.date(
            byAdding: .day,
            value: -recurringOverdueLookbackDays,
            to: today
        ) ?? today
        var pendingByEventID: [UUID: [CalendarEventOccurrence]] = [:]
        var todayEventIDs: Set<UUID> = []
        var completedTodayEventIDs: Set<UUID> = []

        for occurrence in timeline.expandedOccurrences {
            let event = occurrence.event
            guard event.isActionableTask else { continue }
            let occurrenceDay = calendar.startOfDay(for: occurrence.occurrenceDate)

            if occurrenceDay == today {
                todayEventIDs.insert(event.id)
                if event.isOccurrenceMarkedComplete(on: occurrence.occurrenceDate) {
                    completedTodayEventIDs.insert(event.id)
                }
            }

            guard !event.isOccurrenceMarkedComplete(on: occurrence.occurrenceDate) else { continue }
            if event.recurrenceDays > 0, occurrenceDay < recurringCutoff {
                continue
            }
            pendingByEventID[event.id, default: []].append(occurrence)
        }

        var overdueItems: [TaskCenterItemSnapshot] = []
        var todayItems: [TaskCenterItemSnapshot] = []
        var upcomingItems: [TaskCenterItemSnapshot] = []

        for occurrences in pendingByEventID.values {
            guard let occurrence = currentOccurrence(
                from: occurrences,
                now: now,
                calendar: calendar
            ) else { continue }
            let item = makeItem(
                occurrence: occurrence,
                pets: pets,
                humans: humans,
                plants: plants,
                insurances: insurances,
                petMedications: petMedications,
                humanMedications: humanMedications,
                now: now,
                calendar: calendar
            )

            switch item.urgency {
            case .critical, .overdue:
                overdueItems.append(item)
            case .standard:
                if calendar.isDate(item.occurrenceDate, inSameDayAs: today) {
                    todayItems.append(item)
                } else {
                    upcomingItems.append(item)
                }
            }
        }

        return TaskCenterSnapshot(
            overdue: overdueItems.sorted(by: taskSort),
            today: todayItems.sorted(by: taskSort),
            upcoming: upcomingItems.sorted(by: taskSort),
            todayCompletedCount: completedTodayEventIDs.count,
            todayTotalCount: todayEventIDs.count
        )
    }

    private static func currentOccurrence(
        from occurrences: [CalendarEventOccurrence],
        now: Date,
        calendar: Calendar
    ) -> CalendarEventOccurrence? {
        let sorted = occurrences.sorted { occurrenceMoment($0, calendar: calendar) < occurrenceMoment($1, calendar: calendar) }
        if let overdue = sorted.first(where: { $0.event.isOverdue(on: $0.occurrenceDate, now: now) }) {
            return overdue
        }
        if let today = sorted.first(where: { calendar.isDateInToday($0.occurrenceDate) }) {
            return today
        }
        return sorted.first
    }

    private static func makeItem(
        occurrence: CalendarEventOccurrence,
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        insurances: [PetInsurance],
        petMedications: [PetMedication],
        humanMedications: [HumanMedication],
        now: Date,
        calendar: Calendar
    ) -> TaskCenterItemSnapshot {
        let event = occurrence.event
        let subject = subjectPresentation(
            for: event,
            pets: pets,
            humans: humans,
            plants: plants,
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications
        )
        let isOverdue = event.isOverdue(on: occurrence.occurrenceDate, now: now)
        let urgency: TaskCenterUrgency = if isOverdue, isHealthCritical(event) {
            .critical
        } else if isOverdue {
            .overdue
        } else {
            .standard
        }
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return TaskCenterItemSnapshot(
            id: "\(event.id.uuidString)-\(CalendarSnapshotBuilder.timelineDateID(occurrence.occurrenceDate))",
            eventID: event.id,
            title: title.isEmpty ? event.eventType : title,
            subjectName: subject.name,
            eventType: event.eventTypeEnum,
            symbol: event.silhouetteListSymbol,
            themeColorHex: subject.themeColorHex,
            occurrenceDate: occurrence.occurrenceDate,
            scheduledAt: occurrenceMoment(occurrence, calendar: calendar),
            isAllDay: event.isAllDay,
            isRecurring: event.recurrenceDays > 0,
            urgency: urgency
        )
    }

    private static func subjectPresentation(
        for event: Event,
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        insurances: [PetInsurance],
        petMedications: [PetMedication],
        humanMedications: [HumanMedication]
    ) -> (name: String?, themeColorHex: String?) {
        if let pet = MemberLifecycleActiveScheduleResolver.petTarget(
            for: event,
            pets: pets,
            petMedications: petMedications,
            insurances: insurances,
            includePassedAway: false
        ) {
            return (pet.name, pet.themeColorHex)
        }
        if let plantID = DomainEntityLinkRegistry.plantId(for: event),
           let plant = plants.first(where: { $0.id == plantID && !$0.isArchived }) {
            return (plant.name, plant.themeColorHex)
        }
        if let human = MemberLifecycleActiveScheduleResolver.humanOwner(
            for: event,
            humans: humans,
            humanMedications: humanMedications,
            includePassedAway: false
        ) ?? MemberLifecycleActiveScheduleResolver.humanInvolved(
            in: event,
            humans: humans,
            humanMedications: humanMedications,
            includePassedAway: false
        ) ?? MemberLifecycleActiveScheduleResolver.humanAssignee(
            for: event,
            humans: humans,
            includePassedAway: false
        ) {
            return (human.name, human.themeColorHex)
        }
        return (nil, nil)
    }

    private static func occurrenceMoment(
        _ occurrence: CalendarEventOccurrence,
        calendar _: Calendar
    ) -> Date {
        let event = occurrence.event
        if event.recurrenceDays > 0, !event.isAllDay {
            return Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrence.occurrenceDate)
        }
        return event.isAllDay ? occurrence.occurrenceDate : event.startDate
    }

    private static func isHealthCritical(_ event: Event) -> Bool {
        switch event.eventTypeEnum {
        case .medication, .petMedication, .petMedicationDose:
            true
        default:
            false
        }
    }

    private static func taskSort(_ lhs: TaskCenterItemSnapshot, _ rhs: TaskCenterItemSnapshot) -> Bool {
        if lhs.scheduledAt == rhs.scheduledAt {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return lhs.scheduledAt < rhs.scheduledAt
    }
}
