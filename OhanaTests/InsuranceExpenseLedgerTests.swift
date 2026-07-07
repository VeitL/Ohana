import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct InsuranceExpenseLedgerTests {
    @Test func savePolicyAutoPaymentsWriteExpenseLedgerEventsWithoutRewards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let human = Human(name: "Executor")
        context.insert(pet)
        context.insert(human)
        try context.save()

        let result = try InsurancePolicyCommandService.savePolicy(
            existing: nil,
            pet: pet,
            input: InsurancePolicySaveCommandInput(
                companyName: "Ohana Care",
                policyNumber: "P-1",
                productName: "Care Plus",
                annualPremium: 120,
                coverageAmount: 1000,
                startDate: makeDate(year: 2026, month: 1, day: 1),
                renewalDate: makeDate(year: 2026, month: 12, day: 31),
                notes: "",
                paymentFrequency: .quarterly,
                paymentDayOfMonth: 1,
                showInCalendar: false,
                otherFeeAmount: 5,
                otherFeeNote: "Service fee",
                autoGeneratesPayments: true,
                executorId: human.id.uuidString
            ),
            context: context
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>()).sorted { $0.date < $1.date }
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let coconutEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(result.expenseLogIDs == expenses.map(\.id))
        #expect(expenses.count == 4)
        #expect(ledgerEvents.count == expenses.count)
        #expect(Set(ledgerEvents.compactMap(\.legacyModelId)) == Set(expenses.map(\.id.uuidString)))
        #expect(coconutEntries.isEmpty)
        #expect(pet.coconutBalance == 0)
        #expect(human.coconutBalance == 0)

        for expense in expenses {
            let ledger = try #require(ledgerEvents.first { $0.legacyModelId == expense.id.uuidString })
            #expect(ledger.legacyModelName == "PetExpenseLog")
            #expect(ledger.eventKind == CareLedgerEventKind.expense.rawValue)
            #expect(ledger.actionType == ExpenseCategory.insurancePremium.rawValue)
            #expect(ledger.amountValue == 35)
            #expect(ledger.amountUnit == "currency")
            #expect(ledger.subjectKind == CareLedgerSubjectKind.pet.rawValue)
            #expect(ledger.subjectId == pet.id.uuidString)
            #expect(ledger.actorKind == CareLedgerActorKind.human.rawValue)
            #expect(ledger.actorId == human.id.uuidString)
            #expect(ledger.coconutDelta == 0)
        }
    }

    @Test func createApprovedClaimWritesReimbursementExpenseLedgerEventWithoutRewards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let human = Human(name: "Executor")
        let insurance = PetInsurance(companyName: "Ohana Care", productName: "Care Plus", pet: pet)
        context.insert(pet)
        context.insert(human)
        context.insert(insurance)
        try context.save()

        let result = try InsurancePolicyCommandService.createClaim(
            insurance: insurance,
            pet: pet,
            input: InsuranceClaimCommandInput(
                claimDate: makeDate(year: 2026, month: 6, day: 8),
                incidentDate: makeDate(year: 2026, month: 6, day: 7),
                totalExpense: 200,
                claimedAmount: 80,
                status: .approved,
                note: "clinic",
                executorId: human.id.uuidString,
                approvedAt: makeDate(year: 2026, month: 6, day: 9)
            ),
            context: context
        )

        let expense = try #require(try context.fetch(FetchDescriptor<PetExpenseLog>()).first)
        let ledger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first)
        let coconutEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(result.expenseLogID == expense.id)
        #expect(expense.amount == -80)
        #expect(ledger.legacyModelName == "PetExpenseLog")
        #expect(ledger.legacyModelId == expense.id.uuidString)
        #expect(ledger.eventKind == CareLedgerEventKind.expense.rawValue)
        #expect(ledger.actionType == ExpenseCategory.insurancePremium.rawValue)
        #expect(ledger.amountValue == -80)
        #expect(ledger.actorId == human.id.uuidString)
        #expect(ledger.subjectId == pet.id.uuidString)
        #expect(ledger.coconutDelta == 0)
        #expect(coconutEntries.isEmpty)
        #expect(pet.coconutBalance == 0)
        #expect(human.coconutBalance == 0)
    }

    @Test func updateClaimStatusApprovedWritesReimbursementExpenseLedgerEventOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let human = Human(name: "Executor")
        let insurance = PetInsurance(companyName: "Ohana Care", productName: "", pet: pet)
        let claim = InsuranceClaim(
            incidentDate: makeDate(year: 2026, month: 6, day: 7),
            totalExpense: 200,
            claimedAmount: 80,
            status: .submitted,
            insurance: insurance
        )
        context.insert(pet)
        context.insert(human)
        context.insert(insurance)
        context.insert(claim)
        try context.save()

        let approvedAt = makeDate(year: 2026, month: 6, day: 9)
        let first = try InsurancePolicyCommandService.updateClaimStatus(
            claim,
            to: .approved,
            insurance: insurance,
            pet: pet,
            context: context,
            approvedAt: approvedAt,
            executorId: human.id.uuidString
        )
        let second = try InsurancePolicyCommandService.updateClaimStatus(
            claim,
            to: .approved,
            insurance: insurance,
            pet: pet,
            context: context,
            approvedAt: approvedAt,
            executorId: human.id.uuidString
        )

        let expenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        let ledgerEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let coconutEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let expense = try #require(expenses.first)
        let ledger = try #require(ledgerEvents.first)
        #expect(expenses.count == 1)
        #expect(ledgerEvents.count == 1)
        #expect(first.expenseLogID == expense.id)
        #expect(second.expenseLogID == nil)
        #expect(expense.amount == -80)
        #expect(ledger.legacyModelId == expense.id.uuidString)
        #expect(ledger.amountValue == -80)
        #expect(ledger.coconutDelta == 0)
        #expect(coconutEntries.isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}
