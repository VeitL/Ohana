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

    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var walkCountToday: Int {
        pet.walkLogs.filter { Calendar.current.isDateInToday($0.startDate) }.count
    }

    private var playCountToday: Int {
        pet.careLogs.filter { $0.type == CareType.play.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }

    // 本周（周一起）步行距离 km
    private var thisWeekDistanceKm: Double {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let start = cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date ?? Date()
        return pet.walkLogs
            .filter { $0.startDate >= start }
            .reduce(0) { $0 + $1.distanceMeters } / 1000.0
    }

    private var weeklyGoalSet: Bool { pet.weeklyWalkGoalKm > 0 }
    private var weeklyGoalReached: Bool { weeklyGoalSet && thisWeekDistanceKm >= pet.weeklyWalkGoalKm }

    // 自适应文字颜色
    private var primaryText: Color {
        Color.ohanaPrimaryText
    }
    
    private var secondaryText: Color {
        Color.ohanaSecondaryText
    }
    
    private var tertiaryText: Color {
        Color.ohanaTertiaryText
    }

    var body: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
            // ── 标题行
            HStack(spacing: 6) {
                Text("🐾").font(OhanaFont.adaptive(size: 14))
                Text("遛狗 & 陪玩")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                    .foregroundStyle(tertiaryText)
            }

            // ── 遛狗快捷行
            HStack(spacing: 10) {
                Image(systemName: "figure.walk").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.goPrimary : Color.goTeal)
                Text("遛狗")
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryText)
                Text("今日 \(walkCountToday) 次")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryText)
                Spacer()
                // 本周进度胶囊（设置了目标才显示）
                if weeklyGoalSet {
                    let capsuleColor = weeklyGoalReached ? Color.goPrimary : Color.goTeal.opacity(0.8)
                    Text(String(format: "%.1f / %.0f km", thisWeekDistanceKm, pet.weeklyWalkGoalKm))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(weeklyGoalReached ? Color.arkInk : Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(capsuleColor, in: Capsule())
                }
            }

            // ── 陪玩快捷行
            HStack(spacing: 10) {
                Image(systemName: "tennisball.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "FF6B6B"))
                Text("陪玩")
                    .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryText)
                Text("今日 \(playCountToday) 次")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryText)
                Spacer()
                Button {
                    recordPlay()
                } label: {
                    Text("+ 打卡")
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "FF6B6B"), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
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
                    .background(Color.ohanaCardSurface.opacity(0.3), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                content()
                    .goGlassBackground(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private func recordPlay() {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let command = DomainCommand.petCareRecord(petID: pet.id, type: CareType.play.rawValue)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            _ = PetCareCommandExecutor(context: modelContext).recordCare(
                pet: pet,
                type: .play,
                executorId: executorId,
                note: "dog.activity.play"
            )
        }
    }
}
