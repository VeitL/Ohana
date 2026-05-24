//
//  WalkDetailView.swift
//  Ohana
//
//  N2: 遛狗详情页 — 交互式地图 + 路径 + Apple Maps 跳转

import SwiftUI
import MapKit

struct WalkDetailView: View {
    let walk: PetWalkLog
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @AppStorage(RainbowWalkEffectKeys.route) private var equipFxRainbow: Bool = false
    @AppStorage(RainbowWalkEffectKeys.poop) private var equipFxRainbowPoop: Bool = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var shareImage: UIImage? = nil
    @State private var isSharing = false
    @State private var isRendering = false
    @State private var rainbowRoutePhase: CGFloat = 0
    private let l = L10n()

    // 解码路径坐标
    private var routeCoordinates: [CLLocationCoordinate2D] {
        guard let data = walk.routeLocationsData,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
        else { return [] }
        return arr.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private var routeRegion: MKCoordinateRegion? {
        let coords = routeCoordinates + walkPoopMarkers.compactMap(\.coordinate)
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

    private var walkPoopMarkers: [WalkPoopMarker] {
        pet.pottyLogs
            .filter { $0.walkLogId == walk.id.uuidString }
            .sorted { $0.date < $1.date }
            .map {
                WalkPoopMarker(
                    id: $0.id,
                    date: $0.date,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    accuracyMeters: $0.locationAccuracyMeters,
                    type: $0.pottyType
                )
            }
    }

    private var shouldAnimateRainbowWalkEffects: Bool {
        (equipFxRainbow || equipFxRainbowPoop) && workloadPolicy.ambientMotionBudget(isVisible: true).allowsMotion
    }

    private var walkEndDateText: String {
        guard let endDate = walk.endDate else {
            return l.tr(zh: "未结束", en: "Open", de: "Offen")
        }
        return endDate.formatted(.dateTime.hour().minute())
    }

    private var averagePaceText: String {
        guard walk.distanceMeters > 5, walk.durationSeconds > 10 else { return "--" }
        let secondsPerKilometer = walk.durationSeconds / max(walk.distanceMeters / 1000, 0.001)
        let minutes = Int(secondsPerKilometer) / 60
        let seconds = Int(secondsPerKilometer) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }

    private var poopCountText: String {
        "\(walkPoopMarkers.count)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        pageChrome
                        heroSummary
                        mapSection
                        metricStrip
                        detailTimeline
                        Color.clear.frame(height: 28)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isSharing) {
                if let img = shareImage {
                    ShareSheet(image: img)
                }
            }
        }
        .onAppear { updateRainbowRouteFlow() }
        .onChange(of: shouldAnimateRainbowWalkEffects) { _, _ in updateRainbowRouteFlow() }
    }

