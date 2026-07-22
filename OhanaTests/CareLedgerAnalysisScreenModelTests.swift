import Foundation
import Testing
@testable import Ohana

@MainActor
struct CareLedgerAnalysisScreenModelTests {
    @Test func freeAndPersonalCareRangesStayConsistentWithHouseholdInsights() {
        #expect(CareLedgerRangeFilter.allCases == [.week, .month, .days90, .year, .all])
        #expect(!CareLedgerRangeFilter.week.requiresPersonal)
        #expect(!CareLedgerRangeFilter.month.requiresPersonal)
        #expect(CareLedgerRangeFilter.days90.requiresPersonal)
        #expect(CareLedgerRangeFilter.year.requiresPersonal)
        #expect(CareLedgerRangeFilter.all.requiresPersonal)
        #expect(CareLedgerRangeFilter.week.trendDayCount == 7)
        #expect(CareLedgerRangeFilter.month.trendDayCount == 30)
        #expect(CareLedgerRangeFilter.days90.trendDayCount == 90)
        #expect(CareLedgerRangeFilter.year.trendDayCount == 365)
    }

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
            subjects: []
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
            subjects: []
        )
        model.selectedRange = .all

        #expect(model.realOperationCount == 2)
        #expect(model.objectCoverageCount == 4)
        #expect(model.dailyTrendTotal == 2)
        #expect(model.kindStats.map(\.1).reduce(0, +) == 2)
    }

    @Test func subjectSelectionKeepsFreeAnalysisScopedToOneObject() throws {
        let now = Date()
        let first = Pet(name: "Mochi", species: "cat")
        let second = Pet(name: "Nori", species: "cat")
        let firstSubject = CareLedgerAnalysisSubjectSnapshot(
            id: "pet:\(first.id.uuidString)",
            kind: CareLedgerSubjectKind.pet.rawValue,
            subjectID: first.id.uuidString,
            name: first.name
        )
        let secondSubject = CareLedgerAnalysisSubjectSnapshot(
            id: "pet:\(second.id.uuidString)",
            kind: CareLedgerSubjectKind.pet.rawValue,
            subjectID: second.id.uuidString,
            name: second.name
        )
        let model = CareLedgerAnalysisScreenModel()
        model.applyQuerySnapshot(
            ledgerEvents: [
                ledger(kind: .care, occurredAt: now, subjectId: first.id.uuidString),
                ledger(kind: .care, occurredAt: now, subjectId: second.id.uuidString)
            ],
            subjects: [firstSubject, secondSubject]
        )

        #expect(model.availableSubjects.map(\.name) == ["Mochi", "Nori"])
        model.selectedSubjectKey = try #require(model.availableSubjects.first?.id)
        #expect(model.realOperationCount == 1)
        #expect(model.objectCoverageCount == 1)
        model.selectedSubjectKey = nil
        #expect(model.realOperationCount == 2)
    }

    private func ledger(
        kind: CareLedgerEventKind,
        actionType: String? = nil,
        occurredAt: Date,
        subjectId: String = "pet-1",
        metadataJSON: String = ""
    ) -> CareLedgerAnalysisEventSnapshot {
        CareLedgerAnalysisEventSnapshot(
            id: UUID(),
            occurredAt: occurredAt,
            actorKind: CareLedgerActorKind.human.rawValue,
            actorId: "human-1",
            subjectKind: CareLedgerSubjectKind.pet.rawValue,
            subjectId: subjectId,
            eventKind: kind.rawValue,
            actionType: actionType ?? kind.rawValue,
            amountValue: 0,
            coconutDelta: 0,
            metadataJSON: metadataJSON
        )
    }
}
