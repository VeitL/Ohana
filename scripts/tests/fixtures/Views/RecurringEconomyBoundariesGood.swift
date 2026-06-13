import SwiftData

struct RecurringEconomyBoundariesGoodCommand {
    let questManager: QuestManager

    func record(pet: Pet, context: ModelContext, executorId: String) {
        _ = EconomyRewardDiscipline.awardCareAction(
            type: .feeding,
            pet: pet,
            context: context,
            executorId: executorId,
            questManager: questManager
        )
    }
}
