import SwiftData
import SwiftUI

struct RecurringEconomyBoundariesBadView: View {
    let pet: Pet
    let questManager: QuestManager
    let context: ModelContext

    var body: some View {
        Button("Bad") {
            pet.coconutBalance += 1
            _ = questManager.awardAction(type: .feeding, pet: pet, context: context)
            _ = EconomyRewardDiscipline.awardCareAction(
                type: .feeding,
                pet: pet,
                context: context,
                questManager: questManager
            )
            if CoconutExchangeFeatureGate.isEnabled {
                print("UI-only exchange gate")
            }
        }
    }
}

struct RecurringEconomyUnconsumedFactCommand {
    let careEvents: CareEventRecording
    let context: ModelContext

    func record(pet: Pet, executorId: String) {
        let recorded = careEvents.recordCareFact(
            pet: pet,
            type: .feeding,
            amountMl: 0,
            context: context,
            executorId: executorId,
            reward: .feeding,
            quality: .none,
            date: Date(),
            source: .quickAction,
            createsLinkedPottyLog: false
        )
        print(recorded.result.logID)
    }
}
