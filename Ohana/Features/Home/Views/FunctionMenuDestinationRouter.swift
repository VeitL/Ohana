import SwiftData
import SwiftUI

struct FunctionMenuDestinationRouter: View {
    let destination: FMDest
    @Binding var parentPath: NavigationPath
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]

    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    var body: some View {
        let decision = AppFeatureRouteGuard.functionDestinationDecision(
            destination,
            currentLevel: appServices.oasisTree.treeLevel.rawValue
        )
        switch decision {
        case .rootMenu:
            EmptyView()
        case .allow:
            destinationView(destination)
        case let .redirectToRoadmap(note):
            GrowthUnlockRoadmapView(
                currentLevel: appServices.oasisTree.treeLevel.rawValue,
                progressToNextLevel: appServices.oasisTree.progressToNextLevel,
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
                currentLevel: appServices.oasisTree.treeLevel.rawValue,
                progressToNextLevel: appServices.oasisTree.progressToNextLevel,
                appLanguage: appLanguage
            )
        case let .featureGroup(group):
            FeatureGroupDashboardView(
                group: group,
                parentPath: $parentPath,
                pets: pets,
                humans: humans
            )
        case let .featureAggregate(feature):
            FeatureAggregateView(
                feature: feature,
                parentPath: $parentPath,
                pets: pets,
                humans: humans,
                showsEntityChips: false
            )
        case let .petHealth(id):
            if let pet = pet(for: id) { PetHealthDetailView(pet: pet, isModal: false) }
        case let .petMedications(id):
            if let pet = pet(for: id) { PetMedicationView(pet: pet) }
        case let .petFood(id):
            if let pet = pet(for: id) { PetFoodManagementView(pet: pet) }
        case let .petHygiene(id):
            if let pet = pet(for: id) { PetHygieneDetailView(pet: pet) }
        case let .petWalks(id):
            if let pet = pet(for: id) { WalkSummarySheet(pet: pet) }
        case let .petPotty(id):
            if let pet = pet(for: id) { QuickPottyDetailRouteContainer(id: pet.id, onRemove: {}) }
        case let .petBasicInfo(id):
            if let pet = pet(for: id) { PetBasicInfoDetailView(pet: pet) }
        case let .petDocuments(id):
            if let pet = pet(for: id) { DocumentsListView(pet: pet) }
        case let .petInsurance(id):
            if let pet = pet(for: id) { PetInsuranceView(pet: pet) }
        case let .petMoments(id):
            if let pet = pet(for: id) { PetMomentsHubView(pet: pet) }
        case let .petTimeline(id):
            if let pet = pet(for: id) { PetMomentsHubView(pet: pet) }
        case let .petAchievements(id):
            if let pet = pet(for: id) { AchievementWallView(pet: pet) }
        case let .petRetention(id):
            if let pet = pet(for: id) { PetRetentionHubView(pet: pet) }
        case let .petWeight(id):
            if let pet = pet(for: id) { WeightHistoryView(pet: pet) }
        case let .petExpense(id):
            if let pet = pet(for: id) { ExpenseHistoryView(pet: pet) }
        case let .humanWeight(id):
            if let human = human(for: id) { HumanWeightHistoryView(human: human) }
        case let .humanExpense(id):
            if let human = human(for: id) { HumanExpenseDetailView(human: human) }
        case .plantsDashboard:
            PlantDashboardView(
                plants: plants,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case let .plantDetail(id):
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
