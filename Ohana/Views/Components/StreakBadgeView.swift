//
//  StreakBadgeView.swift
//  Ohana
//
//  羁绊值徽章：显示连续打卡天数 + 火焰动画

import SwiftUI

struct StreakBadgeView: View {
    let streak: Int
    let petName: String
    @State private var flamePulse = false
    @State private var isVisible = false
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var shouldRunPulse: Bool {
        streak > 0 && workloadPolicy.shouldRunRepeatingAnimation(isVisible: isVisible)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(streak > 0 ? "🔥" : "💤")
                .font(.system(size: 14))
                .scaleEffect(shouldRunPulse && flamePulse ? 1.15 : 1.0)
                .animation(
                    shouldRunPulse
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : GoMotion.reduced,
                    value: flamePulse
                )
                .onAppear {
                    isVisible = true
                    flamePulse = shouldRunPulse
                }
                .onDisappear {
                    isVisible = false
                    flamePulse = false
                }
                .onChange(of: shouldRunPulse) { _, canRun in
                    flamePulse = canRun
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    Text("\(streak)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(streak >= 7 ? Color.goPrimary : Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Text("天")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                }
                Text(streakSubtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            streak >= 7
                ? Color.goPrimary.opacity(0.12)
                : Color.ohanaControlFill.opacity(0.72),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    streak >= 7 ? Color.goPrimary.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private var streakSubtitle: String {
        if streak == 0 { return "开始打卡吧" }
        if streak < 3  { return "好的开始！" }
        if streak < 7  { return "继续加油" }
        if streak < 30 { return "势不可当！" }
        return "传说级铲屎官"
    }
}
