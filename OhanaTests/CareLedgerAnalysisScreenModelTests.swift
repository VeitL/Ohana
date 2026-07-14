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

    @Test func batchAndSharedCareDistinguishOperationsFromObjectCoverage() {
        let now = Date()
        let model = CareLedgerAnalysisScreenModel()
        let plantTransaction = UUID().uuidString
        let sharedPetSession = UUID().uuidString

        model.applyQuerySnapshot(
            ledgerEvents: [
                ledger(
                    kind: .plantCare,
                    actionType: "watering",
                    occurredAt: now,
                    subjectId: "plant-1",
                    metadataJSON: "{\"careTransactionId\":\"\(plantTransaction)\"}"
                ),
                ledger(
                    kind: .plantCare,
                    actionType: "watering",
                    occurredAt: now,
                    subjectId: "plant-2",
                    metadataJSON: "{\"careTransactionId\":\"\(plantTransaction)\"}"
                ),
                ledger(
                    kind: .hygiene,
                    actionType: "litterBox",
                    occurredAt: now,
                    subjectId: "pet-1",
                    metadataJSON: "{\"sharedSessionId\":\"\(sharedPetSession)\"}"
                ),
                ledger(
                    kind: .hygiene,
                    actionType: "litterBox",
                    occurredAt: now,
                    subjectId: "pet-2",
                    metadataJSON: "{\"sharedSessionId\":\"\(sharedPetSession)\"}"
                ),
                ledger(
                    kind: .hygiene,
                    actionType: "litterBox",
                    occurredAt: now,
                    subjectId: "pet-2",
                    metadataJSON: "{\"sharedSessionId\":\"\(sharedPetSession)\"}"
                )
            ],
            pets: [],
            humans: []
        )
        model.selectedRange = .all

        #expect(model.realOperationCount == 2)
        #expect(model.objectCoverageCount == 4)
        #expect(model.dailyTrendTotal == 2)
        #expect(model.kindStats.map(\.1).reduce(0, +) == 2)
    }

    private func ledger(
        kind: CareLedgerEventKind,
        actionType: String? = nil,
        occurredAt: Date,
        subjectId: String = "pet-1",
        metadataJSON: String = ""
    ) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: occurredAt,
            actorKind: .human,
            actorId: "human-1",
            subjectKind: .pet,
            subjectId: subjectId,
            eventKind: kind,
            actionType: actionType ?? kind.rawValue,
            metadataJSON: metadataJSON
        )
    }
}
