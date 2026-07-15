//
//  TaskCenterView.swift
//  Ohana
//
//  Minimal grouped task list with Fitness-inspired daily progress.
//

import SwiftUI

private struct TaskCenterScrollFocus: Equatable {
    let itemID: String?
    let requestID: UUID?
}

struct TaskCenterCalendarWorkflowStrip: View {
    let items: [TaskCenterItemSnapshot]
    let onOpen: (TaskCenterItemSnapshot) -> Void
    let onAction: (TaskCenterItemSnapshot, TaskCenterAvailableAction) -> Bool

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(l.tr(zh: "家庭分工", en: "Household assignments", de: "Aufgabenverteilung"))
                        .font(OhanaFont.footnote(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("\(items.count)")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goPurple)
                    Spacer()
                }
                .padding(.horizontal, 18)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(items) { item in
                            HStack(spacing: 8) {
                                Button {
                                    onOpen(item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(OhanaFont.caption(.bold))
                                            .foregroundStyle(Color.ohanaPrimaryText)
                                            .lineLimit(1)
                                        Text(item.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(OhanaFont.caption2(.semibold))
                                            .foregroundStyle(Color.ohanaSecondaryText)
                                    }
                                }
                                .buttonStyle(.plain)

                                if let action = primaryAction(item) {
                                    Button(actionTitle(action)) {
                                        _ = onAction(item, action)
                                    }
                                    .font(OhanaFont.caption2(.black))
                                    .buttonStyle(.bordered)
                                    .tint(action == .reject ? Color.goRed : Color.goPrimary)
                                }
                            }
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                            .frame(minHeight: 52)
                            .background(Color.ohanaCardSurface, in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                            }
                            .accessibilityIdentifier("task-center-calendar-family-\(item.id)")
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
            .padding(.vertical, 8)
            .accessibilityIdentifier("task-center-calendar-family-strip")
        }
    }

    private func primaryAction(_ item: TaskCenterItemSnapshot) -> TaskCenterAvailableAction? {
        let order: [TaskCenterAvailableAction] = [.approve, .reject, .claim, .submitForReview, .complete]
        return order.first(where: item.availableActions.contains)
    }

    private func actionTitle(_ action: TaskCenterAvailableAction) -> String {
        switch action {
        case .complete: l.tr(zh: "完成", en: "Complete", de: "Erledigen")
        case .claim: l.tr(zh: "领取", en: "Claim", de: "Übernehmen")
        case .submitForReview: l.tr(zh: "提交", en: "Submit", de: "Einreichen")
        case .approve: l.tr(zh: "通过", en: "Approve", de: "Bestätigen")
        case .reject: l.tr(zh: "驳回", en: "Reject", de: "Ablehnen")
        }
    }
}