    private var pageChrome: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.goPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(l.tr(zh: "遛狗回放", en: "Walk replay", de: "Spaziergang"))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pet.name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }

            Spacer(minLength: 0)

            Button {
                Task { await renderShareImage() }
            } label: {
                if isRendering {
                    ProgressView()
                        .tint(Color.ohanaPrimaryText)
                        .scaleEffect(0.78)
                        .frame(width: 42, height: 42)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 42, height: 42)
                }
            }
            .background(Color.ohanaControlFill, in: Circle())
            .disabled(isRendering)
            .buttonStyle(ScaleButtonStyle())

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 42)
            }
            .background(Color.ohanaControlFill, in: Circle())
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var heroSummary: some View {
        HStack(spacing: 14) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 58,
                backgroundOpacity: 0.10
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(walk.startDate, format: .dateTime.month().day().weekday(.wide))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(walk.startDate.formatted(.dateTime.hour().minute())) - \(walkEndDateText)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(walk.distanceText)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .ohanaNumericMotion(walk.distanceMeters)
                Text(l.tr(zh: "距离", en: "Distance", de: "Distanz"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    // MARK: - Map Section
    @ViewBuilder
    private var mapSection: some View {
        let coords = routeCoordinates
        if coords.count >= 2, let region = routeRegion {
            VStack(spacing: 10) {
                Map(initialPosition: .region(region)) {
                    RainbowRoutePolyline(
                        coordinates: coords,
                        normalColor: .goPrimary,
                        lineWidth: 5,
                        isRainbow: equipFxRainbow,
                        isFlowing: shouldAnimateRainbowWalkEffects,
                        flowPhase: rainbowRoutePhase
                    )

                    if let first = coords.first {
                        Annotation(l.tr(zh: "出发", en: "Start", de: "Start"), coordinate: first) {
                            routeEndpoint(color: .goPrimary, icon: "figure.walk")
                        }
                    }
                    if let last = coords.last {
                        Annotation(l.tr(zh: "到家", en: "Finish", de: "Ziel"), coordinate: last) {
                            routeEndpoint(color: .goRed, icon: "house.fill")
                        }
                    }

                    ForEach(walkPoopMarkers) { marker in
                        if let coordinate = marker.coordinate {
                            Annotation(l.tr(zh: "便便", en: "Poop", de: "Haufen"), coordinate: coordinate) {
                                RainbowPoopPin(
                                    isRainbow: equipFxRainbowPoop,
                                    isFlowing: shouldAnimateRainbowWalkEffects,
                                    size: 30
                                )
                            }
                        }
                    }
                }
                .frame(height: 334)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(alignment: .topLeading) {
                    mapBadge(icon: "point.topleft.down.curvedto.point.bottomright.up", text: "\(coords.count)")
                        .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    mapBadge(icon: "sparkles", text: equipFxRainbow ? l.tr(zh: "彩虹", en: "Rainbow", de: "Regenbogen") : l.tr(zh: "路线", en: "Route", de: "Route"))
                        .padding(12)
                }

                Button { openInAppleMaps(coords: coords) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 13, weight: .black))
                        Text(l.tr(zh: "Apple Maps", en: "Apple Maps", de: "Apple Maps"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        } else if let snapshotData = walk.mapSnapshotData, let img = UIImage(data: snapshotData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.ohanaControlFill)
                    .frame(height: 240)
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(l.tr(zh: "没有路径数据", en: "No route data", de: "Keine Routendaten"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 10) {
            metricPill(icon: "clock.fill", value: walk.durationText, label: l.tr(zh: "时长", en: "Time", de: "Zeit"))
            metricPill(icon: "speedometer", value: averagePaceText, label: l.tr(zh: "配速", en: "Pace", de: "Tempo"))
            metricPill(icon: "pawprint.fill", value: poopCountText, label: l.tr(zh: "便便", en: "Poop", de: "Haufen"))
        }
    }

    @ViewBuilder
    private var detailTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "这一趟", en: "This walk", de: "Dieser Spaziergang"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                if walk.coconutsEarned > 0 {
                    Text("+\(walk.coconutsEarned)🥥")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.goPrimary, in: Capsule())
                        .ohanaNumericMotion(walk.coconutsEarned)
                }
            }

            VStack(spacing: 8) {
                timelineRow(
                    icon: "play.fill",
                    title: l.tr(zh: "出发", en: "Started", de: "Gestartet"),
                    value: walk.startDate.formatted(.dateTime.month().day().hour().minute()),
                    tint: .goPrimary
                )
                timelineRow(
                    icon: "flag.checkered",
                    title: l.tr(zh: "结束", en: "Finished", de: "Beendet"),
                    value: walk.endDate?.formatted(.dateTime.month().day().hour().minute()) ?? l.tr(zh: "未结束", en: "Open", de: "Offen"),
                    tint: .goTeal
                )
                if walkPoopMarkers.isEmpty == false {
                    timelineRow(
                        icon: "pawprint.fill",
                        title: l.tr(zh: "路线事件", en: "Route events", de: "Routenereignisse"),
                        value: l.tr(zh: "\(walkPoopMarkers.count) 次便便", en: "\(walkPoopMarkers.count) poop stop\(walkPoopMarkers.count == 1 ? "" : "s")", de: "\(walkPoopMarkers.count) Haufen"),
                        tint: .goYellow
                    )
                }
                if let notes = walk.behaviorNotes, notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    timelineRow(
                        icon: "quote.bubble.fill",
                        title: l.tr(zh: "备注", en: "Note", de: "Notiz"),
                        value: notes,
                        tint: .goPurple
                    )
                }
            }
        }
    }

    private func updateRainbowRouteFlow() {
        guard shouldAnimateRainbowWalkEffects else {
            withAnimation(GoMotion.feedback) { rainbowRoutePhase = 0 }
            return
        }
        rainbowRoutePhase = 0
        withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) { // ui-v4: allow route cosmetic loop; runtime-guardrail: allow gated by AppWorkloadPolicy and only used for visible equipped walk detail maps.
            rainbowRoutePhase = -68
        }
    }

    private func routeEndpoint(color: Color, icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(width: 28, height: 28)
            .background(color, in: Circle())
            .shadow(color: color.opacity(0.28), radius: 8, y: 3) // ui-v4: allow semantic map endpoint elevation.
    }

    private func mapBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text(text)
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.ohanaCardSurface.opacity(0.88), in: Capsule())
    }

    private func metricPill(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .ohanaNumericMotion(value)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timelineRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Share
    @MainActor
    private func renderShareImage() async {
        isRendering = true
        defer { isRendering = false }

        // 优先使用已生成的地图快照
        if let data = walk.mapSnapshotData, let img = UIImage(data: data) {
            shareImage = img
            isSharing = true
            return
        }

        // 无快照时用 ImageRenderer 渲染 statsSection
        let renderer = ImageRenderer(content:
            VStack(spacing: 14) {
                heroSummary
                metricStrip
            }
                .frame(width: 360)
                .padding(20)
                .background(Color(hex: "4338FF"))
        )
        renderer.scale = 3.0
        if let img = renderer.uiImage {
            shareImage = img
            isSharing = true
        }
    }

    // MARK: - Apple Maps
    private func openInAppleMaps(coords: [CLLocationCoordinate2D]) {
        guard let first = coords.first, let last = coords.last else { return }

        let startItem = mapItem(coordinate: first)
        startItem.name = "出发点"
        let endItem = mapItem(coordinate: last)
        endItem.name = "终点"

        MKMapItem.openMaps(
            with: [startItem, endItem],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        )
    }

    private func mapItem(coordinate: CLLocationCoordinate2D) -> MKMapItem {
        if #available(iOS 26.0, *) {
            MKMapItem(
                location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                address: nil
            )
        } else {
            MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
