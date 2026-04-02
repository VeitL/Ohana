//
//  IslandEnergyBar.swift
//  Ohana
//
//  岛屿能量条：显示生命之树当前等级进度，嵌入首页委托卡区域顶部。
//

import SwiftUI

struct IslandEnergyBar: View {
    let progress: Double     // 0.0 ~ 1.0
    let levelLabel: String   // e.g. "🌱 希望之种 Lv.1"
    let nextLevelHint: String // e.g. "再完成 2 个任务可升级"

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标签行
            HStack(spacing: 6) {
                Text("🌿 岛屿能量")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
                Text(levelLabel)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                Text("·")
                    .foregroundStyle(.secondary.opacity(0.4))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)

                    // 填充进度
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.goPrimary.opacity(0.8), Color.goPrimary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * animatedProgress, height: 8)
                        .shadow(color: Color.goPrimary.opacity(0.4), radius: 4, y: 0)
                }
            }
            .frame(height: 8)

            // 升级提示
            Text(nextLevelHint)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newVal in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = newVal
            }
        }
    }
}

// MARK: - 便利包装（直接从 OasisTreeManager.shared 读取）
struct IslandEnergyBarContainer: View {
    private var mgr: OasisTreeManager { OasisTreeManager.shared }

    private var levelLabel: String {
        "Lv.\(mgr.treeLevel.rawValue) \(mgr.treeLevel.displayName)"
    }

    private var nextLevelHint: String {
        guard mgr.treeLevel < .lv10 else { return "🎉 生命之树已达满级！" }
        let remaining = mgr.nextLevelThreshold - mgr.totalEnergy
        return "还需 \(remaining) 点能量升级"
    }

    var body: some View {
        IslandEnergyBar(
            progress: mgr.progressToNextLevel,
            levelLabel: levelLabel,
            nextLevelHint: nextLevelHint
        )
    }
}
