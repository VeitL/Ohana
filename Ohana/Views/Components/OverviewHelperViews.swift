//
//  OverviewHelperViews.swift
//  Ohana
//
//  Phase 59: 从 OverviewView.swift 提取的辅助视图组件
//

import SwiftUI
import SwiftData

// MARK: - Floating Dock Nav（iOS 26 Liquid Glass + GlassEffectContainer morphing）
struct FloatingDockNav: View {
    @Binding var selectedTab: Int
    let onHome: () -> Void
    let onPlant: () -> Void
    let onCalendar: () -> Void
    let onOasis: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @Namespace private var dockNamespace

    private var items: [(String, String, Int)] {
        let l = L10n(appLanguage)
        return [
            ("house.fill", l.tabHome, 0),
            ("camera.macro", l.tabPlant, 1),
            ("calendar", l.tabCalendar, 2),
            ("leaf.fill", l.tabOasis, 3),
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.2) { item in
                let idx = item.2
                let isSelected = selectedTab == idx
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = idx
                    }
                    switch idx {
                    case 0: onHome()
                    case 1: onPlant()
                    case 2: onCalendar()
                    default: onOasis()
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.0)
                            .font(.system(size: isSelected ? 22 : 20, weight: .bold))
                            .foregroundStyle(isSelected ? Color.goPrimary : (colorScheme == .light ? Color.black.opacity(0.55) : Color.primary.opacity(0.4)))
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedTab)
                        Circle()
                            .fill(isSelected ? Color.goPrimary : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .goGlassBackground(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 32)
    }
}

// MARK: - Compact Task Row
struct CompactTaskRow: View {
    let reminder: Reminder
    @Environment(\.modelContext) private var modelContext
    @State private var isDone = false

    var body: some View {
        HStack(spacing: 12) {
            Text(reminder.event?.emoji ?? "📌")
                .font(.system(size: 18))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.event?.title ?? "提醒")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isDone ? .white.opacity(0.3) : .white)
                    .strikethrough(isDone)
                HStack(spacing: 4) {
                    if let petName = reminder.event?.relatedEntityId {
                        Text("🐾 \(petName.prefix(8))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Text(reminder.scheduledAt, style: .time)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3)) { isDone.toggle() }
                let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                if isDone {
                    ReminderCompletionService.complete(reminder, by: activeHumanId, context: modelContext)
                    QuestManager.shared.addCoconuts(2, emoji: "✅", reason: reminder.event?.title ?? "完成待办")
                    CareLedgerService.recordCoconut(
                        delta: 2,
                        title: reminder.event?.title ?? "完成待办",
                        actorId: activeHumanId,
                        actorName: nil,
                        source: .economy,
                        context: modelContext
                    )
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    ReminderCompletionService.reopen(reminder, by: activeHumanId, context: modelContext)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(isDone ? Color.goTeal : .white.opacity(0.25), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.goTeal)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(isDone ? 0.03 : 0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isDone)
    }
}

// MARK: - Swipeable Reminder Card
struct SwipeableReminderCard: View {
    let reminder: Reminder
    @Environment(\.modelContext) private var modelContext

    @State private var dragX: CGFloat = 0
    @State private var isDismissed = false

    private var tiltAngle: Angle {
        .degrees(Double(max(-300, min(300, dragX))) / 300.0 * 8.0)
    }
    private var actionColor: Color {
        if dragX > 40 { return Color.goTeal }
        if dragX < -40 { return Color.goOrange }
        return .clear
    }

    var body: some View {
        ZStack {
            HStack {
                if dragX > 40 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Done")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 20)
                    Spacer()
                } else if dragX < -40 {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Skip")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.trailing, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(actionColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(min(1.0, Double(abs(dragX)) / 60.0))

            HStack(spacing: 12) {
                Text(reminder.event?.emoji ?? "📌")
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.event?.title ?? "提醒")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                    Text(reminder.scheduledAt, style: .time)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.arkInk.opacity(0.3))
            }
            .padding(14)
            .goCard(color: .white, cornerRadius: 16)
            .offset(x: dragX)
            .rotationEffect(tiltAngle, anchor: UnitPoint(x: 0.5, y: 1.0))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { val in
                        withAnimation(.interactiveSpring(response: 0.3)) {
                            dragX = val.translation.width
                        }
                    }
                    .onEnded { val in
                        let threshold: CGFloat = 90
                        if val.translation.width > threshold {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragX = 400
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                completeReminder()
                            }
                        } else if val.translation.width < -threshold {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragX = -400
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                dismissReminder()
                            }
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                dragX = 0
                            }
                        }
                    }
            )
        }
        .opacity(isDismissed ? 0 : 1)
        .frame(maxHeight: isDismissed ? 0 : .infinity)
        .animation(.spring(response: 0.35), value: isDismissed)
    }

    private func completeReminder() {
        isDismissed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            ReminderCompletionService.complete(reminder, by: activeHumanId, context: modelContext)
        }
    }

    private func dismissReminder() {
        isDismissed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            ReminderCompletionService.skip(reminder, by: activeHumanId, context: modelContext)
        }
    }
}

