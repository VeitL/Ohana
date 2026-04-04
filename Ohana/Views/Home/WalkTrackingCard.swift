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
    @State private var showSummarySheet = false
    @State private var showAlwaysBanner = false

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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .sheet(item: $showWalkDetail) { walk in WalkDetailView(walk: walk, pet: pet) }
        .sheet(isPresented: $showSummarySheet) { WalkSummarySheet(pet: pet) }
        .onChange(of: mgr.showSummary) { _, newVal in
            if newVal && mgr.currentPet?.id == pet.id {
                showSummarySheet = true
                mgr.showSummary = false
            }
        }
        .onAppear {
            withAnimation { showAlwaysBanner = locationMgr.authorizationStatus == .authorizedWhenInUse }
        }
        .onChange(of: locationMgr.authorizationStatus) { _, status in
            withAnimation { showAlwaysBanner = (status == .authorizedWhenInUse) }
        }
    }

    // MARK: - Map Background

    @ViewBuilder
    private var mapBackground: some View {
        if isWalking {
            // 活跃遛狗中：实时位置地图
            ZStack {
                Color(hex: "1A1F2E")
                // Live route overlay indicator
                VStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.goPrimary)
                        .shadow(color: Color.goPrimary.opacity(0.6), radius: 8)
                    Text(distanceText)
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
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
                    mgr.stop(modelContext: modelContext, household: households.first)
                }
                poopButton

            case .paused:
                circleButton(icon: "play.fill", color: Color.goTeal) { mgr.resume() }
                circleButton(icon: "stop.fill", color: Color.goRed) {
                    mgr.stop(modelContext: modelContext, household: households.first)
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
}
