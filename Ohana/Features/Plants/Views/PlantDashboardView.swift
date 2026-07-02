//
//  PlantDashboardView.swift
//  Ohana
//
//  植物 Tab 主面板：展示植物卡片网格 + 快捷浇水/施肥 + 空态引导
//

import SwiftData
import SwiftUI
import UIKit

enum PlantDashboardEntryMode: String, Hashable {
    case sites
    case plants
    case photos
}

private enum PlantDashboardMode: String, CaseIterable, Identifiable {
    case sites
    case plants
    case photos

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .sites: l.tr(zh: "位置", en: "Sites", de: "Orte")
        case .plants: l.tr(zh: "植物", en: "Plants", de: "Pflanzen")
        case .photos: l.tr(zh: "照片", en: "Photos", de: "Fotos")
        }
    }

    init(entryMode: PlantDashboardEntryMode) {
        switch entryMode {
        case .sites:
            self = .sites
        case .plants:
            self = .plants
        case .photos:
            self = .photos
        }
    }
}

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

private struct PlantDashboardRoomSummary: Identifiable {
    let id: String
    let title: String
    let plants: [Plant]
    let plantCount: Int
    let dueTaskCount: Int
    let watchCount: Int
}

struct PlantDashboardPhotoItem: Identifiable {
    let id: String
    let plant: Plant
    let imageData: Data?
    let fallbackEmoji: String
    let title: String
    let subtitle: String
    let photoDate: Date?
    let tint: Color
}

private struct PlantDashboardReadinessItem: Identifiable {
    let id: String
    let plant: Plant
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let priority: Int
}

private struct PlantDashboardCareLogDraft: Identifiable {
    let plant: Plant
    let careType: PlantCareType

    var id: String { "\(plant.id.uuidString)-\(careType.rawValue)" }
}

