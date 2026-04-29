//
//  CalendarView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

enum CalendarViewMode: String, CaseIterable {
    case month = "月"
    case list = "列表"
}

/// 日历宠物筛选条（与 `CalendarView` 共享 `calendar_filterPetId`，空字符串表示「全部」）
struct CalendarPetChipFilterBar: View {
    @AppStorage("calendar_filterPetId") private var calendarFilterPetId: String = ""
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appUIStyle") private var appUIStyle: String = "go"

    private var isMaterial: Bool { false }
    private var chipAccent: Color { Color.goPrimary }
    private var chipSelFg: Color { Color.arkInk }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var selectedId: String? { calendarFilterPetId.isEmpty ? nil : calendarFilterPetId }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "全部", systemImage: "square.grid.2x2.fill", isSelected: selectedId == nil) {
                    calendarFilterPetId = ""
                }
                ForEach(pets) { pet in
                    chipButton(label: pet.name, systemImage: pet.speciesSilhouetteSymbol, isSelected: selectedId == pet.id.uuidString) {
                        calendarFilterPetId = pet.id.uuidString
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
            .shadow(color: isSelected && isMaterial ? chipAccent.opacity(0.25) : .clear, radius: 6, x: 0, y: 2)
        }
    }

    private func chipForeground(isSelected: Bool) -> Color {
        if isSelected { return chipSelFg }
        if isMaterial { return Color(hex: "8E8E93") }
        return colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)
    }

    private func chipBackground(isSelected: Bool) -> Color {
        if isSelected { return chipAccent }
        if isMaterial { return matSurface }
        return colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.1)
    }
}

