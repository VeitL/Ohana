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

    private var walkCountToday: Int {
        pet.walkLogs.filter { Calendar.current.isDateInToday($0.startDate) }.count
    }

    private var playCountToday: Int {
        pet.careLogs.filter { $0.type == CareType.play.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── 标题行
            HStack(spacing: 6) {
                Text("🐾").font(.system(size: 14))
                Text("遛狗 & 陪玩")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.25))
            }

            // ── 遛狗快捷行
            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.goLime)
                Text("遛狗")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("今日 \(walkCountToday) 次")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                Spacer()
            }

            // ── 陪玩快捷行
            HStack(spacing: 10) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "FF6B6B"))
                Text("陪玩")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("今日 \(playCountToday) 次")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
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
        .padding(.horizontal, 4)
    }
}
