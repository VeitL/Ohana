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
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("user_login_streak") private var loginStreak: Int = 0
    @AppStorage("user_last_login_date") private var lastLoginDateStr: String = ""
    @AppStorage("user_login_history") private var loginHistoryJSON: String = ""
    @State private var selectedMonth = Date()
    @State private var checkedInDates: Set<String> = []
    @State private var makeupDates: Set<String> = []
    @State private var makeupPackCount = 0
    @State private var showMakeupConfirm: String? = nil
    @State private var showCoconutShop = false
    @State private var showingCoconutLog = false
    @AppStorage("checkIn_lastClaimedMilestone") private var lastClaimedMilestone: Int = 0

    private let cal = Calendar.current
    private let checkedInKey = "oasis_checkedIn_dates"
    private let makeupDatesKey = "oasis_makeup_dates"
    private let makeupPackKey = "inventory_backdate_1day_count"

    private var safeTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 52
    }
    private var navBarHeight: CGFloat { safeTop + 56 }

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    Spacer().frame(height: navBarHeight)
                    myStreakCard
                    checkInCalendarSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .top) { navBar }
        .onAppear {
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
            CoconutShopView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCoconutLog) {
            CoconutLogView()
        }
        .onChange(of: showCoconutShop) { _, isShowing in
            if !isShowing { loadCheckInData() }
        }
    }

    // MARK: - Nav Bar (matches IslandWealthDashboardView)

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("打卡连击")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            CoconutBalanceCapsule { showingCoconutLog = true }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.01))
    }

    // MARK: - 我的连击卡片
    private var myStreakCard: some View {
        let boundId = UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        let activeHuman = humans.first(where: { $0.id.uuidString == boundId }) ?? humans.first
        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: activeHuman?.themeColorHex ?? "4338FF").opacity(0.25))
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
                        .foregroundStyle(.primary)
                    Text("每天打开 App 即打卡")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(currentStreak)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(currentStreak > 0 ? Color.goOrange : .primary.opacity(0.25))
                            .contentTransition(.numericText())
                        Text("天")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
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
                            .foregroundStyle(.primary.opacity(0.4))
                        Spacer()
                        Text("还差 \(next - currentStreak) 天")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goOrange.opacity(0.8))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.primary.opacity(0.1))
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
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                        .foregroundStyle(.primary)
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

            OhanaDashedDivider(color: .white.opacity(0.08))

            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMonth = cal.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .goGlassBackground(Circle())
                }

                Spacer()

                Text(monthYearString(selectedMonth))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    let next = cal.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    if next <= Date() {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMonth = next
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
                            ? Color.primary.opacity(0.15)
                            : Color.primary.opacity(0.5)
                        )
                        .frame(width: 36, height: 36)
                        .goGlassBackground(Circle())
                }
                .disabled(cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }

            HStack(spacing: 0) {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = monthCalendarCells(for: selectedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    calendarDayCell(cell)
                }
            }

            OhanaDashedDivider(color: .white.opacity(0.08))

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("📦").font(.system(size: 14))
                    Text("补签包")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                    Text("×\(makeupPackCount)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(makeupPackCount > 0 ? Color.goPrimary : .primary.opacity(0.3))
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
                    .buttonStyle(.plain)
                }
            }

            if currentStreak > 0 {
                checkInMilestoneRow
            }
        }
        .padding(16)
        .goGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var checkInMilestoneRow: some View {
        let milestones: [(days: Int, reward: Int, emoji: String)] = [
            (7, 10, "⭐️"), (14, 25, "🌟"), (30, 60, "💎"), (60, 150, "👑"), (100, 300, "🏆")
        ]
        let nextMilestone = milestones.first(where: { $0.days > currentStreak })
        let lastClaimed = lastClaimedMilestone

        return VStack(spacing: 8) {
            OhanaDashedDivider(color: .white.opacity(0.08))

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
                            .foregroundStyle(.black)
                        Spacer()
                        Text("+\(milestone.reward)🥥 领取")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
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

    private var parsedLoginHistory: [Date] {
        guard !loginHistoryJSON.isEmpty,
              let data = loginHistoryJSON.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            if !lastLoginDateStr.isEmpty {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                if let d = fmt.date(from: lastLoginDateStr) {
                    return [d]
                }
            }
            return []
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return arr.compactMap { fmt.date(from: $0) }
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
                                .foregroundStyle(.black.opacity(0.7))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.black)
                        }
                    } else {
                        Text("\(cell.day)")
                            .font(.system(size: 13, weight: cell.isToday ? .black : .medium, design: .rounded))
                            .foregroundStyle(
                                cell.isFuture ? .primary.opacity(0.2) :
                                cell.isToday ? Color.goPrimary :
                                .primary.opacity(0.7)
                            )
                    }
                }
                .frame(height: 40)
            }
            .buttonStyle(.plain)
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
            return Color.white.opacity(0.05)
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
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private var currentStreak: Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var streak = 0
        var day = Date()
        while true {
            let value = fmt.string(from: day)
            if checkedInDates.contains(value) {
                streak += 1
                day = cal.date(byAdding: .day, value: -1, to: day) ?? day
            } else {
                break
            }
        }
        return streak
    }

    private var longestStreak: Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let sorted = checkedInDates.compactMap { fmt.date(from: $0) }.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<sorted.count {
            if let expected = cal.date(byAdding: .day, value: 1, to: sorted[index - 1]),
               cal.isDate(expected, inSameDayAs: sorted[index]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
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
        if let arr = UserDefaults.standard.stringArray(forKey: checkedInKey) {
            checkedInDates = Set(arr)
        }
        if let arr = UserDefaults.standard.stringArray(forKey: makeupDatesKey) {
            makeupDates = Set(arr)
        }
        makeupPackCount = UserDefaults.standard.integer(forKey: makeupPackKey)
    }

    private func triggerTodayCheckIn() {
        let today = todayStr()
        guard !checkedInDates.contains(today) else { return }
        checkedInDates.insert(today)
        UserDefaults.standard.set(Array(checkedInDates), forKey: checkedInKey)
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: "每日打卡奖励")
    }

    private func applyMakeup(date: String) {
        guard makeupPackCount > 0, !checkedInDates.contains(date) else { return }
        makeupPackCount -= 1
        UserDefaults.standard.set(makeupPackCount, forKey: makeupPackKey)
        checkedInDates.insert(date)
        makeupDates.insert(date)
        UserDefaults.standard.set(Array(checkedInDates), forKey: checkedInKey)
        UserDefaults.standard.set(Array(makeupDates), forKey: makeupDatesKey)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func claimMilestone(_ days: Int, reward: Int, emoji: String) {
        QuestManager.shared.addCoconuts(reward, emoji: emoji, title: "\(days)天连胜奖励")
        lastClaimedMilestone = days
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
