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
    @AppStorage("shop_equip_fx_rainbow") private var equipFxRainbow: Bool = false
    @State private var shareImage: UIImage? = nil
    @State private var isSharing = false
    @State private var isRendering = false

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
        let coords = routeCoordinates
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

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()

                ScrollView {
                    VStack(spacing: 20) {
                        mapSection
                        statsSection
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("🦮 \(pet.name)的巡岛")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await renderShareImage() }
                    } label: {
                        if isRendering {
                            ProgressView()
                                .tint(Color.goLime)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.goLime)
                        }
                    }
                    .disabled(isRendering)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let img = shareImage {
                    ShareSheet(image: img)
                }
            }
        }
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
                    if equipFxRainbow {
                        MapPolyline(coordinates: coords)
                            .stroke(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .leading, endPoint: .trailing), lineWidth: 4)
                    } else {
                        MapPolyline(coordinates: coords)
                            .stroke(Color.goLime, lineWidth: 4)
                    }

                    // 起点标注
                    if let first = coords.first {
                        Annotation("出发", coordinate: first) {
                            ZStack {
                                Circle().fill(Color.goLime).frame(width: 20, height: 20)
                                Circle().fill(Color.arkInk).frame(width: 8, height: 8)
                            }
                        }
                    }
                    // 终点标注
                    if let last = coords.last {
                        Annotation("到家", coordinate: last) {
                            ZStack {
                                Circle().fill(Color.goRed).frame(width: 20, height: 20)
                                    .shadow(color: Color.goRed.opacity(0.4), radius: 6)
                                Circle().fill(.white).frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Apple Maps 跳转按钮
                Button { openInAppleMaps(coords: coords) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("在 Apple Maps 中查看")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.goLime)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.goLime.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        } else if let snapshotData = walk.mapSnapshotData, let img = UIImage(data: snapshotData) {
            // fallback：静态截图（无坐标时）
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.05))
                    .frame(height: 160)
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32))
                        .foregroundStyle(.primary.opacity(0.25))
                    Text("没有路径数据")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.3))
                }
            }
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 0) {
            statCell(icon: "ruler", value: walk.distanceText, label: "距离", color: Color.goLime)
            divider
            statCell(icon: "clock", value: walk.durationText, label: "时长", color: Color.goTeal)
            divider
            statCell(icon: "calendar", value: walk.startDate.formatted(.dateTime.month().day()), label: "日期", color: Color.goYellow)
            divider
            statCell(icon: "clock.badge", value: walk.startDate.formatted(.dateTime.hour().minute()), label: "出发", color: Color.goMint)
        }
        .padding(.vertical, 20)
        .goTranslucentCard(cornerRadius: 20)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 40)
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
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
