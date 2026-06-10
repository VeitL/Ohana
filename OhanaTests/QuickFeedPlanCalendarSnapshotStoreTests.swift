import Foundation
import Testing
@testable import Ohana

@MainActor
struct QuickFeedPlanCalendarSnapshotStoreTests {
    @Test func planCalendarSnapshotBuildsManualOccurrencesAndReminders() {
        let pet = Pet(name: "Momo", species: "猫")
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let event = Event(
            title: "Breakfast",
            startDate: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        event.feedRuleKindRaw = FeedRuleKind.manualReminder.rawValue
        event.feedAmountGrams = 40
        let reminder = Reminder(event: event, scheduledAt: event.startDate)
        reminder.statusEnum = .completed
        event.reminders = [reminder]

        let snapshot = QuickFeedPlanCalendarSnapshot.build(
            manualEvents: [event],
            autoEvents: [],
            careLogs: [],
            activeMode: .manualReminder,
            month: today,
            selectedDate: today,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.monthKey.isEmpty == false)
        #expect(snapshot.allReminders.map(\.id) == [reminder.id])
        #expect(snapshot.selectedDateOccurrences.count == 1)
        #expect(snapshot.selectedDateOccurrences.first?.isCompleted == true)
        #expect(snapshot.daySummaries.filter(\.isInDisplayedMonth).contains { !$0.markers.isEmpty })
    }

    @Test func planCalendarSnapshotBuildsAutoOccurrencesFromDedupedLogs() {
        let pet = Pet(name: "Momo", species: "猫")
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let event = Event(
            title: "Auto",
            startDate: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today) ?? today,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        event.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        let log = PetCareLog(
            date: event.startDate,
            amountGrams: 35,
            note: FeedLogMetadata.autoNote(eventId: event.id, scheduledAt: event.startDate),
            foodKind: .dry,
            pet: pet
        )

        let snapshot = QuickFeedPlanCalendarSnapshot.build(
            manualEvents: [],
            autoEvents: [event],
            careLogs: [log],
            activeMode: .autoFeeder,
            month: today,
            selectedDate: today,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.selectedDateOccurrences.count == 1)
        #expect(snapshot.selectedDateOccurrences.first?.autoLog?.id == log.id)
        #expect(snapshot.selectedDateOccurrences.first?.isCompleted == true)
    }

    @Test func autoPlanCalendarDoesNotMarkPastOccurrencesMissed() {
        let pet = Pet(name: "Momo", species: "猫")
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let event = Event(
            title: "Auto",
            startDate: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today) ?? today,
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        event.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue

        let snapshot = QuickFeedPlanCalendarSnapshot.build(
            manualEvents: [],
            autoEvents: [event],
            careLogs: [],
            activeMode: .autoFeeder,
            month: today,
            selectedDate: today,
            now: now,
            calendar: calendar
        )

        let todayMarkers = snapshot.daySummaries
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
            .flatMap(\.markers)
        #expect(!todayMarkers.contains { marker in
            if case .missed = marker.status { return true }
            return false
        })
    }

    private func fixedDate() -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }
}
