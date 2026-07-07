//
//  WalkTrackingCard+SummaryFace.swift
//  Ohana
//

import MapKit
import SwiftData
import SwiftUI

extension WalkTrackingCard {
    // MARK: - Finished Back Face

    var walkSummaryBackFace: some View {
        GeometryReader { geo in
            let walk = latestWalk
            let elapsed = finishedElapsed
            let distance = finishedDistance(walk)
            let poop = finishedPoopCount
            let coconutDelta = finishedCoconutDelta(for: walk)
            let contentHeight = max(0, geo.size.height - 28)
            let footerHeight: CGFloat = coconutDelta > 0 ? 116 : 74
            let mapHeight = max(144, contentHeight - footerHeight)

            ZStack {
                LinearGradient(
                    colors: [Color(hex: "12264A"), Color(hex: "07111F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 12) {
                    summaryMapPanel(walk: walk, distance: distance)
                        .frame(height: mapHeight)

                    if coconutDelta > 0 {
                        summaryRewardBadge(delta: coconutDelta)
                    }

                    HStack(spacing: 8) {
                        summaryStatCell(label: L10n(appLanguage).tr(zh: "时间", en: "Time", de: "Zeit"), value: formatElapsed(elapsed), accent: .goPrimary, identifier: "walk-tracking-summary-duration")
                        summaryStatCell(label: L10n(appLanguage).tr(zh: "距离", en: "Distance", de: "Distanz"), value: distanceText(distance), accent: .goTeal, identifier: "walk-tracking-summary-distance")
                        summaryStatCell(label: L10n(appLanguage).tr(zh: "便便", en: "Poop", de: "Häufchen"), value: poopCountText(poop), accent: .goYellow, identifier: "walk-tracking-summary-poop")
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

    func summaryRewardBadge(delta: Int) -> some View {
        Label {
            Text(L10n(appLanguage).tr(zh: "+\(delta) 椰子", en: "+\(delta) coconuts", de: "+\(delta) Kokosnüsse"))
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } icon: {
            Image(systemName: "plus.circle.fill") // a11y: allow decorative reward glyph; label text names the reward.
                .font(OhanaFont.adaptive(size: 13, weight: .black))
        }
        .foregroundStyle(Color.arkInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.goPrimary, in: Capsule())
        .ohanaNumericMotion(delta)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityIdentifier("walk-tracking-summary-coconut-reward")
    }

    func summaryMapPanel(walk: PetWalkLog?, distance: Double) -> some View {
        ZStack {
            summaryRouteMap(walk: walk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                        .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 1)
                }
                .clipped()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    petAvatar(pet: pet, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n(appLanguage).tr(zh: "本次遛狗", en: "This walk", de: "Dieser Spaziergang"))
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.goPrimary)
                            .tracking(1.2)
                        Text(L10n(appLanguage).tr(zh: "\(pet.name) 到家啦", en: "\(pet.name) is home", de: "\(pet.name) ist zurück"))
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

    var summaryMapToolbar: some View {
        HStack(spacing: 8) {
            summaryEditGoalIconButton
            summaryCloseButton
        }
        .zIndex(40)
    }

    var summaryMapToolbarPlaceholder: some View {
        Color.clear
            .frame(width: 96, height: 44)
            .allowsHitTesting(false)
    }

    var summaryCloseButton: some View {
        Button { closeSummaryBack() } label: {
            Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goCardWhite)
                .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.arkInk.opacity(0.42), in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.goCardWhite.opacity(0.18), lineWidth: 1)
                }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n(appLanguage).tr(zh: "关闭遛狗摘要", en: "Close walk summary", de: "Spaziergangsübersicht schließen"))
        .accessibilityIdentifier("walk-tracking-summary-close-action")
    }

    var summaryEditGoalIconButton: some View {
        Button {
            goalDraft = max(3, pet.weeklyWalkGoalKm)
            showingGoalSetter = true
        } label: {
            Image(systemName: "slider.horizontal.3") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.arkInk)
                .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPrimary, in: Circle())
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n(appLanguage).tr(zh: "编辑遛狗目标", en: "Edit walk goal", de: "Spaziergangsziel bearbeiten"))
        .accessibilityIdentifier("walk-tracking-summary-goal-action")
    }

    @ViewBuilder
    func summaryRouteMap(walk: PetWalkLog?) -> some View {
        let coords = snapshot.latestRouteCoordinates
        let poopMarkers = snapshot.latestPoopMarkers
        let markerCoords = poopMarkers.compactMap(\.coordinate)
        let previewCoords = coords.isEmpty ? markerCoords : coords
        if walk != nil, let data = snapshot.latestWalkMapData, !(equipFxRainbowRoute || equipFxRainbowPoop) {
            GeometryReader { geo in
                WalkMapSnapshotImage(data: data)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Label(L10n(appLanguage).tr(zh: "本次轨迹", en: "Route", de: "Route"), systemImage: "map.fill")
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
                title: coords.count >= 2
                    ? L10n(appLanguage).tr(zh: "本次轨迹", en: "Route", de: "Route")
                    : L10n(appLanguage).tr(zh: "本次定位", en: "Location", de: "Standort")
            )
        } else {
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                .fill(Color.goCardWhite.opacity(0.08))
                .overlay {
                    VStack(spacing: 5) {
                        Image(systemName: "map") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 22, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goCardWhite.opacity(0.28))
                        Text(L10n(appLanguage).tr(zh: "本次轨迹生成中", en: "Route is being generated", de: "Route wird erstellt"))
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.goCardWhite.opacity(0.38))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    func summaryGoalOverlay(distance _: Double) -> some View {
        if pet.weeklyWalkGoalKm > 0 {
            let progress = weeklyProgress
            goalOverlayContainer {
                HStack(spacing: 10) {
                    goalProgressRing(progress: progress)
                    goalTextBlock(
                        title: L10n(appLanguage).tr(zh: "本周目标", en: "Weekly goal", de: "Wochenziel"),
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
                            title: L10n(appLanguage).tr(zh: "还没有遛狗目标", en: "No walk goal yet", de: "Noch kein Spaziergangsziel"),
                            subtitle: L10n(appLanguage).tr(zh: "设一个每周目标，之后会显示完成率", en: "Set a weekly goal to see progress here.", de: "Setze ein Wochenziel, um Fortschritt zu sehen.")
                        )
                        Spacer(minLength: 8)
                        editGoalButton
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            goalFlagIcon
                            goalTextBlock(
                                title: L10n(appLanguage).tr(zh: "还没有遛狗目标", en: "No walk goal yet", de: "Noch kein Spaziergangsziel"),
                                subtitle: L10n(appLanguage).tr(zh: "设一个每周目标，之后会显示完成率", en: "Set a weekly goal to see progress here.", de: "Setze ein Wochenziel, um Fortschritt zu sehen.")
                            )
                            Spacer(minLength: 0)
                        }
                        editGoalButton
                    }
                }
            }
        }
    }

    func goalOverlayContainer(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.arkInk.opacity(0.48), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 1)
            }
    }

