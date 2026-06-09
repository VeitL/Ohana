import SwiftData
import SwiftUI

struct FunctionMenuDestinationRouter: View {
    let destination: FMDest
    @Binding var parentPath: NavigationPath
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var treeManager = OasisTreeManager.shared

    var body: some View {
        let decision = AppFeatureRouteGuard.functionDestinationDecision(
            destination,
            currentLevel: treeManager.treeLevel.rawValue
        )
        switch decision {
        case .rootMenu:
            EmptyView()
        case .allow:
            destinationView(destination)
        case let .redirectToRoadmap(note):
            GrowthUnlockRoadmapView(
                currentLevel: treeManager.treeLevel.rawValue,
                progressToNextLevel: treeManager.progressToNextLevel,
                appLanguage: appLanguage
            )
            .onAppear {
                AppFeatureRouteGuard.recordIntercept(note)
            }
        case let .suppress(note):
            Color.clear
                .onAppear {
                    AppFeatureRouteGuard.recordIntercept(note)
                }
        }
    }

    @ViewBuilder
    private func destinationView(_ dest: FMDest) -> some View {
        switch dest {
        case .growthRoadmap:
            GrowthUnlockRoadmapView(
                currentLevel: treeManager.treeLevel.rawValue,
                progressToNextLevel: treeManager.progressToNextLevel,
                appLanguage: appLanguage
            )
        case .featureGroup(let group):
            FeatureGroupDashboardView(
                group: group,
                parentPath: $parentPath,
                pets: pets,
                humans: humans
            )
        case .featureAggregate(let feature):
            FeatureAggregateView(
                feature: feature,
                parentPath: $parentPath,
                pets: pets,
                humans: humans,
                showsEntityChips: false
            )
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
            if let pet = pet(for: id) { QuickPottyDetailRouteContainer(id: pet.id, onRemove: {}) }
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
            PlantDashboardView(
                plants: plants,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantDetail(let id):
            if let plant = plant(for: id) {
                PlantDetailView(plant: plant)
            }
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
            CoconutShopRouteContainer()
        case .gacha:
            GachaRouteContainer()
        case .calendar:
            CalendarRouteContainer()
        }
    }

    private func pet(for id: PersistentIdentifier) -> Pet? {
        pets.first { $0.persistentModelID == id }
    }

    private func human(for id: PersistentIdentifier) -> Human? {
        humans.first { $0.persistentModelID == id }
    }

    private func plant(for id: UUID) -> Plant? {
        plants.first { $0.id == id }
    }
}
