//
//  PlantDashboardView.swift
//  Ohana
//
//  植物 Tab 主面板：展示植物卡片网格 + 快捷浇水/施肥 + 空态引导
//

import SwiftData
import SwiftUI

private enum PlantDashboardFilter: String, CaseIterable, Identifiable {
    case all
    case due
    case watching
    case indoor

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
        case .due: l.tr(zh: "7天任务", en: "7-day tasks", de: "7-Tage-Aufgaben")
        case .watching: l.tr(zh: "需观察", en: "Watch", de: "Beobachten")
        case .indoor: l.tr(zh: "室内", en: "Indoor", de: "Drinnen")
        }
    }
}

struct PlantDashboardView: View {
    let plants: [Plant]
    let onOpenPlant: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingAddPlant = false
    @State private var selectedFilter: PlantDashboardFilter = .all
    @State private var selectedLocation: String?

    init(
        plants: [Plant] = [],
        onOpenPlant: @escaping (UUID) -> Void = { _ in }
    ) {
        self.plants = plants
        self.onOpenPlant = onOpenPlant
    }

    private var l: L10n { L10n(appLanguage) }
    private var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }

    private var plantsNeedingWater: [Plant] {
        let ids = Set(dueTasks.filter { $0.careType == .watering }.map(\.plantID))
        return plants.filter { ids.contains($0.id) }
    }

    private var upcomingTasks: [PlantCareTaskSnapshot] {
        appServices.plantCarePlans.tasks(for: plants, days: 7)
    }

    private var dueTasks: [PlantCareTaskSnapshot] {
        upcomingTasks.filter { $0.daysUntilDue <= 0 }
    }

    private var locationOptions: [String] {
        let locations = plants
            .map { $0.location.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(locations)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var visiblePlants: [Plant] {
        let filtered: [Plant]
        switch selectedFilter {
        case .all:
            filtered = plants
        case .due:
            let ids = Set(upcomingTasks.map(\.plantID))
            filtered = plants.filter { ids.contains($0.id) }
        case .watching:
            filtered = plants.filter { $0.healthStatus == .watching || $0.healthStatus == .stressed }
        case .indoor:
            filtered = plants.filter(\.isIndoor)
        }
        guard let selectedLocation else { return filtered }
        return filtered.filter {
            $0.location.trimmingCharacters(in: .whitespacesAndNewlines) == selectedLocation
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Spacer().frame(height: 70)

            if plants.isEmpty {
                emptyState
            } else {
                VStack(spacing: 20) {
                    taskSummarySection
                    filterBar

                    if !plantsNeedingWater.isEmpty {
                        urgentSection
                    }

                    plantGrid

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showingAddPlant) {
            AddPlantDataContainer {
                showingAddPlant = false
            }
        }
        .accessibilityIdentifier("plant-dashboard-screen")
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var taskSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock") // a11y: allow decorative section glyph; heading names the task window.
                    .foregroundStyle(Color.goLime)
                    .accessibilityHidden(true)
                Text(l.tr(zh: "今日与未来 7 天", en: "Today and next 7 days", de: "Heute und die nächsten 7 Tage"))
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }

            if dueTasks.isEmpty {
                Text(l.tr(zh: "今天没有到期植物任务", en: "No plant tasks due today", de: "Heute keine fälligen Pflanzenaufgaben"))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(dueTasks.prefix(4)) { task in
                        taskRow(task)
                    }
                }
                HStack(spacing: 10) {
                    Button(l.tr(zh: "全部完成", en: "Complete all", de: "Alle erledigen")) {
                        completeDueTasks()
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.goLime, in: Capsule())
                    .accessibilityIdentifier("plant-dashboard-complete-all-due")

                    Button(l.tr(zh: "全部延后一天", en: "Defer all one day", de: "Alle um einen Tag verschieben")) {
                        deferDueTasksOneDay()
                    }
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
                    .accessibilityIdentifier("plant-dashboard-defer-all-due")
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlantDashboardFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title(l))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedFilter == filter ? Color.arkInk : Color.ohanaPrimaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter ? Color.goLime : Color.ohanaControlFill.opacity(0.62),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                if !locationOptions.isEmpty {
                    Menu {
                        Button(l.tr(zh: "全部位置", en: "All locations", de: "Alle Standorte")) {
                            selectedLocation = nil
                        }
                        ForEach(locationOptions, id: \.self) { location in
                            Button(location) {
                                selectedLocation = location
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.and.ellipse") // a11y: allow decorative menu icon; label text names the location filter.
                                .font(OhanaFont.adaptive(size: 11, weight: .bold))
                                .accessibilityHidden(true)
                            Text(selectedLocation ?? l.tr(zh: "位置", en: "Location", de: "Standort"))
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedLocation == nil ? Color.ohanaPrimaryText : Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedLocation == nil ? Color.ohanaControlFill.opacity(0.62) : Color.goLime,
                            in: Capsule()
                        )
                    }
                }
            }
        }
    }

    private func taskRow(_ task: PlantCareTaskSnapshot) -> some View {
        HStack(spacing: 10) {
            Text(task.careType.emoji)
                .font(OhanaFont.adaptive(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(task.subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                Text(task.explanation)
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                completeTask(task)
            } label: {
                Image(systemName: "checkmark") // a11y: allow decorative icon; button has explicit completion label.
                    .font(OhanaFont.adaptive(size: 12, weight: .bold))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goLime, in: Circle())
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(l.tr(zh: "完成\(task.careType.displayName)", en: "Complete \(task.careType.displayName)", de: "\(task.careType.displayName) erledigen"))
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            Text("🌱")
                .font(OhanaFont.adaptive(size: 72)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup

            Text(l.tr(zh: "还没有植物", en: "No plants yet", de: "Noch keine Pflanzen"))
                .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)

            Text(l.tr(
                zh: "添加你的第一棵植物，开始记录浇水和施肥",
                en: "Add your first plant and start tracking watering and fertilizing",
                de: "Füge deine erste Pflanze hinzu und tracke Gießen und Düngen"
            ))
            .font(OhanaFont.adaptive(size: 15, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Button {
                showingAddPlant = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                        .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-dashboard-empty-add-action")

            Spacer()
        }
    }

    // MARK: - Urgent Section

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(.cyan)
                Text(l.tr(zh: "需要浇水", en: "Needs watering", de: "Braucht Wasser"))
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    waterAll()
                } label: {
                    Text(l.tr(zh: "全部浇水", en: "Water all", de: "Alle gießen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plantsNeedingWater) { plant in
                        urgentPlantChip(plant)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func urgentPlantChip(_ plant: Plant) -> some View {
        HStack(spacing: 8) {
            Text(plant.avatarEmoji)
                .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                if let days = plant.daysSinceWatered {
                    Text(l.tr(
                        zh: "\(days)天未浇水",
                        en: "\(days)d overdue",
                        de: "\(days) T. überfällig"
                    ))
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(.red.opacity(0.8))
                }
            }
            Button {
                waterPlant(plant)
            } label: {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(.cyan, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    // MARK: - Plant Grid

    private var plantGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "我的植物", en: "My plants", de: "Meine Pflanzen"))
                    .font(OhanaFont.adaptive(size: 17, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(selectedFilter == .all && selectedLocation == nil ? "\(plants.count)" : "\(visiblePlants.count)/\(plants.count)")
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(visiblePlants) { plant in
                    plantCard(plant)
                }

                addPlantButton
            }
        }
    }

    private func plantCard(_ plant: Plant) -> some View {
        let nextTask = appServices.plantCarePlans.nextTask(for: plant)
        return Button {
            onOpenPlant(plant.id)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(nextTask?.careType == .watering && (nextTask?.daysUntilDue ?? 1) <= 0 ? Color.cyan.opacity(0.2) : .primary.opacity(0.08))
                        .frame(width: 56, height: 56)
                    Text(plant.avatarEmoji)
                        .font(OhanaFont.adaptive(size: 30)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }

                Text(plant.name)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)

                Text(plant.species)
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)

                statusBadge(for: plant)

                if let task = nextTask {
                    Text(task.daysUntilDue <= 0
                        ? l.tr(zh: "今天：\(task.careType.displayName)", en: "Today: \(task.careType.displayName)", de: "Heute: \(task.careType.displayName)")
                        : l.tr(zh: "\(task.daysUntilDue)天后：\(task.careType.displayName)", en: "In \(task.daysUntilDue)d: \(task.careType.displayName)", de: "In \(task.daysUntilDue) T.: \(task.careType.displayName)"))
                        .font(OhanaFont.adaptive(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-dashboard-card-\(plant.name)")
    }

    @ViewBuilder
    private func statusBadge(for plant: Plant) -> some View {
        let nextTask = appServices.plantCarePlans.nextTask(for: plant)
        if nextTask?.careType == .watering && (nextTask?.daysUntilDue ?? 1) <= 0 {
            HStack(spacing: 3) {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 8, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(l.tr(zh: "需浇水", en: "Water", de: "Gießen"))
                    .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.cyan, in: Capsule())
        } else if nextTask?.careType == .fertilizing && (nextTask?.daysUntilDue ?? 1) <= 0 {
            HStack(spacing: 3) {
                Image(systemName: "leaf.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 8, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(l.tr(zh: "需施肥", en: "Fertilize", de: "Düngen"))
                    .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.orange, in: Capsule())
        } else if let days = plant.daysSinceWatered {
            Text(l.tr(zh: "\(days)天前浇水", en: "\(days)d ago", de: "vor \(days) T."))
                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        } else {
            Text(l.tr(zh: "新植物", en: "New", de: "Neu"))
                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private var addPlantButton: some View {
        Button {
            showingAddPlant = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(.primary.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 22, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Text(l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)

                Text(" ")
                    .font(OhanaFont.adaptive(size: 10)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup

                Text(" ")
                    .font(OhanaFont.adaptive(size: 9)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .padding(.vertical, 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ohanaCardSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-dashboard-grid-add-action")
    }

    // MARK: - Actions

    private func waterPlant(_ plant: Plant) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let plantID = plant.id
        commandQueue.enqueue(.plantCare(plantID: plantID, action: PlantCareType.watering.rawValue)) {
            commandExecutor.recordPlantCare(.watering, plantID: plantID, executorId: currentExecutorId())
        }
    }

    private func waterAll() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        for plantID in plantsNeedingWater.map(\.id) {
            commandQueue.enqueue(.plantCare(plantID: plantID, action: PlantCareType.watering.rawValue)) {
                commandExecutor.recordPlantCare(.watering, plantID: plantID, executorId: currentExecutorId())
            }
        }
    }

    private func completeTask(_ task: PlantCareTaskSnapshot) {
        guard let plant = plants.first(where: { $0.id == task.plantID }) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.plantCare(plantID: plant.id, action: task.careType.rawValue)) {
            commandExecutor.recordPlantCare(task.careType, plant: plant, executorId: currentExecutorId())
        }
    }

    private func completeDueTasks() {
        for task in dueTasks {
            completeTask(task)
        }
    }

    private func deferDueTasksOneDay() {
        let duePlantIDs = Set(dueTasks.map(\.plantID))
        let duePlants = plants.filter { duePlantIDs.contains($0.id) }
        guard !duePlants.isEmpty else { return }

        commandQueue.enqueue(
            .command(
                "plants",
                "deferDueTasksOneDay",
                ["plantCount": String(duePlants.count)]
            )
        ) {
            commandExecutor.deferPlantDueTasksOneDay(
                plants: duePlants,
                executorId: currentExecutorId()
            )
        }
    }

    private func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }
}