struct PlantDashboardView: View {
    let plants: [Plant]
    let onOpenPlant: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""
    @AppStorage("ohana_onboarding_has_pets") private var onboardingHasPets = true
    @AppStorage("ohana_onboarding_has_children") private var onboardingHasChildren = false

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var showingAddPlant = false
    @State private var selectedDashboardMode: PlantDashboardMode = .sites
    @State private var selectedFilter: PlantDashboardFilter = .all
    @State private var selectedLocation: String?
    @State private var selectedSiteSummary: PlantDashboardRoomSummary?
    @State private var selectedDashboardPhoto: PlantDashboardPhotoItem?
    @State private var showingCarePlanSheet = false
    @State private var careLogDraft: PlantDashboardCareLogDraft?
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    init(
        plants: [Plant] = [],
        initialMode: PlantDashboardEntryMode = .sites,
        onOpenPlant: @escaping (UUID) -> Void = { _ in }
    ) {
        self.plants = plants
        self.onOpenPlant = onOpenPlant
        _selectedDashboardMode = State(initialValue: PlantDashboardMode(entryMode: initialMode))
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

    private var careWindowTasks: [PlantCareTaskSnapshot] {
        upcomingTasks
    }

    private var plantsNeedingCareCount: Int {
        Set(dueTasks.map(\.plantID)).count
    }

    private var watchedPlantsCount: Int {
        plants.count(where: { $0.healthStatus == .watching || $0.healthStatus == .stressed })
    }

    private var indoorPlantCount: Int {
        plants.filter(\.isIndoor).count
    }

    private var locationOptions: [String] {
        let locations = plants
            .map(locationFilterValue(for:))
            .filter { !$0.isEmpty }
        return Array(Set(locations)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchingPlants: Bool {
        !normalizedSearchText.isEmpty
    }

    private var isNarrowingPlants: Bool {
        selectedFilter != .all || selectedLocation != nil || isSearchingPlants
    }

    private var roomCareSummaries: [PlantDashboardRoomSummary] {
        Dictionary(grouping: plants, by: locationFilterValue(for:))
            .compactMap { location, roomPlants in
                let title = location.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }

                let roomPlantIDs = Set(roomPlants.map(\.id))
                let dueTaskCount = dueTasks.count { roomPlantIDs.contains($0.plantID) }
                let watchCount = roomPlants.count {
                    $0.healthStatus == .watching || $0.healthStatus == .stressed
                }

                return PlantDashboardRoomSummary(
                    id: title,
                    title: title,
                    plants: roomPlants.sorted { lhs, rhs in
                        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    },
                    plantCount: roomPlants.count,
                    dueTaskCount: dueTaskCount,
                    watchCount: watchCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.dueTaskCount != rhs.dueTaskCount {
                    return lhs.dueTaskCount > rhs.dueTaskCount
                }
                if lhs.watchCount != rhs.watchCount {
                    return lhs.watchCount > rhs.watchCount
                }
                if lhs.plantCount != rhs.plantCount {
                    return lhs.plantCount > rhs.plantCount
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
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
        let locationFiltered: [Plant] = if let selectedLocation {
            filtered.filter {
                locationFilterValue(for: $0) == selectedLocation
            }
        } else {
            filtered
        }
        guard isSearchingPlants else { return locationFiltered }
        let query = normalizedForPlantSearch(normalizedSearchText)
        return locationFiltered.filter {
            plantMatchesSearch($0, normalizedQuery: query)
        }
    }

    private var photoDashboardItems: [PlantDashboardPhotoItem] {
        plants.flatMap { plant -> [PlantDashboardPhotoItem] in
            var items: [PlantDashboardPhotoItem] = []

            if let avatarImageData = plant.avatarImageData {
                items.append(
                    PlantDashboardPhotoItem(
                        id: "\(plant.id.uuidString)-profile",
                        plant: plant,
                        imageData: avatarImageData,
                        fallbackEmoji: plant.avatarEmoji,
                        title: plant.name,
                        subtitle: locationSummary(for: plant),
                        photoDate: nil,
                        tint: siteTint(for: plant)
                    )
                )
            }

            let photoLogs = plant.careLogs
                .filter { $0.photoData != nil }
                .sorted { $0.date > $1.date }

            items += photoLogs.prefix(3).map { log in
                PlantDashboardPhotoItem(
                    id: "\(plant.id.uuidString)-log-\(log.id.uuidString)",
                    plant: plant,
                    imageData: log.photoData,
                    fallbackEmoji: plant.avatarEmoji,
                    title: plant.name,
                    subtitle: "\(log.careType.displayName) · \(shortDate(log.date))",
                    photoDate: log.date,
                    tint: careTint(for: log.careType)
                )
            }

            if items.isEmpty {
                items.append(
                    PlantDashboardPhotoItem(
                        id: "\(plant.id.uuidString)-fallback",
                        plant: plant,
                        imageData: nil,
                        fallbackEmoji: plant.avatarEmoji,
                        title: plant.name,
                        subtitle: locationSummary(for: plant),
                        photoDate: nil,
                        tint: siteTint(for: plant)
                    )
                )
            }

            return items.prefix(3).map(\.self)
        }
        .sorted { lhs, rhs in
            if (lhs.imageData != nil) != (rhs.imageData != nil) {
                return lhs.imageData != nil
            }
            switch (lhs.photoDate, rhs.photoDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate > rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private var profileReadinessItems: [PlantDashboardReadinessItem] {
        plants
            .compactMap(profileReadinessItem(for:))
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.plant.name.localizedStandardCompare(rhs.plant.name) == .orderedAscending
            }
    }

    private var dashboardLeadPlant: Plant? {
        plants.first { previewImageData(for: $0) != nil } ?? plants.first
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Spacer().frame(height: 70)

            if plants.isEmpty {
                emptyState
            } else {
                VStack(spacing: 18) {
                    dashboardOverviewCard
                    dashboardModePicker
                    dashboardModeContent

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
        .sheet(item: $selectedSiteSummary) { summary in
            PlantSiteDetailSheet(
                siteName: summary.title,
                plants: summary.plants,
                careTasks: careTasks(for: summary),
                onShowPlants: { showPlants(for: summary) },
                onOpenPlant: openPlantFromSite,
                onOpenCareLog: openCareLogFromSite
            )
        }
        .sheet(item: $selectedDashboardPhoto) { item in
            PlantDashboardPhotoDetailSheet(
                item: item,
                onOpenPlant: openPlantFromPhoto
            )
        }
        .sheet(isPresented: $showingCarePlanSheet) {
            PlantDashboardCarePlanSheet(
                plants: plants,
                careTasks: careWindowTasks,
                onOpenPlant: openPlantFromCarePlan,
                onOpenCareLog: openCareLogFromCarePlan,
                onCompleteDueTasks: completeDueTasks,
                onDeferDueTasks: deferDueTasksOneDay
            )
        }
        .sheet(item: $careLogDraft) { draft in
            PlantCareLogSheet(
                plant: draft.plant,
                initialCareType: draft.careType,
                currentHealthStatus: draft.plant.healthStatus
            ) { type, careNote, healthStatus, photoData in
                savePlantCareLog(for: draft.plant, type: type, careNote: careNote, photoData: photoData, healthStatus: healthStatus)
            }
        }
        .accessibilityIdentifier("plant-dashboard-screen")
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var dashboardOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                dashboardLibraryAvatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "我的植物", en: "My Plants", de: "Meine Pflanzen"))
                        .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(plantCollectionSummaryLine)
                        .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(dashboardStatusLine)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                dashboardActionCapsule
            }

            dashboardStatusRibbon
            dashboardQuickActionRail

            if let nextTask = upcomingTasks.first {
                nextCareStrip(nextTask)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-overview")
    }

    private var dashboardLibraryAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.ohanaCardSurface)
                .overlay {
                    Circle().strokeBorder(Color.ohanaCardStroke.opacity(0.7), lineWidth: 1)
                }

            if let plant = dashboardLeadPlant {
                PlantDashboardPhotoTile(
                    imageData: previewImageData(for: plant),
                    fallbackEmoji: plant.avatarEmoji,
                    tint: siteTint(for: plant)
                )
                .clipShape(Circle())
                .padding(4)
            } else {
                Image(systemName: "person.crop.circle.fill") // a11y: allow decorative empty library avatar; surrounding header labels the plant library.
                    .font(OhanaFont.adaptive(size: 36, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 82, height: 82)
        .accessibilityHidden(true)
        .accessibilityIdentifier("plant-dashboard-library-avatar")
    }

    private var dashboardActionCapsule: some View {
        HStack(spacing: 2) {
            dashboardHeaderIconButton(
                id: "search",
                icon: "magnifyingglass",
                tint: Color.ohanaPrimaryText,
                label: l.tr(zh: "搜索植物", en: "Search plants", de: "Pflanzen suchen")
            ) {
                selectedDashboardMode = .plants
                Task { @MainActor in
                    await OhanaFrameScheduler.waitAfterNextFrame()
                    searchFocused = true
                }
            }

            dashboardHeaderIconButton(
                id: "filters",
                icon: "line.3.horizontal.decrease",
                tint: Color.ohanaPrimaryText,
                label: l.tr(zh: "筛选植物", en: "Filter plants", de: "Pflanzen filtern"),
                action: openDashboardFilters
            )

            dashboardHeaderIconButton(
                id: "add",
                icon: "plus",
                tint: Color.arkInk,
                label: l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"),
                fill: Color.goLime
            ) {
                showingAddPlant = true
            }
        }
        .padding(4)
        .background(Color.ohanaCardSurface, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.ohanaCardStroke.opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-action-capsule")
    }

    private func dashboardHeaderIconButton(
        id: String,
        icon: String,
        tint: Color,
        label: String,
        fill: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon) // a11y: allow decorative header glyph; button label names the command.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 16, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(fill ?? Color.clear, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(id == "search" ? "plant-dashboard-open-search" : id == "filters" ? "plant-dashboard-open-filters" : "plant-dashboard-add-action")
    }

    private var dashboardStatusRibbon: some View {
        HStack(spacing: 8) {
            dashboardStatusChip(
                id: "tasks",
                icon: "calendar.badge.clock",
                title: dueTasks.isEmpty
                    ? l.tr(zh: "今日清爽", en: "Clear today", de: "Heute frei")
                    : l.tr(zh: "\(dueTasks.count) 项任务", en: "\(dueTasks.count) tasks", de: "\(dueTasks.count) Aufgaben"),
                tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow
            )

            dashboardStatusChip(
                id: "watch",
                icon: "eye.fill",
                title: watchedPlantsCount == 0
                    ? l.tr(zh: "状态稳定", en: "Stable", de: "Stabil")
                    : l.tr(zh: "\(watchedPlantsCount) 株观察", en: "\(watchedPlantsCount) watch", de: "\(watchedPlantsCount) beobachten"),
                tint: watchedPlantsCount == 0 ? Color.goLime : Color.goYellow
            )

            dashboardStatusChip(
                id: "sites",
                icon: "house.fill",
                title: l.tr(zh: "\(roomCareSummaries.count) 个位置", en: "\(roomCareSummaries.count) sites", de: "\(roomCareSummaries.count) Orte"),
                tint: Color.goTeal
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-status-ribbon")
    }

    private func dashboardStatusChip(id: String, icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 34)
        .padding(.horizontal, 8)
        .background(Color.ohanaCardSurface, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-status-chip-\(id)")
    }

    private var plantCollectionSummaryLine: String {
        l.tr(
            zh: "\(plants.count) 株植物 · \(roomCareSummaries.count) 个位置",
            en: "\(plants.count) plants · \(roomCareSummaries.count) sites",
            de: "\(plants.count) Pflanzen · \(roomCareSummaries.count) Orte"
        )
    }

    private var dashboardStatusLine: String {
        if !dueTasks.isEmpty {
            return l.tr(
                zh: "\(dueTasks.count) 项照护今天到期，先处理 \(plantsNeedingCareCount) 株植物",
                en: "\(dueTasks.count) care tasks due today across \(plantsNeedingCareCount) plants",
                de: "\(dueTasks.count) Pflegeaufgaben heute für \(plantsNeedingCareCount) Pflanzen"
            )
        }
        if let nextTask = upcomingTasks.first {
            return l.tr(
                zh: "下一项：\(nextTask.title)，\(dueText(for: nextTask))",
                en: "Next: \(nextTask.title), \(dueText(for: nextTask))",
                de: "Als Nächstes: \(nextTask.title), \(dueText(for: nextTask))"
            )
        }
        return l.tr(
            zh: "本周节奏稳定，适合补照片、观察新叶和整理档案",
            en: "This week is calm: add photos, watch new leaves, and tidy profiles",
            de: "Diese Woche ist ruhig: Fotos ergänzen, neue Blätter beobachten und Profile pflegen"
        )
    }

    private var dashboardModePicker: some View {
        HStack(spacing: 6) {
            ForEach(PlantDashboardMode.allCases) { mode in
                Button {
                    selectedDashboardMode = mode
                    if mode == .sites {
                        searchFocused = false
                    }
                } label: {
                    Text(mode.title(l))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(selectedDashboardMode == mode ? Color.arkInk : Color.ohanaSecondaryText)
                        .frame(minWidth: 86)
                        .frame(height: 44)
                        .background(
                            selectedDashboardMode == mode ? Color.goLime : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-dashboard-mode-\(mode.rawValue)")
            }
        }
        .padding(5)
        .background(Color.ohanaControlFill.opacity(0.76), in: Capsule())
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-mode-picker")
    }

    @ViewBuilder
    private var dashboardModeContent: some View {
        switch selectedDashboardMode {
        case .sites:
            sitesDashboardSection
        case .plants:
            plantsDashboardSection
        case .photos:
            photosDashboardSection
        }
    }

    private func dashboardMetric(
        icon: String,
        title: String,
        value: String,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24) // a11y: allow non-interactive metric glyph; metric text provides the accessible value.
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.adaptive(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaTertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(detail)")
    }

    private var dashboardQuickActionRail: some View {
        HStack(spacing: 8) {
            dashboardQuickActionButton(
                id: "care-plan",
                icon: "calendar.badge.clock",
                title: l.tr(zh: "护理计划", en: "Care plan", de: "Pflegeplan"),
                subtitle: dueTasks.isEmpty
                    ? l.tr(zh: "本周", en: "Week", de: "Woche")
                    : l.tr(zh: "\(dueTasks.count) 到期", en: "\(dueTasks.count) due", de: "\(dueTasks.count) fällig"),
                tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow,
                action: openDashboardCarePlan
            )

            dashboardQuickActionButton(
                id: "profile",
                icon: "checkmark.seal.fill",
                title: l.tr(zh: "档案待办", en: "Profiles", de: "Profile"),
                subtitle: profileReadinessItems.isEmpty
                    ? l.tr(zh: "完成", en: "Ready", de: "Bereit")
                    : l.tr(zh: "\(profileReadinessItems.count) 项", en: "\(profileReadinessItems.count) items", de: "\(profileReadinessItems.count) Punkte"),
                tint: profileReadinessItems.isEmpty ? Color.goLime : Color.goYellow,
                action: openDashboardProfileQueue
            )

            dashboardQuickActionButton(
                id: "photos",
                icon: "photo.stack.fill",
                title: l.tr(zh: "成长照片", en: "Photos", de: "Fotos"),
                subtitle: photoDashboardItems.isEmpty
                    ? l.tr(zh: "补照片", en: "Add", de: "Ergänzen")
                    : l.tr(zh: "\(photoDashboardItems.count) 张", en: "\(photoDashboardItems.count)", de: "\(photoDashboardItems.count)"),
                tint: photoDashboardItems.isEmpty ? Color.goYellow : Color.goTeal,
                action: openDashboardPhotos
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-quick-actions")
    }

    private func dashboardQuickActionButton(
        id: String,
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon) // a11y: allow decorative quick-action glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 74, alignment: .center)
            .padding(.horizontal, 10)
            .background(Color.ohanaControlFill.opacity(0.54), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityIdentifier("plant-dashboard-quick-action-\(id)")
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.ohanaControlFill.opacity(0.75))
            .frame(width: 1, height: 58)
            .padding(.horizontal, 10)
            .accessibilityHidden(true)
    }

    private func nextCareStrip(_ task: PlantCareTaskSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: careSymbol(for: task.careType))
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(careTint(for: task.careType))
                .frame(width: 30, height: 30) // a11y: allow non-interactive next-care glyph; adjacent text names the task.
                .background(careTint(for: task.careType).opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "下一项照护", en: "Next care", de: "Nächste Pflege"))
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                Text("\(task.title) · \(dueText(for: task))")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
        }
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.46), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var sitesDashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sitesModeHeader

            ForEach(roomCareSummaries) { summary in
                siteCard(summary)
            }

            if !profileReadinessItems.isEmpty {
                profileReadinessSection
            }

            if !careWindowTasks.isEmpty {
                taskSummarySection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-sites-view")
    }

    private var plantsDashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchAndFilterSection
            plantsModeBanner
            plantListSection

            if !profileReadinessItems.isEmpty {
                profileReadinessSection
            }

            if !locationOptions.isEmpty {
                roomCareMapSection
            }

            if !plantsNeedingWater.isEmpty {
                urgentSection
            }

            if !careWindowTasks.isEmpty {
                taskSummarySection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-plants-view")
    }

    private var sitesModeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "位置", en: "Sites", de: "Orte"))
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(l.tr(
                    zh: "按摆放空间查看植物和待办",
                    en: "Browse plants and care tasks by where they live",
                    de: "Pflanzen und Pflege nach Standort durchsuchen"
                ))
                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill") // a11y: allow decorative sites count glyph; adjacent text gives the count.
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .accessibilityHidden(true)
                Text(l.tr(zh: "\(roomCareSummaries.count) 个", en: "\(roomCareSummaries.count)", de: "\(roomCareSummaries.count)"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(Color.goLime, in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-sites-header")
    }

    private var plantsModeBanner: some View {
        Button {
            openDashboardCarePlan()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: dueTasks.isEmpty ? "checkmark.seal.fill" : "calendar.badge.clock")
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.arkInk.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plantsModeBannerTitle)
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(plantsModeBannerSubtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.76))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right") // a11y: allow decorative banner navigation glyph; the button has a full label.
                    .font(OhanaFont.adaptive(size: 17, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(dueTasks.isEmpty ? Color.goLime : Color.goYellow, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(plantsModeBannerTitle), \(plantsModeBannerSubtitle)")
        .accessibilityIdentifier("plant-dashboard-plants-banner")
    }

    private var plantsModeBannerTitle: String {
        dueTasks.isEmpty
            ? l.tr(zh: "今天没有到期护理", en: "No care due today", de: "Heute keine Pflege fällig")
            : l.tr(zh: "今天有 \(dueTasks.count) 项护理", en: "\(dueTasks.count) care tasks today", de: "\(dueTasks.count) Pflegeaufgaben heute")
    }

    private var plantsModeBannerSubtitle: String {
        if dueTasks.isEmpty {
            return l.tr(
                zh: "可以补照片、整理档案，或查看未来 7 天计划",
                en: "Add photos, tidy profiles, or review the 7-day plan",
                de: "Fotos ergänzen, Profile ordnen oder den 7-Tage-Plan prüfen"
            )
        }
        return l.tr(
            zh: "点这里打开护理计划，或在列表里逐株完成",
            en: "Open the care plan here or complete items from the list",
            de: "Plan hier öffnen oder Aufgaben in der Liste erledigen"
        )
    }

    private var photosDashboardSection: some View {
        let items = photoDashboardItems

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "照片", en: "Photos", de: "Fotos"))
                        .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "按最近档案照片和照护照片回看植物状态",
                        en: "Review profile and care photos across your plants",
                        de: "Profil- und Pflegefotos deiner Pflanzen prüfen"
                    ))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("\(items.count)")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 30)
                    .background(Color.goLime, in: Capsule())
            }

            photoJournalSummaryCard(items)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(items) { item in
                    photoDashboardCard(item)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-photos-view")
    }

    private func photoJournalSummaryCard(_ items: [PlantDashboardPhotoItem]) -> some View {
        let realPhotoItems = items.filter { $0.imageData != nil }
        let plantsWithPhotos = Set(realPhotoItems.map(\.plant.id)).count
        let missingPhotoPlants = plants.filter { previewImageData(for: $0) == nil }
        let latestPhoto = realPhotoItems.first

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "photo.stack.fill") // a11y: allow decorative photo journal glyph; heading names the summary.
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive summary glyph; text carries content.
                    .background(Color.goTeal.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "成长照片档案", en: "Growth photo journal", de: "Wachstumsfoto-Archiv"))
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(photoJournalSummaryText(realPhotoCount: realPhotoItems.count, missingCount: missingPhotoPlants.count))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                photoJournalMetric(
                    id: "real",
                    icon: "photo.fill",
                    title: l.tr(zh: "真实照片", en: "Real photos", de: "Echte Fotos"),
                    value: "\(realPhotoItems.count)",
                    tint: realPhotoItems.isEmpty ? Color.goYellow : Color.goTeal
                )
                photoJournalMetric(
                    id: "covered",
                    icon: "leaf.circle.fill",
                    title: l.tr(zh: "已覆盖", en: "Covered", de: "Erfasst"),
                    value: "\(plantsWithPhotos)/\(plants.count)",
                    tint: plantsWithPhotos == plants.count ? Color.goLime : Color.goYellow
                )
                photoJournalMetric(
                    id: "missing",
                    icon: "camera.badge.ellipsis",
                    title: l.tr(zh: "待补", en: "Missing", de: "Fehlt"),
                    value: "\(missingPhotoPlants.count)",
                    tint: missingPhotoPlants.isEmpty ? Color.goLime : Color.goYellow
                )
            }

            if let firstMissing = missingPhotoPlants.first {
                Button {
                    openCareLogSheet(for: firstMissing, type: .photo)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill") // a11y: allow decorative add-photo glyph; button text names the action.
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "给 \(firstMissing.name) 补照片", en: "Add photo for \(firstMissing.name)", de: "Foto für \(firstMissing.name) ergänzen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-dashboard-photo-log-missing")
            } else if let latestPhoto {
                Button {
                    selectedDashboardPhoto = latestPhoto
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath") // a11y: allow decorative latest-photo glyph; button text names the action.
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .accessibilityHidden(true)
                        Text(l.tr(zh: "查看最近照片", en: "Review latest photo", de: "Neuestes Foto ansehen"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("plant-dashboard-photo-open-latest")
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-photo-journal-summary")
    }

    private func photoJournalMetric(
        id: String,
        icon: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 68)
        .padding(10)
        .background(Color.ohanaControlFill.opacity(0.58), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plant-dashboard-photo-metric-\(id)")
    }

    private func photoJournalSummaryText(realPhotoCount: Int, missingCount: Int) -> String {
        if realPhotoCount == 0 {
            return l.tr(
                zh: "还没有真实照片，先为植物补一张档案照或护理照片。",
                en: "No real photos yet. Start with a profile or care photo.",
                de: "Noch keine echten Fotos. Beginne mit Profil- oder Pflegefoto."
            )
        }
        if missingCount > 0 {
            return l.tr(
                zh: "\(realPhotoCount) 张照片已沉淀，仍有 \(missingCount) 株植物缺少照片。",
                en: "\(realPhotoCount) photos saved; \(missingCount) plants still need photos.",
                de: "\(realPhotoCount) Fotos gespeichert; \(missingCount) Pflanzen brauchen noch Fotos."
            )
        }
        return l.tr(
            zh: "\(realPhotoCount) 张照片覆盖全部植物，可用于回看成长变化。",
            en: "\(realPhotoCount) photos cover every plant for growth review.",
            de: "\(realPhotoCount) Fotos decken alle Pflanzen für den Wachstumsrückblick ab."
        )
    }

    private func photoDashboardCard(_ item: PlantDashboardPhotoItem) -> some View {
        Button {
            selectedDashboardPhoto = item
        } label: {
            ZStack(alignment: .bottomLeading) {
                PlantDashboardPhotoTile(
                    imageData: item.imageData,
                    fallbackEmoji: item.fallbackEmoji,
                    tint: item.tint
                )
                .frame(maxWidth: .infinity)
                .frame(height: 168)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(item.subtitle)
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurface.opacity(0.86))
            }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(photoDashboardAccessibilityLabel(item))
        .accessibilityIdentifier("plant-dashboard-photo-card-\(item.id)")
    }

    private func siteCard(_ summary: PlantDashboardRoomSummary) -> some View {
        Button {
            selectedSiteSummary = summary
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                siteImageMosaic(for: summary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(summary.title)
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(l.tr(zh: "\(summary.plantCount) 株植物", en: "\(summary.plantCount) plants", de: "\(summary.plantCount) Pflanzen"))
                            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    siteTaskBadge(summary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(siteCardAccessibilityLabel(summary))
        .accessibilityIdentifier("plant-dashboard-site-card-\(roomZoneIdentifier(summary.id))")
    }

    @ViewBuilder
    private func siteImageMosaic(for summary: PlantDashboardRoomSummary) -> some View {
        let previewPlants = Array(summary.plants.prefix(4))
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
        if previewPlants.isEmpty {
            RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                .fill(Color.ohanaControlFill.opacity(0.7))
                .frame(height: 172)
                .accessibilityHidden(true)
        } else {
            HStack(spacing: 3) {
                PlantDashboardPhotoTile(
                    imageData: previewImageData(for: previewPlants[0]),
                    fallbackEmoji: previewPlants[0].avatarEmoji,
                    tint: siteTint(for: previewPlants[0])
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if previewPlants.count > 1 {
                    VStack(spacing: 3) {
                        PlantDashboardPhotoTile(
                            imageData: previewImageData(for: previewPlants[1]),
                            fallbackEmoji: previewPlants[1].avatarEmoji,
                            tint: siteTint(for: previewPlants[1])
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if previewPlants.count > 2 {
                            PlantDashboardPhotoTile(
                                imageData: previewImageData(for: previewPlants[2]),
                                fallbackEmoji: previewPlants[2].avatarEmoji,
                                tint: siteTint(for: previewPlants[2])
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if previewPlants.count > 3 {
                    PlantDashboardPhotoTile(
                        imageData: previewImageData(for: previewPlants[3]),
                        fallbackEmoji: previewPlants[3].avatarEmoji,
                        tint: siteTint(for: previewPlants[3])
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 172)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.ohanaCardStroke.opacity(0.55), lineWidth: 1)
            }
            .accessibilityHidden(true)
        }
    }

    private func siteTaskBadge(_ summary: PlantDashboardRoomSummary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: summary.dueTaskCount == 0 ? "checkmark.circle.fill" : "calendar.badge.clock")
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .accessibilityHidden(true)
            Text(summary.dueTaskCount == 0
                ? l.tr(zh: "无任务", en: "clear", de: "frei")
                : l.tr(zh: "\(summary.dueTaskCount) 任务", en: "\(summary.dueTaskCount) tasks", de: "\(summary.dueTaskCount) Aufgaben"))
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(summary.dueTaskCount == 0 ? Color.goTeal : Color.goRed)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(Color.ohanaControlFill.opacity(0.76), in: Capsule())
    }

    private var plantListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "植物", en: "Plants", de: "Pflanzen"))
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text(isNarrowingPlants ? "\(visiblePlants.count)/\(plants.count)" : "\(plants.count)")
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            if visiblePlants.isEmpty {
                plantSearchEmptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(visiblePlants) { plant in
                        plantListRow(plant)
                    }

                    addPlantListButton
                }
            }
        }
    }

    private func plantListRow(_ plant: Plant) -> some View {
        let nextTask = appServices.plantCarePlans.nextTask(for: plant)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    onOpenPlant(plant.id)
                } label: {
                    HStack(spacing: 14) {
                        PlantDashboardPhotoTile(
                            imageData: previewImageData(for: plant),
                            fallbackEmoji: plant.avatarEmoji,
                            tint: cardAccentColor(for: plant, nextTask: nextTask)
                        )
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(Color.ohanaCardStroke.opacity(0.6), lineWidth: 1)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(plant.name)
                                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Text(locationSummary(for: plant))
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .lineLimit(1)
                            plantListBadges(for: plant, nextTask: nextTask)
                            Text(plantListCarePlanSummary(for: plant, nextTask: nextTask))
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaTertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.right") // a11y: allow decorative row navigation glyph; the row button has a full plant label.
                            .font(OhanaFont.adaptive(size: 18, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(plantCardAccessibilityLabel(for: plant, nextTask: nextTask))
                .accessibilityIdentifier("plant-dashboard-plant-open-\(plant.id.uuidString)")

                Button {
                    openCareLogSheet(for: plant, type: nextTask?.careType ?? .watering)
                } label: {
                    Image(systemName: nextTask.map { careSymbol(for: $0.careType) } ?? "drop.fill") // a11y: allow decorative quick-care glyph; label names the action.
                        .font(OhanaFont.adaptive(size: 13, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 44, height: 44)
                        .background(cardAccentColor(for: plant, nextTask: nextTask), in: Circle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(plantListQuickCareAccessibilityLabel(for: plant, nextTask: nextTask))
                .accessibilityIdentifier("plant-dashboard-plant-quick-care-\(plant.id.uuidString)")
            }
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.ohanaCardStroke.opacity(0.72))
                .frame(height: 1)
                .padding(.leading, 78)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-plant-row-\(plant.name)")
    }

    private func plantListMetricPill(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text(value)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(Color.ohanaControlFill.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func plantListBadges(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> some View {
        let profilePercent = plantProfileCompletionPercent(for: plant)
        return HStack(spacing: 6) {
            if let nextTask, nextTask.daysUntilDue <= 0 {
                plantListBadge(
                    icon: careSymbol(for: nextTask.careType),
                    text: nextTask.careType.displayName,
                    tint: careTint(for: nextTask.careType)
                )
            }

            if plant.healthStatus == .watching || plant.healthStatus == .stressed {
                plantListBadge(
                    icon: plant.healthStatus == .stressed ? "exclamationmark.triangle.fill" : "eye.fill",
                    text: plant.healthStatus.displayName,
                    tint: plant.healthStatus == .stressed ? Color.goRed : Color.goYellow
                )
            }

            plantListBadge(
                icon: "info.circle.fill",
                text: "\(plantCareScore(for: plant))%",
                tint: plant.healthStatus == .stressed ? Color.goRed : Color.goLime
            )

            plantListBadge(
                icon: "checkmark.seal.fill",
                text: "\(profilePercent)%",
                tint: profilePercent >= 80 ? Color.goLime : Color.goYellow
            )
        }
        .lineLimit(1)
    }

    private func plantListBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 28)
        .background(Color.ohanaControlFill.opacity(0.72), in: Capsule())
    }

    private func plantListCarePlanSummary(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> String {
        if let nextTask {
            return [
                nextTask.title,
                dueText(for: nextTask),
                nextTask.subtitle
            ].joined(separator: " · ")
        }

        if plant.careLogs.isEmpty {
            return l.tr(
                zh: "还没有护理记录，先完成一次浇水或观察。",
                en: "No care log yet. Start with watering or a small observation.",
                de: "Noch kein Pflegeeintrag. Beginne mit Gießen oder einer Beobachtung."
            )
        }

        return l.tr(
            zh: "当前没有 7 天内任务，可以补照片或整理档案。",
            en: "No task in the 7-day window. Add a photo or tidy the profile.",
            de: "Keine Aufgabe im 7-Tage-Fenster. Foto ergänzen oder Profil ordnen."
        )
    }

    private func plantListQuickCareAccessibilityLabel(
        for plant: Plant,
        nextTask: PlantCareTaskSnapshot?
    ) -> String {
        if let nextTask {
            return l.tr(
                zh: "完成\(plant.name)的\(nextTask.careType.displayName)",
                en: "Complete \(nextTask.careType.displayName) for \(plant.name)",
                de: "\(nextTask.careType.displayName) für \(plant.name) erledigen"
            )
        }
        return l.tr(
            zh: "记录\(plant.name)的一次浇水",
            en: "Log watering for \(plant.name)",
            de: "Gießen für \(plant.name) erfassen"
        )
    }

    private func plantProfileCompletionPercent(for plant: Plant) -> Int {
        let total = 5
        var completed = 0
        if !plant.species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completed += 1
        }
        if !plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !plant.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completed += 1
        }
        if plant.potDiameterCm > 0 || !plant.soilType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completed += 1
        }
        if PlantCatalog.entry(id: plant.catalogSpeciesId) != nil {
            completed += 1
        }
        if !plant.careLogs.isEmpty {
            completed += 1
        }
        return Int((Double(completed) / Double(total) * 100).rounded())
    }

    private var profileReadinessSection: some View {
        let items = Array(profileReadinessItems.prefix(4))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checklist.checked") // a11y: allow decorative section glyph; heading names the checklist.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goLime)
                    .frame(width: 28, height: 28) // a11y: allow non-interactive section glyph; heading names the checklist.
                    .background(Color.goLime.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "档案待办", en: "Profile queue", de: "Profil-Queue"))
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "像成员档案一样补齐关键信息，让护理计划更可靠。",
                        en: "Complete key facts like a household profile so care plans stay reliable.",
                        de: "Ergänze Kerndaten wie bei Haushaltsprofilen, damit Pflegepläne verlässlich bleiben."
                    ))
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("\(profileReadinessItems.count)")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Color.goLime, in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    profileReadinessRow(item)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-profile-readiness")
    }

    private func profileReadinessRow(_ item: PlantDashboardReadinessItem) -> some View {
        Button {
            onOpenPlant(item.plant.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon) // a11y: allow decorative row glyph; row text describes the action.
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .foregroundStyle(item.tint)
                    .frame(width: 34, height: 34) // a11y: allow non-interactive row glyph; the whole row button has a full label.
                    .background(item.tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.plant.name)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(item.title)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(item.detail)
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right") // a11y: allow decorative row navigation glyph; the row button has a full plant label.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(Color.ohanaControlFill.opacity(0.56), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(profileReadinessAccessibilityLabel(item))
        .accessibilityIdentifier("plant-dashboard-profile-readiness-row-\(item.id)")
    }

    private var addPlantListButton: some View {
        Button {
            showingAddPlant = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus") // a11y: allow decorative add glyph; button text names the action.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goLime, in: Circle())
                    .accessibilityHidden(true)
                Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }
            .padding(10)
            .background(Color.ohanaCardSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("plant-dashboard-list-add-action")
    }

    private var roomCareMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "house.and.flag.fill") // a11y: allow decorative section glyph; heading names the room map.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "家中植物分区", en: "Home plant zones", de: "Pflanzenzonen zuhause"))
                        .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(roomCareMapSubtitle)
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    allRoomZoneButton

                    ForEach(roomCareSummaries.prefix(6)) { summary in
                        roomZoneButton(summary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-room-map")
    }

    private var roomCareMapSubtitle: String {
        if let selectedLocation {
            return l.tr(
                zh: "正在查看 \(selectedLocation) 的植物和到期照护",
                en: "Viewing plants and due care in \(selectedLocation)",
                de: "Pflanzen und fällige Pflege in \(selectedLocation)"
            )
        }
        if !dueTasks.isEmpty {
            return l.tr(
                zh: "按房间先处理到期和需观察的植物",
                en: "Work through due care and watch items room by room",
                de: "Fällige Pflege und Beobachtung Raum für Raum erledigen"
            )
        }
        return l.tr(
            zh: "按摆放位置快速查看每个空间的植物状态",
            en: "Scan each room by where plants live",
            de: "Jeden Raum nach Pflanzenstandort prüfen"
        )
    }

    private var allRoomZoneButton: some View {
        let isSelected = selectedLocation == nil
        return Button {
            selectedLocation = nil
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "square.grid.2x2.fill")
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.goTeal)
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    Text("\(plants.count)")
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .lineLimit(1)
                }

                Text(l.tr(zh: "全部区域", en: "All zones", de: "Alle Zonen"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    roomZoneStatusChip(
                        icon: "calendar.badge.clock",
                        text: dueTasks.isEmpty
                            ? l.tr(zh: "无到期", en: "clear", de: "frei")
                            : l.tr(zh: "\(dueTasks.count) 到期", en: "\(dueTasks.count) due", de: "\(dueTasks.count) fällig"),
                        tint: dueTasks.isEmpty ? Color.goTeal : Color.goYellow,
                        isSelected: isSelected
                    )
                    if watchedPlantsCount > 0 {
                        roomZoneStatusChip(
                            icon: "eye.fill",
                            text: "\(watchedPlantsCount)",
                            tint: Color.goYellow,
                            isSelected: isSelected
                        )
                    }
                }
            }
            .frame(width: 142, alignment: .topLeading)
            .frame(minHeight: 106, alignment: .topLeading)
            .padding(12)
            .background(
                isSelected ? Color.goLime : Color.ohanaControlFill.opacity(0.6),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(allRoomZoneAccessibilityLabel(isSelected: isSelected))
        .accessibilityIdentifier("plant-dashboard-room-zone-all")
    }

    private func roomZoneButton(_ summary: PlantDashboardRoomSummary) -> some View {
        let isSelected = selectedLocation == summary.id
        return Button {
            selectedLocation = isSelected ? nil : summary.id
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "house.fill")
                        .font(OhanaFont.adaptive(size: 14, weight: .black))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.goTeal)
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    Text("\(summary.plantCount)")
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                        .lineLimit(1)
                }

                Text(summary.title)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 6) {
                    roomZoneStatusChip(
                        icon: "calendar.badge.clock",
                        text: summary.dueTaskCount == 0
                            ? l.tr(zh: "无到期", en: "clear", de: "frei")
                            : l.tr(zh: "\(summary.dueTaskCount) 到期", en: "\(summary.dueTaskCount) due", de: "\(summary.dueTaskCount) fällig"),
                        tint: summary.dueTaskCount == 0 ? Color.goTeal : Color.goYellow,
                        isSelected: isSelected
                    )
                    if summary.watchCount > 0 {
                        roomZoneStatusChip(
                            icon: "eye.fill",
                            text: "\(summary.watchCount)",
                            tint: Color.goYellow,
                            isSelected: isSelected
                        )
                    }
                }
            }
            .frame(width: 142, alignment: .topLeading)
            .frame(minHeight: 106, alignment: .topLeading)
            .padding(12)
            .background(
                isSelected ? Color.goLime : Color.ohanaControlFill.opacity(0.6),
                in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(roomZoneAccessibilityLabel(summary, isSelected: isSelected))
        .accessibilityIdentifier("plant-dashboard-room-zone-\(roomZoneIdentifier(summary.id))")
    }

    private func roomZoneStatusChip(
        icon: String,
        text: String,
        tint: Color,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(isSelected ? Color.arkInk : tint)
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            isSelected ? Color.arkInk.opacity(0.09) : Color.ohanaCardSurface.opacity(0.78),
            in: Capsule()
        )
    }

    private func allRoomZoneAccessibilityLabel(isSelected: Bool) -> String {
        [
            l.tr(zh: "全部区域", en: "All zones", de: "Alle Zonen"),
            l.tr(zh: "\(plants.count) 株植物", en: "\(plants.count) plants", de: "\(plants.count) Pflanzen"),
            l.tr(zh: "\(dueTasks.count) 项到期", en: "\(dueTasks.count) due tasks", de: "\(dueTasks.count) fällige Aufgaben"),
            l.tr(zh: "\(watchedPlantsCount) 株需观察", en: "\(watchedPlantsCount) watch items", de: "\(watchedPlantsCount) Beobachtungen"),
            isSelected
                ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt")
                : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        ].joined(separator: ", ")
    }

    private func roomZoneAccessibilityLabel(
        _ summary: PlantDashboardRoomSummary,
        isSelected: Bool
    ) -> String {
        [
            summary.title,
            l.tr(zh: "\(summary.plantCount) 株植物", en: "\(summary.plantCount) plants", de: "\(summary.plantCount) Pflanzen"),
            l.tr(zh: "\(summary.dueTaskCount) 项到期", en: "\(summary.dueTaskCount) due tasks", de: "\(summary.dueTaskCount) fällige Aufgaben"),
            l.tr(zh: "\(summary.watchCount) 株需观察", en: "\(summary.watchCount) watch items", de: "\(summary.watchCount) Beobachtungen"),
            isSelected
                ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt")
                : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        ].joined(separator: ", ")
    }

    private func roomZoneIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "unknown"
            : value
    }

    private func siteCardAccessibilityLabel(_ summary: PlantDashboardRoomSummary) -> String {
        [
            summary.title,
            l.tr(zh: "\(summary.plantCount) 株植物", en: "\(summary.plantCount) plants", de: "\(summary.plantCount) Pflanzen"),
            l.tr(zh: "\(summary.dueTaskCount) 项任务", en: "\(summary.dueTaskCount) tasks", de: "\(summary.dueTaskCount) Aufgaben"),
            l.tr(zh: "\(summary.watchCount) 株需观察", en: "\(summary.watchCount) watch items", de: "\(summary.watchCount) Beobachtungen"),
            l.tr(zh: "打开位置详情", en: "Open site detail", de: "Standortdetails öffnen")
        ].joined(separator: ", ")
    }

    private func careTasks(for summary: PlantDashboardRoomSummary) -> [PlantCareTaskSnapshot] {
        let plantIDs = Set(summary.plants.map(\.id))
        return careWindowTasks.filter { plantIDs.contains($0.plantID) }
    }

    private func photoDashboardAccessibilityLabel(_ item: PlantDashboardPhotoItem) -> String {
        [
            item.title,
            item.subtitle,
            locationSummary(for: item.plant)
        ].joined(separator: ", ")
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

                if !careWindowTasks.isEmpty {
                    Button {
                        showingCarePlanSheet = true
                    } label: {
                        Text(l.tr(zh: "全部", en: "All", de: "Alle"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 34)
                            .background(Color.goLime, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "查看全部植物护理计划", en: "View all plant care plans", de: "Alle Pflanzenpflegepläne anzeigen"))
                    .accessibilityIdentifier("plant-dashboard-care-plan-open")
                }
            }

            if careWindowTasks.isEmpty {
                Text(l.tr(
                    zh: "未来 7 天没有植物任务，适合补照片或整理档案",
                    en: "No plant tasks in the next 7 days. Add photos or tidy profiles.",
                    de: "Keine Pflanzenaufgaben in den nächsten 7 Tagen. Fotos oder Profile ergänzen."
                ))
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(careWindowTasks.prefix(4)) { task in
                        taskRow(task)
                    }
                }

                if dueTasks.isEmpty {
                    Text(l.tr(
                        zh: "今天没有到期任务，以上是本周护理节奏。",
                        en: "Nothing is due today. This is the care rhythm for the week.",
                        de: "Heute ist nichts fällig. Das ist der Pflegerhythmus der Woche."
                    ))
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }

                if !dueTasks.isEmpty {
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
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityIdentifier("plant-dashboard-task-summary")
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
        .accessibilityIdentifier("plant-dashboard-filter-bar")
    }

    private func taskRow(_ task: PlantCareTaskSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: careSymbol(for: task.careType))
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(careTint(for: task.careType))
                .frame(width: 34, height: 34) // a11y: allow non-interactive care glyph; completion button is the hit target.
                .background(careTint(for: task.careType).opacity(0.16), in: Circle())
                .accessibilityHidden(true)
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

    private var searchAndFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            filterBar
        }
        .accessibilityIdentifier("plant-dashboard-search-filter")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass") // a11y: allow decorative search glyph; the text field carries the accessible label.
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(searchFocused ? Color.goTeal : Color.ohanaSecondaryText)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            TextField( // ui-v4: allow dashboard search input; it is locally styled and covered by input responsiveness tests.
                l.tr(
                    zh: "搜索植物、品种、房间",
                    en: "Search plants, species, rooms",
                    de: "Pflanzen, Arten, Räume suchen"
                ),
                text: $searchText
            )
            .focused($searchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .accessibilityLabel(l.tr(zh: "搜索植物", en: "Search plants", de: "Pflanzen suchen"))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill") // a11y: allow decorative clear glyph; button label names the action.
                        .font(OhanaFont.adaptive(size: 16, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "清空植物搜索", en: "Clear plant search", de: "Pflanzensuche leeren"))
                .accessibilityIdentifier("plant-dashboard-search-clear")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, searchText.isEmpty ? 14 : 2)
        .frame(minHeight: 52)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(searchFocused ? Color.goTeal.opacity(0.52) : Color.ohanaCardStroke, lineWidth: searchFocused ? 1.5 : 1)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-search-field")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            Image(systemName: "leaf.circle.fill") // a11y: allow decorative empty-state glyph; following title describes the state.
                .accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 72, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goTeal)

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
                    .foregroundStyle(Color.goTeal)
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
                    .foregroundStyle(Color.goRed)
                }
            }
            Button {
                waterPlant(plant)
            } label: {
                Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(Color.goTeal, in: Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "给\(plant.name)浇水", en: "Water \(plant.name)", de: "\(plant.name) gießen"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    // MARK: - Search Empty State

    private var plantSearchEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isSearchingPlants ? "magnifyingglass.circle.fill" : "line.3.horizontal.decrease.circle.fill") // a11y: allow decorative empty-search glyph; adjacent text states the result.
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(Color.goTeal)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSearchingPlants
                        ? l.tr(zh: "没有匹配的植物", en: "No matching plants", de: "Keine passenden Pflanzen")
                        : l.tr(zh: "当前筛选没有植物", en: "No plants in this filter", de: "Keine Pflanzen in diesem Filter"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isSearchingPlants
                        ? l.tr(zh: "换个名字、品种或房间试试", en: "Try another name, species, or room", de: "Anderen Namen, Art oder Raum versuchen")
                        : l.tr(zh: "清空筛选即可回到完整植物列表", en: "Clear filters to return to the full plant list", de: "Filter leeren, um alle Pflanzen zu sehen"))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(2)
                }
            }

            Button {
                clearPlantSearchAndFilters()
            } label: {
                Text(l.tr(zh: "显示全部植物", en: "Show all plants", de: "Alle Pflanzen anzeigen"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.goLime, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("plant-dashboard-search-reset")
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plant-dashboard-search-empty")
    }

    private func locationFilterValue(for plant: Plant) -> String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty {
            return room
        }
        return plant.isIndoor
            ? l.tr(zh: "未设置室内位置", en: "Unassigned indoor", de: "Innen ohne Ort")
            : l.tr(zh: "未设置户外位置", en: "Unassigned outdoor", de: "Außen ohne Ort")
    }

    private func plantMatchesSearch(_ plant: Plant, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        let catalogEntry = PlantCatalog.entry(id: plant.catalogSpeciesId)
        let searchableParts = [
            plant.name,
            plant.species,
            plant.roomName,
            plant.location,
            plant.notes,
            plant.soilType,
            plant.potMaterial,
            plant.acquisitionSource,
            plant.healthStatus.displayName,
            plant.lightLevel.displayName,
            catalogEntry?.localizedCommonName,
            catalogEntry?.latinName,
            catalogEntry?.localizedCareDifficulty,
            catalogEntry?.localizedSoil,
            catalogEntry?.localizedWateringPreference
        ]
        .compactMap(\.self)
        + (catalogEntry?.aliases ?? [])

        return searchableParts.contains {
            normalizedForPlantSearch($0).contains(normalizedQuery)
        }
    }

    private func profileReadinessItem(for plant: Plant) -> PlantDashboardReadinessItem? {
        let plantID = plant.id.uuidString
        if needsSafetyReview(plant) {
            return PlantDashboardReadinessItem(
                id: "\(plantID)-safety",
                plant: plant,
                title: l.tr(zh: "复核安全位置", en: "Review safe placement", de: "Sicheren Standort prüfen"),
                detail: l.tr(
                    zh: "这株植物有宠物/儿童/室内适配风险，先确认摆放位置。",
                    en: "This plant has pet, child, or indoor suitability notes. Check placement first.",
                    de: "Diese Pflanze hat Hinweise für Tiere, Kinder oder Innenräume. Standort zuerst prüfen."
                ),
                icon: "shield.checkered",
                tint: Color.goYellow,
                priority: 0
            )
        }

        if plant.catalogSpeciesId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            plant.species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PlantDashboardReadinessItem(
                id: "\(plantID)-catalog",
                plant: plant,
                title: l.tr(zh: "补齐品种/资料库", en: "Add species or catalog match", de: "Art oder Katalog ergänzen"),
                detail: l.tr(
                    zh: "匹配资料库后，浇水、施肥和安全提示会更准确。",
                    en: "A catalog match improves watering, fertilizing, and safety guidance.",
                    de: "Ein Katalogtreffer verbessert Gießen, Düngen und Sicherheit."
                ),
                icon: "books.vertical.fill",
                tint: Color.goLime,
                priority: 1
            )
        }

        if plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           plant.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PlantDashboardReadinessItem(
                id: "\(plantID)-location",
                plant: plant,
                title: l.tr(zh: "补齐摆放位置", en: "Add placement", de: "Standort ergänzen"),
                detail: l.tr(
                    zh: "房间和具体位置会帮助按区域处理照护任务。",
                    en: "Room and exact spot help organize care by site.",
                    de: "Raum und genauer Standort ordnen Pflege nach Bereich."
                ),
                icon: "mappin.and.ellipse",
                tint: Color.goTeal,
                priority: 2
            )
        }

        if plant.potDiameterCm == 0,
           plant.soilType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PlantDashboardReadinessItem(
                id: "\(plantID)-potting",
                plant: plant,
                title: l.tr(zh: "补齐盆土信息", en: "Add pot and soil", de: "Topf und Erde ergänzen"),
                detail: l.tr(
                    zh: "盆径、排水和土壤会影响浇水节奏。",
                    en: "Pot size, drainage, and soil affect watering rhythm.",
                    de: "Topfgröße, Abzug und Erde beeinflussen den Gießrhythmus."
                ),
                icon: "shippingbox.fill",
                tint: Color.goYellow,
                priority: 3
            )
        }

