import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ExpenseEditingTests {
    @Test func updateSynchronizesExpenseLedgerReceiptAndPayerSplit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let firstPayer = Human(name: "Alex")
        let secondPayer = Human(name: "Sam")
        let originalDate = Date(timeIntervalSince1970: 1_800_000_000)
        let updatedDate = Date(timeIntervalSince1970: 1_800_086_400)
        let log = PetExpenseLog(
            date: originalDate,
            amount: 10,
            category: .food,
            note: "Old",
            pet: pet,
            executorId: firstPayer.id.uuidString
        )
        let ledger = CareLedgerEvent(
            occurredAt: originalDate,
            actorKind: .human,
            actorId: firstPayer.id.uuidString,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.food.rawValue,
            amountValue: 10,
            amountUnit: "currency",
            note: "Old",
            source: .detail,
            legacyModelName: "PetExpenseLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: 3
        )
        let receipt = PetDocument(title: "Receipt", category: .other, pet: pet)
        receipt.issueDate = originalDate
        receipt.cost = 10
        receipt.notes = ExpenseReceiptMetadata.notes(
            visibleNote: "Old",
            expenseLogId: log.id.uuidString
        )
        context.insert(pet)
        context.insert(firstPayer)
        context.insert(secondPayer)
        context.insert(log)
        context.insert(ledger)
        context.insert(receipt)
        try context.save()

        let contributions = [
            try ExpensePayerContributionPolicy.contribution(humanID: firstPayer.id, amount: 6),
            try ExpensePayerContributionPolicy.contribution(humanID: secondPayer.id, amount: 8)
        ]
        let result = try ExpenseCommandService.updatePetExpense(
            log,
            pet: pet,
            input: PetExpenseUpdateInput(
                amount: 14,
                date: updatedDate,
                category: .toys,
                note: "Ball",
                payerID: firstPayer.id,
                payerContributions: contributions
            ),
            context: context
        )

        #expect(result.didChange)
        #expect(result.ledgerEventIDs == [ledger.id])
        #expect(result.documentIDs == [receipt.id])
        #expect(log.amount == 14)
        #expect(log.date == updatedDate)
        #expect(log.expenseCategory == .toys)
        #expect(log.note == "Ball")
        #expect(log.executorId == firstPayer.id.uuidString)
        #expect(log.payerContributions == contributions)
        #expect(ledger.occurredAt == updatedDate)
        #expect(ledger.actorId == firstPayer.id.uuidString)
        #expect(ledger.actionType == ExpenseCategory.toys.rawValue)
        #expect(ledger.amountValue == 14)
        #expect(ledger.note == "Ball")
        #expect(ledger.coconutDelta == 3)
        #expect(receipt.issueDate == updatedDate)
        #expect(receipt.cost == 14)
        #expect(ExpenseReceiptMetadata.visibleNotes(from: receipt.notes) == "Ball")
        #expect(ExpenseReceiptMetadata.expenseLogId(from: receipt.notes) == log.id.uuidString)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).count == 1)
    }

    @Test func noteEditPreservesAnonymousHistoricalPayerShares() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let survivingPayer = Human(name: "Alex")
        let contributions = [
            ExpensePayerContribution(humanID: survivingPayer.id, minorUnits: 600),
            ExpensePayerContribution(humanID: nil, minorUnits: 400)
        ]
        let originalSnapshot = ExpensePayerContributionPolicy.encode(contributions)
        let log = PetExpenseLog(
            amount: 10,
            category: .food,
            note: "Old",
            pet: pet,
            executorId: survivingPayer.id.uuidString,
            payerContributionsJSON: originalSnapshot
        )
        context.insert(pet)
        context.insert(survivingPayer)
        context.insert(log)
        try context.save()

        let result = try ExpenseCommandService.updatePetExpense(
            log,
            pet: pet,
            input: PetExpenseUpdateInput(
                amount: 10,
                date: log.date,
                category: .food,
                note: "New",
                payerID: nil,
                payerContributions: nil
            ),
            context: context
        )

        #expect(result.didChange)
        #expect(log.note == "New")
        #expect(log.payerContributionsJSON == originalSnapshot)
        #expect(log.payerContributions == contributions)
        #expect(log.amountPaid(by: survivingPayer.id.uuidString) == 6)

        do {
            _ = try ExpenseCommandService.updatePetExpense(
                log,
                pet: pet,
                input: PetExpenseUpdateInput(
                    amount: 12,
                    date: log.date,
                    category: .food,
                    note: "Changed total",
                    payerID: nil,
                    payerContributions: nil
                ),
                context: context
            )
            Issue.record("Expected a new payer allocation for a changed total")
        } catch let error as PetExpenseUpdateError {
            #expect(error == .payerAllocationRequired)
        }
        #expect(log.amount == 10)
        #expect(log.payerContributionsJSON == originalSnapshot)
    }

    @Test func reimbursementAmountCannotDivergeFromApprovedClaim() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let insurance = PetInsurance(companyName: "Care", pet: pet)
        let claim = InsuranceClaim(approvedAmount: 100, status: .approved, insurance: insurance)
        let log = PetExpenseLog(
            amount: -100,
            category: .insurancePremium,
            note: "\(ExpenseAmountPolicy.insuranceReimbursementNotePrefix)Care",
            pet: pet
        )
        context.insert(pet)
        context.insert(insurance)
        context.insert(claim)
        context.insert(log)
        try context.save()

        do {
            _ = try ExpenseCommandService.updatePetExpense(
                log,
                pet: pet,
                input: PetExpenseUpdateInput(
                    amount: -80,
                    date: log.date,
                    category: .insurancePremium,
                    note: log.note,
                    payerID: nil,
                    payerContributions: nil
                ),
                context: context
            )
            Issue.record("Expected reimbursement amount edit to be rejected")
        } catch let error as PetExpenseUpdateError {
            #expect(error == .reimbursementAmountLocked)
        }
        #expect(log.amount == -100)
        #expect(insurance.totalApprovedReimbursement == 100)
        #expect(!context.hasChanges)
    }

    @Test func legacyPayerIsNotReassignedDuringNoteEdit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "cat")
        let historicalPayer = Human(name: "Alex")
        historicalPayer.passedAwayDate = Date(timeIntervalSince1970: 1_700_000_000)
        let log = PetExpenseLog(
            amount: 25,
            category: .food,
            note: "Old",
            pet: pet,
            executorId: historicalPayer.id.uuidString
        )
        context.insert(pet)
        context.insert(historicalPayer)
        context.insert(log)
        try context.save()

        _ = try ExpenseCommandService.updatePetExpense(
            log,
            pet: pet,
            input: PetExpenseUpdateInput(
                amount: 25,
                date: log.date,
                category: .food,
                note: "Updated note",
                payerID: nil,
                payerContributions: nil
            ),
            context: context
        )

        #expect(log.executorId == historicalPayer.id.uuidString)
        #expect(log.note == "Updated note")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV99.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
