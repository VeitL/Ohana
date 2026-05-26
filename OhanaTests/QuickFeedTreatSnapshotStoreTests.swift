import Foundation
@testable import Ohana
import Testing

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

        let snapshot = QuickFeedTreatSnapshot.build(
            pet: pet,
            careLogs: [lickable, jerky, oldTreat, mainFood],
            range: .days7,
            selectedKind: .lickable,
            now: now,
            calendar: calendar
        )

        #expect(snapshot.logsInRange.map(\.id) == [lickable.id, jerky.id])
        #expect(snapshot.filteredLogsInRange.map(\.id) == [lickable.id])
        #expect(snapshot.filteredLogsToday.map(\.id) == [lickable.id])
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
}
