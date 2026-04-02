//
//  WalkTrackingCard.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import MapKit

struct WalkTrackingCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]

    // 单一数据源
    private var mgr: PetWalkingManager { PetWalkingManager.shared }

    @State private var showFloatingPoop = false
    @State private var showWalkDetail: PetWalkLog? = nil
    @State private var showSummarySheet = false
    @State private var showAlwaysBanner = false
    private var locationMgr: LocationManager { LocationManager.shared }

    // 当前 pet 是否是正在遛的 pet（多宠物场景下隔离）
    private var isActivePet: Bool {
        mgr.currentPet?.id == pet.id || mgr.phase == .idle
    }

    var body: some View {
        VStack(spacing: 0) {
            // Always 权限升级横幅（仅 WhenInUse 时显示）
            if showAlwaysBanner {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.goYellow)
                    Text("开启「始终允许」定位，后台路线追踪更完整")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.85))
                    Spacer()
                    Button {
                        locationMgr.upgradeToAlways()
                    } label: {
                        Text("升级")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goYellow)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.goYellow.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        withAnimation { showAlwaysBanner = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.goYellow.opacity(0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 16) {
                // 左列
                VStack(alignment: .leading, spacing: 10) {
                    headerRow
                    timerArea
                    buttonRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 右列 — 地图小图
                mapPreview
                    .frame(width: 110, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .padding(16)
        }
        .goTranslucentCard(cornerRadius: 20)
        .sheet(item: $showWalkDetail) { walk in
            WalkDetailView(walk: walk, pet: pet)
        }
        .sheet(isPresented: $showSummarySheet) {
            WalkSummarySheet(pet: pet)
        }
        .onChange(of: mgr.showSummary) { _, newVal in
            if newVal && mgr.currentPet?.id == pet.id {
                showSummarySheet = true
                mgr.showSummary = false
            }
        }
        .onAppear {
            withAnimation {
                showAlwaysBanner = locationMgr.authorizationStatus == .authorizedWhenInUse
            }
        }
        .onChange(of: locationMgr.authorizationStatus) { _, status in
            withAnimation {
                showAlwaysBanner = (status == .authorizedWhenInUse)
            }
        }
    }
    
    // MARK: - Header Row
    private var headerRow: some View {
        HStack(spacing: 8) {
            // 宠物头像
            ZStack {
                Circle()
                    .fill(pet.themeColor.color.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
                Text(pet.avatarEmoji)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                statusBadge
            }
        }
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusColor: Color {
        guard isActivePet else { return .white.opacity(0.3) }
        switch mgr.phase {
        case .idle: return .white.opacity(0.3)
        case .running: return Color.goPrimary
        case .paused: return Color.goYellow
        case .finished: return Color.goTeal
        }
    }
    
    private var statusText: String {
        guard isActivePet else { return "待出发" }
        switch mgr.phase {
        case .idle: return "待出发"
        case .running: return "运动中"
        case .paused: return "已暂停"
        case .finished: return "已完成"
        }
    }
    
    // MARK: - Timer Area
    private var timerArea: some View {
        let elapsed = isActivePet ? Int(mgr.elapsedTime) : 0
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return HStack(spacing: 2) {
            Text(String(format: "%02d", h))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(":")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
            Text(String(format: "%02d", m))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(":")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
            Text(String(format: "%02d", s))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.goPrimary)
                .contentTransition(.numericText())
        }
        .animation(.default, value: elapsed)
    }
    
    // MARK: - Button Row
    private var buttonRow: some View {
        let phase = isActivePet ? mgr.phase : .idle
        return HStack(spacing: 8) {
            switch phase {
            case .idle:
                Button {
                    mgr.start(pet: pet)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12, weight: .bold))
                        Text("出发")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.goPrimary, in: Capsule())
                }

            case .running:
                Button {
                    mgr.pause()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                        .background(Color.goYellow, in: Circle())
                }
                Button {
                    mgr.stop(modelContext: modelContext, household: households.first)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color.goRed, in: Circle())
                }
                poopButton

            case .paused:
                Button {
                    mgr.resume()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                        .background(Color.goTeal, in: Circle())
                }
                Button {
                    mgr.stop(modelContext: modelContext, household: households.first)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color.goRed, in: Circle())
                }
                poopButton

            case .finished:
                Button {
                    mgr.reset()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("再来一次")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.goPrimary, in: Capsule())
                }
            }
        }
    }
    
    // MARK: - Poop Button
    private var poopButton: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                mgr.addPoop()
                showFloatingPoop = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showFloatingPoop = false
                }
            } label: {
                Text("💩")
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(.regularMaterial, in: Circle())
            }
            
            if mgr.poopCount > 0 {
                Text("\(mgr.poopCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 16, height: 16)
                    .background(.orange, in: Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
    
    // MARK: - Map Preview
    @ViewBuilder
    private var mapPreview: some View {
        let phase = isActivePet ? mgr.phase : .idle
        if phase == .idle {
            let lastWalk = pet.walkLogs.sorted(by: { $0.startDate > $1.startDate }).first
            Button {
                if let walk = lastWalk { showWalkDetail = walk }
            } label: {
                ZStack {
                    if let data = lastWalk?.mapSnapshotData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.white.opacity(0.04)
                        VStack(spacing: 6) {
                            Image(systemName: "map")
                                .font(.system(size: 26))
                                .foregroundStyle(.primary.opacity(0.25))
                            Text("无记录")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.2))
                        }
                    }
                    if lastWalk != nil {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up.forward.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.goPrimary)
                                    .shadow(radius: 4)
                                    .padding(6)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            ZStack {
                Color.goPrimary.opacity(0.07)
                VStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.goPrimary)
                    Text(LocationManager.shared.totalDistance >= 1000
                         ? String(format: "%.1f km", LocationManager.shared.totalDistance / 1000)
                         : String(format: "%.0f m", LocationManager.shared.totalDistance))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
    }
    
}
