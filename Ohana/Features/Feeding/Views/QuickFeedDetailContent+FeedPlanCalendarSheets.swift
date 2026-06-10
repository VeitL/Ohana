import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var manualFeedSettingSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: pet.mainFoodKind.systemIconName)
                .font(OhanaFont.adaptive(size: 17, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "当前打卡设置", en: "Current log setting", de: "Aktuelle Einstellung"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(manualFeedSettingSummaryText)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            Button {
                openManualFeedSheet(settingsOnly: true)
            } label: {
                Image(systemName: "slider.horizontal.3").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.goPrimary, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "修改打卡设置", en: "Edit log setting", de: "Einstellung ändern"))
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }

    var manualFeedSettingSummaryText: String {
        if pet.dailyPortionGrams > 0 {
            return l.tr(
                zh: "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))",
                en: "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))",
                de: "\(pet.mainFoodKind.title(l)) · \(formattedFoodWeight(pet.dailyPortionGrams))"
            )
        }
        return l.tr(
            zh: "\(pet.mainFoodKind.title(l)) · 未设置默认克数",
            en: "\(pet.mainFoodKind.title(l)) · no default amount",
            de: "\(pet.mainFoodKind.title(l)) · keine Standardmenge"
        )
    }

    var feedPlanCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    shiftFeedPlanCalendarMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .feedFlatBlockSurface(cornerRadius: OhanaRadius.row)
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    withAnimation(GoMotion.quick) {
                        draftStore.showFeedPlanMonthPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(feedPlanCalendarMonthTitle)
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Image(systemName: draftStore.showFeedPlanMonthPicker ? "chevron.up" : "chevron.down")
                            .font(OhanaFont.adaptive(size: 10, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    .padding(.horizontal, 4)
                }
                .buttonStyle(ScaleButtonStyle())
                Spacer()
                Button {
                    let today = Date()
                    let direction = today >= draftStore.feedPlanCalendarMonth ? 1 : -1
                    setFeedPlanCalendarMonth(today, direction: direction)
                } label: {
                    Text(l.tr(zh: "今天", en: "Today", de: "Heute"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .feedFlatBlockSurface(cornerRadius: OhanaRadius.row)
                }
                .buttonStyle(ScaleButtonStyle())
                Button {
                    shiftFeedPlanCalendarMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .feedFlatBlockSurface(cornerRadius: OhanaRadius.row)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            FeedPlanMonthlyCalendarView(
                weekdayTitles: feedPlanWeekdayTitles,
                days: feedPlanCalendarDaySummaries,
                tint: feedingModeTint,
                textColor: Color.ohanaPrimaryText,
                secondaryTextColor: Color.ohanaSecondaryText,
                selectedDate: draftStore.feedPlanCalendarSelectedDate,
                onSelectDate: { date in
                    withAnimation(GoMotion.quick) {
                        selectFeedPlanCalendarDate(date)
                    }
                }
            )
            .id(feedPlanCalendarMonthKey)
            .transition(.asymmetric(
                insertion: .move(edge: draftStore.feedPlanCalendarMonthSlideDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: draftStore.feedPlanCalendarMonthSlideDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
            ))
            .simultaneousGesture(
                DragGesture(minimumDistance: 28, coordinateSpace: .local)
                    .onEnded { value in
                        let width = value.translation.width
                        let height = value.translation.height
                        guard abs(width) > 54, abs(width) > abs(height) * 1.35 else { return }
                        shiftFeedPlanCalendarMonth(by: width < 0 ? 1 : -1)
                    }
            )
        }
    }

    var feedPlanYearMonthPicker: some View {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: draftStore.feedPlanCalendarMonth)
        let selectedMonth = calendar.component(.month, from: draftStore.feedPlanCalendarMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    setFeedPlanCalendarYear(year - 1)
                } label: {
                    Image(systemName: "chevron.left").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .feedFlatBlockSurface(cornerRadius: OhanaRadius.row)
                }
                .buttonStyle(ScaleButtonStyle())

                Text(feedPlanPlainYearText(year))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)

                Button {
                    setFeedPlanCalendarYear(year + 1)
                } label: {
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .feedFlatBlockSurface(cornerRadius: OhanaRadius.row)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1 ... 12, id: \.self) { month in
                    let isSelected = month == selectedMonth
                    Button {
                        selectFeedPlanCalendarMonth(year: year, month: month)
                    } label: {
                        Text(feedPlanMonthTitle(month, year: year))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(isSelected ? feedingModeTint : Color.ohanaSecondaryText.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(12)
        .background {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(false), in: shape)
        }
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.24), radius: 22, x: 0, y: 12) // ui-v4: allow floating calendar picker lift shadow
    }

    func shiftFeedPlanCalendarMonth(by delta: Int) {
        let calendar = Calendar.current
        guard let targetMonth = calendar.date(byAdding: .month, value: delta, to: draftStore.feedPlanCalendarMonth) else { return }
        let targetYear = calendar.component(.year, from: targetMonth)
        let targetMonthNumber = calendar.component(.month, from: targetMonth)
        let firstDay = feedPlanDate(year: targetYear, month: targetMonthNumber, day: 1) ?? targetMonth
        setFeedPlanCalendarMonth(firstDay, direction: delta >= 0 ? 1 : -1)
    }

    func setFeedPlanCalendarYear(_ year: Int) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: draftStore.feedPlanCalendarMonth)
        guard let target = feedPlanDate(year: year, month: month, day: 1) else { return }
        let currentYear = calendar.component(.year, from: draftStore.feedPlanCalendarMonth)
        setFeedPlanCalendarMonth(target, direction: year >= currentYear ? 1 : -1)
    }

    func selectFeedPlanCalendarMonth(year: Int, month: Int) {
        let calendar = Calendar.current
        guard let firstDay = feedPlanDate(year: year, month: month, day: 1) else { return }
        let direction = firstDay >= calendar.startOfDay(for: draftStore.feedPlanCalendarMonth) ? 1 : -1
        setFeedPlanCalendarMonth(firstDay, direction: direction)
    }

    func selectFeedPlanCalendarDate(_ date: Date) {
        let calendar = Calendar.current
        let targetMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let direction = targetMonth >= (calendar.dateInterval(of: .month, for: draftStore.feedPlanCalendarMonth)?.start ?? draftStore.feedPlanCalendarMonth) ? 1 : -1
        draftStore.feedPlanCalendarMonthSlideDirection = direction
        draftStore.feedPlanCalendarMonth = targetMonth
        draftStore.feedPlanCalendarSelectedDate = date
    }

    func setFeedPlanCalendarMonth(_ firstDay: Date, direction: Int) {
        withAnimation(GoMotion.page) {
            draftStore.feedPlanCalendarMonthSlideDirection = direction
            draftStore.feedPlanCalendarMonth = firstDay
            draftStore.feedPlanCalendarSelectedDate = defaultFeedPlanSelectedDate(forMonth: firstDay)
        }
    }

    func defaultFeedPlanSelectedDate(forMonth firstDay: Date) -> Date {
        let calendar = Calendar.current
        let today = Date()
        if calendar.isDate(firstDay, equalTo: today, toGranularity: .month) {
            return today
        }
        return firstDay
    }

    func feedPlanDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    func feedPlanMonthTitle(_ month: Int, year: Int) -> String {
        guard let date = feedPlanDate(year: year, month: month, day: 1) else { return "\(month)" }
        let monthName = date.formatted(.dateTime.month(.abbreviated))
        return L10n(appLanguage).tr(zh: "\(month)月", en: monthName, de: monthName)
    }

    func feedPlanPlainYearText(_ year: Int) -> String {
        String(format: "%04d", year)
    }

    @ViewBuilder
    var feedPlanSelectedDateSection: some View {
        overviewSectionHeader(feedPlanSelectedDateSectionTitle)
        let occurrences = feedPlanSelectedDateOccurrences
        if occurrences.isEmpty {
            emptyInlineState(
                icon: "clock.badge.questionmark",
                text: activeFeedingMode == .autoFeeder
                    ? l.tr(zh: "这一天没有自动餐次", en: "No auto meals on this day", de: "Keine Auto-Mahlzeiten an diesem Tag")
                    : l.tr(zh: "这一天没有计划餐", en: "No planned meals on this day", de: "Keine Planmahlzeiten an diesem Tag"),
                solid: true
            )
        } else {
            ForEach(occurrences) { occurrence in
                feedPlanSelectedOccurrenceRow(occurrence)
            }
        }
    }

    func feedPlanSelectedOccurrenceRow(_ occurrence: FeedPlanCalendarOccurrence) -> some View {
        let event = occurrence.event
        let grams = formattedFoodWeight(FeedRuleMetadata.amountGrams(from: event, fallback: pet.dailyPortionGrams))
        let status = feedPlanStatus(for: occurrence)
        let actionTitle = feedPlanActionTitle(for: occurrence)
        return HStack(spacing: 10) {
            Image(systemName: status.icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(status.tint, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(occurrence.date.formatted(date: .omitted, time: .shortened)) · \(event.foodKind.title(l)) · \(grams)")
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if let actionTitle {
                Button {
                    completeSelectedPlanOccurrence(occurrence)
                } label: {
                    Text(actionTitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(status.tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }

    @ViewBuilder
    var feedPlanHistoryRecordsSection: some View {
        overviewSectionHeader(l.tr(zh: "历史记录", en: "History", de: "Verlauf"))
        let reminders = feedPlanHistoryReminders
        if reminders.isEmpty {
            emptyInlineState(icon: "fork.knife", text: l.tr(zh: "还没有已发生的计划餐", en: "No past planned meals yet", de: "Noch keine vergangenen Planmahlzeiten"), solid: true)
        } else {
            ForEach(reminders, id: \.id) { reminder in
                planReminderHistoryRow(reminder, allowsCatchUp: canCatchUpPlanReminder(reminder))
            }
        }
    }
}
