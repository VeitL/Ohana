//
//  CalendarView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

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
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil
    var events: [Event] = []
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var insurances: [PetInsurance] = []
    var petMedications: [PetMedication] = []
    var humanMedications: [HumanMedication] = []
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    
    @State var selectedDate = Date()
    @AppStorage("calendar_filterPetId") var calendarFilterPetId: String = ""
    @AppStorage("calendar_filterHumanId") var calendarFilterHumanId: String = ""
    @State var showingAddEvent = false
    @State var addEventPresentationProgress: CGFloat = 0
    @State var isAddEventContentMounted = false
    @AppStorage("currentActiveHumanId") var activeHumanIdStr = ""
    @AppStorage("calendar_viewMode") var viewModeRaw: String = CalendarViewMode.list.rawValue
    @State var displayedViewModeRaw: String?
    var viewMode: CalendarViewMode { CalendarViewMode(rawValue: displayedViewModeRaw ?? viewModeRaw) ?? .list }
    @State var visualFilterSelection = CalendarFilterSelection.all
    @State var appliedFilterSelection = CalendarFilterSelection.all
    @State var didSyncCalendarFilter = false
    @State var deletingEvent: Event? = nil
    @State var showDeleteSeriesAlert = false
    @Environment(\.colorScheme) var colorScheme
    @StateObject var visibleDateCoordinator = CalendarVisibleDateCoordinator()
    @State var listVisibleTopDate = Calendar.current.startOfDay(for: Date())
    @State var visibleTimelineDateID: String? = CalendarView.todayTimelineDateID
    @State var timelineTodayScrollRequest = 0
    @State var didScrollListToToday = false
    @State var viewModeCommitTask: Task<Void, Never>?
    @State var filterApplyTask: Task<Void, Never>?
    @State var filterStorageCommitTask: Task<Void, Never>?
    @State var calendarMaintenanceTask: Task<Void, Never>?
    @State var listInitialPositionTask: Task<Void, Never>?
    @State var addEventPresentationTask: Task<Void, Never>?
    @State var addEventContentMountTask: Task<Void, Never>?
    @State var didScheduleCalendarMaintenance = false
    @State var calendarOpenStartedAt: CFAbsoluteTime?
    @State var addEventFlowStartedAt: CFAbsoluteTime?

    var isMaterial: Bool { false }
    var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    var chipAccent: Color { Color.goPrimary }
    var chipSelFg:  Color { Color.arkInk }
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

    var storedFilterSelection: CalendarFilterSelection {
        CalendarFilterSelection(petId: calendarFilterPetId, humanId: calendarFilterHumanId)
    }

    var displayedFilterSelection: CalendarFilterSelection {
        didSyncCalendarFilter ? visualFilterSelection : storedFilterSelection
    }

    var activeFilterSelection: CalendarFilterSelection {
        didSyncCalendarFilter ? appliedFilterSelection : storedFilterSelection
    }

    var effectiveFilterSelection: CalendarFilterSelection {
        if let preselectedPetId { return .pet(preselectedPetId) }
        if let preselectedHumanId { return .human(preselectedHumanId) }
        return activeFilterSelection
    }

    var contentHandoffState: CalendarContentHandoffState {
        CalendarContentHandoffState(
            viewModeRaw: displayedViewModeRaw ?? viewModeRaw,
            filter: effectiveFilterSelection
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
    
    /// 从宠物详情进入时固定为该宠物；否则使用 AppStorage 筛选
    var effectivePetFilterId: String? {
        if let p = preselectedPetId { return p }
        if preselectedHumanId != nil || !activeFilterSelection.humanId.isEmpty { return nil }
        return activeFilterSelection.selectedPetId
    }

    /// 从人类卡片进入时固定为该成员；首页默认不筛选，继续显示全部日历项目。
    var effectiveHumanFilterId: String? {
        if let preselectedHumanId { return preselectedHumanId }
        return activeFilterSelection.selectedHumanId
    }

    var filteredEvents: [Event] {
        var result = events.filter { !CarePlanCalendarSync.isDefaultGeneratedCalendarPlan($0, pets: pets) }
        if let petId = effectivePetFilterId {
            result = result.filter { eventIsRelatedToPet($0, petId: petId) }
        }
        if let humanId = effectiveHumanFilterId {
            result = result.filter { eventIsRelatedToHuman($0, humanId: humanId) }
        }
        return result
    }

    func eventIsRelatedToPet(_ event: Event, petId: String) -> Bool {
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

    func eventIsRelatedToHuman(_ event: Event, humanId: String) -> Bool {
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
    var overviewCalendarEmbedTopInset: CGFloat { 98 }

    var shouldShowInlinePetChips: Bool {
        preselectedPetId == nil && preselectedHumanId == nil && (!hideToolbar || showsEmbeddedControls || isMaterial)
    }

    // D1: 展开重复事件 → 生成虚拟 (Event, occurrenceDate) 对，用于列表视图分组
    struct EventOccurrence: Identifiable {
        let id: String          // event.id + date
        let event: Event
        let occurrenceDate: Date
    }

    struct TimelineDateSection: Identifiable {
        let date: Date
        let occurrences: [EventOccurrence]

        var id: Date { date }
    }

    var expandedOccurrences: [EventOccurrence] {
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

    var timelineSections: [TimelineDateSection] {
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

    var timelineDates: [Date] {
        timelineSections.map(\.date)
    }

    var timelineDateSignature: String {
        timelineDates.map(timelineDateID).joined(separator: "|")
    }

    var timelineDateIDs: Set<String> {
        Set(timelineDates.map(timelineDateID))
    }
    
    var eventsForSelectedDate: [Event] {
        filteredEvents.filter {
            eventOccursOnDate($0, date: selectedDate) &&
                shouldShowEventOccurrence($0, occurrenceDate: selectedDate)
        }
    }

    func shouldShowEventOccurrence(_ event: Event, occurrenceDate: Date) -> Bool {
        CarePlanCalendarSync.shouldShowModeScopedPlanOccurrence(
            event,
            occurrenceDate: occurrenceDate,
            allEvents: events,
            pets: pets
        )
    }

    /// 判断事件是否出现在指定日期（支持多日事件 + 重复事件展开）
    func eventOccursOnDate(_ event: Event, date: Date) -> Bool {
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
    var thisWeekDays: [Date] {
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
}

#Preview {
    CalendarView()
        .modelContainer(SharedModelContainer.make())
}
