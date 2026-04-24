// EmptyStateWelcomeCard.swift
// Cold-start welcome card shown when the user has no pets and no humans.
// Replaces the Mochi/Luna dummy stack for real first-time users.

import SwiftUI

struct EmptyStateWelcomeCard: View {
    var onAddPet:   () -> Void
    var onAddHuman: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("🏝️")
                .font(.system(size: 64))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("欢迎来到你的岛屿")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "23181A").opacity(0.88))
                Text("添加第一位家人开始记录")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "23181A").opacity(0.55))
            }

            VStack(spacing: 10) {
                Button(action: onAddPet) {
                    HStack(spacing: 8) {
                        Text("🐾").font(.system(size: 16))
                        Text("添加宠物")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.goLime, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加宠物")
                .accessibilityHint("打开添加成员界面")

                Button(action: onAddHuman) {
                    HStack(spacing: 8) {
                        Text("👤").font(.system(size: 16))
                        Text("添加家人")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "23181A").opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.6), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加家人")
                .accessibilityHint("打开添加成员界面")
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "FFE4EA"), Color(hex: "F8D8DF")],
                startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color(hex: "23181A").opacity(0.08), radius: 14, y: 6)
    }
}
