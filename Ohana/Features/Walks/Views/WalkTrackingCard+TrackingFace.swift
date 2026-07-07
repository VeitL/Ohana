//
//  WalkTrackingCard+TrackingFace.swift
//  Ohana
//

import MapKit
import SwiftData
import SwiftUI

extension WalkTrackingCard {
    var trackingFrontFace: some View {
        ZStack(alignment: .bottom) {
            // ── 背景层：地图或快照
            mapBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── 控制层：半透明玻璃条
            VStack(spacing: 0) {
                if isActivePet {
                    walkLocationStatusPill
                }
                if !isWalking, let checkpoint = snapshot.recoverableWalkCheckpoint {
                    walkRecoveryPrompt(checkpoint: checkpoint)
                }
                controlPanel
            }
            .background(Color.ohanaCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
    }

    // MARK: - Map Background

    @ViewBuilder
    var mapBackground: some View {
        if isRunningWalk {
            let routeStyle = WalkTrackingMapPresentationPolicy.routeVisualStyle(for: mgr.phase)
            // 活跃遛狗中：实时位置地图
            Map(position: $cameraPosition) {
                UserAnnotation()
                RainbowRoutePolyline(
                    coordinates: liveRouteCoordinates,
                    normalColor: WalkTrackingMapPresentationPolicy.routeNormalColor(for: routeStyle),
                    lineWidth: 6,
                    isRainbow: WalkTrackingMapPresentationPolicy.allowsRainbowRoute(
                        phase: mgr.phase,
                        isRainbowEquipped: equipFxRainbowRoute
                    ),
                    isFlowing: WalkTrackingMapPresentationPolicy.allowsRouteFlow(
                        phase: mgr.phase,
                        shouldAnimate: shouldAnimateRainbowWalkEffects
                    ),
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
            .overlay(alignment: .topLeading) {
                distanceBadge
            }
        } else if isWalking {
            let coords = liveRouteCoordinates.isEmpty ? snapshot.latestRouteCoordinates : liveRouteCoordinates
            if coords.count >= 2, let region = routeRegion(for: coords) {
                let routeStyle = WalkTrackingMapPresentationPolicy.routeVisualStyle(for: mgr.phase)
                Map(initialPosition: .region(region)) {
                    RainbowRoutePolyline(
                        coordinates: coords,
                        normalColor: WalkTrackingMapPresentationPolicy.routeNormalColor(for: routeStyle),
                        lineWidth: 6,
                        isRainbow: WalkTrackingMapPresentationPolicy.allowsRainbowRoute(
                            phase: mgr.phase,
                            isRainbowEquipped: equipFxRainbowRoute
                        ),
                        isFlowing: WalkTrackingMapPresentationPolicy.allowsRouteFlow(
                            phase: mgr.phase,
                            shouldAnimate: shouldAnimateRainbowWalkEffects
                        ),
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
                .overlay(alignment: .topLeading) {
                    distanceBadge
                }
            } else {
                pausedRoutePlaceholder
            }
        } else {
            // 待出发：显示上次遛狗地图快照
            if let lastWalk = snapshot.latestWalk, let data = snapshot.latestWalkMapData {
                Button {
                    showWalkDetail = lastWalk
                } label: {
                    WalkMapSnapshotImage(data: data)
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
                        Image(systemName: "map") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 24)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goCardWhite.opacity(0.2))
                        Text(L10n(appLanguage).tr(zh: "暂无路线记录", en: "No route yet", de: "Noch keine Route"))
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color.goCardWhite.opacity(0.2))
                    }
                )
            }
        }
    }

    var distanceBadge: some View {
        Text(distanceText)
            .font(OhanaFont.footnote(.bold))
            .foregroundStyle(Color.goCardWhite)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.arkInk.opacity(0.6), in: Capsule())
            .padding(8)
            .accessibilityIdentifier("walk-tracking-distance-badge")
    }

    var pausedRoutePlaceholder: some View {
        LinearGradient(
            colors: [Color(hex: "1A2744"), Color(hex: "0D1526")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 6) {
                Image(systemName: "pause.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 24)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goYellow.opacity(0.7))
                Text(L10n(appLanguage).tr(zh: "遛狗已暂停", en: "Walk paused", de: "Gassi pausiert"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goCardWhite.opacity(0.62))
            }
        )
    }

    var poopMapPin: some View {
        RainbowPoopPin(
            isRainbow: equipFxRainbowPoop,
            isFlowing: shouldAnimateRainbowWalkEffects,
            size: 28
        )
    }

    var distanceText: String {
        AppMeasurementSystem.formatDistanceMeters(locationMgr.totalDistance)
    }

    var walkLocationStatusPill: some View {
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

    var walkLocationStatus: (icon: String, title: String, detail: String, tint: Color) {
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

    func walkRecoveryPrompt(checkpoint: PetWalkLog) -> some View {
        let l = L10n(appLanguage)
        return HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath") // a11y: allow decorative icon; adjacent text labels recovery state
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goYellow)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "发现未完成的遛狗", en: "Unfinished walk found", de: "Unvollendeter Spaziergang"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(AppMeasurementSystem.formatDistanceMeters(checkpoint.distanceMeters))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 8)
            Button {
                mgr.restore(checkpoint: checkpoint, modelContext: modelContext)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text(l.tr(zh: "继续", en: "Resume", de: "Fortsetzen"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(minHeight: 36)
                    .padding(.horizontal, 12)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("walk-recovery-resume-action")

            Button {
                mgr.discardRecoveryCheckpoint(checkpoint, modelContext: modelContext)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon; button supplies localized accessibilityLabel
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaControlFill, in: Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "丢弃未完成遛狗", en: "Discard unfinished walk", de: "Unvollendeten Spaziergang verwerfen"))
            .accessibilityIdentifier("walk-recovery-discard-action")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .accessibilityIdentifier("walk-recovery-prompt")
    }

    var controlPanel: some View {
        HStack(spacing: 0) {
            // Left: pet info + timer
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pet.avatarEmoji).font(OhanaFont.adaptive(size: 18)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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

    var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6) // a11y: allow decorative non-interactive frame; hit area handled by parent
    }

    var statusColor: Color {
        guard isActivePet else { return Color.ohanaTertiaryText.opacity(0.3) }
        switch mgr.phase {
        case .idle: return Color.ohanaTertiaryText.opacity(0.3)
        case .running: return Color.goPrimary
        case .paused: return Color.goYellow
        case .finished: return Color.goTeal
        }
    }

    @ViewBuilder
    var timerText: some View {
        if walkSurfaceGate.allowsRefresh {
            TimelineView(.periodic(from: .now, by: walkClockInterval)) { _ in
                walkTimerLabel(elapsed: currentWalkElapsedSeconds)
            }
        } else {
            walkTimerLabel(elapsed: currentWalkElapsedSeconds)
        }
    }

    var currentWalkElapsedSeconds: Int {
        isActivePet ? Int(mgr.elapsedTime) : 0
    }

    func walkTimerLabel(elapsed: Int) -> some View {
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
}
