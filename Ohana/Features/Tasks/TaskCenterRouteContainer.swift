//
//  TaskCenterRouteContainer.swift
//  Ohana
//
//  Bounded route-data host for the task center and its Calendar handoff.
//

import SwiftData
import SwiftUI

enum TaskCenterPresentation: Equatable {
    case embeddedHome
    case sheet
}

struct TaskCenterRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    @State private var selectedSurface: TaskCenterSurface
    @State private var routeData = TaskCenterRouteData()
    @State private var routeDataGeneration = 0
    @State private var dataLoadTask: Task<Void, Never>?
    @State private var revisionReloadTask: Task<Void, Never>?
    @State private var eventDetailPresentation: CalendarEventDetailPresentation?
    @State private var showingAddEvent = false

    let presentation: TaskCenterPresentation
    var preselectedPetId: String?
    var preselectedHumanId: String?
    var addEventTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onRequestAddEvent: (([Plant]) -> Void)?
    var onPlantsLoaded: (([Plant]) -> Void)?
    var onEmbeddedScrollOffsetChange: ((CGFloat) -> Void)?
    var onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onBadgeChange: ((TaskCenterBadgeSnapshot) -> Void)?
    var onDismiss: (() -> Void)?

    init(
        presentation: TaskCenterPresentation,
        initialSurface: TaskCenterSurface = .tasks,
        preselectedPetId: String? = nil,
        preselectedHumanId: String? = nil,
        addEventTrigger: Int = 0,
        isEmbeddedPrepared: Bool = true,
        isEmbeddedVisible: Bool = true,
        isEmbeddedActive: Bool = true,
        onRequestAddEvent: (([Plant]) -> Void)? = nil,
        onPlantsLoaded: (([Plant]) -> Void)? = nil,
        onEmbeddedScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)? = nil,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil,
        onBadgeChange: ((TaskCenterBadgeSnapshot) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.presentation = presentation
        self.preselectedPetId = preselectedPetId
        self.preselectedHumanId = preselectedHumanId
        self.addEventTrigger = addEventTrigger
        self.isEmbeddedPrepared = isEmbeddedPrepared
        self.isEmbeddedVisible = isEmbeddedVisible
        self.isEmbeddedActive = isEmbeddedActive
        self.onRequestAddEvent = onRequestAddEvent
        self.onPlantsLoaded = onPlantsLoaded
        self.onEmbeddedScrollOffsetChange = onEmbeddedScrollOffsetChange
        self.onOpenEventDestination = onOpenEventDestination
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onBadgeChange = onBadgeChange
        self.onDismiss = onDismiss
        _selectedSurface = State(initialValue: initialSurface)
    }

    var body: some View {
        ZStack {
            if presentation == .sheet {
                OhanaAppBackground()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                TaskCenterHeader(
                    selectedSurface: $selectedSurface,
                    snapshot: routeData.snapshot,
                    isLoading: !routeData.hasLoaded,
                    showsAddButton: presentation == .sheet,
                    showsCloseButton: presentation == .sheet,
                    onAdd: requestAddEvent,
                    onClose: onDismiss
                )

                Group {
                    switch selectedSurface {
                    case .tasks:
                        TaskCenterView(
                            snapshot: routeData.snapshot,
                            isLoading: !routeData.hasLoaded,
                            bottomClearance: presentation == .embeddedHome ? 190 : 42,
                            onComplete: completeTask,
                            onOpen: openTask,
                            onScrollOffsetChange: onEmbeddedScrollOffsetChange
                        )
                    case .calendar:
                        CalendarRouteContainer(
                            preselectedPetId: preselectedPetId,
                            preselectedHumanId: preselectedHumanId,
                            hideToolbar: true,
                            showsEmbeddedControls: true,
                            isEmbeddedPrepared: isEmbeddedPrepared,
                            isEmbeddedVisible: isEmbeddedVisible,
                            isEmbeddedActive: isEmbeddedActive,
                            onRequestAddEvent: onRequestAddEvent,
                            onPlantsLoaded: onPlantsLoaded,
                            onEmbeddedScrollOffsetChange: onEmbeddedScrollOffsetChange,
                            onOpenEventDestination: onOpenEventDestination,
                            onPresentCoconutLog: onPresentCoconutLog
                        )
                    }
                }
                .contentTransition(.opacity)
            }
        }
        .fullScreenCover(item: $eventDetailPresentation) { presentation in
            CalendarEventDetailPage(
                event: presentation.event,
                occurrenceDate: presentation.occurrenceDate,
                pets: routeData.pets,
                humans: routeData.humans,
                plants: routeData.plants,
                allowsEditing: presentation.allowsEditing,
                onDelete: {
                    eventDetailPresentation = nil
                    scheduleRouteDataLoad(delayMilliseconds: 220, force: true)
                },
                onComplete: {
                    _ = completeEvent(
                        presentation.event,
                        occurrenceDate: presentation.occurrenceDate
                    )
                }
            )
        }
        .fullScreenCover(isPresented: $showingAddEvent) {
            AddEventView(
                onClose: {
                    showingAddEvent = false
                    scheduleRouteDataLoad(delayMilliseconds: 220, force: true)
                },
                plants: routeData.plants
            )
        }
        .onAppear {
            scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds)
        }
        .onChange(of: selectedSurface) { _, _ in
            OhanaFeedback.selection()
            onEmbeddedScrollOffsetChange?(0)
        }
        .onChange(of: addEventTrigger) { _, _ in
            requestAddEvent()
        }
        .onChange(of: isEmbeddedActive) { _, isActive in
            if isActive, !routeData.hasLoaded {
                scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds)
            }
        }
        .onChange(of: isEmbeddedVisible) { _, isVisible in
            if isVisible, !routeData.hasLoaded {
                scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds)
            }
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRevisionReload()
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
            revisionReloadTask?.cancel()
            revisionReloadTask = nil
        }
        .accessibilityIdentifier("task-center-route")
    }

    private var routeDataLoadDelayMilliseconds: UInt64 {
        if presentation == .sheet || isEmbeddedVisible || isEmbeddedActive {
            return 24
        }
        return isEmbeddedPrepared ? 96 : 180
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64, force: Bool = false) {
        guard presentation == .sheet || isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive else { return }
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        routeDataGeneration += 1
        let generation = routeDataGeneration
        let container = modelContext.container
        let loadPlants = AppFeatureRouteGuard.shouldLoadPlantData

        dataLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else {
                clearDataLoadTask(generation: generation)
                return
            }

            do {
                let actor = TaskCenterDataActor(modelContainer: container)
                let reference = try await actor.load(loadPlants: loadPlants)
                guard !Task.isCancelled, generation == routeDataGeneration else { return }
                let loaded = TaskCenterRouteData(reference: reference, context: modelContext)
                routeData = loaded
                onPlantsLoaded?(loaded.plants)
                onBadgeChange?(TaskCenterBadgeSnapshot(snapshot: loaded.snapshot))
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Task center data load failed: \(error.localizedDescription)",
                    category: "Tasks"
                )
            }
            clearDataLoadTask(generation: generation)
        }
    }

    private func clearDataLoadTask(generation: Int) {
        guard generation == routeDataGeneration else { return }
        dataLoadTask = nil
    }

    private func scheduleRevisionReload() {
        revisionReloadTask?.cancel()
        revisionReloadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
            revisionReloadTask = nil
        }
    }

    private func requestAddEvent() {
        OhanaFeedback.light()
        if let onRequestAddEvent {
            onRequestAddEvent(routeData.plants)
        } else {
            showingAddEvent = true
        }
    }

    private func completeTask(_ item: TaskCenterItemSnapshot) -> Bool {
        guard let event = routeData.events.first(where: { $0.id == item.eventID }) else { return false }
        return completeEvent(event, occurrenceDate: item.occurrenceDate)
    }

    private func completeEvent(_ event: Event, occurrenceDate: Date) -> Bool {
        guard !event.isOccurrenceMarkedComplete(on: occurrenceDate) else { return true }
        let command = DomainCommand.calendarEventCompletion(eventID: event.id, isCompleted: true)
        let executor = CalendarCommandExecutor(context: modelContext, services: appServices)
        do {
            let result = try executor.toggleCompletion(
                event: event,
                occurrenceDate: occurrenceDate,
                pets: routeData.pets,
                executorId: appServices.activeHumanSelection.currentHumanId,
                note: "task_center.event.completion"
            )
            guard result.isCompleted else { return false }
            scheduleRouteDataLoad(delayMilliseconds: 180, force: true)
            return true
        } catch {
            appServices.domainRevisions.publishFailure(command: command, error: error)
            return false
        }
    }

    private func openTask(_ item: TaskCenterItemSnapshot) {
        guard let event = routeData.events.first(where: { $0.id == item.eventID }) else { return }
        let allowsEditing = CalendarEventInteractionPolicy.allowsUserEventDetail(
            for: event,
            pets: routeData.pets
        )
        if let onOpenEventDestination,
           CalendarEventInteractionPolicy.shouldOpenRelatedDestination(for: event, pets: routeData.pets) {
            let destination = FocusHomeReminderDeepLinkRouter.destination(
                for: event,
                pets: routeData.pets,
                humans: routeData.humans,
                plants: routeData.plants,
                humanMedications: routeData.humanMedications
            )
            if case let .calendar(entityID, humanID, plantID) = destination,
               entityID == nil, humanID == nil, plantID == nil {
                presentEventDetail(event, occurrenceDate: item.occurrenceDate, allowsEditing: allowsEditing)
            } else {
                onOpenEventDestination(destination)
            }
            return
        }
        presentEventDetail(event, occurrenceDate: item.occurrenceDate, allowsEditing: allowsEditing)
    }

    private func presentEventDetail(_ event: Event, occurrenceDate: Date, allowsEditing: Bool) {
        eventDetailPresentation = CalendarEventDetailPresentation(
            event: event,
            occurrenceDate: occurrenceDate,
            allowsEditing: allowsEditing
        )
    }
}

