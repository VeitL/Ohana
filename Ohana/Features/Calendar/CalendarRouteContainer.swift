import SwiftData
import SwiftUI

struct CalendarRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("calendar_filterPetId") private var calendarFilterPetId: String = ""
    @AppStorage("calendar_filterHumanId") private var calendarFilterHumanId: String = ""
    @AppStorage("calendar_filterPlantId") private var calendarFilterPlantId: String = ""
    @State private var routeData = CalendarRouteData()
    @State private var routeDataRevision = 0
    @State private var routeDataGeneration = 0
    @State private var dataLoadTask: Task<Void, Never>?
    @State private var revisionReloadTask: Task<Void, Never>?

    var preselectedPetId: String?
    var preselectedHumanId: String?
    var hideToolbar: Bool = false
    var showsEmbeddedControls: Bool = false
    var addEventTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onRequestAddEvent: (([Plant]) -> Void)?
    var onPlantsLoaded: (([Plant]) -> Void)?
    var onEmbeddedScrollOffsetChange: ((CGFloat) -> Void)?
    var onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onCompleteEvent: ((Event, Date, String?) -> Bool)?

    var body: some View {
        CalendarView(
            preselectedPetId: preselectedPetId,
            preselectedHumanId: preselectedHumanId,
            hideToolbar: hideToolbar,
            showsEmbeddedControls: showsEmbeddedControls,
            addEventTrigger: addEventTrigger,
            isEmbeddedPrepared: isEmbeddedPrepared,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive,
            onRequestAddEvent: onRequestAddEvent,
            onEmbeddedScrollOffsetChange: onEmbeddedScrollOffsetChange,
            onOpenEventDestination: onOpenEventDestination,
            onPresentCoconutLog: onPresentCoconutLog,
            onCompleteEvent: onCompleteEvent,
            events: routeData.events,
            familyTaskProjectionEvents: routeData.familyTaskProjectionEvents,
            pets: routeData.pets,
            humans: routeData.humans,
            plants: routeData.plants,
            insurances: routeData.insurances,
            petMedications: routeData.petMedications,
            humanMedications: routeData.humanMedications,
            dataRevision: routeDataRevision,
            routePreparedSnapshotReferences: routeData.preparedSnapshotReferences
        )
        .onAppear {
            scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds)
        }
        .onChange(of: isEmbeddedActive) { _, isActive in
            guard isActive, !routeData.hasLoaded else { return }
            dataLoadTask?.cancel()
            dataLoadTask = nil
            scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds)
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataReloadAfterRevision()
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
            revisionReloadTask?.cancel()
            revisionReloadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        routeDataGeneration += 1
        let generation = routeDataGeneration
        let targetRevision = routeDataRevision + 1
        let container = modelContext.container
        let input = CalendarRouteDataLoadInput(
            selectedDate: Date(),
            filterSelection: initialFilterSelection,
            dataRevision: targetRevision,
            loadPlants: AppFeatureRouteGuard.shouldLoadPlantData
        )

        dataLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else {
                clearDataLoadTask(generation: generation)
                return
            }

            let actor = CalendarRouteDataActor(modelContainer: container)
            do {
                let loadedReference = try await actor.load(input: input)
                guard !Task.isCancelled, generation == routeDataGeneration else { return }
                let loadedData = CalendarRouteData(reference: loadedReference, context: modelContext)
                routeData = loadedData
                routeDataRevision = targetRevision
                onPlantsLoaded?(loadedData.plants)
                if !loadedData.plants.isEmpty {
                    OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
                        PlantUnlockPolicy.noteExistingPlantData()
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Calendar route actor load failed: \(error.localizedDescription)",
                    category: "Calendar"
                )
            }
            clearDataLoadTask(generation: generation)
        }
    }

    private func clearDataLoadTask(generation: Int) {
        guard generation == routeDataGeneration else { return }
        dataLoadTask = nil
    }

    private func scheduleRouteDataReloadAfterRevision() {
        revisionReloadTask?.cancel()
        revisionReloadTask = OhanaFrameScheduler.runAfterNextFrame(
            milliseconds: CalendarEmbeddedContentMountPolicy.revisionReloadDebounceMilliseconds
        ) {
            scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds, force: true)
            revisionReloadTask = nil
        }
    }

    private var routeDataLoadDelayMilliseconds: UInt64 {
        CalendarEmbeddedContentMountPolicy.routeDataLoadDelayMilliseconds(
            hideToolbar: hideToolbar,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive
        )
    }

    private var initialFilterSelection: CalendarFilterSelection {
        if let preselectedPetId {
            return .pet(preselectedPetId)
        }
        if let preselectedHumanId {
            return .human(preselectedHumanId)
        }
        return CalendarFilterSelection(
            petId: calendarFilterPetId,
            humanId: calendarFilterHumanId,
            plantId: calendarFilterPlantId
        )
        .normalizedForUserFilterControls
    }
}

