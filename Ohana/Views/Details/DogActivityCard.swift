//
//  DogActivityCard.swift
//  Ohana
//
//  狗狗专属卡片：遛狗 + 陪玩 — 极简双行快捷打卡
//

import SwiftUI
import SwiftData

struct DogActivityCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var walkCountToday: Int {
        pet.walkLogs.filter { Calendar.current.isDateInToday($0.startDate) }.count
    }

    private var playCountToday: Int {
        pet.careLogs.filter { $0.type == CareType.play.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }

    // 自适应文字颜色
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4)
    }

    var body: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
            // ── 标题行
            HStack(spacing: 6) {
                Text("🐾").font(.system(size: 14))
                Text("遛狗 & 陪玩")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tertiaryText)
            }

            // ── 遛狗快捷行
            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.goLime : Color.goTeal)
                Text("遛狗")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryText)
                Text("今日 \(walkCountToday) 次")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryText)
                Spacer()
            }

            // ── 陪玩快捷行
            HStack(spacing: 10) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "FF6B6B"))
                Text("陪玩")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryText)
                Text("今日 \(playCountToday) 次")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryText)
                Spacer()
                Button {
                    let log = PetCareLog(date: Date(), type: .play, pet: pet)
                    modelContext.insert(log)
                    modelContext.safeSave()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("+ 打卡")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "FF6B6B"), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        }
    }
    
    // MARK: - Glass Card Helper
    @ViewBuilder
    private func glassCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        if reduceTransparency {
            // 无障碍降级：纯色不透明背景
            content()
                .background(Color(.systemBackground).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            // 浅色模式下更透明
            if colorScheme == .light {
                content()
                    .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                content()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}
