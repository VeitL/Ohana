//
//  CalendarView+Content.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CalendarView {
    @ViewBuilder
    var calendarContent: some View {
        if hideToolbar {
            calendarContentBody
        } else {
            calendarContentBody
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var calendarContentBody: some View {
        ZStack(alignment: .top) {
            if !hideToolbar {
                OhanaAppBackground()
            }

            VStack(spacing: 0) {
                if isMaterial {
                    // Material 模式：为 sticky header 留空间
                    Spacer().frame(height: 68)
                } else if !hideToolbar {
                    // 独立页面时显示顶栏；嵌入首页时由外层 header 负责。
                    classicCalendarHeader
                } else if showsEmbeddedControls {
                    embeddedCalendarHeader
                } else {
                    // 首页嵌入：为全局顶栏 + 外层宠物筛选条留出空间
                    Spacer().frame(height: overviewCalendarEmbedTopInset)
                }

                if shouldShowInlinePetChips {
                    CalendarPetChipFilterBar(
                        selection: chipFilterSelection,
                        pets: pets,
                        humans: humans,
                        plants: plants,
                        onSelect: selectCalendarFilter
                    )
                }

                Group {
                    if shouldRenderCalendarMainContent {
                        switch viewMode {
                        case .month:
                            goMonthView
                        case .list:
                            goListView
                        }
                    } else {
                        calendarDeferredContentPlaceholder
                    }
                }
                .ohanaContextHandoff(
                    contentHandoffState,
                    direction: .neutral,
                    isVisible: isEmbeddedVisible || !hideToolbar,
                    initialScale: 0.996
                )
            }

            // Material 模式 Sticky Header
            if isMaterial {
                calStickyHeader
            }
        }
        .overlay { inlineAddEventLayer }
        .onChange(of: addEventTrigger) { _, _ in requestAddEventPresentation() }
        .onChange(of: viewModeRaw) { _, newValue in
            syncCalendarViewModeFromStorage(newValue)
        }
        .onChange(of: calendarFilterPetId) { _, _ in
            syncCalendarFilterFromStorage(animated: true)
        }
        .onChange(of: calendarFilterHumanId) { _, _ in
            syncCalendarFilterFromStorage(animated: true)
        }
        .onChange(of: calendarFilterPlantId) { _, _ in
            syncCalendarFilterFromStorage(animated: true)
        }
        .onChange(of: preselectedPetId) { _, _ in
            resetRouteFilterOverride()
        }
        .onChange(of: preselectedHumanId) { _, _ in
            resetRouteFilterOverride()
        }
        .onChange(of: preselectedPlantId) { _, _ in
            resetRouteFilterOverride()
        }
        .onAppear {
            recordCalendarOpen()
            syncCalendarViewModeFromStorage(viewModeRaw)
            syncCalendarFilterFromStorage(animated: false)
            scheduleCalendarMainContentMountIfNeeded()
            if isCalendarPrepared, viewMode == .list {
                scheduleInitialListPositionIfNeeded()
            }
            if isCalendarPrepared {
                scheduleCalendarMaintenance()
            }
        }
        .onDisappear {
            resetEmbeddedBottomChromeScrollBaseline()
            cancelPendingCalendarMaintenance()
            filterApplyTask?.cancel()
            filterStorageCommitTask?.cancel()
            listInitialPositionTask?.cancel()
            listInitialPositionTask = nil
            timelinePositionCoordinator.cancel()
            addEventPresentationTask?.cancel()
            addEventContentMountTask?.cancel()
            cancelPendingCalendarMainContentMount(resetMountedState: true)
        }
        .onChange(of: isEmbeddedActive) { _, isActive in
            if isActive {
                scheduleCalendarMainContentMountIfNeeded()
                scheduleCalendarMaintenance()
                if viewMode == .list {
                    scheduleInitialListPositionIfNeeded()
                }
            } else if !isCalendarPrepared {
                cancelPendingCalendarMainContentMount(resetMountedState: true)
                cancelPendingCalendarMaintenance()
                listInitialPositionTask?.cancel()
                listInitialPositionTask = nil
                timelinePositionCoordinator.cancel()
            }
        }
        .onChange(of: isEmbeddedPrepared) { _, isPrepared in
            if isPrepared {
                scheduleCalendarMainContentMountIfNeeded()
                scheduleCalendarMaintenance()
                if viewMode == .list {
                    scheduleInitialListPositionIfNeeded()
                }
            } else if !isEmbeddedVisible, !isEmbeddedActive {
                cancelPendingCalendarMainContentMount(resetMountedState: true)
                cancelPendingCalendarMaintenance()
                listInitialPositionTask?.cancel()
                listInitialPositionTask = nil
                timelinePositionCoordinator.cancel()
            }
        }
        .onChange(of: isEmbeddedVisible) { _, isVisible in
            if isVisible {
                syncCalendarViewModeFromStorage(viewModeRaw)
                scheduleCalendarMainContentMountIfNeeded()
                scheduleCalendarMaintenance()
                if viewMode == .list {
                    scheduleInitialListPositionIfNeeded()
                }
            } else if !isEmbeddedPrepared, !isEmbeddedActive {
                cancelPendingCalendarMainContentMount(resetMountedState: true)
                cancelPendingCalendarMaintenance()
                listInitialPositionTask?.cancel()
                listInitialPositionTask = nil
                timelinePositionCoordinator.cancel()
            }
        }
    }

    @ViewBuilder
    var inlineAddEventLayer: some View {
        if showingAddEvent || addEventPresentationProgress > 0.001 {
            OhanaDeferredInlinePageCover(
                progress: addEventPresentationProgress,
                isContentMounted: isAddEventContentMounted,
                reservesSafeArea: false
            ) {
                AddEventView(onClose: closeInlineAddEvent, plants: plants)
            }
            .zIndex(90)
        }
    }

    var calendarDeferredContentPlaceholder: some View {
        VStack(spacing: 12) {
            ForEach(0 ..< 5, id: \.self) { index in
                RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                    .fill(Color.ohanaControlFill.opacity(index == 0 ? 0.84 : 0.58))
                    .frame(height: index == 0 ? 50 : 58) // a11y: allow fixed-format noninteractive loading row
                    .overlay(alignment: .leading) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.ohanaControlFill)
                                .frame(width: 32, height: 32) // a11y: allow fixed-format decorative loading dot
                            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                                .fill(Color.ohanaControlFill)
                                .frame(width: index == 0 ? 116 : 168, height: 12) // a11y: allow fixed-format skeleton line
                        }
                        .padding(.horizontal, 14)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, timelineBottomClearance)
        .accessibilityHidden(true)
    }

    func requestAddEventPresentation() {
        OhanaFeedback.light()
        if let onRequestAddEvent {
            onRequestAddEvent(plants)
        } else {
            openInlineAddEvent()
        }
    }

    func openInlineAddEvent() {
        guard !showingAddEvent else { return }
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.calendarAddEventSheet,
            note: ["source": hideToolbar ? "embedded" : "standalone"]
        )
        addEventFlowStartedAt = startedAt
        addEventPresentationTask?.cancel()
        addEventContentMountTask?.cancel()
        showingAddEvent = true
        addEventPresentationProgress = 0
        isAddEventContentMounted = false
        AppFlowPerformance.mark(
            AppPerformanceFlows.calendarAddEventSheet,
            AppPerformancePhases.shellReady,
            startedAt: startedAt
        )
        addEventPresentationTask = OhanaFrameScheduler.runAfterNextFrame {
            guard showingAddEvent else {
                addEventPresentationTask = nil
                return
            }
            withAnimation(GoMotion.sheetEnter) {
                addEventPresentationProgress = 1
            }
            addEventPresentationTask = nil
        }
        addEventContentMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            guard showingAddEvent else {
                addEventContentMountTask = nil
                return
            }
            withAnimation(GoMotion.quick) {
                isAddEventContentMounted = true
            }
            AppFlowPerformance.mark(
                AppPerformanceFlows.calendarAddEventSheet,
                AppPerformancePhases.contentMounted,
                startedAt: startedAt
            )
            addEventContentMountTask = nil
        }
    }

    func closeInlineAddEvent() {
        guard showingAddEvent || addEventPresentationProgress > 0.001 else { return }
        addEventContentMountTask?.cancel()
        isAddEventContentMounted = false
        withAnimation(GoMotion.sheetEnter) {
            addEventPresentationProgress = 0
        }
        addEventPresentationTask?.cancel()
        addEventPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 340) {
            guard addEventPresentationProgress <= 0.02 else {
                addEventPresentationTask = nil
                return
            }
            if let addEventFlowStartedAt {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.calendarAddEventSheet,
                    AppPerformancePhases.routeDismiss,
                    startedAt: addEventFlowStartedAt
                )
            }
            showingAddEvent = false
            isAddEventContentMounted = false
            addEventFlowStartedAt = nil
            addEventPresentationTask = nil
        }
    }

    func reconcileDefaultPlanOverrides() {
        for pet in pets {
            CarePlanCalendarSync.reconcileDefaultPlanOverrides(for: pet, context: modelContext)
        }
    }

    func scheduleCalendarMaintenance() {
        guard isCalendarPrepared else { return }
        guard !didScheduleCalendarMaintenance else { return }
        didScheduleCalendarMaintenance = true
        calendarMaintenanceTask?.cancel()
        let delayMilliseconds: UInt64 = isEmbeddedActive ? (hideToolbar ? 220 : 90) : (hideToolbar ? 60 : 30)
        calendarMaintenanceTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            reconcileDefaultPlanOverrides()
            calendarMaintenanceTask = nil
        }
    }

    func cancelPendingCalendarMaintenance() {
        if calendarMaintenanceTask != nil {
            didScheduleCalendarMaintenance = false
        }
        calendarMaintenanceTask?.cancel()
        calendarMaintenanceTask = nil
    }

    func scheduleCalendarMainContentMountIfNeeded() {
        guard CalendarEmbeddedContentMountPolicy.shouldScheduleDeferredMount(
            hideToolbar: hideToolbar,
            isEmbeddedPrepared: isEmbeddedPrepared,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive,
            isContentMounted: isCalendarMainContentMounted
        ) else { return }
        guard calendarMainContentMountTask == nil else { return }

        let delayMilliseconds = CalendarEmbeddedContentMountPolicy
            .contentDelayMilliseconds(isEmbeddedActive: isEmbeddedActive)
        calendarMainContentMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            guard isCalendarPrepared else {
                calendarMainContentMountTask = nil
                return
            }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isCalendarMainContentMounted = true
            }
            calendarMainContentMountTask = nil
        }
    }

    func cancelPendingCalendarMainContentMount(resetMountedState: Bool) {
        calendarMainContentMountTask?.cancel()
        calendarMainContentMountTask = nil
        guard resetMountedState, isCalendarMainContentMounted else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isCalendarMainContentMounted = false
        }
    }

    func selectCalendarViewMode(_ mode: CalendarViewMode) {
        guard viewMode != mode else { return }
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.calendarModeSwitch,
            note: ["to": mode.rawValue]
        )
        resetEmbeddedBottomChromeScrollBaseline()
        withAnimation(GoMotion.selection) {
            displayedViewModeRaw = mode.rawValue
        }
        AppFlowPerformance.mark(
            AppPerformanceFlows.calendarModeSwitch,
            AppPerformancePhases.firstFrame,
            startedAt: startedAt,
            note: ["to": mode.rawValue]
        )
        if mode == .list {
            resetCalendarListPositionForModeSwitch()
        }
        scheduleCalendarViewModeStorageCommit(mode)
    }

    func syncCalendarViewModeFromStorage(_ rawValue: String) {
        guard let newMode = CalendarViewMode(rawValue: rawValue) else { return }
        guard displayedViewModeRaw != rawValue else { return }
        let previousMode = CalendarViewMode(rawValue: displayedViewModeRaw ?? viewModeRaw)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedViewModeRaw = rawValue
        }
        if previousMode != newMode {
            resetEmbeddedBottomChromeScrollBaseline()
        }
        if previousMode != .list, newMode == .list {
            resetCalendarListPositionForModeSwitch()
        }
    }

    func scheduleCalendarViewModeStorageCommit(_ mode: CalendarViewMode) {
        viewModeCommitTask?.cancel()
        viewModeCommitTask = OhanaFrameScheduler.runAfterNextFrame {
            guard viewModeRaw != mode.rawValue else {
                viewModeCommitTask = nil
                return
            }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                viewModeRaw = mode.rawValue
            }
            viewModeCommitTask = nil
        }
    }

    func selectCalendarFilter(_ selection: CalendarFilterSelection) {
        guard displayedFilterSelection != selection else { return }
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.calendarFilter,
            note: ["scope": selection.metricScope]
        )
        withAnimation(GoMotion.selection) {
            if routeFilterSelection != nil {
                hasUserOverriddenRouteFilter = true
            }
            visualFilterSelection = selection
            didSyncCalendarFilter = true
        }
        AppFlowPerformance.mark(
            AppPerformanceFlows.calendarFilter,
            AppPerformancePhases.firstFrame,
            startedAt: startedAt
        )
        scheduleCalendarFilterApply(selection)
    }

    func recordCalendarOpen() {
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.calendarOpen,
            note: ["source": hideToolbar ? "embedded" : "standalone", "mode": viewMode.rawValue]
        )
        calendarOpenStartedAt = startedAt
        AppFlowPerformance.mark(
            AppPerformanceFlows.calendarOpen,
            AppPerformancePhases.shellReady,
            startedAt: startedAt,
            note: ["prepared": isCalendarPrepared ? "true" : "false"]
        )
        OhanaFrameScheduler.runAfterNextFrame {
            guard calendarOpenStartedAt == startedAt else { return }
            AppFlowPerformance.mark(
                AppPerformanceFlows.calendarOpen,
                AppPerformancePhases.firstFrame,
                startedAt: startedAt,
                note: ["prepared": isCalendarPrepared ? "true" : "false"]
            )
        }
    }

    func resetRouteFilterOverride() {
        guard hasUserOverriddenRouteFilter else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hasUserOverriddenRouteFilter = false
        }
    }

    func reportEmbeddedBottomChromeScrollOffset(_ scrollOffset: CGFloat, canEstablishBaseline: Bool = true) {
        guard hideToolbar else { return }
        guard canEstablishBaseline else { return }

        let clampedOffset = max(0, scrollOffset)
        guard let baseline = embeddedBottomChromeBaselineOffset else {
            embeddedBottomChromeBaselineOffset = clampedOffset
            onEmbeddedScrollOffsetChange?(0)
            return
        }

        onEmbeddedScrollOffsetChange?(max(0, clampedOffset - baseline))
    }

    func resetEmbeddedBottomChromeScrollBaseline() {
        embeddedBottomChromeBaselineOffset = nil
        onEmbeddedScrollOffsetChange?(0)
    }

    func syncCalendarFilterFromStorage(animated: Bool) {
        let selection = storedFilterSelection
        guard displayedFilterSelection != selection || activeFilterSelection != selection || !didSyncCalendarFilter else { return }
        filterApplyTask?.cancel()
        filterStorageCommitTask?.cancel()
        didSyncCalendarFilter = true
        if animated {
            withAnimation(GoMotion.selection) {
                visualFilterSelection = selection
            }
            withAnimation(GoMotion.stateChange) {
                appliedFilterSelection = selection
            }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                visualFilterSelection = selection
                appliedFilterSelection = selection
            }
        }
    }

    func scheduleCalendarFilterApply(_ selection: CalendarFilterSelection) {
        filterApplyTask?.cancel()
        filterApplyTask = OhanaFrameScheduler.runAfterNextFrame {
            guard visualFilterSelection == selection else {
                filterApplyTask = nil
                return
            }
            withAnimation(GoMotion.stateChange) {
                appliedFilterSelection = selection
            }
            if viewMode == .list {
                resetCalendarListPositionForModeSwitch()
            }
            filterApplyTask = nil
            scheduleCalendarFilterStorageCommit(selection)
        }
    }

    func scheduleCalendarFilterStorageCommit(_ selection: CalendarFilterSelection) {
        filterStorageCommitTask?.cancel()
        filterStorageCommitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 90) {
            guard appliedFilterSelection == selection else {
                filterStorageCommitTask = nil
                return
            }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                calendarFilterPetId = selection.petId
                calendarFilterHumanId = selection.humanId
                calendarFilterPlantId = selection.plantId
            }
            filterStorageCommitTask = nil
        }
    }

    func resetCalendarListPositionForModeSwitch() {
        resetEmbeddedBottomChromeScrollBaseline()
        listInitialPositionTask?.cancel()
        listInitialPositionTask = nil
        let today = Calendar.current.startOfDay(for: Date())
        let todayID = timelineDateID(today)
        didScrollListToToday = false
        if visibleTimelineDateID != todayID {
            visibleTimelineDateID = todayID
        }
        listVisibleTopDate = today
    }
}
