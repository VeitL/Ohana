import SwiftData
import SwiftUI

struct FunctionMenuDestinationRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = FunctionMenuRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let destination: FMDest
    @Binding var parentPath: NavigationPath

    var body: some View {
        FunctionMenuDestinationRouter(
            destination: destination,
            parentPath: $parentPath,
            pets: routeData.pets,
            humans: routeData.humans,
            petAggregateSummaries: routeData.petAggregateSummaries,
            petFeatureCollectionSummary: routeData.petFeatureCollectionSummary,
            plants: routeData.plants,
            plantFeatureCollectionSummary: routeData.plantFeatureCollectionSummary,
            isRouteDataLoaded: routeData.hasLoaded
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = FunctionMenuRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

struct FunctionMenuRootRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = FunctionMenuRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let appLanguage: String
    let onSelect: (FMDest) -> Void
    let onClose: () -> Void

    var body: some View {
        FunctionMenuRootView(
            appLanguage: appLanguage,
            onSelect: onSelect,
            onClose: onClose,
            pets: routeData.pets,
            humans: routeData.humans
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = FunctionMenuRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct FunctionMenuRouteData {
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var petAggregateSummaries: [UUID: FunctionMenuPetAggregateSummary] = [:]
    var petFeatureCollectionSummary: PetFeatureCollectionSummary = .empty
    var plantFeatureCollectionSummary: PlantFeatureCollectionSummary = .empty
    var hasLoaded = false

    static func load(from context: ModelContext) -> FunctionMenuRouteData {
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
            context: context,
            name: "Pet"
        )
        let humans = fetch(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.name)]),
            context: context,
            name: "Human"
        )
        let plants = PlantFeatureGate.allows(.plants)
            ? fetch(
                FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Plant"
            )
            : []
        if !plants.isEmpty {
            PlantUnlockPolicy.noteExistingPlantData()
        }
        let petAggregateSummaries = FunctionMenuPetAggregateSummary.load(pets: pets, context: context)
        return FunctionMenuRouteData(
            pets: pets,
            humans: humans,
            plants: plants,
            petAggregateSummaries: petAggregateSummaries,
            petFeatureCollectionSummary: PetFeatureCollectionSummary.load(
                pets: pets,
                humans: humans,
                petAggregateSummaries: petAggregateSummaries
            ),
            plantFeatureCollectionSummary: PlantFeatureCollectionSummary.load(plants: plants),
            hasLoaded: true
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Function menu route data fetch failed for \(name): \(error.localizedDescription)",
                category: "FunctionMenu"
            )
            return []
        }
    }
}

struct PlantFeatureCollectionSummary: Equatable {
    var plantCount: Int = 0
    var dueTaskCount: Int = 0
    var duePlantCount: Int = 0
    var wateringDueCount: Int = 0
    var fertilizingDueCount: Int = 0
    var maintenanceDueCount: Int = 0
    var healthDueCount: Int = 0
    var growthLogCount: Int = 0
    var recentLogCount: Int = 0
    var photoCount: Int = 0
    var roomCount: Int = 0
    var healthSignalCount: Int = 0
    var reminderEnabledCount: Int = 0
    var calendarPlanEnabledCount: Int = 0
    var systemReminderEnabledCount: Int = 0
    var latestLogDate: Date?

    static let empty = PlantFeatureCollectionSummary()

