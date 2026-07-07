//
//  SwipeableEventRow.swift
//  Ohana
//

import SwiftData
import SwiftUI

/// 谷歌日历风格滑动行：左滑完成 + 右滑删除 + 点击详情
/// 三种视觉状态：Pending / Completed / Overdue
struct SwipeableEventRow: View {
    let event: Event
    var occurrenceDate: Date = .init()
    var petThemeColor: Color?
    var allowsUserEventDetail = true
    let onComplete: () -> Void
    let onDelete: () -> Void
    var onOpenDetail: (() -> Void)?
    var onOpenRelated: (() -> Bool)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false

    @State private var offsetX: CGFloat = 0
    @State private var isTriggerred = false
    @State private var showDeleteConfirmAlert = false
    @State private var celebrationParticles: [CelebrationParticle] = []
    @AppStorage("shop_equip_fx_stars") private var equipFxStars: Bool = false
    @State private var activeDragAxis: DragAxis? = nil

    // Overdue emphasis stays static in list geometry; rows must not drift while the user scans.
    @State private var overdueBreath: Bool = false

    private let triggerThreshold: CGFloat = 100
    private let dampFactor: CGFloat = 0.4
    private enum DragAxis {
        case horizontal
        case vertical
    }

    private var shouldReduceWork: Bool {
        powerSavingMode || reduceMotion || AppPerformanceMode.systemPrefersReducedWork
    }

    private var leftProgress: CGFloat { max(0, -offsetX) / triggerThreshold }
    private var rightProgress: CGFloat { max(0, offsetX) / triggerThreshold }
    private var l: L10n { L10n(appLanguage) }
    private var accessibilityHint: String {
        allowsUserEventDetail
            ? l.tr(zh: "查看日历事项详情", en: "View calendar event details", de: "Kalendertermin-Details anzeigen")
            : l.tr(zh: "打开相关功能", en: "Open related feature", de: "Zugehorige Funktion offnen")
    }

    // MARK: - Row State（重复序列按「本次发生日」判断完成/逾期，避免整串共用一个 isCompleted / startDate）
    private enum RowState { case pending, completed, overdue }
    private var rowState: RowState {
        if event.isOccurrenceMarkedComplete(on: occurrenceDate) { return .completed }
        if event.isOverdue(on: occurrenceDate) { return .overdue }
        return .pending
    }

    /// 列表右侧时间：重复日程用「发生日 + 模板开始时刻」
    private var occurrenceDisplayStart: Date {
        if event.recurrenceDays > 0, !event.isAllDay {
            return Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
        }
        return event.startDate
    }