        if previewImageData(for: plant) == nil {
            return PlantDashboardReadinessItem(
                id: "\(plantID)-photo",
                plant: plant,
                title: l.tr(zh: "补第一张照片", en: "Add first photo", de: "Erstes Foto ergänzen"),
                detail: l.tr(
                    zh: "有照片后，位置和照片视图会更像真实植物档案。",
                    en: "Photos make Sites and Photos views feel like a real plant record.",
                    de: "Fotos machen Bereiche und Galerie zu einer echten Pflanzenakte."
                ),
                icon: "photo.fill",
                tint: Color.goTeal,
                priority: 4
            )
        }

        if plant.careLogs.isEmpty {
            return PlantDashboardReadinessItem(
                id: "\(plantID)-first-log",
                plant: plant,
                title: l.tr(zh: "记录首次照护", en: "Log first care", de: "Erste Pflege erfassen"),
                detail: l.tr(
                    zh: "第一条记录会启动成长时间线和本地护理节奏。",
                    en: "The first log starts the timeline and local care rhythm.",
                    de: "Der erste Eintrag startet Zeitachse und Pflegerhythmus."
                ),
                icon: "clock.badge.checkmark.fill",
                tint: Color.goLime,
                priority: 5
            )
        }

        return nil
    }

    private func needsSafetyReview(_ plant: Plant) -> Bool {
        (onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs)) ||
            (onboardingHasChildren && plant.isToxicToChildren) ||
            !plant.isIndoorSuitable
    }

    private func profileReadinessAccessibilityLabel(_ item: PlantDashboardReadinessItem) -> String {
        [
            item.plant.name,
            item.title,
            item.detail,
            l.tr(zh: "打开植物详情", en: "Open plant detail", de: "Pflanzendetails öffnen")
        ].joined(separator: ", ")
    }

    private func normalizedForPlantSearch(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    private func locationSummary(for plant: Plant) -> String {
        locationFilterValue(for: plant)
    }

    private func previewImageData(for plant: Plant) -> Data? {
        plant.avatarImageData ?? plant.careLogs
            .sorted { $0.date > $1.date }
            .first { $0.photoData != nil }?
            .photoData
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func siteTint(for plant: Plant) -> Color {
        let trimmed = plant.themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Color.goTeal : Color(hex: trimmed)
    }

    private func plantCareScore(for plant: Plant) -> Int {
        switch plant.healthStatus {
        case .thriving:
            92
        case .stable:
            78
        case .watching:
            64
        case .stressed:
            42
        }
    }

    private func dueText(for task: PlantCareTaskSnapshot) -> String {
        if task.daysUntilDue < 0 {
            return l.tr(
                zh: "逾期 \(abs(task.daysUntilDue)) 天",
                en: "\(abs(task.daysUntilDue))d overdue",
                de: "\(abs(task.daysUntilDue)) T. überfällig"
            )
        }
        if task.daysUntilDue == 0 {
            return l.tr(zh: "今天到期", en: "Due today", de: "Heute fällig")
        }
        return l.tr(
            zh: "\(task.daysUntilDue) 天后",
            en: "In \(task.daysUntilDue)d",
            de: "In \(task.daysUntilDue) T."
        )
    }

    private func plantCardAccessibilityLabel(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> String {
        var parts = [
            plant.name,
            plant.species.isEmpty ? l.tr(zh: "未设置品种", en: "Species unset", de: "Art fehlt") : plant.species,
            locationSummary(for: plant),
            plant.healthStatus.displayName
        ]
        if let nextTask {
            parts.append("\(nextTask.careType.displayName), \(dueText(for: nextTask))")
        }
        return parts.joined(separator: ", ")
    }

    private func cardAccentColor(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> Color {
        if let nextTask, nextTask.daysUntilDue <= 0 {
            return careTint(for: nextTask.careType)
        }
        switch plant.healthStatus {
        case .stressed:
            return Color.goRed
        case .watching:
            return Color.goYellow
        case .thriving:
            return Color.goLime
        case .stable:
            return Color.goTeal
        }
    }

    private func careTint(for careType: PlantCareType) -> Color {
        switch careType {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goLime
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    private func careSymbol(for careType: PlantCareType) -> String {
        switch careType {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .repotting:
            "arrow.triangle.2.circlepath"
        case .pruning:
            "scissors"
        case .misting:
            "cloud.drizzle.fill"
        case .rotating:
            "rotate.3d"
        case .leafCleaning:
            "sparkles"
        case .pestCheck:
            "ladybug.fill"
        case .photo:
            "camera.fill"
        case .newLeaf:
            "leaf.circle.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .pestFound:
            "ant.fill"
        case .customNote:
            "note.text"
        }
    }

    // MARK: - Actions

    private func waterPlant(_ plant: Plant) {
        openCareLogSheet(for: plant, type: .watering)
    }

    private func waterAll() {
        for plant in plantsNeedingWater {
            recordPlantCare(.watering, plant: plant)
        }
    }

    private func clearPlantSearchAndFilters() {
        searchText = ""
        searchFocused = false
        selectedFilter = .all
        selectedLocation = nil
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func completeTask(_ task: PlantCareTaskSnapshot) {
        guard let plant = plants.first(where: { $0.id == task.plantID }) else { return }
        openCareLogSheet(for: plant, type: task.careType)
    }

    private func openCareLogSheet(for plant: Plant, type: PlantCareType) {
        careLogDraft = PlantDashboardCareLogDraft(plant: plant, careType: type)
    }

    private func openDashboardFilters() {
        selectedDashboardMode = .plants
        searchFocused = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func openDashboardCarePlan() {
        showingCarePlanSheet = true
    }

    private func openDashboardProfileQueue() {
        selectedDashboardMode = .plants
        selectedFilter = .all
        selectedLocation = nil
        searchFocused = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func openDashboardPhotos() {
        selectedDashboardMode = .photos
        searchFocused = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func showPlants(for summary: PlantDashboardRoomSummary) {
        selectedSiteSummary = nil
        selectedLocation = summary.id
        selectedDashboardMode = .plants
        searchFocused = false
    }

    private func openPlantFromSite(_ plantID: UUID) {
        selectedSiteSummary = nil
        onOpenPlant(plantID)
    }

    private func openCareLogFromSite(plant: Plant, type: PlantCareType) {
        selectedSiteSummary = nil
        openCareLogSheet(for: plant, type: type)
    }

    private func openPlantFromPhoto(_ plantID: UUID) {
        selectedDashboardPhoto = nil
        onOpenPlant(plantID)
    }

    private func openPlantFromCarePlan(_ plantID: UUID) {
        showingCarePlanSheet = false
        onOpenPlant(plantID)
    }

    private func openCareLogFromCarePlan(plant: Plant, type: PlantCareType) {
        showingCarePlanSheet = false
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            openCareLogSheet(for: plant, type: type)
        }
    }

    private func savePlantCareLog(
        for plant: Plant,
        type: PlantCareType,
        careNote: String,
        photoData: Data?,
        healthStatus: PlantHealthStatus
    ) {
        recordPlantCare(type, plant: plant, careNote: careNote, photoData: photoData, healthStatus: healthStatus)
    }

    private func recordPlantCare(
        _ type: PlantCareType,
        plant: Plant,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.plantCare(plantID: plant.id, action: type.rawValue)) {
            commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: currentExecutorId(),
                careNote: careNote,
                photoData: photoData,
                healthStatus: healthStatus
            )
        }
    }

    private func completeDueTasks() {
        for task in dueTasks {
            guard let plant = plants.first(where: { $0.id == task.plantID }) else { continue }
            recordPlantCare(task.careType, plant: plant)
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

private struct PlantDashboardPhotoTile: View {
    let imageData: Data?
    let fallbackEmoji: String
    let tint: Color

    @State private var image: UIImage?

    private var imageSignature: String {
        guard let imageData else { return "none" }
        return "\(imageData.count)-\(imageData.first ?? 0)-\(imageData.last ?? 0)"
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(tint.opacity(0.18))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(fallbackEmoji.isEmpty ? "🌱" : fallbackEmoji)
                    .font(OhanaFont.adaptive(size: 30, weight: .black))
                    .minimumScaleFactor(0.72)
            }
        }
        .clipped()
        .task(id: imageSignature) {
            guard let imageData else {
                image = nil
                return
            }
            image = await AttachmentImageDecoder.decode(imageData)
        }
        .accessibilityHidden(true)
    }
}
