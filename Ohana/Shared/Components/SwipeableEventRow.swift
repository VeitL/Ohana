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
    let onComplete: () -> Void
    let onDelete: () -> Void
    var onOpenRelated: (() -> Bool)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppServices.self) private var appServices
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false

    @State private var offsetX: CGFloat = 0
    @State private var isTriggerred = false
    @State private var showDeleteConfirmAlert = false
    @State private var celebrationParticles: [CelebrationParticle] = []
    @AppStorage("shop_equip_fx_stars") private var equipFxStars: Bool = false
    @State private var showDetail = false
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
                .onTapGesture {
                    guard onOpenRelated?() != true else { return }
                    showDetail = true
                }
        }
        .sheet(isPresented: $showDetail) {
            EventDetailSheet(event: event, occurrenceDate: occurrenceDate, onDelete: onDelete, onComplete: onComplete)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
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
            CalendarCommandExecutor(context: modelContext, services: appServices).delete(
                event: event,
                occurrenceDate: occurrenceDate,
                scope: .wholeEvent,
                note: "calendar.event.delete.row"
            )
            onDelete()
            isTriggerred = false
            withAnimation(GoMotion.feedback) { offsetX = 0 }
        }
    }

    private func deleteEvent(scope: CalendarEventDeletionScope) {
        CalendarCommandExecutor(context: modelContext, services: appServices).delete(
            event: event,
            occurrenceDate: occurrenceDate,
            scope: scope,
            note: "calendar.event.delete.row.menu"
        )
        onDelete()
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

// MARK: - Event Detail Sheet（F2F0F5 浅色大圆角底板）

private struct EventDetailSheet: View {
    let event: Event
    var occurrenceDate: Date
    let onDelete: () -> Void
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.goCardWhite.opacity(0.2))
                .frame(width: 40, height: 4) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .padding(.top, 12).padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题行
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                                .fill(nodeColor.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: event.silhouetteListSymbol)
                                .font(OhanaFont.adaptive(size: 22, weight: .bold))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(nodeColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(2)
                            Text(event.eventType)
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(nodeColor)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(nodeColor.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    // 时间信息（重复日程展示「本次发生」的日期+时间）
                    Group {
                        if event.isAllDay {
                            infoRow(icon: "clock.fill", label: "开始",
                                    value: Calendar.current.startOfDay(for: occurrenceDate).formatted(date: .abbreviated, time: .omitted))
                        } else {
                            let startDT = Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
                            infoRow(icon: "clock.fill", label: "开始",
                                    value: startDT.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let end = event.endDate {
                            if event.isAllDay {
                                infoRow(icon: "clock.badge.checkmark.fill", label: "截止",
                                        value: Calendar.current.startOfDay(for: end).formatted(date: .abbreviated, time: .omitted))
                            } else {
                                let cal = Calendar.current
                                let sameDay = cal.isDate(event.startDate, inSameDayAs: end)
                                let endDT = sameDay
                                    ? Event.dateMergingTime(from: end, ontoOccurrenceDay: occurrenceDate)
                                    : end
                                infoRow(icon: "clock.badge.checkmark.fill", label: "截止",
                                        value: endDT.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                    }
                    if event.recurrenceDays > 0 {
                        infoRow(icon: "repeat", label: "重复",
                                value: recurrenceLabel(event.recurrenceDays))
                    }

                    GoDashedDivider().padding(.horizontal, 24)

                    // 操作按钮
                    HStack(spacing: 12) {
                        // 信息性事件（生日/纪念日）不显示完成按钮
                        if event.isActionableTask {
                            Button {
                                onComplete()
                                dismiss()
                            } label: {
                                Label(event.isOccurrenceMarkedComplete(on: occurrenceDate) ? "标记未完成" : "标记完成",
                                      systemImage: event.isOccurrenceMarkedComplete(on: occurrenceDate) ? "xmark.circle" : "checkmark.circle.fill")
                                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: OhanaRadius.row))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除", systemImage: "trash.fill")
                                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.goRed, in: RoundedRectangle(cornerRadius: OhanaRadius.row))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("删除此事项", role: .destructive) {
                                CalendarCommandExecutor(context: modelContext, services: appServices).delete(
                                    event: event,
                                    occurrenceDate: occurrenceDate,
                                    scope: .wholeEvent,
                                    note: "calendar.event.delete.detail"
                                )
                                onDelete()
                                dismiss()
                            }
                            Button("取消", role: .cancel) {}
                        } message: {
                            Text("确定要删除「\(event.title)」吗？此操作不可撤回。")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
        .background {
            ZStack {
                Color.goDeepNavy
                Color.goPrimary.opacity(0.15)
            }
        }
        .presentationCornerRadius(OhanaRadius.hero)
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

    private func recurrenceLabel(_ days: Int) -> String {
        switch days {
        case 1: "每天"
        case 7: "每周"
        case 14: "每两周"
        case 30: "每月"
        default: "每\(days)天"
        }
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
