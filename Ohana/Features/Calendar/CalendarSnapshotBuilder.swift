//
//  CalendarSnapshotBuilder.swift
//  Ohana
//
//  Narrow calendar aggregation for list/month surfaces. Views pass filtered event
//  collections in and render the resulting value snapshot.
//

import Foundation
import SwiftData

nonisolated struct CalendarEventOccurrence: Identifiable {
    let id: String
    let event: Event
    let occurrenceDate: Date
}

nonisolated struct CalendarEventOccurrenceReference: Identifiable, Sendable {
    let id: String
    let eventModelID: PersistentIdentifier
    let occurrenceDate: Date
}

nonisolated struct CalendarTimelineDateSection: Identifiable {
    let date: Date
    let occurrences: [CalendarEventOccurrence]

    var id: Date { date }
}

nonisolated struct CalendarTimelineSnapshot {
    let expandedOccurrences: [CalendarEventOccurrence]
    let sections: [CalendarTimelineDateSection]

    static let empty = CalendarTimelineSnapshot(
        expandedOccurrences: [],
        sections: []
    )

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

nonisolated struct CalendarTimelineSnapshotReference: Sendable {
    let expandedOccurrences: [CalendarEventOccurrenceReference]
    let sections: [CalendarTimelineSectionReference]
}

private nonisolated struct CalendarOccurrenceDayIndex {
    let expandedOccurrences: [CalendarEventOccurrence]
    let occurrencesByDay: [Date: [CalendarEventOccurrence]]

    func events(on day: Date, calendar: Calendar) -> [Event] {
        let dayStart = calendar.startOfDay(for: day)
        return (occurrencesByDay[dayStart] ?? []).map(\.event)
    }
}

nonisolated struct CalendarTimelineSectionReference: Identifiable, Sendable {
    let date: Date
    let occurrences: [CalendarEventOccurrenceReference]

    var id: Date { date }
}

nonisolated struct CalendarPreparedSnapshot {
    let filteredEvents: [Event]
    let timeline: CalendarTimelineSnapshot
    let eventsByDay: [String: [Event]]
    let weekEventsByDay: [String: [Event]]
    let monthEventDayIDs: Set<String>

    static let empty = CalendarPreparedSnapshot(
        filteredEvents: [],
        timeline: .empty,
        eventsByDay: [:],
        weekEventsByDay: [:],
        monthEventDayIDs: []
    )

    nonisolated func events(forDayID dayID: String) -> [Event] {
        eventsByDay[dayID] ?? []
    }

    nonisolated func events(for date: Date) -> [Event] {
        events(forDayID: CalendarSnapshotBuilder.timelineDateID(date))
    }

    nonisolated func eventDayIDs(for dates: [Date]) -> Set<String> {
        Set(dates
            .map(CalendarSnapshotBuilder.timelineDateID)
            .filter { !(eventsByDay[$0] ?? []).isEmpty })
    }
}

nonisolated struct CalendarPreparedSnapshotReference: Sendable {
    let filteredEventModelIDs: [PersistentIdentifier]
    let timeline: CalendarTimelineSnapshotReference
    let eventModelIDsByDay: [String: [PersistentIdentifier]]
    let weekEventModelIDsByDay: [String: [PersistentIdentifier]]
    let monthEventDayIDs: Set<String>
}

nonisolated struct CalendarRoutePreparedSnapshot {
    let key: CalendarPreparedSnapshotTriggerKey
    let snapshot: CalendarPreparedSnapshot
}

nonisolated struct CalendarRoutePreparedSnapshotReference: Sendable {
    let key: CalendarPreparedSnapshotTriggerKey
    let snapshot: CalendarPreparedSnapshotReference
}

extension CalendarRoutePreparedSnapshotReference {
    nonisolated func rehydrated(eventByModelID: [PersistentIdentifier: Event]) -> CalendarRoutePreparedSnapshot {
        CalendarRoutePreparedSnapshot(
            key: key,
            snapshot: snapshot.rehydrated(eventByModelID: eventByModelID)
        )
    }
}

extension CalendarPreparedSnapshotReference {
    nonisolated func rehydrated(eventByModelID: [PersistentIdentifier: Event]) -> CalendarPreparedSnapshot {
        CalendarPreparedSnapshot(
            filteredEvents: events(for: filteredEventModelIDs, eventByModelID: eventByModelID),
            timeline: timeline.rehydrated(eventByModelID: eventByModelID),
            eventsByDay: eventModelIDsByDay.mapValues { modelIDs in
                events(for: modelIDs, eventByModelID: eventByModelID)
            },
            weekEventsByDay: weekEventModelIDsByDay.mapValues { modelIDs in
                events(for: modelIDs, eventByModelID: eventByModelID)
            },
            monthEventDayIDs: monthEventDayIDs
        )
    }

    private nonisolated func events(
        for modelIDs: [PersistentIdentifier],
        eventByModelID: [PersistentIdentifier: Event]
    ) -> [Event] {
        modelIDs.compactMap { eventByModelID[$0] }
    }
}

extension CalendarTimelineSnapshotReference {
    nonisolated func rehydrated(eventByModelID: [PersistentIdentifier: Event]) -> CalendarTimelineSnapshot {
        CalendarTimelineSnapshot(
            expandedOccurrences: expandedOccurrences.compactMap {
                $0.rehydrated(eventByModelID: eventByModelID)
            },
            sections: sections.map {
                $0.rehydrated(eventByModelID: eventByModelID)
            }
        )
    }
}

extension CalendarTimelineSectionReference {
    nonisolated func rehydrated(eventByModelID: [PersistentIdentifier: Event]) -> CalendarTimelineDateSection {
        CalendarTimelineDateSection(
            date: date,
            occurrences: occurrences.compactMap {
                $0.rehydrated(eventByModelID: eventByModelID)
            }
        )
    }
}

extension CalendarEventOccurrenceReference {
    nonisolated func rehydrated(eventByModelID: [PersistentIdentifier: Event]) -> CalendarEventOccurrence? {
        guard let event = eventByModelID[eventModelID] else { return nil }
        return CalendarEventOccurrence(
            id: id,
            event: event,
            occurrenceDate: occurrenceDate
        )
    }
}

nonisolated enum CalendarTimelineWindowPolicy {
    static let pastMonths = -3
    static let futureMonths = 3
    static let windowedEventFetchLimit = 600
    static let recurringEventFetchLimit = 500

    static func bounds(
        around now: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        (
            calendar.date(byAdding: .month, value: pastMonths, to: now) ?? now,
            calendar.date(byAdding: .month, value: futureMonths, to: now) ?? now
        )
    }
}

nonisolated enum CalendarSnapshotBuilder {
    static let preparedSnapshotWindowKey = "rolling-window-v1"

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
        let occurrenceIndex = buildOccurrenceDayIndex(
            events: events,
            visibilityContext: visibilityContext
        )
        return buildTimeline(
            occurrenceIndex: occurrenceIndex,
            visibilityContext: visibilityContext
        )
    }

    static func preparedSnapshot(
        filteredEvents: [Event],
        allEvents: [Event],
        pets: [Pet],
        weekDays: [Date],
        monthDays: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CalendarPreparedSnapshot {
        let visibilityContext = VisibilityContext(
            allEvents: allEvents,
            pets: pets,
            now: now,
            calendar: calendar
        )
        let occurrenceIndex = buildOccurrenceDayIndex(
            events: filteredEvents,
            visibilityContext: visibilityContext
        )
        let timeline = buildTimeline(
            occurrenceIndex: occurrenceIndex,
            visibilityContext: visibilityContext
        )
        let eventsByDay = buildEventsByDay(occurrenceIndex: occurrenceIndex)
        var weekEventsByDay: [String: [Event]] = [:]
        for day in weekDays {
            let dayID = timelineDateID(day)
            weekEventsByDay[dayID] = eventsByDay[dayID] ?? []
        }
        let monthEventDayIDs = Set(monthDays.map(timelineDateID).filter { !(eventsByDay[$0] ?? []).isEmpty })
        return CalendarPreparedSnapshot(
            filteredEvents: filteredEvents,
            timeline: timeline,
            eventsByDay: eventsByDay,
            weekEventsByDay: weekEventsByDay,
            monthEventDayIDs: monthEventDayIDs
        )
    }

    static func preparedSnapshotReference(
        filteredEvents: [Event],
        allEvents: [Event],
        pets: [Pet],
        weekDays: [Date],
        monthDays: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CalendarPreparedSnapshotReference {
        preparedSnapshot(
            filteredEvents: filteredEvents,
            allEvents: allEvents,
            pets: pets,
            weekDays: weekDays,
            monthDays: monthDays,
            now: now,
            calendar: calendar
        )
        .reference
    }

    @MainActor
    static func mergingFamilyTaskProjectionEvents(
        _ projectionEvents: [Event],
        into snapshot: CalendarPreparedSnapshot,
        allEvents: [Event],
        pets: [Pet],
        selectedDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CalendarPreparedSnapshot {
        let persistedOccurrenceKeys = Set(snapshot.filteredEvents.compactMap(\.familyTaskOccurrenceKey))
        let uniqueProjectionEvents = projectionEvents.filter { event in
            guard let occurrenceKey = event.familyTaskOccurrenceKey else { return false }
            return !persistedOccurrenceKeys.contains(occurrenceKey)
        }
        guard !uniqueProjectionEvents.isEmpty else { return snapshot }

        let projectionSnapshot = preparedSnapshot(
            filteredEvents: uniqueProjectionEvents,
            allEvents: allEvents + uniqueProjectionEvents,
            pets: pets,
            weekDays: weekDays(around: now, calendar: calendar),
            monthDays: monthDays(containing: selectedDate, calendar: calendar),
            now: now,
            calendar: calendar
        )
        let occurrences = (snapshot.timeline.expandedOccurrences + projectionSnapshot.timeline.expandedOccurrences)
            .sorted(by: occurrenceSort)
        let occurrencesByDay = Dictionary(grouping: occurrences) { occurrence in
            calendar.startOfDay(for: occurrence.occurrenceDate)
        }
        .mapValues { $0.sorted(by: occurrenceSort) }
        let sectionDates = Set(snapshot.timeline.sections.map(\.date))
            .union(projectionSnapshot.timeline.sections.map(\.date))
        let sections = sectionDates.sorted().map { date in
            CalendarTimelineDateSection(
                date: date,
                occurrences: occurrencesByDay[calendar.startOfDay(for: date)] ?? []
            )
        }

        return CalendarPreparedSnapshot(
            filteredEvents: snapshot.filteredEvents + uniqueProjectionEvents,
            timeline: CalendarTimelineSnapshot(
                expandedOccurrences: occurrences,
                sections: sections
            ),
            eventsByDay: mergingEventBuckets(snapshot.eventsByDay, projectionSnapshot.eventsByDay),
            weekEventsByDay: mergingEventBuckets(
                snapshot.weekEventsByDay,
                projectionSnapshot.weekEventsByDay
            ),
            monthEventDayIDs: snapshot.monthEventDayIDs.union(projectionSnapshot.monthEventDayIDs)
        )
    }

    private static func mergingEventBuckets(
        _ first: [String: [Event]],
        _ second: [String: [Event]]
    ) -> [String: [Event]] {
        first.merging(second) { existing, projected in
            (existing + projected).sorted {
                if $0.startDate == $1.startDate { return $0.title < $1.title }
                return $0.startDate < $1.startDate
            }
        }
    }

    private static func occurrenceSort(
        _ first: CalendarEventOccurrence,
        _ second: CalendarEventOccurrence
    ) -> Bool {
        if first.occurrenceDate == second.occurrenceDate {
            if first.event.startDate == second.event.startDate {
                return first.event.title < second.event.title
            }
            return first.event.startDate < second.event.startDate
        }
        return first.occurrenceDate < second.occurrenceDate
    }

    private static func weekDays(around now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let daysFromSunday = calendar.component(.weekday, from: today) - 1
        guard let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else { return [] }
        return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    }

    private static func monthDays(containing date: Date, calendar: Calendar) -> [Date] {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }

    private static func buildTimeline(
        occurrenceIndex: CalendarOccurrenceDayIndex,
        visibilityContext: VisibilityContext
    ) -> CalendarTimelineSnapshot {
        let calendar = visibilityContext.calendar
        let today = calendar.startOfDay(for: visibilityContext.now)
        let sections = Array(Set(occurrenceIndex.occurrencesByDay.keys).union([today]))
            .sorted()
            .map { CalendarTimelineDateSection(date: $0, occurrences: occurrenceIndex.occurrencesByDay[$0] ?? []) }

        return CalendarTimelineSnapshot(
            expandedOccurrences: occurrenceIndex.expandedOccurrences,
            sections: sections
        )
    }

    private static func buildEventsByDay(
        occurrenceIndex: CalendarOccurrenceDayIndex
    ) -> [String: [Event]] {
        var eventsByDay: [String: [Event]] = [:]
        for (day, occurrences) in occurrenceIndex.occurrencesByDay {
            guard !occurrences.isEmpty else { continue }
            eventsByDay[timelineDateID(day)] = occurrences.map(\.event)
        }
        return eventsByDay
    }

    private static func buildOccurrenceDayIndex(
        events: [Event],
        visibilityContext: VisibilityContext
    ) -> CalendarOccurrenceDayIndex {
        let occurrences = expandedOccurrences(
            events: events,
            visibilityContext: visibilityContext
        )
        let calendar = visibilityContext.calendar
        let occurrencesByDay = Dictionary(grouping: occurrences) { occurrence in
            calendar.startOfDay(for: occurrence.occurrenceDate)
        }
        .mapValues { dayOccurrences in
            dayOccurrences.sorted {
                if $0.occurrenceDate == $1.occurrenceDate {
                    if $0.event.startDate == $1.event.startDate {
                        return $0.event.title < $1.event.title
                    }
                    return $0.event.startDate < $1.event.startDate
                }
                return $0.occurrenceDate < $1.occurrenceDate
            }
        }
        return CalendarOccurrenceDayIndex(
            expandedOccurrences: occurrences,
            occurrencesByDay: occurrencesByDay
        )
    }

    nonisolated static func timelineDateID(_ date: Date) -> String {
        String(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))
    }

    private static func expandedOccurrences(
        events: [Event],
        visibilityContext: VisibilityContext
    ) -> [CalendarEventOccurrence] {
        let now = visibilityContext.now
        let calendar = visibilityContext.calendar
        let window = CalendarTimelineWindowPolicy.bounds(around: now, calendar: calendar)
        let cutoff = window.start
        let future = window.end
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
            } else {
                appendSingleEventOccurrences(
                    for: event,
                    eventStart: eventStart,
                    cutoff: cutoff,
                    future: future,
                    visibilityContext: visibilityContext,
                    into: &result
                )
            }
        }

        return result.sorted {
            if $0.occurrenceDate == $1.occurrenceDate {
                if $0.event.startDate == $1.event.startDate {
                    return $0.event.title < $1.event.title
                }
                return $0.event.startDate < $1.event.startDate
            }
            return $0.occurrenceDate < $1.occurrenceDate
        }
    }

    private static func appendSingleEventOccurrences(
        for event: Event,
        eventStart: Date,
        cutoff: Date,
        future: Date,
        visibilityContext: VisibilityContext,
        into result: inout [CalendarEventOccurrence]
    ) {
        let calendar = visibilityContext.calendar
        let eventEnd = event.endDate.map { calendar.startOfDay(for: $0) } ?? eventStart
        var cursor = max(eventStart, calendar.startOfDay(for: cutoff))
        let hardCap = min(eventEnd, calendar.startOfDay(for: future))
        var safety = 0
        while cursor <= hardCap, safety < 370 {
            if shouldShowOccurrence(event, occurrenceDate: cursor, visibilityContext: visibilityContext) {
                result.append(CalendarEventOccurrence(
                    id: occurrenceID(for: event, occurrenceDate: cursor),
                    event: event,
                    occurrenceDate: cursor
                ))
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            safety += 1
        }
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
                    id: occurrenceID(for: event, occurrenceDate: cursor),
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
        if PlantReminderPreferenceStore.isPlantCareCompletionEvent(event),
           let plantID = DomainEntityLinkRegistry.plantId(for: event),
           let careType = PlantReminderPreferenceStore.careType(forEventType: event.eventType),
           !PlantReminderPreferenceStore.isCompletionCalendarEnabled(forPlantID: plantID, careType: careType) {
            return false
        }

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

    private static func occurrenceID(for event: Event, occurrenceDate: Date) -> String {
        "\(event.id.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))"
    }

    private nonisolated struct VisibilityContext {
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

private extension CalendarPreparedSnapshot {
    nonisolated var reference: CalendarPreparedSnapshotReference {
        CalendarPreparedSnapshotReference(
            filteredEventModelIDs: filteredEvents.map(\.persistentModelID),
            timeline: timeline.reference,
            eventModelIDsByDay: eventsByDay.mapValues { events in
                events.map(\.persistentModelID)
            },
            weekEventModelIDsByDay: weekEventsByDay.mapValues { events in
                events.map(\.persistentModelID)
            },
            monthEventDayIDs: monthEventDayIDs
            )
        }
    }

private extension CalendarTimelineSnapshot {
    nonisolated var reference: CalendarTimelineSnapshotReference {
        CalendarTimelineSnapshotReference(
            expandedOccurrences: expandedOccurrences.map(\.reference),
            sections: sections.map(\.reference)
        )
    }
}

private extension CalendarTimelineDateSection {
    nonisolated var reference: CalendarTimelineSectionReference {
        CalendarTimelineSectionReference(
            date: date,
            occurrences: occurrences.map(\.reference)
        )
    }
}

private extension CalendarEventOccurrence {
    nonisolated var reference: CalendarEventOccurrenceReference {
        CalendarEventOccurrenceReference(
            id: id,
            eventModelID: event.persistentModelID,
            occurrenceDate: occurrenceDate
        )
    }
}
