//
//  DailyStreakDetailView.swift
//  Ohana
//
//  打卡连击详情页 — 打卡日历 + 连击排行
//

import SwiftUI
import SwiftData

struct DailyStreakDetailView: View {
    let pets: [Pet]
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \CareLedgerEvent.occurredAt, order: .reverse) private var ledgerEvents: [CareLedgerEvent]
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @State private var selectedMonth = Date()
    @State private var checkedInDates: Set<String> = []
    @State private var makeupDates: Set<String> = []
    @State private var makeupPackCount = 0
    @State private var showMakeupConfirm: String? = nil
    @State private var showCoconutShop = false
    @State private var showingCoconutLog = false
    @State private var lastClaimedMilestone = 0
    @State private var monthSlideDirection = 1

    private let cal = Calendar.current
    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == currentActiveHumanId } ?? humans.first
    }
    private var activeHumanIdForStreak: String {
        activeHuman?.id.uuidString ?? currentActiveHumanId
    }

    var body: some View {
        OhanaSheetPageScaffold(
            title: "打卡连击",
            subtitle: activeHuman?.name ?? "Ohana",
            onClose: closePage,
            leading: {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.ohanaControlFill, in: Circle())
            },
            trailing: {
                CoconutBalanceCapsule(balance: activeHuman?.coconutBalance ?? 0) {
                    showingCoconutLog = true
                }
            },
            content: {
                VStack(spacing: 16) {
                    myStreakCard
                    if humans.count > 1 {
                        familyCompetitionSection
                    }
                    checkInCalendarSection
                }
                .padding(.bottom, 18)
            },
            floating: {
                EmptyView()
            }
        )
        .onAppear {
            selectedMonth = Date()
            loadCheckInData()
            triggerTodayCheckIn()
        }
        .onChange(of: currentActiveHumanId) { _, _ in
            selectedMonth = Date()
            loadCheckInData()
            triggerTodayCheckIn()
        }
        .alert(
            "补签确认",
            isPresented: Binding(get: { showMakeupConfirm != nil }, set: { if !$0 { showMakeupConfirm = nil } })
        ) {
            Button("消耗1个补签包确认") {
                if let date = showMakeupConfirm {
                    applyMakeup(date: date)
                }
                showMakeupConfirm = nil
            }
            Button("取消", role: .cancel) { showMakeupConfirm = nil }
        } message: {
            Text("补签 \(showMakeupConfirm ?? "")，将消耗1个补签包")
        }
        .sheet(isPresented: $showCoconutShop) {
            CoconutShopView(initialCategory: .boost)
                .ohanaSheetPagePresentation() // ui-v4: allow long shop overview
        }
        .sheet(isPresented: $showingCoconutLog) {
            CoconutLogView()
        }
        .onChange(of: showCoconutShop) { _, isShowing in
            if !isShowing { loadCheckInData() }
        }
    }

    private func closePage() {
        onClose?()
        dismiss()
    }

    // MARK: - 我的连击卡片
    private var myStreakCard: some View {
        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: activeHuman?.safeThemeColorHex ?? OhanaThemeColorPolicy.humanFallbackHex).opacity(0.25))
                        .frame(width: 52, height: 52)
                    if let data = activeHuman?.avatarImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    } else {
                        Text(activeHuman?.avatarEmoji ?? "🧑")
                            .font(.system(size: 26))
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(activeHuman?.name ?? "我")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("每天打开 App 即打卡")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(currentStreak)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(currentStreak > 0 ? Color.goOrange : Color.ohanaPrimaryText.opacity(0.25))
                            .contentTransition(.numericText())
                        Text("天")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                    }
                    Text(currentStreak >= 30 ? "🔥 传奇！" : currentStreak >= 7 ? "🔥 火热！" : "继续保持")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.goOrange)
                }
            }

            // 里程碑进度条
            let milestones = [3, 7, 14, 30, 60, 100]
            if let next = milestones.first(where: { $0 > currentStreak }) {
                let prev = milestones.last(where: { $0 <= currentStreak }) ?? 0
                let progress = Double(currentStreak - prev) / Double(next - prev)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("距离 \(next) 天里程碑")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        Spacer()
                        Text("还差 \(next - currentStreak) 天")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goOrange.opacity(0.8))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.ohanaPrimaryText.opacity(0.1))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: [Color.goOrange, Color.goYellow], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        }
    }

    private var familyCompetitionSection: some View {
        let leaderboard = familyLeaderboard
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("家庭连击")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("本周照护贡献，谁最稳一眼就知道")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goOrange)
            }

            VStack(spacing: 8) {
                ForEach(Array(leaderboard.prefix(4).enumerated()), id: \.element.human.id) { index, entry in
                    HStack(spacing: 10) {
                        Text(index == 0 ? "🏆" : "\(index + 1)")
                            .font(.system(size: index == 0 ? 20 : 13, weight: .black, design: .rounded))
                            .foregroundStyle(index == 0 ? Color.goYellow : Color.ohanaSecondaryText)
                            .frame(width: 28)
                        humanAvatar(entry.human, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.human.name)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                            Text(entry.count == 0 ? "本周还没有记录" : "\(entry.count) 次照护 · +\(entry.coconuts)🥥")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer()
                        Text("\(entry.count)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(index == 0 ? Color.goPrimary : Color.ohanaPrimaryText)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(index == 0 ? Color.goPrimary.opacity(0.14) : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        }
    }

    private var checkInCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                    Text("打卡日历")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(currentStreak) 天连胜")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goOrange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.goOrange.opacity(0.12), in: Capsule())
            }

            checkInStatsRow

            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.08))

            HStack {
                Button {
                    shiftCheckInMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background(Color.ohanaControlFill, in: Circle())
                }

                Spacer()

                Text(monthYearString(selectedMonth))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)

                Spacer()

                Button {
                    shiftCheckInMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
                            ? Color.ohanaPrimaryText.opacity(0.15)
                            : Color.ohanaPrimaryText.opacity(0.5)
                        )
                        .frame(width: 36, height: 36)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .disabled(cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }

            HStack(spacing: 0) {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = monthCalendarCells(for: selectedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    calendarDayCell(cell)
                }
            }
            .id(checkInMonthKey)
            .transition(.asymmetric(
                insertion: .move(edge: monthSlideDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: monthSlideDirection > 0 ? .leading : .trailing).combined(with: .opacity)
            ))

            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.08))

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("📦").font(.system(size: 14))
                    Text("补签包")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    Text("×\(makeupPackCount)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(makeupPackCount > 0 ? Color.goPrimary : Color.ohanaPrimaryText.opacity(0.3))
                }
                Spacer()
                if makeupPackCount > 0 {
                    Text("点击灰色日期补签")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.goPrimary.opacity(0.7))
                } else {
                    Button { showCoconutShop = true } label: {
                        Text("去商店购买 →")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goYellow.opacity(0.85))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            if currentStreak > 0 {
                checkInMilestoneRow
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
    }

    private var checkInStatsRow: some View {
        HStack(spacing: 10) {
            checkInStatCell(value: "\(checkedInDates.count)", label: "总打卡", icon: "checkmark.circle.fill", color: Color.goPrimary)
            checkInStatCell(value: "\(currentStreak)", label: "当前连胜", icon: "flame.fill", color: Color.goOrange)
            checkInStatCell(value: "\(longestStreak)", label: "最长连胜", icon: "trophy.fill", color: Color.goYellow)
            checkInStatCell(value: "\(monthCheckInRate)%", label: "本月", icon: "chart.bar.fill", color: Color.goCardCyan)
        }
    }

    private func checkInStatCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var checkInMilestoneRow: some View {
        let milestones: [(days: Int, reward: Int, emoji: String)] = [
            (7, 10, "⭐️"), (14, 25, "🌟"), (30, 60, "💎"), (60, 150, "👑"), (100, 300, "🏆")
        ]
        let nextMilestone = milestones.first(where: { $0.days > currentStreak })
        let lastClaimed = lastClaimedMilestone

        return VStack(spacing: 8) {
            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.08))

            if let nextMilestone {
                HStack(spacing: 6) {
                    Text(nextMilestone.emoji)
                    Text("再连续 \(nextMilestone.days - currentStreak) 天即可领取 +\(nextMilestone.reward)🥥")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goPrimary.opacity(0.75))
                    Spacer()
                }
            }

            let claimable = milestones.filter { $0.days <= currentStreak && $0.days > lastClaimed }
            ForEach(claimable, id: \.days) { milestone in
                Button {
                    claimMilestone(milestone.days, reward: milestone.reward, emoji: milestone.emoji)
                } label: {
                    HStack(spacing: 8) {
                        Text(milestone.emoji)
                            .font(.system(size: 16))
                        Text("\(milestone.days) 天连胜达成！")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                        Spacer()
                        Text("+\(milestone.reward)🥥 领取")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private struct CalendarCell {
        let dateStr: String
        let day: Int
        let isToday: Bool
        let isChecked: Bool
        let isMakeup: Bool
        let isFuture: Bool
    }

    private func monthCalendarCells(for month: Date) -> [CalendarCell] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let comps = cal.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = cal.date(from: comps) else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var cells: [CalendarCell] = []
        for _ in 0..<weekdayOfFirst {
            cells.append(CalendarCell(dateStr: "", day: 0, isToday: false, isChecked: false, isMakeup: false, isFuture: false))
        }

        let todayString = fmt.string(from: Date())
        for day in 1...daysInMonth {
            var dc = DateComponents()
            dc.year = comps.year
            dc.month = comps.month
            dc.day = day
            let date = cal.date(from: dc) ?? firstOfMonth
            let dateStr = fmt.string(from: date)
            let isToday = dateStr == todayString
            let isChecked = checkedInDates.contains(dateStr)
            let isMakeup = makeupDates.contains(dateStr)
            let isFuture = date > Date() && !isToday
            cells.append(CalendarCell(dateStr: dateStr, day: day, isToday: isToday, isChecked: isChecked, isMakeup: isMakeup, isFuture: isFuture))
        }
        return cells
    }

    private var checkInMonthKey: String {
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .local)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > 44, abs(width) > abs(height) * 1.25 else { return }
                shiftCheckInMonth(by: width < 0 ? 1 : -1)
            }
    }

    private func shiftCheckInMonth(by delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: selectedMonth) else { return }
        if next > Date(), !cal.isDate(next, equalTo: Date(), toGranularity: .month) {
            return
        }
        monthSlideDirection = delta >= 0 ? 1 : -1
        withAnimation(GoMotion.selection) {
            selectedMonth = next
        }
    }

    @ViewBuilder
    private func calendarDayCell(_ cell: CalendarCell) -> some View {
        if cell.dateStr.isEmpty {
            Color.clear.frame(height: 40)
        } else {
            Button {
                if !cell.isChecked && !cell.isToday && !cell.isFuture && makeupPackCount > 0 {
                    showMakeupConfirm = cell.dateStr
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(cellFillColor(cell))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().strokeBorder(
                                cell.isToday ? Color.goPrimary : .clear,
                                lineWidth: 1.5
                            )
                        )
                    if cell.isChecked {
                        if cell.isMakeup {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Color.ohanaPrimaryActionText.opacity(0.72))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.ohanaPrimaryActionText)
                        }
                    } else {
                        Text("\(cell.day)")
                            .font(.system(size: 13, weight: cell.isToday ? .black : .medium, design: .rounded))
                            .foregroundStyle(
                                cell.isFuture ? Color.ohanaPrimaryText.opacity(0.2) :
                                cell.isToday ? Color.goPrimary :
                                Color.ohanaPrimaryText.opacity(0.7)
                            )
                    }
                }
                .frame(height: 40)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(cell.isChecked || cell.isToday || cell.isFuture || makeupPackCount == 0)
        }
    }

    private func cellFillColor(_ cell: CalendarCell) -> Color {
        if cell.isChecked && cell.isMakeup {
            return Color.goYellow.opacity(0.85)
        } else if cell.isChecked {
            return Color.goPrimary
        } else if cell.isToday {
            return Color.goPrimary.opacity(0.22)
        } else {
            return Color.ohanaControlFill
        }
    }

    @ViewBuilder
    private func humanAvatar(_ human: Human, size: CGFloat) -> some View {
        if let data = human.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(human.avatarEmoji.isEmpty ? "🧑" : human.avatarEmoji)
                .font(.system(size: size * 0.52))
                .frame(width: size, height: size)
                .background(Color(hex: human.safeThemeColorHex).opacity(0.18), in: Circle())
        }
    }

    private var familyLeaderboard: [(human: Human, count: Int, coconuts: Int)] {
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? cal.date(byAdding: .day, value: -7, to: Date())
            ?? Date()
        let interval = DateInterval(start: start, end: Date())
        let livingPets = pets.filter { !$0.hasPassedAway }
        let entries = CareLedgerStatsService.reportEntries(
            events: ledgerEvents,
            pets: livingPets,
            humans: humans,
            interval: interval
        )
        return humans
            .map { human in
                let id = human.id.uuidString
                let mine = entries.filter { $0.actorId == id }
                return (human, mine.count, mine.reduce(0) { $0 + $1.coconuts })
            }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.coconuts != $1.coconuts { return $0.coconuts > $1.coconuts }
                return $0.human.createdAt < $1.human.createdAt
            }
    }

    private var shortDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = AppLanguage.effectiveLocale
        f.dateFormat = AppLanguage.compactMonthDayFormat
        return f
    }

    private var monthYearFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = AppLanguage.effectiveLocale
        f.dateFormat = AppLanguage.fullMonthYearFormat
        return f
    }

    private func monthYearString(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    private func todayStr() -> String {
        CheckInStreakStore.dateString()
    }

    private var currentStreak: Int {
        CheckInStreakStore.currentStreak(for: activeHumanIdForStreak, calendar: cal)
    }

    private var longestStreak: Int {
        CheckInStreakStore.longestStreak(for: activeHumanIdForStreak, calendar: cal)
    }

    private var monthCheckInRate: Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let comps = cal.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = cal.date(from: comps) else { return 0 }
        let dayOfMonth = cal.component(.day, from: today)
        var count = 0
        for day in 0..<dayOfMonth {
            if let date = cal.date(byAdding: .day, value: day, to: firstOfMonth) {
                let value = fmt.string(from: date)
                if checkedInDates.contains(value) {
                    count += 1
                }
            }
        }
        return dayOfMonth > 0 ? Int(Double(count) / Double(dayOfMonth) * 100) : 0
    }

    private func loadCheckInData() {
        checkedInDates = CheckInStreakStore.checkedInDates(for: activeHumanIdForStreak)
        makeupDates = CheckInStreakStore.makeupDates(for: activeHumanIdForStreak)
        makeupPackCount = UserDefaults.standard.integer(forKey: CheckInStreakStore.makeupPackKey)
        lastClaimedMilestone = CheckInStreakStore.lastClaimedMilestone(for: activeHumanIdForStreak)
    }

    private func triggerTodayCheckIn() {
        let today = todayStr()
        guard !checkedInDates.contains(today) else { return }
        checkedInDates.insert(today)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: activeHumanIdForStreak)
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: "每日打卡奖励")
    }

    private func applyMakeup(date: String) {
        guard makeupPackCount > 0, !checkedInDates.contains(date) else { return }
        makeupPackCount -= 1
        UserDefaults.standard.set(makeupPackCount, forKey: CheckInStreakStore.makeupPackKey)
        checkedInDates.insert(date)
        makeupDates.insert(date)
        CheckInStreakStore.setCheckedInDates(checkedInDates, for: activeHumanIdForStreak)
        CheckInStreakStore.setMakeupDates(makeupDates, for: activeHumanIdForStreak)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func claimMilestone(_ days: Int, reward: Int, emoji: String) {
        QuestManager.shared.addCoconuts(reward, emoji: emoji, title: "\(days)天连胜奖励")
        lastClaimedMilestone = days
        CheckInStreakStore.setLastClaimedMilestone(days, for: activeHumanIdForStreak)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
