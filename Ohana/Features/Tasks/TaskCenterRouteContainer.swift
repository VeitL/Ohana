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
    @State private var showingAddChoice = false
    @State private var didAutoPresentCreation = false
    @State private var familyTaskEditorRoute: FamilyCollaborationEditorRoute?

    let presentation: TaskCenterPresentation
    let routeContext: TaskCenterRouteContext
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
        routeContext: TaskCenterRouteContext = .all,
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
        self.routeContext = routeContext
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
                    snapshot: visibleSnapshot,
                    isLoading: !routeData.hasLoaded,
                    showsAddButton: true,
                    showsCloseButton: presentation == .sheet,
                    filterLabel: scopeLabel,
                    onAdd: requestAdd,
                    onClose: onDismiss
                )

                Group {
                    switch selectedSurface {
                    case .tasks:
                        TaskCenterView(
                            snapshot: visibleSnapshot,
                            isLoading: !routeData.hasLoaded,
                            bottomClearance: presentation == .embeddedHome ? 190 : 42,
                            showsDailyProgress: routeContext.scope == .all,
                            focusedItemID: focusedItemID,
                            focusRequestID: routeContext.focusRequestID,
                            onAction: performTaskAction,
                            onOpen: openTask,
                            onScrollOffsetChange: onEmbeddedScrollOffsetChange
                        )
                    case .calendar:
                        VStack(spacing: 0) {
                            TaskCenterCalendarWorkflowStrip(
                                items: calendarWorkflowItems,
                                onOpen: openTask,
                                onAction: performTaskAction
                            )
                            CalendarRouteContainer(
                                preselectedPetId: effectivePreselectedPetID,
                                preselectedHumanId: effectivePreselectedHumanID,
                                hideToolbar: true,
                                showsEmbeddedControls: true,
                                isEmbeddedPrepared: isEmbeddedPrepared,
                                isEmbeddedVisible: isEmbeddedVisible,
                                isEmbeddedActive: isEmbeddedActive,
                                onRequestAddEvent: onRequestAddEvent,
                                onPlantsLoaded: onPlantsLoaded,
                                onEmbeddedScrollOffsetChange: onEmbeddedScrollOffsetChange,
                                onOpenEventDestination: onOpenEventDestination,
                                onPresentCoconutLog: onPresentCoconutLog,
                                onCompleteEvent: completeEvent
                            )
                        }
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
                plants: routeData.plants,
                preselectedEntityType: routeContext.preselectedEntityType,
                preselectedEntityId: routeContext.preselectedEntityId,
                taskCreationPreset: routeContext.creationPreset
            )
        }
        .sheet(item: $familyTaskEditorRoute) { route in
            familyTaskEditor(route)
        }
        .confirmationDialog(
            L10n.current.tr(zh: "添加待办", en: "Add task", de: "Aufgabe hinzufügen"),
            isPresented: $showingAddChoice,
            titleVisibility: .visible
        ) {
            Button(L10n.current.tr(zh: "家庭分工", en: "Household assignment", de: "Aufgabe verteilen")) {
                familyTaskEditorRoute = .create
            }
            Button(L10n.current.tr(zh: "日历事项", en: "Calendar item", de: "Kalendereintrag")) {
                requestAddEvent()
            }
            Button(L10n.current.cancel, role: .cancel) {}
        }
        .onAppear {
            scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds)
            if routeContext.creationPreset != nil, !didAutoPresentCreation {
                didAutoPresentCreation = true
                showingAddEvent = true
            }
        }
        .onChange(of: selectedSurface) { _, _ in
            OhanaFeedback.selection()
            onEmbeddedScrollOffsetChange?(0)
        }
        .onChange(of: addEventTrigger) { _, _ in
            requestAdd()
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
                let reference = try await actor.load(
                    loadPlants: loadPlants,
                    activeHumanID: appServices.activeHumanSelection.currentHumanId
                )
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
        if routeContext.creationPreset != nil {
            showingAddEvent = true
        } else if let onRequestAddEvent {
            onRequestAddEvent(routeData.plants)
        } else {
            showingAddEvent = true
        }
    }

    private func requestAdd() {
        OhanaFeedback.light()
        if routeContext.creationPreset != nil || routeContext.scope != .all {
            requestAddEvent()
        } else if activeHumans.count > 1, currentHuman != nil {
            showingAddChoice = true
        } else {
            requestAddEvent()
        }
    }

    private func performTaskAction(
        _ item: TaskCenterItemSnapshot,
        action: TaskCenterAvailableAction
    ) -> Bool {
        let result = TaskActionCommandExecutor(
            modelContext: modelContext,
            services: appServices
        ).execute(
            TaskActionCommand(item: item, action: action),
            events: routeData.events,
            familyTasks: routeData.familyTasks,
            humans: routeData.humans,
            pets: routeData.pets
        )
        guard result.didSucceed else { return false }
        scheduleRouteDataLoad(delayMilliseconds: 180, force: true)
        return true
    }

    private func completeEvent(_ event: Event, occurrenceDate: Date) -> Bool {
        guard let item = taskCenterItem(for: event, occurrenceDate: occurrenceDate) else {
            return event.isOccurrenceMarkedComplete(on: occurrenceDate)
        }
        if item.workflowStatus == .completed || item.workflowStatus == .pendingReview {
            return true
        }
        if item.availableActions.contains(.submitForReview) {
            return performTaskAction(item, action: .submitForReview)
        }
        guard item.availableActions.contains(.complete) else { return false }
        return performTaskAction(item, action: .complete)
    }

    private func taskCenterItem(
        for event: Event,
        occurrenceDate: Date
    ) -> TaskCenterItemSnapshot? {
        if let exactItem = routeData.snapshot.allItems.first(where: {
            $0.eventID == event.id &&
                Calendar.current.isDate($0.occurrenceDate, inSameDayAs: occurrenceDate)
        }) {
            return exactItem
        }
        guard let template = routeData.snapshot.allItems.first(where: { $0.eventID == event.id }) else {
            return nil
        }
        let calendar = Calendar.current
        let occurrenceDay = calendar.startOfDay(for: occurrenceDate)
        let scheduledAt = event.isAllDay
            ? occurrenceDay
            : calendar.date(
                bySettingHour: calendar.component(.hour, from: event.startDate),
                minute: calendar.component(.minute, from: event.startDate),
                second: calendar.component(.second, from: event.startDate),
                of: occurrenceDay
            ) ?? occurrenceDate
        return TaskCenterItemSnapshot(
            id: "event-\(event.id.uuidString)-\(Int(occurrenceDay.timeIntervalSince1970))",
            eventID: template.eventID,
            reminderID: nil,
            familyTaskID: nil,
            source: .event,
            title: template.title,
            subject: template.subject,
            eventType: template.eventType,
            symbol: template.symbol,
            occurrenceDate: occurrenceDate,
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            isAllDay: template.isAllDay,
            isRecurring: template.isRecurring,
            urgency: template.urgency,
            workflowStatus: .active,
            availableActions: [.complete],
            participantHumanIDs: template.participantHumanIDs,
            createdByMember: nil,
            assignedToMember: template.assignedToMember,
            claimedByMember: nil,
            completedByMember: nil,
            rewardCoconuts: 0
        )
    }

    private func openTask(_ item: TaskCenterItemSnapshot) {
        guard let eventID = item.eventID,
              let event = routeData.events.first(where: { $0.id == eventID }) else {
            if let familyTaskID = item.familyTaskID {
                familyTaskEditorRoute = .editTask(familyTaskID)
            }
            return
        }
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

    private var activeHumans: [Human] {
        routeData.humans.filter { !$0.hasPassedAway }
    }

    private var effectivePreselectedPetID: String? {
        if let preselectedPetId { return preselectedPetId }
        if case let .pet(id) = routeContext.scope { return id.uuidString }
        return nil
    }

    private var effectivePreselectedHumanID: String? {
        if let preselectedHumanId { return preselectedHumanId }
        if case let .human(id) = routeContext.scope { return id.uuidString }
        return nil
    }

    private var currentHuman: Human? {
        let selectedID = appServices.activeHumanSelection.currentHumanId
        return activeHumans.first { $0.id.uuidString == selectedID } ?? activeHumans.first
    }

    private var visibleSnapshot: TaskCenterSnapshot {
        routeData.snapshot.filtered(for: routeContext.scope)
    }

    private var scopeLabel: String? {
        switch routeContext.scope {
        case .all:
            nil
        case let .human(id):
            routeData.humans.first(where: { $0.id == id }).map { human in
                L10n.current.tr(
                    zh: "\(human.name) 的待办",
                    en: "Tasks for \(human.name)",
                    de: "Aufgaben für \(human.name)"
                )
            }
        case let .pet(id):
            routeData.pets.first(where: { $0.id == id }).map { pet in
                L10n.current.tr(
                    zh: "\(pet.name) 的待办",
                    en: "Tasks for \(pet.name)",
                    de: "Aufgaben für \(pet.name)"
                )
            }
        case let .plant(id):
            routeData.plants.first(where: { $0.id == id }).map { plant in
                L10n.current.tr(
                    zh: "\(plant.name) 的待办",
                    en: "Tasks for \(plant.name)",
                    de: "Aufgaben für \(plant.name)"
                )
            }
        }
    }

    private var focusedItemID: String? {
        if let focusedItemID = routeContext.focusedItemID,
           visibleSnapshot.allItems.contains(where: { $0.id == focusedItemID }) {
            return focusedItemID
        }
        guard let familyTaskID = routeContext.focusedFamilyTaskID else { return nil }
        return visibleSnapshot.allItems.first { $0.familyTaskID == familyTaskID }?.id
    }

    private var calendarWorkflowItems: [TaskCenterItemSnapshot] {
        visibleSnapshot.allItems.filter { item in
            item.dueAt != nil &&
                (item.source == .familyTask || item.workflowStatus == .pendingReview)
        }
    }

    @ViewBuilder
    private func familyTaskEditor(_ route: FamilyCollaborationEditorRoute) -> some View {
        let context = FamilyCollaborationEditorContext.resolve(
            route: route,
            reminders: routeData.reminders,
            tasks: routeData.familyTasks
        )
        let commandExecutor = FamilyCollaborationCommandExecutor(modelContext: modelContext)
        NavigationStack {
            Group {
                if let context {
                    FamilyTaskEditorPanel(
                        context: context,
                        humans: activeHumans,
                        currentHuman: currentHuman,
                        pets: routeData.pets.filter { !$0.hasPassedAway },
                        onClose: dismissFamilyTaskEditor,
                        onAssignReminder: { reminder, human, reward, note in
                            commandExecutor.assignReminder(
                                reminder,
                                to: human,
                                by: currentHuman,
                                rewardCoconuts: reward,
                                note: note
                            )
                        },
                        onCreateTask: { title, note, human, reward, dueAt, emoji in
                            commandExecutor.createTask(
                                title: title,
                                note: note,
                                assignedTo: human,
                                by: currentHuman,
                                rewardCoconuts: reward,
                                dueAt: dueAt,
                                emoji: emoji
                            )
                        },
                        onUpdateTask: { task, title, note, human, reward, dueAt, emoji in
                            commandExecutor.updateTask(
                                task,
                                title: title,
                                note: note,
                                assignedTo: human,
                                rewardCoconuts: reward,
                                dueAt: dueAt,
                                emoji: emoji,
                                by: currentHuman
                            )
                        },
                        onDeleteTask: { task in
                            commandExecutor.deleteTask(task, by: currentHuman)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        L10n.current.tr(zh: "任务不可用", en: "Task unavailable", de: "Aufgabe nicht verfügbar"),
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .navigationTitle(editorTitle(route))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.current.cancel, action: dismissFamilyTaskEditor)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private func dismissFamilyTaskEditor() {
        familyTaskEditorRoute = nil
        scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
    }

    private func editorTitle(_ route: FamilyCollaborationEditorRoute) -> String {
        switch route {
        case .assignReminder:
            L10n.current.tr(zh: "分配提醒", en: "Assign reminder", de: "Erinnerung zuweisen")
        case .editTask:
            L10n.current.tr(zh: "编辑任务", en: "Edit task", de: "Aufgabe bearbeiten")
        case .create:
            L10n.current.tr(zh: "新建任务", en: "New task", de: "Neue Aufgabe")
        }
    }
}

private nonisolated struct TaskCenterRouteDataReference: Sendable {
    let snapshot: TaskCenterSnapshot
    let eventModelIDs: [PersistentIdentifier]
    let reminderModelIDs: [PersistentIdentifier]
    let familyTaskModelIDs: [PersistentIdentifier]
    let petModelIDs: [PersistentIdentifier]
    let humanModelIDs: [PersistentIdentifier]
    let plantModelIDs: [PersistentIdentifier]
    let humanMedicationModelIDs: [PersistentIdentifier]
}

private struct TaskCenterRouteData {
    var snapshot = TaskCenterSnapshot.empty
    var events: [Event] = []
    var reminders: [Reminder] = []
    var familyTasks: [FamilyCollaborationTask] = []
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
        reminders = Self.rehydrate(reference.reminderModelIDs, as: Reminder.self, context: context)
        familyTasks = Self.rehydrate(
            reference.familyTaskModelIDs,
            as: FamilyCollaborationTask.self,
            context: context
        )
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
    private static let completedFamilyTaskFetchLimit = 300

    func load(
        loadPlants: Bool,
        activeHumanID: String?,
        now: Date = Date()
    ) throws -> TaskCenterRouteDataReference {
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
        let reminders = fetchVisibleReminders()
        let activeFamilyTasks = fetchActiveFamilyTasks()
        let completedFamilyTasks = fetchCompletedFamilyTasks(on: now)
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
            reminders: reminders,
            familyTasks: activeFamilyTasks + completedFamilyTasks,
            activeHumanId: activeHumanID,
            now: now
        )
        try Task.checkCancellation()

        return TaskCenterRouteDataReference(
            snapshot: snapshot,
            eventModelIDs: events.map(\.persistentModelID),
            reminderModelIDs: reminders.map(\.persistentModelID),
            familyTaskModelIDs: activeFamilyTasks.map(\.persistentModelID),
            petModelIDs: pets.map(\.persistentModelID),
            humanModelIDs: humans.map(\.persistentModelID),
            plantModelIDs: plants.map(\.persistentModelID),
            humanMedicationModelIDs: humanMedications.map(\.persistentModelID)
        )
    }

    private func fetchVisibleEvents(now: Date) -> [Event] {
        let calendar = Calendar.current
        let window = CalendarTimelineWindowPolicy.bounds(around: now, calendar: calendar)
        let windowStart = window.start
        let windowEnd = window.end
        var windowedDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.startDate >= windowStart && event.startDate <= windowEnd
            },
            sortBy: [
                SortDescriptor(\.startDate),
                SortDescriptor(\.id)
            ]
        )
        windowedDescriptor.fetchLimit = CalendarTimelineWindowPolicy.windowedEventFetchLimit
        let windowedEvents = fetch(windowedDescriptor, name: "Event.window")

        var recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.recurrenceDays > 0 && event.startDate <= windowEnd
            },
            sortBy: [
                SortDescriptor(\.startDate, order: .reverse),
                SortDescriptor(\.id)
            ]
        )
        recurringDescriptor.fetchLimit = CalendarTimelineWindowPolicy.recurringEventFetchLimit
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

    private func fetchVisibleReminders() -> [Reminder] {
        let pendingStatus = "pending"
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus
            },
            sortBy: [SortDescriptor(\.scheduledAt), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 400
        return fetch(descriptor, name: "Reminder.pending")
    }

    private func fetchActiveFamilyTasks() -> [FamilyCollaborationTask] {
        let active = FamilyCollaborationTaskStatus.active.rawValue
        let claimed = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReview = FamilyCollaborationTaskStatus.pendingReview.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.statusRaw == active ||
                    task.statusRaw == claimed ||
                    task.statusRaw == pendingReview
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 300
        return fetch(descriptor, name: "FamilyCollaborationTask.active")
    }

    private func fetchCompletedFamilyTasks(on date: Date) -> [FamilyCollaborationTask] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let completed = FamilyCollaborationTaskStatus.completed.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.statusRaw == completed &&
                    task.updatedAt >= dayStart &&
                    task.updatedAt < dayEnd
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = Self.completedFamilyTaskFetchLimit
        return fetch(descriptor, name: "FamilyCollaborationTask.completedToday").filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= dayStart && completedAt < dayEnd
        }
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
