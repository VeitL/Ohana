import Foundation
import SwiftUI

struct ArchitectureBoundariesBad {
    let result: HumanMedicationDoseCommandResult?
    let reward: QuestManager.OhanaActionType?
    let concreteEconomyPolicy = CoconutEconomyPolicyV2.self
    let presentationLeak: Color = .goPrimary

    func run() {
        _ = PetMedicationCommandExecutor.self
        _ = QuestManager.QualityBonus.none
        _ = OasisTreeManagerRegistry.current
        _ = StaticCareEventEconomyAwarder.self
        _ = "pet_food_stock"
    }
}
