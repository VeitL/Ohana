//
//  CalendarView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct CalendarView: View {
    var preselectedPetId: String?
    var preselectedHumanId: String?
    var hideToolbar: Bool = false
    var showsEmbeddedControls: Bool = false
    var addEventTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onRequestAddEvent: (([Plant]) -> Void)?
    var onEmbeddedScrollOffsetChange: ((CGFloat) -> Void)?
    var onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onCompleteEvent: ((Event, Date, String?) -> Bool)?
    var events: [Event] = []
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var insurances: [PetInsurance] = []
    var petMedications: [PetMedication] = []
    var humanMedications: [HumanMedication] = []
    var dataRevision = 0
    var routePreparedSnapshotReferences: [CalendarRoutePreparedSnapshotReference] = []

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices

    @State var selectedDate = Date()
    @AppStorage("calendar_filterPetId") var calendarFilterPetId: String = ""
    @AppStorage("calendar_filterHumanId") var calendarFilterHumanId: String = ""
    @AppStorage("calendar_filterPlantId") var calendarFilterPlantId: String = ""
    @State var showingAddEvent = false
    @AppStorage("currentActiveHumanId") var activeHumanIdStr = ""
    @AppStorage("calendar_viewMode") var viewModeRaw: String = CalendarViewMode.list.rawValue
    @State var displayedViewModeRaw: String?
    var viewMode: CalendarViewMode { CalendarViewMode(rawValue: displayedViewModeRaw ?? viewModeRaw) ?? .list }
    @State var visualFilterSelection = CalendarFilterSelection.all
    @State var appliedFilterSelection = CalendarFilterSelection.all
    @State var didSyncCalendarFilter = false
    @State var hasUserOverriddenRouteFilter = false
    @State var deletingEvent: Event? = nil
    @State var eventDetailPresentation: CalendarEventDetailPresentation?
    @State var pendingActionHumanConfirmation: ActionHumanConfirmationDraft?
    @State var personalUpgradePrompt: PersonalUpgradePrompt?
    @State var showDeleteSeriesAlert = false
    @Environment(\.colorScheme) var colorScheme
    @StateObject var visibleDateCoordinator = CalendarVisibleDateCoordinator()
    @StateObject var timelinePositionCoordinator = CalendarTimelinePositionCoordinator()
    @State var listVisibleTopDate = Calendar.current.startOfDay(for: Date())
    @State var visibleTimelineDateID: String? = CalendarView.todayTimelineDateID
    @State var timelineTodayScrollRequest = 0
    @State var didScrollListToToday = false
    @State var pendingFilterTimelineAnchorDate: Date?
    @State var viewModeCommitTask: Task<Void, Never>?
    @State var filterApplyTask: Task<Void, Never>?
    @State var filterStorageCommitTask: Task<Void, Never>?
    @State var calendarMaintenanceTask: Task<Void, Never>?
    @State var listInitialPositionTask: Task<Void, Never>?
    @State var isCalendarMainContentMounted = false
    @State var calendarMainContentMountTask: Task<Void, Never>?
    @State var preparedCalendarSnapshot = CalendarPreparedSnapshot.empty
    @State var preparedCalendarSnapshotKey: CalendarPreparedSnapshotTriggerKey?
    @State var preparedCalendarSnapshotTask: Task<Void, Never>?
    @State var preparedCalendarSnapshotGeneration = 0
    @State var embeddedBottomChromeBaselineOffset: CGFloat?
    @State var didScheduleCalendarMaintenance = false
    @State var calendarOpenStartedAt: CFAbsoluteTime?
    @State var addEventFlowStartedAt: CFAbsoluteTime?

    var isMaterial: Bool { false }
    var matBg: Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    var chipAccent: Color { Color.goPrimary }
    var chipSelFg: Color { Color.arkInk }
    // 独立日历页下自适应 light/dark 的文字颜色辅助
    var classicSoftText: Color { colorScheme == .dark ? .white.opacity(0.4) : .secondary }
    var classicPrimaryText: Color { colorScheme == .dark ? .white.opacity(0.85) : .primary }
    var classicSubtleFill: Color { colorScheme == .dark ? .white.opacity(0.1) : .primary.opacity(0.07) }
    var classicDotFill: Color { colorScheme == .dark ? .white.opacity(0.12) : .primary.opacity(0.12) }
    var classicLineColors: [Color] { colorScheme == .dark ? [.white.opacity(0.35), .white.opacity(0.06)] : [.primary.opacity(0.2), .primary.opacity(0.04)] }
    var calendarHeaderDate: Date {
        viewMode == .list ? listVisibleTopDate : selectedDate
    }

    static var todayTimelineDateID: String {
        String(Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970))
    }

    var isCalendarPrepared: Bool {
        isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive
    }

    var shouldRenderCalendarMainContent: Bool {
        CalendarEmbeddedContentMountPolicy.shouldRenderMainContent(
            hideToolbar: hideToolbar,
            isEmbeddedPrepared: isEmbeddedPrepared,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive,
            isContentMounted: isCalendarMainContentMounted
        )
    }

    var storedFilterSelection: CalendarFilterSelection {
        CalendarFilterSelection(
            petId: calendarFilterPetId,
            humanId: calendarFilterHumanId,
            plantId: calendarFilterPlantId
        )
        .normalizedForUserFilterControls
    }

    var displayedFilterSelection: CalendarFilterSelection {
        if !hasUserOverriddenRouteFilter, let routeFilterSelection {
            return routeFilterSelection
        }
        return didSyncCalendarFilter ? visualFilterSelection : storedFilterSelection
    }

    var chipFilterSelection: CalendarFilterSelection {
        displayedFilterSelection
    }

    var activeFilterSelection: CalendarFilterSelection {
        if !hasUserOverriddenRouteFilter, let routeFilterSelection {
            return routeFilterSelection
        }
        return didSyncCalendarFilter ? appliedFilterSelection : storedFilterSelection
    }

    var routeFilterSelection: CalendarFilterSelection? {
        if let preselectedPetId {
            return .pet(preselectedPetId)
        }
        if let preselectedHumanId {
            return .human(preselectedHumanId)
        }
        return nil
    }

    var effectiveFilterSelection: CalendarFilterSelection {
        activeFilterSelection
    }

    var effectivePetFilterId: String? {
        let selection = effectiveFilterSelection
        if !selection.humanId.isEmpty ||
            !selection.plantId.isEmpty {
            return nil
        }
        return selection.selectedPetId
    }

    var effectiveHumanFilterId: String? {
        let selection = effectiveFilterSelection
        if !selection.petId.isEmpty ||
            !selection.plantId.isEmpty {
            return nil
        }
        return selection.selectedHumanId
    }

    var effectivePlantFilterId: String? {
        let selection = effectiveFilterSelection
        if !selection.petId.isEmpty ||
            !selection.humanId.isEmpty {
            return nil
        }
        return selection.selectedPlantId
    }

    var effectivePlantFilterIncludesAll: Bool {
        let selection = effectiveFilterSelection
        guard selection.petId.isEmpty, selection.humanId.isEmpty else { return false }
        return selection.isAllPlantsSelected
    }

    var contentHandoffState: CalendarContentHandoffState {
        CalendarContentHandoffState(
            viewModeRaw: displayedViewModeRaw ?? viewModeRaw
        )
    }

    var activeHuman: Human? {
        if let id = UUID(uuidString: activeHumanIdStr), let human = humans.first(where: { $0.id == id }) {
            return human
        }
        return humans.first
    }

    var calendarCoconutBalance: Int {
        activeHuman?.coconutBalance ?? humans.reduce(0) { $0 + $1.coconutBalance }
    }

    var preparedCalendarSnapshotTriggerKey: CalendarPreparedSnapshotTriggerKey {
        CalendarPreparedSnapshotTriggerKey(
            monthKey: CalendarSnapshotBuilder.preparedSnapshotWindowKey,
            filter: effectiveFilterSelection,
            dataRevision: dataRevision
        )
    }

    func eventIsRelatedToAnyPlant(_ event: Event) -> Bool {
        guard let plantId = DomainEntityLinkRegistry.plantId(for: event) else { return false }
        return plants.contains { $0.id == plantId }
    }

    /// 首页嵌入时为全局顶栏 + 外层宠物条预留空间。
    var overviewCalendarEmbedTopInset: CGFloat { 98 }

    var shouldShowInlinePetChips: Bool {
        if preselectedPetId != nil || preselectedHumanId != nil {
            return !hideToolbar || isMaterial
        }
        return !hideToolbar || showsEmbeddedControls || isMaterial
    }

    typealias EventOccurrence = CalendarEventOccurrence
    typealias TimelineDateSection = CalendarTimelineDateSection

    var calendarTimelineSnapshot: CalendarTimelineSnapshot {
        preparedCalendarSnapshot.timeline
    }

    var expandedOccurrences: [EventOccurrence] {
        calendarTimelineSnapshot.expandedOccurrences
    }

    var timelineSections: [TimelineDateSection] {
        calendarTimelineSnapshot.sections
    }

    var timelineDates: [Date] {
        calendarTimelineSnapshot.dates
    }

    var timelineDateSignature: String {
        calendarTimelineSnapshot.dateSignature
    }

    var timelineDateIDs: Set<String> {
        calendarTimelineSnapshot.dateIDs
    }

    var eventsForSelectedDate: [Event] {
        preparedCalendarSnapshot.events(for: selectedDate)
    }

    func shouldShowEventOccurrence(_ event: Event, occurrenceDate: Date) -> Bool {
        CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(
            event,
            occurrenceDate: occurrenceDate,
            allEvents: events,
            pets: pets
        )
    }

    // 本周 7 天
    var thisWeekDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        guard let sunday = cal.date(byAdding: .day, value: -daysFromSunday, to: today) else { return [] }
        return (0 ..< 7).compactMap { cal.date(byAdding: .day, value: $0, to: sunday) }
    }

    var body: some View {
        Group {
            if hideToolbar {
                calendarContent
            } else {
                NavigationStack {
                    calendarContent
                }
            }
        }
        .fullScreenCover(item: $eventDetailPresentation) { presentation in
            CalendarEventDetailPage(
                event: presentation.event,
                occurrenceDate: presentation.occurrenceDate,
                pets: pets,
                humans: humans,
                plants: plants,
                allowsEditing: presentation.allowsEditing,
                requiresActionHumanConfirmation: presentation.event.requiresTodayFocusActionHuman,
                onDelete: {
                    eventDetailPresentation = nil
                    schedulePreparedCalendarSnapshotRebuild(delayMilliseconds: 220, force: true)
                },
                onComplete: { executorID in
                    _ = performEventCompletion(
                        presentation.event,
                        occurrenceDate: presentation.occurrenceDate,
                        executorID: executorID
                    )
                }
            )
        }
        .sheet(item: $personalUpgradePrompt) { prompt in
            PersonalPlanView(prompt: prompt)
        }
        .actionHumanConfirmationDialog(draft: $pendingActionHumanConfirmation)
    }
}

#Preview {
    if let modelContainer = try? SharedModelContainer.makePreview() {
        CalendarView()
            .modelContainer(modelContainer)
    }
}
