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

enum PlantDashboardMode: String, CaseIterable, Identifiable {
    case sites
    case plants
    case photos

    static var primaryCases: [PlantDashboardMode] { [.sites, .plants] }

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

enum PlantDashboardFilter: String, CaseIterable, Identifiable {
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

enum PlantDashboardPlantsViewStyle: String, CaseIterable, Identifiable {
    case deck
    case list

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .deck: l.tr(zh: "卡牌堆", en: "Card stack", de: "Kartenstapel")
        case .list: l.tr(zh: "列表", en: "List", de: "Liste")
        }
    }

    func shortTitle(_ l: L10n) -> String {
        switch self {
        case .deck: l.tr(zh: "卡", en: "Cards", de: "Karten")
        case .list: l.tr(zh: "列", en: "List", de: "Liste")
        }
    }

    var icon: String {
        switch self {
        case .deck: "square.stack.3d.up.fill"
        case .list: "list.bullet"
        }
    }
}

struct PlantDashboardRoomSummary: Identifiable {
    let id: String
    let title: String
    let plants: [Plant]
    let plantCount: Int
    let dueTaskCount: Int
    let watchCount: Int
}

enum PlantDashboardPhotoSource: Equatable, Sendable {
    case profile
    case careLog(PersistentIdentifier, UUID, String)
    case fallback

    var hasRealPhoto: Bool {
        self != .fallback
    }
}

struct PlantDashboardPhotoItem: Identifiable {
    let id: String
    let plant: Plant
    let plantModelID: PersistentIdentifier
    let source: PlantDashboardPhotoSource
    let mediaSignature: String
    let fallbackEmoji: String
    let title: String
    let subtitle: String
    let photoDate: Date?
    let tint: Color

    var hasRealPhoto: Bool {
        source.hasRealPhoto
    }
}

struct PlantDashboardReadinessItem: Identifiable {
    let id: String
    let plant: Plant
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let priority: Int
}

nonisolated enum PlantDashboardPhotoPolicy {
    static let maxLogsToInspectPerPlant = 8
    static let maxLogPhotoItemsPerPlant = 2
    static let maxDashboardItems = 60
}

struct PlantDashboardCareLogDraft: Identifiable {
    let plant: Plant
    let careType: PlantCareType

    var id: String { "\(plant.id.uuidString)-\(careType.rawValue)" }
}

struct PlantDashboardCareAggregateDraft: Identifiable, Hashable {
    let feature: PlantCareFeatureDestination
    let focusedCareType: PlantCareType?

    var id: String {
        [feature.rawValue, focusedCareType?.rawValue].compactMap(\.self).joined(separator: "-")
    }
}

struct PlantDashboardAvatarPreloadRequest: Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let signature: String
}

struct PlantDashboardView: View {
    let plants: [Plant]
    let isPlantDataLoaded: Bool
    let opensBatchCareOnAppear: Bool
    let opensBatchQuickRecordOnAppear: Bool
    let initialBatchCareType: PlantCareType?
    let onOpenPlant: (UUID) -> Void

    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @AppStorage("currentActiveHumanId") var activeHumanIdRaw = ""
    @AppStorage("plantQuickActionItems_v1") var plantQuickActionItemsRaw = ""
    @AppStorage("ohana_onboarding_has_pets") var onboardingHasPets = true
    @AppStorage("ohana_onboarding_has_children") var onboardingHasChildren = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var workloadPolicy = AppWorkloadPolicy.shared

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @State var showingAddPlant = false
    @State var selectedDashboardMode: PlantDashboardMode = .sites
    @State var selectedFilter: PlantDashboardFilter = .all
    @State var selectedPlantsViewStyle: PlantDashboardPlantsViewStyle = .deck
    @State var selectedLocation: String?
    @State var isRoomEdgeRailExpanded = false
    @State var roomEdgeRailScrollID: Int?
    @State var selectedSiteSummary: PlantDashboardRoomSummary?
    @State var selectedDashboardPhoto: PlantDashboardPhotoItem?
    @State var showingCarePlanSheet = false
    @State var showingBatchCareSheet = false
    @State var showingBatchQuickRecordSheet = false
    @State var didOpenInitialBatchCareSheet = false
    @State var didOpenInitialBatchQuickRecordSheet = false
    @State var batchCareInitialType: PlantCareType?
    @State var batchCareRoomFilter: String?
    @State var batchCareSheetSnapshot: PlantBatchCareSheetSnapshot = .empty
    @State var batchCareRouteSnapshotTask: Task<Void, Never>?
    @State var batchCareRouteSnapshotGeneration = 0
    @State var pendingBatchCareUndoToken: PlantBatchCareUndoToken?
    @State var pendingBatchCareRewardTask: Task<Void, Never>?
    @State var careLogDraft: PlantDashboardCareLogDraft?
    @State var quickCareActorDraft: PlantQuickCareActorDraft?
    @State var careAggregateDraft: PlantDashboardCareAggregateDraft?
    @State var searchText = ""
    @State var searchFocused = false
    @State var expandedPlantCardID: UUID?
    @State var plantHeroSnapshot: FocusHomeVerticalSolidHeroSnapshot?
    @State var plantHeroProgress: CGFloat = 0
    @State var plantHeroDirection: Int = 0
    @State var plantHeroGeneration = 0
    @State var plantAvatarCacheRevision = 0
    @State var plantAvatarPreloadTask: Task<Void, Never>?
    @State var plantPreparedHeroSnapshots: [UUID: FocusHomeVerticalSolidHeroSnapshot] = [:]
    @State var plantCollapseCleanupTask: Task<Void, Never>?
    @State var mediaAttachmentIndexRepairTask: Task<Void, Never>?
    @Namespace var plantWalletNamespace
    @Namespace var plantWalletHeroNamespace

