//
//  SwipeableEventRow.swift
//  Ohana
//

import SwiftUI
import SwiftData

/// 谷歌日历风格滑动行：左滑完成 + 右滑删除 + 点击详情
/// 三种视觉状态：Pending / Completed / Overdue
struct SwipeableEventRow: View {
    let event: Event
    var occurrenceDate: Date = Date()
    var petThemeColor: Color? = nil
    let onComplete: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var offsetX: CGFloat = 0
    @State private var isTriggerred = false
    @State private var showDeleteConfirmAlert = false
    @State private var celebrationParticles: [CelebrationParticle] = []
    @AppStorage("shop_equip_fx_stars") private var equipFxStars: Bool = false
    @State private var coconutFloats: [CoconutFloat] = []
    @State private var showDetail = false
    @State private var showSkipReason = false

    // Overdue gravitational pull — driven by native SwiftUI animation (no TimelineView polling)
    @State private var overdueBreath: Bool = false
    @State private var overdueFloat: CGFloat = 0

    private let triggerThreshold: CGFloat = 100
    private let dampFactor: CGFloat = 0.4

    private var leftProgress:  CGFloat { max(0, -offsetX) / triggerThreshold }
    private var rightProgress: CGFloat { max(0,  offsetX) / triggerThreshold }

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

    private struct CoconutFloat: Identifiable {
        let id = UUID()
        var offsetY: CGFloat = 0
        var opacity: Double  = 1.0
    }

