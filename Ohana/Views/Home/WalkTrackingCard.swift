//
//  WalkTrackingCard.swift
//  Ohana
//
//  遛狗追踪卡片：地图铺满卡片背景，控制面板以玻璃层叠加。
//

import SwiftUI
import SwiftData
import MapKit

struct WalkTrackingCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]

    private var mgr: PetWalkingManager { PetWalkingManager.shared }
    private var locationMgr: LocationManager { LocationManager.shared }

    @State private var showFloatingPoop = false
    @State private var showWalkDetail: PetWalkLog? = nil
    @State private var showAlwaysBanner = false
    @State private var showSummaryBack = false
    @State private var summaryRotation: Double = 0
    @State private var showingGoalSetter = false
    @State private var goalDraft: Double = 0
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

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

    var body: some View {
        ZStack {
            trackingFrontFace
                .opacity(summaryRotation < 90 ? 1 : 0)

            walkSummaryBackFace
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(summaryRotation >= 90 ? 1 : 0)
        }
        .rotation3DEffect(.degrees(summaryRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .sheet(item: $showWalkDetail) { walk in WalkDetailView(walk: walk, pet: pet) }
        .sheet(isPresented: $showingGoalSetter) {
            walkGoalSetterSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
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
            withAnimation { showAlwaysBanner = locationMgr.authorizationStatus == .authorizedWhenInUse }
            if case .finished = mgr.phase, mgr.currentPet?.id == pet.id {
                presentSummaryBack(animated: false)
            }
        }
        .onChange(of: locationMgr.authorizationStatus) { _, status in
            withAnimation { showAlwaysBanner = (status == .authorizedWhenInUse) }
        }
    }

    private var trackingFrontFace: some View {
        ZStack(alignment: .bottom) {
            // ── 背景层：地图或快照
            mapBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── 控制层：半透明玻璃条
            VStack(spacing: 0) {
                if showAlwaysBanner {
                    alwaysBanner
                }
                controlPanel
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Map Background

    @ViewBuilder
    private var mapBackground: some View {
        if isWalking {
            // 活跃遛狗中：实时位置地图
            Map(position: $cameraPosition) {
                UserAnnotation()
                MapPolyline(coordinates: locationMgr.collectedLocations.map(\.coordinate))
                    .stroke(Color.goPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
            }
            .overlay(alignment: .topTrailing) {
                Text(distanceText)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.black.opacity(0.6), in: Capsule())
                    .padding(8)
            }
        } else {
            // 待出发：显示上次遛狗地图快照
            let lastWalk = pet.walkLogs.sorted { $0.startDate > $1.startDate }.first
            if let data = lastWalk?.mapSnapshotData, let ui = UIImage(data: data) {
                Button {
                    if let walk = lastWalk { showWalkDetail = walk }
                } label: {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                }
                .buttonStyle(.plain)
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
                            .foregroundStyle(.white.opacity(0.2))
                        Text("暂无路线记录")
                            .font(OhanaFont.caption())
                            .foregroundStyle(.white.opacity(0.2))
                    }
                )
            }
        }
    }

    private var distanceText: String {
        let d = locationMgr.totalDistance
        return d >= 1000
            ? String(format: "%.1f km", d / 1000)
            : String(format: "%.0f m", d)
    }

    // MARK: - Always Permission Banner

    private var alwaysBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(OhanaFont.caption2())
                .foregroundStyle(Color.goYellow)
            Text("开启「始终允许」定位，后台追踪更完整")
                .font(OhanaFont.caption())
                .foregroundStyle(.primary.opacity(0.8))
            Spacer()
            Button { locationMgr.upgradeToAlways() } label: {
                Text("升级")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goYellow)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.goYellow.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            Button { withAnimation { showAlwaysBanner = false } } label: {
                Image(systemName: "xmark")
                    .font(OhanaFont.caption2())
                    .foregroundStyle(.primary.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
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
                        .foregroundStyle(.primary)
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
        guard isActivePet else { return .white.opacity(0.3) }
        switch mgr.phase {
        case .idle:     return .white.opacity(0.3)
        case .running:  return Color.goPrimary
        case .paused:   return Color.goYellow
        case .finished: return Color.goTeal
        }
    }

    private var timerText: some View {
        let elapsed = isActivePet ? Int(mgr.elapsedTime) : 0
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(h > 0
                 ? String(format: "%d:%02d:%02d", h, m, s)
                 : String(format: "%02d:%02d", m, s))
                .font(OhanaFont.metric(size: 22))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Finished Back Face

    private var walkSummaryBackFace: some View {
        let walk = latestWalk
        let elapsed = finishedElapsed
        let distance = finishedDistance(walk)
        let poop = finishedPoopCount

        return ZStack {
            LinearGradient(
                colors: [Color(hex: "12264A"), Color(hex: "07111F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    petAvatar(pet: pet, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本次遛狗")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.goPrimary)
                            .tracking(1.4)
                        Text("\(pet.name) 到家啦")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { closeSummaryBack() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭遛狗摘要")
                }

                summaryRouteMap(walk: walk)
                    .frame(height: 110)

                HStack(spacing: 8) {
                    summaryStatCell(label: "时间", value: formatElapsed(elapsed), accent: .goPrimary)
                    summaryStatCell(label: "距离", value: distanceText(distance), accent: .goTeal)
                    summaryStatCell(label: "便便", value: "\(poop)次", accent: .goYellow)
                }

                summaryGoalRow(distance: distance)
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private func summaryRouteMap(walk: PetWalkLog?) -> some View {
        let coords = routeCoordinates(for: walk)
        if coords.count >= 2, let region = routeRegion(for: coords) {
            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: coords)
                    .stroke(Color.goPrimary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                if let first = coords.first {
                    Annotation("出发", coordinate: first) {
                        Circle()
                            .fill(Color.goPrimary)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().fill(Color.arkInk).frame(width: 6, height: 6))
                    }
                }
                if let last = coords.last {
                    Annotation("到家", coordinate: last) {
                        Circle()
                            .fill(Color.goRed)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().fill(.white).frame(width: 7, height: 7))
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Label("本次轨迹", systemImage: "map.fill")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.46), in: Capsule())
                    .padding(8)
            }
        } else if let walk, let data = walk.mapSnapshotData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Label("本次轨迹", systemImage: "map.fill")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.46), in: Capsule())
                        .padding(8)
                }
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay {
                    VStack(spacing: 5) {
                        Image(systemName: "map")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white.opacity(0.28))
                        Text("本次轨迹生成中")
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
        }
    }

    @ViewBuilder
    private func summaryGoalRow(distance: Double) -> some View {
        if pet.weeklyWalkGoalKm > 0 {
            let progress = weeklyProgress
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.goPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("本周目标完成率")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(.white.opacity(0.52))
                    Text(String(format: "%.1f / %.0f km", thisWeekDistanceKm, pet.weeklyWalkGoalKm))
                        .font(OhanaFont.footnote(.black))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.goPrimary.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("还没有遛狗目标")
                        .font(OhanaFont.footnote(.black))
                        .foregroundStyle(.white)
                    Text("设一个每周目标，之后会显示完成率")
                        .font(OhanaFont.caption2(.medium))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Button {
                    goalDraft = max(3, pet.weeklyWalkGoalKm)
                    showingGoalSetter = true
                } label: {
                    Text("编辑目标")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var walkGoalSetterSheet: some View {
        VStack(spacing: 20) {
            Text("设定每周步行目标")
                .font(OhanaFont.headline(.black))
                .padding(.top, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weeklyGoalDisplay(goalDraft))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: goalDraft)
                Text("km / 周")
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 28) {
                Button { adjustWeeklyGoal(-0.5) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft <= 0 ? Color.secondary.opacity(0.35) : Color.goPrimary, Color.primary.opacity(0.12))
                }
                .buttonStyle(.plain)
                .disabled(goalDraft <= 0)

                Text("每次 ±0.5 km")
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(.secondary)

                Button { adjustWeeklyGoal(0.5) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft >= 100 ? Color.secondary.opacity(0.35) : Color.goPrimary, Color.primary.opacity(0.12))
                }
                .buttonStyle(.plain)
                .disabled(goalDraft >= 100)
            }

            Button {
                pet.weeklyWalkGoalKm = goalDraft
                modelContext.safeSave()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingGoalSetter = false
            } label: {
                Text(goalDraft == 0 ? "清除目标" : "保存目标")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer(minLength: 8)
        }
    }

    private func summaryStatCell(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var latestWalk: PetWalkLog? {
        pet.walkLogs.sorted { $0.startDate > $1.startDate }.first
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

    private var weekStartDate: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date ?? Date()
    }

    private var thisWeekDistanceKm: Double {
        pet.walkLogs
            .filter { $0.startDate >= weekStartDate }
            .reduce(0) { $0 + $1.distanceMeters } / 1000.0
    }

    private var weeklyProgress: Double {
        guard pet.weeklyWalkGoalKm > 0 else { return 0 }
        return min(thisWeekDistanceKm / pet.weeklyWalkGoalKm, 1.0)
    }

    private func routeCoordinates(for walk: PetWalkLog?) -> [CLLocationCoordinate2D] {
        guard let data = walk?.routeLocationsData,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
        else { return [] }
        return arr.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
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
        meters >= 1000
            ? String(format: "%.2f km", meters / 1000)
            : String(format: "%.0f m", meters)
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
        ZStack {
            Circle()
                .fill(Color(hex: pet.themeColorHex).opacity(0.25))
                .frame(width: size, height: size)
            if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(pet.speciesEmoji)
                    .font(.system(size: size * 0.5))
            }
        }
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
                .buttonStyle(.plain)

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
                .buttonStyle(.plain)
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
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(color, in: Circle())
        }
        .buttonStyle(.plain)
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
                    .background(.ultraThinMaterial, in: Circle())
            }
            if mgr.poopCount > 0 {
                Text("\(mgr.poopCount)")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(Color.goOrange, in: Circle())
                    .offset(x: 3, y: -3)
            }
        }
    }

    private func finishWalkAndFlip() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        mgr.stop(modelContext: modelContext, household: households.first)
        presentSummaryBack()
    }

    private func presentSummaryBack(animated: Bool = true) {
        guard !showSummaryBack else { return }
        showSummaryBack = true
        summaryRotation = 0
        let updates = { summaryRotation = 180.0 }
        if animated {
            withAnimation(.easeInOut(duration: 0.46)) { updates() }
        } else {
            updates()
        }
    }

    private func closeSummaryBack() {
        withAnimation(.easeInOut(duration: 0.24)) {
            summaryRotation = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            showSummaryBack = false
            mgr.reset()
        }
    }
}
