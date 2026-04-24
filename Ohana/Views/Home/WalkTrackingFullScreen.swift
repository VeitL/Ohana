//
//  WalkTrackingFullScreen.swift
//  Ohana
//
//  巡岛进行时的前置全屏卡：
//  - 地图 + 实时轨迹铺满背景
//  - 底部玻璃控制面板（时长 / 便便 / 继续 / 结束）
//  - 顶部最小化按钮，可收回首页（巡岛继续在后台进行）
//
//  与原首页内嵌版共用 `WalkTrackingCard`，此处仅额外提供顶栏 + 全屏容器。
//

import SwiftUI
import SwiftData

struct WalkTrackingFullScreen: View {
    let pet: Pet
    var onMinimize: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 内部卡片本体（地图 + 控制面板）铺满整个屏幕
            WalkTrackingCard(pet: pet)
                .ignoresSafeArea()

            // 顶部最小化按钮 — 用户可收起卡片回到首页，巡岛继续进行
            minimizeButton
                .padding(.top, 12)
                .padding(.leading, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden(false)
    }

    private var minimizeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onMinimize()
            dismiss()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .heavy))
                Text("收起")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
