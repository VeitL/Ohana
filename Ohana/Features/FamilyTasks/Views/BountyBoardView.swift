//
//  BountyBoardView.swift
//  Ohana
//
//  家庭悬赏榜 — 家人间发布任务，接单完成后资产转移
//

import SwiftData
import SwiftUI

// MARK: - 悬赏榜主视图
struct BountyBoardContentView: View {
    let humans: [Human]
    let pets: [Pet]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("bountyTasks") private var tasksRaw: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @State private var showAddTask = false
    @State private var selectedTab = 0 // 0=进行中 1=已完成 2=周报
    @State private var completedTaskId: UUID? = nil
    @State private var showCompleteConfirm = false
    @State private var pendingCompleteId: UUID? = nil

    private var tasks: [BountyTask] {
        BountyTask.decode(tasksRaw)
    }

    private var activeTasks: [BountyTask] { tasks.filter { !$0.isCompleted } }
    private var completedTasks: [BountyTask] { tasks.filter(\.isCompleted) }

    // P2: 历史归档 — 7天前完成的任务
    private var recentCompleted: [BountyTask] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return completedTasks.filter { ($0.completedAt ?? $0.createdAt) >= cutoff }
    }

    private var archivedCompleted: [BountyTask] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return completedTasks.filter { ($0.completedAt ?? $0.createdAt) < cutoff }
    }

    @State private var showArchive = false

    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
    }

    private var legacyBountyExecutor: LegacyBountyCommandExecutor {
        LegacyBountyCommandExecutor(
            questManager: appServices.questManager,
            revisions: appServices.domainRevisions
        )
    }

    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.58) }
    private var tertiaryText: Color { colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4) }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 统计 Header
                    statsHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Tab 切换
                    tabPicker
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // 列表
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if selectedTab == 2 {
                                weeklyReportContent
                            } else if selectedTab == 0 {
                                if activeTasks.isEmpty {
                                    emptyState(message: "还没有悬赏任务\n发布第一个任务，让家人来完成吧！")
                                } else {
                                    ForEach(activeTasks) { task in
                                        taskCard(task, isActive: true)
                                    }
                                }
                            } else {
                                if completedTasks.isEmpty {
                                    emptyState(message: "还没有完成的任务")
                                } else {
                                    // 近7天完成
                                    ForEach(recentCompleted) { task in
                                        taskCard(task, isActive: false)
                                    }
                                    // 历史归档（7天前完成）
                                    if !archivedCompleted.isEmpty {
                                        Button {
                                            withAnimation(.spring(response: 0.3)) { showArchive.toggle() } // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: showArchive ? "chevron.down" : "chevron.right")
                                                    .font(OhanaFont.caption2(.bold))
                                                Text("历史归档 (\(archivedCompleted.count))")
                                                    .font(OhanaFont.caption(.bold))
                                                Spacer()
                                            }
                                            .foregroundStyle(tertiaryText)
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        if showArchive {
                                            ForEach(archivedCompleted) { task in
                                                taskCard(task, isActive: false)
                                                    .opacity(0.7)
                                            }
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("家庭悬赏榜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ohanaCardSurface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("关闭")
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(Color.goPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill").accessibilityHidden(true)
                            .foregroundStyle(Color.goPrimary)
                            .font(OhanaFont.metric(size: 22, .semibold))
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddBountyTaskSheet(humans: humans, currentHumanId: activeHumanId) { newTask in
                    runLegacyBountyCommand {
                        createTask(newTask)
                    }
                }
            }
            .confirmationDialog("确认完成", isPresented: $showCompleteConfirm, titleVisibility: .visible) {
                Button("完成并领取奖励") {
                    if let id = pendingCompleteId {
                        runLegacyBountyCommand {
                            completeTask(id: id)
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let id = pendingCompleteId,
                   let task = tasks.first(where: { $0.id == id }) {
                    Text("完成「\(task.title)」并领取 \(task.reward)🥥 奖励？")
                }
            }
        }
        .tint(Color.goPrimary)
    }

    // MARK: - 统计 Header
    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCell(value: "\(activeTasks.count)", label: "进行中", accent: Color.goPrimary)
            statCell(value: "\(completedTasks.count)", label: "已完成", accent: Color.goTeal)
            statCell(
                value: "\(completedTasks.reduce(0) { $0 + $1.reward })🥥",
                label: "累计发放",
                accent: Color.goYellow
            )
        }
    }

    private func statCell(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(accent)
            Text(label)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack(spacing: 8) {
            tabButton(label: "进行中 (\(activeTasks.count))", idx: 0)
            tabButton(label: "已完成 (\(completedTasks.count))", idx: 1)
            tabButton(label: "周报", idx: 2)
            Spacer()
        }
    }

    private func tabButton(label: String, idx: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = idx } // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
        } label: {
            Text(label)
                .font(OhanaFont.subheadline(.bold))
                .foregroundStyle(selectedTab == idx ? Color.arkInk : secondaryText)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(
                    selectedTab == idx ? Color.goPrimary : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selectedTab == idx ? Color.clear : Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - 任务卡片
    private func taskCard(_ task: BountyTask, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(OhanaFont.metric(size: 28))
                    .frame(width: 48, height: 48)
                    .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.chip))

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(OhanaFont.footnote(.medium))
                            .foregroundStyle(secondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // 奖励
                VStack(spacing: 2) {
                    Text("🥥")
                        .font(OhanaFont.metric(size: 16, .medium))
                    Text("\(task.reward)")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.goYellow)
                }
            }

            // 发布人 → 指派对象（如有）
            HStack(spacing: 8) {
                Text(task.creatorEmoji)
                    .font(OhanaFont.subheadline())
                Text(task.creatorName)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(tertiaryText)

                if let toName = task.assignedToName, !toName.isEmpty {
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(tertiaryText)
                    HStack(spacing: 3) {
                        if let emoji = task.assignedToEmoji, !emoji.isEmpty {
                            Text(emoji).font(OhanaFont.footnote())
                        }
                        Text("@\(toName)")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(
                                task.assignedToId == activeHumanId
                                    ? Color.goPrimary
                                    : Color.goTeal.opacity(0.85)
                            )
                    }
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(
                        task.assignedToId == activeHumanId
                            ? Color.goPrimary.opacity(0.18)
                            : Color.goTeal.opacity(0.12),

                        in: Capsule()
                    )
                } else {
                    Text("发布")
                        .font(OhanaFont.caption(.medium))
                        .foregroundStyle(tertiaryText)
                }

                Spacer()

                if isActive {
                    let isOwner = task.creatorId == activeHumanId
                    let isAssignedToMe = task.assignedToId == activeHumanId
                    let canComplete: Bool = {
                        if task.assignedToId == nil { return !isOwner } // 所有人可接（除自己发布的）
                        return isAssignedToMe // 被 @ 才能完成
                    }()

                    if isOwner {
                        Button {
                            runLegacyBountyCommand {
                                deleteTask(id: task.id)
                            }
                        } label: {
                            Text("撤销")
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.goRed.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.goRed.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else if canComplete {
                        Button {
                            pendingCompleteId = task.id
                            showCompleteConfirm = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                                    .font(OhanaFont.caption2(.bold))
                                Text("完成")
                                    .font(OhanaFont.caption(.bold))
                            }
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        Text("指派中")
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(tertiaryText)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), in: Capsule())
                    }
                } else {
                    // 已完成标签
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color.goTeal)
                        if let name = task.assigneeName {
                            Text(name)
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.goTeal.opacity(0.8))
                        }
                    }
                }
            }

            // 已完成时间
            if !isActive, let completedAt = task.completedAt {
                Text("完成于 \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(OhanaFont.caption2(.medium))
                    .foregroundStyle(tertiaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .fill(
                    isActive
                        ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
                        : Color.goTeal.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.goYellow.opacity(0.18) : Color.goTeal.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - 空状态
    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Text("📋")
                .font(OhanaFont.metric(size: 48, .medium))
                .opacity(0.5)
            Text(message)
                .font(OhanaFont.callout(.medium))
                .foregroundStyle(tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 完成任务（资产转移）
    private func createTask(_ task: BountyTask) {
        guard let raw = legacyBountyExecutor.createTask(task, in: tasks) else { return }
        tasksRaw = raw
    }

    private func completeTask(id: UUID) {
        guard let raw = legacyBountyExecutor.completeTask(
            id: id,
            in: tasks,
            activeHumanId: activeHumanId,
            currentHuman: currentHuman,
            context: modelContext
        ) else { return }
        tasksRaw = raw
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - 删除任务
    private func deleteTask(id: UUID) {
        guard let raw = legacyBountyExecutor.deleteTask(id: id, in: tasks) else { return }
        tasksRaw = raw
    }

    private func runLegacyBountyCommand(_ command: @escaping @MainActor () -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        OhanaFrameScheduler.runAfterNextFrame {
            command()
        }
    }

    // MARK: - 周报 Tab（每位家人本周护理打卡柱图）

    /// 单个家人的本周统计
    private struct HumanWeekStat: Identifiable {
        let id: String // humanId
        let human: Human
        let count: Int // 本周所有护理动作总数
        let careCount: Int // 喂食/喝水/换水等
        let pottyCount: Int
        let walkCount: Int
        let expenseCount: Int
    }

    /// 本周起点（周一 00:00，使用系统 Calendar 设置）
    private var weekStart: Date {
        let cal = Calendar.current
        let today = Date()
        // 使用系统周起始日
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        return cal.date(from: comps) ?? cal.startOfDay(for: today)
    }

    /// 本周每位家人的统计（按总数降序）
    private var weeklyStats: [HumanWeekStat] {
        let start = weekStart

        var care: [String: Int] = [:]
        var potty: [String: Int] = [:]
        var walk: [String: Int] = [:]
        var expense: [String: Int] = [:]

        for pet in pets {
            for log in pet.careLogs where log.date >= start {
                if let id = log.executorId, !id.isEmpty { care[id, default: 0] += 1 }
            }
            for log in pet.pottyLogs where log.date >= start {
                if let id = log.executorId, !id.isEmpty { potty[id, default: 0] += 1 }
            }
            for log in pet.walkLogs where log.startDate >= start {
                for id in log.executorIds where !id.isEmpty {
                    walk[id, default: 0] += 1
                }
            }
            for log in pet.expenseLogs where log.date >= start {
                if let id = log.executorId, !id.isEmpty { expense[id, default: 0] += 1 }
            }
        }

        return humans.map { h in
            let key = h.id.uuidString
            let c = care[key] ?? 0
            let p = potty[key] ?? 0
            let w = walk[key] ?? 0
            let e = expense[key] ?? 0
            return HumanWeekStat(
                id: key, human: h,
                count: c + p + w + e,
                careCount: c, pottyCount: p, walkCount: w, expenseCount: e
            )
        }
        .sorted { $0.count > $1.count }
    }

    @ViewBuilder
    private var weeklyReportContent: some View {
        let stats = weeklyStats
        let total = stats.reduce(0) { $0 + $1.count }
        let maxCount = max(stats.first?.count ?? 0, 1)
        let topperId = stats.first(where: { $0.count > 0 })?.id

        VStack(alignment: .leading, spacing: 16) {
            weeklyHeader(total: total, topper: stats.first(where: { $0.count > 0 })?.human)

            if total == 0 {
                emptyState(message: "本周还没有打卡记录\n快去主页给宠物打卡吧！")
            } else {
                VStack(spacing: 10) {
                    ForEach(stats) { s in
                        weeklyBarRow(s, maxCount: maxCount, isTop: s.id == topperId)
                    }
                }

                Text("每周日 20:00 会推送本周家庭周报 · 可在系统通知中管理")
                    .font(OhanaFont.caption2(.medium))
                    .foregroundStyle(tertiaryText)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func weeklyHeader(total: Int, topper: Human?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis").accessibilityHidden(true)
                    .font(OhanaFont.subheadline(.bold))
                    .foregroundStyle(Color.goPrimary)
                Text("本周家庭照护周报")
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(primaryText)
                Spacer()
                Text(weekRangeLabel)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
            }
            HStack(spacing: 12) {
                statCell(value: "\(total)", label: "总打卡", accent: Color.goPrimary)
                if let topper {
                    statCell(
                        value: "\(topper.avatarEmoji) \(topper.name)",
                        label: "本周最勤快",
                        accent: Color.goYellow
                    )
                } else {
                    statCell(value: "—", label: "本周最勤快", accent: Color.goYellow.opacity(0.4))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var weekRangeLabel: String {
        let start = weekStart
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let fmt = DateFormatter()
        fmt.locale = AppLanguage.effectiveLocale
        fmt.dateFormat = AppLanguage.compactMonthDayFormat
        return "\(fmt.string(from: start)) - \(fmt.string(from: end))"
    }

    private func weeklyBarRow(_ stat: HumanWeekStat, maxCount: Int, isTop: Bool) -> some View {
        let ratio = CGFloat(stat.count) / CGFloat(maxCount)
        return HStack(spacing: 10) {
            Text(stat.human.avatarEmoji)
                .font(OhanaFont.title3())
                .frame(width: 40, height: 40) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08), in: Circle())
                .overlay(Circle().strokeBorder(
                    isTop ? Color.goYellow : Color.clear,
                    lineWidth: 2
                ))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(stat.human.name)
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(primaryText)
                    if isTop {
                        Text("👑 最勤快")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.goYellow)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.goYellow.opacity(0.15), in: Capsule())
                    }
                    Spacer()
                    Text("\(stat.count)")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(isTop ? Color.goYellow : Color.goPrimary)
                }

                // 柱图
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: OhanaRadius.micro)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: OhanaRadius.micro)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        isTop ? Color.goYellow : Color.goPrimary,
                                        (isTop ? Color.goYellow : Color.goPrimary).opacity(0.5)
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * ratio), height: 8)
                    }
                }
                .frame(height: 8)

                // 明细
                HStack(spacing: 8) {
                    if stat.careCount > 0 {
                        statChip("🍖", "\(stat.careCount)")
                    }
                    if stat.walkCount > 0 {
                        statChip("🦮", "\(stat.walkCount)")
                    }
                    if stat.pottyCount > 0 {
                        statChip("💩", "\(stat.pottyCount)")
                    }
                    if stat.expenseCount > 0 {
                        statChip("💰", "\(stat.expenseCount)")
                    }
                    if stat.count == 0 {
                        Text("本周尚未打卡")
                            .font(OhanaFont.caption2(.medium))
                            .foregroundStyle(tertiaryText)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OhanaRadius.row)
                .fill(
                    isTop
                        ? Color.goYellow.opacity(0.06)
                        : Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.04)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.row)
                .strokeBorder(
                    isTop
                        ? Color.goYellow.opacity(0.25)
                        : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08),
                    lineWidth: 1
                )
        )
    }

    private func statChip(_ emoji: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(emoji).font(OhanaFont.caption2())
            Text(value)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(secondaryText)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), in: Capsule())
    }
}
