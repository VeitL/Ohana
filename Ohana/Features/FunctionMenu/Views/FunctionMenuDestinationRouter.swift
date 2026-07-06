import SwiftData
import SwiftUI

struct FunctionMenuDestinationRouter: View {
    let destination: FMDest
    @Binding var parentPath: NavigationPath
    let pets: [Pet]
    let humans: [Human]
    var petAggregateSummaries: [UUID: FunctionMenuPetAggregateSummary] = [:]
    var petFeatureCollectionSummary: PetFeatureCollectionSummary = .empty
    let plants: [Plant]
    var plantFeatureCollectionSummary: PlantFeatureCollectionSummary = .empty
    var isRouteDataLoaded = true

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
                .onAppear {
                    GrowthNewFeatureStore.markVisited(destination)
                }
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
                humans: humans,
                plants: plants,
                isRouteDataLoaded: isRouteDataLoaded,
                petAggregateSummaries: petAggregateSummaries
            )
        case .petFeatureCollection:
            PetFeatureCollectionView(
                parentPath: $parentPath,
                pets: pets,
                humans: humans,
                summary: petFeatureCollectionSummary
            )
        case .petSharedCheckIn:
            PetSharedCheckInView(
                parentPath: $parentPath,
                pets: pets
            )
        case .plantFeatureCollection:
            PlantFeatureCollectionView(
                parentPath: $parentPath,
                plants: plants,
                summary: plantFeatureCollectionSummary
            )
        case let .featureAggregate(feature):
            FeatureAggregateView(
                feature: feature,
                parentPath: $parentPath,
                pets: pets,
                humans: humans,
                petAggregateSummaries: petAggregateSummaries,
                showsEntityChips: false
            )
        case let .petHealth(id):
            if let pet = pet(for: id) { PetHealthDetailView(pet: pet, isModal: false) }
        case let .petMedications(id):
            if let pet = pet(for: id) { PetMedicationView(pet: pet) }
        case let .petFood(id):
            if let pet = pet(for: id) { PetFoodManagementView(pet: pet) }
        case let .petWater(id):
            if let pet = pet(for: id) { QuickWaterDetailRouteContainer(id: pet.id, onRemove: {}, onClose: nil) }
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
            if let pet = pet(for: id) { PetMomentsHubRouteContainer(pet: pet) }
        case let .petTimeline(id):
            if let pet = pet(for: id) { PetMomentsHubRouteContainer(pet: pet) }
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
        case let .humanWorkout(id):
            if let human = human(for: id) { HumanWorkoutSummaryView(human: human) }
        case let .humanMedication(id):
            if let human = human(for: id) { HumanMedicationView(human: human) }
        case let .humanNote(id):
            if let human = human(for: id) { HumanNoteHistorySheet(human: human) }
        case let .humanExpense(id):
            if let human = human(for: id) { HumanExpenseDetailView(human: human) }
        case .plantsDashboard:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .sites,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantsBatchCare:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .plants,
                opensBatchCareOnAppear: true,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case let .plantsBatchCareFiltered(careType):
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .plants,
                opensBatchCareOnAppear: true,
                initialBatchCareType: careType,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantsBatchQuickRecord:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .plants,
                opensBatchQuickRecordOnAppear: true,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantsList:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .plants,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case .plantsPhotos:
            PlantDashboardView(
                plants: plants,
                isPlantDataLoaded: isRouteDataLoaded,
                initialMode: .photos,
                onOpenPlant: { plantID in
                    parentPath.append(FMDest.plantDetail(plantID))
                }
            )
        case let .plantDetail(id):
            if let plant = plant(for: id) {
                PlantDetailView(plant: plant)
            }
        case let .plantFeature(id, destination):
            if let careFeatureDestination = destination.careFeatureDestination {
                PlantCareFeatureDetailView(
                    plants: plants,
                    feature: careFeatureDestination,
                    focusedPlantID: id,
                    focusedCareType: nil
                )
            } else if let plant = plant(for: id) {
                PlantDetailView(plant: plant, initialFeatureDestination: destination)
            }
        case let .plantCare(id, feature):
            PlantCareFeatureDetailView(
                plants: plants,
                feature: feature,
                focusedPlantID: id,
                focusedCareType: nil
            )
        case let .plantCareAggregate(feature):
            PlantCareFeatureDetailView(
                plants: plants,
                feature: feature,
                focusedPlantID: nil,
                focusedCareType: nil
            )
        case .wealthDashboard:
            IslandWealthDashboardView()
        case .bountyBoard:
            if OnlineFeatureGate.allows(.onlineCollaboration) {
                BountyBoardView()
            }
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
        }
    }

    private func openCalendarEventDestination(_ destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            if let destination = functionMenuDestination(forPetQuickKey: key, pet: pet) {
                parentPath.append(destination)
            }
        case let .petFeature(feature, pet):
            parentPath.append(functionMenuDestination(for: feature, pet: pet))
        case let .petHealth(pet, _):
            parentPath.append(FMDest.petHealth(pet.persistentModelID))
        case let .humanQuick(key, human):
            if let destination = functionMenuDestination(forHumanQuickKey: key, human: human) {
                parentPath.append(destination)
            }
        case .humanDetail:
            parentPath.append(FMDest.featureGroup(.householdHub))
        case let .plant(plant):
            parentPath.append(FMDest.plantDetail(plant.id))
        case let .plantFeature(plant, destination):
            parentPath.append(FMDest.plantFeature(plant.id, destination))
        case let .plantCare(plant, feature):
            parentPath.append(FMDest.plantCare(plant.id, feature))
        case let .functionMenu(destination):
            parentPath.append(destination)
        case .calendar:
            break
        }
    }

    private func functionMenuDestination(forPetQuickKey key: String, pet: Pet) -> FMDest? {
        switch key {
        case "feed":
            .petFood(pet.persistentModelID)
        case "water":
            .petWater(pet.persistentModelID)
        case "waterChange", "filterClean", "groom", "cageCleaning",
             "freeFlight", "misting", "substrateChange":
            .petHygiene(pet.persistentModelID)
        case "potty", "litter":
            .petPotty(pet.persistentModelID)
        case "walk":
            .petWalks(pet.persistentModelID)
        case "health":
            .petHealth(pet.persistentModelID)
        case "medication":
            .petMedications(pet.persistentModelID)
        case "weight":
            .petWeight(pet.persistentModelID)
        case "expense":
            .petExpense(pet.persistentModelID)
        case "play":
            .featureGroup(.dailyCare)
        default:
            nil
        }
    }

    private func functionMenuDestination(for feature: PetFeature, pet: Pet) -> FMDest {
        switch feature {
        case .health:
            .petHealth(pet.persistentModelID)
        case .medications:
            .petMedications(pet.persistentModelID)
        case .food:
            .petFood(pet.persistentModelID)
        case .hygiene:
            .petHygiene(pet.persistentModelID)
        case .walks:
            .petWalks(pet.persistentModelID)
        case .potty:
            .petPotty(pet.persistentModelID)
        case .basicInfo:
            .petBasicInfo(pet.persistentModelID)
        case .documents:
            .petDocuments(pet.persistentModelID)
        case .moments:
            .petMoments(pet.persistentModelID)
        case .achievements:
            .petAchievements(pet.persistentModelID)
        case .retention:
            .petRetention(pet.persistentModelID)
        case .weight:
            .petWeight(pet.persistentModelID)
        case .expense:
            .petExpense(pet.persistentModelID)
        }
    }

    private func functionMenuDestination(forHumanQuickKey key: String, human: Human) -> FMDest? {
        switch key {
        case "humanWeight":
            .humanWeight(human.persistentModelID)
        case "humanWorkout":
            .humanWorkout(human.persistentModelID)
        case "humanMedication":
            .humanMedication(human.persistentModelID)
        case "humanNote":
            .humanNote(human.persistentModelID)
        case "humanExpense":
            .humanExpense(human.persistentModelID)
        default:
            nil
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
