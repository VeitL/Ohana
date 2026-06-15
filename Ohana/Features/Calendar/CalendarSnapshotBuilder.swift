//
//  CalendarSnapshotBuilder.swift
//  Ohana
//
//  Narrow calendar aggregation for list/month surfaces. Views pass filtered event
//  collections in and render the resulting value snapshot.
//

import Foundation

struct CalendarEventOccurrence: Identifiable {
    let id: String
    let event: Event
    let occurrenceDate: Date
}

struct CalendarTimelineDateSection: Identifiable {
    let date: Date
    let occurrences: [CalendarEventOccurrence]

    var id: Date { date }
}

struct CalendarTimelineSnapshot {
    let expandedOccurrences: [CalendarEventOccurrence]
    let sections: [CalendarTimelineDateSection]

    var dates: [Date] {
        sections.map(\.date)
    }

    var dateSignature: String {
        dates.map(CalendarSnapshotBuilder.timelineDateID).joined(separator: "|")
    }

    var dateIDs: Set<String> {
        Set(dates.map(CalendarSnapshotBuilder.timelineDateID))
    }
}

enum CalendarSnapshotBuilder {
    static func buildTimeline(
        events: [Event],
        allEvents: [Event],
        pets: [Pet],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CalendarTimelineSnapshot {
        let visibilityContext = VisibilityContext(
            allEvents: allEvents,
            pets: pets,
            now: now,
            calendar: calendar
        )
        let occurrences = expandedOccurrences(
            events: events,
            visibilityContext: visibilityContext
        )
        let today = calendar.startOfDay(for: now)
        let occurrencesByDay = Dictionary(grouping: occurrences) { occurrence in
            calendar.startOfDay(for: occurrence.occurrenceDate)
        }
        .mapValues { dayOccurrences in
            dayOccurrences.sorted {
                if $0.occurrenceDate == $1.occurrenceDate {
                    return $0.event.startDate < $1.event.startDate
                }
                return $0.occurrenceDate < $1.occurrenceDate
            }
        }
        let sections = Array(Set(occurrencesByDay.keys).union([today]))
            .sorted()
            .map { CalendarTimelineDateSection(date: $0, occurrences: occurrencesByDay[$0] ?? []) }

        return CalendarTimelineSnapshot(
            expandedOccurrences: occurrences,
            sections: sections
        )
    }

    static func eventsForDate(
        _ events: [Event],
        date: Date,
        allEvents: [Event],
        pets: [Pet],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Event] {
        let visibilityContext = VisibilityContext(
            allEvents: allEvents,
            pets: pets,
            now: now,
            calendar: calendar
        )
        return events.filter {
            eventOccursOnDate($0, date: date, calendar: calendar) &&
                shouldShowOccurrence($0, occurrenceDate: date, visibilityContext: visibilityContext)
        }
    }

    nonisolated static func timelineDateID(_ date: Date) -> String {
        String(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))
    }

    static func eventOccursOnDate(_ event: Event, date: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        let eventStart = calendar.startOfDay(for: event.startDate)

        if event.recurrenceDays > 0 {
            guard dayStart >= eventStart else { return false }
            if let recurrenceEndDate = event.recurrenceEndDate {
                guard dayStart <= calendar.startOfDay(for: recurrenceEndDate) else { return false }
            }
            let diff = calendar.dateComponents([.day], from: eventStart, to: dayStart).day ?? 0
            return diff % event.recurrenceDays == 0
        }

        let eventEnd = event.endDate.map { calendar.startOfDay(for: $0) } ?? eventStart
        return eventStart < dayEnd && eventEnd >= dayStart
    }

    private static func expandedOccurrences(
        events: [Event],
        visibilityContext: VisibilityContext
    ) -> [CalendarEventOccurrence] {
        let now = visibilityContext.now
        let calendar = visibilityContext.calendar
        let cutoff = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        let future = calendar.date(byAdding: .month, value: 3, to: now) ?? now
        var result: [CalendarEventOccurrence] = []

        for event in events {
            let eventStart = calendar.startOfDay(for: event.startDate)
            if event.recurrenceDays > 0 {
                appendRecurringOccurrences(
                    for: event,
                    eventStart: eventStart,
                    cutoff: cutoff,
                    future: future,
                    visibilityContext: visibilityContext,
                    into: &result
                )
            } else if eventStart >= cutoff,
                      eventStart <= future,
                      shouldShowOccurrence(event, occurrenceDate: eventStart, visibilityContext: visibilityContext) {
                result.append(CalendarEventOccurrence(
                    id: event.id.uuidString,
                    event: event,
                    occurrenceDate: eventStart
                ))
            }
        }

        return result.sorted { $0.occurrenceDate < $1.occurrenceDate }
    }