// MARK: - Plant Garden Card
struct PlantGardenCard: View {
    let plant: Plant
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isWatering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(plant.needsWatering ? Color.goPrimary.opacity(0.2) : .white.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Text(plant.avatarEmoji)
                        .font(.system(size: 32))
                        .scaleEffect(isWatering ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isWatering)
                }

                Text(plant.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if plant.needsWatering {
                    Button {
                        waterPlant()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("Water")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.goPrimary, in: Capsule())
                    }
                } else if let days = plant.daysSinceWatered {
                    Text("\(days)d ago")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    Text("No record")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 92)
            .padding(.vertical, 12)
            .goTranslucentCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }

    private func waterPlant() {
        isWatering = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        plant.lastWateredDate = Date()
        modelContext.safeSave()
        CareLedgerService.record(
            occurredAt: plant.lastWateredDate ?? Date(),
            actorKind: .human,
            actorId: UserDefaults.standard.string(forKey: "currentActiveHumanId"),
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: PlantCareType.watering.rawValue,
            source: .quickAction,
            context: modelContext
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isWatering = false
        }
    }
}

// MARK: - Home Section Manage Sheet
struct HomeSectionManageSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("home_section_order") private var sectionOrderRaw: String = "quickActions,batchCheckIn,memoryDrop,islandStats"
    @AppStorage("home_section_hidden") private var hiddenRaw: String = ""

    @State private var sections: [HomeSectionEntry] = []
    @State private var editMode: EditMode = .active

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            Color.goDeepNavy.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("首页模块管理")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("拖拽排序，切换显示/隐藏")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Button("完成") {
                        saveState()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.goPrimary.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                List {
                    ForEach($sections) { $section in
                        HStack(spacing: 14) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(width: 24)
                            Image(systemName: section.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: section.colorHex))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(section.subtitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.38))
                            }
                            Spacer()
                            Toggle("", isOn: $section.isVisible)
                                .tint(Color.goPrimary)
                                .labelsHidden()
                                .onChange(of: section.isVisible) { _, _ in saveState() }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.goDarkBlue.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                )
                                .padding(.vertical, 3)
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onMove { from, to in
                        sections.move(fromOffsets: from, toOffset: to)
                        saveState()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
            }
        }
        .onAppear { loadState() }
    }

    private func loadState() {
        var order = sectionOrderRaw.split(separator: ",").map(String.init)
        // Migrate legacy IDs → new split IDs
        let legacyGroup = ["quickAccess", "todayTasks", "todayActions"]
        if order.contains(where: { legacyGroup.contains($0) }) {
            let insertIdx = order.firstIndex(where: { legacyGroup.contains($0) }) ?? 0
            order.removeAll { legacyGroup.contains($0) }
            if !order.contains("batchCheckIn") { order.insert("batchCheckIn", at: min(insertIdx + 1, order.count)) }
            if !order.contains("quickActions") { order.insert("quickActions",  at: min(insertIdx,     order.count)) }
            sectionOrderRaw = order.joined(separator: ",")
        }
        // Also drop old batchCheckIn if it was already there separately (dedup)
        var seen = Set<String>()
        order = order.filter { seen.insert($0).inserted }
        let hidden = Set(hiddenRaw.split(separator: ",").map(String.init))
        let allSections = HomeSectionEntry.defaults
        var sorted: [HomeSectionEntry] = order.compactMap { id in allSections.first(where: { $0.id == id }) }
        for s in allSections where !sorted.contains(where: { $0.id == s.id }) { sorted.append(s) }
        sections = sorted.map { var s = $0; s.isVisible = !hidden.contains(s.id) && !hidden.contains("todayActions"); return s }
    }

    private func saveState() {
        sectionOrderRaw = sections.map(\.id).joined(separator: ",")
        hiddenRaw = sections.filter { !$0.isVisible }.map(\.id).joined(separator: ",")
    }
}

