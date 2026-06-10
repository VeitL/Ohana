//
//  CalendarView+Helpers.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CalendarView {
    // MARK: - Calendar Helpers
    func calendarDays() -> [Date?] {
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

    var calendarMonthKey: String {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .local)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > 44, abs(width) > abs(height) * 1.25 else { return }
                shiftMonth(by: width < 0 ? 1 : -1)
            }
    }

    func shiftMonth(by delta: Int) {
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