private nonisolated struct CalendarRouteDataLoadInput {
    let selectedDate: Date
    let filterSelection: CalendarFilterSelection
    let dataRevision: Int
    let loadPlants: Bool
}

nonisolated struct CalendarPreparedSnapshotLoadInput: Sendable {
    let selectedDate: Date
    let filterSelection: CalendarFilterSelection
    let dataRevision: Int
    let loadPlants: Bool
}

private nonisolated struct CalendarRouteData {
    var events: [Event] = []
    var familyTaskProjectionEvents: [Event] = []
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var insurances: [PetInsurance] = []
    var petMedications: [PetMedication] = []
    var humanMedications: [HumanMedication] = []
    var preparedSnapshotReferences: [CalendarRoutePreparedSnapshotReference] = []
    var hasLoaded = false

    init() {}

    @MainActor
    init(reference: CalendarRouteDataReference, context: ModelContext) {
        events = Self.rehydrate(reference.events, as: Event.self, context: context)
        familyTaskProjectionEvents = reference.familyTaskOccurrences.map { $0.makeReadOnlyEvent() }
        pets = Self.rehydrate(reference.pets, as: Pet.self, context: context)
        humans = Self.rehydrate(reference.humans, as: Human.self, context: context)
        plants = Self.rehydrate(reference.plants, as: Plant.self, context: context)
        insurances = Self.rehydrate(reference.insurances, as: PetInsurance.self, context: context)
        petMedications = Self.rehydrate(reference.petMedications, as: PetMedication.self, context: context)
        humanMedications = Self.rehydrate(reference.humanMedications, as: HumanMedication.self, context: context)
        preparedSnapshotReferences = reference.preparedSnapshots
        hasLoaded = reference.hasLoaded
    }

    @MainActor
    private static func rehydrate<T: PersistentModel>(
        _ identifiers: [PersistentIdentifier],
        as _: T.Type,
        context: ModelContext
    ) -> [T] {
        identifiers.compactMap { context.model(for: $0) as? T }
    }
}

private nonisolated struct CalendarRouteDataReference: Sendable {
    var events: [PersistentIdentifier] = []
    var familyTaskOccurrences: [CalendarFamilyTaskOccurrenceProjection] = []
    var pets: [PersistentIdentifier] = []
    var humans: [PersistentIdentifier] = []
    var plants: [PersistentIdentifier] = []
    var insurances: [PersistentIdentifier] = []
    var petMedications: [PersistentIdentifier] = []
    var humanMedications: [PersistentIdentifier] = []
    var preparedSnapshots: [CalendarRoutePreparedSnapshotReference] = []
    var hasLoaded = false
}

