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
