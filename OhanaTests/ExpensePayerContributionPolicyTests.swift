import Foundation
import Testing
@testable import Ohana

struct ExpensePayerContributionPolicyTests {
    @Test func threePayersSplitMinorUnitRemainderDeterministically() throws {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let contributions = try ExpensePayerContributionPolicy.equalSplit(
            total: 100,
            humanIDs: [first, second, third]
        )

        #expect(contributions.map(\.humanID) == [first, second, third])
        #expect(contributions.map(\.minorUnits) == [3334, 3333, 3333])
        #expect(contributions.reduce(Int64(0)) { $0 + $1.minorUnits } == 10000)
    }

    @Test func customSixtyFortyAllocationValidatesWithoutChangingOrder() throws {
        let first = UUID()
        let second = UUID()
        let requested = [
            try ExpensePayerContributionPolicy.contribution(humanID: first, amount: 60),
            try ExpensePayerContributionPolicy.contribution(humanID: second, amount: 40)
        ]

        let validated = try ExpensePayerContributionPolicy.validated(requested, total: 100)

        #expect(validated == requested)
        #expect(validated.map(\.minorUnits) == [6000, 4000])
    }

    @Test func payerDraftAmountsProduceAnExactHeaderTotal() throws {
        let contributions = [
            try ExpensePayerContributionPolicy.contribution(humanID: UUID(), amount: 6),
            try ExpensePayerContributionPolicy.contribution(humanID: UUID(), amount: 8)
        ]

        #expect(try ExpensePayerContributionPolicy.totalAmount(of: contributions) == 14)
    }

