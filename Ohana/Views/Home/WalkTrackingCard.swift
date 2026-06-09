//
//  WalkTrackingCard.swift
//  Ohana
//
//  遛狗追踪卡片：地图铺满卡片背景，控制面板以玻璃层叠加。
//

import SwiftUI
import SwiftData
import MapKit

struct WalkTrackingSnapshot {
    let latestWalk: PetWalkLog?
    let latestWalkMapImage: UIImage?
    let latestRouteCoordinates: [CLLocationCoordinate2D]
    let latestPoopMarkers: [WalkPoopMarker]
    let thisWeekDistanceKm: Double

    @MainActor
    static func make(pet: Pet, manager: PetWalkingManager) -> WalkTrackingSnapshot {
        let latestWalk: PetWalkLog?
        if manager.lastCompletedPetId == pet.id, let completed = manager.lastCompletedWalk {
            latestWalk = completed
        } else {
            latestWalk = pet.walkLogs.max { $0.startDate < $1.startDate }
        }
        let routeCoordinates: [CLLocationCoordinate2D]
        if manager.lastCompletedPetId == pet.id, !manager.lastCompletedRouteCoordinates.isEmpty {
            routeCoordinates = manager.lastCompletedRouteCoordinates
        } else {
            routeCoordinates = Self.routeCoordinates(from: latestWalk?.routeLocationsData)
        }
        let poopMarkers: [WalkPoopMarker]
        if manager.lastCompletedPetId == pet.id, !manager.lastCompletedPoopMarkers.isEmpty {
            poopMarkers = manager.lastCompletedPoopMarkers
        } else if let walkId = latestWalk?.id.uuidString {
            poopMarkers = pet.pottyLogs
                .filter { $0.walkLogId == walkId }
                .sorted { $0.date < $1.date }
                .map(WalkPoopMarker.init(log:))
        } else {
            poopMarkers = []
        }
        let weekDistanceKm = pet.walkLogs
            .filter { $0.startDate >= Self.weekStartDate() }
            .reduce(0) { $0 + $1.distanceMeters } / 1000.0
        return WalkTrackingSnapshot(
            latestWalk: latestWalk,
            latestWalkMapImage: latestWalk?.mapSnapshotData.flatMap(UIImage.init(data:)),
            latestRouteCoordinates: routeCoordinates,
            latestPoopMarkers: poopMarkers,
            thisWeekDistanceKm: weekDistanceKm
        )
    }

    private static func routeCoordinates(from data: Data?) -> [CLLocationCoordinate2D] {
        guard let data,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
        else { return [] }
        return arr.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private static func weekStartDate() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date ?? Date()
    }
}

@MainActor
struct WalkTrackingCommandExecutor {
    let modelContext: ModelContext

    func stopWalk(manager: PetWalkingManager) {
        manager.stop(modelContext: modelContext)
    }

    func saveWeeklyGoal(_ goal: Double, for pet: Pet) {
        PetWalkCommandExecutor(context: modelContext).saveWeeklyGoal(
            goal,
            for: pet,
            note: "walk.card.goal"
        )
    }
}

struct WalkTrackingCardHost: View {
    let pet: Pet
    var onCloseSummaryToPetCard: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let commandExecutor = WalkTrackingCommandExecutor(modelContext: modelContext)
        WalkTrackingCard(
            pet: pet,
            snapshot: WalkTrackingSnapshot.make(pet: pet, manager: PetWalkingManager.shared),
            onCloseSummaryToPetCard: onCloseSummaryToPetCard,
            onStopWalk: {
                commandExecutor.stopWalk(manager: PetWalkingManager.shared)
            },
            onSaveWeeklyGoal: { goal in
                commandExecutor.saveWeeklyGoal(goal, for: pet)
            }
        )
    }
}

struct WalkTrackingCard: View {
    let pet: Pet
    let snapshot: WalkTrackingSnapshot
    var onCloseSummaryToPetCard: (() -> Void)? = nil
    var onStopWalk: () -> Void
    var onSaveWeeklyGoal: (Double) -> Void

    private var mgr: PetWalkingManager { PetWalkingManager.shared }
    private var locationMgr: LocationManager { LocationManager.shared }
    @AppStorage("appLanguage") private var appLanguage: String = "zh"
    @AppStorage(RainbowWalkEffectKeys.route) private var equipFxRainbowRoute = false
    @AppStorage(RainbowWalkEffectKeys.poop) private var equipFxRainbowPoop = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    @State private var showFloatingPoop = false
    @State private var showWalkDetail: PetWalkLog? = nil
    @State private var showSummaryBack = false
    @State private var isClosingSummaryBack = false
    @State private var summaryRotation: Double = 0
    @State private var showingGoalSetter = false
    @State private var goalDraft: Double = 0
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var rainbowRoutePhase: CGFloat = 0

