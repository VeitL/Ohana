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
    let onComplete: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var offsetX: CGFloat = 0
    @State private var isTriggerred = false
    @State private var celebrationParticles: [CelebrationParticle] = []
    @State private var coconutFloats: [CoconutFloat] = []
    @State private var showDetail = false

    private let triggerThreshold: CGFloat = 100
    private let dampFactor: CGFloat = 0.4

    private var leftProgress:  CGFloat { max(0, -offsetX) / triggerThreshold }
    private var rightProgress: CGFloat { max(0,  offsetX) / triggerThreshold }

    // MARK: - Row State
    private enum RowState { case pending, completed, overdue }
    private var rowState: RowState {
        if event.isCompleted { return .completed }
        // 信息性事件（生日/绪日）即便过期也不显示逾期状态
        if event.startDate < Date() && !event.isCompleted && event.isActionableTask { return .overdue }
        return .pending
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
                    .foregroundStyle(Color.goLime)
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
                        Text("完成").font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
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
                        Image(systemName: rightProgress >= 1 ? "trash.fill" : "trash")
                            .font(.system(size: 20, weight: .bold))
                        Text("删除").font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
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
                        else if dx > triggerThreshold { triggerDelete() }
                        else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offsetX = 0 }
                        }
                    }
                )
                .onTapGesture { showDetail = true }
        }
        .sheet(isPresented: $showDetail) {
            EventDetailSheet(event: event, onDelete: onDelete, onComplete: onComplete)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Event Card

    private var eventCard: some View {
        HStack(spacing: 12) {
            // 动态图标节点
            ZStack {
                Circle()
                    .fill(eventNodeColor.opacity(rowState == .completed ? 0.08 : 0.2))
                    .frame(width: 40, height: 40)
                if rowState == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.goTeal)
                } else {
                    Text(dynamicEmoji)
                        .font(.system(size: 20))
                }
            }

            // 中间信息区
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(rowState == .completed ? .white.opacity(0.35) : .white)
                    .strikethrough(rowState == .completed, color: .white.opacity(0.25))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(event.eventType)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(eventNodeColor)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(eventNodeColor.opacity(0.15), in: Capsule())

                    if event.recurrenceDays > 0 {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    if rowState == .overdue {
                        Text("逾期")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goOrange)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.goOrange.opacity(0.15), in: Capsule())
                    }
                }
            }

            Spacer()

            // 右侧：时间 / 完成标记
            Group {
                if rowState == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.goLime)
                } else if event.isAllDay {
                    Text("全天")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))
                } else {
                    Text(event.startDate, style: .time)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(rowState == .overdue ? Color.goOrange : .white.opacity(0.35))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(rowState == .completed ? 0.04 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    rowState == .overdue ? Color.goOrange.opacity(0.4) : .white.opacity(0.09),
                    lineWidth: rowState == .overdue ? 1.5 : 1
                )
        )
        .opacity(rowState == .completed ? 0.55 : 1.0)
    }

    // MARK: - Dynamic Emoji（根据标题关键词）

    private var dynamicEmoji: String {
        let t = event.title.lowercased()
        if t.contains("喂") || t.contains("feed") || t.contains("吃")     { return "🍖" }
        if t.contains("遛") || t.contains("walk") || t.contains("巡岛")   { return "🦮" }
        if t.contains("便") || t.contains("铲") || t.contains("potty")    { return "💩" }
        if t.contains("疫苗") || t.contains("医") || t.contains("health") { return "💊" }
        if t.contains("洗") || t.contains("澡") || t.contains("bath")     { return "🛁" }
        if t.contains("梳") || t.contains("剪") || t.contains("groom")    { return "✂️" }
        if t.contains("生日") || t.contains("周年") || t.contains("纪念") { return "🎂" }
        if t.contains("水") || t.contains("喝")                           { return "💧" }
        return event.emoji.isEmpty ? "📋" : event.emoji
    }

    // MARK: - Color Coding

    private var eventNodeColor: Color {
        let t = event.eventType.lowercased() + event.title.lowercased()
        if t.contains("排泄") || t.contains("potty") || t.contains("便") || t.contains("铲") { return .goTeal }
        if t.contains("喂食") || t.contains("食") || t.contains("feed")                      { return .goYellow }
        if t.contains("遛")   || t.contains("walk")                                          { return .goLime }
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
        guard event.relatedEntityType == "pet" else { return false }
        let petIdStr = event.relatedEntityId
        let title = event.title
        // 判断事件类型
        let isFeeding  = title.contains("喂") || title.contains("feed") || title.contains("吃")
        let isWatering = title.contains("水") || title.contains("喝")
        let isPotty    = title.contains("便") || title.contains("铲") || title.contains("potty")
        let isWalk     = title.contains("遗") || title.contains("巡岛") || title.contains("walk")
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
        let careType: String = isFeeding ? "feeding" : isWatering ? "watering" : "walking"
        let desc = FetchDescriptor<PetCareLog>(
            predicate: #Predicate { log in
                log.date >= today && log.date < tomorrow
            }
        )
        guard let logs = try? modelContext.fetch(desc) else { return false }
        return logs.contains { $0.pet?.id.uuidString == petIdStr && $0.type == careType }
    }

    private func triggerDelete() {
        isTriggerred = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { offsetX = 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            // 真删除：写入 modelContext
            modelContext.delete(event)
            modelContext.safeSave()
            onDelete()
            isTriggerred = false
            withAnimation(.spring(response: 0.35)) { offsetX = 0 }
        }
    }

    private func launchCelebrationParticles() {
        let emojis = ["⭐️", "✨", "💛", "🎉", "🐾"]
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
    let onDelete: () -> Void
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.1))
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
                            Text(dynamicEmoji)
                                .font(.system(size: 26))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color.arkInk)
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

                    // 时间信息
                    infoRow(icon: "clock.fill", label: "时间",
                            value: event.isAllDay ? "全天" : event.startDate.formatted(date: .abbreviated, time: .shortened))
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
                                Label(event.isCompleted ? "标记未完成" : "标记完成",
                                      systemImage: event.isCompleted ? "xmark.circle" : "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            modelContext.delete(event)
                            modelContext.safeSave()
                            onDelete()
                            dismiss()
                        } label: {
                            Label("删除", systemImage: "trash.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.goRed, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(hex: "F2F0F5"))
        .presentationCornerRadius(28)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(nodeColor)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.arkInk.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.arkInk)
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

    private var dynamicEmoji: String {
        let t = event.title.lowercased()
        if t.contains("喂") || t.contains("feed") { return "🍖" }
        if t.contains("遛") || t.contains("walk") { return "🦮" }
        if t.contains("便") || t.contains("铲")   { return "💩" }
        if t.contains("疫苗") || t.contains("医") { return "💊" }
        if t.contains("洗") || t.contains("澡")   { return "🛁" }
        if t.contains("生日") || t.contains("纪念"){ return "🎂" }
        return event.emoji.isEmpty ? "📋" : event.emoji
    }

    private var nodeColor: Color {
        let t = event.eventType.lowercased()
        if t.contains("排泄") || t.contains("potty")  { return .goTeal }
        if t.contains("喂食") || t.contains("feed")   { return .goYellow }
        if t.contains("遛")   || t.contains("walk")   { return .goLime }
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
