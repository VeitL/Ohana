import SwiftUI
import SwiftData

struct FunctionMenuDestinationRouter: View {
    let destination: FMDest
    @Binding var parentPath: NavigationPath
    @Binding var selectedPlant: Plant?

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]

    var body: some View {
        destinationView(destination)
    }

    @ViewBuilder
    private func destinationView(_ dest: FMDest) -> some View {
        switch dest {
        case .featureGroup(let group):
            FeatureGroupDashboardView(group: group, parentPath: $parentPath)
        case .featureAggregate(let feature):
            FeatureAggregateView(feature: feature, parentPath: $parentPath, showsEntityChips: false)
        case .petHealth(let id):
            if let pet = pet(for: id) { PetHealthDetailView(pet: pet, isModal: false) }
        case .petMedications(let id):
            if let pet = pet(for: id) { PetMedicationView(pet: pet) }
        case .petFood(let id):
            if let pet = pet(for: id) { PetFoodManagementView(pet: pet) }
        case .petHygiene(let id):
            if let pet = pet(for: id) { PetHygieneDetailView(pet: pet) }
        case .petWalks(let id):
            if let pet = pet(for: id) { WalkSummarySheet(pet: pet) }
        case .petPotty(let id):
            if let pet = pet(for: id) { QuickPottyDetailSheet(pet: pet) {} }
        case .petBasicInfo(let id):
            if let pet = pet(for: id) { PetBasicInfoDetailView(pet: pet) }
        case .petDocuments(let id):
            if let pet = pet(for: id) { DocumentsListView(pet: pet) }
        case .petInsurance(let id):
            if let pet = pet(for: id) { PetInsuranceView(pet: pet) }
        case .petMoments(let id):
            if let pet = pet(for: id) { PetMomentsHubView(pet: pet) }
        case .petTimeline(let id):
            if let pet = pet(for: id) { PetMomentsHubView(pet: pet) }
        case .petAchievements(let id):
            if let pet = pet(for: id) { AchievementWallView(pet: pet) }
        case .petRetention(let id):
            if let pet = pet(for: id) { PetRetentionHubView(pet: pet) }
        case .petWeight(let id):
            if let pet = pet(for: id) { WeightHistoryView(pet: pet) }
        case .petExpense(let id):
            if let pet = pet(for: id) { ExpenseHistoryView(pet: pet) }
        case .humanWeight(let id):
            if let human = human(for: id) { HumanWeightHistoryView(human: human) }
        case .humanExpense(let id):
            if let human = human(for: id) { HumanExpenseDetailView(human: human) }
        case .plantsDashboard:
            PlantDashboardView(selectedPlant: $selectedPlant)
        case .wealthDashboard:
            IslandWealthDashboardView()
        case .bountyBoard:
            BountyBoardView()
        case .familyWeeklyReport:
            FamilyWeeklyReportDashboardView()
        case .careLedgerAnalysis:
            CareLedgerAnalysisView()
        case .reminderObservability:
            ReminderObservabilityView()
        case .coconutShop:
            CoconutShopView()
        case .gacha:
            GachaView()
        case .calendar:
            CalendarView()
        }
    }

    private func pet(for id: PersistentIdentifier) -> Pet? {
        pets.first { $0.persistentModelID == id }
    }

    private func human(for id: PersistentIdentifier) -> Human? {
        humans.first { $0.persistentModelID == id }
    }
}
