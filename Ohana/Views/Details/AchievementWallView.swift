//
//  AchievementWallView.swift
//  Ohana
//
//  P1-1: 成就墙视图 — 展示宠物所有成就徽章（解锁/未解锁）

import SwiftUI

struct AchievementWallView: View {
    let pet: Pet
    @State private var manager = AchievementManager.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()

                ScrollView {
                    VStack(spacing: 20) {
                        // 进度标题
                        progressHeader

                        // 徽章网格
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(manager.achievements) { badge in
                                badgeCell(badge)
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("🏆 \(pet.name)的成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
            }
            .task {
                await manager.evaluate(for: pet)
            }
        }
    }

    // MARK: - Progress Header
    private var progressHeader: some View {
        let unlocked = manager.achievements.filter(\.isUnlocked).count
        let total = manager.achievements.count
        return HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("\(unlocked)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                Text("已解锁")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(.primary.opacity(0.12)).frame(width: 1, height: 40)

            VStack(spacing: 6) {
                Text("\(total)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text("共计")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(.primary.opacity(0.12)).frame(width: 1, height: 40)

            VStack(spacing: 6) {
                Text(total > 0 ? "\(Int(Double(unlocked)/Double(total)*100))%" : "0%")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                Text("完成度")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .goTranslucentCard(cornerRadius: 20)
        .padding(.horizontal, 16)
    }

    // MARK: - Badge Cell
    private func badgeCell(_ badge: Achievement) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? badge.color.opacity(0.18) : Color.primary.opacity(0.05))
                    .frame(width: 60, height: 60)

                if badge.isUnlocked {
                    // 外发光
                    Circle()
                        .fill(badge.color.opacity(0.3))
                        .frame(width: 72, height: 72)
                        .blur(radius: 10)
                }

                Text(badge.emoji)
                    .font(.system(size: 28))
                    .opacity(badge.isUnlocked ? 1.0 : 0.25)
                    .grayscale(badge.isUnlocked ? 0 : 1)

                if badge.isUnlocked {
                    Circle()
                        .strokeBorder(badge.color.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                }
            }

            Text(badge.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(badge.isUnlocked ? Color.primary : Color.primary.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if badge.isUnlocked {
                Text("已解锁")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(badge.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badge.color.opacity(0.15), in: Capsule())
            } else {
                Text(badge.description)
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.25))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .goTranslucentCard(cornerRadius: 16)
    }
}
