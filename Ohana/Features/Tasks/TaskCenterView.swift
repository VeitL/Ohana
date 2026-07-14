//
//  TaskCenterView.swift
//  Ohana
//
//  Minimal grouped task list with Fitness-inspired daily progress.
//

import SwiftUI

struct TaskCenterHeader: View {
    @Binding var selectedSurface: TaskCenterSurface
    let snapshot: TaskCenterSnapshot
    let isLoading: Bool
    let showsAddButton: Bool
    let showsCloseButton: Bool
    let onAdd: () -> Void
    let onClose: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "待办中心", en: "Tasks", de: "Aufgaben"))
                        .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(summaryText)
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(summaryTint)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                if showsAddButton {
                    Button(action: onAdd) {
                        Image(systemName: "plus") // a11y: allow decorative symbol inside the labeled 44pt button
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(width: 44, height: 44)
                            .background(Color.goPrimary, in: Circle())
                            .contentShape(Circle())
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "添加待办", en: "Add task", de: "Aufgabe hinzufügen"))
                    .accessibilityIdentifier("task-center-add-action")
                }

                if showsCloseButton, let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark") // a11y: allow decorative symbol inside the labeled 44pt button
                            .font(OhanaFont.adaptive(size: 14, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                            .background(Color.ohanaControlFill, in: Circle())
                            .contentShape(Circle())
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                    .accessibilityIdentifier("task-center-close-action")
                }
            }

            surfacePicker
        }
        .padding(.horizontal, 18)
        .padding(.top, showsCloseButton ? 12 : 6)
        .padding(.bottom, 10)
        .accessibilityIdentifier("task-center-header")
    }

    private var surfacePicker: some View {
        HStack(spacing: 4) {
            surfaceButton(
                .tasks,
                title: l.tr(zh: "待办", en: "Tasks", de: "Aufgaben"),
                symbol: "checklist"
            )
            surfaceButton(
                .calendar,
                title: l.tr(zh: "日历", en: "Calendar", de: "Kalender"),
                symbol: "calendar"
            )
        }
        .padding(4)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task-center-surface-picker")
    }

    private func surfaceButton(
        _ surface: TaskCenterSurface,
        title: String,
        symbol: String
    ) -> some View {
        let isSelected = selectedSurface == surface
        return Button {
            guard selectedSurface != surface else { return }
            selectedSurface = surface
        } label: {
            Label(title, systemImage: symbol)
                .font(OhanaFont.footnote(.black))
                .foregroundStyle(isSelected ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    isSelected ? Color.ohanaCardSurfaceElevated : Color.clear,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("task-center-surface-\(surface.rawValue)")
    }

    private var summaryText: String {
        if isLoading {
            return l.tr(zh: "正在整理待办", en: "Organizing your tasks", de: "Aufgaben werden sortiert")
        }
        if snapshot.overdueCount > 0 {
            return l.tr(
                zh: "\(snapshot.overdueCount) 项逾期 · \(snapshot.pendingCount) 项待处理",
                en: "\(snapshot.overdueCount) overdue · \(snapshot.pendingCount) remaining",
                de: "\(snapshot.overdueCount) überfällig · \(snapshot.pendingCount) offen"
            )
        }
        return snapshot.pendingCount == 0
            ? l.tr(zh: "现在没有待办", en: "Nothing pending", de: "Nichts offen")
            : l.tr(
                zh: "\(snapshot.pendingCount) 项待处理",
                en: "\(snapshot.pendingCount) remaining",
                de: "\(snapshot.pendingCount) offen"
            )
    }

    private var summaryTint: Color {
        if snapshot.criticalCount > 0 { return .goRed }
        if snapshot.overdueCount > 0 { return .goOrange }
        return .ohanaSecondaryText
    }
}

struct TaskCenterView: View {
    let snapshot: TaskCenterSnapshot
    let isLoading: Bool
    let bottomClearance: CGFloat
    let onComplete: (TaskCenterItemSnapshot) -> Bool
    let onOpen: (TaskCenterItemSnapshot) -> Void
    let onScrollOffsetChange: ((CGFloat) -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completingIDs: Set<String> = []

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 22) {
                if isLoading {
                    loadingState
                } else if snapshot.pendingCount == 0 {
                    emptyState
                } else {
                    dailyProgress
                    taskSection(
                        title: l.tr(zh: "逾期", en: "Overdue", de: "Überfällig"),
                        items: visible(snapshot.overdue),
                        tint: snapshot.criticalCount > 0 ? .goRed : .goOrange,
                        identifier: "overdue"
                    )
                    taskSection(
                        title: l.tr(zh: "今天", en: "Today", de: "Heute"),
                        items: visible(snapshot.today),
                        tint: .goPrimary,
                        identifier: "today"
                    )
                    taskSection(
                        title: l.tr(zh: "接下来", en: "Upcoming", de: "Als Nächstes"),
                        items: visible(snapshot.upcoming),
                        tint: .goTeal,
                        identifier: "upcoming"
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, bottomClearance)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offset in
            onScrollOffsetChange?(offset)
        }
        .onChange(of: snapshot) { _, _ in
            completingIDs.removeAll()
        }
        .accessibilityIdentifier("task-center-scroll-view")
    }

    private var dailyProgress: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.ohanaControlFill, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: snapshot.todayCompletionFraction)
                    .stroke(
                        Color.goPrimary,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(snapshot.todayPendingCount)")
                        .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .monospacedDigit()
                    Text(l.tr(zh: "今天", en: "today", de: "heute"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .frame(width: 78, height: 78)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(l.tr(
                zh: "今天完成 \(snapshot.todayCompletedCount) 项，共 \(snapshot.todayTotalCount) 项",
                en: "\(snapshot.todayCompletedCount) of \(snapshot.todayTotalCount) tasks complete today",
                de: "Heute \(snapshot.todayCompletedCount) von \(snapshot.todayTotalCount) Aufgaben erledigt"
            ))

            VStack(alignment: .leading, spacing: 10) {
                metricLine(
                    value: snapshot.todayPendingCount,
                    label: l.tr(zh: "今天待办", en: "Due today", de: "Heute fällig"),
                    tint: .goPrimary
                )
                metricLine(
                    value: snapshot.overdueCount,
                    label: l.tr(zh: "已经逾期", en: "Overdue", de: "Überfällig"),
                    tint: snapshot.criticalCount > 0 ? .goRed : .goOrange
                )
                metricLine(
                    value: snapshot.upcoming.count,
                    label: l.tr(zh: "之后安排", en: "Upcoming", de: "Demnächst"),
                    tint: .goTeal
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            Color.ohanaCardSurfaceElevated,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .accessibilityIdentifier("task-center-daily-progress")
    }

    private func metricLine(value: Int, label: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8) // a11y: allow non-interactive metric legend glyph
                .accessibilityHidden(true)
            Text("\(value)")
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .monospacedDigit()
                .frame(minWidth: 24, alignment: .trailing)
            Text(label)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func taskSection(
        title: String,
        items: [TaskCenterItemSnapshot],
        tint: Color,
        identifier: String
    ) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("\(items.count)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.12), in: Capsule())
                        .monospacedDigit()
                    Spacer()
                }

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        taskRow(item)
                        if index < items.count - 1 {
                            Divider()
                                .overlay(Color.ohanaCardStroke.opacity(0.7))
                                .padding(.leading, 54)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(
                    Color.ohanaCardSurface,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
            }
            .accessibilityIdentifier("task-center-section-\(identifier)")
        }
    }

    private func taskRow(_ item: TaskCenterItemSnapshot) -> some View {
        HStack(spacing: 8) {
            Button {
                onOpen(item)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.symbol)
                        .font(OhanaFont.adaptive(size: 16, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(itemTint(item))
                        .frame(width: 38, height: 38) // a11y: allow decorative glyph inside the full-width 68pt row button
                        .background(itemTint(item).opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(itemSubtitle(item))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Text(dueText(item))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(item.urgency == .standard ? Color.ohanaSecondaryText : itemTint(item))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("\(item.title). \(itemSubtitle(item)). \(dueText(item))")
            .accessibilityHint(l.tr(zh: "打开事项", en: "Open task", de: "Aufgabe öffnen"))

            Button {
                complete(item)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(itemTint(item), lineWidth: 2)
                        .frame(width: 26, height: 26) // a11y: allow visual ring inside the enclosing 44pt button
                    if completingIDs.contains(item.id) {
                        Circle()
                            .fill(Color.goTeal)
                            .frame(width: 26, height: 26) // a11y: allow visual fill inside the enclosing 44pt button
                        Image(systemName: "checkmark") // a11y: allow decorative state glyph inside the labeled button
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(completingIDs.contains(item.id))
            .accessibilityLabel(l.tr(
                zh: "完成 \(item.title)",
                en: "Complete \(item.title)",
                de: "\(item.title) erledigen"
            ))
            .accessibilityIdentifier("task-center-complete-\(item.id)")
        }
        .frame(minHeight: 68)
        .opacity(completingIDs.contains(item.id) ? 0.44 : 1)
        .scaleEffect(completingIDs.contains(item.id) && !reduceMotion ? 0.985 : 1)
        .animation(reduceMotion ? GoMotion.reduced : GoMotion.feedback, value: completingIDs.contains(item.id))
        .accessibilityIdentifier("task-center-item-\(item.id)")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark") // a11y: allow decorative empty-state symbol combined with the explanatory copy
                .font(OhanaFont.adaptive(size: 26, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 64, height: 64)
                .background(Color.goTeal, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(l.tr(zh: "都处理好了", en: "All caught up", de: "Alles erledigt"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "新的照护、用药和提醒事项会出现在这里。",
                    en: "New care, medication, and reminder tasks will appear here.",
                    de: "Neue Pflege-, Medikamenten- und Erinnerungsaufgaben erscheinen hier."
                ))
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 58)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("task-center-empty-state")
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ForEach(0 ..< 5, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.ohanaControlFill)
                        .frame(width: 38, height: 38) // a11y: allow non-interactive loading placeholder
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                            .fill(Color.ohanaControlFill)
                            .frame(width: index.isMultiple(of: 2) ? 164 : 124, height: 11)
                        RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                            .fill(Color.ohanaControlFill.opacity(0.72))
                            .frame(width: 92, height: 9)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 68)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l.tr(zh: "正在加载待办", en: "Loading tasks", de: "Aufgaben werden geladen"))
        .accessibilityIdentifier("task-center-loading-state")
    }

    private func visible(_ items: [TaskCenterItemSnapshot]) -> [TaskCenterItemSnapshot] {
        items.filter { !completingIDs.contains($0.id) }
    }

    private func complete(_ item: TaskCenterItemSnapshot) {
        guard !completingIDs.contains(item.id) else { return }
        completingIDs.insert(item.id)
        guard onComplete(item) else {
            completingIDs.remove(item.id)
            return
        }
        OhanaFeedback.medium()
    }

    private func itemTint(_ item: TaskCenterItemSnapshot) -> Color {
        switch item.urgency {
        case .critical:
            .goRed
        case .overdue:
            .goOrange
        case .standard:
            .goPrimary
        }
    }

    private func itemSubtitle(_ item: TaskCenterItemSnapshot) -> String {
        let category = item.eventType?.localizedLabel(l)
        return [item.subjectName, category, item.isRecurring ? l.tr(zh: "重复", en: "Repeats", de: "Wiederholt") : nil]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    private func dueText(_ item: TaskCenterItemSnapshot) -> String {
        if item.urgency == .critical {
            return l.tr(zh: "健康逾期", en: "Health overdue", de: "Gesundheit überfällig")
        }
        if item.urgency == .overdue {
            return CalendarDateTextFormatter.relativeDate(item.occurrenceDate, l: l)
        }
        if Calendar.current.isDateInToday(item.occurrenceDate) {
            return item.isAllDay
                ? l.tr(zh: "全天", en: "All day", de: "Ganztägig")
                : item.scheduledAt.formatted(date: .omitted, time: .shortened)
        }
        return CalendarDateTextFormatter.relativeDate(item.occurrenceDate, l: l)
    }
}
