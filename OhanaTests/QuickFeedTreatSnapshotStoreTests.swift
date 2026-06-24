import Foundation
import Testing
@testable import Ohana

@MainActor
struct QuickFeedTreatSnapshotStoreTests {
    @Test func treatSnapshotCachesFiltersCountsAndCharts() {
        let pet = Pet(name: "Momo", species: "猫")
        let calendar = Calendar(identifier: .gregorian)
        let now = fixedDate()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let oldDay = calendar.date(byAdding: .day, value: -10, to: today) ?? today
        let lickable = PetCareLog(
            date: today.addingTimeInterval(3600),
            amountGrams: 8,
            note: FeedLogMetadata.treatFeedNoteMarker,
            treatKind: .lickable,
            pet: pet
        )
        let jerky = PetCareLog(
            date: yesterday.addingTimeInterval(3600),
            amountGrams: 5,
            note: FeedLogMetadata.treatFeedNoteMarker,
            treatKind: .jerky,
            pet: pet
        )
        let oldTreat = PetCareLog(
            date: oldDay,
            amountGrams: 12,
            note: FeedLogMetadata.treatFeedNoteMarker,
            treatKind: .lickable,
            pet: pet
        )
        let mainFood = PetCareLog(date: today, amountGrams: 40, foodKind: .dry, pet: pet)
        let lickableLedger = feedingLedgerEvent(from: lickable)
        let jerkyLedger = feedingLedgerEvent(from: jerky)
        let oldTreatLedger = feedingLedgerEvent(from: oldTreat)
        let mainFoodLedger = feedingLedgerEvent(from: mainFood)
        let entries = QuickFeedLedgerEntry.entries(
            pet: pet,
            feedingLedgerEvents: [lickableLedger, jerkyLedger, oldTreatLedger, mainFoodLedger],
            legacyCareLogs: [lickable, jerky, oldTreat, mainFood]
        )

        let snapshot = QuickFeedTreatSnapshot.build(
            pet: pet,
            feedingLedgerEntries: entries,
            range: .days7,
            selectedKind: .lickable,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.logsInRange.map(\.legacyModelId) == [lickable.id.uuidString, jerky.id.uuidString])
        #expect(snapshot.filteredLogsInRange.map(\.legacyModelId) == [lickable.id.uuidString])
        #expect(snapshot.filteredLogsToday.map(\.legacyModelId) == [lickable.id.uuidString])
        #expect(snapshot.filteredGramsToday == 8)
        #expect(snapshot.count(for: nil) == 2)
        #expect(snapshot.count(for: .lickable) == 1)
        #expect(snapshot.count(for: .jerky) == 1)
        #expect(snapshot.lastDate(for: .lickable) == lickable.date)
        #expect(snapshot.chartPoints.last?.value == 1)
        #expect(snapshot.filteredChartPoints.last?.value == 1)
    }

    private func fixedDate() -> Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func feedingLedgerEvent(from log: PetCareLog) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: log.date,
            subjectKind: .pet,
            subjectId: log.pet?.id.uuidString,
            eventKind: .care,
            actionType: CareType.feeding.rawValue,
            amountValue: log.amountGrams,
            amountUnit: "g",
            note: log.note,
            source: .quickAction,
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString
        )
    }
}
