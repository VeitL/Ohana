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

struct CalendarView: View {
    var preselectedPetId: String? = nil
    var hideToolbar: Bool = false
    var addEventTrigger: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    
    @State private var selectedDate = Date()
    @State private var selectedPetFilter: String? = nil
    @State private var showingAddEvent = false
    @State private var showingCoconutLog = false
    @AppStorage("calendar_viewMode") private var viewModeRaw: String = CalendarViewMode.list.rawValue
    private var viewMode: CalendarViewMode { CalendarViewMode(rawValue: viewModeRaw) ?? .list }
    @State private var deletingEvent: Event? = nil
    @State private var showDeleteSeriesAlert = false
    
    private var filteredEvents: [Event] {
        var result = events
        if let petId = selectedPetFilter ?? preselectedPetId {
            result = result.filter { $0.relatedEntityId == petId }
        }
        return result
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
            ZStack {
                ArkBackgroundView()
                
                VStack(spacing: 0) {
                    // R6: 全局 header 占位
                    Spacer().frame(height: 70)

                    if !hideToolbar {
                        // 日历工具栏（独立使用时显示，嵌入 tab 时由全局 header 提供）
                        HStack(spacing: 12) {
                            Spacer()
                            HStack(spacing: 2) {
                                iconModeBtn(systemName: "calendar", mode: .month)
                                iconModeBtn(systemName: "list.bullet", mode: .list)
                            }
                            .padding(3)
                            .background(.white.opacity(0.1), in: Capsule())
                            Button { showingAddEvent = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.goLime)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    }

                    // Go 风格 Pet Chip 筛选器
                    goPetChipFilter
                    
                    switch viewMode {
                    case .month:
                        goMonthView
                    case .list:
                        goListView
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddEvent) { AddEventView() }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
            .onChange(of: addEventTrigger) { _, _ in showingAddEvent = true }
        }
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
                    
                    Button {
                        withAnimation(.spring(response: 0.25)) { selectedDate = day }
                    } label: {
                        VStack(spacing: 5) {
                            Text(day, format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? Color.arkInk : .white.opacity(0.4))
                            
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(isSelected ? Color.arkInk : (isToday ? Color.goLime : .white.opacity(0.85)))
                            
                            // 事件点
                            ZStack {
                                Circle()
                                    .fill(hasEvents
                                          ? (isSelected ? Color.arkInk.opacity(0.5) : Color.goLime)
                                          : Color.clear)
                                    .frame(width: 5, height: 5)
                                
                                if !hasEvents {
                                    Circle().fill(Color.clear).frame(width: 5, height: 5)
                                }
                            }
                            
                            // 首个事件 emoji
                            if let first = dayEvents.first {
                                Text(first.emoji)
                                    .font(.system(size: 12))
                            } else {
                                Color.clear.frame(height: 16)
                            }
                        }
                        .frame(width: 44)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.goLime : (isToday ? Color.white.opacity(0.08) : Color.clear),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Go Pet Chip Filter
    private var goPetChipFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                goChipButton(label: "全部", emoji: "🏝️", isSelected: selectedPetFilter == nil) {
                    selectedPetFilter = nil
                }
                
                ForEach(pets) { pet in
                    goChipButton(
                        label: pet.name,
                        emoji: pet.avatarEmoji,
                        isSelected: selectedPetFilter == pet.id.uuidString
                    ) {
                        selectedPetFilter = pet.id.uuidString
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    private func goChipButton(label: String, emoji: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.arkInk : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.goLime : Color.white.opacity(0.1),
                in: Capsule()
            )
        }
    }
    
    // MARK: - Go View Mode Toggle（图标版）
    private var goViewModeToggle: some View {
        HStack(spacing: 2) {
            iconModeBtn(systemName: "calendar", mode: .month)
            iconModeBtn(systemName: "list.bullet", mode: .list)
        }
        .padding(3)
        .background(.white.opacity(0.1), in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func iconModeBtn(systemName: String, mode: CalendarViewMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.28)) { viewModeRaw = mode.rawValue }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(viewMode == mode ? Color.arkInk : .white.opacity(0.45))
                .frame(width: 36, height: 30)
                .background {
                    if viewMode == mode {
                        Capsule().fill(Color.goLime)
                    }
                }
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
                        .foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: Circle())
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
                        .foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: Circle())
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
                                    .foregroundStyle(isSelected ? Color.arkInk : (isToday ? Color.goLime : .white.opacity(0.85)))
                                
                                Circle()
                                    .fill(hasEvents ? (isSelected ? Color.arkInk.opacity(0.5) : Color.goLime) : .clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(width: 40, height: 48)
                            .background(
                                isSelected ? Color.goLime : (isToday ? Color.white.opacity(0.08) : .clear),
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
                            Text("📭")
                                .font(.system(size: 32))
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
                        Text("📭").font(.system(size: 40))
                        Text("暂无记录")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
    private var ambientLightBlobs: some View {
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
                colors: [Color.goLime.opacity(0.08), .clear],
                center: .init(x: 0.8, y: 0.7),
                startRadius: 0, endRadius: 120
            )
            .frame(width: 200, height: 200)
            .offset(x: UIScreen.main.bounds.width * 0.5, y: 300)
            .blur(radius: 18)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    // 单日时间轴组
    private func timelineSection(date: Date, occurrences: [EventOccurrence]) -> some View {
        VStack(spacing: 0) {
            // 日期组头
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Calendar.current.isDateInToday(date) ? Color.goLime : .white.opacity(0.12))
                        .frame(width: 10, height: 10)
                    if Calendar.current.isDateInToday(date) {
                        Circle().fill(.clear).frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(Color.goLime.opacity(0.3), lineWidth: 1.5))
                    }
                }
                .frame(width: 40)

                Text(relativeDate(date))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? Color.goLime : .white.opacity(0.4))
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
                                colors: [.white.opacity(0.35), .white.opacity(0.06)],
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
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "M月d日 EEEE" : "yyyy年M月d日"
        return formatter.string(from: date)
    }
    
    // MARK: - Go Event Row
    private func goEventRow(_ event: Event, occurrenceDate: Date) -> some View {
        SwipeableEventRow(
            event: event,
            occurrenceDate: occurrenceDate,
            onComplete: {
                withAnimation(.spring(response: 0.3)) {
                    event.isCompleted.toggle()
                    let now = Date()
                    let today = Calendar.current.startOfDay(for: now)
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
                    for reminder in event.reminders {
                        if reminder.scheduledAt >= today && reminder.scheduledAt < tomorrow {
                            reminder.status = event.isCompleted ? "completed" : "pending"
                            reminder.completedAt = event.isCompleted ? now : nil
                        }
                    }
                    modelContext.safeSave()
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
