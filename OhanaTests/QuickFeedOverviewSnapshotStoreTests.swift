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
        let entries = QuickFeedLedgerEntry.entries(
            pet: pet,
            feedingLedgerEvents: [manualLedger, planLedger, autoLedger, oldLedger],
            legacyCareLogs: [manualLog, planLog, autoLog, oldLog],
            manualPlanEvents: [planEvent],
            autoFeederEvents: [planEvent]
        )

        let snapshot = QuickFeedOverviewSnapshot.build(
            pet: pet,
            manualPlanEvents: [planEvent],
            autoFeederEvents: [planEvent],
            feedingLedgerEntries: entries,
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

        let entries = QuickFeedLedgerEntry.entries(
            pet: pet,
            feedingLedgerEvents: [ledger],
            legacyCareLogs: []
        )

        #expect(entries.map(\.id) == [ledger.id])
        #expect(entries.first?.legacyModelId == nil)
        #expect(entries.first?.foodKind == .wet)
        #expect(entries.first?.source == .manualMain)
    }

    @Test func feedingEntriesPreferLedgerMetadataForKindAndSession() {
        let pet = Pet(name: "Momo", species: "猫")
        let date = fixedDate()
        let legacySessionID = UUID()
        let metadataSessionID = UUID()
        let legacyLog = PetCareLog(
            date: date,
            amountGrams: 24,
            foodKind: .dry,
            treatKind: .dentalNeck,
            pet: pet
        )
        legacyLog.sharedSessionId = legacySessionID.uuidString
        var metadata = CareLedgerMetadata.addingString(
            CareLedgerMetadata.feedFoodKind,
            value: FeedFoodKind.wet.rawValue,
            to: ""
        )
        metadata = CareLedgerMetadata.addingString(
            CareLedgerMetadata.feedTreatKind,
            value: FeedTreatKind.jerky.rawValue,
            to: metadata
        )
        metadata = CareLedgerMetadata.addingString(
            CareLedgerMetadata.sharedSessionId,
            value: metadataSessionID.uuidString,
            to: metadata
        )
        let ledger = CareLedgerEvent(
            occurredAt: date,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: 24,
            amountUnit: "g",
            note: FeedLogMetadata.treatFeedNoteMarker,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: legacyLog.id.uuidString,
            metadataJSON: metadata
        )

        let entry = QuickFeedLedgerEntry.entries(
            pet: pet,
            feedingLedgerEvents: [ledger],
            legacyCareLogs: [legacyLog]
        ).first

        #expect(entry?.foodKind == .wet)
        #expect(entry?.treatKind == .jerky)
        #expect(entry?.sharedSessionId == metadataSessionID.uuidString)
        #expect(entry?.source == .treat)
    }

    @Test func feedHomeSnapshotUsesLedgerEntriesForVisibleProgress() {
        let pet = Pet(name: "Momo", species: "猫")
        pet.dailyPortionGrams = 50
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let legacyDryLog = PetCareLog(
            date: today.addingTimeInterval(600),
            amountGrams: 99,
            foodKind: .dry,
            pet: pet
        )
        let wetEntry = feedEntry(
            pet: pet,
            date: today.addingTimeInterval(1200),
            amount: 20,
            source: .manualMain,
            foodKind: .wet
        )
        let treatEntry = feedEntry(
            pet: pet,
            date: today.addingTimeInterval(1800),
            amount: 4,
            source: .treat,
            foodKind: .dry,
            treatKind: .jerky
        )
        let autoEntry = feedEntry(
            pet: pet,
            date: yesterday.addingTimeInterval(3600),
            amount: 12,
            source: .autoMain,
            foodKind: .dry
        )

        let snapshot = FeedHomeSnapshotBuilder.build(input: FeedHomeSnapshotInput(
            pet: pet,
            allEvents: [],
            careLogs: [legacyDryLog],
            feedingLedgerEntries: [wetEntry, treatEntry, autoEntry],
            foodRecords: [],
            now: now,
            todayLabel: "T",
            calendar: calendar
        ))

        #expect(snapshot.todayDryFoodGrams == 0)
        #expect(snapshot.todayWetFoodGrams == 20)
        #expect(snapshot.todayMainFoodGrams == 20)
        #expect(snapshot.todayTreatGrams == 4)
        #expect(snapshot.todayTreatCount == 1)
        #expect(snapshot.latestAutoFeedDate == autoEntry.date)
        #expect(snapshot.guidedSevenDayMainFoodPoints.last?.value == 20)
    }

    @Test func feedHomeSnapshotTreatsEmptyLedgerEntriesAsAuthoritative() {
        let pet = Pet(name: "Momo", species: "猫")
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let legacyDryLog = PetCareLog(
            date: today.addingTimeInterval(600),
            amountGrams: 99,
            foodKind: .dry,
            pet: pet
        )

        let snapshot = FeedHomeSnapshotBuilder.build(input: FeedHomeSnapshotInput(
            pet: pet,
            allEvents: [],
            careLogs: [legacyDryLog],
            feedingLedgerEntries: [],
            foodRecords: [],
            now: now,
            todayLabel: "T",
            calendar: calendar
        ))

        #expect(snapshot.todayMainFoodGrams == 0)
        #expect(snapshot.todayTreatCount == 0)
        #expect(snapshot.latestAutoFeedDate == nil)
        #expect(snapshot.guidedSevenDayMainFoodPoints.last?.value == 0)
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

    private func feedEntry(
        pet: Pet,
        date: Date,
        amount: Double,
        source: FeedLogSource,
        foodKind: FeedFoodKind,
        treatKind: FeedTreatKind? = nil
    ) -> QuickFeedLedgerEntry {
        QuickFeedLedgerEntry(
            id: UUID(),
            petId: pet.id,
            date: date,
            amountGrams: amount,
            note: "",
            source: source,
            foodKind: foodKind,
            treatKind: treatKind,
            legacyModelId: nil,
            sharedSessionId: "",
            actorId: nil,
            sourceEventId: nil,
            sourceReminderId: nil,
            metadataJSON: ""
        )
    }
}
