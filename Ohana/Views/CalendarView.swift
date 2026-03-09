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
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    
    @State private var selectedDate = Date()
    @State private var selectedPetFilter: String? = nil
    @State private var showingAddEvent = false
    @State private var showingCoconutLog = false
    @State private var viewMode: CalendarViewMode = .list
    @State private var deletingEvent: Event? = nil
    @State private var showDeleteSeriesAlert = false
    
    enum CalendarViewMode: String, CaseIterable {
        case month = "月"
        case list = "列表"
    }
    
    private var filteredEvents: [Event] {
        var result = events
        if let petId = selectedPetFilter ?? preselectedPetId {
            result = result.filter { $0.relatedEntityId == petId }
        }
        return result
    }
    
    private var eventsForSelectedDate: [Event] {
        filteredEvents.filter { eventOccursOnDate($0, date: selectedDate) }
    }

    /// 判断事件是否出现在指定日期（支持多日事件）
    private func eventOccursOnDate(_ event: Event, date: Date) -> Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        let eStart = event.startDate
        let eEnd = event.endDate ?? eStart  // 无 endDate 则等于 startDate
        // 事件范围与当天范围有交集
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
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // 1. 日历模式切换（独立胶囊背景）
                        HStack(spacing: 2) {
                            iconModeBtn(systemName: "calendar", mode: .month)
                            iconModeBtn(systemName: "list.bullet", mode: .list)
                        }
                        .padding(3)
                        .background(.white.opacity(0.1), in: Capsule())

                        // 2. 添加事件按钮（独立，无联合背景）
                        Button { showingAddEvent = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.goLime)
                        }

                        // 3. 椰子余额（完全独立的视觉个体）
                        CoconutBalanceCapsule { showingCoconutLog = true }
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) { AddEventView() }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
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
                goChipButton(label: "All", emoji: "🏝️", isSelected: selectedPetFilter == nil) {
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
            withAnimation(.spring(response: 0.28)) { viewMode = mode }
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
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: Circle())
                }
                
                Spacer()
                
                Text(selectedDate, format: .dateTime.year().month(.wide))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    withAnimation { selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
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
                        .foregroundStyle(.white.opacity(0.3))
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
                            Text("No events")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.top, 20)
                    } else {
                        ForEach(eventsForSelectedDate) { event in
                            goEventRow(event)
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
                let grouped = Dictionary(grouping: filteredEvents) { event in
                    Calendar.current.startOfDay(for: event.startDate)
                }.sorted { $0.key > $1.key }

                if grouped.isEmpty {
                    VStack(spacing: 12) {
                        Text("📭").font(.system(size: 40))
                        Text("暂无记录")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(grouped, id: \.key) { date, dayEvents in
                            timelineSection(date: date, events: dayEvents)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            // ✅ alert 挂在列表级别，唯一实例，消除 ForEach 多行竞争
            .alert("删除事件", isPresented: $showDeleteSeriesAlert, presenting: deletingEvent) { ev in
                Button("删除此条", role: .destructive) {
                    modelContext.delete(ev)
                    modelContext.safeSave()
                    deletingEvent = nil
                }
                if ev.recurrenceDays > 0 {
                    Button("删除此条及之后所有重复", role: .destructive) {
                        deleteSeriesFrom(ev)
                        deletingEvent = nil
                    }
                }
                Button("取消", role: .cancel) { deletingEvent = nil }
            } message: { ev in
                Text(ev.recurrenceDays > 0 ? "这是一个重复事件，请选择删除方式" : "确认删除「\(ev.title)」吗？")
            }
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
    private func timelineSection(date: Date, events: [Event]) -> some View {
        VStack(spacing: 0) {
            // 日期组头
            HStack(spacing: 10) {
                // 日期节点圆点
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

                Text("·  \(events.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))

                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 6)

            // 事件行列（左侧纵线贯穿）
            HStack(alignment: .top, spacing: 0) {
                // 纵向时间线（LinearGradient 发光光纤效果）
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

                // 事件卡片列
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        goEventRow(event)
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
    private func goEventRow(_ event: Event) -> some View {
        SwipeableEventRow(
            event: event,
            onComplete: {
                withAnimation(.spring(response: 0.3)) {
                    event.isCompleted.toggle()
                    // N6: 同步所有关联的今日 Reminder 状态
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
            onDelete: {
                deletingEvent = event
                showDeleteSeriesAlert = true
            }
        )
    }

    private func deleteSeriesFrom(_ event: Event) {
        let sameTitle = events.filter { $0.title == event.title && $0.startDate >= event.startDate }
        for ev in sameTitle { modelContext.delete(ev) }
        modelContext.safeSave()
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