    init(
        plants: [Plant] = [],
        isPlantDataLoaded: Bool = true,
        initialMode: PlantDashboardEntryMode = .sites,
        opensBatchCareOnAppear: Bool = false,
        opensBatchQuickRecordOnAppear: Bool = false,
        initialBatchCareType: PlantCareType? = nil,
        onOpenPlant: @escaping (UUID) -> Void = { _ in }
    ) {
        self.plants = plants
        self.isPlantDataLoaded = isPlantDataLoaded
        self.opensBatchCareOnAppear = opensBatchCareOnAppear
        self.opensBatchQuickRecordOnAppear = opensBatchQuickRecordOnAppear
        self.initialBatchCareType = initialBatchCareType
        self.onOpenPlant = onOpenPlant
        _selectedDashboardMode = State(initialValue: PlantDashboardMode(entryMode: initialMode))
    }

    var l: L10n { L10n(appLanguage) }
    var commandExecutor: HomeCommandExecutor { HomeCommandExecutor(modelContext: modelContext, services: appServices) }

    var plantsNeedingWater: [Plant] {
        let ids = Set(dueTasks.filter { $0.careType == .watering }.map(\.plantID))
        return plants.filter { ids.contains($0.id) }
    }

    var upcomingTasks: [PlantCareTaskSnapshot] {
        appServices.plantCarePlans.tasks(for: plants, days: 7)
    }

    var dueTasks: [PlantCareTaskSnapshot] {
        upcomingTasks.filter { $0.daysUntilDue <= 0 }
    }

    var careWindowTasks: [PlantCareTaskSnapshot] {
        upcomingTasks
    }

    var plantsNeedingCareCount: Int {
        Set(dueTasks.map(\.plantID)).count
    }

    var watchedPlantsCount: Int {
        plants.count(where: { $0.healthStatus == .watching || $0.healthStatus == .stressed })
    }

    var indoorPlantCount: Int {
        plants.filter(\.isIndoor).count
    }

