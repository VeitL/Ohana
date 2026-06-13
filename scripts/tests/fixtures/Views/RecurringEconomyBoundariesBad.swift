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
            if CoconutExchangeFeatureGate.isEnabled {
                print("UI-only exchange gate")
            }
        }
    }
}
