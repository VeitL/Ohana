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
        (equipFxRainbow || equipFxRainbowPoop) && workloadPolicy.shouldAnimate(isVisible: true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        detailHeader
                        mapSection
                        statsSection
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await renderShareImage() }
                    } label: {
                        if isRendering {
                            ProgressView()
                                .tint(Color.goPrimary)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.goPrimary)
                        }
                    }
                    .disabled(isRendering)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let img = shareImage {
                    ShareSheet(image: img)
                }
            }
        }
        .onAppear { updateRainbowRouteFlow() }
        .onChange(of: shouldAnimateRainbowWalkEffects) { _, _ in updateRainbowRouteFlow() }
    }

    private var detailHeader: some View {
        HStack(spacing: 14) {
            if let data = pet.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
            } else {
                Text(pet.avatarEmoji)
                    .font(.system(size: 34))
                    .frame(width: 54, height: 54)
                    .background(Color(hex: pet.themeColorHex).opacity(0.16), in: Circle())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("单次记录")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .tracking(1.2)
                Text(walk.startDate, format: .dateTime.month().day().weekday(.wide))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(walk.startDate, format: .dateTime.hour().minute())
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .goTranslucentCard(cornerRadius: 24)
    }

    // MARK: - Map Section
    @ViewBuilder
    private var mapSection: some View {
        let coords = routeCoordinates
        if coords.count >= 2, let region = routeRegion {
            VStack(spacing: 0) {
                // 交互式地图
                Map(initialPosition: .region(region)) {
                    // 路径折线
                    RainbowRoutePolyline(
                        coordinates: coords,
                        normalColor: .goPrimary,
                        lineWidth: 4,
                        isRainbow: equipFxRainbow,
                        isFlowing: shouldAnimateRainbowWalkEffects,
                        flowPhase: rainbowRoutePhase
                    )

                    // 起点标注
                    if let first = coords.first {
                        Annotation("出发", coordinate: first) {
                            ZStack {
                                Circle().fill(Color.goPrimary).frame(width: 20, height: 20)
                                Circle().fill(Color.arkInk).frame(width: 8, height: 8)
                            }
                        }
                    }
                    // 终点标注
                    if let last = coords.last {
                        Annotation("到家", coordinate: last) {
                            ZStack {
                                Circle().fill(Color.goRed).frame(width: 20, height: 20)
                                    .shadow(color: Color.goRed.opacity(0.4), radius: 6) // ui-v4: allow map endpoint glow.
                                Circle().fill(Color.goCardWhite).frame(width: 8, height: 8)
                            }
                        }
                    }

                    ForEach(walkPoopMarkers) { marker in
                        if let coordinate = marker.coordinate {
                            Annotation("便便", coordinate: coordinate) {
                                RainbowPoopPin(
                                    isRainbow: equipFxRainbowPoop,
                                    isFlowing: shouldAnimateRainbowWalkEffects,
                                    size: 28
                                )
                            }
                        }
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Apple Maps 跳转按钮
                Button { openInAppleMaps(coords: coords) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 14, weight: .bold))
                        Text("在 Apple Maps 中查看")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.goPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.goPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.top, 10)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(12)
            .goTranslucentCard(cornerRadius: 24)
        } else if let snapshotData = walk.mapSnapshotData, let img = UIImage(data: snapshotData) {
            // fallback：静态截图（无坐标时）
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .goTranslucentCard(cornerRadius: 24)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.ohanaCardSurface)
                    .frame(height: 160)
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                    Text("没有路径数据")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                }
            }
            .goTranslucentCard(cornerRadius: 24)
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overview")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                statCell(icon: "arrow.left.and.right", value: walk.distanceText, label: "距离")
                statCell(icon: "clock", value: walk.durationText, label: "时长")
                statCell(icon: "calendar", value: walk.startDate.formatted(.dateTime.month().day()), label: "日期")
                statCell(icon: "circle", value: walk.startDate.formatted(.dateTime.hour().minute()), label: "出发")
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 24)
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

    private var divider: some View {
        Rectangle()
            .fill(.primary.opacity(0.12))
            .frame(width: 1, height: 40)
    }

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.07), in: Circle())
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            statsSection
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

        let startItem = MKMapItem(placemark: MKPlacemark(coordinate: first))
        startItem.name = "出发点"
        let endItem = MKMapItem(placemark: MKPlacemark(coordinate: last))
        endItem.name = "终点"

        MKMapItem.openMaps(
            with: [startItem, endItem],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        )
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
