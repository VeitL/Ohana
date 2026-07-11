import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ExpenseAmountPolicyTests {
    @Test func userExpensePolicyRejectsZeroNegativeAndNonFiniteValues() {
        let invalidAmounts: [Double] = [0, -1, .nan, .infinity, -Double.infinity]
        for amount in invalidAmounts {
            #expect(!ExpenseAmountPolicy.isValidUserExpense(amount))
        }
        #expect(ExpenseAmountPolicy.isValidUserExpense(0.01))

        #expect(
            ExpenseAmountPolicy.isValidPersistedExpense(
                amount: -80,
                categoryRaw: ExpenseCategory.insurancePremium.rawValue,
                note: "\(ExpenseAmountPolicy.insuranceReimbursementNotePrefix)clinic"
            )
        )
        #expect(
            !ExpenseAmountPolicy.isValidPersistedExpense(
                amount: -80,
                categoryRaw: ExpenseCategory.medical.rawValue,
                note: "clinic"
            )
        )
    }

    @Test func repeatedInvalidCommandsDoNotWriteAndValidRetryRecovers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        let secondPet = Pet(name: "Nana", species: "狗")
        let human = Human(name: "Executor")
        context.insert(pet)
        context.insert(secondPet)
        context.insert(human)
        try context.save()

        for _ in 0 ..< 2 {
            expectInvalidUserExpense {
                _ = try ExpenseCommandService.recordPetExpense(
                    pet: pet,
                    amount: 0,
                    date: Date(),
                    category: .medical,
                    note: "invalid",
                    context: context,
                    awardsReward: false
                )
            }
            expectInvalidUserExpense {
                _ = try ExpenseCommandService.recordSharedPetExpense(
                    sourcePet: pet,
                    targets: [pet, secondPet],
                    amount: -Double.infinity,
                    date: Date(),
                    category: .other,
                    note: "invalid",
                    context: context
                )
            }
            expectInvalidUserExpense {
                _ = try ExpenseCommandService.recordHumanExpense(
                    human: human,
                    amount: -1,
                    date: Date(),
                    note: "invalid",
                    context: context
                )
            }
        }

        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SharedCareSession>()).isEmpty)

        _ = try ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 12.5,
            date: Date(),
            category: .medical,
            note: "valid retry",
            context: context,
            awardsReward: false
        )
        let recoveredExpenses = try context.fetch(FetchDescriptor<PetExpenseLog>())
        #expect(recoveredExpenses.count == 1)
        #expect(recoveredExpenses.first?.amount == 12.5)

        expectInvalidUserExpense {
            _ = try ExpenseCommandService.recordPetExpense(
                pet: pet,
                amount: .nan,
                date: Date(),
                category: .medical,
                note: "invalid after recovery",
                context: context,
                awardsReward: false
            )
        }
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).count == 1)
    }

    @Test func rehydrateRejectsInvalidAmountsAndRemainsIdempotentForValidFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "狗")
        context.insert(pet)
        try context.save()

        let invalid = makeSnapshot(
            amount: -30,
            category: .medical,
            note: "ordinary negative",
            petID: pet.id
        )
        for _ in 0 ..< 2 {
            do {
                _ = try DomainCareFactRehydrateWriter.insertPetExpenseLogIfNeeded(
                    snapshot: invalid,
                    source: .backupRestore,
                    context: context
                )
                Issue.record("Expected invalid persisted expense rejection")
            } catch let error as ExpenseAmountValidationError {
                #expect(error == .invalidPersistedExpense)
            }
        }
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).isEmpty)

        let valid = makeSnapshot(
            amount: 30,
            category: .medical,
            note: "valid",
            petID: pet.id
        )
        let first = try DomainCareFactRehydrateWriter.insertPetExpenseLogIfNeeded(
            snapshot: valid,
            source: .backupRestore,
            context: context
        )
        try context.save()
        let repeated = try DomainCareFactRehydrateWriter.insertPetExpenseLogIfNeeded(
            snapshot: valid,
            source: .backupRestore,
            context: context
        )
        #expect(first.inserted)
        #expect(!repeated.inserted)

        let reimbursement = makeSnapshot(
            amount: -80,
            category: .insurancePremium,
            note: "\(ExpenseAmountPolicy.insuranceReimbursementNotePrefix)clinic",
            petID: pet.id
        )
        let reimbursementFirst = try DomainCareFactRehydrateWriter.insertPetExpenseLogIfNeeded(
            snapshot: reimbursement,
            source: .cloudApply,
            context: context
        )
        try context.save()
        let reimbursementRepeated = try DomainCareFactRehydrateWriter.insertPetExpenseLogIfNeeded(
            snapshot: reimbursement,
            source: .cloudApply,
            context: context
        )
        #expect(reimbursementFirst.inserted)
        #expect(!reimbursementRepeated.inserted)
        #expect(try context.fetch(FetchDescriptor<PetExpenseLog>()).count == 2)
    }

    private func expectInvalidUserExpense(_ operation: () throws -> Void) {
        do {
            try operation()
            Issue.record("Expected invalid user expense rejection")
        } catch let error as ExpenseAmountValidationError {
            #expect(error == .invalidUserExpense)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeSnapshot(
        amount: Double,
        category: ExpenseCategory,
        note: String,
        petID: UUID
    ) -> DomainPetExpenseLogRehydrateSnapshot {
        DomainPetExpenseLogRehydrateSnapshot(
            id: UUID(),
            date: Date(),
            amount: amount,
            categoryRaw: category.rawValue,
            note: note,
            petId: petID,
            executorId: nil,
            sharedSessionId: ""
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: ArkMigrationPlan.self,
            configurations: [config]
        )
    }
}
