import Foundation
import SwiftUI
import UIKit

struct ArchitectureBoundariesBad {
    let result: HumanMedicationDoseCommandResult?
    let reward: QuestManager.OhanaActionType?
    let concreteEconomyPolicy = CoconutEconomyPolicyV2.self
    let presentationLeak: Color = .goPrimary
    let platformImage: UIImage? = nil

    func run() {
        _ = CareEventServiceDependencies.live()
        _ = ReminderSchedulingManager.self
        _ = PetMedicationCommandExecutor.self
        _ = QuestManager.QualityBonus.none
        _ = OasisTreeManagerRegistry.current
        _ = StaticCareEventEconomyAwarder.self
        _ = "pet_food_stock"
    }
}
