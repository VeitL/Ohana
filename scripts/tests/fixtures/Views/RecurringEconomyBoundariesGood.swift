import Foundation
import SwiftData

struct RecurringEconomyBoundariesGoodCommand {
    let careEvents: CareEventRecording

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
}