struct TaskCenterHeader: View {
    @Binding var selectedSurface: TaskCenterSurface
    let snapshot: TaskCenterSnapshot
    let isLoading: Bool
    let showsAddButton: Bool
    let showsCloseButton: Bool
    let filterLabel: String?
    let onAdd: () -> Void
    let onClose: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "待办", en: "Tasks", de: "Aufgaben"))
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

            if let filterLabel {
                Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goPrimary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(Color.goPrimary.opacity(0.12), in: Capsule())
                    .accessibilityIdentifier("task-center-active-filter")
            }
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
                title: l.tr(zh: "清单", en: "List", de: "Liste"),
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
    let showsDailyProgress: Bool
    let focusedItemID: String?
    let focusRequestID: UUID?
    let onAction: (TaskCenterItemSnapshot, TaskCenterAvailableAction) -> Bool
    let onOpen: (TaskCenterItemSnapshot) -> Void
    let onScrollOffsetChange: ((CGFloat) -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var performingIDs: Set<String> = []
    /// `nil` preserves the effortless default: the current local member when
    /// collaboration is relevant, otherwise the complete household list.
    @State private var selectedMemberFilter: TaskCenterMemberFilter?

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if !isLoading, snapshot.showsMemberFilters {
                        memberFilterRail
                    }
                    if isLoading {
                        loadingState
                    } else if displayedSnapshot.pendingCount == 0 {
                        emptyState
                    } else {
                        taskSection(
                            title: l.tr(
                                zh: "新手成长计划",
                                en: "Starter journey",
                                de: "Starter-Reise"
                            ),
                            items: visible(systemJourneyItems),
                            tint: .goYellow,
                            identifier: "starter-journey",
                            badgeText: starterJourneyRewardProgressText
                        )
                        if showsDailyProgress, resolvedMemberFilter == .all {
                            dailyProgress
                        }
                        taskSection(
                            title: l.tr(zh: "待审核", en: "Needs review", de: "Zu prüfen"),
                            items: visible(pendingReviewItems),
                            tint: .goYellow,
                            identifier: "pending-review"
                        )
                        taskSection(
                            title: l.tr(zh: "逾期", en: "Overdue", de: "Überfällig"),
                            items: visible(nonReview(displayedSnapshot.overdue)),
                            tint: displayedSnapshot.criticalCount > 0 ? .goRed : .goOrange,
                            identifier: "overdue"
                        )
                        taskSection(
                            title: l.tr(zh: "今天", en: "Today", de: "Heute"),
                            items: visible(nonReview(displayedSnapshot.today)),
                            tint: .goPrimary,
                            identifier: "today"
                        )
                        taskSection(
                            title: l.tr(zh: "接下来", en: "Upcoming", de: "Als Nächstes"),
                            items: visible(nonReview(displayedSnapshot.upcoming)),
                            tint: .goTeal,
                            identifier: "upcoming"
                        )
                        taskSection(
                            title: l.tr(zh: "未排期", en: "Unscheduled", de: "Ohne Termin"),
                            items: visible(ordinaryUnscheduledItems),
                            tint: .goPurple,
                            identifier: "unscheduled"
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
            .onChange(of: scrollFocus, initial: true) { _, focus in
                guard let itemID = focus.itemID else { return }
                Task { @MainActor in
                    await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 80)
                    withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.page) {
                        proxy.scrollTo(itemID, anchor: .center)
                    }
                }
            }
        }
        .onChange(of: snapshot) { _, _ in
            performingIDs.removeAll()
        }
        .onChange(of: selectedMemberFilter) { _, _ in
            OhanaFeedback.selection()
        }
        .accessibilityIdentifier("task-center-scroll-view")
    }

    private var scrollFocus: TaskCenterScrollFocus {
        TaskCenterScrollFocus(itemID: focusedItemID, requestID: focusRequestID)
    }

    private var displayedSnapshot: TaskCenterSnapshot {
        snapshot.filtered(for: resolvedMemberFilter)
    }

    private var resolvedMemberFilter: TaskCenterMemberFilter {
        snapshot.resolvedMemberFilter(explicitSelection: selectedMemberFilter)
    }

    private var memberFilterRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskCenterMemberFilter.allCases) { filter in
                    memberFilterButton(filter)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task-center-member-filters")
    }

    private func memberFilterButton(_ filter: TaskCenterMemberFilter) -> some View {
        let isSelected = resolvedMemberFilter == filter
        return Button {
            guard !isSelected else { return }
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.selection) {
                selectedMemberFilter = filter
            }
        } label: {
            Text(memberFilterTitle(filter))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(memberFilterAccessibilityLabel(filter))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("task-center-member-filter-\(filter.rawValue)")
    }

    private func memberFilterTitle(_ filter: TaskCenterMemberFilter) -> String {
        switch filter {
        case .all:
            l.tr(zh: "全部", en: "All", de: "Alle")
        case .currentMember:
            snapshot.memberFilterContext.activeHumanName
                ?? l.tr(zh: "当前成员", en: "Current member", de: "Aktuelles Mitglied")
        case .waitingForOthers:
            l.tr(zh: "等待他人", en: "Waiting on others", de: "Warten auf andere")
        case .pendingReview:
            l.tr(zh: "待审核", en: "Needs review", de: "Zu prüfen")
        }
    }

    private func memberFilterAccessibilityLabel(_ filter: TaskCenterMemberFilter) -> String {
        guard filter == .currentMember,
              let activeHumanName = snapshot.memberFilterContext.activeHumanName else {
            return memberFilterTitle(filter)
        }
        return l.tr(
            zh: "当前成员：\(activeHumanName)",
            en: "Current member: \(activeHumanName)",
            de: "Aktuelles Mitglied: \(activeHumanName)"
        )
    }

    private var dailyProgress: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.ohanaControlFill, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: displayedSnapshot.todayCompletionFraction)
                    .stroke(
                        Color.goPrimary,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(displayedSnapshot.todayPendingCount)")
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
                zh: "今天完成 \(displayedSnapshot.todayCompletedCount) 项，共 \(displayedSnapshot.todayTotalCount) 项",
                en: "\(displayedSnapshot.todayCompletedCount) of \(displayedSnapshot.todayTotalCount) tasks complete today",
                de: "Heute \(displayedSnapshot.todayCompletedCount) von \(displayedSnapshot.todayTotalCount) Aufgaben erledigt"
            ))

            VStack(alignment: .leading, spacing: 10) {
                metricLine(
                    value: displayedSnapshot.todayPendingCount,
                    label: l.tr(zh: "今天待办", en: "Due today", de: "Heute fällig"),
                    tint: .goPrimary
                )
                metricLine(
                    value: displayedSnapshot.overdueCount,
                    label: l.tr(zh: "已经逾期", en: "Overdue", de: "Überfällig"),
                    tint: displayedSnapshot.criticalCount > 0 ? .goRed : .goOrange
                )
                metricLine(
                    value: displayedSnapshot.upcoming.count,
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
        identifier: String,
        badgeText: String? = nil
    ) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(badgeText ?? "\(items.count)")
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
                            .id(item.id)
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
            .accessibilityHint(systemAccessibilityHint(for: item))

            actionButtons(for: item)
        }
        .frame(minHeight: 68)
        .opacity(performingIDs.contains(item.id) ? 0.44 : 1)
        .scaleEffect(performingIDs.contains(item.id) && !reduceMotion ? 0.985 : 1)
        .animation(reduceMotion ? GoMotion.reduced : GoMotion.feedback, value: performingIDs.contains(item.id))
        .accessibilityIdentifier("task-center-item-\(item.id)")
    }

    @ViewBuilder
    private func actionButtons(for item: TaskCenterItemSnapshot) -> some View {
        if let destination = item.systemDestination {
            Button {
                OhanaFeedback.light()
                onOpen(item)
            } label: {
                Text(systemActionTitle(for: item))
                    .font(OhanaFont.caption2(.black))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(Color.goPrimary.opacity(0.14), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .foregroundStyle(Color.goPrimary)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("\(systemActionTitle(for: item)) \(item.title)")
            .accessibilityIdentifier("task-center-system-action-\(destination.rawValue)-\(item.id)")
        } else if item.availableActions.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 4) {
                ForEach(orderedActions(for: item), id: \.self) { action in
                    Button {
                        perform(action, for: item)
                    } label: {
                        if action == .complete {
                            Image(systemName: "checkmark") // a11y: allow decorative glyph inside the labeled action button
                                .font(OhanaFont.adaptive(size: 12, weight: .black))
                                .frame(width: 28, height: 28) // a11y: allow decorative glyph inside the enclosing 44pt button
                                .background(itemTint(item).opacity(0.14), in: Circle())
                                .accessibilityHidden(true)
                        } else {
                            Text(actionTitle(action))
                                .font(OhanaFont.caption2(.black))
                                .padding(.horizontal, 8)
                                .frame(minHeight: 32)
                                .background(actionTint(action).opacity(0.14), in: Capsule())
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .foregroundStyle(actionTint(action))
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(performingIDs.contains(item.id))
                    .accessibilityLabel("\(actionTitle(action)) \(item.title)")
                    .accessibilityIdentifier("task-center-action-\(action.rawValue)-\(item.id)")
                }
            }
        }
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
        items.filter { !performingIDs.contains($0.id) }
    }

    private var pendingReviewItems: [TaskCenterItemSnapshot] {
        displayedSnapshot.allItems
            .filter { $0.workflowStatus == .pendingReview }
    }

    private var systemJourneyItems: [TaskCenterItemSnapshot] {
        displayedSnapshot.systemJourneyItems
            .sorted { systemJourneyOrder($0) < systemJourneyOrder($1) }
    }

    private var ordinaryUnscheduledItems: [TaskCenterItemSnapshot] {
        nonReview(displayedSnapshot.ordinaryUnscheduledItems)
    }

    private var starterJourneyRewardProgressText: String? {
        guard let journey = displayedSnapshot.starterJourney, journey.isEnabled else { return nil }
        return "\(journey.claimedRewardCoconuts) / \(journey.totalRewardCoconuts) 🥥"
    }

    private func nonReview(_ items: [TaskCenterItemSnapshot]) -> [TaskCenterItemSnapshot] {
        items.filter { $0.workflowStatus != .pendingReview }
    }

    private func orderedActions(for item: TaskCenterItemSnapshot) -> [TaskCenterAvailableAction] {
        let order: [TaskCenterAvailableAction] = [.reject, .approve, .claim, .submitForReview, .complete]
        return order.filter(item.availableActions.contains)
    }

    private func perform(_ action: TaskCenterAvailableAction, for item: TaskCenterItemSnapshot) {
        guard !performingIDs.contains(item.id) else { return }
        performingIDs.insert(item.id)
        guard onAction(item, action) else {
            performingIDs.remove(item.id)
            return
        }
        OhanaFeedback.medium()
    }

    private func actionTitle(_ action: TaskCenterAvailableAction) -> String {
        switch action {
        case .complete:
            l.tr(zh: "完成", en: "Complete", de: "Erledigen")
        case .claim:
            l.tr(zh: "领取", en: "Claim", de: "Übernehmen")
        case .submitForReview:
            l.tr(zh: "提交", en: "Submit", de: "Einreichen")
        case .approve:
            l.tr(zh: "通过", en: "Approve", de: "Bestätigen")
        case .reject:
            l.tr(zh: "驳回", en: "Reject", de: "Ablehnen")
        }
    }

    private func systemActionTitle(for item: TaskCenterItemSnapshot) -> String {
        if item.systemJourneyPresentationState == .rewardReady {
            return l.tr(zh: "领取", en: "Claim", de: "Abholen")
        }
        guard let destination = item.systemDestination else {
            return l.tr(zh: "打开", en: "Open", de: "Öffnen")
        }
        switch destination {
        case .createFirstPet:
            l.tr(zh: "建立", en: "Create", de: "Erstellen")
        case .claimStarterGift:
            l.tr(zh: "领取", en: "Claim", de: "Abholen")
        case .completeHumanProfile, .completeFirstPetProfile:
            l.tr(zh: "完善", en: "Complete", de: "Ergänzen")
        case .confirmPetIdentityProtection, .confirmPetPreventiveCare:
            l.tr(zh: "确认", en: "Review", de: "Prüfen")
        case .configureFirstCarePlan:
            l.tr(zh: "设置", en: "Set up", de: "Einrichten")
        case .recordFirstCare:
            l.tr(zh: "记录", en: "Record", de: "Erfassen")
        }
    }

    private func systemAccessibilityHint(for item: TaskCenterItemSnapshot) -> String {
        if item.systemJourneyPresentationState == .rewardReady {
            return l.tr(
                zh: "打开奖励领取说明",
                en: "Open reward claim details",
                de: "Details zur Belohnung öffnen"
            )
        }
        switch item.systemDestination {
        case .createFirstPet:
            l.tr(zh: "开始建立宠物", en: "Start creating a pet", de: "Haustier erstellen")
        case .claimStarterGift:
            l.tr(zh: "打开首宠奖励领取弹窗", en: "Open the first-pet gift", de: "Belohnung für das erste Tier öffnen")
        case .completeHumanProfile:
            l.tr(zh: "查看并完善人类资料", en: "Review and complete the human profile", de: "Menschenprofil ergänzen")
        case .completeFirstPetProfile:
            l.tr(zh: "查看并完善宠物资料", en: "Review and complete the pet profile", de: "Haustierprofil ergänzen")
        case .confirmPetIdentityProtection:
            l.tr(zh: "确认宠物证件与保障状态", en: "Review identity and protection details", de: "Dokumente und Schutz prüfen")
        case .confirmPetPreventiveCare:
            l.tr(zh: "确认疫苗与保健状态", en: "Review preventive care status", de: "Vorsorge prüfen")
        case .configureFirstCarePlan:
            l.tr(zh: "设置一个适用的照护计划", en: "Set up a suitable care plan", de: "Pflegeplan einrichten")
        case .recordFirstCare:
            l.tr(zh: "记录一次真实照护", en: "Record a real care action", de: "Eine echte Pflege erfassen")
        case nil:
            l.tr(zh: "打开事项", en: "Open task", de: "Aufgabe öffnen")
        }
    }

    private func systemJourneyOrder(_ item: TaskCenterItemSnapshot) -> Int {
        switch item.systemDestination {
        case .createFirstPet: 0
        case .claimStarterGift: 1
        case .completeHumanProfile: 10
        case .completeFirstPetProfile: 20
        case .confirmPetIdentityProtection: 30
        case .confirmPetPreventiveCare: 40
        case .configureFirstCarePlan: 50
        case .recordFirstCare: 60
        case nil: .max
        }
    }

    private func actionTint(_ action: TaskCenterAvailableAction) -> Color {
        switch action {
        case .reject: .goRed
        case .approve, .complete: .goTeal
        case .claim, .submitForReview: .goPrimary
        }
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
        let reward = item.rewardCoconuts > 0 ? "+\(item.rewardCoconuts) 🥥" : nil
        return [
            item.subjectName,
            snapshot.showsMemberFilters ? responsibilityText(item) : nil,
            reward,
            category,
            item.isRecurring ? l.tr(zh: "重复", en: "Repeats", de: "Wiederholt") : nil
        ]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    private func responsibilityText(_ item: TaskCenterItemSnapshot) -> String? {
        switch item.workflowStatus {
        case .pendingReview:
            guard let name = nonemptyMemberName(item.createdByMember) else { return nil }
            return l.tr(
                zh: "等待 \(name) 审核",
                en: "Review by \(name)",
                de: "Prüfung durch \(name)"
            )
        case .completed:
            guard let name = nonemptyMemberName(item.completedByMember) else { return nil }
            return l.tr(
                zh: "由 \(name) 完成",
                en: "Completed by \(name)",
                de: "Erledigt von \(name)"
            )
        case .claimed:
            guard let name = nonemptyMemberName(item.claimedByMember) else { return nil }
            return l.tr(
                zh: "\(name) 已领取",
                en: "Claimed by \(name)",
                de: "Übernommen von \(name)"
            )
        case .active, .scheduled:
            guard let name = nonemptyMemberName(item.assignedToMember) else { return nil }
            return l.tr(
                zh: "分配给 \(name)",
                en: "Assigned to \(name)",
                de: "Zugewiesen an \(name)"
            )
        case .cancelled:
            return nil
        }
    }

    private func nonemptyMemberName(_ member: TaskMemberSnapshot?) -> String? {
        guard let name = member?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    private func dueText(_ item: TaskCenterItemSnapshot) -> String {
        if item.source == .systemJourney {
            if item.systemJourneyPresentationState == .rewardReady {
                return l.tr(zh: "可领取", en: "Ready", de: "Bereit")
            }
            return l.tr(zh: "随时", en: "Anytime", de: "Jederzeit")
        }
        if item.dueAt == nil, item.source == .familyTask {
            return l.tr(zh: "未排期", en: "Unscheduled", de: "Ohne Termin")
        }
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
