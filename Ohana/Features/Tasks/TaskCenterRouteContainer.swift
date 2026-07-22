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

private struct TaskCenterSystemJourneyEditorRoute: Identifiable, Equatable {
    let targetID: UUID
    let task: HouseholdStarterJourneyTask
    let destination: TaskCenterSystemDestination
    let checkpoint: HouseholdStarterJourneyCheckpoint?
    let completionWasSatisfiedAtPresentation: Bool

    var id: String {
        "\(targetID.uuidString)-\(task.rawValue)-\(destination.rawValue)-\(checkpoint?.rawValue ?? "action")"
    }
}

struct TaskCenterFamilyTaskDetailRoute: Identifiable {
    let snapshot: TaskCenterFamilyTaskDetailSnapshot

    var id: String {
        "family-task-\(snapshot.taskID.uuidString)"
    }
}

private struct TaskCenterFamilyTaskInboxRoute: Identifiable, Equatable {
    let humanID: UUID

    var id: UUID { humanID }
}

struct TaskCenterRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage(StarterGiftStorageKey.ceremonySeen) private var starterGiftCeremonySeen = false

    @State private var selectedSurface: TaskCenterSurface
    @State var routeData = TaskCenterRouteData()
    @State private var routeDataGeneration = 0
    @State private var dataLoadTask: Task<Void, Never>?
    @State private var revisionReloadTask: Task<Void, Never>?
    @State private var eventDetailPresentation: CalendarEventDetailPresentation?
    @State private var showingAddEvent = false
    @State private var showingAddChoice = false
    @State private var didAutoPresentCreation = false
    @State private var familyTaskActivities: [FamilyTaskActivitySnapshot] = []
    @State private var familyTaskUnreadActivityCount = 0
    @State private var familyTaskInboxRoute: TaskCenterFamilyTaskInboxRoute?
    @State private var familyTaskDetailRoute: TaskCenterFamilyTaskDetailRoute?
    @State var familyTaskEditorRoute: FamilyCollaborationEditorRoute?
    @State private var selectedMemberFilter: TaskCenterMemberFilter?
    @State private var pendingActionHumanConfirmation: ActionHumanConfirmationDraft?
    @State private var systemJourneyItemPresentation: TaskCenterItemSnapshot?
    @State private var systemJourneyEditorPresentation: TaskCenterSystemJourneyEditorRoute?

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
    var onOpenSystemDestination: ((TaskCenterItemSnapshot) -> Void)?
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
        onOpenSystemDestination: ((TaskCenterItemSnapshot) -> Void)? = nil,
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
        self.onOpenSystemDestination = onOpenSystemDestination
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onBadgeChange = onBadgeChange
        self.onDismiss = onDismiss
        _selectedSurface = State(initialValue: initialSurface)
    }

    var body: some View {
        lifecycleContent
    }

    private var taskCenterContent: some View {
        ZStack {
            taskCenterBackground
            taskCenterStack
        }
    }

    @ViewBuilder
    private var taskCenterBackground: some View {
        if presentation == .sheet {
            OhanaAppBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var taskCenterStack: some View {
        VStack(spacing: 0) {
            taskCenterHeader
            taskCenterSelectedSurface
                .contentTransition(.opacity)
        }
    }

    private var taskCenterHeader: some View {
        TaskCenterHeader(
            selectedSurface: $selectedSurface,
            snapshot: headerSnapshot,
            isLoading: !routeData.hasLoaded,
            showsAddButton: true,
            showsCloseButton: presentation == .sheet,
            filterLabel: scopeLabel,
            inboxUnreadCount: familyTaskUnreadActivityCount,
            onOpenInbox: taskCenterInboxAction,
            onAdd: requestAdd,
            onClose: onDismiss
        )
    }

    private var taskCenterInboxAction: (() -> Void)? {
        guard selectedActiveHumanID != nil else { return nil }
        return { openFamilyTaskInbox() }
    }

    @ViewBuilder
    private var taskCenterSelectedSurface: some View {
        switch selectedSurface {
        case .tasks:
            taskListSurface
        case .calendar:
            taskCalendarSurface
        }
    }

    private var taskListSurface: some View {
        TaskCenterView(
            selectedMemberFilter: $selectedMemberFilter,
            snapshot: visibleSnapshot,
            isLoading: !routeData.hasLoaded,
            bottomClearance: presentation == .embeddedHome ? 190 : 42,
            showsDailyProgress: routeContext.scope == .all,
            focusedItemID: focusedItemID,
            focusRequestID: routeContext.focusRequestID,
            onAction: { item, action in
                performTaskAction(item, action: action)
            },
            onClaimSystemJourneyReward: { item in
                claimStarterJourneyReward(for: item)
            },
            onOpen: openTask,
            onScrollOffsetChange: onEmbeddedScrollOffsetChange
        )
    }

    private var taskCalendarSurface: some View {
        VStack(spacing: 0) {
            TaskCenterCalendarWorkflowStrip(
                items: calendarWorkflowItems,
                onOpen: openTask,
                onAction: { item, action in
                    performTaskAction(item, action: action)
                }
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

    private var modalContent: some View {
        taskCenterContent
        .fullScreenCover(item: $eventDetailPresentation) { presentation in
            CalendarEventDetailPage(
                event: presentation.event,
                occurrenceDate: presentation.occurrenceDate,
                pets: routeData.pets,
                humans: routeData.humans,
                plants: routeData.plants,
                allowsEditing: presentation.allowsEditing,
                requiresActionHumanConfirmation: presentation.event.requiresTodayFocusActionHuman,
                onDelete: {
                    eventDetailPresentation = nil
                    scheduleRouteDataLoad(delayMilliseconds: 220, force: true)
                },
                onComplete: { executorID in
                    _ = completeEvent(
                        presentation.event,
                        occurrenceDate: presentation.occurrenceDate,
                        executorID: executorID
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
        .sheet(item: $familyTaskDetailRoute) { route in
            familyTaskDetail(route)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $familyTaskInboxRoute) { route in
            FamilyTaskInboxView(
                activities: familyTaskActivities,
                unreadCount: familyTaskUnreadActivityCount,
                memberName: familyTaskInboxMemberName(route.humanID),
                onOpen: { activity in
                    openFamilyTaskActivity(activity, inboxHumanID: route.humanID)
                },
                onMarkAllRead: {
                    markAllFamilyTaskActivitiesRead(inboxHumanID: route.humanID)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $familyTaskEditorRoute) { route in
            familyTaskEditor(route)
        }
        .sheet(item: $systemJourneyItemPresentation) { item in
            TaskCenterSystemJourneySheet(
                item: item,
                taskState: starterJourneyState(for: item),
                onOpenDestination: { checkpoint in
                    presentSystemJourneyEditor(item, checkpoint: checkpoint)
                },
                onClaim: { claimStarterJourneyReward(for: item) },
                onRecordResolution: { checkpoint, resolution in
                    recordStarterJourneyResolution(
                        for: item,
                        checkpoint: checkpoint,
                        resolution: resolution
                    )
                },
                onClose: {
                    systemJourneyEditorPresentation = nil
                    systemJourneyItemPresentation = nil
                }
            )
            .sheet(
                item: $systemJourneyEditorPresentation,
                onDismiss: {
                    scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
                }
            ) { route in
                systemJourneyEditor(route)
                    .presentationDetents([.large])
                    .presentationContentInteraction(.scrolls)
            }
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
        }
    }

    private var lifecycleContent: some View {
        modalContent
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
        .actionHumanConfirmationDialog(draft: $pendingActionHumanConfirmation)
        .onAppear {
            scheduleRouteDataLoad(delayMilliseconds: routeDataLoadDelayMilliseconds)
            refreshFamilyTaskActivities()
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
        .onChange(of: routeData.snapshot.starterJourney) { _, _ in
            dismissCompletedSystemJourneyEditorIfNeeded()
        }
        .onChange(of: starterGiftCeremonySeen) { _, didSeeCeremony in
            if didSeeCeremony {
                scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
            }
        }
        .onChange(of: appServices.activeHumanSelection.currentHumanId) { _, _ in
            selectedMemberFilter = nil
            familyTaskDetailRoute = nil
            familyTaskInboxRoute = nil
            familyTaskEditorRoute = nil
            refreshFamilyTaskActivities()
            scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
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

    func scheduleRouteDataLoad(delayMilliseconds: UInt64, force: Bool = false) {
        guard presentation == .sheet || isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive else { return }
        guard force || !routeData.hasLoaded else { return }
        if force {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        } else {
            guard dataLoadTask == nil else { return }
        }
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
                let actor = TaskCenterRouteDataActor(modelContainer: container)
                let reference = try await actor.load(
                    loadPlants: loadPlants,
                    activeHumanID: appServices.activeHumanSelection.currentHumanId,
                    systemDestinations: requestedSystemDestinations,
                    starterJourneyEnabled: isStarterJourneyEnabled
                )
                guard !Task.isCancelled, generation == routeDataGeneration else { return }
                let loaded = TaskCenterRouteData(reference: reference, context: modelContext)
                routeData = loaded
                refreshFamilyTaskActivities()
                onPlantsLoaded?(loaded.plants)
                let actionableSnapshot = loaded.snapshot.filtered(for: .actionRequired)
                onBadgeChange?(TaskCenterBadgeSnapshot(snapshot: actionableSnapshot))
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
        action: TaskCenterAvailableAction,
        executorID: String? = nil
    ) -> Bool {
        if executorID == nil,
           item.familyTaskID == nil,
           action == .complete,
           let eventID = item.eventID,
           let event = routeData.events.first(where: { $0.id == eventID }),
           event.requiresTodayFocusActionHuman {
            return requestActionHumanForTask(item, action: action)
        }
        return executeTaskAction(item, action: action, executorID: executorID)
    }

    private func requestActionHumanForTask(
        _ item: TaskCenterItemSnapshot,
        action: TaskCenterAvailableAction
    ) -> Bool {
        let options = routeData.humans.map { human in
            ActionHumanOption(
                id: human.id,
                name: human.name,
                avatarEmoji: human.avatarEmoji,
                isDeceased: human.hasPassedAway
            )
        }
        let eligible = ActionHumanDefaultSelectionPolicy.eligibleHumans(from: options)
        let preferredID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: appServices.activeHumanSelection.currentHumanId.flatMap(UUID.init(uuidString:)),
            humans: options
        )
        guard eligible.count > 1 else {
            return executeTaskAction(item, action: action, executorID: preferredID?.uuidString)
        }
        pendingActionHumanConfirmation = ActionHumanConfirmationDraft(
            actionTitle: item.title,
            humans: eligible,
            preferredHumanID: preferredID
        ) { executorID in
            if executeTaskAction(item, action: action, executorID: executorID) {
                OhanaFeedback.medium()
            }
        }
        // No mutation has happened yet. The task row stays visible while the
        // lightweight confirmation is on screen.
        return false
    }

    private func executeTaskAction(
        _ item: TaskCenterItemSnapshot,
        action: TaskCenterAvailableAction,
        executorID: String?
    ) -> Bool {
        let result = TaskActionCommandExecutor(
            modelContext: modelContext,
            services: appServices
        ).execute(
            TaskActionCommand(
                item: item,
                action: action,
                actingHumanID: executorID.flatMap(UUID.init(uuidString:))
            ),
            events: routeData.events,
            familyTasks: routeData.familyTasks,
            humans: routeData.humans,
            pets: routeData.pets
        )
        guard result.didSucceed else { return false }
        scheduleRouteDataLoad(delayMilliseconds: 180, force: true)
        return true
    }

    private func completeEvent(_ event: Event, occurrenceDate: Date, executorID: String?) -> Bool {
        guard let item = taskCenterItem(for: event, occurrenceDate: occurrenceDate) else {
            return event.isOccurrenceMarkedComplete(on: occurrenceDate)
        }
        if item.workflowStatus == .completed || item.workflowStatus == .pendingReview {
            return true
        }
        if item.availableActions.contains(.submitForReview) {
            return performTaskAction(item, action: .submitForReview, executorID: executorID)
        }
        guard item.availableActions.contains(.complete) else { return false }
        return performTaskAction(item, action: .complete, executorID: executorID)
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
        if let systemDestination = item.systemDestination {
            if systemDestination == .createFirstPet || systemDestination == .claimStarterGift {
                onOpenSystemDestination?(item)
            } else {
                systemJourneyItemPresentation = item
            }
            return
        }
        if let familyTaskID = item.familyTaskID {
            presentFamilyTaskDetail(taskID: familyTaskID, preferredItem: item)
            return
        }
        guard let eventID = item.eventID,
              let event = routeData.events.first(where: { $0.id == eventID }) else {
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

    var activeHumans: [Human] {
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

    var currentHuman: Human? {
        let selectedID = appServices.activeHumanSelection.currentHumanId
        return activeHumans.first { $0.id.uuidString == selectedID } ?? activeHumans.first
    }

    private var visibleSnapshot: TaskCenterSnapshot {
        routeData.snapshot.filtered(for: routeContext.scope)
    }

    private var headerSnapshot: TaskCenterSnapshot {
        guard selectedSurface == .tasks else { return visibleSnapshot }
        let filter = visibleSnapshot.resolvedMemberFilter(explicitSelection: selectedMemberFilter)
        return visibleSnapshot.filtered(for: filter)
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
            item.source != .systemJourney &&
                item.dueAt != nil &&
                (item.source == .familyTask || item.workflowStatus == .pendingReview)
        }
    }

    private var requestedSystemDestinations: Set<TaskCenterSystemDestination> {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "ohana_has_onboarded"),
              defaults.bool(forKey: StarterGiftStorageKey.pending),
              !defaults.bool(forKey: StarterGiftStorageKey.claimed) else { return [] }
        return [.createFirstPet, .claimStarterGift]
    }

    private var isStarterJourneyEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "ohana_has_onboarded"),
              !defaults.bool(forKey: StarterGiftStorageKey.pending) else { return false }
        if defaults.bool(forKey: StarterGiftStorageKey.claimed) {
            return starterGiftCeremonySeen
        }
        // Existing users predate the starter-gift flags. Keep their journey
        // available instead of reclassifying them as a fresh install.
        return true
    }

    private func starterJourneyState(
        for item: TaskCenterItemSnapshot
    ) -> HouseholdStarterJourneyTaskState? {
        guard let task = starterJourneyTask(for: item) else { return nil }
        return routeData.snapshot.starterJourney?.state(for: task)
    }

    private func starterJourneyTask(
        for item: TaskCenterItemSnapshot
    ) -> HouseholdStarterJourneyTask? {
        switch item.systemDestination {
        case .completeHumanProfile: .humanProfile
        case .completeFirstPetProfile: .petProfile
        case .confirmPetIdentityProtection: .identityProtection
        case .confirmPetPreventiveCare: .healthProtection
        case .configureFirstCarePlan: .carePlan
        case .recordFirstCare: .firstCare
        case .createFirstPet, .claimStarterGift, nil: nil
        }
    }
}

// MARK: - System journey

private extension TaskCenterRouteContainer {
    private func presentSystemJourneyEditor(
        _ item: TaskCenterItemSnapshot,
        checkpoint: HouseholdStarterJourneyCheckpoint?
    ) {
        let routedItem = systemJourneyDestinationItem(item, checkpoint: checkpoint)
        guard let task = starterJourneyTask(for: item),
              let targetID = routedItem.subject.id,
              let destination = routedItem.systemDestination else {
            systemJourneyItemPresentation = nil
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
                onOpenSystemDestination?(routedItem)
            }
            return
        }
        systemJourneyEditorPresentation = TaskCenterSystemJourneyEditorRoute(
            targetID: targetID,
            task: task,
            destination: destination,
            checkpoint: checkpoint,
            completionWasSatisfiedAtPresentation: TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
                task: task,
                checkpoint: checkpoint,
                state: routeData.snapshot.starterJourney?.state(for: task)
            )
        )
    }

    private func systemJourneyDestinationItem(
        _ item: TaskCenterItemSnapshot,
        checkpoint: HouseholdStarterJourneyCheckpoint?
    ) -> TaskCenterItemSnapshot {
        guard let task = starterJourneyTask(for: item) else { return item }
        let guide = TaskCenterSystemJourneyGuide(task: task)
        guard let question = guide.questions.first(where: { $0.checkpoint == checkpoint }) else {
            return item
        }
        let destination = guide.systemDestination(for: question)
        guard destination != item.systemDestination else { return item }

        return TaskCenterItemSnapshot(
            id: item.id,
            eventID: item.eventID,
            reminderID: item.reminderID,
            familyTaskID: item.familyTaskID,
            source: item.source,
            systemDestination: destination,
            systemJourneyPresentationState: item.systemJourneyPresentationState,
            title: item.title,
            subject: item.subject,
            eventType: item.eventType,
            symbol: item.symbol,
            occurrenceDate: item.occurrenceDate,
            scheduledAt: item.scheduledAt,
            dueAt: item.dueAt,
            isAllDay: item.isAllDay,
            isRecurring: item.isRecurring,
            urgency: item.urgency,
            workflowStatus: item.workflowStatus,
            availableActions: item.availableActions,
            participantHumanIDs: item.participantHumanIDs,
            createdByMember: item.createdByMember,
            assignedToMember: item.assignedToMember,
            claimedByMember: item.claimedByMember,
            completedByMember: item.completedByMember,
            rewardCoconuts: item.rewardCoconuts
        )
    }

    @ViewBuilder
    private func systemJourneyEditor(_ route: TaskCenterSystemJourneyEditorRoute) -> some View {
        switch route.destination {
        case .completeHumanProfile:
            if let human = routeData.humans.first(where: { $0.id == route.targetID }) {
                NavigationStack {
                    HumanBasicInfoDetailView(
                        human: human,
                        startsEditing: true,
                        onSave: dismissSystemJourneyEditor
                    )
                }
            } else {
                missingSystemJourneyEditorTarget()
            }
        case .completeFirstPetProfile:
            if let pet = routeData.pets.first(where: { $0.id == route.targetID }) {
                NavigationStack {
                    PetBasicInfoDetailView(
                        pet: pet,
                        startsEditing: true,
                        onSave: dismissSystemJourneyEditor,
                        onClose: dismissSystemJourneyEditor
                    )
                }
            } else {
                missingSystemJourneyEditorTarget()
            }
        case .confirmPetIdentityProtection:
            petSystemJourneyEditor(route, destination: .documents)
        case .confirmPetPreventiveCare:
            petSystemJourneyEditor(route, destination: .health(.preventive))
        case .configureFirstCarePlan:
            petSystemJourneyEditor(
                route,
                destination: .food,
                showsFoodCloseButton: true
            )
        case .recordFirstCare:
            petSystemJourneyEditor(route, destination: .feed(true))
        case .createFirstPet, .claimStarterGift:
            missingSystemJourneyEditorTarget()
        }
    }

    private func petSystemJourneyEditor(
        _ route: TaskCenterSystemJourneyEditorRoute,
        destination: AppPetDetailSheetDestination,
        showsFoodCloseButton: Bool = false
    ) -> some View {
        AppPetDetailSheetRouteContainer(
            id: route.targetID,
            destination: destination,
            onMissing: dismissSystemJourneyEditor,
            onDismiss: dismissSystemJourneyEditor,
            showsFoodCloseButton: showsFoodCloseButton
        )
    }

    private func missingSystemJourneyEditorTarget() -> some View {
        Color.clear
            .onAppear(perform: dismissSystemJourneyEditor)
            .accessibilityHidden(true)
    }

    private func dismissSystemJourneyEditor() {
        systemJourneyEditorPresentation = nil
    }

    private func dismissCompletedSystemJourneyEditorIfNeeded() {
        guard let route = systemJourneyEditorPresentation else { return }
        guard !route.completionWasSatisfiedAtPresentation else { return }
        let state = routeData.snapshot.starterJourney?.state(for: route.task)
        guard TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: route.task,
            checkpoint: route.checkpoint,
            state: state
        ) else { return }
        dismissSystemJourneyEditor()
    }

    private func claimStarterJourneyReward(
        for item: TaskCenterItemSnapshot
    ) -> TaskCenterSystemJourneyMutationOutcome {
        guard let task = starterJourneyTask(for: item) else {
            return .failure(L10n.current.tr(
                zh: "这个奖励暂时无法识别，请返回待办后重试。",
                en: "This reward could not be identified. Return to Tasks and try again.",
                de: "Diese Belohnung konnte nicht erkannt werden. Bitte erneut versuchen."
            ))
        }
        let result = HouseholdStarterJourneyService.claim(
            task: task,
            actingHumanID: appServices.activeHumanSelection.currentHumanId,
            context: modelContext,
            questManager: appServices.questManager,
            wallet: appServices.coconutWallet
        )
        switch result {
        case .claimed, .alreadyClaimed:
            systemJourneyItemPresentation = nil
            scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
            return .success
        case .notEligible:
            scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
            return .failure(L10n.current.tr(
                zh: "这项内容还没有完成，请先完善或确认当前状态。",
                en: "This item is not complete yet. Finish it or confirm its current status first.",
                de: "Diese Aufgabe ist noch nicht abgeschlossen. Bitte zuerst ergänzen oder bestätigen."
            ))
        case .missingHuman, .requiresHumanSelection:
            return .failure(L10n.current.tr(
                zh: "请先在首页选择当前家庭成员。",
                en: "Choose the current household member on Home first.",
                de: "Bitte zuerst das aktuelle Haushaltsmitglied auf der Startseite auswählen."
            ))
        case .persistenceFailed:
            return .failure(L10n.current.tr(
                zh: "奖励保存失败，请稍后重试。",
                en: "The reward could not be saved. Please try again.",
                de: "Die Belohnung konnte nicht gespeichert werden. Bitte erneut versuchen."
            ))
        }
    }

    private func recordStarterJourneyResolution(
        for item: TaskCenterItemSnapshot,
        checkpoint: HouseholdStarterJourneyCheckpoint,
        resolution: HouseholdStarterJourneyResolution
    ) -> TaskCenterSystemJourneyMutationOutcome {
        guard let task = starterJourneyTask(for: item),
              let subjectID = item.subject.id else {
            return .failure(L10n.current.tr(
                zh: "找不到需要确认的家庭成员，请返回待办后重试。",
                en: "The member to review could not be found. Return to Tasks and try again.",
                de: "Das zu prüfende Mitglied wurde nicht gefunden. Bitte erneut versuchen."
            ))
        }
        let result = HouseholdStarterJourneyService.recordResolution(
            task: task,
            checkpoint: checkpoint,
            resolution: resolution,
            subjectID: subjectID,
            actingHumanID: appServices.activeHumanSelection.currentHumanId,
            context: modelContext
        )
        guard result.didSucceed else {
            return .failure(L10n.current.tr(
                zh: "当前状态没有保存，请检查家庭成员后重试。",
                en: "The current status was not saved. Check the household member and try again.",
                de: "Der aktuelle Status wurde nicht gespeichert. Bitte erneut versuchen."
            ))
        }
        scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
        return .success
    }
}

// MARK: - Family task detail

extension TaskCenterRouteContainer {
    func familyTaskDetail(_ route: TaskCenterFamilyTaskDetailRoute) -> some View {
        FamilyTaskDetailView(
            snapshot: route.snapshot,
            onEdit: route.snapshot.capabilities.canEdit ? {
                presentFamilyTaskEditorAfterDetail(taskID: route.snapshot.taskID)
            } : nil,
            onTaskAction: { action in
                performFamilyTaskDetailAction(taskID: route.snapshot.taskID, action: action)
            },
            onDecline: { reason in
                declineFamilyTask(taskID: route.snapshot.taskID, reason: reason)
            },
            onPostpone: { dueAt in
                postponeFamilyTask(taskID: route.snapshot.taskID, to: dueAt)
            },
            onComment: { body in
                commentOnFamilyTask(taskID: route.snapshot.taskID, body: body)
            },
            onCancel: { scope in
                await cancelFamilyTask(taskID: route.snapshot.taskID, scope: scope)
            }
        )
    }

    func presentFamilyTaskDetail(
        taskID: UUID,
        preferredItem: TaskCenterItemSnapshot? = nil
    ) {
        guard let task = familyTaskModel(id: taskID) else { return }
        familyTaskDetailRoute = makeFamilyTaskDetailRoute(task: task, preferredItem: preferredItem)
    }

    func makeFamilyTaskDetailRoute(
        task: FamilyCollaborationTask,
        preferredItem: TaskCenterItemSnapshot?
    ) -> TaskCenterFamilyTaskDetailRoute {
        let latestItem = preferredItem.flatMap { preferred in
            routeData.snapshot.allItems.first(where: { $0.id == preferred.id }) ?? preferred
        } ?? routeData.snapshot.allItems.first(where: { $0.familyTaskID == task.id })
        let capabilities = FamilyTaskCapabilities.resolve(
            task: task,
            currentHumanID: selectedActiveHumanID
        )
        var actions: Set<TaskCenterAvailableAction> = []
        if capabilities.canComplete {
            actions.insert(task.hasReward ? .submitForReview : .complete)
        }
        if capabilities.canApprove { actions.insert(.approve) }
        if capabilities.canReturnForRedo { actions.insert(.reject) }
        if task.status == .active,
           task.isOpen,
           selectedActiveHumanID != nil,
           latestItem?.availableActions.contains(.claim) == true {
            actions.insert(.claim)
        }

        return TaskCenterFamilyTaskDetailRoute(
            snapshot: TaskCenterFamilyTaskDetailSnapshot(
                taskID: task.id,
                title: task.title,
                note: task.note,
                emoji: task.emoji,
                creatorName: task.createdByName,
                assigneeName: task.claimedByName ?? task.assignedToName,
                viewerRole: familyTaskViewerRole(for: task),
                capabilities: capabilities,
                status: task.status,
                dueAt: task.dueAt ?? latestItem?.dueAt,
                isAllDay: latestItem?.isAllDay ?? false,
                isRecurring: latestItem?.isRecurring == true || task.planId != nil,
                allowsThisAndFutureCancellation: task.planId != nil && task.nominalAt != nil,
                rewardCoconuts: task.rewardCoconuts,
                availableActions: actions,
                isLinkedToCalendar: latestItem?.eventID != nil || task.relatedEventId != nil,
                activities: FamilyTaskActivityService.occurrenceTimeline(
                    taskID: task.id,
                    context: modelContext
                )
            )
        )
    }

    func familyTaskViewerRole(
        for task: FamilyCollaborationTask
    ) -> TaskCenterFamilyTaskViewerRole {
        guard let selectedHumanID = selectedActiveHumanID else {
            return .familyMember
        }
        if UUID(uuidString: task.createdById) == selectedHumanID {
            return .creator
        }
        if task.claimedById.flatMap(UUID.init(uuidString:)) == selectedHumanID ||
            task.assignedToId.flatMap(UUID.init(uuidString:)) == selectedHumanID {
            return .assignee
        }
        return .familyMember
    }

    func canSelectedHumanEdit(_ task: FamilyCollaborationTask) -> Bool {
        FamilyTaskCapabilities.resolve(
            task: task,
            currentHumanID: selectedActiveHumanID
        ).canEdit
    }

    func presentFamilyTaskEditorAfterDetail(taskID: UUID) {
        familyTaskDetailRoute = nil
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            guard let task = familyTaskModel(id: taskID),
                  canSelectedHumanEdit(task) else { return }
            if !routeData.familyTasks.contains(where: { $0.id == taskID }) {
                routeData.familyTasks.append(task)
            }
            familyTaskEditorRoute = .editTask(taskID)
        }
    }

    func performFamilyTaskDetailAction(
        taskID: UUID,
        action: TaskCenterAvailableAction
    ) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand() else { return false }
        let capabilities = FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id)
        let didSucceed: Bool
        switch action {
        case .complete, .submitForReview:
            guard capabilities.canComplete else { return false }
            didSucceed = familyTaskCommandExecutor.complete(task, by: human)
        case .claim:
            didSucceed = familyTaskCommandExecutor.claim(task, by: human)
        case .approve:
            guard capabilities.canApprove else { return false }
            didSucceed = familyTaskCommandExecutor.confirmCompletion(task, by: human)
        case .reject:
            guard capabilities.canReturnForRedo else { return false }
            didSucceed = familyTaskCommandExecutor.rejectCompletion(task, by: human)
        }
        return finishFamilyTaskMutation(didSucceed, taskID: taskID)
    }

    func declineFamilyTask(taskID: UUID, reason: String) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canDecline else {
            return false
        }
        return finishFamilyTaskMutation(
            familyTaskCommandExecutor.declineAssignment(task, by: human, reason: reason),
            taskID: taskID
        )
    }

    func postponeFamilyTask(taskID: UUID, to dueAt: Date) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canPostpone else {
            return false
        }
        return finishFamilyTaskMutation(
            familyTaskCommandExecutor.postponeOccurrence(task, to: dueAt, by: human),
            taskID: taskID
        )
    }

    func commentOnFamilyTask(taskID: UUID, body: String) -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canComment else {
            return false
        }
        let idempotencyKey = "family-task:\(taskID.uuidString):comment:\(human.id.uuidString):\(UUID().uuidString)"
        return finishFamilyTaskMutation(
            familyTaskCommandExecutor.addComment(
                task,
                body: body,
                by: human,
                idempotencyKey: idempotencyKey
            ),
            taskID: taskID
        )
    }

    func cancelFamilyTask(
        taskID: UUID,
        scope: FamilyTaskEditScope
    ) async -> Bool {
        guard let task = familyTaskModel(id: taskID),
              let human = selectedHumanForFamilyTaskCommand(),
              FamilyTaskCapabilities.resolve(task: task, currentHumanID: human.id).canCancel else {
            return false
        }
        switch scope {
        case .onlyThis:
            return finishFamilyTaskMutation(
                familyTaskCommandExecutor.cancelTask(task, by: human),
                taskID: taskID
            )
        case .thisAndFuture:
            guard let rawPlanID = task.planId,
                  let planID = UUID(uuidString: rawPlanID),
                  let nominalAt = task.nominalAt else { return false }
            let didSucceed = await familyTaskCommandExecutor.cancelThisAndFuture(
                planID: planID,
                from: nominalAt,
                by: human
            )
            guard didSucceed else { return false }
            refreshFamilyTaskActivities()
            scheduleRouteDataLoad(delayMilliseconds: 0, force: true)
            return true
        }
    }

    func finishFamilyTaskMutation(_ didSucceed: Bool, taskID: UUID) -> Bool {
        guard didSucceed else { return false }
        if familyTaskDetailRoute?.snapshot.taskID == taskID,
           let task = familyTaskModel(id: taskID) {
            familyTaskDetailRoute = makeFamilyTaskDetailRoute(task: task, preferredItem: nil)
        }
        refreshFamilyTaskActivities()
        scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        return true
    }

    var familyTaskCommandExecutor: FamilyCollaborationCommandExecutor {
        FamilyCollaborationCommandExecutor(
            modelContext: modelContext,
            familyTasks: appServices.familyTasks,
            revisions: appServices.domainRevisions
        )
    }

    var selectedActiveHumanID: UUID? {
        appServices.activeHumanSelection.currentHumanId.flatMap(UUID.init(uuidString:))
    }

    func selectedHumanForFamilyTaskCommand() -> Human? {
        guard let selectedActiveHumanID else { return nil }
        return routeData.humans.first { $0.id == selectedActiveHumanID && !$0.hasPassedAway }
    }

    func familyTaskModel(id: UUID) -> FamilyCollaborationTask? {
        routeData.familyTasks.first { $0.id == id }
    }
}

// MARK: - Family task inbox

private extension TaskCenterRouteContainer {
    func refreshFamilyTaskActivities() {
        guard let humanID = selectedActiveHumanID else {
            familyTaskActivities = []
            familyTaskUnreadActivityCount = 0
            familyTaskInboxRoute = nil
            return
        }
        if let route = familyTaskInboxRoute, route.humanID != humanID {
            familyTaskInboxRoute = nil
        }
        familyTaskActivities = FamilyTaskActivityService.inbox(
            recipientHumanID: humanID,
            context: modelContext
        )
        familyTaskUnreadActivityCount = FamilyTaskActivityService.unreadCount(
            recipientHumanID: humanID,
            context: modelContext
        )
    }

    func openFamilyTaskInbox() {
        guard let humanID = selectedActiveHumanID else { return }
        refreshFamilyTaskActivities()
        familyTaskInboxRoute = TaskCenterFamilyTaskInboxRoute(humanID: humanID)
        OhanaFeedback.light()
    }

    func familyTaskInboxMemberName(_ humanID: UUID) -> String {
        routeData.humans.first(where: { $0.id == humanID })?.name
            ?? L10n.current.tr(zh: "当前成员", en: "Current member", de: "Aktuelles Mitglied")
    }

    func openFamilyTaskActivity(
        _ activity: FamilyTaskActivitySnapshot,
        inboxHumanID: UUID
    ) {
        guard selectedActiveHumanID == inboxHumanID,
              activity.recipientHumanID == inboxHumanID else { return }
        if activity.isUnread {
            _ = FamilyTaskActivityService.markRead(
                activityID: activity.id,
                recipientHumanID: inboxHumanID,
                context: modelContext
            )
        }
        refreshFamilyTaskActivities()
        if let task = familyTaskModel(for: activity) {
            presentFamilyTaskActivity(task, inboxHumanID: inboxHumanID)
            return
        }

        Task { @MainActor in
            let loader = TaskCenterRouteDataActor(modelContainer: modelContext.container)
            let modelID = try? await loader.resolveFamilyTaskModelID(
                taskID: activity.taskID,
                occurrenceKey: activity.occurrenceKey,
                planID: activity.planID
            )
            guard !Task.isCancelled,
                  selectedActiveHumanID == inboxHumanID,
                  familyTaskInboxRoute?.humanID == inboxHumanID,
                  let modelID,
                  let task = modelContext.model(for: modelID) as? FamilyCollaborationTask else { return }
            presentFamilyTaskActivity(task, inboxHumanID: inboxHumanID)
        }
    }

    func presentFamilyTaskActivity(
        _ task: FamilyCollaborationTask,
        inboxHumanID: UUID
    ) {
        let nextRoute = makeFamilyTaskDetailRoute(task: task, preferredItem: nil)
        familyTaskInboxRoute = nil
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 160) {
            guard selectedActiveHumanID == inboxHumanID else { return }
            familyTaskDetailRoute = nextRoute
        }
    }

    func familyTaskModel(for activity: FamilyTaskActivitySnapshot) -> FamilyCollaborationTask? {
        if let taskID = activity.taskID, let task = familyTaskModel(id: taskID) {
            return task
        }
        if let occurrenceKey = activity.occurrenceKey {
            if let task = routeData.familyTasks.first(where: { $0.occurrenceKey == occurrenceKey }) {
                return task
            }
        }
        guard let planID = activity.planID else { return nil }
        let rawPlanID = planID.uuidString
        let tasks = routeData.familyTasks
            .filter { $0.planId == rawPlanID }
            .sorted { ($0.nominalAt ?? .distantPast) > ($1.nominalAt ?? .distantPast) }
        return tasks.first(where: { !$0.isFinished }) ?? tasks.first
    }

    func markAllFamilyTaskActivitiesRead(inboxHumanID: UUID) {
        guard selectedActiveHumanID == inboxHumanID else { return }
        for _ in 0 ..< 20 {
            let markedCount = FamilyTaskActivityService.markAllRead(
                recipientHumanID: inboxHumanID,
                context: modelContext
            )
            if markedCount == 0 { break }
        }
        refreshFamilyTaskActivities()
    }
}
