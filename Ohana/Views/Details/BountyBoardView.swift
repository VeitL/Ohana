//
//  BountyBoardView.swift
//  Ohana
//
//  家庭悬赏榜 — 家人间发布任务，接单完成后资产转移
//

import SwiftUI
import SwiftData

// MARK: - 悬赏任务模型（用 WishlistItem 扩展，或用 UserDefaults 存储）
struct BountyTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var reward: Int          // 椰子奖励
    var creatorId: String    // Human UUID
    var creatorName: String
    var creatorEmoji: String
    var assigneeId: String?  // 接单人（实际完成者）UUID
    var assigneeName: String?
    // 指派字段（发布时 @ 某个家人，可选；nil = 所有人可接）
    var assignedToId: String?
    var assignedToName: String?
    var assignedToEmoji: String?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var emoji: String

    init(title: String, description: String, reward: Int,
         creatorId: String, creatorName: String, creatorEmoji: String, emoji: String,
         assignedToId: String? = nil, assignedToName: String? = nil, assignedToEmoji: String? = nil) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.reward = reward
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.creatorEmoji = creatorEmoji
        self.emoji = emoji
        self.assignedToId = assignedToId
        self.assignedToName = assignedToName
        self.assignedToEmoji = assignedToEmoji
        self.isCompleted = false
        self.createdAt = Date()
    }

    /// 从 AppStorage 读取并解析当前存储的所有悬赏任务
    static func loadAll() -> [BountyTask] {
        guard let raw = UserDefaults.standard.string(forKey: "bountyTasks"),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([BountyTask].self, from: data)
        else { return [] }
        return decoded
    }

    /// 计算指派给某家人且未完成的任务数（用于首页红点 / 入口 badge）
    static func pendingAssignedCount(for humanIdString: String) -> Int {
        guard !humanIdString.isEmpty else { return 0 }
        return loadAll().filter {
            !$0.isCompleted && $0.assignedToId == humanIdString
        }.count
    }
}