    var body: some View {
        ZStack {
            // 完成粒子层
            ForEach(celebrationParticles) { p in
                Text(p.emoji).font(.system(size: 18))
                    .offset(x: p.offsetX, y: p.offsetY)
                    .rotationEffect(.degrees(p.rotation))
                    .transition(.asymmetric(insertion: .scale(scale: 0.1).combined(with: .opacity), removal: .opacity))
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: celebrationParticles.count)

            // 椰子浮字
            ForEach(coconutFloats) { f in
                Text("+5🥥")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .offset(y: f.offsetY)
                    .opacity(f.opacity)
                    .allowsHitTesting(false)
            }

            // 左滑背景（完成，仅行动任务才可完成）
            if offsetX < 0 && event.isActionableTask {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: leftProgress >= 1 ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 20, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                        Text("完成").font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.primary)
                    .opacity(min(1, leftProgress * 1.5))
                    .scaleEffect(0.8 + leftProgress * 0.2)
                    .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.goTeal.opacity(0.2 + leftProgress * 0.7)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
            }

            // 右滑背景（删除）
            if offsetX > 0 {
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                        Text("删除").font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.primary)
                    .opacity(min(1, rightProgress * 1.5))
                    .scaleEffect(0.8 + rightProgress * 0.2)
                    .padding(.leading, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.goRed.opacity(0.2 + rightProgress * 0.7)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
            }

            // 主卡片
            eventCard
                .offset(x: offsetX)
                .gesture(DragGesture(minimumDistance: 12)
                    .onChanged { val in
                        guard !isTriggerred else { return }
                        let dx = val.translation.width
                        if abs(dx) <= triggerThreshold {
                            offsetX = dx
                        } else {
                            let extra = abs(dx) - triggerThreshold
                            offsetX = (dx > 0 ? 1 : -1) * (triggerThreshold + extra * dampFactor)
                        }
                    }
                    .onEnded { val in
                        guard !isTriggerred else { return }
                        let dx = val.translation.width
                        // 信息性事件不可左滑完成
                        if dx < -triggerThreshold && event.isActionableTask { triggerComplete() }
                        else if dx < -triggerThreshold { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offsetX = 0 } }
                        else if dx > triggerThreshold { pendingDelete() }
                        else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offsetX = 0 }
                        }
                    }
                )
                .onTapGesture { showDetail = true }
        }
        .sheet(isPresented: $showDetail) {
            EventDetailSheet(event: event, occurrenceDate: occurrenceDate, onDelete: onDelete, onComplete: onComplete)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // F1+F2: 唯一删除确认弹窗，所有逻辑在此处理
        .confirmationDialog(
            event.recurrenceDays > 0 ? "删除重复事件" : "删除「\(event.title)」",
            isPresented: $showDeleteConfirmAlert,
            titleVisibility: .visible
        ) {
            if event.recurrenceDays > 0 {
                Button("仅删除此条", role: .destructive) { deleteSingleOccurrence() }
                Button("删除此条及之后所有重复", role: .destructive) { deleteThisAndAfter() }
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
            guard rowState == .overdue else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                overdueBreath = true
            }
            withAnimation(.easeInOut(duration: 0.83).repeatForever(autoreverses: true)) {
                overdueFloat = 2.0
            }
        }
        .overlay(alignment: .top) {
            if showSkipReason {
                Text("今日已打卡，不重复奖励 🥥")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.goYellow, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .offset(y: -8)
            }
        }
    }

    // MARK: - Event Card

    private var eventCard: some View {
        let titlePrimary: Color = colorScheme == .light ? Color.black.opacity(0.88) : Color.white
        let titleMuted: Color = colorScheme == .light ? Color.black.opacity(0.38) : Color.white.opacity(0.35)
        let timeSecondary: Color = colorScheme == .light ? Color.black.opacity(0.45) : Color.white.opacity(0.35)
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
                        .frame(width: 40, height: 40)
                        .scaleEffect(overdueBreath ? 1.05 : 1.0)
                    if leftProgress > 0.3 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .opacity(Double((leftProgress - 0.3) / 0.7))
                            .scaleEffect(0.5 + leftProgress * 0.5)
                    } else {
                        Image(systemName: event.silhouetteListSymbol)
                            .font(.system(size: 17, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.white)
                            .opacity(1 - Double(leftProgress / 0.3))
                    }
                }
                .offset(y: overdueFloat)
            } else if rowState == .completed {
                ZStack {
                    Circle()
                        .fill(Color.goTeal.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goTeal)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(nodeCircleColor)
                        .frame(width: 40, height: 40)
                    // Morph icon → checkmark as swipe deepens
                    if leftProgress > 0.4 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .opacity(Double((leftProgress - 0.4) / 0.6))
                            .scaleEffect(0.5 + leftProgress * 0.5)
                    } else {
                        Image(systemName: event.silhouetteListSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.primary)
                            .opacity(leftProgress > 0 ? Double(1 - leftProgress / 0.4) : 1)
                    }
                }
            }

            // 中间信息区
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(rowState == .completed ? titleMuted : titlePrimary)
                    .strikethrough(rowState == .completed, color: titleMuted.opacity(0.9))
                    .lineLimit(1)
                    .opacity(leftProgress > 0 ? Double(max(0, 1 - leftProgress * 0.8)) : 1)

                HStack(spacing: 6) {
                    Text(event.eventType)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(eventNodeColor)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(eventNodeColor.opacity(0.15), in: Capsule())

                    if event.recurrenceDays > 0 {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(timeSecondary.opacity(0.85))
                    }
                    if rowState == .overdue {
                        Text("逾期")
                            .font(.system(size: 9, weight: .black, design: .rounded))
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goPrimary)
                } else if event.isAllDay {
                    Text("全天")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(timeSecondary)
                } else {
                    Text(occurrenceDisplayStart, style: .time)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: leftProgress)
    }

    // MARK: - Color Coding

    private var eventNodeColor: Color {
        if let themeColor = petThemeColor { return themeColor }
        let t = event.eventType.lowercased() + event.title.lowercased()
        if t.contains("排泄") || t.contains("potty") || t.contains("便") || t.contains("铲") { return .goTeal }
        if t.contains("喂食") || t.contains("食") || t.contains("feed")                      { return .goYellow }
        if t.contains("遛")   || t.contains("walk")                                          { return .goPrimary }
        if t.contains("医")   || t.contains("疫苗") || t.contains("health")                  { return .goRed }
        if t.contains("清洁") || t.contains("洗澡") || t.contains("hygiene")                 { return Color(hex: "C084FC") }
        return .goCardBlue
    }

    // MARK: - Gesture Actions

    private func triggerComplete() {
        isTriggerred = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        // task38: 防重复奖励 — 检查今日该宠物是否已就打卡过
        let alreadyCheckedIn = hasTodayCheckIn(for: event)
        if !alreadyCheckedIn {
            QuestManager.shared.addCoconuts(5, emoji: "🥥", title: event.title + " 完成奖励")
            spawnCoconutFloat()
        } else {
            // 提示用户已打卡
            withAnimation(.spring(response: 0.3)) { showSkipReason = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showSkipReason = false }
            }
        }
        launchCelebrationParticles()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { offsetX = -800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onComplete()
            self.isTriggerred = false
            withAnimation(.spring(response: 0.35)) { self.offsetX = 0 }
        }
    }

    /// task38: 检查今日该宠物是否已有对应类型的打卡记录
    private func hasTodayCheckIn(for event: Event) -> Bool {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet" else { return false }
        let petIdStr = event.relatedEntityId
        let title = event.title
        // 判断事件类型
        let isFeeding  = title.contains("喂") || title.contains("feed") || title.contains("吃")
        let isWatering = title.contains("水") || title.contains("喝")
        let isPotty    = title.contains("便") || title.contains("铲") || title.contains("potty")
        let isWalk     = title.contains("遛") || title.contains("散步") || title.contains("巡岛") || title.contains("walk")
        guard isFeeding || isWatering || isPotty || isWalk else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        if isPotty {
            let desc = FetchDescriptor<PetPottyLog>(
                predicate: #Predicate { log in
                    log.date >= today && log.date < tomorrow
                }
            )
            guard let logs = try? modelContext.fetch(desc) else { return false }
            return logs.contains { $0.pet?.id.uuidString == petIdStr }
        }
        if isWalk {
            let desc = FetchDescriptor<PetWalkLog>(
                predicate: #Predicate { log in
                    log.startDate >= today && log.startDate < tomorrow
                }
            )
            guard let logs = try? modelContext.fetch(desc) else { return false }
            return logs.contains { $0.pet?.id.uuidString == petIdStr }
        }
        let careType: String = isFeeding ? CareType.feeding.rawValue : CareType.watering.rawValue
        let desc = FetchDescriptor<PetCareLog>(
            predicate: #Predicate { log in
                log.date >= today && log.date < tomorrow
            }
        )
        guard let logs = try? modelContext.fetch(desc) else { return false }
        return logs.contains { $0.pet?.id.uuidString == petIdStr && $0.type == careType }
    }

    // E1: 右滑只弹确认 alert，回弹到原位
    private func pendingDelete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offsetX = 0 }
        showDeleteConfirmAlert = true
    }

    private func triggerDelete() {
        isTriggerred = true
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { offsetX = 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            modelContext.delete(event)
            modelContext.safeSave()
            onDelete()
            isTriggerred = false
            withAnimation(.spring(response: 0.35)) { offsetX = 0 }
        }
    }

    /// F1: 仅删除单条重复出现（修改 recurrenceEndDate 或 startDate 或拆分）
    private func deleteSingleOccurrence() {
        let cal = Calendar.current
        let occStart = cal.startOfDay(for: occurrenceDate)
        let eventStart = cal.startOfDay(for: event.startDate)

        if occStart == eventStart {
            // 第一条：将 startDate 推进到下一次
            if let next = cal.date(byAdding: .day, value: event.recurrenceDays, to: eventStart) {
                let hasMore: Bool
                if let end = event.recurrenceEndDate {
                    hasMore = next <= cal.startOfDay(for: end)
                } else {
                    hasMore = true
                }
                if hasMore {
                    event.startDate = next
                } else {
                    modelContext.delete(event)
                }
            } else {
                modelContext.delete(event)
            }
        } else {
            // 中间或末尾：截断当前事件到前一天，如果后面还有则创建新事件
            let dayBefore = cal.date(byAdding: .day, value: -1, to: occStart)!
            let nextOcc = cal.date(byAdding: .day, value: event.recurrenceDays, to: occStart)!
            let hasAfter: Bool
            if let endDate = event.recurrenceEndDate {
                hasAfter = nextOcc <= cal.startOfDay(for: endDate)
            } else {
                hasAfter = true
            }
            if hasAfter {
                let newEvent = Event(
                    title: event.title,
                    startDate: nextOcc,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    eventType: event.eventType,
                    relatedEntityType: event.relatedEntityType,
                    relatedEntityId: event.relatedEntityId
                )
                newEvent.recurrenceDays = event.recurrenceDays
                newEvent.recurrenceEndDate = event.recurrenceEndDate
                newEvent.assigneeId = event.assigneeId
                modelContext.insert(newEvent)
            }
            event.recurrenceEndDate = dayBefore
        }
        modelContext.safeSave()
        onDelete()
    }

    /// F1: 删除此条及之后所有重复
    private func deleteThisAndAfter() {
        let cal = Calendar.current
        let occStart = cal.startOfDay(for: occurrenceDate)
        let eventStart = cal.startOfDay(for: event.startDate)

        if occStart <= eventStart {
            // 选中的是第一条或之前 → 删除整个事件
            modelContext.delete(event)
        } else {
            // 截断到选中日期的前一天
            let dayBefore = cal.date(byAdding: .day, value: -1, to: occStart)!
            event.recurrenceEndDate = dayBefore
        }
        modelContext.safeSave()
        onDelete()
    }

    private func launchCelebrationParticles() {
        let emojis = equipFxStars ? ["✨", "⭐️", "🌟", "💫", "💛"] : ["⭐️", "✨", "💛", "🎉", "🐾"]
        celebrationParticles = (0..<6).map { i in
            CelebrationParticle(
                emoji: emojis[i % emojis.count],
                offsetX: CGFloat.random(in: -80...80),
                offsetY: CGFloat.random(in: -120 ... -40),
                rotation: Double.random(in: -30...30)
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { celebrationParticles.removeAll() }
    }

    private func spawnCoconutFloat() {
        var f = CoconutFloat()
        coconutFloats.append(f)
        let id = f.id
        withAnimation(.easeOut(duration: 0.9)) {
            if let idx = coconutFloats.firstIndex(where: { $0.id == id }) {
                coconutFloats[idx].offsetY = -60
                coconutFloats[idx].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            coconutFloats.removeAll { $0.id == id }
        }
        _ = f
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
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 12).padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题行
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(nodeColor.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: event.silhouetteListSymbol)
                                .font(.system(size: 22, weight: .bold))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(nodeColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(event.eventType)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
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
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除", systemImage: "trash.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.goRed, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("删除此事项", role: .destructive) {
                                modelContext.delete(event)
                                modelContext.safeSave()
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
        .presentationCornerRadius(28)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(nodeColor)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 24)
    }

    private func recurrenceLabel(_ days: Int) -> String {
        switch days {
        case 1:  return "每天"
        case 7:  return "每周"
        case 14: return "每两周"
        case 30: return "每月"
        default: return "每\(days)天"
        }
    }

    private var nodeColor: Color {
        let t = event.eventType.lowercased()
        if t.contains("排泄") || t.contains("potty")  { return .goTeal }
        if t.contains("喂食") || t.contains("feed")   { return .goYellow }
        if t.contains("遛")   || t.contains("walk")   { return .goPrimary }
        if t.contains("医")   || t.contains("疫苗")   { return .goRed }
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