    private var isActivePet: Bool {
        mgr.currentPet?.id == pet.id || mgr.phase == .idle
    }
    private var isWalking: Bool {
        guard isActivePet else { return false }
        switch mgr.phase {
        case .running, .paused: return true
        default: return false
        }
    }
    private var isRunningWalk: Bool {
        guard isActivePet else { return false }
        if case .running = mgr.phase { return true }
        return false
    }
    private var walkClockInterval: TimeInterval {
        guard walkSurfaceGate.allowsRefresh else { return 60 }
        return workloadPolicy.refreshInterval(
            default: 1,
            throttled: 15,
            paused: 60,
            isVisible: isWalking,
            allowDuringActiveWalk: true
        )
    }
    private var liveRouteCoordinates: [CLLocationCoordinate2D] {
        routeCoordinates(from: locationMgr.collectedLocations, maxCount: 320)
    }
    private var livePoopMarkers: [WalkPoopMarker] {
        isActivePet ? mgr.activePoopMarkers : []
    }
    private var shouldAnimateRainbowWalkEffects: Bool {
        walkSurfaceGate.allowsAmbientMotion
    }

    private var walkSurfaceGate: SurfaceActivityGate {
        workloadPolicy.surfaceGate(
            isVisible: isWalking,
            isLive: isActivePet,
            allowsAmbientOptIn: equipFxRainbowRoute || equipFxRainbowPoop,
            allowDuringActiveWalk: true
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                trackingFrontFace
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(summaryRotation < 90 ? 1 : 0)
                    .allowsHitTesting(!showSummaryBack)

                walkSummaryBackFace
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(summaryRotation >= 90 ? 1 : 0)
                    .allowsHitTesting(showSummaryBack)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .rotation3DEffect(.degrees(summaryRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if showSummaryBack {
                    summaryMapToolbar
                        .padding(.top, 26)
                        .padding(.trailing, 24)
                        .zIndex(200)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .clipped()
        .sheet(item: $showWalkDetail) { walk in WalkDetailView(walk: walk, pet: pet) }
        .sheet(isPresented: $showingGoalSetter) {
            walkGoalSetterSheet
                .ohanaCompactSheetPresentation(detents: [.height(320)])
        }
        .onChange(of: mgr.showSummary) { _, newVal in
            if newVal && mgr.currentPet?.id == pet.id {
                presentSummaryBack()
                mgr.showSummary = false
            }
        }
        .onChange(of: mgr.phase) { _, newPhase in
            if case .finished = newPhase, mgr.currentPet?.id == pet.id {
                presentSummaryBack()
            }
        }
        .onAppear {
            if case .finished = mgr.phase, mgr.currentPet?.id == pet.id {
                presentSummaryBack(animated: false)
            }
            updateRainbowRouteFlow()
        }
        .onChange(of: shouldAnimateRainbowWalkEffects) { _, _ in updateRainbowRouteFlow() }
    }

    private var trackingFrontFace: some View {
        ZStack(alignment: .bottom) {
            // ── 背景层：地图或快照
            mapBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── 控制层：半透明玻璃条
            VStack(spacing: 0) {
                if isActivePet {
                    walkLocationStatusPill
                }
                controlPanel
            }
            .background(Color.ohanaCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Map Background

    @ViewBuilder
    private var mapBackground: some View {
        if isRunningWalk {
            // 活跃遛狗中：实时位置地图
            Map(position: $cameraPosition) {
                UserAnnotation()
                RainbowRoutePolyline(
                    coordinates: liveRouteCoordinates,
                    normalColor: .goPrimary,
                    lineWidth: 6,
                    isRainbow: equipFxRainbowRoute,
                    isFlowing: shouldAnimateRainbowWalkEffects,
                    flowPhase: rainbowRoutePhase
                )
                ForEach(livePoopMarkers) { marker in
                    if let coordinate = marker.coordinate {
                        Annotation("便便", coordinate: coordinate) {
                            poopMapPin
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
            }
            .overlay(alignment: .topTrailing) {
                Text(distanceText)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.goCardWhite)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.arkInk.opacity(0.6), in: Capsule())
                    .padding(8)
            }
        } else if isWalking {
            let coords = liveRouteCoordinates
            if coords.count >= 2, let region = routeRegion(for: coords) {
                Map(initialPosition: .region(region)) {
                    RainbowRoutePolyline(
                        coordinates: coords,
                        normalColor: .goYellow,
                        lineWidth: 6,
                        isRainbow: equipFxRainbowRoute,
                        isFlowing: shouldAnimateRainbowWalkEffects,
                        flowPhase: rainbowRoutePhase
                    )
                    ForEach(livePoopMarkers) { marker in
                        if let coordinate = marker.coordinate {
                            Annotation("便便", coordinate: coordinate) {
                                poopMapPin
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .overlay(alignment: .topTrailing) {
                    Text(distanceText)
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(Color.goCardWhite)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.arkInk.opacity(0.6), in: Capsule())
                        .padding(8)
                }
            } else {
                pausedRoutePlaceholder
            }
        } else {
            // 待出发：显示上次遛狗地图快照
            if let lastWalk = snapshot.latestWalk, let ui = snapshot.latestWalkMapImage {
                Button {
                    showWalkDetail = lastWalk
                } label: {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                // 无快照：渐变占位
                LinearGradient(
                    colors: [Color(hex: "1A2744"), Color(hex: "0D1526")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.goCardWhite.opacity(0.2))
                        Text("暂无路线记录")
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color.goCardWhite.opacity(0.2))
                    }
                )
            }
        }
    }

    private var pausedRoutePlaceholder: some View {
        LinearGradient(
            colors: [Color(hex: "1A2744"), Color(hex: "0D1526")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 6) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.goYellow.opacity(0.7))
                Text(L10n(appLanguage).tr(zh: "遛狗已暂停", en: "Walk paused", de: "Gassi pausiert"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goCardWhite.opacity(0.62))
            }
        )
    }

    private var poopMapPin: some View {
        RainbowPoopPin(
            isRainbow: equipFxRainbowPoop,
            isFlowing: shouldAnimateRainbowWalkEffects,
            size: 28
        )
    }

    private var distanceText: String {
        AppMeasurementSystem.formatDistanceMeters(locationMgr.totalDistance)
    }

    private var walkLocationStatusPill: some View {
        let status = walkLocationStatus
        return HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(status.tint)
            Text(status.title)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
            Spacer(minLength: 8)
            Text(status.detail)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(status.tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 9)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }

    private var walkLocationStatus: (icon: String, title: String, detail: String, tint: Color) {
        let l = L10n(appLanguage)
        switch mgr.phase {
        case .running:
            if locationMgr.authorizationStatus == .authorizedAlways {
                return (
                    "lock.iphone",
                    l.tr(zh: "路线记录中", en: "Route recording", de: "Route wird aufgezeichnet"),
                    l.tr(zh: "锁屏继续", en: "Lock screen OK", de: "Sperrbildschirm OK"),
                    Color.goPrimary
                )
            }
            if locationMgr.authorizationStatus == .authorizedWhenInUse {
                return (
                    "location.fill",
                    l.tr(zh: "路线记录中", en: "Route recording", de: "Route wird aufgezeichnet"),
                    l.tr(zh: "后台会提示", en: "Background indicator", de: "Hintergrundhinweis"),
                    Color.goYellow
                )
            }
            return (
                "location.slash.fill",
                l.tr(zh: "等待定位授权", en: "Location needed", de: "Standort benötigt"),
                l.tr(zh: "前台记录", en: "Foreground only", de: "Nur Vordergrund"),
                Color.goYellow
            )
        case .paused:
            return (
                "pause.circle.fill",
                l.tr(zh: "已暂停", en: "Paused", de: "Pausiert"),
                l.tr(zh: "不使用定位", en: "Location off", de: "Standort aus"),
                Color.goYellow
            )
        default:
            return (
                "location.slash.fill",
                l.tr(zh: "定位已关闭", en: "Location off", de: "Standort aus"),
                l.tr(zh: "省电", en: "Saving power", de: "Energiesparend"),
                Color.ohanaSecondaryText
            )
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        HStack(spacing: 0) {
            // Left: pet info + timer
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pet.avatarEmoji).font(.system(size: 18))
                    Text(pet.name)
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    statusDot
                }
                timerText
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: action buttons
            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6)
    }

    private var statusColor: Color {
        guard isActivePet else { return Color.ohanaTertiaryText.opacity(0.3) }
        switch mgr.phase {
        case .idle:     return Color.ohanaTertiaryText.opacity(0.3)
        case .running:  return Color.goPrimary
        case .paused:   return Color.goYellow
        case .finished: return Color.goTeal
        }
    }

    @ViewBuilder
    private var timerText: some View {
        if walkSurfaceGate.allowsRefresh {
            TimelineView(.periodic(from: .now, by: walkClockInterval)) { _ in
                walkTimerLabel(elapsed: currentWalkElapsedSeconds)
            }
        } else {
            walkTimerLabel(elapsed: currentWalkElapsedSeconds)
        }
    }

    private var currentWalkElapsedSeconds: Int {
        isActivePet ? Int(mgr.elapsedTime) : 0
    }

    private func walkTimerLabel(elapsed: Int) -> some View {
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return Text(h > 0
             ? String(format: "%d:%02d:%02d", h, m, s)
             : String(format: "%02d:%02d", m, s))
            .font(OhanaFont.metric(size: 22))
            .foregroundStyle(Color.ohanaPrimaryText)
            .contentTransition(.numericText())
    }

    // MARK: - Finished Back Face

    private var walkSummaryBackFace: some View {
        GeometryReader { geo in
            let walk = latestWalk
            let elapsed = finishedElapsed
            let distance = finishedDistance(walk)
            let poop = finishedPoopCount
            let contentHeight = max(0, geo.size.height - 28)
            let mapHeight = max(160, contentHeight - 74)

            ZStack {
                LinearGradient(
                    colors: [Color(hex: "12264A"), Color(hex: "07111F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 12) {
                    summaryMapPanel(walk: walk, distance: distance)
                        .frame(height: mapHeight)

                    HStack(spacing: 8) {
                        summaryStatCell(label: "时间", value: formatElapsed(elapsed), accent: .goPrimary)
                        summaryStatCell(label: "距离", value: distanceText(distance), accent: .goTeal)
                        summaryStatCell(label: "便便", value: "\(poop)次", accent: .goYellow)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func summaryMapPanel(walk: PetWalkLog?, distance: Double) -> some View {
        ZStack {
            summaryRouteMap(walk: walk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 1)
                }
                .clipped()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    petAvatar(pet: pet, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本次遛狗")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.goPrimary)
                            .tracking(1.2)
                        Text("\(pet.name) 到家啦")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.goCardWhite)
                            .lineLimit(1)
                    }
                    Spacer()
                    summaryMapToolbarPlaceholder
                }

                Spacer(minLength: 14)

                summaryGoalOverlay(distance: distance)
            }
            .padding(12)
        }
    }

    private var summaryMapToolbar: some View {
        HStack(spacing: 8) {
            summaryEditGoalIconButton
            summaryCloseButton
        }
        .zIndex(40)
    }

    private var summaryMapToolbarPlaceholder: some View {
        Color.clear
            .frame(width: 96, height: 44)
            .allowsHitTesting(false)
    }

    private var summaryCloseButton: some View {
        Button { closeSummaryBack() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.goCardWhite)
                    .frame(width: 40, height: 40)
                    .background(Color.arkInk.opacity(0.42), in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.goCardWhite.opacity(0.18), lineWidth: 1)
                    }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("关闭遛狗摘要")
    }

    private var summaryEditGoalIconButton: some View {
        Button {
            goalDraft = max(3, pet.weeklyWalkGoalKm)
            showingGoalSetter = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 40, height: 40)
                .background(Color.goPrimary, in: Circle())
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("编辑遛狗目标")
    }

    @ViewBuilder
    private func summaryRouteMap(walk: PetWalkLog?) -> some View {
        let coords = snapshot.latestRouteCoordinates
        let poopMarkers = snapshot.latestPoopMarkers
        let markerCoords = poopMarkers.compactMap(\.coordinate)
        let previewCoords = coords.isEmpty ? markerCoords : coords
        if walk != nil, let ui = snapshot.latestWalkMapImage, !(equipFxRainbowRoute || equipFxRainbowPoop) {
            GeometryReader { geo in
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Label("本次轨迹", systemImage: "map.fill")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.goCardWhite)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.arkInk.opacity(0.46), in: Capsule())
                            .padding(10)
                    }
            }
        } else if !previewCoords.isEmpty {
            WalkRouteTracePreview(
                coordinates: previewCoords,
                title: coords.count >= 2 ? "本次轨迹" : "本次定位"
            )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.goCardWhite.opacity(0.08))
                .overlay {
                    VStack(spacing: 5) {
                        Image(systemName: "map")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.goCardWhite.opacity(0.28))
                        Text("本次轨迹生成中")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.goCardWhite.opacity(0.38))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func summaryGoalOverlay(distance: Double) -> some View {
        if pet.weeklyWalkGoalKm > 0 {
            let progress = weeklyProgress
            goalOverlayContainer {
                HStack(spacing: 10) {
                    goalProgressRing(progress: progress)
                    goalTextBlock(
                        title: "本周目标",
                        subtitle: String(format: "%.1f / %.0f km", thisWeekDistanceKm, pet.weeklyWalkGoalKm)
                    )
                    Spacer(minLength: 0)
                }
            }
        } else {
            goalOverlayContainer {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        goalFlagIcon
                        goalTextBlock(
                            title: "还没有遛狗目标",
                            subtitle: "设一个每周目标，之后会显示完成率"
                        )
                        Spacer(minLength: 8)
                        editGoalButton
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            goalFlagIcon
                            goalTextBlock(
                                title: "还没有遛狗目标",
                                subtitle: "设一个每周目标，之后会显示完成率"
                            )
                            Spacer(minLength: 0)
                        }
                        editGoalButton
                    }
                }
            }
        }
    }

    private func goalOverlayContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.arkInk.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 1)
            }
    }

    private func goalTextBlock(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.goCardWhite.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(OhanaFont.footnote(.black))
                .foregroundStyle(Color.goCardWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func goalProgressRing(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.goCardWhite.opacity(0.14), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.goPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(GoMotion.feedback, value: progress)
            Text("\(Int(progress * 100))%")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.goCardWhite)
        }
        .frame(width: 42, height: 42)
    }

    private var goalFlagIcon: some View {
        Image(systemName: "flag.checkered")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.goPrimary)
            .frame(width: 42, height: 42)
            .background(Color.arkInk.opacity(0.34), in: Circle())
    }

    private var editGoalButton: some View {
        Button {
            goalDraft = max(3, pet.weeklyWalkGoalKm)
            showingGoalSetter = true
        } label: {
            Text("编辑目标")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.arkInk)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var walkGoalSetterSheet: some View {
        VStack(spacing: 20) {
            Text("设定每周步行目标")
                .font(OhanaFont.headline(.black))
                .padding(.top, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weeklyGoalDisplay(goalDraft))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .contentTransition(.numericText())
                    .animation(GoMotion.feedback, value: goalDraft)
                Text("km / 周")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            HStack(spacing: 28) {
                Button { adjustWeeklyGoal(-0.5) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft <= 0 ? Color.ohanaTertiaryText.opacity(0.35) : Color.goPrimary, Color.ohanaControlFill.opacity(0.42))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(goalDraft <= 0)

                Text("每次 ±0.5 km")
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(Color.ohanaSecondaryText)

                Button { adjustWeeklyGoal(0.5) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft >= 100 ? Color.ohanaTertiaryText.opacity(0.35) : Color.goPrimary, Color.ohanaControlFill.opacity(0.42))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(goalDraft >= 100)
            }

            Button {
                onSaveWeeklyGoal(goalDraft)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingGoalSetter = false
            } label: {
                    Text(goalDraft == 0 ? "清除目标" : "保存目标")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)

            Spacer(minLength: 8)
        }
    }

    private func summaryStatCell(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goCardWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var latestWalk: PetWalkLog? {
        snapshot.latestWalk
    }

    private var finishedElapsed: TimeInterval {
        if case .finished(let elapsed, _) = mgr.phase, mgr.currentPet?.id == pet.id {
            return elapsed
        }
        return latestWalk?.durationSeconds ?? 0
    }

    private var finishedPoopCount: Int {
        if case .finished(_, let poopCount) = mgr.phase, mgr.currentPet?.id == pet.id {
            return poopCount
        }
        return mgr.poopCount
    }

    private func finishedDistance(_ walk: PetWalkLog?) -> Double {
        if let walk, walk.distanceMeters > 0 {
            return walk.distanceMeters
        }
        return locationMgr.totalDistance
    }

    private var thisWeekDistanceKm: Double {
        snapshot.thisWeekDistanceKm
    }

    private var weeklyProgress: Double {
        guard pet.weeklyWalkGoalKm > 0 else { return 0 }
        return min(thisWeekDistanceKm / pet.weeklyWalkGoalKm, 1.0)
    }

    private func routeCoordinates(from locations: [CLLocation], maxCount: Int) -> [CLLocationCoordinate2D] {
        guard locations.count > maxCount, maxCount >= 2 else {
            return locations.map(\.coordinate)
        }
        let step = Double(locations.count - 1) / Double(maxCount - 1)
        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(maxCount)
        var lastIndex = -1
        for i in 0..<maxCount {
            let index = min(locations.count - 1, Int((Double(i) * step).rounded()))
            if index != lastIndex {
                result.append(locations[index].coordinate)
                lastIndex = index
            }
        }
        if let last = locations.last?.coordinate, let renderedLast = result.last {
            if renderedLast.latitude != last.latitude || renderedLast.longitude != last.longitude {
                result[result.count - 1] = last
            }
        }
        return result
    }

    private func routeRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.008, (lats.max()! - lats.min()!) * 1.6),
            longitudeDelta: max(0.008, (lons.max()! - lons.min()!) * 1.6)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func distanceText(_ meters: Double) -> String {
        AppMeasurementSystem.formatDistanceMeters(meters, fractionDigits: 2)
    }

    private func weeklyGoalDisplay(_ km: Double) -> String {
        if km <= 0 { return "0" }
        let rounded = (km * 2).rounded() / 2
        if rounded.truncatingRemainder(dividingBy: 1) < 0.01 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    private func adjustWeeklyGoal(_ delta: Double) {
        let next = min(100, max(0, goalDraft + delta))
        guard next != goalDraft else { return }
        goalDraft = (next * 2).rounded() / 2
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func petAvatar(pet: Pet, size: CGFloat) -> some View {
        PetAvatarPortraitView(
            imageData: pet.avatarImageData,
            fallbackText: pet.speciesEmoji,
            themeColor: Color(hex: pet.safeThemeColorHex),
            size: size,
            backgroundOpacity: 0.25
        )
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let s = Int(t)
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        let phase = isActivePet ? mgr.phase : .idle
        HStack(spacing: 8) {
            switch phase {
            case .idle:
                Button {
                    mgr.start(pet: pet)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("出发", systemImage: "figure.walk")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

            case .running:
                circleButton(icon: "pause.fill", color: Color.goYellow) { mgr.pause() }
                circleButton(icon: "stop.fill", color: Color.goRed) {
                    finishWalkAndFlip()
                }
                poopButton

            case .paused:
                circleButton(icon: "play.fill", color: Color.goTeal) { mgr.resume() }
                circleButton(icon: "stop.fill", color: Color.goRed) {
                    finishWalkAndFlip()
                }
                poopButton

            case .finished:
                Button {
                    mgr.reset()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("再来", systemImage: "arrow.clockwise")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func circleButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: icon)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.arkInk)
                .frame(width: 34, height: 34)
                .background(color, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var poopButton: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                mgr.addPoop()
                showFloatingPoop = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showFloatingPoop = false }
            } label: {
                Text("💩")
                    .font(.system(size: 15))
                    .frame(width: 34, height: 34)
                    .background(Color.ohanaCardSurface, in: Circle())
            }
            if mgr.poopCount > 0 {
                Text("\(mgr.poopCount)")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.goCardWhite)
                    .frame(width: 15, height: 15)
                    .background(Color.goOrange, in: Circle())
                    .offset(x: 3, y: -3)
            }
        }
    }

    private func finishWalkAndFlip() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        onStopWalk()
        presentSummaryBack()
    }

    private func presentSummaryBack(animated: Bool = true) {
        guard !showSummaryBack else { return }
        isClosingSummaryBack = false
        showSummaryBack = true
        summaryRotation = 0
        let updates = { summaryRotation = 180.0 }
        if animated {
            withAnimation(GoMotion.page) { updates() }
        } else {
            updates()
        }
    }

    private func updateRainbowRouteFlow() {
        guard shouldAnimateRainbowWalkEffects else {
            withAnimation(GoMotion.feedback) { rainbowRoutePhase = 0 }
            return
        }
        rainbowRoutePhase = 0
        withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) { // ui-v4: allow route cosmetic loop; runtime-guardrail: allow gated by AppWorkloadPolicy and only used for visible equipped walk maps; smoothness: allow visible active-walk route effect gated by surfaceGate.
            rainbowRoutePhase = -68
        }
    }

    private func closeSummaryBack() {
        guard showSummaryBack, !isClosingSummaryBack else { return }
        isClosingSummaryBack = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let onCloseSummaryToPetCard {
            onCloseSummaryToPetCard()
            return
        }
        withAnimation(GoMotion.page) {
            summaryRotation = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            showSummaryBack = false
            isClosingSummaryBack = false
            mgr.reset()
        }
    }
}
