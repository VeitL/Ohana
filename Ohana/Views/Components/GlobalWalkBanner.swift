//
//  GlobalWalkBanner.swift
//  Ohana
//
//  全局遛狗悬浮卡：
//  - 展开：底部大卡片（遛狗控制）
//  - 最小化：右侧可拖动气泡
//  - 结束后：卡片翻转到背面显示遛狗详情（地图+数据）+关闭按钮
//

import SwiftUI
import SwiftData
import MapKit

struct GlobalWalkBanner: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Household.createdAt) private var households: [Household]

    @State private var isMinimized = false
    @State private var showSummaryCard = false       // 结束后翻到背面
    @State private var summaryRotation: Double = 0   // 翻转角度
    @State private var isStopped = false             // B2: 结束状态，隐藏展开卡

    // 气泡拖动位置（Y轴，锚点在屏幕右侧）
    @State private var bubbleAnchorY: CGFloat = 0    // B1: 拖动结束后保存的Y
    @GestureState private var dragDelta: CGFloat = 0 // B1: 实时拖动偏移（GestureState自动归零）

    private var mgr: PetWalkingManager { PetWalkingManager.shared }
    private let flipCardHeight: CGFloat = 272

    private var isActive: Bool {
        switch mgr.phase {
        case .running, .paused: return true
        default: return false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                // ── 展开大卡片（遛狗中，结束后立即隐藏）
                if isActive, !isMinimized, !isStopped, let pet = mgr.currentPet {
                    expandedCard(pet: pet)
                        .frame(height: flipCardHeight)
                        .padding(.horizontal, 16)
                        .padding(.bottom, safeBottom(geo) + 160)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity)
                        .zIndex(998)
                }

                // ── 最小化气泡（可拖动，B1: 用 GestureState）
                if isActive, isMinimized, !isStopped, let pet = mgr.currentPet {
                    draggableBubble(pet: pet, geo: geo)
                        .zIndex(999)
                }

                // ── 结束后详情卡（直接翻转显示）
                if showSummaryCard, let pet = mgr.currentPet {
                    summaryFlipCard(pet: pet, geo: geo)
                        .zIndex(1000)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isMinimized)
            .animation(.easeInOut(duration: 0.15), value: isStopped)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 最小化气泡（B1: GestureState 消除幻影，drawingGroup 避免卡顿）
    private func draggableBubble(pet: Pet, geo: GeometryProxy) -> some View {
        let minY = -geo.size.height + 200
        let rawY = bubbleAnchorY + dragDelta
        let clampedY = max(minY, min(0, rawY))

        return ZStack {
            Circle()
                .fill(Color(hex: "0D1A0D").opacity(0.97))
                .overlay(Circle().strokeBorder(Color.goPrimary.opacity(0.5), lineWidth: 2))
                .shadow(color: Color.goPrimary.opacity(0.35), radius: 12)
            VStack(spacing: 1) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(formatElapsed(mgr.elapsedTime))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.goPrimary)
                }
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())  // C7: 裁剪成圆形，消除方块背景
        .compositingGroup()   // C7: 替代 drawingGroup，避免背景溢出
        .onTapGesture { withAnimation { isMinimized = false } }
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragDelta) { val, state, _ in
                    // GestureState 自动归零，不会有残留
                    let tentative = bubbleAnchorY + val.translation.height
                    state = max(minY, min(0, tentative)) - bubbleAnchorY
                }
                .onEnded { val in
                    let tentative = bubbleAnchorY + val.translation.height
                    bubbleAnchorY = max(minY, min(0, tentative))
                }
        )
        .padding(.trailing, 20)
        .padding(.bottom, safeBottom(geo) + 160)
        .offset(y: clampedY)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    // MARK: - 展开大卡片
    private func expandedCard(pet: Pet) -> some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                HStack(spacing: 8) {
                    petAvatar(pet: pet, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            if case .paused = mgr.phase {
                                Text("已暂停")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.goYellow)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color.goYellow.opacity(0.15), in: Capsule())
                            } else {
                                Circle().fill(Color.goPrimary).frame(width: 7, height: 7)
                                    .shadow(color: Color.goPrimary.opacity(0.8), radius: 4)
                                Text("巡岛中")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.goPrimary)
                            }
                        }
                        Text(pet.name)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
                Button { withAnimation { isMinimized = true } } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
            .padding(.horizontal, 20).padding(.top, 18)

            GoDashedDivider().padding(.horizontal, 20).padding(.top, 12)

            // 数据行
            HStack(spacing: 0) {
                walkStatCell(label: "时长", accent: .goPrimary) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(formatElapsed(mgr.elapsedTime))
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 40)
                walkStatCell(label: "距离", accent: .goTeal) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", LocationManager.shared.totalDistance / 1000))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("km").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.goTeal)
                    }
                }
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 40)
                walkStatCell(label: "便便", accent: .goYellow) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(mgr.poopCount)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("💩").font(.system(size: 14))
                    }
                }
            }
            .padding(.vertical, 14)

            GoDashedDivider().padding(.horizontal, 20)

            // 控制按钮
            HStack(spacing: 10) {
                Button {
                    if case .running = mgr.phase { mgr.pause() }
                    else if case .paused = mgr.phase { mgr.resume() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        mgr.phase == .running ? "暂停" : "继续",
                        systemImage: mgr.phase == .running ? "pause.fill" : "play.fill"
                    )
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(mgr.phase == .running ? Color.goYellow : Color.goTeal,
                                in: RoundedRectangle(cornerRadius: 14))
                }
                Button {
                    mgr.addPoop()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("💩").font(.system(size: 20))
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    // B2: 先隐藏展开卡，同帧立即显示翻转卡（不中间消失）
                    isStopped = true
                    mgr.stop(modelContext: modelContext, household: households.first)
                    // 立即进入翻转卡，避免先露出旧背景再显示新卡
                    showSummaryCard = true
                } label: {
                    Label("结束", systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.goRed, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .goGlassBackground(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
    }

    // MARK: - 结束后翻转详情卡（B2 重写）
    private func summaryFlipCard(pet: Pet, geo: GeometryProxy) -> some View {
        let elapsed = mgr.elapsedTime
        let distance = LocationManager.shared.totalDistance
        let poop = mgr.poopCount
        let latestWalk = pet.walkLogs.sorted { $0.startDate > $1.startDate }.first
        let showBack = summaryRotation >= 90

        return ZStack {
            summaryBackFace(pet: pet, elapsed: elapsed, distance: distance, poop: poop, latestWalk: latestWalk)
                .opacity(showBack ? 0 : 1)

            summaryBackFace(pet: pet, elapsed: elapsed, distance: distance, poop: poop, latestWalk: latestWalk)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showBack ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: flipCardHeight, maxHeight: flipCardHeight)
        .rotation3DEffect(.degrees(summaryRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
        .goGlassBackground(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, safeBottom(geo) + 160)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            summaryRotation = 0
            withAnimation(.easeInOut(duration: 0.42)) {
                summaryRotation = 180
            }
        }
    }

    private func summaryBackFace(
        pet: Pet,
        elapsed: TimeInterval,
        distance: Double,
        poop: Int,
        latestWalk: PetWalkLog?
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    petAvatar(pet: pet, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("巡岛完成 🎉")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                        Text(pet.name)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSummaryCard = false
                        summaryRotation = 0
                        isStopped = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { mgr.reset() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 12)

            Group {
                if let walk = latestWalk, let data = walk.mapSnapshotData, let ui = UIImage(data: data) {
                    Button {
                        if let url = URL(string: "maps://") { UIApplication.shared.open(url) }
                    } label: {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 108)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill").font(.system(size: 11, weight: .bold))
                                    Text("在地图中查看")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.black.opacity(0.45), in: Capsule())
                                .padding(8),
                                alignment: .bottomTrailing
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .frame(maxWidth: .infinity).frame(height: 108)
                        .overlay(
                            HStack(spacing: 6) {
                                Image(systemName: "map").font(.system(size: 20)).foregroundStyle(.primary.opacity(0.2))
                                Text("地图生成中…").font(.system(size: 12)).foregroundStyle(.primary.opacity(0.3))
                            }
                        )
                }
            }
            .padding(.horizontal, 18).padding(.top, 6)

            GoDashedDivider().padding(.horizontal, 18).padding(.top, 10)

            HStack(spacing: 0) {
                summaryStatCell(label: "时长", value: formatElapsed(elapsed), accent: .goPrimary)
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 36)
                summaryStatCell(label: "距离", value: distance >= 1000
                    ? String(format: "%.2f km", distance / 1000)
                    : String(format: "%.0f m", distance), accent: .goTeal)
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 36)
                summaryStatCell(label: "便便", value: "\(poop) 💩", accent: .goYellow)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
        }
    }

    // MARK: - 数据格（活跃中）
    private func walkStatCell<V: View>(label: String, accent: Color, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 3) {
            value()
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 数据格（详情卡）
    private func summaryStatCell(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 宠物头像
    private func petAvatar(pet: Pet, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: pet.themeColorHex).opacity(0.25)).frame(width: size, height: size)
            if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(pet.speciesEmoji).font(.system(size: size * 0.5))
            }
        }
    }

    private func safeBottom(_ geo: GeometryProxy) -> CGFloat {
        geo.safeAreaInsets.bottom
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let s = Int(t)
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
