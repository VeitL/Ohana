//
//  CalendarView+List.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CalendarView {
    // MARK: - Go List View（时间轴版）
    var goListView: some View {
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
    var ambientLightBlobs: some View {
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
    func timelineSection(date: Date, occurrences: [EventOccurrence]) -> some View {
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
                        .font(OhanaFont.footnote(.black))
                        .foregroundStyle(isMaterial ? Color(hex: "8E8E93") : classicSoftText)
                        .tracking(0.5)

                    Text("·  \(occurrences.count)")
                        .font(OhanaFont.caption(.bold))
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

    func todayTimelineAnchor(date: Date, count: Int) -> some View {
        HStack(spacing: 10) {
            timelineDateBadge(date, isToday: true)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("今天")
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(chipAccent)
                    Text(count == 0 ? "暂无事件" : "\(count) 项")
                        .font(OhanaFont.footnote(.bold))
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

    func timelineDateBadge(_ date: Date, isToday: Bool) -> some View {
        let dayNumber = Calendar.current.component(.day, from: date)
        return VStack(spacing: 3) {
            Text(weekdayShort(date))
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(isToday ? chipAccent : classicSoftText)
                .textCase(.uppercase)

            Text("\(dayNumber)")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(isToday ? chipSelFg : classicPrimaryText)
                .ohanaNumericMotion(dayNumber)
                .frame(width: 34, height: 34) // a11y: allow fixed-format noninteractive date badge
                .background(isToday ? chipAccent : classicSubtleFill, in: Circle())
        }
    }

    var emptyTodayPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative empty-state icon
                .font(OhanaFont.callout(.bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(chipAccent)
                .accessibilityHidden(true)
            Text("今天没有安排，保持轻松")
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(classicPrimaryText.opacity(0.66))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(classicSubtleFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    func weekdayShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func timelineDateID(_ date: Date) -> String {
        String(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))
    }

    func scheduleInitialListPositionIfNeeded() {
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

    func scheduleInitialTimelineScrollIfNeeded(proxy: ScrollViewProxy) {
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
            if let calendarOpenStartedAt {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.calendarOpen,
                    AppPerformancePhases.dataReady,
                    startedAt: calendarOpenStartedAt,
                    note: ["timelineSections": "\(timelineSections.count)"]
                )
            }
            listInitialPositionTask = nil
        }
    }

    func scrollTimeline(_ proxy: ScrollViewProxy, to dateID: String, animated: Bool) {
        guard timelineDateIDs.contains(dateID) else { return }
        if animated {
            withAnimation(GoMotion.selection) {
                proxy.scrollTo(dateID, anchor: .top)
            }
        } else {
            proxy.scrollTo(dateID, anchor: .top)
        }
    }

    func returnCalendarToToday() {
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

    func scrollListToToday(proxy: ScrollViewProxy) {
        guard isCalendarPrepared else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let todayID = timelineDateID(today)
        guard timelineDateIDs.contains(todayID) else { return }
        scrollTimeline(proxy, to: todayID, animated: false)
        scheduleVisibleCalendarMonthUpdate(from: todayID)
    }

    func scheduleVisibleCalendarMonthUpdate(from dateID: String?) {
        guard isCalendarPrepared else { return }
        guard let dateID,
              let timestamp = TimeInterval(dateID) else { return }
        let date = Date(timeIntervalSince1970: timestamp)
        visibleDateCoordinator.scheduleUpdate(to: date) { normalized in
            guard isCalendarPrepared else { return }
            updateVisibleCalendarMonth(to: normalized)
        }
    }

    func updateVisibleCalendarMonth(to normalized: Date) {
        guard !Calendar.current.isDate(listVisibleTopDate, inSameDayAs: normalized) else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            listVisibleTopDate = normalized
        }
    }

    func relativeDate(_ date: Date) -> String {
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
    func goEventRow(_ event: Event, occurrenceDate: Date) -> some View {
        let relatedPetColor: Color? = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets)
            .map { Color(hex: $0.themeColorHex) }
            ?? DomainEntityLinkRegistry.plantId(
                for: DomainEntityLink(event: event)
            )
            .flatMap { plantId in plants.first(where: { $0.id == plantId }) }
            .map { Color(hex: $0.themeColorHex) }
        return SwipeableEventRow(
            event: event,
            occurrenceDate: occurrenceDate,
            petThemeColor: relatedPetColor,
            onComplete: {
                let executor = CalendarCommandExecutor(context: modelContext, services: appServices)
                executor.toggleCompletion(
                    event: event,
                    occurrenceDate: occurrenceDate,
                    pets: pets,
                    executorId: appServices.activeHumanSelection.currentHumanId,
                    note: "calendar.event.completion.toggle"
                )
            },
            onDelete: { /* F2: 删除逻辑已在 SwipeableEventRow 内处理 */ },
            onOpenRelated: {
                openRelatedDestination(for: event)
            }
        )
    }

    func openRelatedDestination(for event: Event) -> Bool {
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

    func presentCoconutLog() {
        onPresentCoconutLog?(nil)
    }
}
