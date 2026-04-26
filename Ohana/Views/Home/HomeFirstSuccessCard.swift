//
//  HomeFirstSuccessCard.swift
//  Ohana
//
//  First-run quick check-in card for the GO home carousel.
//

import SwiftUI

struct HomeFirstSuccessCard: View {
    let pet: Pet
    var onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("3 分钟成功体验")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("陪 \(pet.name) 玩一会儿，完成第一次轻量打卡并看到椰子奖励。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onComplete) {
                Text("陪玩 +🥥")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
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
}
