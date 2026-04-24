//
//  HomeMoreSection.swift
//  Ohana
//
//  首页简化 · 岛屿三层重构（P0）
//  把"记忆碎片 / 岛屿统计 / 完整负反馈列表 / 家庭活动完整条"
//  收进一个可折叠的底部抽屉，默认折叠（一行标题 + ⌄），点击展开。
//

import SwiftUI

struct HomeMoreSection<Memory: View, Stats: View>: View {
    var hasMemory: Bool
    var hasStats: Bool
    @ViewBuilder var memory: () -> Memory
    @ViewBuilder var stats: () -> Stats

    @AppStorage("home_more_expanded") private var expanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if hasMemory || hasStats {
            VStack(spacing: 0) {
                header
                if expanded {
                    VStack(spacing: 24) {
                        if hasMemory { memory() }
                        if hasStats {  stats()  }
                    }
                    .padding(.top, 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: expanded)
        } else {
            EmptyView()
        }
    }

    private var header: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation { expanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.primary.opacity(0.5))
                    .frame(width: 18, height: 18)
                    .background(Color.primary.opacity(0.08), in: Circle())
                Text(expanded ? "收起 · 岛屿近况" : "更多 · 岛屿近况")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.primary.opacity(0.55))
                Spacer()
                if !expanded {
                    Text(previewHint)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var previewHint: String {
        var items: [String] = []
        if hasMemory { items.append("回忆") }
        if hasStats { items.append("统计") }
        return items.joined(separator: " · ")
    }
}