@ModelActor
private actor CalendarRouteDataActor {
    private static let eventFetchPastMonths = -3
    private static let eventFetchFutureMonths = 3
    private static let recurringEventFetchLimit = 500

    func load(input: CalendarRouteDataLoadInput) throws -> CalendarRouteDataReference {
        try Task.checkCancellation()
        let plants = input.loadPlants
            ? fetch(
                FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)]),
                name: "Plant"
            )
            : []
        let events = fetchVisibleEvents()
        let familyTaskOccurrences = fetchFamilyTaskOccurrences(existingEvents: events)
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "Pet"
        )
        let humans = fetch(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "Human"
        )
        let insurances = fetch(
            FetchDescriptor<PetInsurance>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "PetInsurance"
        )
        let petMedications = fetch(
            FetchDescriptor<PetMedication>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "PetMedication"
        )
        let humanMedications = fetch(
            FetchDescriptor<HumanMedication>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "HumanMedication"
        )
        let routeData = CalendarActorRouteData(
            events: events,
            pets: pets,
            humans: humans,
            plants: plants,
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications
        )
        let preparedSnapshots = preparedSnapshots(for: routeData, input: input)
        try Task.checkCancellation()
        return CalendarRouteDataReference(
            events: events.map(\.persistentModelID),
            familyTaskOccurrences: familyTaskOccurrences,
            pets: pets.map(\.persistentModelID),
            humans: humans.map(\.persistentModelID),
            plants: plants.map(\.persistentModelID),
            insurances: insurances.map(\.persistentModelID),
            petMedications: petMedications.map(\.persistentModelID),
            humanMedications: humanMedications.map(\.persistentModelID),
            preparedSnapshots: preparedSnapshots,
            hasLoaded: true
        )
    }

    private func fetchVisibleEvents(now: Date = Date()) -> [Event] {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .month, value: Self.eventFetchPastMonths, to: now) ?? now
        let windowEnd = calendar.date(byAdding: .month, value: Self.eventFetchFutureMonths, to: now) ?? now
        let windowedEvents = fetch(
            FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.startDate >= windowStart && event.startDate <= windowEnd
                },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            ),
            name: "Event.window"
        )
        var recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.recurrenceDays > 0 && event.startDate <= windowEnd
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        recurringDescriptor.fetchLimit = Self.recurringEventFetchLimit
        let recurringEvents = fetch(
            recurringDescriptor,
            name: "Event.recurring"
        )
        .filter { event in
            guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
            return recurrenceEndDate >= windowStart
        }

        var uniqueEvents: [UUID: Event] = [:]
        for event in windowedEvents + recurringEvents {
            uniqueEvents[event.id] = event
        }
        return uniqueEvents.values.sorted { $0.startDate > $1.startDate }
    }

    private func fetchFamilyTaskOccurrences(
        existingEvents: [Event],
        now: Date = Date()
    ) -> [CalendarFamilyTaskOccurrenceProjection] {
        let activeStatus = FamilyTaskPlanStatus.active.rawValue
        var planDescriptor = FetchDescriptor<FamilyTaskPlan>(
            predicate: #Predicate<FamilyTaskPlan> { $0.statusRaw == activeStatus },
            sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)]
        )
        planDescriptor.fetchLimit = CalendarFamilyTaskProjectionBuilder.activePlanFetchLimit
        let plans = fetch(planDescriptor, name: "FamilyTaskPlan.active")
        guard !plans.isEmpty else { return [] }

        var taskDescriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.planId != nil && task.occurrenceKey != nil
            },
            sortBy: [SortDescriptor(\.nominalAt, order: .reverse), SortDescriptor(\.id)]
        )
        taskDescriptor.fetchLimit = CalendarFamilyTaskProjectionBuilder.existingOccurrenceFetchLimit
        let activePlanIDs = Set(plans.map(\.id.uuidString))
        let taskKeys = fetch(taskDescriptor, name: "FamilyCollaborationTask.planOccurrenceKeys")
            .filter { task in
                guard let planID = task.planId else { return false }
                return activePlanIDs.contains(planID)
            }
            .compactMap(\.occurrenceKey)
        let eventKeys = existingEvents.compactMap(\.familyTaskOccurrenceKey)
        let existingKeys = Set(taskKeys).union(eventKeys)

        return CalendarFamilyTaskProjectionBuilder.occurrences(
            plans: plans.map(familyTaskPlanProjection),
            existingOccurrenceKeys: existingKeys,
            now: now
        )
    }

    private func familyTaskPlanProjection(
        _ plan: FamilyTaskPlan
    ) -> CalendarFamilyTaskPlanProjection {
        let relatedEntityType: String
        let relatedEntityID: String
        switch plan.subjectKind {
        case .household:
            relatedEntityType = ""
            relatedEntityID = ""
        case .human:
            relatedEntityType = EntityKind.human.rawValue
            relatedEntityID = plan.subjectId ?? ""
        case .pet:
            relatedEntityType = EntityKind.pet.rawValue
            relatedEntityID = plan.subjectId ?? ""
        case .plant:
            relatedEntityType = EntityKind.plant.rawValue
            relatedEntityID = plan.subjectId ?? ""
        }
        return CalendarFamilyTaskPlanProjection(
            id: plan.id,
            title: plan.title,
            isAllDay: plan.isAllDay,
            eventTypeRaw: plan.eventTypeRaw,
            relatedEntityType: relatedEntityType,
            relatedEntityID: relatedEntityID,
            assignedToID: plan.assignedToId,
            taskCareKindRaw: plan.taskCareKindRaw,
            recurrenceRule: plan.recurrenceRule,
            anchorAt: plan.anchorAt,
            startsAt: plan.startsAt,
            endsAt: plan.endsAt,
            timeZone: plan.timeZone,
            scheduleVersion: plan.scheduleVersion,
            materializedThroughAt: plan.materializedThroughAt,
            createdAt: plan.createdAt
        )
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        name: String
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Calendar route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Calendar"
            )
            return []
        }
    }

    private func preparedSnapshots(
        for routeData: CalendarActorRouteData,
        input: CalendarRouteDataLoadInput
    ) -> [CalendarRoutePreparedSnapshotReference] {
        prewarmedFilterSelections(for: routeData, initial: input.filterSelection).map { filter in
            preparedSnapshot(
                for: routeData,
                selectedDate: input.selectedDate,
                filter: filter,
                dataRevision: input.dataRevision
            )
        }
    }

    private func preparedSnapshot(
        for routeData: CalendarActorRouteData,
        selectedDate: Date,
        filter: CalendarFilterSelection,
        dataRevision: Int
    ) -> CalendarRoutePreparedSnapshotReference {
        let key = CalendarPreparedSnapshotTriggerKey(
            monthKey: CalendarSnapshotBuilder.preparedSnapshotWindowKey,
            filter: filter,
            dataRevision: dataRevision
        )
        let filtered = filteredEvents(
            routeData.events,
            routeData: routeData,
            filter: filter
        )
        return CalendarRoutePreparedSnapshotReference(
            key: key,
            snapshot: CalendarSnapshotBuilder.preparedSnapshotReference(
                filteredEvents: filtered,
                allEvents: routeData.events,
                pets: routeData.pets,
                weekDays: weekDays(),
                monthDays: monthDays(for: selectedDate)
            )
        )
    }

    private func prewarmedFilterSelections(
        for routeData: CalendarActorRouteData,
        initial: CalendarFilterSelection
    ) -> [CalendarFilterSelection] {
        var selections: [CalendarFilterSelection] = [initial, .all]
        selections.append(contentsOf: routeData.pets.map { CalendarFilterSelection.pet($0.id.uuidString) })
        selections.append(contentsOf: routeData.humans.map { CalendarFilterSelection.human($0.id.uuidString) })
        if !routeData.plants.isEmpty {
            selections.append(.allPlants)
        }
        return uniqueFilterSelections(selections)
    }

    private func uniqueFilterSelections(_ selections: [CalendarFilterSelection]) -> [CalendarFilterSelection] {
        var unique: [CalendarFilterSelection] = []
        for selection in selections where !unique.contains(selection) {
            unique.append(selection)
        }
        return unique
    }

    private func filteredEvents(
        _ events: [Event],
        routeData: CalendarActorRouteData,
        filter: CalendarFilterSelection
    ) -> [Event] {
        var result = events.filter {
            !CarePlanCalendarSync.isDefaultGeneratedCalendarPlan($0, pets: routeData.pets) &&
                !MemberLifecycleActiveScheduleResolver.eventTargetsDeceasedActiveSchedule(
                    $0,
                    pets: routeData.pets,
                    humans: routeData.humans,
                    petMedications: routeData.petMedications,
                    humanMedications: routeData.humanMedications,
                    insurances: routeData.insurances
                )
        }
        if let petId = effectivePetFilterId(filter) {
            result = result.filter {
                MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                    $0,
                    petId: petId,
                    petMedications: routeData.petMedications,
                    insurances: routeData.insurances
                )
            }
        }
        if let humanId = effectiveHumanFilterId(filter) {
            result = result.filter {
                MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                    $0,
                    humanId: humanId,
                    humanMedications: routeData.humanMedications
                )
            }
        }
        if effectivePlantFilterIncludesAll(filter) {
            result = result.filter { eventIsRelatedToAnyPlant($0, plants: routeData.plants) }
        } else if let plantId = effectivePlantFilterId(filter) {
            result = result.filter {
                DomainEntityLinkRegistry.plantId(for: $0)?.uuidString == plantId
            }
        }
        return result
    }

    private func effectivePetFilterId(_ selection: CalendarFilterSelection) -> String? {
        if !selection.humanId.isEmpty || !selection.plantId.isEmpty {
            return nil
        }
        return selection.selectedPetId
    }

    private func effectiveHumanFilterId(_ selection: CalendarFilterSelection) -> String? {
        if !selection.petId.isEmpty || !selection.plantId.isEmpty {
            return nil
        }
        return selection.selectedHumanId
    }

    private func effectivePlantFilterId(_ selection: CalendarFilterSelection) -> String? {
        if !selection.petId.isEmpty || !selection.humanId.isEmpty {
            return nil
        }
        return selection.selectedPlantId
    }

    private func effectivePlantFilterIncludesAll(_ selection: CalendarFilterSelection) -> Bool {
        guard selection.petId.isEmpty, selection.humanId.isEmpty else { return false }
        return selection.isAllPlantsSelected
    }

    private func eventIsRelatedToAnyPlant(_ event: Event, plants: [Plant]) -> Bool {
        guard let plantId = DomainEntityLinkRegistry.plantId(for: event) else { return false }
        return plants.contains { $0.id == plantId }
    }

    private func weekDays(now: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        guard let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else { return [] }
        return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    }

    private func monthDays(for selectedDate: Date) -> [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
}