    func goalTextBlock(title: String, subtitle: String) -> some View {
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

    func goalProgressRing(progress: Double) -> some View {
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
        .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
    }

    var goalFlagIcon: some View {
        Image(systemName: "flag.checkered") // a11y: allow decorative icon covered by surrounding text or control
            .font(OhanaFont.adaptive(size: 18, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.goPrimary)
            .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
            .background(Color.arkInk.opacity(0.34), in: Circle())
    }

    var editGoalButton: some View {
        Button {
            goalDraft = max(3, pet.weeklyWalkGoalKm)
            showingGoalSetter = true
        } label: {
            Text(L10n(appLanguage).tr(zh: "编辑目标", en: "Edit goal", de: "Ziel ändern"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.arkInk)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var walkGoalSetterSheet: some View {
        VStack(spacing: 20) {
            Text(L10n(appLanguage).tr(zh: "设定每周步行目标", en: "Set weekly walk goal", de: "Wochenziel festlegen"))
                .font(OhanaFont.headline(.black))
                .padding(.top, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weeklyGoalDisplay(goalDraft))
                    .font(OhanaFont.adaptive(size: 52, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .contentTransition(.numericText())
                    .animation(GoMotion.feedback, value: goalDraft)
                Text(L10n(appLanguage).tr(zh: "km / 周", en: "km / week", de: "km / Woche"))
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            HStack(spacing: 28) {
                Button { adjustWeeklyGoal(-0.5) } label: {
                    Image(systemName: "minus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 40, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft <= 0 ? Color.ohanaTertiaryText.opacity(0.35) : Color.goPrimary, Color.ohanaControlFill.opacity(0.42))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(goalDraft <= 0)

                Text(L10n(appLanguage).tr(zh: "每次 ±0.5 km", en: "±0.5 km per tap", de: "±0,5 km pro Tipp"))
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(Color.ohanaSecondaryText)

                Button { adjustWeeklyGoal(0.5) } label: {
                    Image(systemName: "plus.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 40, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(goalDraft >= 100 ? Color.ohanaTertiaryText.opacity(0.35) : Color.goPrimary, Color.ohanaControlFill.opacity(0.42))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(goalDraft >= 100)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let result = onSaveWeeklyGoal(goalDraft)
                guard result.didPersist else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showingGoalSetter = false
            } label: {
                Text(goalDraft == 0
                    ? L10n(appLanguage).tr(zh: "清除目标", en: "Clear goal", de: "Ziel löschen")
                    : L10n(appLanguage).tr(zh: "保存目标", en: "Save goal", de: "Ziel speichern"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.row))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)

            Spacer(minLength: 8)
        }
    }

    func summaryStatCell(label: String, value: String, accent: Color, identifier: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goCardWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("\(identifier)-value")
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
    }

    var latestWalk: PetWalkLog? {
        snapshot.latestWalk
    }

    func finishedCoconutDelta(for walk: PetWalkLog?) -> Int {
        if let summary = lastStopRewardSummary,
           summary.walkLogID == nil || summary.walkLogID == walk?.id {
            return summary.coconutDelta
        }
        return walk?.coconutsEarned ?? 0
    }

    var finishedElapsed: TimeInterval {
        if case let .finished(elapsed, _) = mgr.phase, mgr.currentPet?.id == pet.id {
            return elapsed
        }
        return latestWalk?.durationSeconds ?? 0
    }

    var finishedPoopCount: Int {
        if case let .finished(_, poopCount) = mgr.phase, mgr.currentPet?.id == pet.id {
            return poopCount
        }
        return mgr.poopCount
    }

    func finishedDistance(_ walk: PetWalkLog?) -> Double {
        if let walk, walk.distanceMeters > 0 {
            return walk.distanceMeters
        }
        return locationMgr.totalDistance
    }

    var thisWeekDistanceKm: Double {
        snapshot.thisWeekDistanceKm
    }

    var weeklyProgress: Double {
        guard pet.weeklyWalkGoalKm > 0 else { return 0 }
        return min(thisWeekDistanceKm / pet.weeklyWalkGoalKm, 1.0)
    }

    func routeCoordinates(from locations: [CLLocation], maxCount: Int) -> [CLLocationCoordinate2D] {
        guard locations.count > maxCount, maxCount >= 2 else {
            return locations.map(\.coordinate)
        }
        let step = Double(locations.count - 1) / Double(maxCount - 1)
        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(maxCount)
        var lastIndex = -1
        for i in 0 ..< maxCount {
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

    func routeRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
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

    func distanceText(_ meters: Double) -> String {
        AppMeasurementSystem.formatDistanceMeters(meters, fractionDigits: 2)
    }

    func poopCountText(_ count: Int) -> String {
        L10n(appLanguage).tr(zh: "\(count)次", en: "\(count)", de: "\(count)")
    }

    func weeklyGoalDisplay(_ km: Double) -> String {
        if km <= 0 { return "0" }
        let rounded = (km * 2).rounded() / 2
        if rounded.truncatingRemainder(dividingBy: 1) < 0.01 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    func adjustWeeklyGoal(_ delta: Double) {
        let next = min(100, max(0, goalDraft + delta))
        guard next != goalDraft else { return }
        goalDraft = (next * 2).rounded() / 2
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func petAvatar(pet: Pet, size: CGFloat) -> some View {
        PetAvatarPortraitView(
            pet: pet,
            fallbackText: pet.speciesEmoji,
            themeColor: Color(hex: pet.safeThemeColorHex),
            size: size,
            backgroundOpacity: 0.25
        )
    }

    func formatElapsed(_ t: TimeInterval) -> String {
        let s = Int(t)
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
