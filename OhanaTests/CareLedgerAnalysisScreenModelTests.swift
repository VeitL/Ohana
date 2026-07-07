import Foundation
import Testing
@testable import Ohana

struct CareLedgerAnalysisScreenModelTests {
    @Test func dailyTrendPointsTrackRangeAndKindFilter() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let older = calendar.date(byAdding: .day, value: -8, to: today) ?? today
        let model = CareLedgerAnalysisScreenModel()

        model.applyQuerySnapshot(
            ledgerEvents: [
                ledger(kind: .care, occurredAt: today.addingTimeInterval(60)),
                ledger(kind: .care, occurredAt: today.addingTimeInterval(120)),
                ledger(kind: .hygiene, occurredAt: yesterday.addingTimeInterval(60)),
                ledger(kind: .walk, occurredAt: older)
            ],
            pets: [],
            humans: []
        )

        model.selectedRange = .week

        #expect(model.dailyTrendPoints.count == 7)
        #expect(model.dailyTrendTotal == 3)
        #expect(model.dailyTrendActiveDayCount == 2)
        #expect(model.dailyTrendPoints.last?.value == 2)

        model.selectedKind = .care

        #expect(model.dailyTrendTotal == 2)
        #expect(model.dailyTrendActiveDayCount == 1)
        #expect(model.dailyTrendPoints.last?.value == 2)
    }

    private func ledger(kind: CareLedgerEventKind, occurredAt: Date) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: occurredAt,
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: "pet-1",
            eventKind: kind,
            actionType: kind.rawValue
        )
    }
}
