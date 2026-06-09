//
//  HomeFirstSuccessCard.swift
//  Ohana
//
//  First-run quick check-in card for the GO home carousel.
//

import SwiftUI

struct HomeFirstSuccessCard: View {
    let pet: Pet
    var onFeed: () -> Void
    var onPlay: () -> Void
    var onMoment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("3 分钟成功体验")
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white) // ui-v4: allow dark success card text contrast
                    Text("选一个 10 秒动作，马上看到反馈和椰子奖励。")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62)) // ui-v4: allow dark success card secondary text contrast
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                actionButton("喂食", icon: "fork.knife", action: onFeed)
                actionButton("陪玩", icon: "tennisball.fill", action: onPlay)
                actionButton("照片", icon: "camera.fill", action: onMoment)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "102448").opacity(0.94), Color(hex: "0C1640").opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.28), lineWidth: 1)
        )
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                Text(title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
