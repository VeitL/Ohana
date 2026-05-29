//
//  CalendarView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import Combine

enum CalendarViewMode: String, CaseIterable {
    case month = "月"
    case list = "列表"
}

@MainActor
private final class CalendarVisibleDateCoordinator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private var pendingDate: Date?
    private var updateTask: Task<Void, Never>?

    deinit {
        updateTask?.cancel()
    }

    func scheduleUpdate(to date: Date, apply: @escaping @MainActor (Date) -> Void) {
        let normalized = Calendar.current.startOfDay(for: date)
        if let pendingDate,
           Calendar.current.isDate(pendingDate, inSameDayAs: normalized) {
            return
        }
        pendingDate = normalized
        guard updateTask == nil else { return }

        updateTask = OhanaFrameScheduler.runAfterNextFrame { [weak self] in
            guard let self else { return }
            let date = pendingDate
            pendingDate = nil
            updateTask = nil
            guard let date else { return }
            apply(date)
        }
    }
}

private struct CalendarFilterSelection: Equatable {
    var petId: String
    var humanId: String

    static let all = CalendarFilterSelection(petId: "", humanId: "")

    var selectedPetId: String? { petId.isEmpty ? nil : petId }
    var selectedHumanId: String? { humanId.isEmpty ? nil : humanId }

    static func pet(_ id: String) -> CalendarFilterSelection {
        CalendarFilterSelection(petId: id, humanId: "")
    }

    static func human(_ id: String) -> CalendarFilterSelection {
        CalendarFilterSelection(petId: "", humanId: id)
    }
}

private struct CalendarContentHandoffState: Equatable {
    var viewModeRaw: String
    var filter: CalendarFilterSelection
}

/// 日历宠物筛选条：点击时只回传本地视觉选择，持久化由 `CalendarView` 下一帧处理。
private struct CalendarPetChipFilterBar: View {
    let selection: CalendarFilterSelection
    let onSelect: (CalendarFilterSelection) -> Void

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Environment(\.colorScheme) private var colorScheme

    private var isMaterial: Bool { false }
    private var chipAccent: Color { Color.goPrimary }
    private var chipSelFg: Color { Color.arkInk }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var selectedPetId: String? { selection.selectedPetId }
    private var selectedHumanId: String? { selection.selectedHumanId }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "全部", systemImage: "square.grid.2x2.fill", isSelected: selectedPetId == nil && selectedHumanId == nil) {
                    onSelect(.all)
                }
                ForEach(pets) { pet in
                    chipButton(label: pet.name, systemImage: pet.speciesSilhouetteSymbol, isSelected: selectedPetId == pet.id.uuidString) {
                        onSelect(.pet(pet.id.uuidString))
                    }
                }
                ForEach(humans) { human in
                    chipButton(label: human.name, systemImage: "person.fill", isSelected: selectedHumanId == human.id.uuidString) {
                        onSelect(.human(human.id.uuidString))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
    }

    private func chipButton(label: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                Text(label).font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(chipForeground(isSelected: isSelected))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(chipBackground(isSelected: isSelected), in: Capsule())
            .shadow(color: isSelected && isMaterial ? chipAccent.opacity(0.25) : .clear, radius: 6, x: 0, y: 2) // ui-v4: allow legacy material calendar chip depth
        }
        .buttonStyle(ScaleButtonStyle())
        .ohanaSelectionMotion(isSelected: isSelected, scale: 1.018)
    }

    private func chipForeground(isSelected: Bool) -> Color {
        if isSelected { return chipSelFg }
        if isMaterial { return Color(hex: "8E8E93") }
        return Color.ohanaSecondaryText
    }

    private func chipBackground(isSelected: Bool) -> Color {
        if isSelected { return chipAccent }
        if isMaterial { return matSurface }
        return Color.ohanaControlFill
    }
}

