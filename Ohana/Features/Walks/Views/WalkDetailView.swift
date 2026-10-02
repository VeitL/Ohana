//
//  WalkDetailView.swift
//  Ohana
//
//  N2: 遛狗详情页 — 交互式地图 + 路径 + Apple Maps 跳转

import MapKit
import SwiftData
import SwiftUI

struct WalkDetailView: View {
    let walk: PetWalkLog
    let pet: Pet

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RainbowWalkEffectKeys.route) private var equipFxRainbow: Bool = false
    @AppStorage(RainbowWalkEffectKeys.poop) private var equipFxRainbowPoop: Bool = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var shareImage: UIImage? = nil
    @State private var isSharing = false
    @State private var isRendering = false
    @State private var rainbowRoutePhase: CGFloat = 0
    private var l: L10n { L10n(appLanguage) }

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
        WalkFeaturePolicy.activePoopMarkers(for: walk, pet: pet)
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
                        WalkExecutorNamesDataContainer(executorIds: walk.executorIds) { namesByID in
                            executorSummary(namesByID: namesByID)
                        }
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
                Image(systemName: "figure.walk") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(l.tr(zh: "遛狗回放", en: "Walk replay", de: "Spaziergang"))
                        .font(OhanaFont.adaptive(size: 19, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(pet.name)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                        .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                } else {
                    Image(systemName: "square.and.arrow.up") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                }
            }
            .background(Color.ohanaControlFill, in: Circle())
            .disabled(isRendering)
            .buttonStyle(ScaleButtonStyle())

            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
            }
            .background(Color.ohanaControlFill, in: Circle())
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            .accessibilityIdentifier("walk-detail-close")
        }
    }

    private var heroSummary: some View {
        HStack(spacing: 14) {
            PetAvatarPortraitView(
                pet: pet,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 58,
                backgroundOpacity: 0.10
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(walk.startDate, format: .dateTime.month().day().weekday(.wide))
                    .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(walk.startDate.formatted(.dateTime.hour().minute())) - \(walkEndDateText)")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(walk.distanceText)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .ohanaNumericMotion(walk.distanceMeters)
                Text(l.tr(zh: "距离", en: "Distance", de: "Distanz"))
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func executorSummary(namesByID: [UUID: String]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(WalkExecutorDisplay.title(l))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(WalkExecutorDisplay.names(for: walk.executorIds, namesByID: namesByID, l: l))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("walk-detail-executor")
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge))
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
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetCompact, style: .continuous))
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
                        Image(systemName: "map.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(l.tr(zh: "Apple Maps", en: "Apple Maps", de: "Apple Maps"))
                            .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    }
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        } else if let snapshotData = walk.mapSnapshotData {
            WalkDetailSnapshotImage(snapshotData: snapshotData)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.sheetCompact, style: .continuous)
                    .fill(Color.ohanaControlFill)
                    .frame(height: 240)
                VStack(spacing: 8) {
                    Image(systemName: "map") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 32, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(l.tr(zh: "没有路径数据", en: "No route data", de: "Keine Routendaten"))
                        .font(OhanaFont.adaptive(size: 14, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                    .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                if walk.coconutsEarned > 0 {
                    Text("+\(walk.coconutsEarned)🥥")
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryActionText)
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
        withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) { // ui-v4: allow route cosmetic loop; runtime-guardrail: allow gated by AppWorkloadPolicy and only used for visible equipped walk detail maps; smoothness: allow visible policy-gated route effect.
            rainbowRoutePhase = -68
        }
    }

    private func routeEndpoint(color: Color, icon: String) -> some View {
        Image(systemName: icon)
            .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
            .background(color, in: Circle())
            .shadow(color: color.opacity(0.28), radius: 8, y: 3) // ui-v4: allow semantic map endpoint elevation.
    }

    private func mapBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(text)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                    .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                Text(label)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Text(value)
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .ohanaNumericMotion(value)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func timelineRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    // MARK: - Share
    @MainActor
    private func renderShareImage() async {
        isRendering = true
        defer { isRendering = false }

        // 优先使用已生成的地图快照
        if let data = walk.mapSnapshotData,
           let img = await MapSnapshotImageDecoder.decode(data) {
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

private struct WalkDetailSnapshotImage: View {
    let snapshotData: Data

    @State private var image: UIImage?

    private var imageKey: String {
        "\(snapshotData.count)-\(snapshotData.hashValue)"
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: OhanaRadius.sheetCompact, style: .continuous)
                    .fill(Color.ohanaControlFill)
                    .overlay {
                        ProgressView()
                            .tint(Color.ohanaSecondaryText)
                    }
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetCompact, style: .continuous))
        .task(id: imageKey) {
            let decoded = await MapSnapshotImageDecoder.decode(snapshotData)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                image = decoded
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

/// Display only recorded participants; missing historical attribution never falls back to the current member.
enum WalkExecutorDisplay {
    static func descriptor(for executorIds: [String]) -> FetchDescriptor<Human> {
        let ids = Array(Set(executorIds.compactMap(UUID.init(uuidString:))))
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate { ids.contains($0.id) })
        descriptor.fetchLimit = max(1, ids.count)
        return descriptor
    }

    static func title(_ l: L10n) -> String {
        l.tr(zh: "执行人", en: "Walked by", de: "Begleitet von", es: "Paseo con", pt: "Passeio com",
             fr: "Promenade avec", ja: "散歩の担当者", ko: "산책 담당자", it: "Passeggiata con")
    }

    static func names(for executorIds: [String], namesByID: [UUID: String], l: L10n) -> String {
        guard !executorIds.isEmpty else {
            return l.tr(zh: "未记录", en: "Not recorded", de: "Nicht erfasst", es: "Sin registrar", pt: "Não registrado",
                        fr: "Non renseigné", ja: "記録なし", ko: "기록 없음", it: "Non registrato")
        }
        return executorIds.map { executorId in
            guard let id = UUID(uuidString: executorId), let name = namesByID[id] else {
                return l.tr(zh: "成员已不可用", en: "Member unavailable", de: "Mitglied nicht verfügbar", es: "Miembro no disponible",
                            pt: "Membro indisponível", fr: "Membre indisponible", ja: "メンバーが見つかりません", ko: "구성원 정보 없음", it: "Membro non disponibile")
            }
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName.isEmpty
                ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied", es: "Miembro sin nombre", pt: "Membro sem nome",
                       fr: "Membre sans nom", ja: "名前のないメンバー", ko: "이름 없는 구성원", it: "Membro senza nome")
                : trimmedName
        }.joined(separator: l.tr(zh: "、", en: ", ", de: ", ", es: ", ", pt: ", ", fr: ", ", ja: "、", ko: ", ", it: ", "))
    }
}