    @MainActor
    static func load(plants: [Plant]) -> PlantFeatureCollectionSummary {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let recentWindowStart = calendar.date(byAdding: .day, value: -30, to: todayStart) ?? todayStart
        let tasks = PlantCarePlanService.tasks(for: plants, days: 7, now: now, calendar: calendar)
        let dueTasks = tasks.filter { $0.daysUntilDue <= 0 }

        var recentLogCount = 0
        var growthLogCount = 0
        var photoCount = 0
        var roomNames = Set<String>()
        var healthSignalCount = 0
        var latestLogDate: Date?
        var calendarPlanEnabledCount = 0
        var systemReminderEnabledCount = 0

        for plant in plants {
            let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !room.isEmpty {
                roomNames.insert(room)
            }
            if plant.hasAvatarImageAttachment {
                photoCount += 1
            }
            if plant.healthStatus == .watching || plant.healthStatus == .stressed {
                healthSignalCount += 1
            }
            if plant.isNearClimateSource {
                healthSignalCount += 1
            }
            if !plant.potHasDrainage {
                healthSignalCount += 1
            }
            let enabledPlanTypes = PlantReminderPreferenceStore.controllableCareTypes.filter {
                PlantReminderPreferenceStore.isPlanCalendarEnabled(
                    forPlantID: plant.id,
                    careType: $0,
                    fallback: PlantReminderPreferenceStore.planCalendarFallback(
                        for: $0,
                        plantRemindersEnabled: plant.remindersEnabled
                    )
                )
            }
            if !enabledPlanTypes.isEmpty {
                calendarPlanEnabledCount += 1
            }
            if enabledPlanTypes.contains(where: {
                PlantReminderPreferenceStore.isSystemReminderEnabled(forPlantID: plant.id, careType: $0)
            }) {
                systemReminderEnabledCount += 1
            }

            for log in plant.careLogs {
                if log.date >= recentWindowStart {
                    recentLogCount += 1
                    if log.careType.careCategory == .growth {
                        growthLogCount += 1
                    }
                    if log.careType == .yellowLeaf || log.careType == .pestFound {
                        healthSignalCount += 1
                    }
                }
                if log.hasPhotoAttachment {
                    photoCount += 1
                }
                latestLogDate = max(latestLogDate ?? log.date, log.date)
            }
        }

        return PlantFeatureCollectionSummary(
            plantCount: plants.count,
            dueTaskCount: dueTasks.count,
            duePlantCount: Set(dueTasks.map(\.plantID)).count,
            wateringDueCount: dueTasks.count { PlantCareFeatureDestination.water.matches($0.careType) },
            fertilizingDueCount: dueTasks.count { PlantCareFeatureDestination.fertilize.matches($0.careType) },
            maintenanceDueCount: dueTasks.count { PlantCareFeatureDestination.maintenance.matches($0.careType) },
            healthDueCount: dueTasks.count { PlantCareFeatureDestination.health.matches($0.careType) },
            growthLogCount: growthLogCount,
            recentLogCount: recentLogCount,
            photoCount: photoCount,
            roomCount: roomNames.count,
            healthSignalCount: healthSignalCount,
            reminderEnabledCount: plants.count { $0.remindersEnabled },
            calendarPlanEnabledCount: calendarPlanEnabledCount,
            systemReminderEnabledCount: systemReminderEnabledCount,
            latestLogDate: latestLogDate
        )
    }
}

struct PetFeatureCollectionSummary: Equatable {
    var activePetCount: Int = 0
    var visibleHumanCount: Int = 0
    var todayFoodLogs: Int = 0
    var todayFoodPetCount: Int = 0
    var hygieneLogsLast7Days: Int = 0
    var todayWalkCount: Int = 0
    var todayWalkDistanceMeters: Double = 0
    var todayPottyLogs: Int = 0
    var healthSignalCount: Int = 0
    var activeMedicationCount: Int = 0
    var weightMemberCount: Int = 0
    var latestWeightDate: Date?
    var monthExpenseCount: Int = 0
    var monthExpenseAmount: Double = 0
    var archiveItemCount: Int = 0

    static let empty = PetFeatureCollectionSummary()

