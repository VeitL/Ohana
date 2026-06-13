import SwiftData

struct RecurringEconomyBoundariesGoodCommand {
    let questManager: QuestManager

    func record(pet: Pet, context: ModelContext, executorId: String) {
        _ = questManager.awardAction(
            type: .feeding,
            pet: pet,
            context: context,
            executorId: executorId
        )
    }
}
