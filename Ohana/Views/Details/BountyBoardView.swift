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
    var assigneeId: String?  // 接单人 UUID
    var assigneeName: String?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var emoji: String

    init(title: String, description: String, reward: Int,
         creatorId: String, creatorName: String, creatorEmoji: String, emoji: String) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.reward = reward
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.creatorEmoji = creatorEmoji
        self.emoji = emoji
        self.isCompleted = false
        self.createdAt = Date()
    }
}

// MARK: - 悬赏榜主视图
struct BountyBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("bountyTasks") private var tasksRaw: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @State private var questManager = QuestManager.shared
    @State private var showAddTask   = false
    @State private var selectedTab   = 0   // 0=进行中 1=已完成
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

    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()

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
                            if selectedTab == 0 {
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
                                    ForEach(completedTasks) { task in
                                        taskCard(task, isActive: false)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Color.goLime)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.goLime)
                            .font(.system(size: 22))
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
    }

    // MARK: - 统计 Header
    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCell(value: "\(activeTasks.count)", label: "进行中", accent: Color.goLime)
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
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(accent)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack(spacing: 8) {
            tabButton(label: "进行中 (\(activeTasks.count))", idx: 0)
            tabButton(label: "已完成 (\(completedTasks.count))", idx: 1)
            Spacer()
        }
    }

    private func tabButton(label: String, idx: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = idx }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selectedTab == idx ? .black : .white.opacity(0.5))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selectedTab == idx ? Color.goLime : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 任务卡片
    private func taskCard(_ task: BountyTask, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                            .lineLimit(2)
                    }
                }

                Spacer()

                // 奖励
                VStack(spacing: 2) {
                    Text("🥥")
                        .font(.system(size: 16))
                    Text("\(task.reward)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
            }

            // 发布人 + 状态
            HStack(spacing: 8) {
                Text(task.creatorEmoji)
                    .font(.system(size: 14))
                Text(task.creatorName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                Text("发布")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.25))

                Spacer()

                if isActive {
                    let isOwner = task.creatorId == activeHumanId
                    if isOwner {
                        // 发布人：可删除
                        Button {
                            deleteTask(id: task.id)
                        } label: {
                            Text("撤销")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.goRed.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.goRed.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 接单人：可完成
                        Button {
                            pendingCompleteId = task.id
                            showCompleteConfirm = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("完成")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.goLime, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // 已完成标签
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.goTeal)
                        if let name = task.assigneeName {
                            Text(name)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.goTeal.opacity(0.8))
                        }
                    }
                }
            }

            // 已完成时间
            if !isActive, let completedAt = task.completedAt {
                Text("完成于 \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.2))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? Color.white.opacity(0.07) : Color.goTeal.opacity(0.05))
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
                .font(.system(size: 48))
                .opacity(0.5)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.3))
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
        questManager.coconutCount += reward
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
}

// MARK: - 发布任务 Sheet
struct AddBountyTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    let humans: [Human]
    let currentHumanId: String
    let onAdd: (BountyTask) -> Void

    @State private var title       = ""
    @State private var description = ""
    @State private var reward      = 20
    @State private var selectedEmoji = "🎯"
    @State private var showEmojiPicker = false

    private let emojiOptions = ["🎯","🧹","🍳","🛒","📦","🐾","🌱","💊","🚗","📚","🎮","🎂","🧺","💻","🔧","✏️","🎵","🏃"]
    private let rewardOptions = [10, 20, 30, 50, 80, 100, 150, 200]

    private var creator: Human? {
        humans.first { $0.id.uuidString == currentHumanId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Emoji 选择
                        VStack(alignment: .leading, spacing: 10) {
                            Text("任务图标")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.5))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(emojiOptions, id: \.self) { emoji in
                                        Button {
                                            selectedEmoji = emoji
                                        } label: {
                                            Text(emoji)
                                                .font(.system(size: 28))
                                                .frame(width: 52, height: 52)
                                                .background(
                                                    selectedEmoji == emoji
                                                        ? Color.goLime.opacity(0.25)
                                                        : Color.white.opacity(0.07),
                                                    in: RoundedRectangle(cornerRadius: 14)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .strokeBorder(
                                                            selectedEmoji == emoji
                                                                ? Color.goLime : Color.clear,
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
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .tint(Color.goLime)
                                .placeholder(when: title.isEmpty) {
                                    Text("例如：帮我给猫铲屎")
                                        .foregroundStyle(.primary.opacity(0.25))
                                }
                        }

                        // 描述
                        formField(title: "任务说明（可选）") {
                            TextField("", text: $description, axis: .vertical)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .tint(Color.goLime)
                                .lineLimit(3)
                                .placeholder(when: description.isEmpty) {
                                    Text("描述任务内容...")
                                        .foregroundStyle(.primary.opacity(0.25))
                                }
                        }

                        // 奖励
                        VStack(alignment: .leading, spacing: 10) {
                            Text("椰子奖励")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.5))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(rewardOptions, id: \.self) { val in
                                        Button {
                                            reward = val
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text("🥥")
                                                    .font(.system(size: 16))
                                                Text("\(val)")
                                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                                    .foregroundStyle(reward == val ? .black : Color.goYellow)
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(
                                                reward == val ? Color.goLime : Color.goYellow.opacity(0.1),
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

                        // 发布人预览
                        if let human = creator {
                            HStack(spacing: 10) {
                                Text(human.avatarEmoji)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("发布人")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.3))
                                    Text(human.name)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Text("奖励 \(reward)🥥")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.primary.opacity(0.6))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发布") {
                        guard !title.isEmpty, let human = creator else { return }
                        let task = BountyTask(
                            title: title,
                            description: description,
                            reward: reward,
                            creatorId: human.id.uuidString,
                            creatorName: human.name,
                            creatorEmoji: human.avatarEmoji,
                            emoji: selectedEmoji
                        )
                        onAdd(task)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(title.isEmpty ? Color.goLime.opacity(0.3) : Color.goLime)
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func formField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
            content()
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.1), lineWidth: 1))
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
