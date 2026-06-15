import Foundation
import SwiftData

struct RecurringEconomyBoundariesGoodCommand {
    let careEvents: CareEventRecording
    let careLedger: CareLedgerRecording

    func record(pet: Pet, context: ModelContext, executorId: String) {
        _ = careEvents.recordCare(
            pet: pet,
            type: .feeding,
            amountMl: 0,
            context: context,
            executorId: executorId,
            reward: .feeding,
            quality: .none,
            date: Date()
        )
    }

    func recordExpense(pet: Pet, context: ModelContext, executorId: String) {
        ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: 42,
            date: Date(),
            category: .medical,
            note: "good.expense",
            context: context,
            executorId: executorId
        )
    }

    func recordExpenseThroughLedgerHelper(pet: Pet, context: ModelContext, executorId: String) {
        let expense = PetExpenseLog(
            date: Date(),
            amount: 42,
            category: .medical,
            note: "good.expense.helper",
            pet: pet,
            executorId: executorId
        )
        context.insert(expense)
        recordExpenseLedger(expense: expense, pet: pet, executorId: executorId, context: context)
    }

    private func recordExpenseLedger(
        expense: PetExpenseLog,
        pet: Pet,
        executorId: String,
        context: ModelContext
    ) {
        careLedger.record(
            occurredAt: expense.date,
            actorKind: .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.medical.rawValue,
            amountValue: expense.amount,
            amountUnit: "currency",
            note: expense.note,
            source: .detail,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "PetExpenseLog",
            legacyModelId: expense.id.uuidString,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "",
            context: context,
            save: true
        )
    }
}