    private static func appendRecurringOccurrences(
        for event: Event,
        eventStart: Date,
        cutoff: Date,
        future: Date,
        visibilityContext: VisibilityContext,
        into result: inout [CalendarEventOccurrence]
    ) {
        let calendar = visibilityContext.calendar
        let hardCap = min(event.recurrenceEndDate ?? future, future)
        var cursor = max(eventStart, cutoff)

        if cursor > eventStart {
            let diff = calendar.dateComponents([.day], from: eventStart, to: cursor).day ?? 0
            let steps = Int(ceil(Double(diff) / Double(event.recurrenceDays)))
            cursor = calendar.date(byAdding: .day, value: steps * event.recurrenceDays, to: eventStart) ?? eventStart
        }

        var safety = 0
        while cursor <= hardCap, safety < 200 {
            if shouldShowOccurrence(event, occurrenceDate: cursor, visibilityContext: visibilityContext) {
                result.append(CalendarEventOccurrence(
                    id: "\(event.id.uuidString)-\(cursor.timeIntervalSince1970)",
                    event: event,
                    occurrenceDate: cursor
                ))
            }
            cursor = calendar.date(byAdding: .day, value: event.recurrenceDays, to: cursor) ?? cursor
            safety += 1
        }
    }

    private static func shouldShowOccurrence(
        _ event: Event,
        occurrenceDate: Date,
        visibilityContext: VisibilityContext
    ) -> Bool {
        let calendar = visibilityContext.calendar
        guard let pet = visibilityContext.pet(for: event) else {
            return true
        }

        if FeedRuleMetadata.isAutoFeederEvent(event, pet: pet) {
            guard visibilityContext.feedModeByPetId[pet.id.uuidString] == .autoFeeder else {
                return false
            }
            return occurrenceMoment(for: event, occurrenceDate: occurrenceDate, calendar: calendar) > visibilityContext.now
        }

        if FeedRuleMetadata.isManualReminderEvent(event, pet: pet) {
            return visibilityContext.feedModeByPetId[pet.id.uuidString] == .manualReminder
        }

        guard calendar.startOfDay(for: occurrenceDate) >= visibilityContext.today else {
            return true
        }

        if WaterPlanWriter.isPlanEvent(event, pet: pet) {
            return visibilityContext.waterModeByPetId[pet.id.uuidString] == .reminder
        }

        return true
    }

    private static func occurrenceMoment(for event: Event, occurrenceDate: Date, calendar: Calendar) -> Date {
        guard event.recurrenceDays > 0 else { return event.startDate }
        let time = calendar.dateComponents([.hour, .minute, .second], from: event.startDate)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: calendar.startOfDay(for: occurrenceDate)
        ) ?? occurrenceDate
    }

    private struct VisibilityContext {
        let pets: [Pet]
        let feedModeByPetId: [String: FeedOperatingMode]
        let waterModeByPetId: [String: WaterOperatingMode]
        let today: Date
        let now: Date
        let calendar: Calendar

        init(allEvents: [Event], pets: [Pet], now: Date, calendar: Calendar) {
            self.now = now
            self.calendar = calendar
            self.today = calendar.startOfDay(for: now)
            self.pets = pets

            var hasManualFeedEvents = Set<String>()
            var hasAutoFeedEvents = Set<String>()
            var hasWaterPlanEvents = Set<String>()

            for event in allEvents {
                guard let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else { continue }
                let petId = pet.id.uuidString
                if FeedRuleMetadata.isManualReminderEvent(event, pet: pet) {
                    hasManualFeedEvents.insert(petId)
                }
                if FeedRuleMetadata.isAutoFeederEvent(event, pet: pet) {
                    hasAutoFeedEvents.insert(petId)
                }
                if WaterPlanWriter.isPlanEvent(event, pet: pet) {
                    hasWaterPlanEvents.insert(petId)
                }
            }

            self.feedModeByPetId = Dictionary(uniqueKeysWithValues: pets.map { pet in
                let petId = pet.id.uuidString
                return (petId, Self.feedMode(
                    for: pet,
                    hasManualReminderEvents: hasManualFeedEvents.contains(petId),
                    hasAutoFeederEvents: hasAutoFeedEvents.contains(petId)
                ))
            })
            self.waterModeByPetId = Dictionary(uniqueKeysWithValues: pets.map { pet in
                let petId = pet.id.uuidString
                return (petId, Self.waterMode(
                    for: pet,
                    hasPlanEvents: hasWaterPlanEvents.contains(petId)
                ))
            })
        }

        func pet(for event: Event) -> Pet? {
            MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets)
        }

        private static func feedMode(
            for pet: Pet,
            hasManualReminderEvents: Bool,
            hasAutoFeederEvents: Bool
        ) -> FeedOperatingMode {
            if let stored = FeedOperatingMode.stored(for: pet.id) {
                switch stored {
                case .manual:
                    return .manual
                case .manualReminder:
                    return hasManualReminderEvents ? .manualReminder : .manual
                case .autoFeeder:
                    return hasAutoFeederEvents ? .autoFeeder : .manual
                }
            }
            if hasAutoFeederEvents { return .autoFeeder }
            if hasManualReminderEvents { return .manualReminder }
            return .manual
        }

        private static func waterMode(for pet: Pet, hasPlanEvents: Bool) -> WaterOperatingMode {
            if let stored = WaterOperatingMode.stored(pet.id) {
                return stored == .reminder && !hasPlanEvents ? .manual : stored
            }
            return hasPlanEvents ? .reminder : .manual
        }
    }
}