    var body: some View {
        ZStack {
            // 完成粒子层
            ForEach(celebrationParticles) { p in
                Text(p.emoji).font(OhanaFont.adaptive(size: 18))
                    .offset(x: p.offsetX, y: p.offsetY)
                    .rotationEffect(.degrees(p.rotation))
                    .transition(.asymmetric(insertion: .scale(scale: 0.1).combined(with: .opacity), removal: .opacity))
            }
            .animation(GoMotion.feedback, value: celebrationParticles.count)

            // 左滑背景（完成，仅行动任务才可完成）
            if offsetX < 0, event.isActionableTask {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: leftProgress >= 1 ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(OhanaFont.adaptive(size: 20, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                        Text("完成").font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .opacity(min(1, leftProgress * 1.5))
                    .scaleEffect(0.8 + leftProgress * 0.2)
                    .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.goTeal.opacity(0.2 + leftProgress * 0.7)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)))
            }

            // 右滑背景（删除）
            if offsetX > 0 {
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 20, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                        Text("删除").font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .opacity(min(1, rightProgress * 1.5))
                    .scaleEffect(0.8 + rightProgress * 0.2)
                    .padding(.leading, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.goRed.opacity(0.2 + rightProgress * 0.7)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)))
            }

            // 主卡片
            eventCard
                .offset(x: offsetX)
                .simultaneousGesture(rowSwipeGesture)
                .highPriorityGesture(
                    TapGesture().onEnded { openPrimaryAction() }
                )
        }
        // F1+F2: 唯一删除确认弹窗，所有逻辑在此处理
        .confirmationDialog(
            event.recurrenceDays > 0 ? "删除重复事件" : "删除「\(event.title)」",
            isPresented: $showDeleteConfirmAlert,
            titleVisibility: .visible
        ) {
            if event.recurrenceDays > 0 {
                Button("仅删除此条", role: .destructive) { deleteEvent(scope: .singleOccurrence) }
                Button("删除此条及之后所有重复", role: .destructive) { deleteEvent(scope: .thisAndFuture) }
            } else {
                Button("删除", role: .destructive) { triggerDelete() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(event.recurrenceDays > 0
                ? "这是一个重复事件，请选择删除方式"
                : "确定要删除「\(event.title)」吗？此操作不可撤回。")
        }
        .onAppear {
            guard rowState == .overdue, !shouldReduceWork else {
                overdueBreath = false
                return
            }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { // ui-v4: allow overdue warning breath, gated by reduce-work policy. // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                overdueBreath = true
            }
        }
    }

    // MARK: - Event Card

    private var eventCard: some View {
        let titlePrimary = Color.ohanaPrimaryText
        let titleMuted = Color.ohanaTertiaryText
        let timeSecondary = Color.ohanaSecondaryText.opacity(0.72)
        // Squish scale: card compresses as left-swipe deepens
        let squishX = 1.0 - leftProgress * 0.04
        let squishY = 1.0 + leftProgress * 0.02
        // Morph: node bg color interpolates from eventNodeColor → orange, icon fades to checkmark
        let morphColor: Color = rowState == .overdue
            ? Color(hex: "FF5A00")
            : eventNodeColor.opacity(rowState == .completed ? 0.08 : 0.2)
        let nodeCircleColor = leftProgress > 0
            ? Color(hex: "FF5A00").opacity(0.15 + leftProgress * 0.85)
            : morphColor

        return HStack(spacing: 12) {
            // 动态图标节点 — overdue uses native SwiftUI animation
            if rowState == .overdue {
                ZStack {
                    Circle()
                        .fill(Color(hex: "FF5A00"))
                        .frame(width: 40, height: 40) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                        .scaleEffect(overdueBreath ? 1.05 : 1.0)
                    if leftProgress > 0.3 {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 16, weight: .black))
                            .foregroundStyle(Color.goCardWhite)
                            .opacity(Double((leftProgress - 0.3) / 0.7))
                            .scaleEffect(0.5 + leftProgress * 0.5)
                    } else {
                        Image(systemName: event.silhouetteListSymbol)
                            .font(OhanaFont.adaptive(size: 17, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.goCardWhite)
                            .opacity(1 - Double(leftProgress / 0.3))
                    }
                }
            } else if rowState == .completed {
                ZStack {
                    Circle()
                        .fill(Color.goTeal.opacity(0.12))
                        .frame(width: 40, height: 40) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 20, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goTeal)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(nodeCircleColor)
                        .frame(width: 40, height: 40) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    // Morph icon → checkmark as swipe deepens
                    if leftProgress > 0.4 {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 16, weight: .black))
                            .foregroundStyle(Color.goCardWhite)
                            .opacity(Double((leftProgress - 0.4) / 0.6))
                            .scaleEffect(0.5 + leftProgress * 0.5)
                    } else {
                        Image(systemName: event.silhouetteListSymbol)
                            .font(OhanaFont.adaptive(size: 18, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .opacity(leftProgress > 0 ? Double(1 - leftProgress / 0.4) : 1)
                    }
                }
            }

            // 中间信息区
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(rowState == .completed ? titleMuted : titlePrimary)
                    .strikethrough(rowState == .completed, color: titleMuted.opacity(0.9))
                    .lineLimit(1)
                    .opacity(leftProgress > 0 ? Double(max(0, 1 - leftProgress * 0.8)) : 1)

                HStack(spacing: 6) {
                    Text(event.eventType)
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(eventNodeColor)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(eventNodeColor.opacity(0.15), in: Capsule())

                    if event.recurrenceDays > 0 {
                        Image(systemName: "repeat").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 9, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(timeSecondary.opacity(0.85))
                    }
                    if rowState == .overdue {
                        Text("逾期")
                            .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "FF5A00"))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color(hex: "FF5A00").opacity(0.12), in: Capsule())
                    }
                }
                .opacity(leftProgress > 0 ? Double(max(0, 1 - leftProgress * 0.8)) : 1)
            }

            Spacer()

            // 右侧：时间 / 完成标记
            Group {
                if rowState == .completed {
                    Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 16, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goPrimary)
                } else if event.isAllDay {
                    Text("全天")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(timeSecondary)
                } else {
                    Text(occurrenceDisplayStart, style: .time)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(rowState == .overdue ? Color(hex: "FF5A00") : timeSecondary)
                        .monospacedDigit()
                }
            }
            .opacity(leftProgress > 0 ? Double(max(0, 1 - leftProgress * 1.2)) : 1)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .opacity(rowState == .completed ? 0.5 : 1.0)
        // Squish: card compresses horizontally, slightly taller on deep swipe
        .scaleEffect(x: squishX, y: squishY, anchor: .trailing)
        .animation(GoMotion.feedback, value: leftProgress)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.title)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("calendar-event-row-\(event.title)")
    }

    // MARK: - Color Coding

    private var eventNodeColor: Color {
        if let themeColor = petThemeColor { return themeColor }
        let t = event.eventType.lowercased() + event.title.lowercased()
        if t.contains("排泄") || t.contains("potty") || t.contains("便") || t.contains("铲") { return .goTeal }
        if t.contains("喂食") || t.contains("食") || t.contains("feed") { return .goYellow }
        if t.contains("遛") || t.contains("walk") { return .goPrimary }
        if t.contains("医") || t.contains("疫苗") || t.contains("health") { return .goRed }
        if t.contains("清洁") || t.contains("洗澡") || t.contains("hygiene") { return Color(hex: "C084FC") }
        return .goCardBlue
    }

    // MARK: - Gesture Actions

    private var rowSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !isTriggerred else { return }
                let dx = value.translation.width
                let dy = value.translation.height

                if activeDragAxis == nil {
                    let absX = abs(dx)
                    let absY = abs(dy)
                    guard max(absX, absY) > 10 else { return }

                    if absY > absX * 1.12 {
                        activeDragAxis = .vertical
                        if offsetX != 0 {
                            withAnimation(GoMotion.feedback) { offsetX = 0 }
                        }
                        return
                    }

                    guard absX > absY * 1.45 else { return }
                    activeDragAxis = .horizontal
                }

                guard activeDragAxis == .horizontal else { return }
                if abs(dx) <= triggerThreshold {
                    offsetX = dx
                } else {
                    let extra = abs(dx) - triggerThreshold
                    offsetX = (dx > 0 ? 1 : -1) * (triggerThreshold + extra * dampFactor)
                }
            }
            .onEnded { value in
                defer { activeDragAxis = nil }
                guard !isTriggerred else { return }
                guard activeDragAxis == .horizontal else {
                    if offsetX != 0 {
                        withAnimation(GoMotion.feedback) { offsetX = 0 }
                    }
                    return
                }

                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.35 else {
                    withAnimation(GoMotion.feedback) { offsetX = 0 }
                    return
                }

                if dx < -triggerThreshold, event.isActionableTask { triggerComplete() }
                else if dx < -triggerThreshold { withAnimation(GoMotion.feedback) { offsetX = 0 } }
                else if dx > triggerThreshold { pendingDelete() }
                else {
                    withAnimation(GoMotion.feedback) { offsetX = 0 }
                }
            }
    }

    private func triggerComplete() {
        isTriggerred = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        launchCelebrationParticles()
        withAnimation(GoMotion.page) { offsetX = -800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onComplete()
            self.isTriggerred = false
            withAnimation(GoMotion.feedback) { self.offsetX = 0 }
        }
    }

    private func openPrimaryAction() {
        guard !isTriggerred, offsetX == 0 else { return }
        guard onOpenRelated?() != true else { return }
        guard allowsUserEventDetail else { return }
        onOpenDetail?()
    }

    // E1: 右滑只弹确认 alert，回弹到原位
    private func pendingDelete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(GoMotion.feedback) { offsetX = 0 }
        showDeleteConfirmAlert = true
    }

    private func triggerDelete() {
        isTriggerred = true
        withAnimation(GoMotion.page) { offsetX = 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            let command = DomainCommand.calendarEventDeletion(
                eventID: event.id,
                scope: CalendarEventDeletionScope.wholeEvent.revisionActionKey
            )
            do {
                try CalendarCommandExecutor(context: modelContext, services: appServices).delete(
                    event: event,
                    occurrenceDate: occurrenceDate,
                    scope: .wholeEvent,
                    note: "calendar.event.delete.row"
                )
                onDelete()
            } catch {
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
            isTriggerred = false
            withAnimation(GoMotion.feedback) { offsetX = 0 }
        }
    }

    private func deleteEvent(scope: CalendarEventDeletionScope) {
        let command = DomainCommand.calendarEventDeletion(eventID: event.id, scope: scope.revisionActionKey)
        do {
            try CalendarCommandExecutor(context: modelContext, services: appServices).delete(
                event: event,
                occurrenceDate: occurrenceDate,
                scope: scope,
                note: "calendar.event.delete.row.menu"
            )
            onDelete()
        } catch {
            appServices.domainRevisions.publishFailure(command: command, error: error)
        }
    }

    private func launchCelebrationParticles() {
        let emojis = equipFxStars ? ["✨", "⭐️", "🌟", "💫", "💛"] : ["⭐️", "✨", "💛", "🎉", "🐾"]
        celebrationParticles = (0 ..< 6).map { i in
            CelebrationParticle(
                emoji: emojis[i % emojis.count],
                offsetX: CGFloat.random(in: -80 ... 80),
                offsetY: CGFloat.random(in: -120 ... -40),
                rotation: Double.random(in: -30 ... 30)
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { celebrationParticles.removeAll() }
    }
}

// MARK: - Calendar Event Detail Page

struct CalendarEventDetailPage: View {
    let event: Event
    var occurrenceDate: Date
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let allowsEditing: Bool
    let onDelete: () -> Void
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var showDeleteConfirm = false
    @State private var showEditEvent = false
    private var l: L10n { L10n(appLanguage) }
    private var detailActions: [CalendarEventDetailAction] {
        CalendarEventInteractionPolicy.detailActions(for: event, allowsEditing: allowsEditing)
    }
    private var isOccurrenceComplete: Bool {
        event.isOccurrenceMarkedComplete(on: occurrenceDate)
    }

    var body: some View {
        GeometryReader { proxy in
            let headerTopInset = max(14, proxy.safeAreaInsets.top + 12)
            let bottomInset = max(18, proxy.safeAreaInsets.bottom + 14)
            let actionReserve = detailActions.isEmpty
                ? bottomInset + 24
                : CGFloat(detailActions.count) * 64 + CGFloat(max(0, detailActions.count - 1)) * 10 + bottomInset + 28

            ZStack(alignment: .bottom) {
                OhanaAppBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, headerTopInset)
                        .padding(.bottom, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            eventSummary
                            timingSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, actionReserve)
                    }
                }

                if !detailActions.isEmpty {
                    actionSection(bottomInset: bottomInset)
                }
            }
        }
        .fullScreenCover(isPresented: $showEditEvent) {
            AddEventContentView(
                onClose: {
                    showEditEvent = false
                    dismiss()
                },
                pets: pets,
                humans: humans,
                plants: plants,
                editingEvent: event,
                editingOccurrenceDate: occurrenceDate
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "事项详情", en: "Event details", de: "Termindetails"))
                    .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .accessibilityIdentifier("calendar-event-detail-page")
                Text(occurrenceStartValue)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schliessen"))
            .accessibilityIdentifier("calendar-event-detail-close-action")
        }
    }

    private var eventSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .fill(nodeColor.opacity(0.15))
                    Image(systemName: event.silhouetteListSymbol)
                        .font(OhanaFont.adaptive(size: 22, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(nodeColor)
                }
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        detailPill(event.eventType, systemImage: event.silhouetteListSymbol, tint: nodeColor)
                        if event.recurrenceDays > 0 {
                            detailPill(
                                l.tr(zh: "重复", en: "Repeats", de: "Wiederholt"),
                                systemImage: "repeat",
                                tint: Color.goPrimary
                            )
                        }
                        if isOccurrenceComplete {
                            detailPill(
                                l.tr(zh: "已完成", en: "Completed", de: "Erledigt"),
                                systemImage: "checkmark.circle.fill",
                                tint: Color.goTeal
                            )
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(Color.ohanaCardSurfaceElevated.opacity(0.94), in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            infoRow(
                icon: event.isAllDay ? "calendar" : "clock.fill",
                label: l.tr(zh: "开始", en: "Starts", de: "Beginn"),
                value: occurrenceStartValue
            )
            if let occurrenceEndValue {
                GoDashedDivider()
                    .padding(.leading, 54)
                infoRow(
                    icon: "clock.badge.checkmark.fill",
                    label: l.tr(zh: "截止", en: "Ends", de: "Ende"),
                    value: occurrenceEndValue
                )
            }
        }
        .padding(.vertical, 4)
        .background(Color.ohanaControlFill.opacity(0.86), in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func actionSection(bottomInset: CGFloat) -> some View {
        VStack(spacing: 10) {
            if detailActions.contains(.edit) {
                actionButton(
                    title: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
                    systemImage: "pencil",
                    fill: Color.goPrimary
                ) {
                    showEditEvent = true
                }
                .accessibilityIdentifier("calendar-event-edit-action")
            }

            if detailActions.contains(.complete) {
                actionButton(
                    title: isOccurrenceComplete
                        ? l.tr(zh: "标记未完成", en: "Mark incomplete", de: "Als offen markieren")
                        : l.tr(zh: "标记完成", en: "Mark complete", de: "Als erledigt markieren"),
                    systemImage: isOccurrenceComplete ? "xmark.circle" : "checkmark.circle.fill",
                    fill: Color.goTeal
                ) {
                    onComplete()
                    dismiss()
                }
                .accessibilityIdentifier("calendar-event-complete-action")
            }

            if detailActions.contains(.delete) {
                actionButton(
                    title: l.tr(zh: "删除", en: "Delete", de: "Loeschen"),
                    systemImage: "trash.fill",
                    fill: Color.goRed
                ) {
                    showDeleteConfirm = true
                }
                .accessibilityIdentifier("calendar-event-delete-action")
                .confirmationDialog(deleteDialogTitle, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    ForEach(deleteScopes, id: \.revisionActionKey) { scope in
                        Button(deleteLabel(for: scope), role: .destructive) {
                            deleteEvent(scope: scope)
                        }
                        .accessibilityIdentifier(confirmDeleteAccessibilityIdentifier(for: scope))
                    }
                    Button(l.cancel, role: .cancel) {}
                } message: {
                    Text(deleteDialogMessage)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, bottomInset)
        .background {
            Color.ohanaCardSurfaceElevated
                .opacity(0.96)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(fill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func detailPill(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(OhanaFont.adaptive(size: 10, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.caption2(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var occurrenceStartDate: Date {
        event.isAllDay
            ? Calendar.current.startOfDay(for: occurrenceDate)
            : Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
    }

    private var occurrenceStartValue: String {
        event.isAllDay
            ? occurrenceStartDate.formatted(date: .abbreviated, time: .omitted)
            : occurrenceStartDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var occurrenceEndValue: String? {
        guard let end = event.endDate else { return nil }
        if event.isAllDay {
            return Calendar.current.startOfDay(for: end).formatted(date: .abbreviated, time: .omitted)
        }
        let cal = Calendar.current
        let endDate = cal.isDate(event.startDate, inSameDayAs: end)
            ? Event.dateMergingTime(from: end, ontoOccurrenceDay: occurrenceDate)
            : end
        return endDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var deleteScopes: [CalendarEventDeletionScope] {
        CalendarEventInteractionPolicy.detailDeletionScopes(for: event)
    }

    private var deleteDialogTitle: String {
        event.recurrenceDays > 0
            ? l.tr(zh: "删除重复事项", en: "Delete repeating event", de: "Wiederholten Termin loschen")
            : l.tr(
                zh: "删除「\(event.title)」",
                en: "Delete \"\(event.title)\"",
                de: "\"\(event.title)\" loschen"
            )
    }

    private var deleteDialogMessage: String {
        event.recurrenceDays > 0
            ? l.tr(
                zh: "这是一个重复事项，请选择删除范围。",
                en: "This is a repeating event. Choose what to delete.",
                de: "Dies ist ein wiederholter Termin. Wahle, was geloscht wird."
            )
            : l.tr(
                zh: "确定要删除「\(event.title)」吗？此操作不可撤回。",
                en: "Delete \"\(event.title)\"? This can't be undone.",
                de: "\"\(event.title)\" loschen? Dies kann nicht ruckgangig gemacht werden."
            )
    }

    private func deleteLabel(for scope: CalendarEventDeletionScope) -> String {
        switch scope {
        case .wholeEvent:
            l.tr(zh: "删除此事项", en: "Delete event", de: "Termin loschen")
        case .singleOccurrence:
            l.tr(zh: "仅删除本次", en: "Delete this occurrence", de: "Nur diesen Termin loschen")
        case .thisAndFuture:
            l.tr(zh: "删除本次及之后", en: "Delete this and future occurrences", de: "Diesen und zukunftige Termine loschen")
        }
    }

    private func confirmDeleteAccessibilityIdentifier(for scope: CalendarEventDeletionScope) -> String {
        switch scope {
        case .wholeEvent:
            "calendar-event-confirm-delete-action"
        case .singleOccurrence:
            "calendar-event-confirm-delete-single-occurrence-action"
        case .thisAndFuture:
            "calendar-event-confirm-delete-this-and-future-action"
        }
    }

    private func deleteEvent(scope: CalendarEventDeletionScope) {
        let command = DomainCommand.calendarEventDeletion(eventID: event.id, scope: scope.revisionActionKey)
        do {
            try CalendarCommandExecutor(context: modelContext, services: appServices).delete(
                event: event,
                occurrenceDate: occurrenceDate,
                scope: scope,
                note: "calendar.event.delete.detail.\(scope.revisionActionKey)"
            )
            onDelete()
            dismiss()
        } catch {
            appServices.domainRevisions.publishFailure(command: command, error: error)
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(nodeColor)
                .frame(width: 22)
            Text(label)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
            Spacer()
            Text(value)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .padding(.horizontal, 24)
    }

    private var nodeColor: Color {
        let t = event.eventType.lowercased()
        if t.contains("排泄") || t.contains("potty") { return .goTeal }
        if t.contains("喂食") || t.contains("feed") { return .goYellow }
        if t.contains("遛") || t.contains("walk") { return .goPrimary }
        if t.contains("医") || t.contains("疫苗") { return .goRed }
        return .goCardBlue
    }
}

// MARK: - Celebration Particle Model
struct CelebrationParticle: Identifiable {
    let id = UUID()
    let emoji: String
    let offsetX: CGFloat
    let offsetY: CGFloat
    let rotation: Double
}