    @MainActor
    static func load(
        pets: [Pet],
        humans: [Human],
        petAggregateSummaries: [UUID: FunctionMenuPetAggregateSummary]
    ) -> PetFeatureCollectionSummary {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? todayStart
        let activePets = pets.filter { !$0.hasPassedAway }
        let visibleHumans = humans.filter { !$0.hasPassedAway }

        var foodPetIDs = Set<UUID>()
        var todayFoodLogs = 0
        var hygieneLogsLast7Days = 0
        var todayWalkCount = 0
        var todayWalkDistanceMeters = 0.0
        var todayPottyLogs = 0
        var healthSignalCount = 0
        var activeMedicationCount = 0
        var latestWeightDate: Date?
        var petWeightMemberIDs = Set<UUID>()
        var monthExpenseCount = 0
        var monthExpenseAmount = 0.0

        for pet in activePets {
            let todayFood = pet.careLogs.filter {
                $0.careType == .feeding && $0.date >= todayStart && $0.date < tomorrowStart
            }
            todayFoodLogs += todayFood.count
            if !todayFood.isEmpty {
                foodPetIDs.insert(pet.id)
            }

            hygieneLogsLast7Days += pet.hygieneLogs.count { $0.date >= sevenDaysAgo }
            hygieneLogsLast7Days += pet.careLogs.count {
                [.waterChange, .filterClean, .cageCleaning, .freeFlight, .misting, .substrateChange]
                    .contains($0.careType) && $0.date >= sevenDaysAgo
            }

            let todayWalks = pet.walkLogs.filter {
                !$0.isRecoveryCheckpoint && $0.startDate >= todayStart && $0.startDate < tomorrowStart
            }
            todayWalkCount += todayWalks.count
            todayWalkDistanceMeters += todayWalks.reduce(0) { $0 + $1.distanceMeters }

            todayPottyLogs += pet.pottyLogs.count { $0.date >= todayStart && $0.date < tomorrowStart }
            todayPottyLogs += pet.careLogs.count {
                $0.careType == .litter && $0.date >= todayStart && $0.date < tomorrowStart
            }

            healthSignalCount += pet.healthLogs.count {
                ($0.nextCheckupDate ?? $0.expirationDate ?? .distantFuture) <= tomorrowStart
            }
            activeMedicationCount += pet.medications.count { $0.isActive(on: now) }

            if let latestPetWeight = pet.weightLogs.map(\.date).max() {
                petWeightMemberIDs.insert(pet.id)
                latestWeightDate = max(latestWeightDate ?? latestPetWeight, latestPetWeight)
            }

            let monthExpenses = pet.expenseLogs.filter { $0.date >= monthStart }
            monthExpenseCount += monthExpenses.count
            monthExpenseAmount += monthExpenses.reduce(0) { $0 + $1.amount }
        }

        var humanWeightMemberIDs = Set<UUID>()
        for human in visibleHumans {
            if let latestHumanWeight = human.weightLogs.map(\.date).max() {
                humanWeightMemberIDs.insert(human.id)
                latestWeightDate = max(latestWeightDate ?? latestHumanWeight, latestHumanWeight)
            }
        }

        let archiveItemCount = petAggregateSummaries.values.reduce(0) { total, summary in
            total + summary.documentCount + summary.photoCount + summary.milestoneCount
        }

        return PetFeatureCollectionSummary(
            activePetCount: activePets.count,
            visibleHumanCount: visibleHumans.count,
            todayFoodLogs: todayFoodLogs,
            todayFoodPetCount: foodPetIDs.count,
            hygieneLogsLast7Days: hygieneLogsLast7Days,
            todayWalkCount: todayWalkCount,
            todayWalkDistanceMeters: todayWalkDistanceMeters,
            todayPottyLogs: todayPottyLogs,
            healthSignalCount: healthSignalCount,
            activeMedicationCount: activeMedicationCount,
            weightMemberCount: petWeightMemberIDs.count + humanWeightMemberIDs.count,
            latestWeightDate: latestWeightDate,
            monthExpenseCount: monthExpenseCount,
            monthExpenseAmount: monthExpenseAmount,
            archiveItemCount: archiveItemCount
        )
    }
}

struct FunctionMenuPetAggregateSummary: Equatable {
    var documentCount: Int = 0
    var photoCount: Int = 0
    var milestoneCount: Int = 0

    static let empty = FunctionMenuPetAggregateSummary()

    @MainActor
    static func load(pets: [Pet], context: ModelContext) -> [UUID: FunctionMenuPetAggregateSummary] {
        var summaries: [UUID: FunctionMenuPetAggregateSummary] = [:]
        for pet in pets {
            let petID = pet.id
            summaries[petID] = FunctionMenuPetAggregateSummary(
                documentCount: count(
                    FetchDescriptor<PetDocument>(
                        predicate: #Predicate<PetDocument> { document in
                            document.pet?.id == petID
                        }
                    ),
                    context: context,
                    name: "PetDocument"
                ),
                photoCount: count(
                    FetchDescriptor<PetPhotoLog>(
                        predicate: #Predicate<PetPhotoLog> { photo in
                            photo.pet?.id == petID
                        }
                    ),
                    context: context,
                    name: "PetPhotoLog"
                ),
                milestoneCount: count(
                    FetchDescriptor<PetMilestone>(
                        predicate: #Predicate<PetMilestone> { milestone in
                            milestone.pet?.id == petID
                        }
                    ),
                    context: context,
                    name: "PetMilestone"
                )
            )
        }
        return summaries
    }

    @MainActor
    private static func count(
        _ descriptor: FetchDescriptor<some PersistentModel>,
        context: ModelContext,
        name: String
    ) -> Int {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            OhanaLog.warning(
                "Function menu aggregate count failed for \(name): \(error.localizedDescription)",
                category: "FunctionMenu"
            )
            return 0
        }
    }
}