// MARK: - HomeSectionEntry
struct HomeSectionEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let colorHex: String
    var isVisible: Bool = true

    static let defaults: [HomeSectionEntry] = [
        HomeSectionEntry(id: "islandHeader",    title: "岛屿天气胶囊",  subtitle: "首页顶部 60pt 天气/情绪/负反馈汇总",       icon: "cloud.sun.fill",         colorHex: "FFD93D"),
        HomeSectionEntry(id: "familyStripMini", title: "家庭活动胶囊",  subtitle: "宠物卡下方 Mini 家人活动条，点击展开",     icon: "person.2.fill",          colorHex: "8E6DFF"),
        HomeSectionEntry(id: "todayFocus",      title: "今日聚焦",     subtitle: "智能推送当前最该做的事情（单卡）",          icon: "sparkles",               colorHex: "FF8C42"),
        HomeSectionEntry(id: "quickActions",    title: "快捷操作",     subtitle: "按宠物物种自定义的快捷打卡卡片网格",        icon: "bolt.fill",              colorHex: "FF8C42"),
        HomeSectionEntry(id: "batchCheckIn",    title: "一键打卡",     subtitle: "多宠物同时喂食/喂水，一键全员打卡",         icon: "checkmark.circle.fill",  colorHex: "34C759"),
        HomeSectionEntry(id: "memoryDrop",      title: "记忆碎片",     subtitle: "折叠到更多区 · 回忆片段",                icon: "heart.text.square.fill", colorHex: "FF6B9D"),
        HomeSectionEntry(id: "islandStats",     title: "岛屿统计",     subtitle: "折叠到更多区 · 体重/步数/花费/粮仓",      icon: "chart.bar.fill",         colorHex: "00D4AA"),
    ]
}

// MARK: - Bento Stat Card
struct BentoStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let trend: String?
    let trendUp: Bool?
    let accentColor: Color
    var showMiniBar: Int = 0
    var barMax: Int = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.metric(size: 32))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
            if showMiniBar > 0 || barMax > 0 && showMiniBar >= 0 {
                HStack(spacing: 3) {
                    ForEach(0..<min(7, barMax), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < showMiniBar ? accentColor : accentColor.opacity(0.18))
                            .frame(width: 6, height: i < showMiniBar ? 14 : 8)
                    }
                }
            }
            if let t = trend {
                HStack(spacing: 3) {
                    Image(systemName: (trendUp ?? true) ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(t)
                        .font(OhanaFont.caption2(.bold))
                }
                .foregroundStyle((trendUp ?? true) ? Color.goTeal : Color.goOrange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 130)
        .goGlassBackground(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - AllPetsFoodOverviewSheet
struct AllPetsFoodOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @State private var selectedPet: Pet? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(pets) { pet in
                            petFoodRow(pet)
                        }
                        if pets.isEmpty {
                            VStack(spacing: 12) {
                                Text("🐾").font(.system(size: 48))
                                Text("还没有宠物")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("粮仓总览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .sheet(item: $selectedPet) { pet in
            PetFoodManagementView(pet: pet)
        }
    }

    @ViewBuilder
    private func petFoodRow(_ pet: Pet) -> some View {
        let days = pet.remainingFoodDays
        let grams = pet.remainingFoodGrams
        let accent: Color = days <= 0 ? .goRed : days <= 7 ? .goOrange : .goTeal
        let progress = min(1.0, Double(days) / 30.0)

        Button { selectedPet = pet } label: {
            HStack(spacing: 14) {
                Group {
                    if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                    } else {
                        Text(pet.species == "cat" ? "🐱" : pet.species == "dog" ? "🐶" : "🐾")
                            .font(.system(size: 26))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(accent.opacity(0.5), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(days > 0 ? "余粮 \(grams)g · 可用 \(days) 天" : "余粮不足，请补充")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(accent)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(days)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
                .frame(width: 36, height: 36)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
