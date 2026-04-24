//
//  WalkInProgressPill.swift
//  Ohana
//
//  巡岛最小化后的迷你胶囊：显示当前宠物 + 时长 + 重开按钮
//

import SwiftUI

struct WalkInProgressPill: View {
    let pet: Pet
    var onTap: () -> Void = {}

    private var mgr: PetWalkingManager { PetWalkingManager.shared }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 10) {
                // 左：行走小人图标（脉动）
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.25))
                        .frame(width: 30, height: 30)
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }

                // 中：宠物名 + 时长
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(pet.name) 正在巡岛")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let elapsed = Int(mgr.elapsedTime)
                        let m = elapsed / 60, s = elapsed % 60
                        Text(String(format: "已巡 %02d:%02d", m, s))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.55))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }

                Spacer(minLength: 0)

                // 右：展开箭头
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 26, height: 26)
                    .background(Color.goPrimary.opacity(0.12), in: Circle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(.thinMaterial)
            )
            .overlay(
                Capsule().strokeBorder(Color.goPrimary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