struct CalendarView: View {
    var preselectedPetId: String? = nil
    var hideToolbar: Bool = false
    var addEventTrigger: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \PetInsurance.createdAt) private var insurances: [PetInsurance]
    @Query(sort: \PetMedication.createdAt) private var petMedications: [PetMedication]
    
    @State private var selectedDate = Date()
    @AppStorage("calendar_filterPetId") private var calendarFilterPetId: String = ""
    @State private var showingAddEvent = false
    @State private var showingCoconutLog = false
    @AppStorage("calendar_viewMode") private var viewModeRaw: String = CalendarViewMode.list.rawValue
    private var viewMode: CalendarViewMode { CalendarViewMode(rawValue: viewModeRaw) ?? .list }
    @State private var deletingEvent: Event? = nil
    @State private var showDeleteSeriesAlert = false
    @AppStorage("appUIStyle") private var appUIStyle: String = "go"
    @Environment(\.colorScheme) private var colorScheme
    @State private var coconutCount: Int = QuestManager.shared.coconutCount

    private var isMaterial: Bool { false }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var chipAccent: Color { Color.goPrimary }
    private var chipSelFg:  Color { Color.arkInk }
    // 经典模式下自适应 light/dark 的文字颜色辅助
    private var classicSoftText: Color { colorScheme == .dark ? .white.opacity(0.4) : .secondary }
    private var classicPrimaryText: Color { colorScheme == .dark ? .white.opacity(0.85) : .primary }
    private var classicSubtleFill: Color { colorScheme == .dark ? .white.opacity(0.1) : .primary.opacity(0.07) }
    private var classicDotFill: Color { colorScheme == .dark ? .white.opacity(0.12) : .primary.opacity(0.12) }
    private var classicLineColors: [Color] { colorScheme == .dark ? [.white.opacity(0.35), .white.opacity(0.06)] : [.primary.opacity(0.2), .primary.opacity(0.04)] }
    
    /// 从宠物详情进入时固定为该宠物；否则使用 AppStorage 筛选
    private var effectivePetFilterId: String? {
        if let p = preselectedPetId { return p }
        return calendarFilterPetId.isEmpty ? nil : calendarFilterPetId
    }

    private var filteredEvents: [Event] {
        var result = events.filter { $0.eventType != EventType.foodChange.rawValue }
        if let petId = effectivePetFilterId {
            result = result.filter { eventIsRelatedToPet($0, petId: petId) }
        }
        return result
    }

    private func eventIsRelatedToPet(_ event: Event, petId: String) -> Bool {
        let entityType = event.relatedEntityType.lowercased()
        if event.relatedEntityId == petId {
            return entityType == EntityKind.pet.rawValue.lowercased()
                || entityType == "pet"
                || entityType == "pet_food_stock"
        }
        if entityType == "pet_insurance" {
            return insurances.first { $0.id.uuidString == event.relatedEntityId }?.pet?.id.uuidString == petId
        }
        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication.lowercased() {
            return petMedications.first { $0.id.uuidString == event.relatedEntityId }?.pet?.id.uuidString == petId
        }
        return false
    }

    /// 嵌入 Overview 时顶栏 + 外层宠物条占位（经典 Ark）；略减小使宠物筛选条更靠上
    private var overviewCalendarEmbedTopInset: CGFloat { 98 }

    private var shouldShowInlinePetChips: Bool {
        preselectedPetId == nil && (!hideToolbar || isMaterial)
    }

    // D1: 展开重复事件 → 生成虚拟 (Event, occurrenceDate) 对，用于列表视图分组
    private struct EventOccurrence: Identifiable {
        let id: String          // event.id + date
        let event: Event
        let occurrenceDate: Date
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
                    result.append(EventOccurrence(
                        id: "\(event.id.uuidString)-\(cursor.timeIntervalSince1970)",
                        event: event,
                        occurrenceDate: cursor
                    ))
                    cursor = cal.date(byAdding: .day, value: event.recurrenceDays, to: cursor) ?? cursor
                    safety += 1
                }
            } else {
                if eStart >= cutoff && eStart <= future {
                    result.append(EventOccurrence(
                        id: event.id.uuidString,
                        event: event,
                        occurrenceDate: eStart
                    ))
                }
            }
        }
        return result.sorted { $0.occurrenceDate > $1.occurrenceDate }
    }
    
    private var eventsForSelectedDate: [Event] {
        filteredEvents.filter { eventOccursOnDate($0, date: selectedDate) }
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
        NavigationStack {
            ZStack(alignment: .top) {
                if isMaterial { matBg.ignoresSafeArea() } else { ArkBackgroundView() }
                
                VStack(spacing: 0) {
                    if isMaterial {
                        // Material 模式：为 sticky header 留空间
                        Spacer().frame(height: 68)
                    } else if !hideToolbar {
                        // 经典模式：独立页面时显示顶栏（嵌入 OverviewView 时由外层 header 负责）
                        classicCalendarHeader
                    } else {
                        // 嵌入 Overview：为全局顶栏 + 外层宠物筛选条留出空间
                        Spacer().frame(height: overviewCalendarEmbedTopInset)
                    }

                    if shouldShowInlinePetChips {
                        CalendarPetChipFilterBar()
                    }
                    
                    switch viewMode {
                    case .month:
                        goMonthView
                    case .list:
                        goListView
                    }
                }

                // Material 模式 Sticky Header
                if isMaterial {
                    calStickyHeader
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddEvent) { AddEventView() }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
            .onChange(of: addEventTrigger) { _, _ in showingAddEvent = true }
            .onAppear { coconutCount = QuestManager.shared.coconutCount }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("coconutCountChanged"))) { _ in
                coconutCount = QuestManager.shared.coconutCount
            }
        }
    }

    // MARK: - Classic Calendar Header
    private var classicCalendarHeader: some View {
        HStack(spacing: 12) {
            // 月历标题
            Text(Date(), format: .dateTime.year().month(.wide))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            // 视图切换胶囊
            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(3)
            .goGlassBackground(Capsule())

            // 添加事件按钮
            Button { showingAddEvent = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.goPrimary, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Sticky Calendar Header (Material)
    private var calStickyHeader: some View {
        let bg: Color = colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C")
        let surface: Color = colorScheme == .light ? .white : Color(hex: "1C1C1E")
        let accent = Color(hex: "FF5A00")
        let textSec: Color = colorScheme == .light ? Color(hex: "8E8E93") : Color(hex: "64748B")
        return HStack(spacing: 10) {
            // Add event
            Button { showingAddEvent = true } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 2)
            }.buttonStyle(ScaleButtonStyle())

            // View toggle pill
            HStack(spacing: 2) {
                iconModeBtn(systemName: "calendar", mode: .month)
                iconModeBtn(systemName: "list.bullet.rectangle.fill", mode: .list)
            }
            .padding(4)
            .goGlassBackground(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)

            Spacer()

            // Coconut count (rightmost, matches home)
            Button { showingCoconutLog = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(accent)
                    Text("\(coconutCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: coconutCount)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(surface, in: Capsule())
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }.buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            bg.opacity(0.92)
                .background(.ultraThinMaterial)
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
                    let dayEvents = filteredEvents.filter { eventOccursOnDate($0, date: day) }
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
                        withAnimation(.spring(response: 0.25)) { selectedDate = day }
                    } label: {
                        VStack(spacing: 5) {
                            Text(day, format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? chipSelFg : (isMaterial ? Color(hex: "8E8E93") : classicSoftText))
                            
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(isSelected ? chipSelFg : (isToday ? chipAccent : (isMaterial ? .primary : classicPrimaryText)))
                            
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
            return colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.48)
        }()
        return Button {
            withAnimation(.spring(response: 0.28)) { viewModeRaw = mode.rawValue }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(viewMode == mode ? chipSelFg : unselectedTint)
                .frame(width: 36, height: 30)
                .background { if viewMode == mode { Capsule().fill(chipAccent) } }
        }
    }
    
    // MARK: - Go Month View
    private var goMonthView: some View {
        VStack(spacing: 12) {
            // Month header — Go 风格
            HStack {
                Button {
                    withAnimation { selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(isMaterial ? matSurface : classicSubtleFill, in: Circle())
                }
                
                Spacer()
                
                Text(selectedDate, format: .dateTime.year().month(.wide))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    withAnimation { selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary.opacity(0.6))
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
                        .foregroundStyle(.primary.opacity(0.3))
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
                        let hasEvents = filteredEvents.contains { eventOccursOnDate($0, date: date) }
                        
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                selectedDate = date
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? chipSelFg : (isToday ? chipAccent : (isMaterial ? .primary : classicPrimaryText)))
                                
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
                                .foregroundStyle(.primary.opacity(0.35))
                            Text("暂无事件")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
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
    }
    
    // MARK: - Go List View（时间轴版）
    private var goListView: some View {
        ZStack(alignment: .topLeading) {
            // 环境光斑（毛玻璃卡片后方，营造流动光影）
            ambientLightBlobs

            ScrollView {
                // D1: 用展开后的重复事件按 occurrenceDate 分组
                let grouped = Dictionary(grouping: expandedOccurrences) { occ in
                    Calendar.current.startOfDay(for: occ.occurrenceDate)
                }.sorted { $0.key > $1.key }

                if grouped.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.fill")
                            .font(OhanaFont.metric(size: 40, .medium))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.tertiary)
                        Text("暂无记录")
                            .font(OhanaFont.headline(.bold))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(grouped, id: \.key) { date, occurrences in
                            timelineSection(date: date, occurrences: occurrences)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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
        VStack(spacing: 0) {
            // 日期组头
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Calendar.current.isDateInToday(date) ? chipAccent : (isMaterial ? Color(hex: "C7C7CC") : classicDotFill))
                        .frame(width: 10, height: 10)
                    if Calendar.current.isDateInToday(date) {
                        Circle().fill(.clear).frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(chipAccent.opacity(0.3), lineWidth: 1.5))
                    }
                }
                .frame(width: 40)

                Text(relativeDate(date))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? chipAccent : (isMaterial ? Color(hex: "8E8E93") : classicSoftText))
                    .tracking(0.5)

                Text("·  \(occurrences.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.25))

                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 6)

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
                    ForEach(occurrences) { occ in
                        goEventRow(occ.event, occurrenceDate: occ.occurrenceDate)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        if AppLanguage.isEnglish {
            formatter.dateFormat = sameYear ? "EEEE, MMM d" : "MMM d, yyyy"
        } else {
            formatter.dateFormat = sameYear ? "M月d日 EEEE" : "yyyy年M月d日"
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
                withAnimation(.spring(response: 0.3)) {
                    event.toggleOccurrenceComplete(on: occurrenceDate)
                    let now = Date()
                    let cal = Calendar.current
                    let today = cal.startOfDay(for: now)
                    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
                    // 仅单次事件同步「今日」提醒状态；重复序列按日完成不写 isCompleted，避免误伤整批 Reminder
                    if event.recurrenceDays == 0 {
                        for reminder in event.reminders {
                            if reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow {
                                let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                                if event.isCompleted {
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
            onDelete: { /* F2: 删除逻辑已在 SwipeableEventRow 内处理 */ }
        )
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
}

#Preview {
    CalendarView()
        .modelContainer(SharedModelContainer.make())
}
