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
        let manualLedger = feedingLedgerEvent(from: manualLog)
        let planLedger = feedingLedgerEvent(
            from: planLog,
            source: .reminder,
            sourceEventId: planEvent.id.uuidString,
            sourceReminderId: planReminder.id.uuidString
        )
        let autoLedger = feedingLedgerEvent(
            from: autoLog,
            note: "",
            source: .service,
            sourceEventId: planEvent.id.uuidString
        )
        let oldLedger = feedingLedgerEvent(from: oldLog)

        let snapshot = QuickFeedOverviewSnapshot.build(
            pet: pet,
            manualPlanEvents: [planEvent],
            autoFeederEvents: [planEvent],
            feedingLedgerEvents: [manualLedger, planLedger, autoLedger, oldLedger],
            legacyCareLogs: [manualLog, planLog, autoLog, oldLog],
            range: .days7,
            activeMode: .autoFeeder,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.mainFoodLogsInRange.map(\.legacyModelId).contains(oldLog.id.uuidString) == false)
        #expect(snapshot.feedModeLogsInRange.map(\.legacyModelId) == [autoLog.id.uuidString])
        #expect(snapshot.sourceTotal(.manualMain) == 40)
        #expect(snapshot.sourceTotal(.manualReminder) == 30)
        #expect(snapshot.sourceTotal(.autoMain) == 20)
        #expect(snapshot.mainFoodChartPoints.last?.value == 60)
        #expect(snapshot.todayAutoFeedLogs.map(\.legacyModelId) == [autoLog.id.uuidString])
        #expect(snapshot.todayPlanReminders.map(\.id) == [planReminder.id])
        #expect(snapshot.nextPendingManualReminder?.id == planReminder.id)
    }

    @Test func feedingEntriesIncludeLedgerOnlyEvents() {
        let pet = Pet(name: "Momo", species: "猫")
        pet.mainFoodKind = .wet
        let date = fixedDate()
        let ledger = CareLedgerEvent(
            occurredAt: date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: 24,
            amountUnit: "g",
            note: PetCareLog.manualFeedNoteMarker,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: nil
        )

        let entries = QuickFeedOverviewSnapshot.feedingEntries(
            pet: pet,
            feedingLedgerEvents: [ledger],
            legacyCareLogs: []
        )

        #expect(entries.map(\.id) == [ledger.id])
        #expect(entries.first?.legacyModelId == nil)
        #expect(entries.first?.foodKind == .wet)
        #expect(entries.first?.source == .manualMain)
    }

    private func fixedDate() -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func feedingLedgerEvent(
        from log: PetCareLog,
        note: String? = nil,
        source: CareLedgerSource = .quickAction,
        sourceEventId: String? = nil,
        sourceReminderId: String? = nil
    ) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: log.date,
            subjectKind: .pet,
            subjectId: log.pet?.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: log.amountGrams,
            amountUnit: "g",
            note: note ?? log.note,
            source: source,
            sourceEventId: sourceEventId,
            sourceReminderId: sourceReminderId,
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString
        )
    }
}