@ModelActor
actor CalendarPreparedSnapshotActor {
    private static let eventFetchPastMonths = -3
    private static let eventFetchFutureMonths = 3
    private static let recurringEventFetchLimit = 500

    func load(input: CalendarPreparedSnapshotLoadInput) throws -> CalendarRoutePreparedSnapshotReference {
        try Task.checkCancellation()
        let plants = input.loadPlants
            ? fetch(
                FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)]),
                name: "Plant"
            )
            : []
        let events = fetchVisibleEvents()
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "Pet"
        )
        let humans = fetch(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "Human"
        )
        let insurances = fetch(
            FetchDescriptor<PetInsurance>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "PetInsurance"
        )
        let petMedications = fetch(
            FetchDescriptor<PetMedication>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "PetMedication"
        )
        let humanMedications = fetch(
            FetchDescriptor<HumanMedication>(sortBy: [SortDescriptor(\.createdAt)]),
            name: "HumanMedication"
        )
        let routeData = CalendarActorRouteData(
            events: events,
            pets: pets,
            humans: humans,
            plants: plants,
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications
        )
        let preparedSnapshot = preparedSnapshot(for: routeData, input: input)
        try Task.checkCancellation()
        return preparedSnapshot
    }

    private func fetchVisibleEvents(now: Date = Date()) -> [Event] {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .month, value: Self.eventFetchPastMonths, to: now) ?? now
        let windowEnd = calendar.date(byAdding: .month, value: Self.eventFetchFutureMonths, to: now) ?? now
        let windowedEvents = fetch(
            FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.startDate >= windowStart && event.startDate <= windowEnd
                },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            ),
            name: "Event.window"
        )
        var recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.recurrenceDays > 0 && event.startDate <= windowEnd
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        recurringDescriptor.fetchLimit = Self.recurringEventFetchLimit
        let recurringEvents = fetch(
            recurringDescriptor,
            name: "Event.recurring"
        )
        .filter { event in
            guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
            return recurrenceEndDate >= windowStart
        }

        var uniqueEvents: [UUID: Event] = [:]
        for event in windowedEvents + recurringEvents {
            uniqueEvents[event.id] = event
        }
        return uniqueEvents.values.sorted { $0.startDate > $1.startDate }
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        name: String
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Calendar prepared snapshot fetch failed for \(name): \(error.localizedDescription)",
                category: "Calendar"
            )
            return []
        }
    }

    private func preparedSnapshot(
        for routeData: CalendarActorRouteData,
        input: CalendarPreparedSnapshotLoadInput
    ) -> CalendarRoutePreparedSnapshotReference {
        let key = CalendarPreparedSnapshotTriggerKey(
            monthKey: CalendarSnapshotBuilder.preparedSnapshotWindowKey,
            filter: input.filterSelection,
            dataRevision: input.dataRevision
        )
        let filtered = filteredEvents(
            routeData.events,
            routeData: routeData,
            filter: input.filterSelection
        )
        return CalendarRoutePreparedSnapshotReference(
            key: key,
            snapshot: CalendarSnapshotBuilder.preparedSnapshotReference(
                filteredEvents: filtered,
                allEvents: routeData.events,
                pets: routeData.pets,
                weekDays: weekDays(),
                monthDays: monthDays(for: input.selectedDate)
            )
        )
    }

    private func filteredEvents(
        _ events: [Event],
        routeData: CalendarActorRouteData,
        filter: CalendarFilterSelection
    ) -> [Event] {
        var result = events.filter {
            !CarePlanCalendarSync.isDefaultGeneratedCalendarPlan($0, pets: routeData.pets) &&
                !MemberLifecycleActiveScheduleResolver.eventTargetsDeceasedActiveSchedule(
                    $0,
                    pets: routeData.pets,
                    humans: routeData.humans,
                    petMedications: routeData.petMedications,
                    humanMedications: routeData.humanMedications,
                    insurances: routeData.insurances
                )
        }
        if let petId = effectivePetFilterId(filter) {
            result = result.filter {
                MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                    $0,
                    petId: petId,
                    petMedications: routeData.petMedications,
                    insurances: routeData.insurances
                )
            }
        }
        if let humanId = effectiveHumanFilterId(filter) {
            result = result.filter {
                MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                    $0,
                    humanId: humanId,
                    humanMedications: routeData.humanMedications
                )
            }
        }
        if effectivePlantFilterIncludesAll(filter) {
            result = result.filter { eventIsRelatedToAnyPlant($0, plants: routeData.plants) }
        } else if let plantId = effectivePlantFilterId(filter) {
            result = result.filter {
                DomainEntityLinkRegistry.plantId(for: $0)?.uuidString == plantId
            }
        }
        return result
    }

    private func effectivePetFilterId(_ selection: CalendarFilterSelection) -> String? {
        if !selection.humanId.isEmpty || !selection.plantId.isEmpty {
            return nil
        }
        return selection.selectedPetId
    }

    private func effectiveHumanFilterId(_ selection: CalendarFilterSelection) -> String? {
        if !selection.petId.isEmpty || !selection.plantId.isEmpty {
            return nil
        }
        return selection.selectedHumanId
    }

    private func effectivePlantFilterId(_ selection: CalendarFilterSelection) -> String? {
        if !selection.petId.isEmpty || !selection.humanId.isEmpty {
            return nil
        }
        return selection.selectedPlantId
    }

    private func effectivePlantFilterIncludesAll(_ selection: CalendarFilterSelection) -> Bool {
        guard selection.petId.isEmpty, selection.humanId.isEmpty else { return false }
        return selection.isAllPlantsSelected
    }

    private func eventIsRelatedToAnyPlant(_ event: Event, plants: [Plant]) -> Bool {
        guard let plantId = DomainEntityLinkRegistry.plantId(for: event) else { return false }
        return plants.contains { $0.id == plantId }
    }

    private func weekDays(now: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        guard let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else { return [] }
        return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    }

    private func monthDays(for selectedDate: Date) -> [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
}

private nonisolated struct CalendarActorRouteData {
    let events: [Event]
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let insurances: [PetInsurance]
    let petMedications: [PetMedication]
    let humanMedications: [HumanMedication]
}
