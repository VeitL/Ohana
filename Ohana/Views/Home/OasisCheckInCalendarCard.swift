//
//  OasisCheckInCalendarCard.swift
//  Ohana
//
//  Pure render surface for the Oasis check-in calendar and streak milestones.
//

import SwiftUI

struct OasisCheckInCalendarCard: View {
    @Binding var displayMonth: Date

    let checkedInDates: Set<String>
    let makeupDates: Set<String>
    let makeupPackCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let monthCheckInRate: Int
    let lastClaimedMilestone: Int
    let localization: L10n
    let onRequestMakeup: (String) -> Void
    let onOpenMakeupShop: () -> Void
    let onClaimMilestone: (_ days: Int, _ reward: Int, _ emoji: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            statsRow
            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.1))
            monthNavigation
            weekdayHeader
            monthGrid
            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.1))
            makeupPackRow
            if currentStreak > 0 {
                milestoneRow
            }
        }
        .padding(16)
        .background {
            ZStack {
                Color.goDeepNavy
                Color.goPrimary.opacity(0.1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.15), lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                Text(localization.tr(zh: "打卡日历", en: "Check-in calendar", de: "Check-in-Kalender"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .black))
                Text(localization.tr(zh: "\(currentStreak) 天连胜", en: "\(currentStreak)-day streak", de: "\(currentStreak)-Tage-Serie"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goYellow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.goYellow.opacity(0.12), in: Capsule())
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(checkedInDates.count)", label: localization.tr(zh: "总打卡", en: "Total", de: "Gesamt"), icon: "checkmark.circle.fill", color: Color.goPrimary)
            statCell(value: "\(currentStreak)", label: localization.tr(zh: "当前连胜", en: "Current", de: "Aktuell"), icon: "flame.fill", color: Color.goYellow)
            statCell(value: "\(longestStreak)", label: localization.tr(zh: "最长连胜", en: "Best", de: "Beste"), icon: "trophy.fill", color: Color.goOrange)
            statCell(value: "\(monthCheckInRate)%", label: localization.tr(zh: "本月", en: "Month", de: "Monat"), icon: "chart.bar.fill", color: Color.goCardCyan)
        }
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
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
    }

    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation(GoMotion.quick) {
                    displayMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
            }

            Spacer()

            Text(monthYearString(displayMonth))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)

            Spacer()

            Button {
                let next = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                if next <= Date() {
                    withAnimation(GoMotion.quick) {
                        displayMonth = next
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        Calendar.current.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
                            ? Color.ohanaPrimaryText.opacity(0.15)
                            : Color.ohanaPrimaryText.opacity(0.5)
                    )
            }
            .disabled(Calendar.current.isDate(displayMonth, equalTo: Date(), toGranularity: .month))
        }
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let cells = monthCalendarCells(for: displayMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                calendarDayCell(cell)
            }
        }
    }

    private var makeupPackRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                Text(localization.tr(zh: "补签包", en: "Makeup packs", de: "Nachtragspakete"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                Text("x\(makeupPackCount)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(makeupPackCount > 0 ? Color.goPrimary : Color.ohanaPrimaryText.opacity(0.3))
            }

            Spacer()

            if makeupPackCount > 0 {
                Text(localization.tr(zh: "点击灰色日期补签", en: "Tap a gray date to make up", de: "Graues Datum zum Nachtragen tippen"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.goPrimary.opacity(0.6))
            } else {
                Button(action: onOpenMakeupShop) {
                    Text(localization.tr(zh: "去商店购买", en: "Buy in shop", de: "Im Shop kaufen"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goYellow.opacity(0.8))
                }
            }
        }
    }

    private var milestoneRow: some View {
        let milestones: [(days: Int, reward: Int, emoji: String, systemName: String)] = [
            (7, 10, "⭐️", "star.fill"),
            (14, 25, "🌟", "sparkles"),
            (30, 60, "💎", "diamond.fill"),
            (60, 150, "👑", "crown.fill"),
            (100, 300, "🏆", "trophy.fill")
        ]
        let nextMilestone = milestones.first(where: { $0.days > currentStreak })
        let claimable = milestones.filter { $0.days <= currentStreak && $0.days > lastClaimedMilestone }

        return VStack(spacing: 6) {
            OhanaDashedDivider(color: Color.ohanaPrimaryText.opacity(0.1))
            if let next = nextMilestone {
                HStack(spacing: 6) {
                    Image(systemName: next.systemName)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.goPrimary.opacity(0.7))
                    Text(localization.tr(
                        zh: "再连续 \(next.days - currentStreak) 天即可领取 +\(next.reward)🥥",
                        en: "\(next.days - currentStreak) more days for +\(next.reward)🥥",
                        de: "Noch \(next.days - currentStreak) Tage für +\(next.reward)🥥"
                    ))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary.opacity(0.7))
                    Spacer()
                }
            }

            if !claimable.isEmpty {
                ForEach(claimable, id: \.days) { milestone in
                    Button {
                        onClaimMilestone(milestone.days, milestone.reward, milestone.emoji)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: milestone.systemName)
                                .font(.system(size: 14, weight: .black))
                            Text(localization.tr(
                                zh: "\(milestone.days) 天连胜达成！",
                                en: "\(milestone.days)-day streak reached!",
                                de: "\(milestone.days)-Tage-Serie erreicht!"
                            ))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            Spacer()
                            Text(localization.tr(zh: "+\(milestone.reward)🥥 领取", en: "Claim +\(milestone.reward)🥥", de: "+\(milestone.reward)🥥 holen"))
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
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        var cells: [CalendarCell] = []

        for _ in 0..<weekdayOfFirst {
            cells.append(CalendarCell(dateStr: "", day: 0, isToday: false, isChecked: false, isMakeup: false, isFuture: false))
        }

        for day in 1...daysInMonth {
            var dayComponents = DateComponents()
            dayComponents.year = components.year
            dayComponents.month = components.month
            dayComponents.day = day
            let date = calendar.date(from: dayComponents) ?? firstOfMonth
            let dateStr = formatter.string(from: date)
            let isToday = dateStr == todayString
            cells.append(CalendarCell(
                dateStr: dateStr,
                day: day,
                isToday: isToday,
                isChecked: checkedInDates.contains(dateStr),
                isMakeup: makeupDates.contains(dateStr),
                isFuture: date > Date() && !isToday
            ))
        }

        return cells
    }

    @ViewBuilder
    private func calendarDayCell(_ cell: CalendarCell) -> some View {
        if cell.dateStr.isEmpty {
            Color.clear.frame(width: 34, height: 34)
        } else {
            Button {
                if !cell.isChecked && !cell.isToday && !cell.isFuture && makeupPackCount > 0 {
                    onRequestMakeup(cell.dateStr)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(cellFillColor(cell))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().strokeBorder(
                                cell.isToday ? Color.goPrimary : Color.clear,
                                lineWidth: 1.5
                            )
                        )
                    if cell.isChecked {
                        Image(systemName: cell.isMakeup ? "arrow.uturn.backward" : "checkmark")
                            .font(.system(size: cell.isMakeup ? 9 : 10, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryActionText.opacity(cell.isMakeup ? 0.72 : 1))
                    } else {
                        Text("\(cell.day)")
                            .font(.system(size: 11, weight: cell.isToday ? .black : .medium, design: .rounded))
                            .foregroundStyle(
                                cell.isFuture ? Color.ohanaSecondaryText.opacity(0.35) :
                                    cell.isToday ? Color.goPrimary : Color.ohanaSecondaryText
                            )
                    }
                }
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

    private var weekdaySymbols: [String] {
        switch localization.lang {
        case "en":
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        case "de":
            return ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        default:
            return ["日", "一", "二", "三", "四", "五", "六"]
        }
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = localization.lang == "zh" ? "yyyy年 M月" : "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var locale: Locale {
        switch localization.lang {
        case "de":
            return Locale(identifier: "de_DE")
        case "en":
            return Locale(identifier: "en_US")
        default:
            return Locale(identifier: "zh_CN")
        }
    }
}