struct CalendarView: View {
    var preselectedPetId: String? = nil
    var preselectedHumanId: String? = nil
    var hideToolbar: Bool = false
    var showsEmbeddedControls: Bool = false
    var addEventTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onRequestAddEvent: (() -> Void)? = nil
    var onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \PetInsurance.createdAt) private var insurances: [PetInsurance]
    @Query(sort: \PetMedication.createdAt) private var petMedications: [PetMedication]
    @Query(sort: \HumanMedication.createdAt) private var humanMedications: [HumanMedication]
    
    @State private var selectedDate = Date()
    @AppStorage("calendar_filterPetId") private var calendarFilterPetId: String = ""
    @AppStorage("calendar_filterHumanId") private var calendarFilterHumanId: String = ""
    @State private var showingAddEvent = false
    @State private var addEventPresentationProgress: CGFloat = 0
    @State private var isAddEventContentMounted = false
    @State private var showingCoconutLog = false
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("calendar_viewMode") private var viewModeRaw: String = CalendarViewMode.list.rawValue
    @State private var displayedViewModeRaw: String?
    private var viewMode: CalendarViewMode { CalendarViewMode(rawValue: displayedViewModeRaw ?? viewModeRaw) ?? .list }
    @State private var visualFilterSelection = CalendarFilterSelection.all
    @State private var appliedFilterSelection = CalendarFilterSelection.all
    @State private var didSyncCalendarFilter = false
    @State private var deletingEvent: Event? = nil
    @State private var showDeleteSeriesAlert = false
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var visibleDateCoordinator = CalendarVisibleDateCoordinator()
    @State private var listVisibleTopDate = Calendar.current.startOfDay(for: Date())
    @State private var visibleTimelineDateID: String? = CalendarView.todayTimelineDateID
    @State private var timelineTodayScrollRequest = 0
    @State private var didScrollListToToday = false
    @State private var viewModeCommitTask: Task<Void, Never>?
    @State private var filterApplyTask: Task<Void, Never>?
    @State private var filterStorageCommitTask: Task<Void, Never>?
    @State private var calendarMaintenanceTask: Task<Void, Never>?
    @State private var listInitialPositionTask: Task<Void, Never>?
    @State private var addEventPresentationTask: Task<Void, Never>?
    @State private var addEventContentMountTask: Task<Void, Never>?
    @State private var didScheduleCalendarMaintenance = false

    private var isMaterial: Bool { false }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var chipAccent: Color { Color.goPrimary }
    private var chipSelFg:  Color { Color.arkInk }
    // 独立日历页下自适应 light/dark 的文字颜色辅助
    private var classicSoftText: Color { colorScheme == .dark ? .white.opacity(0.4) : .secondary }
    private var classicPrimaryText: Color { colorScheme == .dark ? .white.opacity(0.85) : .primary }
    private var classicSubtleFill: Color { colorScheme == .dark ? .white.opacity(0.1) : .primary.opacity(0.07) }
    private var classicDotFill: Color { colorScheme == .dark ? .white.opacity(0.12) : .primary.opacity(0.12) }
    private var classicLineColors: [Color] { colorScheme == .dark ? [.white.opacity(0.35), .white.opacity(0.06)] : [.primary.opacity(0.2), .primary.opacity(0.04)] }
    private var calendarHeaderDate: Date {
        viewMode == .list ? listVisibleTopDate : selectedDate
    }

    private static var todayTimelineDateID: String {
        String(Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970))
    }

    private var isCalendarPrepared: Bool {
        isEmbeddedPrepared || isEmbeddedVisible || isEmbeddedActive
    }

    private var storedFilterSelection: CalendarFilterSelection {
        CalendarFilterSelection(petId: calendarFilterPetId, humanId: calendarFilterHumanId)
    }

    private var displayedFilterSelection: CalendarFilterSelection {
        didSyncCalendarFilter ? visualFilterSelection : storedFilterSelection
    }

    private var activeFilterSelection: CalendarFilterSelection {
        didSyncCalendarFilter ? appliedFilterSelection : storedFilterSelection
    }

    private var effectiveFilterSelection: CalendarFilterSelection {
        if let preselectedPetId { return .pet(preselectedPetId) }
        if let preselectedHumanId { return .human(preselectedHumanId) }
        return activeFilterSelection
    }

    private var contentHandoffState: CalendarContentHandoffState {
        CalendarContentHandoffState(
            viewModeRaw: displayedViewModeRaw ?? viewModeRaw,
            filter: effectiveFilterSelection
        )
    }

    private var activeHuman: Human? {
        if let id = UUID(uuidString: activeHumanIdStr), let human = humans.first(where: { $0.id == id }) {
            return human
        }
        return humans.first
    }

    private var calendarCoconutBalance: Int {
        activeHuman?.coconutBalance ?? QuestManager.shared.coconutCount
    }
    
    /// 从宠物详情进入时固定为该宠物；否则使用 AppStorage 筛选
    private var effectivePetFilterId: String? {
        if let p = preselectedPetId { return p }
        if preselectedHumanId != nil || !activeFilterSelection.humanId.isEmpty { return nil }
        return activeFilterSelection.selectedPetId
    }

    /// 从人类卡片进入时固定为该成员；首页默认不筛选，继续显示全部日历项目。
    private var effectiveHumanFilterId: String? {
        if let preselectedHumanId { return preselectedHumanId }
        return activeFilterSelection.selectedHumanId
    }

    private var filteredEvents: [Event] {
        var result = events.filter { !CarePlanCalendarSync.isDefaultGeneratedCalendarPlan($0, pets: pets) }
        if let petId = effectivePetFilterId {
            result = result.filter { eventIsRelatedToPet($0, petId: petId) }
        }
        if let humanId = effectiveHumanFilterId {
            result = result.filter { eventIsRelatedToHuman($0, humanId: humanId) }
        }
        return result
    }

    private func eventIsRelatedToPet(_ event: Event, petId: String) -> Bool {
        let entityType = event.relatedEntityType.lowercased()
        if event.relatedEntityId == petId {
            return entityType == EntityKind.pet.rawValue.lowercased()
                || entityType == "pet"
                || entityType == "pet_food_stock"
                || entityType == FeedRuleMetadata.autoFeederEntityType.lowercased()
                || entityType == WaterPlanWriter.entityType.lowercased()
        }
        if entityType == "pet_insurance" {
            return insurances.first { $0.id.uuidString == event.relatedEntityId }?.pet?.id.uuidString == petId
        }
        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication.lowercased() {
            return petMedications.first { $0.id.uuidString == event.relatedEntityId }?.pet?.id.uuidString == petId
        }
        return false
    }

    private func eventIsRelatedToHuman(_ event: Event, humanId: String) -> Bool {
        let entityType = event.relatedEntityType.lowercased()
        if event.assigneeId == humanId {
            return true
        }
        if event.relatedEntityId == humanId {
            return entityType == EntityKind.human.rawValue.lowercased()
                || entityType == "human"
        }
        if entityType == "human_medication" {
            return humanMedications.first { $0.id.uuidString == event.relatedEntityId }?.humanId == humanId
        }
        return false
    }

    /// 首页嵌入时为全局顶栏 + 外层宠物条预留空间。
    private var overviewCalendarEmbedTopInset: CGFloat { 98 }

    private var shouldShowInlinePetChips: Bool {
        preselectedPetId == nil && preselectedHumanId == nil && (!hideToolbar || showsEmbeddedControls || isMaterial)
    }

    // D1: 展开重复事件 → 生成虚拟 (Event, occurrenceDate) 对，用于列表视图分组
    private struct EventOccurrence: Identifiable {
        let id: String          // event.id + date
        let event: Event
        let occurrenceDate: Date
    }

    private struct TimelineDateSection: Identifiable {
        let date: Date
        let occurrences: [EventOccurrence]

        var id: Date { date }
    }

    private var expandedOccurrences: [EventOccurrence] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .month, value: -3, to: Date()) ?? Date() // 只展开近3个月
        let future = cal.date(byAdding: .month, value: 3, to: Date()) ?? Date()  // 及未来3个月
        var result: [EventOccurrence] = []
        for event in filteredEvents {
            let eStart = cal.startOfDay(for: event.startDate)
            if event.recurrenceDays > 0 {
                let hardCap: Date
                if let recEnd = event.recurrenceEndDate {
                    hardCap = min(recEnd, future)
                } else {
                    hardCap = future
                }
                var cursor = max(eStart, cutoff)
                // 对齐到第一个重复发生日
                if cursor > eStart {
                    let diff = cal.dateComponents([.day], from: eStart, to: cursor).day ?? 0
                    let steps = Int(ceil(Double(diff) / Double(event.recurrenceDays)))
                    cursor = cal.date(byAdding: .day, value: steps * event.recurrenceDays, to: eStart) ?? eStart
                }
                var safety = 0
                while cursor <= hardCap && safety < 200 {
                    if shouldShowEventOccurrence(event, occurrenceDate: cursor) {
                        result.append(EventOccurrence(
                            id: "\(event.id.uuidString)-\(cursor.timeIntervalSince1970)",
                            event: event,
                            occurrenceDate: cursor
                        ))
                    }
                    cursor = cal.date(byAdding: .day, value: event.recurrenceDays, to: cursor) ?? cursor
                    safety += 1
                }
            } else {
                if eStart >= cutoff && eStart <= future && shouldShowEventOccurrence(event, occurrenceDate: eStart) {
                    result.append(EventOccurrence(
                        id: event.id.uuidString,
                        event: event,
                        occurrenceDate: eStart
                    ))
                }
            }
        }
        return result.sorted { $0.occurrenceDate < $1.occurrenceDate }
    }

    private var timelineSections: [TimelineDateSection] {
        let today = Calendar.current.startOfDay(for: Date())
        let occurrencesByDay = Dictionary(grouping: expandedOccurrences) { occ in
            Calendar.current.startOfDay(for: occ.occurrenceDate)
        }
        .mapValues { occurrences in
            occurrences.sorted {
                if $0.occurrenceDate == $1.occurrenceDate {
                    return $0.event.startDate < $1.event.startDate
                }
                return $0.occurrenceDate < $1.occurrenceDate
            }
        }

        return Array(Set(occurrencesByDay.keys).union([today]))
            .sorted()
            .map { TimelineDateSection(date: $0, occurrences: occurrencesByDay[$0] ?? []) }
    }

    private var timelineDates: [Date] {
        timelineSections.map(\.date)
    }

    private var timelineDateSignature: String {
        timelineDates.map(timelineDateID).joined(separator: "|")
    }

    private var timelineDateIDs: Set<String> {
        Set(timelineDates.map(timelineDateID))
    }
    
    private var eventsForSelectedDate: [Event] {
        filteredEvents.filter {
            eventOccursOnDate($0, date: selectedDate) &&
                shouldShowEventOccurrence($0, occurrenceDate: selectedDate)
        }
    }

    private func shouldShowEventOccurrence(_ event: Event, occurrenceDate: Date) -> Bool {
        CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(
            event,
            occurrenceDate: occurrenceDate,
            allEvents: events,
            pets: pets
        )
    }

    /// 判断事件是否出现在指定日期（支持多日事件 + 重复事件展开）
    private func eventOccursOnDate(_ event: Event, date: Date) -> Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        let eStart = cal.startOfDay(for: event.startDate)

        // 重复事件：检查 date 是否是某个重复发生日
        if event.recurrenceDays > 0 {
            // date 不能早于事件开始日
            guard dayStart >= eStart else { return false }
            // 不能超过重复结束日（如果设置了）
            if let recEnd = event.recurrenceEndDate {
                guard dayStart <= cal.startOfDay(for: recEnd) else { return false }
            }
            // date 距 startDate 的天数必须是 recurrenceDays 的整数倍
            let diff = cal.dateComponents([.day], from: eStart, to: dayStart).day ?? 0
            return diff % event.recurrenceDays == 0
        }

        // 单次事件：事件范围与当天范围有交集
        let eEnd = event.endDate.map { cal.startOfDay(for: $0) } ?? eStart
        return eStart < dayEnd && eEnd >= dayStart
    }
    
    // 本周 7 天
    private var thisWeekDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        guard let sunday = cal.date(byAdding: .day, value: -daysFromSunday, to: today) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: sunday) }
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
    }

    private var calendarContent: some View {
        ZStack(alignment: .top) {
            OhanaAppBackground()

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
                        selection: displayedFilterSelection,
                        onSelect: selectCalendarFilter
                    )
                }

                Group {
                    switch viewMode {
                    case .month:
                        goMonthView
                    case .list:
                        goListView
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
        .toolbar(.hidden, for: .navigationBar)
        .overlay { inlineAddEventLayer }
        .sheet(isPresented: $showingCoconutLog) {
            CoconutLogView()
                .ohanaSheetPagePresentation() // ui-v4: allow coconut history as long sheet
        }
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
        .onAppear {
            syncCalendarViewModeFromStorage(viewModeRaw)
            syncCalendarFilterFromStorage(animated: false)
            if isCalendarPrepared, viewMode == .list {
                scheduleInitialListPositionIfNeeded()
            }
            if isCalendarPrepared {
                scheduleCalendarMaintenance()
            }
        }
        .onDisappear {
            cancelPendingCalendarMaintenance()
            filterApplyTask?.cancel()
            filterStorageCommitTask?.cancel()
            listInitialPositionTask?.cancel()
            listInitialPositionTask = nil
            addEventPresentationTask?.cancel()
            addEventContentMountTask?.cancel()
        }
        .onChange(of: isEmbeddedActive) { _, isActive in
            if isActive {
                scheduleCalendarMaintenance()
                if viewMode == .list {
                    scheduleInitialListPositionIfNeeded()
                }
            } else if !isCalendarPrepared {
                cancelPendingCalendarMaintenance()
                listInitialPositionTask?.cancel()
                listInitialPositionTask = nil
            }
        }
        .onChange(of: isEmbeddedPrepared) { _, isPrepared in
            if isPrepared {
                scheduleCalendarMaintenance()
                if viewMode == .list {
                    scheduleInitialListPositionIfNeeded()
                }
            } else if !isEmbeddedVisible && !isEmbeddedActive {
                cancelPendingCalendarMaintenance()
                listInitialPositionTask?.cancel()
                listInitialPositionTask = nil
            }
        }
        .onChange(of: isEmbeddedVisible) { _, isVisible in
            if isVisible {
                syncCalendarViewModeFromStorage(viewModeRaw)
                scheduleCalendarMaintenance()
                if viewMode == .list {
                    scheduleInitialListPositionIfNeeded()
                }
            } else if !isEmbeddedPrepared && !isEmbeddedActive {
                cancelPendingCalendarMaintenance()
                listInitialPositionTask?.cancel()
                listInitialPositionTask = nil
            }
        }
    }

    @ViewBuilder
    private var inlineAddEventLayer: some View {
        if showingAddEvent || addEventPresentationProgress > 0.001 {
            OhanaDeferredInlinePageCover(
                progress: addEventPresentationProgress,
                isContentMounted: isAddEventContentMounted
            ) {
                AddEventView(onClose: closeInlineAddEvent)
            }
            .zIndex(90)
        }
    }

    private func requestAddEventPresentation() {
        OhanaFeedback.light()
        if let onRequestAddEvent {
            onRequestAddEvent()
        } else {
            openInlineAddEvent()
        }
    }

    private func openInlineAddEvent() {
        guard !showingAddEvent else { return }
        addEventPresentationTask?.cancel()
        addEventContentMountTask?.cancel()
        showingAddEvent = true
        addEventPresentationProgress = 0
        isAddEventContentMounted = false
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
            addEventContentMountTask = nil
        }
    }

    private func closeInlineAddEvent() {
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
            showingAddEvent = false
            isAddEventContentMounted = false
            addEventPresentationTask = nil
        }
    }

    private func reconcileDefaultPlanOverrides() {
        for pet in pets {
            CarePlanCalendarSync.reconcileDefaultPlanOverrides(for: pet, context: modelContext)
        }
    }

    private func scheduleCalendarMaintenance() {
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

    private func cancelPendingCalendarMaintenance() {
        if calendarMaintenanceTask != nil {
            didScheduleCalendarMaintenance = false
        }
        calendarMaintenanceTask?.cancel()
        calendarMaintenanceTask = nil
    }

    private func selectCalendarViewMode(_ mode: CalendarViewMode) {
        guard viewMode != mode else { return }
        withAnimation(GoMotion.selection) {
            displayedViewModeRaw = mode.rawValue
        }
        if mode == .list {
            resetCalendarListPositionForModeSwitch()
        }
        scheduleCalendarViewModeStorageCommit(mode)
    }

    private func syncCalendarViewModeFromStorage(_ rawValue: String) {
        guard let newMode = CalendarViewMode(rawValue: rawValue) else { return }
        guard displayedViewModeRaw != rawValue else { return }
        let previousMode = CalendarViewMode(rawValue: displayedViewModeRaw ?? viewModeRaw)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedViewModeRaw = rawValue
        }
        if previousMode != .list, newMode == .list {
            resetCalendarListPositionForModeSwitch()
        }
    }

    private func scheduleCalendarViewModeStorageCommit(_ mode: CalendarViewMode) {
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

    private func selectCalendarFilter(_ selection: CalendarFilterSelection) {
        guard displayedFilterSelection != selection else { return }
        withAnimation(GoMotion.selection) {
            visualFilterSelection = selection
            didSyncCalendarFilter = true
        }
        scheduleCalendarFilterApply(selection)
    }

    private func syncCalendarFilterFromStorage(animated: Bool) {
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

    private func scheduleCalendarFilterApply(_ selection: CalendarFilterSelection) {
        filterApplyTask?.cancel()
        filterApplyTask = OhanaFrameScheduler.runAfterNextFrame {
            guard visualFilterSelection == selection else {
                filterApplyTask = nil
                return
            }
            withAnimation(GoMotion.stateChange) {
                appliedFilterSelection = selection
            }
            filterApplyTask = nil
            scheduleCalendarFilterStorageCommit(selection)
        }
    }

    private func scheduleCalendarFilterStorageCommit(_ selection: CalendarFilterSelection) {
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
            }
            filterStorageCommitTask = nil
        }
    }

    private func resetCalendarListPositionForModeSwitch() {
        listInitialPositionTask?.cancel()
        listInitialPositionTask = nil
        let today = Calendar.current.startOfDay(for: Date())
        didScrollListToToday = false
        visibleTimelineDateID = timelineDateID(today)
        listVisibleTopDate = today
    }

    // MARK: - Classic Calendar Header
    private var embeddedCalendarHeader: some View {
        HStack(spacing: 10) {
            calendarHeaderTitle(fontSize: 19)

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(3)
            .background(Color.ohanaControlFill, in: Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var classicCalendarHeader: some View {
        HStack(spacing: 12) {
            calendarHeaderTitle(fontSize: 20)

            Spacer()

            // 视图切换胶囊
            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(3)
            .goGlassBackground(Capsule())

            // 添加事件按钮
            Button { requestAddEventPresentation() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 36, height: 36)
                    .background(Color.goPrimary, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func calendarHeaderTitle(fontSize: CGFloat) -> some View {
        let l = L10n(AppLanguage.code)
        return Button {
            returnCalendarToToday()
        } label: {
            Text(calendarHeaderDate, format: .dateTime.year().month(.wide))
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "返回今天", en: "Return to today", de: "Zu heute springen"))
        .accessibilityValue(calendarHeaderDate.formatted(.dateTime.year().month(.wide)))
    }

    // MARK: - Sticky Calendar Header (Material)
    private var calStickyHeader: some View {
        let bg: Color = colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C")
        let accent = Color(hex: "FF5A00")
        return HStack(spacing: 10) {
            // Add event
            Button { requestAddEventPresentation() } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 40, height: 40)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 2) // ui-v4: allow legacy material calendar floating action depth
            }.buttonStyle(ScaleButtonStyle())

            // View toggle pill
            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(4)
            .goGlassBackground(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2) // ui-v4: allow legacy material calendar segmented depth

            Spacer()

            // Coconut count (rightmost, matches home)
            CoconutBalanceCapsule(balance: calendarCoconutBalance) {
                showingCoconutLog = true
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            bg.opacity(0.92)
                .background(Color.ohanaCardSurface.opacity(0.88))
                .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Go Week Strip (本周快速预览)
    private var goWeekStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(thisWeekDays, id: \.self) { day in
                    let isToday = Calendar.current.isDateInToday(day)
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    let dayNumber = Calendar.current.component(.day, from: day)
                    let dayEvents = filteredEvents.filter {
                        eventOccursOnDate($0, date: day) &&
                            shouldShowEventOccurrence($0, occurrenceDate: day)
                    }
                    let hasEvents = !dayEvents.isEmpty
                    // 每个事件对应的宠物主题色（去重，最多3种）
                    let dotColors: [Color] = {
                        var seen: [String] = []
                        var colors: [Color] = []
                        for ev in dayEvents {
                            if let pet = pets.first(where: { $0.id.uuidString == ev.relatedEntityId }) {
                                let hex = pet.themeColorHex
                                if !seen.contains(hex) {
                                    seen.append(hex)
                                    colors.append(Color(hex: hex))
                                }
                            } else if let plant = plants.first(where: { $0.id.uuidString == ev.relatedEntityId }) {
                                let hex = plant.themeColorHex
                                if !seen.contains(hex) {
                                    seen.append(hex)
                                    colors.append(Color(hex: hex))
                                }
                            } else if !seen.contains("default") {
                                seen.append("default")
                                colors.append(chipAccent)
                            }
                            if colors.count >= 3 { break }
                        }
                        return colors
                    }()

                    Button {
                        withAnimation(GoMotion.feedback) { selectedDate = day }
                    } label: {
                        VStack(spacing: 5) {
                            Text(day, format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? chipSelFg : (isMaterial ? Color(hex: "8E8E93") : classicSoftText))
                            
                            Text("\(dayNumber)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(isSelected ? chipSelFg : (isToday ? chipAccent : (isMaterial ? .primary : classicPrimaryText)))
                                .ohanaNumericMotion(dayNumber)
                            
                            // 事件点（宠物主题色，多宠物时最多3个彩点）
                            ZStack {
                                if hasEvents && !isSelected {
                                    HStack(spacing: 2) {
                                        ForEach(0..<dotColors.count, id: \.self) { i in
                                            Circle().fill(dotColors[i]).frame(width: 5, height: 5)
                                        }
                                    }
                                } else {
                                    Circle()
                                        .fill(hasEvents && isSelected ? chipSelFg.opacity(0.7) : Color.clear)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            
                            // 首个事件剪影图标
                            if let first = dayEvents.first {
                                Image(systemName: first.silhouetteListSymbol)
                                    .font(.system(size: 11, weight: .bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(isSelected ? chipSelFg.opacity(0.9) : (isMaterial ? Color.primary.opacity(0.5) : classicPrimaryText.opacity(0.55)))
                            } else {
                                Color.clear.frame(height: 16)
                            }
                        }
                        .frame(width: 44)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? chipAccent : (isToday ? chipAccent.opacity(isMaterial ? 0.12 : 0.08) : Color.clear),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Go View Mode Toggle（图标版）
    private var goViewModeToggle: some View {
        HStack(spacing: 2) {
            iconModeBtn(systemName: "calendar", mode: .month)
            iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
        }
        .padding(3)
        .goGlassBackground(Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func iconModeBtn(systemName: String, mode: CalendarViewMode) -> some View {
        let unselectedTint: Color = {
            if isMaterial { return Color(hex: "8E8E93") }
            return Color.ohanaSecondaryText
        }()
        return Button {
            selectCalendarViewMode(mode)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(viewMode == mode ? chipSelFg : unselectedTint)
                .frame(width: 36, height: 30)
                .background { if viewMode == mode { Capsule().fill(chipAccent) } }
        }
        .buttonStyle(ScaleButtonStyle())
        .ohanaSelectionMotion(isSelected: viewMode == mode, scale: 1.018)
    }
    
    // MARK: - Go Month View
    private var goMonthView: some View {
        VStack(spacing: 12) {
            // Month header — Go 风格
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(isMaterial ? matSurface : classicSubtleFill, in: Circle())
                }
                
                Spacer()
                
                Text(selectedDate, format: .dateTime.year().month(.wide))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                
                Spacer()
                
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(isMaterial ? matSurface : classicSubtleFill, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            
            // Weekday header — 日一二三四五六
            HStack(spacing: 0) {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            // Calendar grid
            let daysInMonth = calendarDays()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { offset, date in
                    if let date {
                        let isToday = Calendar.current.isDateInToday(date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let dayNumber = Calendar.current.component(.day, from: date)
                        let hasEvents = filteredEvents.contains {
                            eventOccursOnDate($0, date: date) &&
                                shouldShowEventOccurrence($0, occurrenceDate: date)
                        }
                        
                        Button {
                            withAnimation(GoMotion.feedback) {
                                selectedDate = date
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(dayNumber)")
                                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? chipSelFg : (isToday ? chipAccent : (isMaterial ? .primary : classicPrimaryText)))
                                    .ohanaNumericMotion(dayNumber)
                                
                                Circle()
                                    .fill(hasEvents ? (isSelected ? chipSelFg.opacity(0.7) : chipAccent) : .clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(width: 40, height: 48)
                            .background(
                                isSelected ? chipAccent : (isToday ? chipAccent.opacity(isMaterial ? 0.12 : 0.08) : .clear),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                    } else {
                        Color.clear.frame(width: 40, height: 48)
                    }
                }
            }
            .padding(.horizontal, 12)
            .id(calendarMonthKey)
            .transition(.opacity.combined(with: .scale(scale: 0.996, anchor: .center)))
            
            GoDashedDivider()
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            
            // Events for selected date — Go 风格
            ScrollView {
                VStack(spacing: 8) {
                    if eventsForSelectedDate.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 32, weight: .medium))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                            Text("暂无事件")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }
                        .padding(.top, 20)
                    } else {
                        ForEach(eventsForSelectedDate) { event in
                            goEventRow(event, occurrenceDate: selectedDate)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
    }
    
    // MARK: - Go List View（时间轴版）
    private var goListView: some View {
        ZStack(alignment: .topLeading) {
            // 环境光斑（毛玻璃卡片后方，营造流动光影）
            ambientLightBlobs

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(timelineSections) { section in
                            timelineSection(date: section.date, occurrences: section.occurrences)
                                .id(timelineDateID(section.date))
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .scrollPosition(id: $visibleTimelineDateID, anchor: .top)
                .onAppear {
                    scheduleInitialTimelineScrollIfNeeded(proxy: proxy)
                }
                .onChange(of: isEmbeddedPrepared) { _, isPrepared in
                    if isPrepared {
                        scheduleInitialTimelineScrollIfNeeded(proxy: proxy)
                    }
                }
                .onChange(of: isEmbeddedVisible) { _, isVisible in
                    if isVisible {
                        scheduleInitialTimelineScrollIfNeeded(proxy: proxy)
                    }
                }
                .onChange(of: timelineDateSignature) { _, _ in
                    scheduleInitialTimelineScrollIfNeeded(proxy: proxy)
                }
                .onChange(of: visibleTimelineDateID) { _, dateID in
                    guard isCalendarPrepared else { return }
                    scheduleVisibleCalendarMonthUpdate(from: dateID)
                }
                .onChange(of: timelineTodayScrollRequest) { _, _ in
                    scrollListToToday(proxy: proxy)
                }
            }
            // F2: 删除 alert 已移至 SwipeableEventRow’s confirmationDialog
        }
    }

    // 环境光斑
    @ViewBuilder
    private var ambientLightBlobs: some View {
        if !isMaterial {
            GeometryReader { geo in
                ZStack {
                    RadialGradient(
                        colors: [Color.goPrimary.opacity(0.18), .clear],
                        center: .init(x: 0.2, y: 0.25),
                        startRadius: 0, endRadius: 160
                    )
                    .frame(width: 280, height: 280)
                    .offset(x: -30, y: 60)
                    .blur(radius: 20)
                    .allowsHitTesting(false)

                    RadialGradient(
                        colors: [Color.goPrimary.opacity(0.08), .clear],
                        center: .init(x: 0.8, y: 0.7),
                        startRadius: 0, endRadius: 120
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: geo.size.width * 0.5, y: 300)
                    .blur(radius: 18)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()
        }
    }

    // 单日时间轴组
    private func timelineSection(date: Date, occurrences: [EventOccurrence]) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        return VStack(spacing: 0) {
            // 日期组头
            if isToday {
                todayTimelineAnchor(date: date, count: occurrences.count)
            } else {
                HStack(spacing: 10) {
                    timelineDateBadge(date, isToday: false)
                        .frame(width: 40)

                    Text(relativeDate(date))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(isMaterial ? Color(hex: "8E8E93") : classicSoftText)
                        .tracking(0.5)

                    Text("·  \(occurrences.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                        .ohanaNumericMotion(occurrences.count)

                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 6)
            }

            // 事件行列（左侧纵线贯穿）
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: classicLineColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1)
                }
                .frame(width: 40)

                VStack(spacing: 8) {
                    if occurrences.isEmpty {
                        emptyTodayPill
                    } else {
                        ForEach(occurrences) { occ in
                            goEventRow(occ.event, occurrenceDate: occ.occurrenceDate)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func todayTimelineAnchor(date: Date, count: Int) -> some View {
        HStack(spacing: 10) {
            timelineDateBadge(date, isToday: true)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("今天")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(chipAccent)
                    Text(count == 0 ? "暂无事件" : "\(count) 项")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(classicPrimaryText.opacity(0.55))
                        .ohanaNumericMotion(count)
                    Spacer()
                }

                Rectangle()
                    .fill(chipAccent.opacity(colorScheme == .dark ? 0.45 : 0.7))
                    .frame(height: 1.5)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func timelineDateBadge(_ date: Date, isToday: Bool) -> some View {
        let dayNumber = Calendar.current.component(.day, from: date)
        return VStack(spacing: 3) {
            Text(weekdayShort(date))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(isToday ? chipAccent : classicSoftText)
                .textCase(.uppercase)

            Text("\(dayNumber)")
                .font(.system(size: isToday ? 18 : 17, weight: .black, design: .rounded))
                .foregroundStyle(isToday ? chipSelFg : classicPrimaryText)
                .ohanaNumericMotion(dayNumber)
                .frame(width: 34, height: 34)
                .background(isToday ? chipAccent : classicSubtleFill, in: Circle())
        }
    }

    private var emptyTodayPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(chipAccent)
            Text("今天没有安排，保持轻松")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(classicPrimaryText.opacity(0.66))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(classicSubtleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func weekdayShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func timelineDateID(_ date: Date) -> String {
        String(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))
    }

    private func scheduleInitialListPositionIfNeeded() {
        guard isCalendarPrepared else { return }
        guard !didScrollListToToday, timelineDates.contains(where: { Calendar.current.isDateInToday($0) }) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let todayID = timelineDateID(today)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            listVisibleTopDate = today
            visibleTimelineDateID = todayID
        }
    }

    private func scheduleInitialTimelineScrollIfNeeded(proxy: ScrollViewProxy) {
        guard isCalendarPrepared, !didScrollListToToday else { return }
        scheduleInitialListPositionIfNeeded()
        guard let targetID = visibleTimelineDateID, timelineDateIDs.contains(targetID) else { return }
        listInitialPositionTask?.cancel()
        listInitialPositionTask = OhanaFrameScheduler.runAfterNextFrame {
            guard isCalendarPrepared, timelineDateIDs.contains(targetID) else {
                listInitialPositionTask = nil
                return
            }
            scrollTimeline(proxy, to: targetID, animated: false)
            didScrollListToToday = true
            listInitialPositionTask = nil
        }
    }

    private func scrollTimeline(_ proxy: ScrollViewProxy, to dateID: String, animated: Bool) {
        guard timelineDateIDs.contains(dateID) else { return }
        if animated {
            withAnimation(GoMotion.selection) {
                proxy.scrollTo(dateID, anchor: .top)
            }
        } else {
            proxy.scrollTo(dateID, anchor: .top)
        }
    }

    private func returnCalendarToToday() {
        OhanaFeedback.light()
        listInitialPositionTask?.cancel()
        listInitialPositionTask = nil
        let today = Calendar.current.startOfDay(for: Date())
        let todayID = timelineDateID(today)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedDate = today
            listVisibleTopDate = today
            if timelineDateIDs.contains(todayID) {
                visibleTimelineDateID = todayID
                timelineTodayScrollRequest += 1
            }
            didScrollListToToday = true
        }
    }

    private func scrollListToToday(proxy: ScrollViewProxy) {
        guard isCalendarPrepared else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let todayID = timelineDateID(today)
        guard timelineDateIDs.contains(todayID) else { return }
        scrollTimeline(proxy, to: todayID, animated: false)
        scheduleVisibleCalendarMonthUpdate(from: todayID)
    }

    private func scheduleVisibleCalendarMonthUpdate(from dateID: String?) {
        guard isCalendarPrepared else { return }
        guard let dateID,
              let timestamp = TimeInterval(dateID) else { return }
        let date = Date(timeIntervalSince1970: timestamp)
        visibleDateCoordinator.scheduleUpdate(to: date) { normalized in
            guard isCalendarPrepared else { return }
            updateVisibleCalendarMonth(to: normalized)
        }
    }

    private func updateVisibleCalendarMonth(to normalized: Date) {
        guard !Calendar.current.isDate(listVisibleTopDate, inSameDayAs: normalized) else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            listVisibleTopDate = normalized
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let l = L10n(AppLanguage.code)
        if Calendar.current.isDateInToday(date) {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        if Calendar.current.isDateInYesterday(date) {
            return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern")
        }
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        switch AppLanguage.code {
        case "zh":
            formatter.dateFormat = sameYear ? "M月d日 EEEE" : "yyyy年M月d日"
        case "de":
            formatter.dateFormat = sameYear ? "EEEE, d. MMM" : "d. MMM yyyy"
        default:
            formatter.dateFormat = sameYear ? "EEEE, MMM d" : "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
    
    // MARK: - Go Event Row
    private func goEventRow(_ event: Event, occurrenceDate: Date) -> some View {
        let relatedPetColor: Color? = pets.first(where: { $0.id.uuidString == event.relatedEntityId })
            .map { Color(hex: $0.themeColorHex) }
            ?? plants.first(where: { $0.id.uuidString == event.relatedEntityId })
            .map { Color(hex: $0.themeColorHex) }
        return SwipeableEventRow(
            event: event,
            occurrenceDate: occurrenceDate,
            petThemeColor: relatedPetColor,
            onComplete: {
                withAnimation(GoMotion.feedback) {
                    let shouldComplete = !event.isOccurrenceMarkedComplete(on: occurrenceDate)
                    event.setOccurrenceMarkedComplete(shouldComplete, on: occurrenceDate)
                    let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                    CalendarTaskCompletionSyncService.syncPetTask(
                        event: event,
                        occurrenceDate: occurrenceDate,
                        isCompleted: shouldComplete,
                        pets: pets,
                        context: modelContext,
                        executorId: activeHumanId
                    )
                    let now = Date()
                    let cal = Calendar.current
                    let today = cal.startOfDay(for: now)
                    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
                    // 仅单次事件同步「今日」提醒状态；重复序列按日完成不写 isCompleted，避免误伤整批 Reminder
                    if event.recurrenceDays == 0 {
                        for reminder in event.reminders {
                            if reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow {
                                if shouldComplete {
                                    ReminderCompletionService.complete(reminder, by: activeHumanId, context: modelContext)
                                } else {
                                    ReminderCompletionService.reopen(reminder, by: activeHumanId, context: modelContext)
                                }
                            }
                        }
                    } else {
                        modelContext.safeSave()
                    }
                }
            },
            onDelete: { /* F2: 删除逻辑已在 SwipeableEventRow 内处理 */ },
            onOpenRelated: {
                openRelatedDestination(for: event)
            }
        )
    }

    private func openRelatedDestination(for event: Event) -> Bool {
        guard let onOpenEventDestination else { return false }
        let destination = FocusHomeReminderDeepLinkRouter.destination(
            for: event,
            pets: pets,
            humans: humans,
            plants: plants,
            humanMedications: humanMedications
        )
        if case let .calendar(entityId, humanId) = destination,
           entityId == nil,
           humanId == nil {
            return false
        }
        onOpenEventDestination(destination)
        return true
    }
    
    // MARK: - Calendar Helpers
    private func calendarDays() -> [Date?] {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: selectedDate)
        guard let firstOfMonth = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        
        let weekday = cal.component(.weekday, from: firstOfMonth)
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }

    private var calendarMonthKey: String {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .local)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > 44, abs(width) > abs(height) * 1.25 else { return }
                shiftMonth(by: width < 0 ? 1 : -1)
            }
    }

    private func shiftMonth(by delta: Int) {
        let cal = Calendar.current
        guard let targetMonth = cal.date(byAdding: .month, value: delta, to: selectedDate),
              let interval = cal.dateInterval(of: .month, for: targetMonth) else { return }

        let today = Date()
        let targetDate = cal.isDate(interval.start, equalTo: today, toGranularity: .month)
            ? today
            : interval.start

        withAnimation(GoMotion.stateChange) {
            selectedDate = targetDate
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(SharedModelContainer.make())
}