private nonisolated struct TaskCenterRouteDataReference: Sendable {
    let snapshot: TaskCenterSnapshot
    let eventModelIDs: [PersistentIdentifier]
    let petModelIDs: [PersistentIdentifier]
    let humanModelIDs: [PersistentIdentifier]
    let plantModelIDs: [PersistentIdentifier]
    let humanMedicationModelIDs: [PersistentIdentifier]
}

private struct TaskCenterRouteData {
    var snapshot = TaskCenterSnapshot.empty
    var events: [Event] = []
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var humanMedications: [HumanMedication] = []
    var hasLoaded = false

    init() {}

    @MainActor
    init(reference: TaskCenterRouteDataReference, context: ModelContext) {
        snapshot = reference.snapshot
        events = Self.rehydrate(reference.eventModelIDs, as: Event.self, context: context)
        pets = Self.rehydrate(reference.petModelIDs, as: Pet.self, context: context)
        humans = Self.rehydrate(reference.humanModelIDs, as: Human.self, context: context)
        plants = Self.rehydrate(reference.plantModelIDs, as: Plant.self, context: context)
        humanMedications = Self.rehydrate(
            reference.humanMedicationModelIDs,
            as: HumanMedication.self,
            context: context
        )
        hasLoaded = true
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

@ModelActor
private actor TaskCenterDataActor {
    private static let eventFetchPastMonths = -3
    private static let eventFetchFutureMonths = 3
    private static let eventFetchLimit = 600
    private static let recurringEventFetchLimit = 500

    func load(loadPlants: Bool, now: Date = Date()) throws -> TaskCenterRouteDataReference {
        try Task.checkCancellation()
        let pets = fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]), name: "Pet")
        let humans = fetch(FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]), name: "Human")
        let plants = loadPlants
            ? fetch(FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)]), name: "Plant")
            : []
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
        let allEvents = fetchVisibleEvents(now: now)
        let events = allEvents.filter { event in
            if !loadPlants, DomainEntityLinkRegistry.plantId(for: event) != nil {
                return false
            }
            return !MemberLifecycleActiveScheduleResolver.eventTargetsDeceasedActiveSchedule(
                event,
                pets: pets,
                humans: humans,
                petMedications: petMedications,
                humanMedications: humanMedications,
                insurances: insurances,
                now: now
            )
        }
        let snapshot = TaskCenterSnapshotBuilder.make(
            events: events,
            allEvents: events,
            pets: pets,
            humans: humans,
            plants: plants,
            insurances: insurances,
            petMedications: petMedications,
            humanMedications: humanMedications,
            now: now
        )
        try Task.checkCancellation()

        return TaskCenterRouteDataReference(
            snapshot: snapshot,
            eventModelIDs: events.map(\.persistentModelID),
            petModelIDs: pets.map(\.persistentModelID),
            humanModelIDs: humans.map(\.persistentModelID),
            plantModelIDs: plants.map(\.persistentModelID),
            humanMedicationModelIDs: humanMedications.map(\.persistentModelID)
        )
    }

    private func fetchVisibleEvents(now: Date) -> [Event] {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .month, value: Self.eventFetchPastMonths, to: now) ?? now
        let windowEnd = calendar.date(byAdding: .month, value: Self.eventFetchFutureMonths, to: now) ?? now
        var windowedDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.startDate >= windowStart && event.startDate <= windowEnd
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        windowedDescriptor.fetchLimit = Self.eventFetchLimit
        let windowedEvents = fetch(windowedDescriptor, name: "Event.window")

        var recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.recurrenceDays > 0 && event.startDate <= windowEnd
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        recurringDescriptor.fetchLimit = Self.recurringEventFetchLimit
        let recurringEvents = fetch(recurringDescriptor, name: "Event.recurring").filter { event in
            guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
            return recurrenceEndDate >= windowStart
        }

        var uniqueEvents: [UUID: Event] = [:]
        for event in windowedEvents + recurringEvents {
            uniqueEvents[event.id] = event
        }
        return uniqueEvents.values.sorted { $0.startDate < $1.startDate }
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        name: String
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Task center data fetch failed for \(name): \(error.localizedDescription)",
                category: "Tasks"
            )
            return []
        }
    }
}