    var locationOptions: [String] {
        let locations = plants
            .map(locationFilterValue(for:))
            .filter { !$0.isEmpty }
        return Array(Set(locations)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearchingPlants: Bool {
        !normalizedSearchText.isEmpty
    }

    var isNarrowingPlants: Bool {
        selectedFilter != .all || selectedLocation != nil || isSearchingPlants
    }

    var roomCareSummaries: [PlantDashboardRoomSummary] {
        roomCareSummaries(for: plants)
    }

    var plantListModePlants: [Plant] {
        plantsSortedByCareUrgency(filteredPlants(ignoresLocation: true))
    }

    var plantListModeRoomSummaries: [PlantDashboardRoomSummary] {
        roomCareSummaries(for: plantListModePlants)
    }

    func roomCareSummaries(for sourcePlants: [Plant]) -> [PlantDashboardRoomSummary] {
        Dictionary(grouping: sourcePlants, by: locationFilterValue(for:))
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
                    plants: plantsSortedByCareUrgency(roomPlants),
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

    var visiblePlants: [Plant] {
        filteredPlants(ignoresLocation: false)
    }

    func filteredPlants(ignoresLocation: Bool) -> [Plant] {
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
        let locationFiltered: [Plant] = if !ignoresLocation, let selectedLocation {
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

    func plantsSortedByCareUrgency(_ sourcePlants: [Plant]) -> [Plant] {
        let dueByPlantID = Dictionary(
            upcomingTasks.map { ($0.plantID, $0.daysUntilDue) },
            uniquingKeysWith: min
        )

        return sourcePlants.sorted { lhs, rhs in
            let lhsDue = dueByPlantID[lhs.id] ?? Int.max
            let rhsDue = dueByPlantID[rhs.id] ?? Int.max
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }

            let lhsHealthPriority = plantHealthSortPriority(lhs)
            let rhsHealthPriority = plantHealthSortPriority(rhs)
            if lhsHealthPriority != rhsHealthPriority {
                return lhsHealthPriority < rhsHealthPriority
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    func plantHealthSortPriority(_ plant: Plant) -> Int {
        switch plant.healthStatus {
        case .stressed:
            0
        case .watching:
            1
        default:
            2
        }
    }

    var showsRoomEdgeRail: Bool {
        selectedDashboardMode == .plants
            && selectedPlantsViewStyle == .deck
            && roomCareSummaries.count >= 2
            && !plants.isEmpty
            && expandedPlantCardID == nil
            && plantHeroDirection == 0
    }

    var showsPlantViewSwitcherRail: Bool {
        selectedDashboardMode == .plants
            && !plants.isEmpty
            && expandedPlantCardID == nil
            && plantHeroDirection == 0
    }

    var photoDashboardItems: [PlantDashboardPhotoItem] {
        let items = plants.flatMap { plant -> [PlantDashboardPhotoItem] in
            var items: [PlantDashboardPhotoItem] = []

            if plant.hasAvatarImageAttachment {
                items.append(
                    PlantDashboardPhotoItem(
                        id: "\(plant.id.uuidString)-profile",
                        plant: plant,
                        plantModelID: plant.persistentModelID,
                        source: .profile,
                        mediaSignature: plant.avatarThumbnailSignature,
                        fallbackEmoji: plant.avatarEmoji,
                        title: plant.name,
                        subtitle: locationSummary(for: plant),
                        photoDate: nil,
                        tint: siteTint(for: plant)
                    )
                )
            }

            let recentLogs = plant.careLogs
                .sorted { $0.date > $1.date }
                .prefix(PlantDashboardPhotoPolicy.maxLogsToInspectPerPlant)

            var logPhotoItems: [PlantDashboardPhotoItem] = []
            for log in recentLogs {
                guard log.hasPhotoAttachment else { continue }
                let mediaSignature = log.photoThumbnailSignature
                logPhotoItems.append(PlantDashboardPhotoItem(
                    id: "\(plant.id.uuidString)-log-\(log.id.uuidString)",
                    plant: plant,
                    plantModelID: plant.persistentModelID,
                    source: .careLog(log.persistentModelID, log.id, mediaSignature),
                    mediaSignature: mediaSignature,
                    fallbackEmoji: plant.avatarEmoji,
                    title: plant.name,
                    subtitle: "\(log.careType.displayName(l: l)) · \(shortDate(log.date))",
                    photoDate: log.date,
                    tint: careTint(for: log.careType)
                ))
                if logPhotoItems.count >= PlantDashboardPhotoPolicy.maxLogPhotoItemsPerPlant {
                    break
                }
            }
            items += logPhotoItems

            if items.isEmpty {
                items.append(
                    PlantDashboardPhotoItem(
                        id: "\(plant.id.uuidString)-fallback",
                        plant: plant,
                        plantModelID: plant.persistentModelID,
                        source: .fallback,
                        mediaSignature: "",
                        fallbackEmoji: plant.avatarEmoji,
                        title: plant.name,
                        subtitle: locationSummary(for: plant),
                        photoDate: nil,
                        tint: siteTint(for: plant)
                    )
                )
            }

            return Array(items.prefix(3))
        }
        .sorted { lhs, rhs in
            if lhs.hasRealPhoto != rhs.hasRealPhoto {
                return lhs.hasRealPhoto
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
        return Array(items.prefix(PlantDashboardPhotoPolicy.maxDashboardItems))
    }

    var profileReadinessItems: [PlantDashboardReadinessItem] {
        plants
            .compactMap(profileReadinessItem(for:))
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.plant.name.localizedStandardCompare(rhs.plant.name) == .orderedAscending
            }
    }

    var dashboardLeadPlant: Plant? {
        plants.first { plantHasPreviewImage($0) } ?? plants.first
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.vertical, showsIndicators: false) {
                Spacer().frame(height: 70)

                if plants.isEmpty, !isPlantDataLoaded {
                    loadingState
                } else if plants.isEmpty {
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

            plantFloatingEdgeControls
            batchCareUndoBanner
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
                imageDataProvider: photoImageData(for:),
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
                onDeferDueTasks: deferDueTasksOneDay,
                onDeferTask: deferTaskOneDay,
                onSkipTask: skipTask
            )
        }
        .sheet(isPresented: $showingBatchCareSheet) {
            PlantBatchCareSheet(
                snapshot: batchCareSheetSnapshot,
                initialCareType: batchCareInitialType,
                imageDataProvider: { plantModelID in
                    await previewImageData(for: plantModelID, source: .profile)
                },
                onComplete: completeBatchCare,
                onOpenCareLog: openCareLogFromBatchCare,
                onDeferTask: deferTaskFromBatchCare,
                onSkipTask: skipTaskFromBatchCare
            )
            .onDisappear {
                batchCareRoomFilter = nil
            }
        }
        .modifier(
            PlantDashboardCareSheetsModifier(
                showingBatchQuickRecordSheet: $showingBatchQuickRecordSheet,
                quickCareActorDraft: $quickCareActorDraft,
                careLogDraft: $careLogDraft,
                careAggregateDraft: $careAggregateDraft,
                plants: plants,
                initialBatchCareType: initialBatchCareType,
                imageDataProvider: { await previewImageData(for: $0, source: .profile) },
                onRecordBatchCare: recordBatchQuickCare,
                onConfirmQuickCare: confirmPlantDockQuickCare,
                onSaveCareLog: savePlantCareLog
            )
        )
        .accessibilityIdentifier("plant-dashboard-screen")
        .onChange(of: selectedDashboardMode) { _, _ in
            collapseExpandedPlantIfNeeded()
        }
        .onChange(of: selectedLocation) { _, _ in
            collapseExpandedPlantIfNeeded()
        }
        .onChange(of: searchText) { _, _ in
            collapseExpandedPlantIfNeeded()
        }
        .onAppear {
            scheduleMediaAttachmentIndexRepair()
            scheduleVisiblePlantAvatarPreload()
            openInitialBatchCareSheetIfNeeded()
            openInitialBatchQuickRecordSheetIfNeeded()
        }
        .onChange(of: plants.count) { _, _ in
            scheduleMediaAttachmentIndexRepair()
        }
        .onChange(of: plantAvatarPreloadSignature) { _, _ in
            scheduleVisiblePlantAvatarPreload()
        }
        .onDisappear {
            mediaAttachmentIndexRepairTask?.cancel()
            plantAvatarPreloadTask?.cancel()
            batchCareRouteSnapshotTask?.cancel()
            pendingBatchCareRewardTask?.cancel()
            commandQueue.cancelAll()
        }
    }

    func locationFilterValue(for plant: Plant) -> String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty {
            return room
        }
        return plant.isIndoor
            ? l.tr(zh: "未设置室内位置", en: "Unassigned indoor", de: "Innen ohne Ort")
            : l.tr(zh: "未设置户外位置", en: "Unassigned outdoor", de: "Außen ohne Ort")
    }

    func plantMatchesSearch(_ plant: Plant, normalizedQuery: String) -> Bool {
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

    func profileReadinessItem(for plant: Plant) -> PlantDashboardReadinessItem? {
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
                tint: Color.goPrimary,
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

        if !plantHasPreviewImage(plant) {
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
                tint: Color.goPrimary,
                priority: 5
            )
        }

        return nil
    }

    func needsSafetyReview(_ plant: Plant) -> Bool {
        (onboardingHasPets && (plant.isToxicToCats || plant.isToxicToDogs)) ||
            (onboardingHasChildren && plant.isToxicToChildren) ||
            !plant.isIndoorSuitable
    }

    func profileReadinessAccessibilityLabel(_ item: PlantDashboardReadinessItem) -> String {
        [
            item.plant.name,
            item.title,
            item.detail,
            l.tr(zh: "打开植物详情", en: "Open plant detail", de: "Pflanzendetails öffnen")
        ].joined(separator: ", ")
    }

    func normalizedForPlantSearch(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    func locationSummary(for plant: Plant) -> String {
        locationFilterValue(for: plant)
    }

    func previewImageData(for plantModelID: PersistentIdentifier, source: PlantDashboardPhotoSource) async -> Data? {
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        switch source {
        case .profile:
            return await loader.plantAvatarImageData(modelID: plantModelID)
        case let .careLog(logModelID, _, _):
            return await loader.plantCareLogPhotoData(modelID: logModelID)
        case .fallback:
            return nil
        }
    }

    func previewImageID(for plant: Plant, source: PlantDashboardPhotoSource) -> String {
        switch source {
        case .profile:
            "\(plant.id.uuidString)-profile"
        case let .careLog(_, logID, _):
            "\(plant.id.uuidString)-log-\(logID.uuidString)"
        case .fallback:
            "\(plant.id.uuidString)-fallback"
        }
    }

    func previewImageSignature(for plant: Plant, source: PlantDashboardPhotoSource) -> String {
        switch source {
        case .profile:
            plant.avatarThumbnailSignature
        case let .careLog(_, _, mediaSignature):
            mediaSignature
        case .fallback:
            ""
        }
    }

    func previewImageSource(for plant: Plant) -> PlantDashboardPhotoSource {
        if plant.hasAvatarImageAttachment {
            return .profile
        }
        if let log = plant.careLogs
            .sorted(by: { $0.date > $1.date })
            .first(where: { $0.hasPhotoAttachment }) {
            let mediaSignature = log.photoThumbnailSignature
            return .careLog(log.persistentModelID, log.id, mediaSignature)
        }
        return .fallback
    }

    func plantHasPreviewImage(_ plant: Plant) -> Bool {
        plant.hasAvatarImageAttachment || plant.careLogs.contains { $0.hasPhotoAttachment }
    }

    func photoImageData(for item: PlantDashboardPhotoItem) async -> Data? {
        await previewImageData(for: item.plantModelID, source: item.source)
    }

    @ViewBuilder
    func plantPreviewTile(for plant: Plant) -> some View {
        let source = previewImageSource(for: plant)
        let plantModelID = plant.persistentModelID
        PlantDashboardPhotoTile(
            imageID: previewImageID(for: plant, source: source),
            imageSignature: previewImageSignature(for: plant, source: source),
            imageDataProvider: { await previewImageData(for: plantModelID, source: source) },
            fallbackEmoji: plant.avatarEmoji,
            tint: siteTint(for: plant)
        )
    }

    func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    func siteTint(for plant: Plant) -> Color {
        let trimmed = plant.themeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Color.goTeal : Color(hex: trimmed)
    }

    func plantCareScore(for plant: Plant) -> Int {
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

    func dueText(for task: PlantCareTaskSnapshot) -> String {
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

    func plantCardAccessibilityLabel(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> String {
        var parts = [
            plant.name,
            plant.species.isEmpty ? l.tr(zh: "未设置品种", en: "Species unset", de: "Art fehlt") : plant.species,
            locationSummary(for: plant),
            plant.healthStatus.displayName
        ]
        if let nextTask {
            parts.append("\(nextTask.careType.displayName(l: l)), \(dueText(for: nextTask))")
        }
        return parts.joined(separator: ", ")
    }

    func cardAccentColor(for plant: Plant, nextTask: PlantCareTaskSnapshot?) -> Color {
        if let nextTask, nextTask.daysUntilDue <= 0 {
            return careTint(for: nextTask.careType)
        }
        switch plant.healthStatus {
        case .stressed:
            return Color.goRed
        case .watching:
            return Color.goYellow
        case .thriving:
            return Color.goPrimary
        case .stable:
            return Color.goTeal
        }
    }

    func careTint(for careType: PlantCareType) -> Color {
        switch careType {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goPrimary
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    func careSymbol(for careType: PlantCareType) -> String {
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
}

struct PlantDashboardPhotoTile: View {
    let imageID: String
    let imageSignature: String
    let imageDataProvider: @Sendable () async -> Data?
    let fallbackEmoji: String
    let tint: Color

    init(
        imageID: String,
        imageSignature: String,
        imageDataProvider: @escaping @Sendable () async -> Data?,
        fallbackEmoji: String,
        tint: Color
    ) {
        self.imageID = imageID
        self.imageSignature = imageSignature
        self.imageDataProvider = imageDataProvider
        self.fallbackEmoji = fallbackEmoji
        self.tint = tint
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(tint.opacity(0.18))

            PlantDetailDecodedImageTile(
                imageID: imageID,
                imageSignature: imageSignature,
                imageDataProvider: { await imageDataProvider() },
                tint: tint,
                fillsContainer: true,
                maxPixel: 720
            )

            if imageSignature.isEmpty {
                Text(fallbackEmoji.isEmpty ? "🌱" : fallbackEmoji)
                    .font(OhanaFont.adaptive(size: 30, weight: .black))
                    .minimumScaleFactor(0.72)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