// MARK: - 悬赏榜主视图
struct BountyBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]
    @AppStorage("bountyTasks") private var tasksRaw: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @State private var questManager = QuestManager.shared
    @State private var showAddTask   = false
    @State private var selectedTab   = 0   // 0=进行中 1=已完成 2=周报
    @State private var completedTaskId: UUID? = nil
    @State private var showCompleteConfirm = false
    @State private var pendingCompleteId: UUID? = nil

    private var tasks: [BountyTask] {
        guard let data = tasksRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([BountyTask].self, from: data)
        else { return [] }
        return decoded
    }

    private func saveTasks(_ tasks: [BountyTask]) {
        if let data = try? JSONEncoder().encode(tasks),
           let str = String(data: data, encoding: .utf8) {
            tasksRaw = str
        }
    }

    private var activeTasks: [BountyTask]    { tasks.filter { !$0.isCompleted } }
    private var completedTasks: [BountyTask] { tasks.filter { $0.isCompleted } }

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

    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.58) }
    private var tertiaryText: Color { colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4) }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
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
                                            withAnimation(.spring(response: 0.3)) { showArchive.toggle() }
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
                                        .buttonStyle(.plain)
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
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.goPrimary)
                            .font(OhanaFont.metric(size: 22, .semibold))
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddBountyTaskSheet(humans: humans, currentHumanId: activeHumanId) { newTask in
                    var current = tasks
                    current.insert(newTask, at: 0)
                    saveTasks(current)
                }
            }
            .confirmationDialog("确认完成", isPresented: $showCompleteConfirm, titleVisibility: .visible) {
                Button("完成并领取奖励") {
                    if let id = pendingCompleteId {
                        completeTask(id: id)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = idx }
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
        .buttonStyle(.plain)
    }

    // MARK: - 任务卡片
    private func taskCard(_ task: BountyTask, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(OhanaFont.metric(size: 28))
                    .frame(width: 48, height: 48)
                    .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

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
                    Image(systemName: "arrow.right")
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
                        (task.assignedToId == activeHumanId
                            ? Color.goPrimary.opacity(0.18)
                            : Color.goTeal.opacity(0.12)
                        ),
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
                        if task.assignedToId == nil { return !isOwner }    // 所有人可接（除自己发布的）
                        return isAssignedToMe                              // 被 @ 才能完成
                    }()

                    if isOwner {
                        Button {
                            deleteTask(id: task.id)
                        } label: {
                            Text("撤销")
                                .font(OhanaFont.caption(.semibold))
                                .foregroundStyle(Color.goRed.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.goRed.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else if canComplete {
                        Button {
                            pendingCompleteId = task.id
                            showCompleteConfirm = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(OhanaFont.caption2(.bold))
                                Text("完成")
                                    .font(OhanaFont.caption(.bold))
                            }
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.goPrimary, in: Capsule())
                        }
                        .buttonStyle(.plain)
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
                        Image(systemName: "checkmark.circle.fill")
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isActive
                        ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
                        : Color.goTeal.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
    private func completeTask(id: UUID) {
        var current = tasks
        guard let idx = current.firstIndex(where: { $0.id == id }) else { return }
        var task = current[idx]

        let reward = task.reward
        task.isCompleted = true
        task.completedAt = Date()
        task.assigneeId = activeHumanId
        task.assigneeName = currentHuman?.name
        current[idx] = task
        saveTasks(current)

        // 奖励椰子
        questManager.addCoconuts(
            reward,
            emoji: "📋",
            title: "完成家庭任务",
            actorId: activeHumanId.isEmpty ? nil : activeHumanId,
            actorName: currentHuman?.name
        )
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - 删除任务
    private func deleteTask(id: UUID) {
        var current = tasks
        current.removeAll { $0.id == id }
        saveTasks(current)
    }

    // MARK: - 周报 Tab（每位家人本周护理打卡柱图）

    /// 单个家人的本周统计
    private struct HumanWeekStat: Identifiable {
        let id: String              // humanId
        let human: Human
        let count: Int              // 本周所有护理动作总数
        let careCount: Int          // 喂食/喝水/换水等
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

        var care: [String: Int]    = [:]
        var potty: [String: Int]   = [:]
        var walk: [String: Int]    = [:]
        var expense: [String: Int] = [:]

        for pet in pets {
            for log in pet.careLogs where log.date >= start {
                if let id = log.executorId, !id.isEmpty { care[id, default: 0] += 1 }
            }
            for log in pet.pottyLogs where log.date >= start {
                if let id = log.executorId, !id.isEmpty { potty[id, default: 0] += 1 }
            }
            for log in pet.walkLogs where log.startDate >= start {
                if let id = log.executorId, !id.isEmpty { walk[id, default: 0] += 1 }
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
                Image(systemName: "chart.bar.xaxis")
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .frame(width: 40, height: 40)
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
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
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
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isTop
                        ? Color.goYellow.opacity(0.06)
                        : Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.04)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

// MARK: - 发布任务 Sheet
struct AddBountyTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let humans: [Human]
    let currentHumanId: String
    let onAdd: (BountyTask) -> Void

    @State private var title       = ""
    @State private var description = ""
    @State private var reward      = 20
    @State private var selectedEmoji = "🎯"
    @State private var showEmojiPicker = false
    @State private var assignedToId: String? = nil  // nil = 所有人可接

    private let emojiOptions = ["🎯","🧹","🍳","🛒","📦","🐾","🌱","💊","🚗","📚","🎮","🎂","🧺","💻","🔧","✏️","🎵","🏃"]
    private let rewardOptions = [10, 20, 30, 50, 80, 100, 150, 200]

    private var creator: Human? {
        humans.first { $0.id.uuidString == currentHumanId }
    }

    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.58) }
    private var tertiaryText: Color { colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4) }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Emoji 选择
                        VStack(alignment: .leading, spacing: 10) {
                            Text("任务图标")
                                .font(OhanaFont.subheadline(.semibold))
                                .foregroundStyle(tertiaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(emojiOptions, id: \.self) { emoji in
                                        Button {
                                            selectedEmoji = emoji
                                        } label: {
                                            Text(emoji)
                                                .font(OhanaFont.metric(size: 28))
                                                .frame(width: 52, height: 52)
                                                .background(
                                                    selectedEmoji == emoji
                                                        ? Color.goPrimary.opacity(0.25)
                                                        : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08),
                                                    in: RoundedRectangle(cornerRadius: 14)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .strokeBorder(
                                                            selectedEmoji == emoji
                                                                ? Color.goPrimary : Color.clear,
                                                            lineWidth: 2
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        // 标题
                        formField(title: "任务标题") {
                            TextField("", text: $title)
                                .font(OhanaFont.headline(.semibold))
                                .foregroundStyle(primaryText)
                                .tint(Color.goPrimary)
                                .placeholder(when: title.isEmpty) {
                                    Text("例如：帮我给猫铲屎")
                                        .foregroundStyle(tertiaryText)
                                }
                        }

                        // 描述
                        formField(title: "任务说明（可选）") {
                            TextField("", text: $description, axis: .vertical)
                                .font(OhanaFont.callout(.medium))
                                .foregroundStyle(primaryText)
                                .tint(Color.goPrimary)
                                .lineLimit(3)
                                .placeholder(when: description.isEmpty) {
                                    Text("描述任务内容...")
                                        .foregroundStyle(tertiaryText)
                                }
                        }

                        // 奖励
                        VStack(alignment: .leading, spacing: 10) {
                            Text("椰子奖励")
                                .font(OhanaFont.subheadline(.semibold))
                                .foregroundStyle(tertiaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(rewardOptions, id: \.self) { val in
                                        Button {
                                            reward = val
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text("🥥")
                                                    .font(OhanaFont.metric(size: 16, .medium))
                                                Text("\(val)")
                                                    .font(OhanaFont.callout(.black))
                                                    .foregroundStyle(
                                                        reward == val ? Color.arkInk : Color.goYellow
                                                    )
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(
                                                reward == val ? Color.goPrimary : Color.goYellow.opacity(0.1),
                                                in: RoundedRectangle(cornerRadius: 12)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(
                                                        reward == val ? Color.clear : Color.goYellow.opacity(0.2),
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        // 指派给（可选；不选 = 所有人可接）
                        if humans.count > 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Text("指派给")
                                        .font(OhanaFont.subheadline(.semibold))
                                        .foregroundStyle(tertiaryText)
                                    if assignedToId != nil {
                                        Text("@")
                                            .font(OhanaFont.caption(.black))
                                            .foregroundStyle(Color.goPrimary)
                                    }
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        assigneeOption(id: nil, emoji: "👥", name: "所有人可接")
                                        ForEach(humans.filter { $0.id.uuidString != currentHumanId }) { h in
                                            assigneeOption(id: h.id.uuidString, emoji: h.avatarEmoji, name: h.name)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                        }

                        // 发布人预览
                        if let human = creator {
                            HStack(spacing: 10) {
                                Text(human.avatarEmoji)
                                    .font(OhanaFont.title2())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("发布人")
                                        .font(OhanaFont.caption2(.medium))
                                        .foregroundStyle(tertiaryText)
                                    Text(human.name)
                                        .font(OhanaFont.callout(.bold))
                                        .foregroundStyle(primaryText)
                                }
                                Spacer()
                                Text("奖励 \(reward)🥥")
                                    .font(OhanaFont.subheadline(.bold))
                                    .foregroundStyle(Color.goYellow)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Color.goYellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.goYellow.opacity(0.15), lineWidth: 1))
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("发布悬赏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(secondaryText)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        guard !title.isEmpty, let human = creator else { return }
                        let assignee = humans.first { $0.id.uuidString == assignedToId }
                        let task = BountyTask(
                            title: title,
                            description: description,
                            reward: reward,
                            creatorId: human.id.uuidString,
                            creatorName: human.name,
                            creatorEmoji: human.avatarEmoji,
                            emoji: selectedEmoji,
                            assignedToId: assignee?.id.uuidString,
                            assignedToName: assignee?.name,
                            assignedToEmoji: assignee?.avatarEmoji
                        )
                        onAdd(task)
                        dismiss()
                    } label: {
                        Text("发布")
                            .font(OhanaFont.body(.bold))
                            .foregroundStyle(title.isEmpty ? Color.goPrimary.opacity(0.35) : Color.goPrimary)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .tint(Color.goPrimary)
    }

    @ViewBuilder
    private func assigneeOption(id: String?, emoji: String, name: String) -> some View {
        let isSelected = assignedToId == id
        Button {
            assignedToId = id
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? Color.goPrimary.opacity(0.25)
                                : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08)
                        )
                        .frame(width: 46, height: 46)
                    Text(emoji).font(OhanaFont.title3())
                }
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2)
                )
                Text(name)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(isSelected ? Color.goPrimary : secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 60)
            }
        }
        .buttonStyle(.plain)
    }

    private func formField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.subheadline(.semibold))
                .foregroundStyle(tertiaryText)
            content()
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Placeholder helper
extension View {
    @ViewBuilder
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}