    @Test func duplicateZeroAndMismatchedContributionsAreRejected() {
        let first = UUID()
        let second = UUID()

        #expect(throws: ExpensePayerContributionError.invalidAllocation) {
            try ExpensePayerContributionPolicy.validated(
                [
                    ExpensePayerContribution(humanID: first, minorUnits: 5000),
                    ExpensePayerContribution(humanID: first, minorUnits: 5000)
                ],
                total: 100
            )
        }
        #expect(throws: ExpensePayerContributionError.invalidAllocation) {
            try ExpensePayerContributionPolicy.validated(
                [
                    ExpensePayerContribution(humanID: first, minorUnits: 10000),
                    ExpensePayerContribution(humanID: second, minorUnits: 0)
                ],
                total: 100
            )
        }
        #expect(throws: ExpensePayerContributionError.invalidAllocation) {
            try ExpensePayerContributionPolicy.validated(
                [
                    ExpensePayerContribution(humanID: first, minorUnits: 6000),
                    ExpensePayerContribution(humanID: second, minorUnits: 3999)
                ],
                total: 100
            )
        }
    }

    @Test func hugeFiniteAmountsFailWithoutIntegerConversionTrap() {
        #expect(ExpensePayerContributionPolicy.minorUnits(Double.greatestFiniteMagnitude) == nil)
        #expect(ExpensePayerContributionPolicy.minorUnits(Double(Int64.max) / 100) == nil)
        #expect(throws: ExpensePayerContributionError.invalidAllocation) {
            try ExpensePayerContributionPolicy.equalSplit(
                total: Double.greatestFiniteMagnitude,
                humanIDs: [UUID(), UUID()]
            )
        }
        #expect(throws: ExpensePayerContributionError.invalidAllocation) {
            try ExpensePayerContributionPolicy.validated(
                [
                    ExpensePayerContribution(humanID: UUID(), minorUnits: Int64.max),
                    ExpensePayerContribution(humanID: UUID(), minorUnits: 1)
                ],
                total: 1
            )
        }
    }

    @Test func versionedJSONSupportsLegacyArrayAndMalformedDataDoesNotReattribute() throws {
        let payerID = UUID()
        let contributions = [ExpensePayerContribution(humanID: payerID, minorUnits: 2550)]
        let versioned = ExpensePayerContributionPolicy.encode(contributions)
        let legacyData = try JSONEncoder().encode(contributions)
        let legacy = try #require(String(data: legacyData, encoding: .utf8))

        #expect(ExpensePayerContributionPolicy.decode(versioned) == contributions)
        #expect(ExpensePayerContributionPolicy.decode(legacy) == contributions)
        #expect(
            ExpensePayerContributionPolicy.effectiveContributions(
                raw: "",
                executorID: payerID.uuidString,
                total: 25.5
            ) == contributions
        )

        let malformed = "{not-json"
        #expect(ExpensePayerContributionPolicy.decode(malformed) == nil)
        #expect(
            ExpensePayerContributionPolicy.effectiveContributions(
                raw: malformed,
                executorID: payerID.uuidString,
                total: 25.5
            ).isEmpty
        )
        #expect(throws: ExpensePayerContributionError.invalidAllocation) {
            try ExpensePayerContributionPolicy.validatedDecoded(malformed, total: 25.5)
        }
    }

    @Test func anonymizingMalformedSnapshotFailsClosedAsUnknownWholeBill() {
        let deletedPayerID = UUID()
        let malformed = #"{"humanID":"\#(deletedPayerID.uuidString)""#
        let expense = PetExpenseLog(
            amount: 100,
            executorId: deletedPayerID.uuidString,
            payerContributionsJSON: malformed
        )

        let didAnonymize = expense.anonymizePayer(deletedPayerID)
        let expectedUnknown = ExpensePayerContribution(humanID: nil, minorUnits: 10000)

        #expect(didAnonymize)
        #expect(!expense.payerContributionsJSON.lowercased().contains(deletedPayerID.uuidString.lowercased()))
        #expect(expense.executorId == nil)
        #expect(expense.payerContributions == [expectedUnknown])
        #expect(expense.amountPaid(by: deletedPayerID.uuidString) == 0)
        #expect(ExpenseSummaryBuilder.payerShares(for: expense) == [
            ExpensePayerShare(humanID: nil, amount: 100)
        ])
    }

    @Test func legacyReimbursementKeepsNegativePayerAttribution() {
        let payerID = UUID()
        let reimbursement = PetExpenseLog(
            amount: -80,
            category: .insurancePremium,
            note: "ohana_insurance_reimbursement:clinic",
            executorId: payerID.uuidString
        )

        #expect(reimbursement.payerContributions == [
            ExpensePayerContribution(humanID: payerID, minorUnits: -8000)
        ])
        #expect(reimbursement.amountPaid(by: payerID.uuidString) == -80)
        #expect(ExpenseSummaryBuilder.amountPaid(by: payerID, for: reimbursement) == -80)
        #expect(ExpenseSummaryBuilder.paidBy(payerID, from: [reimbursement]).map(\.id) == [reimbursement.id])
    }

    @Test func twoPayersAcrossThreePetsPreserveEveryRowAndColumnTotal() throws {
        let first = UUID()
        let second = UUID()
        let contributions = [
            ExpensePayerContribution(humanID: first, minorUnits: 6000),
            ExpensePayerContribution(humanID: second, minorUnits: 4000)
        ]
        let childAmounts = [33.34, 33.33, 33.33]

        let rows = try ExpensePayerContributionPolicy.distributed(
            contributions,
            across: childAmounts
        )

        #expect(rows.count == 3)
        #expect(rows.map { $0.reduce(Int64(0)) { $0 + $1.minorUnits } } == [3334, 3333, 3333])

        var totalsByPayer: [UUID: Int64] = [:]
        for contribution in rows.joined() {
            let humanID = try #require(contribution.humanID)
            totalsByPayer[humanID, default: 0] += contribution.minorUnits
        }
        #expect(totalsByPayer[first] == 6000)
        #expect(totalsByPayer[second] == 4000)
        #expect(rows.joined().reduce(Int64(0)) { $0 + $1.minorUnits } == 10000)
    }
}
