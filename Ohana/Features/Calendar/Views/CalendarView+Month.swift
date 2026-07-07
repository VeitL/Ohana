//
//  CalendarView+Month.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension CalendarView {
    // MARK: - Go Month View
    var goMonthView: some View {
        let l = L10n(AppLanguage.code)
        return VStack(spacing: 12) {
            // Month header — Go 风格
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Label(l.tr(zh: "上个月", en: "Previous month", de: "Vorheriger Monat"), systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .font(OhanaFont.callout(.bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(isMaterial ? matSurface : classicSubtleFill, in: Circle())
                }
                .accessibilityLabel(l.tr(zh: "上个月", en: "Previous month", de: "Vorheriger Monat"))

                Spacer()

                Text(selectedDate, format: .dateTime.year().month(.wide))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Label(l.tr(zh: "下个月", en: "Next month", de: "Nächster Monat"), systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .font(OhanaFont.callout(.bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(isMaterial ? matSurface : classicSubtleFill, in: Circle())
                }
                .accessibilityLabel(l.tr(zh: "下个月", en: "Next month", de: "Nächster Monat"))
            }
            .padding(.horizontal, 20)

            // Weekday header
            let weekdayFormatter = DateFormatter()
            let weekdaySymbols = {
                weekdayFormatter.locale = AppLanguage.effectiveLocale
                return weekdayFormatter.veryShortStandaloneWeekdaySymbols ?? weekdayFormatter.shortStandaloneWeekdaySymbols ?? []
            }()
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { d in
                    Text(d)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            // Calendar grid
            let daysInMonth = calendarDays()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isToday = Calendar.current.isDateInToday(date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let dayNumber = Calendar.current.component(.day, from: date)
                        let hasEvents = preparedCalendarSnapshot.monthEventDayIDs.contains(timelineDateID(date))

                        Button {
                            withAnimation(GoMotion.feedback) {
                                selectedDate = date
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(dayNumber)")
                                    .font(OhanaFont.headline(isSelected || isToday ? .bold : .medium))
                                    .foregroundStyle(isSelected ? chipSelFg : (isToday ? chipAccent : (isMaterial ? .primary : classicPrimaryText)))
                                    .ohanaNumericMotion(dayNumber)

                                Circle()
                                    .fill(hasEvents ? (isSelected ? chipSelFg.opacity(0.7) : chipAccent) : .clear)
                                    .frame(width: 5, height: 5) // a11y: allow decorative event density dot
                            }
                            .frame(width: 40, height: 48)
                            .background(
                                isSelected ? chipAccent : (isToday ? chipAccent.opacity(isMaterial ? 0.12 : 0.08) : .clear),
                                in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
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
                            Image(systemName: "tray.fill") // a11y: allow decorative empty-state icon
                                .font(OhanaFont.largeTitle(.medium))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                                .accessibilityHidden(true)
                            Text(l.tr(zh: "暂无事件", en: "No events", de: "Keine Ereignisse"))
                                .font(OhanaFont.callout(.semibold))
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
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offsetY in
                reportEmbeddedBottomChromeScrollOffset(offsetY)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
    }
}
