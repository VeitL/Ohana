import Foundation
import Testing
@testable import Ohana

@MainActor
struct QuickFeedOverviewSnapshotStoreTests {
    @Test func overviewSnapshotCachesMainFoodChartAndSourceTotals() {
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 50
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let oldDay = calendar.date(byAdding: .day, value: -8, to: today) ?? today
        let upcomingReminderDate = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let planEvent = Event(title: "Feed", startDate: upcomingReminderDate)
        let planReminder = Reminder(event: planEvent, scheduledAt: upcomingReminderDate)
        planEvent.reminders = [planReminder]

        let manualLog = PetCareLog(date: today.addingTimeInterval(3600), amountGrams: 40, foodKind: .dry, pet: pet)
        let planLog = PetCareLog(
            date: yesterday.addingTimeInterval(3600),
            amountGrams: 30,
            note: PetCareLog.plannedFeedNotePrefix + planEvent.id.uuidString,
            foodKind: .wet,
            pet: pet
        )
        let autoLog = PetCareLog(
            date: today.addingTimeInterval(7200),
            amountGrams: 20,
            note: FeedLogMetadata.autoNote(eventId: planEvent.id, scheduledAt: today.addingTimeInterval(7200)),
            foodKind: .dry,
            pet: pet
        )
        let oldLog = PetCareLog(date: oldDay, amountGrams: 99, foodKind: .dry, pet: pet)

        let snapshot = QuickFeedOverviewSnapshot.build(
            pet: pet,
            manualPlanEvents: [planEvent],
            careLogs: [manualLog, planLog, autoLog, oldLog],
            range: .days7,
            activeMode: .autoFeeder,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.mainFoodLogsInRange.map(\.id).contains(oldLog.id) == false)
        #expect(snapshot.feedModeLogsInRange.map(\.id) == [autoLog.id])
        #expect(snapshot.sourceTotal(.manualMain) == 40)
        #expect(snapshot.sourceTotal(.manualReminder) == 30)
        #expect(snapshot.sourceTotal(.autoMain) == 20)
        #expect(snapshot.mainFoodChartPoints.last?.value == 60)
        #expect(snapshot.todayAutoFeedLogs.map(\.id) == [autoLog.id])
        #expect(snapshot.todayPlanReminders.map(\.id) == [planReminder.id])
        #expect(snapshot.nextPendingManualReminder?.id == planReminder.id)
    }

    private func fixedDate() -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }
}
